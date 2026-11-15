import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/agent_domain.dart';

/// Máy in của một Agent khác: Agent nào, khoá máy in, tên hiển thị.
typedef _PeerPrinter = ({
  String stationId,
  String agent,
  String key,
  String name,
});

/// Agent bản cũ: chưa báo khoá máy in (chưa biết lệnh bật / tắt từ xa).
bool agentPeerIsOldVersion(Map<Object?, Object?> printer) {
  final key = printer['key'];
  return key is! String || key.isEmpty;
}

/// Bấm máy in của một Agent KHÁC trên sơ đồ: bật / tắt nhận lệnh cho máy in đó
/// từ xa ([AgentPrinterRemote]) + thông báo kèm Hoàn tác. Agent bản cũ (chưa
/// báo khoá máy in): báo cần cập nhật app trên máy Agent đó.
VoidCallback? agentPeerPrinterToggle(
  Map<Object?, Object?> station,
  Map<Object?, Object?> printer,
) {
  final stationId = station['id']?.toString() ?? '';
  if (stationId.isEmpty) return null;
  final key = printer['key'];
  if (agentPeerIsOldVersion(printer) || key is! String) {
    return () => unawaited(
      AppNotification.show(
        message: LocaleKeys.printerSetting_agentPeerOldVersionTr(
          agent: AgentIdentity.ofStation(station),
        ),
        type: AppNotificationType.warning,
        duration: const Duration(seconds: 6),
      ),
    );
  }
  final target = (
    stationId: stationId,
    agent: AgentIdentity.ofStation(station),
    key: key,
    name: printer['name']?.toString() ?? '',
  );
  // Đang tắt → bấm để bật lại, và ngược lại.
  final on = printer['on'] == false;
  return () => unawaited(_toggle(target, on));
}

Future<bool> _send(_PeerPrinter p, bool on) => PrintAgentUi.station.remote.send(
  stationId: p.stationId,
  key: p.key,
  on: on,
  printerName: p.name,
);

Future<void> _toggle(_PeerPrinter p, bool on) async {
  if (!await _send(p, on)) {
    unawaited(
      AppNotification.show(
        message: LocaleKeys.printerSetting_agentRemoveFailed,
        type: AppNotificationType.error,
      ),
    );
    return;
  }
  unawaited(
    AppNotification.show(
      message: on
          ? LocaleKeys.printerSetting_agentPrinterRemoteOnTr(
              printer: p.name,
              agent: p.agent,
            )
          : LocaleKeys.printerSetting_agentPrinterRemoteOffTr(
              printer: p.name,
              agent: p.agent,
            ),
      type: on ? AppNotificationType.success : AppNotificationType.warning,
      trailing: _UndoButton(p, on: on),
    ),
  );
}

/// Nút "Hoàn tác" trên thông báo: gửi lệnh ngược lại.
class _UndoButton extends StatelessWidget {
  const _UndoButton(this.printer, {required this.on});

  final _PeerPrinter printer;
  final bool on;

  @override
  Widget build(BuildContext context) => BaseTap(
    onTap: () {
      AppNotification.dismiss();
      unawaited(_send(printer, !on));
    },
    child: const AppPadding.symmetric(
      horizontal: AppSpace.md,
      vertical: AppSpace.sm,
      child: AppText(LocaleKeys.printerSetting_agentUndo, variant: .title),
    ),
  );
}
