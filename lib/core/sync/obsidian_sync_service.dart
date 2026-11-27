import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/db/app_database.dart';
import '../../data/models/habit_models.dart';
import '../../domain/habit_engine.dart';
import '../calendar/app_calendar.dart';
import 'sync_ports.dart';

/// Full interlinked Markdown vault mirror & automatic background sync worker.
///
/// Always operates strictly inside a dedicated `XHabit/` subfolder of the user's
/// chosen Obsidian Vault (via Android SAF) and/or the local fallback directory
/// `XHabit/Exports/Obsidian`, never modifying or deleting any files outside it.
class ObsidianSyncService implements ObsidianSyncPort {
  ObsidianSyncService._();

  static final ObsidianSyncService instance = ObsidianSyncService._();
  static const MethodChannel _storageChannel =
      MethodChannel('app.xhabit.tracker/storage');
  static const String dedicatedFolderName = 'XHabit';

  Timer? _debounceTimer;
  bool _isSyncing = false;
  bool _rerunRequested = false;
  bool _forceNextFullWrite = false;
  AppSettings? _pendingSettings;
  void Function(int syncedAtMs)? _onSyncedCallback;

  // Differential cache so rapid background updates only push changed pages.
  String? _cachedTargetKey;
  final Map<String, String> _cachedSignatures = <String, String>{};

  @override
  Future<bool> isConfigured() async => true;

  @override
  Future<SyncResult> syncToVault(
    ObsidianVaultConfig config,
    List<SyncChangeRecord> dirtyChanges,
  ) async {
    return exportStructuredVault(
      settings: AppSettings(
        obsidianVaultUri: config.vaultRootUri,
        obsidianSyncEnabled: config.vaultRootUri.isNotEmpty,
      ),
      vaultUri: config.vaultRootUri.isEmpty ? null : config.vaultRootUri,
      forceFullWrite: true,
    );
  }

