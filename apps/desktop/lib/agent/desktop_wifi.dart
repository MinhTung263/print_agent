import 'package:print_agent/print_agent.dart';

/// Máy tính: không đọc / đổi Wi-Fi từ app (dùng cài đặt mạng của hệ thống).
class DesktopWifi implements AgentWifi {
  const DesktopWifi();

  @override
  String? ssidOf(AgentPrinterRef printer) => null;

  @override
  Future<void> ensureNamePermission({bool force = false}) async {}

  @override
  Future<String?> passwordFor(String ssid) async => null;

  @override
  Future<bool> switchTo(String ssid, {String password = ''}) async => false;

  @override
  Future<bool> usesSystemPanel() async => true;

  @override
  Future<String?> currentSsid() async => null;

  @override
  Future<List<String>> nearby() async => const [];

  @override
  Future<void> openSettings() async {}
}
