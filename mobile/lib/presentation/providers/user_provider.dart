import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/user_service.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();

  UserProvider() {
    _listenToEvents();
  }

  void _listenToEvents() {
    AppConfig.log('UserProvider: Start listening to friendRequestStream');
    _chatService.friendRequestStream.listen((_) {
      AppConfig.log(
        'UserProvider: FriendRequestReceived event from stream -> Reloading data',
      );
      loadData();
    });
  }

  List<dynamic> _friends = [];
  List<dynamic> _pendingRequests = [];
  Map<String, dynamic>? _myProfile;
  bool _isLoading = false;
  String? _error;

  List<dynamic> get friends => _friends;
  List<dynamic> get pendingRequests => _pendingRequests;
  Map<String, dynamic>? get myProfile => _myProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get pendingCount => _pendingRequests.length;

  void clear() {
    _friends = [];
    _pendingRequests = [];
    _myProfile = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> loadData() async {
    // Only show loading if we have no existing data (first load)
    final isFirstLoad = _friends.isEmpty && _pendingRequests.isEmpty;
    if (isFirstLoad) {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();

    try {
      print('[UserProvider] loadData: fetching friends, pending, profile...');
      final results = await Future.wait([
        _userService.getFriends(),
        _userService.getPendingRequests(),
        _fetchMyProfile(),
      ]);

      _friends = results[0] as List<dynamic>;
      _pendingRequests = results[1] as List<dynamic>;
      _myProfile = results[2] as Map<String, dynamic>?;
      print(
        '[UserProvider] loadData: ${_friends.length} friends, ${_pendingRequests.length} pending',
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('[UserProvider] loadData error: $e');
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> _fetchMyProfile() async {
    try {
      final currentUserId = await AuthService.getUserId();
      if (currentUserId == null) return null;
      return await _userService.getUserProfile(currentUserId);
    } catch (e) {
      AppConfig.log('Error fetching my profile: $e');
      return null;
    }
  }

  Future<void> acceptRequest(String requesterId) async {
    try {
      await _userService.acceptFriendRequest(requesterId);
      await loadData(); // Reload to update lists and count
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> declineRequest(String requesterId) async {
    try {
      await _userService.declineFriendRequest(requesterId);
      await loadData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Send friend request by Identity ID (used by QR scan)
  Future<void> sendFriendRequestByIdentityId(String identityId) async {
    try {
      await _userService.sendFriendRequestByIdentityId(identityId);
      await loadData(); // Reload to update lists
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
