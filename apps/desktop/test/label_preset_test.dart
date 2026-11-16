import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/agent/label_preset.dart';

void main() {
  test(
    'khổ mặc định: 2 tem/hàng, mỗi tem 35×22mm (cả hàng 72×22, khe 1mm)',
    () {
      final s = LabelPreset.defaultPreset.spec;
      expect([s.widthMm, s.heightMm, s.gapMm, s.home], [72, 22, 1, false]);
    },
  );

  test(
    'có các khổ phổ biến app chưa có tên: 40×25 (khe 3mm), 50×40, 100×50, 4 tem 25×15',
    () {
      final titles = LabelPreset.all.map((p) => p.title).join('\n');
      for (final t in ['40×25', '50×40', '100×50', '25×15']) {
        expect(titles, contains(t));
      }
      final p4025 = LabelPreset.extra.firstWhere(
        (p) => p.title.contains('40×25'),
      );
      expect(
        [p4025.spec.widthMm, p4025.spec.heightMm, p4025.spec.gapMm],
        [85, 25, 3],
      );
    },
  );

  test('mọi khổ có kích thước hợp lệ và tên không trùng', () {
    for (final p in LabelPreset.all) {
      expect(p.spec.widthMm, greaterThan(0), reason: p.title);
      expect(p.spec.heightMm, greaterThan(0), reason: p.title);
    }
    final titles = LabelPreset.all.map((p) => p.title).toList();
    expect(titles.toSet().length, titles.length);
  });
}
