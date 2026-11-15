import 'dart:async';

import 'package:print_agent/print_agent.dart';

import 'agent_config.dart';
import 'agent_printer.dart';
import 'desktop_printer.dart';

/// Cổng máy in của Agent máy tính: "máy in tích hợp" = máy in đã chọn ở cài
/// đặt (LAN / USB); không có danh sách máy in đã lưu như app bán hàng.
class DesktopPrinterGateway implements AgentPrinterGateway<DesktopPrinter> {
  DesktopPrinterGateway(this._config);

  final AgentConfig Function() _config;

  bool _connected = false;
  final _builtIn = StreamController<bool>.broadcast();
  final _printers = StreamController<void>.broadcast();

  /// Máy in của Agent kết nối được không (lần kiểm tra gần nhất).
  bool get connected => _connected;

  void _setConnected(bool ok) {
    if (ok == _connected) return;
    _connected = ok;
    _builtIn.add(ok);
  }

  /// Cài đặt máy in vừa đổi: kiểm tra lại + báo cho máy khác.
  Future<void> printerChanged() async {
    _connected = false;
    _printers.add(null);
    await reconnectBuiltIn();
  }

  @override
  List<DesktopPrinter> get printers => const [];

  @override
  bool get hasBuiltIn => _config().hasPrinter;

  @override
  bool get builtInConnected => _connected;

  @override
  Stream<bool> get builtInChanges => _builtIn.stream;

  @override
  Stream<void> get printersChanged => _printers.stream;

  @override
  DesktopPrinter builtInPrinter() => DesktopPrinter(
    kind: AgentPrinterKind.builtIn,
    address: _config().printer.trim(),
    name: DesktopPrinter.builtInName,
    id: -1,
  );

  @override
  Future<void> reconnectBuiltIn() async {
    if (!hasBuiltIn) return _setConnected(false);
    _setConnected(await AgentPrinter.reachable(_config().printer));
  }

  @override
  Future<bool> isUsbAttached(DesktopPrinter printer) =>
      AgentPrinter.reachable(printer.address);

  @override
  Future<bool> connectUsb(DesktopPrinter printer) =>
      AgentPrinter.reachable(printer.address);

  @override
  Future<bool> isReady(DesktopPrinter printer) async {
    final ok = await AgentPrinter.reachable(printer.address);
    if (printer.kind == AgentPrinterKind.builtIn) _setConnected(ok);
    return ok;
  }

  /// Máy tính không tìm lại máy in theo MAC (chưa hỗ trợ).
  @override
  Future<DesktopPrinter?> relocate(
    DesktopPrinter printer, {
    Duration? timeout,
  }) async => null;

  @override
  String? wifiSsidOf(DesktopPrinter printer) => null;

  /// Đổi mạng: IP máy tính đổi (kiểm tra mỗi 15s, chỉ đọc IP — nhẹ).
  @override
  Stream<void> get networkChanges async* {
    var last = (await PrintRelayLanServer.localIpv4s()).join(',');
    await for (final _ in Stream<void>.periodic(const Duration(seconds: 15))) {
      final now = (await PrintRelayLanServer.localIpv4s()).join(',');
      if (now == last) continue;
      last = now;
      yield null;
    }
  }
}
