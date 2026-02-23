import 'dart:convert';

enum CallDirection { incoming, outgoing }

enum CallStatus { completed, missed, rejected }

enum CallType { audio, video }

class CallLog {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final CallType callType;
  final CallDirection direction;
  final CallStatus status;
  final DateTime startedAt;
  final int durationSeconds; // 0 if missed/rejected

  const CallLog({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.callType,
    required this.direction,
    required this.status,
    required this.startedAt,
    this.durationSeconds = 0,
  });

  CallLog copyWith({CallStatus? status, int? durationSeconds}) {
    return CallLog(
      id: id,
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      otherUserAvatar: otherUserAvatar,
      callType: callType,
      direction: direction,
      status: status ?? this.status,
      startedAt: startedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'otherUserId': otherUserId,
    'otherUserName': otherUserName,
    'otherUserAvatar': otherUserAvatar,
    'callType': callType.name,
    'direction': direction.name,
    'status': status.name,
    'startedAt': startedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
  };

  factory CallLog.fromJson(Map<String, dynamic> json) => CallLog(
    id: json['id'] as String,
    otherUserId: json['otherUserId'] as String,
    otherUserName: json['otherUserName'] as String,
    otherUserAvatar: json['otherUserAvatar'] as String?,
    callType: CallType.values.firstWhere(
      (e) => e.name == json['callType'],
      orElse: () => CallType.audio,
    ),
    direction: CallDirection.values.firstWhere(
      (e) => e.name == json['direction'],
      orElse: () => CallDirection.outgoing,
    ),
    status: CallStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => CallStatus.completed,
    ),
    startedAt: DateTime.parse(json['startedAt'] as String),
    durationSeconds: (json['durationSeconds'] as int?) ?? 0,
  );

  static String encodeList(List<CallLog> logs) =>
      jsonEncode(logs.map((l) => l.toJson()).toList());

  static List<CallLog> decodeList(String source) {
    final list = jsonDecode(source) as List<dynamic>;
    return list
        .map((e) => CallLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
