import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_links.dart';
import 'package:hiddify/features/raman/finder/clean_ip_core.dart';
import 'package:hiddify/features/raman/finder/finder_core.dart';
import 'package:hiddify/features/raman/finder/finder_strings.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Raman VPN 1.9 clean-IP scanner (manual, from the «کانفیگ‌یاب» page): for a CDN config (TLS
/// with a domain SNI) it finds which CDN serves the domain, tries random edge IPs of that CDN from
/// the provider's own published list with the config's SNI, and writes a COPY of the config that
/// connects to the best IP into a local profile «IP تمیز». The original config is never changed.
/// Cloudflare is recognised but never scanned (its IPs are throttled from Iran since 2026-10-02).
abstract class CleanIpPrefs {
  static const profileId = 'raman-cleanip-profile-id';

  /// The copies written so far (JSON list of links, newest first, at most [maxLinks]).
  static const links = 'raman-cleanip-links';
  static const maxLinks = 50;
}

const cleanIpProfileName = 'IP تمیز';
const cleanIpCounts = [100, 200, 400];

class CleanIpResult {
  const CleanIpResult(this.ip, this.ms);

  final String ip;
  final int ms;
}

final cleanIpControllerProvider = Provider<CleanIpController>((ref) => CleanIpController(ref));

class CleanIpController with InfraLogger {
  CleanIpController(this._ref);

  final Ref _ref;
  final Map<CdnProvider, List<Cidr4>> _ranges = {};
  final Set<CdnProvider> _live = {};

  SharedPreferences get _prefs => _ref.read(sharedPreferencesProvider).requireValue;

  /// Whether [p]'s ranges came from its live list (false = the built-in copy, or none).
  bool isLive(CdnProvider p) => _live.contains(p);

