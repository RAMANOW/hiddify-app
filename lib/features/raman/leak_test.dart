import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:hiddify/features/connection/data/connection_data_providers.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// One address the leak test saw: the exit IP, or a DNS resolver that asked for the test names.
class LeakSeen {
  const LeakSeen({required this.ip, required this.countryCode, required this.country, required this.org});

  final String ip;

  /// Lower-case ISO code ("ir"), or empty.
  final String countryCode;
  final String country;
  final String org;

  bool get inIran => countryCode == 'ir';
}

enum LeakVerdict { ok, leak, unknown }

class LeakTestState {
  const LeakTestState({
    this.running = false,
    this.exit,
    this.resolvers = const [],
    this.verdict,
    this.error,
    this.fakeIp = false,
    this.serverSide = false,
    this.finishedAt,
  });

  final bool running;
  final LeakSeen? exit;
  final List<LeakSeen> resolvers;
  final LeakVerdict? verdict;

  /// 'notConnected', 'proxyAuth' or 'unreachable'.
  final String? error;

  /// The core answered with fake IPs (FakeIP on): names are resolved by the server, not here.
  final bool fakeIp;

  /// The names were looked up by the proxy server (the core's DNS could not be reached).
  final bool serverSide;
  final DateTime? finishedAt;
}

final leakTestProvider = StateNotifierProvider<LeakTestNotifier, LeakTestState>(LeakTestNotifier.new);

/// Checks what the internet sees through the tunnel: the exit IP and its country, and which DNS
/// resolvers look up names for this device (bash.ws DNS leak test, with ipleak.net as a second
/// source).
///
/// The app itself is outside its own VPN (Android VpnService excludes it), so the test goes
/// through the core's local proxy port on 127.0.0.1: HTTPS through it for the IP, and DNS over TCP
/// through it, which the core hijacks and answers with the same DNS rules and servers the apps in
/// the VPN get. In VPN mode the local port is closed unless "local proxy in VPN" is on; the test
/// opens it for itself (one quick reload of the core) and closes it again afterwards.
class LeakTestNotifier extends StateNotifier<LeakTestState> with InfraLogger {
  LeakTestNotifier(this._ref) : super(const LeakTestState());

  final Ref _ref;
  static const _timeout = Duration(seconds: 12);
  static const _names = 8;

  bool get _connected => _ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false;

  Future<void> run() async {
    if (state.running) return;
    if (!_connected) {
      state = const LeakTestState(error: 'notConnected');
      return;
    }
    final read = _ref.read;
    if (read(ConfigOptions.localProxyAuth)) {
      state = const LeakTestState(error: 'proxyAuth');
      return;
    }
    state = const LeakTestState(running: true);
    final vpnMode = read(ConfigOptions.serviceMode) == ServiceMode.tun;
    final opened = vpnMode && !read(ConfigOptions.localProxyInVpn);
    try {
      if (opened) {
        await read(ConfigOptions.localProxyInVpn.notifier).update(true);
        await _reloaded();
      }
      final port = read(ConfigOptions.mixedPort);
      final result = await _test(port);
      if (mounted) state = result;
    } catch (e, st) {
      loggy.warning('leak test failed', e, st);
      if (mounted) state = const LeakTestState(error: 'unreachable');
    } finally {
      if (opened) {
        await read(ConfigOptions.localProxyInVpn.notifier).update(false);
        await _reloaded();
      }
    }
  }

  HttpClient _client(int port) => HttpClient()
    ..connectionTimeout = _timeout
    ..findProxy = ((_) => 'PROXY 127.0.0.1:$port')
    ..userAgent = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36';

  Future<String> _get(HttpClient client, String url) async {
    final req = await client.getUrl(Uri.parse(url)).timeout(_timeout);
    final res = await req.close().timeout(_timeout);
    final body = await res.transform(utf8.decoder).join().timeout(_timeout);
    if (res.statusCode >= 400) throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
    return body;
  }

  Future<LeakTestState> _test(int port) async {
    final client = _client(port);
    try {
      try {
        return await _bashWs(client, port);
      } catch (e) {
        loggy.warning('bash.ws leak test failed, trying ipleak.net', e);
      }
      return await _ipleak(client);
    } finally {
      client.close(force: true);
    }
  }

