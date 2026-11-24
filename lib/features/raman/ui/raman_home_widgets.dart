import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_delay_indicator.dart';
import 'package:hiddify/features/raman/ui/raman_ui_strings.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/utils/number_formatters.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Raman VPN 1.9 home pieces. They only READ the connection's state (connectionNotifierProvider,
/// statsNotifierProvider, the active proxy); none of them starts, stops or retries anything.

/// When the tunnel came up, kept in prefs so the timer survives the app being closed while the
/// VPN keeps running. Cleared once the app sees the connection off.
const _kConnectedSince = 'raman-connected-since';

/// The time since the tunnel came up, HH:MM:SS, ticking once a second while it shows.
class RamanConnectionTimer extends HookConsumerWidget {
  const RamanConnectionTimer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(connectionNotifierProvider.select((s) => s.valueOrNull?.isRunning ?? false));
    final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
    final since = useState<DateTime?>(null);
    useEffect(() {
      if (!running) return null;
      final now = DateTime.now();
      final saved = prefs?.getInt(_kConnectedSince);
      final from = saved == null ? null : DateTime.fromMillisecondsSinceEpoch(saved);
      if (from != null && from.isBefore(now)) {
        since.value = from;
      } else {
        since.value = now;
        prefs?.setInt(_kConnectedSince, now.millisecondsSinceEpoch);
      }
      return null;
    }, [running]);
    final tick = useState(0);
    useEffect(() {
      if (!running) return null;
      final timer = Timer.periodic(const Duration(seconds: 1), (_) => tick.value++);
      return timer.cancel;
    }, [running]);
    final from = since.value;
    if (!running || from == null) return const SizedBox.shrink();
    final d = DateTime.now().difference(from);
    String two(int n) => n.toString().padLeft(2, '0');
    final text = '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
    final theme = Theme.of(context);
    return Text(
      text,
      textDirection: TextDirection.ltr,
      style: theme.textTheme.titleMedium?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 1,
      ),
    );
  }
}

/// Clears the saved start time once the connection is off. Put once on the home page.
class RamanConnectionSinceKeeper extends HookConsumerWidget {
  const RamanConnectionSinceKeeper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(connectionNotifierProvider, (previous, next) {
      if (next.valueOrNull is Disconnected) {
        ref.read(sharedPreferencesProvider).valueOrNull?.remove(_kConnectedSince);
      }
    });
    return const SizedBox.shrink();
  }
}

/// Live download / upload speed and the ping of the server in use, in one row of small pills.
/// The row keeps its height when the tunnel is off, so the button does not move.
class RamanLiveStatsRow extends ConsumerWidget {
  const RamanLiveStatsRow({super.key});

  static const height = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(connectionNotifierProvider.select((s) => s.valueOrNull?.isRunning ?? false));
    if (!running) return const SizedBox(height: height);
    final ui = ref.watch(ramanUiStringsProvider);
    final (down, up) = ref.watch(
      statsNotifierProvider.select((stats) {
        final s = stats.valueOrNull;
        return s == null ? (0, 0) : (s.downlink.toInt(), s.uplink.toInt());
      }),
    );
    // a narrow phone or a large font: the row shrinks as a whole instead of overflowing
    return SizedBox(
      height: height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SpeedPill(icon: Icons.south_rounded, value: down.speed(), label: ui.download),
            const Gap(8),
            _SpeedPill(icon: Icons.north_rounded, value: up.speed(), label: ui.upload),
            const Gap(8),
            // the existing ping pill: a tap tests the ping again, a long press the upload speed
            const ActiveProxyDelayIndicator(),
          ],
        ),
      ),
    );
  }
}

class _SpeedPill extends StatelessWidget {
  const _SpeedPill({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const Gap(4),
            Text(
              value,
              textDirection: TextDirection.ltr,
              style: theme.textTheme.labelLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small caption over a card or a group of tiles.
class RamanSectionLabel extends StatelessWidget {
  const RamanSectionLabel(this.text, {super.key, this.padding = const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 6)});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// A settings icon in a small tinted rounded square, the same on every settings row.
class RamanTileIcon extends StatelessWidget {
  const RamanTileIcon(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
    );
  }
}
