import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_delay_indicator.dart';
import 'package:hiddify/core/theme/raman_brand.dart';
import 'package:hiddify/features/raman/home/raman_connection_stats.dart';
import 'package:hiddify/features/raman/raman_strings.dart';
import 'package:hiddify/features/raman/shield/shield_controller.dart';
import 'package:hiddify/features/raman/shield/shield_settings_page.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/uri_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const _shieldGreen = RamanBrand.connected;
const _shieldAmber = RamanBrand.warning;

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
    final split = ref.watch(ShieldPrefs.splitMode);
    final lan = ref.watch(ConfigOptions.allowConnectionFromLan);
    final port = ref.watch(ConfigOptions.lanSharingPort);
    final controller = ref.read(shieldControllerProvider);

    // Shield's connection changes: a sound and/or vibration, and the website to open once connected
    ref.listen(connectionNotifierProvider, (previous, next) {
      if (!ref.read(shieldActiveProvider)) return;
      final before = previous?.valueOrNull;
      final now = next.valueOrNull;
      if (before == null || now == null) return;
      final becameConnected = now is Connected && before is! Connected;
      final becameDisconnected = now is Disconnected && before is! Disconnected;
      if (!becameConnected && !becameDisconnected) return;
      ShieldPlatform.statusFeedback(
        sound: ref.read(ShieldPrefs.notifySound),
        vibrate: ref.read(ShieldPrefs.notifyVibrate),
      );
      if (becameConnected && ref.read(ShieldPrefs.openSite)) {
        final uri = Uri.tryParse(ref.read(ShieldPrefs.openSiteUrl));
        if (uri != null && uri.host.isNotEmpty) UriUtils.tryLaunch(uri);
      }
    });

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
          child: _ShieldButton(
            color: color,
            connected: status is Connected,
            busy: running && status is! Connected,
            label: running ? s.shieldDisconnect : s.shieldConnect,
            onTap: status is Disconnecting ? null : onTap,
          ),
        ),
        const Gap(16),
        Text(label, textAlign: TextAlign.center, style: theme.textTheme.titleSmall?.copyWith(color: color)),
        if (shieldActive && status.isRunning) const Center(child: ActiveProxyDelayIndicator()),
        if (shieldActive) const RamanConnectionStats(),
        const Gap(16),
        Card(
          child: ListTile(
            leading: Text(shieldFlag(region == PsiphonRegion.auto ? '' : region.key), style: const TextStyle(fontSize: 24)),
            title: Text(s.shieldRegion),
            subtitle: Text(region == PsiphonRegion.auto ? s.shieldRegionAuto : region.present(t)),
            trailing: const Icon(Icons.arrow_drop_down_rounded),
            onTap: () => pickShieldRegion(context, ref),
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
              ListTile(
                leading: const Icon(Icons.apps_rounded),
                title: Text(s.shieldPerApp),
                subtitle: Text(switch (split) {
                  ShieldSplitMode.all => s.ssSplitAll,
                  ShieldSplitMode.include => s.ssSplitInclude,
                  ShieldSplitMode.exclude => s.ssSplitExclude,
                }),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openSettings(context),
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
        Card(
          child: ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: Text(s.ssOpen),
            subtitle: Text(s.ssOpenSub),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openSettings(context),
          ),
        ),
      ],
    );
  }

  static void _openSettings(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ShieldSettingsPage()));
}

/// Shield's connect button: the logo's gradient at rest, a turning arc with soft ripples while it
/// connects, a green glow once connected.
class _ShieldButton extends HookWidget {
  const _ShieldButton({
    required this.color,
    required this.connected,
    required this.busy,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final bool connected;
  final bool busy;
  final String label;
  final VoidCallback? onTap;

  static const _size = 184.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final spin = useAnimationController(duration: const Duration(milliseconds: 1400));
    useEffect(() {
      if (busy && !reduceMotion) {
        spin.repeat();
      } else {
        spin.stop();
        spin.value = 0;
      }
      return null;
    }, [busy, reduceMotion]);
    final idle = !busy && !connected;
    final fill = idle
        ? RamanBrand.gradient
        : LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [Color.lerp(color, Colors.white, .12)!, color],
          );

    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: _size + 40,
        height: _size + 40,
        child: AnimatedBuilder(
          animation: spin,
          builder: (context, child) => CustomPaint(
            painter: _RingPainter(
              progress: spin.value,
              color: busy ? color : (connected ? color : RamanBrand.blue),
              busy: busy,
              glow: connected,
            ),
            child: child,
          ),
          child: Center(
            child: AnimatedScale(
              scale: connected ? 1 : (busy ? .96 : 1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: Ink(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: fill,
                    boxShadow: [
                      BoxShadow(
                        color: (idle ? RamanBrand.blue : color).withValues(alpha: connected ? .45 : .25),
                        blurRadius: connected ? 36 : 20,
                        spreadRadius: connected ? 2 : 0,
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: onTap,
                    customBorder: const CircleBorder(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                          child: Icon(
                            connected ? Icons.verified_user_rounded : Icons.shield_rounded,
                            key: ValueKey(connected),
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                        const Gap(8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            label,
                            key: ValueKey(label),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.busy, required this.glow});

  final double progress;
  final Color color;
  final bool busy;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = _ShieldButton._size / 2 + 10;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = color.withValues(alpha: glow ? .55 : .16);
    canvas.drawCircle(center, radius, track);
    if (!busy) return;
    // two ripples spreading out
    for (final phase in [0.0, .5]) {
      final p = (progress + phase) % 1;
      final ripple = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: (1 - p) * .35);
      canvas.drawCircle(center, radius + p * 14, ripple);
    }
    // a turning arc
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0), color],
        transform: GradientRotation(progress * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * 2 * math.pi,
      math.pi * 1.2,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.busy != busy || old.glow != glow;
}
