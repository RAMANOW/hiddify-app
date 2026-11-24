import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hiddify/features/raman/dnstunnel/dns_links.dart';

/// Raman VPN 1.8.3 «کانفیگ‌یاب» (config finder), the parts with no Flutter in them: the public
/// sources, reading their pages, taking the config links out of them, and the reachability test.
/// No config list is shipped with the app: every list is read from its source when the user asks.

/// A public place free configs are posted: a raw subscription file or a Telegram channel's web
/// preview (`t.me/s/<channel>`).
class FinderSource {
  const FinderSource(this.url, this.label, {this.shutdown = false, this.small = false});

  final String url;
  final String label;

  /// 1.9: a channel that posted shutdown configs (DNS-tunnel links, v2ray on whitelisted routes)
  /// during the Feb–May 2026 shutdown; read first, and the only channels read from behind the DNS
  /// tunnel.
  final bool shutdown;

  /// 1.9: a small raw file (under ~70 KB), cheap enough to read from behind the DNS tunnel.
  final bool small;

  bool get isTelegram => telegramChannelOf(url) != null;
}

/// The built-in sources (checked 2026-11-23: each answered with configs and was updated that day).
const builtinFinderSources = <FinderSource>[
  FinderSource('https://raw.githubusercontent.com/barry-far/V2ray-Config/main/Sub1.txt', 'GitHub · barry-far'),
  FinderSource(
    'https://raw.githubusercontent.com/MatinGhanbari/v2ray-configs/main/subscriptions/v2ray/subs/sub1.txt',
    'GitHub · MatinGhanbari',
  ),
  FinderSource(
    'https://raw.githubusercontent.com/mahdibland/V2RayAggregator/master/Eternity.txt',
    'GitHub · mahdibland',
    small: true,
  ),
  FinderSource('https://raw.githubusercontent.com/MhdiTaheri/V2rayCollector/main/sub/mix', 'GitHub · MhdiTaheri'),
  FinderSource(
    'https://raw.githubusercontent.com/roosterkid/openproxylist/main/V2RAY_RAW.txt',
    'GitHub · roosterkid',
    small: true,
  ),
  FinderSource('https://t.me/s/V2ray_Alpha', 'Telegram · V2ray_Alpha'),
  FinderSource('https://t.me/s/FreakConfig', 'Telegram · FreakConfig'),
  FinderSource('https://t.me/s/v2rayNG_Matsuri', 'Telegram · v2rayNG_Matsuri'),
  FinderSource('https://t.me/s/ConfigsHUB', 'Telegram · ConfigsHUB'),
  FinderSource('https://t.me/s/Outline_Vpn', 'Telegram · Outline_Vpn'),
];

/// 1.9: public channels that posted shutdown configs in the Feb–May 2026 shutdown and still had
/// such links in their web preview on 2026-11-24 (DNS-tunnel links: soar / cottendns / masterdns /
/// stormdns; v2ray configs "for the national internet"). Only the channel names are kept here,
/// nothing of their posts; the user can turn each one off.
const shutdownFinderSources = <FinderSource>[
  FinderSource('https://t.me/s/whitedns', 'Telegram · whitedns', shutdown: true),
  FinderSource('https://t.me/s/ConfigWireguard', 'Telegram · ConfigWireguard', shutdown: true),
  FinderSource('https://t.me/s/vpnfolder', 'Telegram · vpnfolder', shutdown: true),
  FinderSource('https://t.me/s/Masir_Sefid', 'Telegram · Masir_Sefid', shutdown: true),
  FinderSource('https://t.me/s/v2raypooliran', 'Telegram · v2raypooliran', shutdown: true),
  FinderSource('https://t.me/s/tanhanet', 'Telegram · tanhanet', shutdown: true),
];

/// Every built-in source, shutdown channels first.
const allBuiltinFinderSources = <FinderSource>[...shutdownFinderSources, ...builtinFinderSources];

/// How much is read from behind the DNS tunnel (a few kB/s): the shutdown channels, one page
/// each, and at most two small raw files.
const finderSlowMaxRaw = 2;
const finderSlowPageBytes = 300 << 10;
const finderSlowRawBytes = 128 << 10;

