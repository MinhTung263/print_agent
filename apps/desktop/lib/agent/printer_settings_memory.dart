import 'dart:convert';

import 'agent_store.dart';
import 'paper_size.dart';
import 'printer_settings.dart';

/// Nhớ cài đặt riêng của máy in (tắt cắt giấy, tắt còi, khổ giấy, căn chỉnh tem) theo
/// DANH TÍNH máy — để xoá máy in khỏi trạm rồi thêm lại (hoặc cài lại Agent trên cùng máy
/// tính) cài đặt vẫn quay về, không phải chỉnh lại từ đầu:
/// - máy LAN: MAC (nếu biết) và địa chỉ IP;
/// - máy USB: địa chỉ thiết bị (`usb:` / `usbp:` / `queue:` / `lpq:` / `cups:`).
///
/// Loại máy (hoá đơn / tem) không nhớ ở đây — Agent tự nhận lại mỗi lần thêm.
abstract final class PrinterSettingsMemory {
  static String _byAddress(String address) =>
      'printerSettings.addr:${address.trim()}';

  static String _byMac(String mac) =>
      'printerSettings.mac:${mac.trim().toUpperCase().replaceAll('-', ':')}';

  /// Ghi nhớ [settings] của máy in ở [address] ([mac] nếu biết).
  static void remember(
    String address,
    PrinterSettings settings, {
    String mac = '',
  }) {
    if (address.trim().isEmpty) return;
    final json = jsonEncode({
      'paper': settings.paper.name,
      'offsetXMm': settings.offsetXMm,
      'offsetYMm': settings.offsetYMm,
      'gapMm': settings.gapMm,
      'beep': settings.beep,
      'autoCut': settings.autoCut,
      'dpi': settings.dpi,
      'ribbon': settings.ribbon.name,
    });
    AgentStore.set(_byAddress(address), json);
    if (mac.trim().isNotEmpty) AgentStore.set(_byMac(mac), json);
  }

  /// Cài đặt đã nhớ của máy in ở [address] ([mac] nếu biết; MAC ưu tiên vì IP có thể đổi);
  /// đặt lên [base] (giữ loại máy của [base]). `null` khi chưa nhớ gì.
  static PrinterSettings? recall(
    String address,
    PrinterSettings base, {
    String mac = '',
  }) {
    final raw =
        (mac.trim().isEmpty ? null : AgentStore.get(_byMac(mac))) ??
        AgentStore.get(_byAddress(address));
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      double num0(Object? v) => v is num ? v.toDouble() : 0;
      return base.copyWith(
        paper: PaperSize.values.firstWhere(
          (p) => p.name == m['paper'],
          orElse: () => base.paper,
        ),
        offsetXMm: num0(m['offsetXMm']),
        offsetYMm: num0(m['offsetYMm']),
        gapMm: num0(m['gapMm']),
        beep: m['beep'] != false,
        autoCut: m['autoCut'] != false,
        dpi: m['dpi'] == 300 ? 300 : 203,
        ribbon: RibbonMode.fromName(m['ribbon']?.toString()),
      );
    } catch (_) {
      return null;
    }
  }
}
