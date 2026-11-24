import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:hiddify/features/raman/finder/finder_core.dart';

/// Raman VPN 1.9 clean-IP scanner, the parts with no Flutter in them. For a config that runs
/// behind a CDN (TLS with a domain SNI: ws / grpc / xhttp / httpupgrade / tcp), it looks for an
/// edge IP of the same CDN that answers from this network, using only the ranges each provider
/// publishes itself. Cloudflare is never scanned: its IPs are throttled from Iran since
/// 2026-10-02 (Filterwatch), so a Cloudflare config is only recognised and the user told so.
enum CdnProvider {
  fastly('Fastly', 'https://api.fastly.com/public-ip-list'),
  gcore('Gcore', 'https://api.gcore.com/cdn/public-ip-list'),
  akamai('Akamai', 'https://techdocs.akamai.com/property-manager/pdfs/akamai_ipv4_ipv6_CIDRs-txt.zip'),
  cloudfront('Amazon CloudFront', 'https://d7uri8nf7uskq.cloudfront.net/tools/list-cloudfront-ips'),
  bunny('Bunny CDN', 'https://bunnycdn.com/api/system/edgeserverlist'),

  /// Detection only, never scanned.
  cloudflare('Cloudflare', 'https://www.cloudflare.com/ips-v4');

  const CdnProvider(this.label, this.listUrl);

  final String label;

  /// The provider's own published list of its IPs.
  final String listUrl;

  bool get scannable => this != CdnProvider.cloudflare;
}

/// A copy of the providers' published IPv4 ranges (read 2026-11-24 from [CdnProvider.listUrl]),
/// used only when the live list can not be read. Gcore and Bunny publish long lists of single IPs
/// that change often, so they are only read live.
const cdnRangesSnapshot = <CdnProvider, List<String>>{
  CdnProvider.fastly: [
    '23.235.32.0/20', '43.249.72.0/22', '103.244.50.0/24', '103.245.222.0/23', '103.245.224.0/24', //
    '104.156.80.0/20', '140.248.64.0/18', '140.248.128.0/17', '146.75.0.0/17', '151.101.0.0/16',
    '157.52.64.0/18', '167.82.0.0/17', '167.82.128.0/20', '167.82.160.0/20', '167.82.224.0/20',
    '172.111.64.0/18', '185.31.16.0/22', '199.27.72.0/21', '199.232.0.0/16',
  ],
  CdnProvider.akamai: ['2.16.0.0/13', '23.0.0.0/12', '23.192.0.0/11', '23.32.0.0/11', '95.100.0.0/15', '184.24.0.0/13'],
  CdnProvider.cloudfront: [
    '108.156.0.0/14', '13.224.0.0/14', '3.168.0.0/14', '3.160.0.0/14', '18.64.0.0/14', '18.160.0.0/15', //
    '13.32.0.0/15', '18.238.0.0/15', '18.244.0.0/15', '18.164.0.0/15', '3.166.0.0/15', '18.172.0.0/15',
  ],
  CdnProvider.cloudflare: [
    '173.245.48.0/20', '103.21.244.0/22', '103.22.200.0/22', '103.31.4.0/22', '141.101.64.0/18', //
    '108.162.192.0/18', '190.93.240.0/20', '188.114.96.0/20', '197.234.240.0/22', '198.41.128.0/17',
    '162.158.0.0/15', '104.16.0.0/13', '104.24.0.0/14', '172.64.0.0/13', '131.0.72.0/22',
  ],
};

/// An IPv4 prefix.
class Cidr4 {
  const Cidr4(this.base, this.bits);

  final int base;
  final int bits;

  static Cidr4? tryParse(String s) {
    final t = s.trim();
    final parts = t.split('/');
    final ip = ipv4ToInt(parts.first);
    if (ip == null) return null;
    final bits = parts.length > 1 ? int.tryParse(parts[1]) : 32;
    if (bits == null || bits < 8 || bits > 32) return null;
    final mask = bits == 0 ? 0 : (0xFFFFFFFF << (32 - bits)) & 0xFFFFFFFF;
    return Cidr4(ip & mask, bits);
  }

  int get size => 1 << (32 - bits);

  bool contains(int ip) => (ip & ((0xFFFFFFFF << (32 - bits)) & 0xFFFFFFFF)) == base;

