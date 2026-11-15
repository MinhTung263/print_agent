import 'dart:async';

import 'package:get/get.dart';

import '../domain/entities/agent_job_log.dart';
import '../print_agent_module.dart';

/// Nhật ký lệnh in hộ gần đây của máy Agent — lưu trên máy THEO CÔNG TY (giữ
/// qua khởi động lại), tối đa [_max] lệnh. Lần ghi xuống bộ nhớ được gom
/// [_saveDelay] một lần: giờ cao điểm nhiều đơn liên tiếp không ghi đĩa liên
/// tục (đỡ giật giao diện, tránh ghi chồng).
abstract final class AgentJobLogStore {
  static const String _storagePrefix = 'agent_job_log';
  static const int _max = 30;
  static const Duration _saveDelay = Duration(seconds: 3);

  /// Mới nhất ở đầu.
  static final RxList<AgentJobLog> logs = <AgentJobLog>[].obs;

  static String? _loadedFor;
  static Timer? _saveTimer;

  static String get _storageKey =>
      '${_storagePrefix}_${PrintAgentModule.host.companyKey}';

  /// Đọc nhật ký của công ty đang đăng nhập (đổi công ty thì đọc lại) — gọi
  /// NGOÀI lúc dựng giao diện. Bản cũ lưu chung một khoá: chuyển sang công ty
  /// mở đầu tiên.
  static void ensureLoaded() {
    final key = _storageKey;
    if (_loadedFor == key) return;
    if (_saveTimer != null) _flush();
    _loadedFor = key;
    final storage = PrintAgentModule.host.storage;
    try {
      var raw = storage.get(key);
      final legacy = storage.get(_storagePrefix);
      if (raw == null && legacy != null) {
        raw = legacy;
        unawaited(storage.put(key, legacy));
        unawaited(storage.put(_storagePrefix, null));
      }
      logs.assignAll([
        if (raw is List)
          for (final e in raw) ?AgentJobLog.fromMap(e),
      ]);
    } catch (_) {
      logs.clear();
    }
  }

  static void add(AgentJobLog log) {
    ensureLoaded();
    logs.insert(0, log);
    if (logs.length > _max) logs.removeRange(_max, logs.length);
    _saveTimer ??= Timer(_saveDelay, _flush);
  }

  /// Ghi ngay phần chưa lưu (đổi công ty / trước khi thoát).
  static void _flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final key = _loadedFor;
    if (key == null) return;
    try {
      unawaited(
        PrintAgentModule.host.storage.put(key, [
          for (final l in logs) l.toMap(),
        ]),
      );
    } catch (_) {}
  }
}
