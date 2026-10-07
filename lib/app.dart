import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/config.dart';
import 'core/i18n.dart';
import 'core/push.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'features/account/branches_screen.dart';
import 'features/account/callback_screen.dart';
import 'features/account/edit_profile_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/booking/booking_draft.dart';
import 'features/booking/checkout_screen.dart';
import 'features/booking/offers_screen.dart';
import 'features/contracts/contract_screen.dart';
import 'features/home/home_shell.dart';
import 'features/home/splash_screen.dart';
import 'features/invoices/invoices_screen.dart';
import 'features/reservations/reservation_screen.dart';
import 'features/self_service/self_service_screen.dart';

/// Screens anyone may open before signing in.
const _public = {'/login', '/register', '/callback'};

class CustomerApp extends StatefulWidget {
  const CustomerApp({super.key, required this.session, this.push});

  final Session session;
  final PushService? push;

  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    refreshListenable: widget.session,
    redirect: (context, state) {
      final session = widget.session;
      final at = state.matchedLocation;
      if (session.restoring) return at == '/splash' ? null : '/splash';
      if (!session.isSignedIn) return _public.contains(at) ? null : '/login';
      if (at == '/login' || at == '/register' || at == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/register',
        redirect: (_, state) => state.extra is RegistrationClaim ? null : '/login',
        builder: (_, state) => RegisterScreen(claim: state.extra! as RegistrationClaim),
      ),
      GoRoute(path: '/callback', builder: (_, _) => const CallbackScreen()),
      // Detail screens sit on top of home, so `go` to one keeps home underneath for "back".
      GoRoute(
        path: '/',
        builder: (_, state) => HomeShell(initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0),
        routes: [
          GoRoute(
            path: 'book/offers',
            redirect: (_, state) => state.extra is SearchDraft ? null : '/',
            builder: (_, state) => OffersScreen(search: state.extra! as SearchDraft),
          ),
          GoRoute(
            path: 'book/checkout',
            redirect: (_, state) => state.extra is CheckoutDraft ? null : '/',
            builder: (_, state) => CheckoutScreen(draft: state.extra! as CheckoutDraft),
          ),
          GoRoute(
            path: 'reservations/:id',
            builder: (_, state) => ReservationScreen(id: int.parse(state.pathParameters['id']!)),
          ),
          GoRoute(
            path: 'contracts/:id',
            builder: (_, state) => ContractScreen(id: int.parse(state.pathParameters['id']!)),
          ),
          GoRoute(
            path: 'self-service/:type/:id',
            builder: (_, state) => SelfServiceScreen(
              pickup: state.pathParameters['type'] == 'pickup',
              id: int.parse(state.pathParameters['id']!),
              minPhotos: int.tryParse(state.uri.queryParameters['photos'] ?? '') ?? 4,
            ),
          ),
          GoRoute(path: 'invoices', builder: (_, _) => const InvoicesScreen()),
          GoRoute(path: 'profile', builder: (_, _) => const EditProfileScreen()),
          GoRoute(path: 'branches', builder: (_, _) => const BranchesScreen()),
        ],
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    // A tapped notification opens its contract or the invoices once the renter is signed in.
    widget.push?.onOpen = (data) {
      final route = routeForPush(data);
      if (route != null && widget.session.isSignedIn) _router.push(route);
    };
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: AppLanguage.current,
    // A new key rebuilds every screen in the chosen language (and direction); the router keeps
    // the current page.
    builder: (context, language, _) => MaterialApp.router(
      key: ValueKey(language),
      title: AppConfig.companyName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: Locale(language),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: _router,
    ),
  );
}
