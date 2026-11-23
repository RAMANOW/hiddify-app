import 'dart:convert';

/// The two DNS-tunnel engines of the "DNS قطعی" tab.
enum DnsEngine {
  /// Soar (getlantern/soar, Apache-2.0): soar:// links.
  soar,

  /// CottenDNS (TaJirax, MIT): cottendns:// links.
  cotten;

  String get label => switch (this) {
    DnsEngine.soar => 'Soar',
    DnsEngine.cotten => 'CottenDNS',
  };
}

/// One config from a soar:// or cottendns:// link. The link is base64url JSON
/// `{"profile":{...},"schema":"whitedns.profile","version":1}`; the profile carries the server
/// (domain + public_key for Soar, domain + encryption_key + encryption_method for CottenDNS), the
/// resolvers, and for Soar its tuning (soarSettings).
class DnsTunnelConfig {
  DnsTunnelConfig._(this.link, this.engine, this.profile);

  final String link;
  final DnsEngine engine;
  final Map<String, dynamic> profile;

  Map<String, dynamic> get server => (profile['server'] as Map?)?.cast<String, dynamic>() ?? const {};

  String get domain => (server['domain'] as String? ?? '').trim();

  String get name {
    final n = (profile['name'] as String? ?? '').trim();
    return n.isEmpty ? domain : n;
  }

  List<String> get resolvers =>
      ((profile['resolvers'] as List?) ?? const []).whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  String get _secret => engine == DnsEngine.soar
      ? (server['public_key'] as String? ?? '')
      : (server['encryption_key'] as String? ?? '');

  /// Two links for the same server and key are the same config.
  String get key => '${engine.name}|${domain.toLowerCase()}|$_secret';
}

final _linkRe = RegExp(r'(soar|cottendns)://([A-Za-z0-9_\-+/=]{16,})', caseSensitive: false);
final _host = RegExp(r'^[A-Za-z0-9.-]{3,253}$');
final _secret = RegExp(r'^[A-Za-z0-9+/=_-]{16,256}$');

Map<String, dynamic>? _decodeJson(String payload) {
  var p = payload.trim().replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
  p = p.padRight(p.length + (4 - p.length % 4) % 4, '=');
  try {
    final j = jsonDecode(utf8.decode(base64Url.decode(p)));
    return j is Map<String, dynamic> ? j : null;
  } catch (_) {
    return null;
  }
}

/// A config from one link, or null when it is not a usable soar:// / cottendns:// link.
DnsTunnelConfig? parseDnsLink(String link) {
  final m = _linkRe.firstMatch(link.trim());
  if (m == null) return null;
  final scheme = m.group(1)!.toLowerCase();
  final j = _decodeJson(m.group(2)!);
  final profile = (j?['profile'] as Map?)?.cast<String, dynamic>();
  if (profile == null) return null;
  final engine = scheme == 'soar' ? DnsEngine.soar : DnsEngine.cotten;
  final c = DnsTunnelConfig._('$scheme://${m.group(2)}', engine, profile);
  if (!_host.hasMatch(c.domain)) return null;
  if (!_secret.hasMatch(c._secret.trim())) return null;
  return c;
}

/// Plain text of a Telegram web-preview page (or any HTML): tags dropped, line breaks kept.
String htmlToText(String html) {
  final s = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');
  return s;
}

/// Every distinct soar:// and cottendns:// link in [text] (HTML or plain), parsed; invalid ones
/// are skipped, duplicates (same server and key) kept once.
List<DnsTunnelConfig> extractDnsConfigs(String text) {
  final seen = <String>{};
  final out = <DnsTunnelConfig>[];
  for (final source in [text, htmlToText(text)]) {
    for (final m in _linkRe.allMatches(source)) {
      final c = parseDnsLink(m.group(0)!);
      if (c != null && seen.add(c.key)) out.add(c);
    }
  }
  return out;
}

/// The older-posts cursor of a t.me/s page (`?before=N`), the smallest one on the page.
int? telegramBefore(String html) {
  final ids = RegExp(r'(?:data-before="|[?&]before=)(\d+)')
      .allMatches(html)
      .map((m) => int.tryParse(m.group(1)!))
      .whereType<int>()
      .toList();
  if (ids.isEmpty) return null;
  ids.sort();
  return ids.first;
}
