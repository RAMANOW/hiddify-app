import 'dart:convert';

/// The DNS-tunnel engines of the "DNS قطعی" tab.
enum DnsEngine {
  /// Soar (getlantern/soar, Apache-2.0): soar:// links.
  soar,

  /// CottenDNS (TaJirax, MIT): cottendns:// links.
  cotten,

  /// dnstt (David Fifield, public domain): dnstt:// and dnst://…/dnstt/socks links, or by hand.
  dnstt,

  /// Slipstream (EndPositive, Apache-2.0): slipstream:// and dnst://…/slipstream/socks links, or by hand.
  slipstream,

  /// MasterDnsVPN (Amin Mahmoudi, MIT): masterdns:// and dnst://…/masterdns/socks links.
  masterdns;

  String get label => switch (this) {
    DnsEngine.soar => 'Soar',
    DnsEngine.cotten => 'CottenDNS',
    DnsEngine.dnstt => 'dnstt',
    DnsEngine.slipstream => 'Slipstream',
    DnsEngine.masterdns => 'MasterDnsVPN',
  };

  /// The engine's local SOCKS5 port on 127.0.0.1 (DnsTunnelCore.kt; its test runs on port + 1).
  int get port => switch (this) {
    DnsEngine.soar || DnsEngine.cotten => 18096,
    DnsEngine.dnstt => 18098,
    DnsEngine.slipstream => 18100,
    DnsEngine.masterdns => 18102,
  };

  /// No public servers are known for it: it works only with the user's own server.
  bool get needsOwnServer => this == DnsEngine.slipstream;
}

/// One config. soar:// / cottendns:// / masterdns:// links are base64url JSON
/// `{"profile":{...},"schema":"whitedns.profile","version":1}`; the profile carries the server
/// (domain + public_key for Soar, domain + encryption_key + encryption_method for CottenDNS and
/// MasterDnsVPN), the resolvers, and for Soar its tuning (soarSettings). dnstt and Slipstream
/// configs (1.8.2, from dnstt://, slipstream://, dnst:// or the form) are kept in the same shape:
/// server.domain (+ server.public_key for dnstt), an optional `resolver` (dnstt: a DoH URL,
/// tls://host or IP[:port]) or `resolvers` (Slipstream), and an optional SOCKS5 login `socks`.
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

  /// dnstt's own resolver, if the config has one.
  String get resolver => (profile['resolver'] as String? ?? '').trim();

  /// The SOCKS5 login of the server's proxy, if the link has one.
  ({String user, String password})? get socksLogin {
    final s = profile['socks'];
    if (s is! Map) return null;
    final user = s['user'] as String? ?? '';
    if (user.isEmpty) return null;
    return (user: user, password: s['password'] as String? ?? '');
  }

  String get _secret => switch (engine) {
    DnsEngine.soar => server['public_key'] as String? ?? '',
    DnsEngine.dnstt => (server['public_key'] as String? ?? '').toLowerCase(),
    DnsEngine.cotten || DnsEngine.masterdns => server['encryption_key'] as String? ?? '',
    DnsEngine.slipstream => '',
  };

  /// Two links for the same server and key are the same config.
  String get key => '${engine.name}|${domain.toLowerCase()}|$_secret';
}

/// base64url JSON links (whitedns profile shape). 1.9: stormdns:// (StormDNS, a MasterDnsVPN fork
/// with the same config: domain + encryption key + method) is read as a MasterDnsVPN config.
final _linkRe = RegExp(r'(soar|cottendns|masterdns|stormdns)://([A-Za-z0-9_\-+/=]{16,})', caseSensitive: false);

/// URL-shaped links (1.8.2): dnstt://, slipstream:// and dnst:// (net2share/dnst-url-spec, both forms)
final _urlLinkRe = RegExp(r'''(dnstt|dnst|slipstream)://[^\s"'<>`]+''', caseSensitive: false);

