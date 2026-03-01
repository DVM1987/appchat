import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../../core/config/app_config.dart';
import 'auth_service.dart';
import 'sound_service.dart';

class ChatService with WidgetsBindingObserver {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;

  ChatService._internal() {
    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);
  }

  // Stream Controllers
  final _userTypingController =
      StreamController<Map<String, String>>.broadcast();
  final _userOnlineController = StreamController<String>.broadcast();
  final _userOfflineController = StreamController<String>.broadcast();
  final _messageController = StreamController<dynamic>.broadcast();
  final _messageReadController =
      StreamController<Map<String, String>>.broadcast();
  final _conversationCreatedController = StreamController<dynamic>.broadcast();
  final _conversationUpdatedController = StreamController<dynamic>.broadcast();
  final _conversationDeletedController = StreamController<String>.broadcast();
  final _messageReactedController = StreamController<dynamic>.broadcast();
  final _messageDeletedController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Streams
  Stream<Map<String, String>> get userTypingStream =>
      _userTypingController.stream;
  Stream<String> get userOnlineStream => _userOnlineController.stream;
  Stream<String> get userOfflineStream => _userOfflineController.stream;
  Stream<dynamic> get messageStream => _messageController.stream;
  Stream<Map<String, String>> get messageReadStream =>
      _messageReadController.stream;
  Stream<dynamic> get messageReactedStream => _messageReactedController.stream;
  Stream<Map<String, dynamic>> get messageDeletedStream =>
      _messageDeletedController.stream;
  Stream<dynamic> get conversationCreatedStream =>
      _conversationCreatedController.stream;
  Stream<dynamic> get conversationUpdatedStream =>
      _conversationUpdatedController.stream;
  Stream<String> get conversationDeletedStream =>
      _conversationDeletedController.stream;

  // URLs from centralized AppConfig — no more hardcoded localhost
  String get _baseUrl => AppConfig.chatApiBaseUrl;
  String get _hubUrl => AppConfig.chatHubUrl;
  String get _presenceHubUrl => AppConfig.presenceHubUrl;
  String get _userHubUrl => AppConfig.userHubUrl;

  HubConnection? _hubConnection;
  HubConnection? _presenceHubConnection;
  HubConnection? _userHubConnection;
  Timer? _heartbeatTimer;

  /// Expose ChatHub connection state for debugging
  String get chatHubState => _hubConnection?.state?.toString() ?? 'null';

  // Stream Controllers
  final _friendRequestController = StreamController<void>.broadcast();

  // Streams
  Stream<void> get friendRequestStream => _friendRequestController.stream;

  // === CALL SIGNALING CALLBACKS ===
  // Called when callee receives an incoming call
  void Function(Map<String, dynamic> callData)? onIncomingCall;
  // Called when caller's call is accepted
  VoidCallback? onCallAccepted;
  // Called when caller's call is rejected
  VoidCallback? onCallRejected;
  // Called when the other party ends the call
  VoidCallback? onCallEnded;

  // Get my conversations
  Future<List<dynamic>> getConversations() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('User not authenticated');

      final response = await http.get(
        Uri.parse('$_baseUrl/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        throw Exception(
          'Failed to load conversations: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      AppConfig.log('Error getting conversations: $e');
      return [];
    }
  }

  // Get conversation details
  Future<Map<String, dynamic>?> getConversationDetails(String id) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('User not authenticated');

    final response = await http.get(
      Uri.parse('$_baseUrl/conversations/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  // Create Group Conversation
  Future<String> createGroupConversation(
    String name,
    List<String> participantIds,
  ) async {
    final token = await AuthService.getToken();
    final userId = await AuthService.getUserId();

    if (token == null || userId == null) {
      throw Exception('User not authenticated');
    }

    final allParticipants = [userId, ...participantIds]; // Add self

    final response = await http.post(
      Uri.parse('$_baseUrl/conversations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'participantIds': allParticipants,
        'isGroup': true,
        'name': name,
        'avatarUrl': null, // Optional: Add avatar support later
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['id'];
    } else {
      throw Exception(
        'Failed to create group: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Add Participants to Group
  Future<void> addParticipants(
    String conversationId,
    List<String> participantIds,
    List<String> participantNames,
  ) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('User not authenticated');

    final response = await http.post(
      Uri.parse('$_baseUrl/conversations/$conversationId/participants'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'participantIds': participantIds,
        'participantNames': participantNames,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to add participants: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Remove Participant from Group
  Future<void> removeParticipant(
    String conversationId,
    String participantId,
    String name,
  ) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('User not authenticated');

    final response = await http.delete(
      Uri.parse(
        '$_baseUrl/conversations/$conversationId/participants/$participantId?name=$name',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to remove participant: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Join Conversation via Invite Token
  Future<String> joinConversationByToken(String token, String name) async {
    final authToken = await AuthService.getToken();
    if (authToken == null) throw Exception('User not authenticated');

    final response = await http.post(
      Uri.parse('$_baseUrl/conversations/join?token=$token&name=$name'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['conversationId'];
    } else {
      throw Exception(
        'Failed to join group: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Leave Conversation
  Future<void> leaveConversation(String id, String name) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('User not authenticated');

    final response = await http.post(
      Uri.parse('$_baseUrl/conversations/$id/leave?name=$name'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to leave group: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Update Conversation
  Future<void> updateConversation(
    String id,
    String? name,
    String? description,
    String? avatarUrl,
  ) async {
    final token = await AuthService.getToken();
    final userName = await AuthService.getUserName();

    if (token == null) throw Exception('User not authenticated');

    final response = await http.put(
      Uri.parse('$_baseUrl/conversations/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'description': description,
        'avatarUrl': avatarUrl,
        'updatedByName': userName,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update group: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Disband Conversation
  Future<void> disbandConversation(String id) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('User not authenticated');

    final response = await http.delete(
      Uri.parse('$_baseUrl/conversations/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to disband group: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Create or Get Conversation
  Future<String> createConversation(String friendId) async {
    final token = await AuthService.getToken();
    final userId = await AuthService.getUserId();
    // ... rest of existing code

    if (token == null || userId == null) {
      throw Exception('User not authenticated');
    }

    AppConfig.log(
      '[ChatService] createConversation: friendId=$friendId, userId=$userId',
    );
    AppConfig.log('[ChatService] POST $_baseUrl/conversations');

    final response = await http.post(
      Uri.parse('$_baseUrl/conversations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'participantIds': [userId, friendId],
        'isGroup': false,
        'name': 'Chat', // Backend might ignore/overwrite
      }),
    );

    AppConfig.log(
      '[ChatService] createConversation response: ${response.statusCode}',
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      AppConfig.log('[ChatService] createConversation got id: ${data['id']}');
      return data['id']; // Adjust based on backend response structure
    } else {
      AppConfig.log(
        '[ChatService] createConversation FAILED: ${response.statusCode} - ${response.body}',
      );
      throw Exception(
        'Failed to create conversation: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Get Messages
  Future<List<dynamic>> getMessages(
    String conversationId, {
    int skip = 0,
    int take = 50,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('User not authenticated');

    final url =
        '$_baseUrl/conversations/$conversationId/messages?skip=$skip&take=$take';
    AppConfig.log('[ChatService] getMessages: GET $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    AppConfig.log(
      '[ChatService] getMessages response: ${response.statusCode}, body length: ${response.body.length}',
    );

    if (response.statusCode == 200) {
      final messages = jsonDecode(response.body) as List<dynamic>;
      AppConfig.log(
        '[ChatService] getMessages: ${messages.length} messages loaded',
      );
      return messages;
    } else {
      AppConfig.log(
        '[ChatService] getMessages FAILED: ${response.statusCode} - ${response.body}',
      );
      throw Exception('Failed to load messages: ${response.statusCode}');
    }
  }

  // Send Message (API)
  Future<void> sendMessage(
    String conversationId,
    String content, {
    int type = 0,
    String? replyToId,
    String? replyToContent,
  }) async {
    final token = await AuthService.getToken();
    final userId = await AuthService.getUserId();
    if (token == null || userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/conversations/$conversationId/messages'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'conversationId': conversationId,
        'senderId': userId,
        'content': content,
        'type': type, // 0 = Text
        'replyToId': replyToId,
        'replyToContent': replyToContent,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to send message: ${response.body}');
    }
  }

  // Upload Images to server
  Future<List<String>> uploadImages(List<File> imageFiles) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('User not authenticated');

    final uri = Uri.parse('$_baseUrl/files/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    for (final file in imageFiles) {
      final fileName = file.path.split('/').last;
      final ext = fileName.split('.').last.toLowerCase();

      // Map extension to MIME type
      final mimeTypes = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'gif': 'image/gif',
        'webp': 'image/webp',
        'heic': 'image/heic',
        'heif': 'image/heif',
      };
      final mimeType = mimeTypes[ext] ?? 'image/jpeg';

      request.files.add(
        await http.MultipartFile.fromPath(
          'files',
          file.path,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
      );
    }

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode == 200) {
      final data = jsonDecode(responseBody);
      final urls = (data['urls'] as List).cast<String>();
      return urls;
    } else {
      throw Exception('Failed to upload images: $responseBody');
    }
  }

  // Send Image Messages (upload + send each as type=1)
  Future<void> sendImageMessages(
    String conversationId,
    List<File> imageFiles,
  ) async {
    // 1. Upload all images
    final urls = await uploadImages(imageFiles);

    // 2. Send each URL as an Image message (type=1)
    for (final url in urls) {
      await sendMessage(conversationId, url, type: 1);
    }
  }

  // Upload a voice recording to server
  Future<String> uploadVoice(File voiceFile) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('User not authenticated');

    final uri = Uri.parse('$_baseUrl/files/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    final fileName = voiceFile.path.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();

    final mimeTypes = {
      'm4a': 'audio/mp4',
      'aac': 'audio/aac',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'ogg': 'audio/ogg',
      'opus': 'audio/opus',
    };
    final mimeType = mimeTypes[ext] ?? 'audio/mp4';

    AppConfig.log(
      'Voice upload: uri=$uri, file=$fileName, ext=$ext, mime=$mimeType',
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        'files',
        voiceFile.path,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    AppConfig.log(
      'Voice upload: status=${streamedResponse.statusCode}, body=$responseBody',
    );

    if (streamedResponse.statusCode == 200) {
      final data = jsonDecode(responseBody);
      final urls = (data['urls'] as List).cast<String>();
      if (urls.isEmpty) throw Exception('No voice URL returned');
      return urls.first;
    } else {
      throw Exception('Failed to upload voice: $responseBody');
    }
  }

  // Send Voice Message (upload + send as type=4)
  Future<void> sendVoiceMessage(String conversationId, File voiceFile) async {
    final url = await uploadVoice(voiceFile);
    await sendMessage(conversationId, url, type: 4);
  }

  // Send Reaction (API)
  Future<void> reactToMessage(
    String conversationId,
    String messageId,
    String reactionType,
  ) async {
    final token = await AuthService.getToken();
    final userId = await AuthService.getUserId();
    if (token == null || userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await http.post(
      Uri.parse(
        '$_baseUrl/conversations/$conversationId/messages/$messageId/reactions',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'reactionType': reactionType}),
    );

    AppConfig.log('ReactToMessage: ${response.statusCode} - ${response.body}');

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to react to message: ${response.body}');
    }
  }

  Future<void> deleteMessage(
    String conversationId,
    String messageId, {
    bool forEveryone = false,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('User not authenticated');

    final response = await http.delete(
      Uri.parse(
        '$_baseUrl/conversations/$conversationId/messages/$messageId?forEveryone=$forEveryone',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete message: ${response.body}');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (
      timer,
    ) async {
      if (_presenceHubConnection?.state == HubConnectionState.Connected) {
        try {
          await _presenceHubConnection?.invoke('Heartbeat');
        } catch (e) {
          AppConfig.log('Error sending heartbeat: $e');
        }
      }
    });
  }

  // SignalR
  Future<void> initSignalR() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      debugPrint('[SignalR] initSignalR: starting parallel connection...');
      final sw = Stopwatch()..start();

      // Build all hub connections if not yet created
      _buildChatHub(token);
      _buildPresenceHub(token);
      _buildUserHub(token);

      // Connect all hubs IN PARALLEL (with individual timeouts)
      await Future.wait([
        _connectHub(_hubConnection, 'Chat'),
        _connectHub(_presenceHubConnection, 'Presence'),
        _connectHub(_userHubConnection, 'User'),
      ]);

      // Start heartbeat after presence is connected
      if (_presenceHubConnection?.state == HubConnectionState.Connected) {
        _startHeartbeat();
      }

      sw.stop();
      debugPrint('[SignalR] All hubs connected in ${sw.elapsedMilliseconds}ms');
    } catch (e) {
      debugPrint('[SignalR] initSignalR error: $e');
    }
  }

  Future<void> _connectHub(HubConnection? hub, String name) async {
    if (hub == null) return;
    final connection = hub; // promote to non-null
    if (connection.state == HubConnectionState.Disconnected) {
      try {
        final sw = Stopwatch()..start();
        final startFuture = connection.start();
        if (startFuture != null) {
          await startFuture.timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              debugPrint('[SignalR] $name hub connection timed out after 8s');
            },
          );
        }
        sw.stop();
        debugPrint(
          '[SignalR] $name hub connected in ${sw.elapsedMilliseconds}ms',
        );
      } catch (e) {
        debugPrint('[SignalR] Error connecting $name hub: $e');
      }
    }
  }

  void _buildChatHub(String token) {
    if (_hubConnection != null) return;

    _hubConnection = HubConnectionBuilder()
        .withUrl(
          _hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
            skipNegotiation: true,
            transport: HttpTransportType.WebSockets,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _hubConnection?.on('UserTyping', (arguments) {
      if (arguments != null && arguments.length >= 3) {
        _userTypingController.add({
          'conversationId': arguments[0].toString(),
          'userId': arguments[1].toString(),
          'userName': arguments[2].toString(),
        });
      }
    });
    _hubConnection?.on('ReceiveMessage', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        _messageController.add(arguments[0]);
        SoundService().playMessageSound();
      }
    });
    _hubConnection?.on('MessagesRead', (arguments) {
      if (arguments != null && arguments.length >= 2) {
        _messageReadController.add({
          'conversationId': arguments[0] as String,
          'userId': arguments[1] as String,
        });
      }
    });
    _hubConnection?.on('ConversationCreated', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        _conversationCreatedController.add(arguments[0]);
      }
    });
    _hubConnection?.on('ConversationUpdated', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        _conversationUpdatedController.add(arguments[0]);
      }
    });
    _hubConnection?.on('ConversationDeleted', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        _conversationDeletedController.add(arguments[0] as String);
      }
    });
    _hubConnection?.on('MessageReacted', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        _messageReactedController.add(arguments[0]);
      }
    });
    _hubConnection?.on('MessageDeleted', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final raw = arguments[0];
        if (raw is Map) {
          _messageDeletedController.add(
            raw.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      }
    });

    // === CALL SIGNALING LISTENERS ===
    _hubConnection?.off('IncomingCall');
    _hubConnection?.on('IncomingCall', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final raw = arguments[0];
        if (raw is Map) {
          final data = raw.map((k, v) => MapEntry(k.toString(), v));
          SoundService().playRingtone();
          onIncomingCall?.call(data);
        }
      }
    });

    _hubConnection?.off('CallAccepted');
    _hubConnection?.on('CallAccepted', (arguments) {
      SoundService().stopRingtone();
      onCallAccepted?.call();
    });

    _hubConnection?.off('CallRejected');
    _hubConnection?.on('CallRejected', (arguments) {
      SoundService().stopRingtone();
      SoundService().playCallEnd();
      onCallRejected?.call();
    });

    _hubConnection?.off('CallEnded');
    _hubConnection?.on('CallEnded', (arguments) {
      SoundService().stopRingtone();
      SoundService().playCallEnd();
      onCallEnded?.call();
    });
  }

  void _buildPresenceHub(String token) {
    if (_presenceHubConnection != null) return;

    _presenceHubConnection = HubConnectionBuilder()
        .withUrl(
          _presenceHubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
            skipNegotiation: true,
            transport: HttpTransportType.WebSockets,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _presenceHubConnection?.on('UserOnline', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        _userOnlineController.add(arguments[0] as String);
      }
    });
    _presenceHubConnection?.on('UserOffline', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        _userOfflineController.add(arguments[0] as String);
      }
    });
  }

  void _buildUserHub(String token) {
    if (_userHubConnection != null) return;

    _userHubConnection = HubConnectionBuilder()
        .withUrl(
          _userHubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
            skipNegotiation: true,
            transport: HttpTransportType.WebSockets,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _userHubConnection?.onclose(({Exception? error}) {
      AppConfig.log('[SignalR] User hub closed: $error');
    });

    _userHubConnection?.on('FriendRequestReceived', (arguments) {
      _friendRequestController.add(null);
    });
    _userHubConnection?.on('FriendRequestAccepted', (arguments) {
      _friendRequestController.add(null);
    });
  }

  Future<void> markAsRead(String conversationId) async {
    AppConfig.log(
      'ChatService: markAsRead called for $conversationId. State: ${_hubConnection?.state}',
    );
    if (_hubConnection?.state == HubConnectionState.Connected) {
      await _hubConnection?.invoke('MarkAsRead', args: [conversationId]);
      AppConfig.log('ChatService: markAsRead invoked successfully');
    } else {
      AppConfig.log('ChatService: markAsRead failed - Not Connected');
    }
  }

  Future<void> joinConversation(String conversationId) async {
    if (_hubConnection?.state != HubConnectionState.Connected) {
      try {
        await _hubConnection?.start();
      } catch (e) {
        AppConfig.log("Error starting hub connection in joinConversation: $e");
        return;
      }
    }
    await _hubConnection?.invoke('JoinConversation', args: [conversationId]);
  }

  Future<void> sendTyping(String conversationId) async {
    if (_hubConnection?.state == HubConnectionState.Connected) {
      final userId = await AuthService.getUserId();
      if (userId == null) return;
      await _hubConnection?.invoke('Typing', args: [conversationId, userId]);
    }
  }

  // === CALL SIGNALING METHODS ===
  Future<void> initiateCall({
    required String calleeId,
    required String callType,
  }) async {
    if (_hubConnection?.state == HubConnectionState.Connected) {
      final prefs = await SharedPreferences.getInstance();
      final callerName = prefs.getString('user_name') ?? 'Người dùng';
      await _hubConnection?.invoke(
        'InitiateCall',
        args: [calleeId, callType, callerName, ''],
      );
      AppConfig.log('Call: InitiateCall sent to $calleeId, type=$callType');
    }
  }

  Future<void> acceptCall({required String callerId}) async {
    if (_hubConnection?.state == HubConnectionState.Connected) {
      await _hubConnection?.invoke('AcceptCall', args: [callerId]);
      AppConfig.log('Call: AcceptCall sent to $callerId');
    }
  }

  Future<void> rejectCall({required String callerId}) async {
    if (_hubConnection?.state == HubConnectionState.Connected) {
      await _hubConnection?.invoke('RejectCall', args: [callerId]);
      AppConfig.log('Call: RejectCall sent to $callerId');
    }
  }

  Future<void> endCall({required String otherUserId}) async {
    if (_hubConnection?.state == HubConnectionState.Connected) {
      await _hubConnection?.invoke('EndCall', args: [otherUserId]);
      AppConfig.log('Call: EndCall sent to $otherUserId');
    }
  }

  // Get Presence for a specific user via HTTP API (or SignalR if implemented as Hub method)
  // Based on previous logs, it seems to use API endpoint: api/v1/presence/{userId}
  Future<Map<String, dynamic>?> getPresence(String userId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_presenceUrl/api/v1/presence/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        // User not found in presence DB - treat as Offline
        return {'status': 'Offline', 'userId': userId};
      } else {
        AppConfig.log(
          'Failed to get presence for $userId: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      AppConfig.log('Error getting presence: $e');
      return null;
    }
  }

  // Presence REST base URL from AppConfig
  String get _presenceUrl => AppConfig.presenceApiBaseUrl;

  // Get Presence for multiple users
  Future<List<Map<String, dynamic>>> getPresences(List<String> userIds) async {
    if (_presenceHubConnection?.state == HubConnectionState.Connected) {
      try {
        final result = await _presenceHubConnection?.invoke(
          'GetPresences',
          args: [userIds],
        );
        AppConfig.log('ChatService: GetPresences result: $result');

        if (result != null && result is List) {
          return result.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            // Normalize keys to camelCase/lowercase for robustness
            final normalized = <String, dynamic>{};
            map.forEach((key, value) {
              normalized[key.toLowerCase()] = value;
              // Also keep original just in case
              normalized[key] = value;
            });
            return normalized;
          }).toList();
        }
      } catch (e) {
        AppConfig.log('ChatService: Error invoking GetPresences: $e');
      }
    } else {
      AppConfig.log(
        'ChatService: GetPresences skipped - PresenceHub not connected',
      );
    }
    return [];
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppConfig.log('[ChatService] App Resumed -> Checking connections...');
      // Re-initialize if disconnected (e.g. after being killed)
      if (_hubConnection?.state == HubConnectionState.Disconnected ||
          _presenceHubConnection?.state == HubConnectionState.Disconnected) {
        initSignalR();
      } else {
        _startHeartbeat();
      }
    } else if (state == AppLifecycleState.detached) {
      // Only disconnect when the engine is completely detached (app killed)
      AppConfig.log('[ChatService] App Detached -> Disconnecting...');
      disconnect();
    }
    // NOTE: Do NOT disconnect on pause — keep connections alive for
    // background message delivery and faster resume.
  }

  Future<void> disconnect() async {
    AppConfig.log('[ChatService] disconnect: stopping SignalR connections...');
    _heartbeatTimer?.cancel();
    try {
      // Timeout each stop() call to prevent hanging forever
      await Future.wait([
        if (_hubConnection != null)
          _hubConnection!.stop().timeout(
            const Duration(seconds: 3),
            onTimeout: () =>
                AppConfig.log('[ChatService] chatHub stop timed out'),
          ),
        if (_presenceHubConnection != null)
          _presenceHubConnection!.stop().timeout(
            const Duration(seconds: 3),
            onTimeout: () =>
                AppConfig.log('[ChatService] presenceHub stop timed out'),
          ),
        if (_userHubConnection != null)
          _userHubConnection!.stop().timeout(
            const Duration(seconds: 3),
            onTimeout: () =>
                AppConfig.log('[ChatService] userHub stop timed out'),
          ),
      ]);
    } catch (e) {
      AppConfig.log('[ChatService] disconnect error (ignored): $e');
    }
    _hubConnection = null;
    _presenceHubConnection = null;
    _userHubConnection = null;
    AppConfig.log('[ChatService] disconnect: done');
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    // Singleton shouldn't really be disposed unless app terminates or logout
    _hubConnection?.stop();
    _presenceHubConnection?.stop();
    _userHubConnection?.stop();
    _userTypingController.close();
    _userOnlineController.close();
    _userOfflineController.close();
    _messageController.close();
    _messageReadController.close();
    _conversationCreatedController.close();
    _conversationUpdatedController.close();
    _conversationDeletedController.close();
    _messageReactedController.close();
    _messageDeletedController.close();
    _friendRequestController.close();
  }
}
