import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_links.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_tunnel_controller.dart';
import 'package:hiddify/features/raman/finder/finder_core.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Raman VPN 1.8.3 «کانفیگ‌یاب»: reads public free-config lists, tests the configs from the phone
/// and keeps the best ones in one local profile of that name (updated in place on each run). It
/// never starts, stops or reloads a connection and never changes the active profile, except when
/// the user taps "use this profile".
abstract class FinderPrefs {
  /// The user's own sources (JSON list of URLs).
  static const sources = 'raman-finder-sources';

  /// Built-in sources the user turned off (JSON list of URLs).
  static const off = 'raman-finder-off';
  static const keep = 'raman-finder-keep';

  /// 0 = off.
  static const autoHours = 'raman-finder-auto-hours';
  static const profileId = 'raman-finder-profile-id';

  /// The last run: {at, saved, best, passed, tested, candidates}.
  static const last = 'raman-finder-last';
}

const finderProfileName = 'کانفیگ‌یاب';
const finderMaxCandidates = 300;
const finderKeepChoices = [10, 20, 30, 50];
const finderAutoChoices = [0, 6, 12, 24];

enum FinderPhase { idle, fetching, testing, saving, done }

/// What one source gave in the last run: configs found, or the error.
class FinderSourceResult {
  const FinderSourceResult(this.found, this.error);

  final int found;
  final String? error;
}

class FinderState {
  const FinderState({
    this.phase = FinderPhase.idle,
    this.done = 0,
    this.total = 0,
    this.sources = const {},
    this.candidates = 0,
    this.passed = 0,
    this.saved = 0,
    this.bestMs,
    this.dnsAdded = 0,
    this.error,
  });

  final FinderPhase phase;
  final int done;
  final int total;
  final Map<String, FinderSourceResult> sources;
  final int candidates;
  final int passed;
  final int saved;
  final int? bestMs;
  final int dnsAdded;

  /// 'fetch' (no source answered), 'none' (nothing passed), 'save', or null.
  final String? error;

  bool get running => phase == FinderPhase.fetching || phase == FinderPhase.testing || phase == FinderPhase.saving;

  FinderState copyWith({
    FinderPhase? phase,
    int? done,
    int? total,
    Map<String, FinderSourceResult>? sources,
    int? candidates,
    int? passed,
    int? saved,
    int? bestMs,
    int? dnsAdded,
    String? error,
  }) => FinderState(
    phase: phase ?? this.phase,
    done: done ?? this.done,
    total: total ?? this.total,
    sources: sources ?? this.sources,
    candidates: candidates ?? this.candidates,
    passed: passed ?? this.passed,
    saved: saved ?? this.saved,
    bestMs: bestMs ?? this.bestMs,
    dnsAdded: dnsAdded ?? this.dnsAdded,
    error: error ?? this.error,
  );
}

/// The last run as saved: when, how many kept, best delay.
class FinderLastRun {
  const FinderLastRun(this.at, this.saved, this.bestMs, this.passed, this.tested);

  final DateTime at;
  final int saved;
  final int? bestMs;
  final int passed;
  final int tested;
}

final finderControllerProvider = Provider<FinderController>((ref) {
  final c = FinderController(ref);
  ref.onDispose(c.dispose);
  return c;
});

class FinderController with InfraLogger {
  FinderController(this._ref);

  final Ref _ref;
  final state = ValueNotifier(const FinderState());
  final sourcesVersion = ValueNotifier(0);
  bool _cancel = false;
  Timer? _autoTimer;

  SharedPreferences get _prefs => _ref.read(sharedPreferencesProvider).requireValue;

  void dispose() {
    _autoTimer?.cancel();
    state.dispose();
    sourcesVersion.dispose();
  }

  // ---- settings ----