  Future<bool> _portOpen(int port) async {
    try {
      final s = await Socket.connect('127.0.0.1', port, timeout: const Duration(milliseconds: 300));
      s.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Same order as the finder: the core's local port, a running DNS tunnel engine, direct.
  Future<List<FinderRoute>> _routes() async {
    final port = _ref.read(ConfigOptions.mixedPort);
    final dnsPorts = {for (final e in DnsEngine.values) e.port};
    int? dns;
    for (final p in dnsPorts) {
      if (await _portOpen(p)) {
        dns = p;
        break;
      }
    }
    return [
      if (await _portOpen(port)) FinderRoute.core(port),
      if (dns != null) FinderRoute.socks(dns),
      const FinderRoute.direct(),
    ];
  }

  /// Reads every provider's published list once per app run; the built-in copy when it can not
  /// be read.
  Future<void> loadRanges() async {
    final missing = CdnProvider.values.where((p) => !_live.contains(p)).toList();
    if (missing.isEmpty) return;
    final routes = await _routes();
    await Future.wait(
      missing.map((p) async {
        for (final r in routes) {
          try {
            final body = await fetchFinderBytes(p.listUrl, route: r, timeout: const Duration(seconds: 40));
            final list = parseCdnList(p, body);
            if (list.isNotEmpty) {
              _ranges[p] = list;
              _live.add(p);
              return;
            }
          } catch (e) {
            loggy.debug('clean ip: ${p.label} list via ${r.name}: $e');
          }
        }
        _ranges[p] ??= (cdnRangesSnapshot[p] ?? const <String>[]).map(Cidr4.tryParse).whereType<Cidr4>().toList();
      }),
    );
  }

  List<Cidr4> rangesOf(CdnProvider p) => _ranges[p] ?? const [];

  /// The CDN that serves [c]'s domain (its SNI, then the config's own address), with the last
  /// byte of the IPs it resolves to; (null, …) when none of the known ranges has them.
  Future<(CdnProvider?, Set<int>)> detect(CdnConfig c) async {
    final ips = <int>{};
    for (final host in {c.sni, c.endpoint.host}) {
      final direct = ipv4ToInt(host);
      if (direct != null) {
        ips.add(direct);
        continue;
      }
      try {
        final found = await InternetAddress.lookup(
          host,
          type: InternetAddressType.IPv4,
        ).timeout(const Duration(seconds: 8));
        ips.addAll(found.map((a) => ipv4ToInt(a.address)).whereType<int>());
      } catch (_) {}
    }
    for (final ip in ips) {
      final p = cdnOf(ip, _ranges);
      if (p != null) {
        return (p, {for (final i in ips.where((i) => cdnOf(i, _ranges) == p)) i & 255});
      }
    }
    return (null, <int>{});
  }

  bool _cancel = false;
  void cancel() => _cancel = true;

  /// Tries [count] edge IPs of [p] with [c]'s SNI on its port; the ones that answered, fastest
  /// first.
  Future<List<CleanIpResult>> scan(
    CdnConfig c,
    CdnProvider p,
    int count, {
    Set<int> lastOctets = const {},
    void Function(int done, int total, int ok)? onProgress,
  }) async {
    _cancel = false;
    final ips = sampleCdnIps(rangesOf(p), count, lastOctets: lastOctets);
    var ok = 0;
    final res = await runPool<String, int?>(
      ips,
      (ip) async {
        final ms = await probeCleanIp(ip, c.endpoint.port, c.sni);
        if (ms != null) ok++;
        return ms;
      },
      concurrency: 16,
      onDone: (d) => onProgress?.call(d, ips.length, ok),
      cancelled: () => _cancel,
    );
    final out = <CleanIpResult>[
      for (var i = 0; i < ips.length; i++)
        if (res[i] != null) CleanIpResult(ips[i], res[i]!),
    ]..sort((a, b) => a.ms.compareTo(b.ms));
    return out;
  }

  /// Writes a copy of [link] that connects to [r]'s IP into the «IP تمیز» profile (made the first
  /// time, not made active, as the finder does). Returns the copy, or null.
  Future<String?> apply(String link, CdnConfig c, CdnProvider p, CleanIpResult r) async {
    final copy = withCleanIp(link, r.ip, c.sni, '${p.label} · ${r.ip} · ${r.ms}ms');
    if (copy == null) return null;
    List<String> saved;
    try {
      saved = (jsonDecode(_prefs.getString(CleanIpPrefs.links) ?? '[]') as List).whereType<String>().toList();
    } catch (_) {
      saved = [];
    }
    final all = [copy, ...saved.where((l) => l != copy)].take(CleanIpPrefs.maxLinks).toList();
    final repo = await _ref.read(profileRepositoryProvider.future);
    final id = _prefs.getString(CleanIpPrefs.profileId);
    final ProfileEntity? existing = id == null ? null : (await repo.getById(id).run()).getOrElse((_) => null);
    final content = all.join('\n');
    bool ok;
    if (existing != null) {
      ok = (await repo.offlineUpdate(existing, content).run()).isRight();
    } else {
      final active = await _ref.read(activeProfileProvider.future);
      final added = await repo
          .addLocal(
            content,
            userOverride: const UserOverride(name: cleanIpProfileName, isAutoUpdateDisable: true),
            activate: active == null,
          )
          .run();
      ok = added.isRight();
      if (ok) await _prefs.setString(CleanIpPrefs.profileId, added.getOrElse((_) => ''));
    }
    if (!ok) {
      loggy.warning('clean ip: profile not saved');
      return null;
    }
    await _prefs.setString(CleanIpPrefs.links, jsonEncode(all));
    return copy;
  }
}

Future<void> showCleanIpPage(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CleanIpPage()));

class CleanIpPage extends ConsumerStatefulWidget {
  const CleanIpPage({super.key});

  @override
  ConsumerState<CleanIpPage> createState() => _CleanIpPageState();
}

class _CleanIpPageState extends ConsumerState<CleanIpPage> {
  final _link = TextEditingController();
  CdnConfig? _config;
  String? _configError;
  CdnProvider? _detected;
  CdnProvider? _chosen;
  Set<int> _octets = const {};
  int _count = 200;
  bool _busy = false;
  bool _scanning = false;
  String? _status;
  List<CleanIpResult> _results = const [];

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  CdnProvider? get _provider => _chosen ?? _detected;

