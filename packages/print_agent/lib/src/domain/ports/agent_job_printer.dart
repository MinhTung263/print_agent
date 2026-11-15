import 'dart:typed_data';

import 'package:print_agent_core/print_agent_core.dart';

import '../entities/agent_job_log.dart';
import '../entities/agent_printer_ref.dart';
import '../entities/peer_built_in_printer.dart';

/// Lý do in lỗi (kèm câu máy in báo, nếu có).
class AgentPrintFailure {
  const AgentPrintFailure(this.error, {this.detail});

  final AgentJobError error;
  final String? detail;
}

/// Khổ giấy + chức năng in của máy in tích hợp (báo cho máy khác).
class AgentBuiltInSpec {
  const AgentBuiltInSpec({this.paper, this.templates = const []});

  /// Tên khổ giấy của app (VD `size80`).
  final String? paper;

  /// Tên các chức năng in (VD `temporaryPrintForm`).
  final List<String> templates;
}

/// Cổng in của app chủ cho module Agent — chỉ phần thật sự riêng của app:
/// in một lệnh bằng máy in của app, đổi qua lại giữa máy in của app và máy in
/// trên hàng đợi. [P] là kiểu máy in của app (VD `PrinterEntity`).
abstract interface class AgentJobPrinter<P extends AgentPrinterRef> {
  /// Máy in nhận lệnh [job] trên máy Agent: máy đã lưu (theo mã / máy in tích
  /// hợp), không thấy thì dựng từ thông tin máy gửi báo.
  P resolve(PrintRelayJob job);

  /// In [job] ra [printer] (đã kết nối được); `null` = in được.
  Future<AgentPrintFailure?> printJob(P printer, PrintRelayJob job);

  /// Máy gửi: máy in đích trên hàng đợi của máy in LAN / USB [printer];
  /// `null` khi không gửi qua Agent được.
  PrintRelayPrinter? targetOf(P printer);

  /// Máy gửi: ảnh hoá đơn thu về khổ giấy [paper] trước khi gửi.
  Future<Uint8List> fitReceipt(Uint8List image, String paper);

  /// Máy in tích hợp của máy này (báo cho máy khác); `null` khi không có.
  AgentBuiltInSpec? builtInSpec();

  /// Chức năng in mặc định của máy in tích hợp (Agent bản cũ không báo).
  List<String> get defaultTemplates;

  /// Máy in tích hợp của Agent khác dưới dạng máy in của app.
  P peerBuiltIn(PeerBuiltInPrinter printer);

  /// Tên máy in trong thông báo lỗi.
  String messageName(P printer);

  /// Chạy [action] kèm tiến trình in trên giao diện (khi bấm "In lại").
  Future<T> withProgress<T>(P printer, Future<T> Function() action);
}
