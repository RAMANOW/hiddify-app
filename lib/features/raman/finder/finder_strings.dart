import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/gen/translations.g.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// «کانفیگ‌یاب» texts: Persian, Kurdish (Sorani), English.
class FinderStrings {
  const FinderStrings(this.locale);

  final AppLocale locale;

  String _t(String fa, String en, String ckb) => switch (locale) {
    AppLocale.fa => fa,
    AppLocale.ckb => ckb,
    _ => en,
  };

  String get button => _t('کانفیگ‌یاب', 'Config finder', 'کانفیگدۆزەرەوە');
  String get title => _t('کانفیگ‌یاب', 'Config finder', 'کانفیگدۆزەرەوە');
  String get intro => _t(
    'کانفیگ‌های رایگانِ منتشرشده در گیت‌هاب و کانال‌های تلگرام رو می‌گیره، از همین گوشی و همین اینترنت امتحانشون می‌کنه و بهترین‌ها رو توی یک پروفایل به اسم «کانفیگ‌یاب» می‌ذاره. اتصالِ روشنت دست نمی‌خوره.',
    'Gets the free configs posted on GitHub and Telegram channels, tests them from this phone on this network, and puts the best ones in one profile called «کانفیگ‌یاب». Your running connection is not touched.',
    'ئەو کانفیگە بێبەرامبەرانەی لە گیتهەب و کەناڵەکانی تێلیگرام بڵاوکراونەتەوە وەردەگرێت، لەم مۆبایلە و لەم ئینتەرنێتە تاقییان دەکاتەوە و باشترینەکان دەخاتە پرۆفایلێک بە ناوی «کانفیگ‌یاب». پەیوەندیی ئێستات دەستی لێ نادرێت.',
  );
  String get warning => _t(
    'کانفیگ‌های رایگانِ عمومی ممکنه کند باشن یا ترافیکت رو ثبت کنن؛ برای حساب‌های حساس (بانک، ایمیل کاری) ازشون استفاده نکن.',
    'Public free configs may be slow or logged; do not use them for sensitive accounts.',
    'کانفیگە گشتییە بێبەرامبەرەکان لەوانەیە خاو بن یان هاتوچۆکەت تۆمار بکەن؛ بۆ هەژمارە هەستیارەکان بەکاریان مەهێنە.',
  );
  String get start => _t('پیدا کن', 'Find configs', 'بیدۆزەرەوە');
  String get stop => _t('توقف', 'Stop', 'وەستان');
  String get sources => _t('منبع‌ها', 'Sources', 'سەرچاوەکان');
  String get builtin => _t('منبع‌های آماده', 'Built-in sources', 'سەرچاوە ئامادەکان');
  String get mine => _t('منبع‌های خودم', 'My sources', 'سەرچاوەکانی خۆم');
  String get addSource => _t('افزودن منبع', 'Add source', 'زیادکردنی سەرچاوە');
  String get addSourceHint => _t(
    'لینک خامِ سابسکریپشن (https://…) یا کانال تلگرام (t.me/… یا @…)',
    'A raw subscription link (https://…) or a Telegram channel (t.me/… or @…)',
    'لینکی خاوی سابسکریپشن (https://…) یان کەناڵی تێلیگرام (t.me/… یان @…)',
  );
  String get badSource => _t('این لینک منبع نیست.', 'This is not a source link.', 'ئەمە لینکی سەرچاوە نییە.');
  String get add => _t('افزودن', 'Add', 'زیادکردن');
  String get cancel => _t('انصراف', 'Cancel', 'پاشگەزبوونەوە');
  String get delete => _t('حذف', 'Delete', 'سڕینەوە');
  String get keep => _t('تعداد نگه‌داری', 'Keep', 'ژمارەی هەڵگرتن');
  String get autoRefresh => _t('به‌روزرسانی خودکار', 'Auto-refresh', 'نوێکردنەوەی خۆکار');
  String get autoOff => _t('خاموش', 'Off', 'کوژاوە');
  String hours(int h) => _t('هر $h ساعت', 'Every $h h', 'هەر $h کاتژمێر');
  String get autoHint => _t(
    'فقط وقتی برنامه بازه انجام می‌شه.',
    'Runs only while the app is open.',
    'تەنها کاتێک بەرنامەکە کراوەیە ئەنجام دەدرێت.',
  );
  String get fetching => _t('گرفتن فهرست‌ها', 'Reading the lists', 'وەرگرتنی لیستەکان');
  String get testing => _t('امتحانِ کانفیگ‌ها', 'Testing configs', 'تاقیکردنەوەی کانفیگەکان');
  String get saving => _t('ذخیرهٔ پروفایل', 'Saving the profile', 'پاشەکەوتکردنی پرۆفایل');
  String progress(int done, int total) => _t('$done از $total', '$done of $total', '$done لە $total');
  String found(int n) => _t('$n کانفیگ', '$n configs', '$n کانفیگ');
  String get failed => _t('جواب نداد', 'no answer', 'وەڵامی نەدایەوە');
  String get disabled => _t('خاموش', 'off', 'کوژاوە');
  String result(int saved, int ms) => _t(
    '$saved کانفیگِ سالم در پروفایل «کانفیگ‌یاب» · بهترین $ms میلی‌ثانیه',
    '$saved working configs in the «کانفیگ‌یاب» profile · best $ms ms',
    '$saved کانفیگی کارا لە پرۆفایلی «کانفیگ‌یاب» · باشترین $ms ms',
  );
  String tested(int passed, int total) => _t(
    '$passed از $total جواب دادن',
    '$passed of $total answered',
    '$passed لە $total وەڵامیان دایەوە',
  );
  String dnsAdded(int n) => _t(
    '$n کانفیگ DNS به تب «DNS قطعی» رفت',
    '$n DNS configs went to the Shutdown DNS tab',
    '$n کانفیگی DNS چوو بۆ «DNSی بڕان»',
  );
  String lastRun(String when) => _t('آخرین جستجو: $when', 'Last search: $when', 'دوایین گەڕان: $when');
  String get select => _t('استفاده از این پروفایل', 'Use this profile', 'ئەم پرۆفایلە بەکاربهێنە');
  String get selected => _t('پروفایل «کانفیگ‌یاب» فعال شد', 'The «کانفیگ‌یاب» profile is now in use', 'پرۆفایلی «کانفیگ‌یاب» چالاک کرا');
  String get inUse => _t('الان همین پروفایل فعاله', 'This profile is in use now', 'ئێستا ئەم پرۆفایلە چالاکە');
  String get reconnectHint => _t(
    'فهرست تازه بعد از قطع و وصلِ دوباره به کار می‌آد.',
    'The new list is used after you reconnect.',
    'لیستە نوێیەکە دوای پچڕان و پەیوەستبوونەوە بەکاردێت.',
  );
  String get selectHint => _t(
    'اگه وصلی، با انتخابِ این پروفایل اتصال یک بار قطع و وصل می‌شه.',
    'If you are connected, choosing it reconnects once.',
    'ئەگەر پەیوەستیت، هەڵبژاردنی ئەم پرۆفایلە جارێک پەیوەندی دەپچڕێنێت و دەیبەستێتەوە.',
  );
  String get noneWorked => _t(
    'هیچ کانفیگی از این شبکه جواب نداد. بعداً یا با اینترنت دیگه دوباره امتحان کن.',
    'No config answered from this network. Try again later or on another network.',
    'هیچ کانفیگێک لەم تۆڕەوە وەڵامی نەدایەوە. دواتر یان بە ئینتەرنێتێکی تر دووبارە تاقی بکەرەوە.',
  );
  String get noneFetched => _t(
    'هیچ منبعی جواب نداد. اگه VPN وصله، «پورت محلی در حالت VPN» رو روشن کن تا فهرست‌ها از راه VPN گرفته بشن.',
    'No source answered. If the VPN is on, turn on the local port in VPN mode so the lists are read through it.',
    'هیچ سەرچاوەیەک وەڵامی نەدایەوە. ئەگەر VPN پەیوەستە، پۆرتی ناوخۆیی لە دۆخی VPN داگیرسێنە تا لیستەکان لە ڕێیەوە وەربگیرێن.',
  );
  String get saveFailed => _t('پروفایل ذخیره نشد', 'The profile could not be saved', 'پرۆفایلەکە پاشەکەوت نەکرا');
  String get method => _t(
    'روش امتحان: اتصال TCP و دست‌دادنِ TLS به سرورِ هر کانفیگ، از همین شبکه (نه از راه VPN). بعد از انتخاب، خودِ رامان با تست تأخیر بهترین رو برمی‌داره. hy2/tuic (UDP) امتحان نمی‌شن و نگه داشته نمی‌شن.',
    "Test: a TCP connect and TLS handshake to each config's server, from this network (not through the VPN). Once chosen, Raman's own delay test picks the best. hy2/tuic (UDP) are not tested and not kept.",
    'تاقیکردنەوە: پەیوەندیی TCP و دەستدانی TLS بۆ ڕاژەکاری هەر کانفیگێک، لەم تۆڕەوە (نەک لە ڕێی VPN). دوای هەڵبژاردن، تاقیکردنەوەی دواکەوتنی ڕامان خۆی باشترینەکە هەڵدەبژێرێت. hy2/tuic (UDP) تاقی ناکرێنەوە و هەڵناگیرێن.',
  );
}

final finderStringsProvider = Provider<FinderStrings>((ref) => FinderStrings(ref.watch(localePreferencesProvider)));