  Future<void> _check() async {
    final s = ref.read(finderStringsProvider);
    final c = ref.read(cleanIpControllerProvider);
    final (config, err) = cdnConfigOf(_link.text);
    setState(() {
      _config = config;
      _configError = err == null ? null : s.cleanBadConfig(err);
      _detected = null;
      _chosen = null;
      _results = const [];
      _status = null;
    });
    if (config == null) return;
    setState(() => _busy = true);
    try {
      await c.loadRanges();
      final (p, octets) = await c.detect(config);
      if (!mounted) return;
      setState(() {
        _detected = p;
        _octets = octets;
        _status = p == null ? s.cleanUnknownCdn : (p.scannable ? s.cleanDetected(p.label) : s.cleanIsCloudflare);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final s = ref.read(finderStringsProvider);
    final c = ref.read(cleanIpControllerProvider);
    final config = _config;
    final p = _provider;
    if (config == null || p == null || !p.scannable) return;
    setState(() {
      _scanning = true;
      _results = const [];
    });
    try {
      final r = await c.scan(
        config,
        p,
        _count,
        lastOctets: p == _detected ? _octets : const {},
        onProgress: (d, t, ok) {
          if (mounted) setState(() => _status = '${s.progress(d, t)} · ${s.tested(ok, d)}');
        },
      );
      if (!mounted) return;
      setState(() {
        _results = r;
        _status = r.isEmpty ? s.cleanNone : s.cleanFound(r.length);
      });
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _apply(CleanIpResult r) async {
    final s = ref.read(finderStringsProvider);
    final notification = ref.read(inAppNotificationControllerProvider);
    final config = _config;
    final p = _provider;
    if (config == null || p == null) return;
    final copy = await ref.read(cleanIpControllerProvider).apply(_link.text.trim(), config, p, r);
    if (copy == null) {
      notification.showErrorToast(s.saveFailed);
    } else {
      notification.showSuccessToast(s.cleanApplied(r.ip));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(finderStringsProvider);
    final c = ref.read(cleanIpControllerProvider);
    final theme = Theme.of(context);
    final p = _provider;
    return Scaffold(
      appBar: AppBar(title: Text(s.cleanTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(s.cleanIntro, style: theme.textTheme.bodyMedium),
          const Gap(12),
          TextField(
            controller: _link,
            textDirection: TextDirection.ltr,
            minLines: 1,
            maxLines: 4,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: s.cleanLink,
              errorText: _configError,
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste_rounded),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  final text = data?.text?.trim() ?? '';
                  if (text.isNotEmpty) {
                    _link.text = text.split(RegExp(r'\s+')).first;
                    await _check();
                  }
                },
              ),
            ),
            onSubmitted: (_) => _check(),
          ),
          const Gap(8),
          OutlinedButton.icon(
            onPressed: _busy || _scanning ? null : _check,
            icon: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.manage_search_rounded),
            label: Text(s.cleanCheck),
          ),
          if (_config != null) ...[
            const Gap(12),
            Text(
              'SNI: ${_config!.sni} · ${_config!.endpoint.host}:${_config!.endpoint.port}',
              textDirection: TextDirection.ltr,
              style: theme.textTheme.bodySmall,
            ),
            const Gap(8),
            Row(
              children: [
                Expanded(child: Text(s.cleanProvider, style: theme.textTheme.bodyMedium)),
                DropdownButton<CdnProvider>(
                  value: p != null && p.scannable ? p : null,
                  hint: Text(s.cleanPick),
                  items: [
                    for (final v in CdnProvider.values.where((v) => v.scannable))
                      DropdownMenuItem(
                        value: v,
                        child: Text('${v.label}${c.isLive(v) || c.rangesOf(v).isEmpty ? '' : ' *'}'),
                      ),
                  ],
                  onChanged: _scanning ? null : (v) => setState(() => _chosen = v),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(child: Text(s.cleanCount, style: theme.textTheme.bodyMedium)),
                DropdownButton<int>(
                  value: _count,
                  items: [for (final n in cleanIpCounts) DropdownMenuItem(value: n, child: Text('$n'))],
                  onChanged: _scanning ? null : (v) => setState(() => _count = v ?? 200),
                ),
              ],
            ),
            if (p != null && p.scannable && !c.isLive(p) && c.rangesOf(p).isNotEmpty)
              Text(s.cleanSnapshot, style: theme.textTheme.bodySmall),
            if (p != null && p.scannable && c.rangesOf(p).isEmpty)
              Text(s.cleanNoList, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            const Gap(8),
            if (_scanning)
              OutlinedButton.icon(onPressed: c.cancel, icon: const Icon(Icons.stop_rounded), label: Text(s.stop))
            else
              FilledButton.icon(
                onPressed: p == null || !p.scannable || c.rangesOf(p).isEmpty || _busy ? null : _scan,
                icon: const Icon(Icons.radar_rounded),
                label: Text(s.cleanScan),
              ),
          ],
          if (_status != null) ...[const Gap(8), Text(_status!, style: theme.textTheme.bodyMedium)],
          if (_results.isNotEmpty) ...[
            const Gap(8),
            FilledButton.tonalIcon(
              onPressed: _scanning ? null : () => _apply(_results.first),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: Text(s.cleanApplyBest),
            ),
            const Gap(4),
            Text(s.cleanApplyHint, style: theme.textTheme.bodySmall),
            for (final r in _results.take(10))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(r.ip, textDirection: TextDirection.ltr),
                subtitle: Text('${r.ms} ms'),
                trailing: IconButton(
                  tooltip: s.cleanApply,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: _scanning ? null : () => _apply(r),
                ),
              ),
          ],
          const Gap(16),
          Text(s.cleanMethod, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
