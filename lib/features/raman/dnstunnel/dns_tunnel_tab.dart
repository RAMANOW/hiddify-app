import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_links.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_tunnel_controller.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_tunnel_strings.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const _green = Color(0xFF16A34A);
const _amber = Color(0xFFD97706);
const _red = Color(0xFFDC2626);

String _two(int v) => v.toString().padLeft(2, '0');
String _when(DateTime t) {
  final l = t.toLocal();
  return '${l.year}-${_two(l.month)}-${_two(l.day)} ${_two(l.hour)}:${_two(l.minute)}';
}

/// Raman tools › DNS قطعی: configs (from the channel, pasted, or typed), resolvers, connect.
class DnsTunnelTab extends HookConsumerWidget {
  const DnsTunnelTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(dnsTunnelStringsProvider);
    final theme = Theme.of(context);
    final controller = ref.read(dnsTunnelControllerProvider);
    final tunnelActive = ref.watch(dnsTunnelActiveProvider);
    ref.watch(dnsTunnelProfileIdProvider);
    ref.watch(dnsTunnelConfigsVersionProvider);
    final selectedKey = ref.watch(DnsTunnelPrefs.selected);
    final useSystem = ref.watch(DnsTunnelPrefs.useSystemDns);
    final useLink = ref.watch(DnsTunnelPrefs.useLinkResolvers);
    final connection = ref.watch(connectionNotifierProvider).valueOrNull ?? const Disconnected();

    final extraCtl = useTextEditingController(text: ref.read(DnsTunnelPrefs.extraResolvers));
    final busy = useState(false);
    final fetching = useState(false);
    final status = useState<Map<String, dynamic>>(const {});
    final systemDns = useState<List<String>>(const []);
    final engines = useState<Map<String, dynamic>>(const {});
    final testing = useState<String?>(null);
    final results = useState<Map<String, String>>(const {});
    final logLines = useState<List<String>>(const []);

    final list = controller.configs();
    final selected = controller.selected;

    void toast(String m, {bool error = false}) {
      final n = ref.read(inAppNotificationControllerProvider);
      error ? n.showErrorToast(m) : n.showInfoToast(m);
    }

    Future<void> refresh() async {
      status.value = await DnsTunnelPlatform.status();
    }

    Future<void> fetch({required bool manual}) async {
      if (fetching.value) return;
      fetching.value = true;
      try {
        final (n, err) = await controller.fetchChannel(openLocalProxy: manual);
        if (!manual) return;
        if (err != null) {
          toast(s.fetchFailed, error: true);
        } else {
          toast(n > 0 ? s.fetched(n) : s.fetchNone, error: n == 0);
        }
      } finally {
        fetching.value = false;
      }
    }

    useEffect(() {
      unawaited(refresh());
      unawaited(DnsTunnelPlatform.systemDns().then((v) => systemDns.value = v));
      unawaited(DnsTunnelPlatform.available().then((v) => engines.value = v));
      // refresh the channel configs when the tab opens, at most every 6 hours, quietly
      final at = controller.fetchedAt;
      if (at == null || DateTime.now().difference(at) > const Duration(hours: 6)) {
        unawaited(fetch(manual: false));
      }
      final timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
      return timer.cancel;
    }, const []);

    String errorText(String code) => switch (code) {
      'config' => s.pickConfig,
      'resolvers' => s.noResolvers,
      'shield' => s.shieldFirst,
      'relay' => s.relayFirst,
      _ when code.startsWith('profile:') => s.profileFailed,
      _ => '${s.startFailed}: ${code.replaceFirst('start:', '')}',
    };

    bool engineIn(DnsEngine e) => engines.value.isEmpty || engines.value[e.name] == true;

