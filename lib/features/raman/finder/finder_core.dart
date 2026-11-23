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
  const FinderSource(this.url, this.label);

  final String url;
  final String label;

  bool get isTelegram => telegramChannelOf(url) != null;
}

/// The built-in sources (checked 2026-11-23: each answered with configs and was updated that day).
const builtinFinderSources = <FinderSource>[
  FinderSource('https://raw.githubusercontent.com/barry-far/V2ray-Config/main/Sub1.txt', 'GitHub · barry-far'),
  FinderSource(
    'https://raw.githubusercontent.com/MatinGhanbari/v2ray-configs/main/subscriptions/v2ray/subs/sub1.txt',
    'GitHub · MatinGhanbari',
  ),
  FinderSource('https://raw.githubusercontent.com/mahdibland/V2RayAggregator/master/Eternity.txt', 'GitHub · mahdibland'),
  FinderSource('https://raw.githubusercontent.com/MhdiTaheri/V2rayCollector/main/sub/mix', 'GitHub · MhdiTaheri'),
  FinderSource('https://raw.githubusercontent.com/roosterkid/openproxylist/main/V2RAY_RAW.txt', 'GitHub · roosterkid'),
  FinderSource('https://t.me/s/V2ray_Alpha', 'Telegram · V2ray_Alpha'),
  FinderSource('https://t.me/s/FreakConfig', 'Telegram · FreakConfig'),
  FinderSource('https://t.me/s/v2rayNG_Matsuri', 'Telegram · v2rayNG_Matsuri'),
  FinderSource('https://t.me/s/ConfigsHUB', 'Telegram · ConfigsHUB'),
  FinderSource('https://t.me/s/Outline_Vpn', 'Telegram · Outline_Vpn'),
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
        return FinderEndpoint(
          link: link,
          scheme: scheme,
          host: host,
          port: port,
          tls: tlsField == 'tls' || tlsField == 'reality',
          sni: sni.isEmpty ? host : sni.split(',').first,
          udp: net == 'kcp' || net == 'quic',
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
        final isUdp = scheme == 'hy2' || scheme == 'hysteria2' || scheme == 'tuic' || type == 'quic' || type == 'kcp';
        final s = sni.isNotEmpty ? sni : (host2.isNotEmpty ? host2.split(',').first : host);
        return FinderEndpoint(
          link: link,
          scheme: scheme == 'hysteria2' ? 'hy2' : scheme,
          host: host,
          port: port,
          tls: security == 'tls' || security == 'reality' || security == 'xtls',
          sni: s,
          udp: isUdp,
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

/// Reads one source (two pages of a Telegram channel) through 127.0.0.1:[proxyPort] when given.
/// At most [maxBytes] of each page are read.
Future<String> fetchFinderSource(
  String url, {
  int? proxyPort,
  Duration timeout = const Duration(seconds: 20),
  int maxBytes = 3 << 20,
}) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..userAgent = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36';
  if (proxyPort != null) client.findProxy = (_) => 'PROXY 127.0.0.1:$proxyPort';
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
      if (before == null) return first;
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
