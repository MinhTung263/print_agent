import 'dart:async';
import 'dart:typed_data';

import 'package:print_agent_core/print_agent_core.dart';
import 'package:printer_label/printer_label.dart';

import '../domain/entities/agent_printer_ref.dart';
import '../domain/entities/peer_built_in_printer.dart';
import '../domain/ports/agent_host.dart';
import '../domain/ports/agent_job_printer.dart';
import '../l10n/agent_locale_keys.dart';
import '../print_agent_module.dart';
import 'agent_device_name.dart';
import 'peer_built_in_printers.dart';

/// Máy gửi: in qua máy Agent khi máy này không in thẳng được (khác mạng, 4G,
/// máy in USB cắm ở máy khác) hoặc in thẳng đã lỗi; lỗi thì báo kèm "In lại".
class AgentSender<P extends AgentPrinterRef> {
  AgentSender({
    required PrintRelay Function() relay,
    required AgentJobPrinter<P> printer,
  }) : _relay = relay,
       _printer = printer;

  final PrintRelay Function() _relay;
  final AgentJobPrinter<P> _printer;

  PrintRelayPrinter? _target(P printer) {
    final stationId = printer.refKind == AgentPrinterKind.builtIn
        ? PeerBuiltInPrinter.stationIdOf(printer.refAddress)
        : null;
    if (stationId != null) {
      return PrintRelayPrinter.stationBuiltIn(
        stationId: stationId,
        name: printer.nameOrNull,
      );
    }
    return _printer.targetOf(printer);
  }

  /// Lệnh tới [printer] sẽ đi qua Agent (nơi gọi bỏ bước kiểm tra kết nối thẳng).
  Future<bool> willRelay(P printer) async {
    final target = _target(printer);
    return target != null && await _relay().willRelay(target);
  }

  Future<bool?> tryReceipt({
    required Uint8List image,
    required String paper,
    required P printer,
    int quantity = 1,
    bool openDrawer = false,
    bool force = false,
    bool beep = false,
  }) => _send(
    printer,
    force: force,
    (target) async => PrintRelayJob.receipt(
      printer: target,
      // Thu về khổ giấy rồi đổi sang đen / trắng — ảnh nhỏ đi nhiều lần.
      image: await PrintRelayImage.compact(
        await _printer.fitReceipt(image, paper),
      ),
      paperSize: paper,
      quantity: quantity,
      openDrawer: openDrawer,
      sender: AgentDeviceName.label,
      beep: beep,
    ),
  );

  Future<bool?> tryLabel({
    required List<Uint8List> images,
    required P printer,
    required LabelPerRow size,
    int copies = 1,
    bool force = false,
  }) => _send(
    printer,
    force: force,
    (target) async => PrintRelayJob.label(
      printer: target,
      images: images,
      size: size,
      copies: copies,
      sender: AgentDeviceName.label,
      // Máy tem vàng bạc 300dpi: dựng ảnh mịn hơn 203dpi (Agent báo độ phân giải đầu in).
      dotsPerMm: await _labelDotsPerMm(target),
    ),
  );

  /// Số chấm/mm để dựng ảnh tem cho máy in [target]: theo độ phân giải Agent báo
  /// ([dotsPerMmOf]); không biết / lỗi thì 8 (203dpi, như cũ).
  Future<double> _labelDotsPerMm(PrintRelayPrinter target) async {
    try {
      final stations = await _relay().onlineStations().timeout(
        const Duration(seconds: 2),
      );
      return dotsPerMmOf(stations, target);
    } catch (_) {
      return 8;
    }
  }

  /// Máy tem [target] trên các trạm [stations] in ở bao nhiêu dpi (theo `builtIn.dpi` mỗi trạm
  /// báo): 300dpi → ~11,81 chấm/mm, còn lại 8. Máy in tích hợp của trạm tra theo mã trạm, máy
  /// khác theo địa chỉ.
  static double dotsPerMmOf(
    List<Map<Object?, Object?>> stations,
    PrintRelayPrinter target,
  ) {
    int? dpi;
    for (final station in stations) {
      final builtIn = station['builtIn'];
      final map = builtIn is Map ? builtIn['dpi'] : null;
      if (map is! Map) continue;
      final byStation = target.isBuiltIn && target.stationId != null;
      if (byStation) {
        if (station['id'] == target.stationId) dpi = _dpiOf(map['builtin']);
      } else {
        dpi ??= _dpiOf(map[target.address.trim()]);
      }
      if (dpi != null) break;
    }
    return dpi != null && dpi >= 300 ? 300 / 25.4 : 8;
  }