/// Every scheme the tab takes (for the add profile sheet's routing).
final dnsLinkSchemeRe = RegExp(
  r'''(?:soar|cottendns|masterdns|stormdns)://[A-Za-z0-9_\-+/=]*|(?:dnstt|dnst|slipstream)://[^\s"'<>`]*''',
  caseSensitive: false,
);

final _host = RegExp(r'^[A-Za-z0-9.-]{3,253}$');
final _secretRe = RegExp(r'^[A-Za-z0-9+/=_-]{16,256}$');

/// 1.9: MasterDnsVPN / StormDNS / CottenDNS encryption keys are free text in some channels' links
/// ("…--->@channel"): any printable ASCII but space, quote and backslash (safe in the TOML file).
final _textSecretRe = RegExp(r'^[!#-\[\]-~]{16,256}$');
final _hexKey = RegExp(r'^[0-9A-Fa-f]{64}$');
final _resolverEntry = RegExp(r'^(\d{1,3}(\.\d{1,3}){3}(:\d{1,5})?|\[[0-9A-Fa-f:.]+\](:\d{1,5})?|[0-9A-Fa-f.]*:[0-9A-Fa-f:.]*)$');
final _dnsttResolver = RegExp(r'^(https://[A-Za-z0-9.\-\[\]:]+(/\S*)?|tls://[A-Za-z0-9.-]+(:\d{1,5})?|(udp://)?[0-9A-Fa-f.:\[\]]{2,60})$');

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

/// A config from one link, or null when it is not a usable DNS-tunnel link.
DnsTunnelConfig? parseDnsLink(String link) {
  final t = link.trim();
  final m = _linkRe.firstMatch(t);
  if (m != null && m.start == 0) {
    final scheme = m.group(1)!.toLowerCase();
    final j = _decodeJson(m.group(2)!);
    final profile = (j?['profile'] as Map?)?.cast<String, dynamic>();
    if (profile == null) return null;
    final engine = switch (scheme) {
      'soar' => DnsEngine.soar,
      'masterdns' || 'stormdns' => DnsEngine.masterdns,
      _ => DnsEngine.cotten,
    };
    return _checked(DnsTunnelConfig._('$scheme://${m.group(2)}', engine, profile));
  }
  final u = _urlLinkRe.firstMatch(t);
  if (u == null || u.start != 0) return null;
  return _parseUrlLink(_trimTail(u.group(0)!));
}

DnsTunnelConfig? _checked(DnsTunnelConfig c) {
  if (!_host.hasMatch(c.domain)) return null;
  switch (c.engine) {
    case DnsEngine.dnstt:
      if (!_hexKey.hasMatch(c._secret)) return null;
      if (c.resolver.isNotEmpty && !_dnsttResolver.hasMatch(c.resolver)) return null;
    case DnsEngine.slipstream:
      break;
    case DnsEngine.soar:
      if (!_secretRe.hasMatch(c._secret.trim())) return null;
    case DnsEngine.cotten:
    case DnsEngine.masterdns:
      if (!_textSecretRe.hasMatch(c._secret.trim())) return null;
  }
  return c;
}

/// Punctuation a link copied from a sentence often ends with.
String _trimTail(String s) => s.replaceFirst(RegExp(r'''[.,;:!?)\]}'"»،]+$'''), '');

String? _str(Object? v) {
  final s = v is String ? v.trim() : (v is num ? v.toString() : null);
  return s == null || s.isEmpty ? null : s;
}

Map<String, dynamic>? _socks(String? user, String? password) =>
    user == null ? null : {'user': user, 'password': password ?? ''};

