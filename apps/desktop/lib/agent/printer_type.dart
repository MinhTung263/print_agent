/// Máy in của Agent là máy in hoá đơn (ESC/POS) hay máy in tem (TSPL): lệnh in
/// hoá đơn gửi tới máy in tem (và ngược lại) không ra gì hoặc ra ký tự lạ.
enum PrinterType {
  receipt('Hoá đơn', 'Máy in hoá đơn'),
  label('Tem', 'Máy in tem');

  const PrinterType(this.short, this.title);

  /// Chữ ngắn trên nút chọn.
  final String short;

  /// Tên đầy đủ.
  final String title;

  static PrinterType fromName(String? name) => PrinterType.values.firstWhere(
    (t) => t.name == name,
    orElse: () => receipt,
  );
}
