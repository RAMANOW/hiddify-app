import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/theme/raman_brand.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/ambient_motion.dart';
import 'package:hiddify/core/widget/unique_keys_layout.dart';
import 'package:hiddify/features/chain/model/chain_enum.dart';
import 'package:hiddify/features/chain/overview/chain_mode_icon.dart';
import 'package:hiddify/features/connection/model/connection_failure.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/proxy/model/connection_health.dart';
import 'package:hiddify/features/proxy/model/proxy_entity.dart';
import 'package:hiddify/features/raman/ui/raman_home_widgets.dart';
import 'package:hiddify/features/raman/ui/raman_ui_strings.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// What the button shows, one value per look.
enum _Look { loading, disconnected, connecting, waiting, noProxies, connected, hotReloading, disconnecting, failed }

/// One look per status the core reports. The core decides when the tunnel is waiting for a ping
/// and when it is connected; the button only shows it.
///
/// The status reloads after every core start; until the new stream answers,
/// the last status holds. A failed start comes back as disconnected with the
/// failure attached.
///
/// A hot reload keeps the tunnel up and has a look of its own.
_Look _lookOf(AsyncValue<ConnectionStatus> status) => switch (status) {
  AsyncError() => _Look.failed,
  AsyncValue(valueOrNull: Disconnected(connectionFailure: _?)) => _Look.failed,
  AsyncValue(valueOrNull: Disconnected()) => _Look.disconnected,
  AsyncValue(valueOrNull: Connecting()) => _Look.connecting,
  AsyncValue(valueOrNull: Waiting()) => _Look.waiting,
  AsyncValue(valueOrNull: NoAvailableProxies()) => _Look.noProxies,
  AsyncValue(valueOrNull: HotReloading()) => _Look.hotReloading,
  AsyncValue(valueOrNull: Connected()) => _Look.connected,
  AsyncValue(valueOrNull: Disconnecting()) => _Look.disconnecting,
  _ => _Look.loading,
};

class ConnectionButton extends HookConsumerWidget {
  const ConnectionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final status = ref.watch(connectionNotifierProvider);
    final look = _held(_lookOf(status));

    // What a tap does follows the core alone, and the core can be stopped whatever it is doing: a
    // tunnel that is up, a start in progress, and a hot reload all turn off at once, and the core
    // cancels what it was busy with.
    final onTap = switch (status) {
      AsyncData(value: Disconnected()) || AsyncError() => () => _connect(ref),
      AsyncData(value: Connected() || Waiting() || NoAvailableProxies() || Connecting() || HotReloading()) =>
        () => ref.read(connectionNotifierProvider.notifier).toggleConnection(),
      _ => null,
    };

    final failure = switch (status) {
      AsyncError(:final ConnectionFailure error) => error,
      AsyncValue(valueOrNull: Disconnected(connectionFailure: final failure?)) => failure,
      _ => null,
    };
    // Connected means some server answers; the user's pick or the chain hop can still be down.
    final health = ref.watch(connectionHealthProvider);
    final h = t.connection.health;
    final chainName = health?.chain?.present(t) ?? '';
    final degraded = look == _Look.connected && (health?.degraded ?? false);
    final hopPending = look == _Look.connected && (health?.hopPending ?? false);

