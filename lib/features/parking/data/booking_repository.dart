import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/parking_config.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/utils/formatters.dart';
import '../domain/booking.dart';
import '../domain/slot_condition.dart';

/// Thrown for expected, user-facing booking failures.
class BookingException implements Exception {
  BookingException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Owns the `bookings` collection and all reservation rules.
class BookingRepository {
  BookingRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('bookings');

  /// Lock documents that make booking race-free.
  ///
  /// Firestore transactions on the client don't lock *query* results, so
  /// two people confirming the same slot at the same moment could both pass
  /// the "slot is free" check. Every booking/extension transaction therefore
  /// also reads and writes `bookingLocks/slot_<slotId>` (and
  /// `bookingLocks/user_<uid>` when booking). If two transactions touch the
  /// same lock, Firestore rejects the slower one and retries it, and the
  /// retry sees the booking the first one created, so only one succeeds.
  ///
  /// Requires the `bookingLocks` rule in `firestore.rules`.
  CollectionReference<Map<String, dynamic>> get _locks =>
      _firestore.collection('bookingLocks');

  DocumentReference<Map<String, dynamic>> _slotLock(String slotId) =>
      _locks.doc('slot_$slotId');

  DocumentReference<Map<String, dynamic>> _userLock(String userId) =>
      _locks.doc('user_$userId');

