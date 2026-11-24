import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/gen/translations.g.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Raman VPN 1.9 texts for the per-network memory and the "Iran Access" DNS fallback: Persian,
/// Kurdish (Sorani), English.
class NetWatchStrings {
  const NetWatchStrings(this.locale);

  final AppLocale locale;

  String _t(String fa, String en, String ckb) => switch (locale) {
    AppLocale.fa => fa,
    AppLocale.ckb => ckb,
    _ => en,
  };

  String networkLabel(String kind, String label) => switch (kind) {
    'wifi' when label == 'Wi-Fi' => _t('وای‌فای', 'Wi‑Fi', 'وای‌فای'),
    'mobile' when label == 'Mobile' => _t('اینترنت همراه', 'Mobile data', 'ئینتەرنێتی مۆبایل'),
    _ => label,
  };

  String seenBefore(String profile, String network) => _t(
    'این شبکه ($network) قبلاً با «$profile» وصل شد',
    'This network ($network) connected with «$profile» before',
    'ئەم تۆڕە ($network) پێشتر بە «$profile» پەیوەست بوو',
  );
  String get use => _t('انتخاب', 'Use it', 'هەڵبژاردن');

  // settings (Iran tab)
  String get memoryTitle => _t('حافظهٔ شبکه', 'Per-network memory', 'بیرگەی تۆڕ');
  String get memorySubtitle => _t(
    'یادش می‌مونه روی هر وای‌فای / اپراتور با کدوم پروفایل وصل شدی و وقتی شبکه عوض شد پیشنهادش می‌ده (خودش چیزی رو عوض نمی‌کنه). اسمِ وای‌فای بدونِ دسترسیِ «موقعیت مکانی» خونده نمی‌شه و رامان این دسترسی رو نمی‌خواد؛ برای همین وای‌فای‌ها با مشخصاتِ روترشون از هم جدا می‌شن و فقط «وای‌فای» نوشته می‌شه.',
    'Remembers which profile connected on each Wi‑Fi / operator and suggests it when the network changes (it never switches by itself). Android hides the Wi‑Fi name without the location permission, which Raman does not ask for, so Wi‑Fi networks are told apart by their router and shown just as "Wi‑Fi".',
    'لەبیری دەمێنێت لەسەر هەر وای‌فای / ئۆپەراتۆرێک بە کام پرۆفایل پەیوەست بوویت و کاتێک تۆڕ گۆڕا پێشنیاری دەکات (خۆی هیچ ناگۆڕێت). ناوی وای‌فای بەبێ مۆڵەتی «شوێن» ناخوێندرێتەوە و ڕامان ئەم مۆڵەتە ناخوازێت؛ بۆیە وای‌فایەکان بە ڕاوتەرەکەیان لە یەک جیا دەکرێنەوە.',
  );
  String memoryNow(String network) => _t('شبکهٔ الان: $network', 'Network now: $network', 'تۆڕی ئێستا: $network');
  String memoryCount(int n) => _t('$n شبکه به خاطر سپرده شده', '$n networks remembered', '$n تۆڕ لەبیر کراوە');
  String get memoryClear => _t('پاک کردنِ حافظه', 'Forget all', 'سڕینەوەی بیرگە');

  // fallback (DNS tab)
  String get fallbackTitle => _t(
    'رفتنِ خودکار به «DNS قطعی» وقتی فقط نت ملی هست',
    'Switch to Shutdown DNS when only the national internet works',
    'چوونی خۆکار بۆ «DNSی بڕان» کاتێک تەنها نێتی نیشتمانی هەیە',
  );
  String get fallbackSubtitle => _t(
    'خاموش به‌طور پیش‌فرض. وقتی وصلی و حدودِ ۴۵ ثانیه هیچ چیزی از راهِ VPN به اینترنتِ جهانی نمی‌رسه، ولی سایت‌های داخلی باز می‌شن و اینترنتِ جهانی بدونِ VPN هم بسته‌ست (حالتِ «فقط دسترسی داخلی»)، یک بار با کانفیگِ انتخاب‌شدهٔ همین تب به «DNS قطعی» می‌ره. تا وقتی خودت دوباره وصل نشی، دوباره این کار رو نمی‌کنه.',
    'Off by default. When you are connected and for about 45 s nothing reaches the international internet through the VPN, while Iranian sites open and the international internet is closed without the VPN too ("Iran Access"), it switches once to Shutdown DNS with the config selected in this tab. It does not do it again until you reconnect yourself.',
    'بە شێوەی بنەڕەت کوژاوەیە. کاتێک پەیوەستیت و نزیکەی ٤٥ چرکە هیچ شتێک لە ڕێی VPN ناگاتە ئینتەرنێتی جیهانی، بەڵام ماڵپەڕە ناوخۆییەکان دەکرێنەوە، یەک جار بە کانفیگی هەڵبژێردراوی ئەم بەشە دەچێت بۆ «DNSی بڕان».',
  );
  String switching(String config) => _t(
    'اینترنتِ جهانی قطعه و فقط نتِ داخلی جواب می‌ده؛ رفتیم روی «DNS قطعی» ($config). کُنده.',
    'The international internet is cut and only Iranian sites answer; switching to Shutdown DNS ($config). It is slow.',
    'ئینتەرنێتی جیهانی بڕاوە و تەنها ماڵپەڕە ناوخۆییەکان وەڵام دەدەنەوە؛ چووین بۆ «DNSی بڕان» ($config). خاوە.',
  );
  String get noDnsConfig => _t(
    'اینترنتِ جهانی قطعه و فقط نتِ داخلی جواب می‌ده، ولی هیچ کانفیگِ DNSی ذخیره نشده.',
    'The international internet is cut and only Iranian sites answer, but no DNS config is saved.',
    'ئینتەرنێتی جیهانی بڕاوە، بەڵام هیچ کانفیگێکی DNS پاشەکەوت نەکراوە.',
  );
  String get open => _t('باز کردن', 'Open', 'کردنەوە');
  String switchFailed(String why) => _t(
    'رفتن به «DNS قطعی» نشد: $why',
    'Could not switch to Shutdown DNS: $why',
    'چوون بۆ «DNSی بڕان» سەرنەکەوت: $why',
  );
}

final netWatchStringsProvider = Provider<NetWatchStrings>(
  (ref) => NetWatchStrings(ref.watch(localePreferencesProvider)),
);
