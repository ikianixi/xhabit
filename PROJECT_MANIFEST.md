---
name: "XHabit"
version: "1.2.0"
latest_file: "/root/XHabit-latest.zip"
size: "2.86 MB"
description: "XHabit - Clean-room bilingual (Persian/English) Flutter habit tracker with dual Gregorian and Jalali calendars, 2 responsive Android home screen widgets (Adaptive 2x1..4x4 & Daily List 2x2..4x6), native AudioTrack WebAudio DSP chimes, 8-tier streak medals, rich media notes, persistent release signing, and local-first privacy."
install_command: "wget -O {filename} {download_url} && unzip -o {filename} -d /opt/{slug} && cd /opt/{slug} && flutter pub get && flutter gen-l10n && flutter build apk --release"
changelog:
  - "v1.2.0: Persistent PKCS12 release keystore signing via GitHub Secrets + monotonic CI build numbers for seamless in-place updates; clean white-check launcher icon & About logo; native Android AudioTrack static PCM chime engine; adaptive widget ratio classification (strictly no KPI footer up to 4x2, 3-col footer from 4x3, clickable checklist sub-steps at 4x4), full-bleed responsive calendars with clean breathing margins, background isolate widget theme persistence fix, and scoped preview confetti celebrations."
  - "v1.1.0: Full UI/UX parity update with Grid/List layouts, mute toggle, 4 tactile sound styles, 8-tier opt-in streak medals (1-365d), rich 14D/30D/90D habit analytics, full-screen tinted note editor, voice/photo sheets, 4-digit PIN lock overlay, safe category/archive management, and upgraded 2-widget Kotlin Android system."
  - "v1.0.0: Initial Phase 1 clean-room Flutter implementation with dual calendar, bilingual ARB localization, SQLite sync-ready schema, and GitHub Actions APK CI."
---

<!-- PROJECT_MANIFEST: NAME="XHabit" VERSION="1.2.0" LATEST_FILE="/root/XHabit-latest.zip" SIZE="~2.86 MB" -->

# XHabit — Project Manifest

## Metadata
- **Project Name:** XHabit
- **Version:** 1.2.0
- **Latest Archive on Server:** `/root/XHabit-latest.zip`
- **Release Date:** 2026-11-25

## Description
Clean-room bilingual (`fa`/`en`) habit tracker built with Flutter, Riverpod, SQLite (`sqflite`), `shamsi_date` dual calendar engine, responsive Android widgets (`AdaptiveHabitWidgetProvider` & `DailyListWidgetProvider`), rich notes (text, image, voice), biometric/PIN app lock, and full JSON backup/restore.

## Changelog
- **v1.2.0:**
  - Persistent PKCS12 release signing + monotonic `versionCode` for in-place APK upgrades without uninstalling.
  - Clean white-checkmark launcher & About logo, strict adaptive widget row ratios & breathing room, clickable `4x4` checklist sub-steps, and persistent Light/Dark widget theme across background clicks.
- **v1.1.0:**
  - Full UI parity across Home, Timeline, Habit Details, Add/Edit Habit, and Settings, plus redesigned Kotlin widgets.
- **v1.0.0:**
  - Initial implementation and GitHub Actions APK workflow.
