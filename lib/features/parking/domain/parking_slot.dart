import 'booking.dart';

/// Availability of a slot at a given moment.
enum SlotStatus { available, occupied, mine }

/// A physical parking slot. Definitions are static (see ParkingConfig); the
/// live status is derived by matching against active bookings.
class ParkingSlot {
  const ParkingSlot({
    required this.id,
    required this.section,
    required this.number,
  });

  final String id; // e.g. "A3"
  final String section; // "A"
  final int number; // 3

  String get label => id;
}

/// A slot paired with its currently-derived status and (optional) booking.
class SlotView {
  const SlotView({
    required this.slot,
    required this.status,
    this.booking,
  });

  final ParkingSlot slot;
  final SlotStatus status;
  final Booking? booking;

  bool get isAvailable => status == SlotStatus.available;
  bool get isMine => status == SlotStatus.mine;
}
