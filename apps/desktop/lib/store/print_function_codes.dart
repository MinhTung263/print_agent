import 'package:print_agent/print_agent.dart' show AgentPrintFunction;

/// Đổi qua lại giữa chức năng của Agent ([AgentPrintFunction]) và mã `typeTemplates` mà API
/// máy in của cửa hàng dùng. Khác nhau ở hai mã: API gán Tem nhãn = 5, QR thanh toán = 6
/// (`TypeTemplateEnum.value` của app bán hàng); Agent theo thứ tự tài liệu (QR 5, Tem 6).
abstract final class PrintFunctionCodes {
  static const Map<AgentPrintFunction, int> _api = {
    AgentPrintFunction.provisional: 0,
    AgentPrintFunction.payment: 1,
    AgentPrintFunction.kitchen: 2,
    AgentPrintFunction.cancelDish: 3,
    AgentPrintFunction.supply: 4,
    AgentPrintFunction.label: 5,
    AgentPrintFunction.paymentQr: 6,
    AgentPrintFunction.prescription: 7,
  };

  static int apiCode(AgentPrintFunction f) => _api[f]!;

  static AgentPrintFunction? fromApiCode(int code) {
    for (final e in _api.entries) {
      if (e.value == code) return e.key;
    }
    return null;
  }
}
