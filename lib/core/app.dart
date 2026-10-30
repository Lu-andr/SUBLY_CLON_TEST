import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'animations/app_animations.dart';
import '../core/theme/app_theme.dart';
import '../data/providers/app_state.dart';
import '../data/providers/subly_repository.dart';
import '../features/calculator/screens/calculator_screen.dart';
import '../features/application/screens/application_flow.dart';
import '../features/home/screens/home_screen.dart';
import '../features/lifecycle/screens/splash_screen.dart';
import '../features/partners/screens/partners_screen.dart';
import '../features/settings/screens/legal_screens.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/subscriptions/screens/subscription_detail_screen.dart';
import '../features/subscriptions/screens/subscriptions_screen.dart';
import 'services/offer_config_service.dart';

Widget _buildWithSafeTextScale(BuildContext context, Widget? child) {
  final mediaQuery = MediaQuery.of(context);
  return MediaQuery(
    data: mediaQuery.copyWith(
      textScaler: mediaQuery.textScaler.clamp(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.25,
      ),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}

class SublyApp extends StatelessWidget {
  const SublyApp({this.offerConfigService, super.key});
  final OfferConfigService? offerConfigService;
  @override
  Widget build(BuildContext context) =>
      ProviderScope(child: _Bootstrap(offerConfigService: offerConfigService));
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap({this.offerConfigService});
  final OfferConfigService? offerConfigService;
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  AppState? state;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final value = AppState(
      SublyRepository(preferences),
      offerConfigService: widget.offerConfigService,
    );
    await value.initialize();
    if (mounted) setState(() => state = value);
  }

  @override
  Widget build(BuildContext context) => state == null
      ? MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: SublyTheme.light(),
          builder: _buildWithSafeTextScale,
          home: const SplashScreen(),
        )
      : _ReadyApp(state: state!);
}

class _ReadyApp extends StatefulWidget {
  const _ReadyApp({required this.state});
  final AppState state;
  @override
  State<_ReadyApp> createState() => _ReadyAppState();
}