    Future<void> onStart() async {
      final c = selected?.config;
      if (c != null && !engineIn(c.engine)) {
        toast(s.engineMissing, error: true);
        return;
      }
      if (controller.isBusy && !tunnelActive) {
        final ok = await ref
            .read(dialogNotifierProvider.notifier)
            .showConfirmation(title: s.busyTitle, message: s.busyBody, positiveBtnTxt: s.yes);
        if (!ok) return;
        await ref.read(connectionNotifierProvider.notifier).abortConnection();
        for (var i = 0; i < 50; i++) {
          final st = ref.read(connectionNotifierProvider).valueOrNull;
          if (st == null || st.isDisconnected) break;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
      busy.value = true;
      try {
        final err = await controller.start();
        if (err != null) toast(errorText(err), error: true);
      } finally {
        busy.value = false;
        await refresh();
      }
    }

    Future<void> onStop() async {
      busy.value = true;
      try {
        final err = await controller.stop();
        if (err != null) toast(errorText(err), error: true);
      } finally {
        busy.value = false;
        await refresh();
      }
    }

    Future<void> onTest(SavedDnsConfig c) async {
      if (testing.value != null) return;
      if (!engineIn(c.config.engine)) {
        results.value = {...results.value, c.config.key: s.engineMissing};
        return;
      }
      testing.value = c.config.key;
      try {
        final (ok, ms, err) = await controller.test(c.config);
        final text = ok ? s.testOk(ms ?? 0) : s.testFail(err == null ? '' : (err == 'resolvers' ? s.noResolvers : err));
        results.value = {...results.value, c.config.key: text};
      } finally {
        testing.value = null;
      }
    }

    Future<void> onPaste() async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final n = await controller.addFromText(data?.text ?? '');
      toast(n > 0 ? s.added(n) : s.nothingToAdd, error: n == 0);
    }

    Future<void> onAddManual() async {
      final ctl = TextEditingController();
      final text = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s.addManual),
          content: TextField(
            controller: ctl,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(hintText: s.addHint, border: const OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.of(context).pop(ctl.text), child: Text(s.add)),
          ],
        ),
      );
      ctl.dispose();
      if (text == null || text.trim().isEmpty) return;
      final n = await controller.addFromText(text);
      toast(n > 0 ? s.added(n) : s.nothingToAdd, error: n == 0);
    }

    final running = status.value['running'] == true;
    final listening = status.value['listening'] == true;
    final percent = (status.value['percent'] as num?)?.toInt();
    final inUse = controller.inUse || running;
    final (String label, Color color) = switch ((running, listening, tunnelActive, connection)) {
      (true, true, true, Connected()) => (s.stateConnected, _green),
      (true, true, true, Disconnected()) => (s.stateNoVpn, _amber),
      (true, true, true, _) => (s.stateConnecting, _amber),
      (true, false, _, _) => (s.stateStarting, _amber),
      _ when busy.value => (s.stateStarting, _amber),
      (false, _, _, _) when controller.inUse => (s.stateEngineDown, _red),
      (true, _, _, _) => (s.stateStarting, _amber),
      _ => (s.stateOff, theme.colorScheme.outline),
    };

    Widget section(String title, IconData icon, {Widget? trailing}) => ListTile(
      leading: Icon(icon),
      title: Text(title, style: theme.textTheme.titleMedium),
      trailing: trailing,
    );
    Widget body(String text, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: color)),
    );
    const ltr = TextDirection.ltr;
    final fetchedAt = controller.fetchedAt;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(s.intro, style: theme.textTheme.bodyMedium),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: color.withValues(alpha: .10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.cell_tower_rounded, color: color),
                    const Gap(8),
                    Expanded(child: Text(label, style: theme.textTheme.titleSmall?.copyWith(color: color))),
                  ],
                ),
                if (selected != null) ...[
                  const Gap(4),
                  Text('${selected.config.name} · ${selected.config.engine.label}', style: theme.textTheme.bodySmall),
                ],
                if (running && !listening && percent != null) ...[
                  const Gap(8),
                  LinearProgressIndicator(value: percent.clamp(0, 100) / 100),
                ],
                const Gap(8),
                if (!inUse)
                  FilledButton.icon(
                    onPressed: busy.value || selected == null ? null : onStart,
                    icon: busy.value
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(s.start),
                  )
                else ...[
                  if (running && listening && tunnelActive && connection is Disconnected)
                    FilledButton.icon(
                      onPressed: busy.value ? null : () => ref.read(connectionNotifierProvider.notifier).toggleConnection(),
                      icon: const Icon(Icons.power_settings_new_rounded),
                      label: Text(s.connectAgain),
                    ),
                  if (!running && !busy.value)
                    FilledButton.icon(
                      onPressed: selected == null ? null : onStart,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(s.start),
                    ),
                  const Gap(8),
                  OutlinedButton.icon(
                    onPressed: onStop,
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(s.stop),
                  ),
                ],
              ],
            ),
          ),
        ),
        body(s.whileOn),
        const Divider(),
        section(s.configs, Icons.list_alt_rounded),
        body(s.saveNow),
        body(fetchedAt == null ? s.neverFetched : s.fetchedAt(_when(fetchedAt)), color: theme.colorScheme.outline),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton.tonalIcon(
                onPressed: fetching.value ? null : () => fetch(manual: true),
                icon: fetching.value
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_download_rounded),
                label: Text(fetching.value ? s.fetching : s.getConfigs),
              ),
              OutlinedButton.icon(onPressed: onPaste, icon: const Icon(Icons.content_paste_rounded), label: Text(s.paste)),
              OutlinedButton.icon(onPressed: onAddManual, icon: const Icon(Icons.add_rounded), label: Text(s.addManual)),
            ],
          ),
        ),
        if (list.isEmpty) body(s.empty),
        for (final c in list)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: c.config.key == (selected?.config.key ?? selectedKey) ? theme.colorScheme.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: inUse ? null : () => controller.select(c),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          c.config.key == selected?.config.key ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const Gap(8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.config.name, textDirection: ltr, style: theme.textTheme.titleSmall),
                              Text(
                                '${c.config.engine.label}${c.manual ? ' · ${s.manualBadge}' : ''}',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: testing.value != null ? null : () => onTest(c),
                          child: testing.value == c.config.key
                              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(s.test),
                        ),
                        IconButton(
                          tooltip: s.delete,
                          onPressed: inUse && c.config.key == selected?.config.key ? null : () => controller.remove(c),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                    if (testing.value == c.config.key) Text(s.testing, style: theme.textTheme.bodySmall),
                    if (results.value[c.config.key] case final r?)
                      Text(r, style: theme.textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          ),
        const Divider(),
        section(s.resolvers, Icons.dns_rounded),
        SwitchListTile(
          title: Text(s.useSystem),
          subtitle: Text(
            s.systemNow(systemDns.value.isEmpty ? s.systemNone : systemDns.value.join(', ')),
            textDirection: systemDns.value.isEmpty ? null : ltr,
          ),
          value: useSystem,
          onChanged: (v) => ref.read(DnsTunnelPrefs.useSystemDns.notifier).update(v),
        ),
        SwitchListTile(
          title: Text(s.useLink),
          subtitle: Text(s.useLinkHint),
          value: useLink,
          onChanged: (v) => ref.read(DnsTunnelPrefs.useLinkResolvers.notifier).update(v),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: extraCtl,
            textDirection: ltr,
            minLines: 2,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: s.extra,
              helperText: s.extraHint,
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => ref.read(DnsTunnelPrefs.extraResolvers.notifier).update(v),
          ),
        ),
        ExpansionTile(
          leading: const Icon(Icons.receipt_long_rounded),
          title: Text(s.log),
          onExpansionChanged: (open) async {
            if (open) logLines.value = await DnsTunnelPlatform.logs();
          },
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () async => logLines.value = await DnsTunnelPlatform.logs(),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 320),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: SelectableText(
                  logLines.value.isEmpty ? s.noLog : logLines.value.join('\n'),
                  textDirection: ltr,
                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Text(s.credits, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        ),
      ],
    );
  }
}
