import 'dart:io';

import 'package:print_agent/print_agent.dart' show AgentJobErrorText;
import 'package:printer_label/desktop.dart';
import 'package:printer_label/printer_label.dart' show PrinterLabel;

import '../../agent/agent_printer.dart';
import '../../agent/printer_type.dart';
import '../printer_discovery.dart';
import '../printer_option.dart';
import '../printer_type_detector.dart';

/// [PrinterDiscovery] bằng plugin printer_label: quét cổng 9100 trong các dải
/// mạng của máy, máy in USB theo hệ điều hành (Linux usblp, Windows hàng in
/// RAW, macOS CUPS), tên model qua SNMP / mDNS...
class DesktopPrinterDiscovery implements PrinterDiscovery {
  const DesktopPrinterDiscovery();

  @override
  Future<List<PrinterOption>> find() async {
    final results = await Future.wait([
      LanPrinterScanner.scan(),
      if (UsbPrinters.supported) UsbPrinters.list(),
    ]);
    final lan = results[0] as List<LanPrinterFound>;
    final usb = results.length > 1
        ? results[1] as List<UsbPrinterInfo>
        : const <UsbPrinterInfo>[];
    return [
      for (final p in usb)
        PrinterOption.usb(
          address: p.address,
          name: p.name,
          setupPort: p.setupPort,
        ),
      for (final p in lan)
        PrinterOption.lan(
          p.address,
          hardBlock: p.issue == LanPrinterIssue.ipConflict,
          warning: switch (p.issue) {
            LanPrinterIssue.none => null,
            LanPrinterIssue.ipConflict =>
              'IP đang bị thiết bị khác dùng — cần đổi IP máy in',
            LanPrinterIssue.unreachable =>
              'Chưa kết nối được (khác dải mạng hoặc bị chặn) — bấm loa để thử bíp, vẫn thêm được',
          },
        ),
    ];
  }

  @override
  PrinterOption missing(String address) => UsbPrinters.isLocal(address)
      ? PrinterOption.usb(
          address: address,
          name: UsbPrinters.label(address),
          missing: true,
        )
      : PrinterOption.lan(address);

  @override
  Future<String?> modelOf(String address) async {
    try {
      final host = parsePrinterAddress(address)?.$1 ?? address;
      final name = await PrinterLabel.getLanPrinterName(host);
      return (name ?? '').trim().isEmpty ? null : name!.trim();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PrinterType?> typeOf(String address, {String? model}) async {
    // Máy USB: loại máy tự báo trong chuỗi định danh IEEE 1284 (`CMD:TSPL2` / `CMD:ESC/POS`).
    if (UsbPrinters.isLocal(address)) {
      final id = await UsbPrinters.deviceId(address);
      final language = id == null
          ? null
          : PrinterLanguageProbe.fromIeee1284(id);
      return PrinterTypeDetector.decide(
        language: language,
        model: model ?? (id == null ? null : Ieee1284.name(id)),
      ).type;
    }
    final parsed = parsePrinterAddress(address);
    if (parsed == null) return null;
    PrinterLanguage? language;
    try {
      language = await PrinterLanguageProbe.probeLan(
        parsed.$1,
        port: parsed.$2,
      );
    } catch (_) {}
    return PrinterTypeDetector.decide(language: language, model: model).type;
  }

  @override
  Future<String?> beep(String address, {PrinterType? type}) async {
    final failure = await AgentPrinter.beep(
      address,
      label: type == PrinterType.label,
    );
    return failure == null
        ? null
        : AgentJobErrorText.message(failure.error, detail: failure.detail);
  }

  @override
  Future<String?> setupUsb(String setupPort) => UsbPrinters.setup(setupPort);

  @override
  String? get setupError => UsbPrinters.lastSetupError;

  /// [address] là `ip` hoặc `ip:cổng` (máy in tem hay dùng cổng khác 9100).
  @override
  Future<bool> reachable(String address) {
    final parsed = parsePrinterAddress(address);
    if (parsed == null) return Future.value(false);
    return LanPrinterScanner.probe(
      parsed.$1,
      port: parsed.$2,
      timeout: const Duration(seconds: 2),
    );
  }

  @override
  Future<List<String>> scannedNetworks() async {
    final out = <String>{};
    try {
      for (final nic in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      )) {
        for (final a in nic.addresses) {
          if (a.isLoopback || a.isLinkLocal) continue;
          final p = a.address.split('.');
          if (p.length == 4) out.add('${p.take(3).join('.')}.x');
        }
      }
    } catch (_) {}
    return out.toList()..sort();
  }

  @override
  Future<String?> localIp() async {
    try {
      for (final nic in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      )) {
        for (final a in nic.addresses) {
          final p = a.address.split('.');
          if (p.length != 4) continue;
          final second = int.tryParse(p[1]) ?? 0;
          if (p[0] == '10' ||
              (p[0] == '192' && p[1] == '168') ||
              (p[0] == '172' && second >= 16 && second <= 31)) {
            return a.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
