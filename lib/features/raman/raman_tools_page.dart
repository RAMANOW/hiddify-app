import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/theme/raman_brand.dart';
import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/core/model/region.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/raman/dns_probe.dart';
import 'package:hiddify/features/raman/iran_defaults.dart';
import 'package:hiddify/features/raman/network_checker.dart';
import 'package:hiddify/features/raman/raman_strings.dart';
import 'package:hiddify/features/raman/smart_dns_notifier.dart';
import 'package:hiddify/features/raman/tls_tuner.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/gen/translations.g.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const _green = RamanBrand.connected;
const _amber = RamanBrand.warning;
const _red = RamanBrand.error;

Color _latencyColor(int ms) => ms < 300 ? _green : (ms < 1200 ? _amber : _red);

/// Raman VPN's own tools: smart DNS, the network checker and the Iran settings.
class RamanToolsPage extends ConsumerWidget {
  const RamanToolsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ramanStringsProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.toolsTitle),
          bottom: TabBar(
            isScrollable: false,
            tabs: [
              Tab(icon: const Icon(Icons.dns_rounded), text: s.tabDns),
              Tab(icon: const Icon(Icons.network_check_rounded), text: s.tabNetwork),
              Tab(icon: const Icon(Icons.tune_rounded), text: s.tabIran),
            ],
          ),
        ),
        body: const TabBarView(children: [_SmartDnsTab(), _NetworkTab(), _IranTab()]),
      ),
    );
  }
}

class _SmartDnsTab extends ConsumerWidget {
  const _SmartDnsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ramanStringsProvider);
    final st = ref.watch(smartDnsProvider);
    final notifier = ref.read(smartDnsProvider.notifier);
    final theme = Theme.of(context);
    final last = st.lastRun;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(s.dnsIntro, style: theme.textTheme.bodyMedium),
        ),
        SwitchListTile.adaptive(
          title: Text(s.autoDirect),
          value: st.autoDirect,
          onChanged: notifier.setAutoDirect,
        ),
        SwitchListTile.adaptive(
          title: Text(s.autoRemote),
          value: st.autoRemote,
          onChanged: notifier.setAutoRemote,
        ),
        ListTile(
          dense: true,
          title: Text(s.currentDirect),
          subtitle: Text(ref.watch(ConfigOptions.directDnsAddress), textDirection: TextDirection.ltr),
        ),
        ListTile(
          dense: true,
          title: Text(s.currentRemote),
          subtitle: Text(ref.watch(ConfigOptions.remoteDnsAddress), textDirection: TextDirection.ltr),
        ),
        ListTile(
          dense: true,
          title: Text(s.lastRun),
          subtitle: Text(last == null ? s.never : _formatTime(last)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FilledButton.icon(
            onPressed: st.running
                ? null
                : () async {
                    await notifier.runTest();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.reconnectHint)));
                    }
                  },
            icon: st.running
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.speed_rounded),
            label: Text(st.running ? s.testing : s.testNow),
          ),
        ),
        if (st.testedWithVpn && st.results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(s.vpnWarning, style: theme.textTheme.bodySmall?.copyWith(color: _amber)),
          ),
        for (final r in st.results) _DnsResultTile(result: r, strings: s, best: st),
      ],
    );
  }
}

String _formatTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

class _DnsResultTile extends StatelessWidget {
  const _DnsResultTile({required this.result, required this.strings, required this.best});