List<String> _resolverList(String? s) => (s ?? '')
    .split(RegExp(r'[\s,;]+'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty && _resolverEntry.hasMatch(e))
    .toSet()
    .toList();

Map<String, dynamic> _profile(String? name, Map<String, dynamic> server, Map<String, dynamic>? socks) => {
  if (name != null) 'name': name,
  'server': server,
  if (socks != null) 'socks': socks,
};

/// dnstt:// (Raman's own form), slipstream:// (Raman's own form) and dnst:// links.
///  - dnstt://DOMAIN?pubkey=HEX[&resolver=URL|tls://HOST|IP[:port]][&doh=URL|&dot=HOST:PORT|&udp=IP:PORT][&user=&password=]#NAME
///    (also dnstt://PUBKEY@DOMAIN…)
///  - slipstream://DOMAIN[?resolver=IP,IP…][&user=&password=]#NAME
///  - dnst://DOMAIN/TRANSPORT/socks?params#TAG or dnst://BASE64URL-JSON (net2share/dnst-url-spec
///    1.0); transports dnstt, slipstream and masterdns with a SOCKS5 backend only.
DnsTunnelConfig? _parseUrlLink(String link) {
  final schemeEnd = link.indexOf('://');
  final scheme = link.substring(0, schemeEnd).toLowerCase();
  final after = link.substring(schemeEnd + 3);
  if (scheme == 'dnst' && !after.contains('/')) return _parseDnstJson(link, after);
  final Uri uri;
  try {
    uri = Uri.parse(link);
  } catch (_) {
    return null;
  }
  final q = uri.queryParameters;
  String? name;
  try {
    name = _str(Uri.decodeComponent(uri.fragment));
  } catch (_) {
    name = _str(uri.fragment);
  }
  final domain = uri.host.trim().replaceFirst(RegExp(r'\.$'), '');
  final login = _socks(_str(q['user']), _str(q['password']));
  final server = <String, dynamic>{'domain': domain};
  final profile = _profile(name, server, login);
  final DnsEngine engine;
  switch (scheme) {
    case 'dnstt':
      engine = DnsEngine.dnstt;
      server['public_key'] = _str(q['pubkey']) ?? _str(uri.userInfo) ?? '';
      final dot = _str(q['dot']);
      final res = _str(q['resolver']) ?? _str(q['doh']) ?? (dot == null ? null : 'tls://$dot') ?? _str(q['udp']);
      if (res != null) profile['resolver'] = res;
    case 'slipstream':
      engine = DnsEngine.slipstream;
      final rs = _resolverList(q['resolver'] ?? q['resolvers']);
      if (rs.isNotEmpty) profile['resolvers'] = rs;
    default: // dnst
      final seg = uri.pathSegments.where((e) => e.isNotEmpty).toList();
      if (seg.length < 2 || seg[1].toLowerCase() != 'socks') return null;
      switch (seg[0].toLowerCase()) {
        case 'dnstt':
          engine = DnsEngine.dnstt;
          server['public_key'] = _str(q['pubkey']) ?? '';
        case 'slipstream':
          engine = DnsEngine.slipstream;
        case 'masterdns':
          engine = DnsEngine.masterdns;
          server['encryption_key'] = _str(q['mkey']) ?? '';
          server['encryption_method'] = int.tryParse(q['encryption'] ?? '') ?? 5;
        default:
          return null;
      }
  }
  return _checked(DnsTunnelConfig._(link, engine, profile));
}

DnsTunnelConfig? _parseDnstJson(String link, String payload) {
  final j = _decodeJson(payload);
  if (j == null) return null;
  final t = (j['transport'] as Map?)?.cast<String, dynamic>();
  final b = (j['backend'] as Map?)?.cast<String, dynamic>();
  if (t == null || (b?['type'] as String? ?? 'socks').toLowerCase() != 'socks') return null;
  final server = <String, dynamic>{'domain': _str(t['domain']) ?? ''};
  final DnsEngine engine;
  switch ((t['type'] as String? ?? '').toLowerCase()) {
    case 'dnstt':
      engine = DnsEngine.dnstt;
      server['public_key'] = _str(t['pubkey']) ?? '';
    case 'slipstream':
      engine = DnsEngine.slipstream;
    case 'masterdns':
      engine = DnsEngine.masterdns;
      server['encryption_key'] = _str(t['mkey']) ?? '';
      server['encryption_method'] = (t['encryption'] as num?)?.toInt() ?? 5;
    default:
      return null;
  }
  final profile = _profile(_str(j['tag']), server, _socks(_str(b?['user']), _str(b?['password'])));
  return _checked(DnsTunnelConfig._(link, engine, profile));
}

/// A dnstt:// link for a dnstt server typed into the form.
String dnsttLink({required String domain, required String pubkey, String resolver = '', String name = ''}) => Uri(
  scheme: 'dnstt',
  host: domain.trim(),
  queryParameters: {'pubkey': pubkey.trim().toLowerCase(), if (resolver.trim().isNotEmpty) 'resolver': resolver.trim()},
  fragment: name.trim().isEmpty ? null : name.trim(),
).toString();

/// A slipstream:// link for a Slipstream server typed into the form.
String slipstreamLink({required String domain, String resolvers = '', String name = ''}) {
  final rs = _resolverList(resolvers);
  return Uri(
    scheme: 'slipstream',
    host: domain.trim(),
    queryParameters: rs.isEmpty ? null : {'resolver': rs.join(',')},
    fragment: name.trim().isEmpty ? null : name.trim(),
  ).toString();
}

/// dnstt-client command lines in a text, as servers are often posted:
/// `dnstt-client [-doh URL|-dot ADDR|-udp ADDR] -pubkey HEX DOMAIN 127.0.0.1:PORT`.
List<DnsTunnelConfig> _dnsttCommands(String text) {
  final out = <DnsTunnelConfig>[];
  for (final line in text.split('\n')) {
    final i = line.indexOf('dnstt-client');
    if (i < 0) continue;
    final tok = line.substring(i).trim().split(RegExp(r'\s+')).skip(1).toList();
    String? key;
    String? res;
    final pos = <String>[];
    for (var k = 0; k < tok.length; k++) {
      final a = tok[k];
      final next = k + 1 < tok.length ? tok[k + 1] : null;
      if (a == '-pubkey' && next != null) {
        key = next;
        k++;
      } else if ((a == '-doh' || a == '-dot' || a == '-udp') && next != null) {
        res = a == '-dot' ? 'tls://$next' : next;
        k++;
      } else if (a.startsWith('-')) {
        // another flag (-pubkey-file FILE, -utls X): skip its value
        if (next != null && !next.startsWith('-')) k++;
      } else {
        pos.add(a);
      }
    }
    if (key == null || pos.isEmpty) continue;
    final c = parseDnsLink(dnsttLink(domain: pos.first.replaceAll('[.]', '.'), pubkey: key, resolver: res ?? ''));
    if (c != null) out.add(c);
  }
  return out;
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

/// Every distinct DNS-tunnel config in [text] (HTML or plain), parsed: soar://, cottendns://,
/// masterdns://, dnstt://, slipstream://, dnst:// links and dnstt-client command lines. Invalid
/// ones are skipped, duplicates (same engine, server and key) kept once.
List<DnsTunnelConfig> extractDnsConfigs(String text) {
  final seen = <String>{};
  final out = <DnsTunnelConfig>[];
  // the tag-stripped text first: a link inside HTML has &amp; for its &. 1.9: links posted with
  // no space between them (…fQstormdns://…) are split first: a scheme name is made of base64
  // letters and would otherwise be read as the end of the link before it
  for (final source in [htmlToText(text), text].map(splitGluedDnsLinks)) {
    for (final m in [..._linkRe.allMatches(source), ..._urlLinkRe.allMatches(source)]) {
      final c = parseDnsLink(m.group(0)!);
      if (c != null && seen.add(c.key)) out.add(c);
    }
    for (final c in _dnsttCommands(source)) {
      if (seen.add(c.key)) out.add(c);
    }
  }
  return out;
}

final _gluedRe = RegExp(r'(?<=[A-Za-z0-9_\-+/=])(soar|cottendns|masterdns|stormdns)://', caseSensitive: false);

/// [text] with a space put before every base64-JSON DNS link that follows another one directly.
String splitGluedDnsLinks(String text) => text.replaceAllMapped(_gluedRe, (m) => ' ${m.group(0)}');

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
