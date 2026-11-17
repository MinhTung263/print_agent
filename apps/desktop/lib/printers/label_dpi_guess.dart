/// Đoán độ phân giải đầu in (dpi) của máy tem từ TÊN model — tên ghi rõ "300" (VD
/// `4BARCODE 3B-300B`, `ZT230-300`, `TTP-346M 300dpi`) thì là máy 300dpi. Máy tem phổ thông
/// là 203dpi nên không có "300" trong tên thì không đoán (giữ 203, khách vẫn nhận biết bằng
/// tem thử). Chỉ là GỢI Ý để khách đỡ phải chọn — không thay cho việc kiểm tra bằng mắt.
abstract final class LabelDpiGuess {
  static final RegExp _has300 = RegExp(r'(?<![0-9])300(?![0-9])');

  /// `300` khi tên model ghi 300; `null` = không đoán được.
  static int? fromModel(String? model) {
    final name = (model ?? '').trim();
    if (name.isEmpty) return null;
    return _has300.hasMatch(name) ? 300 : null;
  }
}
