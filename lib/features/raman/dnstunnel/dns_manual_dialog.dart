import 'package:flutter/material.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_links.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_tunnel_strings.dart';

enum _Kind { link, dnstt, slipstream }

final _domainRe = RegExp(r'^[A-Za-z0-9.-]{3,253}$');
final _hexRe = RegExp(r'^[0-9A-Fa-f]{64}$');

/// The "DNS قطعی" tab's «افزودن دستی» (1.8.2): a pasted link, or a dnstt / Slipstream server typed
/// in (tunnel domain, dnstt's public key, an optional resolver). Returns the text to add (the link,
/// or the dnstt:// / slipstream:// link made from the fields), null when cancelled.
Future<String?> showDnsManualDialog(BuildContext context, DnsTunnelStrings s) =>
    showDialog<String>(context: context, builder: (_) => _ManualDialog(s));

class _ManualDialog extends StatefulWidget {
  const _ManualDialog(this.s);

  final DnsTunnelStrings s;

  @override
  State<_ManualDialog> createState() => _ManualDialogState();
}

class _ManualDialogState extends State<_ManualDialog> {
  var _kind = _Kind.link;
  final _link = TextEditingController();
  final _domain = TextEditingController();
  final _key = TextEditingController();
  final _resolver = TextEditingController();
  final _name = TextEditingController();
  String? _domainError;
  String? _keyError;
  String? _resolverError;
  String? _linkError;

  @override
  void dispose() {
    for (final c in [_link, _domain, _key, _resolver, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final s = widget.s;
    if (_kind == _Kind.link) {
      if (_link.text.trim().isEmpty) {
        setState(() => _linkError = s.nothingToAdd);
        return;
      }
      Navigator.of(context).pop(_link.text);
      return;
    }
    final domain = _domain.text.trim().replaceFirst(RegExp(r'\.$'), '');
    final key = _key.text.trim();
    setState(() {
      _domainError = _domainRe.hasMatch(domain) ? null : s.formBadDomain;
      _keyError = _kind == _Kind.dnstt && !_hexRe.hasMatch(key) ? s.formBadKey : null;
      _resolverError = null;
    });
    if (_domainError != null || _keyError != null) return;
    final link = _kind == _Kind.dnstt
        ? dnsttLink(domain: domain, pubkey: key, resolver: _resolver.text, name: _name.text)
        : slipstreamLink(domain: domain, resolvers: _resolver.text, name: _name.text);
    if (parseDnsLink(link) == null) {
      setState(() => _resolverError = s.formBadResolver);
      return;
    }
    Navigator.of(context).pop(link);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final theme = Theme.of(context);
    const ltr = TextDirection.ltr;
    InputDecoration deco(String label, {String? error, String? helper}) => InputDecoration(
      labelText: label,
      errorText: error,
      helperText: helper,
      helperMaxLines: 4,
      border: const OutlineInputBorder(),
    );
    final engine = switch (_kind) {
      _Kind.dnstt => 'dnstt',
      _Kind.slipstream => 'slipstream',
      _Kind.link => '',
    };
    return AlertDialog(
      title: Text(s.addManual),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_Kind>(
                segments: [
                  ButtonSegment(value: _Kind.link, label: Text(s.formLink)),
                  const ButtonSegment(value: _Kind.dnstt, label: Text('dnstt')),
                  const ButtonSegment(value: _Kind.slipstream, label: Text('Slipstream')),
                ],
                selected: {_kind},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _kind = v.first),
              ),
              const SizedBox(height: 12),
              if (_kind == _Kind.link)
                TextField(
                  controller: _link,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 8,
                  textDirection: ltr,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(hintText: s.addHint, hintMaxLines: 4, errorText: _linkError, border: const OutlineInputBorder()),
                )
              else ...[
                Text(s.engineHint(engine), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                const SizedBox(height: 12),
                TextField(
                  controller: _domain,
                  textDirection: ltr,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.url,
                  decoration: deco(s.formDomain, error: _domainError),
                ),
                if (_kind == _Kind.dnstt) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _key,
                    textDirection: ltr,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: deco(s.formPubkey, error: _keyError),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _resolver,
                  textDirection: ltr,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.url,
                  decoration: deco(
                    s.resolvers,
                    helper: _kind == _Kind.dnstt ? s.formDnsttResolver : s.formSlipResolvers,
                    error: _resolverError,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: _name, decoration: deco(s.formName)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.cancel)),
        FilledButton(onPressed: _submit, child: Text(s.add)),
      ],
    );
  }
}
