import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import 'auth_service.dart';

/// ─────────────────────────────────────────────
/// TOP-LEVEL background handler (required by FCM)
/// ─────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Show local notification even when app is terminated
  await PushNotificationService._showLocalNotification(message);
  AppConfig.log('[FCM] Background message handled: ${message.messageId}');
}

/// ─────────────────────────────────────────────
/// Flutter Local Notifications plugin instance (shared)
/// ─────────────────────────────────────────────
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// ─────────────────────────────────────────────
/// Android notification channel
/// ─────────────────────────────────────────────
const AndroidNotificationChannel _messageChannel = AndroidNotificationChannel(
  'appchat_messages', // must match backend AndroidNotification.ChannelId
  'Tin nhắn',
  description: 'Thông báo tin nhắn mới từ MChat',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

const AndroidNotificationChannel _callChannel = AndroidNotificationChannel(
  'appchat_calls',
  'Cuộc gọi',
  description: 'Thông báo cuộc gọi đến',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

/// ─────────────────────────────────────────────
/// PushNotificationService — singleton
/// ─────────────────────────────────────────────
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  // ════════════════════════════════════════════
  // INIT
  // ════════════════════════════════════════════
  Future<void> initialize() async {
    // ── 1. Request permission ──
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    AppConfig.log('[FCM] Permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      AppConfig.log('[FCM] User denied notification permission');
      return;
    }

    // ── 2. Setup local notifications (Android channel + init) ──
    await _setupLocalNotifications();

    // ── 3. Get FCM token (iOS needs APNs token first) ──
    try {
      if (Platform.isIOS) {
        // On iOS, we must wait for APNs token before getting FCM token
        // Paid Apple Developer account — APNs token should arrive
        String? apnsToken = await _messaging.getAPNSToken();
        int retries = 0;
        while (apnsToken == null && retries < 5) {
          AppConfig.log(
            '[FCM] Waiting for APNs token... attempt ${retries + 1}',
          );
          await Future.delayed(const Duration(seconds: 2));
          apnsToken = await _messaging.getAPNSToken();
          retries++;
        }
        if (apnsToken != null) {
          AppConfig.log(
            '[FCM] APNs token received: ${apnsToken.substring(0, 20)}...',
          );
        } else {
          AppConfig.log(
            '[FCM] APNs token not available after retries - push notifications may not work',
          );
          // Don't return — still try to get FCM token
        }
      }

      _fcmToken = await _messaging.getToken();
      AppConfig.log('[FCM] Got FCM token: ${_fcmToken?.substring(0, 20)}...');

      if (_fcmToken != null) {
        await _registerTokenWithBackend(_fcmToken!);
        await _saveTokenLocally(_fcmToken!);
      } else {
        AppConfig.log('[FCM] WARNING: FCM token is NULL!');
      }
    } catch (e) {
      AppConfig.log('[FCM] ERROR getting token: $e');
    }

    // ── 4. Token refresh ──
    _messaging.onTokenRefresh.listen((newToken) async {
      AppConfig.log('[FCM] Token refreshed');
      _fcmToken = newToken;
      await _registerTokenWithBackend(newToken);
      await _saveTokenLocally(newToken);
    });

    // ── 5. Foreground messages → show local notification ──
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // ── 6. User tapped notification → navigate ──
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // ── 7. App opened from terminated state via notification ──
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      AppConfig.log('[FCM] App opened from terminated notification');
      _handleMessageOpenedApp(initialMessage);
    }

    // ── 8. iOS foreground presentation ──
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    AppConfig.log('[FCM] Initialized successfully');
  }

  // ════════════════════════════════════════════
  // LOCAL NOTIFICATIONS SETUP
  // ════════════════════════════════════════════
  Future<void> _setupLocalNotifications() async {
    // Android initialization
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        final payload = response.payload;
        if (payload != null) {
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            _handleNotificationTap(data);
          } catch (e) {
            AppConfig.log('[Notification] Error parsing payload: $e');
          }
        }
      },
    );

    // Create Android notification channels
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_messageChannel);
      await androidPlugin.createNotificationChannel(_callChannel);
    }
  }

  // ════════════════════════════════════════════
  // FOREGROUND MESSAGE → show local notification
  // ════════════════════════════════════════════
  void _handleForegroundMessage(RemoteMessage message) {
    AppConfig.log('[FCM] Foreground message: ${message.notification?.title}');

    // Also show a local notification so it appears in the status bar
    _showLocalNotification(message);

    // Notify in-app listeners
    final notification = message.notification;
    if (notification == null) return;

    _lastNotification = NotificationData(
      title: notification.title ?? 'MChat',
      body: notification.body ?? '',
      data: message.data,
    );

    onForegroundNotification?.call(_lastNotification!);
  }

  // ════════════════════════════════════════════
  // SHOW LOCAL NOTIFICATION (works in all states)
  // ════════════════════════════════════════════
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title ?? 'MChat';
    final body = notification.body ?? '';

    // Determine channel based on notification type
    final type = message.data['type'] ?? '';
    final channelId = type == 'incoming_call'
        ? 'appchat_calls'
        : 'appchat_messages';
    final channelName = type == 'incoming_call' ? 'Cuộc gọi' : 'Tin nhắn';
    final importance = type == 'incoming_call'
        ? Importance.max
        : Importance.high;
    final priority = type == 'incoming_call' ? Priority.max : Priority.high;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: importance,
      priority: priority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
      category: type == 'incoming_call'
          ? AndroidNotificationCategory.call
          : AndroidNotificationCategory.message,
      groupKey: message.data['conversationId'] ?? 'appchat',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use a unique ID based on message
    final notificationId =
        message.messageId?.hashCode ??
        DateTime.now().millisecondsSinceEpoch % 100000;

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  // ════════════════════════════════════════════
  // NOTIFICATION TAP HANDLERS
  // ════════════════════════════════════════════
  void _handleMessageOpenedApp(RemoteMessage message) {
    AppConfig.log('[FCM] Message opened app: ${message.data}');
    _handleNotificationTap(message.data);
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
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

  // ════════════════════════════════════════════
  // BACKEND TOKEN REGISTRATION
  // ════════════════════════════════════════════
  Future<void> _registerTokenWithBackend(String fcmToken) async {
    try {
      final authToken = await AuthService.getToken();
      if (authToken == null) {
        AppConfig.log(
          '[FCM] WARNING: authToken is NULL, cannot register device token',
        );
        return;
      }

      final url = '${AppConfig.userApiBaseUrl}/users/device-token';
      AppConfig.log('[FCM] Registering token with backend: $url');
      AppConfig.log('[FCM] Auth token: ${authToken.substring(0, 20)}...');
      AppConfig.log('[FCM] FCM token: ${fcmToken.substring(0, 20)}...');
      AppConfig.log('[FCM] Platform: ${Platform.isIOS ? "ios" : "android"}');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'token': fcmToken,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      );

      AppConfig.log(
        '[FCM] Register response: ${response.statusCode} ${response.body}',
      );

      if (response.statusCode == 200) {
        AppConfig.log('[FCM] ✅ Token registered successfully!');
      } else {
        AppConfig.log(
          '[FCM] ❌ Failed to register token: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      AppConfig.log('[FCM] ❌ Error registering token: $e');
    }
  }

  /// Re-register FCM token after login (important for new/returning users)
  Future<void> reRegisterToken() async {
    AppConfig.log(
      '[FCM] reRegisterToken called, existing token: ${_fcmToken != null ? "YES" : "NO"}',
    );
    if (_fcmToken != null) {
      await _registerTokenWithBackend(_fcmToken!);
    } else {
      try {
        // On iOS, wait for APNs token first
        if (Platform.isIOS) {
          String? apnsToken = await _messaging.getAPNSToken();
          int retries = 0;
          while (apnsToken == null && retries < 2) {
            AppConfig.log(
              '[FCM] reRegister: waiting for APNs... attempt ${retries + 1}',
            );
            await Future.delayed(const Duration(seconds: 1));
            apnsToken = await _messaging.getAPNSToken();
            retries++;
          }
          if (apnsToken == null) {
            AppConfig.log('[FCM] reRegister: APNs not available, skipping');
            return;
          }
        }

        _fcmToken = await _messaging.getToken();
        AppConfig.log(
          '[FCM] reRegister got token: ${_fcmToken != null ? "YES" : "NO"}',
        );
        if (_fcmToken != null) {
          await _registerTokenWithBackend(_fcmToken!);
          await _saveTokenLocally(_fcmToken!);
        }
      } catch (e) {
        AppConfig.log('[FCM] Error re-registering token: $e');
      }
    }
  }

  Future<void> _saveTokenLocally(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  // ════════════════════════════════════════════
  // UI CALLBACKS
  // ════════════════════════════════════════════
  void Function(NotificationData notification)? onForegroundNotification;
  void Function(String conversationId)? onNavigateToConversation;
  void Function(String callerId, String callerName, String callType)?
  onIncomingCallNotification;
  VoidCallback? onNavigateToFriends;

  NotificationData? _lastNotification;
}

class NotificationData {
  final String title;
  final String body;
  final Map<String, dynamic> data;

  NotificationData({
    required this.title,
    required this.body,
    required this.data,
  });
}
