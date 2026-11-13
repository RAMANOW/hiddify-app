import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// How a resolver is reached.
enum DnsTransport { udp, tcp, doh }

/// One public DNS resolver Raman VPN can test and pick.
class DnsServer {
  const DnsServer({
    required this.name,
    required this.host,
    this.transport = DnsTransport.udp,
    this.dohUrl,
    this.domestic = false,
  });

  final String name;

  /// The IP (or, for DoH, the host of [dohUrl]).
  final String host;
  final DnsTransport transport;
  final String? dohUrl;

  /// An Iranian resolver: good for direct (domestic) traffic, never used as the remote DNS.
  final bool domestic;

  /// The address in the form the core's DNS settings take.
  String get address => switch (transport) {
    DnsTransport.udp => 'udp://$host',
    DnsTransport.tcp => 'tcp://$host',
    DnsTransport.doh => dohUrl!,
  };

  /// The address to use as the remote DNS (through the proxy): TCP is more reliable than UDP there.
  String get remoteAddress => transport == DnsTransport.udp ? 'tcp://$host' : address;

  String get label => switch (transport) {
    DnsTransport.udp => host,
    DnsTransport.tcp => 'tcp://$host',
    DnsTransport.doh => dohUrl!,
  };
}

/// The built-in list of resolvers.
abstract final class RamanDnsServers {
  static const all = <DnsServer>[
    // international
    DnsServer(name: 'Cloudflare', host: '1.1.1.1'),
    DnsServer(name: 'Cloudflare', host: '1.0.0.1'),
    DnsServer(name: 'Google', host: '8.8.8.8'),
    DnsServer(name: 'Google', host: '8.8.4.4'),
    DnsServer(name: 'Quad9', host: '9.9.9.9'),
    DnsServer(name: 'AdGuard', host: '94.140.14.14'),
    DnsServer(name: 'OpenDNS', host: '208.67.222.222'),
    // DNS over HTTPS
    DnsServer(name: 'Cloudflare DoH', host: '1.1.1.1', transport: DnsTransport.doh, dohUrl: 'https://1.1.1.1/dns-query'),
    DnsServer(name: 'Google DoH', host: '8.8.8.8', transport: DnsTransport.doh, dohUrl: 'https://8.8.8.8/dns-query'),
    DnsServer(
      name: 'AdGuard DoH',
      host: 'dns.adguard-dns.com',
      transport: DnsTransport.doh,
      dohUrl: 'https://dns.adguard-dns.com/dns-query',
    ),
    // Iranian (domestic) resolvers
    DnsServer(name: 'Shecan', host: '178.22.122.100', domestic: true),
    DnsServer(name: 'Shecan', host: '185.51.200.2', domestic: true),
    DnsServer(name: 'Electro', host: '78.157.42.100', domestic: true),
    DnsServer(name: 'Electro', host: '78.157.42.101', domestic: true),
    DnsServer(name: 'Begzar', host: '185.55.226.26', domestic: true),
    DnsServer(name: 'Begzar', host: '185.55.225.25', domestic: true),
    DnsServer(name: 'Radar', host: '10.202.10.10', domestic: true),
    DnsServer(name: 'Radar', host: '10.202.10.11', domestic: true),
  ];
}

/// The outcome of testing one resolver.
class DnsProbeResult {
  const DnsProbeResult({required this.server, this.latencyMs, this.poisoned = false, this.error});

  final DnsServer server;

  /// Best round trip of the test queries; null when every attempt failed.
  final int? latencyMs;

  /// The resolver answered a blocked name with Iran's filtering address (10.10.34.x).
  final bool poisoned;
  final String? error;

  bool get ok => latencyMs != null;
}

/// Sends real DNS queries (UDP, TCP or DoH) and times them.
abstract final class DnsProbe {
  static const _testDomain = 'www.google.com';

  /// A name that is filtered in Iran, to spot resolvers that return the block page address.
  static const _blockedDomain = 'www.youtube.com';
  static const timeout = Duration(milliseconds: 2500);

  static Future<DnsProbeResult> probe(DnsServer server, {int attempts = 3}) async {
    int? best;
    String? error;
    HttpClient? http;
    try {
      if (server.transport == DnsTransport.doh) {
        http = HttpClient()..connectionTimeout = timeout;
      }
      for (var i = 0; i < attempts; i++) {
        try {
          final sw = Stopwatch()..start();
          final ips = await _query(server, _testDomain, http);
          sw.stop();
          if (ips.isEmpty) {
            error = 'empty answer';
            continue;
          }
          final ms = max(1, sw.elapsedMilliseconds);
          if (best == null || ms < best) best = ms;
        } catch (e) {
          error = e.toString();
        }
      }
      var poisoned = false;
      if (best != null) {
        try {
          final ips = await _query(server, _blockedDomain, http);
          poisoned = ips.any((ip) => ip.startsWith('10.10.34.'));
        } catch (_) {}
      }
      return DnsProbeResult(server: server, latencyMs: best, poisoned: poisoned, error: best == null ? error : null);
    } finally {
      http?.close(force: true);
    }
  }

