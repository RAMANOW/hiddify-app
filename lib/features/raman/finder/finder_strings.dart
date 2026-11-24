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
  // ---- 1.9 ----
  String get slowNote => _t(
    'از پشت تونل DNS، کُند است؛ فقط کانال‌های کانفیگِ قطعی (هر کدوم یک صفحه) و دو فایل کوچک خونده می‌شن.',
    'Behind the DNS tunnel, it is slow; only the shutdown-config channels (one page each) and two small files are read.',
    'لە پشت تونێلی DNS، خاوە؛ تەنها کەناڵەکانی کانفیگی بڕان (هەریەکە یەک لاپەڕە) و دوو فایلی بچووک دەخوێندرێنەوە.',
  );
  String get viaCore => _t('از راه پورت محلیِ رامان', 'through Raman\'s local port', 'لە ڕێی پۆرتی ناوخۆیی ڕامان');
  String get viaDns => _t('از راه تونل DNS', 'through the DNS tunnel', 'لە ڕێی تونێلی DNS');
  String get viaDirect => _t('مستقیم', 'directly', 'ڕاستەوخۆ');
  String route(String r) => switch (r) {
    'core' => viaCore,
    'dns' => viaDns,
    _ => viaDirect,
  };
  String get shutdownSources => _t('کانال‌های کانفیگِ قطعی', 'Shutdown-config channels', 'کەناڵەکانی کانفیگی بڕان');
  String get shutdownHint => _t(
    'کانال‌هایی که در قطعیِ اسفند ۱۴۰۴ تا خرداد ۱۴۰۵ کانفیگ DNS و کانفیگِ مخصوصِ نت ملی گذاشتن. لینک‌های DNS به تب «DNS قطعی» می‌رن و بقیه به پروفایل «کانفیگ‌یاب».',
    'Channels that posted DNS-tunnel configs and national-internet configs during the Feb–May 2026 shutdown. DNS links go to the Shutdown DNS tab, the rest to the «کانفیگ‌یاب» profile.',
    'ئەو کەناڵانەی لە بڕانی ئینتەرنێتی شوبات تا ئایار کانفیگی DNS و کانفیگی تایبەت بە نێتی نیشتمانییان دانا. لینکەکانی DNS دەچن بۆ «DNSی بڕان» و ئەوانی تر بۆ پرۆفایلی «کانفیگ‌یاب».',
  );
  String get rankNote => _t(
    'ترتیب: اول REALITY، بعد XHTTP، بعد بقیهٔ TLS، آخر هم بدون TLS.',
    'Order: REALITY first, then XHTTP, then other TLS, plain last.',
    'ڕیزبەندی: یەکەم REALITY، دواتر XHTTP، دواتر TLSی تر، کۆتایی بێ TLS.',
  );

  // clean IP scanner
  String get cleanButton => _t('اسکنِ IP تمیز (CDN)', 'Clean IP scan (CDN)', 'پشکنینی IPی پاک (CDN)');
  String get cleanTitle => _t('IP تمیز برای کانفیگ CDN', 'Clean IP for a CDN config', 'IPی پاک بۆ کانفیگی CDN');
  String get cleanIntro => _t(
    'یک کانفیگِ پشتِ CDN (TLS با دامنه) بده. رامان می‌فهمه کدوم CDN سرویسش می‌ده، IPهای همون CDN رو از فهرستی که خودِ شرکت منتشر کرده با SNIِ کانفیگ امتحان می‌کنه و یک «کپی» از کانفیگ با بهترین IP در پروفایل «IP تمیز» می‌سازه. کانفیگِ اصلی دست نمی‌خوره. کلودفلر عمداً اسکن نمی‌شه (از مهر ۱۴۰۵ از ایران کُند شده).',
    'Give a config that runs behind a CDN (TLS with a domain). Raman finds which CDN serves it, tries edge IPs of that CDN from the list the company itself publishes with the config\'s SNI, and writes a copy of the config with the best IP into the «IP تمیز» profile. The original is not changed. Cloudflare is deliberately not scanned (throttled from Iran since Oct 2026).',
    'کانفیگێکی پشت CDN (TLS بە دۆمەین) بدە. ڕامان دەزانێت کام CDN خزمەتی دەکات، IPەکانی هەمان CDN لە ئەو لیستەی کە کۆمپانیاکە خۆی بڵاوی کردووەتەوە بە SNIی کانفیگەکە تاقی دەکاتەوە و «کۆپییەک» لە کانفیگەکە بە باشترین IP لە پرۆفایلی «IP تمیز» دروست دەکات. کانفیگە سەرەکییەکە دەستی لێ نادرێت. Cloudflare بە ئەنقەست ناپشکنرێت.',
  );
  String get cleanLink => _t('لینکِ کانفیگ (vless / vmess / trojan)', 'Config link (vless / vmess / trojan)', 'لینکی کانفیگ (vless / vmess / trojan)');
  String get cleanCheck => _t('بررسی کانفیگ', 'Check the config', 'پشکنینی کانفیگ');
  String cleanBadConfig(String why) => switch (why) {
    'reality' => _t('REALITY به یک سرورِ مشخص وصل می‌شه، نه CDN؛ IP تمیز براش معنی نداره.', 'REALITY talks to one server, not a CDN; a clean IP means nothing for it.', 'REALITY بە یەک ڕاژەکار پەیوەست دەبێت، نەک CDN.'),
    'notls' => _t('فقط کانفیگ‌های TLS اسکن می‌شن.', 'Only TLS configs can be scanned.', 'تەنها کانفیگەکانی TLS دەپشکنرێن.'),
    'udp' => _t('کانفیگ‌های UDP/QUIC اسکن نمی‌شن.', 'UDP/QUIC configs can not be scanned.', 'کانفیگەکانی UDP/QUIC ناپشکنرێن.'),
    'nosni' => _t('این کانفیگ SNIِ دامنه‌دار نداره.', 'This config has no domain SNI.', 'ئەم کانفیگە SNIی دۆمەینی نییە.'),
    _ => _t('این لینک خونده نشد.', 'This link could not be read.', 'ئەم لینکە نەخوێندرایەوە.'),
  };
  String cleanDetected(String cdn) => _t('این دامنه روی $cdn است.', 'This domain is on $cdn.', 'ئەم دۆمەینە لەسەر $cdn ـە.');
  String get cleanIsCloudflare => _t(
    'این دامنه پشتِ کلودفلره؛ اسکنِ کلودفلر عمداً خاموشه. اگه مطمئنی همین دامنه روی CDNِ دیگه‌ای هم هست، از فهرست انتخابش کن.',
    'This domain is behind Cloudflare; Cloudflare scanning is deliberately off. If you know the domain is also on another CDN, pick it from the list.',
    'ئەم دۆمەینە لە پشت Cloudflareـە؛ پشکنینی Cloudflare بە ئەنقەست کوژاوەیە. ئەگەر دڵنیایت لەسەر CDNێکی تریشە، لە لیستەکە هەڵیبژێرە.',
  );
  String get cleanUnknownCdn => _t(
    'CDNِ این دامنه شناخته نشد (یا DNS جواب نداد). اگه می‌دونی کدومه، از فهرست انتخابش کن.',
    'The CDN of this domain was not recognised (or DNS did not answer). Pick it from the list if you know it.',
    'CDNی ئەم دۆمەینە نەناسرایەوە. ئەگەر دەزانیت کامەیە، لە لیستەکە هەڵیبژێرە.',
  );
  String get cleanProvider => _t('CDN', 'CDN', 'CDN');
  String get cleanPick => _t('انتخاب', 'Pick', 'هەڵبژاردن');
  String get cleanCount => _t('تعداد IP برای امتحان', 'IPs to try', 'ژمارەی IP بۆ تاقیکردنەوە');
  String get cleanSnapshot => _t(
    '* فهرستِ زنده خونده نشد؛ از نسخهٔ ذخیره‌شدهٔ فهرستِ همین شرکت (آذر ۱۴۰۵) استفاده می‌شه.',
    '* The live list could not be read; the saved copy of the provider\'s own list (Nov 2026) is used.',
    '* لیستی زیندوو نەخوێندرایەوە؛ کۆپییە پاشەکەوتکراوەکەی لیستی هەمان کۆمپانیا بەکاردێت.',
  );
  String get cleanNoList => _t('فهرستِ IPهای این CDN خونده نشد.', 'The IP list of this CDN could not be read.', 'لیستی IPەکانی ئەم CDNـە نەخوێندرایەوە.');
  String get cleanScan => _t('اسکن', 'Scan', 'پشکنین');
  String get cleanNone => _t(
    'هیچ IPی با SNIِ این کانفیگ جواب نداد. تعداد رو بیشتر کن یا CDNِ دیگه رو امتحان کن.',
    'No IP answered with this config\'s SNI. Try more IPs or another CDN.',
    'هیچ IPێک بە SNIی ئەم کانفیگە وەڵامی نەدایەوە.',
  );
  String cleanFound(int n) => _t('$n IP جواب دادن (سریع‌ترین بالا).', '$n IPs answered (fastest first).', '$n IP وەڵامیان دایەوە.');
  String get cleanApplyBest => _t('ساختِ کپی با بهترین IP', 'Make a copy with the best IP', 'کۆپی بە باشترین IP');
  String get cleanApply => _t('ساختِ کپی با این IP', 'Make a copy with this IP', 'کۆپی بەم IPیە');
  String get cleanApplyHint => _t(
    'کپی در پروفایل «IP تمیز» ذخیره می‌شه؛ کانفیگِ اصلی همون‌طور می‌مونه.',
    'The copy is saved in the «IP تمیز» profile; the original stays as it is.',
    'کۆپییەکە لە پرۆفایلی «IP تمیز» پاشەکەوت دەکرێت؛ کانفیگە سەرەکییەکە وەک خۆی دەمێنێتەوە.',
  );
  String cleanApplied(String ip) => _t('کپی با $ip در «IP تمیز» ذخیره شد', 'Copy with $ip saved in «IP تمیز»', 'کۆپی بە $ip لە «IP تمیز» پاشەکەوت کرا');
  String get cleanMethod => _t(
    'روش: اتصال TCP و دست‌دادنِ TLS با SNIِ کانفیگ به هر IP، از همین شبکه؛ گواهی باید برای همون دامنه معتبر باشه. منابعِ IP: فهرست‌های عمومیِ Fastly، Gcore، Akamai، Amazon CloudFront و Bunny CDN.',
    'Method: a TCP connect and a TLS handshake with the config\'s SNI to each IP, from this network; the certificate must be valid for that domain. IP sources: the public lists of Fastly, Gcore, Akamai, Amazon CloudFront and Bunny CDN.',
    'ڕێگا: پەیوەندیی TCP و دەستدانی TLS بە SNIی کانفیگەکە بۆ هەر IPێک، لەم تۆڕەوە؛ بڕوانامەکە دەبێت بۆ هەمان دۆمەین دروست بێت. سەرچاوەکان: لیستە گشتییەکانی Fastly، Gcore، Akamai، Amazon CloudFront و Bunny CDN.',
  );
}

final finderStringsProvider = Provider<FinderStrings>((ref) => FinderStrings(ref.watch(localePreferencesProvider)));
