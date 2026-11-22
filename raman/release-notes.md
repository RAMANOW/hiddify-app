**Raman VPN (رامان VPN) 1.6** for Android — open source, licensed under the Hiddify Extended GPL v3 (see LICENSE.md). Non-commercial.

### تازه‌های ۱.۶ (ضد نشتی + زبان کردی)
- 🛡️ **حالت ضد نشتی** با یک لمس (ابزارهای رامان ← ضد نشتی؛ وقتی روشن است نشانش در صفحه‌ی اصلی دیده می‌شود): DNS راه‌دور به‌صورت DNS over HTTPS از داخل پروکسی، مسیر سخت‌گیرانه (strict route)، فقط IPv4، مسدود شدن QUIC، و پروفایل‌ها (اشتراک‌ها) دیگر نمی‌توانند DNS را به DNS محلی یا بیرون از تونل عوض کنند. خاموش کردن، تنظیمات قبلی را برمی‌گرداند. به‌طور پیش‌فرض خاموش است؛ اتصال معمولی مثل ۱.۴.۱ است.
- 🔎 **آزمایش نشتی**: IP عمومی و کشور، و سرورهای DNS که نام‌ها را می‌پرسند (bash.ws و ipleak.net)، با نتیجه‌ی سبز یا قرمز.
- 🔒 راهنمای «VPN همیشه روشن» و «مسدود کردن اتصال‌های بدون VPN» اندروید (قفل واقعی) با دکمه‌ی باز کردن تنظیمات VPN و نمایش وضعیتش.
- ⚠️ هشدار وقتی تونل‌سازی جداگانه‌ی برنامه‌ها روشن است. گزینه‌ی اختیاری FakeIP و انتخاب «سایت‌های ایرانی مستقیم» با توضیح.
- 🗣️ **زبان کردی (سورانی)** اضافه شد و زبان پیش‌فرض نصب‌های تازه است؛ فارسی و انگلیسی در تنظیمات می‌مانند. زبانی که قبلاً انتخاب کرده‌اید عوض نمی‌شود.
- ↩️ ظاهر و رفتار اتصال نسخه‌ی ۱.۵ برگردانده شد؛ این نسخه بر پایه‌ی ۱.۴.۱ است.

### نوێیەکانی ١.٦
- 🛡️ **دۆخی دژە-دزە** بە یەک دەستلێدان، **تاقیکردنەوەی دزە**، ڕێنمایی قفڵی ئەندرۆید (VPNی هەمیشە داگیرساو).
- 🗣️ **زمانی کوردی (سۆرانی)** زیاد کرا و زمانی بنەڕەتی دامەزراندنە نوێیەکانە.

### New in 1.6 (anti-leak + Kurdish)
- 🛡️ One-tap **anti-leak mode** (Raman tools → Anti-leak; a badge shows on home while on): remote DNS as DNS over HTTPS through the proxy, strict route, IPv4 only, QUIC blocked, and profiles can no longer switch the DNS to the system resolver. Off restores the previous settings. Off by default: normal connecting is as in 1.4.1.
- 🔎 **Leak test**: public IP and country, and the DNS resolvers seen (bash.ws, ipleak.net), green or red.
- 🔒 Android always-on VPN + "Block connections without VPN" guidance, a button to the VPN settings, and its status.
- 🗣️ **Kurdish (Sorani)** added and the default for new installs; Persian and English stay. A language you already picked is kept.
- ↩️ The 1.5 look and connection changes are reverted; this release is based on 1.4.1.

### تازه‌های ۱.۴.۱ (تنظیمات شیلد)
- 🛡️ گزینه‌های «به‌زودی» شیلد که هسته‌ی رسمی ۵.۹.۱۵ پشتیبانی می‌کند، حالا کار می‌کنند:
  - **پروتکل اتصال**: «خودکار» (همه‌ی پروتکل‌ها همراه با جست‌وجوی لبه‌های CDN) یا «فقط مستقیم» (بدون جست‌وجوی CDN، فقط پروتکل‌های TCP؛ برای شبکه‌های باز سریع‌تر)
  - **حالت تهاجمی (Beast)**: جست‌وجوی عمیق از همان ابتدا، بدون محدودیت زمان و با تلاش‌های هم‌زمان بیشتر
  - **شبکه‌های CDN**: انتخاب CDNهایی که شیلد از پشت آن‌ها عبور می‌کند (Cloudflare، Fastly، CloudFront، Akamai و…)
  - **IPهای لبه‌ی CDN**: IP یا بازه‌ی CIDR دلخواه (IPv4) که اول امتحان می‌شود
  - **نام‌های SNI برای CDN**: همراه با IPهای خودتان فرستاده می‌شوند
- این گزینه‌ها فقط وقتی شیلد مستقیم وصل می‌شود (بدون پروکسی بالادستی) اثر دارند.
- گزینه‌هایی که هسته‌ی رسمی ندارد (Conduit، هشدار بدافزار، اشتراک NFC، به‌روزرسانی فقط با Wi‑Fi) غیرفعال مانده‌اند و دلیلشان کنار هرکدام نوشته شده است.

