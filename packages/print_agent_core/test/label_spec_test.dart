import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_core/print_agent_core.dart';

Map<String, Object?> _job(Object? spec) => {
  'kind': 'label',
  'printerIp': '10.0.0.9',
  'printerType': 'lan',
  'labelSize': 'double',
  'images': ['AAAA'],
  'labelSpec': ?spec,
};

void main() {
  test('lệnh tem mang kích thước thật: đọc và gửi lại đúng', () {
    final job = PrintRelayJob.fromMap('j1', {
      ..._job({'w': 105, 'h': 40, 'gap': 1, 'count': 2, 'shiftX': 0}),
    })!;
    final spec = job.labelSpec!;
    expect(
      [spec.widthMm, spec.heightMm, spec.gapMm, spec.count],
      [105, 40, 1, 2],
    );
    expect(spec.shiftXDots, 0);
    expect(job.toMap()['labelSpec'], {
      'w': 105,
      'h': 40,
      'gap': 1,
      'count': 2,
      'shiftX': 0,
    });
    // Giữ nguyên khi đổi máy in đích (withPrinter / withOnHeld).
    expect(job.withOnHeld(() {}).labelSpec?.widthMm, 105);
  });

  test('app bản cũ không gửi labelSpec: null, toMap không có trường này', () {
    final job = PrintRelayJob.fromMap('j1', _job(null))!;
    expect(job.labelSpec, isNull);
    expect(job.toMap().containsKey('labelSpec'), isFalse);
  });

  test('kích thước vô lý bị bỏ; khe / số tem sai thì dùng mặc định', () {
    for (final bad in [
      {'w': 0, 'h': 30},
      {'w': 50},
      {'w': 5000, 'h': 30},
      'rác',
    ]) {
      expect(PrintRelayLabelSpec.fromMap(bad), isNull, reason: '$bad');
    }
    final s = PrintRelayLabelSpec.fromMap({
      'w': 50,
      'h': 30,
      'gap': -3,
      'count': 99,
    })!;
    expect([s.gapMm, s.count], [2, 1]);
  });
}
