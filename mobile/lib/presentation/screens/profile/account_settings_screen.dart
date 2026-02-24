import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../auth/phone_input_screen.dart';
import 'edit_profile_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  String _phoneNumber = '';
  String _userName = '';
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _phoneNumber = prefs.getString('phone_number') ?? '';
      _userName = prefs.getString('user_name') ?? '';
      _userId = prefs.getString('user_id') ?? '';
    });
  }

  void _openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (result == true && mounted) {
      _loadUserData();
    }
  }

  void _showDeleteAccountDialog() {
    final confirmController = TextEditingController();
    bool canDelete = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Xóa tài khoản',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ Hành động này không thể hoàn tác!',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Toàn bộ tin nhắn sẽ bị xóa\n'
                      '• Danh sách bạn bè sẽ bị xóa\n'
                      '• Nhóm chat sẽ bị xóa\n'
                      '• Lịch sử cuộc gọi sẽ bị xóa',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nhập "$_phoneNumber" để xác nhận:',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Nhập số điện thoại',
                  hintStyle: const TextStyle(color: AppColors.textPlaceholder),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  setDialogState(() {
                    canDelete = value.trim() == _phoneNumber;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Hủy',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: canDelete ? () => _deleteAccount(context) : null,
              child: Text(
                'Xóa tài khoản',
                style: TextStyle(
                  color: canDelete
                      ? AppColors.error
                      : AppColors.textPlaceholder,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext dialogContext) async {
    Navigator.pop(dialogContext); // Close dialog

    // Show loading
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 12),
            Text('Đang xóa tài khoản...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      context.read<UserProvider>().clear();
      context.read<ChatProvider>().clear();
      await context.read<AuthProvider>().logout();
    } catch (e) {
      // Ignore errors during cleanup
    }

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => PhoneInputScreen()));
    }
  }

  String _formatPhone(String phone) {
    if (phone.startsWith('+84') && phone.length >= 11) {
      return '+84 ${phone.substring(3, 6)} ${phone.substring(6, 9)} ${phone.substring(9)}';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final displayName = authProvider.userName ?? _userName;
    final displayPhone = authProvider.userEmail ?? _phoneNumber;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cài đặt tài khoản'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Info Section
            _buildSectionHeader('THÔNG TIN TÀI KHOẢN'),
            const SizedBox(height: 8),
            _buildInfoCard([
              _buildInfoRow(
                icon: Icons.phone_outlined,
                label: 'Số điện thoại',
                value: _formatPhone(displayPhone),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: displayPhone));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã sao chép số điện thoại'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),
              _buildDivider(),
              _buildInfoRow(
                icon: Icons.person_outline,
                label: 'Tên hiển thị',
                value: displayName,
                onTap: _openEditProfile,
              ),
              _buildDivider(),
              _buildInfoRow(
                icon: Icons.badge_outlined,
                label: 'ID người dùng',
                value: _userId.length > 12
                    ? '${_userId.substring(0, 12)}...'
                    : _userId,
                trailing: IconButton(
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _userId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã sao chép ID'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),
            ]),

            const SizedBox(height: 24),

            // Device Section
            _buildSectionHeader('THIẾT BỊ'),
            const SizedBox(height: 8),
            _buildInfoCard([
              _buildInfoRow(
                icon: Icons.phone_iphone,
                label: 'Thiết bị hiện tại',
                value:
                    '${Platform.operatingSystem.toUpperCase()} ${Platform.operatingSystemVersion.split(' ').first}',
              ),
              _buildDivider(),
              _buildInfoRow(
                icon: Icons.access_time,
                label: 'Phiên đang hoạt động',
                value: 'Đang trực tuyến',
                valueColor: AppColors.onlineGreen,
              ),
            ]),

            const SizedBox(height: 24),

            // Account Actions
            _buildSectionHeader('HÀNH ĐỘNG'),
            const SizedBox(height: 8),
            _buildInfoCard([
              _buildActionRow(
                icon: Icons.edit_outlined,
                label: 'Chỉnh sửa hồ sơ',
                onTap: _openEditProfile,
              ),
              _buildDivider(),
              _buildActionRow(
                icon: Icons.lock_outline,
                label: 'Đổi mã PIN',
                subtitle: 'Sắp ra mắt',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tính năng đang được phát triển'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                enabled: false,
              ),
            ]),

            const SizedBox(height: 24),

            // Danger zone
            _buildSectionHeader('VÙNG NGUY HIỂM'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showDeleteAccountDialog,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.delete_forever,
                      color: AppColors.error,
                      size: 24,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xóa tài khoản',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Xóa vĩnh viễn tài khoản và mọi dữ liệu',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.error,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ---- UI Helpers ----

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 52),
      child: Divider(height: 1, color: AppColors.divider),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
    VoidCallback? onTap,
    Color? valueColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: valueColor ?? AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
            if (onTap != null && trailing == null)
              const Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textPlaceholder,
                size: 14,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: enabled
                  ? AppColors.textSecondary
                  : AppColors.textPlaceholder,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textPlaceholder,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: enabled
                  ? AppColors.textPlaceholder
                  : AppColors.textPlaceholder.withValues(alpha: 0.3),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
