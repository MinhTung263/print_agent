import 'package:get/get.dart';
import 'package:print_agent_core/print_agent_core.dart';

import '../../data/agent_printer_reconnect.dart';
import '../../data/agent_printer_remote.dart';
import '../../data/agent_printer_watchdog.dart';
import '../../domain/entities/agent_printer_ref.dart';
import '../../domain/entities/agent_test_print_result.dart';

/// Wi-Fi của máy in (app chủ nhớ Wi-Fi từng máy in + mật khẩu đã dùng).
abstract interface class AgentWifi {
  /// Wi-Fi của máy in LAN [printer] (nếu đã nhớ).
  String? ssidOf(AgentPrinterRef printer);

  /// Xin quyền đọc tên Wi-Fi (Android cần quyền vị trí).
  Future<void> ensureNamePermission({bool force = false});

  /// Mật khẩu đã lưu của [ssid] (`null` khi chưa có).
  Future<String?> passwordFor(String ssid);

  /// Nối Wi-Fi [ssid] và ở lại; `true` khi nối được.
  Future<bool> switchTo(String ssid, {String password = ''});

  /// Hệ thống chỉ cho chọn Wi-Fi trong bảng của hệ thống (Android 10+).
  Future<bool> usesSystemPanel();

  /// Wi-Fi máy này đang nối (`null` khi không đọc được / dùng mạng dây).
  Future<String?> currentSsid();

  /// Các Wi-Fi đang bắt được sóng.
  Future<List<String>> nearby();

  /// Mở cài đặt Wi-Fi của hệ thống.
  Future<void> openSettings();
}

/// Cổng điều khiển máy Agent của app chủ cho màn Máy Agent: trạm in (bật / tắt
/// làm Agent, tên, thống kê) và các dịch vụ máy in đã gắn với máy in của app.
abstract interface class AgentStation {
  PrintRelay get relay;

  /// Mã Agent của máy này.
  String get stationId;

  /// Tên đặt cho máy Agent này (rỗng = dùng tên thiết bị).
  RxString get name;

  /// Tên hiển thị (tên đặt, chưa đặt thì tên thiết bị).
  String get displayName;

  Future<void> setName(String name);

  /// Máy này đang là Agent của công ty KHÁC công ty đang đăng nhập.
  bool get boundElsewhere;

  /// Bật / tắt làm Agent. [onOtherApp]: bản app khác trên máy đang làm Agent.
  Future<bool> setEnabled(
    bool on, {
    void Function(String otherApp)? onOtherApp,
  });

  /// Ngắt kết nối từ xa một trạm in khác.
  Future<bool> removeAgent(Map<Object?, Object?> station);

  /// Máy này là trạm in chính trong mạng (không có trạm cùng mạng ưu tiên
  /// hơn).
  RxBool get isPrimary;

  RxInt get printed;
  RxInt get failed;
  Rxn<DateTime> get lastJobAt;

  /// Phát khi thiết bị đổi mạng (Wi-Fi / dây / 4G).
  Stream<void> get networkChanges;

  AgentPrinterWatchdog<AgentPrinterRef> get watchdog;
  AgentPrinterReconnect<AgentPrinterRef> get reconnect;
  AgentPrinterRemote<AgentPrinterRef> get remote;
  AgentWifi get wifi;

  /// In thử máy in [printer] của máy này.
  Future<AgentTestPrintResult> testPrint(AgentPrinterRef printer);

  /// In thử máy in [printer] (một mục `printers.names`) của Agent [station].
  Future<AgentTestPrintResult> testPrintPeer(
    Map<Object?, Object?> station,
    Map<Object?, Object?> printer,
  );

  /// Hỏi các Agent đang trực tuyến, cập nhật máy in tích hợp của Agent khác.
  Future<void> refreshPeerBuiltIns();
}
