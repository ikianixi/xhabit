# Google OAuth Verification Guide (برای عمومی کردن لاگین گوگل)

برای اینکه در **Google Cloud Console** اپلیکیشن از حالت `Testing` به حالت عمومی (**Published / In Production**) تغییر کند و **هر کاربری بدون پیام هشدار گوگل** با اکانت جیمیل خود وارد شود، مراحل زیر را انجام دهید:

---

## ۱. انتشار فایل Privacy Policy (فایل آماده شده است)
فایل‌های `PRIVACY.md` و `docs/privacy.html` در همین مخزن قرار دارند. وقتی کد را روی گیتهاب پابلیک (`iKianix/xhabit`) منتشر کردید، یکی از این دو آدرس را برای گوگل بگذارید:
- **بهترین گزینه (توصیه‌شده):** در تنظیمات مخزن گیتهاب بروید **Settings → Pages**، شاخه `main` و پوشه `/docs` را انتخاب و Save کنید. آن‌وقت آدرس HTTPS تمیز شما می‌شود:
  `https://ikianix.github.io/xhabit/privacy.html`
- **یا لینک مستقیم گیتهاب:**
  `https://github.com/iKianix/xhabit/blob/main/PRIVACY.md`

---

## ۲. تکمیل بخش **Branding / OAuth Consent Screen** در Google Cloud Console
- **App name:** `XHabit`
- **Application home page:** `https://github.com/iKianix/xhabit`
- **Application privacy policy link:** `https://ikianix.github.io/xhabit/privacy.html`
- **Authorized domains:** `github.io` و `github.com`

---

## ۳. دکمه **Publish App** و توضیح Scopeها برای بازبین گوگل
در بخش **Audience** دکمه **Publish App** را بزنید و اگر برای Scopeهای زیر توضیح خواست (`Verification Center → Prepare for Verification`)، این متن‌های آماده انگلیسی را دقیق کپی-پیست کنید:

- **Scope: `.../auth/drive.appdata`**
  > XHabit is an offline-first habit tracker without a proprietary backend server. It uses `drive.appdata` strictly to store and merge a single private JSON backup file (`xhabit_cloud_sync.json`) in the user's hidden application-specific Drive folder so users can restore habits, completions, and notes across devices. It never accesses personal Drive files.

- **Scope: `.../auth/calendar.events`** *(فقط اگر سینک تقویم عمومی را هم تایید می‌کنید)*
  > When explicitly enabled by the user via a toggle in Settings, XHabit creates, updates, and removes recurring calendar events tagged privately for XHabit (`xhabitApp=true`) corresponding to the user's active habit reminders. It never reads or shares the user's personal calendar events.

> **نکته:** اگر گوگل یک ویدئوی کوتاه (حدود ۳۰ ثانیه) خواست، کافی است با گوشی از باز کردن **Settings → Google Account & Calendar**، زدن دکمه **Sign in with Google** و نمایش کامل صفحه تایید گوگل فیلم بگیرید و لینک Unlisted یوتیوب را بدهید (اگر فعلاً فقط `drive.appdata` را بگذارید تایید بسیار سریع‌تر و ساده‌تر انجام می‌شود).
