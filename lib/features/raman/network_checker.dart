import 'dart:async';
import 'dart:io';

import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A service the network checker tries to reach.
class CheckTarget {
  const CheckTarget(this.name, this.url, {this.domestic = false});

  final String name;
  final String url;
  final bool domestic;
}

abstract final class RamanCheckTargets {
  static const all = <CheckTarget>[
    CheckTarget('Google', 'https://www.google.com/generate_204'),
    CheckTarget('YouTube', 'https://www.youtube.com/generate_204'),
    CheckTarget('Instagram', 'https://www.instagram.com/'),
    CheckTarget('Telegram', 'https://web.telegram.org/'),
    CheckTarget('WhatsApp', 'https://web.whatsapp.com/'),
    CheckTarget('X (Twitter)', 'https://x.com/'),
    CheckTarget('GitHub', 'https://github.com/'),
    CheckTarget('Cloudflare', 'https://www.cloudflare.com/cdn-cgi/trace'),
    CheckTarget('Aparat', 'https://www.aparat.com/', domestic: true),
    CheckTarget('Digikala', 'https://www.digikala.com/', domestic: true),
  ];
}

class CheckResult {
  const CheckResult({required this.target, this.latencyMs, this.error});

  final CheckTarget target;
  final int? latencyMs;
  final String? error;

  bool get ok => latencyMs != null;
}

class NetworkCheckState {
  const NetworkCheckState({this.running = false, this.withVpn = const {}, this.withoutVpn = const {}});

  final bool running;

  /// The last results with the VPN on, and with it off, by target name.
  final Map<String, CheckResult> withVpn;
  final Map<String, CheckResult> withoutVpn;
}

final networkCheckProvider = StateNotifierProvider<NetworkCheckNotifier, NetworkCheckState>(
  (ref) => NetworkCheckNotifier(ref),
);

class NetworkCheckNotifier extends StateNotifier<NetworkCheckState> {
  NetworkCheckNotifier(this._ref) : super(const NetworkCheckState());

  final Ref _ref;
  static const timeout = Duration(seconds: 8);

  bool get vpnOn => _ref.read(connectionNotifierProvider).asData?.value.isConnected ?? false;

  /// Tries every service at once. The app's own traffic goes through the VPN while it is on, so the
  /// result is stored as "with VPN" or "without VPN" by the state at the start.
  Future<void> run() async {
    if (state.running) return;
    final withVpn = vpnOn;
    state = NetworkCheckState(running: true, withVpn: state.withVpn, withoutVpn: state.withoutVpn);
    final results = await Future.wait(RamanCheckTargets.all.map(check));
    final map = {for (final r in results) r.target.name: r};
    state = NetworkCheckState(
      withVpn: withVpn ? map : state.withVpn,
      withoutVpn: withVpn ? state.withoutVpn : map,
    );
  }

  /// Any HTTPS answer, whatever its status, means the site is reachable: a filtered site does not
  /// finish the TLS handshake.
  static Future<CheckResult> check(CheckTarget target) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..userAgent = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36';
    try {
      final sw = Stopwatch()..start();
      final req = await client.getUrl(Uri.parse(target.url)).timeout(timeout);
      req.followRedirects = false;
      final res = await req.close().timeout(timeout);
      sw.stop();
      unawaited(res.drain<void>().catchError((_) {}));
      return CheckResult(target: target, latencyMs: sw.elapsedMilliseconds < 1 ? 1 : sw.elapsedMilliseconds);
    } on TimeoutException {
      return CheckResult(target: target, error: 'timeout');
    } catch (e) {
      return CheckResult(target: target, error: e.runtimeType.toString());
    } finally {
      client.close(force: true);
    }
  }
}
