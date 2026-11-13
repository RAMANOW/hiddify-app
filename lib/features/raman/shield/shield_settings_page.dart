import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/features/common/general_pref_tiles.dart';
import 'package:hiddify/features/raman/disguise_icon.dart';
import 'package:hiddify/features/raman/raman_strings.dart';
import 'package:hiddify/features/raman/shield/shield_controller.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/widget/lan_sharing_tile.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:installed_apps/installed_apps.dart';

/// The flag of a two-letter country code.
String shieldFlag(String code) {
  if (code.length != 2) return '🌐';
  final up = code.toUpperCase();
  return String.fromCharCodes([0x1F1E6 + up.codeUnitAt(0) - 65, 0x1F1E6 + up.codeUnitAt(1) - 65]);
}

/// Picks Shield's exit country.
Future<void> pickShieldRegion(BuildContext context, WidgetRef ref) async {
  final s = ref.read(ramanStringsProvider);
  final t = ref.read(translationsProvider).requireValue;
  final region = ref.read(ShieldPrefs.region);
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
              secondary: Text(shieldFlag(r == PsiphonRegion.auto ? '' : r.key), style: const TextStyle(fontSize: 22)),
              title: Text(r == PsiphonRegion.auto ? s.shieldRegionAuto : r.present(t)),
            ),
        ],
      ),
    ),
  );
  if (picked != null && picked != region) await ref.read(shieldControllerProvider).setRegion(picked);
}

/// A text value of Shield's settings, edited in a dialog.
Future<String?> _editText(
  BuildContext context,
  RamanStrings s, {
  required String title,
  required String initial,
  String? hint,
  bool obscure = false,
  bool digits = false,
  bool multiline = false,
  String? Function(String value)? validate,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextDialog(
      s: s,
      title: title,
      initial: initial,
      hint: hint,
      obscure: obscure,
      digits: digits,
      multiline: multiline,
      validate: validate,
    ),
  );
}

class _TextDialog extends HookWidget {
  const _TextDialog({
    required this.s,
    required this.title,
    required this.initial,
    this.hint,
    this.obscure = false,
    this.digits = false,
    this.multiline = false,
    this.validate,
  });

  final RamanStrings s;
  final String title;
  final String initial;
  final String? hint;
  final bool obscure;
  final bool digits;
  final bool multiline;
  final String? Function(String value)? validate;

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: initial);
    final error = useState<String?>(null);
    final hidden = useState(obscure);
    void save() {
      final value = controller.text.trim();
      final problem = value.isEmpty ? null : validate?.call(value);
      if (problem != null) {
        error.value = problem;
        return;
      }
      Navigator.of(context).pop(value);
    }

    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: hidden.value,
        keyboardType: digits ? TextInputType.number : (multiline ? TextInputType.multiline : TextInputType.text),
        inputFormatters: digits ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)] : null,
        maxLines: multiline ? 4 : 1,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          hintText: hint,
          errorText: error.value,
          suffixIcon: obscure
              ? IconButton(
                  icon: Icon(hidden.value ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  onPressed: () => hidden.value = !hidden.value,
                )
              : null,
        ),
        onSubmitted: multiline ? null : (_) => save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(''), child: Text(s.ssClear)),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.ssCancel)),
        FilledButton(onPressed: save, child: Text(s.ssSave)),
      ],
    );
  }
}

