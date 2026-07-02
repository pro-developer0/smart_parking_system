import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/parking_config.dart';
import '../../../core/providers/firebase_providers.dart';
import '../domain/booking.dart';

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
      });
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
    final newEnd = booking.endTime.add(extension);
    final maxEnd = booking.startTime
        .add(const Duration(minutes: ParkingConfig.maxBookingMinutes));
    if (newEnd.isAfter(maxEnd)) {
      throw BookingException(
        'That exceeds the maximum booking length. Please book again later.',
      );
    }

    await _firestore.runTransaction((txn) async {
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
      txn.update(ref, {'endTime': Timestamp.fromDate(newEnd)});
    });
  }

  /// Marks a booking completed (frees the slot). Used on manual "leave now"
  /// and when the client detects the window has elapsed.
  Future<void> completeBooking(String bookingId) async {
    await _bookings.doc(bookingId).update({
      'status': BookingStatus.completed.name,
    });
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
