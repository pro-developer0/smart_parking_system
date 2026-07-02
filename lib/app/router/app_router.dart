import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/parking/presentation/booking_history_screen.dart';
import '../../features/parking/presentation/my_booking_screen.dart';
import '../../features/parking/presentation/parking_home_screen.dart';
import '../../features/parking/presentation/slot_booking_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../shell/main_scaffold.dart';
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
    _authSub = ref.listen(
      authStateProvider,
      (_, __) => notifyListeners(),
      fireImmediately: true,
    );
    _splashSub = ref.listen(
      _splashMinDurationProvider,
      (_, __) => notifyListeners(),
      fireImmediately: true,
    );
  }
  late final ProviderSubscription _authSub;
  late final ProviderSubscription _splashSub;

  @override
  void dispose() {
    _authSub.close();
    _splashSub.close();
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

      final loggedIn = authState.value != null;
      final loc = state.matchedLocation;
      final onAuthScreen = loc == Routes.login || loc == Routes.signup;
      final onSplash = loc == Routes.splash;

      if (!loggedIn) {
        return onAuthScreen ? null : Routes.login;
      }
      // Logged in but sitting on splash/auth → go home.
      if (onSplash || onAuthScreen) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.signup,
        builder: (_, __) => const SignupScreen(),
      ),
      // Home / History / Profile live behind a persistent bottom nav bar,
      // each keeping its own navigation stack when the user switches tabs.
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainScaffold(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (_, __) => const ParkingHomeScreen(),
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
              GoRoute(
                path: Routes.history,
                builder: (_, __) => const BookingHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // Pushed full-screen above the nav bar rather than living in a tab.
      GoRoute(
        path: Routes.myBooking,
        builder: (_, __) => const MyBookingScreen(),
      ),
      GoRoute(
        path: Routes.editProfile,
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});
