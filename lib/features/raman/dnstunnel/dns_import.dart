import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/router/go_router/go_router_notifier.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_links.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_tunnel_controller.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_tunnel_strings.dart';
import 'package:hiddify/utils/link_parsers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// soar:// and cottendns:// links in the add profile sheet (Raman VPN 1.8.1): they go to the
/// "DNS قطعی" tab's config store, not to the profiles.

final _dnsScheme = RegExp(r'(soar|cottendns)://[A-Za-z0-9_\-+/=]*', caseSensitive: false);

/// What is left of a text once its DNS links are taken out counts as a normal import only when it
/// still looks like a config or a link; a label or an emoji around a copied link does not.
final _normalContent = RegExp(r'[a-z][a-z0-9+.\-]*://|^\s*\{|\[Interface\]|proxies:|outbounds', caseSensitive: false);

/// Shows "N کانفیگ DNS اضافه شد" with a button to the DNS tab. Made while [ref] is still usable,
/// so it can be called after the add profile sheet is gone.
void Function(int added) dnsAddedToaster(WidgetRef ref) {
  final s = ref.read(dnsTunnelStringsProvider);
  final router = ref.read(goRouterNotiferProvider);
  final notification = ref.read(inAppNotificationControllerProvider);
  return (added) => notification.showSuccessToast(
    added > 0 ? s.dnsAdded(added) : s.dnsAlreadySaved,
    action: (label: s.openTab, onPressed: () => router.goNamed('ramanTools', queryParameters: const {'tab': 'dns'})),
  );
}

/// For the clipboard, QR code and file imports: takes the soar:// / cottendns:// links out of
/// [text] into the DNS tab. [rest] is what is left for the normal import, null when nothing is
/// (the sheet is then closed here and the toast shown); [dnsAdded] is set when DNS configs were
/// found next to normal content, for the caller to show after its import. A text without such
/// links comes back unchanged.
Future<({String? rest, int? dnsAdded})> routeDnsLinks(BuildContext context, WidgetRef ref, String text) async {
  var source = text;
  if (!_dnsScheme.hasMatch(source)) {
    // a base64 subscription text can carry them too
    final trimmed = text.trim();
    final decoded = safeDecodeBase64(trimmed);
    if (decoded == trimmed || !_dnsScheme.hasMatch(decoded)) return (rest: text, dnsAdded: null);
    source = decoded;
  }
  final controller = ref.read(dnsTunnelControllerProvider);
  final toast = dnsAddedToaster(ref);
  final found = extractDnsConfigs(source).length;
  final rest = source.replaceAll(_dnsScheme, '').trim();
  if (_normalContent.hasMatch(rest)) {
    // both kinds: the DNS ones here, the rest the usual way
    if (found == 0) return (rest: rest, dnsAdded: null);
    return (rest: rest, dnsAdded: await controller.addFromText(source));
  }
  if (found == 0) {
    ref.read(inAppNotificationControllerProvider).showErrorToast(ref.read(dnsTunnelStringsProvider).nothingToAdd);
    return (rest: null, dnsAdded: null);
  }
  final added = await controller.addFromText(source);
  if (context.mounted && context.canPop()) context.pop();
  toast(added);
  return (rest: null, dnsAdded: null);
}

/// The sheet's «کانفیگ DNS» button: a dialog to paste one or more links.
Future<void> showAddDnsDialog(BuildContext context, WidgetRef ref) async {
  final toast = dnsAddedToaster(ref);
  final added = await showDialog<int>(context: context, builder: (_) => const _AddDnsDialog());
  if (added == null) return;
  if (context.mounted && context.canPop()) context.pop();
  toast(added);
}

class _AddDnsDialog extends ConsumerStatefulWidget {
  const _AddDnsDialog();

  @override
  ConsumerState<_AddDnsDialog> createState() => _AddDnsDialogState();
}

class _AddDnsDialogState extends ConsumerState<_AddDnsDialog> {
  final _ctl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty) return;
    final now = _ctl.text.trim();
    _ctl.text = now.isEmpty ? text : '$now\n$text';
    setState(() => _error = null);
  }

  Future<void> _add() async {
    final s = ref.read(dnsTunnelStringsProvider);
    var text = _ctl.text;
    if (!_dnsScheme.hasMatch(text)) text = safeDecodeBase64(text.trim());
    if (extractDnsConfigs(text).isEmpty) {
      setState(() => _error = s.nothingToAdd);
      return;
    }
    setState(() => _busy = true);
    final added = await ref.read(dnsTunnelControllerProvider).addFromText(text);
    if (mounted) Navigator.of(context).pop(added);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(dnsTunnelStringsProvider);
    return AlertDialog(
      title: Text(s.sheetTitle),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: _ctl,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          textDirection: TextDirection.ltr,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.multiline,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            hintText: s.sheetHint,
            errorText: _error,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: s.pasteClipboard,
              icon: const Icon(Icons.content_paste_rounded),
              onPressed: _paste,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.cancel)),
        FilledButton(onPressed: _busy ? null : _add, child: Text(s.add)),
      ],
    );
  }
}
