import 'dart:async';
import 'dart:typed_data';

import 'package:print_agent/print_agent.dart';

import 'agent_config.dart';
import 'agent_printer.dart';
import 'desktop_printer.dart';
import 'desktop_printer_gateway.dart';
import 'last_label.dart';
import 'printer_settings.dart';

/// Cổng in của Agent máy tính: in hoá đơn ESC/POS ra máy in đã chọn (lệnh
/// tới "máy in tích hợp") hoặc máy in LAN của lệnh in hộ; tem (TSPL) in ra máy
/// in tem LAN / USB mà lệnh chỉ định.
class DesktopJobPrinter implements AgentJobPrinter<DesktopPrinter> {
  DesktopJobPrinter(
    this._config,
    this._gateway, {
    PrinterSettings Function(String address)? settingsOf,
  }) : _settingsOf = settingsOf;

  /// Cài đặt riêng của máy in ở một địa chỉ; không có thì dùng cài đặt máy in chính.
  final PrinterSettings Function(String address)? _settingsOf;

  PrinterSettings _settings(String address) =>
      _settingsOf?.call(address) ??
      PrinterSettings(
        type: _config().printerType,
        paper: _config().paper,
        offsetXMm: _config().labelOffsetXMm,
        offsetYMm: _config().labelOffsetYMm,
        gapMm: _config().labelGapMm,
        beep: _config().beep,
      );

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
    final settings = _settings(printer.address);
    final failure = job.isLabel
        ? await AgentPrinter.printLabelJob(
            job,
            printer.address,
            gapOverrideMm: settings.gapMm,
            calibration: settings.calibration,
          )
        : await AgentPrinter.printJob(
            job,
            printer.address,
            allowBeep: settings.beep,
          );
    // Nhớ máy in cho sơ đồ — không bắt lệnh chờ (đọc bảng ARP).
    if (failure == null) unawaited(_gateway.printedFor(printer));
    // Nhớ khổ tem vừa in: màn căn chỉnh dùng luôn khổ này, khách không phải chọn.
    if (failure == null && job.isLabel) {
      LastLabel.remember(
        printer.address,
        AgentPrinter.labelSpecOf(job),
        job.labelSpec?.count ?? job.labelSize?.count ?? 1,
      );
    }
    return failure;
  }

  /// Agent máy tính không gửi lệnh đi (không có máy in đã lưu để gửi).
  @override
  PrintRelayPrinter? targetOf(DesktopPrinter printer) => null;

  @override
  Future<Uint8List> fitReceipt(Uint8List image, String paper) async => image;

  @override
  AgentBuiltInSpec? builtInSpec() => AgentBuiltInSpec(
    paper: _config().paper.name,
    // Máy in tem chỉ nhận tem; máy in hoá đơn nhận các phiếu hoá đơn.
    templates: _config().printerType == PrinterType.label
        ? labelTemplates
        : templates,
  );

  /// Mẫu in của máy in tem (tên khớp `TypeTemplateEnum.label` của app).
  static const List<String> labelTemplates = ['label'];

  @override
  List<String> get defaultTemplates =>
      _config().printerType == PrinterType.label ? labelTemplates : templates;

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
