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
}

final ramanStringsProvider = Provider<RamanStrings>(
  (ref) => RamanStrings(ref.watch(localePreferencesProvider) == AppLocale.fa),
);