    final buttonTheme = Theme.of(context).extension<ConnectionButtonTheme>() ?? ConnectionButtonTheme.light;
    final ui = ref.watch(ramanUiStringsProvider);
    // Raman VPN 1.9: what a tap does, and every state, are the same as before; only the look is
    // new (one round power button, a short state word, and the details under it).
    final detailedLabel = switch (look) {
      _Look.loading => "",
      _Look.disconnected => t.connection.tapToConnect,
      _Look.connecting => t.connection.connecting,
      _Look.waiting => t.connection.waiting,
      _Look.noProxies => t.connection.noAvailableProxies,
      // connected says the traffic gets through; when it does not, say what stops it
      _Look.connected when degraded =>
        health!.pick == HealthState.failed ? h.pickDead : h.hopFailed(chain: chainName),
      _Look.connected when hopPending => h.hopPending(chain: chainName),
      _Look.connected => t.connection.connected,
      _Look.hotReloading => t.connection.hotReloading,
      _Look.disconnecting => t.connection.disconnecting,
      _Look.failed => t.connection.failed,
    };
    final title = switch (look) {
      _Look.loading => "",
      _Look.disconnected => ui.stateDisconnected,
      _Look.connecting || _Look.waiting || _Look.hotReloading => ui.stateConnecting,
      _Look.noProxies => t.connection.noAvailableProxies,
      _Look.connected => ui.stateConnected,
      _Look.disconnecting => ui.stateDisconnecting,
      _Look.failed => ui.stateFailed,
    };
    // the second line: the core's own words where they say more than the state word
    final detail = switch (look) {
      _Look.disconnected => ui.tapToConnect,
      _Look.failed => t.connection.tapToRetry,
      _Look.waiting || _Look.hotReloading => detailedLabel,
      _Look.connected when degraded || hopPending => detailedLabel,
      _ => null,
    };
    final button = _PowerButton(
      look: look,
      onTap: onTap,
      onErrorDetails: failure == null
          ? null
          : () => ref.read(dialogNotifierProvider.notifier).showCustomAlertFromErr(failure.present(t)),
      errorDetailsLabel: ui.errorDetails,
      semanticLabel: detailedLabel,
      title: title,
      detail: detail,
      // the connection timer, only while the tunnel is up and the traffic gets through
      showTimer: look == _Look.connected && !degraded && !hopPending,
      busy: {_Look.connecting, _Look.waiting, _Look.hotReloading, _Look.disconnecting}.contains(look) || hopPending,
      // the chain hop, while the core runs with the chain on
      hop: {_Look.connected, _Look.noProxies, _Look.waiting}.contains(look)
          ? ref.watch(activeProxyCardProvider.select((card) => card?.hopStatus == null ? null : card))
          : null,
      onHop: ref.read(bottomSheetsNotifierProvider.notifier).showConnectionHealth,
      hopLabel: health == null ? '' : '$chainName: ${_hopLabel(h, health)}',
      color: switch (look) {
        _Look.connected when degraded => _degradedColor,
        // the traffic waits for the chain hop: still on its way
        _Look.connected when hopPending => RamanBrand.connecting,
        _Look.connected => buttonTheme.connectedColor!,
        _Look.noProxies => _degradedColor,
        _Look.failed => RamanBrand.error,
        _Look.connecting || _Look.waiting || _Look.hotReloading || _Look.disconnecting => RamanBrand.connecting,
        _ => buttonTheme.idleColor!,
      },
      // reduce animations (the app's own switch or the system's) stills the spinning ring
      reduceMotion: ref.watch(Preferences.reduceAnimations),
    );
    return button;
  }

  /// Coming back from the background, the app sets the core up again, and for a moment the status
  /// can read as not connected though the tunnel never went down. So leaving connected for
  /// [_Look.loading] waits [_hold] before it shows, and nothing changes if
  /// connected is back by then.
  ///
  /// Intentional disconnect must not keep the Connected label: it goes through
  /// [_Look.disconnecting], and a bare Connected→Disconnected jump (no Stopping event) must
  /// also clear immediately — holding disconnected made disconnect feel multi-second slow.
  /// A failure is failed, so it still shows at once.
  _Look _held(_Look look) {
    final shown = useRef(look);
    final until = useRef<DateTime?>(null);
    final rebuild = useState(0);
    final steady = {_Look.connected, _Look.noProxies}.contains(shown.value);
    final blip = {_Look.loading}.contains(look);
    var result = look;
    if (steady && blip) {
      until.value ??= DateTime.now().add(_hold);
      if (DateTime.now().isBefore(until.value!)) {
        result = shown.value;
      } else {
        until.value = null;
      }
    } else {
      until.value = null;
    }
    shown.value = result;
    // shows the new look once the hold is over, if nothing else rebuilds the button first
    useEffect(() {
      final end = until.value;
      if (end == null) return null;
      final timer = Timer(end.difference(DateTime.now()), () => rebuild.value++);
      return timer.cancel;
    }, [until.value]);
    return result;
  }

  static const _hold = Duration(milliseconds: 1500);

  /// Connected, but the traffic does not get through: amber, between connected and failed.
  static const _degradedColor = Color(0xFFE3A63A);

  static String _hopLabel(TranslationsConnectionHealthEn h, ConnectionHealth health) => switch (health.hopState) {
    HealthState.ok => h.hopReady,
    HealthState.pending => h.hopConnecting,
    HealthState.blocked => h.hopBlocked,
    HealthState.failed => health.hopNoReply ? h.hopNoReply : h.hopBroken,
  };

  /// Connects, or sends the user to add a profile when there is none.
  Future<void> _connect(WidgetRef ref) async {
    final dialogs = ref.read(dialogNotifierProvider.notifier);
    if (ref.read(activeProfileProvider).valueOrNull == null) {
      await dialogs.showNoActiveProfile();
      ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
      return;
    }
    if (await dialogs.showExperimentalFeatureNotice()) {
      await ref.read(connectionNotifierProvider.notifier).toggleConnection();
    }
  }
}

