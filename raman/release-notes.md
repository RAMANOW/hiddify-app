**Raman VPN (رامان VPN) 1.9.0** for Android — open source, licensed under the Hiddify Extended GPL v3 (see LICENSE.md). Non-commercial. The Google Relay uses mhrv-rs (therealaleph) / MasterHttpRelayVPN (masterking32), MIT. The shutdown DNS tunnel uses Soar (Lantern team, Apache-2.0), CottenDNS (TaJirax, MIT; from StormDNS by NullRoute1970 and MasterDnsVPN by Amin Mahmoudi), dnstt (David Fifield, public domain / CC0), Slipstream (EndPositive, Apache-2.0) and MasterDnsVPN (Amin Mahmoudi, MIT).

### ظاهر تازه (۱.۹)
- **صفحهٔ اصلی**: یک دکمهٔ گرد و بزرگِ روشن/خاموش وسط صفحه؛ رنگ و کلمهٔ کوتاهِ وضعیت (قطع / در حال اتصال / متصل)، زمان‌سنجِ اتصال، سرعت دانلود و آپلود و پینگ زیرش، و کارتِ «کانفیگ انتخاب‌شده» که با یک ضربه فهرست کانفیگ‌ها رو باز می‌کنه. حلقهٔ دورِ دکمه فقط موقع اتصال می‌چرخه.
- **فهرست سرورها**: جستجو، ستاره برای علاقه‌مندی‌ها، بخش «اخیر» بالای فهرست، ردیف‌های گرد.
- **تنظیمات** در سه گروهِ «رامان»، «اتصال» و «برنامه»؛ صفحهٔ افزودن با دو بخشِ «افزودن کانفیگ» و «ابزارهای رامان».
- یک رنگِ برند (آبیِ رامان) در تم روشن و تیره، فونت وزیرمتن برای فارسی و کردی. کدِ اتصال، زبانه‌ها و همهٔ ابزارها مثل قبل.

### ڕووکاری نوێ (١.٩)
- دوگمەیەکی گەورەی خڕ بۆ پەیوەندی، دۆخ بە ڕەنگ و وشەیەکی کورت، کاتژمێری پەیوەندی، خێرایی و پینگ؛ گەڕان و دڵخوازەکان لە لیستی ڕاژەکارەکان؛ ڕێکخستنەکان لە سێ گرووپدا؛ فۆنتی وەزیرمەتن.

### New look (1.9)
- Home: one large round connect button, a short coloured state word (Disconnected / Connecting / Connected), a connection timer, live download / upload speed and ping, and a "Selected config" card that opens the config list. Only the ring round the button animates, and only while connecting.
- Server list: search, favourites (star), recently used at the top, rounded rows.
- Settings grouped into Raman / Connection / App; the add sheet has "Add a config" and "Raman tools" sections.
- One brand palette (Raman blue) in light and dark themes; Vazirmatn font (SIL OFL 1.1) for Persian and Kurdish. Connection code, tabs and every tool are unchanged.

