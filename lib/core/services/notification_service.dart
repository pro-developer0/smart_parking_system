import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper around `flutter_local_notifications` for the single
/// "your booking ends soon" notification. Only one live booking can exist
/// per user at a time, so a fixed notification id is enough to identify it.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _notificationId = 9001;
  // A fresh channel id — Android locks in a channel's importance/sound the
  // first time it's created on a device, so reusing the old
  // 'booking_reminders' id here would silently keep whatever settings that
  // channel happened to get during earlier testing, no matter what we pass
  // below.
  static const _channelId = 'booking_notifications';

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

    // Create the channel explicitly (rather than relying on lazy creation
    // on first schedule) so its importance is set correctly from the start.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'Booking notifications',
            description: 'Notifies you shortly before your parking booking ends',
            importance: Importance.high,
          ),
        );
    _initialized = true;
  }

  /// Prompts the user for notification permission. Safe to call more than
  /// once; the OS only shows the prompt the first time.
  Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    // Lets the notification fire on time instead of being delayed by
    // Doze/battery optimizations. Android only shows this system prompt if
    // not already granted/denied; safe to call every session.
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {
      // Older plugin/OS combos may not support this — inexact fallback
      // below still delivers the notification, just possibly a bit late.
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Schedules a single notification at [fireAt] for the booking in
  /// [slotId]. Replaces any previously scheduled one (there's only ever
  /// one). Tries exact timing first (so it isn't delayed by Doze/battery
  /// optimizations) and falls back to inexact if the OS won't allow it.
  Future<void> scheduleBookingNotification({
    required String slotId,
    required DateTime fireAt,
  }) async {
    if (!_initialized) await init();
    final when = tz.TZDateTime.from(fireAt.toUtc(), tz.UTC);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Booking notifications',
        channelDescription: 'Notifies you shortly before your parking booking ends',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        _notificationId,
        'Parking notification',
        'Slot $slotId — your booking ends soon.',
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Exact notification scheduling failed ($e), using inexact.');
      await _plugin.zonedSchedule(
        _notificationId,
        'Parking notification',
        'Slot $slotId — your booking ends soon.',
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelBookingNotification() => _plugin.cancel(_notificationId);
}