/// Raman VPN 1.9: the connect button. One round power button in the state's colour on a soft halo,
/// a thin ring round it that spins only while the connection is on its way, then the state word
/// and one line of detail (or the connection timer) under it. Nothing else on the page moves.
class _PowerButton extends HookWidget {
  const _PowerButton({
    required this.look,
    required this.onTap,
    required this.onErrorDetails,
    required this.errorDetailsLabel,
    required this.semanticLabel,
    required this.title,
    required this.detail,
    required this.showTimer,
    required this.busy,
    required this.hop,
    required this.onHop,
    required this.hopLabel,
    required this.color,
    required this.reduceMotion,
  });

  final _Look look;
  final VoidCallback? onTap;

  /// Shows what went wrong; null when nothing did.
  final VoidCallback? onErrorDetails;
  final String errorDetailsLabel;
  final String semanticLabel;
  final String title;
  final String? detail;
  final bool showTimer;

  /// On its way (connecting, waiting for a ping, reloading, stopping): the ring spins.
  final bool busy;

  /// The chain hop as a badge on the button; null with the chain off.
  final ActiveProxyCardData? hop;
  final VoidCallback onHop;
  final String hopLabel;
  final Color color;
  final bool reduceMotion;

  /// The face of the button, and the halo round it.
  static const _face = 148.0;
  static const _size = 216.0;

  /// The button takes less of a short screen (a TV, a phone held sideways, a small window).
  static const _fullFrom = 820.0;
  static const _smallFrom = 600.0;
  static const _smallest = .7;

