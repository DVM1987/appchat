import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/user_service.dart';
import '../../widgets/common/custom_avatar.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _emailController = TextEditingController();
  final _userService = UserService();

  bool _isLoading = false;
  Map<String, dynamic>? _foundUser;
  String? _errorMessage;
  bool _requestSent = false;

  Future<void> _searchUser() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _foundUser = null;
      _requestSent = false;
    });

    try {
      final user = await _userService.searchUserByEmail(email);
      setState(() {
        _foundUser = user;
        if (user == null) {
          _errorMessage = 'Không tìm thấy người dùng với email này.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_foundUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Assuming 'id' is coming from user_service response.
      // Check backend UsersController response structure: { "id": "...", "identityId": "...", "fullName": "..." }
      // Using "identityId" might be safer if that's what friend service expects,
      // OR "id" if friend service expects UserProfile ID.
      // Based on typical DDD, usually we link via ProfileId (Guid).
      // Let's assume 'id' from response is the ProfileId.
      await _userService.sendFriendRequest(_foundUser!['id']);

      setState(() {
        _requestSent = true;
      });

      if (mounted) {
        // Navigate back to Home
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi lời mời kết bạn!')),
        );
      }
    } catch (e) {
      final errorMsg = e.toString();
      // Check for specific error message regarding duplicate request
      // Adjust this check based on actual backend error message
      if (errorMsg.contains('Friend request already sent') ||
          errorMsg.contains('đã gửi lời mời') ||
          errorMsg.contains('already friends or pending') ||
          errorMsg.contains('400')) {
        setState(() {
          _requestSent = true;
          // Optimistically update the status to prevent further clicks
          if (_foundUser != null) {
            _foundUser!['friendshipStatus'] = 'Pending_Sent';
          }
        });

        if (mounted) {
          // Optionally show a milder message or just nothing if UI updates
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lời mời kết bạn đã được gửi trước đó.'),
            ),
          );
        }
      } else {
        if (mounted) {
          // Only show error if it's NOT a duplicate request issue
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi: $errorMsg')));
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thêm liên hệ mới'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Input
            TextField(
              controller: _emailController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nhập email người dùng',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                hintText: 'example@email.com',
                hintStyle: const TextStyle(color: AppColors.textPlaceholder),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: AppColors.primary),
                  onPressed: _isLoading ? null : _searchUser,
                ),
              ),
              onSubmitted: (_) => _searchUser(),
            ),

            const SizedBox(height: 24),

            // Loading Indicator
            if (_isLoading)
              const CircularProgressIndicator(color: AppColors.primary),

            // Error Message
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),

            // User Result
            if (_foundUser != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    CustomAvatar(
                      imageUrl: _foundUser!['avatarUrl'],
                      name: _foundUser!['fullName'] ?? 'User',
                      size: 80,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _foundUser!['fullName'] ?? 'Unknown User',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _foundUser!['email'] ?? '',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_foundUser!['friendshipStatus'] == 'Pending_Sent' ||
                        _requestSent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.textSecondary),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time, color: AppColors.warning),
                            SizedBox(width: 8),
                            Text(
                              'Đã gửi lời mời (Chờ chấp nhận)',
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      )
                    else if (_foundUser!['friendshipStatus'] == 'Accepted')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.success),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: AppColors.success),
                            SizedBox(width: 8),
                            Text(
                              'Đã là bạn bè',
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      )
                    else if (_foundUser!['friendshipStatus'] ==
                        'Pending_Received')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: const Text(
                          'Đã gửi lời mời cho bạn',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      )
                    else if (_foundUser!['friendshipStatus'] == 'Self')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: const Text(
                          'Đây là tài khoản của bạn',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _sendFriendRequest,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Gửi lời mời kết bạn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
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
}