### New in 1.4.1 (Shield settings)
- 🛡️ The Shield options marked "coming soon" that official core 5.9.15 supports now work:
  - **Connection protocol**: Automatic (every protocol, with the CDN edge search) or Direct only (no CDN search, TCP protocols only; faster on open networks)
  - **Beast mode**: a deep search from the start, with no time limit and more attempts at once
  - **CDN networks**: pick the CDNs Shield fronts through (Cloudflare, Fastly, CloudFront, Akamai…)
  - **CDN edge IPs**: your own IPv4 addresses or CIDR ranges, tried first
  - **CDN SNI hostnames**: sent with your own edge IPs
- These take effect when Shield connects directly (no upstream proxy).
- Options the official core lacks (Conduit, malware alerts, NFC bump, Wi‑Fi-only upgrades) stay disabled, each with its reason.

### تازه‌های ۱.۴ (بر پایه‌ی Hiddify 5.9.15)
- 🔎 جست‌وجوگر مشترک WARP و Psiphon: اگر جست‌وجوی راه عبور در زمان معمول به نتیجه نرسد، برنامه «جست‌وجوی عمیق» را پیشنهاد می‌دهد (ممکن است طول بکشد و باتری مصرف کند، پس اول می‌پرسد)
- 🌐 سایفون در حالت ضدفیلتر لبه‌های CDN را به‌عنوان اولین گام اسکن می‌کند؛ کشور گام سایفون را می‌توانید مستقیم از جزئیات پروکسی در صفحه‌ی اصلی عوض کنید
- ⚡ نگه‌داشتن سریع‌ترین‌ها (keep-top) حالا هر ساعت پروکسی‌های در حال استراحت را دوباره بررسی می‌کند و اگر سریع‌تر باشند جایگزین می‌شوند؛ دکمه‌ی «آزمایش دوباره» همه‌ی پروکسی‌ها را کامل تست می‌کند
- 🔒 پروکسی‌های ناامن (بدون TLS، Shadowsocks بدون رمز، TLS ناامن) با برچسب قرمز «ناامن» و دلیلش مشخص می‌شوند؛ نوع انتقال و امنیت هر پروکسی کنار پروتکلش نمایش داده می‌شود
- 🛠️ رفع اشکال‌های VLESS، XHTTP، AmneziaWG، WireGuard و WARP؛ پذیرش نام رمزهای Shadowsocks به سبک Xray
- 📥 دانلود اشتراک اول از طریق هسته با دست‌دهی TLS کروم؛ اگر ناموفق باشد، دلیل و راه‌حل به زبان ساده گفته می‌شود
- 📱 پایداری بیشتر در اندروید: سرویس VPN با توقف هسته درست بسته می‌شود، کاشی تنظیمات سریع و پرس‌وجوهای DNS بهتر شده‌اند
- 📝 «گزارش مشکل» می‌تواند ۱۰ دقیقه لاگ دقیق ثبت کند؛ گزارش فقط روی گوشی ذخیره می‌شود و جایی فرستاده نمی‌شود
- 🔤 پیام‌های خطای فارسی حالا راست‌به‌چپ نمایش داده می‌شوند
- 🛡️ شیلد بدون تغییر: همه‌ی تنظیمات قبلی مثل قبل کار می‌کنند

### New in 1.4 (based on Hiddify 5.9.15)
- 🔎 One shared scanner for WARP and Psiphon: when a search for a way through finds nothing in its normal time, the app offers a deep search (it can take long and use battery, so it asks first)
- 🌐 Psiphon as unblocker scans CDN edges as its first hop; change the Psiphon hop's country right from its details on the home page
- ⚡ Keep-top now looks at the resting proxies again every hour and swaps in a faster one; "Test again" on the sleeping-proxies card runs a full test
- 🔒 Insecure proxies (no TLS, Shadowsocks "none", insecure TLS) get a red "Not secure" mark with the reason; each proxy shows its transport and security next to its protocol
- 🛠️ VLESS, XHTTP, AmneziaWG, WireGuard and WARP fixes; Shadowsocks accepts Xray's cipher names
- 📥 Subscriptions download through the core first, with Chrome's TLS handshake; a failure says why and what to try
- 📱 Steadier Android service: the VPN goes down when its core stops, better quick-settings tile and DNS handling
- 📝 "Report a problem" can record 10 minutes of detailed logs first; the report stays on your device
- 🔤 Error messages in Persian read right to left
- 🛡️ Shield unchanged: all its settings work as before

### Raman VPN
- Two tabs: **Raman** (your profiles and configs) and **Shield** (one-tap connect through the Psiphon network, no server needed)
- Shield: exit-country picker, use as extra security or unblocker for Raman profiles, Shield settings (own split tunneling, upstream proxy, network sharing, disable timeouts, sound/vibration, stealth notifications, open a website after connecting, language, disguise icon, always-on VPN)
- Disguise icon: show the app as Calculator, Weather, Notes or Clock
- Smart DNS, network checker, Iran defaults

The core library is the official [hiddify-core](https://github.com/hiddify/hiddify-core) 5.9.15 release, same license. Raman VPN is based on [Hiddify](https://github.com/hiddify/hiddify-app); all credit for the app and its core goes to the Hiddify team.

Install `RamanVPN-Android-universal.apk` if you are not sure which one fits your phone. An APK signed with a different key than the one you have installed can't update over it: uninstall the old version first in that case.
