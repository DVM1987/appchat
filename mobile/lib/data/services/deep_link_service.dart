import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import 'chat_service.dart';

/// Handles deep links for the app.
/// Supported schemes:
///   - appchat://join?token=XXX → Join a group conversation via invite token
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  /// Stream controller for incoming deep links
  final _deepLinkController = StreamController<Uri>.broadcast();
  Stream<Uri> get deepLinkStream => _deepLinkController.stream;

  Uri? _initialLink;
  Uri? get initialLink => _initialLink;

  /// Push a new deep link URI (called from platform-specific code)
  void onNewLink(String link) {
    final uri = Uri.tryParse(link);
    if (uri != null) {
      AppConfig.log('[DeepLink] Received link: $link');
      _deepLinkController.add(uri);
    }
  }

  /// Parse a deep link URI and extract its parameters
  static DeepLinkData? parse(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'appchat') return null;

    final host = uri.host.toLowerCase();

    switch (host) {
      case 'join':
        final token = uri.queryParameters['token'];
        if (token != null && token.isNotEmpty) {
          return DeepLinkData(type: DeepLinkType.joinGroup, token: token);
        }
        break;
    }

    return null;
  }

  /// Handle a deep link URI in the given BuildContext
  static Future<void> handleDeepLink(BuildContext context, Uri uri) async {
    final data = parse(uri);
    if (data == null) {
      AppConfig.log('[DeepLink] Unknown deep link: $uri');
      return;
    }

    switch (data.type) {
      case DeepLinkType.joinGroup:
        AppConfig.log('[DeepLink] Joining group with token: ${data.token}');
        _showJoinGroupDialog(context, data.token!);
        break;
    }
  }

  /// Show a confirmation dialog before joining a group
  static void _showJoinGroupDialog(BuildContext context, String token) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.group_add, color: Colors.blue),
            SizedBox(width: 8),
            Text('Tham gia nhóm'),
          ],
        ),
        content: const Text(
          'Bạn đã nhận được lời mời tham gia nhóm.\nBạn có muốn tham gia không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _joinGroup(context, token);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Tham gia'),
          ),
        ],
      ),
    );
  }

  /// Actually join the group via ChatService
  static Future<void> _joinGroup(BuildContext context, String token) async {
    try {
      final chatService = ChatService();
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('fullName') ?? 'Thành viên';

      final conversationId = await chatService.joinConversationByToken(
        token,
        name,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Đã tham gia nhóm thành công!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        AppConfig.log('[DeepLink] Joined group: $conversationId');
      }
    } catch (e) {
      AppConfig.log('[DeepLink] Error joining group: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tham gia nhóm: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void dispose() {
    _deepLinkController.close();
  }
}

enum DeepLinkType { joinGroup }

class DeepLinkData {
  final DeepLinkType type;
  final String? token;

  DeepLinkData({required this.type, this.token});
}
