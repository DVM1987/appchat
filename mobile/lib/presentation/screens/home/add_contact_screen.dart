import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/user_service.dart';
import '../../widgets/common/custom_avatar.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _phoneController = TextEditingController();
  final _userService = UserService();
  String _countryCode = '+84';

  bool _isLoading = false;
  Map<String, dynamic>? _foundUser;
  String? _errorMessage;
  bool _requestSent = false;

  String get _fullPhoneNumber {
    var phone = _phoneController.text.trim();
    if (phone.startsWith('0')) phone = phone.substring(1);
    return '$_countryCode$phone';
  }

  Future<void> _searchUser() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _foundUser = null;
      _requestSent = false;
    });

    try {
      // Search by phone number (stored in email field for phone-auth users)
      final user = await _userService.searchUserByEmail(_fullPhoneNumber);
      setState(() {
        _foundUser = user;
        if (user == null) {
          _errorMessage = 'Không tìm thấy người dùng với SĐT này.';
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
      await _userService.sendFriendRequest(_foundUser!['id']);

      setState(() {
        _requestSent = true;
      });

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi lời mời kết bạn!')),
        );
      }
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('Friend request already sent') ||
          errorMsg.contains('đã gửi lời mời') ||
          errorMsg.contains('already friends or pending') ||
          errorMsg.contains('400')) {
        setState(() {
          _requestSent = true;
          if (_foundUser != null) {
            _foundUser!['friendshipStatus'] = 'Pending_Sent';
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lời mời kết bạn đã được gửi trước đó.'),
            ),
          );
        }
      } else {
        if (mounted) {
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
    _phoneController.dispose();
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
            // Phone Input
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Country code selector
                GestureDetector(
                  onTap: () => _showCountryCodePicker(),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        Text(
                          _countryCode,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Phone number field
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppColors.textPrimary),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Nhập số điện thoại',
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                      hintText: '901234567',
                      hintStyle: const TextStyle(
                        color: AppColors.textPlaceholder,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.search,
                          color: AppColors.primary,
                        ),
                        onPressed: _isLoading ? null : _searchUser,
                      ),
                    ),
                    onSubmitted: (_) => _searchUser(),
                  ),
                ),
              ],
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

  void _showCountryCodePicker() {
    final codes = [
      {'+84': '🇻🇳 Việt Nam'},
      {'+1': '🇺🇸 United States'},
      {'+44': '🇬🇧 United Kingdom'},
      {'+81': '🇯🇵 Japan'},
      {'+82': '🇰🇷 Korea'},
      {'+86': '🇨🇳 China'},
      {'+65': '🇸🇬 Singapore'},
      {'+66': '🇹🇭 Thailand'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Container(
        height: 400,
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            const Text(
              'Chọn mã quốc gia',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: codes.length,
                itemBuilder: (ctx, i) {
                  final code = codes[i].keys.first;
                  final label = codes[i].values.first;
                  return ListTile(
                    title: Text(
                      label,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    trailing: Text(
                      code,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                    onTap: () {
                      setState(() => _countryCode = code);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
