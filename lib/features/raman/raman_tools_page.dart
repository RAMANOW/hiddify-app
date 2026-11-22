import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/core/model/region.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/raman/anti_leak.dart';
import 'package:hiddify/features/raman/dns_probe.dart';
import 'package:hiddify/features/raman/leak_test.dart';
import 'package:hiddify/features/raman/shield/shield_controller.dart';
import 'package:hiddify/features/raman/iran_defaults.dart';
import 'package:hiddify/features/raman/network_checker.dart';
import 'package:hiddify/features/raman/raman_strings.dart';
import 'package:hiddify/features/raman/smart_dns_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/gen/translations.g.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const _green = Color(0xFF16A34A);
const _amber = Color(0xFFD97706);
const _red = Color(0xFFDC2626);

Color _latencyColor(int ms) => ms < 300 ? _green : (ms < 1200 ? _amber : _red);

/// Raman VPN's own tools: smart DNS, the network checker and the Iran settings.
class RamanToolsPage extends ConsumerWidget {
  const RamanToolsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ramanStringsProvider);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.toolsTitle),
          bottom: TabBar(
            isScrollable: false,
            tabs: [
              Tab(icon: const Icon(Icons.dns_rounded), text: s.tabDns),
              Tab(icon: const Icon(Icons.network_check_rounded), text: s.tabNetwork),
              Tab(icon: const Icon(Icons.tune_rounded), text: s.tabIran),
              Tab(icon: const Icon(Icons.shield_moon_rounded), text: s.tabAntiLeak),
            ],
          ),
        ),
        body: const TabBarView(children: [_SmartDnsTab(), _NetworkTab(), _IranTab(), _AntiLeakTab()]),
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
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(s.iranIntro, style: theme.textTheme.bodyMedium),
        ),
        SwitchListTile.adaptive(
          secondary: const Icon(Icons.flag_rounded),
          title: Text(s.regionIran),
          value: region == Region.ir,
          onChanged: (v) => ref.read(ConfigOptions.region.notifier).update(v ? Region.ir : Region.other),
        ),
        SwitchListTile.adaptive(
          secondary: const Icon(Icons.content_cut_rounded),
          title: Text(s.tlsFragment),
          value: ref.watch(ConfigOptions.enableTlsFragment),
          onChanged: ref.read(ConfigOptions.enableTlsFragment.notifier).update,
        ),
        SwitchListTile.adaptive(
          secondary: const Icon(Icons.text_fields_rounded),
          title: Text(s.mixedSni),
          value: ref.watch(ConfigOptions.enableTlsMixedSniCase),
          onChanged: ref.read(ConfigOptions.enableTlsMixedSniCase.notifier).update,
        ),
        SwitchListTile.adaptive(
          secondary: const Icon(Icons.bolt_rounded),
          title: Text(s.ipv4Only),
          value: ref.watch(ConfigOptions.ipv6Mode) == IPv6Mode.ipv4Only,
          onChanged: (v) =>
              ref.read(ConfigOptions.ipv6Mode.notifier).update(v ? IPv6Mode.ipv4Only : IPv6Mode.preferIPv4),
        ),
        ListTile(
          leading: const Icon(Icons.translate_rounded),
          title: Text(s.language),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<AppLocale>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: AppLocale.ckb, label: Text(s.langKurdish)),
              ButtonSegment(value: AppLocale.fa, label: Text(s.langPersian)),
              ButtonSegment(value: AppLocale.en, label: Text(s.langEnglish)),
            ],
            selected: {
              switch (ref.watch(localePreferencesProvider)) {
                AppLocale.ckb => AppLocale.ckb,
                AppLocale.fa => AppLocale.fa,
                _ => AppLocale.en,
              },
            },
            onSelectionChanged: (v) => ref.read(localePreferencesProvider.notifier).changeLocale(v.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () async {
              await applyIranDefaults(ref.read);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.appliedAll)));
              }
            },
            icon: const Icon(Icons.auto_fix_high_rounded),
            label: Text(s.applyAll),
          ),
        ),
      ],
    );
  }
}

