import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/raman/shield/shield_controller.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Relay (رله گوگل): mhrv-rs (MIT; a Rust port of masterking32's MasterHttpRelayVPN) runs in
/// the app on 127.0.0.1 and sends web traffic through the user's own Google Apps Script
/// deployment, reached with domain fronting (TLS name www.google.com on a Google IP). The VPN is
/// the usual Hiddify core: a hidden local profile with one socks outbound to the relay.
///
/// Off unless the user starts it in its tab. While it runs, FakeIP is on (apps get fake addresses
/// and the core hands the relay host names, as the relay needs them) and QUIC is blocked (the
/// relay carries TCP only, so browsers fall back to TCP at once); both come back when it stops.
abstract class RelayPrefs {
  /// Deployment IDs or /exec URLs, one per line.
  static final deployments = PreferencesNotifier.create<String, String>('raman-relay-deployments', '');
  static final authKey = PreferencesNotifier.create<String, String>('raman-relay-auth-key', '');

  /// Empty = the upstream defaults (defaultGoogleIp, defaultFront).
  static final googleIp = PreferencesNotifier.create<String, String>('raman-relay-google-ip', '');
  static final frontDomain = PreferencesNotifier.create<String, String>('raman-relay-front-domain', '');

  static const profileId = 'raman-relay-profile-id';
  static const lastProfileId = 'raman-relay-last-profile-id';
  static const savedFakeDns = 'raman-relay-saved-fake-dns';
  static const savedBlockQuic = 'raman-relay-saved-block-quic';

  /// Read by Android (RelayCore.autoStart): the relay is in use, and the config it runs with.
  static const active = 'raman-relay-active';
  static const config = 'raman-relay-config';

  static const defaultGoogleIp = '216.239.38.120';
  static const defaultFront = 'www.google.com';

  /// Apps Script's UrlFetchApp quota on a free Google account (calls per day).
  static const dailyQuota = 20000;
}

/// A Deployment ID from what the user pasted: the ID itself or the web app URL.
String? relayDeploymentId(String item) {
  final s = item.trim();
  if (s.isEmpty) return null;
  final m = RegExp('/macros/s/([A-Za-z0-9_-]+)').firstMatch(s);
  final id = m?.group(1) ?? s;
  if (!RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(id)) return null;
  return id;
}

List<String> relayDeploymentIds(String value) =>
    value.split(RegExp(r'[\s,;]+')).map(relayDeploymentId).whereType<String>().toSet().toList();

/// A random AUTH_KEY: 32 letters and digits.
String relayRandomKey() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
  final r = Random.secure();
  return List.generate(32, (_) => chars[r.nextInt(chars.length)]).join();
}

final _ipv4 = RegExp(r'^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$');

bool relayValidIp(String v) => _ipv4.hasMatch(v.trim());

/// The relay's Android side (RelayHandler.kt).
abstract class RelayPlatform {
  static const _channel = MethodChannel('com.ramanow.ramanvpn/relay');

  static bool get supported => Platform.isAndroid;

  static const socksPort = 18086;

