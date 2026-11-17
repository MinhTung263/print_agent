import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';
// ignore: implementation_imports
import 'package:print_agent/src/l10n/agent_locale_keys.dart';
// ignore: implementation_imports
import 'package:print_agent/src/presentation/widgets/sheets/agent_map_arrange_sheet.dart';

import 'support/fake_host.dart';
import 'support/fake_station.dart';

void main() {
  late FakeStation station;

  setUp(() {
    PrintAgentModule.init(FakeHost());
    PrintAgentUi.init(
      const MaterialAgentUiKit(),
      station: station = FakeStation(),
    );
    Get.locale = const Locale('vi', 'VN');
    AgentMapLayout.agents.clear();
    AgentMapLayout.printers.clear();
    AgentPeersVisibility.show.value = false;
    station.relay.stations.value = [
      {
        'id': 'peer-bep',
        'name': 'Trạm Bếp Nitro',
        'printers': {
          'names': [
            {'name': 'HPRT bếp', 'kind': 'lan', 'addr': '10.0.0.9', 'ok': true},
          ],
        },
      },
    ];
  });

  Future<void> open(WidgetTester t, {required bool isAgent}) async {
    await t.binding.setSurfaceSize(const Size(600, 1400));
    await t.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AgentMapArrangeSheet(isAgent: isAgent),
          ),
        ),
      ),
    );
    await t.pump();
  }

  testWidgets(
    'Máy Agent đã ẨN trạm in khác: bảng sắp xếp không liệt kê trạm khác',
    (t) async {
      await open(t, isAgent: true);
      expect(find.textContaining('Trạm Bếp Nitro'), findsNothing);
      expect(find.textContaining('Máy test'), findsOneWidget);
    },
  );

  testWidgets('Bật hiện trạm in khác: bảng sắp xếp liệt kê cả trạm khác', (
    t,
  ) async {
    AgentPeersVisibility.show.value = true;
    await open(t, isAgent: true);
    expect(find.textContaining('Trạm Bếp Nitro'), findsOneWidget);
  });

  testWidgets(
    'Máy bán hàng: luôn liệt kê các Agent của công ty (không theo nút ẩn / hiện)',
    (t) async {
      await open(t, isAgent: false);
      expect(find.textContaining('Trạm Bếp Nitro'), findsOneWidget);
    },
  );

  testWidgets(
    'Lưu khi đang ẩn trạm khác: giữ nguyên thứ tự đã sắp của trạm bị ẩn',
    (t) async {
      AgentMapLayout.agents.assignAll(['peer-bep']);
      AgentMapLayout.printers.assignAll({
        'peer-bep': ['ip:10.0.0.9'],
      });
      await open(t, isAgent: true);
      await t.tap(find.text(LocaleKeys.printerSetting_agentArrangeSave.tr));
      await t.pumpAndSettle();
      expect(AgentMapLayout.agents.toList(), contains('peer-bep'));
      expect(AgentMapLayout.printers['peer-bep'], ['ip:10.0.0.9']);
    },
  );

  testWidgets(
    'Hai máy cùng tên (HPRT): mỗi máy có dòng phụ cách kết nối + địa chỉ để phân biệt',
    (t) async {
      AgentPeersVisibility.show.value = true;
      station.relay.stations.value = [
        {
          'id': 'peer-1',
          'name': 'Trạm Quầy',
          'printers': {
            'names': [
              {
                'name': 'Máy in hoá đơn · HPRT',
                'kind': 'lan',
                'addr': '192.168.1.242',
                'ok': true,
              },
              {
                'name': 'Máy in hoá đơn · HPRT',
                'kind': 'lan',
                'addr': '192.168.1.243',
                'ok': true,
              },
              {
                'name': 'Máy in hoá đơn · XP',
                'kind': 'usb',
                'addr': 'usb:1:2:a',
                'ok': true,
              },
              {
                'name': 'Máy in hoá đơn · XP',
                'kind': 'usb',
                'addr': 'usb:1:2:b',
                'ok': true,
              },
            ],
          },
        },
      ];
      await open(t, isAgent: false);
      expect(find.textContaining('192.168.1.242'), findsOneWidget);
      expect(find.textContaining('192.168.1.243'), findsOneWidget);
      // Hai máy USB cùng tên, cùng dòng phụ: đánh số.
      expect(find.textContaining('#1'), findsOneWidget);
      expect(find.textContaining('#2'), findsOneWidget);
    },
  );
}