/// The sources read from behind the DNS tunnel, in order: shutdown channels, then up to
/// [finderSlowMaxRaw] small raw files, then the user's own Telegram channels.
List<FinderSource> slowFinderSources(List<FinderSource> active) => [
  ...active.where((s) => s.shutdown),
  ...active.where((s) => s.small && !s.isTelegram).take(finderSlowMaxRaw),
  ...active.where((s) => !s.shutdown && !s.small && s.isTelegram && !builtinFinderSources.any((b) => b.url == s.url)),
];

final _channelRe = RegExp(r'^(?:https?://)?(?:www\.)?(?:t|telegram)\.me/(?:s/)?([A-Za-z][A-Za-z0-9_]{3,31})/?(?:\?.*)?$', caseSensitive: false);

/// The channel name of a t.me link (t.me/name, t.me/s/name), or null.
String? telegramChannelOf(String url) {
  final m = _channelRe.firstMatch(url.trim());
  if (m == null) return null;
  final name = m.group(1)!;
  // t.me/proxy?… and t.me/socks?… are Telegram proxy links, not channels
  if (const {'proxy', 'socks', 'joinchat', 'share', 'addstickers'}.contains(name.toLowerCase())) return null;
  return name;
}

/// A source the user typed: a raw subscription URL, a t.me link or @channel. Null when it is
/// neither.
String? normalizeFinderSource(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('@')) s = 't.me/s/${s.substring(1)}';
  final channel = telegramChannelOf(s);
  if (channel != null) return 'https://t.me/s/$channel';
  final uri = Uri.tryParse(s);
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http') || uri.host.isEmpty) return null;
  return uri.toString();
}

/// The link schemes the finder tests and keeps.
final finderLinkRe = RegExp(
  r'''(?:vless|vmess|trojan|ss|hy2|hysteria2|tuic)://[^\s"'<>`]+''',
  caseSensitive: false,
);

String _trimTail(String s) => s.replaceFirst(RegExp(r'''[.,;)\]}'"»،]+$'''), '');

String _decodeBase64(String s) {
  var t = s.trim().replaceAll(RegExp(r'\s'), '');
  if (t.isEmpty) return s;
  t = t.replaceAll('-', '+').replaceAll('_', '/');
  t = t.padRight(t.length + (4 - t.length % 4) % 4, '=');
  try {
    return utf8.decode(base64.decode(t), allowMalformed: true);
  } catch (_) {
    return s;
  }
}

/// Every config link in a source's body (a subscription file, plain or base64, or a Telegram web
/// page), in the order found; newest first for a Telegram page (its newest post is at the bottom).
List<String> extractFinderLinks(String body, {bool telegram = false}) {
  var text = body;
  if (telegram || text.contains('<html') || text.contains('tgme_')) {
    text = htmlToText(text);
  } else if (!finderLinkRe.hasMatch(text)) {
    text = _decodeBase64(text);
  }
  final out = <String>[];
  for (final m in finderLinkRe.allMatches(text)) {
    out.add(_trimTail(m.group(0)!));
  }
  return telegram ? out.reversed.toList() : out;
}

/// Where a link's server is, as the test needs it.
class FinderEndpoint {
  const FinderEndpoint({
    required this.link,
    required this.scheme,
    required this.host,
    required this.port,
    required this.tls,
    required this.sni,
    required this.udp,
    required this.key,
    this.security = '',
    this.transport = '',
  });

  final String link;
  final String scheme;
  final String host;
  final int port;

  /// The client opens TLS (tls / reality / trojan) to the server: the test does a TLS handshake.
  final bool tls;
  final String sni;

  /// QUIC-based (hysteria2, tuic, quic / kcp transports): a TCP test says nothing about it.
  final bool udp;

  /// The link without its name, for dedupe.
  final String key;

  /// 1.9: 'reality', 'tls' or '' (none), and the transport ('tcp', 'ws', 'grpc', 'xhttp', …).
  final String security;
  final String transport;

  bool get isReality => security == 'reality';
  bool get isXhttp => transport == 'xhttp';
}

