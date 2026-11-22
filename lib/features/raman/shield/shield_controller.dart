import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How Shield (the Psiphon network) is used with the Raman profiles: not at all, in front of them
/// as extra security, or behind them as an unblocker that carries their traffic out.
enum ShieldChainUse { off, extraSecurity, unblocker }

abstract class ShieldPrefs {
  static const profileId = 'raman-shield-profile-id';
  static const lastRamanProfileId = 'raman-last-profile-id';
  static const savedChainStatus = 'raman-shield-saved-chain-status';

  /// The exit country of Shield.
  static final region = PreferencesNotifier.create<PsiphonRegion, String>(
    'raman-shield-region',
    PsiphonRegion.auto,
    mapFrom: PsiphonRegion.values.byName,
    mapTo: (value) => value.name,
  );

  /// Set while Shield is the connection in use; the Android VPN service then takes Shield's own
  /// split tunnel (android Settings.kt).
  static const active = 'raman-shield-active';

  // split tunneling (Shield's own; the Raman profiles keep app-based routing)
  static final splitMode = PreferencesNotifier.create<ShieldSplitMode, String>(
    'raman-shield-split-mode',
    ShieldSplitMode.all,
    mapFrom: ShieldSplitMode.values.byName,
    mapTo: (value) => value.name,
  );

  /// Package names joined by ';' (read as is by the VPN service).
  static final includeApps = PreferencesNotifier.create<String, String>('raman-shield-include-apps', '');
  static final excludeApps = PreferencesNotifier.create<String, String>('raman-shield-exclude-apps', '');

  // upstream proxy: Psiphon's own connections go through it (core field upstream_proxy_url)
  static final upstreamEnabled = PreferencesNotifier.create<bool, bool>('raman-shield-upstream-enabled', false);
  static final upstreamSource = PreferencesNotifier.create<ShieldUpstreamSource, String>(
    'raman-shield-upstream-source',
    ShieldUpstreamSource.system,
    mapFrom: ShieldUpstreamSource.values.byName,
    mapTo: (value) => value.name,
  );
  static final upstreamType = PreferencesNotifier.create<ShieldUpstreamType, String>(
    'raman-shield-upstream-type',
    ShieldUpstreamType.http,
    mapFrom: ShieldUpstreamType.values.byName,
    mapTo: (value) => value.name,
  );
  static final upstreamHost = PreferencesNotifier.create<String, String>('raman-shield-upstream-host', '');
  static final upstreamPort = PreferencesNotifier.create<String, String>('raman-shield-upstream-port', '');
  static final upstreamAuth = PreferencesNotifier.create<bool, bool>('raman-shield-upstream-auth', false);
  static final upstreamUser = PreferencesNotifier.create<String, String>('raman-shield-upstream-user', '');
  static final upstreamPass = PreferencesNotifier.create<String, String>('raman-shield-upstream-pass', '');
  static final upstreamDomain = PreferencesNotifier.create<String, String>('raman-shield-upstream-domain', '');

  /// Slow networks: the tunnel core keeps trying for 30 minutes (core field establish_tunnel_timeout).
  static final disableTimeouts = PreferencesNotifier.create<bool, bool>('raman-shield-disable-timeouts', false);

  // notifications
  static final notifySound = PreferencesNotifier.create<bool, bool>('raman-shield-notify-sound', false);
  static final notifyVibrate = PreferencesNotifier.create<bool, bool>('raman-shield-notify-vibrate', false);

  /// The VPN notification shows the disguise app (read by the Android notification).
  static final stealthNotifications = PreferencesNotifier.create<bool, bool>('raman-stealth-notifications', false);

  // a website opened when Shield connects
  static final openSite = PreferencesNotifier.create<bool, bool>('raman-shield-open-site', false);
  static final openSiteUrl = PreferencesNotifier.create<String, String>('raman-shield-open-site-url', '');

  static const establishTimeoutSlow = '30m';

  // CDN fronting and search (core 5.9.15 psiphon outbound field `scanner`)
  /// auto: every protocol and the CDN edge scan (core default as the first hop); direct: no scan,
  /// the tunnel core's TCP protocols only (scanner.enabled = false).
  static final protocolMode = PreferencesNotifier.create<ShieldProtocolMode, String>(
    'raman-shield-protocol-mode',
    ShieldProtocolMode.auto,
    mapFrom: ShieldProtocolMode.values.byName,
    mapTo: (value) => value.name,
  );

