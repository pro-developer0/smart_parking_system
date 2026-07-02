import '../../features/parking/domain/parking_slot.dart';

/// Static definition of the single parking lot this app manages.
///
/// Slots are pre-defined here rather than in Firestore because the physical
/// layout never changes at runtime — Firestore only tracks live *bookings*.
abstract class ParkingConfig {
  static const String lotName = 'Qurtuba University Parking';
  static const String lotAddress = 'Level B1 · Blue Zone';

  /// Two sections (A and B), 10 slots each → 20 total.
  static final List<ParkingSlot> slots = [
    for (final section in ['A', 'B'])
      for (var i = 1; i <= 10; i++)
        ParkingSlot(
          id: '$section$i',
          section: section,
          number: i,
        ),
  ];

  /// Booking duration options offered to the user (in minutes).
  static const List<int> durationOptionsMinutes = [2, 60, 120, 180, 300];

  /// Extension options offered while a booking is active (in minutes).
  static const List<int> extensionOptionsMinutes = [15, 30, 60];

  /// Max total time a single booking may span, to keep turnover healthy.
  static const int maxBookingMinutes = 480; // 8 hours

  /// How long before a booking ends to fire the "ending soon" notification.
  static const int notificationLeadMinutes = 1;
}
