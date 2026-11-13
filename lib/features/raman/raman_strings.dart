import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/gen/translations.g.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The texts of Raman VPN's own screens, in Persian and English.
class RamanStrings {
  const RamanStrings(this.fa);

  final bool fa;

  String _t(String faText, String enText) => fa ? faText : enText;

  String get toolsTitle => _t('ابزارهای رامان', 'Raman tools');
  String get toolsSubtitle => _t('DNS هوشمند، بررسی شبکه، تنظیمات ایران', 'Smart DNS, network check, Iran settings');
  String get tabDns => _t('DNS هوشمند', 'Smart DNS');
  String get tabNetwork => _t('بررسی شبکه', 'Network check');
  String get tabIran => _t('تنظیمات ایران', 'Iran settings');

  String get dnsIntro => _t(
    'سرورهای DNS عمومی آزمایش می‌شوند و سریع‌ترین سرور سالم به‌طور خودکار برای DNS مستقیم و DNS راه‌دور انتخاب می‌شود. این آزمایش هنگام باز شدن برنامه، روزی یک‌بار، انجام می‌شود.',
    'Public DNS resolvers are tested and the fastest working one is set as the direct and remote DNS automatically. The test runs when the app opens, once a day.',
  );
  String get testNow => _t('آزمایش کن', 'Test now');
  String get testing => _t('در حال آزمایش…', 'Testing…');
  String get autoDirect => _t('انتخاب خودکار DNS مستقیم', 'Pick the direct DNS automatically');
  String get autoRemote => _t('انتخاب خودکار DNS راه‌دور', 'Pick the remote DNS automatically');
  String get currentDirect => _t('DNS مستقیم فعلی', 'Current direct DNS');
  String get currentRemote => _t('DNS راه‌دور فعلی', 'Current remote DNS');
  String get lastRun => _t('آخرین آزمایش', 'Last test');
  String get never => _t('هنوز انجام نشده', 'Not yet');
  String get failed => _t('ناموفق', 'Failed');
  String get poisoned => _t('پاسخ فیلترشده', 'Filtered answer');
  String get domestic => _t('داخلی', 'Iranian');
  String get vpnWarning => _t(
    'VPN روشن است؛ نتیجه‌ها از داخل تونل اندازه‌گیری شده‌اند. برای دقیق‌ترین نتیجه، آزمایش را با VPN خاموش انجام دهید.',
    'The VPN is on, so these numbers went through the tunnel. For the most accurate pick, test with the VPN off.',
  );
  String get applied => _t('اعمال شد', 'Applied');
  String get reconnectHint => _t(
    'اگر متصل هستید، برای اعمال DNS جدید یک‌بار قطع و وصل کنید.',
    'If you are connected, reconnect once to use the new DNS.',
  );

  String get networkIntro => _t(
    'دسترسی و تأخیر سرویس‌های پرکاربرد را بررسی می‌کند. یک‌بار با VPN خاموش و یک‌بار روشن آزمایش کنید تا مقایسه کنید.',
    'Checks whether popular services are reachable and how fast. Run it once with the VPN off and once with it on to compare.',
  );
  String get withVpn => _t('با VPN', 'With VPN');
  String get withoutVpn => _t('بدون VPN', 'Without VPN');
  String get vpnIsOn => _t('VPN اکنون روشن است', 'The VPN is on now');
  String get vpnIsOff => _t('VPN اکنون خاموش است', 'The VPN is off now');
  String get runCheck => _t('بررسی کن', 'Check now');
  String get notTested => _t('—', '—');
  String get ms => _t('میلی‌ثانیه', 'ms');

