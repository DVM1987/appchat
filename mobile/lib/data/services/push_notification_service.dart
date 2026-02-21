import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import 'auth_service.dart';

/// Handles Firebase background messages (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  AppConfig.log('[FCM] Background message: ${message.messageId}');
}

/// PushNotificationService manages Firebase Cloud Messaging (FCM)
/// for receiving push notifications when the app is in background/terminated.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Initialize FCM — call this from main.dart after Firebase.initializeApp()
  Future<void> initialize() async {
    // 1. Request notification permissions (iOS & Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    AppConfig.log('[FCM] Permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      AppConfig.log('[FCM] User denied notification permission');
      return;
    }

    // 2. Get FCM token (may fail on iOS if APNS entitlement not configured)
    try {
      _fcmToken = await _messaging.getToken();
      AppConfig.log('[FCM] Token: $_fcmToken');

      if (_fcmToken != null) {
        await _registerTokenWithBackend(_fcmToken!);
        await _saveTokenLocally(_fcmToken!);
      }
    } catch (e) {
      AppConfig.log('[FCM] Could not get token (APNS not configured?): $e');
      // App continues without push notifications
    }

    // 3. Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      AppConfig.log('[FCM] Token refreshed: $newToken');
      _fcmToken = newToken;
      await _registerTokenWithBackend(newToken);
      await _saveTokenLocally(newToken);
    });

    // 4. Setup foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. Setup message opened app handler (user tapped notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 6. Check if app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      AppConfig.log('[FCM] App opened from terminated state via notification');
      _handleMessageOpenedApp(initialMessage);
    }

    AppConfig.log('[FCM] Initialized successfully');
  }

  /// Handle foreground messages — show in-app notification
  void _handleForegroundMessage(RemoteMessage message) {
    AppConfig.log('[FCM] Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // Store notification data for later use by the UI
    _lastNotification = _NotificationData(
      title: notification.title ?? 'AppChat',
      body: notification.body ?? '',
      data: message.data,
    );

    // Notify listeners (HomeScreen, etc.)
    onForegroundNotification?.call(_lastNotification!);
  }

  /// Handle when user taps a notification (foreground or background)
  void _handleMessageOpenedApp(RemoteMessage message) {
    AppConfig.log('[FCM] Message opened app: ${message.data}');

    final data = message.data;
    final type = data['type'];

    switch (type) {
      case 'new_message':
        final conversationId = data['conversationId'];
        if (conversationId != null) {
          onNavigateToConversation?.call(conversationId);
        }
        break;
      case 'incoming_call':
        final callerId = data['callerId'];
        final callerName = data['callerName'] ?? 'Người dùng';
        final callType = data['callType'] ?? 'audio';
        if (callerId != null) {
          onIncomingCallNotification?.call(callerId, callerName, callType);
        }
        break;
      case 'friend_request':
        onNavigateToFriends?.call();
        break;
      default:
        AppConfig.log('[FCM] Unknown notification type: $type');
    }
  }

  /// Register FCM token with backend
  Future<void> _registerTokenWithBackend(String fcmToken) async {
    try {
      final authToken = await AuthService.getToken();
      if (authToken == null) return;

      final response = await http.post(
        Uri.parse('${AppConfig.userApiBaseUrl}/users/device-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'token': fcmToken, 'platform': _getPlatform()}),
      );

      if (response.statusCode == 200) {
        AppConfig.log('[FCM] Token registered with backend');
      } else {
        AppConfig.log('[FCM] Failed to register token: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.log('[FCM] Error registering token: $e');
    }
  }

  /// Save token locally
  Future<void> _saveTokenLocally(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  /// Get platform string
  String _getPlatform() {
    // Check for iOS or Android
    return WidgetsBinding
                .instance
                .platformDispatcher
                .views
                .first
                .platformDispatcher
                .defaultRouteName ==
            'ios'
        ? 'ios'
        : 'android';
  }

  // === Callbacks for UI to handle notifications ===
  void Function(_NotificationData notification)? onForegroundNotification;
  void Function(String conversationId)? onNavigateToConversation;
  void Function(String callerId, String callerName, String callType)?
  onIncomingCallNotification;
  VoidCallback? onNavigateToFriends;

  _NotificationData? _lastNotification;
}

class _NotificationData {
  final String title;
  final String body;
  final Map<String, dynamic> data;

  _NotificationData({
    required this.title,
    required this.body,
    required this.data,
  });
}
