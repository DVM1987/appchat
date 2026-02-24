import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/chat_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isAuthenticated = false;
  String? _token;
  String? _userId;
  String? _userName;
  String? _userEmail;
  int? _tokenExpiresIn;

  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;

  // Check if user is already logged in (on app start)
  Future<void> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _userId = prefs.getString('user_id');
    _userName = prefs.getString('user_name');
    _userEmail = prefs.getString('user_email');

    // Check if token exists and is not expired
    if (_token != null) {
      final expiresAt = prefs.getInt('token_expires_at');
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      if (expiresAt != null && now < expiresAt) {
        _isAuthenticated = true;

        // If userId is missing but we have token, try to decode it again
        if (_userId == null) {
          try {
            Map<String, dynamic> decodedToken = JwtDecoder.decode(_token!);
            if (decodedToken.containsKey('sub')) {
              _userId = decodedToken['sub'];
              await prefs.setString('user_id', _userId!);
            }
            if (decodedToken.containsKey('name')) {
              _userName = decodedToken['name'];
              await prefs.setString('user_name', _userName!);
            }
          } catch (e) {
            AppConfig.log('Error decoding token in checkAuthStatus: $e');
          }
        }
      } else {
        // Token expired — try to refresh
        final newToken = await AuthService.refreshAccessToken();
        if (newToken != null) {
          _token = newToken;
          _isAuthenticated = true;
          // Update expiry
          final newExpiry =
              DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
          await prefs.setInt('token_expires_at', newExpiry);
          // Decode refreshed token for userId/userName
          try {
            Map<String, dynamic> decoded = JwtDecoder.decode(newToken);
            if (decoded.containsKey('sub')) {
              _userId = decoded['sub'];
              await prefs.setString('user_id', _userId!);
            }
            if (decoded.containsKey('name')) {
              _userName = decoded['name'];
              await prefs.setString('user_name', _userName!);
            }
          } catch (_) {}
        } else {
          // Refresh failed — force logout
          await logout();
        }
      }
    }

    notifyListeners();
  }

  // Login with backend API
  Future<void> login({required String email, required String password}) async {
    try {
      final response = await _authService.login(
        email: email,
        password: password,
      );

      // Extract data from response
      _token = response['token'] as String;
      _tokenExpiresIn = response['expiresIn'] as int?;
      _userEmail = email;
      _isAuthenticated = true;

      // Calculate expiration timestamp
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiresAt = now + (_tokenExpiresIn ?? 3600); // Default 1 hour

      // Save tokens (access + refresh) to SharedPreferences
      final refreshToken = response['refreshToken'] as String? ?? '';
      final prefs = await SharedPreferences.getInstance();
      await AuthService.saveTokens(
        accessToken: _token!,
        refreshToken: refreshToken,
      );
      await prefs.setString('user_email', _userEmail!);
      await prefs.setInt('token_expires_at', expiresAt);

      // Decode token to get userId and userName
      Map<String, dynamic> decodedToken = JwtDecoder.decode(_token!);
      if (kDebugMode) {
        AppConfig.log('Decoded Token: $decodedToken');
      }

      // 'sub' is standard for Subject (UserId), 'name' for Full Name
      if (decodedToken.containsKey('sub')) {
        _userId = decodedToken['sub'];
        await prefs.setString('user_id', _userId!);
      }

      if (decodedToken.containsKey('name')) {
        _userName = decodedToken['name'];
        await prefs.setString('user_name', _userName!);
      }

      notifyListeners();
    } catch (e) {
      // Re-throw the exception to be handled by the UI
      rethrow;
    }
  }

  // Register with backend API
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      await _authService.register(
        fullName: name,
        email: email,
        password: password,
      );

      // Registration successful - user needs to login
    } catch (e) {
      // Re-throw the exception to be handled by the UI
      rethrow;
    }
  }

  // Logout and clear all stored data
  Future<void> logout() async {
    await ChatService().disconnect();

    _token = null;
    _userId = null;
    _userName = null;
    _userEmail = null;
    _tokenExpiresIn = null;
    _isAuthenticated = false;

    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('token_expires_at');

    // Notify any registered logout callbacks (to clear providers)
    for (final cb in _logoutCallbacks) {
      cb();
    }

    notifyListeners();
  }

  // Logout callbacks — allows providers to register cleanup
  final List<VoidCallback> _logoutCallbacks = [];
  void onLogout(VoidCallback callback) => _logoutCallbacks.add(callback);

  // ─── Phone OTP Auth ──────────────────────────────────────

  // Send OTP to phone number
  Future<void> sendOtp({required String phoneNumber}) async {
    await _authService.sendOtp(phoneNumber: phoneNumber);
  }

  // Verify OTP and login
  Future<bool> verifyOtp({
    required String phoneNumber,
    required String otpCode,
    String? fullName,
  }) async {
    try {
      final response = await _authService.verifyOtp(
        phoneNumber: phoneNumber,
        otpCode: otpCode,
        fullName: fullName,
      );

      // Extract data
      _token = response['token'] as String;
      _tokenExpiresIn = response['expiresIn'] as int?;
      _isAuthenticated = true;
      final isNewUser = response['isNewUser'] as bool? ?? false;

      // Calculate expiration
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiresAt = now + (_tokenExpiresIn ?? 3600);

      // Save tokens (access + refresh)
      final refreshToken = response['refreshToken'] as String? ?? '';
      final prefs = await SharedPreferences.getInstance();
      await AuthService.saveTokens(
        accessToken: _token!,
        refreshToken: refreshToken,
      );
      await prefs.setInt('token_expires_at', expiresAt);

      // Decode token
      Map<String, dynamic> decodedToken = JwtDecoder.decode(_token!);
      if (decodedToken.containsKey('sub')) {
        _userId = decodedToken['sub'];
        await prefs.setString('user_id', _userId!);
      }
      if (decodedToken.containsKey('name')) {
        _userName = decodedToken['name'];
        await prefs.setString('user_name', _userName!);
      }
      if (decodedToken.containsKey('email')) {
        _userEmail = decodedToken['email'];
        await prefs.setString('user_email', _userEmail!);
      }

      notifyListeners();
      return isNewUser;
    } catch (e) {
      rethrow;
    }
  }
}
