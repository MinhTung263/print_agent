import 'package:print_agent_core/print_agent_core.dart';

import '../print_agent_module.dart';

/// Lệnh đang GIỮ (máy in hết giấy / mở nắp — chưa in gì) lưu xuống máy để
/// app tắt / máy khởi động lại giữa chừng vẫn in tiếp, không mất phiếu bếp.
///
/// - Chỉ lưu lệnh có mã ([PrintRelayJob.dedupeKey]) để in lại không bị đúp.
/// - Lệnh quá [maxAge] (tính từ lúc bắt đầu giữ) thì bỏ — phiếu cũ in ra
///   bếp lúc đó không còn đúng.
/// - Theo công ty; tối đa [maxJobs] lệnh.
class AgentHeldJobStore {
  AgentHeldJobStore({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const Duration maxAge = Duration(minutes: 15);
  static const int maxJobs = 30;

  final DateTime Function() _now;

  String get _key => 'agent_held_jobs_${PrintAgentModule.host.companyKey}';

  List<Map<String, Object?>> _read() {
    try {
      final raw = PrintAgentModule.host.storage.get(_key);
      if (raw is! List) return [];
      return [
        for (final e in raw)
          if (e is Map) Map<String, Object?>.from(e),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<Map<String, Object?>> items) async {
    try {
      await PrintAgentModule.host.storage.put(
        _key,
        items.isEmpty ? null : items,
      );
    } catch (_) {}
  }

  /// Bắt đầu giữ [job]: lưu lại (đã lưu thì thôi).
  Future<void> save(PrintRelayJob job) async {
    final id = job.dedupeKey;
    if (id.isEmpty) return;
    final items = _read();
    if (items.any((e) => e['id'] == id)) return;
    items.add({
      'id': id,
      'at': _now().millisecondsSinceEpoch,
      'job': job.toMap(),
    });
    while (items.length > maxJobs) {
      items.removeAt(0);
    }
    await _write(items);
  }

  /// [job] đã xong (in được / lỗi hẳn): bỏ khỏi danh sách.
  Future<void> remove(PrintRelayJob job) async {
    final id = job.dedupeKey;
    if (id.isEmpty) return;
    final items = _read();
    final before = items.length;
    items.removeWhere((e) => e['id'] == id);
    if (items.length != before) await _write(items);
  }

  /// Lấy ra (và xoá khỏi máy) các lệnh còn hạn để in lại, cũ trước.
  Future<List<PrintRelayJob>> takePending() async {
    final items = _read();
    if (items.isEmpty) return const [];
    final cutoff = _now().subtract(maxAge).millisecondsSinceEpoch;
    final jobs = <PrintRelayJob>[];
    for (final e in items) {
      final at = e['at'];
      if (at is! int || at < cutoff) continue;
      final job = PrintRelayJob.fromMap(e['id']?.toString() ?? '', e['job']);
      if (job != null && job.images.isNotEmpty) jobs.add(job);
    }
    await _write(const []);
    return jobs;
  }
}
