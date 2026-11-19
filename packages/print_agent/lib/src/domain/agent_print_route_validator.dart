import 'entities/agent_print_route.dart';

/// Lý do một dòng cấu hình không hợp lệ.
enum AgentPrintRouteIssue {
  /// Trùng tên chức năng với dòng khác.
  duplicateName,

  /// Có mẫu in nhưng chưa chọn máy in.
  missingPrinter,

  /// Có máy in nhưng chưa chọn mẫu in.
  missingTemplate,

  /// Số bản in nhỏ hơn 1.
  invalidCopies,
}

/// Kiểm tra cấu hình in theo chức năng trước khi lưu (nghiệp vụ Tool in ver 3):
/// tên chức năng không được trùng, và phải khai báo đủ cặp máy in + mẫu in
/// (hoặc để trống cả hai). Dòng trống hoàn toàn là hợp lệ (chưa cấu hình).
class AgentPrintRouteValidator {
  const AgentPrintRouteValidator._();

  /// Lỗi theo vị trí dòng trong [routes]; dòng hợp lệ không có mặt trong kết quả.
  static Map<int, Set<AgentPrintRouteIssue>> validate(
    List<AgentPrintRoute> routes,
  ) {
    final out = <int, Set<AgentPrintRouteIssue>>{};
    void add(int i, AgentPrintRouteIssue issue) =>
        out.putIfAbsent(i, () => <AgentPrintRouteIssue>{}).add(issue);

    final seen = <String, int>{};
    for (var i = 0; i < routes.length; i++) {
      final r = routes[i];
      final key = r.title.toLowerCase();
      final first = seen[key];
      if (first == null) {
        seen[key] = i;
      } else {
        add(first, AgentPrintRouteIssue.duplicateName);
        add(i, AgentPrintRouteIssue.duplicateName);
      }
      if (r.hasTemplate && !r.hasPrinter) {
        add(i, AgentPrintRouteIssue.missingPrinter);
      }
      if (r.hasPrinter && !r.hasTemplate) {
        add(i, AgentPrintRouteIssue.missingTemplate);
      }
      if (r.copies < 1) add(i, AgentPrintRouteIssue.invalidCopies);
    }
    return out;
  }

  static bool isValid(List<AgentPrintRoute> routes) => validate(routes).isEmpty;
}
