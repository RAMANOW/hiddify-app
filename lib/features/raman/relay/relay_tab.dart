import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/raman/relay/relay_controller.dart';
import 'package:hiddify/features/raman/relay/relay_strings.dart';
import 'package:hiddify/utils/uri_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const _green = Color(0xFF16A34A);
const _amber = Color(0xFFD97706);
const _red = Color(0xFFDC2626);

/// Raman tools › Google Relay: settings, start/stop, the Apps Script code and the CA.
class RelayTab extends HookConsumerWidget {
  const RelayTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(relayStringsProvider);
    final theme = Theme.of(context);
    final controller = ref.read(relayControllerProvider);
    final relayActive = ref.watch(relayActiveProvider);
    ref.watch(relayProfileIdProvider);
    final connection = ref.watch(connectionNotifierProvider).valueOrNull ?? const Disconnected();

    final idsCtl = useTextEditingController(text: ref.read(RelayPrefs.deployments));
    final keyCtl = useTextEditingController(text: ref.read(RelayPrefs.authKey));
    final ipCtl = useTextEditingController(text: ref.read(RelayPrefs.googleIp));
    final frontCtl = useTextEditingController(text: ref.read(RelayPrefs.frontDomain));
    final showKey = useState(false);
    final busy = useState(false);
    final running = useState(false);
    final calls = useState<int?>(null);
    final sniResult = useState<String?>(null);
    final sniTesting = useState(false);
    final caPath = useState<String?>(null);
    final caPrint = useState<String?>(null);
    final caOk = useState<bool?>(null);
    final logLines = useState<List<String>>(const []);
    final unavailable = useState<String?>(null);
    useListenable(idsCtl);

    Future<void> refresh() async {
      running.value = await RelayPlatform.running();
      final st = running.value ? await RelayPlatform.stats() : null;
      calls.value = (st?['today_calls'] as num?)?.toInt();
    }

    useEffect(() {
      unawaited(refresh());
      unawaited(RelayPlatform.caInstalled().then((v) => caOk.value = v));
      final timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
      return timer.cancel;
    }, const []);

    void toast(String m, {bool error = false}) {
      final n = ref.read(inAppNotificationControllerProvider);
      error ? n.showErrorToast(m) : n.showInfoToast(m);
    }

    String errorText(String code) => switch (code) {
      'ids' => s.missingIds,
      'key' => s.missingKey,
      'ip' => s.missingIp,
      'shield' => s.shieldFirst,
      _ when code.startsWith('profile:') => s.profileFailed,
      _ => '${s.startFailed}: ${code.replaceFirst('start:', '')}',
    };

