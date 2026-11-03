import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/parking_config.dart';

enum BookingStatus { active, completed, cancelled }

/// A reservation of a slot for a time window, stored at `bookings/{id}`.
class Booking {
  const Booking({
    required this.id,
    required this.slotId,
    required this.userId,
    required this.userName,
    required this.vehicleNumber,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.createdAt,
    this.bookedMinutes,
  });

  final String id;
  final String slotId;
  final String userId;
  final String userName;
  final String vehicleNumber;
  final DateTime startTime;
  final DateTime endTime;
  final BookingStatus status;
  final DateTime createdAt;

  /// Duration originally chosen when booking (before any extensions).
  /// Null for bookings made before this field existed.
  final int? bookedMinutes;

  Duration get totalDuration => endTime.difference(startTime);

  /// The originally booked length. Older bookings without the field fall
  /// back to their current length.
  Duration get bookedDuration =>
      bookedMinutes != null ? Duration(minutes: bookedMinutes!) : totalDuration;

  /// How much more time this booking may still be extended by.
  Duration get extensionLeft {
    final left = ParkingConfig.maxTotalDuration(bookedDuration) - totalDuration;
    return left.isNegative ? Duration.zero : left;
  }

  Duration remaining(DateTime now) {
    final diff = endTime.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// True while the reservation is actually occupying its slot right now
  /// (i.e. its window has started and not yet ended).
  bool isLive(DateTime now) =>
      status == BookingStatus.active &&
      !now.isBefore(startTime) &&
      endTime.isAfter(now);

  /// True for a booking scheduled to start later today.
  bool isUpcoming(DateTime now) =>
      status == BookingStatus.active && now.isBefore(startTime);

  bool hasExpired(DateTime now) =>
      status == BookingStatus.active && !endTime.isAfter(now);

  /// Fraction of the window elapsed, clamped to 0..1.
  double progress(DateTime now) {
    final total = totalDuration.inSeconds;
    if (total <= 0) return 1;
    final elapsed = now.difference(startTime).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Booking(
      id: doc.id,
      slotId: d['slotId'] as String,
      userId: d['userId'] as String,
      userName: (d['userName'] ?? '') as String,
      vehicleNumber: (d['vehicleNumber'] ?? '') as String,
      startTime: (d['startTime'] as Timestamp).toDate(),
      endTime: (d['endTime'] as Timestamp).toDate(),
      status: BookingStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => BookingStatus.active,
      ),
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bookedMinutes: (d['bookedMinutes'] as num?)?.toInt(),
    );
  }

  /// Like [Booking.fromDoc], but returns null instead of throwing for a
  /// missing/malformed document (e.g. hand-edited or partially-written data)
  /// so one bad doc doesn't take down an entire list for every user.
  static Booking? tryFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      return Booking.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }
}
