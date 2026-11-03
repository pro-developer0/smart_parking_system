import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/booking_repository.dart';
import '../domain/booking.dart';

/// Handles booking write-actions and surfaces loading/error state to the UI.
class BookingController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  BookingRepository get _repo => ref.read(bookingRepositoryProvider);

  Future<bool> book({
    required String slotId,
    required DateTime startTime,
    required Duration duration,
  }) async {
    final profile = ref.read(userProfileProvider).value;
    final uid = ref.read(currentUserIdProvider);
    if (uid == null || profile == null) {
      state = AsyncError(
        BookingException('You need to be signed in.'),
        StackTrace.current,
      );
      return false;
    }
    if (profile.suspended) {
      state = AsyncError(
        BookingException(
          'Your account is suspended from booking. '
          'Please contact the parking office.',
        ),
        StackTrace.current,
      );
      return false;
    }
    if (!profile.hasBookingDetails) {
      state = AsyncError(
        BookingException(
          'Please add your phone number and vehicle number in your '
          'profile before booking.',
        ),
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.bookSlot(
        slotId: slotId,
        userId: uid,
        userName: profile.name,
        vehicleNumber: profile.vehicleNumber,
        startTime: startTime,
        duration: duration,
      ),
    );
    return !state.hasError;
  }

  Future<bool> extend(Booking booking, Duration extension) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.extendBooking(booking: booking, extension: extension),
    );
    return !state.hasError;
  }

  Future<bool> endEarly(String bookingId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.completeBooking(bookingId));
    return !state.hasError;
  }

  Future<bool> cancel(String bookingId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.cancelBooking(bookingId));
    return !state.hasError;
  }
}

final bookingControllerProvider =
    AsyncNotifierProvider<BookingController, void>(
  BookingController.new,
);

String mapBookingError(Object error) {
  if (error is BookingException) return error.message;
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'You are not allowed to make this booking. '
        'Your account may be suspended.';
  }
  if (error is FirebaseException && error.code == 'aborted') {
    return 'Lots of people are booking right now. Please try again.';
  }
  return 'Something went wrong. Please try again.';
}
