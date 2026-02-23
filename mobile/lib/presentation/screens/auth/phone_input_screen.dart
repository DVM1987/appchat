import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'otp_verification_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _phoneController = TextEditingController();
  String _countryCode = '+84';
  String _countryName = 'Viet Nam';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
  }

  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('last_phone_number');
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _phoneController.text = saved);
    }
  }

  Future<void> _savePhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_phone_number', phone);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber {
    var phone = _phoneController.text.trim();
    if (phone.startsWith('0')) phone = phone.substring(1);
    return '$_countryCode$phone';
  }

  bool get _isPhoneValid {
    final phone = _phoneController.text.trim();
    return phone.length >= 9;
  }

  Future<void> _handleSendOtp() async {
    if (!_isPhoneValid) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.sendOtp(phoneNumber: _fullPhoneNumber);

      // Save phone for auto-fill next time
      await _savePhone(_phoneController.text.trim());

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            phoneNumber: _fullPhoneNumber,
            displayPhone: '$_countryCode ${_phoneController.text.trim()}',
          ),
        ),
      );
    } catch (e) {
      AppConfig.log('Error sending OTP: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _CountryPickerSheet(
        onSelected: (code, name) {
          setState(() {
            _countryCode = code;
            _countryName = name;
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Số điện thoại',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isPhoneValid && !_isLoading ? _handleSendOtp : null,
            child: Text(
              'Tiếp tục',
              style: TextStyle(
                color: _isPhoneValid && !_isLoading
                    ? const Color(0xFF007AFF)
                    : Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),

          // Instructions text
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Vui lòng xác nhận mã quốc gia và\nnhập số điện thoại của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Country selector
          InkWell(
            onTap: _showCountryPicker,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    _countryName,
                    style: const TextStyle(
                      color: Color(0xFF007AFF),
                      fontSize: 17,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 22),
                ],
              ),
            ),
          ),

          // Phone input row
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
              ),
            ),
            child: Row(
              children: [
                // Country code
                SizedBox(
                  width: 60,
                  child: Text(
                    _countryCode,
                    style: const TextStyle(color: Colors.black87, fontSize: 17),
                  ),
                ),
                const SizedBox(
                  height: 30,
                  child: VerticalDivider(
                    color: Color(0xFFE0E0E0),
                    width: 16,
                    thickness: 1,
                  ),
                ),
                // Phone number field
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    style: const TextStyle(color: Colors.black87, fontSize: 17),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    decoration: const InputDecoration(
                      hintText: 'số điện thoại',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 17),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (_isPhoneValid) _handleSendOtp();
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF007AFF),
              ),
            ),

          const Spacer(),
          // Info: OTP will be sent via SMS
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Chúng tôi sẽ gửi mã xác nhận qua SMS đến số điện thoại của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black38, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Country Picker ──────────────────────────────────────────────

class _CountryPickerSheet extends StatelessWidget {
  final void Function(String code, String name) onSelected;

  const _CountryPickerSheet({required this.onSelected});

  static const _countries = [
    {'code': '+84', 'name': 'Viet Nam', 'flag': '🇻🇳'},
    {'code': '+1', 'name': 'United States', 'flag': '🇺🇸'},
    {'code': '+44', 'name': 'United Kingdom', 'flag': '🇬🇧'},
    {'code': '+81', 'name': 'Japan', 'flag': '🇯🇵'},
    {'code': '+82', 'name': 'Korea', 'flag': '🇰🇷'},
    {'code': '+86', 'name': 'China', 'flag': '🇨🇳'},
    {'code': '+65', 'name': 'Singapore', 'flag': '🇸🇬'},
    {'code': '+66', 'name': 'Thailand', 'flag': '🇹🇭'},
    {'code': '+61', 'name': 'Australia', 'flag': '🇦🇺'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          const Text(
            'Chọn quốc gia',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _countries.length,
              itemBuilder: (ctx, i) {
                final c = _countries[i];
                return ListTile(
                  leading: Text(
                    c['flag']!,
                    style: const TextStyle(fontSize: 28),
                  ),
                  title: Text(
                    c['name']!,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: Text(
                    c['code']!,
                    style: const TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                  onTap: () => onSelected(c['code']!, c['name']!),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
