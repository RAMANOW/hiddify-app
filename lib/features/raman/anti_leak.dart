import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/features/raman/iran_defaults.dart';
import 'package:hiddify/features/raman/shield/shield_controller.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Raman VPN 1.6 "anti-leak mode" (حالت ضد نشتی). Off by default: with it off, connecting is
/// exactly as in 1.4.1.
///
/// On, it sets what keeps DNS and traffic inside the tunnel, as far as the official core 5.9.15
/// and Android allow:
/// - remote DNS as DNS over HTTPS to 1.1.1.1, through the proxy (the core's remote group still
///   falls back to 1.1.1.1 over UDP/TCP/TLS and to 8.8.8.8, all through the proxy);
/// - strict route on (the TUN takes every route, DNS to port 53 is hijacked by the core: the core
///   already adds hijack-dns and a ::/0 route on every TUN);
/// - IPv4 only (IPv6 connections are refused at once; the TUN keeps ::/0, so no IPv6 goes around
///   the VPN);
/// - QUIC blocked for proxied traffic (browsers fall back to TLS over TCP);
/// - a profile (subscription) can no longer override the remote DNS, strict route, IPv6 mode or
///   the QUIC block (ConfigOptionRepository.keepAntiLeak); and Smart DNS no longer changes the remote DNS.
///
/// Iranian sites keep going direct, with their names resolved by the direct DNS, while the
/// region is Iran ("bypass Iran"); the user can turn that off for everything through the tunnel.
abstract final class AntiLeak {
  static const key = 'raman-anti-leak';
  static const _kSnapshot = 'raman-anti-leak-snapshot';

  static final enabled = PreferencesNotifier.create<bool, bool>(key, false);

  /// The remote DNS anti-leak mode uses: DNS over HTTPS by IP (no name to look up first).
  static const remoteDns = 'https://1.1.1.1/dns-query';

  /// Turns the mode on, keeping the values it replaces, or off, putting them back. A value the
  /// user changed while the mode was on stays as the user set it.
  static Future<void> set(RamanReader read, bool on) async {
    final prefs = read(sharedPreferencesProvider).requireValue;
    if (on) {
      if (read(enabled)) return;
      final snapshot = {
        'remote-dns': read(ConfigOptions.remoteDnsAddress),
        'strict-route': read(ConfigOptions.strictRoute),
        'ipv6-mode': read(ConfigOptions.ipv6Mode).key,
        'block-quic': read(ConfigOptions.blockQuic),
      };
      await prefs.setString(_kSnapshot, jsonEncode(snapshot));
      await read(ConfigOptions.remoteDnsAddress.notifier).update(remoteDns);
      await read(ConfigOptions.strictRoute.notifier).update(true);
      await read(ConfigOptions.ipv6Mode.notifier).update(IPv6Mode.ipv4Only);
      await read(ConfigOptions.blockQuic.notifier).update(true);
      await read(enabled.notifier).update(true);
      return;
    }
    if (!read(enabled)) return;
    Map<String, dynamic> snapshot = const {};
    try {
      snapshot = (jsonDecode(prefs.getString(_kSnapshot) ?? '{}') as Map).cast<String, dynamic>();
    } catch (_) {}
    await read(enabled.notifier).update(false);
    if (snapshot['remote-dns'] is String && read(ConfigOptions.remoteDnsAddress) == remoteDns) {
      await read(ConfigOptions.remoteDnsAddress.notifier).update(snapshot['remote-dns'] as String);
    }
    if (snapshot['strict-route'] is bool && read(ConfigOptions.strictRoute)) {
      await read(ConfigOptions.strictRoute.notifier).update(snapshot['strict-route'] as bool);
    }
    if (snapshot['ipv6-mode'] is String && read(ConfigOptions.ipv6Mode) == IPv6Mode.ipv4Only) {
      await read(ConfigOptions.ipv6Mode.notifier).update(IPv6Mode.fromKey(snapshot['ipv6-mode'] as String));
    }
    if (snapshot['block-quic'] is bool && read(ConfigOptions.blockQuic)) {
      await read(ConfigOptions.blockQuic.notifier).update(snapshot['block-quic'] as bool);
    }
    await prefs.remove(_kSnapshot);
  }

  /// Whether every setting of the mode is in place (the user may have changed one by hand).
  static bool complete(RamanReader read) =>
      read(ConfigOptions.remoteDnsAddress) != 'local' &&
      read(ConfigOptions.strictRoute) &&
      read(ConfigOptions.ipv6Mode) == IPv6Mode.ipv4Only &&
      read(ConfigOptions.blockQuic);

  /// Whether some apps are left out of the VPN (split tunneling) on the tab in use: their traffic
  /// and DNS do not go through the tunnel.
  static bool splitTunnelOn(RamanReader read) {
    final prefs = read(sharedPreferencesProvider).requireValue;
    if (prefs.getBool(ShieldPrefs.active) ?? false) return read(ShieldPrefs.splitMode) != ShieldSplitMode.all;
    return read(Preferences.perAppProxyEnabled);
  }
}

/// Android's own kill switch, as far as the app can see it: whether this app is the always-on VPN
/// and whether "Block connections without VPN" is on. Known only while the VPN runs, on Android 10
/// and later; null otherwise.
class VpnLockdownStatus {
  const VpnLockdownStatus({required this.alwaysOn, required this.lockdown});

  final bool alwaysOn;
  final bool lockdown;

  static const _channel = MethodChannel('com.ramanow.ramanvpn/shield');

  static Future<VpnLockdownStatus?> read() async {
    if (!Platform.isAndroid) return null;
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>('vpnLockdown');
      if (r == null) return null;
      return VpnLockdownStatus(alwaysOn: r['alwaysOn'] == true, lockdown: r['lockdown'] == true);
    } catch (_) {
      return null;
    }
  }
}

final vpnLockdownProvider = FutureProvider.autoDispose<VpnLockdownStatus?>((ref) => VpnLockdownStatus.read());
