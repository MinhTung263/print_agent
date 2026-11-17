import 'dart:async';
import 'dart:io';

import 'package:print_agent/print_agent.dart';
import 'package:printer_label/desktop.dart';
import 'package:printer_label/printer_label.dart'
    show LabelCalibration, LabelPerRow;

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
  /// Máy in LAN chỉ tính là bật khi mở được cổng in, hoặc từ chối kết nối nhưng đúng máy
  /// ([mac] khớp bảng ARP) — xem `LanPrinterScanner.isPrinterAlive`.
  static Future<bool> reachable(String address, {String? mac}) async {
    try {
      if (UsbPrinters.isLocal(address)) {
        return await UsbPrinters.present(
          address,
        ).timeout(const Duration(seconds: 5));
      }
      final parsed = parsePrinterAddress(address);
      if (parsed == null) return false;
      return await LanPrinterScanner.isPrinterAlive(
        parsed.$1,
        port: parsed.$2,
        mac: mac,
      );
    } catch (_) {
      return false;
    }
  }

  /// In ảnh hoá đơn của [job] ra [address]; `null` = in được.
  static Future<AgentPrintFailure?> printJob(
    PrintRelayJob job,
    String address, {
    bool allowBeep = true,
    bool autoCut = true,
  }) async {
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
        beep: job.beep && allowBeep,
        cut: autoCut,
      ),
    );
  }

  /// Khổ hàng tem của [job]: kích thước thật kèm lệnh ([PrintRelayJob.labelSpec])
  /// nếu có, không thì theo tên khổ của app ([PrintRelayJob.labelSize], mặc định
  /// 2 tem/hàng 35×22mm).
  static TsplLabelSpec labelSpecOf(PrintRelayJob job) {
    final base = TsplLabelSpec.fromLabelPerRow(
      job.labelSize ?? LabelPerRow.doubleLabels,
    )!;
    final spec = job.labelSpec;
    if (spec == null) return base;
    return TsplLabelSpec(
      widthMm: spec.widthMm,
      heightMm: spec.heightMm,
      gapMm: spec.gapMm,
      home: base.home,
      shiftXDots: spec.shiftXDots ?? base.shiftXDots,
    );
  }

  /// Khe thật của cuộn tem trên máy này ([gapMm] > 0) thay cho khe trong lệnh.
  static TsplLabelSpec withGap(TsplLabelSpec spec, num gapMm) =>
      gapMm <= 0 ? spec : spec.copyWith(gapMm: gapMm);

  /// Đầu in của máy tem này: [dpi] (203 / 300) và ruy-băng mực ([ribbon]; `null` = không gửi lệnh).
  static TsplLabelSpec withDevice(
    TsplLabelSpec spec, {
    int dpi = 203,
    bool? ribbon,
  }) => spec.copyWith(dpi: dpi, ribbon: ribbon);

  /// In các hàng tem (TSPL) của [job] ra [address]; `null` = in được.
  /// [calibration]: chỉnh tem in lệch của máy tính này.
  static Future<AgentPrintFailure?> printLabelJob(
    PrintRelayJob job,
    String address, {
    LabelCalibration calibration = LabelCalibration.none,
    num gapOverrideMm = 0,
    int dpi = 203,
    bool? ribbon,
  }) async {
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
      () => TsplPrinter.printImages(
        port,
        job.images,
        spec: withDevice(
          withGap(labelSpecOf(job), gapOverrideMm),
          dpi: dpi,
          ribbon: ribbon,
        ),
        copies: job.copies,
        calibration: calibration,
      ),
    );
  }

  /// In MỘT tem thử căn chỉnh đúng khổ
  /// [spec] với độ chỉnh [calibration]; `null` = in được. [labelsPerRow] (kèm [temWidthMm]):
  /// in tem mẫu như ngoài thị trường — tên hàng, giá, mã vạch EAN-13 trong khung sát mép.
  static Future<AgentPrintFailure?> printLabelCalibration({
    required String address,
    required TsplLabelSpec spec,
    LabelCalibration calibration = LabelCalibration.none,
    num gapOverrideMm = 0,
    int? labelsPerRow,
    int? temWidthMm,
    int repeat = 1,
    int dpi = 203,
    bool? ribbon,
  }) async {
    final port = portOf(address);
    if (port == null) {
      return const AgentPrintFailure(
        AgentJobError.unreachable,
        detail: 'Chưa chọn máy in',
      );
    }
    return _guard(
      address,
      () => TsplPrinter.printCalibration(
        port,
        spec: withDevice(
          withGap(spec, gapOverrideMm),
          dpi: dpi,
          ribbon: ribbon,
        ),
        calibration: calibration,
        labelsPerRow: labelsPerRow,
        temWidthMm: temWidthMm,
        repeat: repeat,
      ),
    );
  }

  /// Cho máy in [address] kêu bíp ngắn (nhận ra máy nào): máy tem [label] dùng lệnh tem; `null` =
  /// đã gửi. Máy không có còi thì không có tiếng nhưng vẫn "gửi được".
  /// Bảo máy tem dò lại khe cuộn tem (`GAPDETECT`): máy cuốn vài tem để đo khe thật —
  /// dùng khi vừa đổi cuộn tem (cuộn mới khe khác thì tem lệch dần). `null` = đã gửi.
  static Future<AgentPrintFailure?> detectGap({
    required String address,
    required TsplLabelSpec spec,
    num gapOverrideMm = 0,
    int dpi = 203,
    bool? ribbon,
  }) async {
    final port = portOf(address);
    if (port == null) {
      return const AgentPrintFailure(
        AgentJobError.unreachable,
        detail: 'Chưa chọn máy in',
      );
    }
    return _guard(
      address,
      () => TsplPrinter.detectGap(
        port,
        spec: withDevice(
          withGap(spec, gapOverrideMm),
          dpi: dpi,
          ribbon: ribbon,
        ),
      ),
    );
  }

  static Future<AgentPrintFailure?> beep(
    String address, {
    required bool label,
  }) async {
    final port = portOf(address);
    if (port == null) {
      return const AgentPrintFailure(
        AgentJobError.unreachable,
        detail: 'Chưa chọn máy in',
      );
    }
    return _guard(
      address,
      () => port.send(PrinterBeep.bytes(label: label), checkStatus: false),
    );
  }

  /// Phiếu in thử (chữ không dấu — in thô không cần phông tiếng Việt).
  static Future<AgentPrintFailure?> printTest({
    required String address,
    required String label,
    required int paperMm,
    bool autoCut = true,
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
        ], cut: autoCut),
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
        // Máy tem: kẹt giấy / sai khổ khe tem, hết ruy-băng mực — cũng giữ lệnh, tự in khi xử lý xong.
        PaperStatus.jam => const AgentPrintFailure(
          AgentJobError.outOfPaper,
          detail: 'Máy in tem kẹt giấy hoặc sai khổ tem — kiểm tra cuộn tem',
        ),
        PaperStatus.ribbonEnd => const AgentPrintFailure(
          AgentJobError.outOfPaper,
          detail: 'Máy in tem hết cuộn mực (ruy-băng)',
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
