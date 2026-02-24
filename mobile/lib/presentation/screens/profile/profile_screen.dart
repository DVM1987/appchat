import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/user_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common/custom_avatar.dart';
import '../auth/phone_input_screen.dart';
import 'account_settings_screen.dart';
import 'edit_profile_screen.dart';
import 'help_support_screen.dart';
import 'privacy_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // Optional: If null, show current user

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _userService = UserService();
  final _picker = ImagePicker();
  bool _isUploading = false;
  Map<String, dynamic>? _profileData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (widget.userId == null) return; // Will use AuthProvider for self

    setState(() => _isLoading = true);
    try {
      final profile = await _userService.getUserProfile(widget.userId!);
      if (mounted) {
        setState(() {
          _profileData = profile;
        });
      }
    } catch (e) {
      AppConfig.log('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isSelf => widget.userId == null;

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      // 1. Upload Image
      final imageUrl = await _userService.uploadAvatar(image.path);
      if (imageUrl == null) throw Exception('Upload failed');

      // 2. Update Profile with new Avatar URL
      await _userService.updateProfile(avatarUrl: imageUrl);

      // 3. Save avatar URL locally and refresh AuthProvider
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_avatar', imageUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật ảnh đại diện thành công!')),
        );
        context.read<AuthProvider>().checkAuthStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _logout() async {
    print('[Profile] _logout pressed');
    try {
      context.read<UserProvider>().clear();
      context.read<ChatProvider>().clear();
      await context.read<AuthProvider>().logout();
    } catch (e) {
      print('[Profile] logout error (ignored): $e');
    }
    // Always navigate to login, even if logout had errors
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => PhoneInputScreen()));
    }
  }

  void _openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (result == true && mounted) {
      // Refresh profile after edit
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String name = _isSelf
        ? (authProvider.userName ?? 'Unknown')
        : (_profileData?['fullName'] ?? _profileData?['FullName'] ?? 'User');
    final String email = _isSelf
        ? (authProvider.userEmail ?? '')
        : (_profileData?['email'] ?? _profileData?['Email'] ?? '');
    String? avatarUrl = _isSelf
        ? authProvider.userAvatar
        : (_profileData?['avatarUrl'] ?? _profileData?['AvatarUrl']);

    if (avatarUrl != null && !avatarUrl.startsWith('http')) {
      avatarUrl = '${AuthService.baseUrl}$avatarUrl';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isSelf ? 'Hồ sơ cá nhân' : 'Thông tin người dùng'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          if (_isSelf)
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  // Avatar
                  CustomAvatar(imageUrl: avatarUrl, name: name, size: 120),

                  // Edit Button (Only for self)
                  if (_isSelf)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isUploading ? null : _pickAndUploadImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.background,
                              width: 2,
                            ),
                          ),
                          child: _isUploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Info Card (tappable to edit)
            GestureDetector(
              onTap: _isSelf ? () => _openEditProfile() : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    if (_isSelf) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Nhấn để chỉnh sửa hồ sơ',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            if (_isSelf) ...[
              // Settings Options
              _buildOptionItem(
                Icons.edit,
                'Chỉnh sửa hồ sơ',
                onTap: _openEditProfile,
              ),
              _buildOptionItem(
                Icons.settings,
                'Cài đặt tài khoản',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountSettingsScreen(),
                  ),
                ),
              ),
              _buildOptionItem(
                Icons.privacy_tip,
                'Quyền riêng tư',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacySettingsScreen(),
                  ),
                ),
              ),
              _buildOptionItem(
                Icons.help,
                'Trợ giúp & Hỗ trợ',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                ),
              ),
            ] else ...[
              _buildOptionItem(Icons.chat_outlined, 'Gửi tin nhắn'),
              _buildOptionItem(Icons.call_outlined, 'Gọi điện'),
              _buildOptionItem(Icons.block_outlined, 'Chặn người dùng'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSecondary),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textPlaceholder,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
