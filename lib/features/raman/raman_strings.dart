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

  // diagnostics
  String get shareDiagnostics => _t('ذخیره یا اشتراک‌گذاری فایل گزارش', 'Save or share the report file');
  String get shareDiagnosticsMsg => _t('فایل را برای پشتیبانی خودتان بفرستید', 'Send the file to whoever supports you');
}

final ramanStringsProvider = Provider<RamanStrings>(
  (ref) => RamanStrings(ref.watch(localePreferencesProvider) == AppLocale.fa),
);
