import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'core/models.dart';
import 'core/session_controller.dart';
import 'core/theme.dart';
import 'core/widgets.dart';
import 'core/google_sign_in.dart';
import 'features/chat.dart';
import 'features/auth_screen.dart';
import 'features/insights.dart';
import 'features/onboarding.dart';
import 'features/plan.dart';
import 'features/profile.dart';
import 'features/sheets.dart';
import 'features/shop.dart';

class ValoraApp extends StatefulWidget {
  const ValoraApp({super.key, this.session});
  final SessionController? session;
  @override
  State<ValoraApp> createState() => _ValoraAppState();
}

class _ValoraAppState extends State<ValoraApp> with WidgetsBindingObserver {
  late final session = widget.session ?? SessionController();
  final _appLinks = AppLinks();
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.session != null) return;
    const apiUrl = String.fromEnvironment(
      'VALORA_API_URL',
      defaultValue:
          'https://valora-nebius-api.jadhav-rushikesh-ggl.workers.dev',
    );
    final isMobileApp =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (apiUrl.isNotEmpty && isMobileApp) {
      session.connectBackend(
        baseUrl: apiUrl,
        auth: GoogleSignInService(baseUrl: apiUrl),
      );
      _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
        session.handleAuthCallback(uri).catchError((_) {});
      });
      _appLinks.getInitialLink().then((uri) {
        if (uri != null) session.handleAuthCallback(uri).catchError((_) {});
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        session.signedIn &&
        session.onboarded) {
      unawaited(session.firstDayPlanner?.refresh());
    }
    if (state == AppLifecycleState.inactive &&
        session.hasUnsavedChanges &&
        session.onboarded) {
      session.saveAccountData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    session.backendApi?.close();
    session.googleSignIn?.close();
    if (widget.session == null) session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigatorKey,
    title: 'Valora',
    debugShowCheckedModeBanner: false,
    theme: valoraTheme(),
    builder: (context, child) => ListenableBuilder(
      listenable: session,
      builder: (context, _) => Column(
        children: [
          if (session.signedIn &&
              (session.savingAccount || session.hasUnsavedChanges))
            Material(
              color: session.saveError.isEmpty
                  ? ValoraColors.mint
                  : ValoraColors.amber,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.saveError.isNotEmpty
                              ? session.saveError
                              : session.savingAccount
                              ? 'Saving your changes…'
                              : 'Changes waiting to save',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      if (session.saveError.isNotEmpty)
                        TextButton(
                          onPressed:
                              session.savingAccount || session.foodReloading
                              ? null
                              : () async {
                                  if (session.foodConflict) {
                                    final dialogContext = _navigatorKey
                                        .currentState
                                        ?.overlay
                                        ?.context;
                                    if (dialogContext == null) return;
                                    final generation =
                                        session.accountGeneration;
                                    final discard = await showDialog<bool>(
                                      context: dialogContext,
                                      builder: (context) => AlertDialog(
                                        title: const Text(
                                          'Load saved food records?',
                                        ),
                                        content: const Text(
                                          'This replaces unsaved pantry, meal log and plan changes on this device with the version saved to your account. Profile changes stay here.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text(
                                              'Keep local edits',
                                            ),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Discard & load'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (discard == true &&
                                        generation == session.accountGeneration)
                                      await session.reloadSavedFoodRecords();
                                  } else if (session.onboarded) {
                                    await session.saveAccountData();
                                  } else {
                                    await session.completeOnboarding();
                                  }
                                },
                          child: Text(
                            session.foodReloading
                                ? 'Loading…'
                                : session.foodConflict
                                ? 'Load saved'
                                : 'Retry',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
    ),
    home: _PreviewFrame(child: _AppShell(session: session)),
  );
}

class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 700) return child;
      return ColoredBox(
        color: const Color(0xFFE8ECE4),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430, maxHeight: 940),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x201D2923),
                      blurRadius: 50,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _AppShell extends StatefulWidget {
  const _AppShell({required this.session});
  final SessionController session;
  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int tab = 0;
  bool reviewingProfile = false, shopping = false;
  void _plan() => setState(() {
    tab = 1;
    shopping = false;
  });
  void _panel(Panel panel) =>
      showPanel(context, widget.session, panel, onPlan: _plan);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final s = widget.session;
      if (s.backendApi != null && !s.authResolved) {
        return const Scaffold(
          backgroundColor: Color(0xFFF5F4EC),
          body: Center(
            child: CircularProgressIndicator(color: ValoraColors.forest),
          ),
        );
      }
      if (s.backendApi != null && !s.signedIn) {
        tab = 0;
        reviewingProfile = shopping = false;
        return AuthScreen(session: s);
      }
      if (s.backendApi != null && s.signedIn && !s.accountLoaded) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Wordmark(),
                    const SizedBox(height: 24),
                    if (s.accountLoading)
                      const CircularProgressIndicator()
                    else ...[
                      Text(
                        s.accountError.isEmpty
                            ? 'Load your saved details to continue.'
                            : s.accountError,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: s.loadAccountData,
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: s.signOut,
                        child: const Text('Sign out'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }
      if (!s.onboarded) {
        return reviewingProfile
            ? PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) setState(() => reviewingProfile = false);
                },
                child: ProfileConfirmation(
                  session: s,
                  onEdit: () => setState(() => reviewingProfile = false),
                ),
              )
            : OnboardingPage(
                session: s,
                onReview: () => setState(() => reviewingProfile = true),
              );
      }
      if (reviewingProfile && s.firstDayPlanner != null) {
        reviewingProfile = false;
        tab = 1;
      }
      final inConversation = tab == 0 && s.conversation;
      return PopScope(
        canPop: tab == 0 && !inConversation,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (inConversation)
            s.backToSpace();
          else if (tab == 1 && shopping)
            _plan();
          else
            setState(() => tab = 0);
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Wordmark(),
            leading: inConversation
                ? IconButton(
                    tooltip: 'Your space',
                    onPressed: s.backToSpace,
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                : tab == 1 && shopping
                ? IconButton(
                    tooltip: 'Back to plan',
                    onPressed: _plan,
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                : null,
            actions: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => _panel(Panel.notifications),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: ValoraColors.forest,
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: IndexedStack(
              index: tab,
              children: [
                ChatPage(session: s, onPlan: _plan, onPanel: _panel),
                shopping
                    ? ShopPage(session: s, onPanel: _panel, onBack: _plan)
                    : PlanPage(
                        session: s,
                        onPanel: _panel,
                        onRecipe: (type) => showRecipe(context, s, type),
                        onShop: () {
                          if (s.reviewPlan()) setState(() => shopping = true);
                        },
                      ),
                InsightsPage(session: s, onLog: () => showIntake(context, s)),
                ProfilePage(session: s, onPanel: _panel),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (value) => setState(() {
              tab = value;
            }),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded),
                label: 'Chat',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month_rounded),
                label: 'Plan',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart_rounded),
                label: 'Insights',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'You',
              ),
            ],
          ),
        ),
      );
    },
  );
}
