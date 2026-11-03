import '../../features/parking/domain/parking_slot.dart';

/// Static definition of the single parking lot this app manages.
///
/// Slots are pre-defined here rather than in Firestore because the physical
/// layout never changes at runtime — Firestore only tracks live *bookings*.
abstract class ParkingConfig {
  static const String lotName = 'Smart Parking System';
  static const String lotAddress = 'Level B1 · Blue Zone';

  /// Where users send complaints and questions (Profile → Contact us).
  static const String supportEmail = 'salaar1bro@gmail.com';

  /// Number of slots in each section, in display order.
  static const Map<String, int> slotsPerSection = {'A': 20, 'B': 10};

  /// Section keys (used in slot IDs) in display order.
  static final List<String> sections = slotsPerSection.keys.toList();

  /// Human-readable section names shown in the UI.
  static const Map<String, String> sectionNames = {
    'A': 'Motor Car / Jeep',
    'B': 'Motor Bike',
  };

  /// Number of CCTV cameras covering the lot (shown in the CCTV info).
  static const int cctvCameraCount = 6;

  /// Display name for a section key, falling back to "Section X".
  static String sectionName(String section) =>
      sectionNames[section] ?? 'Section $section';

  /// Section A has 20 slots, section B has 10 → 30 total.
  static final List<ParkingSlot> slots = [
    for (final entry in slotsPerSection.entries)
      for (var i = 1; i <= entry.value; i++)
        ParkingSlot(
          id: '${entry.key}$i',
          section: entry.key,
          number: i,
        ),
  ];

  /// Booking duration options offered to the user (in minutes).
  static const List<int> durationOptionsMinutes = [
    2, 60, 120, 180, 300, //
    1440, // 1 day
    10080, // 7 days
    43200, // 30 days
  ];

  /// Extension options offered while a booking is active (in minutes).
  static const List<int> extensionOptionsMinutes = [15, 30, 60];

  /// Absolute max time a single booking may span (including extensions).
  static const int maxBookingMinutes = 44640; // 31 days

  /// Extensions may add up to this share of the originally booked time...
  static const double extensionAllowanceFraction = 0.5;

  /// ...but always at least this much (so short bookings can still extend).
  static const int minExtensionAllowanceMinutes = 60;

  /// Longest a booking of [booked] length may become through extensions:
  /// booked + max(1 h, 50% of booked), never above [maxBookingMinutes].
  /// e.g. 1 h → 2 h, 5 h → 7 h 30 m, 1 day → 1 day 12 h, 30 days → 31 days.
  static Duration maxTotalDuration(Duration booked) {
    final share = Duration(
      minutes: (booked.inMinutes * extensionAllowanceFraction).round(),
    );
    const minAllowance = Duration(minutes: minExtensionAllowanceMinutes);
    final allowance = share > minAllowance ? share : minAllowance;
    final total = booked + allowance;
    const cap = Duration(minutes: maxBookingMinutes);
    return total > cap ? cap : total;
  }

  /// Default for how long before a booking ends to fire the "ending soon"
  /// notification. Users can change it in Settings.
  static const int notificationLeadMinutes = 1;

  /// Choices offered in Settings for the "ending soon" notification.
  static const List<int> notificationLeadOptionsMinutes = [1, 5, 10, 15, 30];
}
