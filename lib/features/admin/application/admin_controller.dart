import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../parking/application/parking_providers.dart';
import '../../parking/data/booking_repository.dart';
import '../../parking/data/slot_repository.dart';
import '../../parking/domain/booking.dart';
import '../../parking/domain/slot_condition.dart';
import '../../profile/data/profile_photo_repository.dart';
import '../data/admin_repository.dart';

/// Every action the admin can take. Screens call these and show a green or
/// red snackbar depending on the returned bool.
class AdminController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  String get _adminId => ref.read(currentUserIdProvider) ?? '';

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }

  /// Changes one or many slots (e.g. "A3" → construction).
  /// If [releaseBookings] is true, any booking holding those slots is ended
  /// (parked now) or cancelled (starts later) so the slot is really free.
  Future<bool> updateSlots({
    required List<String> slotIds,
    required SlotCondition condition,
    String note = '',
    DateTime? until,
    bool releaseBookings = false,
  }) {
    return _run(() async {
      if (releaseBookings && condition != SlotCondition.open) {
        final now = DateTime.now();
        final bookingRepo = ref.read(bookingRepositoryProvider);
        final holding = (ref.read(activeBookingsProvider).value ?? const [])
            .where((b) => slotIds.contains(b.slotId) && b.endTime.isAfter(now));
        for (final b in holding) {
          if (b.isUpcoming(now)) {
            await bookingRepo.cancelBooking(b.id);
          } else {
            await bookingRepo.completeBooking(b.id);
          }
        }
      }
      await ref.read(slotRepositoryProvider).setCondition(
            slotIds: slotIds,
            condition: condition,
            note: note,
            until: until,
            adminId: _adminId,
          );
    });
  }

  /// Opens every slot the admin had closed.
  Future<bool> reopenAllSlots() {
    final ids =
        (ref.read(slotConditionsProvider).value ?? const {}).keys.toList();
    if (ids.isEmpty) return Future.value(true);
    return updateSlots(slotIds: ids, condition: SlotCondition.open);
  }

  Future<bool> postAnnouncement(String message) => _run(
        () => ref
            .read(slotRepositoryProvider)
            .setAnnouncement(message: message, adminId: _adminId),
      );

  Future<bool> clearAnnouncement() =>
      _run(() => ref.read(slotRepositoryProvider).clearAnnouncement());

  /// Ends a booking now (user is parked) — the slot becomes free.
  Future<bool> endBooking(Booking booking) => _run(
      () => ref.read(bookingRepositoryProvider).completeBooking(booking.id));

  /// Cancels a booking (usually one that hasn't started yet).
  Future<bool> cancelBooking(Booking booking) => _run(
      () => ref.read(bookingRepositoryProvider).cancelBooking(booking.id));

  Future<bool> setUserSuspended(String uid, bool suspended) => _run(
      () => ref.read(adminRepositoryProvider).setSuspended(uid, suspended));

  /// Removes a user's profile picture (e.g. an inappropriate photo).
  Future<bool> removeUserPhoto(String uid) =>
      _run(() => ref.read(profilePhotoRepositoryProvider).removePhoto(uid));
}

final adminControllerProvider =
    AsyncNotifierProvider<AdminController, void>(AdminController.new);

String mapAdminError(Object? error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Permission denied. Check that your account has role "admin" '
        'and that firestore.rules is published.';
  }
  if (error is BookingException) return error.message;
  return 'Something went wrong. Please try again.';
}
