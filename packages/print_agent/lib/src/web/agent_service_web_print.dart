import 'dart:async';
import 'dart:typed_data';

import 'package:print_agent_core/print_agent_core.dart';

import '../data/agent_service.dart';
import '../domain/entities/agent_printer_ref.dart';
import '../print_agent_module.dart';
import 'web_print_port.dart';
import 'web_print_request.dart';
import 'web_receipt_image.dart';

/// Lệnh in của trang web EasyPOS vào [AgentService] của MỘT thiết bị đang bật
/// Agent (điện thoại, máy POS, máy tính...): đi chung hàng đợi với lệnh của app
/// bán hàng ([AgentService.jobs]) — bỏ lệnh trùng theo `jobId`, đúng thứ tự
/// trên từng máy in, giữ lệnh khi hết giấy / mở nắp, có trong nhật ký trạm.
class AgentServiceWebPrint<P extends AgentPrinterRef> implements WebPrintPort {
  AgentServiceWebPrint(
    this._service, {
    required this.builtInName,
    required this.hasBuiltInPrinter,
    required this.defaultPaper,
  });

  final AgentService<P> _service;

  /// Tên máy in của thiết bị này hiện trên trang web.
  final String builtInName;

  /// Thiết bị có máy in để in (máy in tích hợp / máy in đã chọn).
  final bool Function() hasBuiltInPrinter;

  /// Khổ giấy mặc định: `size58` / `size80`.
  final String Function() defaultPaper;

  static const String defaultSender = 'Web EasyPOS';

  int _company() => int.tryParse(PrintAgentModule.host.companyKey) ?? 0;

  bool get _on =>
      PrintAgentModule.host.shopKey != null && _service.relay.isStation.value;

  static int _dots(String paper) => paper == 'size58' ? 384 : 576;

  @override
  Map<String, Object?> info() => {
    'app': 'easypos-print-agent',
    'api': 1,
    'ready': PrintAgentModule.host.shopKey != null,
    'on': _on,
    'companyId': _company(),
    // Mã hàng đợi in của cửa hàng (xem DesktopWebPrint).
    'shopKey': PrintAgentModule.host.shopKey,
    'name': _service.displayName,
    'paper': defaultPaper(),
    'printers': [
      if (hasBuiltInPrinter())
        {'id': const WebPrintTarget.builtIn().id, 'name': builtInName},
      // Máy in LAN đã lưu trong app của thiết bị này (điện thoại không có máy
      // in tích hợp vẫn in hộ được máy in LAN của quán).
      for (final p in PrintAgentModule.host.printers)
        if (p.refKind == AgentPrinterKind.lan &&
            WebPrintTarget.isPrivateAddress(p.refAddress ?? ''))
          {
            'id': WebPrintTarget.lan(p.refAddress!).id,
            'name': p.nameOrNull ?? p.refAddress,
          },
    ],
  };

  @override
  Future<WebPrintResult> print(WebPrintRequest request) async {
    if (!_on) {
      return const WebPrintResult(
        WebPrintStatus.off,
        message: 'Trạm in đang tắt — bật Trạm in trên thiết bị này',
      );
    }
    if (request.companyId != null && request.companyId != _company()) {
      return const WebPrintResult(
        WebPrintStatus.wrongCompany,
        message: 'Trạm in đang đăng nhập cửa hàng khác',
      );
    }
    if (request.target.isBuiltIn && !hasBuiltInPrinter()) {
      return const WebPrintResult(
        WebPrintStatus.noPrinter,
        message: 'Thiết bị này chưa có máy in để in',
      );
    }
    final paper = request.paper ?? defaultPaper();
    final image = await _fit(request, paper);
    if (image == null) {
      return const WebPrintResult(
        WebPrintStatus.failed,
        message: 'Ảnh phiếu không đọc được',
      );
    }
    final held = Completer<WebPrintStatus>();
    final lan = request.target.lanAddress;
    final job =
        PrintRelayJob(
          kind: PrintRelayJobKind.receipt,
          printer: lan == null
              ? PrintRelayPrinter.stationBuiltIn(
                  stationId: _service.stationId,
                  name: builtInName,
                )
              : PrintRelayPrinter(address: lan),
          images: [image],
          paperSize: paper,
          copies: request.copies,
          openDrawer: request.openDrawer,
          beep: request.beep,
          sender: request.sender ?? defaultSender,
          key: 'web:${_company()}:${request.jobId}',
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ).withOnHeld(() {
          if (!held.isCompleted) held.complete(WebPrintStatus.held);
        });
    final status = await Future.any([
      _service.jobs
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

  static Future<Uint8List?> _fit(WebPrintRequest request, String paper) async {
    try {
      return await WebReceiptImage.fit(request.image, _dots(paper));
    } on FormatException {
      return null;
    }
  }
}
