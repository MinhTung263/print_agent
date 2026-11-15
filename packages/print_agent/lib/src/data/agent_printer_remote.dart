import '../print_agent_module.dart';
import 'dart:async';

import '../domain/entities/agent_printer_ref.dart';
import '../l10n/agent_locale_keys.dart';
import '../domain/ports/agent_host.dart';
import 'agent_printer_switches.dart';
import 'agent_printer_watchdog.dart';

/// Bật / tắt nhận lệnh một máy in của máy Agent KHÁC từ sơ đồ (máy bán hàng hoặc
/// Agent khác): gửi lệnh điều khiển `{cmd: 'printer', key, on, by, name}` qua
/// hàng đợi; máy Agent làm theo bằng [AgentPrinterSwitches] (như tự bấm trên máy
/// đó) rồi báo lại thông tin trạm — sơ đồ mọi máy cập nhật theo.
class AgentPrinterRemote<P extends AgentPrinterRef> {
  AgentPrinterRemote({
    required AgentPrinterWatchdog<P> watchdog,
    required Future<bool> Function(String stationId, Map<String, Object?> cmd)
    sendControl,
    required String Function() senderName,
  }) : _watchdog = watchdog,
       _sendControl = sendControl,
       _senderName = senderName;

  static const String command = 'printer';

  final AgentPrinterWatchdog<P> _watchdog;
  final Future<bool> Function(String stationId, Map<String, Object?> cmd)
  _sendControl;

  /// Tên máy này (hiện ở thông báo bên máy Agent: "Quầy 1 đã tắt...").
  final String Function() _senderName;

  /// Máy gửi: yêu cầu Agent [stationId] bật / tắt máy in có khoá [key]
  /// ([AgentPrinterSwitches.keyOf]). `false` khi không gửi được.
  Future<bool> send({
    required String stationId,
    required String key,
    required bool on,
    required String printerName,
  }) => _sendControl(stationId, {
    'cmd': command,
    'key': key,
    'on': on,
    'name': printerName,
    'by': _senderName(),
  });

  /// Máy Agent: làm theo lệnh. Bỏ qua khoá lạ (không phải máy in Agent này
  /// đang quản lý) để máy gửi dùng thông tin cũ không tắt nhầm.
  Future<void> apply(Map<Object?, Object?> cmd) async {
    final key = cmd['key'];
    final on = cmd['on'];
    if (key is! String || key.isEmpty || on is! bool) return;
    final known =
        key == 'builtin' ||
        _watchdog.statuses.any(
          (s) => AgentPrinterSwitches.keyOf(s.printer) == key,
        );
    if (!known) return;
    if (AgentPrinterSwitches.off.contains(key) == !on) return;
    await AgentPrinterSwitches.setKeyOn(key, on);
    final by = cmd['by']?.toString() ?? '';
    final printer = cmd['name']?.toString() ?? key;
    final host = PrintAgentModule.host;
    host.log('[AGENT] $by ${on ? 'bật' : 'tắt'} nhận lệnh cho $printer');
    host.notify(
      on
          ? LocaleKeys.printerSetting_agentPrinterTurnedOnByTr(
              by: by,
              printer: printer,
            )
          : LocaleKeys.printerSetting_agentPrinterTurnedOffByTr(
              by: by,
              printer: printer,
            ),
      level: on ? AgentNoticeLevel.success : AgentNoticeLevel.warning,
    );
  }
}
