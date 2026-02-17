import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/auth_service.dart';

class CustomAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool showOnlineIndicator;
  final bool isOnline;

  const CustomAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 60,
    this.showOnlineIndicator = false,
    this.isOnline = false,
  });

  String get _fullImageUrl {
    if (imageUrl == null || imageUrl!.isEmpty) return '';

    String url = imageUrl!;

    // Check if absolute URL already
    if (url.startsWith('http')) {
      // Fix localhost for Android Emulator
      if (Platform.isAndroid && url.contains('localhost')) {
        url = url.replaceFirst('localhost', '10.0.2.2');
      }
      return url;
    }

    // Prepend Base URL to relative paths
    final baseUrl = AuthService.baseUrl;

    // Ensure clean slash handling
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = url.startsWith('/') ? url : '/$url';

    return '$cleanBaseUrl$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Avatar Circle
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceLight,
          ),
          child: ClipOval(
            child: _fullImageUrl.isNotEmpty
                ? Image.network(
                    _fullImageUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      AppConfig.log('Error loading avatar: $error');
                      return _buildInitials();
                    },
                  )
                : _buildInitials(),
          ),
        ),

        // Online Indicator
        if (showOnlineIndicator && isOnline)
          Positioned(
            right: 0,
            bottom: 4,
            child: Container(
              width: size / 3.2,
              height: size / 3.2,
              decoration: BoxDecoration(
                color: AppColors.onlineGreen,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitials() {
    return Container(
      color: AppColors.surfaceLight,
      alignment: Alignment.center,
      child: Text(
        _getInitials(name),
        style: TextStyle(
          fontSize: size / 2.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}
