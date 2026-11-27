import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/icons/habit_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/xhabit_ui.dart';
import '../../data/models/habit_models.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';

/// Opens the Reorder Habits UI as an integrated bottom sheet matching the
/// Categories & Settings sheets.
Future<void> showReorderHabitsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.74),
    builder: (ctx) {
      final xc = ctx.xc;
      final maxH = MediaQuery.of(ctx).size.height * 0.85;
      return Container(
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: BoxDecoration(
          color: xc.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: xc.borderStrong)),
        ),
        child: const SafeArea(
          top: false,
          maintainBottomViewPadding: true,
          child: _ReorderHabitsSheetContent(),
        ),
      );
    },
  );
}

class _ReorderHabitsSheetContent extends ConsumerStatefulWidget {
  const _ReorderHabitsSheetContent();

  @override
  ConsumerState<_ReorderHabitsSheetContent> createState() =>
      _ReorderHabitsSheetContentState();
}

class _ReorderHabitsSheetContentState
    extends ConsumerState<_ReorderHabitsSheetContent> {
  List<Habit>? _working;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    final stateAsync = ref.watch(habitStateProvider);
    final habits = _working ??
        (stateAsync.value?.habits.where((h) => !h.isArchived).toList() ?? []);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: xc.borderStrong,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.reorderHabits,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: xc.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          await ref
                              .read(habitStateProvider.notifier)
                              .reorderHabits(habits.map((h) => h.id).toList());
                          if (context.mounted) Navigator.pop(context);
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: xc.lime,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: _saving
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: HabitPalette.contrastFg(xc.lime),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.save,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: HabitPalette.contrastFg(xc.lime),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: HabitPalette.contrastFg(xc.lime),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: habits.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  child: Text(
                    l10n.noHabitsYet,
                    style: TextStyle(fontSize: 12.5, color: xc.muted),
                  ),
                )
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      color: Colors.transparent,
                      elevation: 0,
                      child: Transform.scale(scale: 1.02, child: child),
                    );
                  },
                  itemCount: habits.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      final list = List<Habit>.from(habits);
                      final adjNew =
                          newIndex > oldIndex ? newIndex - 1 : newIndex;
                      final moved = list.removeAt(oldIndex);
                      list.insert(adjNew, moved);
                      _working = list;
                    });
                  },
                  itemBuilder: (_, i) {
                    final h = habits[i];
                    return Container(
                      key: ValueKey(h.id),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: xc.card2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: xc.border),
                      ),
                      child: Row(
                        children: [
                          HabitRingIcon(
                            iconKey: h.iconKey,
                            accent: Color(h.colorValue),
                            outerSize: 34,
                            innerSize: 25,
                            iconSize: 14,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              h.title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: xc.text,
                              ),
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(Icons.drag_handle_rounded,
                                  color: xc.muted),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class ReorderHabitsScreen extends ConsumerStatefulWidget {
  const ReorderHabitsScreen({super.key});

  @override
  ConsumerState<ReorderHabitsScreen> createState() =>
      _ReorderHabitsScreenState();
}

class _ReorderHabitsScreenState extends ConsumerState<ReorderHabitsScreen> {
  List<Habit>? _working;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    final stateAsync = ref.watch(habitStateProvider);
    final habits = _working ??
        (stateAsync.value?.habits.where((h) => !h.isArchived).toList() ?? []);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        XNavBackButton(onTap: () => Navigator.pop(context)),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            l10n.reorderHabits,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: xc.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _saving
                        ? null
                        : () async {
                            _saving = true;
                            try {
                              await ref
                                  .read(habitStateProvider.notifier)
                                  .reorderHabits(
                                      habits.map((h) => h.id).toList());
                              if (context.mounted) Navigator.pop(context);
                            } finally {
                              if (mounted) _saving = false;
                            }
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      child: Row(
                        children: [
                          Text(
                            l10n.save,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: xc.text,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.check_rounded, size: 17, color: xc.text),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: EdgeInsets.fromLTRB(14, 0, 14, 24 + bottomInset),
                proxyDecorator: (child, index, animation) {
                  return Material(
                    color: Colors.transparent,
                    elevation: 0,
                    child: Transform.scale(scale: 1.02, child: child),
                  );
                },
                itemCount: habits.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    final list = List<Habit>.from(habits);
                    final adjNew =
                        newIndex > oldIndex ? newIndex - 1 : newIndex;
                    final moved = list.removeAt(oldIndex);
                    list.insert(adjNew, moved);
                    _working = list;
                  });
                },
                itemBuilder: (_, i) {
                  final h = habits[i];
                  return Container(
                    key: ValueKey(h.id),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: xc.card2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: xc.border),
                    ),
                    child: Row(
                      children: [
                        HabitRingIcon(
                          iconKey: h.iconKey,
                          accent: Color(h.colorValue),
                          outerSize: 34,
                          innerSize: 25,
                          iconSize: 14,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            h.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: xc.text,
                            ),
                          ),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(Icons.drag_handle_rounded, color: xc.muted),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
