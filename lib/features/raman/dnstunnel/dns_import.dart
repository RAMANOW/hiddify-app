import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/router/go_router/go_router_notifier.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_links.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_tunnel_controller.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_tunnel_strings.dart';
import 'package:hiddify/features/raman/telegram/telegram_proxies.dart';
import 'package:hiddify/utils/link_parsers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// DNS-tunnel links in the add profile sheet (Raman VPN 1.8.1; 1.8.2 adds masterdns://, dnstt://,
/// slipstream:// and dnst://): they go to the "DNS قطعی" tab's config store, not to the profiles;
/// Telegram proxy links (tg://proxy, t.me/socks, …) go to the Telegram proxy list.

final _dnsScheme = dnsLinkSchemeRe;

/// What is left of a text once those links are taken out counts as a normal import only when it
/// still looks like a config or a link; a label or an emoji around a copied link does not.
final _normalContent = RegExp(r'[a-z][a-z0-9+.\-]*://|^\s*\{|\[Interface\]|proxies:|outbounds', caseSensitive: false);

bool _hasOurs(String s) => _dnsScheme.hasMatch(s) || telegramLinkRe.hasMatch(s);

/// Shows "N کانفیگ DNS اضافه شد" with a button to the DNS tab. Made while [ref] is still usable,
/// so it can be called after the add profile sheet is gone.
void Function(int added) dnsAddedToaster(WidgetRef ref) {
  final toast = _ramanAddedToaster(ref);
  return (added) => toast(added, null);
}

/// The toast for DNS configs and / or Telegram proxies (null = none of that kind found); its
/// button opens the DNS tab, or the Telegram proxy sheet when only proxies came.
void Function(int? dns, int? tg) _ramanAddedToaster(WidgetRef ref) {
  final s = ref.read(dnsTunnelStringsProvider);
  final tgs = ref.read(telegramStringsProvider);
  final router = ref.read(goRouterNotiferProvider);
  final notification = ref.read(inAppNotificationControllerProvider);
  return (dns, tg) {
    final parts = [
      if (dns != null) dns > 0 ? s.dnsAdded(dns) : s.dnsAlreadySaved,
      if (tg != null) tg > 0 ? tgs.added(tg) : tgs.alreadySaved,
    ];
    notification.showSuccessToast(
      parts.join(' · '),
      action: (
        label: s.openTab,
        onPressed: () => dns != null
            ? router.goNamed('ramanTools', queryParameters: const {'tab': 'dns'})
            : showTelegramProxySheet(),
      ),
    );
  };
}

/// For the clipboard, QR code and file imports: takes the soar:// / cottendns:// links into the DNS
/// tab and the Telegram proxy links into their list. [rest] is what is left for the normal import,
/// null when nothing is (the sheet is then closed here and the toast shown); [after] is the toast
/// for the caller to show after its import when both kinds came together. A text without such
/// links comes back unchanged.
Future<({String? rest, void Function()? after})> routeRamanLinks(BuildContext context, WidgetRef ref, String text) async {
  var source = text;
  if (!_hasOurs(source)) {
    // a base64 subscription text can carry them too
    final trimmed = text.trim();
    final decoded = safeDecodeBase64(trimmed);
    if (decoded == trimmed || !_hasOurs(decoded)) return (rest: text, after: null);
    source = decoded;
  }
  final dns = ref.read(dnsTunnelControllerProvider);
  final tg = ref.read(telegramProxyStoreProvider);
  final toast = _ramanAddedToaster(ref);
  final dnsFound = extractDnsConfigs(source).isNotEmpty;
  final tgFound = extractTelegramProxies(source).isNotEmpty;
  final rest = source.replaceAll(_dnsScheme, '').replaceAll(telegramLinkRe, '').trim();
  final hasNormal = _normalContent.hasMatch(rest);
  if (!dnsFound && !tgFound) {
    if (hasNormal) return (rest: rest, after: null);
    final error = _dnsScheme.hasMatch(source)
        ? ref.read(dnsTunnelStringsProvider).nothingToAdd
        : ref.read(telegramStringsProvider).nothingToAdd;
    ref.read(inAppNotificationControllerProvider).showErrorToast(error);
    return (rest: null, after: null);
  }
  final dnsAdded = dnsFound ? await dns.addFromText(source) : null;
  final tgAdded = tgFound ? await tg.addFromText(source) : null;
  // both kinds: these here, the rest the usual way
  if (hasNormal) return (rest: rest, after: () => toast(dnsAdded, tgAdded));
  if (context.mounted && context.canPop()) context.pop();
  toast(dnsAdded, tgAdded);
  return (rest: null, after: null);
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
