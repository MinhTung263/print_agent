import 'dart:convert';

import '../store/store_printer.dart';
import 'agent_store.dart';
import 'paper_size.dart';
import 'printer_type.dart';

/// Đồng bộ máy in của cửa hàng (máy chủ EasyPOS) vào sơ đồ Agent máy tính.
///
/// Máy in LAN của cửa hàng chưa có trên Agent thì được thêm làm "máy in thêm" (tên, loại
/// hoá đơn / tem, khổ giấy theo cửa hàng). Máy người dùng đã XOÁ khỏi Agent được nhớ lại
/// ([ignore]) để lần đồng bộ sau không tự thêm lại.
abstract final class StorePrinterSync {
  /// Mã `typeTemplates` của API cho "Tem nhãn" (QR thanh toán = 6).
  static const int labelCode = 5;

  static String _key(int? companyId) => 'storePrinterIgnored.${companyId ?? 0}';

  /// MAC chuẩn hoá (chữ hoa, dấu `:`) để so sánh; rỗng = không có.
  static String normMac(String? mac) =>
      (mac ?? '').trim().toUpperCase().replaceAll('-', ':');

  static String _addedKey(int? companyId) =>
      'storePrinterAdded.${companyId ?? 0}';

  /// Địa chỉ các máy do đồng bộ từ cửa hàng thêm vào (hiện nhãn "Từ EasyPOS" trên sơ đồ).
  static Set<String> added(int? companyId) {
    final raw = AgentStore.get(_addedKey(companyId));
    if (raw == null || raw.isEmpty) return {};
    try {
      return {for (final e in jsonDecode(raw) as List<dynamic>) '$e'};
    } catch (_) {
      return {};
    }
  }

  /// Đánh dấu máy [address] (và [mac] nếu biết) là máy đồng bộ từ cửa hàng. Nhớ cả MAC để vẫn
  /// nhận ra khi máy đổi IP (Agent tự tìm lại theo MAC).
  static void markAdded(int? companyId, String address, {String? mac}) {
    final all = added(companyId)..add(address.trim());
    final m = normMac(mac);
    if (m.isNotEmpty) all.add('mac:$m');
    AgentStore.set(_addedKey(companyId), jsonEncode(all.toList()));
  }

  static bool isFromStore(int? companyId, String address, {String? mac}) {
    final all = added(companyId);
    final m = normMac(mac);
    return all.contains(address.trim()) ||
        (m.isNotEmpty && all.contains('mac:$m'));
  }

  static void _forgetAdded(int? companyId, String address) {
    final all = added(companyId);
    if (all.remove(address.trim())) {
      AgentStore.set(_addedKey(companyId), jsonEncode(all.toList()));
    }
  }

  static Set<String> ignored(int? companyId) {
    final raw = AgentStore.get(_key(companyId));
    if (raw == null || raw.isEmpty) return {};
    try {
      return {for (final e in jsonDecode(raw) as List<dynamic>) '$e'};
    } catch (_) {
      return {};
    }
  }

  static void ignore(int? companyId, String address) {
    final a = address.trim();
    if (a.isEmpty) return;
    _forgetAdded(companyId, a); // đã xoá: không còn là máy "Từ EasyPOS"
    final all = ignored(companyId)..add(a);
    AgentStore.set(_key(companyId), jsonEncode(all.toList()));
  }

  /// Gỡ khỏi danh sách bỏ qua (người dùng chủ động thêm lại).
  static void unignore(int? companyId, String address) {
    final all = ignored(companyId);
    if (all.remove(address.trim())) {
      AgentStore.set(_key(companyId), jsonEncode(all.toList()));
    }
  }

  /// Máy in cửa hàng đáng thêm vào Agent: máy LAN có IP (bỏ máy Bluetooth, USB của thiết bị
  /// khác, máy in tích hợp).
  static bool isSyncable(StorePrinter p) =>
      p.type == StorePrinter.typeLan && p.ip.trim().isNotEmpty;

  static PrinterType typeOf(StorePrinter p) =>
      p.templates.contains(labelCode) ? PrinterType.label : PrinterType.receipt;

  static PaperSize paperOf(StorePrinter p) =>
      p.pageSize.contains('58') ? PaperSize.size58 : PaperSize.size80;
}