  List<String> _list(String key) {
    try {
      final raw = _prefs.getString(key);
      if (raw == null || raw.isEmpty) return const [];
      return (jsonDecode(raw) as List).whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _setList(String key, List<String> v) async {
    await _prefs.setString(key, jsonEncode(v));
    sourcesVersion.value++;
  }

  List<String> get userSources => _list(FinderPrefs.sources);
  Set<String> get disabledBuiltins => _list(FinderPrefs.off).toSet();

  /// Adds a source the user typed; false when it is not a raw URL / t.me link / @channel.
  Future<bool> addSource(String input) async {
    final url = normalizeFinderSource(input);
    if (url == null) return false;
    final list = userSources.toList();
    if (!list.contains(url) && !builtinFinderSources.any((s) => s.url == url)) list.add(url);
    await _setList(FinderPrefs.sources, list);
    return true;
  }

  Future<void> removeSource(String url) => _setList(FinderPrefs.sources, userSources.where((e) => e != url).toList());

  Future<void> setBuiltinOn(String url, bool on) {
    final off = disabledBuiltins;
    on ? off.remove(url) : off.add(url);
    return _setList(FinderPrefs.off, off.toList());
  }

  int get keep => _prefs.getInt(FinderPrefs.keep) ?? 20;
  Future<void> setKeep(int v) async {
    await _prefs.setInt(FinderPrefs.keep, v);
    sourcesVersion.value++;
  }

  int get autoHours => _prefs.getInt(FinderPrefs.autoHours) ?? 0;
  Future<void> setAutoHours(int v) async {
    await _prefs.setInt(FinderPrefs.autoHours, v);
    sourcesVersion.value++;
    startAutoRefresh();
  }

  String? get profileId => _prefs.getString(FinderPrefs.profileId);

  FinderLastRun? get lastRun {
    try {
      final raw = _prefs.getString(FinderPrefs.last);
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map;
      return FinderLastRun(
        DateTime.parse(m['at'] as String),
        m['saved'] as int? ?? 0,
        m['best'] as int?,
        m['passed'] as int? ?? 0,
        m['tested'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  List<FinderSource> get activeSources => [
    ...builtinFinderSources.where((s) => !disabledBuiltins.contains(s.url)),
    for (final u in userSources) FinderSource(u, telegramChannelOf(u) != null ? 'Telegram · ${telegramChannelOf(u)}' : Uri.parse(u).host),
  ];

  // ---- auto refresh (off by default; only while the app runs) ----

  /// Called once from the home page: a run when one is due, then a check every 30 minutes.
  void startAutoRefresh() {
    _autoTimer?.cancel();
    if (autoHours <= 0) return;
    unawaited(_autoIfDue());
    _autoTimer = Timer.periodic(const Duration(minutes: 30), (_) => unawaited(_autoIfDue()));
  }

  Future<void> _autoIfDue() async {
    final h = autoHours;
    if (h <= 0 || state.value.running) return;
    final last = lastRun?.at;
    if (last != null && DateTime.now().difference(last) < Duration(hours: h)) return;
    loggy.info('config finder: auto refresh');
    await run();
  }

  // ---- run ----

  void cancel() => _cancel = true;

  Future<bool> _portOpen(int port) async {
    try {
      final s = await Socket.connect('127.0.0.1', port, timeout: const Duration(milliseconds: 300));
      s.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// One full search. Safe to call while connected: it only reads pages, opens test sockets from
  /// the app (outside its own VPN) and writes the «کانفیگ‌یاب» profile.
  Future<void> run() async {
    if (state.value.running) return;
    _cancel = false;
    final sources = activeSources;
    state.value = FinderState(phase: FinderPhase.fetching, total: sources.length);

    // the core's local port (open when the local proxy is on) reads blocked sites through the
    // connection; otherwise the pages are read directly
    final port = _ref.read(ConfigOptions.mixedPort);
    final proxyPort = await _portOpen(port) ? port : null;

    final results = <String, FinderSourceResult>{};
    final perSource = List<List<FinderEndpoint>>.filled(sources.length, const []);
    final bodies = List<String?>.filled(sources.length, null);
    var fetched = 0;
    await runPool<int, void>(
      List.generate(sources.length, (i) => i),
      (i) async {
        final s = sources[i];
        String? body;
        String? error;
        for (final p in [if (proxyPort != null) proxyPort, null]) {
          try {
            body = await fetchFinderSource(s.url, proxyPort: p);
            break;
          } catch (e) {
            error = e.toString();
          }
        }
        bodies[i] = body;
        if (body != null) {
          final eps = <FinderEndpoint>[];
          for (final l in extractFinderLinks(body, telegram: s.isTelegram)) {
            final e = parseFinderLink(l);
            if (e != null) eps.add(e);
          }
          perSource[i] = eps;
          results[s.url] = FinderSourceResult(eps.length, null);
        } else {
          results[s.url] = FinderSourceResult(0, error ?? 'error');
        }
        fetched++;
        state.value = state.value.copyWith(done: fetched, sources: Map.of(results));
      },
      concurrency: 4,
      cancelled: () => _cancel,
    );
    if (_cancel) return _stopped();

    // DNS-tunnel links (soar / cotten / dnstt / slipstream / masterdns) go to the DNS tab's store
    var dnsAdded = 0;
    final dnsText = bodies.whereType<String>().where((b) => dnsLinkSchemeRe.hasMatch(b)).join('\n');
    if (dnsText.isNotEmpty) {
      try {
        dnsAdded = await _ref.read(dnsTunnelControllerProvider).addFromText(dnsText);
      } catch (e) {
        loggy.warning('config finder: dns links not saved: $e');
      }
    }

    if (bodies.every((b) => b == null)) {
      state.value = state.value.copyWith(phase: FinderPhase.done, error: 'fetch', dnsAdded: dnsAdded);
      return;
    }

    // dedupe across sources, take turns between sources, at most finderMaxCandidates; UDP ones
    // (hy2, tuic, quic/kcp) can not be tested from here and are left out
    final seen = <String>{};
    final unique = [
      for (final l in perSource) [for (final e in l) if (!e.udp && seen.add(e.key)) e],
    ];
    final candidates = interleave(unique, finderMaxCandidates);
    state.value = state.value.copyWith(
      phase: FinderPhase.testing,
      done: 0,
      total: candidates.length,
      candidates: candidates.length,
      dnsAdded: dnsAdded,
    );

    var passed = 0;
    final delays = await runPool<FinderEndpoint, int?>(
      candidates,
      (e) async {
        final ms = await probeFinderEndpoint(e);
        if (ms != null) passed++;
        return ms;
      },
      onDone: (d) => state.value = state.value.copyWith(done: d, passed: passed),
      cancelled: () => _cancel,
    );
    if (_cancel) return _stopped();

    final ok = <(FinderEndpoint, int)>[
      for (var i = 0; i < candidates.length; i++)
        if (delays[i] != null) (candidates[i], delays[i]!),
    ];
    if (ok.isEmpty) {
      state.value = state.value.copyWith(phase: FinderPhase.done, passed: 0, error: 'none');
      return;
    }
    // a TLS handshake says more than an open port (a CDN edge always accepts TCP), so plain TCP
    // configs come after TLS ones of a similar delay; at most two per server
    int score((FinderEndpoint, int) p) => p.$2 + (p.$1.tls ? 0 : 300);
    ok.sort((a, b) => score(a).compareTo(score(b)));
    final perHost = <String, int>{};
    final best = <(FinderEndpoint, int)>[];
    for (final p in ok) {
      final h = '${p.$1.host}:${p.$1.port}';
      if ((perHost[h] ?? 0) >= 2) continue;
      perHost[h] = (perHost[h] ?? 0) + 1;
      best.add(p);
      if (best.length >= keep) break;
    }
    final links = [
      for (var i = 0; i < best.length; i++)
        renameFinderLink(best[i].$1.link, '${i + 1} · ${best[i].$1.scheme} · ${best[i].$2}ms'),
    ];
    final bestMs = best.map((p) => p.$2).reduce((a, b) => a < b ? a : b);

    state.value = state.value.copyWith(phase: FinderPhase.saving, passed: passed);
    final saved = await _saveProfile(links);
    if (saved == null) {
      state.value = state.value.copyWith(phase: FinderPhase.done, error: 'save');
      return;
    }
    await _prefs.setString(
      FinderPrefs.last,
      jsonEncode({
        'at': DateTime.now().toIso8601String(),
        'saved': saved,
        'best': bestMs,
        'passed': passed,
        'tested': candidates.length,
      }),
    );
    state.value = state.value.copyWith(phase: FinderPhase.done, saved: saved, bestMs: bestMs);
  }

  void _stopped() => state.value = const FinderState();

  /// Writes [links] into the «کانفیگ‌یاب» profile (a new one the first time, not made active unless
  /// there is no profile at all). When the core refuses the whole list, the links it refuses one
  /// by one are dropped. Returns how many were saved, or null.
  Future<int?> _saveProfile(List<String> links) async {
    final repo = await _ref.read(profileRepositoryProvider.future);
    final id = profileId;
    final ProfileEntity? existing = id == null ? null : (await repo.getById(id).run()).getOrElse((_) => null);

    Future<bool> write(List<String> l) async {
      final content = l.join('\n');
      if (existing != null) {
        final r = await repo.offlineUpdate(existing, content).run();
        if (r.isLeft()) loggy.warning('config finder: profile update failed: ${r.getLeft().toNullable()}');
        return r.isRight();
      }
      final active = await _ref.read(activeProfileProvider.future);
      final r = await repo
          .addLocal(
            content,
            userOverride: const UserOverride(name: finderProfileName, isAutoUpdateDisable: true),
            activate: active == null,
          )
          .run();
      return r.fold((l) {
        loggy.warning('config finder: profile add failed: $l');
        return false;
      }, (newId) {
        _prefs.setString(FinderPrefs.profileId, newId);
        return true;
      });
    }

    if (await write(links)) return links.length;
    final good = <String>[];
    final dir = await Directory.systemTemp.createTemp('raman_finder');
    try {
      for (var i = 0; i < links.length; i++) {
        final input = File('${dir.path}/$i.txt');
        await input.writeAsString(links[i]);
        final v = await repo.validateConfig('${dir.path}/$i.json', input.path, null, false).run();
        if (v.isRight()) good.add(links[i]);
      }
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
    if (good.isEmpty) return null;
    return await write(good) ? good.length : null;
  }

  /// Makes the «کانفیگ‌یاب» profile the active one (a running connection reconnects with it, as
  /// when any profile is chosen in the list). False when it is gone.
  Future<bool> selectProfile() async {
    final id = profileId;
    if (id == null) return false;
    final repo = await _ref.read(profileRepositoryProvider.future);
    final p = (await repo.getById(id).run()).getOrElse((_) => null);
    if (p == null) return false;
    return (await repo.setAsActive(id).run()).isRight();
  }

  Future<bool> profileExists() async {
    final id = profileId;
    if (id == null) return false;
    final repo = await _ref.read(profileRepositoryProvider.future);
    return (await repo.getById(id).run()).getOrElse((_) => null) != null;
  }
}