/// 1.9: the core in this build reads XHTTP links. Checked for hiddify-core 5.9.15 (the official
/// core this app ships): its sing-box (hiddify-sing-box v1.13.0 base) has transport/v2rayxhttp, and
/// its link parser ray2sing (63c82f8c, 2026-02-10) maps `type=xhttp` to the XHTTP transport
/// (common.go `case "xhttp"`); libhiddify-core.so of 1.8.3 has the v2rayxhttp symbols. XHTTP with
/// ALPN h3 runs over QUIC (UDP) and is treated like the other UDP configs. Set this to false for a
/// core without XHTTP and the finder drops XHTTP links instead of keeping configs it can not run.
const coreSupportsXhttp = true;

/// 1.9 ranking tier, lower first: REALITY (vless+reality, ~75 % success in Iran, Nov 2026), then
/// XHTTP over TLS (~66 %), then other TLS, then plain TCP (a CDN edge or any open port answers a
/// TCP connect, so it proves the least).
int finderTier(FinderEndpoint e) {
  if (e.isReality) return 0;
  if (e.isXhttp && e.tls) return 1;
  if (e.tls) return 2;
  return 3;
}

/// Orders the configs that answered by tier, then by delay, at most [perHost] per server, and
/// keeps [keep] of them.
List<(FinderEndpoint, int)> rankFinderResults(List<(FinderEndpoint, int)> ok, int keep, {int perHost = 2}) {
  final sorted = ok.toList()
    ..sort((a, b) {
      final t = finderTier(a.$1).compareTo(finderTier(b.$1));
      return t != 0 ? t : a.$2.compareTo(b.$2);
    });
  final count = <String, int>{};
  final out = <(FinderEndpoint, int)>[];
  for (final p in sorted) {
    final h = '${p.$1.host}:${p.$1.port}';
    if ((count[h] ?? 0) >= perHost) continue;
    count[h] = (count[h] ?? 0) + 1;
    out.add(p);
    if (out.length >= keep) break;
  }
  return out;
}

String _stripBrackets(String h) => h.startsWith('[') && h.endsWith(']') ? h.substring(1, h.length - 1) : h;

/// host:port or [v6]:port.
(String, int)? _hostPort(String s) {
  final m = RegExp(r'^\[?([^\[\]@/\s]+?)\]?:(\d{1,5})$').firstMatch(s.trim());
  if (m == null) return null;
  final port = int.parse(m.group(2)!);
  final host = m.group(1)!;
  if (!_validHost(host) || port <= 0 || port > 65535) return null;
  return (host, port);
}

bool _validHost(String h) => h.isNotEmpty && h.length <= 253 && !h.contains(' ');

