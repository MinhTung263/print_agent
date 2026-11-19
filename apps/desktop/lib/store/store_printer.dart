/// Máy in trong danh sách máy in của cửa hàng (máy chủ EasyPOS — các máy bán
/// hàng dùng chung).
class StorePrinter {
  const StorePrinter({
    this.id,
    required this.name,
    required this.ip,
    this.mac,
    this.type = typeLan,
    this.pageSize = 'K80',
    this.templates = const [],
    this.raw = const {},
  });

  /// `type` của app: bluetooth 0, LAN 1, USB 2, máy in tích hợp 3.
  static const int typeLan = 1;
  static const int typeUsb = 2;

  /// Mẫu in hoá đơn (mã của app): tạm tính 0, thanh toán 1, chế biến 2, huỷ
  /// món 3, phục vụ 4, QR thanh toán 6, đơn thuốc 7 (không gồm tem = 5).
  static const List<int> receiptTemplates = [0, 1, 2, 3, 4, 6, 7];

  final int? id;
  final String name;

  /// `ip` hoặc `ip:cổng`.
  final String ip;
  final String? mac;
  final int type;
  final String pageSize;
  final List<int> templates;

  /// Bản ghi gốc máy chủ trả về — để SỬA đúng một trường mà giữ nguyên các trường khác (khổ
  /// giấy, khu vực chế biến...) khi gửi lại.
  final Map<String, Object?> raw;

  static StorePrinter? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final ip = raw['ipAddress']?.toString().trim() ?? '';
    final type = raw['type'];
    return StorePrinter(
      id: raw['id'] is int ? raw['id'] as int : int.tryParse('${raw['id']}'),
      name: raw['printName']?.toString() ?? '',
      ip: ip,
      mac: raw['macAddress']?.toString(),
      type: type is int ? type : int.tryParse('$type') ?? typeLan,
      pageSize: raw['pageSize']?.toString() ?? 'K80',
      raw: {for (final e in raw.entries) '${e.key}': e.value},
      templates: [
        if (raw['typeTemplates'] is List)
          for (final t in raw['typeTemplates'] as List)
            if (int.tryParse('$t') != null) int.parse('$t'),
      ],
    );
  }

  /// Nội dung sửa máy in: giữ nguyên các trường máy chủ đã trả, chỉ đổi chức năng
  /// ([templates], mã của app). Danh sách rỗng gửi `null` (như app bán hàng).
  Map<String, Object?> toUpdateJson(List<int> newTemplates, int comId) => {
    'id': id,
    'printName': raw['printName'] ?? name,
    'ipAddress': raw['ipAddress'] ?? ip,
    'macAddress': raw['macAddress'] ?? mac,
    'type': raw['type'] ?? type,
    'pageSize': raw['pageSize'] ?? pageSize,
    'typeTemplates': newTemplates.isEmpty ? null : newTemplates,
    'processingAreaIds': raw['processingAreaIds'],
    'comId': raw['comId'] ?? comId,
  };

  Map<String, Object?> toCreateJson(int comId) => {
    'printName': name,
    'ipAddress': ip,
    'macAddress': mac,
    'type': type,
    'pageSize': pageSize,
    'typeTemplates': templates,
    'processingAreaIds': const <int>[],
    'comId': comId,
  };
}
