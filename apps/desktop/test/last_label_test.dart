import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/agent/agent_store.dart';
import 'package:print_agent_desktop/agent/label_preset.dart';
import 'package:print_agent_desktop/agent/last_label.dart';
import 'package:printer_label/desktop.dart' show TsplLabelSpec;

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('last_label_');
    AgentStore.debugDirectory = dir;
  });
  tearDown(() {
    AgentStore.debugDirectory = null;
    dir.deleteSync(recursive: true);
  });

  test('chưa in lần nào → khổ mặc định 2 tem 35×22', () {
    final p = LastLabel.of('10.0.0.9');
    expect(p.count, 2);
    expect(p.spec.widthMm, 72);
    expect(p.temWidthMm, 35);
  });

  test('nhớ khổ vừa in theo từng máy, khớp khổ có sẵn', () {
    LastLabel.remember(
      '10.0.0.9',
      const TsplLabelSpec(widthMm: 85, heightMm: 25, gapMm: 3),
      2,
    );
    final p = LastLabel.of('10.0.0.9');
    expect(p.count, 2);
    expect(p.temWidthMm, 40); // khổ 2 tem 40×25
    expect(
      LastLabel.of('10.0.0.10').spec.widthMm,
      72,
    ); // máy khác không bị ảnh hưởng
  });

  test('khổ lạ: dựng khổ riêng, bề rộng một tem = cả hàng chia đều', () {
    LastLabel.remember(
      '10.0.0.9',
      const TsplLabelSpec(widthMm: 90, heightMm: 30, gapMm: 2),
      3,
    );
    final p = LastLabel.of('10.0.0.9');
    expect(p.count, 3);
    expect(p.spec.widthMm, 90);
    expect(p.temWidthMm, 30);
  });

  test('forSize khớp khổ có sẵn', () {
    final p = LabelPreset.forSize(widthMm: 72, heightMm: 22, count: 2);
    expect(identical(p, LabelPreset.defaultPreset), isTrue);
  });
}
