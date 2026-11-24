import 'dart:async';
import 'dart:io';

import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/router/go_router/go_router_notifier.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_tunnel_controller.dart';
import 'package:hiddify/features/raman/netwatch/net_watch_strings.dart';
import 'package:hiddify/features/raman/relay/relay_controller.dart';
import 'package:hiddify/features/raman/shield/shield_controller.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Raman VPN 1.9 "Iran Access" fallback to the DNS tunnel, OPT-IN (off by default).
///
/// A separate watcher, never a wrapper: it does not change the connection code (1.5's quiet
/// auto-retry around connect broke connecting for everyone). It only reads the connection state
/// and, when the switch is on, the phone is connected with a normal profile and the international
/// internet is gone while Iranian sites still open, it starts the DNS tab once, exactly as the
/// user would (stop the connection, then the DNS tab's own start). After that it stays quiet
/// until the user connects again by themselves, and never acts twice within [cooldown].
///
/// "International gone" = [failsNeeded] probes in a row (one every [interval], about 45 s)
/// failed through the tunnel: an HTTP GET of generate_204 through the core's local port when it
/// listens, otherwise the core's own URL test of the selected server (the same test as the ping
/// button, which fetches the connection-test URL through the server). "Iran Access" also needs a
/// direct TLS handshake to an Iranian site to succeed and direct international hosts to fail (if
/// the international internet works without the VPN, the server is the problem, not a shutdown,
/// and the config finder helps more than a DNS tunnel).
abstract class FallbackPrefs {
  static final enabled = PreferencesNotifier.create<bool, bool>('raman-fallback-dns', false);
}

const _domestic = ['www.aparat.com', 'www.digikala.com', 'www.shaparak.ir'];
const _international = [('www.gstatic.com', 443), ('1.1.1.1', 443), ('www.google.com', 443)];

final iranAccessWatcherProvider = Provider<IranAccessWatcher>((ref) {
  final w = IranAccessWatcher(ref);
  ref.onDispose(w.dispose);
  return w;
});

class IranAccessWatcher with InfraLogger {
  IranAccessWatcher(this._ref);

  final Ref _ref;
  Timer? _timer;
  bool _busy = false;
  int _fails = 0;

  /// False after a switch, until the user connects again with a normal profile.
  bool _armed = true;
  DateTime? _firedAt;

  static const interval = Duration(seconds: 15);
  static const failsNeeded = 3;
  static const cooldown = Duration(minutes: 10);

  void dispose() => _timer?.cancel();

  /// Called once from the home page; does nothing while the switch is off.
  void start() {
    if (_timer != null || !Platform.isAndroid) return;
    _timer = Timer.periodic(interval, (_) => unawaited(_tick()));
  }

  bool get _hiddenActive =>
      _ref.read(shieldActiveProvider) || _ref.read(relayActiveProvider) || _ref.read(dnsTunnelActiveProvider);

  Future<void> _tick() async {
    if (_busy) return;
    if (!_ref.read(FallbackPrefs.enabled)) {
      _fails = 0;
      return;
    }
    final status = _ref.read(connectionNotifierProvider).valueOrNull;
    final dns = _ref.read(dnsTunnelControllerProvider);
    if (status == null || !status.isConnected || _hiddenActive || dns.inUse) {
      _fails = 0;
      // re-armed once the user is back on a normal profile by themselves, a while after a switch
      if (!_armed && status != null && status.isDisconnected && !dns.inUse) {
        final at = _firedAt;
        if (at == null || DateTime.now().difference(at) > const Duration(minutes: 2)) _armed = true;
      }
      return;
    }
    if (!_armed) return;
    final at = _firedAt;
    if (at != null && DateTime.now().difference(at) < cooldown) return;

    _busy = true;
    try {
      final ok = await _tunnelWorks();
      if (ok == null) return; // no answer either way
      if (ok) {
        _fails = 0;
        return;
      }
      _fails++;
      loggy.info('iran access watcher: tunnel probe failed ($_fails/$failsNeeded)');
      if (_fails < failsNeeded) return;
      _fails = 0;
      final domestic = await _anyTls(_domestic.map((h) => (h, 443)).toList());
      final international = await _anyTls(_international);
      loggy.info('iran access watcher: domestic $domestic, international direct $international');
      if (!domestic || international) return;
      // still connected with the same kind of profile, still on?
      if (!_ref.read(FallbackPrefs.enabled) || _hiddenActive) return;
      if (!(_ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false)) return;
      _armed = false;
      _firedAt = DateTime.now();
      await _switch();
    } catch (e) {
      loggy.warning('iran access watcher: $e');
    } finally {
      _busy = false;
    }
  }

