import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/widget/adaptive_icon.dart';
import 'package:hiddify/features/app_update/notifier/app_update_notifier.dart';
import 'package:hiddify/features/app_update/notifier/app_update_state.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AboutPage extends HookConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final appInfo = ref.watch(appInfoProvider).requireValue;
    final appUpdate = ref.watch(appUpdateNotifierProvider);

    ref.listen(appUpdateNotifierProvider, (_, next) async {
      if (!context.mounted) return;
      switch (next) {
        case AppUpdateStateAvailable(:final versionInfo) || AppUpdateStateIgnored(:final versionInfo):
          return await ref
              .read(dialogNotifierProvider.notifier)
              .showNewVersion(currentVersion: appInfo.presentVersion, newVersion: versionInfo, canIgnore: false);
        case AppUpdateStateError(:final error):
          return ref.read(inAppNotificationControllerProvider).showErrorToast(t.presentShortError(error));
        case AppUpdateStateNotAvailable():
          return ref.read(inAppNotificationControllerProvider).showSuccessToast(t.pages.about.notAvailableMsg);
      }
    });

    final conditionalTiles = [
      if (appInfo.release.allowCustomUpdateChecker)
        ListTile(
          title: Text(t.pages.about.checkForUpdate),
          trailing: switch (appUpdate) {
            AppUpdateStateChecking() => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
            _ => const Icon(FluentIcons.arrow_sync_24_regular),
          },
          onTap: () async {
            await ref.read(appUpdateNotifierProvider.notifier).check();
          },
        ),
      if (appInfo.release.allowCustomUpdateChecker)
        SwitchListTile.adaptive(
          title: Text(t.pages.about.betaUpdates),
          subtitle: Text(t.pages.about.betaUpdatesMsg),
          value: ref.watch(Preferences.betaUpdates),
          onChanged: ref.read(Preferences.betaUpdates.notifier).update,
        ),
      if (PlatformUtils.isDesktop)
        ListTile(
          title: Text(t.pages.about.openWorkingDir),
          trailing: const Icon(FluentIcons.open_folder_24_regular),
          onTap: () async {
            final path = ref.watch(appDirectoriesProvider).requireValue.workingDir.uri;
            await UriUtils.tryLaunch(path);
          },
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(t.pages.about.title),
        actions: [
          PopupMenuButton(
            icon: Icon(AdaptiveIcon(context).more),
            itemBuilder: (context) {
              return [
                PopupMenuItem(
                  child: Text(t.common.addToClipboard),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: appInfo.format()));
                  },
                ),
              ];
            },
          ),
          const Gap(8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Assets.images.logo.svg(width: 64, height: 64),
                  const Gap(16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.common.appTitle, style: Theme.of(context).textTheme.titleLarge),
                      const Gap(4),
                      Text("${t.common.version} ${appInfo.presentVersion}"),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              ...conditionalTiles,
              if (conditionalTiles.isNotEmpty) const Divider(),
              ListTile(
                title: Text(t.pages.about.reportProblem),
                subtitle: Text(t.pages.about.reportProblemMsg),
                trailing: const Icon(FluentIcons.chat_warning_24_regular),
                onTap: () async {
                  await ref.read(dialogNotifierProvider.notifier).showReportProblem();
                },
              ),
              ListTile(
                title: Text(t.pages.about.sourceCode),
                trailing: const Icon(FluentIcons.open_24_regular),
                onTap: () async {
                  await UriUtils.tryLaunch(Uri.parse(Constants.githubUrl));
                },
              ),
              // the one credit line the upstream license asks for
              ListTile(
                dense: true,
                title: const Text("Open source: based on Hiddify — Hiddify Extended GPL v3"),
                trailing: const Icon(FluentIcons.open_24_regular),
                onTap: () async {
                  await UriUtils.tryLaunch(Uri.parse(Constants.licenseUrl));
                },
              ),
              // Google Relay: mhrv-rs and its Code.gs are MIT; the notice ships in the app
              ListTile(
                dense: true,
                title: const Text(
                  "Google Relay: MasterHttpRelayVPN by masterking32, Rust port mhrv-rs by therealaleph — MIT",
                ),
                trailing: const Icon(FluentIcons.open_24_regular),
                onTap: () async {
                  await UriUtils.tryLaunch(Uri.parse("https://github.com/therealaleph/MasterHttpRelayVPN-RUST"));
                },
              ),
              // DNS قطعی: Soar (Apache-2.0) and CottenDNS (MIT); notices ship in assets/raman/dnstunnel
              ListTile(
                dense: true,
                title: const Text("DNS tunnel: Soar by the Lantern team — Apache-2.0"),
                trailing: const Icon(FluentIcons.open_24_regular),
                onTap: () async {
                  await UriUtils.tryLaunch(Uri.parse("https://github.com/getlantern/soar"));
                },
              ),
              ListTile(
                dense: true,
                title: const Text(
                  "DNS tunnel: CottenDNS by TaJirax, from StormDNS by NullRoute1970 and MasterDnsVPN by Amin Mahmoudi — MIT",
                ),
                trailing: const Icon(FluentIcons.open_24_regular),
                onTap: () async {
                  await UriUtils.tryLaunch(Uri.parse("https://github.com/TaJirax/cottenDNS"));
                },
              ),
              // 1.8.2: dnstt (CC0), Slipstream (Apache-2.0), MasterDnsVPN (MIT); notices in assets/raman/dnstunnel
              ListTile(
                dense: true,
                title: const Text("DNS tunnel: dnstt by David Fifield — public domain (CC0)"),
                trailing: const Icon(FluentIcons.open_24_regular),
                onTap: () async {
                  await UriUtils.tryLaunch(Uri.parse("https://www.bamsoftware.com/software/dnstt/"));
                },
              ),
              ListTile(
                dense: true,
                title: const Text("DNS tunnel: Slipstream by EndPositive — Apache-2.0 (with picoquic, picotls — MIT; SPCDNS — LGPL-3.0)"),
                trailing: const Icon(FluentIcons.open_24_regular),
                onTap: () async {
                  await UriUtils.tryLaunch(Uri.parse("https://github.com/EndPositive/slipstream"));
                },
              ),
              ListTile(
                dense: true,
                title: const Text("DNS tunnel: MasterDnsVPN by Amin Mahmoudi (masterking32) — MIT"),
                trailing: const Icon(FluentIcons.open_24_regular),
                onTap: () async {
                  await UriUtils.tryLaunch(Uri.parse("https://github.com/masterking32/MasterDnsVPN"));
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