  /// A host address inside the prefix (not the network / broadcast one of a /24 or wider).
  int sample(Random r) {
    if (bits >= 31) return base + (bits == 32 ? 0 : r.nextInt(2));
    return base + 1 + r.nextInt(size - 2);
  }

  @override
  String toString() => '${intToIpv4(base)}/$bits';
}

int? ipv4ToInt(String s) {
  final p = s.trim().split('.');
  if (p.length != 4) return null;
  var v = 0;
  for (final x in p) {
    final n = int.tryParse(x);
    if (n == null || n < 0 || n > 255) return null;
    v = (v << 8) | n;
  }
  return v;
}

String intToIpv4(int v) => '${(v >> 24) & 255}.${(v >> 16) & 255}.${(v >> 8) & 255}.${v & 255}';

/// The IPv4 ranges in a provider's published list (JSON, text or the Akamai zip).
List<Cidr4> parseCdnList(CdnProvider p, Uint8List body) {
  final out = <Cidr4>[];
  void addAll(Iterable<Object?> items) {
    for (final i in items) {
      if (i is String) {
        final c = Cidr4.tryParse(i);
        if (c != null) out.add(c);
      }
    }
  }

  try {
    switch (p) {
      case CdnProvider.fastly || CdnProvider.gcore:
        final j = jsonDecode(utf8.decode(body)) as Map;
        addAll((j['addresses'] as List?) ?? const []);
      case CdnProvider.cloudfront:
        final j = jsonDecode(utf8.decode(body)) as Map;
        addAll((j['CLOUDFRONT_GLOBAL_IP_LIST'] as List?) ?? const []);
        addAll((j['CLOUDFRONT_REGIONAL_EDGE_IP_LIST'] as List?) ?? const []);
      case CdnProvider.bunny:
        addAll((jsonDecode(utf8.decode(body)) as List?) ?? const []);
      case CdnProvider.akamai:
        final zip = ZipDecoder().decodeBytes(body);
        for (final f in zip.files) {
          if (!f.isFile || !f.name.endsWith('ipv4_CIDRs.txt') || f.name.contains('__MACOSX')) continue;
          addAll(utf8.decode(f.content as List<int>, allowMalformed: true).split(RegExp(r'\s+')));
        }
      case CdnProvider.cloudflare:
        addAll(utf8.decode(body, allowMalformed: true).split(RegExp(r'\s+')));
    }
  } catch (_) {}
  return out;
}

/// Which provider's ranges [ip] is in, or null.
CdnProvider? cdnOf(int ip, Map<CdnProvider, List<Cidr4>> ranges) {
  for (final e in ranges.entries) {
    if (e.value.any((c) => c.contains(ip))) return e.key;
  }
  return null;
}

/// [count] distinct random edge IPs from [ranges]: every prefix gets a share by the square root of
/// its size (so one /12 does not take all of them, nor a thousand /32s), at least one each.
///
/// With [lastOctets] (the last byte of the IPs the config's own domain resolves to), half of them
/// keep that last byte in other /24 blocks of the ranges: some CDNs (Fastly) serve a domain's
/// certificate only on addresses that end like the ones its DNS gives (151.101.*.223).
List<String> sampleCdnIps(List<Cidr4> ranges, int count, {Random? random, Set<int> lastOctets = const {}}) {
  final r = random ?? Random();
  if (ranges.isEmpty || count <= 0) return const [];
  final wide = ranges.where((c) => c.bits <= 24).toList();
  final suffix = <int>{};
  if (lastOctets.isNotEmpty && wide.isNotEmpty) {
    final octets = lastOctets.toList();
    final ww = wide.map((c) => sqrt(c.size.toDouble())).toList();
    final wt = ww.fold<double>(0, (a, b) => a + b);
    var g = 0;
    while (suffix.length < count ~/ 2 && g++ < count * 20) {
      var x = r.nextDouble() * wt;
      var i = 0;
      while (i < ww.length - 1 && x > ww[i]) {
        x -= ww[i];
        i++;
      }
      final block = wide[i].base + (r.nextInt(wide[i].size >> 8) << 8);
      suffix.add(block | octets[r.nextInt(octets.length)]);
    }
  }
  final rest = _sampleSpread(ranges, count - suffix.length, r, suffix);
  return [...suffix, ...rest].map(intToIpv4).toList();
}

