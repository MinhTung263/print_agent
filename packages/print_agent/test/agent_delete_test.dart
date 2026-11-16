import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';
// ignore: implementation_imports
import 'package:print_agent/src/l10n/agent_locale_keys.dart';
// ignore: implementation_imports
import 'package:print_agent/src/presentation/widgets/sheets/agent_remove_button.dart';

import 'support/fake_gateway.dart';
import 'support/fake_host.dart';
import 'support/fake_job_printer.dart';
import 'support/fake_station.dart';

/// Kênh ghi lại các trạm bị gỡ (các hàm khác không dùng trong test này).
class _Recorder implements PrintRelayTransport {
  final removed = <Object?>[];

  @override
  Future<bool> removeStation(Map<Object?, Object?> station) async {
    removed.add(station['id']);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      switch (invocation.memberName.toString()) {
        _ => Future<void>.value(),
      };
}

void main() {
  setUp(() {
    PrintAgentModule.init(FakeHost());
    Get.locale = const Locale('vi', 'VN');
  });

  test('xoá trạm: gỡ bản ghi trên hàng đợi + quên trên máy này', () async {
    final rec = _Recorder();
    final service = AgentService<FakePrinter>(
      gateway: FakeGateway(),
      printer: FakeJobPrinter(),
      extraQueues: (_) async => [rec],
    );
    final ok = await service.deleteAgent({'id': 'old-6775', 'name': 'Trạm in'});
    expect(ok, isTrue);
    expect(rec.removed, ['old-6775']);
    // Không có mã trạm: không làm gì.
    expect(await service.deleteAgent({'name': 'x'}), isFalse);
    expect(rec.removed, hasLength(1));
  });

  testWidgets(
    'trạm bản cũ (còn máy in, không báo stop): nút là "Xoá trạm in"',
    (t) async {
      PrintAgentUi.init(const MaterialAgentUiKit(), station: FakeStation());
      await t.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AgentRemoveButton(
              station: const {
                'id': 'old',
                'name': 'Trạm in',
                'printers': {'ok': 1, 'total': 1},
              },
            ),
          ),
        ),
      );
      expect(
        find.text(LocaleKeys.printerSetting_agentDelete.tr),
        findsOneWidget,
      );
      expect(find.text(LocaleKeys.printerSetting_agentRemove.tr), findsNothing);
    },
  );

  testWidgets('trạm bản mới (báo stop): vẫn là "Ngắt kết nối trạm in"', (
    t,
  ) async {
    PrintAgentUi.init(const MaterialAgentUiKit(), station: FakeStation());
    await t.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: AgentRemoveButton(
            station: const {'id': 'new', 'name': 'Trạm in', 'stop': true},
          ),
        ),
      ),
    );
    expect(find.text(LocaleKeys.printerSetting_agentRemove.tr), findsOneWidget);
  });
}
