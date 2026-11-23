import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/gen/translations.g.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The "DNS قطعی" tab's texts: Persian, English and Kurdish (Sorani); a missing Kurdish text is
/// shown in Persian.
class DnsTunnelStrings {
  const DnsTunnelStrings(this.locale);

  final AppLocale locale;

  String _t(String fa, String en, [String? ckb]) => switch (locale) {
    AppLocale.fa => fa,
    AppLocale.ckb => ckb ?? fa,
    _ => en,
  };

  String get tab => _t('DNS قطعی', 'Shutdown DNS', 'DNSی بڕان');
  String get intro => _t(
    'برای وقتی که اینترنت قطع می‌شه و فقط DNS جواب می‌ده. ترافیک توی درخواست‌های DNS از راه DNS اپراتور یا DNSهای داخلی رد می‌شه. خیلی کُنده؛ فقط برای پیام متنی تلگرام و پیام‌رسانی سبک. تماس صوتی و تصویری کار نمی‌کنه (فقط TCP).',
    'For internet shutdowns, when only DNS still answers. Traffic rides inside DNS queries through your operator\'s or domestic resolvers. Very slow: Telegram text and light messaging only. Voice and video calls do not work (TCP only).',
    'بۆ کاتی بڕانی ئینتەرنێت، کاتێک تەنها DNS وەڵام دەداتەوە. ترافیک لەناو داواکارییەکانی DNS لە ڕێی DNSی ئۆپەرەیتەر یان DNSی ناوخۆیی دەڕوات. زۆر خاوە؛ تەنها بۆ نامەی دەقیی تێلیگرام و نامەناردنی سووک. پەیوەندیی دەنگی و ڤیدیۆیی کار ناکات (تەنها TCP).',
  );
  String get saveNow => _t(
    'تا اینترنت وصله، کانفیگ‌ها رو بگیر؛ موقع قطعی هم از حافظهٔ گوشی کار می‌کنن.',
    'Get the configs while the internet is up; they stay on the phone for the shutdown.',
    'تا ئینتەرنێت هەیە، کانفیگەکان وەربگرە؛ لە کاتی بڕاندا لەسەر مۆبایلەکە دەمێننەوە.',
  );

