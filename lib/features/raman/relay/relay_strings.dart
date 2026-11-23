import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/gen/translations.g.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The Google Relay tab's texts: Persian, English, and Kurdish (Sorani) where given; a missing
/// Kurdish text is shown in Persian.
class RelayStrings {
  const RelayStrings(this.locale);

  final AppLocale locale;

  String _t(String fa, String en, [String? ckb]) => switch (locale) {
    AppLocale.fa => fa,
    AppLocale.ckb => ckb ?? fa,
    _ => en,
  };

  String get tab => _t('رله گوگل', 'Google Relay', 'ڕیلەی گووگڵ');
  String get intro => _t(
    'رله گوگل ترافیک وب را از راه Google Apps Script خودتان می‌فرستد. برای اینترنت‌دهنده فقط اتصال به www.google.com دیده می‌شود (Domain Fronting). به سرور یا VPS نیازی نیست؛ فقط یک حساب گوگل.',
    'Google Relay sends web traffic through your own Google Apps Script. Your ISP only sees a connection to www.google.com (domain fronting). No server or VPS needed, just a Google account.',
  );

  // status
  String get stateOff => _t('رله خاموش است', 'The relay is off', 'ڕیلەکە کوژاوەتەوە');
  String get stateOn => _t('رله روشن است', 'The relay is on', 'ڕیلەکە داگیرساوە');
  String get stateConnected => _t('متصل از راه رله گوگل', 'Connected through Google Relay', 'پەیوەستە لە ڕێی ڕیلەی گووگڵ');
  String get stateConnecting => _t('در حال اتصال…', 'Connecting…', 'پەیوەستبوون…');
  String get stateRelayNoVpn =>
      _t('رله روشن است ولی VPN وصل نیست', 'The relay runs but the VPN is not connected', 'ڕیلەکە کار دەکات بەڵام VPN پەیوەست نییە');
  String get start => _t('روشن کردن رله و اتصال', 'Start the relay and connect', 'داگیرساندنی ڕیلە و پەیوەستبوون');
  String get stop => _t('خاموش کردن رله', 'Stop the relay', 'کوژاندنەوەی ڕیلە');
  String get connectAgain => _t('اتصال VPN', 'Connect the VPN', 'پەیوەستکردنی VPN');
  String get starting => _t('در حال روشن شدن…', 'Starting…', 'داگیرساندن…');
  String get unavailable => _t(
    'هستهٔ رله در این نسخه بارگذاری نشد.',
    'The relay core could not be loaded in this build.',
  );
  String get busyTitle => _t('اتصال فعلی قطع شود؟', 'Stop the current connection?', 'پەیوەندیی ئێستا ببڕدرێت؟');
  String get busyBody => _t(
    'فقط یک VPN در یک زمان کار می‌کند. اتصال فعلی قطع و رله گوگل وصل شود؟',
    'Only one VPN runs at a time. Stop the current connection and connect through Google Relay?',
  );
  String get yes => _t('بله', 'Yes', 'بەڵێ');
  String get shieldFirst => _t(
    'اول از زبانهٔ شیلد به زبانهٔ رامان برگردید.',
    'Go back from the Shield tab to the Raman tab first.',
  );
  String get missingIds => _t('حداقل یک Deployment ID درست وارد کنید.', 'Enter at least one valid Deployment ID.');
  String get missingKey => _t('AUTH_KEY را وارد کنید.', 'Enter the AUTH_KEY.');
  String get missingIp => _t('google_ip باید یک IPv4 باشد.', 'google_ip must be an IPv4 address.');
  String get startFailed => _t('رله روشن نشد', 'The relay did not start', 'ڕیلەکە دانەگیرسا');
  String get profileFailed => _t('پروفایل رله ساخته نشد', 'The relay profile could not be made');
  String get applied => _t('تنظیمات رله اعمال شد', 'Relay settings applied', 'ڕێکخستنەکانی ڕیلە جێبەجێ کران');
  String get apply => _t('اعمال روی رله روشن', 'Apply to the running relay', 'جێبەجێکردن لەسەر ڕیلەی داگیرساو');
  String get whileOn => _t(
    'تا وقتی رله روشن است، FakeIP روشن و QUIC بسته است (برای همهٔ پروفایل‌ها). با خاموش کردن رله، تنظیم قبلی‌تان برمی‌گردد.',
    'While the relay is on, FakeIP is on and QUIC is blocked (for every profile). Stopping the relay brings your own settings back.',
  );