  /// Queues a fast background sync shortly after any database update.
  /// Coalesces rapid consecutive edits and prevents overlapping writes.
  void scheduleBackgroundSync({
    required AppSettings settings,
    void Function(int syncedAtMs)? onSynced,
    bool immediate = false,
    bool forceFullWrite = false,
  }) {
    if (!settings.obsidianSyncEnabled) return;
    final uri = settings.obsidianVaultUri;
    if (uri == null || uri.isEmpty) return;

    _pendingSettings = settings;
    if (onSynced != null) _onSyncedCallback = onSynced;
    if (forceFullWrite) _forceNextFullWrite = true;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      immediate ? const Duration(milliseconds: 50) : const Duration(milliseconds: 650),
      () => _drainSyncQueue(),
    );
  }

  void cancelPendingSync() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingSettings = null;
    _rerunRequested = false;
  }

  void clearDiffCache() {
    _cachedTargetKey = null;
    _cachedSignatures.clear();
  }

  Future<void> _drainSyncQueue() async {
    final settings = _pendingSettings;
    if (settings == null ||
        !settings.obsidianSyncEnabled ||
        (settings.obsidianVaultUri ?? '').isEmpty) {
      return;
    }
    if (_isSyncing) {
      _rerunRequested = true;
      return;
    }
    _isSyncing = true;
    try {
      do {
        _rerunRequested = false;
        final current = _pendingSettings ?? settings;
        final forceFull = _forceNextFullWrite;
        _forceNextFullWrite = false;
        if (!current.obsidianSyncEnabled ||
            (current.obsidianVaultUri ?? '').isEmpty) {
          break;
        }
        final res = await exportStructuredVault(
          settings: current,
          forceFullWrite: forceFull,
        );
        if (res.success) {
          final ts = DateTime.now().millisecondsSinceEpoch;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('lastObsidianSyncMs', ts);
          } catch (_) {}
          _onSyncedCallback?.call(ts);
        }
      } while (_rerunRequested);
    } finally {
      _isSyncing = false;
    }
  }

  /// Immediate full sync entry point (used by manual "Sync Now" & Workmanager).
  Future<SyncResult> syncFullVaultNow({
    required AppSettings settings,
    bool forceFullWrite = true,
  }) async {
    final res = await exportStructuredVault(
      settings: settings,
      forceFullWrite: forceFullWrite,
    );
    if (res.success) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('lastObsidianSyncMs', res.newRevision);
      } catch (_) {}
    }
    return res;
  }

  /// Deletes ONLY the dedicated `XHabit/` folder inside the user's Obsidian Vault
  /// (and local Obsidian export mirror), never touching any user notes outside it.
  Future<bool> wipeXHabitVaultFolder({required AppSettings settings}) async {
    cancelPendingSync();
    clearDiffCache();

    var ok = true;
    final targetUri = settings.obsidianVaultUri;
    if (Platform.isAndroid && targetUri != null && targetUri.isNotEmpty) {
      try {
        final deleted = await _storageChannel.invokeMethod<bool>(
          'deleteRelativeFolder',
          {
            'treeUri': targetUri,
            'rootFolder': dedicatedFolderName,
          },
        );
        ok = deleted ?? false;
      } catch (_) {
        ok = false;
      }
    }

    try {
      final base =
          (Platform.isAndroid ? await getExternalStorageDirectory() : null) ??
              await getApplicationDocumentsDirectory();
      final obsRoot =
          Directory(p.join(base.path, 'XHabit', 'Exports', 'Obsidian'));
      if (await obsRoot.exists()) {
        await obsRoot.delete(recursive: true);
      }
    } catch (_) {}

    return ok;
  }

  /// Mirrors the entire XHabit database into interlinked Markdown files.
  Future<SyncResult> exportStructuredVault({
    required AppSettings settings,
    String? vaultUri,
    bool forceFullWrite = false,
  }) async {
    final db = AppDatabase.instance;
    final categories = await db.getCategories();
    final habits = await db.getHabits(includeArchived: true);
    final checklist = await db.getAllChecklistItems();
    final completions = await db.getAllCompletions();
    final pauses = await db.getAllPauses();
    final notes = await db.getAllNotes();
    final oneOff = await db.getOneOffTasks();

    final isFa = settings.localeCode == 'fa';
    final today =
        AppCalendar.logicalToday(DateTime.now(), settings.dayResetMinutes);
    final todayKey = AppCalendar.toDateKey(today);
    final todayJalali = AppCalendar.monthDayLabel(
      today,
      CalendarSystem.jalali,
      settings.localeCode,
    );

    final effectiveTodayMode = HabitEngine.resolveDayMode(settings, today);
    final files = <({String subDir, String fileName, String content})>[];

    // Allocate collision-free filenames so Obsidian [[links]] always match cleanly.
    final habitSlugById = <String, String>{};
    final usedHabitSlugs = <String>{};
    for (final h in habits) {
      final slug = _uniqueSlug(h.title, h.id, usedHabitSlugs);
      habitSlugById[h.id] = slug;
    }

    final catById = {for (final c in categories) c.id: c};
    final catSlugById = <String, String>{};
    final usedCatSlugs = <String>{};
    for (final c in categories) {
      final slug = _uniqueSlug(c.name, c.id, usedCatSlugs);
      catSlugById[c.id] = slug;
    }

    String modeLabel(String id) {
      if (id == 'all') return isFa ? 'همه مودها' : 'All Modes';
      for (final m in settings.dayModesList) {
        if (m.id == id) return m.name;
      }
      return switch (id) {
        'normal' => isFa ? 'نرمال' : 'Normal',
        'work' => isFa ? 'روز کاری' : 'Work Day',
        'off' => isFa ? 'تعطیل' : 'Day Off',
        'travel' => isFa ? 'سفر' : 'Travel',
        _ => id,
      };
    }

    // Collect every recorded date in the database + today so all history stays linked.
    final dateKeysSet = <String>{todayKey};
    for (final c in completions) {
      dateKeysSet.add(c.dateKey);
    }
    for (final n in notes) {
      dateKeysSet.add(n.dateKey);
    }
    for (final pz in pauses) {
      dateKeysSet.add(pz.startDateKey);
      if (pz.endDateKey != null) dateKeysSet.add(pz.endDateKey!);
    }
    for (final k in settings.dayModeByDate.keys) {
      dateKeysSet.add(k);
    }
    final allDates = dateKeysSet.toList()..sort();

    // Pre-compute stats once per habit.
    final statsByHabitId = <String, HabitStats>{};
    for (final h in habits) {
      final items = checklist.where((i) => i.habitId == h.id).toList();
      final byDate = {
        for (final c in completions.where((x) => x.habitId == h.id))
          c.dateKey: c,
      };
      statsByHabitId[h.id] = HabitEngine.computeStats(
        h,
        byDate,
        items,
        calendar: settings.calendarSystem,
        weekStart: settings.weekStartDay,
        today: today,
        pauses: pauses,
        monthlyGraceDays: settings.streakGraceDaysPerMonth,
      );
    }

    // 1. Root Hub / Dashboard: `XHabit Home.md`
    final activeHabits = habits.where((h) => !h.isArchived).toList();
    final archivedHabits = habits.where((h) => h.isArchived).toList();
    final homeBuf = StringBuffer()
      ..writeln('# XHabit')
      ..writeln()
      ..writeln(isFa
          ? '> داشبورد کامل عادت‌ها، گزارش‌های روزانه، یادداشت‌ها و لیست کارها (به‌روزرسانی خودکار)'
          : '> Complete mirror of your habits, daily logs, journal notes, and To Do List (auto-synced).')
      ..writeln()
      ..writeln('## ${isFa ? 'دسترسی سریع' : 'Quick Links'}')
      ..writeln('- **${isFa ? 'امروز' : 'Today'}:** [[Daily/$todayKey|$todayKey ($todayJalali)]] — ${modeLabel(effectiveTodayMode)}')
      ..writeln('- **[[To Do List]]** (${oneOff.where((t) => !t.isDone).length}/${oneOff.length})')
      ..writeln('- **[[Day Modes]]** (${modeLabel(settings.activeDayMode)})')
      ..writeln()
      ..writeln('## ${isFa ? 'دسته‌بندی‌ها' : 'Categories'} (${categories.length})');

    if (categories.isEmpty) {
      homeBuf.writeln('- _${isFa ? 'دسته‌بندی ثبت نشده' : 'No categories yet'}_');
    } else {
      for (final c in categories) {
        final cnt = habits.where((h) => h.categoryId == c.id).length;
        homeBuf.writeln('- [[Categories/${catSlugById[c.id]}|${c.name}]] ($cnt)');
      }
    }

    homeBuf
      ..writeln()
      ..writeln('## ${isFa ? 'عادت‌های فعال' : 'Active Habits'} (${activeHabits.length})');
    if (activeHabits.isEmpty) {
      homeBuf.writeln('- _${isFa ? 'عادتی ثبت نشده است' : 'No active habits'}_');
    } else {
      for (final h in activeHabits) {
        final st = statsByHabitId[h.id]!;
        final slug = habitSlugById[h.id]!;
        final cat = h.categoryId != null ? catById[h.categoryId!] : null;
        final catLink = cat != null
            ? ' • [[Categories/${catSlugById[cat.id]}|${cat.name}]]'
            : '';
        homeBuf.writeln(
            '- [[Habits/$slug|${h.title}]]$catLink — ${st.currentStreak}d • ${st.habitScore}%');
      }
    }

    if (archivedHabits.isNotEmpty) {
      homeBuf
        ..writeln()
        ..writeln('## ${isFa ? 'عادت‌های آرشیوشده' : 'Archived Habits'} (${archivedHabits.length})');
      for (final h in archivedHabits) {
        final slug = habitSlugById[h.id]!;
        homeBuf.writeln('- [[Habits/$slug|${h.title}]]');
      }
    }

    homeBuf
      ..writeln()
      ..writeln('## ${isFa ? 'گزارش‌های روزانه اخیر' : 'Recent Daily Logs'} (${allDates.length})');
    for (final dk in allDates.reversed.take(30)) {
      homeBuf.writeln('- [[Daily/$dk|$dk]]');
    }

    files.add((
      subDir: '',
      fileName: 'XHabit Home.md',
      content: homeBuf.toString(),
    ));

    // 2. Unified To Do List (`To Do List.md`)
    final todoBuf = StringBuffer()
      ..writeln('← [[XHabit Home]]')
      ..writeln()
      ..writeln('# To Do List')
      ..writeln();
    final openTodos = oneOff.where((t) => !t.isDone).toList();
    final doneTodos = oneOff.where((t) => t.isDone).toList();
    if (oneOff.isEmpty) {
      todoBuf.writeln('_${isFa ? 'لیست کارها خالی است.' : 'Your To Do List is empty.'}_');
    } else {
      todoBuf.writeln('## ${isFa ? 'انجام‌نشده' : 'Open'} (${openTodos.length})');
      for (final t in openTodos) {
        final noteSuffix = t.quantity.isEmpty ? '' : ' — _${t.quantity}_';
        todoBuf.writeln('- [ ] ${t.title}$noteSuffix');
      }
      if (doneTodos.isNotEmpty) {
        todoBuf
          ..writeln()
          ..writeln('## ${isFa ? 'انجام‌شده' : 'Completed'} (${doneTodos.length})');
        for (final t in doneTodos) {
          final noteSuffix = t.quantity.isEmpty ? '' : ' — _${t.quantity}_';
          todoBuf.writeln('- [x] ${t.title}$noteSuffix');
        }
      }
    }
    files.add((
      subDir: '',
      fileName: 'To Do List.md',
      content: todoBuf.toString(),
    ));

    // 3. Day Modes overview (`Day Modes.md`)
    final modesBuf = StringBuffer()
      ..writeln('← [[XHabit Home]]')
      ..writeln()
      ..writeln('# ${isFa ? 'مودهای روزانه' : 'Day Modes'}')
      ..writeln()
      ..writeln('**${isFa ? 'مود فعال فعلی:' : 'Current Active Mode:'}** ${modeLabel(settings.activeDayMode)}')
      ..writeln()
      ..writeln('## ${isFa ? 'مودها و عادت‌های متصل' : 'Modes & Linked Habits'}');

    final modeEntries = <({String id, String name})>[
      (id: 'all', name: modeLabel('all')),
      for (final m in settings.dayModesList) (id: m.id, name: m.name),
    ];
    for (final m in modeEntries) {
      modesBuf
        ..writeln()
        ..writeln('### ${m.name}');
      final matching = activeHabits
          .where((h) => m.id == 'all'
              ? h.dayModes.contains('all')
              : h.dayModes.contains(m.id))
          .toList();
      if (matching.isEmpty) {
        modesBuf.writeln('- _${isFa ? 'بدون عادت اختصاصی' : 'No habits assigned'}_');
      } else {
        for (final h in matching) {
          modesBuf.writeln('- [[Habits/${habitSlugById[h.id]}|${h.title}]]');
        }
      }
    }

    if (settings.weekdayDayModes.isNotEmpty) {
      modesBuf
        ..writeln()
        ..writeln('## ${isFa ? 'برنامه ثابت هفتگی' : 'Weekly Auto-Schedule'}');
      const wdEn = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const wdFa = ['', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنج‌شنبه', 'جمعه', 'شنبه', 'یکشنبه'];
      for (final e in settings.weekdayDayModes.entries) {
        if (e.key >= 1 && e.key <= 7) {
          final wName = isFa ? wdFa[e.key] : wdEn[e.key];
          modesBuf.writeln('- **$wName:** ${modeLabel(e.value)}');
        }
      }
    }

    if (settings.dayModeByDate.isNotEmpty) {
      modesBuf
        ..writeln()
        ..writeln('## ${isFa ? 'تاریخ‌های انتخاب‌شده روی تقویم' : 'Calendar Mode Overrides'}');
      final sortedDates = settings.dayModeByDate.keys.toList()..sort();
      for (final dk in sortedDates) {
        modesBuf.writeln(
            '- [[Daily/$dk|$dk]] → ${modeLabel(settings.dayModeByDate[dk]!)}');
      }
    }
    files.add((
      subDir: '',
      fileName: 'Day Modes.md',
      content: modesBuf.toString(),
    ));

    // 4. Category Pages (`Categories/<Name>.md`)
    for (final c in categories) {
      final catHabits = habits.where((h) => h.categoryId == c.id).toList();
      final cBuf = StringBuffer()
        ..writeln('← [[XHabit Home]]')
        ..writeln()
        ..writeln('# ${c.name}')
        ..writeln()
        ..writeln('## ${isFa ? 'عادت‌ها' : 'Habits'} (${catHabits.length})');
      if (catHabits.isEmpty) {
        cBuf.writeln('- _${isFa ? 'عادتی در این دسته نیست' : 'No habits in this category'}_');
      } else {
        for (final h in catHabits) {
          final st = statsByHabitId[h.id]!;
          final arch = h.isArchived
              ? ' _(${isFa ? 'آرشیو' : 'Archived'})_'
              : '';
          cBuf.writeln(
              '- [[Habits/${habitSlugById[h.id]}|${h.title}]]$arch — ${st.currentStreak}d • ${st.habitScore}%');
        }
      }
      files.add((
        subDir: 'Categories',
        fileName: '${catSlugById[c.id]}.md',
        content: cBuf.toString(),
      ));
    }

    // 5. Full Evergreen Habit Pages (`Habits/<HabitTitle>.md`)
    for (final h in habits) {
      final slug = habitSlugById[h.id]!;
      final items = checklist.where((i) => i.habitId == h.id).toList();
      final hComps = completions.where((x) => x.habitId == h.id).toList()
        ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
      final byDate = {for (final c in hComps) c.dateKey: c};
      final stats = statsByHabitId[h.id]!;
      final hPauses = pauses.where((p) => p.habitId == h.id).toList();
      final hNotes = notes.where((n) => n.habitId == h.id).toList()
        ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
      final cat = h.categoryId != null ? catById[h.categoryId!] : null;

      final hBuf = StringBuffer()
        ..writeln('← [[XHabit Home]]${cat != null ? ' • [[Categories/${catSlugById[cat.id]}|${cat.name}]]' : ''}')
        ..writeln()
        ..writeln('# ${h.title}${h.isArchived ? (isFa ? ' (آرشیو)' : ' (Archived)') : ''}');

      if (h.description.isNotEmpty) {
        hBuf
          ..writeln()
          ..writeln(h.description);
      }

      final modeNames = (h.dayModes.isEmpty ? ['normal'] : h.dayModes)
          .map(modeLabel)
          .join('، ');
      hBuf
        ..writeln()
        ..writeln('**${isFa ? 'مودهای فعال:' : 'Day Modes:'}** [[Day Modes|$modeNames]]')
        ..writeln()
        ..writeln('| ${isFa ? 'شاخص' : 'Metric'} | ${isFa ? 'مقدار' : 'Value'} |')
        ..writeln('| --- | --- |')
        ..writeln('| ${isFa ? 'استریک فعلی' : 'Current Streak'} | ${stats.currentStreak} ${isFa ? 'روز' : 'days'} |')
        ..writeln('| ${isFa ? 'بهترین استریک' : 'Best Streak'} | ${stats.bestStreak} ${isFa ? 'روز' : 'days'} |')
        ..writeln('| ${isFa ? 'امتیاز عادت' : 'Habit Score'} | ${stats.habitScore}% |')
        ..writeln('| ${isFa ? 'نرخ تکمیل' : 'Completion Rate'} | ${(stats.completionRate * 100).round()}% |');

      if (items.isNotEmpty) {
        hBuf
          ..writeln()
          ..writeln('## ${isFa ? 'زیرمجموعه چک‌لیست' : 'Checklist Steps'}');
        for (final it in items) {
          hBuf.writeln('- ${it.title}');
        }
      }

      if (hPauses.isNotEmpty) {
        hBuf
          ..writeln()
          ..writeln('## ${isFa ? 'دوره‌های توقف موقت' : 'Pause Windows'}');
        for (final pz in hPauses) {
          final endStr = pz.endDateKey == null
              ? (isFa ? 'ادامه دارد' : 'Ongoing')
              : '[[Daily/${pz.endDateKey}|${pz.endDateKey}]]';
          final reason = pz.reason.isEmpty ? '' : ' — ${pz.reason}';
          hBuf.writeln(
              '- [[Daily/${pz.startDateKey}|${pz.startDateKey}]] → $endStr$reason');
        }
      }

      if (hNotes.isNotEmpty) {
        hBuf
          ..writeln()
          ..writeln('## ${isFa ? 'یادداشت‌ها' : 'Journal Notes'} (${hNotes.length})');
        for (final n in hNotes) {
          final titlePart = n.title.isEmpty ? '' : '**${n.title}**: ';
          final body = n.kind == NoteKind.text
              ? n.content
              : '[${n.kind.name}] ${n.content}';
          hBuf.writeln('- [[Daily/${n.dateKey}|${n.dateKey}]] $titlePart$body');
        }
      }

      if (hComps.isNotEmpty) {
        hBuf
          ..writeln()
          ..writeln('## ${isFa ? 'تاریخچه ثبت‌ها' : 'Activity Log'} (${hComps.length})');
        for (final c in hComps.take(90)) {
          final d = AppCalendar.fromDateKey(c.dateKey);
          final done = HabitEngine.isCompletedOn(h, c, items, d, today: today);
          final detail = c.slipped
              ? (isFa ? 'لغزش' : 'Slipped')
              : (h.trackingStyle == TrackingStyle.count
                  ? '${c.value}/${h.targetCount} ${h.countUnit}'.trim()
                  : (done
                      ? (isFa ? 'تکمیل‌شده' : 'Done')
                      : (isFa ? 'ناقص' : 'Partial')));
          hBuf.writeln('- [${done ? 'x' : ' '}] [[Daily/${c.dateKey}|${c.dateKey}]] — $detail');
        }
      } else {
        // Ensure byDate reference isn't unused if comps empty.
        assert(byDate.isEmpty);
      }

      files.add((
        subDir: 'Habits',
        fileName: '$slug.md',
        content: hBuf.toString(),
      ));
    }

    // 6. All Daily Log Pages (`Daily/<YYYY-MM-DD>.md`)
    for (var i = 0; i < allDates.length; i++) {
      final dk = allDates[i];
      final dt = AppCalendar.fromDateKey(dk);
      final prevLink = i > 0 ? '← [[Daily/${allDates[i - 1]}|${allDates[i - 1]}]]' : '';
      final nextLink = i + 1 < allDates.length
          ? '[[Daily/${allDates[i + 1]}|${allDates[i + 1]}]] →'
          : '';
      final navParts = [
        '[[XHabit Home]]',
        if (prevLink.isNotEmpty) prevLink,
        if (nextLink.isNotEmpty) nextLink,
      ];
      final dJalali = AppCalendar.monthDayLabel(
        dt,
        CalendarSystem.jalali,
        settings.localeCode,
      );
      final dMode = HabitEngine.resolveDayMode(settings, dt);

      final dBuf = StringBuffer()
        ..writeln(navParts.join(' • '))
        ..writeln()
        ..writeln('# $dk ($dJalali)')
        ..writeln()
        ..writeln('**${isFa ? 'مود روز:' : 'Day Mode:'}** [[Day Modes|${modeLabel(dMode)}]]')
        ..writeln()
        ..writeln('## ${isFa ? 'عادت‌ها' : 'Habits'}');

      var wroteHabitOnDay = false;
      for (final h in habits) {
        final comp = completions
            .where((x) => x.habitId == h.id && x.dateKey == dk)
            .firstOrNull;
        final matchesMode = !h.isArchived && HabitEngine.matchesDayMode(h, dMode);
        if (comp == null && !matchesMode && dk != todayKey) continue;
        if (h.isArchived && comp == null) continue;

        wroteHabitOnDay = true;
        final items = checklist.where((x) => x.habitId == h.id).toList();
        final done =
            HabitEngine.isCompletedOn(h, comp, items, dt, today: today);
        final paused = HabitEngine.isPausedOn(h.id, dt, pauses);
        final slug = habitSlugById[h.id]!;
        final suffix = paused
            ? ' _(${isFa ? 'متوقف‌شده' : 'Paused'})_'
            : (comp?.slipped == true
                ? ' _(${isFa ? 'لغزش' : 'Slipped'})_'
                : (h.trackingStyle == TrackingStyle.count
                    ? ' (${comp?.value ?? 0}/${h.targetCount} ${h.countUnit})'
                    : ''));
        dBuf.writeln('- [${done ? 'x' : ' '}] [[Habits/$slug|${h.title}]]$suffix');

        for (final sub in items) {
          final subDone = comp?.completedChecklistIds.contains(sub.id) ?? false;
          dBuf.writeln('  - [${subDone ? 'x' : ' '}] ${sub.title}');
        }
      }
      if (!wroteHabitOnDay) {
        dBuf.writeln('- _${isFa ? 'عادتی برای این روز ثبت نشده' : 'No habits recorded for this day'}_');
      }

      if (dk == todayKey) {
        dBuf
          ..writeln()
          ..writeln('## [[To Do List]] (${openTodos.length}/${oneOff.length})');
        if (oneOff.isEmpty) {
          dBuf.writeln('- _${isFa ? 'لیست کارها خالی است' : 'Empty'}_');
        } else {
          for (final t in oneOff) {
            final q = t.quantity.isEmpty ? '' : ' (${t.quantity})';
            dBuf.writeln('- [${t.isDone ? 'x' : ' '}] ${t.title}$q');
          }
        }
      }

      final dayNotes = notes.where((n) => n.dateKey == dk).toList();
      if (dayNotes.isNotEmpty) {
        dBuf
          ..writeln()
          ..writeln('## ${isFa ? 'یادداشت‌های روز' : 'Notes'}');
        for (final n in dayNotes) {
          final hSlug = habitSlugById[n.habitId];
          final hTitle =
              habits.where((h) => h.id == n.habitId).firstOrNull?.title ??
                  n.habitId;
          final habitRef =
              hSlug != null ? '[[Habits/$hSlug|$hTitle]]' : hTitle;
          final titleStr = n.title.isEmpty ? '' : ' (${n.title})';
          final body = n.kind == NoteKind.text
              ? n.content
              : '[${n.kind.name}] ${n.content}';
          dBuf.writeln('- $habitRef$titleStr: $body');
        }
      }

      files.add((
        subDir: 'Daily',
        fileName: '$dk.md',
        content: dBuf.toString(),
      ));
    }

    // Desired relative paths map (for differential writes + stale pruning)
    final desiredPaths = <String>[];
    final targetKey = vaultUri ?? settings.obsidianVaultUri ?? 'local';
    if (forceFullWrite || _cachedTargetKey != targetKey) {
      _cachedSignatures.clear();
      _cachedTargetKey = targetKey;
    }

    final changedFiles = <({String subDir, String fileName, String content})>[];
    final nextSignatures = <String, String>{};
    for (final f in files) {
      final rel = f.subDir.isEmpty ? f.fileName : '${f.subDir}/${f.fileName}';
      desiredPaths.add(rel);
      final sig = '${f.content.length}:${_fnv1a64(f.content)}';
      nextSignatures[rel] = sig;
      if (_cachedSignatures[rel] != sig) {
        changedFiles.add(f);
      }
    }

    // 1. Write & prune local mirror (`XHabit/Exports/Obsidian`) cleanly
    var localOk = true;
    try {
      final base =
          (Platform.isAndroid ? await getExternalStorageDirectory() : null) ??
              await getApplicationDocumentsDirectory();
      final obsRoot =
          Directory(p.join(base.path, 'XHabit', 'Exports', 'Obsidian'));
      final desiredSet = desiredPaths.toSet();

      for (final f in files) {
        final dir = f.subDir.isEmpty
            ? obsRoot
            : Directory(p.join(obsRoot.path, f.subDir));
        if (!await dir.exists()) await dir.create(recursive: true);
        final outFile = File(p.join(dir.path, f.fileName));
        final rel = f.subDir.isEmpty ? f.fileName : '${f.subDir}/${f.fileName}';
        if (!await outFile.exists() || _cachedSignatures[rel] != nextSignatures[rel]) {
          await outFile.writeAsString(f.content, flush: true);
        }
      }

      if (await obsRoot.exists()) {
        await for (final entity in obsRoot.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final rel = p.relative(entity.path, from: obsRoot.path).replaceAll('\\', '/');
            if (!desiredSet.contains(rel)) {
              try {
                await entity.delete();
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {
      localOk = false;
    }

    // 2. Sync & prune directly inside user's Android Obsidian Vault SAF `XHabit/` folder
    var overallSuccess = localOk;
    final targetUri = vaultUri ?? settings.obsidianVaultUri;
    if (Platform.isAndroid && targetUri != null && targetUri.isNotEmpty) {
      var safOk = false;
      try {
        final res = await _storageChannel.invokeMethod<int>(
          'syncRelativeFiles',
          {
            'treeUri': targetUri,
            'rootFolder': dedicatedFolderName,
            'keepRelativePaths': desiredPaths,
            'files': changedFiles
                .map((f) => {
                      'subDir': f.subDir,
                      'fileName': f.fileName,
                      'mimeType': 'text/markdown',
                      'content': f.content,
                    })
                .toList(),
          },
        );
        if (res != null && res >= 0) {
          safOk = true;
          _cachedSignatures
            ..clear()
            ..addAll(nextSignatures);
        }
      } catch (_) {
        // Fallback only when incremental sync fails unexpectedly
        try {
          if (changedFiles.isEmpty) {
            safOk = true;
          } else {
            final fallbackWritten =
                await _storageChannel.invokeMethod<int>('writeRelativeFiles', {
              'treeUri': targetUri,
              'rootFolder': dedicatedFolderName,
              'files': changedFiles
                  .map((f) => {
                        'subDir': f.subDir,
                        'fileName': f.fileName,
                        'mimeType': 'text/markdown',
                        'content': f.content,
                      })
                  .toList(),
            });
            safOk = (fallbackWritten ?? 0) >= changedFiles.length;
          }
          if (safOk) {
            _cachedSignatures
              ..clear()
              ..addAll(nextSignatures);
          }
        } catch (_) {}
      }
      overallSuccess = safOk;
    } else if (localOk) {
      _cachedSignatures
        ..clear()
        ..addAll(nextSignatures);
    }

    return SyncResult(
      success: overallSuccess,
      pushedCount: overallSuccess ? files.length : 0,
      pulledCount: 0,
      newRevision: DateTime.now().millisecondsSinceEpoch,
      errorMessage: overallSuccess ? null : 'obsidian_sync_failed',
    );
  }

  static String _fnv1a64(String input) {
    var hash = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    final mask = (BigInt.one << 64) - BigInt.one;
    for (final unit in input.codeUnits) {
      hash = ((hash ^ BigInt.from(unit)) * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  static String _safeSlug(String title, String fallbackId) {
    var cleaned = title
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|#\[\]^]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s.]+|[\s.]+$'), '');
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      cleaned = fallbackId;
    }
    return cleaned;
  }

  static String _uniqueSlug(String title, String id, Set<String> used) {
    final base = _safeSlug(title, id);
    var candidate = base;
    var suffix = 2;
    while (!used.add(candidate.toLowerCase())) {
      candidate = '$base ($suffix)';
      suffix++;
    }
    return candidate;
  }
}