    Future<void> onStart() async {
      final reason = await RelayPlatform.unavailableReason();
      if (reason != null) {
        unavailable.value = reason;
        toast('${s.unavailable} ($reason)', error: true);
        return;
      }
      if (controller.isBusy && !relayActive) {
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

    Future<void> onApply() async {
      final err = await controller.restartIfRunning();
      toast(err == null ? s.applied : errorText(err), error: err != null);
      await refresh();
    }

    final inUse = controller.inUse || running.value;
    final (String label, Color color) = switch ((running.value, relayActive, connection)) {
      (true, true, Connected()) => (s.stateConnected, _green),
      (true, true, Disconnected()) => (s.stateRelayNoVpn, _amber),
      (true, true, _) => (s.stateConnecting, _amber),
      (true, _, _) => (s.stateOn, _amber),
      _ => (s.stateOff, theme.colorScheme.outline),
    };
    final validIds = relayDeploymentIds(idsCtl.text).length;

    Widget section(String title, IconData icon) => ListTile(
      leading: Icon(icon),
      title: Text(title, style: theme.textTheme.titleMedium),
    );
    Widget body(String text, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: color)),
    );
    const ltr = TextDirection.ltr;

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
                    Icon(Icons.cloud_sync_rounded, color: color),
                    const Gap(8),
                    Expanded(child: Text(label, style: theme.textTheme.titleSmall?.copyWith(color: color))),
                  ],
                ),
                if (calls.value != null) ...[const Gap(4), Text(s.usage(calls.value!), style: theme.textTheme.bodySmall)],
                if (unavailable.value != null) ...[const Gap(4), Text(s.unavailable, style: theme.textTheme.bodySmall?.copyWith(color: _red))],
                const Gap(8),
                if (!inUse)
                  FilledButton.icon(
                    onPressed: busy.value ? null : onStart,
                    icon: busy.value
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(busy.value ? s.starting : s.start),
                  )
                else ...[
                  if (running.value && relayActive && connection is Disconnected)
                    FilledButton.icon(
                      onPressed: busy.value ? null : () => ref.read(connectionNotifierProvider.notifier).toggleConnection(),
                      icon: const Icon(Icons.power_settings_new_rounded),
                      label: Text(s.connectAgain),
                    ),
                  if (!running.value || !relayActive)
                    FilledButton.icon(
                      onPressed: busy.value ? null : onStart,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(s.start),
                    ),
                  const Gap(8),
                  OutlinedButton.icon(
                    onPressed: busy.value ? null : onStop,
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
        section(s.settings, Icons.tune_rounded),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: idsCtl,
            textDirection: ltr,
            minLines: 2,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: s.ids,
              helperText: '${s.idsHint}\n${s.idsCount(validIds)}',
              helperMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => ref.read(RelayPrefs.deployments.notifier).update(v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: keyCtl,
            textDirection: ltr,
            obscureText: !showKey.value,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: s.authKey,
              helperText: s.authKeyHint,
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(showKey.value ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                onPressed: () => showKey.value = !showKey.value,
              ),
            ),
            onChanged: (v) => ref.read(RelayPrefs.authKey.notifier).update(v.trim()),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton.icon(
              icon: const Icon(Icons.casino_rounded),
              label: Text(s.generate),
              onPressed: () {
                final k = relayRandomKey();
                keyCtl.text = k;
                showKey.value = true;
                ref.read(RelayPrefs.authKey.notifier).update(k);
              },
            ),
          ),
        ),
        ExpansionTile(
          leading: const Icon(Icons.settings_ethernet_rounded),
          title: Text(s.advanced),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          children: [
            TextField(
              controller: ipCtl,
              textDirection: ltr,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: s.googleIp,
                hintText: RelayPrefs.defaultGoogleIp,
                helperText: s.googleIpHint(RelayPrefs.defaultGoogleIp),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => ref.read(RelayPrefs.googleIp.notifier).update(v.trim()),
            ),
            const Gap(8),
            TextField(
              controller: frontCtl,
              textDirection: ltr,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: s.front,
                hintText: RelayPrefs.defaultFront,
                helperText: s.googleIpHint(RelayPrefs.defaultFront),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => ref.read(RelayPrefs.frontDomain.notifier).update(v.trim()),
            ),
            const Gap(8),
            OutlinedButton.icon(
              onPressed: sniTesting.value
                  ? null
                  : () async {
                      if (await RelayPlatform.unavailableReason() case final r?) {
                        sniResult.value = s.sniFail(r);
                        return;
                      }
                      sniTesting.value = true;
                      final (ok, ms, err) = await RelayPlatform.testSni(controller.googleIp, controller.front);
                      sniTesting.value = false;
                      sniResult.value = ok ? s.sniOk(ms ?? 0) : s.sniFail(err ?? '');
                    },
              icon: sniTesting.value
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.speed_rounded),
              label: Text(s.testSni),
            ),
            if (sniResult.value != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(sniResult.value!, style: theme.textTheme.bodySmall),
              ),
          ],
        ),
        if (inUse)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: OutlinedButton.icon(onPressed: onApply, icon: const Icon(Icons.sync_rounded), label: Text(s.apply)),
          ),
        const Divider(),
        section(s.deployTitle, Icons.code_rounded),
        body(s.deploySteps),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.copy_rounded),
                label: Text(s.copyCode),
                onPressed: () async {
                  final key = ref.read(RelayPrefs.authKey).trim();
                  final code = await RelayController.codeGs(key);
                  await Clipboard.setData(ClipboardData(text: code));
                  toast(key.isEmpty ? s.copiedNoKey : s.copiedWithKey);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(s.openScript),
                onPressed: () => UriUtils.tryLaunch(Uri.parse('https://script.google.com/home/projects/create')),
              ),
            ],
          ),
        ),
        body(s.quota, color: _amber),
        const Divider(),
        section(s.caTitle, Icons.verified_user_rounded),
        body(s.caBody),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.install_mobile_rounded),
            label: Text(s.caInstall),
            onPressed: () async {
              if (await RelayPlatform.unavailableReason() case final r?) {
                toast('${s.unavailable} ($r)', error: true);
                return;
              }
              final r = await RelayPlatform.exportCa();
              if (r == null) {
                toast(s.caFailed, error: true);
                return;
              }
              caPath.value = r['path'] as String?;
              caPrint.value = r['fingerprint'] as String?;
              caOk.value = r['installed'] == true;
              if (caOk.value != true) await RelayPlatform.installCa();
            },
          ),
        ),
        if (caPath.value != null && caOk.value != true) body(s.caSaved(caPath.value!)),
        ListTile(
          dense: true,
          leading: Icon(Icons.circle, size: 12, color: caOk.value == true ? _green : _amber),
          title: Text(caOk.value == true ? s.caInstalled : s.caNotInstalled),
          trailing: IconButton(
            tooltip: s.caCheck,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async => caOk.value = await RelayPlatform.caInstalled(),
          ),
        ),
        if (caPrint.value != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SelectableText(
              '${s.fingerprint}:\n${caPrint.value}',
              textDirection: ltr,
              style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        const Divider(),
        section(s.limitsTitle, Icons.info_outline_rounded),
        body(s.limits),
        ExpansionTile(
          leading: const Icon(Icons.receipt_long_rounded),
          title: Text(s.logs),
          onExpansionChanged: (open) async {
            if (open) logLines.value = await RelayPlatform.logs();
          },
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: Text(s.refresh),
                onPressed: () async => logLines.value = await RelayPlatform.logs(),
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
                  logLines.value.isEmpty ? s.noLogs : logLines.value.join('\n'),
                  textDirection: ltr,
                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Text(s.credit, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        ),
      ],
    );
  }
}
