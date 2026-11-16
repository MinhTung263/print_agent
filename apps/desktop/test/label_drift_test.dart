import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/agent/label_drift.dart';

void main() {
  test('tem cuối lệch xuống 3mm sau 4 hàng → mỗi hàng 1mm → giảm khe 1mm', () {
    expect(LabelDrift.newGap(currentGapMm: 3, driftMm: 3), closeTo(2, 1e-9));
  });

  test('lệch lên → tăng khe', () {
    expect(
      LabelDrift.newGap(currentGapMm: 2, driftMm: -1.5),
      closeTo(2.5, 1e-9),
    );
  });

  test('làm tròn theo 0,25mm và không ra ngoài 0–10mm', () {
    // 2 - 1/3 = 1.667 → 1.75
    expect(LabelDrift.newGap(currentGapMm: 2, driftMm: 1), closeTo(1.75, 1e-9));
    expect(LabelDrift.newGap(currentGapMm: 1, driftMm: 9), 0);
    expect(LabelDrift.newGap(currentGapMm: 9.5, driftMm: -9), 10);
  });

  test('không lệch → giữ nguyên khe', () {
    expect(LabelDrift.newGap(currentGapMm: 2.5, driftMm: 0), 2.5);
  });
}