  /// bash.ws: an id, then lookups of `n.<id>.bash.ws`, then the list of who asked.
  Future<LeakTestState> _bashWs(HttpClient client, int port) async {
    final id = (await _get(client, 'https://bash.ws/id')).trim();
    if (!RegExp(r'^[0-9a-zA-Z]{6,64}$').hasMatch(id)) throw const FormatException('bad bash.ws id');
    final names = [for (var i = 1; i <= _names; i++) '$i.$id.bash.ws'];
    final (answered, fake) = await _lookupAll(names, port);
    var serverSide = false;
    if (answered == 0 || fake) {
      // the core's DNS could not be reached through the local port, or FakeIP is on: the server
      // looks the names up when asked for them by name
      serverSide = !fake;
      await Future.wait(names.map((n) => _get(client, 'http://$n/').then((_) {}).catchError((_) {})));
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    final body = await _get(client, 'https://bash.ws/dnsleak/test/$id?json');
    final list = (jsonDecode(body) as List).cast<Map<String, dynamic>>();
    LeakSeen? exit;
    final resolvers = <LeakSeen>[];
    for (final e in list) {
      final seen = LeakSeen(
        ip: '${e['ip'] ?? ''}',
        countryCode: '${e['country'] ?? ''}'.toLowerCase(),
        country: '${e['country_name'] ?? ''}',
        org: '${e['asn'] ?? e['org'] ?? ''}',
      );
      switch (e['type']) {
        case 'ip':
          exit = seen;
        case 'dns':
          resolvers.add(seen);
      }
    }
    exit ??= await _exitFromIpleak(client);
    return _verdict(exit, resolvers, fakeIp: fake, serverSide: serverSide);
  }

  /// ipleak.net: the exit IP, and the resolvers that looked up a random name of its, asked for
  /// by name through the proxy (so only the server's side is seen).
  Future<LeakTestState> _ipleak(HttpClient client) async {
    final exit = await _exitFromIpleak(client);
    final rnd = Random.secure();
    final session = List.generate(40, (_) => '0123456789abcdef'[rnd.nextInt(16)]).join();
    final body = await _get(client, 'https://$session.ipleak.net/dnsdetection/');
    final ips = ((jsonDecode(body) as Map)['ip'] as Map?)?.keys.map((e) => '$e').toList() ?? const <String>[];
    final resolvers = <LeakSeen>[];
    for (final ip in ips.take(6)) {
      try {
        final info = jsonDecode(await _get(client, 'https://ipleak.net/json/$ip')) as Map;
        resolvers.add(
          LeakSeen(
            ip: ip,
            countryCode: '${info['country_code'] ?? ''}'.toLowerCase(),
            country: '${info['country_name'] ?? ''}',
            org: '${info['isp_name'] ?? ''}',
          ),
        );
      } catch (_) {
        resolvers.add(LeakSeen(ip: ip, countryCode: '', country: '', org: ''));
      }
    }
    return _verdict(exit, resolvers, fakeIp: false, serverSide: true);
  }

  Future<LeakSeen?> _exitFromIpleak(HttpClient client) async {
    try {
      final info = jsonDecode(await _get(client, 'https://ipleak.net/json/')) as Map;
      return LeakSeen(
        ip: '${info['ip'] ?? ''}',
        countryCode: '${info['country_code'] ?? ''}'.toLowerCase(),
        country: '${info['country_name'] ?? ''}',
        org: '${info['isp_name'] ?? ''}',
      );
    } catch (_) {
      return null;
    }
  }

  /// Red when the exit or any resolver is in Iran: the traffic or the names left without the
  /// tunnel (or went to an Iranian resolver). Green when neither is, with resolvers seen.
  LeakTestState _verdict(LeakSeen? exit, List<LeakSeen> resolvers, {required bool fakeIp, required bool serverSide}) {
    final leak = (exit?.inIran ?? false) || resolvers.any((r) => r.inIran);
    final verdict = leak
        ? LeakVerdict.leak
        : (exit != null && (resolvers.isNotEmpty || fakeIp) ? LeakVerdict.ok : LeakVerdict.unknown);
    return LeakTestState(
      exit: exit,
      resolvers: resolvers,
      verdict: verdict,
      fakeIp: fakeIp,
      serverSide: serverSide,
      finishedAt: DateTime.now(),
    );
  }

  /// Looks every name up through the core: DNS over TCP to 1.1.1.1:53 through the local port, which
  /// the core's route hijacks to its own DNS. Returns how many answered, and whether an answer was
  /// a fake IP (198.18.0.0/15).
  Future<(int, bool)> _lookupAll(List<String> names, int port) async {
    var answered = 0;
    var fake = false;
    final results = await Future.wait(names.map((n) => _lookup(n, port).catchError((Object _) => <InternetAddress>[])));
    for (final r in results) {
      if (r.isEmpty) continue;
      answered++;
      if (r.any((a) => a.rawAddress.length == 4 && a.rawAddress[0] == 198 && (a.rawAddress[1] & 0xFE) == 18)) {
        fake = true;
      }
    }
    return (answered, fake);
  }

  Future<List<InternetAddress>> _lookup(String name, int port) async {
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: _timeout);
    try {
      final buffer = BytesBuilder();
      final done = Completer<void>();
      var headerEnd = -1;
      var connected = false;
      final sub = socket.listen(
        (data) {
          buffer.add(data);
          final bytes = buffer.toBytes();
          if (!connected) {
            headerEnd = _indexOf(bytes, const [13, 10, 13, 10]);
            if (headerEnd < 0) return;
            final head = latin1.decode(bytes.sublist(0, headerEnd));
            final parts = head.split(' ');
            if (!head.startsWith('HTTP/1.') || parts.length < 2 || !parts[1].startsWith('2')) {
              if (!done.isCompleted) done.completeError(const SocketException('proxy refused CONNECT'));
              return;
            }
            connected = true;
            buffer.clear();
            buffer.add(bytes.sublist(headerEnd + 4));
            if (!done.isCompleted) done.complete();
          }
        },
        onError: (Object e) {
          if (!done.isCompleted) done.completeError(e);
        },
        onDone: () {
          if (!done.isCompleted) done.completeError(const SocketException('closed'));
        },
      );
      socket.write('CONNECT 1.1.1.1:53 HTTP/1.1\r\nHost: 1.1.1.1:53\r\n\r\n');
      await done.future.timeout(_timeout);
      // the DNS query, length-prefixed (RFC 1035 4.2.2)
      final query = _query(name);
      socket.add([query.length >> 8, query.length & 0xFF, ...query]);
      final deadline = DateTime.now().add(_timeout);
      while (DateTime.now().isBefore(deadline)) {
        final bytes = buffer.toBytes();
        if (bytes.length >= 2) {
          final len = (bytes[0] << 8) | bytes[1];
          if (bytes.length >= len + 2) {
            await sub.cancel();
            return _answers(Uint8List.sublistView(bytes, 2, len + 2));
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await sub.cancel();
      return const [];
    } finally {
      socket.destroy();
    }
  }

  static int _indexOf(List<int> data, List<int> pattern) {
    for (var i = 0; i + pattern.length <= data.length; i++) {
      var match = true;
      for (var j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  static List<int> _query(String name) {
    final id = Random().nextInt(0xFFFF);
    final out = <int>[id >> 8, id & 0xFF, 0x01, 0x00, 0, 1, 0, 0, 0, 0, 0, 0];
    for (final label in name.split('.')) {
      final b = ascii.encode(label);
      out
        ..add(b.length)
        ..addAll(b);
    }
    out.addAll([0, 0, 1, 0, 1]); // A, IN
    return out;
  }

  /// The A records of a DNS answer.
  static List<InternetAddress> _answers(Uint8List msg) {
    if (msg.length < 12) return const [];
    final an = (msg[6] << 8) | msg[7];
    var i = 12;
    int skipName(int start) {
      var p = start;
      while (p < msg.length) {
        final l = msg[p];
        if (l == 0) return p + 1;
        if (l & 0xC0 == 0xC0) return p + 2;
        p += l + 1;
      }
      return p;
    }

    final qd = (msg[4] << 8) | msg[5];
    for (var q = 0; q < qd; q++) {
      i = skipName(i) + 4;
    }
    final out = <InternetAddress>[];
    for (var a = 0; a < an && i + 10 <= msg.length; a++) {
      i = skipName(i);
      if (i + 10 > msg.length) break;
      final type = (msg[i] << 8) | msg[i + 1];
      final rdlen = (msg[i + 8] << 8) | msg[i + 9];
      i += 10;
      if (type == 1 && rdlen == 4 && i + 4 <= msg.length) {
        out.add(InternetAddress.fromRawAddress(Uint8List.fromList(msg.sublist(i, i + 4))));
      }
      i += rdlen;
    }
    return out;
  }

  /// Makes sure the core runs with the settings just written, then waits until it is connected
  /// again (at most 25 s).
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
      if (_connected) break;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}
