import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/theme/raman_brand.dart';
import 'package:hiddify/core/widget/adaptive_icon.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/keep_top/keep_top_widgets.dart';
import 'package:hiddify/features/proxy/model/proxy_entity.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/proxy/widget/proxy_tile.dart';
import 'package:hiddify/features/raman/ui/raman_home_widgets.dart';
import 'package:hiddify/features/raman/ui/raman_ui_strings.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Raman VPN 1.9: starred servers and the last picked ones, by tag, per install.
const _kFavorites = 'raman-fav-proxies';
const _kRecent = 'raman-recent-proxies';
const _recentCount = 5;

class ProxiesOverviewPage extends HookConsumerWidget with PresLogger {
  const ProxiesOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);

    final proxies = ref.watch(proxiesOverviewNotifierProvider);
    final sortBy = ref.watch(proxiesSortNotifierProvider);
    // the proxies keep top left at rest, under the list: shown at first, then folded or not as the user left them
    final showResting = ref.watch(Preferences.showSleepingProxies);
    // Raman VPN 1.9: a search field, favourites (star) and recently picked servers at the top
    final ui = ref.watch(ramanUiStringsProvider);
    final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
    final query = useState('');
    final searchController = useTextEditingController();
    final favorites = useState<Set<String>>(
      useMemoized(() => (prefs?.getStringList(_kFavorites) ?? const <String>[]).toSet(), [prefs]),
    );
    final recent = useState<List<String>>(
      useMemoized(() => prefs?.getStringList(_kRecent) ?? const <String>[], [prefs]),
    );
    void toggleFavorite(String tag) {
      final next = {...favorites.value};
      if (!next.remove(tag)) next.add(tag);
      favorites.value = next;
      prefs?.setStringList(_kFavorites, next.toList());
    }

    void remember(String tag) {
      if (tag == lowestGroupTag || tag == balanceGroupTag) return;
      final next = [tag, ...recent.value.where((e) => e != tag)].take(_recentCount).toList();
      recent.value = next;
      prefs?.setStringList(_kRecent, next);
    }

    // final selectActiveProxyMutation = useMutation(
    //   initialOnFailure: (error) => CustomToast.error(t.presentShortError(error)).show(context),
    // );

    return Scaffold(
      appBar: AppBar(
        title: Text(t.pages.proxies.title),
        actions: [
          const KeepTopAction(),
          PopupMenuButton<ProxiesSort>(
            initialValue: sortBy,
            onSelected: ref.read(proxiesSortNotifierProvider.notifier).update,
            icon: const Icon(FluentIcons.arrow_sort_24_regular),
            tooltip: t.pages.proxies.sort,
            itemBuilder: (context) {
              return [...ProxiesSort.values.map((e) => PopupMenuItem(value: e, child: Text(e.present(t))))];
            },
          ),
          // "Signal style" (off by default) shows pings as the signal instead of numbers
          PopupMenuButton<bool>(
            onSelected: (_) => ref.read(proxyPingStyleNotifierProvider.notifier).toggle(),
            icon: Icon(AdaptiveIcon(context).more),
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            itemBuilder: (context) => [
              // a null value would close the menu as cancelled
              PopupMenuItem(
                value: true,
                child: Row(
                  children: [
                    Checkbox(
                      value: ref.read(proxyPingStyleNotifierProvider) == ProxyPingStyle.signal,
                      // a tap on the box itself does what a tap on the item does
                      onChanged: (_) => Navigator.pop(context, true),
                    ),
                    const Gap(8),
                    Text(t.pages.proxies.signalStyle),
                  ],
                ),
              ),
            ],
          ),
          const Gap(8),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // the speed of the proxies listed: what it tests and the data it takes show first, and
          // it starts from there
          if (proxies.valueOrNull case final group?)
            FloatingActionButton.small(
              heroTag: 'upload-test',
              onPressed: () async {
                final count = group.items.where((e) => !e.isGroup && !e.resting).length;
                if (await ref.read(dialogNotifierProvider.notifier).showSpeedTest(count: count)) {
                  await ref.read(proxiesOverviewNotifierProvider.notifier).speedTestAll();
                }
              },
              tooltip: t.pages.proxies.speedTest.title,
              child: const Icon(Icons.speed_rounded, size: 26),
            ),
          const Gap(12),
          FloatingActionButton(
            onPressed: () async => await ref.read(proxiesOverviewNotifierProvider.notifier).urlTest("select"),
            tooltip: t.pages.proxies.testDelay,
            child: const Icon(FluentIcons.flash_24_filled),
          ),
        ],
      ),
      body: proxies.when(
        data: (group) => group != null
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  // columns wide enough for a proxy's name: two on a usual window, more only when wider
                  final crossAxisCount = PlatformUtils.isMobile && width < 600 ? 1 : max(1, (width / 420).floor());
                  // the proxies in use, then, folded, the ones keep top left at rest
                  final inUse = group.items.where((e) => !e.resting).toList();
                  final resting = group.items.where((e) => e.resting).toList();
                  final listed = inUse.where((e) => e.tag != lowestGroupTag && e.tag != balanceGroupTag).length;
                  Widget grid(List<OutboundInfo> items) => SliverGrid.builder(
                    itemCount: items.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisExtent: 76,
                    ),
                    itemBuilder: (context, index) {
                      final proxy = items[index];
                      final isFavorite = favorites.value.contains(proxy.tag);
                      final canStar = !proxy.isGroup;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: Material(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(RamanBrand.radiusSmall),
                          clipBehavior: Clip.antiAlias,
                          child: Row(
                            children: [
                              Expanded(
                                child: ProxyTile(
                                  proxy,
                                  // a row keeps its own proxy when the list re-sorts, so a pop plays only on arrival
                                  key: ValueKey(proxy.tag),
                                  selected: group.selected == proxy.tag,
                                  // a pick goes through hundreds of proxies, a row or two change every second:
                                  // their values change in place, nothing pops or loops
                                  quiet: group.keepTopPicking,
                                  // selecting one at rest loads it and tests it
                                  onTap: () async {
                                    remember(proxy.tag);
                                    await ref
                                        .read(proxiesOverviewNotifierProvider.notifier)
                                        .changeProxy(group.tag, proxy.tag);
                                  },
                                ),
                              ),
                              if (canStar)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: isFavorite ? ui.removeFavorite : ui.addFavorite,
                                  onPressed: () => toggleFavorite(proxy.tag),
                                  icon: Icon(
                                    isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: isFavorite ? RamanBrand.warning : theme.colorScheme.outline,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                  Widget header(String text) => SliverToBoxAdapter(child: RamanSectionLabel(text));
                  final q = query.value.trim().toLowerCase();
                  bool matches(OutboundInfo e) =>
                      e.tag.toLowerCase().contains(q) || e.nameWithDetour.toLowerCase().contains(q);
                  final byTag = {for (final e in group.items) e.tag: e};
                  final favoriteItems = group.items.where((e) => !e.isGroup && favorites.value.contains(e.tag)).toList();
                  final recentItems = recent.value
                      .where((tag) => !favorites.value.contains(tag))
                      .map((tag) => byTag[tag])
                      .whereType<OutboundInfo>()
                      .where((e) => !e.isGroup)
                      .toList();
                  final search = SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: TextField(
                        controller: searchController,
                        onChanged: (v) => query.value = v,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: ui.searchServers,
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                          suffixIcon: query.value.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    searchController.clear();
                                    query.value = '';
                                  },
                                ),
                        ),
                      ),
                    ),
                  );
                  if (q.isNotEmpty) {
                    final found = group.items.where(matches).toList();
                    return CustomScrollView(
                      slivers: [
                        search,
                        if (found.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(ui.noMatch, textAlign: TextAlign.center),
                            ),
                          )
                        else
                          grid(found),
                        const SliverPadding(padding: EdgeInsets.only(bottom: 140)),
                      ],
                    );
                  }
                  // a big profile: how many of its proxies run, and what changes it
                  final keepTop = SliverToBoxAdapter(
                    child: KeepTopFooter(listed: listed, picking: group.keepTopPicking, proxies: group.items),
                  );
                  final sections = favoriteItems.isNotEmpty || recentItems.isNotEmpty;
                  return CustomScrollView(
                    slivers: [
                      search,
                      if (favoriteItems.isNotEmpty) ...[header(ui.favorites), grid(favoriteItems)],
                      if (recentItems.isNotEmpty) ...[header(ui.recent), grid(recentItems)],
                      if (sections) header(ui.allServers),
                      // under the proxies that run; over the ones still being tested, none of which
                      // is kept yet
                      if (group.keepTopPicking) ...[
                        keepTop,
                        const SliverPadding(padding: EdgeInsets.only(top: 12)),
                        grid(inUse),
                      ] else ...[
                        grid(inUse),
                        keepTop,
                      ],
                      if (resting.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: RestingProxiesHeader(
                            count: resting.length,
                            shown: showResting,
                            onToggle: () => ref.read(Preferences.showSleepingProxies.notifier).update(!showResting),
                          ),
                        ),
                        if (showResting) grid(resting),
                      ],
                      // room for the buttons over the list's end
                      const SliverPadding(padding: EdgeInsets.only(bottom: 140)),
                    ],
                  );
                },
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    ref.watch(serviceRunningProvider) ? t.pages.proxies.empty : t.pages.proxies.connectToSeeProxies,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.pages.proxies.loadFailed, textAlign: TextAlign.center),
                const Gap(12),
                TextButton(
                  onPressed: () => ref.invalidate(proxiesOverviewNotifierProvider),
                  child: Text(t.connection.tapToRetry),
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
