import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets(
    'AgentSwitch: kích thước 44×24 như công tắc EasyPOS, vùng chạm ≥ 44',
    (t) async {
      await t.pumpWidget(host(AgentSwitch(value: false, onChanged: (_) {})));
      final track = t.getSize(find.byType(AnimatedContainer));
      expect(track, const Size(44, 24));
      expect(
        t.getSize(find.byType(AgentSwitch)).height,
        greaterThanOrEqualTo(44),
      );
    },
  );

  testWidgets('AgentSwitch: bấm đổi trạng thái; con trượt về phải khi bật', (
    t,
  ) async {
    var v = false;
    late StateSetter set;
    await t.pumpWidget(
      host(
        StatefulBuilder(
          builder: (_, s) {
            set = s;
            return AgentSwitch(value: v, onChanged: (x) => set(() => v = x));
          },
        ),
      ),
    );
    final thumb = find.byType(AnimatedAlign);
    expect(t.widget<AnimatedAlign>(thumb).alignment, Alignment.centerLeft);
    await t.tap(find.byType(AgentSwitch));
    await t.pumpAndSettle();
    expect(v, isTrue);
    expect(t.widget<AnimatedAlign>(thumb).alignment, Alignment.centerRight);
    await t.tap(find.byType(AgentSwitch));
    await t.pumpAndSettle();
    expect(v, isFalse);
  });

  testWidgets(
    'AgentSwitch: kéo ngang bật / tắt, không gọi lại khi đã đúng trạng thái',
    (t) async {
      final calls = <bool>[];
      await t.pumpWidget(host(AgentSwitch(value: false, onChanged: calls.add)));
      await t.drag(find.byType(AgentSwitch), const Offset(30, 0));
      await t.pump();
      expect(calls.contains(true), isTrue);
      expect(
        calls.contains(false),
        isFalse,
        reason: 'đang tắt, kéo trái không đổi gì',
      );
    },
  );

  testWidgets('AgentSwitch: enabled=false thì không đổi được', (t) async {
    var calls = 0;
    await t.pumpWidget(
      host(
        AgentSwitch(value: false, enabled: false, onChanged: (_) => calls++),
      ),
    );
    await t.tap(find.byType(AgentSwitch));
    await t.drag(find.byType(AgentSwitch), const Offset(30, 0));
    await t.pump();
    expect(calls, 0);
  });
}
