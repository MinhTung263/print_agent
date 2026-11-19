import '../entities/agent_print_route.dart';

/// Mẫu in của công ty để chọn cho một chức năng.
class AgentPrintTemplate {
  const AgentPrintTemplate({
    required this.id,
    required this.name,
    required this.function,
  });

  final int id;
  final String name;

  /// Loại chứng từ của mẫu (chỉ gợi ý mẫu phù hợp chức năng).
  final AgentPrintFunction function;
}

/// Kho cấu hình in theo chức năng — THEO TÀI KHOẢN (công ty), dùng chung mọi
/// máy; Agent chỉ là nơi người dùng sửa. App chủ cài đặt qua API `print_setting`.
abstract interface class AgentPrintRoutingStore {
  /// Cấu hình hiện có của công ty (thiết lập chung, không theo khu vực).
  Future<List<AgentPrintRoute>> load();

  /// Lưu toàn bộ cấu hình; ném lỗi khi máy chủ từ chối.
  Future<void> save(List<AgentPrintRoute> routes);

  /// Các mẫu in của công ty.
  Future<List<AgentPrintTemplate>> templates();

  /// Tên các máy in của công ty để chọn.
  Future<List<String>> printers();

  /// Máy in đang kết nối / mặc định của cửa hàng (điền sẵn khi thêm chức năng);
  /// `null` = không có.
  Future<String?> defaultPrinter();

  /// Hỏi xem trước hoá đơn khi thanh toán (`preview_before_payment`).
  Future<bool> previewBeforePayment();
  Future<void> setPreviewBeforePayment(bool value);

  /// Hỏi số bản in mỗi lần in (`print_copies_mode` = 0) hay in mặc định 1 bản.
  Future<bool> askCopiesEachPrint();
  Future<void> setAskCopiesEachPrint(bool value);
}
