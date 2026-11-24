import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/raman/disguise_icon.dart';
import 'package:hiddify/features/raman/raman_strings.dart';
import 'package:hiddify/features/raman/ui/raman_home_widgets.dart';
import 'package:hiddify/features/raman/ui/raman_ui_strings.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hiddify/features/settings/notifier/reset_tunnel/reset_tunnel_notifier.dart';
import 'package:hiddify/hiddifycore/hiddify_core_service_provider.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum ConfigOptionSection {
  warp,
  fragment;

  static final _warpKey = GlobalKey(debugLabel: "warp-section-key");
  static final _fragmentKey = GlobalKey(debugLabel: "fragment-section-key");

  GlobalKey get key => switch (this) {
    ConfigOptionSection.warp => _warpKey,
    ConfigOptionSection.fragment => _fragmentKey,
  };
}

class SettingsPage extends HookConsumerWidget {
  SettingsPage({super.key, String? section})
    : section = section != null ? ConfigOptionSection.values.byName(section) : null;

  final ConfigOptionSection? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final ui = ref.watch(ramanUiStringsProvider);
    // final scrollController = useScrollController();

    // useMemoized(
    //   () {
    //     if (section != null) {
    //       WidgetsBinding.instance.addPostFrameCallback(
    //         (_) {
    //           final box = section!.key.currentContext?.findRenderObject() as RenderBox?;

    //           final offset = box?.localToGlobal(Offset.zero);
    //           if (offset == null) return;
    //           final height = scrollController.offset + offset.dy - MediaQueryData.fromView(View.of(context)).padding.top - kToolbarHeight;
    //           scrollController.animateTo(
    //             height,
    //             duration: const Duration(milliseconds: 500),
    //             curve: Curves.decelerate,
    //           );
    //         },
    //       );
    //     }
    //   },
    // );

    return Scaffold(
      appBar: AppBar(
        title: Text(t.pages.settings.title),
        actions: [
          MenuAnchor(
            menuChildren: <Widget>[
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromClipboard();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.clipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromJsonFile();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.file),
                  ),
                ],
                child: Text(t.common.import),
              ),
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonClipboard(),
                    child: Text(t.pages.settings.options.export.anonymousToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(),
                    child: Text(t.pages.settings.options.export.anonymousToFile),
                  ),
                  const PopupMenuDivider(),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(configOptionNotifierProvider.notifier)
                        .exportJsonClipboard(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async =>
                        await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToFile),
                  ),
                ],
                child: Text(t.common.export),
              ),
              const PopupMenuDivider(),
              MenuItemButton(
                child: Text(t.pages.settings.options.reset),
                onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).resetOption(),
              ),
            ],
            builder: (context, controller, child) => IconButton(
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ),
          const Gap(8),
        ],
      ),
      // Raman VPN 1.9: the same pages, grouped into three rounded cards
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // TipCard(message: t.settings.experimentalMsg),
          RamanSectionLabel(ui.groupRaman),
          _SettingsGroup(
            children: [
              SettingsSection(
                title: ref.watch(ramanStringsProvider).toolsTitle,
                subtitle: Text(ref.watch(ramanStringsProvider).toolsSubtitle),
                icon: Icons.shield_rounded,
                namedLocation: context.namedLocation('ramanTools'),
              ),
              const DisguiseIconTile(),
            ],
          ),
          RamanSectionLabel(ui.groupConnection),
          _SettingsGroup(
            children: [
              if (ref.watch(hasAnyProfileProvider).value ?? false)
                SettingsSection(
                  title: t.pages.settings.chain.title,
                  icon: Icons.webhook_rounded,
                  subtitle: Text(t.pages.settings.chain.subtitle),
                  namedLocation: context.namedLocation('chainOptions'),
                ),
              SettingsSection(
                title: t.pages.settings.routing.title,
                icon: Icons.route_rounded,
                namedLocation: context.namedLocation('routingOptions'),
              ),
              SettingsSection(
                title: t.pages.settings.dns.title,
                icon: Icons.dns_rounded,
                namedLocation: context.namedLocation('dnsOptions'),
              ),
              SettingsSection(
                title: t.pages.settings.inbound.title,
                icon: Icons.input_rounded,
                namedLocation: context.namedLocation('inboundOptions'),
              ),
              SettingsSection(
                title: t.pages.settings.tlsTricks.title,
                icon: Icons.content_cut_rounded,
                namedLocation: context.namedLocation('tlsTricks'),
              ),
              if ((PlatformUtils.isIOS || PlatformUtils.isMacOS) &&
                  ref.watch(hiddifyCoreServiceProvider).core.hasVpnProfile)
                ListTile(
                  title: Text(t.pages.settings.resetTunnel),
                  leading: const RamanTileIcon(Icons.autorenew_rounded),
                  onTap: () async {
                    await ref.read(resetTunnelNotifierProvider.notifier).run();
                  },
                ),
            ],
          ),
          RamanSectionLabel(ui.groupApp),
          _SettingsGroup(
            children: [
              SettingsSection(
                title: t.pages.settings.general.title,
                icon: Icons.layers_rounded,
                namedLocation: context.namedLocation('general'),
              ),
              if (Breakpoint(context).isMobile()) ...[
                SettingsSection(
                  title: t.pages.logs.title,
                  icon: Icons.description_rounded,
                  namedLocation: context.namedLocation('logs'),
                ),
                SettingsSection(
                  title: t.pages.about.title,
                  icon: Icons.info_rounded,
                  namedLocation: context.namedLocation('about'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// One rounded card holding a group of settings rows, with thin dividers between them.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (final child in children) {
      if (rows.isNotEmpty) rows.add(const Divider(indent: 64, endIndent: 16));
      rows.add(child);
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(type: MaterialType.transparency, child: Column(mainAxisSize: MainAxisSize.min, children: rows)),
    );
  }
}

class SettingsSection extends HookConsumerWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    required this.namedLocation,
  });

  final String title;
  final Widget? subtitle;
  final IconData icon;
  final String namedLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: RamanTileIcon(icon),
      title: Text(title),
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.go(namedLocation),
    );
  }
}
