import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/router/go_router/go_router_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/raman/finder/finder_controller.dart';
import 'package:hiddify/features/raman/finder/finder_core.dart';
import 'package:hiddify/features/raman/finder/finder_strings.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Opens the «کانفیگ‌یاب» page over whatever is on screen (the add profile sheet closes first).
Future<void> showConfigFinderPage() async {
  final nav = rootNavKey.currentState;
  if (nav == null) return;
  await nav.push(MaterialPageRoute<void>(builder: (_) => const ConfigFinderPage()));
}

class ConfigFinderPage extends ConsumerWidget {
  const ConfigFinderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(finderStringsProvider);
    final c = ref.read(finderControllerProvider);
    final theme = Theme.of(context);
    final activeId = ref.watch(activeProfileProvider).valueOrNull?.id;

    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: AnimatedBuilder(
        animation: Listenable.merge([c.state, c.sourcesVersion]),
        builder: (context, _) {
          final st = c.state.value;
          final last = c.lastRun;
          final off = c.disabledBuiltins;
          final isActive = activeId != null && activeId == c.profileId;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(s.intro, style: theme.textTheme.bodyMedium),
              const Gap(8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.error),
                  const Gap(6),
                  Expanded(
                    child: Text(s.warning, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                  ),
                ],
              ),
              const Gap(16),
              if (st.running) ...[
                Text(
                  '${switch (st.phase) {
                    FinderPhase.fetching => s.fetching,
                    FinderPhase.testing => s.testing,
                    _ => s.saving,
                  }} · ${s.progress(st.done, st.total)}',
                  style: theme.textTheme.titleSmall,
                ),
                const Gap(8),
                LinearProgressIndicator(value: st.total == 0 || st.phase == FinderPhase.saving ? null : st.done / st.total),
                if (st.phase == FinderPhase.testing) ...[
                  const Gap(4),
                  Text(s.tested(st.passed, st.done), style: theme.textTheme.bodySmall),
                ],
                const Gap(8),
                OutlinedButton.icon(onPressed: c.cancel, icon: const Icon(Icons.stop_rounded), label: Text(s.stop)),
              ] else
                FilledButton.icon(
                  onPressed: c.activeSources.isEmpty ? null : c.run,
                  icon: const Icon(Icons.travel_explore_rounded),
                  label: Text(s.start),
                ),
              const Gap(12),
              if (!st.running && st.phase == FinderPhase.done && st.error != null)
                Text(
                  switch (st.error) {
                    'fetch' => s.noneFetched,
                    'none' => s.noneWorked,
                    _ => s.saveFailed,
                  },
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                ),
              if (st.dnsAdded > 0 && !st.running) Text(s.dnsAdded(st.dnsAdded), style: theme.textTheme.bodySmall),
              if (last != null && last.saved > 0)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(s.result(last.saved, last.bestMs ?? 0), style: theme.textTheme.titleSmall),
                        const Gap(4),
                        Text(
                          '${s.tested(last.passed, last.tested)} · ${s.lastRun(_when(last.at))}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const Gap(8),
                        if (isActive) ...[
                          Text(s.inUse, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
                          Text(s.reconnectHint, style: theme.textTheme.bodySmall),
                        ] else ...[
                          FilledButton.tonalIcon(
                            onPressed: st.running
                                ? null
                                : () async {
                                    final notification = ref.read(inAppNotificationControllerProvider);
                                    final ok = await c.selectProfile();
                                    if (ok) {
                                      notification.showSuccessToast(s.selected);
                                    } else {
                                      notification.showErrorToast(s.saveFailed);
                                    }
                                  },
                            icon: const Icon(Icons.check_circle_outline_rounded),
                            label: Text(s.select),
                          ),
                          const Gap(4),
                          Text(s.selectHint, style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ),
              const Gap(8),
              Row(
                children: [
                  Expanded(child: Text(s.keep, style: theme.textTheme.bodyMedium)),
                  DropdownButton<int>(
                    value: finderKeepChoices.contains(c.keep) ? c.keep : 20,
                    items: [for (final n in finderKeepChoices) DropdownMenuItem(value: n, child: Text('$n'))],
                    onChanged: st.running ? null : (v) => v == null ? null : c.setKeep(v),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text(s.autoRefresh, style: theme.textTheme.bodyMedium)),
                  DropdownButton<int>(
                    value: finderAutoChoices.contains(c.autoHours) ? c.autoHours : 0,
                    items: [
                      for (final h in finderAutoChoices)
                        DropdownMenuItem(value: h, child: Text(h == 0 ? s.autoOff : s.hours(h))),
                    ],
                    onChanged: (v) => v == null ? null : c.setAutoHours(v),
                  ),
                ],
              ),
              if (c.autoHours > 0) Text(s.autoHint, style: theme.textTheme.bodySmall),
              const Gap(16),
              Text(s.builtin, style: theme.textTheme.titleMedium),
              for (final src in builtinFinderSources)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: !off.contains(src.url),
                  onChanged: st.running ? null : (v) => c.setBuiltinOn(src.url, v),
                  title: Text(src.label, textDirection: TextDirection.ltr),
                  subtitle: _sourceStatus(s, st, src.url, off.contains(src.url)),
                ),
              const Gap(8),
              Row(
                children: [
                  Expanded(child: Text(s.mine, style: theme.textTheme.titleMedium)),
                  TextButton.icon(
                    onPressed: st.running ? null : () => _addSource(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(s.addSource),
                  ),
                ],
              ),
              for (final u in c.userSources)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(u, textDirection: TextDirection.ltr, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: _sourceStatus(s, st, u, false),
                  trailing: IconButton(
                    tooltip: s.delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: st.running ? null : () => c.removeSource(u),
                  ),
                ),
              const Gap(16),
              Text(s.method, style: theme.textTheme.bodySmall),
            ],
          );
        },
      ),
    );
  }

  static String _when(DateTime at) {
    final l = at.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }

  Widget? _sourceStatus(FinderStrings s, FinderState st, String url, bool off) {
    if (off) return Text(s.disabled);
    final r = st.sources[url];
    if (r == null) return null;
    return Text(r.error != null ? s.failed : s.found(r.found));
  }

  Future<void> _addSource(BuildContext context, WidgetRef ref) async {
    final s = ref.read(finderStringsProvider);
    final c = ref.read(finderControllerProvider);
    final ctl = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(s.addSource),
          content: SizedBox(
            width: 480,
            child: TextField(
              controller: ctl,
              autofocus: true,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                hintText: s.addSourceHint,
                errorText: error,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste_rounded),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    final text = data?.text?.trim() ?? '';
                    if (text.isNotEmpty) ctl.text = text;
                  },
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.cancel)),
            FilledButton(
              onPressed: () async {
                final ok = await c.addSource(ctl.text);
                if (!ok) {
                  setState(() => error = s.badSource);
                  return;
                }
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(s.add),
            ),
          ],
        ),
      ),
    );
    // ctl is left to the GC: the dialog may still be animating out
  }
}
