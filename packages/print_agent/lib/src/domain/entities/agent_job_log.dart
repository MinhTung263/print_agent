import 'package:collection/collection.dart';

/// Lý do một lệnh in hộ bị lỗi (máy Agent hiển thị theo ngôn ngữ đang dùng).
enum AgentJobError {
  /// Lệnh không có ảnh in.
  noContent,

  /// Máy in LAN ở dải mạng khác — máy Agent không tới được.
  otherNetwork,

  /// Máy in không trả lời (tắt nguồn / mất mạng / hết giấy...).
  notReady,

  /// Máy in tích hợp của máy Agent chưa sẵn sàng.
  builtInNotReady,

  /// Kết nối được máy in nhưng gửi lệnh in lỗi.
  sendFailed,

  /// Đứt kết nối khi ĐANG gửi: phiếu có thể đã ra một phần. KHÔNG tự thử lại / giữ lệnh (có thể in trùng) — khác
  /// [unreachable] / [busy] là lỗi xảy ra TRƯỚC khi gửi byte nào.
  interrupted,

  /// Máy in báo hết giấy.
  outOfPaper,

  /// Máy in báo đang mở nắp.
  coverOpen,

  /// Máy in báo quá nóng.
  overheated,

  /// Máy in đang bận (máy khác đang giữ kết nối / đang in).
  busy,

  /// Không kết nối được máy in lúc gửi (tắt nguồn / mất mạng / sai IP).
  unreachable;

  static AgentJobError? fromName(Object? name) =>
      values.firstWhereOrNull((e) => e.name == name);
}

/// Một lệnh máy Agent đã in hộ: máy nào gửi, hoá đơn hay tem, in ra máy in nào,
/// kết quả / lý do lỗi.
class AgentJobLog {
  const AgentJobLog({
    required this.at,
    required this.isLabel,
    required this.printerName,
    required this.ok,
    required this.viaLan,
    required this.durationMs,
    this.sender,
    this.copies = 1,
    this.error,
    this.printerAddress,
    this.connection,
    this.detail,
  });

  final DateTime at;

  /// Tên máy gửi lệnh (`null` khi máy gửi chạy bản cũ).
  final String? sender;
  final bool isLabel;
  final String printerName;
  final int copies;
  final bool ok;
  final AgentJobError? error;

  /// IP (máy LAN) / mã USB của máy in.
  final String? printerAddress;

  /// `lan` / `usb` / `builtin`.
  final String? connection;

  /// Câu chi tiết máy in (native) báo kèm lỗi, nếu có.
  final String? detail;

  /// Lệnh tới thẳng qua mạng nội bộ (không qua đám mây).
  final bool viaLan;

  /// Thời gian máy Agent in (kể cả chờ máy in sẵn sàng).
  final int durationMs;

  Map<String, Object?> toMap() => {
    'at': at.millisecondsSinceEpoch,
    'sender': sender,
    'label': isLabel,
    'printer': printerName,
    'copies': copies,
    'ok': ok,
    'error': error?.name,
    'addr': printerAddress,
    'conn': connection,
    'detail': detail,
    'lan': viaLan,
    'ms': durationMs,
  };

  static AgentJobLog? fromMap(Object? raw) {
    if (raw is! Map || raw['at'] is! int) return null;
    return AgentJobLog(
      at: DateTime.fromMillisecondsSinceEpoch(raw['at'] as int),
      sender: raw['sender']?.toString(),
      isLabel: raw['label'] == true,
      printerName: raw['printer']?.toString() ?? '',
      copies: raw['copies'] is int ? raw['copies'] as int : 1,
      ok: raw['ok'] == true,
      error: AgentJobError.fromName(raw['error']),
      printerAddress: raw['addr']?.toString(),
      connection: raw['conn']?.toString(),
      detail: raw['detail']?.toString(),
      viaLan: raw['lan'] == true,
      durationMs: raw['ms'] is int ? raw['ms'] as int : 0,
    );
  }
}
