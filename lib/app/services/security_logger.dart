import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:logger/logger.dart';

class SecurityLogger {
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final Logger _logger = Logger();

  static Future<void> logSuspiciousActivity({
    required String type,
    required String userId,
    required Map<String, dynamic> details,
  }) async {
    try {
      _logger.w('Suspicious Activity: $type by $userId');

      await _crashlytics.log('Suspicious Activity: $type');
      await _crashlytics.setCustomKey('user_id', userId);
      await _crashlytics.setCustomKey('activity_type', type);

      await _analytics.logEvent(
        name: 'suspicious_activity',
        parameters: {
          'type': type,
          'user_id': userId,
          ...details,
        },
      );
    } catch (e) {
      _logger.e('Failed to log suspicious activity', error: e);
    }
  }

  static Future<void> logLoginAttempt({
    required String email,
    required bool success,
    required String method,
  }) async {
    try {
      _logger
          .i('Login: $email via $method - ${success ? "SUCCESS" : "FAILED"}');
      await _analytics.logLogin(loginMethod: method);

      if (!success) {
        await _crashlytics.log('Failed login: $email');
      }
    } catch (e) {
      _logger.e('Failed to log login', error: e);
    }
  }
}
