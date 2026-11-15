import 'dart:async';
import 'dart:io';

import 'package:print_agent/print_agent.dart';
import 'package:printer_label/desktop.dart';

/// In ra máy in của Agent máy tính bằng ESC/POS — không qua driver: máy in LAN
/// (TCP 9100) hoặc máy cắm USB ([UsbPrinters]: Linux `/dev/usb/lp*`, Windows
/// hàng in RAW). Mọi lần gửi có giới hạn thời gian; mỗi máy in một hàng đợi
/// riêng (máy này tắt không làm kẹt máy khác).
abstract final class AgentPrinter {
  /// Giới hạn một lần in (kể cả chờ máy in nhận hết dữ liệu).
  static const Duration printTimeout = Duration(seconds: 60);

  static PrinterPort? portOf(String address) {
    if (UsbPrinters.isLocal(address)) return UsbPrinters.port(address);
    final parsed = parsePrinterAddress(address);
    return parsed == null ? null : TcpPrinterPort(parsed.$1, port: parsed.$2);
  }

  /// Máy in [address] có kết nối được từ máy này không.
  static Future<bool> reachable(String address) async {
    try {
      if (UsbPrinters.isLocal(address)) {
        return await UsbPrinters.present(
          address,
        ).timeout(const Duration(seconds: 5));
      }
      final parsed = parsePrinterAddress(address);
      if (parsed == null) return false;
      // Máy in đang phục vụ máy khác (từ chối kết nối) vẫn là đang bật.
      return await LanPrinterScanner.isAlive(parsed.$1, port: parsed.$2);
    } catch (_) {
      return false;
    }
  }

  /// In ảnh hoá đơn của [job] ra [address]; `null` = in được.
  static Future<AgentPrintFailure?> printJob(
    PrintRelayJob job,
    String address,
  ) async {
    if (job.images.isEmpty) {
      return const AgentPrintFailure(AgentJobError.noContent);
    }
    final port = portOf(address);
    if (port == null) {
      return const AgentPrintFailure(
        AgentJobError.unreachable,
        detail: 'Chưa chọn máy in',
      );
    }
    return _guard(
      address,
      () => EscPosPrinter.printImage(
        port,
        job.images.first,
        copies: job.copies,
        openDrawer: job.openDrawer,
        beep: job.beep,
      ),
    );
  }

  /// Phiếu in thử (chữ không dấu — in thô không cần phông tiếng Việt).
  static Future<AgentPrintFailure?> printTest({
    required String address,
    required String label,
    required int paperMm,
  }) {
    final port = portOf(address);
    if (port == null) {
      return Future.value(
        const AgentPrintFailure(
          AgentJobError.unreachable,
          detail: 'Chưa chọn máy in',
        ),
      );
    }
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return _guard(
      address,
      () => port.send(
        EscPosCommands.textTicket([
          'EasyPOS - IN THU',
          label,
          '${two(now.day)}/${two(now.month)}/${now.year} '
              '${two(now.hour)}:${two(now.minute)}',
          'Kho ${paperMm}mm - $address',
        ]),
      ),
    );
  }

  static Future<AgentPrintFailure?> _guard(
    String address,
    Future<void> Function() run,
  ) async {
    final label = UsbPrinters.label(address);
    try {
      await run().timeout(printTimeout);
      return null;
    } on PrinterStatusException catch (e) {
      return switch (e.status) {
        PaperStatus.coverOpen => const AgentPrintFailure(
          AgentJobError.coverOpen,
          detail: 'Máy in đang mở nắp',
        ),
        _ => const AgentPrintFailure(
          AgentJobError.outOfPaper,
          detail: 'Máy in hết giấy',
        ),
      };
    } on FormatException {
      return const AgentPrintFailure(
        AgentJobError.sendFailed,
        detail: 'Ảnh hoá đơn không hợp lệ',
      );
    } on UsbPrinterNotFound {
      return AgentPrintFailure(
        AgentJobError.unreachable,
        detail: 'Không thấy máy in $label — kiểm tra cáp USB',
      );
    } on FileSystemException catch (e) {
      return AgentPrintFailure(
        AgentJobError.sendFailed,
        detail: Platform.isLinux
            ? 'Không ghi được máy in USB (quyền /dev/usb/lp*): '
                  '${e.osError?.message ?? e.message}'
            : 'Không gửi được tới máy in $label: ${e.message}',
      );
    } on SocketException catch (e) {
      final refused = e.osError?.errorCode == 111 || e.osError?.errorCode == 61;
      return AgentPrintFailure(
        refused ? AgentJobError.busy : AgentJobError.unreachable,
        detail: 'Không kết nối được máy in $label',
      );
    } on TimeoutException {
      return AgentPrintFailure(
        AgentJobError.notReady,
        detail: 'Máy in $label không phản hồi',
      );
    } catch (e) {
      return AgentPrintFailure(AgentJobError.sendFailed, detail: '$e');
    }
  }
}
