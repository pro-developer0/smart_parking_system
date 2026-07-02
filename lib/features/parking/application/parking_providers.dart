import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/parking_config.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/settings_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/application/auth_providers.dart';
import '../data/booking_repository.dart';
import '../domain/booking.dart';
import '../domain/parking_slot.dart';

/// All active bookings across the lot (server filtered by status == active).
final activeBookingsProvider = StreamProvider<List<Booking>>((ref) {
  return ref.watch(bookingRepositoryProvider).watchActiveBookings();
});

/// The signed-in user's full booking history (newest first).
final userBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(bookingRepositoryProvider).watchUserBookings(uid);
});

/// The user's single *live* booking (currently occupying its slot), or null.
/// Recomputed each tick so it clears itself the instant the window elapses.
final myLiveBookingProvider = Provider<Booking?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final now = ref.watch(tickerProvider).value ?? DateTime.now();
  final bookings = ref.watch(activeBookingsProvider).value ?? const [];
  for (final b in bookings) {
    if (b.userId == uid && b.isLive(now)) return b;
  }
  return null;
});

/// The user's booking scheduled to start later today, if any and if they
/// don't already have a live one.
final myUpcomingBookingProvider = Provider<Booking?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final now = ref.watch(tickerProvider).value ?? DateTime.now();
  final bookings = ref.watch(activeBookingsProvider).value ?? const [];
  Booking? soonest;
  for (final b in bookings) {
    if (b.userId != uid || !b.isUpcoming(now)) continue;
    if (soonest == null || b.startTime.isBefore(soonest.startTime)) {
      soonest = b;
    }
  }
  return soonest;
});

/// The user's current-or-next booking: live if one is active, otherwise the
/// soonest upcoming one, otherwise null.
final myBookingProvider = Provider<Booking?>((ref) {
  return ref.watch(myLiveBookingProvider) ?? ref.watch(myUpcomingBookingProvider);
});

/// The full lot as [SlotView]s with live status, re-derived every tick.
final slotViewsProvider = Provider<List<SlotView>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final now = ref.watch(tickerProvider).value ?? DateTime.now();
  final bookings = ref.watch(activeBookingsProvider).value ?? const [];

  // Map slotId -> the booking holding it, whether it has started yet or not.
  // A slot booked for later today is unavailable to everyone else right
  // away, not just once its window actually starts.
  final occupied = <String, Booking>{};
  for (final b in bookings) {
    if (b.status == BookingStatus.active && b.endTime.isAfter(now)) {
      occupied[b.slotId] = b;
    }
  }

  return ParkingConfig.slots.map((slot) {
    final booking = occupied[slot.id];
    final SlotStatus status;
    if (booking == null) {
      status = SlotStatus.available;
    } else if (booking.userId == uid) {
      status = SlotStatus.mine;
    } else {
      status = SlotStatus.occupied;
    }
    return SlotView(slot: slot, status: status, booking: booking);
  }).toList();
});

/// The current user's bookings that are still `active` in Firestore but whose
/// window has already elapsed — these need to be marked completed.
final _myExpiredBookingsProvider = Provider<List<Booking>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final now = ref.watch(tickerProvider).value ?? DateTime.now();
  final bookings = ref.watch(activeBookingsProvider).value ?? const [];
  return bookings.where((b) => b.userId == uid && b.hasExpired(now)).toList();
});

/// Side-effecting provider that marks the user's own expired bookings as
/// completed exactly once each. Kept alive by being watched in the home screen.
/// Availability is already correct via the `endTime` comparison — this just
/// keeps the database tidy so the active-bookings stream doesn't grow forever.
final bookingJanitorProvider = Provider<void>((ref) {
  final completing = <String>{};
  ref.listen<List<Booking>>(
    _myExpiredBookingsProvider,
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

/// Side-effecting provider that keeps the "booking ends soon" local
/// notification in sync with the user's live booking. Kept alive by being
/// watched in [MainScaffold]. Only reacts when the booking identity or the
/// notifications toggle actually changes, not on every ticker tick.
final bookingNotificationProvider = Provider<void>((ref) {
  String? scheduledForBookingId;

  void sync() {
    final enabled = ref.read(notificationsProvider);
    final booking = ref.read(myLiveBookingProvider);

    if (!enabled || booking == null) {
      if (scheduledForBookingId != null) {
        NotificationService.instance.cancelBookingNotification();
        scheduledForBookingId = null;
      }
      return;
    }

    if (scheduledForBookingId == booking.id) return;

    final notifyAt = booking.endTime.subtract(
      const Duration(minutes: ParkingConfig.notificationLeadMinutes),
    );
    if (notifyAt.isAfter(DateTime.now())) {
      NotificationService.instance.scheduleBookingNotification(
        slotId: booking.slotId,
        fireAt: notifyAt,
      );
      scheduledForBookingId = booking.id;
    } else if (scheduledForBookingId != null) {
      NotificationService.instance.cancelBookingNotification();
      scheduledForBookingId = null;
    }
  }

  ref.listen<Booking?>(
    myLiveBookingProvider,
    (_, __) => sync(),
    fireImmediately: true,
  );
  ref.listen<bool>(notificationsProvider, (_, __) => sync());
});

/// Quick counts for the header summary chips.
final slotCountsProvider = Provider<({int available, int occupied, int total})>(
  (ref) {
    final views = ref.watch(slotViewsProvider);
    final available = views.where((v) => v.isAvailable).length;
    return (
      available: available,
      occupied: views.length - available,
      total: views.length,
    );
  },
);
