import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/ui/dashboard/calibration_stepper.dart';

void main() {
  testWidgets('nút − / + gọi đúng hàm, hiện giá trị, nút đủ lớn (44x44)', (
    t,
  ) async {
    var minus = 0, plus = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalibrationStepper(
            title: 'Ngang',
            hint: '+ dời sang phải',
            valueText: '+1.5 mm',
            onMinus: () => minus++,
            onPlus: () => plus++,
          ),
        ),
      ),
    );
    expect(find.text('+1.5 mm'), findsOneWidget);
    await t.tap(find.byIcon(Icons.add_rounded));
    await t.tap(find.byIcon(Icons.add_rounded));
    await t.tap(find.byIcon(Icons.remove_rounded));
    expect([minus, plus], [1, 2]);
    final btn = find.ancestor(
      of: find.byIcon(Icons.add_rounded),
      matching: find.byType(SizedBox),
    );
    expect(t.getSize(btn.first), const Size(44, 44));
  });
}