/// The endpoint of a vless / vmess / trojan / ss / hy2 / tuic link, or null when it can not be
/// read (the link is then dropped).
FinderEndpoint? parseFinderLink(String raw) {
  final link = raw.trim();
  final sep = link.indexOf('://');
  if (sep < 0) return null;
  final scheme = link.substring(0, sep).toLowerCase();
  final noName = link.split('#').first;
  try {
    switch (scheme) {
      case 'vmess':
        final payload = noName.substring(sep + 3).split('?').first;
        final json = jsonDecode(_decodeBase64(payload));
        if (json is! Map) return null;
        final host = _stripBrackets('${json['add'] ?? ''}'.trim());
        final port = int.tryParse('${json['port'] ?? ''}'.trim()) ?? 0;
        if (!_validHost(host) || port <= 0 || port > 65535) return null;
        final net = '${json['net'] ?? ''}'.toLowerCase();
        final tlsField = '${json['tls'] ?? ''}'.toLowerCase();
        final sni = '${json['sni'] ?? ''}'.trim().isNotEmpty ? '${json['sni']}'.trim() : '${json['host'] ?? ''}'.trim();
        final copy = Map<String, dynamic>.from(json)..remove('ps');
        final alpn = '${json['alpn'] ?? ''}'.toLowerCase();
        if (net == 'xhttp' && !coreSupportsXhttp) return null;
        return FinderEndpoint(
          link: link,
          scheme: scheme,
          host: host,
          port: port,
          tls: tlsField == 'tls' || tlsField == 'reality',
          sni: sni.isEmpty ? host : sni.split(',').first,
          udp: net == 'kcp' || net == 'quic' || (net == 'xhttp' && alpn.contains('h3')),
          security: tlsField == 'reality' ? 'reality' : (tlsField == 'tls' ? 'tls' : ''),
          transport: net.isEmpty ? 'tcp' : net,
          key: 'vmess|${jsonEncode(Map.fromEntries(copy.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))}',
        );
      case 'ss':
        // ss://userinfo@host:port or ss://base64(method:password@host:port); the password of a
        // 2022 cipher is plain base64 (+ / =), which Uri.parse does not take
        var body = noName.substring(sep + 3).split('?').first;
        if (body.endsWith('/')) body = body.substring(0, body.length - 1);
        if (!body.contains('@')) body = _decodeBase64(body);
        final at = body.lastIndexOf('@');
        if (at < 0) return null;
        final hp = _hostPort(body.substring(at + 1));
        if (hp == null) return null;
        return FinderEndpoint(
          link: link,
          scheme: scheme,
          host: hp.$1,
          port: hp.$2,
          tls: false,
          sni: hp.$1,
          udp: false,
          key: 'ss|${body.substring(0, at)}@${hp.$1}:${hp.$2}',
        );
      case 'vless' || 'trojan' || 'hy2' || 'hysteria2' || 'tuic':
        final uri = Uri.parse(noName);
        final host = _stripBrackets(uri.host);
        final port = uri.hasPort ? uri.port : (scheme == 'trojan' ? 443 : 0);
        if (!_validHost(host) || port <= 0 || port > 65535) return null;
        final q = uri.queryParameters.map((k, v) => MapEntry(k.toLowerCase(), v));
        final security = (q['security'] ?? (scheme == 'trojan' ? 'tls' : 'none')).toLowerCase();
        final type = (q['type'] ?? '').toLowerCase();
        final sni = (q['sni'] ?? q['servername'] ?? q['peer'] ?? '').trim();
        final host2 = (q['host'] ?? '').trim();
        final alpn = (q['alpn'] ?? '').toLowerCase();
        if (type == 'xhttp' && !coreSupportsXhttp) return null;
        final isUdp = scheme == 'hy2' ||
            scheme == 'hysteria2' ||
            scheme == 'tuic' ||
            type == 'quic' ||
            type == 'kcp' ||
            (type == 'xhttp' && alpn.contains('h3'));
        final s = sni.isNotEmpty ? sni : (host2.isNotEmpty ? host2.split(',').first : host);
        return FinderEndpoint(
          link: link,
          scheme: scheme == 'hysteria2' ? 'hy2' : scheme,
          host: host,
          port: port,
          tls: security == 'tls' || security == 'reality' || security == 'xtls',
          sni: s,
          udp: isUdp,
          security: security == 'reality' ? 'reality' : (security == 'tls' || security == 'xtls' ? 'tls' : ''),
          transport: type.isEmpty ? 'tcp' : type,
          key: '$scheme|${uri.userInfo}@$host:$port|${(q.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).map((e) => '${e.key}=${e.value}').join('&')}',
        );
      default:
        return null;
    }
  } catch (_) {
    return null;
  }
}

/// [link] with its display name set to [name] (the fragment, or `ps` of a vmess link). Names from
/// public lists often carry ads; the finder names its configs itself.
String renameFinderLink(String link, String name) {
  final sep = link.indexOf('://');
  final scheme = sep < 0 ? '' : link.substring(0, sep).toLowerCase();
  if (scheme == 'vmess') {
    try {
      final payload = link.substring(sep + 3).split('#').first.split('?').first;
      final json = jsonDecode(_decodeBase64(payload));
      if (json is Map) {
        final copy = Map<String, dynamic>.from(json)..['ps'] = name;
        return 'vmess://${base64.encode(utf8.encode(jsonEncode(copy)))}';
      }
    } catch (_) {}
    return link;
  }
  return '${link.split('#').first}#${Uri.encodeComponent(name)}';
}

