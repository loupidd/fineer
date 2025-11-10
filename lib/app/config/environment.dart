class Environment {
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';

  // Configuration
  static int get sessionTimeoutHours => 8;
  static Duration get rateLimitWindow => const Duration(minutes: 1);
  static int get maxAttendanceAttempts => 3;
}
