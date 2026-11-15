import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:printer_label/desktop.dart';
import 'agent_config.dart';

/// Kết quả in một lệnh: `null` = in được, ngược lại là lý do lỗi (hiện nhật ký).
typedef PrintOutcome = String?;

/// In lệnh hoá đơn của hàng đợi ra máy in LAN bằng ESC/POS — không qua driver.
///
/// - `printerType: builtin` (máy gửi chọn "máy in tích hợp" của Agent này) → máy
///   in đã chọn trong cài đặt Agent ([AgentConfig.printer]).
/// - `printerType: lan` → in thẳng tới `printerIp` của lệnh (như Agent Android).
///
/// Máy in của Agent có thể là máy LAN, hoặc máy cắm USB vào máy tính
/// ([UsbPrinters]: Linux `/dev/usb/lp*`, Windows hàng in RAW).
abstract final class AgentPrinter {
  /// Địa chỉ máy in sẽ nhận lệnh [job]; `null` khi Agent này không in được.
  static String? targetOf(Map<String, Object?> job, AgentConfig config) {
    if (job['kind'] == 'label') return null;
    switch (job['printerType']) {
      case 'builtin':
        return config.hasPrinter ? config.printer.trim() : null;
      case 'lan':
        final ip = job['printerIp'];
        return ip is String && ip.trim().isNotEmpty ? ip.trim() : null;
    }
    return null;
  }

  static PrinterPort? portOf(String address) {
    if (UsbPrinters.isLocal(address)) return UsbPrinters.port(address);
    final parsed = parsePrinterAddress(address);
    return parsed == null ? null : TcpPrinterPort(parsed.$1, port: parsed.$2);
  }

  /// Máy in [address] có kết nối được từ máy này không (trước khi giành lệnh).
  static Future<bool> reachable(String address) async {
    if (UsbPrinters.isLocal(address)) return UsbPrinters.present(address);
    final parsed = parsePrinterAddress(address);
    if (parsed == null) return false;
    return LanPrinterScanner.probe(parsed.$1, port: parsed.$2);
  }

  static Future<PrintOutcome> printJob(
    Map<String, Object?> job,
    String address,
  ) async {
    final image = job['image'];
    if (image is! String || image.isEmpty) return 'Không có ảnh hoá đơn';
    final Uint8List png;
    try {
      png = base64Decode(image);
    } on FormatException {
      return 'Ảnh hoá đơn hỏng';
    }
    final port = portOf(address);
    if (port == null) return 'Chưa chọn máy in';
    final copies = job['quantity'] is int ? job['quantity']! as int : 1;
    return _guard(
      address,
      () => EscPosPrinter.printImage(
        port,
        png,
        copies: copies,
        openDrawer: job['openDrawer'] == true,
      ),
    );
  }

  /// Phiếu in thử (chữ không dấu — in thô không cần phông tiếng Việt).
  static Future<PrintOutcome> printTest(AgentConfig config, String label) {
    final port = portOf(config.printer);
    if (port == null) return Future.value('Chưa chọn máy in');
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return _guard(
      config.printer,
      () => port.send(
        EscPosCommands.textTicket([
          'EasyPOS - IN THU',
          label,
          '${two(now.day)}/${two(now.month)}/${now.year} '
              '${two(now.hour)}:${two(now.minute)}',
          'Kho ${config.paper.pageMm}mm - ${config.printer}',
        ]),
      ),
    );
  }

  static Future<PrintOutcome> _guard(
    String address,
    Future<void> Function() run,
  ) async {
    try {
      await run().timeout(const Duration(seconds: 60));
      return null;
    } on PrinterStatusException catch (e) {
      return switch (e.status) {
        PaperStatus.coverOpen => 'Máy in đang mở nắp',
        _ => 'Máy in hết giấy',
      };
    } on FormatException {
      return 'Ảnh hoá đơn không hợp lệ';
    } on UsbPrinterNotFound {
      return 'Không thấy máy in ${UsbPrinters.label(address)} — kiểm tra cáp USB';
    } on FileSystemException catch (e) {
      return Platform.isLinux
          ? 'Không ghi được máy in USB (quyền /dev/usb/lp*): ${e.osError?.message ?? e.message}'
          : 'Không gửi được tới máy in ${UsbPrinters.label(address)}: ${e.message}';
    } on SocketException {
      return 'Không kết nối được máy in $address';
    } on TimeoutException {
      return 'Máy in $address không phản hồi';
    } catch (e) {
      return 'In lỗi: $e';
    }
  }
}
