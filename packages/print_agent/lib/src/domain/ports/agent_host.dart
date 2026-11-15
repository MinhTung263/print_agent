import '../entities/agent_printer_ref.dart';

/// Kho khoá–giá trị bền của app chủ (giữ qua khởi động lại). Giá trị là kiểu
/// JSON (Map / List / chuỗi / số / bool); [put] với `null` = XOÁ khoá (sau đó
/// [get] trả `null`).
abstract interface class AgentStorage {
  Object? get(String key);
  Future<void> put(String key, Object? value);
}

/// Mức thông báo hiện cho người dùng.
enum AgentNoticeLevel { info, success, warning, error }

/// Thông tin thiết bị (để máy khác nhận ra máy Agent này).
class AgentDeviceInfo {
  const AgentDeviceInfo({
    this.name = '',
    this.manufacturer = '',
    this.model = '',
  });

  /// Tên thiết bị do hệ thống báo (VD "Redmi Note 13").
  final String name;
  final String manufacturer;
  final String model;
}

/// Những gì module Agent cần từ app chủ (EasyPOS mobile / Agent máy tính) —
/// cổng (port) của clean architecture: module chỉ biết các giao diện này, không
/// gọi thẳng dịch vụ in / bộ nhớ / đa ngôn ngữ của app.
abstract interface class AgentHost {
  AgentStorage get storage;

  /// Mã công ty đang đăng nhập (dữ liệu Agent lưu riêng theo công ty).
  String get companyKey;

  /// Khoá hàng đợi in của công ty (`{môi trường}/c{công ty}_{chủ}`); `null`
  /// khi chưa đăng nhập.
  String? get shopKey;

  /// Tên gói app đang chạy (VD `vn.softdreams.easypos.dev`).
  String get appPackage;

  /// Tên người dùng đặt cho thiết bị trong app (ưu tiên nhất khi hiện tên máy).
  String? get appDeviceName;

  /// Thiết bị (hệ thống báo); `null` khi không đọc được.
  AgentDeviceInfo? get device;

  /// Máy in đã lưu trên máy này.
  List<AgentPrinterRef> get printers;

  /// Hiện thông báo ngắn; [actionLabel] (khoá đa ngôn ngữ) + [onAction]: nút
  /// trên thông báo (VD "In lại").
  void notify(
    String message, {
    AgentNoticeLevel level = AgentNoticeLevel.info,
    Duration? duration,
    String? actionLabel,
    void Function()? onAction,
  });

  void log(String message);
}
