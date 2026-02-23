import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/call_log_model.dart';

class CallLogService {
  static final CallLogService _instance = CallLogService._internal();
  factory CallLogService() => _instance;
  CallLogService._internal();

  static const _key = 'call_logs';
  static const _maxLogs = 100;
  static const _uuid = Uuid();

  static String generateId() => _uuid.v4();

  Future<List<CallLog>> getLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return CallLog.decodeList(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> addLog(CallLog log) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await getLogs();
    // Insert at beginning (newest first)
    logs.insert(0, log);
    // Cap at max
    if (logs.length > _maxLogs) logs.removeRange(_maxLogs, logs.length);
    await prefs.setString(_key, CallLog.encodeList(logs));
  }

  Future<void> updateLog(
    String id, {
    CallStatus? status,
    int? durationSeconds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await getLogs();
    final idx = logs.indexWhere((l) => l.id == id);
    if (idx != -1) {
      logs[idx] = logs[idx].copyWith(
        status: status,
        durationSeconds: durationSeconds,
      );
      await prefs.setString(_key, CallLog.encodeList(logs));
    }
  }

  Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
