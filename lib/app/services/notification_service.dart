import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final _logger = Logger();

// Top-level function for background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  _logger.i('Handling background message: ${message.messageId}');
}

class NotificationService extends GetxService {
  static NotificationService get instance => Get.find<NotificationService>();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RxBool isNotificationEnabled = false.obs;

  Future<NotificationService> init() async {
    try {
      // Initialize timezone
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

      // Request permissions
      await _requestPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Initialize FCM
      await _initializeFCM();

      // Load user preference
      await _loadNotificationPreference();

      _logger.i('NotificationService initialized successfully');
    } catch (e) {
      _logger.e('Error initializing NotificationService', error: e);
    }
    return this;
  }

  Future<void> _requestPermissions() async {
    // Request notification permission
    final notificationStatus = await Permission.notification.request();

    if (notificationStatus.isGranted) {
      _logger.i('Notification permission granted');

      // Request FCM permission (iOS)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      _logger.i('FCM Permission status: ${settings.authorizationStatus}');
    } else {
      _logger.w('Notification permission denied');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _logger.i('Local notifications initialized');
  }

  Future<void> _initializeFCM() async {
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.i('Received foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.i('Notification opened app: ${message.notification?.title}');
      _handleNotificationTap(message);
    });

    // Get FCM token
    String? token = await _fcm.getToken();
    if (token != null) {
      _logger.i('FCM Token: $token');
      await _saveFCMToken(token);
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen(_saveFCMToken);
  }

  Future<void> _saveFCMToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('pegawai').doc(user.uid).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        _logger.i('FCM token saved to Firestore');
      }
    } catch (e) {
      _logger.e('Error saving FCM token', error: e);
    }
  }

  Future<void> _loadNotificationPreference() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('pegawai').doc(user.uid).get();
        isNotificationEnabled.value =
            doc.data()?['notificationsEnabled'] ?? false;

        if (isNotificationEnabled.value) {
          await scheduleWeekdayNotifications();
        }
      }
    } catch (e) {
      _logger.e('Error loading notification preference', error: e);
    }
  }

  Future<void> toggleNotifications(bool enabled) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('pegawai').doc(user.uid).update({
          'notificationsEnabled': enabled,
        });

        isNotificationEnabled.value = enabled;

        if (enabled) {
          await scheduleWeekdayNotifications();
          Get.snackbar(
            'Notifications Enabled',
            'You will receive daily reminders at 08:00 WIB',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Get.theme.primaryColor,
            colorText: Get.theme.colorScheme.onPrimary,
          );
        } else {
          await cancelAllNotifications();
          Get.snackbar(
            'Notifications Disabled',
            'Daily reminders have been turned off',
            snackPosition: SnackPosition.BOTTOM,
          );
        }

        _logger.i('Notifications ${enabled ? "enabled" : "disabled"}');
      }
    } catch (e) {
      _logger.e('Error toggling notifications', error: e);
      Get.snackbar(
        'Error',
        'Failed to update notification settings',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    }
  }

  Future<void> scheduleWeekdayNotifications() async {
    try {
      // Cancel existing notifications first
      await _localNotifications.cancelAll();

      final now = tz.TZDateTime.now(tz.getLocation('Asia/Jakarta'));

      // Schedule for Monday to Friday (1-5)
      for (int weekday = DateTime.monday;
          weekday <= DateTime.friday;
          weekday++) {
        await _scheduleDailyNotification(weekday, now);
      }

      _logger.i('Scheduled weekday notifications (Mon-Fri at 08:00 WIB)');
    } catch (e) {
      _logger.e('Error scheduling notifications', error: e);
    }
  }

  Future<void> _scheduleDailyNotification(
      int weekday, tz.TZDateTime now) async {
    // Find next occurrence of this weekday at 08:00
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.getLocation('Asia/Jakarta'),
      now.year,
      now.month,
      now.day,
      8, // 08:00 WIB
      0,
      0,
    );

    // Adjust to next occurrence of the target weekday
    while (scheduledDate.weekday != weekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'attendance_reminder',
      'Attendance Reminders',
      channelDescription: 'Daily reminders to mark attendance',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      weekday, // Use weekday as ID (1-5)
      'Attendance Reminder',
      'Don\'t forget to mark your attendance today! 📋',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    _logger.i(
        'Scheduled notification for ${_getWeekdayName(weekday)} at ${scheduledDate.toString()}');
  }

  String _getWeekdayName(int weekday) {
    const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    return days[weekday];
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
    _logger.i('Cancelled all notifications');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Notifications',
      channelDescription: 'General notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? '',
      details,
      payload: message.data.toString(),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    _logger.i('Notification tapped: ${response.payload}');
    // Navigate to home or attendance screen
    Get.toNamed('/home');
  }

  void _handleNotificationTap(RemoteMessage message) {
    _logger.i('Handling notification tap: ${message.data}');
    // Navigate based on notification data
    Get.toNamed('/home');
  }

  // Show immediate test notification
  Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Test notification channel',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      999,
      'Test Notification',
      'This is a test notification from Fineer!',
      details,
    );
  }
}
