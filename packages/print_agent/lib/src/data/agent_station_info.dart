import '../domain/entities/agent_printer_ref.dart';
import '../domain/entities/agent_printer_status.dart';
import '../domain/ports/agent_job_printer.dart';
import '../print_agent_module.dart';
import 'agent_device_identity.dart';
import 'agent_printer_switches.dart';

/// Thông tin trạm máy Agent báo lên hàng đợi (máy khác đọc để hiện sơ đồ, in
/// qua máy in tích hợp, bật / tắt máy in từ xa).
abstract final class AgentStationInfo {
  /// Tối đa số máy in báo kèm (thông tin trực tuyến không quá nặng).
  static const int maxPrinters = 30;

  static Map<String, Object?> build({
    required String name,
    required String? model,
    required AgentBuiltInSpec? builtIn,
    required bool builtInConnected,
    required List<AgentPrinterStatus<AgentPrinterRef>> statuses,
  }) {
    final builtInOff = AgentPrinterSwitches.off.contains('builtin');
    final info = <String, Object?>{
      // Máy gửi thấy tên này trên sơ đồ ("Máy Agent" khi trống) + mã ngắn.
      'name': name,
      // Nhận ra máy: model + bản app (Dev / prod...).
      'model': ?model,
      'app': PrintAgentModule.host.appPackage,
      // Biết lệnh ngắt kết nối từ xa cả khi còn máy in (bản cũ chỉ nhận khi
      // không có máy in).
      'stop': true,
    };
    // Mã cũ (ngẫu nhiên) của máy này: máy khác gộp Agent cũ vào mã mới.
    final prev = AgentDeviceIdentity.previousIds;
    if (prev.isNotEmpty) info['prev'] = prev;
    if (builtIn != null) {
      info['builtIn'] = {
        'paper': builtIn.paper,
        'templates': builtIn.templates,
        // Đã tắt nhận lệnh trên Agent → coi như chưa sẵn sàng.
        'ready': builtInConnected && !builtInOff,
        if (builtInOff) 'off': true,
      };
    }
    final printers = _printers(statuses);
    if (printers != null) info['printers'] = printers;
    return info;
  }

  /// `{ok, total, names}` — máy khác bấm vào Agent này xem được từng máy in.
  /// `null` khi chưa kiểm tra.
  static Map<String, Object?>? _printers(
    List<AgentPrinterStatus<AgentPrinterRef>> statuses,
  ) {
    if (statuses.isEmpty) return null;
    // Máy in đã tắt nhận lệnh không tính vào "x/y máy in".
    final active = statuses.where((s) => AgentPrinterSwitches.isOn(s.printer));
    return {
      'ok': active.where((s) => s.state == AgentPrinterState.connected).length,
      'total': active.length,
      'names': [
        for (final s in statuses.take(maxPrinters))
          {
            'name': s.printer.refName,
            'ok': s.state == AgentPrinterState.connected,
            if (!AgentPrinterSwitches.isOn(s.printer)) 'on': false,
            // Máy khác bấm máy in này trên sơ đồ để bật / tắt từ xa.
            'key': AgentPrinterSwitches.keyOf(s.printer),
            'kind': switch (s.printer.refKind) {
              AgentPrinterKind.builtIn => 'builtin',
              AgentPrinterKind.usb => 'usb',
              _ => 'lan',
            },
            if (s.printer.refKind == AgentPrinterKind.lan)
              'addr': s.printer.refAddress ?? '',
          },
      ],
    };
  }
}
