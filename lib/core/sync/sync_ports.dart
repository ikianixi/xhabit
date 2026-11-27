/// Phase 2 sync integration contracts.
///
/// Phase 1 persists all entities with stable UUIDs, monotonic `syncRevision`,
/// `updatedAtMs`, soft-delete `deletedAtMs`, and `syncDirty` flags so both
/// Obsidian vault sync and personal server delta sync can attach without
/// database schema migrations.

enum SyncEntityType {
  category,
  habit,
  checklistItem,
  completion,
  note,
}

enum SyncConflictPolicy {
  lastWriteWins,
  appendOnlyPreferCompletion,
}

class SyncChangeRecord {
  const SyncChangeRecord({
    required this.entityType,
    required this.entityId,
    required this.revision,
    required this.updatedAtMs,
    required this.payload,
    this.deletedAtMs,
  });

  final SyncEntityType entityType;
  final String entityId;
  final int revision;
  final int updatedAtMs;
  final int? deletedAtMs;
  final Map<String, dynamic> payload;

  bool get isDeleted => deletedAtMs != null;

  Map<String, dynamic> toJson() => {
        'entityType': entityType.name,
        'entityId': entityId,
        'revision': revision,
        'updatedAtMs': updatedAtMs,
        'deletedAtMs': deletedAtMs,
        'payload': payload,
      };
}

class SyncResult {
  const SyncResult({
    required this.success,
    required this.pushedCount,
    required this.pulledCount,
    required this.newRevision,
    this.errorMessage,
  });

  final bool success;
  final int pushedCount;
  final int pulledCount;
  final int newRevision;
  final String? errorMessage;
}

class ObsidianVaultConfig {
  const ObsidianVaultConfig({
    required this.vaultRootUri,
    this.habitsFolder = 'XHabit/Habits',
    this.dailyNotesFolder = 'XHabit/Daily',
    this.encryptSensitiveNotes = true,
  });

  final String vaultRootUri;
  final String habitsFolder;
  final String dailyNotesFolder;
  final bool encryptSensitiveNotes;
}

/// Port for Phase 2 secure Obsidian vault synchronization.
abstract interface class ObsidianSyncPort {
  Future<bool> isConfigured();
  Future<SyncResult> syncToVault(
    ObsidianVaultConfig config,
    List<SyncChangeRecord> dirtyChanges,
  );
}

class PersonalServerConfig {
  const PersonalServerConfig({
    required this.endpointUrl,
    required this.deviceId,
    this.conflictPolicy = SyncConflictPolicy.lastWriteWins,
  });

  final String endpointUrl;
  final String deviceId;
  final SyncConflictPolicy conflictPolicy;
}

/// Port for Phase 2 personal server delta synchronization.
abstract interface class PersonalCloudSyncPort {
  Future<bool> isConfigured();
  Future<SyncResult> pushAndPull(
    PersonalServerConfig config, {
    required int lastSyncedRevision,
    required List<SyncChangeRecord> dirtyChanges,
  });
}

class NoOpObsidianSyncPort implements ObsidianSyncPort {
  const NoOpObsidianSyncPort();

  @override
  Future<bool> isConfigured() async => false;

  @override
  Future<SyncResult> syncToVault(
    ObsidianVaultConfig config,
    List<SyncChangeRecord> dirtyChanges,
  ) async {
    return const SyncResult(
      success: false,
      pushedCount: 0,
      pulledCount: 0,
      newRevision: 0,
      errorMessage: 'Obsidian sync activates in Phase 2.',
    );
  }
}

class NoOpPersonalCloudSyncPort implements PersonalCloudSyncPort {
  const NoOpPersonalCloudSyncPort();

  @override
  Future<bool> isConfigured() async => false;

  @override
  Future<SyncResult> pushAndPull(
    PersonalServerConfig config, {
    required int lastSyncedRevision,
    required List<SyncChangeRecord> dirtyChanges,
  }) async {
    return SyncResult(
      success: false,
      pushedCount: 0,
      pulledCount: 0,
      newRevision: lastSyncedRevision,
      errorMessage: 'Personal cloud sync activates in Phase 2.',
    );
  }
}
