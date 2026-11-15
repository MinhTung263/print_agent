import 'dart:async';
import 'dart:typed_data';

import 'package:print_agent/print_agent.dart';

import 'desktop_agent.dart';
import 'desktop_printer.dart';
import 'paper_size.dart';

/// Lệnh in của trang web EasyPOS (cổng web) đi chung hàng đợi với lệnh của
/// app bán hàng ([AgentService.jobs]): bỏ lệnh trùng theo `jobId`, đúng thứ tự
/// trên từng máy in, giữ lệnh khi hết giấy / mở nắp, ghi nhật ký trạm in.
class DesktopWebPrint implements WebPrintPort {
  DesktopWebPrint(this._agent);

  final DesktopAgent _agent;

  static const String defaultSender = 'Web EasyPOS';

  @override
  Map<String, Object?> info() {
    final c = _agent.config;
    final own = c.printer.trim();
    return {
      'app': 'easypos-print-agent',
      'api': 1,
      'ready': c.ready,
      'on': c.ready && _agent.isOn,
      'companyId': c.companyId,
      'companyName': c.companyName,
      'name': _agent.service.displayName,
      'paper': c.paper.name,
      'printers': [
        if (c.hasPrinter)
          {
            'id': const WebPrintTarget.builtIn().id,
            'name': DesktopPrinter.builtInName,
            'ready': _agent.gateway.connected,
          },
        for (final p in _agent.gateway.lanPrinters.printers)
          if (p.address != own)
            {'id': WebPrintTarget.lan(p.address).id, 'name': p.name},
      ],
    };
  }

  @override
  Future<WebPrintResult> print(WebPrintRequest request) async {
    final c = _agent.config;
    if (!c.ready || !_agent.isOn) {
      return const WebPrintResult(
        WebPrintStatus.off,
        message: 'Trạm in đang tắt — mở app Agent và bật nhận lệnh in',
      );
    }
    if (request.companyId != null && request.companyId != c.companyId) {
      return WebPrintResult(
        WebPrintStatus.wrongCompany,
        message: 'Trạm in đang đăng nhập cửa hàng khác (${c.companyName})',
      );
    }
    if (request.target.isBuiltIn && !c.hasPrinter) {
      return const WebPrintResult(
        WebPrintStatus.noPrinter,
        message: 'Trạm in chưa chọn máy in',
      );
    }
    final paper = PaperSize.fromName(request.paper ?? c.paper.name);
    final Uint8List image;
    try {
      image = await WebReceiptImage.fit(request.image, paper.dots);
    } on FormatException {
      return const WebPrintResult(
        WebPrintStatus.failed,
        message: 'Ảnh phiếu không đọc được',
      );
    }
    final held = Completer<WebPrintStatus>();
    final job =
        PrintRelayJob(
          kind: PrintRelayJobKind.receipt,
          printer: _printer(request.target),
          images: [image],
          paperSize: paper.name,
          copies: request.copies,
          openDrawer: request.openDrawer,
          beep: request.beep,
          sender: request.sender ?? defaultSender,
          key: 'web:${c.companyId}:${request.jobId}',
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ).withOnHeld(() {
          if (!held.isCompleted) held.complete(WebPrintStatus.held);
        });
    final status = await Future.any([
      _agent.service.jobs
          .handle(job)
          .then((ok) => ok ? WebPrintStatus.done : WebPrintStatus.failed),
      held.future,
    ]);
    return switch (status) {
      WebPrintStatus.held => const WebPrintResult(
        WebPrintStatus.held,
        message:
            'Máy in hết giấy hoặc đang mở nắp — trạm in sẽ tự in khi '
            'máy in sẵn sàng lại',
      ),
      WebPrintStatus.failed => const WebPrintResult(
        WebPrintStatus.failed,
        message: 'Máy in chưa in được — kiểm tra máy in đã bật và còn kết nối',
      ),
      _ => WebPrintResult(status),
    };
  }

  PrintRelayPrinter _printer(WebPrintTarget target) {
    final lan = target.lanAddress;
    if (lan == null) {
      return PrintRelayPrinter.stationBuiltIn(
        stationId: _agent.service.stationId,
        name: DesktopPrinter.builtInName,
      );
    }
    final known = _agent.gateway.lanPrinters.printers
        .where((p) => p.address == lan)
        .firstOrNull;
    return PrintRelayPrinter(
      address: lan,
      name: known?.name,
      id: known?.id,
      mac: known?.mac,
    );
  }
}
