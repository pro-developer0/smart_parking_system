import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper around `flutter_local_notifications` for the single
/// "your booking ends soon" reminder. Only one live booking can exist per
/// user at a time, so a fixed notification id is enough to identify it.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _reminderNotificationId = 9001;
  static const _channelId = 'booking_reminders';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
        macOS: iosInit,
      ),
    );
    _initialized = true;
  }

  /// Prompts the user for notification permission. Safe to call more than
  /// once; the OS only shows the prompt the first time.
  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Schedules a single reminder at [fireAt] for the booking in [slotId].
  /// Replaces any previously scheduled reminder (there's only ever one).
  Future<void> scheduleBookingReminder({
    required String slotId,
    required DateTime fireAt,
  }) async {
    if (!_initialized) await init();
    await _plugin.zonedSchedule(
      _reminderNotificationId,
      'Parking reminder',
      'Slot $slotId — your booking ends soon.',
      tz.TZDateTime.from(fireAt.toUtc(), tz.UTC),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Booking reminders',
          channelDescription: "Alerts before your parking booking ends",
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelBookingReminder() =>
      _plugin.cancel(_reminderNotificationId);
}
