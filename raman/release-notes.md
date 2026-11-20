**Raman VPN (رامان VPN) 1.4** for Android — open source, licensed under the Hiddify Extended GPL v3 (see LICENSE.md). Non-commercial.

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
- 🛡️ Shield unchanged: all its settings work as before (connection protocol, beast mode, CDN and Conduit options stay "coming soon")

### Raman VPN
- Two tabs: **Raman** (your profiles and configs) and **Shield** (one-tap connect through the Psiphon network, no server needed)
- Shield: exit-country picker, use as extra security or unblocker for Raman profiles, Shield settings (own split tunneling, upstream proxy, network sharing, disable timeouts, sound/vibration, stealth notifications, open a website after connecting, language, disguise icon, always-on VPN)
- Disguise icon: show the app as Calculator, Weather, Notes or Clock
- Smart DNS, network checker, Iran defaults

The core library is the official [hiddify-core](https://github.com/hiddify/hiddify-core) 5.9.15 release, same license. Raman VPN is based on [Hiddify](https://github.com/hiddify/hiddify-app); all credit for the app and its core goes to the Hiddify team.

Install `RamanVPN-Android-universal.apk` if you are not sure which one fits your phone. An APK signed with a different key than the one you have installed can't update over it: uninstall the old version first in that case.
