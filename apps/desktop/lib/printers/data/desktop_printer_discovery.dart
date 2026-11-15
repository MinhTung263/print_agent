import 'dart:io';

import 'package:printer_label/desktop.dart';
import 'package:printer_label/printer_label.dart' show PrinterLabel;

import '../printer_discovery.dart';
import '../printer_option.dart';

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
      for (final p in lan) PrinterOption.lan(p.address),
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
  Future<String?> setupUsb(String setupPort) => UsbPrinters.setup(setupPort);

  @override
  Future<bool> reachable(String ip) =>
      LanPrinterScanner.probe(ip, timeout: const Duration(seconds: 2));

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