  static double _scaleFor(double height) =>
      _smallest + (1 - _smallest) * ((height - _smallFrom) / (_fullFrom - _smallFrom)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scale = _scaleFor(MediaQuery.sizeOf(context).height);
    final still = reduceMotion || MediaQuery.disableAnimationsOf(context);
    final spin = useAnimationController(duration: const Duration(milliseconds: 1400));
    final spinning = busy && !still;
    useEffect(() {
      if (spinning) {
        spin.repeat();
      } else {
        spin.stop();
      }
      return null;
    }, [spinning]);
    final focused = useState(false);
    final loading = look == _Look.loading;
    final up = look == _Look.connected || look == _Look.noProxies;
    final faceColor = loading ? theme.colorScheme.outline : color;
    final deep = Color.lerp(faceColor, Colors.black, dark ? .25 : .18)!;
    final bright = Color.lerp(faceColor, Colors.white, .12)!;

    final face = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      width: _face,
      height: _face,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bright, deep],
        ),
        boxShadow: [
          BoxShadow(color: faceColor.withValues(alpha: up ? .45 : .28), blurRadius: up ? 36 : 22, spreadRadius: up ? 2 : 0),
        ],
      ),
      child: Material(
        key: const ValueKey("home_connection_button"),
        shape: const CircleBorder(),
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onFocusChange: (value) => focused.value = value,
          focusColor: Colors.transparent,
          highlightColor: Colors.white.withValues(alpha: .08),
          splashColor: Colors.white.withValues(alpha: .14),
          child: Center(
            child: Icon(
              Icons.power_settings_new_rounded,
              size: 68,
              color: Colors.white.withValues(alpha: loading ? .6 : 1),
            ),
          ),
        ),
      ),
    );

    final ring = RepaintBoundary(
      child: AnimatedBuilder(
        animation: spin,
        builder: (context, _) => CustomPaint(
          painter: _RingPainter(
            color: faceColor,
            track: faceColor.withValues(alpha: dark ? .22 : .16),
            // the arc spins while busy; a full ring once up; only the track at rest
            sweep: busy ? .28 : (up ? 1 : 0),
            turn: spin.value,
          ),
        ),
      ),
    );

    final button = SizedBox.square(
      dimension: _size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // the soft halo
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: _size,
            height: _size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: faceColor.withValues(alpha: dark ? .12 : .09)),
          ),
          SizedBox.square(dimension: _face + 28, child: ring),
          face,
          // keyboard / TV remote focus: a ring round the button
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: focused.value ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Container(
                width: _face + 44,
                height: _face + 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.primary, width: 3),
                ),
              ),
            ),
          ),
          // the chain hop sits on the rim at the top start, half on the button
          if (hop case final hop?)
            Positioned.fromRect(
              rect: Rect.fromCircle(
                center: const Offset(_size / 2, _size / 2) + Offset.fromDirection(5 * math.pi / 4, _face / 2 + 6),
                radius: _ChainBadge.size / 2,
              ),
              child: _ChainBadge(hop, label: hopLabel, onTap: onHop),
            ),
        ],
      ),
    );

    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: onTap != null,
          label: semanticLabel,
          child: SizedBox.square(
            dimension: _size * scale,
            child: FittedBox(child: button),
          ),
        ),
        Gap(12 * scale),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: loading ? null : faceColor),
        ),
        const Gap(4),
        SizedBox(
          height: 24,
          child: Center(
            child: showTimer
                ? const RamanConnectionTimer()
                : detail == null
                ? const SizedBox.shrink()
                : Text(detail!, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: muted),
          ),
        ),
        if (look == _Look.failed && onErrorDetails != null)
          TextButton.icon(
            onPressed: onErrorDetails,
            icon: const Icon(Icons.info_outline_rounded, size: 18),
            label: Text(errorDetailsLabel),
          ),
      ],
    );
  }
}