  final DnsProbeResult result;
  final RamanStrings strings;
  final SmartDnsState best;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final picked = r.server.address == best.bestDirect || r.server.remoteAddress == best.bestRemote;
    final color = r.ok ? _latencyColor(r.latencyMs!) : _red;
    final tags = [
      if (r.server.domestic) strings.domestic,
      if (r.poisoned) strings.poisoned,
    ];
    return ListTile(
      dense: true,
      leading: Icon(r.ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color),
      title: Text(r.server.name + (tags.isEmpty ? '' : '  •  ${tags.join(' • ')}')),
      subtitle: Text(r.server.label, textDirection: TextDirection.ltr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (picked) const Icon(Icons.star_rounded, color: _amber, size: 18),
          const Gap(4),
          Text(
            r.ok ? '${r.latencyMs} ${strings.ms}' : strings.failed,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _NetworkTab extends ConsumerWidget {
  const _NetworkTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ramanStringsProvider);
    final st = ref.watch(networkCheckProvider);
    final vpnOn = ref.watch(connectionNotifierProvider).asData?.value.isConnected ?? false;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(s.networkIntro, style: theme.textTheme.bodyMedium),
        ),
        ListTile(
          dense: true,
          leading: Icon(vpnOn ? Icons.vpn_lock_rounded : Icons.public_rounded, color: vpnOn ? _green : null),
          title: Text(vpnOn ? s.vpnIsOn : s.vpnIsOff),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FilledButton.icon(
            onPressed: st.running ? null : () => ref.read(networkCheckProvider.notifier).run(),
            icon: st.running
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.network_check_rounded),
            label: Text(st.running ? s.testing : s.runCheck),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              Expanded(
                flex: 2,
                child: Text(s.withoutVpn, textAlign: TextAlign.center, style: theme.textTheme.labelLarge),
              ),
              Expanded(
                flex: 2,
                child: Text(s.withVpn, textAlign: TextAlign.center, style: theme.textTheme.labelLarge),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        for (final target in RamanCheckTargets.all)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    target.name + (target.domestic ? '  (${s.domestic})' : ''),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                Expanded(flex: 2, child: _StatusCell(result: st.withoutVpn[target.name], strings: s)),
                Expanded(flex: 2, child: _StatusCell(result: st.withVpn[target.name], strings: s)),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.result, required this.strings});

  final CheckResult? result;
  final RamanStrings strings;

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) return Text(strings.notTested, textAlign: TextAlign.center);
    final color = r.ok ? _latencyColor(r.latencyMs!) : _red;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.circle, size: 10, color: r.ok ? _green : _red),
        const Gap(6),
        Flexible(
          child: Text(
            r.ok ? '${r.latencyMs} ${strings.ms}' : strings.failed,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _IranTab extends ConsumerWidget {
  const _IranTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ramanStringsProvider);
    final theme = Theme.of(context);
    final region = ref.watch(ConfigOptions.region);
    // watched so the badge follows every switch below
    ref.watch(ConfigOptions.ipv6Mode);
    ref.watch(ConfigOptions.urlTestInterval);
    final lowest = ref.watch(ConfigOptions.defaultProxy) == DefaultProxy.lowest;
    final retry = ref.watch(RamanPrefs.autoRetry);
    final iranMode = isIranMode(ref.read);
    final tuner = ref.watch(tlsTunerProvider);
    ref.watch(ConfigOptions.enableTlsFragment);
    ref.watch(ConfigOptions.enableTlsMixedSniCase);
    ref.watch(ConfigOptions.tlsFragmentSize);
    ref.watch(ConfigOptions.tlsFragmentSleep);
    ref.watch(ConfigOptions.enableTlsPadding);
    final preset = TlsPreset.current(ref.read);

    Widget header(String title, {String? help}) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
          if (help != null) ...[
            const Gap(4),
            Text(help, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
    Widget group(List<Widget> children) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(margin: EdgeInsets.zero, child: Column(mainAxisSize: MainAxisSize.min, children: children)),
    );

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        // Iran mode at a glance
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RamanBrand.gradient),
                        child: const Icon(Icons.shield_moon_rounded, color: Colors.white),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.iranMode, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            Text(
                              iranMode ? s.iranModeOn : s.iranModeOff,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: iranMode ? _green : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (iranMode) const Icon(Icons.check_circle_rounded, color: _green),
                    ],
                  ),
                  const Gap(12),
                  Text(s.iranIntro, style: theme.textTheme.bodyMedium),
                  if (!iranMode) ...[
                    const Gap(12),
                    FilledButton.icon(
                      onPressed: () async {
                        await applyIranDefaults(ref.read);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.appliedAll)));
                        }
                      },
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      label: Text(s.applyAll),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        header(s.tabIran),
        group([
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.flag_rounded),
            title: Text(s.regionIran),
            value: region == Region.ir,
            onChanged: (v) => ref.read(ConfigOptions.region.notifier).update(v ? Region.ir : Region.other),
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.speed_rounded),
            title: Text(s.autoSelect),
            subtitle: Text(s.autoSelectSub),
            value: lowest,
            onChanged: (v) async {
              await ref.read(ConfigOptions.defaultProxy.notifier).update(v ? DefaultProxy.lowest : DefaultProxy.balance);
              if (v) await ref.read(ConfigOptions.urlTestInterval.notifier).update(ramanUrlTestInterval);
            },
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.bolt_rounded),
            title: Text(s.ipv4Only),
            value: ref.watch(ConfigOptions.ipv6Mode) == IPv6Mode.ipv4Only,
            onChanged: (v) =>
                ref.read(ConfigOptions.ipv6Mode.notifier).update(v ? IPv6Mode.ipv4Only : IPv6Mode.preferIPv4),
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.replay_rounded),
            title: Text(s.autoRetry),
            subtitle: Text(s.autoRetrySub),
            value: retry,
            onChanged: ref.read(RamanPrefs.autoRetry.notifier).update,
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.translate_rounded),
            title: Text(s.persian),
            value: ref.watch(localePreferencesProvider) == AppLocale.fa,
            onChanged: (v) => ref.read(localePreferencesProvider.notifier).changeLocale(v ? AppLocale.fa : AppLocale.en),
          ),
        ]),
        header(s.tlsSection, help: s.tlsHelp),
        group([
          ListTile(
            leading: const Icon(Icons.content_cut_rounded),
            title: Text(s.tlsCurrent),
            subtitle: Text(preset == null ? s.tlsCustom : s.tlsPresetName(preset.name)),
          ),
          for (final p in TlsPreset.values)
            RadioListTile<TlsPreset?>(
              value: p,
              groupValue: preset,
              title: Text(s.tlsPresetName(p.name)),
              subtitle: switch (tuner.trials.where((e) => e.preset == p).firstOrNull) {
                final TlsTrial r => Text(
                  r.medianMs == null ? s.tlsResult(r.ok, r.total) : '${s.tlsResult(r.ok, r.total)} · ${r.medianMs} ms',
                  style: TextStyle(color: r.ok == 0 ? _red : (r.ok == r.total ? _green : _amber)),
                ),
                _ => null,
              },
              onChanged: tuner.running ? null : (v) => v?.apply(ref.read),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.tonalIcon(
                  onPressed: tuner.running ? null : () => ref.read(tlsTunerProvider.notifier).run(),
                  icon: tuner.running
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.travel_explore_rounded),
                  label: Text(
                    tuner.running && tuner.trying != null ? s.tlsTrying(s.tlsPresetName(tuner.trying!.name)) : s.tlsFind,
                  ),
                ),
                if (!tuner.running && (tuner.error != null || tuner.best != null)) ...[
                  const Gap(8),
                  Text(
                    switch (tuner.error) {
                      'notConnected' => s.tlsNeedsConnection,
                      'noneWorked' => s.tlsNoneWorked,
                      _ => s.tlsBest(s.tlsPresetName(tuner.best!.name)),
                    },
                    style: theme.textTheme.bodySmall?.copyWith(color: tuner.error == null ? _green : _amber),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ],
    );
  }
}
