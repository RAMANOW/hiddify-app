import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/raman/anti_leak.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_tunnel_controller.dart';
import 'package:hiddify/features/raman/finder/finder_controller.dart';
import 'package:hiddify/features/raman/netwatch/iran_access_watcher.dart';
import 'package:hiddify/features/raman/netwatch/network_memory.dart';
import 'package:hiddify/features/raman/relay/relay_controller.dart';
import 'package:hiddify/features/raman/raman_strings.dart';
import 'package:hiddify/features/raman/shield/shield_controller.dart';
import 'package:hiddify/features/raman/shield/shield_page.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'package:hiddify/features/home/widget/local_proxy_hint.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/widget/profile_tile.dart';
import 'package:hiddify/features/proxy/active/active_proxy_card.dart';
import 'package:hiddify/core/theme/raman_brand.dart';
import 'package:hiddify/features/raman/ui/raman_home_widgets.dart';
import 'package:hiddify/features/raman/ui/raman_ui_strings.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider).requireValue;
    // final hasAnyProfile = ref.watch(hasAnyProfileProvider);
    final activeProfile = ref.watch(activeProfileProvider);
    final s = ref.watch(ramanStringsProvider);
    final shieldActive = ref.watch(shieldActiveProvider);
    // the Shield tab while Shield is the profile in use, the Raman tab otherwise
    final tab = useState(shieldActive ? 1 : 0);
    useEffect(() {
      if (shieldActive && tab.value != 1) tab.value = 1;
      return null;
    }, [shieldActive]);
    // Raman VPN 1.8.1: a relay / DNS tunnel profile still active once that tunnel is off goes back
    // to the previous profile (see healStale)
    final relayProfileActive = ref.watch(relayActiveProvider);
    final dnsProfileActive = ref.watch(dnsTunnelActiveProvider);
    useEffect(() {
      if (relayProfileActive && !ref.read(relayControllerProvider).inUse) {
        ref.read(relayControllerProvider).healStale();
      }
      if (dnsProfileActive && !ref.read(dnsTunnelControllerProvider).inUse) {
        ref.read(dnsTunnelControllerProvider).healStale();
      }
      return null;
    }, [relayProfileActive, dnsProfileActive]);
    // Raman VPN 1.8.3: «کانفیگ‌یاب» auto refresh (off unless the user set it)
    useEffect(() {
      ref.read(finderControllerProvider).startAutoRefresh();
      // Raman VPN 1.9: per-network memory (suggestions only) and the opt-in "Iran Access" DNS
      // fallback; both only watch the connection, they do not change it by themselves
      ref.read(networkMemoryProvider).start();
      ref.read(iranAccessWatcherProvider).start();
      return null;
    }, const []);

    /// Only one VPN runs at a time: leaving a tab whose connection runs asks first, then stops it.
    Future<void> selectTab(int index) async {
      if (index == tab.value) return;
      final shield = ref.read(shieldControllerProvider);
      final busy = shield.isBusy;
      if (index == 0) {
        if (shield.isShieldActive) {
          if (busy) {
            final ok = await ref
                .read(dialogNotifierProvider.notifier)
                .showConfirmation(title: s.switchTitle, message: s.switchToRaman, positiveBtnTxt: s.switchYes);
            if (!ok) return;
            await shield.disconnect();
            await _waitStopped(ref);
          }
          await shield.restoreRaman();
        }
      } else if (busy && !shield.isShieldActive) {
        final ok = await ref
            .read(dialogNotifierProvider.notifier)
            .showConfirmation(title: s.switchTitle, message: s.switchToShield, positiveBtnTxt: s.switchYes);
        if (!ok) return;
        await ref.read(connectionNotifierProvider.notifier).abortConnection();
        await _waitStopped(ref);
      }
      tab.value = index;
    }

    return Scaffold(
      appBar: AppBar(
        // leading: (RootScaffold.stateKey.currentState?.hasDrawer ?? false) && showDrawerButton(context)
        //     ? DrawerButton(
        //         onPressed: () {
        //           RootScaffold.stateKey.currentState?.openDrawer();
        //         },
        //       )
        //     : null,
        title: Row(
          children: [
            Assets.images.logo.svg(height: 24),
            const Gap(8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: t.common.appTitle),
                  const TextSpan(text: " "),
                  const WidgetSpan(child: AppVersionLabel(), alignment: PlaceholderAlignment.middle),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // IconButton(
          //     onPressed: () => const QuickSettingsRoute().push(context),
          //     icon: const Icon(FluentIcons.options_24_filled),
          //     material: (context, platform) => MaterialIconButtonData(
          //           tooltip: t.config.quickSettings,
          //         )),
          // IconButton(
          //     onPressed: () => const AddProfileRoute().push(context),
          //     icon: const Icon(FluentIcons.add_circle_24_filled),
          //     material: (context, platform) => MaterialIconButtonData(
          //           tooltip: t.profile.add.buttonText,
          //         )),
          // Raman VPN 1.6: anti-leak mode at a glance
          if (ref.watch(AntiLeak.enabled))
            IconButton(
              tooltip: s.antiLeakBadge,
              icon: const Icon(Icons.shield_moon_rounded, color: Color(0xFF16A34A)),
              onPressed: () => context.go(context.namedLocation('ramanTools')),
            ),
          IconButton(
            tooltip: ref.watch(ramanStringsProvider).toolsTitle,
            icon: Icon(Icons.network_check_rounded, color: theme.colorScheme.primary),
            onPressed: () => context.go(context.namedLocation('ramanTools')),
          ),
          Semantics(
            key: const ValueKey("profile_add_button"),
            label: t.pages.profiles.add,
            child: IconButton(
              icon: Icon(Icons.add_rounded, color: theme.colorScheme.primary),
              onPressed: () => ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(),
            ),
          ),
          const Gap(8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 0, label: Text(s.tabRaman), icon: const Icon(Icons.vpn_key_rounded)),
                  ButtonSegment(value: 1, label: Text(s.tabShield), icon: const Icon(Icons.shield_rounded)),
                ],
                selected: {tab.value},
                onSelectionChanged: (v) => selectTab(v.first),
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(index: tab.value, children: [_ramanBody(context, ref, theme, t, activeProfile), const ShieldPage()]),
    );
  }

  Widget _ramanBody(BuildContext context, WidgetRef ref, ThemeData theme, Translations t, AsyncValue<ProfileEntity?> activeProfile) {
    // The sky and the map are drawn once into their own layer: a ripple or a label changing on
    // the page no longer redraws the whole map image under it.
    return Stack(
        fit: StackFit.expand,
        children: [
          // Raman VPN 1.9: a soft brand-blue light behind the connect button instead of the map
          RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -.35),
                  radius: .9,
                  colors: [
                    RamanBrand.blue.withValues(alpha: theme.brightness == Brightness.dark ? .14 : .10),
                    RamanBrand.blue.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  // The page does not move under the finger: no bounce (iOS) or stretch (Android) when it
                  // fits the screen. It still scrolls, without them, when it does not (a small screen or a
                  // large font).
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
                    child: CustomScrollView(
                      physics: const ClampingScrollPhysics(),
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Column(
                            children: [
                              const RamanConnectionSinceKeeper(),
                              // the button, its state and the live speeds / ping, centred
                              const Expanded(
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [ConnectionButton(), Gap(8), RamanLiveStatsRow()],
                                    ),
                                  ),
                                ),
                              ),
                              // the selected config: a tap opens the config list
                              if (activeProfile case AsyncData(value: final profile?)) ...[
                                RamanSectionLabel(ref.watch(ramanUiStringsProvider).selectedConfig),
                                ProfileTile(
                                  profile: profile,
                                  isMain: true,
                                  margin: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                              ],
                              // the server in use (flag, name, IP; a tap opens the server list), while connected
                              const ActiveProxyFooter(),
                              const Gap(40),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (ref.watch(hasAnyProfileProvider).value ?? false)
                Positioned(
                  right: 0,
                  left: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    // tabs of either height stand on the bottom edge
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // in proxy mode, a smaller tab beside this one on how to point apps at the proxy
                      const Flexible(child: LocalProxyHint()),
                      Material(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          onTap: () => ref.read(bottomSheetsNotifierProvider.notifier).showQuickSettings(),
                          child: Container(
                            height: 32,
                            padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(t.pages.home.quickSettings),
                                const Gap(4),
                                const Icon(Icons.arrow_drop_up_rounded, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      );
  }
}

class AppVersionLabel extends HookConsumerWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);

    final version = ref.watch(appInfoProvider).requireValue.presentVersion;
    if (version.isBlank) return const SizedBox();

    return Semantics(
      label: t.common.version,
      button: false,
      child: Container(
        decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          version,
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
        ),
      ),
    );
  }
}

/// Waits, for at most a few seconds, until no connection runs.
Future<void> _waitStopped(WidgetRef ref) async {
  for (var i = 0; i < 50; i++) {
    final status = ref.read(connectionNotifierProvider).valueOrNull;
    if (status == null || status.isDisconnected) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}