/// All of Shield's settings, reached from the Shield tab.
class ShieldSettingsPage extends HookConsumerWidget {
  const ShieldSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ramanStringsProvider);
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final controller = ref.read(shieldControllerProvider);
    final shieldActive = ref.watch(shieldActiveProvider);
    final changed = useState(false);

    final region = ref.watch(ShieldPrefs.region);
    final split = ref.watch(ShieldPrefs.splitMode);
    final includeApps = _splitList(ref.watch(ShieldPrefs.includeApps));
    final excludeApps = _splitList(ref.watch(ShieldPrefs.excludeApps));
    final upstream = ref.watch(ShieldPrefs.upstreamEnabled);
    final upstreamSource = ref.watch(ShieldPrefs.upstreamSource);
    final upstreamType = ref.watch(ShieldPrefs.upstreamType);
    final host = ref.watch(ShieldPrefs.upstreamHost);
    final port = ref.watch(ShieldPrefs.upstreamPort);
    final auth = ref.watch(ShieldPrefs.upstreamAuth);
    final user = ref.watch(ShieldPrefs.upstreamUser);
    final pass = ref.watch(ShieldPrefs.upstreamPass);
    final domain = ref.watch(ShieldPrefs.upstreamDomain);
    final disableTimeouts = ref.watch(ShieldPrefs.disableTimeouts);
    final sound = ref.watch(ShieldPrefs.notifySound);
    final vibrate = ref.watch(ShieldPrefs.notifyVibrate);
    final stealth = ref.watch(ShieldPrefs.stealthNotifications);
    final openSite = ref.watch(ShieldPrefs.openSite);
    final openSiteUrl = ref.watch(ShieldPrefs.openSiteUrl);
    final lanPort = ref.watch(ConfigOptions.lanSharingPort);
    final protocol = ref.watch(ShieldPrefs.protocol);
    final beast = ref.watch(ShieldPrefs.beastMode);
    final conduitMode = ref.watch(ShieldPrefs.conduitMode);
    final conduitId = ref.watch(ShieldPrefs.conduitCompartmentId);
    final conduitFallback = ref.watch(ShieldPrefs.conduitFallbackMinutes);
    final unsafeAlerts = ref.watch(ShieldPrefs.unsafeTrafficAlerts);
    final conduit = protocol == ShieldProtocol.conduit;

    /// Saves a setting that goes into Shield's connection; a running Shield is reconnected on Apply.
    Future<void> update<T>(PreferencesNotifier<T, dynamic> notifier, T value) async {
      await notifier.update(value);
      changed.value = true;
    }

    Widget section(String title, {String? help}) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          if (help != null) ...[
            const Gap(4),
            Text(help, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );

    Widget soon(IconData icon, String title, String subtitle, {String? why}) => ListTile(
      enabled: false,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text([if (subtitle.isNotEmpty) subtitle, s.ssSoonNote(why ?? s.ssNeedsCore)].join('\n')),
      isThreeLine: subtitle.isNotEmpty,
      trailing: Chip(label: Text(s.ssSoon), visualDensity: VisualDensity.compact),
    );

    /// A setting this build cannot offer, with the reason.
    Widget unavailable(IconData icon, String title, String why) => ListTile(
      enabled: false,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(why),
      isThreeLine: true,
      trailing: Chip(label: Text(s.ssUnavailable), visualDensity: VisualDensity.compact),
    );

    Widget textTile({
      required IconData? icon,
      required String title,
      required String value,
      required PreferencesNotifier<String, dynamic> notifier,
      String? hint,
      bool obscure = false,
      bool digits = false,
      bool enabled = true,
      String? Function(String)? validate,
    }) => ListTile(
      enabled: enabled,
      leading: icon != null ? Icon(icon) : const SizedBox(width: 24),
      title: Text(title),
      subtitle: Text(
        value.isEmpty ? s.ssNotSet : (obscure ? '•' * value.length.clamp(4, 12) : value),
        textDirection: value.isEmpty ? null : TextDirection.ltr,
      ),
      onTap: () async {
        final v = await _editText(
          context,
          s,
          title: title,
          initial: value,
          hint: hint,
          obscure: obscure,
          digits: digits,
          validate: validate,
        );
        if (v != null) await update(notifier, v);
      },
    );

    Future<void> chooseApps(ShieldSplitMode mode) async {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ShieldAppsPage(mode: mode)));
      changed.value = true;
    }

    final listMode = split == ShieldSplitMode.all ? null : split;
    final listCount = listMode == ShieldSplitMode.include ? includeApps.length : excludeApps.length;

    return Scaffold(
      appBar: AppBar(title: Text(s.ssTitle)),
      bottomNavigationBar: shieldActive && changed.value
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(s.ssApply),
                  onPressed: () async {
                    final reconnected = await controller.applySettings();
                    changed.value = false;
                    if (context.mounted) {
                      ref
                          .read(inAppNotificationControllerProvider)
                          .showSuccessToast(reconnected ? s.ssApplied : s.ssSaved);
                    }
                  },
                ),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // region
          section(s.ssSecRegion),
          ListTile(
            leading: Text(shieldFlag(region == PsiphonRegion.auto ? '' : region.key), style: const TextStyle(fontSize: 24)),
            title: Text(s.shieldRegion),
            subtitle: Text(region == PsiphonRegion.auto ? s.shieldRegionAuto : region.present(t)),
            trailing: const Icon(Icons.arrow_drop_down_rounded),
            onTap: () => pickShieldRegion(context, ref),
          ),

          // split tunneling
          section(s.ssSecSplit, help: s.ssSplitHelp),
          if (!ShieldPlatform.supported)
            ListTile(enabled: false, title: Text(s.ssAppsUnsupported))
          else ...[
            for (final (mode, label) in [
              (ShieldSplitMode.all, s.ssSplitAll),
              (ShieldSplitMode.include, s.ssSplitInclude),
              (ShieldSplitMode.exclude, s.ssSplitExclude),
            ])
              RadioListTile<ShieldSplitMode>(
                value: mode,
                groupValue: split,
                title: Text(label),
                onChanged: (v) async {
                  if (v == null) return;
                  await update(ref.read(ShieldPrefs.splitMode.notifier), v);
                  if (v != ShieldSplitMode.all && _splitList(ref.read(_listPref(v))).isEmpty && context.mounted) {
                    await chooseApps(v);
                  }
                },
              ),
            ListTile(
              enabled: listMode != null,
              leading: const Icon(Icons.apps_rounded),
              title: Text(s.ssSplitChoose),
              subtitle: listMode == null ? null : Text(s.ssSplitCount(listCount)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: listMode == null ? null : () => chooseApps(listMode),
            ),
            ListTile(
              leading: const Icon(Icons.vpn_lock_rounded),
              title: Text(s.ssAlwaysOn),
              subtitle: Text(s.ssAlwaysOnSub),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: ShieldPlatform.openVpnSettings,
            ),
          ],

          // upstream proxy
          section(s.ssSecUpstream, help: s.ssUpstreamHelp),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.device_hub_rounded),
            title: Text(s.ssUpstreamUse),
            value: upstream,
            onChanged: (v) => update(ref.read(ShieldPrefs.upstreamEnabled.notifier), v),
          ),
          if (upstream) ...[
            RadioListTile<ShieldUpstreamSource>(
              value: ShieldUpstreamSource.system,
              groupValue: upstreamSource,
              title: Text(s.ssUpstreamSystem),
              onChanged: (v) => update(ref.read(ShieldPrefs.upstreamSource.notifier), v!),
            ),
            RadioListTile<ShieldUpstreamSource>(
              value: ShieldUpstreamSource.custom,
              groupValue: upstreamSource,
              title: Text(s.ssUpstreamCustom),
              onChanged: (v) => update(ref.read(ShieldPrefs.upstreamSource.notifier), v!),
            ),
            if (upstreamSource == ShieldUpstreamSource.custom) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SegmentedButton<ShieldUpstreamType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ShieldUpstreamType.http, label: Text('HTTP')),
                    ButtonSegment(value: ShieldUpstreamType.socks5, label: Text('SOCKS5')),
                  ],
                  selected: {upstreamType},
                  onSelectionChanged: (v) => update(ref.read(ShieldPrefs.upstreamType.notifier), v.first),
                ),
              ),
              textTile(
                icon: Icons.dns_rounded,
                title: s.ssUpstreamHost,
                value: host,
                hint: s.ssUpstreamHostHint,
                notifier: ref.read(ShieldPrefs.upstreamHost.notifier),
              ),
              textTile(
                icon: Icons.numbers_rounded,
                title: s.ssUpstreamPort,
                value: port,
                hint: '8080',
                digits: true,
                notifier: ref.read(ShieldPrefs.upstreamPort.notifier),
                validate: (v) {
                  final p = int.tryParse(v);
                  return p == null || p < 1 || p > 65535 ? '1–65535' : null;
                },
              ),
              if (host.trim().isEmpty || int.tryParse(port) == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(s.ssUpstreamInvalid, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                ),
              SwitchListTile.adaptive(
                secondary: const Icon(Icons.lock_rounded),
                title: Text(s.ssUpstreamAuth),
                value: auth,
                onChanged: (v) => update(ref.read(ShieldPrefs.upstreamAuth.notifier), v),
              ),
              if (auth) ...[
                textTile(
                  icon: Icons.person_rounded,
                  title: s.ssUpstreamUser,
                  value: user,
                  notifier: ref.read(ShieldPrefs.upstreamUser.notifier),
                ),
                textTile(
                  icon: Icons.password_rounded,
                  title: s.ssUpstreamPass,
                  value: pass,
                  obscure: true,
                  notifier: ref.read(ShieldPrefs.upstreamPass.notifier),
                ),
                if (upstreamType == ShieldUpstreamType.http)
                  textTile(
                    icon: Icons.domain_rounded,
                    title: s.ssUpstreamDomain,
                    value: domain,
                    notifier: ref.read(ShieldPrefs.upstreamDomain.notifier),
                  ),
              ],
            ],
          ],

          // LAN sharing
          section(s.ssSecLan, help: s.ssLanHelp),
          const LanSharingPreferenceWidget(),
          ListTile(
            leading: const Icon(Icons.settings_ethernet_rounded),
            title: Text(s.ssLanPort),
            subtitle: Text('$lanPort'),
            onTap: () async {
              final v = await _editText(
                context,
                s,
                title: s.ssLanPort,
                initial: '$lanPort',
                digits: true,
                validate: (v) {
                  final p = int.tryParse(v);
                  return p == null || p < 1024 || p > 65535 ? '1024–65535' : null;
                },
              );
              final p = int.tryParse(v ?? '');
              if (p != null) await update(ref.read(ConfigOptions.lanSharingPort.notifier), p);
            },
          ),

          // connection
          section(s.ssSecConnection),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.sync_disabled_rounded),
            title: Text(s.ssDisableTimeouts),
            subtitle: Text(s.ssDisableTimeoutsSub),
            value: disableTimeouts,
            onChanged: (v) => update(ref.read(ShieldPrefs.disableTimeouts.notifier), v),
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.bolt_rounded),
            title: Text(s.ssBeast),
            subtitle: Text(s.ssBeastSub),
            isThreeLine: true,
            value: beast,
            onChanged: (v) => update(ref.read(ShieldPrefs.beastMode.notifier), v),
          ),

          // protocol
          section(s.ssProtocol, help: s.ssProtocolHelp),
          for (final (value, title, sub) in [
            (ShieldProtocol.auto, s.ssProtoAuto, s.ssProtoAutoSub),
            (ShieldProtocol.direct, s.ssProtoDirect, s.ssProtoDirectSub),
            (ShieldProtocol.cdn, s.ssProtoCdn, s.ssProtoCdnSub),
            (ShieldProtocol.conduit, s.ssProtoConduit, s.ssProtoConduitSub),
          ])
            RadioListTile<ShieldProtocol>(
              value: value,
              groupValue: protocol,
              title: Text(title),
              subtitle: Text(sub),
              onChanged: (v) => update(ref.read(ShieldPrefs.protocol.notifier), v!),
            ),

          // CDN fronting
          section(s.ssSecCdn),
          unavailable(Icons.cloud_rounded, s.ssCdnIps, s.ssCdnWhy),
          unavailable(Icons.badge_rounded, s.ssCdnSni, s.ssCdnWhy),

          // Conduit
          section(s.ssSecConduit, help: s.ssConduitHelp),
          for (final (value, title) in [
            (ShieldConduitMode.auto, s.ssConduitAuto),
            (ShieldConduitMode.personal, s.ssConduitPersonal),
            (ShieldConduitMode.public, s.ssConduitPublic),
          ])
            RadioListTile<ShieldConduitMode>(
              value: value,
              groupValue: conduitMode,
              title: Text(title),
              onChanged: conduit ? (v) => update(ref.read(ShieldPrefs.conduitMode.notifier), v!) : null,
            ),
          if (conduitMode != ShieldConduitMode.public) ...[
            textTile(
              icon: Icons.key_rounded,
              title: s.ssConduitId,
              value: conduitId,
              hint: s.ssConduitIdHint,
              enabled: conduit,
              notifier: ref.read(ShieldPrefs.conduitCompartmentId.notifier),
            ),
            if (conduitId.trim().isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(s.ssConduitNoId, style: theme.textTheme.bodySmall),
              ),
          ],
          if (conduitMode == ShieldConduitMode.auto)
            ListTile(
              enabled: conduit && conduitId.trim().isNotEmpty,
              leading: const Icon(Icons.timer_rounded),
              title: Text(s.ssConduitTimeout),
              subtitle: Text(s.ssConduitTimeoutSub(conduitFallback)),
              trailing: DropdownButton<int>(
                value: ShieldPrefs.conduitFallbackChoices.contains(conduitFallback) ? conduitFallback : 3,
                underline: const SizedBox(),
                items: [
                  for (final m in ShieldPrefs.conduitFallbackChoices)
                    DropdownMenuItem(value: m, child: Text(s.ssMinutes(m))),
                ],
                onChanged: conduit && conduitId.trim().isNotEmpty
                    ? (v) {
                        if (v != null) update(ref.read(ShieldPrefs.conduitFallbackMinutes.notifier), v);
                      }
                    : null,
              ),
            ),
          unavailable(Icons.block_rounded, s.ssConduitReject, s.ssConduitRejectWhy),

          // notifications
          section(s.ssSecNotifications),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.notifications_active_rounded),
            title: Text(s.ssSound),
            subtitle: Text(s.ssSoundSub),
            value: sound,
            onChanged: (v) => ref.read(ShieldPrefs.notifySound.notifier).update(v),
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.vibration_rounded),
            title: Text(s.ssVibrate),
            subtitle: Text(s.ssVibrateSub),
            value: vibrate,
            onChanged: (v) => ref.read(ShieldPrefs.notifyVibrate.notifier).update(v),
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.visibility_off_rounded),
            title: Text(s.ssStealth),
            subtitle: Text(s.ssStealthSub),
            value: stealth,
            onChanged: (v) => ref.read(ShieldPrefs.stealthNotifications.notifier).update(v),
          ),

          // appearance
          section(s.ssSecAppearance),
          const LocalePrefTile(),
          const DisguiseIconTile(),

          // more
          section(s.ssSecMore),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.open_in_browser_rounded),
            title: Text(s.ssOpenSite),
            subtitle: openSite && openSiteUrl.isNotEmpty ? Text(openSiteUrl, textDirection: TextDirection.ltr) : null,
            value: openSite,
            onChanged: (v) async {
              await ref.read(ShieldPrefs.openSite.notifier).update(v);
              if (v && ref.read(ShieldPrefs.openSiteUrl).isEmpty && context.mounted) {
                final url = await _editText(
                  context,
                  s,
                  title: s.ssOpenSiteUrl,
                  initial: '',
                  hint: 'https://',
                  validate: _validateUrl(s),
                );
                if (url != null) await ref.read(ShieldPrefs.openSiteUrl.notifier).update(url);
                if (ref.read(ShieldPrefs.openSiteUrl).isEmpty) await ref.read(ShieldPrefs.openSite.notifier).update(false);
              }
            },
          ),
          if (openSite)
            textTile(
              icon: null,
              title: s.ssOpenSiteUrl,
              value: openSiteUrl,
              hint: 'https://',
              notifier: ref.read(ShieldPrefs.openSiteUrl.notifier),
              validate: _validateUrl(s),
            ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.gpp_maybe_rounded),
            title: Text(s.ssMalware),
            subtitle: Text(s.ssMalwareSub),
            isThreeLine: true,
            value: unsafeAlerts,
            onChanged: (v) => update(ref.read(ShieldPrefs.unsafeTrafficAlerts.notifier), v),
          ),
          soon(Icons.contactless_rounded, s.ssNfc, '', why: s.ssNfcWhy),
          soon(Icons.system_update_rounded, s.ssWifiUpdates, '', why: s.ssWifiUpdatesWhy),
          ListTile(
            leading: const Icon(Icons.send_rounded),
            title: Text(s.ssFeedback),
            subtitle: Text(s.ssFeedbackSub),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.goNamed('logs'),
          ),
          ListTile(
            leading: const Icon(Icons.info_rounded),
            title: Text(s.ssAbout),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.goNamed('about'),
          ),
        ],
      ),
    );
  }
}