  String get iranIntro => _t(
    'تنظیمات پیشنهادی برای اینترنت ایران: سایت‌های داخلی مستقیم باز می‌شوند، TLS fragment برای عبور از فیلترینگ روشن است و زبان برنامه فارسی است.',
    'Suggested settings for Iran: domestic sites open directly, TLS fragment is on to get past filtering, and the app is in Persian.',
  );
  String get regionIran => _t('منطقه: ایران (سایت‌های داخلی مستقیم)', 'Region: Iran (domestic sites go direct)');
  String get tlsFragment => _t('TLS fragment (عبور از فیلترینگ)', 'TLS fragment (gets past filtering)');
  String get mixedSni => _t('حروف درهم SNI', 'Mixed-case SNI');
  String get ipv4Only => _t('فقط IPv4 (اتصال سریع‌تر)', 'IPv4 only (faster connecting)');
  String get persian => _t('زبان فارسی', 'Persian language');
  String get applyAll => _t('اعمال همه تنظیمات پیشنهادی', 'Apply all suggested settings');
  String get appliedAll => _t('تنظیمات ایران اعمال شد', 'Iran settings applied');
  // home tabs
  String get tabRaman => _t('رامان', 'Raman');
  String get tabShield => _t('شیلد', 'Shield');

  // Shield
  String get shieldIntro => _t(
    'شیلد بدون نیاز به سرور یا اشتراک، با یک لمس از طریق شبکه‌ی Psiphon وصل می‌شود و خودش راه عبور از فیلترینگ را پیدا می‌کند.',
    'Shield connects in one tap through the Psiphon network, with no server or subscription, and finds its own way past filtering.',
  );
  String get shieldConnect => _t('اتصال', 'Connect');
  String get shieldDisconnect => _t('قطع اتصال', 'Disconnect');
  String get shieldDisconnected => _t('قطع است', 'Not connected');
  String get shieldConnecting => _t('در حال اتصال… (اولین بار ممکن است تا یک دقیقه طول بکشد)', 'Connecting… (the first time can take up to a minute)');
  String get shieldConnected => _t('شیلد وصل است', 'Shield is connected');
  String get shieldDisconnecting => _t('در حال قطع…', 'Disconnecting…');
  String get shieldRegion => _t('کشور خروجی', 'Exit country');
  String get shieldRegionAuto => _t('بهترین کشور (خودکار)', 'Best country (automatic)');
  String get shieldChain => _t('شیلد همراه پروفایل‌های رامان', 'Shield with the Raman profiles');
  String get shieldChainOff => _t('خاموش', 'Off');
  String get shieldChainSecurity => _t('امنیت بیشتر', 'Extra security');
  String get shieldChainUnblocker => _t('رفع مسدودی', 'Unblocker');
  String get shieldChainHelp => _t(
    'امنیت بیشتر: ترافیک پروفایل رامان از شیلد هم عبور می‌کند. رفع مسدودی: اتصال به سرور پروفایل از طریق شیلد برقرار می‌شود. هنگام استفاده از تب رامان اعمال می‌شود.',
    'Extra security: Raman profile traffic also passes through Shield. Unblocker: the profile’s server is reached through Shield. Applies when you use the Raman tab.',
  );
  String get shieldPerApp => _t('تونل‌سازی جداگانه برای برنامه‌ها', 'Per-app split tunneling');
  String get shieldPerAppOn => _t('روشن — برای انتخاب برنامه‌ها لمس کنید', 'On — tap to choose apps');
  String get shieldPerAppOff => _t('همه‌ی برنامه‌ها از VPN استفاده می‌کنند', 'All apps use the VPN');
  String get shieldLan => _t('اشتراک پروکسی در شبکه‌ی محلی', 'Share the proxy on the local network');
  String shieldLanPort(int port) => _t('دستگاه‌های دیگر این شبکه می‌توانند از پورت $port استفاده کنند', 'Other devices on this network can use port $port');
  String get shieldLanOff => _t('فقط همین دستگاه', 'This device only');
  String get switchTitle => _t('فقط یک VPN در هر زمان', 'One VPN at a time');
  String get switchToShield => _t('رامان اکنون وصل است. برای استفاده از شیلد، اتصال رامان قطع شود؟', 'Raman is connected now. Disconnect it to use Shield?');
  String get switchToRaman => _t('شیلد اکنون وصل است. برای استفاده از پروفایل‌های رامان، شیلد قطع شود؟', 'Shield is connected now. Disconnect it to use the Raman profiles?');
  String get switchYes => _t('قطع و ادامه', 'Disconnect and continue');
  String get shieldFailed => _t('اتصال شیلد ناموفق بود', 'Shield could not connect');
  String get reconnectToApply => _t('برای اعمال، دوباره وصل شوید', 'Reconnect to apply');

