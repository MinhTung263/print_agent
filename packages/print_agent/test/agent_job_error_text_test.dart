import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';
// ignore: implementation_imports
import 'package:print_agent/src/l10n/agent_translations.dart';

import 'support/fake_host.dart';
import 'support/fake_station.dart';

void main() {
  setUp(() {
    PrintAgentModule.init(FakeHost());
    PrintAgentUi.init(const MaterialAgentUiKit(), station: FakeStation());
    Get.addTranslations(agentTranslations);
    Get.locale = const Locale('vi', 'VN');
  });

  test('mỗi lỗi đều có lý do + cách xử lý riêng', () {
    for (final e in AgentJobError.values) {
      expect(AgentJobErrorText.reason(e), isNotEmpty, reason: e.name);
      expect(AgentJobErrorText.hint(e), isNotEmpty, reason: e.name);
      expect(AgentJobErrorText.hint(e), isNot(e.name), reason: e.name);
    }
    expect(AgentJobErrorText.hint(AgentJobError.outOfPaper), contains('giấy'));
  });

  test(
    'message ghép lý do, cách xử lý và chi tiết gốc; bỏ chi tiết trùng tên lỗi',
    () {
      final full = AgentJobErrorText.message(
        AgentJobError.unreachable,
        detail: 'SocketException: No route to host',
      );
      expect(full, contains('Không kết nối được máy in'));
      expect(full, contains('địa chỉ IP'));
      expect(full, contains('No route to host'));
      expect(
        AgentJobErrorText.message(AgentJobError.busy, detail: 'busy'),
        isNot(contains('Chi tiết')),
      );
    },
  );

  testWidgets('nhật ký in lỗi: lý do, cách xử lý, IP và câu lỗi gốc', (
    t,
  ) async {
    final log = AgentJobLog(
      at: DateTime(2026, 11, 16, 10),
      isLabel: false,
      printerName: 'Máy in bếp',
      ok: false,
      viaLan: true,
      durationMs: 300,
      error: AgentJobError.unreachable,
      connection: 'lan',
      printerAddress: '192.168.1.50',
      detail: 'SocketException: No route to host',
    );
    await t.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: AgentJobRow(log: log)),
      ),
    );
    expect(find.textContaining('Không kết nối được máy in'), findsOneWidget);
    expect(find.textContaining('đúng địa chỉ IP'), findsOneWidget);
    expect(find.textContaining('192.168.1.50'), findsOneWidget);
    expect(find.textContaining('No route to host'), findsOneWidget);
  });

  testWidgets('lệnh in thành công: không hiện cách xử lý', (t) async {
    final log = AgentJobLog(
      at: DateTime(2026, 11, 16, 10),
      isLabel: false,
      printerName: 'Máy in bếp',
      ok: true,
      viaLan: true,
      durationMs: 300,
    );
    await t.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: AgentJobRow(log: log)),
      ),
    );
    expect(find.textContaining('Kiểm tra máy in'), findsNothing);
  });
}