  static int? _dpiOf(Object? v) => v is num ? v.toInt() : null;

  /// [force]: gửi qua Agent kể cả khi tưởng in thẳng được (in thẳng đã lỗi).
  Future<bool?> _send(
    P printer,
    FutureOr<PrintRelayJob> Function(PrintRelayPrinter target) build, {
    bool force = false,
  }) async {
    final target = _target(printer);
    if (target == null) return null;
    final result = await _relay().relay(
      target,
      () => build(target),
      force: force,
    );
    final error = switch (result) {
      PrintRelayResult.failed => LocaleKeys.printerSetting_remotePrintFailedTr(
        printerName: _printer.messageName(printer),
      ),
      PrintRelayResult.timeout || PrintRelayResult.noResponse =>
        LocaleKeys.printerSetting_remotePrintTimeout,
      _ => null,
    };
    if (result == PrintRelayResult.held) {
      // Agent giữ phiếu chờ thay giấy / đóng nắp rồi tự in — KHÔNG in lại.
      PrintAgentModule.host.notify(
        LocaleKeys.printerSetting_relayHeldTr(
          printerName: _printer.messageName(printer),
        ),
        level: AgentNoticeLevel.warning,
        duration: const Duration(seconds: 8),
      );
      return true;
    }
    if (error != null) {
      // Kèm nút "In lại" (hiện lâu hơn để kịp bấm) — không mất hoá đơn / tem.
      PrintAgentModule.host.notify(
        error,
        level: AgentNoticeLevel.error,
        duration: const Duration(seconds: 8),
        actionLabel: LocaleKeys.bills_rePrint,
        onAction: () => unawaited(_retry(printer, build)),
      );
    }
    return result == null ? null : result == PrintRelayResult.done;
  }

  /// "In lại": gửi lại qua Agent (kèm tiến trình in). Không còn Agent nào trực
  /// tuyến thì báo rõ.
  Future<void> _retry(
    P printer,
    FutureOr<PrintRelayJob> Function(PrintRelayPrinter target) build,
  ) async {
    final ok = await _printer.withProgress(
      printer,
      () => _send(printer, build, force: true),
    );
    if (ok == null) {
      PrintAgentModule.host.notify(
        LocaleKeys.printerSetting_relayNoStation,
        level: AgentNoticeLevel.warning,
      );
    }
  }

  // --- Máy in tích hợp của Agent khác ---------------------------------------

  /// Máy in tích hợp của các Agent đã BẬT, chỉ Agent ĐANG trực tuyến (Agent tắt
  /// thì tạm bỏ qua — máy in khác vẫn in bình thường; báo nhẹ một lần).
  Future<List<P>> peerBuiltIns() async {
    PeerBuiltInPrinters.ensureLoaded();
    final enabled = [
      for (final p in PeerBuiltInPrinters.all)
        if (p.enabled) p,
    ];
    if (enabled.isEmpty) return const [];
    // Lần đầu sau khi mở app chờ chút cho danh sách Agent về.
    final online = await _relay().currentStations();
    PeerBuiltInPrinters.sync(online);
    final onlineIds = {for (final s in online) s['id']};
    return [
      for (final p in enabled)
        if (onlineIds.contains(p.stationId))
          _printer.peerBuiltIn(p)
        else
          ?_skipped(p),
    ];
  }

  final Map<String, DateTime> _skippedAt = {};

  /// Báo "Agent đang ngoại tuyến" tối đa 10 phút một lần mỗi Agent.
  P? _skipped(PeerBuiltInPrinter printer) {
    final last = _skippedAt[printer.stationId];
    if (last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 10)) {
      return null;
    }
    _skippedAt[printer.stationId] = DateTime.now();
    final name = PeerBuiltInPrinters.displayName(printer);
    PrintAgentModule.host
      ..log('[PRINT-RELAY] $name: Agent ngoại tuyến — bỏ qua')
      ..notify(
        LocaleKeys.printerSetting_stationBuiltInSkippedTr(printer: name),
        level: AgentNoticeLevel.warning,
      );
    return null;
  }
}
