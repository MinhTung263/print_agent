/// Chức năng in cấu hình qua Agent (`type_template` của bảng `print_setting`).
enum AgentPrintFunction {
  provisional(0, 'Tạm tính'),
  payment(1, 'Thanh toán'),
  kitchen(2, 'Chế biến'),
  cancelDish(3, 'Huỷ món'),
  supply(4, 'Cung ứng'),
  paymentQr(5, 'QR thanh toán'),
  label(6, 'Tem nhãn'),
  prescription(7, 'Đơn thuốc');

  const AgentPrintFunction(this.value, this.title);

  /// Giá trị lưu ở `type_template`.
  final int value;

  /// Tên mặc định hiển thị.
  final String title;

  static AgentPrintFunction? fromValue(int? value) {
    for (final f in values) {
      if (f.value == value) return f;
    }
    return null;
  }
}

/// Một dòng cấu hình: chức năng in ra máy in nào bằng mẫu in nào, bao nhiêu bản.
///
/// Thiết lập chung của công ty (không gắn khu vực chế biến): bản ghi mặc định
/// khi tạo tài khoản có máy in và mẫu in đều rỗng — hợp lệ (chưa cấu hình).
class AgentPrintRoute {
  const AgentPrintRoute({
    required this.function,
    this.name,
    this.printerName,
    this.templateId,
    this.copies = 1,
  });

  final AgentPrintFunction function;

  /// Tên chức năng người dùng đặt (rỗng = dùng tên mặc định của [function]).
  final String? name;

  /// Máy in (`print_name`); rỗng = chưa chọn.
  final String? printerName;

  /// Mẫu in (`print_template_id`); rỗng = không có mẫu in.
  final int? templateId;

  /// Số bản in (`print_count`), tối thiểu 1.
  final int copies;

  String get title =>
      (name ?? '').trim().isEmpty ? function.title : name!.trim();

  bool get hasPrinter => (printerName ?? '').trim().isNotEmpty;
  bool get hasTemplate => templateId != null;

  /// Chưa cấu hình gì (cả máy in lẫn mẫu in đều trống).
  bool get isEmpty => !hasPrinter && !hasTemplate;

  AgentPrintRoute copyWith({
    String? name,
    String? printerName,
    int? templateId,
    int? copies,
    bool clearPrinter = false,
    bool clearTemplate = false,
  }) => AgentPrintRoute(
    function: function,
    name: name ?? this.name,
    printerName: clearPrinter ? null : (printerName ?? this.printerName),
    templateId: clearTemplate ? null : (templateId ?? this.templateId),
    copies: copies ?? this.copies,
  );
}
