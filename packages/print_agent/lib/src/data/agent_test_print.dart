import 'dart:async';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:print_agent_core/print_agent_core.dart';

import '../domain/entities/agent_printer_ref.dart';
import '../domain/entities/agent_test_print_result.dart';
import '../domain/ports/agent_job_printer.dart';
import '../l10n/agent_locale_keys.dart';
import 'agent_job_handler.dart';
import 'agent_test_slip.dart';

/// "In thử" một máy in: in một phiếu thử ghi tên máy in. Đi qua đúng đường in
/// của lệnh thật — máy in của máy này in qua [AgentJobHandler] (hàng đợi từng
/// máy, giữ phiếu khi hết giấy), máy in của Agent khác gửi qua kênh relay tới
/// Agent đó.
class AgentTestPrint<P extends AgentPrinterRef> {
  AgentTestPrint({
    required AgentJobHandler<P> jobs,
    required AgentJobPrinter<P> printer,
    required PrintRelay Function() relay,
    required String Function() stationId,
    required String Function() stationName,
  }) : _jobs = jobs,
       _printer = printer,
       _relay = relay,
       _stationId = stationId,
       _stationName = stationName;

  final AgentJobHandler<P> _jobs;
  final AgentJobPrinter<P> _printer;
  final PrintRelay Function() _relay;
  final String Function() _stationId;
  final String Function() _stationName;

  static const String _paper = 'size80';

  /// In thử máy in [printer] của máy này.
  Future<AgentTestPrintResult> local(P printer) async {
    final name = printer.nameOrNull ?? printer.refAddress ?? '';
    final target = printer.refKind == AgentPrinterKind.builtIn
        ? PrintRelayPrinter.stationBuiltIn(stationId: _stationId(), name: name)
        : _printer.targetOf(printer);
    if (target == null) return AgentTestPrintResult.failed;
    final Uint8List image;
    try {
      image = await _slip(
        name: name,
        kind: printer.refKind,
        address: printer.refAddress,
        station: _stationName(),
      );
    } catch (_) {
      return AgentTestPrintResult.failed;
    }
    final held = Completer<void>();
    final job = _job(target, image).withOnHeld(() {
      if (!held.isCompleted) held.complete();
    });
    return Future.any([
      _jobs
          .handle(job)
          .then(
            (ok) =>
                ok ? AgentTestPrintResult.done : AgentTestPrintResult.failed,
          ),
      held.future.then((_) => AgentTestPrintResult.held),
    ]);
  }

  /// In thử máy in [printer] (một mục `printers.names` Agent báo) của Agent
  /// [station] — gửi qua kênh relay, Agent đó in.
  Future<AgentTestPrintResult> peer(
    Map<Object?, Object?> station,
    Map<Object?, Object?> printer,
  ) async {
    final stationId = station['id']?.toString();
    if (stationId == null || stationId.isEmpty) {
      return AgentTestPrintResult.offline;
    }
    final kind = printer['kind']?.toString() ?? 'lan';
    final name = printer['name']?.toString() ?? '';
    final addr = printer['addr']?.toString() ?? '';
    final target = switch (kind) {
      'builtin' => PrintRelayPrinter.stationBuiltIn(
        stationId: stationId,
        name: name,
      ),
      'usb' => PrintRelayPrinter(
        address: addr,
        isUsb: true,
        usbDeviceId: addr,
        id: printer['id'],
        name: name,
      ).withStation(stationId),
      _ => PrintRelayPrinter(
        address: addr,
        id: printer['id'],
        name: name,
        mac: printer['mac']?.toString(),
      ).withStation(stationId),
    };
    final Uint8List image;
    try {
      image = await _slip(
        name: name,
        kind: switch (kind) {
          'builtin' => AgentPrinterKind.builtIn,
          'usb' => AgentPrinterKind.usb,
          _ => AgentPrinterKind.lan,
        },
        address: addr,
        station: station['name']?.toString() ?? '',
      );
    } catch (_) {
      return AgentTestPrintResult.failed;
    }
    final result = await _relay().relay(
      target,
      () => _job(target, image),
      force: true,
    );
    return switch (result) {
      PrintRelayResult.done => AgentTestPrintResult.done,
      PrintRelayResult.held => AgentTestPrintResult.held,
      PrintRelayResult.failed ||
      PrintRelayResult.timeout => AgentTestPrintResult.failed,
      _ => AgentTestPrintResult.offline,
    };
  }

  PrintRelayJob _job(PrintRelayPrinter target, Uint8List image) =>
      PrintRelayJob(
        kind: PrintRelayJobKind.receipt,
        printer: target,
        images: [image],
        paperSize: _paper,
        sender: LocaleKeys.printerSetting_agentTestPrint.tr,
        key: 'test:${PrintRelayJob.newKey()}',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

  Future<Uint8List> _slip({
    required String name,
    required AgentPrinterKind? kind,
    required String? address,
    required String station,
  }) async {
    final raw = await AgentTestSlip.render(
      title: LocaleKeys.printerSetting_agentTestSlipTitle.tr,
      printer: name,
      lines: [
        '${LocaleKeys.printerSetting_agentPrinterDetailConnection.tr}: '
            '${switch (kind) {
              AgentPrinterKind.usb => LocaleKeys.printerSetting_agentPrinterKindUsb.tr,
              AgentPrinterKind.builtIn => LocaleKeys.printerSetting_agentPrinterKindBuiltIn.tr,
              _ => LocaleKeys.printerSetting_agentPrinterKindLan.tr,
            }}',
        if (kind == AgentPrinterKind.lan && (address ?? '').isNotEmpty)
          '${LocaleKeys.printerSetting_agentPrinterDetailIp.tr}: $address',
        if (station.isNotEmpty)
          '${LocaleKeys.printerSetting_agentPrinterDetailStation.tr}: $station',
        DateFormat('HH:mm dd/MM/yyyy').format(DateTime.now()),
      ],
      footer: LocaleKeys.printerSetting_agentTestSlipOk.tr,
    );
    return _printer.fitReceipt(raw, _paper);
  }
}
