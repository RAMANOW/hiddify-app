import 'dart:async';

import 'package:hiddify/core/model/optional_range.dart';
import 'package:hiddify/features/connection/data/connection_data_providers.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/raman/network_checker.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The TLS tricks Raman VPN can try, each a complete setting of the core's TLS tricks (they apply
/// to every TLS and REALITY connection to the server). No single one works on every network in
/// Iran in 2026: fragmenting the ClientHello still gets some networks past SNI filtering, while
/// on others fragmented ClientHellos are dropped and only an untouched one goes through.
enum TlsPreset {
  /// No tricks: the ClientHello as the browser fingerprint sends it (REALITY and XHTTP friendly).
  off(fragment: false),

  /// Raman VPN's default since 1.1: small pieces, short pauses.
  raman(fragment: true, size: OptionalRange(min: 10, max: 30), sleep: OptionalRange(min: 2, max: 8)),

  /// The values Hiddify's guide suggests (TLS Hello, 100-200 bytes, 10-20 ms).
  hiddify(fragment: true, size: OptionalRange(min: 100, max: 200), sleep: OptionalRange(min: 10, max: 20)),

  /// Very small pieces with very short pauses, reported to help on some mobile networks.
  tiny(fragment: true, size: OptionalRange(min: 1, max: 3), sleep: OptionalRange(min: 1, max: 5)),

  /// No fragment, the server name in mixed case.
  mixedSni(fragment: false, sniCase: true);

  const TlsPreset({required this.fragment, this.size, this.sleep, this.sniCase = false});

  final bool fragment;
  final OptionalRange? size;
  final OptionalRange? sleep;
  final bool sniCase;

  /// The preset the current settings match, or null for values set by hand.
  static TlsPreset? current(T Function<T>(ProviderListenable<T>) read) {
    final fragment = read(ConfigOptions.enableTlsFragment);
    final mixed = read(ConfigOptions.enableTlsMixedSniCase);
    final size = read(ConfigOptions.tlsFragmentSize);
    final sleep = read(ConfigOptions.tlsFragmentSleep);
    if (read(ConfigOptions.enableTlsPadding)) return null;
    for (final p in values) {
      if (p.fragment != fragment || p.sniCase != mixed) continue;
      if (!p.fragment) return p;
      if (p.size!.min == size.min && p.size!.max == size.max && p.sleep!.min == sleep.min && p.sleep!.max == sleep.max) {
        return p;
      }
    }
    return null;
  }

  /// Writes the preset. TLS padding is turned off with it: padding and fragment cancel each other.
  Future<void> apply(T Function<T>(ProviderListenable<T>) read) async {
    await read(ConfigOptions.enableTlsPadding.notifier).update(false);
    await read(ConfigOptions.enableTlsMixedSniCase.notifier).update(sniCase);
    if (fragment) {
      await read(ConfigOptions.tlsFragmentSize.notifier).update(size!);
      await read(ConfigOptions.tlsFragmentSleep.notifier).update(sleep!);
    }
    await read(ConfigOptions.enableTlsFragment.notifier).update(fragment);
  }
}

/// How one preset did: how many of the test requests went through the tunnel, and their median
/// time.
class TlsTrial {
  const TlsTrial(this.preset, this.ok, this.total, this.medianMs);

  final TlsPreset preset;
  final int ok;
  final int total;
  final int? medianMs;

  /// More answers first, then the faster.
  int compareTo(TlsTrial other) {
    if (ok != other.ok) return other.ok.compareTo(ok);
    return (medianMs ?? 1 << 30).compareTo(other.medianMs ?? 1 << 30);
  }
}

class TlsTunerState {
  const TlsTunerState({this.running = false, this.trying, this.trials = const [], this.best, this.error});

  final bool running;
  final TlsPreset? trying;
  final List<TlsTrial> trials;
  final TlsPreset? best;

  /// Why the last run stopped early: 'notConnected', or 'noneWorked'.
  final String? error;
}

final tlsTunerProvider = StateNotifierProvider<TlsTunerNotifier, TlsTunerState>(TlsTunerNotifier.new);

/// Finds the TLS trick that works best on the network in use: while connected, it applies each
/// preset in turn, lets the core reload, sends a few requests through the tunnel, and keeps the
/// preset that answered the most (then the fastest). When none answers, the settings from before
/// are put back.
class TlsTunerNotifier extends StateNotifier<TlsTunerState> with InfraLogger {
  TlsTunerNotifier(this._ref) : super(const TlsTunerState());

  final Ref _ref;

  static const _probes = [
    CheckTarget('gstatic', 'https://www.gstatic.com/generate_204'),
    CheckTarget('cloudflare', 'https://www.cloudflare.com/cdn-cgi/trace'),
  ];
  static const _rounds = 2;

  bool get _connected => _ref.read(connectionNotifierProvider).valueOrNull is Connected;

  Future<void> run() async {
    if (state.running) return;
    if (!_connected) {
      state = const TlsTunerState(error: 'notConnected');
      return;
    }
    final read = _ref.read;
    final before = (
      fragment: read(ConfigOptions.enableTlsFragment),
      size: read(ConfigOptions.tlsFragmentSize),
      sleep: read(ConfigOptions.tlsFragmentSleep),
      mixed: read(ConfigOptions.enableTlsMixedSniCase),
      padding: read(ConfigOptions.enableTlsPadding),
    );
    final trials = <TlsTrial>[];
    state = const TlsTunerState(running: true);
    try {
      for (final preset in TlsPreset.values) {
        if (!mounted) return;
        state = TlsTunerState(running: true, trying: preset, trials: List.of(trials));
        await preset.apply(read);
        await _reloaded();
        trials.add(await _measure(preset));
        loggy.info("tls tuner: ${preset.name} ${trials.last.ok}/${trials.last.total} ${trials.last.medianMs}ms");
      }
      final ranked = List.of(trials)..sort((a, b) => a.compareTo(b));
      final best = ranked.first;
      if (best.ok == 0) {
        await read(ConfigOptions.enableTlsPadding.notifier).update(before.padding);
        await read(ConfigOptions.enableTlsMixedSniCase.notifier).update(before.mixed);
        await read(ConfigOptions.tlsFragmentSize.notifier).update(before.size);
        await read(ConfigOptions.tlsFragmentSleep.notifier).update(before.sleep);
        await read(ConfigOptions.enableTlsFragment.notifier).update(before.fragment);
        await _reloaded();
        if (mounted) state = TlsTunerState(trials: trials, error: 'noneWorked');
        return;
      }
      await best.preset.apply(read);
      await _reloaded();
      if (mounted) state = TlsTunerState(trials: trials, best: best.preset);
    } catch (e, st) {
      loggy.warning("tls tuner failed", e, st);
      if (mounted) state = TlsTunerState(trials: trials, error: 'noneWorked');
    }
  }

  /// Makes sure the core runs with the settings just written, then waits until it is connected
  /// again (at most 25 s). The settings listener reloads the core on a change, but skips changes
  /// that come within 100 ms of the one before, so a reload is asked for here when the running
  /// options still differ.
  Future<void> _reloaded() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final running = _ref.read(connectionRepositoryProvider).configOptionsSnapshot;
    final wanted = _ref.read(ConfigOptions.singboxConfigOptions);
    if (running != wanted && _ref.read(connectionNotifierProvider).valueOrNull?.isRunning == true) {
      final profile = await _ref.read(activeProfileProvider.future);
      await _ref.read(connectionNotifierProvider.notifier).reconnect(profile);
    }
    final deadline = DateTime.now().add(const Duration(seconds: 25));
    await Future<void>.delayed(const Duration(milliseconds: 800));
    while (DateTime.now().isBefore(deadline)) {
      if (_connected) break;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    // a moment for the first connections after a reload
    await Future<void>.delayed(const Duration(seconds: 1));
  }

  Future<TlsTrial> _measure(TlsPreset preset) async {
    final times = <int>[];
    var total = 0;
    for (var round = 0; round < _rounds; round++) {
      final results = await Future.wait(_probes.map(NetworkCheckNotifier.check));
      for (final r in results) {
        total++;
        if (r.ok) times.add(r.latencyMs!);
      }
    }
    times.sort();
    return TlsTrial(preset, times.length, total, times.isEmpty ? null : times[times.length ~/ 2]);
  }
}
