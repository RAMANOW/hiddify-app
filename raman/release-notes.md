**Raman VPN (رامان VPN) 1.5** for Android — open source, licensed under the Hiddify Extended GPL v3 (see LICENSE.md). Non-commercial.

### تازه‌های ۱.۵ (ظاهر نو و تنظیمات ضدفیلتر برای ایران)
- 🎨 ظاهر تازه با رنگ آبی لوگوی رامان در حالت روشن و تیره؛ کارت‌های گرد و تمیزتر و فاصله‌گذاری بهتر
- 🔤 فونت فارسی **وزیرمتن** همراه برنامه (مجوز آزاد OFL) و چیدمان کامل راست‌به‌چپ
- 📊 در صفحه‌ی اصلی، هنگام اتصال: مدت اتصال، سرعت دانلود و آپلود، پینگ، و نام و پرچم سرور فعلی
- 🛡️ دکمه‌ی اتصال شیلد نو: حلقه‌ی چرخان هنگام اتصال و درخشش سبز پس از وصل شدن
- ↔️ جابه‌جایی نرم بین تب‌های رامان و شیلد
- 🗂️ تنظیمات شیلد در گروه‌های جدا (کارت‌ها) مرتب شده؛ گزینه‌های غیرفعال با دلیلشان باقی مانده‌اند
- 🇮🇷 **حالت ایران** در «ابزارهای رامان»: سایت‌های داخلی مستقیم، انتخاب خودکار سریع‌ترین سرور با جایگزینی هنگام خطا، آزمایش سرورها هر ۵ دقیقه، فقط IPv4، و تلاش دوباره برای اتصال ناموفق
- ✂️ **یافتن بهترین ترفند TLS**: روی همین شبکه، بدون ترفند، چند حالت فرگمنت و حروف درهم SNI را امتحان می‌کند و بهترین را نگه می‌دارد (چون در ۱۴۰۵ فرگمنت روی بعضی شبکه‌ها کمک می‌کند و روی بعضی دیگر مسدود می‌شود)
- ☁️ شیلد: پیشنهاد «همه‌ی CDNها به‌جز Cloudflare» در انتخاب شبکه‌های CDN (Cloudflare از مهر ۱۴۰۵ در ایران به‌شدت کند شده است)
- ⚙️ تغییر پیش‌فرض‌ها: پروکسی پیش‌فرض «کمترین تأخیر» به‌جای «پخش بین همه»، و فاصله‌ی آزمایش سرورها ۵ دقیقه به‌جای ۱۰. تنظیماتی که خودتان عوض کرده‌اید دست نمی‌خورد
- 🔁 اگر شروع اتصال به دلیلی گذرا ناموفق شود (مثلاً هسته هنوز آماده نیست)، دو بار دیگر بی‌صدا امتحان می‌شود

### New in 1.5 (new look, Iran anti-filtering settings)
- 🎨 A new look in the Raman logo's blue, light and dark; cleaner rounded cards and spacing
- 🔤 Bundled Persian font **Vazirmatn** (SIL OFL) and full right-to-left layout
- 📊 Home shows, while connected: time connected, download and upload speed, ping, and the server in use with its flag
- 🛡️ A new Shield connect button: a turning ring while connecting, a green glow once connected
- ↔️ Smooth switching between the Raman and Shield tabs
- 🗂️ Shield settings grouped in cards; disabled options keep their reasons
- 🇮🇷 **Iran mode** in Raman tools: domestic sites direct, the fastest server picked automatically and replaced on failure, servers tested every 5 minutes, IPv4 only, and a failed start retried
- ✂️ **Find the best TLS trick**: tries no trick, several fragment settings and mixed-case SNI on the network in use and keeps the best (in 2026 fragment helps on some Iranian networks and is dropped on others)
- ☁️ Shield: a "all CDNs but Cloudflare" suggestion in the CDN networks picker (Cloudflare from Iran is heavily throttled since October 2026)
- ⚙️ Changed defaults: the default proxy is "lowest delay" instead of "balance", and servers are tested every 5 minutes instead of 10. Settings you changed yourself stay as they are
- 🔁 A start that fails for a passing reason (the core not ready yet) is quietly tried twice more

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