  // settings
  String get settings => _t('تنظیمات رله', 'Relay settings', 'ڕێکخستنەکانی ڕیلە');
  String get ids => _t('Deployment ID (هر خط یکی)', 'Deployment IDs (one per line)', 'Deployment ID (هەر هێڵێک یەک)');
  String get idsHint => _t(
    'شناسه یا نشانی …/macros/s/…/exec. چند شناسه = پخش بار و سهمیهٔ بیشتر.',
    'The ID or the …/macros/s/…/exec URL. Several = load spread and more quota.',
  );
  String idsCount(int n) => _t('$n شناسهٔ معتبر', '$n valid', '$n ناسنامەی دروست');
  String get authKey => 'AUTH_KEY';
  String get authKeyHint => _t(
    'همان کلیدی که در Code.gs گذاشته‌اید (۲۰ نویسه یا بیشتر).',
    'The same key you put in Code.gs (20+ characters).',
  );
  String get generate => _t('ساخت کلید تصادفی', 'Generate a random key', 'دروستکردنی کلیلی هەڕەمەکی');
  String get advanced => _t('پیشرفته: IP گوگل و SNI', 'Advanced: Google IP and SNI', 'پێشکەوتوو: IPی گووگڵ و SNI');
  String get googleIp => 'google_ip';
  String googleIpHint(String d) => _t('خالی = $d', 'Empty = $d', 'بەتاڵ = $d');
  String get front => _t('SNI جلویی (front_domain)', 'Front SNI (front_domain)', 'SNIی پێشەوە (front_domain)');
  String get testSni => _t('آزمایش IP و SNI', 'Test the IP and SNI', 'تاقیکردنەوەی IP و SNI');
  String sniOk(int ms) => _t('در دسترس است: $ms میلی‌ثانیه', 'Reachable: $ms ms', 'دەگەیشترێت: $ms ms');
  String sniFail(String e) => _t('در دسترس نیست: $e', 'Not reachable: $e', 'ناگەیشترێت: $e');

  // deploy
  String get deployTitle => _t('ساخت Apps Script (یک‌بار)', 'Deploy the Apps Script (once)', 'دروستکردنی Apps Script (جارێک)');
  String get deploySteps => _t(
    '۱. با رایانه یا مرورگر به script.google.com بروید و «New project» را بزنید.\n'
        '۲. دکمهٔ «کپی Code.gs» را بزنید و همهٔ کد پیش‌فرض را با آن جایگزین کنید.\n'
        '۳. اگر کلید را اینجا وارد کرده باشید، AUTH_KEY در کد کپی‌شده گذاشته شده است؛ وگرنه خط AUTH_KEY را با کلید خودتان عوض کنید.\n'
        '۴. ذخیره کنید، سپس Deploy ← New deployment ← نوع Web app.\n'
        '۵. Execute as: Me و Who has access: Anyone را انتخاب کنید و Deploy بزنید (بار اول اجازه بدهید: Advanced ← Go to … ← Allow).\n'
        '۶. Deployment ID را کپی کنید و بالا وارد کنید.',
    '1. On a computer or in a browser open script.google.com and tap "New project".\n'
        '2. Tap "Copy Code.gs" and replace all of the default code with it.\n'
        '3. If you entered the key here, AUTH_KEY is already set in the copied code; otherwise change the AUTH_KEY line to your key.\n'
        '4. Save, then Deploy → New deployment → type Web app.\n'
        '5. Execute as: Me, Who has access: Anyone, then Deploy (allow it the first time: Advanced → Go to … → Allow).\n'
        '6. Copy the Deployment ID and enter it above.',
  );
  String get copyCode => _t('کپی Code.gs', 'Copy Code.gs', 'کۆپیکردنی Code.gs');
  String get copiedWithKey => _t('Code.gs با AUTH_KEY شما کپی شد', 'Code.gs copied with your AUTH_KEY', 'Code.gs لەگەڵ AUTH_KEYەکەت کۆپی کرا');
  String get copiedNoKey => _t(
    'Code.gs کپی شد؛ AUTH_KEY را در کد عوض کنید',
    'Code.gs copied; change AUTH_KEY in the code',
    'Code.gs کۆپی کرا؛ AUTH_KEY لە کۆدەکەدا بگۆڕە',
  );
  String get openScript => _t('باز کردن script.google.com', 'Open script.google.com', 'کردنەوەی script.google.com');
  String get quota => _t(
    'هر حساب گوگل روزانه حدود ۲۰٬۰۰۰ درخواست دارد. برای مصرف بیشتر، با چند حساب چند Deployment بسازید و همه را وارد کنید.',
    'Each Google account gets about 20,000 calls a day. For more, deploy with several accounts and enter all the IDs.',
  );
  String usage(int calls) => _t('امروز: $calls درخواست از حدود ۲۰٬۰۰۰ (هر حساب)', 'Today: $calls calls of about 20,000 (per account)', 'ئەمڕۆ: $calls داواکاری لە نزیکەی ٢٠٬٠٠٠ (هەر هەژمارێک)');

