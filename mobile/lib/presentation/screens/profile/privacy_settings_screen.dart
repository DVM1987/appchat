import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  // Privacy settings with defaults
  bool _hideOnlineStatus = false;
  bool _hideLastSeen = false;
  bool _appLockEnabled = false;
  String _avatarVisibility = 'everyone'; // everyone, friends, nobody
  String _groupPermission = 'everyone'; // everyone, friends
  bool _readReceipts = true;
  final List<String> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hideOnlineStatus = prefs.getBool('privacy_hide_online') ?? false;
      _hideLastSeen = prefs.getBool('privacy_hide_last_seen') ?? false;
      _appLockEnabled = prefs.getBool('privacy_app_lock') ?? false;
      _avatarVisibility =
          prefs.getString('privacy_avatar_visibility') ?? 'everyone';
      _groupPermission =
          prefs.getString('privacy_group_permission') ?? 'everyone';
      _readReceipts = prefs.getBool('privacy_read_receipts') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quyền riêng tư'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Online Status Section
            _buildSectionHeader('TRẠNG THÁI TRỰC TUYẾN'),
            const SizedBox(height: 8),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.circle,
                iconColor: AppColors.onlineGreen,
                title: 'Ẩn trạng thái online',
                subtitle: 'Người khác sẽ không biết bạn đang online',
                value: _hideOnlineStatus,
                onChanged: (val) {
                  setState(() => _hideOnlineStatus = val);
                  _saveSetting('privacy_hide_online', val);
                },
              ),
              _buildCardDivider(),
              _buildSwitchTile(
                icon: Icons.access_time,
                iconColor: AppColors.textSecondary,
                title: 'Ẩn lần truy cập cuối',
                subtitle: 'Không hiện "Truy cập lúc..." cho người khác',
                value: _hideLastSeen,
                onChanged: (val) {
                  setState(() => _hideLastSeen = val);
                  _saveSetting('privacy_hide_last_seen', val);
                },
              ),
            ]),

            const SizedBox(height: 24),

            // Visibility Section
            _buildSectionHeader('HIỂN THỊ'),
            const SizedBox(height: 8),
            _buildSettingsCard([
              _buildDropdownTile(
                icon: Icons.account_circle_outlined,
                title: 'Ảnh đại diện',
                subtitle: 'Ai có thể xem ảnh đại diện của bạn',
                value: _avatarVisibility,
                options: const {
                  'everyone': 'Tất cả mọi người',
                  'friends': 'Chỉ bạn bè',
                  'nobody': 'Không ai cả',
                },
                onChanged: (val) {
                  setState(() => _avatarVisibility = val);
                  _saveSetting('privacy_avatar_visibility', val);
                },
              ),
              _buildCardDivider(),
              _buildSwitchTile(
                icon: Icons.done_all,
                iconColor: AppColors.messageRead,
                title: 'Xác nhận đã đọc',
                subtitle: 'Hiện dấu tích xanh khi bạn đọc tin nhắn',
                value: _readReceipts,
                onChanged: (val) {
                  setState(() => _readReceipts = val);
                  _saveSetting('privacy_read_receipts', val);
                },
              ),
            ]),

            const SizedBox(height: 24),

            // Groups Section
            _buildSectionHeader('NHÓM & KÊNH'),
            const SizedBox(height: 8),
            _buildSettingsCard([
              _buildDropdownTile(
                icon: Icons.group_outlined,
                title: 'Ai có thể thêm tôi vào nhóm',
                subtitle: 'Kiểm soát ai có thể thêm bạn vào nhóm chat',
                value: _groupPermission,
                options: const {
                  'everyone': 'Tất cả mọi người',
                  'friends': 'Chỉ bạn bè',
                },
                onChanged: (val) {
                  setState(() => _groupPermission = val);
                  _saveSetting('privacy_group_permission', val);
                },
              ),
            ]),

            const SizedBox(height: 24),

            // Security Section
            _buildSectionHeader('BẢO MẬT'),
            const SizedBox(height: 8),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.fingerprint,
                iconColor: AppColors.primary,
                title: 'Khóa ứng dụng',
                subtitle: _appLockEnabled
                    ? 'Yêu cầu xác thực khi mở ứng dụng'
                    : 'Bảo vệ ứng dụng bằng vân tay / FaceID',
                value: _appLockEnabled,
                onChanged: (val) {
                  setState(() => _appLockEnabled = val);
                  _saveSetting('privacy_app_lock', val);
                  if (val) {
                    _showAppLockInfo();
                  }
                },
              ),
            ]),

            const SizedBox(height: 24),

            // Blocked Users Section
            _buildSectionHeader('NGƯỜI BỊ CHẶN'),
            const SizedBox(height: 8),
            _buildSettingsCard([
              _buildActionTile(
                icon: Icons.block,
                iconColor: AppColors.error,
                title: 'Danh sách chặn',
                subtitle: _blockedUsers.isEmpty
                    ? 'Không có người dùng nào bị chặn'
                    : '${_blockedUsers.length} người dùng bị chặn',
                onTap: () => _showBlockedUsersList(),
              ),
            ]),

            const SizedBox(height: 32),

            // Info note
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Một số cài đặt quyền riêng tư chỉ có hiệu lực trên thiết bị này. '
                      'Các cài đặt nâng cao sẽ được đồng bộ trong phiên bản tương lai.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showAppLockInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.fingerprint, color: AppColors.primary, size: 28),
            SizedBox(width: 12),
            Text(
              'Khóa ứng dụng',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Khóa ứng dụng đã được bật. Mỗi lần mở MChat, bạn sẽ cần xác thực '
          'bằng vân tay hoặc Face ID.\n\n'
          'Lưu ý: Tính năng này sẽ được tích hợp đầy đủ trong phiên bản tiếp theo.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Đã hiểu',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockedUsersList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textPlaceholder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.block, color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Không có người dùng nào bị chặn',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Khi bạn chặn ai đó, họ sẽ không thể gửi tin nhắn\nhoặc gọi điện cho bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceLight,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Đóng'),
              ),
            ),
            const SizedBox(height: 10),
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

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildCardDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 52),
      child: Divider(height: 1, color: AppColors.divider),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
              inactiveThumbColor: AppColors.textPlaceholder,
              inactiveTrackColor: AppColors.surfaceLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    return InkWell(
      onTap: () => _showDropdownSheet(title, value, options, onChanged),
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
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    options[value] ?? value,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _buildActionTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
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

  void _showDropdownSheet(
    String title,
    String currentValue,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textPlaceholder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...options.entries.map((entry) {
              final isSelected = entry.key == currentValue;
              return InkWell(
                onTap: () {
                  onChanged(entry.key);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
