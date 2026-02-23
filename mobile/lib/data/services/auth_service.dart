import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';

class AuthService {
  // Base URL from centralized config — no more hardcoded localhost
  static String get baseUrl => AppConfig.apiBaseUrl;

  // Login endpoint
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Email hoặc mật khẩu không đúng');
      } else {
        throw Exception('Lỗi kết nối server. Vui lòng thử lại sau.');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception(
        'Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.',
      );
    }
  }

  // Register endpoint
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Thông tin đăng ký không hợp lệ');
      } else if (response.statusCode == 409) {
        throw Exception('Email đã được sử dụng');
      } else {
        throw Exception('Lỗi kết nối server. Vui lòng thử lại sau.');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception(
        'Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.',
      );
    }
  }

  // Validate token (optional - for checking if token is still valid)
  Future<bool> validateToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/auth/validate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Static methods to access storage directly (helper for Services)
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  // ─── Phone OTP Auth ──────────────────────────────────────

  // Send OTP to phone number
  Future<Map<String, dynamic>> sendOtp({required String phoneNumber}) async {
    try {
      print('[Auth] sendOtp: $baseUrl/api/v1/auth/send-otp phone=$phoneNumber');
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/v1/auth/send-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phoneNumber': phoneNumber}),
          )
          .timeout(const Duration(seconds: 15));

      print('[Auth] sendOtp response: ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Không thể gửi OTP');
      }
    } catch (e) {
      print('[Auth] sendOtp error: $e');
      if (e is Exception) rethrow;
      throw Exception('Không thể kết nối đến server.');
    }
  }

  // Verify OTP and get token
  Future<Map<String, dynamic>> verifyOtp({
    required String phoneNumber,
    required String otpCode,
    String? fullName,
  }) async {
    try {
      final body = <String, dynamic>{
        'phoneNumber': phoneNumber,
        'otpCode': otpCode,
      };
      if (fullName != null && fullName.isNotEmpty) {
        body['fullName'] = fullName;
      }

      print('[Auth] verifyOtp: $baseUrl/api/v1/auth/verify-otp');
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/v1/auth/verify-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      print('[Auth] verifyOtp response: ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Mã OTP không hợp lệ');
      } else {
        throw Exception('Lỗi server. Vui lòng thử lại.');
      }
    } catch (e) {
      print('[Auth] verifyOtp error: $e');
      if (e is Exception) rethrow;
      throw Exception('Không thể kết nối đến server.');
    }
  }
}