  /// Beast mode: a deep search from the start (scanner.search_timeout < 0: no time limit, more
  /// probes at once, the tunnel core's aggressive establishment).
  static final beast = PreferencesNotifier.create<bool, bool>('raman-shield-beast', false);

  /// The built-in CDN sets scanned and fronted through, ';'-joined; empty = all (scanner.sets).
  static final cdnSets = PreferencesNotifier.create<String, String>('raman-shield-cdn-sets', '');

  /// The user's own CDN edges, IPv4 addresses or CIDRs, one per line or comma-separated (scanner.cidrs).
  static final cdnIps = PreferencesNotifier.create<String, String>('raman-shield-cdn-ips', '');

  /// TLS server names sent to the user's own edges (scanner.server_names; only with cdnIps).
  static final cdnSni = PreferencesNotifier.create<String, String>('raman-shield-cdn-sni', '');

  /// The CDN sets built into core 5.9.15 (hiddify-sing-box protocol/psiphon/h_cdn_edges.go).
  static const builtInCdnSets = [
    'cloudflare',
    'fastly',
    'cloudfront',
    'psiphon-akamai',
    'psiphon-bunny',
    'vercel',
    'github',
    'google',
    'curated-fronting',
    'legacy-android-overrides',
  ];

  /// The CDN networks suggested for Iran: every built-in set but Cloudflare's, which was
  /// throttled from Iran from October 2026 (uploads under 0.1 Mbps, per Filterwatch / MahsaNet).
  static final iranCdnSets = builtInCdnSets.where((e) => e != 'cloudflare').toList();
}

enum ShieldProtocolMode { auto, direct }