### تازه‌های ۱.۹ (کانفیگ‌یابِ هوشمندتر، IP تمیز، حافظهٔ شبکه، رفتن به DNS قطعی)
- **کانفیگ‌یاب** حالا اول REALITY، بعد XHTTP، بعد بقیهٔ TLS رو بالا می‌ذاره (هستهٔ رامان XHTTP رو پشتیبانی می‌کنه؛ XHTTP روی h3 مثل hy2/tuic کنار گذاشته می‌شه).
- **کانال‌های کانفیگِ قطعی**: شش کانال عمومی که در قطعیِ اسفند ۱۴۰۴ تا خرداد ۱۴۰۵ کانفیگ DNS و کانفیگِ مخصوصِ نت ملی گذاشتن، اول خونده می‌شن (هر کدوم قابلِ خاموش کردن). لینک‌های DNS (حالا stormdns:// هم) به «DNS قطعی» می‌رن و بقیه به پروفایل «کانفیگ‌یاب».
- وقتی «DNS قطعی» روشنه، کانفیگ‌یاب فهرست‌ها رو **از پشتِ تونل DNS** می‌گیره (کم‌حجم: هر کانال یک صفحه + دو فایل کوچک) و می‌نویسه «از پشت تونل DNS، کُند است».
- **اسکنِ IP تمیز** برای کانفیگ‌های پشتِ CDN (دکمه در صفحهٔ کانفیگ‌یاب): IPهای Fastly، Gcore، Akamai، CloudFront و Bunny رو از فهرستِ رسمیِ خودِ شرکت‌ها با SNIِ کانفیگ امتحان می‌کنه و یک **کپی** با بهترین IP در پروفایل «IP تمیز» می‌سازه. کلودفلر عمداً اسکن نمی‌شه. کانفیگِ اصلی دست نمی‌خوره.
- **حافظهٔ شبکه** (ابزارهای رامان ← ایران): یادش می‌مونه روی هر وای‌فای / اپراتور کدوم پروفایل وصل شد و وقتی شبکه عوض شد پیشنهاد می‌ده: «این شبکه قبلاً با X وصل شد». خودش چیزی رو عوض نمی‌کنه. اسمِ وای‌فای بدونِ دسترسیِ موقعیت خونده نمی‌شه (رامان این دسترسی رو نمی‌خواد).
- **رفتن به DNS قطعی وقتی فقط نت ملی هست** (زبانهٔ DNS قطعی، **پیش‌فرض خاموش**): اگه روشنش کنی و حدود ۴۵ ثانیه اینترنتِ جهانی از راهِ VPN نرسه ولی سایت‌های داخلی باز بشن، یک بار با کانفیگِ انتخاب‌شدهٔ همون زبانه به DNS قطعی می‌ره. به کدِ اتصال دست نزده.

### نوێیەکانی ١.٩
- کانفیگ‌یاب: یەکەم REALITY، دواتر XHTTP، دواتر TLSی تر؛ کەناڵەکانی کانفیگی بڕان؛ لە پشت تونێلی DNS دەخوێنێتەوە کاتێک DNSی بڕان کارایە.
- پشکنینی IPی پاک بۆ کانفیگی CDN (بێ Cloudflare)، کۆپییەک لە پرۆفایلی «IP تمیز».
- بیرگەی تۆڕ: پێشنیاری ئەو پرۆفایلەی لەسەر ئەم تۆڕە کاری کرد.
- چوونی خۆکار بۆ DNSی بڕان کاتێک تەنها نێتی نیشتمانی هەیە (بە شێوەی بنەڕەت کوژاوەیە).

### New in 1.9.0
- **Config finder** ranks REALITY first, then XHTTP (the bundled core supports it; XHTTP over h3 is skipped like hy2/tuic), then other TLS.
- **Shutdown-config channels**: six public channels that posted DNS-tunnel and national-internet configs in the Feb–May 2026 shutdown are read first (each can be turned off). DNS links (now also stormdns://) go to the Shutdown DNS tab, v2ray links to the «کانفیگ‌یاب» profile.
- While a Shutdown DNS engine runs, the finder reads through it (only those channels, one page each, and two small files) and says it is slow.
- **Clean-IP scanner** for CDN configs: edge IPs of Fastly, Gcore, Akamai, CloudFront and Bunny from the providers' own lists, tested with the config's SNI; writes a copy with the best IP into a «IP تمیز» profile. Cloudflare is never scanned; originals are untouched.
- **Per-network memory**: suggests the profile that worked on this Wi‑Fi / operator before (never switches by itself).
- **Opt-in fallback** (off by default) to Shutdown DNS when only the national internet works. The connection code is unchanged.

### تازه‌های ۱.۸.۳ (کانفیگ‌یاب)
- دکمهٔ تازهٔ **کانفیگ‌یاب** در ردیف دوم صفحهٔ افزودن پروفایل (کنار «کانفیگ DNS»، «کانفیگ رله» و «پروکسی تلگرام»).
- کانفیگ‌های رایگانِ عمومی رو موقعِ زدنِ دکمه از چند فهرستِ گیت‌هاب و صفحهٔ عمومیِ چند کانال تلگرام می‌گیره (هیچ فهرستی توی برنامه نیست). منبعِ خودت رو هم می‌تونی اضافه کنی (لینک خام سابسکریپشن یا t.me/… یا @کانال) و منبع‌های آماده رو خاموش کنی.
- vless / vmess / trojan / ss رو از همین گوشی و همین اینترنت امتحان می‌کنه (اتصال TCP و دست‌دادن TLS، ۱۶ تا هم‌زمان، حداکثر ۳۰۰ کانفیگ) و بهترین‌ها (پیش‌فرض ۲۰) رو در یک پروفایل به اسم **«کانفیگ‌یاب»** می‌ذاره که هر بار همون به‌روز می‌شه. با «استفاده از این پروفایل» انتخابش کن؛ تست تأخیرِ خودِ برنامه بهترین رو برمی‌داره.
- لینک‌های DNS (soar / cotten / dnstt / slipstream / masterdns) که توی منبع‌ها باشن به زبانهٔ «DNS قطعی» می‌رن.
- اتصالِ روشن دست نمی‌خوره. به‌روزرسانی خودکار (هر ۶ / ۱۲ / ۲۴ ساعت) اختیاریه و پیش‌فرض خاموشه.
- ⚠️ کانفیگ‌های رایگانِ عمومی ممکنه کند باشن یا ترافیک رو ثبت کنن؛ برای حساب‌های حساس ازشون استفاده نکنین.

### نوێیەکانی ١.٨.٣
- دوگمەی **کانفیگ‌یاب**: کانفیگە بێبەرامبەرە گشتییەکان لە گیتهەب و کەناڵەکانی تێلیگرام وەردەگرێت، لەم مۆبایلەوە تاقییان دەکاتەوە و باشترینەکان دەخاتە پرۆفایلی «کانفیگ‌یاب». ئاگاداربە: لەوانەیە خاو بن یان تۆمار بکرێن.

### New in 1.8.3 (config finder)
- A **Config finder** («کانفیگ‌یاب») button in the add sheet's second row. It reads public free-config lists (a few GitHub raw files and Telegram channel previews, fetched when you tap; no list ships in the app; add or turn off sources), tests vless/vmess/trojan/ss from this phone (TCP connect + TLS handshake, 16 at a time, up to 300) and keeps the best ones (default 20) in one profile named «کانفیگ‌یاب», updated in place on each run. DNS-tunnel links found go to the Shutdown DNS tab. The running connection is not touched; optional auto-refresh (off by default) runs only while the app is open.
- ⚠️ Public free configs may be slow or logged; do not use them for sensitive accounts.

### تازه‌های ۱.۸.۲ (موتورهای تازهٔ DNS قطعی)
- سه موتور متن‌باز تازه در زبانهٔ **DNS قطعی**، هر کدوم روی پورت محلی خودش:
  - **dnstt**: لینک dnstt:// ، لینک dnst:// ، چسباندن دستور dnstt-client، یا فرم دستی (دامنه + کلید عمومی + ریزالور DoH/DoT/IP اختیاری). به یه سرور dnstt در حالت SOCKS نیاز داره.
  - **Slipstream**: لینک slipstream:// یا dnst:// یا فرم دستی. **سرور عمومی نداره؛ سرور خودت لازمه.**
  - **MasterDnsVPN**: لینک‌های masterdns:// کانال @whitedns حالا وارد می‌شن.
- همهٔ این لینک‌ها از دکمهٔ «کانفیگ DNS» صفحهٔ افزودن، کلیپ‌بورد، QR و فایل هم وارد می‌شن (بدون تکرار).
- فهرست «موتورها و سرور» نشون می‌ده هر موتور چی لازم داره.
- soar:// و cottendns:// مثل قبل کار می‌کنن؛ بقیهٔ برنامه همون ۱.۸.۱ است.

### نوێیەکانی ١.٨.٢
- سێ بزوێنەری نوێ لە **DNSی بڕان**دا: dnstt، Slipstream (سێرڤەری خۆت پێویستە) و MasterDnsVPN (لینکەکانی masterdns://).

### New in 1.8.2 (more Shutdown DNS engines)
- Three more open-source engines in the **Shutdown DNS** tab, each a local SOCKS5 on its own port: **dnstt** (dnstt:// / dnst:// links, pasted dnstt-client commands, or a by-hand form: domain + public key + optional DoH/DoT/IP resolver; needs a dnstt server in SOCKS mode), **Slipstream** (slipstream:// / dnst:// or the form; **no public servers, needs your own**) and **MasterDnsVPN** (the channel's masterdns:// links now import).
- The add sheet's «DNS config» dialog, clipboard, QR and file imports take them too (deduplicated). An "Engines and servers" list says what each engine needs.
- soar:// and cottendns:// unchanged; everything else is as in 1.8.1.


### تازه‌های ۱.۸ (DNS قطعی)
- 📡 زبانه‌ی تازه‌ی **DNS قطعی** در ابزارهای رامان، برای وقتی که اینترنت قطع می‌شه و فقط DNS جواب می‌ده: ترافیک توی درخواست‌های DNS از راه DNS اپراتور یا DNSهای داخلی رد می‌شه.
- دو موتور متن‌باز: **Soar** (لینک‌های soar://) و **CottenDNS** (لینک‌های cottendns://).
- دکمه‌ی **گرفتن کانفیگ‌ها** از صفحه‌ی عمومی کانال @whitedns (و به‌روزرسانی خودکار با باز کردن زبانه)، چسباندن از کلیپ‌بورد و افزودن دستی. کانفیگ‌ها روی گوشی می‌مونن و موقع قطعی هم کار می‌کنن؛ **تا اینترنت وصله بگیرینشون.**
- دکمه‌ی **تست** برای هر کانفیگ (یه اتصال کوتاه واقعی با زمانش).
- DNSها: اول DNS خود گوشی (اپراتور)، بعد DNSهای کانفیگ و هر DNSی که خودتون اضافه کنین.
- اتصال از همون VPN معمولی برنامه. تا وقتی روشنه FakeIP روشن و QUIC بسته‌ست و بعد برمی‌گرده.
- محدودیت‌ها: **خیلی کُنده**؛ برای پیام متنی تلگرام و پیام‌رسانی سبک. فقط TCP؛ تماس صوتی و تصویری کار نمی‌کنه.
- بقیه‌ی برنامه همون ۱.۷ است.

### نوێیەکانی ١.٨
- 📡 **DNSی بڕان**: تونێلی DNS بۆ کاتی بڕانی ئینتەرنێت (Soar و CottenDNS)، زۆر خاوە، تەنها بۆ نامەی دەقی.

### New in 1.8 (Shutdown DNS)
- 📡 New **Shutdown DNS** (DNS قطعی) tab in Raman tools: a last-resort tunnel inside DNS queries through your operator's or domestic resolvers, for internet shutdowns.
- Two open-source engines: **Soar** v0.2.4 (soar:// links) and **CottenDNS** (cottendns:// links), run on the phone as a local SOCKS5 server that the normal VPN uses.
- **Get configs** from the public web preview of the @whitedns channel (also refreshed when the tab opens), paste from the clipboard, or add by hand. Configs stay on the phone for offline use; get them while the internet is up.
- **Test** per config (a short real connection, with its time). Resolvers: the phone's own DNS first, then the config's, plus your own list.
- While on, FakeIP is on and QUIC is blocked; both come back when it stops. Very slow; TCP only (no voice/video calls).
- Everything else is unchanged from 1.7.


### تازه‌های ۱.۷ (رله گوگل)
- ☁️ زبانه‌ی تازه‌ی **رله گوگل** در ابزارهای رامان: ترافیک وب از راه Google Apps Script خودتان می‌رود و اینترنت‌دهنده فقط اتصال به www.google.com را می‌بیند. **به VPS نیاز ندارد**؛ فقط یک حساب گوگل.
- وارد کردن یک یا چند Deployment ID و AUTH_KEY (یا ساخت کلید تصادفی)، IP گوگل و SNI دلخواه با دکمه‌ی آزمایش.
- دکمه‌ی **کپی Code.gs** (با AUTH_KEY شما) و مراحل کوتاه ساخت Web app.
- **گواهی امنیتی مخصوص همین گوشی** (روی گوشی ساخته می‌شود) برای HTTPS در مرورگرها، با ذخیره در Downloads و راهنمای نصب.
- اتصال از همان دکمه و VPN معمولی برنامه انجام می‌شود. تا وقتی رله روشن است FakeIP روشن و QUIC بسته است و با خاموش کردن رله برمی‌گردد.
- محدودیت‌ها: فقط وب (HTTP/HTTPS)؛ برنامه‌هایی که به گواهی اعتماد نمی‌کنند و تلگرام از رله عبور نمی‌کنند؛ حدود ۲۰٬۰۰۰ درخواست در روز برای هر حساب گوگل.
- بقیه‌ی برنامه (زبانه‌های رامان و شیلد، اتصال، ضد نشتی) همان ۱.۶ است.

### نوێیەکانی ١.٧
- ☁️ **ڕیلەی گووگڵ**: هاتوچۆی وێب لە ڕێی Google Apps Scriptی خۆتەوە، بێ VPS.

### New in 1.7 (Google Relay)
- ☁️ New **Google Relay** tab in Raman tools: web traffic goes through your own Google Apps Script deployment with domain fronting; your ISP sees www.google.com. **No VPS needed.**
- One or more Deployment IDs, AUTH_KEY (or a random one), optional Google IP / front SNI with a test; copy Code.gs with your key filled in, short deploy steps.
- A **per-install CA** made on the phone for HTTPS in browsers, saved to Downloads with install steps.
- Connects through the app's normal VPN. While the relay is on, FakeIP is on and QUIC is blocked; both come back when it stops.
- Limits: web only (HTTP/HTTPS); apps that do not trust user CAs and Telegram do not go through the relay; about 20,000 calls a day per Google account.
- Everything else (Raman and Shield tabs, connecting, anti-leak) is unchanged from 1.6.


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
