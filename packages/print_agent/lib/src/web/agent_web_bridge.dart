import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/agent_service.dart';
import '../domain/entities/agent_printer_ref.dart';
import '../print_agent_module.dart';
import 'agent_service_web_print.dart';
import 'web_bridge_server.dart';
import 'web_origin_policy.dart';

/// Cổng web của MỘT thiết bị bật Trạm in (mọi nền tảng): mở khi Trạm in BẬT,
/// đóng khi TẮT — trang web trong mạng quán in ra máy in của thiết bị này.
class AgentWebBridge<P extends AgentPrinterRef> {
  AgentWebBridge(
    AgentService<P> service, {
    required String builtInName,
    required bool Function() hasBuiltInPrinter,
    required String Function() defaultPaper,
    WebOriginPolicy Function()? policy,
  }) : _service = service,
       _server = WebBridgeServer(
         AgentServiceWebPrint<P>(
           service,
           builtInName: builtInName,
           hasBuiltInPrinter: hasBuiltInPrinter,
           defaultPaper: defaultPaper,
         ),
         // Bản debug nhận thêm trang `http://` trong mạng nội bộ (trang test).
         policy: policy ?? (() => WebOriginPolicy(allowLocalHttp: kDebugMode)),
         log: PrintAgentModule.host.log,
       );

  final AgentService<P> _service;
  final WebBridgeServer _server;
  bool _attached = false;

  /// Cổng đang mở; `null` khi chưa mở.
  int? get port => _server.port;

  /// Bắt đầu theo dõi bật / tắt Trạm in (gọi nhiều lần không sao).
  void attach() {
    if (_attached) return;
    _attached = true;
    _service.relay.isStation.addListener(_sync);
    _sync();
  }

  void _sync() {
    if (_service.relay.isStation.value) {
      unawaited(_server.start());
    } else {
      unawaited(_server.stop());
    }
  }
}
