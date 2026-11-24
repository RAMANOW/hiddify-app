import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_tunnel_controller.dart';
import 'package:hiddify/features/raman/netwatch/net_watch_strings.dart';
import 'package:hiddify/features/raman/relay/relay_controller.dart';
import 'package:hiddify/features/raman/shield/shield_controller.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Raman VPN 1.9 per-network memory: which profile last worked on each network (Wi‑Fi or the
/// mobile operator), and a suggestion «این شبکه قبلاً با X وصل شد» with a "use it" button when the
/// phone moves to a network it knows. It only watches: it never connects, disconnects or
/// switches a profile unless the user taps the button (then the profile is chosen the normal
/// way, as in the profile list), and it does not touch the connection code.
abstract class NetMemPrefs {
  static final enabled = PreferencesNotifier.create<bool, bool>('raman-netmem-on', true);

  /// JSON {networkKey: {id, name, label, at}}.
  static const memory = 'raman-netmem';
  static const maxNetworks = 40;
}

/// The network the phone is on (under the VPN), from Android (NetworkId.kt).
class RamanNetwork {
  const RamanNetwork(this.kind, this.key, this.label, this.hidden);

  /// wifi / mobile / other / none
  final String kind;
  final String key;
  final String label;

  /// The Wi‑Fi name was hidden by Android (no location permission): the key is the router's.
  final bool hidden;

  static Future<RamanNetwork?> read() async {
    if (!Platform.isAndroid) return null;
    try {
      final m = await const MethodChannel(
        'com.ramanow.ramanvpn/dnstunnel',
      ).invokeMapMethod<String, dynamic>('networkId');
      final key = m?['key'] as String? ?? '';
      if (key.isEmpty) return null;
      return RamanNetwork(m?['kind'] as String? ?? 'other', key, m?['label'] as String? ?? '', m?['hidden'] == true);
    } catch (_) {
      return null;
    }
  }
}

final networkMemoryProvider = Provider<NetworkMemory>((ref) {
  final m = NetworkMemory(ref);
  ref.onDispose(m.dispose);
  return m;
});

class NetworkMemory with InfraLogger {
  NetworkMemory(this._ref);

  final Ref _ref;
  Timer? _timer;
  String? _lastKey;
  int _connectedTicks = 0;
  bool _busy = false;

  /// The network seen last (for the settings tile).
  final current = ValueNotifier<RamanNetwork?>(null);
  final version = ValueNotifier(0);

  static const _tick = Duration(seconds: 20);

  SharedPreferences get _prefs => _ref.read(sharedPreferencesProvider).requireValue;

  void dispose() {
    _timer?.cancel();
    current.dispose();
    version.dispose();
  }

  /// Called once from the home page.
  void start() {
    if (_timer != null || !Platform.isAndroid) return;
    _timer = Timer.periodic(_tick, (_) => unawaited(_check()));
    Future<void>.delayed(const Duration(seconds: 4), _check);
  }

  Map<String, dynamic> _memory() {
    try {
      final m = jsonDecode(_prefs.getString(NetMemPrefs.memory) ?? '{}');
      return m is Map<String, dynamic> ? m : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  int get count => _memory().length;

  Future<void> clear() async {
    await _prefs.remove(NetMemPrefs.memory);
    version.value++;
  }

  /// A hidden tunnel profile (Shield, Google Relay, DNS tunnel) is in use: nothing is learnt from it
  /// and nothing is suggested over it (their own stop brings the previous profile back).
  bool get _hiddenActive =>
      _ref.read(shieldActiveProvider) || _ref.read(relayActiveProvider) || _ref.read(dnsTunnelActiveProvider);

  Future<void> _check() async {
    if (_busy) return;
    _busy = true;
    try {
      if (!_ref.read(NetMemPrefs.enabled)) {
        _lastKey = null;
        _connectedTicks = 0;
        return;
      }
      final net = await RamanNetwork.read();
      if (net == null) return;
      current.value = net;
      final changed = net.key != _lastKey;
      if (changed) _connectedTicks = 0;
      _lastKey = net.key;

      final connected = _ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false;
      final active = _ref.read(activeProfileProvider).valueOrNull;
      if (connected && active != null && !_hiddenActive) {
        _connectedTicks++;
        // connected for about 40 s on this network: this profile works here
        if (_connectedTicks == 2) await _remember(net, active.id, active.name);
      } else {
        _connectedTicks = 0;
      }
      if (changed) await _suggest(net, active?.id);
    } catch (e) {
      loggy.debug('network memory: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _remember(RamanNetwork net, String id, String name) async {
    final m = _memory();
    final old = m[net.key];
    if (old is Map && old['id'] == id) return;
    m[net.key] = {'id': id, 'name': name, 'label': net.label, 'at': DateTime.now().toIso8601String()};
    if (m.length > NetMemPrefs.maxNetworks) {
      final keys = m.keys.toList()..sort((a, b) => '${(m[a] as Map?)?['at']}'.compareTo('${(m[b] as Map?)?['at']}'));
      for (final k in keys.take(m.length - NetMemPrefs.maxNetworks)) {
        m.remove(k);
      }
    }
    await _prefs.setString(NetMemPrefs.memory, jsonEncode(m));
    version.value++;
    loggy.info('network memory: ${net.kind} network -> profile $id');
  }

  Future<void> _suggest(RamanNetwork net, String? activeId) async {
    final e = _memory()[net.key];
    if (e is! Map) return;
    final id = e['id'] as String?;
    if (id == null || id == activeId || _hiddenActive) return;
    final repo = await _ref.read(profileRepositoryProvider.future);
    final p = (await repo.getById(id).run()).getOrElse((_) => null);
    if (p == null) return;
    final s = _ref.read(netWatchStringsProvider);
    _ref
        .read(inAppNotificationControllerProvider)
        .showInfoToast(
          s.seenBefore(p.name, s.networkLabel(net.kind, net.label)),
          action: (
            label: s.use,
            onPressed: () async {
              final again = await repo.getById(id).run();
              if (again.getOrElse((_) => null) != null) await repo.setAsActive(id).run();
            },
          ),
        );
  }
}