  // disguise icon
  String get disguiseTitle => _t('آیکون مخفی', 'Disguise icon');
  String get disguiseSubtitle => _t('نام و آیکون برنامه را در صفحه‌ی اصلی گوشی تغییر دهید', 'Change the app’s name and icon on the home screen');
  String get disguiseHelp => _t(
    'آیکون و نام برنامه در لانچر گوشی عوض می‌شود تا برنامه کمتر به چشم بیاید. ممکن است لانچر چند ثانیه طول بکشد تا تغییر را نشان دهد و میانبرهای قبلی صفحه‌ی اصلی حذف شوند.',
    'The app’s icon and name in the phone launcher change so it stands out less. The launcher can take a few seconds to show it, and old home-screen shortcuts may be removed.',
  );
  String get disguiseDefault => _t('رامان VPN (پیش‌فرض)', 'Raman VPN (default)');
  String get disguiseCalculator => _t('ماشین‌حساب', 'Calculator');
  String get disguiseWeather => _t('آب‌وهوا', 'Weather');
  String get disguiseNotes => _t('یادداشت‌ها', 'Notes');
  String get disguiseClock => _t('ساعت', 'Clock');
  String get disguiseApplied => _t('آیکون تغییر کرد', 'Icon changed');
  String get disguiseUnsupported => _t('روی این دستگاه پشتیبانی نمی‌شود', 'Not supported on this device');

  // Shield settings
  String get ssTitle => _t('تنظیمات شیلد', 'Shield settings');
  String get ssOpen => _t('همه‌ی تنظیمات شیلد', 'All Shield settings');
  String get ssOpenSub => _t('تونل‌سازی جداگانه، پروکسی بالادستی، اشتراک در شبکه، اعلان‌ها و…', 'Split tunneling, upstream proxy, network sharing, notifications and more');
  String get ssSoon => _t('به‌زودی', 'Coming soon');
  String ssSoonNote(String why) => _t('به‌زودی — $why', 'Coming soon — $why');
  String get ssNeedsCore => _t('هسته‌ی فعلی برنامه این گزینه را پشتیبانی نمی‌کند', 'the app’s current core does not support it yet');
  String get ssApply => _t('اعمال و اتصال دوباره', 'Apply and reconnect');
  String get ssApplied => _t('تنظیمات اعمال شد', 'Settings applied');
  String get ssSaved => _t('ذخیره شد؛ در اتصال بعدی شیلد اعمال می‌شود', 'Saved; used the next time Shield connects');
  String get ssNotSet => _t('تنظیم نشده', 'Not set');
  String get ssSave => _t('ذخیره', 'Save');
  String get ssCancel => _t('انصراف', 'Cancel');
  String get ssClear => _t('پاک کردن', 'Clear');

  String get ssSecRegion => _t('کشور', 'Region');
  String get ssSecSplit => _t('تونل‌سازی جداگانه (VPN)', 'Split tunneling (VPN)');
  String get ssSplitAll => _t('همه‌ی برنامه‌ها از شیلد استفاده کنند', 'Tunnel all apps');
  String get ssSplitInclude => _t('فقط برنامه‌های انتخاب‌شده', 'Only tunnel selected apps');
  String get ssSplitExclude => _t('همه به‌جز برنامه‌های انتخاب‌شده', 'Tunnel all apps except selected ones');
  String get ssSplitChoose => _t('انتخاب برنامه‌ها', 'Choose apps');
  String ssSplitCount(int n) => _t('$n برنامه انتخاب شده', '$n apps selected');
  String get ssSplitHelp => _t(
    'این انتخاب فقط برای شیلد است و هنگام اتصال شیلد به کار می‌رود؛ پروفایل‌های رامان تنظیم «مسیریابی برنامه‌ها»ی خودشان را دارند. خود برنامه همیشه بیرون از تونل است.',
    'This is Shield’s own choice, used when Shield connects; the Raman profiles keep their own app-based routing. This app itself always stays outside the tunnel.',
  );
  String get ssAlwaysOn => _t('VPN همیشه روشن', 'Always-on VPN');
  String get ssAlwaysOnSub => _t('رفتن به تنظیمات سیستم برای روشن کردن VPN همیشه روشن', 'Open the system settings to turn on always-on VPN');
  String get ssAppsSearch => _t('جستجوی برنامه', 'Search apps');
  String get ssAppsHideSystem => _t('پنهان کردن برنامه‌های سیستمی', 'Hide system apps');
  String get ssAppsShowSystem => _t('نمایش برنامه‌های سیستمی', 'Show system apps');
  String get ssAppsIncludeTitle => _t('برنامه‌هایی که از شیلد استفاده کنند', 'Apps that use Shield');
  String get ssAppsExcludeTitle => _t('برنامه‌هایی که از شیلد استفاده نکنند', 'Apps that skip Shield');
  String get ssAppsUnsupported => _t('فقط روی اندروید', 'Android only');