class _ReadyAppState extends State<_ReadyApp> {
  bool splashDone = false;
  bool applicationFlowDone = false;
  late final bool returningModerator;
  late final GoRouter router;
  @override
  void initState() {
    super.initState();
    returningModerator =
        widget.state.isModeratorMode && widget.state.application != null;
    widget.state.addListener(_changed);
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => MainShell(
            state: widget.state,
            onOpenSubscription: (id) => context.push('/subscription/$id'),
          ),
        ),
        GoRoute(
          path: '/subscription/:id',
          builder: (context, route) => SubscriptionDetailScreen(
            state: widget.state,
            id: route.pathParameters['id']!,
            onBack: context.pop,
          ),
        ),
        GoRoute(
          path: '/privacy',
          builder: (_, _) => const PrivacyPolicyScreen(),
        ),
        GoRoute(path: '/terms', builder: (_, _) => const TermsScreen()),
        GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
      ],
    );
    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => splashDone = true);
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.state.removeListener(_changed);
    router.dispose();
    super.dispose();
  }

  ThemeMode get themeMode => switch (widget.state.settings.themeMode) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  @override
  Widget build(BuildContext context) {
    AppAnimations.reduceMotion = widget.state.settings.reduceAnimations;
    if (!splashDone) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SublyTheme.light(),
        darkTheme: SublyTheme.dark(),
        themeMode: themeMode,
        builder: _buildWithSafeTextScale,
        home: const SplashScreen(),
      );
    }
    if (returningModerator) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SublyTheme.light(),
        darkTheme: SublyTheme.dark(),
        themeMode: themeMode,
        builder: _buildWithSafeTextScale,
        home: ModeratorWaitingScreen(state: widget.state),
      );
    }
    if (!widget.state.hasSeenOffers && !applicationFlowDone) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SublyTheme.light(),
        darkTheme: SublyTheme.dark(),
        themeMode: themeMode,
        builder: _buildWithSafeTextScale,
        home: ApplicationFlow(
          state: widget.state,
          onComplete: () => setState(() => applicationFlowDone = true),
        ),
      );
    }
    if (widget.state.hasSeenOffers) {
      // The regular user sees only the geo-targeted offer catalogue. Personal
      // finance tabs, calculator and settings belong to the moderator branch.
      return MaterialApp(
        title: 'Sumly',
        debugShowCheckedModeBanner: false,
        theme: SublyTheme.light(),
        darkTheme: SublyTheme.dark(),
        themeMode: themeMode,
        builder: _buildWithSafeTextScale,
        home: Scaffold(body: PartnersScreen(state: widget.state)),
      );
    }
    return MaterialApp.router(
      title: 'Sumly',
      debugShowCheckedModeBanner: false,
      theme: SublyTheme.light(),
      darkTheme: SublyTheme.dark(),
      themeMode: themeMode,
      builder: _buildWithSafeTextScale,
      routerConfig: router,
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    required this.state,
    required this.onOpenSubscription,
    super.key,
  });
  final AppState state;
  final ValueChanged<String> onOpenSubscription;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.state,
    builder: (context, _) => _buildShell(context),
  );

  Widget _buildShell(BuildContext context) {
    // Once the regular application flow finishes, its destination is always
    // the offers screen. An empty catalogue is rendered there as an explicit
    // error state instead of silently falling back to the personal dashboard.
    final hasPartners = widget.state.hasSeenOffers;
    final screens = [
      hasPartners
          ? PartnersScreen(state: widget.state)
          : HomeScreen(
              state: widget.state,
              onViewAll: () => setState(() => index = 1),
              onOpenSubscription: widget.onOpenSubscription,
            ),
      SubscriptionsScreen(
        state: widget.state,
        onOpenSubscription: widget.onOpenSubscription,
      ),
      const CalculatorScreen(),
      SettingsScreen(
        state: widget.state,
        onPrivacy: () => context.push('/privacy'),
        onTerms: () => context.push('/terms'),
        onAbout: () => context.push('/about'),
      ),
    ];
    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: AppAnimations.standard,
        switchInCurve: AppAnimations.curve,
        child: KeyedSubtree(
          key: ValueKey(index),
          child: IndexedStack(index: index, children: screens),
        ),
      ),
      bottomNavigationBar: _SublyBottomBar(
        index: index,
        hasPartners: hasPartners,
        onChanged: (value) {
          HapticFeedback.selectionClick();
          setState(() => index = value);
        },
      ),
    );
  }
}

class _SublyBottomBar extends StatelessWidget {
  const _SublyBottomBar({
    required this.index,
    required this.hasPartners,
    required this.onChanged,
  });
  final int index;
  final bool hasPartners;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        hasPartners ? Icons.handshake_rounded : Icons.home_rounded,
        hasPartners ? 'Партнёры' : 'Главная',
      ),
      (Icons.autorenew_rounded, 'Подписки'),
      (Icons.calculate_rounded, 'Расчёты'),
      (Icons.tune_rounded, 'Настройки'),
    ];
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: .45),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x260B0F19),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Row(
            children: List.generate(items.length, (itemIndex) {
              final selected = index == itemIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(itemIndex),
                  borderRadius: BorderRadius.circular(21),
                  child: AnimatedContainer(
                    duration: AppAnimations.standard,
                    curve: AppAnimations.curve,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? const LinearGradient(
                              colors: [SublyColors.purple, SublyColors.accent],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(21),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: SublyColors.purple.withValues(
                                  alpha: .28,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedScale(
                          scale: selected ? 1.12 : 1,
                          duration: AppAnimations.fast,
                          child: Icon(
                            items[itemIndex].$1,
                            color: selected
                                ? Colors.white
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            size: 23,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: AppAnimations.fast,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          child: Text(items[itemIndex].$2, maxLines: 1),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
