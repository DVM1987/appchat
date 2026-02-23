import 'package:flutter/material.dart';

import '../../../data/models/call_log_model.dart';
import '../../../data/services/call_log_service.dart';

class CallLogProvider extends ChangeNotifier {
  final _service = CallLogService();
  List<CallLog> _logs = [];
  bool _isLoading = false;

  List<CallLog> get logs => List.unmodifiable(_logs);
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _logs = await _service.getLogs();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addLog(CallLog log) async {
    await _service.addLog(log);
    _logs.insert(0, log);
    // Cap at 100
    if (_logs.length > 100) _logs.removeRange(100, _logs.length);
    notifyListeners();
  }

  Future<void> updateLog(
    String id, {
    CallStatus? status,
    int? durationSeconds,
  }) async {
    await _service.updateLog(
      id,
      status: status,
      durationSeconds: durationSeconds,
    );
    final idx = _logs.indexWhere((l) => l.id == id);
    if (idx != -1) {
      _logs[idx] = _logs[idx].copyWith(
        status: status,
        durationSeconds: durationSeconds,
      );
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    await _service.clearLogs();
    _logs.clear();
    notifyListeners();
  }
}