  /// null when the native relay loads, the reason otherwise.
  static Future<String?> unavailableReason() async {
    if (!supported) return 'android only';
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>('available');
      if (r?['ok'] == true) return null;
      return (r?['error'] as String?) ?? 'unavailable';
    } catch (e) {
      return e.toString();
    }
  }

  /// null when the relay listens, the error otherwise.
  static Future<String?> start(String config) async {
    try {
      return await _channel.invokeMethod<String>('start', {'config': config});
    } catch (e) {
      return e.toString();
    }
  }

  static Future<void> stop() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (_) {}
  }

  static Future<bool> running() async {
    if (!supported) return false;
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>('status');
      return r?['running'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> stats() async {
    if (!supported) return null;
    try {
      final s = await _channel.invokeMethod<String>('stats');
      if (s == null || s.isEmpty) return null;
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<List<String>> logs() async {
    if (!supported) return const [];
    try {
      return (await _channel.invokeListMethod<String>('logs')) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// (ok, latency ms, error)
  static Future<(bool, int?, String?)> testSni(String ip, String sni) async {
    try {
      final s = await _channel.invokeMethod<String>('testSni', {'ip': ip, 'sni': sni});
      final m = jsonDecode(s ?? '{}') as Map<String, dynamic>;
      return (m['ok'] == true, (m['latencyMs'] as num?)?.toInt(), m['error'] as String?);
    } catch (e) {
      return (false, null, e.toString());
    }
  }

  /// Exports the CA (saved to Downloads): {path, fingerprint, installed}.
  static Future<Map<String, dynamic>?> exportCa() async {
    try {
      return await _channel.invokeMapMethod<String, dynamic>('caExport');
    } catch (_) {
      return null;
    }
  }

  /// "installer" (the system dialog opened), "settings" (Settings opened) or null.
  static Future<String?> installCa() async {
    try {
      return await _channel.invokeMethod<String>('caInstall');
    } catch (_) {
      return null;
    }
  }

  static Future<bool> caInstalled() async {
    try {
      return await _channel.invokeMethod<bool>('caInstalled') ?? false;
    } catch (_) {
      return false;
    }
  }
}

/// The id of the hidden profile the relay runs as; null when the relay is not in use.
final relayProfileIdProvider = StateProvider<String?>(
  (ref) => ref.read(sharedPreferencesProvider).requireValue.getString(RelayPrefs.profileId),
);

/// Whether the profile the app runs now is the relay's.
final relayActiveProvider = Provider<bool>((ref) {
  final id = ref.watch(relayProfileIdProvider);
  final active = ref.watch(activeProfileProvider).valueOrNull;
  return id != null && active != null && active.id == id;
});

final relayControllerProvider = Provider<RelayController>((ref) => RelayController(ref));

class RelayController with InfraLogger {
  RelayController(this._ref);

  final Ref _ref;

  SharedPreferences get _prefs => _ref.read(sharedPreferencesProvider).requireValue;

  static const relayTag = 'Google Relay';
  static const profileName = 'رله گوگل';

  /// The profile: one socks outbound to the relay on this device.
  static String profileContent() => jsonEncode({
        'outbounds': [
          {
            'type': 'socks',
            'tag': relayTag,
            'server': '127.0.0.1',
            'server_port': RelayPlatform.socksPort,
            'version': '5',
          },
        ],
      });

  /// The mhrv-rs config (apps_script mode, listening on this device only).
  static String configFor({
    required List<String> ids,
    required String authKey,
    required String googleIp,
    required String front,
  }) => jsonEncode({
        'mode': 'apps_script',
        'script_ids': ids,
        'auth_key': authKey,
        'google_ip': googleIp,
        'front_domain': front,
        'listen_host': '127.0.0.1',
        'listen_port': 18085,
        'socks5_port': RelayPlatform.socksPort,
        'log_level': 'info',
        'verify_ssl': true,
      });

  String get googleIp {
    final v = _ref.read(RelayPrefs.googleIp).trim();
    return v.isEmpty ? RelayPrefs.defaultGoogleIp : v;
  }

  String get front {
    final v = _ref.read(RelayPrefs.frontDomain).trim();
    return v.isEmpty ? RelayPrefs.defaultFront : v;
  }

  /// What is missing before the relay can start: 'ids', 'key', 'ip', or null.
  String? missing() {
    if (relayDeploymentIds(_ref.read(RelayPrefs.deployments)).isEmpty) return 'ids';
    final key = _ref.read(RelayPrefs.authKey).trim();
    if (key.isEmpty || key == 'CHANGE_ME_TO_A_STRONG_SECRET') return 'key';
    if (!relayValidIp(googleIp)) return 'ip';
    return null;
  }

  String buildConfig() => configFor(
        ids: relayDeploymentIds(_ref.read(RelayPrefs.deployments)),
        authKey: _ref.read(RelayPrefs.authKey).trim(),
        googleIp: googleIp.trim(),
        front: front.trim(),
      );

  bool get inUse => _prefs.getBool(RelayPrefs.active) ?? false;

  bool get isBusy {
    final status = _ref.read(connectionNotifierProvider).valueOrNull;
    return status != null && !status.isDisconnected;
  }

  Future<void> _waitStopped() async {
    for (var i = 0; i < 50; i++) {
      final status = _ref.read(connectionNotifierProvider).valueOrNull;
      if (status == null || status.isDisconnected) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Starts the relay, makes its profile the active one and connects. Another running connection
  /// must be stopped first (the caller asks the user). Returns an error code or null.
  Future<String?> start() async {
    if (_ref.read(shieldActiveProvider)) return 'shield';
    final miss = missing();
    if (miss != null) return miss;
    final config = buildConfig();
    final err = await RelayPlatform.start(config);
    if (err != null) {
      loggy.warning('relay did not start: $err');
      return 'start:$err';
    }
    await _prefs.setString(RelayPrefs.config, config);
    await _prefs.setBool(RelayPrefs.active, true);

    // FakeIP on (the relay needs host names), QUIC blocked; the user's values are parked
    if (!_prefs.containsKey(RelayPrefs.savedFakeDns)) {
      await _prefs.setBool(RelayPrefs.savedFakeDns, _ref.read(ConfigOptions.enableFakeDns));
    }
    if (!_prefs.containsKey(RelayPrefs.savedBlockQuic)) {
      await _prefs.setBool(RelayPrefs.savedBlockQuic, _ref.read(ConfigOptions.blockQuic));
    }
    await _ref.read(ConfigOptions.enableFakeDns.notifier).update(true);
    await _ref.read(ConfigOptions.blockQuic.notifier).update(true);

    final repo = await _ref.read(profileRepositoryProvider.future);
    final content = profileContent();
    final active = await _ref.read(activeProfileProvider.future);
    var id = _ref.read(relayProfileIdProvider);
    if (active != null && active.id != id) await _prefs.setString(RelayPrefs.lastProfileId, active.id);

    ProfileEntity? existing;
    if (id != null) existing = (await repo.getById(id).run()).getOrElse((_) => null);
    if (existing != null) {
      final activated = await repo.setAsActive(existing.id).run();
      if (activated.isLeft()) return 'profile:$activated';
    } else {
      final added = await repo
          .addLocal(content, userOverride: const UserOverride(name: profileName, isAutoUpdateDisable: true))
          .run();
      final failure = added.getLeft().toNullable();
      if (failure != null) {
        loggy.warning('could not add the relay profile', failure);
        return 'profile:$failure';
      }
      id = added.getOrElse((_) => '');
      await _prefs.setString(RelayPrefs.profileId, id);
      _ref.read(relayProfileIdProvider.notifier).state = id;
    }

    for (var i = 0; i < 30; i++) {
      final now = _ref.read(activeProfileProvider).valueOrNull;
      if (now != null && now.id == id) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!isBusy) await _ref.read(connectionNotifierProvider.notifier).toggleConnection();
    return null;
  }

  /// Stops the connection and the relay, gives the app back the profile used before, removes the
  /// relay profile and brings back the parked FakeIP / QUIC settings.
  Future<String?> stop() async {
    if (_ref.read(shieldActiveProvider)) return 'shield';
    final relayId = _ref.read(relayProfileIdProvider);
    final relayActive = _ref.read(relayActiveProvider);
    if (relayActive && isBusy) {
      await _ref.read(connectionNotifierProvider.notifier).abortConnection();
      await _waitStopped();
    }
    await RelayPlatform.stop();
    await _prefs.setBool(RelayPrefs.active, false);

    if (relayId != null) {
      final repo = await _ref.read(profileRepositoryProvider.future);
      var restored = !relayActive;
      final lastId = _prefs.getString(RelayPrefs.lastProfileId);
      if (relayActive && lastId != null && lastId != relayId) {
        final last = (await repo.getById(lastId).run()).getOrElse((_) => null);
        if (last != null) restored = (await repo.setAsActive(lastId).run()).isRight();
      }
      final deleted = await repo.deleteById(relayId, !restored).run();
      if (deleted.isLeft()) loggy.warning('could not remove the relay profile: $deleted');
      await _prefs.remove(RelayPrefs.profileId);
      _ref.read(relayProfileIdProvider.notifier).state = null;
    }

    final fake = _prefs.getBool(RelayPrefs.savedFakeDns);
    if (fake != null) {
      await _ref.read(ConfigOptions.enableFakeDns.notifier).update(fake);
      await _prefs.remove(RelayPrefs.savedFakeDns);
    }
    final quic = _prefs.getBool(RelayPrefs.savedBlockQuic);
    if (quic != null) {
      await _ref.read(ConfigOptions.blockQuic.notifier).update(quic);
      await _prefs.remove(RelayPrefs.savedBlockQuic);
    }
    return null;
  }

  /// Applies new settings to a running relay: restarts it with the new config.
  Future<String?> restartIfRunning() async {
    if (!inUse) return null;
    final miss = missing();
    if (miss != null) return miss;
    final config = buildConfig();
    final err = await RelayPlatform.start(config);
    if (err != null) return 'start:$err';
    await _prefs.setString(RelayPrefs.config, config);
    return null;
  }

  /// The Apps Script code (assets/raman/relay/Code.gs, from mhrv-rs) with the AUTH_KEY set.
  static Future<String> codeGs(String authKey) async {
    final code = await rootBundle.loadString('assets/raman/relay/Code.gs');
    final key = authKey.trim();
    if (key.isEmpty) return code;
    final escaped = key.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return code.replaceFirst(
      'const AUTH_KEY = "CHANGE_ME_TO_A_STRONG_SECRET";',
      'const AUTH_KEY = "$escaped";',
    );
  }
}
