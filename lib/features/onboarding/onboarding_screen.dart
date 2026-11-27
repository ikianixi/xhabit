import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/habit_models.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _completing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_completing) return;
    _completing = true;
    try {
      final cur = ref.read(settingsProvider).value ?? const AppSettings();
      await ref
          .read(settingsProvider.notifier)
          .updateSettings(cur.copyWith(isOnboardingCompleted: true));
    } finally {
      if (mounted) _completing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    final slides = [
      (
        Icons.trending_up_rounded,
        const Color(0xFF10B981),
        l10n.onboardingTitle1,
        l10n.onboardingBody1,
      ),
      (
        Icons.shield_outlined,
        const Color(0xFFF59E0B),
        l10n.onboardingTitle2,
        l10n.onboardingBody2,
      ),
      (
        Icons.widgets_rounded,
        const Color(0xFF3B82F6),
        l10n.onboardingTitle3,
        l10n.onboardingBody3,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: TextButton(
                onPressed: _complete,
                child: Text(l10n.skip),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final s = slides[i];
                  return LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 56)
                              .clamp(0, double.infinity),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: s.$2.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(s.$1, size: 58, color: s.$2),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              s.$3,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              s.$4,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: xc.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _page == i
                        ? Theme.of(context).colorScheme.primary
                        : xc.borderStrong,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    if (_page < slides.length - 1) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                      );
                    } else {
                      _complete();
                    }
                  },
                  child: Text(
                    _page == slides.length - 1 ? l10n.getStarted : l10n.next,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