  static Future<List<String>> _query(DnsServer server, String domain, HttpClient? http) {
    final id = Random().nextInt(0xFFFF);
    final packet = buildQuery(domain, id);
    final Future<Uint8List> answer = switch (server.transport) {
      DnsTransport.udp => _udp(server.host, packet),
      DnsTransport.tcp => _tcp(server.host, packet),
      DnsTransport.doh => _doh(http!, server.dohUrl!, packet),
    };
    return answer.timeout(timeout).then((bytes) => parseARecords(bytes, id));
  }

  /// A standard recursive query for the A record of [domain].
  static Uint8List buildQuery(String domain, int id) {
    final b = BytesBuilder();
    b.add([id >> 8 & 0xFF, id & 0xFF, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
    for (final label in domain.split('.')) {
      final bytes = ascii.encode(label);
      b.addByte(bytes.length);
      b.add(bytes);
    }
    b.add([0x00, 0x00, 0x01, 0x00, 0x01]);
    return b.toBytes();
  }

  /// The IPv4 addresses in the answer section; throws on a bad id or an error code.
  static List<String> parseARecords(Uint8List m, int id) {
    if (m.length < 12) throw const FormatException('short answer');
    if ((m[0] << 8 | m[1]) != id) throw const FormatException('wrong id');
    final rcode = m[3] & 0x0F;
    if (rcode != 0) throw FormatException('rcode $rcode');
    final qd = m[4] << 8 | m[5];
    final an = m[6] << 8 | m[7];
    var o = 12;
    int skipName(int from) {
      var p = from;
      while (p < m.length) {
        final len = m[p];
        if (len == 0) return p + 1;
        if (len & 0xC0 == 0xC0) return p + 2;
        p += 1 + len;
      }
      return p;
    }

    for (var i = 0; i < qd; i++) {
      o = skipName(o) + 4;
    }
    final ips = <String>[];
    for (var i = 0; i < an && o < m.length; i++) {
      o = skipName(o);
      if (o + 10 > m.length) break;
      final type = m[o] << 8 | m[o + 1];
      final rdlen = m[o + 8] << 8 | m[o + 9];
      o += 10;
      if (type == 1 && rdlen == 4 && o + 4 <= m.length) {
        ips.add('${m[o]}.${m[o + 1]}.${m[o + 2]}.${m[o + 3]}');
      }
      o += rdlen;
    }
    return ips;
  }

  static Future<Uint8List> _udp(String host, Uint8List packet) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final completer = Completer<Uint8List>();
    final sub = socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final d = socket.receive();
        if (d != null && !completer.isCompleted) completer.complete(d.data);
      }
    });
    try {
      socket.send(packet, InternetAddress(host), 53);
      return await completer.future.timeout(timeout);
    } finally {
      await sub.cancel();
      socket.close();
    }
  }

  static Future<Uint8List> _tcp(String host, Uint8List packet) async {
    final socket = await Socket.connect(host, 53, timeout: timeout);
    try {
      socket.add([packet.length >> 8 & 0xFF, packet.length & 0xFF, ...packet]);
      await socket.flush();
      final buffer = BytesBuilder();
      await for (final chunk in socket.timeout(timeout)) {
        buffer.add(chunk);
        final bytes = buffer.toBytes();
        if (bytes.length >= 2) {
          final len = bytes[0] << 8 | bytes[1];
          if (bytes.length >= len + 2) return Uint8List.fromList(bytes.sublist(2, len + 2));
        }
      }
      throw const SocketException('connection closed');
    } finally {
      socket.destroy();
    }
  }

  static Future<Uint8List> _doh(HttpClient http, String url, Uint8List packet) async {
    final q = base64Url.encode(packet).replaceAll('=', '');
    final uri = Uri.parse('$url?dns=$q');
    final req = await http.getUrl(uri);
    req.headers.set(HttpHeaders.acceptHeader, 'application/dns-message');
    final res = await req.close();
    if (res.statusCode != 200) {
      await res.drain<void>();
      throw HttpException('HTTP ${res.statusCode}');
    }
    final builder = BytesBuilder();
    await for (final chunk in res) {
      builder.add(chunk);
    }
    return builder.toBytes();
  }
}
