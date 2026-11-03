import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../screens/07_admin/admin_screen.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../screens/02_auth/login_screen.dart';
import '../../screens/02_auth/signup_screen.dart';
import '../../screens/01_splash/splash_screen.dart';
import '../../screens/04_parking/booking_history_screen.dart';
import '../../screens/04_parking/my_booking_screen.dart';
import '../../screens/04_parking/parking_home_screen.dart';
import '../../screens/04_parking/slot_booking_screen.dart';
import '../../screens/05_profile/contact_screen.dart';
import '../../screens/05_profile/edit_profile_screen.dart';
import '../../screens/05_profile/profile_screen.dart';
import '../../screens/06_settings/settings_screen.dart';
import '../../screens/03_main_shell/main_scaffold.dart';
import 'route_names.dart';

/// Keeps the splash screen visible for at least this long, even if auth
/// resolves instantly, so it doesn't just flash on screen.
final _splashMinDurationProvider = FutureProvider<void>(
  (ref) => Future.delayed(const Duration(seconds: 2)),
);

/// Bridges a Riverpod stream into a [Listenable] so GoRouter re-evaluates
/// its redirect whenever auth state changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    // Re-check the route when auth changes, the splash time is up, or the
    // profile loads (so we know if this account is an admin).
    _subs = [
      ref.listen(authStateProvider, (_, _) => notifyListeners()),
      ref.listen(_splashMinDurationProvider, (_, _) => notifyListeners()),
      ref.listen(userProfileProvider, (_, _) => notifyListeners()),
    ];
  }
  late final List<ProviderSubscription> _subs;

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.close();
    }
    super.dispose();
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final splashElapsed = !ref.read(_splashMinDurationProvider).isLoading;

      // While the very first auth check is loading, or the splash's minimum
      // display time hasn't elapsed yet, stay on splash.
      if (authState.isLoading || !splashElapsed) return null;

      final user = authState.value;
      final loc = state.matchedLocation;
      final onAuthScreen = loc == Routes.login || loc == Routes.signup;
      final onSplash = loc == Routes.splash;
      final onAdmin = loc.startsWith(Routes.admin);

      if (user == null) {
        return onAuthScreen ? null : Routes.login;
      }

      // Wait until this user's profile has loaded, so we know their role.
      // (While it loads we stay where we are, e.g. on splash or login.)
      final profileAsync = ref.read(userProfileProvider);
      final profile = profileAsync.value;
      final profileReady = !profileAsync.isLoading &&
          (profile == null || profile.uid == user.uid);
      if (!profileReady) return null;

      final isAdmin = profile?.isAdmin ?? false;

      if (isAdmin) {
        // Admins use the admin panel (+ Settings for theme).
        if (onAdmin || loc == Routes.settings) return null;
        return Routes.admin;
      }

      // Normal users can never open the admin panel.
      if (onAdmin) return Routes.home;
      // Logged in but sitting on splash/auth → go home.
      if (onSplash || onAuthScreen) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.signup, builder: (_, _) => const SignupScreen()),
      // Home / History / Profile live behind a persistent bottom nav bar,
      // each keeping its own navigation stack when the user switches tabs.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainScaffold(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (_, _) => const ParkingHomeScreen(),
                routes: [
                  GoRoute(
                    path: Routes.bookingPath,
                    name: Routes.booking,
                    builder: (_, state) => SlotBookingScreen(
                      slotId: state.pathParameters['slotId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.history, builder: (_, _) => const BookingHistoryScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
            ],
          ),
        ],
      ),
      // Pushed full-screen above the nav bar rather than living in a tab.
      GoRoute(path: Routes.myBooking, builder: (_, _) => const MyBookingScreen()),
      GoRoute(path: Routes.editProfile, builder: (_, _) => const EditProfileScreen()),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(path: Routes.contact, builder: (_, _) => const ContactScreen()),
      // Admin panel: only reachable by accounts with role "admin"
      // (see the redirect above).
      GoRoute(path: Routes.admin, builder: (_, _) => const AdminScreen()),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});
