import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../data/services/user_service.dart';
import '../../providers/auth_provider.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String displayPhone;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.displayPhone,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Auto focus first digit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  String get _otpCode {
    return _controllers.map((c) => c.text).join();
  }

  Future<void> _verifyOtp({String? fullName}) async {
    if (_otpCode.length != 6) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isNewUser = await authProvider.verifyOtp(
        phoneNumber: widget.phoneNumber,
        otpCode: _otpCode,
        fullName: fullName,
      );

      if (!mounted) return;

      if (isNewUser && fullName == null) {
        // Show name input dialog for new users
        _showNameInputDialog();
      } else {
        // Navigate to home
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      AppConfig.log('Error verifying OTP: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
        // Clear OTP fields
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showNameInputDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Chào mừng bạn!',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nhập tên của bạn để hoàn tất đăng ký',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Tên hiển thị',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                // Re-verify with name to update profile
                _verifyOtpWithName(name);
              },
              child: const Text(
                'Xác nhận',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyOtpWithName(String fullName) async {
    try {
      // Update profile name on backend
      final userService = UserService();
      await userService.updateProfile(fullName: fullName);

      // Update local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', fullName);

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      AppConfig.log('Error updating name: $e');
      // Still navigate home even if update fails
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.sendOtp(phoneNumber: widget.phoneNumber);

      if (mounted) {
        _startCountdown();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã gửi lại mã OTP')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    // Auto submit when all 6 digits are entered
    if (_otpCode.length == 6) {
      _verifyOtp();
    }
  }

  void _onKeyPressed(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF007AFF)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Xác thực OTP',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Instructions
            Text(
              'Nhập mã 6 số đã gửi đến',
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              widget.displayPhone,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 32),

            // OTP Input boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 45,
                  height: 55,
                  child: RawKeyboardListener(
                    focusNode: FocusNode(),
                    onKey: (event) => _onKeyPressed(index, event),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF007AFF),
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) => _onDigitChanged(index, value),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // Verify button
            if (_isLoading)
              const CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF007AFF),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _otpCode.length == 6 ? () => _verifyOtp() : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Xác thực',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Resend OTP
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Không nhận được mã? ',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                if (_resendCountdown > 0)
                  Text(
                    'Gửi lại sau ${_resendCountdown}s',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  )
                else
                  GestureDetector(
                    onTap: _isResending ? null : _resendOtp,
                    child: Text(
                      _isResending ? 'Đang gửi...' : 'Gửi lại',
                      style: const TextStyle(
                        color: Color(0xFF007AFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
