import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  String? _userAvatar;
  int? _tokenExpiresIn;

  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userAvatar => _userAvatar;

  // ─── Firebase Phone Auth state ──────────────────────────
  String? _verificationId;
  int? _resendToken;
  bool _isOtpSending = false;

  String? get verificationId => _verificationId;
  bool get isOtpSending => _isOtpSending;

  // Check if user is already logged in (on app start)
  Future<void> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _userId = prefs.getString('user_id');
    _userName = prefs.getString('user_name');
    _userEmail = prefs.getString('user_email');
    _userAvatar = prefs.getString('user_avatar');

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

        // Fetch latest profile (name + avatar) — non-blocking
        if (_userId != null) {
          _fetchLatestProfile(_userId!, prefs).then((_) => notifyListeners());
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

          // Fetch latest profile (name + avatar) — non-blocking
          if (_userId != null) {
            _fetchLatestProfile(_userId!, prefs).then((_) => notifyListeners());
          }
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

    // Sign out of Firebase too
    try {
      await fb.FirebaseAuth.instance.signOut();
    } catch (_) {}

    _token = null;
    _userId = null;
    _userName = null;
    _userEmail = null;
    _userAvatar = null;
    _tokenExpiresIn = null;
    _isAuthenticated = false;
    _verificationId = null;
    _resendToken = null;

    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_avatar');
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

  // ─── Firebase Phone Auth ──────────────────────────────────

  /// Send OTP via Firebase Phone Auth
  /// Completer resolves when codeSent callback fires (or error)
  Future<void> sendOtp({required String phoneNumber}) async {
    _isOtpSending = true;
    notifyListeners();

    final completer = Completer<void>();

    await fb.FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (fb.PhoneAuthCredential credential) async {
        // Auto-verification on Android — sign in automatically
        AppConfig.log('[Firebase] Auto-verification completed');
      },
      verificationFailed: (fb.FirebaseAuthException e) {
        AppConfig.log('[Firebase] Verification failed: ${e.message}');
        _isOtpSending = false;
        notifyListeners();
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(e.message ?? 'Không thể gửi mã xác thực'),
          );
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        AppConfig.log('[Firebase] Code sent, verificationId=$verificationId');
        _verificationId = verificationId;
        _resendToken = resendToken;
        _isOtpSending = false;
        notifyListeners();
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        AppConfig.log('[Firebase] Auto retrieval timeout');
        _verificationId = verificationId;
      },
    );

    return completer.future;
  }

  /// Verify OTP using Firebase, then exchange Firebase ID token for app JWT
  Future<bool> verifyOtp({
    required String phoneNumber,
    required String otpCode,
    String? fullName,
  }) async {
    try {
      if (_verificationId == null) {
        throw Exception('Chưa có mã xác thực. Vui lòng gửi lại OTP.');
      }

      // 1. Create credential from verification ID + OTP code
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpCode,
      );

      // 2. Sign in with Firebase
      final userCredential = await fb.FirebaseAuth.instance
          .signInWithCredential(credential);

      // 3. Get Firebase ID token
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) {
        throw Exception('Không thể lấy token từ Firebase');
      }

      AppConfig.log('[Firebase] Got ID token, sending to backend...');

      // 4. Send Firebase ID token to backend for app JWT
      final response = await _authService.verifyFirebaseToken(
        idToken: idToken,
        fullName: fullName,
      );

      // 5. Process backend response (same as before)
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

      // Fetch latest profile from User.API (non-blocking — don't block login)
      if (_userId != null) {
        _fetchLatestProfile(_userId!, prefs).then((_) => notifyListeners());
      }

      notifyListeners();
      return isNewUser;
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch latest profile from User.API to get updated name/avatar
  Future<void> _fetchLatestProfile(
    String userId,
    SharedPreferences prefs,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.userApiBaseUrl}/users/identity/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_token',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final profile = jsonDecode(response.body);
        final latestName = profile['fullName'] as String?;
        if (latestName != null && latestName.isNotEmpty) {
          _userName = latestName;
          await prefs.setString('user_name', latestName);
          AppConfig.log('[Auth] Updated name from profile: $latestName');
        }
        // Persist avatar URL
        final latestAvatar = profile['avatarUrl'] as String?;
        if (latestAvatar != null && latestAvatar.isNotEmpty) {
          _userAvatar = latestAvatar;
          await prefs.setString('user_avatar', latestAvatar);
          AppConfig.log('[Auth] Updated avatar from profile: $latestAvatar');
        }
      }
    } catch (e) {
      AppConfig.log('[Auth] Failed to fetch profile: $e');
      // Non-blocking — use JWT name as fallback
    }
  }
}
