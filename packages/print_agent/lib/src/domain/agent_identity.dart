import 'package:get/get.dart';

import '../l10n/agent_locale_keys.dart';

/// Cách gọi một máy Agent cho người dùng phân biệt: tên (đặt trên máy Agent,
/// chưa đặt thì tên thiết bị) + mã ngắn cố định `#A3F9` (4 ký tự cuối mã máy) —
/// 2 máy cùng loại (VD 2 Sunmi T1-G) trùng tên vẫn phân biệt được.
abstract final class AgentIdentity {
  /// Mã ngắn hiển thị của Agent [stationId] (VD `#A3F9`); rỗng khi không có mã.
  static String shortId(String? stationId) {
    final id = stationId?.trim() ?? '';
    if (id.isEmpty) return '';
    final tail = id.length <= 4 ? id : id.substring(id.length - 4);
    return '#${tail.toUpperCase()}';
  }

  /// "Quầy bar · #A3F9" — chưa có tên thì "Máy Agent · #A3F9".
  static String label(String? name, String? stationId) {
    final n = name?.trim() ?? '';
    final shown = n.isEmpty ? LocaleKeys.printerSetting_agentDashboard.tr : n;
    final code = shortId(stationId);
    return code.isEmpty ? shown : '$shown · $code';
  }

  /// [label] từ thông tin trạm (`{name, id, ...}`) Agent báo khi trực tuyến.
  static String ofStation(Map<Object?, Object?> station) =>
      label(station['name']?.toString(), station['id']?.toString());

  /// Bản app từ tên gói: "Dev" / "Staging" / "EasyPOS" (bản chính).
  static String appLabel(String? package) {
    final p = package?.trim() ?? '';
    if (p.isEmpty) return '';
    final last = p.split('.').last.toLowerCase();
    return switch (last) {
      'dev' => 'EasyPOS Dev',
      'stg' || 'staging' => 'EasyPOS Staging',
      'uat' => 'EasyPOS UAT',
      _ => 'EasyPOS',
    };
  }

  /// "Sunmi T1-G · EasyPOS Dev" — model + bản app Agent báo (bản cũ chưa báo
  /// thì rỗng).
  static String deviceLine(Map<Object?, Object?> station) {
    final model = station['model']?.toString().trim() ?? '';
    final app = appLabel(station['app']?.toString());
    return [model, app].where((e) => e.isNotEmpty).join(' · ');
  }

  /// Agent không có máy in nào (không báo máy in, không có máy in tích hợp).
  static bool hasNoPrinters(Map<Object?, Object?> station) {
    if (station['builtIn'] is Map) return false;
    final printers = station['printers'];
    if (printers is! Map) return true;
    final total = printers['total'];
    return total is! int || total == 0;
  }

  /// Ngắt kết nối từ xa được: trạm không có máy in, hoặc trạm bản mới (biết
  /// lệnh ngắt cả khi còn máy in — báo `stop` trong thông tin trạm).
  static bool canStopRemotely(Map<Object?, Object?> station) =>
      station['stop'] == true || hasNoPrinters(station);
}
