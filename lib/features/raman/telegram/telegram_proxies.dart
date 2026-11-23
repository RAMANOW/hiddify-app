import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/core/router/go_router/go_router_notifier.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/raman/dnstunnel/dns_tunnel_controller.dart';
import 'package:hiddify/features/raman/relay/relay_controller.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/gen/translations.g.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Raman VPN 1.8.1: Telegram's own proxy links (MTProto tg://proxy, SOCKS5 tg://socks, and their
/// https://t.me/… forms) as posted on Telegram channels. The core can not run MTProto, so they are
/// kept in a small list and handed to the Telegram app, which runs them itself.

class TelegramStrings {
  const TelegramStrings(this.locale);

  final AppLocale locale;

  String _t(String fa, String en, String ckb) => switch (locale) {
    AppLocale.fa => fa,
    AppLocale.ckb => ckb,
    _ => en,
  };

  String get button => _t('پروکسی تلگرام', 'Telegram proxy', 'پرۆکسیی تێلیگرام');
  String get title => _t('پروکسی تلگرام', 'Telegram proxies', 'پرۆکسییەکانی تێلیگرام');
  String get useRaman => _t('تلگرام از راه رامان', 'Use Raman for Telegram', 'تێلیگرام لە ڕێی ڕامان');
  String get useRamanHint => _t(
    'پروکسی SOCKS محلیِ اتصالِ روشن (رله گوگل، DNS قطعی یا پورت محلی) رو به تلگرام می‌ده.',
    'Gives Telegram the local SOCKS port of what runs now (Google Relay, Shutdown DNS or the local port).',
    'پۆرتی SOCKSی ناوخۆیی ئەوەی ئێستا کار دەکات (ڕیلەی گووگڵ، DNSی بڕان یان پۆرتی ناوخۆیی) دەدات بە تێلیگرام.',
  );
  String get nothingRunning => _t(
    'الان چیزی وصل نیست. اول وصل شو یا رله گوگل / DNS قطعی رو روشن کن.',
    'Nothing is connected now. Connect first, or start Google Relay / Shutdown DNS.',
    'ئێستا هیچ پەیوەست نییە. سەرەتا پەیوەست بە، یان ڕیلەی گووگڵ / DNSی بڕان داگیرسێنە.',
  );
  String get vpnNoPort => _t(
    'VPN وصله و تلگرام همین الان از راهش می‌ره. برای پروکسی جدا، «پورت محلی در حالت VPN» رو در تنظیمات روشن کن.',
    'The VPN is on and Telegram already goes through it. For a separate proxy, turn on the local port in VPN mode in Settings.',
    'VPN پەیوەستە و تێلیگرام ئێستا لە ڕێیەوە دەڕوات. بۆ پرۆکسیی جیا، پۆرتی ناوخۆیی لە دۆخی VPN لە ڕێکخستنەکان داگیرسێنە.',
  );
  String get noTelegram => _t('تلگرام باز نشد (نصبه؟)', 'Telegram did not open (is it installed?)', 'تێلیگرام نەکرایەوە (دامەزراوە؟)');
  String get saved => _t('پروکسی‌های ذخیره‌شده', 'Saved proxies', 'پرۆکسییە پاشەکەوتکراوەکان');
  String get empty => _t(
    'هنوز پروکسی‌ای نداری. لینک tg://proxy یا t.me/proxy رو کپی کن و «چسباندن» رو بزن.',
    'No proxies yet. Copy a tg://proxy or t.me/proxy link and tap Paste.',
    'هێشتا پرۆکسیت نییە. لینکی tg://proxy یان t.me/proxy کۆپی بکە و «لکاندن» دابگرە.',
  );
  String get paste => _t('چسباندن', 'Paste', 'لکاندن');
  String get longPressHint => _t('برای حذف، نگه دار.', 'Long-press to delete.', 'بۆ سڕینەوە، پەنجە ڕابگرە.');
  String get deleteTitle => _t('این پروکسی حذف بشه؟', 'Delete this proxy?', 'ئەم پرۆکسییە بسڕدرێتەوە؟');
  String get delete => _t('حذف', 'Delete', 'سڕینەوە');
  String get cancel => _t('لغو', 'Cancel', 'هەڵوەشاندنەوە');
  String added(int n) => _t('$n پروکسی تلگرام اضافه شد', '$n Telegram proxies added', '$n پرۆکسیی تێلیگرام زیادکرا');
  String get alreadySaved => _t('این پروکسی‌های تلگرام از قبل ذخیره بودن', 'These Telegram proxies were already saved', 'ئەم پرۆکسییانەی تێلیگرام پێشتر پاشەکەوت کرابوون');
  String get nothingToAdd => _t('لینک پروکسی تلگرام پیدا نشد', 'No Telegram proxy link found', 'هیچ لینکی پرۆکسیی تێلیگرام نەدۆزرایەوە');
}

final telegramStringsProvider = Provider<TelegramStrings>((ref) => TelegramStrings(ref.watch(localePreferencesProvider)));

/// One Telegram proxy link: [kind] is proxy (MTProto) or socks.
class TelegramProxy {
  const TelegramProxy(this.kind, this.params);

  final String kind;
  final Map<String, String> params;

  String get server => params['server'] ?? '';
  int get port => int.tryParse(params['port'] ?? '') ?? 0;
  bool get isMtproto => kind == 'proxy';

  /// The tg:// form, which opens the Telegram app straight away.
  String get link => Uri(scheme: 'tg', host: kind, queryParameters: params).toString();

  String get key => '$kind|${server.toLowerCase()}|$port|${params['secret'] ?? ''}|${params['user'] ?? ''}';
}

/// tg://proxy?…, tg://socks?…, https://t.me/proxy?…, https://t.me/socks?… (also telegram.me).
final telegramLinkRe = RegExp(
  r'''(?:tg://(proxy|socks)|(?:https?://)?(?:www\.)?(?:t|telegram)\.me/(proxy|socks))\?([^\s"'<>]+)''',
  caseSensitive: false,
);

TelegramProxy? _fromMatch(RegExpMatch m) {
  final kind = (m.group(1) ?? m.group(2)!).toLowerCase();
  Map<String, String> q;
  try {
    q = Uri.splitQueryString(m.group(3)!.replaceAll('&amp;', '&'));
  } catch (_) {
    return null;
  }
  final params = <String, String>{};
  for (final k in ['server', 'port', 'secret', 'user', 'pass']) {
    final v = q[k]?.trim();
    if (v != null && v.isNotEmpty) params[k] = v;
  }
  final p = TelegramProxy(kind, params);
  if (!RegExp(r'^[A-Za-z0-9.\-:\[\]]{1,253}$').hasMatch(p.server)) return null;
  if (p.port < 1 || p.port > 65535) return null;
  if (p.isMtproto && !RegExp(r'^[A-Za-z0-9+/=_\-]{16,}$').hasMatch(params['secret'] ?? '')) return null;
  return p;
}

/// Every distinct Telegram proxy link in [text]; broken ones skipped.
List<TelegramProxy> extractTelegramProxies(String text) {
  final seen = <String>{};
  final out = <TelegramProxy>[];
  for (final m in telegramLinkRe.allMatches(text)) {
    final p = _fromMatch(m);
    if (p != null && seen.add(p.key)) out.add(p);
  }
  return out;
}

const _prefsKey = 'raman-tg-proxies';

/// Bumped on every change of the list, for the sheet to redraw.
final telegramProxiesVersionProvider = StateProvider<int>((ref) => 0);

final telegramProxyStoreProvider = Provider<TelegramProxyStore>((ref) => TelegramProxyStore(ref));

class TelegramProxyStore {
  TelegramProxyStore(this._ref);

  final Ref _ref;

  List<TelegramProxy> list() {
    final raw = _ref.read(sharedPreferencesProvider).requireValue.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final out = <TelegramProxy>[];
      for (final e in (jsonDecode(raw) as List).whereType<Map<String, dynamic>>()) {
        out.addAll(extractTelegramProxies(e['link'] as String? ?? ''));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(List<TelegramProxy> list) async {
    final now = DateTime.now().toIso8601String();
    await _ref
        .read(sharedPreferencesProvider)
        .requireValue
        .setString(_prefsKey, jsonEncode(list.map((p) => {'link': p.link, 'at': now}).toList()));
    _ref.read(telegramProxiesVersionProvider.notifier).state++;
  }

  /// Adds the links in [text]; returns how many were new.
  Future<int> addFromText(String text) async {
    final found = extractTelegramProxies(text);
    if (found.isEmpty) return 0;
    final list = this.list().toList();
    final keys = list.map((e) => e.key).toSet();
    var added = 0;
    for (final p in found) {
      if (keys.add(p.key)) {
        list.insert(0, p);
        added++;
      }
    }
    if (added > 0) await _save(list);
    return added;
  }

  Future<void> remove(TelegramProxy p) => _save(list().where((e) => e.key != p.key).toList());
}

Future<bool> _portOpen(int port) async {
  try {
    final s = await Socket.connect('127.0.0.1', port, timeout: const Duration(milliseconds: 300));
    s.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

/// The local SOCKS port of what runs now: the relay's, the DNS tunnel's, or the core's mixed port
/// (open in proxy mode, or in VPN mode with the local port on; not with a password).
Future<int?> ramanLocalSocksPort(WidgetRef ref) async {
  final candidates = <int>[
    if (ref.read(relayControllerProvider).inUse) RelayPlatform.socksPort,
    if (ref.read(dnsTunnelControllerProvider).inUse) DnsTunnelPlatform.socksPort,
    if ((ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false) &&
        !ref.read(ConfigOptions.localProxyAuth))
      ref.read(ConfigOptions.mixedPort),
  ];
  for (final p in candidates) {
    if (await _portOpen(p)) return p;
  }
  return null;
}

Future<bool> _openInTelegram(String link) async {
  try {
    return await launchUrl(Uri.parse(link), mode: LaunchMode.externalNonBrowserApplication);
  } catch (_) {
    return false;
  }
}

/// The «پروکسی تلگرام» sheet, over whatever is on screen.
Future<void> showTelegramProxySheet() async {
  final context = rootNavKey.currentContext;
  if (context == null) return;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const TelegramProxySheet(),
  );
}

class TelegramProxySheet extends HookConsumerWidget {
  const TelegramProxySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(telegramStringsProvider);
    ref.watch(telegramProxiesVersionProvider);
    final store = ref.read(telegramProxyStoreProvider);
    final proxies = store.list();
    final message = useState<String?>(null);
    final busy = useState(false);
    final theme = Theme.of(context);

    Future<void> useRaman() async {
      busy.value = true;
      try {
        final port = await ramanLocalSocksPort(ref);
        if (port == null) {
          final connected = ref.read(connectionNotifierProvider).valueOrNull?.isConnected ?? false;
          message.value = connected ? s.vpnNoPort : s.nothingRunning;
          return;
        }
        final ok = await _openInTelegram('tg://socks?server=127.0.0.1&port=$port');
        message.value = ok ? null : s.noTelegram;
      } finally {
        busy.value = false;
      }
    }

    Future<void> paste() async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      final found = extractTelegramProxies(text).length;
      if (found == 0) {
        message.value = s.nothingToAdd;
        return;
      }
      final n = await store.addFromText(text);
      message.value = n > 0 ? s.added(n) : s.alreadySaved;
    }

    Future<void> delete(TelegramProxy p) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s.deleteTitle),
          content: Text('${p.server}:${p.port}', textDirection: TextDirection.ltr),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(s.delete)),
          ],
        ),
      );
      if (ok ?? false) await store.remove(p);
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(s.title, style: theme.textTheme.titleLarge),
            const Gap(12),
            FilledButton.icon(
              onPressed: busy.value ? null : useRaman,
              icon: const Icon(Icons.send_rounded),
              label: Text(s.useRaman),
            ),
            const Gap(4),
            Text(s.useRamanHint, style: theme.textTheme.bodySmall),
            if (message.value != null) ...[
              const Gap(8),
              Text(message.value!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
            ],
            const Gap(16),
            Row(
              children: [
                Expanded(child: Text(s.saved, style: theme.textTheme.titleMedium)),
                TextButton.icon(onPressed: paste, icon: const Icon(Icons.content_paste_rounded), label: Text(s.paste)),
              ],
            ),
            if (proxies.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(s.empty))
            else ...[
              for (final p in proxies)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(p.isMtproto ? Icons.vpn_key_rounded : Icons.lan_rounded),
                  title: Text('${p.server}:${p.port}', textDirection: TextDirection.ltr),
                  subtitle: Text(p.isMtproto ? 'MTProto' : 'SOCKS5'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () async {
                    final ok = await _openInTelegram(p.link);
                    if (!ok) message.value = s.noTelegram;
                  },
                  onLongPress: () => delete(p),
                ),
              Text(s.longPressHint, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