  // certificate
  String get caTitle => _t('گواهی امنیتی (برای HTTPS)', 'Security certificate (for HTTPS)', 'بڕوانامەی ئاسایش (بۆ HTTPS)');
  String get caBody => _t(
    'رله برای سایت‌های HTTPS یک گواهی مخصوص همین گوشی می‌سازد (کلید آن فقط روی گوشی شماست). بعد از نصب گواهی، HTTPS در Chrome و مرورگرها کار می‌کند. بیشتر برنامه‌های دیگر (بانک، پیام‌رسان‌ها، استریم) به این گواهی اعتماد نمی‌کنند و از رله کار نمی‌کنند. تلگرام از پروتکل خودش (MTProto) استفاده می‌کند و از رله عبور نمی‌کند؛ در این حالت مستقیم وصل می‌شود و ممکن است کار نکند (تلگرام وب در مرورگر کار می‌کند).',
    'For HTTPS sites the relay makes a certificate for this phone only (its key never leaves the phone). Once it is installed, HTTPS works in Chrome and other browsers. Most other apps (banking, messengers, streaming) do not trust it and will not work through the relay. Telegram uses its own protocol (MTProto), which the relay cannot carry: it goes out directly and may not work (Telegram Web in a browser does).',
  );
  String get caInstall => _t('ذخیره و نصب گواهی', 'Save and install the certificate', 'پاشەکەوت و دامەزراندنی بڕوانامە');
  String caSaved(String path) => _t(
    'گواهی در $path ذخیره شد. در تنظیمات گوشی «CA certificate» یا «گواهی CA» را جستجو کنید، «Install anyway» را بزنید و این فایل را از Downloads انتخاب کنید. (اندروید برای نصب گواهی قفل صفحه می‌خواهد.)',
    'The certificate is saved as $path. In the phone settings search for "CA certificate", tap "Install anyway" and pick this file from Downloads. (Android needs a screen lock to install it.)',
  );
  String get caInstalled => _t('گواهی نصب است ✓', 'The certificate is installed ✓', 'بڕوانامەکە دامەزراوە ✓');
  String get caNotInstalled => _t('گواهی هنوز نصب نشده', 'The certificate is not installed yet', 'بڕوانامەکە هێشتا دانەمەزراوە');
  String get caFailed => _t('گواهی ساخته یا ذخیره نشد', 'The certificate could not be made or saved');
  String get caCheck => _t('بررسی دوباره', 'Check again', 'دووبارە پشکنین');
  String get fingerprint => _t('اثر انگشت SHA-256', 'SHA-256 fingerprint', 'شوێنپەنجەی SHA-256');

  // limits & logs
  String get limitsTitle => _t('محدودیت‌ها', 'Limits', 'سنوورەکان');
  String get limits => _t(
    '• فقط ترافیک وب (HTTP/HTTPS) از رله می‌رود؛ UDP، تماس صوتی/تصویری و بازی‌ها کار نمی‌کنند.\n'
        '• IP خروجی از مراکز داده گوگل است و هر درخواست ممکن است عوض شود؛ برخی سایت‌ها (Cloudflare) کپچا نشان می‌دهند.\n'
        '• ویدیو و دانلود بزرگ سهمیهٔ روزانه را زود مصرف می‌کند.\n'
        '• اتصال‌های غیر وب (مثل تلگرام) مستقیم و بدون تونل بیرون می‌روند.',
    '• Only web traffic (HTTP/HTTPS) goes through the relay; UDP, voice/video calls and games do not work.\n'
        '• The exit IP is in Google’s data centres and can change per request; some sites (Cloudflare) show captchas.\n'
        '• Video and large downloads use up the daily quota fast.\n'
        '• Non-web connections (such as Telegram) go out directly, outside the tunnel.',
  );
  String get logs => _t('گزارش رله', 'Relay log', 'تۆماری ڕیلە');
  String get refresh => _t('تازه کردن', 'Refresh', 'نوێکردنەوە');
  String get noLogs => _t('گزارشی نیست', 'No log lines', 'هیچ تۆمارێک نییە');
  String get credit => _t(
    'بر پایهٔ MasterHttpRelayVPN از masterking32 و نسخهٔ Rust آن mhrv-rs از therealaleph (مجوز MIT).',
    'Based on MasterHttpRelayVPN by masterking32 and its Rust port mhrv-rs by therealaleph (MIT licence).',
  );
}

final relayStringsProvider = Provider<RelayStrings>((ref) => RelayStrings(ref.watch(localePreferencesProvider)));
