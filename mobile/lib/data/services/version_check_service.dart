import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/app_config.dart';

/// Result of a version check against the backend.
class VersionCheckResult {
  final String latestVersion;
  final String minVersion;
  final String storeUrl;
  final String releaseNotes;
  final bool forceUpdate;
  final bool updateAvailable;

  VersionCheckResult({
    required this.latestVersion,
    required this.minVersion,
    required this.storeUrl,
    required this.releaseNotes,
    required this.forceUpdate,
    required this.updateAvailable,
  });

  factory VersionCheckResult.fromJson(Map<String, dynamic> json) {
    return VersionCheckResult(
      latestVersion: json['latestVersion'] ?? '1.0.0',
      minVersion: json['minVersion'] ?? '1.0.0',
      storeUrl: json['storeUrl'] ?? '',
      releaseNotes: json['releaseNotes'] ?? '',
      forceUpdate: json['forceUpdate'] ?? false,
      updateAvailable: json['updateAvailable'] ?? false,
    );
  }
}

/// Service to check if the app needs updating.
class VersionCheckService {
  /// Check the backend for version info.
  /// Returns null if the check fails (network error, etc.).
  static Future<VersionCheckResult?> check() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.0"
      final platform = Platform.isIOS ? 'ios' : 'android';

      // Version check endpoint is on the Identity service (port 5002),
      // not the Gateway (port 5001). Adjust the base URL accordingly.
      final baseUrl = AppConfig.apiBaseUrl.replaceFirst(':5001', ':5002');
      final url =
          '$baseUrl/api/v1/appversion/check?platform=$platform&currentVersion=$currentVersion';

      AppConfig.log('[VersionCheck] Checking: $url');

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = VersionCheckResult.fromJson(data);
        AppConfig.log(
          '[VersionCheck] latest=${result.latestVersion}, min=${result.minVersion}, '
          'force=${result.forceUpdate}, update=${result.updateAvailable}',
        );
        return result;
      }
    } catch (e) {
      AppConfig.log('[VersionCheck] Failed: $e');
    }
    return null;
  }
}
