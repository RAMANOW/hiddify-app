import 'dart:async';

import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/raman/dns_probe.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmartDnsState {
  const SmartDnsState({
    this.running = false,
    this.results = const [],
    this.lastRun,
    this.bestDirect,
    this.bestRemote,
    this.autoDirect = true,
    this.autoRemote = true,
    this.testedWithVpn = false,
  });

  final bool running;
  final List<DnsProbeResult> results;
  final DateTime? lastRun;
  final String? bestDirect;
  final String? bestRemote;
  final bool autoDirect;
  final bool autoRemote;

  /// The last test ran while the VPN was on, so its numbers went through the tunnel.
  final bool testedWithVpn;

  SmartDnsState copyWith({
    bool? running,
    List<DnsProbeResult>? results,
    DateTime? lastRun,
    String? bestDirect,
    String? bestRemote,
    bool? autoDirect,
    bool? autoRemote,
    bool? testedWithVpn,
  }) => SmartDnsState(
    running: running ?? this.running,
    results: results ?? this.results,
    lastRun: lastRun ?? this.lastRun,
    bestDirect: bestDirect ?? this.bestDirect,
    bestRemote: bestRemote ?? this.bestRemote,
    autoDirect: autoDirect ?? this.autoDirect,
    autoRemote: autoRemote ?? this.autoRemote,
    testedWithVpn: testedWithVpn ?? this.testedWithVpn,
  );
}

final smartDnsProvider = StateNotifierProvider<SmartDnsNotifier, SmartDnsState>((ref) => SmartDnsNotifier(ref));

/// Raman VPN's automatic DNS: tests the built-in resolvers and sets the fastest working ones as the
/// direct and remote DNS, on start (at most once a day) and when the user asks.
class SmartDnsNotifier extends StateNotifier<SmartDnsState> with InfraLogger {
  SmartDnsNotifier(this._ref) : super(const SmartDnsState()) {
    final p = _prefs;
    final last = p.getInt(_kLastRun);
    state = SmartDnsState(
      lastRun: last == null ? null : DateTime.fromMillisecondsSinceEpoch(last),
      bestDirect: p.getString(_kBestDirect),
      bestRemote: p.getString(_kBestRemote),
      autoDirect: p.getBool(_kAutoDirect) ?? true,
      autoRemote: p.getBool(_kAutoRemote) ?? true,
    );
  }

  final Ref _ref;
  Timer? _timer;

  static const _kLastRun = 'raman-smart-dns-last-run';
  static const _kBestDirect = 'raman-smart-dns-best-direct';
  static const _kBestRemote = 'raman-smart-dns-best-remote';
  static const _kAutoDirect = 'raman-smart-dns-auto-direct';
  static const _kAutoRemote = 'raman-smart-dns-auto-remote';
  static const interval = Duration(days: 1);

  SharedPreferences get _prefs => _ref.read(sharedPreferencesProvider).requireValue;

  bool get _vpnOn => _ref.read(connectionNotifierProvider).asData?.value.isConnected ?? false;

  /// Runs the test when the last one is more than a day old, and checks again every few hours
  /// while the app stays open. Called once, a few seconds after start, so it never slows the launch.
  Future<void> startAutoChecks() async {
    _timer ??= Timer.periodic(const Duration(hours: 3), (_) => unawaited(maybeAutoRun()));
    await maybeAutoRun();
  }

  Future<void> maybeAutoRun() async {
    if (!state.autoDirect && !state.autoRemote) return;
    final last = state.lastRun;
    if (last != null && DateTime.now().difference(last) < interval) return;
    // through the tunnel the core answers DNS itself, so the numbers would say little
    if (_vpnOn) return;
    await runTest(apply: true);
  }

  Future<void> setAutoDirect(bool value) async {
    state = state.copyWith(autoDirect: value);
    await _prefs.setBool(_kAutoDirect, value);
  }

  Future<void> setAutoRemote(bool value) async {
    state = state.copyWith(autoRemote: value);
    await _prefs.setBool(_kAutoRemote, value);
  }

  /// Tests every resolver at once, then, with [apply], writes the winners to the DNS settings
  /// that are on automatic.
  Future<void> runTest({bool apply = true}) async {
    if (state.running) return;
    final withVpn = _vpnOn;
    state = state.copyWith(running: true, testedWithVpn: withVpn);
    try {
      final results = await Future.wait(RamanDnsServers.all.map((s) => DnsProbe.probe(s)));
      results.sort((a, b) {
        if (a.ok != b.ok) return a.ok ? -1 : 1;
        return (a.latencyMs ?? 1 << 30).compareTo(b.latencyMs ?? 1 << 30);
      });
      final working = results.where((r) => r.ok).toList();

      // direct DNS: plain UDP is the lightest for domestic sites; any working resolver will do
      // (an honest answer first: the proxy servers' own names are looked up there too)
      final udp = working.where((r) => r.server.transport == DnsTransport.udp);
      final direct = udp.where((r) => !r.poisoned).firstOrNull ?? udp.firstOrNull ?? working.firstOrNull;
      // remote DNS goes through the proxy: an international resolver, never a filtered answer
      final remote = working.where((r) => !r.server.domestic && !r.poisoned).firstOrNull ??
          working.where((r) => !r.server.domestic).firstOrNull;

      final now = DateTime.now();
      final p = _prefs;
      await p.setInt(_kLastRun, now.millisecondsSinceEpoch);
      if (direct != null) await p.setString(_kBestDirect, direct.server.address);
      if (remote != null) await p.setString(_kBestRemote, remote.server.remoteAddress);
      state = state.copyWith(
        running: false,
        results: results,
        lastRun: now,
        bestDirect: direct?.server.address,
        bestRemote: remote?.server.remoteAddress,
      );

      if (apply) {
        if (state.autoDirect && direct != null) {
          await _ref.read(ConfigOptions.directDnsAddress.notifier).update(direct.server.address);
        }
        if (state.autoRemote && remote != null) {
          await _ref.read(ConfigOptions.remoteDnsAddress.notifier).update(remote.server.remoteAddress);
        }
      }
      loggy.info('smart dns: direct=${direct?.server.address} remote=${remote?.server.remoteAddress}');
    } catch (e, st) {
      loggy.warning('smart dns test failed', e, st);
      state = state.copyWith(running: false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