/// The thin ring round the button: its track, and an arc of [sweep] (0..1 of a turn) that starts
/// at [turn] (0..1).
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.color, required this.track, required this.sweep, required this.turn});

  final Color color;
  final Color track;
  final double sweep;
  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.0;
    final rect = Offset.zero & size;
    final circle = rect.deflate(stroke / 2);
    canvas.drawArc(
      circle,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (sweep <= 0) return;
    canvas.drawArc(
      circle,
      -math.pi / 2 + 2 * math.pi * turn,
      2 * math.pi * sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color || old.track != track || old.sweep != sweep || old.turn != turn;
}

/// The chain hop on the button: its glyph alone, outlined in the button's face color so it reads
/// on the button and on the page. Filled with a check once up, an outline that breathes while it
/// connects, red with a cross when it fails, grey while it waits for the selected proxy. Opens the
/// connection check.
class _ChainBadge extends StatelessWidget {
  const _ChainBadge(this.card, {required this.label, required this.onTap});
  final ActiveProxyCardData card;
  final String label;
  final VoidCallback onTap;

  static const size = 56.0;

  ChainType get _type => card.chain.isUnblocker() ? ChainType.unblocker : ChainType.extraSecurity;

  IconData get _glyph => switch ((_type, card.hopStatus!)) {
    (ChainType.extraSecurity, StepStatus.connected) => Icons.gpp_good_rounded,
    (ChainType.extraSecurity, StepStatus.failed) => Icons.gpp_bad_rounded,
    (ChainType.extraSecurity, _) => Icons.shield_outlined,
    // a door, not a lock: the unblocker gets the proxy through, it does not secure it. Drawn by
    // PassingDoor; these only tell its running state from its shut one, to switch between them
    (ChainType.unblocker, StepStatus.connected || StepStatus.connecting || StepStatus.slow) =>
      Icons.meeting_room_rounded,
    (ChainType.unblocker, _) => Icons.door_front_door_rounded,
  };

  Widget _glyphWidget(StepStatus status) => switch ((_type, status)) {
    // the traffic keeps getting through on its way and once up, as on the proxy card; still, the
    // door open and the dots lined up, while it waits or fails
    (ChainType.unblocker, _) => PassingDoor(
      size: _glyphSize,
      color: Colors.white,
      animate: status == StepStatus.connecting || status == StepStatus.slow || status == StepStatus.connected,
    ),
    _ => Icon(_glyph, size: _glyphSize, color: Colors.white),
  };

  /// The solid shape under the glyph: the white seal that strokes it and fills its cut-outs. The
  /// door sits on a disc, smaller to stay inside it.
  IconData get _seal => _type == ChainType.extraSecurity ? Icons.shield_rounded : Icons.circle;
  double get _glyphSize => _type == ChainType.extraSecurity ? 40 : 30;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = card.hopStatus!;
    final (main, accent) = _type.colors(card.hopMode);
    // a gradient in the chain's own colors; red when it fails, grey while it waits
    final (from, to) = switch (status) {
      StepStatus.failed => (const Color(0xFFFF6B6B), theme.colorScheme.error),
      StepStatus.waiting => (theme.colorScheme.outline, theme.colorScheme.outlineVariant),
      _ => (main, accent),
    };
    const face = Color(0xFFF7F7F9);
    Widget glyph = SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // the seal: a little larger than the glyph, so it reads as a white stroke, with a soft
          // glow in the state's color
          Icon(
            _seal,
            size: 50,
            color: face,
            shadows: [
              Shadow(color: from.withValues(alpha: status == StepStatus.waiting ? .2 : .55), blurRadius: 14),
              Shadow(color: Colors.black.withValues(alpha: .25), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [from, to],
            ).createShader(rect),
            child: _glyphWidget(status),
          ),
        ],
      ),
    );
    // the loops build from a copy: `glyph` itself becomes the result, and a builder that read it
    // would build itself over and over
    final plain = glyph;
    glyph = switch (status) {
      _ when MediaQuery.disableAnimationsOf(context) => plain,
      // the loops below never end: they run on the ambient clock, with the button's light, and stop
      // with it
      // once up, a light sweeps across it now and then
      StepStatus.connected => AmbientLoop(
        period: 3700.ms,
        still: (_) => plain,
        builder: (context, phase) => plain
            .animate(adapter: ValueNotifierAdapter(phase))
            .shimmer(delay: 2500.ms, duration: 1200.ms, color: Colors.white.withValues(alpha: .7)),
      ),
      // on its way: the door opening says so; the shield breathes
      StepStatus.connecting || StepStatus.slow when _type == ChainType.unblocker => plain,
      StepStatus.connecting || StepStatus.slow => AmbientLoop(
        period: 1800.ms,
        still: (_) => plain,
        builder: (context, phase) => ValueListenableBuilder<double>(
          valueListenable: phase,
          // in and out again, 0.9 s each way
          builder: (context, v, child) =>
              Transform.scale(scale: .92 + .12 * Curves.easeInOut.transform(1 - (2 * v - 1).abs()), child: child),
          child: plain,
        ),
      ),
      // failed: one short shake to catch the eye
      StepStatus.failed => plain.animate().shake(hz: 4, rotation: .06, duration: 500.ms),
      StepStatus.waiting => plain,
    };
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          // its shimmer and breathing repaint the badge alone, not the button and the page
          child: RepaintBoundary(
            child: Center(
              child: AnimatedSwitcher(
                layoutBuilder: uniqueKeysLayout(),
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                child: KeyedSubtree(key: ValueKey(_glyph), child: glyph),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
