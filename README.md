# XHabit

Clean-room, open-source, bilingual (**Persian / English**) habit tracker built with Flutter, featuring dual **Jalali (Shamsi) & Gregorian** calendars, **Day Modes**, unified **To Do List**, **2 responsive Android Home Screen Widgets**, automatic **Obsidian Vault** Markdown mirroring, automatic **Google Account (Drive & Calendar)** sync, and an **in-app GitHub Release updater**.

[![License: MIT](https://img.shields.io/badge/License-MIT-84cc16.svg)](LICENSE)
[![Platform: Android](https://img.shields.io/badge/Platform-Android%20(API%2024%2B)-informational.svg)]()

---

## Key Features

### Habit Tracking & Scheduling
- **Build & Quit Habits:** Track **Boolean** checkoffs, **Count** goals with custom units, **Checklist** sub-steps with weighted partial progress, and **Quit** streaks (automatic slip-free day tracking).
- **Flexible Schedules:** Daily, specific weekdays, custom N-day intervals, or custom target days per week.
- **Resilient Streaks:** Configurable **Day Reset Cutoff** (for late nights), **Habit Pause** windows, and **Monthly Streak Grace Days** so real-life breaks don't erase long-term momentum.
- **Rich Journal Notes:** Attach text, camera/gallery photos, and voice audio recordings to any habit and date, with in-app playback.

### Day Modes & Calendar Scheduler
- **Isolated Day Modes:** Switch between *All Modes*, *Normal*, *Work Day*, *Day Off*, *Travel*, or create custom modes with full color & 84-icon customization.
- **Full-Page Manager & Calendar Brush:** Access Day Modes directly from Home to switch modes, assign habits per mode, set weekly auto-schedules, or paint specific dates on the calendar.

### To Do List
- **Quick-Access One-Off Tasks:** Unified **To Do List** launched straight from Home with live progress bar, optional task notes, inline text/note editing, and confirmed one-tap **Clear**.

### Dual Calendar, Themes & Localization
- **Persian (Jalali / Shamsi) & Gregorian:** Seamless switching across calendars, home rings, analytics, widgets, and localized digits.
- **Themes & Sounds:** OLED Dark & Crisp Light themes, 3 font scale presets, and a low-latency native Android `AudioTrack` PCM sound engine (`Pop`, `Drop`, `Wood`, `Minimal`) + confetti celebrations.

### Android Home Screen Widgets (`home_widget`)
1. **Adaptive Single-Habit Widget (`2x1` – `4x4`):** Responsive layout scaling cleanly from compact toggles to full `4x4` metric footers and clickable checklist sub-steps.
2. **Daily Tasks List Widget (`2x2` – `4x6`):** Scrollable today list with direct widget checkoffs, expandable sub-steps, and persistent Light/Dark widget theme.

### Automatic Sync Integrations (Zero Backend Servers)
- **Obsidian Sync (`XHabit/` Folder Isolation):** Pick your Obsidian Vault once, toggle **Automatic Sync**, and XHabit mirrors your entire database (`XHabit Home.md`, `Daily/<date>.md`, `Habits/<name>.md`, `Categories/`, `Day Modes.md`, `To Do List.md`) as interlinked `[[wikilink]]` Markdown pages in background — never touching personal notes outside `XHabit/`, and cleaning only `XHabit/` if you erase data.
- **Google Account, Drive & Calendar Sync:** Sign in directly with your Google account to automatically restore/merge existing data (`drive.appdata` private app folder) across devices and keep active habit routines synced in the background with **Google Calendar**.
- **In-App GitHub Updater:** Check **Settings → Check for Updates** to fetch the latest release from GitHub Releases, stream-download the APK inside the app, and launch Android's package installer.
- **Security & Backups:** Biometric + 4-digit PIN App Lock (`local_auth` + `flutter_secure_storage`), JSON backup export/import, and scheduled auto-backups with retention cleanup.

---

## Privacy & Open-Source Security
XHabit is **local-first** with zero tracking, zero ads, and no developer-hosted servers. See [PRIVACY.md](PRIVACY.md) (or [docs/privacy.html](docs/privacy.html)) for full details on local storage, Obsidian folder scope, and Google API Limited Use compliance.

No signing keystores or OAuth client secrets are stored in this repository. Official CI builds sign APKs using encrypted GitHub Secrets matching our release certificate fingerprint.

---

## Project Structure

```text
lib/
├── app/                   # App theme, localization setup, root router
├── core/
│   ├── calendar/          # Jalali & Gregorian calendar math + date keys
│   ├── icons/             # Categorized Material icon catalog
│   ├── services/          # Notifications, AudioTrack sounds, storage, widgets, GitHub updater
│   ├── sync/              # Obsidian Markdown sync worker, Google Drive/Calendar OAuth sync, ports
│   └── widgets/           # Reusable OLED/Light UI components & pickers
├── data/
│   ├── db/                # SQLite schema (sync-ready tombstones & LWW merge)
│   └── models/            # Immutable models & AppSettings
├── domain/                # Habit engine (streaks, grace days, pauses, day modes, smart reminders)
├── features/              # Home, Timeline, Details, To Do List, Day Modes, Add/Edit, Settings, Lock
├── l10n/                  # app_en.arb & app_fa.arb localizations
└── providers/             # Riverpod async state + automatic background sync triggers
android/                   # Kotlin MainActivity (SAF, AudioTrack PCM, FileProvider APK installer, Widgets)
```

---

## Building from Source

### Prerequisites
- Flutter SDK (`>= 3.38` / Dart `^3.10.0`)
- Android SDK (API 24+ min / API 37 compile) & JDK 21

### Commands
```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter build apk --release
```

### Customizing Google Sign-In & Updater for Forks
If you fork this repository for your own release:
1. Create an Android OAuth Client ID + Web Client ID in Google Cloud Console matching your `applicationId` and signing keystore `SHA-1`.
2. Pass your own Web Client ID and GitHub repository slug at build time without editing code:
   ```bash
   flutter build apk --release \
     --dart-define=XHABIT_GOOGLE_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com \
     --dart-define=XHABIT_UPDATE_REPO=YourUser/xhabit
   ```

---

## معرفی کوتاه (فارسی)

**XHabit** یک اپلیکیشن متن‌باز، بدون تبلیغات و محلی‌محور (Local-First) برای ساخت عادت‌های پایدار و ترک عادت‌های منفی است:
- پشتیبانی کامل از **تقویم شمسی و میلادی** به همراه زبان فارسی و انگلیسی
- سیستم **مودهای روزانه (Day Modes)** با قابلیت زمان‌بندی روی تقویم و بخش **To Do List** سریع
- **۲ ویجت تعاملی اندروید** برای ثبت عادت‌ها مستقیم از صفحه اصلی گوشی
- همگام‌سازی خودکار پس‌زمینه با **ابزیدین (Obsidian)** فقط داخل پوشه `XHabit/` و اتصال مستقیم به **حساب گوگل و تقویم گوگل**
- **به‌روزرسانی درون‌برنامه‌ای مستقیم از گیت‌هاب** و قفل اثر انگشت / پین

## License
Released under the [MIT License](LICENSE).
