import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/router/go_router/go_router_notifier.dart';
import 'package:hiddify/features/raman/relay/relay_controller.dart';
import 'package:hiddify/features/raman/relay/relay_strings.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Raman VPN 1.8.1: Google Relay settings pasted in the add profile sheet, as people share them:
/// Deployment IDs / /exec links with an AUTH_KEY line, or an mhrv-rs config.json
/// (script_ids, auth_key, google_ip, front_domain).
class RelayImport {
  const RelayImport(this.ids, this.authKey, this.googleIp, this.front);

  final List<String> ids;
  final String? authKey;
  final String? googleIp;
  final String? front;
}

const _placeholderKey = 'CHANGE_ME_TO_A_STRONG_SECRET';

String? _str(Object? v) {
  final s = v is String ? v.trim() : null;
  return s == null || s.isEmpty ? null : s;
}

RelayImport parseRelayText(String text) {
  // an mhrv-rs config.json (or any JSON with those keys)
  final open = text.indexOf('{');
  final close = text.lastIndexOf('}');
  if (open >= 0 && close > open) {
    try {
      final j = jsonDecode(text.substring(open, close + 1));
      if (j is Map<String, dynamic>) {
        final rawIds = j['script_ids'] ?? j['script_id'] ?? j['deployment_ids'] ?? j['deployment_id'];
        final ids = rawIds is List
            ? rawIds.whereType<String>().map(relayDeploymentId).whereType<String>().toSet().toList()
            : relayDeploymentIds(rawIds is String ? rawIds : '');
        var key = _str(j['auth_key'] ?? j['authKey'] ?? j['AUTH_KEY']);
        if (key == _placeholderKey) key = null;
        if (ids.isNotEmpty || key != null) {
          return RelayImport(ids, key, _str(j['google_ip']), _str(j['front_domain']));
        }
      }
    } catch (_) {
      // not JSON: read it as text
    }
  }
  var rest = text;
  String? take(RegExp re) {
    final m = re.firstMatch(rest);
    if (m == null) return null;
    rest = rest.replaceRange(m.start, m.end, ' ');
    return m.group(1);
  }

  var key = take(RegExp(r'''(?:AUTH_KEY|auth[_ ]?key|authKey)\s*[:=]?\s*["']?([A-Za-z0-9_\-+/=.!@#$%^&*]{4,})["']?''', caseSensitive: false));
  if (key == _placeholderKey) key = null;
  final ip = take(RegExp(r'''google[_ ]?ip\s*[:=]?\s*["']?(\d{1,3}(?:\.\d{1,3}){3})''', caseSensitive: false));
  final front = take(RegExp(r'''front[_ ]?domain\s*[:=]?\s*["']?([A-Za-z0-9.\-]{4,253})''', caseSensitive: false));
  final ids = relayDeploymentIds(rest).where((id) => id != key && id != _placeholderKey).toList();
  return RelayImport(ids, key, ip, front);
}

/// Shows "Relay settings saved" with a button to the relay tab; made while [ref] is usable.
void Function(int ids) relaySavedToaster(WidgetRef ref) {
  final s = ref.read(relayStringsProvider);
  final router = ref.read(goRouterNotiferProvider);
  final notification = ref.read(inAppNotificationControllerProvider);
  return (ids) => notification.showSuccessToast(
    s.savedN(ids),
    action: (label: s.openTab, onPressed: () => router.goNamed('ramanTools', queryParameters: const {'tab': 'relay'})),
  );
}

/// The sheet's «کانفیگ رله» button.
Future<void> showAddRelayDialog(BuildContext context, WidgetRef ref) async {
  final toast = relaySavedToaster(ref);
  final ids = await showDialog<int>(context: context, builder: (_) => const _AddRelayDialog());
  if (ids == null) return;
  if (context.mounted && context.canPop()) context.pop();
  toast(ids);
}

class _AddRelayDialog extends ConsumerStatefulWidget {
  const _AddRelayDialog();

  @override
  ConsumerState<_AddRelayDialog> createState() => _AddRelayDialogState();
}

class _AddRelayDialogState extends ConsumerState<_AddRelayDialog> {
  final _ids = TextEditingController();
  final _key = TextEditingController();
  String? _ip;
  String? _front;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ids.dispose();
    _key.dispose();
    super.dispose();
  }

  void _fill(String text) {
    final r = parseRelayText(text);
    if (r.ids.isEmpty && r.authKey == null) {
      _ids.text = text.trim();
    } else {
      if (r.ids.isNotEmpty) _ids.text = r.ids.join('\n');
      if (r.authKey != null) _key.text = r.authKey!;
    }
    _ip = r.googleIp ?? _ip;
    _front = r.front ?? _front;
    setState(() => _error = null);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isNotEmpty) _fill(text);
  }

  Future<void> _save() async {
    final s = ref.read(relayStringsProvider);
    // a whole config pasted straight into the field is read the same way
    final r = parseRelayText(_ids.text);
    final key = _key.text.trim().isNotEmpty ? _key.text.trim() : r.authKey;
    if (r.ids.isEmpty) {
      setState(() => _error = s.noIds);
      return;
    }
    setState(() => _busy = true);
    final saved = ref.read(RelayPrefs.deployments);
    final savedKey = ref.read(RelayPrefs.authKey).trim();
    // a new AUTH_KEY belongs to a new set of deployments; the same (or none) adds to the saved ones
    final ids = (key != null && key != savedKey) ? r.ids : {...relayDeploymentIds(saved), ...r.ids}.toList();
    await ref.read(RelayPrefs.deployments.notifier).update(ids.join('\n'));
    if (key != null) await ref.read(RelayPrefs.authKey.notifier).update(key);
    final ip = r.googleIp ?? _ip;
    if (ip != null && relayValidIp(ip)) await ref.read(RelayPrefs.googleIp.notifier).update(ip);
    final front = r.front ?? _front;
    if (front != null) await ref.read(RelayPrefs.frontDomain.notifier).update(front);
    final controller = ref.read(relayControllerProvider);
    if (controller.inUse) await controller.restartIfRunning();
    if (mounted) Navigator.of(context).pop(ids.length);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(relayStringsProvider);
    return AlertDialog(
      title: Text(s.sheetTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.sheetHint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                controller: _ids,
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
                  labelText: s.ids,
                  errorText: _error,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: s.pasteClipboard,
                    icon: const Icon(Icons.content_paste_rounded),
                    onPressed: _paste,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _key,
                textDirection: TextDirection.ltr,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: s.authKey, border: const OutlineInputBorder()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.cancel)),
        FilledButton(onPressed: _busy ? null : _save, child: Text(s.save)),
      ],
    );
  }
}
