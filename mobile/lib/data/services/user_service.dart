import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class UserService {
  // Use the same base URL as AuthService, but point to API Gateway
  final String baseUrl = AuthService.baseUrl;

  // Search user by email
  // Returns: {id, identityId, fullName, email, avatarUrl, friendshipStatus, ...}
  Future<Map<String, dynamic>?> searchUserByEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/users/email/$email'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to search user: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching user: $e');
    }
  }

  // Upload Avatar
  Future<String?> uploadAvatar(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/v1/media/upload'),
      );

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url']; // Returns relative URL like /uploads/...
      } else {
        throw Exception('Failed to upload avatar: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error uploading avatar: $e');
    }
  }

  // Update Profile
  Future<void> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? bio,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.put(
        Uri.parse('$baseUrl/api/v1/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'fullName': fullName,
          'avatarUrl': avatarUrl,
          'bio': bio,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }

      // Update local storage if needed
      if (fullName != null) {
        await prefs.setString('user_name', fullName);
      }
    } catch (e) {
      throw Exception('Error updating profile: $e');
    }
  }

  // Send friend request
  Future<void> sendFriendRequest(String toUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final currentUserId = prefs.getString('user_id');

      if (currentUserId == null) throw Exception('User not logged in');

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/friends/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'requesterId': currentUserId,
          'addresseeId': toUserId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send friend request: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sending friend request: $e');
    }
  }

  // Get Pending Friend Requests
  Future<List<dynamic>> getPendingRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final currentUserId = prefs.getString('user_id');

      if (currentUserId == null) throw Exception('User not logged in');

      print(
        '[UserService] getPendingRequests: $baseUrl/api/v1/friends/pending?userId=$currentUserId',
      );
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/v1/friends/pending?userId=$currentUserId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('[UserService] getPendingRequests: ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to load pending requests: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('[UserService] Error getting pending requests: $e');
      return [];
    }
  }

  // Accept Friend Request
  Future<void> acceptFriendRequest(String requesterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final currentUserId = prefs.getString('user_id'); // Addressee

      if (currentUserId == null) throw Exception('User not logged in');

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/friends/accept'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'requesterId': requesterId,
          'addresseeId': currentUserId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to accept request: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error accepting request: $e');
    }
  }

  // Decline Friend Request
  Future<void> declineFriendRequest(String requesterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final currentUserId = prefs.getString('user_id'); // Addressee

      if (currentUserId == null) throw Exception('User not logged in');

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/friends/decline'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'userId': currentUserId, 'fromUserId': requesterId}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to decline request: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error declining request: $e');
    }
  }

  // Get Friends List
  Future<List<dynamic>> getFriends() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final currentUserId = prefs.getString('user_id');

      if (currentUserId == null) throw Exception('User not logged in');

      print(
        '[UserService] getFriends: $baseUrl/api/v1/friends?userId=$currentUserId',
      );
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/v1/friends?userId=$currentUserId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      print(
        '[UserService] getFriends: ${response.statusCode}, ${response.body.length} bytes',
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load friends: ${response.statusCode}');
      }
    } catch (e) {
      print('[UserService] Error getting friends: $e');
      return [];
    }
  }

  // Get User Profile by Identity Id
  Future<Map<String, dynamic>?> getUserProfile(String identityId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      print(
        '[UserService] getUserProfile: $baseUrl/api/v1/users/identity/$identityId',
      );
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/v1/users/identity/$identityId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('[UserService] getUserProfile: ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      print('[UserService] Error getting user profile: $e');
      return null;
    }
  }
}