  String get ssSecUpstream => _t('پروکسی بالادستی', 'Upstream proxy');
  String get ssUpstreamHelp => _t(
    'اگر شبکه‌ی شما (مثلاً محل کار یا دانشگاه) فقط از طریق یک پروکسی به اینترنت وصل می‌شود، شیلد اتصال‌های خودش را از آن پروکسی عبور می‌دهد.',
    'If your network (at work or university, say) only reaches the internet through a proxy, Shield sends its own connections through it.',
  );
  String get ssUpstreamUse => _t('اتصال از طریق پروکسی', 'Connect through a proxy');
  String get ssUpstreamSystem => _t('استفاده از پروکسی تنظیم‌شده در سیستم (Wi‑Fi)', 'Use the system (Wi‑Fi) proxy settings');
  String get ssUpstreamCustom => _t('استفاده از پروکسی دلخواه', 'Use a custom proxy');
  String get ssUpstreamType => _t('نوع پروکسی', 'Proxy type');
  String get ssUpstreamHost => _t('آدرس میزبان', 'Host address');
  String get ssUpstreamHostHint => _t('مثلاً 192.168.1.10 یا proxy.example.com', 'e.g. 192.168.1.10 or proxy.example.com');
  String get ssUpstreamPort => _t('پورت', 'Port');
  String get ssUpstreamAuth => _t('پروکسی نیاز به احراز هویت دارد', 'The proxy needs authentication');
  String get ssUpstreamUser => _t('نام کاربری', 'Username');
  String get ssUpstreamPass => _t('رمز عبور', 'Password');
  String get ssUpstreamDomain => _t('دامنه (NTLM، اختیاری)', 'Domain (NTLM, optional)');
  String get ssUpstreamNoSystem => _t('پروکسی سیستمی پیدا نشد؛ شیلد مستقیم وصل می‌شود', 'No system proxy found; Shield connects directly');
  String get ssUpstreamInvalid => _t('میزبان و پورت پروکسی دلخواه را وارد کنید', 'Enter the custom proxy’s host and port');

  String get ssSecLan => _t('اشتراک پروکسی در شبکه', 'Share proxy on network');
  String get ssLanHelp => _t(
    'دستگاه‌های دیگر همین Wi‑Fi می‌توانند از طریق این گوشی وصل شوند. یک پورت هم SOCKS5 و هم HTTP را پاسخ می‌دهد و با رمز محافظت می‌شود؛ نشانی، رمز و کد QR را با لمس گزینه ببینید.',
    'Other devices on the same Wi‑Fi can connect through this phone. One port answers both SOCKS5 and HTTP and is protected by a password; tap the row for the address, password and QR code.',
  );
  String get ssLanPort => _t('پورت اشتراک (SOCKS5 و HTTP)', 'Sharing port (SOCKS5 and HTTP)');