/// One reachability test from the phone (the app is outside its own VPN, so this is the user's
/// own network, as the core will see it): a TCP connect to the server, then for TLS configs a TLS
/// handshake with the config's SNI (a REALITY server answers it with its cover site). Returns the
/// time it took in ms, or null when it failed. Nothing of the running connection is touched.
Future<int?> probeFinderEndpoint(FinderEndpoint e, {Duration timeout = const Duration(seconds: 5)}) async {
  if (e.udp) return null;
  final sw = Stopwatch()..start();
  Socket? socket;
  try {
    socket = await Socket.connect(e.host, e.port, timeout: timeout);
    if (!e.tls) {
      final ms = sw.elapsedMilliseconds;
      socket.destroy();
      return ms;
    }
    final left = timeout - sw.elapsed;
    if (left <= Duration.zero) throw TimeoutException('tls');
    final secure = await SecureSocket.secure(
      socket,
      host: e.sni.isEmpty ? e.host : e.sni,
      onBadCertificate: (_) => true,
    ).timeout(left);
    final ms = sw.elapsedMilliseconds;
    secure.destroy();
    return ms;
  } catch (_) {
    socket?.destroy();
    return null;
  }
}

/// Runs [task] on every item with at most [concurrency] at a time; [onDone] after each one.
Future<List<R>> runPool<T, R>(
  List<T> items,
  Future<R> Function(T) task, {
  int concurrency = 16,
  void Function(int done)? onDone,
  bool Function()? cancelled,
}) async {
  final results = List<R?>.filled(items.length, null);
  var next = 0;
  var done = 0;
  Future<void> worker() async {
    while (true) {
      if (cancelled?.call() ?? false) return;
      final i = next++;
      if (i >= items.length) return;
      results[i] = await task(items[i]);
      done++;
      onDone?.call(done);
    }
  }

  await Future.wait(List.generate(concurrency.clamp(1, items.isEmpty ? 1 : items.length), (_) => worker()));
  return results.cast<R>();
}

/// 1.9: a SOCKS5 CONNECT (no login) to [host]:[port] through 127.0.0.1:[socksPort] (the DNS
/// tunnel engines' local port). The returned socket has the handshake done and no listener left
/// on it, so it can be handed to [SecureSocket.secure].
Future<Socket> socks5Connect(int socksPort, String host, int port, {Duration timeout = const Duration(seconds: 30)}) async {
  final s = await Socket.connect('127.0.0.1', socksPort, timeout: timeout);
  final buf = <int>[];
  var want = 0;
  Completer<void>? waiter;
  void wake([Object? error]) {
    final w = waiter;
    if (w == null) return;
    waiter = null;
    error == null ? w.complete() : w.completeError(error);
  }

  final sub = s.listen(
    (d) {
      buf.addAll(d);
      if (buf.length >= want) wake();
    },
    onError: (Object e) => wake(e),
    onDone: () => wake(const SocketException('SOCKS server closed the connection')),
    cancelOnError: true,
  );
  Future<List<int>> read(int n) async {
    if (buf.length < n) {
      want = n;
      waiter = Completer<void>();
      await waiter!.future.timeout(timeout);
    }
    final out = buf.sublist(0, n);
    buf.removeRange(0, n);
    return out;
  }

  try {
    s.add(const [5, 1, 0]);
    final m = await read(2);
    if (m[0] != 5 || m[1] != 0) throw const SocketException('SOCKS: no auth method accepted');
    final h = utf8.encode(host);
    if (h.length > 255) throw const SocketException('SOCKS: host name too long');
    s.add([5, 1, 0, 3, h.length, ...h, port >> 8, port & 255]);
    final r = await read(4);
    if (r[1] != 0) throw SocketException('SOCKS: connect refused (${r[1]})');
    final skip = switch (r[3]) {
      1 => 4,
      4 => 16,
      _ => (await read(1))[0],
    };
    await read(skip + 2);
    if (buf.isNotEmpty) throw const SocketException('SOCKS: unexpected data');
    sub.pause();
    return s;
  } catch (_) {
    await sub.cancel();
    s.destroy();
    rethrow;
  }
}

