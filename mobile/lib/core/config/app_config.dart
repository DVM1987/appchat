// Application configuration for different environments.
//
// Usage:
//   - Development (default): `flutter run`
//   - Staging:    `flutter run --dart-define=ENV=staging`
//   - Production: `flutter run --dart-define=ENV=production`
//   - Custom URL: `flutter run --dart-define=API_BASE_URL=https://your-api.com`
//
// For AWS production, set your actual domain:
//   `flutter build apk --dart-define=ENV=production --dart-define=API_BASE_URL=https://api.your-domain.com`

import 'dart:io';

enum Environment { development, staging, production }

class AppConfig {
  static const String _envString = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  /// Override base URL via --dart-define=API_BASE_URL=https://...
  static const String _customBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static Environment get environment {
    switch (_envString.toLowerCase()) {
      case 'staging':
        return Environment.staging;
      case 'production':
      case 'prod':
        return Environment.production;
      default:
        return Environment.development;
    }
  }

  /// Main API base URL (Identity + API Gateway)
  static String get apiBaseUrl {
    if (_customBaseUrl.isNotEmpty) return _customBaseUrl;

    switch (environment) {
      case Environment.development:
        // Android emulator uses 10.0.2.2 to reach host machine
        return Platform.isAndroid
            ? 'http://10.0.2.2:5001'
            : 'http://localhost:5001';
      case Environment.staging:
        return 'https://staging-api.your-domain.com'; // TODO: Update with actual staging URL
      case Environment.production:
        return 'https://api.your-domain.com'; // TODO: Update with actual production URL
    }
  }

  /// Chat API REST base URL
  static String get chatApiBaseUrl => '$apiBaseUrl/api/v1';

  /// Chat SignalR Hub URL
  static String get chatHubUrl => '$apiBaseUrl/chatHub';

  /// Presence SignalR Hub URL
  static String get presenceHubUrl {
    if (_customBaseUrl.isNotEmpty) {
      // In production, all services go through the same gateway
      return '$_customBaseUrl/presenceHub';
    }

    switch (environment) {
      case Environment.development:
        return Platform.isAndroid
            ? 'http://10.0.2.2:5005/presenceHub'
            : 'http://localhost:5005/presenceHub';
      case Environment.staging:
        return 'https://staging-api.your-domain.com/presenceHub';
      case Environment.production:
        return 'https://api.your-domain.com/presenceHub';
    }
  }

  /// User SignalR Hub URL
  static String get userHubUrl {
    if (_customBaseUrl.isNotEmpty) {
      return '$_customBaseUrl/userHub';
    }

    switch (environment) {
      case Environment.development:
        return Platform.isAndroid
            ? 'http://10.0.2.2:5004/userHub'
            : 'http://localhost:5004/userHub';
      case Environment.staging:
        return 'https://staging-api.your-domain.com/userHub';
      case Environment.production:
        return 'https://api.your-domain.com/userHub';
    }
  }

  /// Presence REST base URL (for HTTP calls like GetPresence)
  static String get presenceApiBaseUrl {
    if (_customBaseUrl.isNotEmpty) return _customBaseUrl;

    switch (environment) {
      case Environment.development:
        return Platform.isAndroid
            ? 'http://10.0.2.2:5005'
            : 'http://localhost:5005';
      case Environment.staging:
        return 'https://staging-api.your-domain.com';
      case Environment.production:
        return 'https://api.your-domain.com';
    }
  }

  /// Whether the current environment is development
  static bool get isDevelopment => environment == Environment.development;

  /// Whether the current environment is production
  static bool get isProduction => environment == Environment.production;

  /// Debug logging — only in development
  static void log(String message) {
    if (isDevelopment) {
      // ignore: avoid_print
      print(message);
    }
  }
}
