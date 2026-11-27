import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/icons/habit_icons.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/xhabit_ui.dart';
import '../../data/models/habit_models.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';

class OneOffTasksScreen extends ConsumerStatefulWidget {
  const OneOffTasksScreen({
    required this.onOpenSettings,
    this.showBackButton = true,
    super.key,
  });

  final VoidCallback onOpenSettings;
  final bool showBackButton;

  @override
  ConsumerState<OneOffTasksScreen> createState() => _OneOffTasksScreenState();
}

class _OneOffTasksScreenState extends ConsumerState<OneOffTasksScreen> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitQuickAdd(AppSettings settings) async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final qty = _qtyCtrl.text.trim();
    _titleCtrl.clear();
    _qtyCtrl.clear();
    await ref.read(habitStateProvider.notifier).addOneOffTask(
          title: title,
          kind: OneOffKind.todo,
          quantity: qty,
        );
    await SoundService.instance.play(
      ChimeKind.done,
      enabled: settings.isAchievementSoundEnabled,
      profile: settings.soundProfile,
    );
  }

  Future<void> _openEditTaskSheet(
    BuildContext context,
    OneOffTask item,
    AppSettings settings,
  ) async {
    final xc = context.xc;
    final l10n = AppLocalizations.of(context);
    final tCtrl = TextEditingController(text: item.title);
    final qCtrl = TextEditingController(text: item.quantity);

    var saving = false;

    Future<void> save(BuildContext ctx) async {
      if (saving) return;
      final title = tCtrl.text.trim();
      if (title.isEmpty) {
        showXToast(ctx, l10n.enterValidTitle);
        return;
      }
      saving = true;
      try {
        await ref.read(habitStateProvider.notifier).updateOneOffTask(
              item,
              title: title,
              quantity: qCtrl.text,
            );
        await SoundService.instance.play(
          ChimeKind.done,
          enabled: settings.isAchievementSoundEnabled,
          profile: settings.soundProfile,
        );
        if (ctx.mounted) Navigator.pop(ctx);
      } finally {
        saving = false;
      }
    }

    await showXModalSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.editTaskTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: xc.text,
            ),
          ),
          const SizedBox(height: 12),
          XDarkField(
            controller: tCtrl,
            hintText: l10n.addOneOffHint,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          XDarkField(
            controller: qCtrl,
            hintText: l10n.quantityOptionalHint,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => save(ctx),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => save(ctx),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: xc.lime,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                l10n.save,
                style: TextStyle(
                  color: HabitPalette.contrastFg(xc.lime),
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(milliseconds: 350), () {
      tCtrl.dispose();
      qCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final stateAsync = ref.watch(habitStateProvider);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        child: stateAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (st) {
            final allTasks = st.oneOffTasks;
            final doneCount = allTasks.where((t) => t.isDone).length;

            return Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.showBackButton) ...[
                        HdrCircleButton(
                          icon: Directionality.of(context) == TextDirection.rtl
                              ? Icons.chevron_right_rounded
                              : Icons.chevron_left_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          l10n.tasksTabTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            color: xc.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          if (allTasks.isEmpty) {
                            showXToast(context, l10n.noOneOffTasks);
                            return;
                          }
                          final ok = await showXConfirmSheet(
                            context: context,
                            icon: Icons.delete_sweep_rounded,
                            title: l10n.clearAllTasksConfirmTitle,
                            message: l10n.clearAllTasksConfirmMsg,
                            cancelLabel: l10n.noCancel,
                            confirmLabel: l10n.yesDelete,
                          );
                          if (!ok || !context.mounted) return;
                          await ref
                              .read(habitStateProvider.notifier)
                              .clearAllOneOffTasks();
                          await SoundService.instance.play(
                            ChimeKind.undo,
                            enabled: settings.isAchievementSoundEnabled,
                            profile: settings.soundProfile,
                          );
                        },
                        child: Container(
                          margin: const EdgeInsetsDirectional.only(end: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(
                            color: xc.card2,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: allTasks.isNotEmpty
                                  ? xc.borderStrong
                                  : xc.border,
                            ),
                          ),
                          child: Text(
                            l10n.clearAllTasksBtn,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: allTasks.isNotEmpty
                                  ? const Color(0xFFEF4444)
                                  : xc.dim,
                            ),
                          ),
                        ),
                      ),
                      HdrCircleButton(
                        icon: Icons.settings_outlined,
                        onTap: widget.onOpenSettings,
                      ),
                    ],
                  ),
                ),

                if (allTasks.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        value: doneCount / allTasks.length,
                        backgroundColor: xc.card2,
                        valueColor: AlwaysStoppedAnimation<Color>(xc.lime),
                      ),
                    ),
                  ),
                ],

                // Quick-add input composer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: xc.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: xc.borderStrong),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              TextField(
                                controller: _titleCtrl,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submitQuickAdd(settings),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: xc.text,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: l10n.addOneOffHint,
                                  hintStyle: TextStyle(
                                    color: xc.muted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              TextField(
                                controller: _qtyCtrl,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submitQuickAdd(settings),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: xc.muted,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: l10n.quantityOptionalHint,
                                  hintStyle: TextStyle(
                                    fontSize: 11.5,
                                    color: xc.dim,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _submitQuickAdd(settings),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: xc.lime,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.add_rounded,
                              color: HabitPalette.contrastFg(xc.lime),
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Items List
                Expanded(
                  child: allTasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.checklist_rtl_rounded,
                                size: 42,
                                color: xc.dim,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.noOneOffTasks,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: xc.muted,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                              14, 0, 14, 24 + bottomInset),
                          itemCount: allTasks.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, idx) {
                            final item = allTasks[idx];
                            return GestureDetector(
                              onTap: () async {
                                await ref
                                    .read(habitStateProvider.notifier)
                                    .toggleOneOffTask(item);
                                await SoundService.instance.play(
                                  !item.isDone
                                      ? ChimeKind.done
                                      : ChimeKind.undo,
                                  enabled: settings.isAchievementSoundEnabled,
                                  profile: settings.soundProfile,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 13, vertical: 12),
                                decoration: BoxDecoration(
                                  color: item.isDone
                                      ? xc.card.withValues(alpha: 0.55)
                                      : xc.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: item.isDone
                                        ? xc.border
                                        : xc.borderStrong,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: item.isDone
                                            ? xc.lime
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(7),
                                        border: item.isDone
                                            ? null
                                            : Border.all(
                                                color: xc.lime
                                                    .withValues(alpha: 0.7),
                                                width: 1.7,
                                              ),
                                      ),
                                      alignment: Alignment.center,
                                      child: item.isDone
                                          ? Icon(
                                              Icons.check_rounded,
                                              size: 16,
                                              color: HabitPalette.contrastFg(
                                                  xc.lime),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: item.isDone
                                                  ? xc.muted
                                                  : xc.text,
                                              decoration: item.isDone
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                          if (item.quantity.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              item.quantity,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: xc.muted,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _openEditTaskSheet(
                                        context,
                                        item,
                                        settings,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: xc.card2,
                                          borderRadius:
                                              BorderRadius.circular(9),
                                          border: Border.all(color: xc.border),
                                        ),
                                        child: Icon(
                                          Icons.edit_outlined,
                                          size: 15,
                                          color: xc.muted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => ref
                                          .read(habitStateProvider.notifier)
                                          .deleteOneOffTask(item.id),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 17,
                                          color: xc.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
