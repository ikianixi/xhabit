# Privacy Policy for XHabit

**Last Updated:** 2026-11-26  
**Application ID:** `app.xhabit.tracker`  
**Source Repository:** https://github.com/iKianix/xhabit

XHabit is a **local-first, open-source habit tracker**. We do not operate any backend servers, we do not sell user data, and the app contains zero third-party advertising or analytics trackers.

---

## 1. Data Stored Locally on Your Device
By default, all data you create in XHabit stays strictly on your device inside its local SQLite database and app storage:
- Habits, categories, checklists, day modes, schedules, and To Do List items
- Completion logs, streak pauses, and completion timestamps
- Journal notes (text, photos, and voice recordings you attach inside the app)
- App preferences, theme/calendar choices, and optional App Lock PIN (stored encrypted via `flutter_secure_storage`)

## 2. Optional Integrations You Explicitly Enable

### A. Google Account, Google Drive & Google Calendar (Optional)
If you choose to sign in with Google inside **Settings → Google Account & Calendar**, XHabit communicates **directly** from your device to Google APIs via OAuth 2.0. No XHabit-operated intermediary server ever receives your tokens or data.

XHabit requests only the minimal scopes needed:
- **`email` and `profile`:** Used solely to display your connected Google account name and email inside Settings.
- **`https://www.googleapis.com/auth/drive.appdata`:** Used solely to store and merge XHabit's backup file (`xhabit_cloud_sync.json`) inside your Google Drive's hidden, application-private `appDataFolder`. **XHabit cannot view, read, modify, or delete any of your personal files or folders in Google Drive.**
- **`https://www.googleapis.com/auth/calendar.events`:** Used only if you enable *Automatic Google Calendar Sync*. Creates, updates, and removes XHabit routine events tagged exclusively for XHabit. **XHabit does not read or share your personal calendar appointments.**

**Google API Services User Data Policy (Limited Use Disclosure):**  
XHabit's use and transfer to any other app of information received from Google APIs strictly adheres to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the **Limited Use** requirements. Google user data is used exclusively to provide backup/restore and habit-schedule synchronization inside XHabit, and is never used for advertising, profiling, or AI training.

### B. Obsidian Vault Folder Sync (Optional)
If you pick an Obsidian Vault folder via Android's Storage Access Framework (`ACTION_OPEN_DOCUMENT_TREE`), XHabit creates and maintains Markdown pages **strictly inside a single `XHabit/` subfolder** within the directory you selected. Your existing notes outside `XHabit/` are never modified or deleted. Choosing **Erase All Data** inside XHabit deletes only the `XHabit/` subfolder.

### C. In-App Update Check (GitHub Releases)
When you tap **Settings → Check for Updates**, the app queries the public GitHub Releases API (`api.github.com`) to compare the latest release tag and optionally download an APK attached to an official release. No personal habit data or device identifiers are transmitted.

## 3. Data Deletion & Control
- **Disconnect Google Account:** Settings → Google Account & Calendar → **Disconnect** (or revoke anytime at https://myaccount.google.com/permissions).
- **Delete Cloud Copy:** Settings → Google Account & Calendar → **Delete Cloud Copy** permanently deletes `xhabit_cloud_sync.json` from your Drive `appDataFolder`.
- **Erase Local Data:** Settings → **Erase All Data** deletes all local habits, logs, media notes, and XHabit's dedicated `XHabit/` Obsidian subfolder.

## 4. Contact
Questions or privacy requests can be opened at:  
https://github.com/iKianix/xhabit/issues

---

## خلاصه حریم خصوصی (فارسی)
- **ایکس‌هبیت بدون سرور مرکزی و بدون تبلیغات/ردیاب کار می‌کند.** تمام داده‌های شما به‌صورت پیش‌فرض فقط روی گوشی خودتان نگهداری می‌شوند.
- **اتصال گوگل (اختیاری):** با ورود به جیمیل، بکاپ برنامه فقط در فضای خصوصی و مخفی خود برنامه (`appDataFolder`) ذخیره می‌شود و برنامه هیچ دسترسی به فایل‌های شخصی گوگل درایو یا رویدادهای شخصی تقویم شما ندارد.
- **ابزیدین (اختیاری):** فایل‌ها فقط داخل پوشه اختصاصی `XHabit/` در مسیر انتخابی شما ساخته و به‌روز می‌شوند و هنگام پاک‌سازی کامل داده‌ها، فقط همان پوشه `XHabit/` حذف می‌شود.
