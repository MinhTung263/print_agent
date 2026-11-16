import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';

import 'support/fake_host.dart';

void main() {
  testWidgets(
    'đọc danh sách lần đầu ngay trong Obx: không lỗi setState lúc build',
    (t) async {
      final host = FakeHost(companyKey: '7');
      host.storage.data['station_builtin_printers_7'] = [
        {'id': 'abc', 'name': 'B68', 'paper': 'size58', 'enabled': true},
      ];
      PrintAgentModule.init(host);

      await t.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Đã nghe danh sách từ trước (như thẻ khác trên màn hình).
                Obx(() => Text('a=${PeerBuiltInPrinters.items.length}')),
                // Đọc danh sách lần đầu ngay lúc dựng (như bảng máy in của trạm).
                Obx(() => Text('n=${PeerBuiltInPrinters.all.length}')),
              ],
            ),
          ),
        ),
      );
      expect(t.takeException(), isNull);
      await t.pump();
      expect(t.takeException(), isNull);
      expect(PeerBuiltInPrinters.items.length, 1);
      expect(find.text('n=1'), findsOneWidget);
      expect(find.text('a=1'), findsOneWidget);
    },
  );
}
