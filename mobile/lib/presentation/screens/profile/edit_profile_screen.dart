import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/user_service.dart';
import '../../providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _userService = UserService();

  bool _isLoading = false;
  bool _hasChanges = false;
  String? _phone;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = authProvider.userName ?? '';
    _phone = authProvider.userEmail; // phone stored in email field

    // Try to load bio from backend
    try {
      final profile = await _userService.searchUserByEmail(_phone ?? '');
      if (profile != null && mounted) {
        setState(() {
          _bioController.text = profile['bio'] ?? '';
          if (_nameController.text.isEmpty) {
            _nameController.text = profile['fullName'] ?? '';
          }
        });
      }
    } catch (_) {}

    _nameController.addListener(_onChanged);
    _bioController.addListener(_onChanged);
  }

  void _onChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tên không được để trống')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _userService.updateProfile(
        fullName: name,
        bio: _bioController.text.trim(),
      );

      // Update local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);

      // Update AuthProvider
      if (mounted) {
        await context.read<AuthProvider>().checkAuthStatus();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật hồ sơ thành công!')),
        );
        Navigator.pop(context, true); // Return true to indicate changes
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Huỷ',
            style: TextStyle(color: AppColors.primary, fontSize: 16),
          ),
        ),
        title: const Text(
          'Chỉnh sửa hồ sơ',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _hasChanges && !_isLoading ? _saveProfile : null,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Text(
                    'Xong',
                    style: TextStyle(
                      color: _hasChanges
                          ? AppColors.primary
                          : AppColors.textPlaceholder,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Name section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 12),
                    child: Text(
                      'Tên',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Phone section (read-only)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 12),
                    child: Text(
                      'Điện thoại',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Di Động',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatPhone(_phone ?? ''),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Bio section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 12),
                    child: Text(
                      'Giới thiệu',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextField(
                    controller: _bioController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                    ),
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Viết gì đó về bạn...',
                      hintStyle: TextStyle(color: AppColors.textPlaceholder),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPhone(String phone) {
    // Format: +84 96 659 78 23
    if (phone.length < 5) return phone;
    final buffer = StringBuffer();
    for (int i = 0; i < phone.length; i++) {
      buffer.write(phone[i]);
      if (i == 2 || i == 4 || i == 7 || i == 9) {
        buffer.write(' ');
      }
    }
    return buffer.toString().trim();
  }
}
