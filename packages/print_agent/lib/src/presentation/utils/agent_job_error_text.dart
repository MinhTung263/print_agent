import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

/// Chữ dễ hiểu cho lỗi in: lý do, cách xử lý, và câu ghép cho thông báo — một chỗ dùng
/// chung cho nhật ký in, nút in thử và các thông báo lỗi.
abstract final class AgentJobErrorText {
  /// Vì sao in không được.
  static String reason(AgentJobError? e) => switch (e) {
    AgentJobError.noContent => LocaleKeys.printerSetting_agentJobErrNoContent,
    AgentJobError.otherNetwork =>
      LocaleKeys.printerSetting_agentJobErrOtherNetwork,
    AgentJobError.builtInNotReady =>
      LocaleKeys.printerSetting_agentJobErrBuiltIn,
    AgentJobError.sendFailed => LocaleKeys.printerSetting_agentJobErrSend,
    AgentJobError.interrupted =>
      LocaleKeys.printerSetting_agentJobErrInterrupted,
    AgentJobError.outOfPaper => LocaleKeys.printerSetting_agentJobErrOutOfPaper,
    AgentJobError.coverOpen => LocaleKeys.printerSetting_agentJobErrCoverOpen,
    AgentJobError.overheated => LocaleKeys.printerSetting_agentJobErrOverheated,
    AgentJobError.busy => LocaleKeys.printerSetting_agentJobErrBusy,
    AgentJobError.unreachable =>
      LocaleKeys.printerSetting_agentJobErrUnreachable,
    AgentJobError.notReady ||
    null => LocaleKeys.printerSetting_agentJobErrNotReady,
  }.tr;

  /// Cách xử lý.
  static String hint(AgentJobError? e) => switch (e) {
    AgentJobError.noContent => LocaleKeys.printerSetting_agentJobHintNoContent,
    AgentJobError.otherNetwork =>
      LocaleKeys.printerSetting_agentJobHintOtherNetwork,
    AgentJobError.builtInNotReady =>
      LocaleKeys.printerSetting_agentJobHintBuiltIn,
    AgentJobError.sendFailed => LocaleKeys.printerSetting_agentJobHintSend,
    AgentJobError.interrupted =>
      LocaleKeys.printerSetting_agentJobHintInterrupted,
    AgentJobError.outOfPaper =>
      LocaleKeys.printerSetting_agentJobHintOutOfPaper,
    AgentJobError.coverOpen => LocaleKeys.printerSetting_agentJobHintCoverOpen,
    AgentJobError.overheated =>
      LocaleKeys.printerSetting_agentJobHintOverheated,
    AgentJobError.busy => LocaleKeys.printerSetting_agentJobHintBusy,
    AgentJobError.unreachable =>
      LocaleKeys.printerSetting_agentJobHintUnreachable,
    AgentJobError.notReady ||
    null => LocaleKeys.printerSetting_agentJobHintNotReady,
  }.tr;

  /// Câu chi tiết máy in / hệ điều hành báo kèm (rỗng nếu không có hoặc chỉ lặp lại tên lỗi).
  static String detail(AgentJobError? e, String? detail) {
    final d = (detail ?? '').trim();
    return d.isEmpty || d == e?.name ? '' : d;
  }

  /// Một thông báo đủ ý: lý do + cách xử lý (+ chi tiết gốc nếu có).
  static String message(AgentJobError? e, {String? detail}) {
    final d = AgentJobErrorText.detail(e, detail);
    return [
      reason(e),
      hint(e),
      if (d.isNotEmpty) LocaleKeys.printerSetting_agentJobDetailTr(detail: d),
    ].join('\n');
  }
}