/// Items of a list setting: split on new lines, commas, semicolons and spaces.
List<String> shieldListItems(String value) =>
    value.split(RegExp(r'[\s,;]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

final _ipv4 = RegExp(r'^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$');

/// An IPv4 address or CIDR as a prefix for the core ("1.2.3.4" -> "1.2.3.4/32"), or null.
String? shieldCidr(String item) {
  final parts = item.split('/');
  if (parts.length > 2 || !_ipv4.hasMatch(parts[0])) return null;
  if (parts.length == 1) return '${parts[0]}/32';
  final bits = int.tryParse(parts[1]);
  if (bits == null || bits < 0 || bits > 32) return null;
  return '${parts[0]}/$bits';
}

final _hostname = RegExp(r'^(?=.{1,253}$)([a-zA-Z0-9_]([a-zA-Z0-9_-]{0,61}[a-zA-Z0-9])?)(\.[a-zA-Z0-9_]([a-zA-Z0-9_-]{0,61}[a-zA-Z0-9])?)*$');

bool shieldValidHostname(String item) => _hostname.hasMatch(item);

/// Which apps go through Shield: all, only the listed ones, or all but the listed ones.
enum ShieldSplitMode { all, include, exclude }

enum ShieldUpstreamSource { system, custom }

enum ShieldUpstreamType { http, socks5 }

/// Shield's Android pieces (ShieldHandler.kt).
abstract class ShieldPlatform {
  static const _channel = MethodChannel('com.ramanow.ramanvpn/shield');

  static bool get supported => Platform.isAndroid;

  /// The system's HTTP proxy, if one is set for the current network.
  static Future<(String, int)?> systemProxy() async {
    if (!supported) return null;
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>('systemProxy');
      if (r == null) return null;
      final host = r['host'] as String?;
      final port = r['port'] as int?;
      if (host == null || host.isEmpty || port == null) return null;
      return (host, port);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> openVpnSettings() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('openVpnSettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> statusFeedback({required bool sound, required bool vibrate}) async {
    if (!supported || (!sound && !vibrate)) return;
    try {
      await _channel.invokeMethod<bool>('statusFeedback', {'sound': sound, 'vibrate': vibrate});
    } catch (_) {}
  }
}

/// The id of the hidden profile Shield runs as, while Shield is in use; null otherwise.
final shieldProfileIdProvider = StateProvider<String?>(
  (ref) => ref.read(sharedPreferencesProvider).requireValue.getString(ShieldPrefs.profileId),
);

/// Whether the profile the app runs now is Shield's.
final shieldActiveProvider = Provider<bool>((ref) {
  final shieldId = ref.watch(shieldProfileIdProvider);
  final active = ref.watch(activeProfileProvider).valueOrNull;
  return shieldId != null && active != null && active.id == shieldId;
});

/// Shield's chain use as the Raman profiles will see it: while Shield runs the chain is parked
/// (saved) and comes back when the Raman tab is used again.
final shieldChainUseProvider = Provider<ShieldChainUse>((ref) {
  final shieldActive = ref.watch(shieldActiveProvider);
  final ChainStatus status;
  if (shieldActive) {
    final saved = ref.read(sharedPreferencesProvider).requireValue.getString(ShieldPrefs.savedChainStatus);
    status = ChainStatus.values.asNameMap()[saved] ?? ref.watch(ConfigOptions.chainStatus);
  } else {
    status = ref.watch(ConfigOptions.chainStatus);
  }
  return switch (status) {
    ChainStatus.extraSecurity when ref.watch(ConfigOptions.extraSecurityMode) == ChainMode.psiphon =>
      ShieldChainUse.extraSecurity,
    ChainStatus.unblocker when ref.watch(ConfigOptions.unblockerMode) == ChainMode.psiphon => ShieldChainUse.unblocker,
    _ => ShieldChainUse.off,
  };
});

final shieldControllerProvider = Provider<ShieldController>((ref) => ShieldController(ref));

/// Runs Shield: a profile holding one Psiphon outbound (the core's built-in Psiphon support),
/// made when Shield connects and removed when the Raman tab is used again, so it never shows in
/// the profile list for long and never mixes with the user's own profiles.
class ShieldController with InfraLogger {
  ShieldController(this._ref);

  final Ref _ref;

  SharedPreferences get _prefs => _ref.read(sharedPreferencesProvider).requireValue;

  static const shieldTag = 'Raman Shield';

  /// The profile Shield runs as: one Psiphon outbound of the core, with the exit country, the
  /// upstream proxy and the tunnel timeout from Shield's settings.
  static String contentFor(
    PsiphonRegion region, {
    String? upstreamProxyUrl,
    bool disableTimeouts = false,
    Map<String, dynamic>? scanner,
  }) => jsonEncode({
        'outbounds': [
          {
            'type': 'psiphon',
            'tag': shieldTag,
            // the Psiphon config built into the core
            'config': 'hiddify',
            if (region != PsiphonRegion.auto) 'egress_region': region.key,
            if (upstreamProxyUrl != null && upstreamProxyUrl.isNotEmpty) 'upstream_proxy_url': upstreamProxyUrl,
            if (disableTimeouts) 'establish_tunnel_timeout': ShieldPrefs.establishTimeoutSlow,
            if (scanner != null && scanner.isNotEmpty) 'scanner': scanner,
          },
        ],
      });

  /// The upstream proxy as a URL for the core, or null for none (off, or no system proxy).
  Future<String?> upstreamProxyUrl() async {
    if (!_ref.read(ShieldPrefs.upstreamEnabled)) return null;
    String host;
    int? port;
    if (_ref.read(ShieldPrefs.upstreamSource) == ShieldUpstreamSource.system) {
      final system = await ShieldPlatform.systemProxy();
      if (system == null) return null;
      (host, port) = system;
      return buildProxyUrl(type: ShieldUpstreamType.http, host: host, port: port);
    }
    host = _ref.read(ShieldPrefs.upstreamHost).trim();
    port = int.tryParse(_ref.read(ShieldPrefs.upstreamPort).trim());
    if (host.isEmpty || port == null || port <= 0 || port > 65535) return null;
    final auth = _ref.read(ShieldPrefs.upstreamAuth);
    return buildProxyUrl(
      type: _ref.read(ShieldPrefs.upstreamType),
      host: host,
      port: port,
      user: auth ? _ref.read(ShieldPrefs.upstreamUser) : null,
      pass: auth ? _ref.read(ShieldPrefs.upstreamPass) : null,
      domain: auth ? _ref.read(ShieldPrefs.upstreamDomain) : null,
    );
  }

  /// http://[domain\\]user:pass@host:port (as the Psiphon clients build it) or socks5://….
  static String buildProxyUrl({
    required ShieldUpstreamType type,
    required String host,
    required int port,
    String? user,
    String? pass,
    String? domain,
  }) {
    final scheme = type == ShieldUpstreamType.socks5 ? 'socks5' : 'http';
    final b = StringBuffer('$scheme://');
    if (user != null && user.isNotEmpty) {
      if (type == ShieldUpstreamType.http && domain != null && domain.trim().isNotEmpty) {
        b.write(Uri.encodeComponent('${domain.trim()}\\'));
      }
      b.write(Uri.encodeComponent(user));
      b.write(':');
      b.write(Uri.encodeComponent(pass ?? ''));
      b.write('@');
    }
    final h = host.contains(':') && !host.startsWith('[') ? '[$host]' : host;
    b.write('$h:$port');
    return b.toString();
  }

  /// The psiphon outbound's `scanner` (core 5.9.15): the CDN edge scan and search of Psiphon as
  /// the first hop. The core runs it only without an upstream proxy; null keeps its defaults.
  static Map<String, dynamic>? scannerFor({
    required ShieldProtocolMode mode,
    required bool beast,
    required List<String> sets,
    required List<String> cidrs,
    required List<String> serverNames,
  }) {
    if (mode == ShieldProtocolMode.direct) return {'enabled': false};
    final scanner = <String, dynamic>{
      if (sets.isNotEmpty) 'sets': sets,
      if (cidrs.isNotEmpty) 'cidrs': cidrs,
      if (cidrs.isNotEmpty && serverNames.isNotEmpty) 'server_names': serverNames,
      // below zero: a deep search from the start (aggressive establishment, no time limit)
      if (beast) 'search_timeout': '-1s',
    };
    return scanner.isEmpty ? null : scanner;
  }

  Map<String, dynamic>? buildScanner() => scannerFor(
    mode: _ref.read(ShieldPrefs.protocolMode),
    beast: _ref.read(ShieldPrefs.beast),
    sets: shieldListItems(_ref.read(ShieldPrefs.cdnSets)).where(ShieldPrefs.builtInCdnSets.contains).toList(),
    cidrs: shieldListItems(_ref.read(ShieldPrefs.cdnIps)).map(shieldCidr).whereType<String>().toList(),
    serverNames: shieldListItems(_ref.read(ShieldPrefs.cdnSni)).where(shieldValidHostname).toList(),
  );

  Future<String> buildContent() async => contentFor(
    _ref.read(ShieldPrefs.region),
    upstreamProxyUrl: await upstreamProxyUrl(),
    disableTimeouts: _ref.read(ShieldPrefs.disableTimeouts),
    scanner: buildScanner(),
  );

  bool get isShieldActive => _ref.read(shieldActiveProvider);

  /// True when a connection runs, or is starting, for any profile.
  bool get isBusy {
    final status = _ref.read(connectionNotifierProvider).valueOrNull;
    return status != null && !status.isDisconnected;
  }

  /// Connects Shield. A running Raman connection must be stopped first (the caller asks the user).
  Future<String?> connect() async {
    final repo = await _ref.read(profileRepositoryProvider.future);
    final content = await buildContent();

    final active = await _ref.read(activeProfileProvider.future);
    final shieldId = _ref.read(shieldProfileIdProvider);
    if (active != null && active.id != shieldId) {
      await _prefs.setString(ShieldPrefs.lastRamanProfileId, active.id);
    }

    // The chain is for the Raman profiles; Shield is already Psiphon, and the core runs one
    // Psiphon at a time. Park it until the Raman tab is used again.
    if (!_prefs.containsKey(ShieldPrefs.savedChainStatus)) {
      await _prefs.setString(ShieldPrefs.savedChainStatus, _ref.read(ConfigOptions.chainStatus).name);
    }
    await _ref.read(ConfigOptions.chainStatus.notifier).update(ChainStatus.off);

    String? id = shieldId;
    ProfileEntity? existing;
    if (id != null) {
      existing = (await repo.getById(id).run()).getOrElse((_) => null);
    }
    if (existing != null) {
      final updated = await repo.offlineUpdate(existing, content).run();
      if (updated.isLeft()) loggy.warning('could not update the Shield profile: $updated');
      final activated = await repo.setAsActive(existing.id).run();
      if (activated.isLeft()) return 'activate: $activated';
    } else {
      final added = await repo
          .addLocal(content, userOverride: const UserOverride(name: shieldTag, isAutoUpdateDisable: true))
          .run();
      final failure = added.getLeft().toNullable();
      if (failure != null) {
        loggy.warning('could not add the Shield profile', failure);
        return failure.toString();
      }
      id = added.getOrElse((_) => '');
      await _prefs.setString(ShieldPrefs.profileId, id);
      _ref.read(shieldProfileIdProvider.notifier).state = id;
    }

    // the VPN service takes Shield's own split tunnel from here on
    await _prefs.setBool(ShieldPrefs.active, true);

    // wait for the new active profile to reach the connection notifier
    for (var i = 0; i < 30; i++) {
      final now = _ref.read(activeProfileProvider).valueOrNull;
      if (now != null && now.id == id) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    final status = _ref.read(connectionNotifierProvider).valueOrNull;
    if (status == null || status.isDisconnected) {
      await _ref.read(connectionNotifierProvider.notifier).toggleConnection();
    }
    return null;
  }

  Future<void> disconnect() async {
    await _ref.read(connectionNotifierProvider.notifier).abortConnection();
  }

  /// Gives the app back to the Raman profiles: the one used before Shield becomes active again,
  /// the Shield profile is removed and the parked chain comes back. Shield must be stopped.
  Future<void> restoreRaman() async {
    final shieldId = _ref.read(shieldProfileIdProvider);
    if (shieldId != null) {
      final repo = await _ref.read(profileRepositoryProvider.future);
      final lastId = _prefs.getString(ShieldPrefs.lastRamanProfileId);
      var restored = false;
      if (lastId != null && lastId != shieldId) {
        final last = (await repo.getById(lastId).run()).getOrElse((_) => null);
        if (last != null) restored = (await repo.setAsActive(lastId).run()).isRight();
      }
      final deleted = await repo.deleteById(shieldId, !restored).run();
      if (deleted.isLeft()) loggy.warning('could not remove the Shield profile: $deleted');
      await _prefs.remove(ShieldPrefs.profileId);
      _ref.read(shieldProfileIdProvider.notifier).state = null;
    }
    await _prefs.setBool(ShieldPrefs.active, false);
    final saved = _prefs.getString(ShieldPrefs.savedChainStatus);
    if (saved != null) {
      final status = ChainStatus.values.asNameMap()[saved];
      if (status != null) await _ref.read(ConfigOptions.chainStatus.notifier).update(status);
      await _prefs.remove(ShieldPrefs.savedChainStatus);
    }
  }

  /// A new exit country: saved, written to the chain hops that use Shield, and applied to a
  /// running Shield by reconnecting.
  Future<void> setRegion(PsiphonRegion region) async {
    await _ref.read(ShieldPrefs.region.notifier).update(region);
    await _ref.read(ConfigOptions.extraSecurityPsiphonRegion.notifier).update(region);
    await _ref.read(ConfigOptions.unblockerPsiphonRegion.notifier).update(region);
    await applySettings();
  }

  /// Writes Shield's settings into its profile and, when Shield runs, reconnects so they take
  /// effect (the split tunnel too: the VPN service reads it on start). True when Shield ran.
  Future<bool> applySettings() async {
    if (!isShieldActive) return false;
    final shieldId = _ref.read(shieldProfileIdProvider);
    if (shieldId == null) return false;
    final repo = await _ref.read(profileRepositoryProvider.future);
    final existing = (await repo.getById(shieldId).run()).getOrElse((_) => null);
    if (existing == null) return false;
    final updated = await repo.offlineUpdate(existing, await buildContent()).run();
    if (updated.isLeft()) {
      loggy.warning('could not update the Shield profile: $updated');
      return false;
    }
    if (!isBusy) return false;
    final fresh = (await repo.getById(shieldId).run()).getOrElse((_) => null);
    await _ref.read(connectionNotifierProvider.notifier).reconnect(fresh ?? existing);
    return true;
  }

  /// Uses Shield with the Raman profiles, as extra security or as an unblocker, or not at all.
  Future<void> setChainUse(ShieldChainUse use) async {
    final region = _ref.read(ShieldPrefs.region);
    final ChainStatus status;
    switch (use) {
      case ShieldChainUse.off:
        status = ChainStatus.off;
      case ShieldChainUse.extraSecurity:
        await _ref.read(ConfigOptions.extraSecurityMode.notifier).update(ChainMode.psiphon);
        await _ref.read(ConfigOptions.extraSecurityPsiphonRegion.notifier).update(region);
        status = ChainStatus.extraSecurity;
      case ShieldChainUse.unblocker:
        await _ref.read(ConfigOptions.unblockerMode.notifier).update(ChainMode.psiphon);
        await _ref.read(ConfigOptions.unblockerPsiphonRegion.notifier).update(region);
        status = ChainStatus.unblocker;
    }
    if (isShieldActive) {
      // parked while Shield runs; applied when the Raman tab is used again
      await _prefs.setString(ShieldPrefs.savedChainStatus, status.name);
      _ref.invalidate(shieldChainUseProvider);
    } else {
      await _ref.read(ConfigOptions.chainStatus.notifier).update(status);
    }
  }
}
