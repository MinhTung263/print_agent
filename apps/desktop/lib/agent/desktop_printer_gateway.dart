import 'dart:async';

import 'package:print_agent/print_agent.dart';
import 'package:printer_label/desktop.dart';

import 'agent_config.dart';
import 'agent_printer.dart';
import 'desktop_printer.dart';

/// Cổng máy in của Agent máy tính: "máy in tích hợp" = máy in đã chọn ở cài
/// đặt (LAN / USB); không có danh sách máy in đã lưu như app bán hàng.
class DesktopPrinterGateway implements AgentPrinterGateway<DesktopPrinter> {
  DesktopPrinterGateway(
    this._config, {
    Future<void> Function(String address)? onRelocated,
    Future<String?> Function(String mac, int port)? findByMac,
  }) : _onRelocated = onRelocated,
       _findByMac = findByMac ?? _scanByMac;

  final AgentConfig Function() _config;

  /// Máy in của Agent vừa được tìm thấy ở địa chỉ mới (lưu lại cấu hình).
  final Future<void> Function(String address)? _onRelocated;
  final Future<String?> Function(String mac, int port) _findByMac;

  static Future<String?> _scanByMac(String mac, int port) =>
      LanPrinterScanner.findByMac(mac, port: port);

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
    mac: _config().printerMac.isEmpty ? null : _config().printerMac,
  );

  /// Kiểm tra máy in của Agent; không tới được mà biết MAC thì tìm lại (máy
  /// in bật lại nhận IP mới) — chạy trong lượt canh định kỳ / khi máy thức.
  @override
  Future<void> reconnectBuiltIn() async {
    if (!hasBuiltIn) return _setConnected(false);
    if (await AgentPrinter.reachable(_config().printer)) {
      return _setConnected(true);
    }
    _setConnected(await relocate(builtInPrinter()) != null);
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

  /// Máy in LAN không trả lời: có thể bật lại được router cấp IP mới — tìm
  /// theo MAC (quét dải mạng + bảng ARP). Thấy ở địa chỉ khác thì trả máy in
  /// với địa chỉ mới; máy in của Agent thì lưu lại cấu hình luôn.
  @override
  Future<DesktopPrinter?> relocate(
    DesktopPrinter printer, {
    Duration? timeout,
  }) async {
    final mac = printer.mac;
    if (mac == null || mac.isEmpty || UsbPrinters.isLocal(printer.address)) {
      return null;
    }
    final parsed = parsePrinterAddress(printer.address);
    if (parsed == null) return null;
    final found = await _findByMac(mac, parsed.$2);
    if (found == null || found == printer.address) return null;
    PrintAgentModule.host.log(
      '[AGENT] ${printer.refName}: đổi IP ${printer.address} → $found (theo MAC)',
    );
    if (printer.kind == AgentPrinterKind.builtIn) {
      await _onRelocated?.call(found);
      _setConnected(true);
    }
    return printer.withAddress(found);
  }

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