  /// true / false, or null when nothing could be measured.
  Future<bool?> _tunnelWorks() async {
    final port = _ref.read(ConfigOptions.mixedPort);
    if (await _portOpen(port)) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8)
        ..findProxy = ((_) => 'PROXY 127.0.0.1:$port');
      try {
        final req = await client
            .getUrl(Uri.parse('http://www.gstatic.com/generate_204'))
            .timeout(const Duration(seconds: 8));
        final res = await req.close().timeout(const Duration(seconds: 8));
        await res.drain<void>();
        return res.statusCode == 204 || res.statusCode == 200;
      } catch (_) {
        return false;
      } finally {
        client.close(force: true);
      }
    }
    // the core's own URL test of the selected server
    final r = await _ref.read(proxyRepositoryProvider).urlTest('').run();
    if (r.isLeft()) return null;
    await Future<void>.delayed(const Duration(seconds: 8));
    final delay = _ref.read(activeProxyNotifierProvider).valueOrNull?.urlTestDelay ?? 0;
    if (delay == 0) return null;
    return ConnectionConst.isValidDelay(delay);
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

  /// A direct (outside the VPN: the app is excluded from it) TLS handshake to any of [hosts].
  Future<bool> _anyTls(List<(String, int)> hosts) async {
    final results = await Future.wait(
      hosts.map((h) async {
        Socket? s;
        try {
          s = await Socket.connect(h.$1, h.$2, timeout: const Duration(seconds: 5));
          final t = await SecureSocket.secure(
            s,
            host: h.$1,
            onBadCertificate: (_) => true,
          ).timeout(const Duration(seconds: 5));
          t.destroy();
          return true;
        } catch (_) {
          s?.destroy();
          return false;
        }
      }),
    );
    return results.any((ok) => ok);
  }

  Future<void> _switch() async {
    final s = _ref.read(netWatchStringsProvider);
    final notification = _ref.read(inAppNotificationControllerProvider);
    final router = _ref.read(goRouterNotiferProvider);
    void openTab() => router.goNamed('ramanTools', queryParameters: const {'tab': 'dns'});
    final dns = _ref.read(dnsTunnelControllerProvider);
    final selected = dns.selected?.config;
    if (selected == null) {
      notification.showInfoToast(s.noDnsConfig, action: (label: s.open, onPressed: openTab));
      return;
    }
    final engines = await DnsTunnelPlatform.available();
    if (engines.isNotEmpty && engines[selected.engine.name] != true) {
      notification.showInfoToast(s.switchFailed(selected.engine.label), action: (label: s.open, onPressed: openTab));
      return;
    }
    loggy.info('iran access watcher: switching to the DNS tunnel (${selected.engine.name})');
    notification.showInfoToast(
      s.switching('${selected.name} · ${selected.engine.label}'),
      action: (label: s.open, onPressed: openTab),
    );
    // the same steps as the DNS tab's start button when another connection runs
    await _ref.read(connectionNotifierProvider.notifier).abortConnection();
    for (var i = 0; i < 50; i++) {
      final st = _ref.read(connectionNotifierProvider).valueOrNull;
      if (st == null || st.isDisconnected) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final err = await dns.start();
    if (err != null) {
      loggy.warning('iran access watcher: dns tunnel start failed: $err');
      notification.showErrorToast(s.switchFailed(err));
    }
  }
}