Iterable<int> _sampleSpread(List<Cidr4> ranges, int count, Random r, Set<int> taken) {
  if (count <= 0) return const [];
  final weights = ranges.map((c) => sqrt(c.size.toDouble())).toList();
  final total = weights.fold<double>(0, (a, b) => a + b);
  final picked = <int>{};
  bool add(int ip) => !taken.contains(ip) && picked.add(ip);
  final order = List.generate(ranges.length, (i) => i)..shuffle(r);
  // first one from as many prefixes as fit, then by weight
  for (final i in order) {
    if (picked.length >= count) break;
    add(ranges[i].sample(r));
  }
  var guard = 0;
  while (picked.length < count && guard++ < count * 20) {
    var x = r.nextDouble() * total;
    var i = 0;
    while (i < weights.length - 1 && x > weights[i]) {
      x -= weights[i];
      i++;
    }
    add(ranges[i].sample(r));
  }
  return picked;
}

/// A config the scanner can use: TLS with a domain name (SNI) that a CDN serves.
class CdnConfig {
  const CdnConfig(this.endpoint, this.sni);

  final FinderEndpoint endpoint;
  final String sni;
}

/// The config in [link] as the scanner needs it, or a reason it can not be used: 'parse',
/// 'reality' (REALITY talks to one server, not a CDN), 'notls', 'udp', 'nosni'.
(CdnConfig?, String?) cdnConfigOf(String link) {
  final e = parseFinderLink(link.trim());
  if (e == null) return (null, 'parse');
  if (e.isReality) return (null, 'reality');
  if (e.udp) return (null, 'udp');
  if (!e.tls) return (null, 'notls');
  final sni = e.sni.trim();
  if (sni.isEmpty || ipv4ToInt(sni) != null || sni.contains(':')) return (null, 'nosni');
  return (CdnConfig(e, sni), null);
}

/// One edge IP tried with the config's SNI: a TCP connect to [port], then a TLS handshake whose
/// certificate must be valid for [sni] (an edge that does not serve the domain fails it). The
/// time in ms, or null.
Future<int?> probeCleanIp(String ip, int port, String sni, {Duration timeout = const Duration(seconds: 4)}) async {
  final sw = Stopwatch()..start();
  Socket? socket;
  try {
    socket = await Socket.connect(ip, port, timeout: timeout);
    final left = timeout - sw.elapsed;
    if (left <= Duration.zero) throw TimeoutException('tls');
    final secure = await SecureSocket.secure(socket, host: sni).timeout(left);
    final ms = sw.elapsedMilliseconds;
    secure.destroy();
    return ms;
  } catch (_) {
    socket?.destroy();
    return null;
  }
}

/// A copy of [link] that connects to [ip] instead of its own address, with the SNI (and the
/// Host header of HTTP transports) kept as the original domain, named [name]. The original
/// link is not changed.
String? withCleanIp(String link, String ip, String sni, String name) {
  final t = link.trim();
  final sep = t.indexOf('://');
  if (sep < 0) return null;
  final scheme = t.substring(0, sep).toLowerCase();
  try {
    if (scheme == 'vmess') {
      final payload = t.substring(sep + 3).split('#').first.split('?').first;
      var p = payload.replaceAll('-', '+').replaceAll('_', '/');
      p = p.padRight(p.length + (4 - p.length % 4) % 4, '=');
      final json = jsonDecode(utf8.decode(base64.decode(p))) as Map;
      final copy = Map<String, dynamic>.from(json)
        ..['add'] = ip
        ..['ps'] = name;
      if ('${copy['sni'] ?? ''}'.trim().isEmpty) copy['sni'] = sni;
      if ('${copy['host'] ?? ''}'.trim().isEmpty) copy['host'] = sni;
      return 'vmess://${base64.encode(utf8.encode(jsonEncode(copy)))}';
    }
    if (scheme != 'vless' && scheme != 'trojan') return null;
    final uri = Uri.parse(t.split('#').first);
    final q = Map<String, String>.from(uri.queryParameters);
    final keys = q.keys.map((k) => k.toLowerCase()).toSet();
    if (!keys.contains('sni') && !keys.contains('servername') && !keys.contains('peer')) q['sni'] = sni;
    final type = (q['type'] ?? '').toLowerCase();
    if (!keys.contains('host') && const {'ws', 'httpupgrade', 'xhttp', 'http', 'h2'}.contains(type)) q['host'] = sni;
    final out = uri.replace(host: ip, queryParameters: q.isEmpty ? null : q);
    return '$out#${Uri.encodeComponent(name)}';
  } catch (_) {
    return null;
  }
}
