import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/theme/raman_brand.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/proxy/active/ip_widget.dart';
import 'package:hiddify/features/raman/raman_strings.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/utils/number_formatters.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// When the tunnel came up, or null while it is not up. Kept for the whole run of the app, so the
/// timer on the home page goes on counting when the page is rebuilt. A tunnel that was already up
/// when the app opened counts from the moment the app saw it.
final ramanConnectedSinceProvider = StateNotifierProvider<_ConnectedSince, DateTime?>(_ConnectedSince.new);

class _ConnectedSince extends StateNotifier<DateTime?> {
  _ConnectedSince(Ref ref) : super(null) {
    _apply(ref.read(connectionNotifierProvider).valueOrNull);
    ref.listen<AsyncValue<ConnectionStatus>>(connectionNotifierProvider, (_, next) => _apply(next.valueOrNull));
  }

  void _apply(ConnectionStatus? status) {
    switch (status) {
      // a hot reload or a moment without a working proxy keeps the tunnel, and the count
      case Connected() || HotReloading() || NoAvailableProxies():
        state ??= DateTime.now();
      case Disconnected() || Disconnecting():
        state = null;
      default:
    }
  }
}

/// "01:02:03" or "02:03".
String ramanDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// The connection at a glance, under the connect button while the tunnel is up: how long it has
/// been up, the download and upload speeds, the ping, and the server in use with its country.
class RamanConnectionStats extends HookConsumerWidget {
  const RamanConnectionStats({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ramanStringsProvider);
    final theme = Theme.of(context);
    final since = ref.watch(ramanConnectedSinceProvider);
    final up = since != null;

    // one rebuild a second for the timer, only while connected
    final tick = useState(0);
    useEffect(() {
      if (!up) return null;
      final timer = Timer.periodic(const Duration(seconds: 1), (_) => tick.value++);
      return timer.cancel;
    }, [up]);

    final (download, upload) = ref.watch(
      statsNotifierProvider.select((stats) {
        final v = stats.valueOrNull;
        return v == null ? (0, 0) : (v.downlink.toInt(), v.uplink.toInt());
      }),
    );
    final proxy = up ? ref.watch(activeProxyNotifierProvider).valueOrNull : null;
    final delay = proxy?.urlTestDelay ?? 0;
    final pingOk = ConnectionConst.isValidDelay(delay);
    final server = proxy == null ? '' : (proxy.tagDisplay.isNotEmpty ? proxy.tagDisplay : proxy.tag);
    final country = proxy != null && proxy.hasIpinfo() ? proxy.ipinfo.countryCode : '';

    final pingColor = !pingOk
        ? theme.colorScheme.outline
        : delay < 400
        ? RamanBrand.connected
        : delay < 1000
        ? RamanBrand.warning
        : RamanBrand.error;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(sizeFactor: animation, axisAlignment: -1, child: child),
      ),
      child: !up
          ? const SizedBox(key: ValueKey('off'), width: double.infinity)
          : Padding(
              key: const ValueKey('on'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _Stat(
                            icon: Icons.timer_outlined,
                            label: s.statTime,
                            value: ramanDuration(DateTime.now().difference(since)),
                            color: theme.colorScheme.primary,
                          ),
                          _Stat(
                            icon: Icons.south_rounded,
                            label: s.statDownload,
                            value: download.speed(),
                            color: RamanBrand.cyan,
                          ),
                          _Stat(
                            icon: Icons.north_rounded,
                            label: s.statUpload,
                            value: upload.speed(),
                            color: RamanBrand.indigo,
                          ),
                          _Stat(
                            icon: Icons.network_ping_rounded,
                            label: s.statPing,
                            value: pingOk ? '$delay ms' : '—',
                            color: pingColor,
                          ),
                        ],
                      ),
                      if (server.isNotEmpty) ...[
                        const Divider(height: 20, indent: 8, endIndent: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              IPCountryFlag(countryCode: country, size: 20),
                              const Gap(10),
                              Expanded(
                                child: Text(
                                  server,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (country.isNotEmpty)
                                Text(
                                  country.toUpperCase(),
                                  textDirection: TextDirection.ltr,
                                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value, required this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Semantics(
        label: '$label $value',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: .14), shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: color),
            ),
            const Gap(6),
            // numbers and units read left to right in Persian too
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textDirection: TextDirection.ltr,
                maxLines: 1,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
