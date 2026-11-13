import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_delay_indicator.dart';
import 'package:hiddify/features/raman/raman_strings.dart';
import 'package:hiddify/features/raman/shield/shield_controller.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const _shieldGreen = Color(0xFF16A34A);
const _shieldAmber = Color(0xFFD97706);

/// The flag of a two-letter country code.
String _flag(String code) {
  if (code.length != 2) return '🌐';
  final up = code.toUpperCase();
  return String.fromCharCodes([0x1F1E6 + up.codeUnitAt(0) - 65, 0x1F1E6 + up.codeUnitAt(1) - 65]);
}

/// The Shield tab: one-tap Psiphon, its exit country, and how it works with the Raman profiles.
class ShieldPage extends HookConsumerWidget {
  const ShieldPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ramanStringsProvider);
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final shieldActive = ref.watch(shieldActiveProvider);
    final connection = ref.watch(connectionNotifierProvider).valueOrNull ?? const Disconnected();
    final status = shieldActive ? connection : const Disconnected();
    final region = ref.watch(ShieldPrefs.region);
    final chainUse = ref.watch(shieldChainUseProvider);
    final perApp = ref.watch(Preferences.perAppProxyEnabled);
    final lan = ref.watch(ConfigOptions.allowConnectionFromLan);
    final port = ref.watch(ConfigOptions.mixedPort);
    final controller = ref.read(shieldControllerProvider);

    final (String label, Color color) = switch (status) {
      Connected() => (s.shieldConnected, _shieldGreen),
      Connecting() || Waiting() || NoAvailableProxies() || HotReloading() => (s.shieldConnecting, _shieldAmber),
      Disconnecting() => (s.shieldDisconnecting, _shieldAmber),
      Disconnected() => (s.shieldDisconnected, theme.colorScheme.outline),
    };
    final running = !status.isDisconnected;

    Future<void> onTap() async {
      if (running) {
        await controller.disconnect();
        return;
      }
      final error = await controller.connect();
      if (error != null && context.mounted) {
        ref.read(inAppNotificationControllerProvider).showErrorToast(s.shieldFailed);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(s.shieldIntro, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        const Gap(24),
        Center(
          child: Semantics(
            button: true,
            label: running ? s.shieldDisconnect : s.shieldConnect,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: status is Disconnecting ? null : onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: .12),
                  border: Border.all(color: color, width: 4),
                  boxShadow: [
                    if (status is Connected) BoxShadow(color: color.withValues(alpha: .35), blurRadius: 32),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_rounded, size: 64, color: color),
                    const Gap(6),
                    Text(
                      running ? s.shieldDisconnect : s.shieldConnect,
                      style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Gap(16),
        Text(label, textAlign: TextAlign.center, style: theme.textTheme.titleSmall?.copyWith(color: color)),
        if (shieldActive && status.isRunning) const Center(child: ActiveProxyDelayIndicator()),
        const Gap(16),
        Card(
          child: ListTile(
            leading: Text(_flag(region == PsiphonRegion.auto ? '' : region.key), style: const TextStyle(fontSize: 24)),
            title: Text(s.shieldRegion),
            subtitle: Text(region == PsiphonRegion.auto ? s.shieldRegionAuto : region.present(t)),
            trailing: const Icon(Icons.arrow_drop_down_rounded),
            onTap: () async {
              final picked = await showModalBottomSheet<PsiphonRegion>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (context) => DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: .7,
                  maxChildSize: .95,
                  builder: (context, scroll) => ListView(
                    controller: scroll,
                    children: [
                      for (final r in PsiphonRegion.values)
                        RadioListTile<PsiphonRegion>(
                          value: r,
                          groupValue: region,
                          onChanged: (v) => Navigator.of(context).pop(v),
                          secondary: Text(_flag(r == PsiphonRegion.auto ? '' : r.key), style: const TextStyle(fontSize: 22)),
                          title: Text(r == PsiphonRegion.auto ? s.shieldRegionAuto : r.present(t)),
                        ),
                    ],
                  ),
                ),
              );
              if (picked != null && picked != region) await controller.setRegion(picked);
            },
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.shieldChain, style: theme.textTheme.titleSmall),
                const Gap(8),
                SegmentedButton<ShieldChainUse>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: ShieldChainUse.off, label: Text(s.shieldChainOff)),
                    ButtonSegment(
                      value: ShieldChainUse.extraSecurity,
                      label: Text(s.shieldChainSecurity),
                      icon: const Icon(Icons.security_rounded),
                    ),
                    ButtonSegment(
                      value: ShieldChainUse.unblocker,
                      label: Text(s.shieldChainUnblocker),
                      icon: const Icon(Icons.meeting_room_rounded),
                    ),
                  ],
                  selected: {chainUse},
                  onSelectionChanged: (v) => controller.setChainUse(v.first),
                ),
                const Gap(8),
                Text(s.shieldChainHelp, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                secondary: const Icon(Icons.apps_rounded),
                title: Text(s.shieldPerApp),
                subtitle: Text(perApp ? s.shieldPerAppOn : s.shieldPerAppOff),
                value: perApp,
                onChanged: (v) async {
                  await ref.read(Preferences.perAppProxyEnabled.notifier).update(v);
                  if (v && context.mounted) context.goNamed('appList');
                },
              ),
              if (perApp)
                ListTile(
                  leading: const SizedBox(width: 24),
                  title: Text(s.shieldPerAppOn),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.goNamed('appList'),
                ),
              SwitchListTile.adaptive(
                secondary: const Icon(Icons.wifi_tethering_rounded),
                title: Text(s.shieldLan),
                subtitle: Text(lan ? s.shieldLanPort(port) : s.shieldLanOff),
                value: lan,
                onChanged: (v) => ref.read(ConfigOptions.allowConnectionFromLan.notifier).update(v),
              ),
              if (running)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(s.reconnectToApply, style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
