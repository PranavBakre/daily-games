import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// One local notification a day, scheduled on the device. No server, no
/// account, and it still fires when the phone was offline all week.
class Reminders {
  Reminders([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const notificationId = 900;
  static const channelId = 'daily-reminder';
  static const payload = 'daily';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  Future<void> init({void Function(String? payload)? onOpen}) async {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => onOpen?.call(response.payload),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  Future<void> scheduleDaily(int hour, int minute) async {
    if (!_ready) return;
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'Daily Games',
      body: 'Four puzzles are waiting.',
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        android: AndroidNotificationDetails(
          channelId,
          'Daily reminder',
          channelDescription: 'One reminder a day for the puzzles',
          icon: 'ic_notification',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  Future<void> cancel() async {
    await _plugin.cancel(id: notificationId);
  }

  Future<bool?> pending() async =>
      (await _plugin.pendingNotificationRequests())
          .any((request) => request.id == notificationId);
}
