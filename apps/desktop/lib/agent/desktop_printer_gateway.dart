import 'dart:async';

import 'package:print_agent/print_agent.dart';
import 'package:printer_label/desktop.dart';

import 'agent_config.dart';
import 'agent_printer.dart';
import 'desktop_extra_printers.dart';
import 'desktop_printer.dart';

/// Cổng máy in của Agent máy tính: "máy in tích hợp" = máy in đã chọn ở cài
/// đặt (LAN / USB). Bật "In hộ máy in LAN" thì [printers] là các máy in LAN đã
/// in giúp ([DesktopLanPrinters]) — hiện trên sơ đồ, tạm ngưng riêng từng máy.
class DesktopPrinterGateway implements AgentPrinterGateway<DesktopPrinter> {
  DesktopPrinterGateway(
    this._config, {
    Future<void> Function(String address)? onRelocated,
    Future<String?> Function(String mac, int port)? findByMac,
    Future<String?> Function(String ip)? macOf,
  }) : _onRelocated = onRelocated,
       _findByMac = findByMac ?? _scanByMac,
       _macOf = macOf ?? ArpTable.macOf {
    extras = DesktopExtraPrinters(() => '${_config().companyId ?? 0}');
  }

  final AgentConfig Function() _config;

  /// Máy in thêm ngoài máy in chính (luôn hiện trên sơ đồ).
  late final DesktopExtraPrinters extras;
  final Future<String?> Function(String ip) _macOf;

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
  List<DesktopPrinter> get printers {
    // Máy in chính của trạm in đã hiện riêng — không hiện lần nữa.
    final own = _config().printer.trim();
    return [
      for (final e in extras.items)
        if (e.address != own) e.toPrinter(),
    ];
  }

  /// Danh sách máy in thêm vừa đổi: báo lại sơ đồ / máy khác.
  void extrasChanged() => _printers.add(null);

  /// Vừa in ra máy in thêm [printer]: chưa biết MAC thì đọc bảng ARP (vừa nối tới máy
  /// in) để tìm lại được khi máy in đổi IP.
  Future<void> printedFor(DesktopPrinter printer) async {
    if (printer.kind != AgentPrinterKind.lan) return;
    final known = extras.byAddress(printer.address);
    if (known == null || known.mac.isNotEmpty) return;
    final parsed = parsePrinterAddress(printer.address);
    if (parsed == null) return;
    final mac = await _macOf(parsed.$1);
    if (mac == null) return;
    if (extras.update(printer.address, mac: mac)) _printers.add(null);
  }

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
    name: DesktopPrinter.nameFor(_config()),
    id: -1,
    mac: _config().printerMac.isEmpty ? null : _config().printerMac,
  );

  /// Kiểm tra máy in của Agent; không tới được mà biết MAC thì tìm lại (máy
  /// in bật lại nhận IP mới) — chạy trong lượt canh định kỳ / khi máy thức.
  @override
  Future<void> reconnectBuiltIn() async {
    if (!hasBuiltIn) return _setConnected(false);
    if (await AgentPrinter.reachable(
      _config().printer,
      mac: _config().printerMac,
    )) {
      return _setConnected(true);
    }
    _setConnected(await relocate(builtInPrinter()) != null);
  }

  @override
  Future<bool> isUsbAttached(DesktopPrinter printer) =>
      AgentPrinter.reachable(printer.address, mac: printer.mac);

  @override
  Future<bool> connectUsb(DesktopPrinter printer) =>
      AgentPrinter.reachable(printer.address, mac: printer.mac);

  @override
  Future<bool> isReady(DesktopPrinter printer) async {
    final ok = await AgentPrinter.reachable(printer.address, mac: printer.mac);
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
    if (UsbPrinters.isLocal(printer.address)) return _relocateUsb(printer);
    final mac = printer.mac;
    if (mac == null || mac.isEmpty) return null;
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
    } else if (extras.moved(printer.address, found)) {
      _printers.add(null);
    }
    return printer.withAddress(found);
  }

  /// Máy in USB rút cắm sang cổng khác (Windows đổi đường dẫn thiết bị theo cổng): tìm lại
  /// theo VID/PID, không giành máy đã cấu hình cho vị trí khác. Máy in của Agent thì lưu
  /// lại cấu hình luôn.
  Future<DesktopPrinter?> _relocateUsb(DesktopPrinter printer) async {
    final taken = {
      for (final p in printers)
        if (p.address != printer.address) p.address,
      for (final e in extras.items)
        if (e.address != printer.address) e.address,
      if (_config().printer.trim() != printer.address) _config().printer.trim(),
    };
    final found = await UsbPrinters.relocate(printer.address, taken: taken);
    if (found == null || found == printer.address) return null;
    PrintAgentModule.host.log(
      '[AGENT] ${printer.refName}: đổi cổng USB → $found (theo VID/PID)',
    );
    if (printer.kind == AgentPrinterKind.builtIn) {
      await _onRelocated?.call(found);
      _setConnected(true);
    } else if (extras.moved(printer.address, found)) {
      _printers.add(null);
    }
    return printer.withAddress(found);
  }

  @override
  String? wifiSsidOf(DesktopPrinter printer) => null;

  /// Đổi mạng: IP máy tính đổi (kiểm tra mỗi 15s, chỉ đọc IP — nhẹ).
  @override
  Stream<void> get networkChanges async* {
    var last = (await PrintRelayLanServer.localIpv4s()).join(',');
    // Chỉ đọc danh sách IP (nhẹ) mỗi 2s: ngắt / bật lại Wi-Fi, cắm / rút dây mạng hiện trong vài giây.
    await for (final _ in Stream<void>.periodic(const Duration(seconds: 2))) {
      final now = (await PrintRelayLanServer.localIpv4s()).join(',');
      if (now == last) continue;
      last = now;
      yield null;
    }
  }
}
