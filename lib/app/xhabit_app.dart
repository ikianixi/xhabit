import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/calendar/app_calendar.dart';
import '../core/icons/habit_icons.dart';
import '../core/services/notification_service.dart';
import '../core/theme/app_tokens.dart';
import '../data/models/habit_models.dart';
import '../features/day_modes/day_modes_screen.dart';
import '../features/habits/add_edit_habit_screen.dart';
import '../features/habits/habit_details_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/timeline_screen.dart';
import '../features/security/app_lock_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tasks/one_off_tasks_screen.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_providers.dart';

class XHabitApp extends ConsumerStatefulWidget {
  const XHabitApp({super.key});

  @override
  ConsumerState<XHabitApp> createState() => _XHabitAppState();
}

class _XHabitAppState extends ConsumerState<XHabitApp>
    with WidgetsBindingObserver {
  final _navKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri?>? _widgetClickSub;
  bool _unlocked = false;
  bool? _prevAppLockEnabled;
  String? _pendingWidgetHabitId;
  String? _pendingWidgetTab;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.onActionCompleted = () {
      if (!mounted) return;
      ref.read(habitStateProvider.notifier).reload(
            skipObsidianSync: true,
            skipGoogleSync: true,
          );
    };
    _setupWidgetDeepLinks();
  }

  @override
  void dispose() {
    NotificationService.onActionCompleted = null;
    WidgetsBinding.instance.removeObserver(this);
    _widgetClickSub?.cancel();
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    final s = ref.read(settingsProvider).value;
    if (s != null && s.isAppLockEnabled && !_unlocked) {
      return true;
    }
    return super.didPopRoute();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final s = ref.read(settingsProvider).value;
      if (s?.isAppLockEnabled == true && mounted) {
        setState(() => _unlocked = false);
      }
    } else if (state == AppLifecycleState.resumed) {
      _refreshFromBackgroundIsolates();
    }
  }

  Future<void> _refreshFromBackgroundIsolates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      if (!mounted) return;
      ref.invalidate(settingsProvider);
      await ref.read(settingsProvider.future);
      if (!mounted) return;
      await ref.read(habitStateProvider.notifier).reload(
            skipObsidianSync: true,
            skipGoogleSync: true,
          );
    } catch (_) {}
  }

  void _setupWidgetDeepLinks() {
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
    _widgetClickSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null || uri.host != 'open') return;
    final tab = uri.queryParameters['tab'];
    if (tab == 'tasks' || tab == 'daymodes') {
      _pendingWidgetTab = tab;
      _pendingWidgetHabitId = null;
      _flushPendingWidgetNavigation();
      return;
    }
    final habitId = uri.queryParameters['habitId'];
    if (habitId == null || habitId.isEmpty) return;
    _pendingWidgetHabitId = habitId;
    _pendingWidgetTab = null;
    _flushPendingWidgetNavigation();
  }

  void _flushPendingWidgetNavigation() {
    final habitId = _pendingWidgetHabitId;
    final tab = _pendingWidgetTab;
    if (habitId == null && tab == null) return;
    final s = ref.read(settingsProvider).value;
    if (s == null) return;
    if (s.isAppLockEnabled && !_unlocked) return;
    _pendingWidgetHabitId = null;
    _pendingWidgetTab = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = _navKey.currentState;
      if (nav == null) return;
      void openSettingsFromDeepLink() {
        nav.push(
          MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
        );
      }

      if (tab == 'tasks') {
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => OneOffTasksScreen(
              onOpenSettings: openSettingsFromDeepLink,
            ),
          ),
        );
        return;
      }
      if (tab == 'daymodes') {
        final today = AppCalendar.logicalToday(DateTime.now(), s.dayResetMinutes);
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => DayModesScreen(
              targetDate: today,
              onOpenSettings: openSettingsFromDeepLink,
            ),
          ),
        );
        return;
      }
      if (habitId != null) {
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => HabitDetailsScreen(habitId: habitId),
          ),
        );
      }
    });
  }

  ThemeData _buildTheme(XColors xc, String fontFamily) {
    final brightness = xc.isDark ? Brightness.dark : Brightness.light;
    const fallback = ['Vazirmatn', 'FiraSans'];
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      scaffoldBackgroundColor: xc.bg,
      hintColor: xc.muted,
      dividerColor: xc.borderStrong,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: xc.lime,
        onPrimary: HabitPalette.contrastFg(xc.lime),
        secondary: xc.lime,
        onSecondary: HabitPalette.contrastFg(xc.lime),
        error: const Color(0xFFEF4444),
        onError: Colors.white,
        surface: xc.card,
        onSurface: xc.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: xc.bg,
        foregroundColor: xc.text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: xc.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: xc.border),
        ),
      ),
    );
    TextStyle? withFallback(TextStyle? s) => s?.copyWith(
          fontFamily: fontFamily,
          fontFamilyFallback: fallback,
          color: xc.text,
        );
    final t = base.textTheme;
    return base.copyWith(
      textTheme: t.copyWith(
        displayLarge: withFallback(t.displayLarge),
        displayMedium: withFallback(t.displayMedium),
        displaySmall: withFallback(t.displaySmall),
        headlineLarge: withFallback(t.headlineLarge),
        headlineMedium: withFallback(t.headlineMedium),
        headlineSmall: withFallback(t.headlineSmall),
        titleLarge: withFallback(t.titleLarge),
        titleMedium: withFallback(t.titleMedium),
        titleSmall: withFallback(t.titleSmall),
        bodyLarge: withFallback(t.bodyLarge),
        bodyMedium: withFallback(t.bodyMedium),
        bodySmall: withFallback(t.bodySmall),
        labelLarge: withFallback(t.labelLarge),
        labelMedium: withFallback(t.labelMedium),
        labelSmall: withFallback(t.labelSmall),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value ?? const AppSettings();
    ref.listen<AsyncValue<AppSettings>>(settingsProvider, (_, next) {
      final s = next.value;
      if (s == null) return;
      final prev = _prevAppLockEnabled;
      _prevAppLockEnabled = s.isAppLockEnabled;
      if (prev == false && s.isAppLockEnabled) {
        // User just enabled App Lock inside Settings; stay unlocked this session.
        _unlocked = true;
      } else if (prev == true && !s.isAppLockEnabled) {
        _unlocked = false;
      }
      _flushPendingWidgetNavigation();
    });
    if (settingsAsync.hasValue && _prevAppLockEnabled == null) {
      _prevAppLockEnabled = settings.isAppLockEnabled;
      if (!settings.isAppLockEnabled) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _flushPendingWidgetNavigation());
      }
    }
    final fontFamily =
        settings.localeCode == 'fa' ? 'Vazirmatn' : 'FiraSans';

    return MaterialApp(
      navigatorKey: _navKey,
      title: 'XHabit',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(XColors.light, fontFamily),
      darkTheme: _buildTheme(XColors.oled, fontFamily),
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(settings.localeCode),
      builder: (ctx, child) {
        final scale = switch (settings.fontScaleMode) {
          FontScaleMode.small => 0.88,
          FontScaleMode.medium => 1.0,
          FontScaleMode.large => 1.14,
        };
        final locked = settings.isAppLockEnabled && !_unlocked;
        return MediaQuery(
          data: MediaQuery.of(ctx).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: Stack(
            children: [
              ExcludeSemantics(
                excluding: locked,
                child: FocusScope(
                  canRequestFocus: !locked,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
              if (locked)
                Positioned.fill(
                  child: AppLockScreen(
                    onUnlocked: () {
                      setState(() => _unlocked = true);
                      _flushPendingWidgetNavigation();
                    },
                  ),
                ),
            ],
          ),
        );
      },
      supportedLocales: const [
        Locale('fa'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: settingsAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          body: Center(child: Text(e.toString())),
        ),
        data: (_) => const _MainShell(),
      ),
    );
  }
}

class _MainShell extends ConsumerStatefulWidget {
  const _MainShell();

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final xc = context.xc;
    final pages = [
      HomeScreen(
        onOpenSettings: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          );
        },
      ),
      TimelineScreen(
        onOpenSettings: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          );
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: xc.isDark
              ? const Color(0xF0000000)
              : const Color(0xF0FFFFFF),
          border: Border(top: BorderSide(color: xc.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _index = 0),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Icon(
                          Icons.grid_view_rounded,
                          size: 23,
                          color: _index == 0 ? xc.lime : xc.dim,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AddEditHabitScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: xc.isDark
                            ? Colors.white
                            : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: xc.isDark
                                ? const Color(0x29FFFFFF)
                                : const Color(0x260F172A),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.add_rounded,
                        size: 24,
                        color: xc.isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _index = 1),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Icon(
                          Icons.article_outlined,
                          size: 23,
                          color: _index == 1 ? xc.lime : xc.dim,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
