import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/gen/translations.g.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Raman VPN 1.9 UI texts (home, server list, settings groups, add sheet): Persian, Kurdish
/// (Sorani), English.
class RamanUiStrings {
  const RamanUiStrings(this.locale);

  final AppLocale locale;

  bool get rtl => locale == AppLocale.fa || locale == AppLocale.ckb;

  String _t(String fa, String en, String ckb) => switch (locale) {
    AppLocale.fa => fa,
    AppLocale.ckb => ckb,
    _ => en,
  };

  // home: short state labels under the connect button
  String get stateDisconnected => _t('قطع', 'Disconnected', 'پچڕاوە');
  String get stateConnecting => _t('در حال اتصال…', 'Connecting…', 'پەیوەندی دەکرێت…');
  String get stateConnected => _t('متصل', 'Connected', 'پەیوەستە');
  String get stateDisconnecting => _t('در حال قطع…', 'Disconnecting…', 'دەپچڕێت…');
  String get stateFailed => _t('اتصال ناموفق', 'Connection failed', 'پەیوەندی سەرنەکەوت');
  String get tapToConnect => _t('برای اتصال بزنید', 'Tap to connect', 'بۆ پەیوەندی دەست لێ بدە');
  String get tapToDisconnect => _t('برای قطع بزنید', 'Tap to disconnect', 'بۆ پچڕاندن دەست لێ بدە');
  String get errorDetails => _t('جزئیات خطا', 'Error details', 'وردەکاریی هەڵە');
  String get download => _t('دانلود', 'Download', 'داگرتن');
  String get upload => _t('آپلود', 'Upload', 'بارکردن');
  String get ping => _t('پینگ', 'Ping', 'پینگ');
  String get selectedConfig => _t('کانفیگ انتخاب‌شده', 'Selected config', 'کانفیگی هەڵبژێردراو');
  String get server => _t('سرور', 'Server', 'ڕاژەکار');

  // server list
  String get searchServers => _t('جستجوی سرور…', 'Search servers…', 'گەڕان بەدوای ڕاژەکار…');
  String get favorites => _t('علاقه‌مندی‌ها', 'Favorites', 'دڵخوازەکان');
  String get recent => _t('اخیر', 'Recent', 'دواین');
  String get allServers => _t('همه سرورها', 'All servers', 'هەموو ڕاژەکارەکان');
  String get addFavorite => _t('افزودن به علاقه‌مندی‌ها', 'Add to favorites', 'زیادکردن بۆ دڵخوازەکان');
  String get removeFavorite => _t('حذف از علاقه‌مندی‌ها', 'Remove from favorites', 'لابردن لە دڵخوازەکان');
  String get noMatch => _t('سروری با این نام پیدا نشد', 'No server matches', 'هیچ ڕاژەکارێک نەدۆزرایەوە');

  // settings groups
  String get groupRaman => _t('رامان', 'Raman', 'ڕامان');
  String get groupConnection => _t('اتصال', 'Connection', 'پەیوەندی');
  String get groupApp => _t('برنامه', 'App', 'بەرنامە');

  // add sheet sections
  String get addImport => _t('افزودن کانفیگ', 'Add a config', 'زیادکردنی کانفیگ');
  String get addRamanTools => _t('ابزارهای رامان', 'Raman tools', 'ئامرازەکانی ڕامان');
}

final ramanUiStringsProvider = Provider<RamanUiStrings>((ref) => RamanUiStrings(ref.watch(localePreferencesProvider)));
