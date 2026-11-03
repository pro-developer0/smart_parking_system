import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../../parking/application/parking_providers.dart';
import '../../parking/data/booking_repository.dart';
import '../../parking/domain/booking.dart';
import '../data/admin_repository.dart';

/// True when the signed-in user has `role: "admin"` in Firestore.
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(userProfileProvider).value?.isAdmin ?? false;
});

/// All registered users (admin panel → Users tab).
final allUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllUsers();
});

/// The latest 200 bookings of every user, newest first.
final recentBookingsProvider = StreamProvider<List<Booking>>((ref) {
  return ref.watch(bookingRepositoryProvider).watchRecentBookings();
});

/// Every booking that still holds a slot (parked now or starting later),
/// soonest first.
final adminActiveBookingsProvider = Provider<List<Booking>>((ref) {
  final now = ref.watch(tickerProvider).value ?? DateTime.now();
  final bookings = ref.watch(activeBookingsProvider).value ?? const [];
  return bookings.where((b) => b.endTime.isAfter(now)).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
});

/// Bookings of ALL users that are still `active` but whose time is over.
final _allExpiredBookingsProvider = Provider<List<Booking>>((ref) {
  final now = ref.watch(tickerProvider).value ?? DateTime.now();
  final bookings = ref.watch(activeBookingsProvider).value ?? const [];
  return bookings.where((b) => b.hasExpired(now)).toList();
});

/// While the admin panel is open, marks every user's expired booking as
/// completed (users only clean up their own when they open the app).
/// Watched by AdminScreen.
final adminJanitorProvider = Provider<void>((ref) {
  final completing = <String>{};
  ref.listen<List<Booking>>(
    _allExpiredBookingsProvider,
    (_, expired) {
      final repo = ref.read(bookingRepositoryProvider);
      for (final b in expired) {
        if (completing.add(b.id)) {
          repo.completeBooking(b.id).catchError((_) => completing.remove(b.id));
        }
      }
    },
    fireImmediately: true,
  );
});
