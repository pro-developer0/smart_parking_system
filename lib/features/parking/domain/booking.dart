import 'package:cloud_firestore/cloud_firestore.dart';

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

  Duration get totalDuration => endTime.difference(startTime);

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
