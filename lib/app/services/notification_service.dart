import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService extends GetxService {
  static const String _wib = 'Asia/Jakarta';
  // Schedule 4 weeks of individual absolute alarms (no matchDateTimeComponents)
  static const int _weeksAhead = 4;

  final _plugin = FlutterLocalNotificationsPlugin();
  final isNotificationEnabled = false.obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    final enabled = await _isEnabled();
    isNotificationEnabled.value = enabled;
    if (enabled) await scheduleWeekdayNotifications();
  }

  Future<void> toggleNotifications(bool enable) async {
    if (enable) {
      final granted = await _requestPermissions();
      if (!granted) {
        isNotificationEnabled.value = false;
        return;
      }
      isNotificationEnabled.value = true;
      await scheduleWeekdayNotifications();
    } else {
      isNotificationEnabled.value = false;
      await _plugin.cancelAll();
    }
  }

  // Schedule one alarm per occurrence for the next _weeksAhead weeks.
  // Uses absolute TZDateTime with no matchDateTimeComponents for Android 12+.
  Future<int> scheduleWeekdayNotifications() async {
    await _plugin.cancelAll();

    final loc = tz.getLocation(_wib);
    final now = tz.TZDateTime.now(loc);
    final canExact = await _canScheduleExact();

    int scheduled = 0;

    for (int week = 0; week < _weeksAhead; week++) {
      for (int wd = DateTime.monday; wd <= DateTime.friday; wd++) {
        final base = now.add(Duration(days: week * 7));
        final daysUntil = (wd - base.weekday + 7) % 7;

        final dayBase = tz.TZDateTime(
          loc,
          base.year,
          base.month,
          base.day + daysUntil,
        );

        final earlyTime = tz.TZDateTime(
          loc,
          dayBase.year,
          dayBase.month,
          dayBase.day,
          7,
          45,
          0,
        );
        final lateTime = tz.TZDateTime(
          loc,
          dayBase.year,
          dayBase.month,
          dayBase.day,
          8,
          15,
          0,
        );

        if (earlyTime.isAfter(now)) {
          await _scheduleAbsolute(
            id: _alarmId(week, wd, 0),
            title: 'Pengingat Absensi',
            body: 'Jangan lupa absen pagi sebelum jam 08:00',
            scheduledDate: earlyTime,
            canExact: canExact,
          );
          scheduled++;
        }

        if (lateTime.isAfter(now)) {
          await _scheduleAbsolute(
            id: _alarmId(week, wd, 1),
            title: 'Absen Terakhir!',
            body: 'Ini pengingat terakhir — segera lakukan absensi',
            scheduledDate: lateTime,
            canExact: canExact,
          );
          scheduled++;
        }
      }
    }

    return scheduled;
  }

  int _alarmId(int week, int weekday, int slot) =>
      week * 100 + weekday * 10 + slot;

  Future<void> _scheduleAbsolute({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required bool canExact,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'fineer_attendance',
      'Pengingat Absensi',
      channelDescription: 'Notifikasi pengingat absensi harian',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: canExact
          ? AndroidScheduleMode.alarmClock
          : AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // NO matchDateTimeComponents — absolute single alarm only
    );
  }

  Future<bool> _isEnabled() async {
    if (GetPlatform.isAndroid) {
      return await Permission.notification.isGranted;
    }
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.checkPermissions();
    return granted?.isEnabled ?? false;
  }

  Future<bool> _requestPermissions() async {
    if (GetPlatform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? false;
  }

  Future<bool> _canScheduleExact() async {
    if (!GetPlatform.isAndroid) return false;
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await impl?.canScheduleExactNotifications() ?? false;
  }
}
