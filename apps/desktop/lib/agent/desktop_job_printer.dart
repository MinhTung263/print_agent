import 'dart:typed_data';

import 'package:print_agent/print_agent.dart';

import 'agent_config.dart';
import 'agent_printer.dart';
import 'desktop_printer.dart';
import 'desktop_printer_gateway.dart';

/// Cổng in của Agent máy tính: in hoá đơn ESC/POS ra máy in đã chọn (lệnh
/// tới "máy in tích hợp") hoặc máy in LAN của lệnh in hộ. Chưa in tem.
class DesktopJobPrinter implements AgentJobPrinter<DesktopPrinter> {
  DesktopJobPrinter(this._config, this._gateway);

  final AgentConfig Function() _config;
  final DesktopPrinterGateway _gateway;

  /// Mẫu in Agent máy tính in được (hoá đơn ảnh, không gồm tem).
  static const List<String> templates = [
    'temporaryPrintForm',
    'paymentPrintingForm',
    'processing',
    'cancel',
    'serve',
    'paymentQR',
    'prescription',
  ];

  @override
  DesktopPrinter resolve(PrintRelayJob job) {
    final t = job.printer;
    if (t.isBuiltIn) return _gateway.builtInPrinter();
    return DesktopPrinter(
      kind: t.isUsb ? AgentPrinterKind.usb : AgentPrinterKind.lan,
      address: t.address.trim(),
      name: t.name ?? '',
      id: t.id,
      mac: t.mac,
    );
  }

  @override
  Future<AgentPrintFailure?> printJob(
    DesktopPrinter printer,
    PrintRelayJob job,
  ) async {
    if (job.isLabel) {
      return const AgentPrintFailure(
        AgentJobError.sendFailed,
        detail: 'Agent máy tính chưa in được tem',
      );
    }
    return AgentPrinter.printJob(job, printer.address);
  }

  /// Agent máy tính không gửi lệnh đi (không có máy in đã lưu để gửi).
  @override
  PrintRelayPrinter? targetOf(DesktopPrinter printer) => null;

  @override
  Future<Uint8List> fitReceipt(Uint8List image, String paper) async => image;

  @override
  AgentBuiltInSpec? builtInSpec() =>
      AgentBuiltInSpec(paper: _config().paper.name, templates: templates);

  @override
  List<String> get defaultTemplates => templates;

  @override
  DesktopPrinter peerBuiltIn(PeerBuiltInPrinter printer) => DesktopPrinter(
    kind: AgentPrinterKind.builtIn,
    address: printer.address,
    name: PeerBuiltInPrinters.displayName(printer),
  );

  @override
  String messageName(DesktopPrinter printer) =>
      printer.name.isEmpty ? printer.address : printer.name;

  @override
  Future<T> withProgress<T>(
    DesktopPrinter printer,
    Future<T> Function() action,
  ) => action();
}
