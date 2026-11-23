import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/features/connection/data/connection_data_providers.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_links.dart';
import 'package:hiddify/features/raman/relay/relay_controller.dart';
import 'package:hiddify/features/raman/shield/shield_controller.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "DNS قطعی": a last-resort tunnel for internet shutdowns, carried inside DNS queries through the
/// resolvers that still answer (the operator's, domestic ones). Two open-source engines run on the
/// phone as a local SOCKS5 server (Soar on soar:// links, CottenDNS on cottendns:// links); the VPN
/// is the usual Hiddify core with a hidden local profile of one socks outbound to it, like the
/// Google Relay tab. Very slow; TCP only.
abstract class DnsTunnelPrefs {
  /// Saved configs: JSON list of {link, src: channel|manual, at}.
  static const configs = 'raman-dns-configs';
  static const fetchedAt = 'raman-dns-fetched-at';
  static final selected = PreferencesNotifier.create<String, String>('raman-dns-selected', '');

  /// Use the phone's own resolvers (Wi-Fi router / mobile operator) first.
  static final useSystemDns = PreferencesNotifier.create<bool, bool>('raman-dns-use-system', true);

  /// Also use the resolvers that come in the link.
  static final useLinkResolvers = PreferencesNotifier.create<bool, bool>('raman-dns-use-link', true);

  /// Extra resolvers of the user's, one per line (IP or IP:port).
  static final extraResolvers = PreferencesNotifier.create<String, String>('raman-dns-resolvers', '');

  static const profileId = 'raman-dns-profile-id';
  static const lastProfileId = 'raman-dns-last-profile-id';
  static const savedFakeDns = 'raman-dns-saved-fake-dns';
  static const savedBlockQuic = 'raman-dns-saved-block-quic';

  /// Read by Android (DnsTunnelCore.autoStart).
  static const active = 'raman-dns-active';
  static const run = 'raman-dns-run';

  static const channelUrl = 'https://t.me/s/whitedns';
  static const channelPages = 3;
}

/// A saved config with where it came from.
class SavedDnsConfig {
  const SavedDnsConfig(this.config, this.manual, this.addedAt);

  final DnsTunnelConfig config;
  final bool manual;
  final DateTime? addedAt;

  Map<String, dynamic> toJson() => {
    'link': config.link,
    'src': manual ? 'manual' : 'channel',
    if (addedAt != null) 'at': addedAt!.toIso8601String(),
  };
}

final _v4Port = RegExp(r'^(\d{1,3}(?:\.\d{1,3}){3})(?::(\d{1,5}))?$');
final _v6Port = RegExp(r'^\[([0-9A-Fa-f:.]+)\](?::(\d{1,5}))?$');

bool _validResolver(String e) {
  final m4 = _v4Port.firstMatch(e);
  if (m4 != null) return InternetAddress.tryParse(m4.group(1)!) != null && (int.tryParse(m4.group(2) ?? '53') ?? 0) < 65536;
  final m6 = _v6Port.firstMatch(e);
  if (m6 != null) return InternetAddress.tryParse(m6.group(1)!)?.type == InternetAddressType.IPv6;
  return InternetAddress.tryParse(e)?.type == InternetAddressType.IPv6;
}

/// Resolver entries from free text (one per line, or separated by spaces / commas): IPv4 or
/// IPv6, optionally with a port (1.2.3.4:53, [2001:db8::1]:53).
List<String> dnsResolverList(String text) =>
    text.split(RegExp(r'[\s,;]+')).map((e) => e.trim()).where((e) => e.isNotEmpty && _validResolver(e)).toSet().toList();

/// The Android side (DnsTunnelHandler.kt).
abstract class DnsTunnelPlatform {
  static const _channel = MethodChannel('com.ramanow.ramanvpn/dnstunnel');

  static bool get supported => Platform.isAndroid;

  static const socksPort = 18096;

  /// Which engines are in this build: {soar: bool, cotten: bool}.
  static Future<Map<String, dynamic>> available() async {
    if (!supported) return const {};
    try {
      return await _channel.invokeMapMethod<String, dynamic>('available') ?? const {};
    } catch (_) {
      return const {};
    }
  }

