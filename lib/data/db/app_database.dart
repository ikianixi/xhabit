import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/sync/sync_ports.dart';
import '../models/habit_models.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const _uuid = Uuid();
  Database? _db;
  Future<Database>? _openFuture;

  Future<String> databaseFilePath() async {
    final dbDir = await getDatabasesPath();
    return p.join(dbDir, 'xhabit.db');
  }

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    return _openFuture ??= _initDb();
  }

  Future<Database> _initDb() async {
    try {
      final path = await databaseFilePath();
      _db = await openDatabase(
        path,
        version: 5,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      return _db!;
    } finally {
      _openFuture = null;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sync_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.insert('sync_meta', {'key': 'local_revision', 'value': '0'});
    await db.insert('sync_meta', {'key': 'device_id', 'value': _uuid.v4()});
    await db.insert('sync_meta', {'key': 'obsidian_last_rev', 'value': '0'});
    await db.insert('sync_meta', {'key': 'cloud_last_rev', 'value': '0'});

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        sort_order INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        deleted_at_ms INTEGER,
        sync_revision INTEGER NOT NULL DEFAULT 0,
        sync_dirty INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE habits (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        mode TEXT NOT NULL,
        tracking_style TEXT NOT NULL,
        frequency_type TEXT NOT NULL,
        weekdays_mask INTEGER NOT NULL DEFAULT 127,
        month_days TEXT NOT NULL DEFAULT '1,15',
        target_per_week INTEGER NOT NULL DEFAULT 5,
        interval_days INTEGER NOT NULL DEFAULT 1,
        target_count INTEGER NOT NULL DEFAULT 1,
        count_unit TEXT NOT NULL DEFAULT '',
        color_value INTEGER NOT NULL,
        icon_key TEXT NOT NULL,
        category_id TEXT,
        start_date_key TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        show_title_badge INTEGER NOT NULL DEFAULT 0,
        reminder_enabled INTEGER NOT NULL DEFAULT 0,
        reminder_hour INTEGER,
        reminder_minute INTEGER,
        reminder_repeat_mins INTEGER NOT NULL DEFAULT 0,
        reminder_max_repeats INTEGER NOT NULL DEFAULT 3,
        response_window_mins INTEGER NOT NULL DEFAULT 120,
        smart_learning_enabled INTEGER NOT NULL DEFAULT 0,
        day_modes TEXT NOT NULL DEFAULT '',
        updated_at_ms INTEGER NOT NULL,
        deleted_at_ms INTEGER,
        sync_revision INTEGER NOT NULL DEFAULT 0,
        sync_dirty INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_checklist_items (
        id TEXT PRIMARY KEY,
        habit_id TEXT NOT NULL,
        title TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        updated_at_ms INTEGER NOT NULL,
        deleted_at_ms INTEGER,
        sync_revision INTEGER NOT NULL DEFAULT 0,
        sync_dirty INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_completions (
        id TEXT PRIMARY KEY,
        habit_id TEXT NOT NULL,
        date_key TEXT NOT NULL,
        value INTEGER NOT NULL DEFAULT 0,
        completed_checklist_ids TEXT NOT NULL DEFAULT '',
        slipped INTEGER NOT NULL DEFAULT 0,
        updated_at_ms INTEGER NOT NULL,
        deleted_at_ms INTEGER,
        sync_revision INTEGER NOT NULL DEFAULT 0,
        sync_dirty INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_completions_habit_date
      ON habit_completions (habit_id, date_key)
    ''');

    await db.execute('''
      CREATE TABLE habit_notes (
        id TEXT PRIMARY KEY,
        habit_id TEXT NOT NULL,
        date_key TEXT NOT NULL,
        kind TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        deleted_at_ms INTEGER,
        sync_revision INTEGER NOT NULL DEFAULT 0,
        sync_dirty INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_pauses (
        id TEXT PRIMARY KEY,
        habit_id TEXT NOT NULL,
        start_date_key TEXT NOT NULL,
        end_date_key TEXT,
        reason TEXT NOT NULL DEFAULT '',
        updated_at_ms INTEGER NOT NULL,
        deleted_at_ms INTEGER,
        sync_revision INTEGER NOT NULL DEFAULT 0,
        sync_dirty INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE one_off_tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'todo',
        quantity TEXT NOT NULL DEFAULT '',
        is_done INTEGER NOT NULL DEFAULT 0,
        due_date_key TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER NOT NULL,
        deleted_at_ms INTEGER,
        sync_revision INTEGER NOT NULL DEFAULT 0,
        sync_dirty INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE completion_events (
        id TEXT PRIMARY KEY,
        habit_id TEXT NOT NULL,
        minute_of_day INTEGER NOT NULL,
        weekday INTEGER NOT NULL,
        recorded_at_ms INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          "ALTER TABLE habits ADD COLUMN month_days TEXT NOT NULL DEFAULT '1,15'");
      await db.execute(
          'ALTER TABLE habits ADD COLUMN target_per_week INTEGER NOT NULL DEFAULT 5');
      await db.execute(
          'ALTER TABLE habits ADD COLUMN show_title_badge INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          "ALTER TABLE habit_notes ADD COLUMN title TEXT NOT NULL DEFAULT ''");
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS habit_pauses (
          id TEXT PRIMARY KEY,
          habit_id TEXT NOT NULL,
          start_date_key TEXT NOT NULL,
          end_date_key TEXT,
          reason TEXT NOT NULL DEFAULT '',
          updated_at_ms INTEGER NOT NULL,
          deleted_at_ms INTEGER,
          sync_revision INTEGER NOT NULL DEFAULT 0,
          sync_dirty INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE habits ADD COLUMN reminder_repeat_mins INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE habits ADD COLUMN reminder_max_repeats INTEGER NOT NULL DEFAULT 3');
      await db.execute(
          'ALTER TABLE habits ADD COLUMN response_window_mins INTEGER NOT NULL DEFAULT 120');
      await db.execute(
          'ALTER TABLE habits ADD COLUMN smart_learning_enabled INTEGER NOT NULL DEFAULT 0');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS one_off_tasks (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          kind TEXT NOT NULL DEFAULT 'todo',
          quantity TEXT NOT NULL DEFAULT '',
          is_done INTEGER NOT NULL DEFAULT 0,
          due_date_key TEXT,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at_ms INTEGER NOT NULL,
          updated_at_ms INTEGER NOT NULL,
          deleted_at_ms INTEGER,
          sync_revision INTEGER NOT NULL DEFAULT 0,
          sync_dirty INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS completion_events (
          id TEXT PRIMARY KEY,
          habit_id TEXT NOT NULL,
          minute_of_day INTEGER NOT NULL,
          weekday INTEGER NOT NULL,
          recorded_at_ms INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute(
          "ALTER TABLE habits ADD COLUMN day_modes TEXT NOT NULL DEFAULT ''");
    }
  }

  Future<int> _nextRevision(DatabaseExecutor txn) async {
    final rows = await txn.query(
      'sync_meta',
      where: 'key = ?',
      whereArgs: ['local_revision'],
    );
    final current = rows.isEmpty ? 0 : int.parse(rows.first['value'] as String);
    final next = current + 1;
    await txn.insert(
      'sync_meta',
      {'key': 'local_revision', 'value': '$next'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return next;
  }

  // --- Categories ---
  Future<List<HabitCategory>> getCategories() async {
    final db = await database;
    final rows = await db.query(
      'categories',
      where: 'deleted_at_ms IS NULL',
      orderBy: 'sort_order ASC',
    );
    return rows.map(HabitCategory.fromDbMap).toList();
  }

  Future<void> upsertCategory(HabitCategory category) async {
    final db = await database;
    await db.transaction((txn) async {
      final rev = await _nextRevision(txn);
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.insert(
        'categories',
        category
            .copyWith(updatedAtMs: now, syncRevision: rev, syncDirty: true)
            .toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> softDeleteCategory(String categoryId, {String? fallbackCategoryId}) async {
    final db = await database;
    await db.transaction((txn) async {
      final rev = await _nextRevision(txn);
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.update(
        'categories',
        {
          'deleted_at_ms': now,
          'updated_at_ms': now,
          'sync_revision': rev,
          'sync_dirty': 1,
        },
        where: 'id = ?',
        whereArgs: [categoryId],
      );
      await txn.update(
        'habits',
        {
          'category_id': fallbackCategoryId,
          'updated_at_ms': now,
          'sync_revision': rev,
          'sync_dirty': 1,
        },
        where: 'category_id = ? AND deleted_at_ms IS NULL',
        whereArgs: [categoryId],
      );
    });
  }

  // --- Habits ---
  Future<List<Habit>> getHabits({bool includeArchived = true}) async {
    final db = await database;
    final rows = await db.query(
      'habits',
      where: includeArchived
          ? 'deleted_at_ms IS NULL'
          : 'deleted_at_ms IS NULL AND is_archived = 0',
      orderBy: 'sort_order ASC',
    );
    return rows.map(Habit.fromDbMap).toList();
  }

  Future<void> upsertHabit(
    Habit habit,
    List<HabitChecklistItem> checklistItems,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      final rev = await _nextRevision(txn);
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.insert(
        'habits',
        habit
            .copyWith(updatedAtMs: now, syncRevision: rev, syncDirty: true)
            .toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final existing = await txn.query(
        'habit_checklist_items',
        where: 'habit_id = ? AND deleted_at_ms IS NULL',
        whereArgs: [habit.id],
      );
      final keepIds = checklistItems.map((e) => e.id).toSet();
      for (final row in existing) {
        final id = row['id'] as String;
        if (!keepIds.contains(id)) {
          await txn.update(
            'habit_checklist_items',
            {
              'deleted_at_ms': now,
              'updated_at_ms': now,
              'sync_revision': rev,
              'sync_dirty': 1,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
      for (final item in checklistItems) {
        final map = item.toDbMap();
        map['updated_at_ms'] = now;
        map['sync_revision'] = rev;
        map['sync_dirty'] = 1;
        await txn.insert(
          'habit_checklist_items',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> updateHabitOrder(List<String> orderedIds) async {
    final db = await database;
    await db.transaction((txn) async {
      final rev = await _nextRevision(txn);
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update(
          'habits',
          {
            'sort_order': i,
            'updated_at_ms': now,
            'sync_revision': rev,
            'sync_dirty': 1,
          },
          where: 'id = ?',
          whereArgs: [orderedIds[i]],
        );
      }
    });
  }

  Future<void> softDeleteHabit(String habitId) async {
    final db = await database;
    await db.transaction((txn) async {
      final rev = await _nextRevision(txn);
      final now = DateTime.now().millisecondsSinceEpoch;
      final patch = {
        'deleted_at_ms': now,
        'updated_at_ms': now,
        'sync_revision': rev,
        'sync_dirty': 1,
      };
      await txn.update('habits', patch,
          where: 'id = ? AND deleted_at_ms IS NULL', whereArgs: [habitId]);
      await txn.update('habit_checklist_items', patch,
          where: 'habit_id = ? AND deleted_at_ms IS NULL',
          whereArgs: [habitId]);
      await txn.update('habit_completions', patch,
          where: 'habit_id = ? AND deleted_at_ms IS NULL',
          whereArgs: [habitId]);
      await txn.update('habit_notes', patch,
          where: 'habit_id = ? AND deleted_at_ms IS NULL',
          whereArgs: [habitId]);
      await txn.update('habit_pauses', patch,
          where: 'habit_id = ? AND deleted_at_ms IS NULL',
          whereArgs: [habitId]);
    });
  }

  // --- Pauses ---
  Future<List<HabitPause>> getAllPauses() async {
    final db = await database;
    final rows = await db.query(
      'habit_pauses',
      where: 'deleted_at_ms IS NULL',
      orderBy: 'start_date_key DESC',
    );
    return rows.map(HabitPause.fromDbMap).toList();
  }

  Future<void> upsertPause(HabitPause pause) async {
    final db = await database;
    await db.transaction((txn) async {
      final rev = await _nextRevision(txn);
      final now = DateTime.now().millisecondsSinceEpoch;
      final map = pause.toDbMap();
      map['updated_at_ms'] = now;
      map['sync_revision'] = rev;
      map['sync_dirty'] = 1;
      await txn.insert('habit_pauses', map,
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> softDeletePause(String pauseId) async {
    final db = await database;
    await db.transaction((txn) async {
      final rev = await _nextRevision(txn);
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.update(
        'habit_pauses',
        {
          'deleted_at_ms': now,
          'updated_at_ms': now,
          'sync_revision': rev,
          'sync_dirty': 1,
        },
        where: 'id = ?',
        whereArgs: [pauseId],
      );
    });
  }

  // --- Checklist Items ---
  Future<List<HabitChecklistItem>> getAllChecklistItems() async {
    final db = await database;
    final rows = await db.query(
      'habit_checklist_items',
      where: 'deleted_at_ms IS NULL',
      orderBy: 'sort_order ASC',
    );
    return rows.map(HabitChecklistItem.fromDbMap).toList();
  }

  // --- Completions ---
  Future<List<HabitCompletion>> getAllCompletions() async {
    final db = await database;
    final rows = await db.query(
      'habit_completions',
      where: 'deleted_at_ms IS NULL',
    );
    return rows.map(HabitCompletion.fromDbMap).toList();
  }

  Future<void> upsertCompletion(HabitCompletion completion) async {
    final db = await database;
    await db.transaction((txn) async {
      final rev = await _nextRevision(txn);
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.delete(
        'habit_completions',
        where: 'habit_id = ? AND date_key = ? AND id != ?',
        whereArgs: [completion.habitId, completion.dateKey, completion.id],
      );
      final map = completion.toDbMap();
      map['updated_at_ms'] = now;
      map['sync_revision'] = rev;
      map['sync_dirty'] = 1;
      await txn.insert(
        'habit_completions',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  // --- Notes ---
  Future<List<HabitNote>> getAllNotes() async {
    final db = await database;
    final rows = await db.query(
      'habit_notes',
      where: 'deleted_at_ms IS NULL',
      orderBy: 'created_at_ms DESC',
    );
    return rows.map(HabitNote.fromDbMap).toList();
  }

  Future<void> insertNote(HabitNote note) async {
    final db = await database;
    await db.transaction((txn) async {
      final rev = await _nextRevision(txn);
      final now = DateTime.now().millisecondsSinceEpoch;
      final map = note.toDbMap();
      map['updated_at_ms'] = now;
      map['sync_revision'] = rev;
      map['sync_dirty'] = 1;
      await txn.insert('habit_notes', map,
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> softDeleteNote(String noteId) async {
    final db = await database;
    await db.transaction((txn) async {
      final rev = await _nextRevision(txn);
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.update(
        'habit_notes',
        {
          'deleted_at_ms': now,
          'updated_at_ms': now,
          'sync_revision': rev,
          'sync_dirty': 1,
        },
        where: 'id = ?',
        whereArgs: [noteId],
      );
    });
  }

  // --- One-Off / Shopping Tasks ---
  Future<List<OneOffTask>> getOneOffTasks() async {
    final db = await database;
    final rows = await db.query(
      'one_off_tasks',
      where: 'deleted_at_ms IS NULL',
      orderBy: 'is_done ASC, sort_order ASC, created_at_ms DESC',
    );
    return rows.map(OneOffTask.fromDbMap).toList();
  }

  Future<void> upsertOneOffTask(OneOffTask task) async {
    final db = await database;
    await db.transaction((txn) async {
      final rev = await _nextRevision(txn);
      final now = DateTime.now().millisecondsSinceEpoch;
      final map = task.toDbMap();
      map['updated_at_ms'] = now;
      map['sync_revision'] = rev;
      map['sync_dirty'] = 1;
      await txn.insert('one_off_tasks', map,
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> softDeleteOneOffTask(String taskId) async {
    final db = await database;
    await db.transaction((txn) async {
      final rev = await _nextRevision(txn);
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.update(
        'one_off_tasks',
        {
          'deleted_at_ms': now,
          'updated_at_ms': now,
          'sync_revision': rev,
          'sync_dirty': 1,
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );
    });
  }

  Future<void> _softDeleteOneOffTasksWhere(
    String where,
    List<Object?>? whereArgs,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      final rev = await _nextRevision(txn);
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.update(
        'one_off_tasks',
        {
          'deleted_at_ms': now,
          'updated_at_ms': now,
          'sync_revision': rev,
          'sync_dirty': 1,
        },
        where: where,
        whereArgs: whereArgs,
      );
    });
  }

  Future<void> clearCompletedOneOffTasks({OneOffKind? kind}) =>
      _softDeleteOneOffTasksWhere(
        kind == null
            ? 'is_done = 1 AND deleted_at_ms IS NULL'
            : 'is_done = 1 AND kind = ? AND deleted_at_ms IS NULL',
        kind == null ? null : [kind.name],
      );

  Future<void> clearAllOneOffTasks() =>
      _softDeleteOneOffTasksWhere('deleted_at_ms IS NULL', null);

  // --- Completion Timing Pattern Events ---
  Future<void> recordCompletionEvent(String habitId, DateTime at) async {
    final db = await database;
    final ev = CompletionEvent(
      id: _uuid.v4(),
      habitId: habitId,
      minuteOfDay: at.hour * 60 + at.minute,
      weekday: at.weekday,
      recordedAtMs: at.millisecondsSinceEpoch,
    );
    await db.insert('completion_events', ev.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CompletionEvent>> getCompletionEvents({
    String? habitId,
    int limit = 250,
  }) async {
    final db = await database;
    final rows = await db.query(
      'completion_events',
      where: habitId == null ? null : 'habit_id = ?',
      whereArgs: habitId == null ? null : [habitId],
      orderBy: 'recorded_at_ms DESC',
      limit: limit,
    );
    return rows.map(CompletionEvent.fromDbMap).toList();
  }

  Future<void> eraseAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in [
        'completion_events',
        'one_off_tasks',
        'habit_pauses',
        'habit_notes',
        'habit_completions',
        'habit_checklist_items',
        'habits',
        'categories',
      ]) {
        await txn.delete(table);
      }
      await _nextRevision(txn);
    });
  }

  // --- Sync Change Collector ---
  Future<List<SyncChangeRecord>> collectDirtyChanges() async {
    final db = await database;
    final out = <SyncChangeRecord>[];
    final tables = <String, SyncEntityType>{
      'categories': SyncEntityType.category,
      'habits': SyncEntityType.habit,
      'habit_checklist_items': SyncEntityType.checklistItem,
      'habit_completions': SyncEntityType.completion,
      'habit_notes': SyncEntityType.note,
    };
    for (final entry in tables.entries) {
      final rows = await db.query(entry.key, where: 'sync_dirty = 1');
      for (final row in rows) {
        out.add(SyncChangeRecord(
          entityType: entry.value,
          entityId: row['id'] as String,
          revision: (row['sync_revision'] as int?) ?? 0,
          updatedAtMs: row['updated_at_ms'] as int,
          deletedAtMs: row['deleted_at_ms'] as int?,
          payload: Map<String, dynamic>.from(row),
        ));
      }
    }
    out.sort((a, b) => a.revision.compareTo(b.revision));
    return out;
  }

  // --- Full JSON Backup & Restore ---
  Future<String> exportBackupJson({AppSettings? settings}) async {
    final db = await database;
    final data = {
      'app': 'XHabit',
      'schemaVersion': 5,
      'exportedAtMs': DateTime.now().millisecondsSinceEpoch,
      if (settings != null) 'settings': settings.toBackupMap(),
      'categories': await db.query('categories'),
      'habits': await db.query('habits'),
      'habit_checklist_items': await db.query('habit_checklist_items'),
      'habit_completions': await db.query('habit_completions'),
      'habit_notes': await db.query('habit_notes'),
      'habit_pauses': await db.query('habit_pauses'),
      'one_off_tasks': await db.query('one_off_tasks'),
      'completion_events': await db.query('completion_events'),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static const Map<String, Set<String>> _tableColumns = {
    'categories': {
      'id',
      'name',
      'color_value',
      'sort_order',
      'updated_at_ms',
      'deleted_at_ms',
      'sync_revision',
      'sync_dirty',
    },
    'habits': {
      'id',
      'title',
      'description',
      'mode',
      'tracking_style',
      'frequency_type',
      'weekdays_mask',
      'month_days',
      'target_per_week',
      'interval_days',
      'target_count',
      'count_unit',
      'color_value',
      'icon_key',
      'category_id',
      'start_date_key',
      'sort_order',
      'is_archived',
      'show_title_badge',
      'reminder_enabled',
      'reminder_hour',
      'reminder_minute',
      'reminder_repeat_mins',
      'reminder_max_repeats',
      'response_window_mins',
      'smart_learning_enabled',
      'day_modes',
      'updated_at_ms',
      'deleted_at_ms',
      'sync_revision',
      'sync_dirty',
    },
    'habit_checklist_items': {
      'id',
      'habit_id',
      'title',
      'sort_order',
      'updated_at_ms',
      'deleted_at_ms',
      'sync_revision',
      'sync_dirty',
    },
    'habit_completions': {
      'id',
      'habit_id',
      'date_key',
      'value',
      'completed_checklist_ids',
      'slipped',
      'updated_at_ms',
      'deleted_at_ms',
      'sync_revision',
      'sync_dirty',
    },
    'habit_notes': {
      'id',
      'habit_id',
      'date_key',
      'kind',
      'title',
      'content',
      'duration_ms',
      'created_at_ms',
      'updated_at_ms',
      'deleted_at_ms',
      'sync_revision',
      'sync_dirty',
    },
    'habit_pauses': {
      'id',
      'habit_id',
      'start_date_key',
      'end_date_key',
      'reason',
      'updated_at_ms',
      'deleted_at_ms',
      'sync_revision',
      'sync_dirty',
    },
    'one_off_tasks': {
      'id',
      'title',
      'kind',
      'quantity',
      'is_done',
      'sort_order',
      'due_date_key',
      'created_at_ms',
      'updated_at_ms',
      'deleted_at_ms',
      'sync_revision',
      'sync_dirty',
    },
    'completion_events': {
      'id',
      'habit_id',
      'minute_of_day',
      'weekday',
      'recorded_at_ms',
    },
  };

  static Map<String, dynamic> _sanitizeRow(String table, Map raw) {
    final allowed = _tableColumns[table] ?? const <String>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    final m = <String, dynamic>{};
    for (final e in raw.entries) {
      final k = e.key.toString();
      if (allowed.contains(k)) m[k] = e.value;
    }
    void normText(String key, String def) {
      final v = m[key];
      m[key] = v == null ? def : v.toString();
    }

    int asInt(Object? v, int def) {
      if (v is num) return v.toInt();
      if (v is bool) return v ? 1 : 0;
      if (v != null) return int.tryParse(v.toString()) ?? def;
      return def;
    }

    void normInt(String key, int def) => m[key] = asInt(m[key], def);
    normText('id', '');

    if (table == 'categories') {
      normText('name', '');
      normInt('color_value', 0xFF84CC16);
      normInt('sort_order', 0);
      normInt('updated_at_ms', now);
      normInt('sync_revision', 0);
      normInt('sync_dirty', 0);
    } else if (table == 'habits') {
      normText('title', '');
      normText('description', '');
      normText('mode', 'build');
      normText('tracking_style', 'boolean');
      normText('frequency_type', 'daily');
      normInt('weekdays_mask', 127);
      normText('month_days', '1,15');
      normInt('target_per_week', 5);
      normInt('interval_days', 1);
      normInt('target_count', 1);
      normText('count_unit', '');
      normInt('color_value', 0xFF84CC16);
      normText('icon_key', 'check_circle');
      if (m['category_id'] != null) m['category_id'] = m['category_id'].toString();
      normText('start_date_key', '2025-01-01');
      normInt('sort_order', 0);
      normInt('is_archived', 0);
      normInt('show_title_badge', 0);
      normInt('reminder_enabled', 0);
      if (m['reminder_hour'] != null) normInt('reminder_hour', 9);
      if (m['reminder_minute'] != null) normInt('reminder_minute', 0);
      normInt('reminder_repeat_mins', 0);
      normInt('reminder_max_repeats', 3);
      normInt('response_window_mins', 120);
      normInt('smart_learning_enabled', 0);
      normText('day_modes', '');
      normInt('updated_at_ms', now);
      normInt('sync_revision', 0);
      normInt('sync_dirty', 0);
    } else if (table == 'habit_checklist_items') {
      normText('habit_id', '');
      normText('title', '');
      normInt('sort_order', 0);
      normInt('updated_at_ms', now);
      normInt('sync_revision', 0);
      normInt('sync_dirty', 0);
    } else if (table == 'habit_completions') {
      normText('habit_id', '');
      normText('date_key', '2025-01-01');
      normInt('value', 0);
      normText('completed_checklist_ids', '');
      normInt('slipped', 0);
      normInt('updated_at_ms', now);
      normInt('sync_revision', 0);
      normInt('sync_dirty', 0);
    } else if (table == 'habit_notes') {
      normText('habit_id', '');
      normText('date_key', '2025-01-01');
      normText('kind', 'text');
      normText('title', '');
      normText('content', '');
      normInt('duration_ms', 0);
      normInt('created_at_ms', now);
      normInt('updated_at_ms', now);
      normInt('sync_revision', 0);
      normInt('sync_dirty', 0);
    } else if (table == 'habit_pauses') {
      normText('habit_id', '');
      normText('start_date_key', '2025-01-01');
      if (m['end_date_key'] != null) m['end_date_key'] = m['end_date_key'].toString();
      normText('reason', '');
      normInt('updated_at_ms', now);
      normInt('sync_revision', 0);
      normInt('sync_dirty', 0);
    } else if (table == 'one_off_tasks') {
      normText('title', '');
      normText('kind', 'todo');
      normText('quantity', '');
      normInt('is_done', 0);
      normInt('sort_order', 0);
      if (m['due_date_key'] != null) m['due_date_key'] = m['due_date_key'].toString();
      normInt('created_at_ms', now);
      normInt('updated_at_ms', now);
      normInt('sync_revision', 0);
      normInt('sync_dirty', 0);
    } else if (table == 'completion_events') {
      normText('habit_id', '');
      normInt('minute_of_day', 0);
      normInt('weekday', 1);
      normInt('recorded_at_ms', now);
    }
    return m;
  }

  Future<Map<String, dynamic>?> importBackupJson(String jsonString) async {
    final rawDecoded = json.decode(jsonString);
    if (rawDecoded is! Map) {
      throw const FormatException('Invalid XHabit backup format');
    }
    final decoded = Map<String, dynamic>.from(rawDecoded);
    final ver = (decoded['schemaVersion'] as num?)?.toInt();
    if ((ver != 1 && ver != 2 && ver != 3 && ver != 4 && ver != 5) ||
        decoded['habits'] is! List) {
      throw const FormatException('Invalid XHabit backup format');
    }
    final rawSettings = decoded['settings'];
    final settingsMap =
        rawSettings is Map ? Map<String, dynamic>.from(rawSettings) : null;

    final db = await database;
    await db.transaction((txn) async {
      for (final table in [
        'completion_events',
        'one_off_tasks',
        'habit_pauses',
        'habit_notes',
        'habit_completions',
        'habit_checklist_items',
        'habits',
        'categories',
      ]) {
        await txn.delete(table);
        final list = (decoded[table] as List?) ?? const [];
        final importedCompByKey = <String, Map<String, dynamic>>{};
        for (final row in list) {
          if (row is! Map) continue;
          final m = _sanitizeRow(table, row);
          if ((m['id'] ?? '').toString().isEmpty) continue;
          if (table == 'habit_completions') {
            final hdKey = '${m['habit_id']}::${m['date_key']}';
            final prev = importedCompByKey[hdKey];
            if (prev != null) {
              if ((m['updated_at_ms'] as int) < (prev['updated_at_ms'] as int)) {
                continue;
              }
              await txn.delete(
                table,
                where: 'id = ?',
                whereArgs: [prev['id']],
              );
            }
            importedCompByKey[hdKey] = m;
          }
          await txn.insert(
            table,
            m,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await _nextRevision(txn);
    });
    return settingsMap;
  }

  /// Non-destructive LWW merge used when syncing with a remote Google account backup.
  Future<({int mergedRows, Map<String, dynamic>? settingsMap, int exportedAtMs})>
      mergeBackupJson(String jsonString) async {
    final rawDecoded = json.decode(jsonString);
    if (rawDecoded is! Map) {
      throw const FormatException('Invalid XHabit backup format');
    }
    final decoded = Map<String, dynamic>.from(rawDecoded);
    final ver = (decoded['schemaVersion'] as num?)?.toInt();
    if ((ver != 1 && ver != 2 && ver != 3 && ver != 4 && ver != 5) ||
        decoded['habits'] is! List) {
      throw const FormatException('Invalid XHabit backup format');
    }
    final exportedAtMs = (decoded['exportedAtMs'] as num?)?.toInt() ?? 0;
    final db = await database;
    var mergedRows = 0;

    await db.transaction((txn) async {
      for (final table in [
        'categories',
        'habits',
        'habit_checklist_items',
        'habit_completions',
        'habit_notes',
        'habit_pauses',
        'one_off_tasks',
      ]) {
        final list = (decoded[table] as List?) ?? const [];
        if (list.isEmpty) continue;
        final existingRows = await txn.query(table);
        final byId = <String, Map<String, Object?>>{
          for (final r in existingRows) r['id'] as String: r,
        };
        final compByHabitDate = <String, Map<String, Object?>>{};
        if (table == 'habit_completions') {
          for (final r in existingRows) {
            compByHabitDate['${r['habit_id']}::${r['date_key']}'] = r;
          }
        }

        for (final raw in list) {
          if (raw is! Map) continue;
          final m = _sanitizeRow(table, raw);
          final id = (m['id'] ?? '').toString();
          if (id.isEmpty) continue;
          final remoteUpdated = (m['updated_at_ms'] as num?)?.toInt() ?? 0;

          final byIdLocal = byId[id];
          final byHdLocal = table == 'habit_completions'
              ? compByHabitDate['${m['habit_id']}::${m['date_key']}']
              : null;
          Map<String, Object?>? local = byIdLocal ?? byHdLocal;
          if (byIdLocal != null &&
              byHdLocal != null &&
              byHdLocal['id'] != byIdLocal['id']) {
            final aUpd = (byIdLocal['updated_at_ms'] as num?)?.toInt() ?? 0;
            final bUpd = (byHdLocal['updated_at_ms'] as num?)?.toInt() ?? 0;
            final loseId = (aUpd >= bUpd ? byHdLocal['id'] : byIdLocal['id']) as String;
            local = aUpd >= bUpd ? byIdLocal : byHdLocal;
            await txn.delete(table, where: 'id = ?', whereArgs: [loseId]);
            byId.remove(loseId);
          }

          if (local == null) {
            await txn.insert(
              table,
              m,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            byId[id] = m;
            if (table == 'habit_completions') {
              compByHabitDate['${m['habit_id']}::${m['date_key']}'] = m;
            }
            mergedRows++;
          } else {
            final localUpdated = (local['updated_at_ms'] as num?)?.toInt() ?? 0;
            if (remoteUpdated > localUpdated) {
              final localId = local['id'] as String;
              if (table == 'habit_completions' && localId != id) {
                await txn.delete(
                  table,
                  where: 'id = ?',
                  whereArgs: [localId],
                );
                byId.remove(localId);
              }
              await txn.insert(
                table,
                m,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              byId[id] = m;
              if (table == 'habit_completions') {
                compByHabitDate['${m['habit_id']}::${m['date_key']}'] = m;
              }
              mergedRows++;
            }
          }
        }
      }

      // Append unseen completion timing events safely
      final evList = (decoded['completion_events'] as List?) ?? const [];
      if (evList.isNotEmpty) {
        final existingEvents = await txn.query('completion_events');
        final existingIds = {
          for (final e in existingEvents) e['id'] as String,
        };
        for (final raw in evList) {
          if (raw is! Map) continue;
          final m = _sanitizeRow('completion_events', raw);
          final id = (m['id'] ?? '').toString();
          if (id.isNotEmpty && !existingIds.contains(id)) {
            await txn.insert(
              'completion_events',
              m,
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
            existingIds.add(id);
          }
        }
      }
      await _nextRevision(txn);
    });

    final rawSettings = decoded['settings'];
    return (
      mergedRows: mergedRows,
      settingsMap:
          rawSettings is Map ? Map<String, dynamic>.from(rawSettings) : null,
      exportedAtMs: exportedAtMs,
    );
  }
}
