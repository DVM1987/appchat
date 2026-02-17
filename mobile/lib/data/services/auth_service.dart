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
}