/// Anti-leak mode, the leak test and Android's kill switch.
class _AntiLeakTab extends ConsumerWidget {
  const _AntiLeakTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ramanStringsProvider);
    final theme = Theme.of(context);
    final on = ref.watch(AntiLeak.enabled);
    // watched so the warnings follow the settings
    ref.watch(ConfigOptions.remoteDnsAddress);
    ref.watch(ConfigOptions.strictRoute);
    ref.watch(ConfigOptions.ipv6Mode);
    ref.watch(ConfigOptions.blockQuic);
    ref.watch(Preferences.perAppProxyEnabled);
    ref.watch(ShieldPrefs.splitMode);
    final complete = AntiLeak.complete(ref.read);
    final split = AntiLeak.splitTunnelOn(ref.read);
    final proxyMode = ref.watch(ConfigOptions.serviceMode) != ServiceMode.tun;
    final region = ref.watch(ConfigOptions.region);
    final test = ref.watch(leakTestProvider);
    final lockdown = ref.watch(vpnLockdownProvider);
    final connected = ref.watch(connectionNotifierProvider).asData?.value.isConnected ?? false;

    Widget warning(String text, {Color color = _amber}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 20),
          const Gap(8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: color))),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(s.antiLeakIntro, style: theme.textTheme.bodyMedium),
        ),
        SwitchListTile.adaptive(
          secondary: Icon(Icons.shield_moon_rounded, color: on ? _green : null),
          title: Text(s.antiLeakMode),
          subtitle: Text(s.antiLeakModeSub),
          value: on,
          onChanged: (v) async {
            await AntiLeak.set(ref.read, v);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(v ? s.antiLeakOnMsg : s.antiLeakOffMsg)));
            }
          },
        ),
        if (on && !complete) warning(s.antiLeakChanged),
        if (split) warning(s.warnSplit, color: on ? _red : _amber),
        if (proxyMode) warning(s.warnProxyMode),
        SwitchListTile.adaptive(
          secondary: const Icon(Icons.flag_rounded),
          title: Text(s.bypassIran),
          subtitle: Text(s.bypassIranSub),
          isThreeLine: true,
          value: region == Region.ir,
          onChanged: (v) => ref.read(ConfigOptions.region.notifier).update(v ? Region.ir : Region.other),
        ),
        SwitchListTile.adaptive(
          secondary: const Icon(Icons.blur_on_rounded),
          title: Text(s.fakeIp),
          subtitle: Text(s.fakeIpSub),
          isThreeLine: true,
          value: ref.watch(ConfigOptions.enableFakeDns),
          onChanged: ref.read(ConfigOptions.enableFakeDns.notifier).update,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.travel_explore_rounded),
          title: Text(s.testTitle, style: theme.textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(s.testIntro, style: theme.textTheme.bodySmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FilledButton.icon(
            onPressed: test.running || !connected ? null : () => ref.read(leakTestProvider.notifier).run(),
            icon: test.running
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.travel_explore_rounded),
            label: Text(test.running ? s.testRunning : (connected ? s.testRun : s.testNotConnected)),
          ),
        ),
        ..._testResult(context, s, test),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.lock_rounded),
          title: Text(s.killTitle, style: theme.textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(s.killBody, style: theme.textTheme.bodySmall),
        ),
        ListTile(
          dense: true,
          leading: Icon(
            Icons.circle,
            size: 12,
            color: switch (lockdown.valueOrNull) {
              VpnLockdownStatus(lockdown: true) => _green,
              VpnLockdownStatus(alwaysOn: true) => _amber,
              VpnLockdownStatus() => _red,
              null => Colors.grey,
            },
          ),
          title: Text(switch (lockdown.valueOrNull) {
            VpnLockdownStatus(lockdown: true) => s.killStatusOn,
            VpnLockdownStatus(alwaysOn: true) => s.killStatusAlways,
            VpnLockdownStatus() => s.killStatusOff,
            null => s.killStatusUnknown,
          }),
          trailing: IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(vpnLockdownProvider),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: OutlinedButton.icon(
            onPressed: ShieldPlatform.openVpnSettings,
            icon: const Icon(Icons.settings_rounded),
            label: Text(s.killOpen),
          ),
        ),
      ],
    );
  }

  List<Widget> _testResult(BuildContext context, RamanStrings s, LeakTestState st) {
    final theme = Theme.of(context);
    if (st.running) return const [];
    if (st.error != null) {
      final text = switch (st.error) {
        'notConnected' => s.testNotConnected,
        'proxyAuth' => s.testProxyAuth,
        _ => s.testUnreachable,
      };
      return [
        ListTile(dense: true, leading: const Icon(Icons.error_outline_rounded, color: _red), title: Text(text)),
      ];
    }
    final verdict = st.verdict;
    if (verdict == null) return const [];
    final (color, icon, text) = switch (verdict) {
      LeakVerdict.ok => (_green, Icons.verified_user_rounded, s.testOk),
      LeakVerdict.leak => (_red, Icons.gpp_bad_rounded, s.testLeak),
      LeakVerdict.unknown => (_amber, Icons.help_outline_rounded, s.testUnknown),
    };
    String line(LeakSeen e) =>
        [e.country, e.org].where((x) => x.isNotEmpty).join(' · ');
    return [
      Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: color.withValues(alpha: .12),
        child: ListTile(
          leading: Icon(icon, color: color, size: 32),
          title: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          subtitle: verdict == LeakVerdict.leak ? Text(s.testLeakHelp) : null,
        ),
      ),
      if (st.exit != null)
        ListTile(
          dense: true,
          leading: Icon(Icons.public_rounded, color: st.exit!.inIran ? _red : _green),
          title: Text(s.testExit),
          subtitle: Text('${st.exit!.ip}\n${line(st.exit!)}', textDirection: TextDirection.ltr),
          isThreeLine: true,
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(s.testResolvers, style: theme.textTheme.labelLarge),
      ),
      if (st.resolvers.isEmpty)
        ListTile(dense: true, title: Text(st.fakeIp ? s.testFakeIp : s.testNoResolvers)),
      for (final r in st.resolvers)
        ListTile(
          dense: true,
          leading: Icon(Icons.dns_rounded, color: r.inIran ? _red : _green),
          title: Text(r.ip, textDirection: TextDirection.ltr),
          subtitle: Text(line(r), textDirection: TextDirection.ltr),
        ),
      if (st.fakeIp && st.resolvers.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(s.testFakeIp, style: theme.textTheme.bodySmall),
        ),
      if (st.serverSide)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(s.testServerSide, style: theme.textTheme.bodySmall?.copyWith(color: _amber)),
        ),
    ];
  }
}
