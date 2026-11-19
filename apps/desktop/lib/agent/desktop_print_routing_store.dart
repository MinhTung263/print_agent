import 'package:print_agent/print_agent.dart';

import '../store/print_function_codes.dart';
import '../store/store_printer.dart';
import '../store/store_printer_api.dart';
import '../store/usb_identity.dart';
import 'agent_store.dart';
import 'store_printer_sync.dart';
import 'desktop_agent.dart';

/// Kho "In theo chức năng" của Agent máy tính: dùng ĐÚNG danh sách máy in của cửa hàng trên
/// máy chủ EasyPOS (cùng API `print-setting` với app bán hàng) — chức năng của từng máy in
/// là `typeTemplates` của máy đó, nên app bán hàng cùng công ty thấy ngay.
///
/// - Máy in của máy này khớp với máy in cửa hàng theo địa chỉ IP ([nameOfAddress]).
/// - Sửa chức năng chỉ đổi `typeTemplates`, giữ nguyên khổ giấy, khu vực chế biến... của máy.
/// - Xem trước hoá đơn / hỏi số bản in: tạm lưu trên máy này (chưa có API cho Agent máy tính).
class DesktopPrintRoutingStore implements AgentPrintRoutingStore {
  DesktopPrintRoutingStore(this._agent, {StorePrinterEditor? api})
    : _api =
          api ??
          StorePrinterApi(
            _agent.auth,
            companyId: () => _agent.config.companyId,
          );

  final DesktopAgent _agent;
  final StorePrinterEditor _api;

  /// Máy in cửa hàng đọc lần gần nhất (để khớp theo IP ngay, không chờ mạng).
  List<StorePrinter> _printers = const [];

  /// Máy in tích hợp của thiết bị bán hàng (type 3) không dùng được ở Agent máy tính.
  static const int _builtInType = 3;

  Future<List<StorePrinter>> refresh() async {
    final all = await _api.list();
    _printers = [
      for (final p in all)
        if (p.id != null && p.name.trim().isNotEmpty && p.type != _builtInType)
          p,
    ];
    // Máy in LAN của cửa hàng hiện luôn trên sơ đồ Agent (chưa có thì thêm).
    try {
      await _agent.syncStorePrinters(_printers);
    } catch (_) {}
    return _printers;
  }

  /// Tên máy in cửa hàng có địa chỉ [address] (`ip` hoặc `ip:cổng`); `null` = chưa có trong cửa
  /// hàng (hoặc chưa tải xong danh sách).
  String? nameOfAddress(String address, {String? mac}) {
    final a = address.trim();
    if (a.isEmpty) return null;
    final usb = _usbMatch(a);
    if (usb != null) return usb;
    final host = a.split(':').first;
    // Khớp theo MAC trước: máy đổi IP (Agent tự tìm lại) vẫn nhận ra đúng máy của cửa hàng.
    final m = StorePrinterSync.normMac(mac);
    if (m.isNotEmpty) {
      for (final p in _printers) {
        if (StorePrinterSync.normMac(p.mac) == m) return p.name.trim();
      }
    }
    for (final p in _printers) {
      final ip = p.ip.trim();
      if (ip.isNotEmpty && (ip == a || ip.split(':').first == host)) {
        return p.name.trim();
      }
    }
    return null;
  }

  /// Máy USB của máy này khớp máy USB trong cửa hàng: cùng serial thì chắc chắn; không có serial
  /// thì chỉ nhận khi cửa hàng có đúng MỘT máy cùng hãng + dòng máy (tránh nhầm hai máy giống nhau).
  String? _usbMatch(String address) {
    final local = UsbIdentity.fromLocal(address);
    if (local == null) return null;
    final stores = <(StorePrinter, UsbIdentity)>[
      for (final p in _printers)
        if (p.type == StorePrinter.typeUsb)
          if (UsbIdentity.fromStore(p.ip) case final id?) (p, id),
    ];
    for (final (p, id) in stores) {
      if (local.sameDevice(id)) return p.name.trim();
    }
    final sameModel = [
      for (final (p, id) in stores)
        if (local.sameModel(id) && !(local.hasSerial && id.hasSerial)) p,
    ];
    return sameModel.length == 1 ? sameModel.first.name.trim() : null;
  }

  @override
  Future<List<AgentPrintRoute>> load() async {
    await refresh();
    return [
      for (final p in _printers)
        for (final code in p.templates)
          if (PrintFunctionCodes.fromApiCode(code) case final f?)
            AgentPrintRoute(
              function: f,
              printerName: p.name.trim(),
              templateId: f.value,
            ),
    ];
  }

  /// Máy nào đổi chức năng thì cập nhật lên máy chủ; lỗi thì ném ra (không im lặng).
  @override
  Future<void> save(List<AgentPrintRoute> routes) async {
    for (final p in _printers) {
      final name = p.name.trim();
      final wanted = {
        for (final r in routes)
          if ((r.printerName ?? '').trim() == name)
            PrintFunctionCodes.apiCode(r.function),
      };
      final next = [...wanted]..sort();
      final current = [...p.templates]..sort();
      if (next.length == current.length && wanted.containsAll(current)) {
        continue;
      }
      await _api.updateTemplates(p, next);
    }
    await refresh();
  }

  @override
  Future<List<AgentPrintTemplate>> templates() async => [
    for (final f in AgentPrintFunction.values)
      AgentPrintTemplate(id: f.value, name: 'Mẫu mặc định', function: f),
  ];

  @override
  Future<List<String>> printers() async => [
    for (final p in _printers) p.name.trim(),
  ];

  @override
  Future<String?> defaultPrinter() async {
    final all = await printers();
    return all.isEmpty ? null : all.first;
  }

  String _key(String name) => '$name.${_agent.config.companyId ?? 0}';

  @override
  Future<bool> previewBeforePayment() async =>
      AgentStore.get(_key('previewBeforePayment')) != '0';

  @override
  Future<void> setPreviewBeforePayment(bool value) async =>
      AgentStore.set(_key('previewBeforePayment'), value ? '1' : '0');

  @override
  Future<bool> askCopiesEachPrint() async =>
      AgentStore.get(_key('askCopies')) == '1';

  @override
  Future<void> setAskCopiesEachPrint(bool value) async =>
      AgentStore.set(_key('askCopies'), value ? '1' : '0');
}