  String get ssSecConnection => _t('اتصال', 'Connection');
  String get ssDisableTimeouts => _t('غیرفعال کردن مهلت‌ها', 'Disable timeouts');
  String get ssDisableTimeoutsSub => _t(
    'برای شبکه‌های کند: شیلد به‌جای یک دقیقه تا ۳۰ دقیقه برای برقراری تونل تلاش می‌کند',
    'For slow networks: Shield keeps trying to build the tunnel for up to 30 minutes instead of one',
  );
  String get ssProtocol => _t('پروتکل اتصال', 'Connection protocol');
  String get ssProtocolSub => _t('خودکار (مستقیم، CDN fronting، Conduit)', 'Automatic (direct, CDN fronting, Conduit)');
  String get ssBeast => _t('حالت تهاجمی (Beast)', 'Beast mode');
  String get ssBeastSub => _t('امتحان همه‌ی پروتکل‌ها روی هر سرور', 'Try every protocol on every server');
  String get ssSecCdn => _t('CDN fronting', 'CDN fronting');
  String get ssCdnIps => _t('IPهای لبه‌ی CDN', 'CDN edge IPs');
  String get ssCdnSni => _t('نام‌های SNI برای CDN', 'CDN SNI hostnames');
  String get ssSecConduit => _t('Conduit (رله‌های داوطلب)', 'Conduit (volunteer relays)');
  String get ssConduitMode => _t('حالت Conduit', 'Conduit mode');
  String get ssConduitTimeout => _t('زمان جایگزینی', 'Fallback timeout');
  String get ssConduitReject => _t('رد کردن رله‌های کشورهای سانسورشده', 'Reject relays in censored countries');

  String get ssSecNotifications => _t('اعلان‌ها', 'Notifications');
  String get ssSound => _t('صدا', 'Sound');
  String get ssSoundSub => _t('پخش صدا هنگام تغییر وضعیت اتصال شیلد', 'Play a sound when Shield’s connection changes');
  String get ssVibrate => _t('لرزش', 'Vibrate');
  String get ssVibrateSub => _t('لرزش هنگام تغییر وضعیت اتصال شیلد', 'Vibrate when Shield’s connection changes');
  String get ssStealth => _t('اعلان مخفی', 'Stealth notifications');
  String get ssStealthSub => _t(
    'وقتی آیکون مخفی فعال است، اعلان VPN نام و آیکون همان برنامه‌ی ظاهری را نشان می‌دهد',
    'With a disguise icon on, the VPN notification shows the disguise app’s name and icon',
  );

  String get ssSecAppearance => _t('ظاهر و زبان', 'Appearance and language');

  String get ssSecMore => _t('بیشتر', 'More');
  String get ssOpenSite => _t('باز کردن یک وب‌سایت پس از اتصال', 'Open a website after connecting');
  String get ssOpenSiteUrl => _t('نشانی وب‌سایت', 'Website address');
  String get ssOpenSiteInvalid => _t('نشانی باید با https:// یا http:// شروع شود', 'The address must start with https:// or http://');
  String get ssMalware => _t('هشدار ترافیک ناامن (بدافزار)', 'Unsafe traffic (malware) alerts');
  String get ssMalwareWhy => _t('نیاز به هشدارهای سرور که هسته‌ی فعلی ارائه نمی‌دهد', 'needs server alerts the current core does not pass on');
  String get ssNfc => _t('اشتراک با NFC', 'NFC bump');
  String get ssNfcWhy => _t('نیاز به کتابخانه‌ی جاوای جداگانه برای خروجی گرفتن از سرورها', 'needs a separate Java library to export servers');
  String get ssWifiUpdates => _t('دانلود به‌روزرسانی فقط با Wi‑Fi', 'Download upgrades on Wi‑Fi only');
  String get ssWifiUpdatesWhy => _t('به‌روزرسانی‌ها از صفحه‌ی انتشار برنامه دریافت می‌شوند و دانلود خودکار ندارند', 'updates come from the app’s releases page; nothing downloads by itself');
  String get ssFeedback => _t('ارسال گزارش', 'Send feedback');
  String get ssFeedbackSub => _t('گزارش‌ها (لاگ) را ببینید و ذخیره یا ارسال کنید', 'View the logs and save or share them');
  String get ssAbout => _t('درباره', 'About');
  String get ssConduitWhy => _t('Conduit و حالت‌های اتصال نیاز به تنظیمات هسته دارند که هنوز در دسترس نیست', 'Conduit and the connection modes need core options that are not available yet');

  // diagnostics
  String get shareDiagnostics => _t('ذخیره یا اشتراک‌گذاری فایل گزارش', 'Save or share the report file');
  String get shareDiagnosticsMsg => _t('فایل را برای پشتیبانی خودتان بفرستید', 'Send the file to whoever supports you');
}

final ramanStringsProvider = Provider<RamanStrings>(
  (ref) => RamanStrings(ref.watch(localePreferencesProvider) == AppLocale.fa),
);
