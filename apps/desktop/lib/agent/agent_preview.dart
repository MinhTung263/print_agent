import 'agent_job.dart';

/// Dữ liệu mẫu cho chế độ xem trước giao diện (`--preview`) và test bố cục.
abstract final class AgentPreview {
  static List<AgentJobEntry> log() {
    final now = DateTime.now();
    return [
      AgentJobEntry(at: now, ok: true, sender: 'Redmi Note 13 Pro 5G'),
      AgentJobEntry(
        at: now.subtract(const Duration(minutes: 3)),
        ok: true,
        sender: 'Quầy 2',
        copies: 2,
      ),
      AgentJobEntry(
        at: now.subtract(const Duration(minutes: 9)),
        ok: false,
        sender: 'Quầy 2',
        error: 'Máy in hết giấy',
      ),
    ];
  }

  /// [peerCount] máy Agent khác, mỗi máy [printerCount] máy in.
  static List<Map<Object?, Object?>> peers(int peerCount, int printerCount) => [
    for (var a = 0; a < peerCount; a++)
      {
        'id':
            'e87c2c846a31${(6775 + a * 1111).toRadixString(16).padLeft(4, '0')}',
        'name': a == 0 ? 'Sunmi T1-G' : 'Quầy ${a + 1}',
        'model': a == 0 ? 'Sunmi T1-G' : 'Xiaomi Pad 6',
        'builtIn': a == 0 ? {'paper': 'size80', 'ready': true} : null,
        'printers': {
          'ok': printerCount - (printerCount ~/ 4),
          'total': printerCount,
          'names': [
            for (var i = 0; i < printerCount; i++)
              {
                'name': i == 0 && a == 0
                    ? 'Máy in tích hợp'
                    : 'Máy in ${i + 1}',
                'ok': i % 4 != 3,
                'kind': i == 0 && a == 0
                    ? 'builtin'
                    : (i % 5 == 4 ? 'usb' : 'lan'),
                if (!(i == 0 && a == 0) && i % 5 != 4)
                  'addr': '192.168.1.${100 + i}',
                if (i == 6) 'on': false,
              },
          ],
        },
      }..removeWhere((_, v) => v == null),
  ];
}
