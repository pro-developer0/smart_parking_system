import 'booking.dart';
import 'slot_condition.dart';

/// Availability of a slot at a given moment.
/// [blocked] = the admin closed it (construction, maintenance, reserved...).
enum SlotStatus { available, occupied, mine, blocked }

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
    this.condition,
  });

  final ParkingSlot slot;
  final SlotStatus status;
  final Booking? booking;

  /// The admin's setting for this slot, when it is blocked.
  final SlotConditionInfo? condition;

  bool get isAvailable => status == SlotStatus.available;
  bool get isMine => status == SlotStatus.mine;
  bool get isBlocked => status == SlotStatus.blocked;
}