  Map<String, dynamic> _lockData(String userId) => {
        'by': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Streams every currently active booking (server-side filter).
  /// Client further filters by `endTime > now` for display, so an expired
  /// booking frees its slot even before it's marked completed.
  Stream<List<Booking>> watchActiveBookings() {
    return _bookings
        .where('status', isEqualTo: BookingStatus.active.name)
        .snapshots()
        .map((snap) => _decodeAll(snap.docs));
  }

  /// Streams the signed-in user's booking history (newest first).
  /// Sorted client-side rather than via a server-side `orderBy` so this
  /// doesn't depend on a composite Firestore index existing.
  Stream<List<Booking>> watchUserBookings(String userId) {
    return _bookings
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => _decodeAll(snap.docs)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  /// Decodes docs into [Booking]s, skipping any that are missing/malformed
  /// fields (e.g. hand-edited or partially-written docs) instead of letting
  /// one bad document take down the whole stream for every user.
  List<Booking> _decodeAll(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map(Booking.tryFromDoc).whereType<Booking>().toList();
  }

  /// Books [slotId] for [duration] starting at [startTime] (may be now or
  /// later today). Runs in a transaction so two users can't grab an
  /// overlapping window, and rejects if the user already holds a live or
  /// upcoming booking.
  Future<void> bookSlot({
    required String slotId,
    required String userId,
    required String userName,
    required String vehicleNumber,
    required DateTime startTime,
    required Duration duration,
  }) async {
    final now = DateTime.now();
    final end = startTime.add(duration);

    await _firestore.runTransaction((txn) async {
      // Read the locks first so concurrent bookings of this slot (or by
      // this user) conflict and get retried. See [_locks].
      await txn.get(_slotLock(slotId));
      await txn.get(_userLock(userId));

      // 0. The admin must not have closed this slot (construction etc.).
      final slotDoc =
          await txn.get(_firestore.collection('slots').doc(slotId));
      final condition = SlotConditionInfo.tryFromDoc(slotDoc);
      if (condition != null && condition.isActive(now)) {
        throw BookingException(
          'Slot $slotId is not available: ${condition.message}',
        );
      }

      // 1. Slot must be free for the whole requested window.
      final slotConflicts = await _bookings
          .where('slotId', isEqualTo: slotId)
          .where('status', isEqualTo: BookingStatus.active.name)
          .get();
      final overlaps = slotConflicts.docs
          .map(Booking.tryFromDoc)
          .whereType<Booking>()
          .where((b) => b.endTime.isAfter(now))
          .any((b) => startTime.isBefore(b.endTime) && end.isAfter(b.startTime));
      if (overlaps) {
        throw BookingException(
          'Sorry, that slot is not free for the selected time.',
        );
      }

      // 2. User may only hold one live/upcoming booking at a time.
      final userActive = await _bookings
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: BookingStatus.active.name)
          .get();
      final hasLive = userActive.docs
          .map(Booking.tryFromDoc)
          .whereType<Booking>()
          .any((b) => b.endTime.isAfter(now));
      if (hasLive) {
        throw BookingException('You already have an active booking.');
      }

      final ref = _bookings.doc();
      txn.set(ref, {
        'slotId': slotId,
        'userId': userId,
        'userName': userName,
        'vehicleNumber': vehicleNumber,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(end),
        'status': BookingStatus.active.name,
        'createdAt': FieldValue.serverTimestamp(),
        // Original length, used to limit extensions.
        'bookedMinutes': duration.inMinutes,
      });
      txn.set(_slotLock(slotId), _lockData(userId));
      txn.set(_userLock(userId), _lockData(userId));
    });
  }

  /// Extends a live booking by [extension]. Fails once the window has ended.
  Future<void> extendBooking({
    required Booking booking,
    required Duration extension,
  }) async {
    final now = DateTime.now();
    if (booking.hasExpired(now)) {
      throw BookingException(
        'This booking has ended and can no longer be extended.',
      );
    }
    _checkExtensionAllowed(booking, extension);

    await _firestore.runTransaction((txn) async {
      // Lock the slot so a booking for the time right after ours can't be
      // created while we extend into it (and vice versa).
      final lock = _slotLock(booking.slotId);
      await txn.get(lock);

      final ref = _bookings.doc(booking.id);
      final snap = await txn.get(ref);
      if (!snap.exists) throw BookingException('Booking no longer exists.');
      final current = Booking.tryFromDoc(snap);
      if (current == null) {
        throw BookingException('This booking could not be read.');
      }
      if (current.hasExpired(now)) {
        throw BookingException(
          'This booking has ended and can no longer be extended.',
        );
      }
      // Re-check with the latest data (an earlier extension may have
      // used up the allowance).
      _checkExtensionAllowed(current, extension);
      final newEnd = current.endTime.add(extension);

      // Someone else may have booked this slot starting after us.
      final others = await _bookings
          .where('slotId', isEqualTo: current.slotId)
          .where('status', isEqualTo: BookingStatus.active.name)
          .get();
      final clash = others.docs
          .map(Booking.tryFromDoc)
          .whereType<Booking>()
          .where((b) => b.id != current.id && b.endTime.isAfter(now))
          .where((b) =>
              current.endTime.isBefore(b.endTime) &&
              newEnd.isAfter(b.startTime))
          .map((b) => b.startTime)
          .fold<DateTime?>(
              null, (min, t) => min == null || t.isBefore(min) ? t : min);
      if (clash != null) {
        throw BookingException(
          'Slot ${current.slotId} is booked by someone else from '
          '${Formatters.smartTime(clash)}, so it can\'t be extended that far.',
        );
      }

      txn.update(ref, {'endTime': Timestamp.fromDate(newEnd)});
      txn.set(lock, _lockData(current.userId));
    });
  }

  /// Throws if adding [extension] goes past what [booking] may be extended
  /// to (see [ParkingConfig.maxTotalDuration]).
  void _checkExtensionAllowed(Booking booking, Duration extension) {
    final left = booking.extensionLeft;
    if (extension > left) {
      throw BookingException(
        left == Duration.zero
            ? 'This booking has reached its extension limit. '
                'Please make a new booking when it ends.'
            : 'You can only extend this booking by '
                '${Formatters.durationLabel(left)} more.',
      );
    }
  }

  /// Marks a booking completed (frees the slot). Used on manual "leave now"
  /// and when the client detects the window has elapsed.
  Future<void> completeBooking(String bookingId) async {
    await _bookings.doc(bookingId).update({
      'status': BookingStatus.completed.name,
    });
  }

  /// Latest bookings of ALL users, newest first (admin panel only).
  /// Uses a single-field orderBy, so no composite index is needed.
  Stream<List<Booking>> watchRecentBookings({int limit = 200}) {
    return _bookings
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => _decodeAll(snap.docs));
  }

  Future<void> cancelBooking(String bookingId) async {
    await _bookings.doc(bookingId).update({
      'status': BookingStatus.cancelled.name,
    });
  }
}

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(ref.watch(firestoreProvider));
});
