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
  });

  /// `type` của app: bluetooth 0, LAN 1, USB 2, máy in tích hợp 3.
  static const int typeLan = 1;

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
      templates: [
        if (raw['typeTemplates'] is List)
          for (final t in raw['typeTemplates'] as List)
            if (int.tryParse('$t') != null) int.parse('$t'),
      ],
    );
  }

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