String? Function(String) _validateUrl(RamanStrings s) => (v) {
  final uri = Uri.tryParse(v);
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http') || uri.host.isEmpty) return s.ssOpenSiteInvalid;
  return null;
};

List<String> _splitList(String value) => value.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

StateNotifierProvider<PreferencesNotifier<String, String>, String> _listPref(ShieldSplitMode mode) =>
    mode == ShieldSplitMode.include ? ShieldPrefs.includeApps : ShieldPrefs.excludeApps;

/// Picks the apps of Shield's split tunnel for one mode.
class ShieldAppsPage extends HookConsumerWidget {
  const ShieldAppsPage({super.key, required this.mode});

  final ShieldSplitMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ramanStringsProvider);
    final pref = _listPref(mode);
    final selected = _splitList(ref.watch(pref)).toSet();
    final hideSystem = useState(true);
    final query = useState('');
    final apps = useFuture(
      useMemoized(
        () => InstalledApps.getInstalledApps(
          excludeSystemApps: hideSystem.value,
          excludeNonLaunchableApps: false,
          withIcon: true,
          detectPlatformType: false,
        ),
        [hideSystem.value],
      ),
    );
    final pickedAtStart = useMemoized(() => selected);

    Future<void> toggle(String pkg, bool on) async {
      final next = {...selected};
      on ? next.add(pkg) : next.remove(pkg);
      next.remove('com.ramanow.ramanvpn');
      await ref.read(pref.notifier).update(next.join(';'));
    }

    final q = query.value.toLowerCase();
    final list = [...?apps.data]
      ..removeWhere((a) => a.packageName == 'com.ramanow.ramanvpn')
      ..sort((a, b) {
        final pa = pickedAtStart.contains(a.packageName) ? 0 : 1;
        final pb = pickedAtStart.contains(b.packageName) ? 0 : 1;
        if (pa != pb) return pa - pb;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final shown = list
        .where((a) => q.isEmpty || a.name.toLowerCase().contains(q) || a.packageName.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(mode == ShieldSplitMode.include ? s.ssAppsIncludeTitle : s.ssAppsExcludeTitle),
        actions: [
          IconButton(
            tooltip: hideSystem.value ? s.ssAppsShowSystem : s.ssAppsHideSystem,
            icon: Icon(hideSystem.value ? Icons.android_rounded : Icons.phone_android_rounded),
            onPressed: () => hideSystem.value = !hideSystem.value,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: s.ssAppsSearch,
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => query.value = v,
            ),
          ),
        ),
      ),
      body: apps.connectionState != ConnectionState.done
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final app = shown[i];
                final on = selected.contains(app.packageName);
                return CheckboxListTile(
                  value: on,
                  onChanged: (v) => toggle(app.packageName, v ?? false),
                  secondary: app.icon != null
                      ? Image.memory(app.icon!, width: 36, height: 36, gaplessPlayback: true)
                      : const Icon(Icons.android_rounded, size: 36),
                  title: Text(app.name),
                  subtitle: Text(app.packageName, textDirection: TextDirection.ltr, style: Theme.of(context).textTheme.bodySmall),
                );
              },
            ),
    );
  }
}