  static Future<List<String>> systemDns() async {
    if (!supported) return const [];
    try {
      return (await _channel.invokeListMethod<String>('systemDns')) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// null when the engine listens, the error otherwise.
  static Future<String?> start(String spec) async {
    if (!supported) return 'android only';
    try {
      return await _channel.invokeMethod<String>('start', {'spec': spec});
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

  static Future<Map<String, dynamic>> status() async {
    if (!supported) return const {};
    try {
      return await _channel.invokeMapMethod<String, dynamic>('status') ?? const {};
    } catch (_) {
      return const {};
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

  /// (ok, ms, error)
  static Future<(bool, int?, String?)> test(String spec) async {
    if (!supported) return (false, null, 'android only');
    try {
      final s = await _channel.invokeMethod<String>('test', {'spec': spec});
      final m = jsonDecode(s ?? '{}') as Map<String, dynamic>;
      return (m['ok'] == true, (m['ms'] as num?)?.toInt(), m['error'] as String?);
    } catch (e) {
      return (false, null, e.toString());
    }
  }

  static Future<void> cancelTest() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<bool>('cancelTest');
    } catch (_) {}
  }
}

/// The id of the hidden profile the DNS tunnel runs as; null when it is not in use.
final dnsTunnelProfileIdProvider = StateProvider<String?>(
  (ref) => ref.read(sharedPreferencesProvider).requireValue.getString(DnsTunnelPrefs.profileId),
);

/// Whether the profile the app runs now is the DNS tunnel's.
final dnsTunnelActiveProvider = Provider<bool>((ref) {
  final id = ref.watch(dnsTunnelProfileIdProvider);
  final active = ref.watch(activeProfileProvider).valueOrNull;
  return id != null && active != null && active.id == id;
});

/// Bumped whenever the saved config list changes.
final dnsTunnelConfigsVersionProvider = StateProvider<int>((ref) => 0);

final dnsTunnelControllerProvider = Provider<DnsTunnelController>((ref) => DnsTunnelController(ref));

class DnsTunnelController with InfraLogger {
  DnsTunnelController(this._ref);

  final Ref _ref;

  SharedPreferences get _prefs => _ref.read(sharedPreferencesProvider).requireValue;

  static const tunnelTag = 'DNS Tunnel';
  static const profileName = 'DNS قطعی';

  static String profileContent() => jsonEncode({
    'outbounds': [
      {
        'type': 'socks',
        'tag': tunnelTag,
        'server': '127.0.0.1',
        'server_port': DnsTunnelPlatform.socksPort,
        'version': '5',
      },
    ],
  });

  // ---- saved configs ----

  List<SavedDnsConfig> configs() {
    final raw = _prefs.getString(DnsTunnelPrefs.configs);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      final out = <SavedDnsConfig>[];
      final seen = <String>{};
      for (final e in list.whereType<Map>()) {
        final c = parseDnsLink(e['link'] as String? ?? '');
        if (c == null || !seen.add(c.key)) continue;
        out.add(SavedDnsConfig(c, e['src'] == 'manual', DateTime.tryParse(e['at'] as String? ?? '')));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(List<SavedDnsConfig> list) async {
    await _prefs.setString(DnsTunnelPrefs.configs, jsonEncode(list.map((e) => e.toJson()).toList()));
    _ref.read(dnsTunnelConfigsVersionProvider.notifier).state++;
  }

  DateTime? get fetchedAt => DateTime.tryParse(_prefs.getString(DnsTunnelPrefs.fetchedAt) ?? '');

  SavedDnsConfig? get selected {
    final key = _ref.read(DnsTunnelPrefs.selected);
    final list = configs();
    if (list.isEmpty) return null;
    return list.where((e) => e.config.key == key).firstOrNull ?? list.first;
  }

  Future<void> select(SavedDnsConfig c) => _ref.read(DnsTunnelPrefs.selected.notifier).update(c.config.key);

  /// Adds the links in [text] as manual configs; returns how many were new.
  Future<int> addFromText(String text) async {
    final found = extractDnsConfigs(text);
    if (found.isEmpty) return 0;
    final list = configs().toList();
    final keys = list.map((e) => e.config.key).toSet();
    var added = 0;
    for (final c in found) {
      if (keys.add(c.key)) {
        list.insert(0, SavedDnsConfig(c, true, DateTime.now()));
        added++;
      }
    }
    if (added > 0) await _save(list);
    return added;
  }

  Future<void> remove(SavedDnsConfig c) async {
    await _save(configs().where((e) => e.config.key != c.config.key).toList());
  }

  /// Reads the channel's public web preview (up to [DnsTunnelPrefs.channelPages] pages) and saves
  /// every soar:// / cottendns:// config in it. The channel configs replace the earlier channel
  /// ones (manual ones stay); nothing is replaced when none were found. Returns (found, error).
  ///
  /// The app is outside its own VPN, so the page is read through the core's local proxy port when
  /// it listens, else directly. With [openLocalProxy] (the button, not the automatic refresh) and a
  /// VPN connection, the local port is opened for a moment as the leak test does (a quick reload).
  Future<(int, String?)> fetchChannel({bool openLocalProxy = false}) async {
    String? lastError;
    final port = _ref.read(ConfigOptions.mixedPort);
    Future<List<DnsTunnelConfig>?> attempt(int? proxyPort) async {
      try {
        return await _readChannel(proxyPort);
      } catch (e) {
        lastError = e.toString();
        return null;
      }
    }

    List<DnsTunnelConfig>? found;
    if (await _portOpen(port)) found = await attempt(port);
    found ??= await attempt(null);
    final connected = _ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false;
    if (found == null &&
        openLocalProxy &&
        connected &&
        _ref.read(ConfigOptions.serviceMode) == ServiceMode.tun &&
        !_ref.read(ConfigOptions.localProxyInVpn) &&
        !_ref.read(ConfigOptions.localProxyAuth)) {
      await _ref.read(ConfigOptions.localProxyInVpn.notifier).update(true);
      try {
        await _reloaded();
        found = await attempt(_ref.read(ConfigOptions.mixedPort));
      } finally {
        await _ref.read(ConfigOptions.localProxyInVpn.notifier).update(false);
        await _reloaded();
      }
    }
    if (found == null) return (0, lastError ?? 'unreachable');
    if (found.isEmpty) return (0, null);
    final now = DateTime.now();
    final manual = configs().where((e) => e.manual).toList();
    final keys = manual.map((e) => e.config.key).toSet();
    final list = [...manual, ...found.where((c) => keys.add(c.key)).map((c) => SavedDnsConfig(c, false, now))];
    await _save(list);
    await _prefs.setString(DnsTunnelPrefs.fetchedAt, now.toIso8601String());
    return (found.length, null);
  }

  Future<List<DnsTunnelConfig>> _readChannel(int? proxyPort) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..userAgent = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36';
    if (proxyPort != null) client.findProxy = (_) => 'PROXY 127.0.0.1:$proxyPort';
    try {
      final all = <String, DnsTunnelConfig>{};
      var url = DnsTunnelPrefs.channelUrl;
      int? before;
      for (var page = 0; page < DnsTunnelPrefs.channelPages; page++) {
        final req = await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 15));
        final res = await req.close().timeout(const Duration(seconds: 20));
        final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 20));
        if (res.statusCode >= 400) throw HttpException('HTTP ${res.statusCode}');
        if (page == 0 && !body.contains('tgme_')) throw const HttpException('not a Telegram page');
        for (final c in extractDnsConfigs(body)) {
          all.putIfAbsent(c.key, () => c);
        }
        final next = telegramBefore(body);
        if (next == null || (before != null && next >= before)) break;
        before = next;
        url = '${DnsTunnelPrefs.channelUrl}?before=$next';
      }
      return all.values.toList();
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _portOpen(int port) async {
    try {
      final s = await Socket.connect('127.0.0.1', port, timeout: const Duration(milliseconds: 300));
      s.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Same as the leak test: makes sure the core runs with the settings just written and waits
  /// until it is connected again (at most 25 s).
  Future<void> _reloaded() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final running = _ref.read(connectionRepositoryProvider).configOptionsSnapshot;
    final wanted = _ref.read(ConfigOptions.singboxConfigOptions);
    if (running != wanted && _ref.read(connectionNotifierProvider).valueOrNull?.isRunning == true) {
      final profile = await _ref.read(activeProfileProvider.future);
      await _ref.read(connectionNotifierProvider.notifier).reconnect(profile);
    }
    final deadline = DateTime.now().add(const Duration(seconds: 25));
    await Future<void>.delayed(const Duration(milliseconds: 800));
    while (DateTime.now().isBefore(deadline)) {
      if (_ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false) break;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }

  // ---- run ----

  /// The run spec Android starts the engine with.
  String specFor(DnsTunnelConfig c) {
    final resolvers = <String>{
      ...dnsResolverList(_ref.read(DnsTunnelPrefs.extraResolvers)),
      if (_ref.read(DnsTunnelPrefs.useLinkResolvers)) ...c.resolvers,
    }.toList();
    return jsonEncode({
      'engine': c.engine.name,
      'profile': c.profile,
      'resolvers': resolvers,
      'useSystemDns': _ref.read(DnsTunnelPrefs.useSystemDns),
    });
  }

  /// What is missing before a start or a test: 'config', 'resolvers', or null.
  String? missing(DnsTunnelConfig? c) {
    if (c == null) return 'config';
    final useSystem = _ref.read(DnsTunnelPrefs.useSystemDns);
    final own = dnsResolverList(_ref.read(DnsTunnelPrefs.extraResolvers));
    final link = _ref.read(DnsTunnelPrefs.useLinkResolvers) ? c.resolvers : const <String>[];
    if (!useSystem && own.isEmpty && link.isEmpty) return 'resolvers';
    return null;
  }

  bool get inUse => _prefs.getBool(DnsTunnelPrefs.active) ?? false;

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

  /// A short real connection with [c] (on a separate local port): (ok, ms, error).
  Future<(bool, int?, String?)> test(DnsTunnelConfig c) async {
    final miss = missing(c);
    if (miss != null) return (false, null, miss);
    return DnsTunnelPlatform.test(specFor(c));
  }

  /// Starts the engine with the selected config, makes the tunnel's profile the active one and
  /// connects. Another running connection must be stopped first (the caller asks the user).
  /// Returns an error code or null.
  Future<String?> start() async {
    if (_ref.read(shieldActiveProvider)) return 'shield';
    if (_ref.read(relayControllerProvider).inUse) return 'relay';
    final c = selected?.config;
    final miss = missing(c);
    if (miss != null) return miss;
    final spec = specFor(c!);
    final err = await DnsTunnelPlatform.start(spec);
    if (err != null) {
      loggy.warning('dns tunnel did not start: $err');
      return 'start:$err';
    }
    await _prefs.setString(DnsTunnelPrefs.run, spec);
    await _prefs.setBool(DnsTunnelPrefs.active, true);

    // FakeIP on (the engine gets host names; it has no UDP for DNS), QUIC blocked; parked
    if (!_prefs.containsKey(DnsTunnelPrefs.savedFakeDns)) {
      await _prefs.setBool(DnsTunnelPrefs.savedFakeDns, _ref.read(ConfigOptions.enableFakeDns));
    }
    if (!_prefs.containsKey(DnsTunnelPrefs.savedBlockQuic)) {
      await _prefs.setBool(DnsTunnelPrefs.savedBlockQuic, _ref.read(ConfigOptions.blockQuic));
    }
    await _ref.read(ConfigOptions.enableFakeDns.notifier).update(true);
    await _ref.read(ConfigOptions.blockQuic.notifier).update(true);

    final repo = await _ref.read(profileRepositoryProvider.future);
    final active = await _ref.read(activeProfileProvider.future);
    var id = _ref.read(dnsTunnelProfileIdProvider);
    if (active != null && active.id != id) await _prefs.setString(DnsTunnelPrefs.lastProfileId, active.id);

    ProfileEntity? existing;
    if (id != null) existing = (await repo.getById(id).run()).getOrElse((_) => null);
    if (existing != null) {
      final activated = await repo.setAsActive(existing.id).run();
      if (activated.isLeft()) return 'profile:$activated';
    } else {
      final added = await repo
          .addLocal(profileContent(), userOverride: const UserOverride(name: profileName, isAutoUpdateDisable: true))
          .run();
      final failure = added.getLeft().toNullable();
      if (failure != null) {
        loggy.warning('could not add the dns tunnel profile', failure);
        return 'profile:$failure';
      }
      id = added.getOrElse((_) => '');
      await _prefs.setString(DnsTunnelPrefs.profileId, id);
      _ref.read(dnsTunnelProfileIdProvider.notifier).state = id;
    }

    for (var i = 0; i < 30; i++) {
      final now = _ref.read(activeProfileProvider).valueOrNull;
      if (now != null && now.id == id) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!isBusy) await _ref.read(connectionNotifierProvider.notifier).toggleConnection();
    return null;
  }

  /// Raman VPN 1.8.1: the hidden profile left active while the DNS tunnel is off (a stop cut short, say by
  /// the app being closed in the middle) showed in the home selector as the profile in use. With
  /// nothing connected and the DNS tunnel not in use, this finishes that stop: the previous profile comes
  /// back and the hidden one goes. Rechecked after a moment so it never runs beside a start or stop.
  Future<void> healStale() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (inUse || isBusy || _ref.read(shieldActiveProvider) || !_ref.read(dnsTunnelActiveProvider)) return;
    loggy.info('the DNS tunnel profile is active while the DNS tunnel is off: restoring the previous profile');
    await stop();
  }

  /// Stops the connection and the engine, gives the app back the profile used before, removes the
  /// tunnel's profile and brings back the parked FakeIP / QUIC settings.
  Future<String?> stop() async {
    if (_ref.read(shieldActiveProvider)) return 'shield';
    final tunnelId = _ref.read(dnsTunnelProfileIdProvider);
    final tunnelActive = _ref.read(dnsTunnelActiveProvider);
    if (tunnelActive && isBusy) {
      await _ref.read(connectionNotifierProvider.notifier).abortConnection();
      await _waitStopped();
    }
    await DnsTunnelPlatform.stop();
    await _prefs.setBool(DnsTunnelPrefs.active, false);

    if (tunnelId != null) {
      final repo = await _ref.read(profileRepositoryProvider.future);
      var restored = !tunnelActive;
      final lastId = _prefs.getString(DnsTunnelPrefs.lastProfileId);
      if (tunnelActive && lastId != null && lastId != tunnelId) {
        final last = (await repo.getById(lastId).run()).getOrElse((_) => null);
        if (last != null) restored = (await repo.setAsActive(lastId).run()).isRight();
      }
      final deleted = await repo.deleteById(tunnelId, !restored).run();
      if (deleted.isLeft()) loggy.warning('could not remove the dns tunnel profile: $deleted');
      await _prefs.remove(DnsTunnelPrefs.profileId);
      _ref.read(dnsTunnelProfileIdProvider.notifier).state = null;
    }

    final fake = _prefs.getBool(DnsTunnelPrefs.savedFakeDns);
    if (fake != null) {
      await _ref.read(ConfigOptions.enableFakeDns.notifier).update(fake);
      await _prefs.remove(DnsTunnelPrefs.savedFakeDns);
    }
    final quic = _prefs.getBool(DnsTunnelPrefs.savedBlockQuic);
    if (quic != null) {
      await _ref.read(ConfigOptions.blockQuic.notifier).update(quic);
      await _prefs.remove(DnsTunnelPrefs.savedBlockQuic);
    }
    return null;
  }
}