/// How a page is read: through the core's local HTTP/mixed port, through a DNS tunnel engine's
/// SOCKS5 port (https only), or directly.
class FinderRoute {
  const FinderRoute.direct() : httpProxyPort = null, socksPort = null;
  const FinderRoute.core(int port) : httpProxyPort = port, socksPort = null;
  const FinderRoute.socks(int port) : httpProxyPort = null, socksPort = port;

  final int? httpProxyPort;
  final int? socksPort;

  String get name => httpProxyPort != null ? 'core' : (socksPort != null ? 'dns' : 'direct');
}

/// An HttpClient that goes by [route] (1.9).
HttpClient finderHttpClient(FinderRoute route, Duration connectTimeout) {
  final client = HttpClient()
    ..connectionTimeout = connectTimeout
    ..userAgent = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36';
  final httpPort = route.httpProxyPort;
  final socksPort = route.socksPort;
  if (httpPort != null) {
    client.findProxy = (_) => 'PROXY 127.0.0.1:$httpPort';
  } else if (socksPort != null) {
    client.findProxy = (_) => 'DIRECT';
    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      if (uri.scheme != 'https') throw const SocketException('only https through SOCKS');
      final task = () async {
        final raw = await socks5Connect(socksPort, uri.host, uri.hasPort ? uri.port : 443, timeout: connectTimeout);
        return SecureSocket.secure(raw, host: uri.host).timeout(connectTimeout);
      }();
      return ConnectionTask.fromSocket<Socket>(task, () {});
    };
  }
  return client;
}

/// The body of [url] as bytes (at most [maxBytes]), by [route].
Future<Uint8List> fetchFinderBytes(
  String url, {
  FinderRoute route = const FinderRoute.direct(),
  Duration timeout = const Duration(seconds: 20),
  Duration connectTimeout = const Duration(seconds: 10),
  int maxBytes = 4 << 20,
}) async {
  final client = finderHttpClient(route, connectTimeout);
  try {
    return await () async {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode >= 400) {
        await res.drain<void>();
        throw HttpException('HTTP ${res.statusCode}');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in res) {
        bytes.add(chunk);
        if (bytes.length >= maxBytes) break;
      }
      return bytes.takeBytes();
    }().timeout(timeout);
  } finally {
    client.close(force: true);
  }
}

/// Reads one source ([telegramPages] pages of a Telegram channel) by [route]. At most [maxBytes]
/// of each page are read (after gzip; pages are asked for gzipped).
Future<String> fetchFinderSource(
  String url, {
  FinderRoute route = const FinderRoute.direct(),
  Duration timeout = const Duration(seconds: 20),
  Duration connectTimeout = const Duration(seconds: 10),
  int maxBytes = 3 << 20,
  int telegramPages = 2,
}) async {
  final client = finderHttpClient(route, connectTimeout);
  Future<String> page(String u) async {
    final req = await client.getUrl(Uri.parse(u));
    final res = await req.close();
    if (res.statusCode >= 400) {
      await res.drain<void>();
      throw HttpException('HTTP ${res.statusCode}');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in res) {
      bytes.add(chunk);
      if (bytes.length >= maxBytes) break;
    }
    return utf8.decode(bytes.takeBytes(), allowMalformed: true);
  }

  try {
    return await () async {
      final channel = telegramChannelOf(url);
      if (channel == null) return page(url);
      final base = 'https://t.me/s/$channel';
      final first = await page(base);
      if (!first.contains('tgme_')) throw const HttpException('not a Telegram page');
      final before = telegramBefore(first);
      if (before == null || telegramPages < 2) return first;
      try {
        // older posts first, so the newest stay at the end of the text
        return '${await page('$base?before=$before')}\n$first';
      } catch (_) {
        return first;
      }
    }().timeout(timeout);
  } finally {
    client.close(force: true);
  }
}

/// Takes [cap] items from [lists] in turn (one from each, then the next one from each, …), so a
/// big source does not crowd out the others.
List<T> interleave<T>(List<List<T>> lists, int cap) {
  final out = <T>[];
  for (var i = 0; out.length < cap; i++) {
    var any = false;
    for (final l in lists) {
      if (i < l.length) {
        any = true;
        out.add(l[i]);
        if (out.length >= cap) break;
      }
    }
    if (!any) break;
  }
  return out;
}
