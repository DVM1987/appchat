// Application configuration for different environments.
//
// Usage:
//   - Development (default): `flutter run`
//   - Staging:    `flutter run --dart-define=ENV=staging`
//   - Production: `flutter run --dart-define=ENV=production`
//   - Custom URL: `flutter run --dart-define=API_BASE_URL=https://your-api.com`
//
// For production release APK:
//   `flutter build apk --dart-define=ENV=production`

import 'dart:io';

enum Environment { development, staging, production }

class AppConfig {
  // If app is built in release (dart.vm.product == true), default to production.
  // Devs can still override with --dart-define=ENV=staging|development.
  static const String _envRaw = String.fromEnvironment('ENV', defaultValue: '');

  static final String _envString = _envRaw.isNotEmpty
      ? _envRaw
      : (const bool.fromEnvironment('dart.vm.product')
            ? 'production'
            : 'development');

  /// Override base URL via --dart-define=API_BASE_URL=https://...
  static const String _customBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// VPS Production IP
  static const String _vpsHost = '139.180.217.83';

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

  /// Main API base URL (Identity/Gateway)
  static String get apiBaseUrl {
    if (_customBaseUrl.isNotEmpty) return _customBaseUrl;

    switch (environment) {
      case Environment.development:
        return Platform.isAndroid
            ? 'http://10.0.2.2:5001'
            : 'http://localhost:5001';
      case Environment.staging:
        return 'http://$_vpsHost:5001';
      case Environment.production:
        return 'http://$_vpsHost:5001';
    }
  }

  /// Chat API REST base URL
  static String get chatApiBaseUrl {
    if (_customBaseUrl.isNotEmpty) return '$_customBaseUrl/api/v1';
    switch (environment) {
      case Environment.development:
        return Platform.isAndroid
            ? 'http://10.0.2.2:5003/api/v1'
            : 'http://localhost:5003/api/v1';
      case Environment.staging:
        return 'http://$_vpsHost:5003/api/v1';
      case Environment.production:
        return 'http://$_vpsHost:5003/api/v1';
    }
  }

  /// Chat SignalR Hub URL
  static String get chatHubUrl {
    if (_customBaseUrl.isNotEmpty) return '$_customBaseUrl/chatHub';
    switch (environment) {
      case Environment.development:
        return Platform.isAndroid
            ? 'http://10.0.2.2:5003/chatHub'
            : 'http://localhost:5003/chatHub';
      case Environment.staging:
        return 'http://$_vpsHost:5003/chatHub';
      case Environment.production:
        return 'http://$_vpsHost:5003/chatHub';
    }
  }

  /// Presence SignalR Hub URL
  static String get presenceHubUrl {
    if (_customBaseUrl.isNotEmpty) return '$_customBaseUrl/presenceHub';

    switch (environment) {
      case Environment.development:
        return Platform.isAndroid
            ? 'http://10.0.2.2:5005/presenceHub'
            : 'http://localhost:5005/presenceHub';
      case Environment.staging:
        return 'http://$_vpsHost:5005/presenceHub';
      case Environment.production:
        return 'http://$_vpsHost:5005/presenceHub';
    }
  }

  /// User SignalR Hub URL
  static String get userHubUrl {
    if (_customBaseUrl.isNotEmpty) return '$_customBaseUrl/userHub';

    switch (environment) {
      case Environment.development:
        return Platform.isAndroid
            ? 'http://10.0.2.2:5004/userHub'
            : 'http://localhost:5004/userHub';
      case Environment.staging:
        return 'http://$_vpsHost:5004/userHub';
      case Environment.production:
        return 'http://$_vpsHost:5004/userHub';
    }
  }

  /// Presence REST base URL
  static String get presenceApiBaseUrl {
    if (_customBaseUrl.isNotEmpty) return _customBaseUrl;

    switch (environment) {
      case Environment.development:
        return Platform.isAndroid
            ? 'http://10.0.2.2:5005'
            : 'http://localhost:5005';
      case Environment.staging:
        return 'http://$_vpsHost:5005';
      case Environment.production:
        return 'http://$_vpsHost:5005';
    }
  }

  /// User API REST base URL
  static String get userApiBaseUrl {
    if (_customBaseUrl.isNotEmpty) return '$_customBaseUrl/api/v1';

    switch (environment) {
      case Environment.development:
        return Platform.isAndroid
            ? 'http://10.0.2.2:5004/api/v1'
            : 'http://localhost:5004/api/v1';
      case Environment.staging:
        return 'http://$_vpsHost:5004/api/v1';
      case Environment.production:
        return 'http://$_vpsHost:5004/api/v1';
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