  // status
  String get stateOff => _t('خاموشه', 'Off', 'کوژاوەتەوە');
  String get stateStarting => _t('داره وصل می‌شه… (ممکنه تا ۲ دقیقه طول بکشه)', 'Connecting… (can take up to 2 minutes)', 'پەیوەست دەبێت… (لەوانەیە تا ٢ خولەک بخایەنێت)');
  String get stateConnected => _t('وصله از راه DNS', 'Connected through DNS', 'پەیوەستە لە ڕێی DNS');
  String get stateConnecting => _t('VPN داره وصل می‌شه…', 'The VPN is connecting…', 'VPN پەیوەست دەبێت…');
  String get stateNoVpn => _t('تونل روشنه ولی VPN وصل نیست', 'The tunnel runs but the VPN is not connected', 'تونێلەکە کار دەکات بەڵام VPN پەیوەست نییە');
  String get stateEngineDown => _t('موتور تونل متوقف شد', 'The tunnel engine stopped', 'بزوێنەری تونێلەکە وەستا');
  String get start => _t('اتصال', 'Connect', 'پەیوەستبوون');
  String get stop => _t('قطع', 'Disconnect', 'پچڕاندن');
  String get connectAgain => _t('وصل کردن VPN', 'Connect the VPN', 'پەیوەستکردنی VPN');
  String get busyTitle => _t('اتصال فعلی قطع بشه؟', 'Stop the current connection?', 'پەیوەندیی ئێستا ببڕدرێت؟');
  String get busyBody => _t(
    'فقط یه VPN در یه زمان کار می‌کنه. اتصال فعلی قطع بشه و از راه DNS وصل بشی؟',
    'Only one VPN runs at a time. Stop the current connection and connect through DNS?',
    'تەنها یەک VPN لە یەک کاتدا کار دەکات. پەیوەندیی ئێستا ببڕدرێت و لە ڕێی DNS پەیوەست بیت؟',
  );
  String get yes => _t('آره', 'Yes', 'بەڵێ');
  String get shieldFirst => _t('اول از تب شیلد برگرد به تب رامان.', 'Go back from the Shield tab to the Raman tab first.', 'سەرەتا لە تابی شیڵد بگەڕێوە بۆ تابی ڕامان.');
  String get relayFirst => _t('اول رله گوگل رو خاموش کن.', 'Stop Google Relay first.', 'سەرەتا ڕیلەی گووگڵ بکوژێنەوە.');
  String get pickConfig => _t('اول یه کانفیگ بگیر یا اضافه کن.', 'Get or add a config first.', 'سەرەتا کانفیگێک وەربگرە یان زیاد بکە.');
  String get noResolvers => _t('هیچ DNSی انتخاب نشده.', 'No resolvers selected.', 'هیچ DNSێک هەڵنەبژێردراوە.');
  String get startFailed => _t('وصل نشد', 'Could not connect', 'پەیوەست نەبوو');
  String get profileFailed => _t('پروفایل ساخته نشد', 'The profile could not be made', 'پرۆفایلەکە دروست نەکرا');
  String get engineMissing => _t('موتور این کانفیگ توی این نسخه نیست.', 'This config\'s engine is not in this build.', 'بزوێنەری ئەم کانفیگە لەم وەشانەدا نییە.');
  String get whileOn => _t(
    'تا وقتی روشنه، FakeIP روشن و QUIC بسته‌ست. با قطع کردن، تنظیمات قبلیت برمی‌گرده.',
    'While it is on, FakeIP is on and QUIC is blocked. Disconnecting brings your settings back.',
    'تا کاتێک داگیرساوە، FakeIP داگیرساوە و QUIC داخراوە. بە پچڕاندن ڕێکخستنەکانی پێشووت دەگەڕێنەوە.',
  );

  // configs
  String get configs => _t('کانفیگ‌ها', 'Configs', 'کانفیگەکان');
  String get getConfigs => _t('گرفتن کانفیگ‌ها', 'Get configs', 'وەرگرتنی کانفیگەکان');
  String get fetching => _t('داره می‌گیره…', 'Getting…', 'وەردەگیرێت…');
  String fetched(int n) => _t('$n کانفیگ گرفته شد', '$n configs found', '$n کانفیگ وەرگیرا');
  String get fetchNone => _t('کانفیگی پیدا نشد', 'No configs found', 'هیچ کانفیگێک نەدۆزرایەوە');
  String get fetchFailed => _t(
    'کانال باز نشد. اول با یه کانفیگ معمولی وصل شو و دوباره بزن، یا کانفیگ رو دستی اضافه کن.',
    'Could not open the channel. Connect with a normal config first and try again, or add a config by hand.',
    'کەناڵەکە نەکرایەوە. سەرەتا بە کانفیگێکی ئاسایی پەیوەست بە و دووبارە هەوڵ بدەوە، یان کانفیگ بە دەست زیاد بکە.',
  );
  String fetchedAt(String when) => _t('آخرین دریافت: $when', 'Last fetched: $when', 'دوایین وەرگرتن: $when');
  String get neverFetched => _t('هنوز کانفیگی نگرفتی', 'Not fetched yet', 'هێشتا وەرنەگیراوە');
  String get paste => _t('چسباندن', 'Paste', 'لکاندن');
  String get addManual => _t('افزودن دستی', 'Add by hand', 'زیادکردن بە دەست');
  String get addHint => _t('لینک soar:// یا cottendns:// رو اینجا بذار', 'Put a soar:// or cottendns:// link here', 'لینکی soar:// یان cottendns:// لێرە دابنێ');
  String get add => _t('افزودن', 'Add', 'زیادکردن');
  String get cancel => _t('لغو', 'Cancel', 'هەڵوەشاندنەوە');
  String added(int n) => _t('$n کانفیگ اضافه شد', '$n configs added', '$n کانفیگ زیادکرا');
  String get nothingToAdd => _t('لینک درستی پیدا نشد', 'No valid link found', 'هیچ لینکێکی دروست نەدۆزرایەوە');
  String get empty => _t('هنوز کانفیگی نداری.', 'No configs yet.', 'هێشتا کانفیگت نییە.');
  String get test => _t('تست', 'Test', 'تاقیکردنەوە');
  String get testing => _t('داره تست می‌کنه…', 'Testing…', 'تاقیدەکرێتەوە…');
  String testOk(int ms) => _t('کار کرد (${(ms / 1000).toStringAsFixed(1)} ثانیه)', 'Works (${(ms / 1000).toStringAsFixed(1)} s)', 'کار دەکات (${(ms / 1000).toStringAsFixed(1)} چرکە)');
  String testFail(String e) => _t('کار نکرد: $e', 'Failed: $e', 'کار ناکات: $e');
  String get delete => _t('حذف', 'Delete', 'سڕینەوە');
  String get manualBadge => _t('دستی', 'manual', 'دەستی');
  String get selectedBadge => _t('انتخاب‌شده', 'selected', 'هەڵبژێردراو');

