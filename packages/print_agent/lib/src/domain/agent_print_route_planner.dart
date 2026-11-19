import 'entities/agent_print_route.dart';
import 'ports/agent_print_routing_store.dart';

/// Điền sẵn thông minh cho cấu hình in: khách chỉ đổi khi muốn khác.
class AgentPrintRoutePlanner {
  const AgentPrintRoutePlanner._();

  /// Dòng mới cho [function]: máy in = máy mặc định (không có thì máy duy nhất),
  /// mẫu in = mẫu đầu tiên đúng loại chứng từ. Không đủ dữ kiện thì để trống đúng
  /// phần đó (người dùng chọn tiếp).
  static AgentPrintRoute create(
    AgentPrintFunction function, {
    required List<String> printers,
    required List<AgentPrintTemplate> templates,
    String? defaultPrinter,
  }) {
    final printer =
        (defaultPrinter != null && printers.contains(defaultPrinter))
        ? defaultPrinter
        : (printers.length == 1 ? printers.single : null);
    final matching = templatesFor(function, templates);
    return AgentPrintRoute(
      function: function,
      printerName: printer,
      templateId: matching.isEmpty ? null : matching.first.id,
    );
  }

  /// Mẫu in đúng loại chứng từ của [function].
  static List<AgentPrintTemplate> templatesFor(
    AgentPrintFunction function,
    List<AgentPrintTemplate> templates,
  ) => [
    for (final t in templates)
      if (t.function == function) t,
  ];

  /// Chức năng chưa có dòng nào — để hiện nút "thêm" (chức năng không dùng thì ẩn).
  static List<AgentPrintFunction> unused(List<AgentPrintRoute> routes) => [
    for (final f in AgentPrintFunction.values)
      if (!routes.any((r) => r.function == f)) f,
  ];

  /// Một dòng tóm tắt "Thanh toán → Xprinter" (chưa chọn máy: chỉ tên chức năng).
  static String summary(AgentPrintRoute r) =>
      r.hasPrinter ? '${r.title} → ${r.printerName}' : r.title;

  static final RegExp _kitchen = RegExp(
    r'b[eế]p|bar|kitchen|pha ch[eế]|ch[eế] bi[eế]n',
    caseSensitive: false,
  );
  static final RegExp _label = RegExp(
    r'tem|label|nh[aã]n|barcode|tsc|zebra|argox|gprinter.*(gp-?1|2)',
    caseSensitive: false,
  );

  /// Gợi ý chức năng cho máy in theo TÊN: máy tem → Tem nhãn; máy bếp / bar → Chế biến + Huỷ
  /// món; còn lại (máy hoá đơn) → Thanh toán + Tạm tính + QR thanh toán. Chỉ gợi ý, người dùng
  /// vẫn chọn lại được.
  static List<AgentPrintFunction> suggest(String printerName) {
    final n = printerName.trim();
    if (_label.hasMatch(n)) return const [AgentPrintFunction.label];
    if (_kitchen.hasMatch(n)) {
      return const [AgentPrintFunction.kitchen, AgentPrintFunction.cancelDish];
    }
    return const [
      AgentPrintFunction.payment,
      AgentPrintFunction.provisional,
      AgentPrintFunction.paymentQr,
    ];
  }

  /// Gợi ý cho [printerName] sau khi bỏ các chức năng đã có máy in nhận (không giành của máy khác).
  static List<AgentPrintFunction> suggestFree(
    String printerName,
    List<AgentPrintRoute> routes,
  ) => [
    for (final f in suggest(printerName))
      if (!routes.any((r) => r.function == f)) f,
  ];
}