  // resolvers
  String get resolvers => _t('DNSها (ریزالورها)', 'Resolvers', 'DNSەکان');
  String get useSystem => _t('اول DNS خود گوشی (اپراتور)', 'Phone\'s DNS first (operator)', 'سەرەتا DNSی مۆبایل (ئۆپەرەیتەر)');
  String systemNow(String list) => _t('الان: $list', 'Now: $list', 'ئێستا: $list');
  String get systemNone => _t('الان پیدا نشد', 'none found now', 'ئێستا نەدۆزرایەوە');
  String get useLink => _t('DNSهای خود کانفیگ هم', 'Also the config\'s resolvers', 'DNSەکانی کانفیگەکەش');
  String get useLinkHint => _t(
    'معمولاً 1.1.1.1 و 8.8.8.8 هستن که موقع قطعی جواب نمی‌دن.',
    'Usually 1.1.1.1 and 8.8.8.8, which often do not answer during a shutdown.',
    'زۆرجار 1.1.1.1 و 8.8.8.8ن کە لە کاتی بڕاندا وەڵام نادەنەوە.',
  );
  String get extra => _t('DNSهای دیگه (هر خط یکی)', 'More resolvers (one per line)', 'DNSی تر (هەر هێڵێک یەک)');
  String get extraHint => _t(
    'مثلاً DNSهای داخلی که موقع قطعی جواب می‌دن. IP یا IP:پورت.',
    'For example domestic resolvers that answer during a shutdown. IP or IP:port.',
    'بۆ نموونە DNSی ناوخۆیی کە لە کاتی بڕاندا وەڵام دەدەنەوە. IP یان IP:پۆرت.',
  );

  String get log => _t('گزارش موتور', 'Engine log', 'تۆماری بزوێنەر');
  String get noLog => _t('چیزی نیست', 'Nothing yet', 'هیچ نییە');

  String get credits => _t(
    'موتورها: Soar از تیم Lantern (Apache-2.0) و CottenDNS از TaJirax (MIT، برگرفته از StormDNS از NullRoute1970 و MasterDnsVPN از امین محمودی). کانفیگ‌های عمومی از کانال تلگرام @whitedns.',
    'Engines: Soar by the Lantern team (Apache-2.0) and CottenDNS by TaJirax (MIT, derived from StormDNS by NullRoute1970 and MasterDnsVPN by Amin Mahmoudi). Public configs from the @whitedns Telegram channel.',
    'بزوێنەرەکان: Soar لە تیمی Lantern (Apache-2.0) و CottenDNS لە TaJirax (MIT، لە StormDNS ی NullRoute1970 و MasterDnsVPN ی ئەمین مەحموودی). کانفیگە گشتییەکان لە کەناڵی تێلیگرامی @whitedns.',
  );
}

final dnsTunnelStringsProvider = Provider<DnsTunnelStrings>((ref) {
  return DnsTunnelStrings(ref.watch(localePreferencesProvider));
});
