// Máy in nhiệt GIẢ (ESC/POS qua TCP) để thử Agent mà không cần máy in thật:
//
//   cd apps/desktop && fvm dart run tool/fake_printer.dart [--port 9100] \
//       [--out <thư mục>] [--paper-out] [--cover-open] [--delay <ms>]
//       [--start-after <ms>]   (từ chối kết nối trong khoảng đầu)
//
// - Nghe cổng 9100 như máy in LAN: Agent máy tính (hoặc app EasyPOS trên điện
//   thoại — thêm máy in LAN với IP của máy chạy công cụ này) in vào đây.
// - Mỗi phiếu (tới lệnh cắt giấy) lưu thành PNG trong --out, in ra màn hình
//   số bản, mở két, còi báo bếp, chữ thô (phiếu in thử).
// - Trả lời hỏi trạng thái `DLE EOT 4/2` như máy thật — giả lập HẾT GIẤY / MỞ
//   NẮP để thử Agent giữ phiếu rồi tự in khi "thay giấy".
// - Gõ lệnh rồi Enter trong lúc chạy:
//     p  bật / tắt hết giấy      c  bật / tắt mở nắp
//     b  bật / tắt bận (từ chối kết nối, như máy đang phục vụ máy khác)
//     d <ms>  chậm khi nhận dữ liệu      s  xem trạng thái      q  thoát
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

bool paperOut = false;
bool coverOpen = false;
bool busy = false;
int delayMs = 0;
late int port;
ServerSocket? server;
int ticketNo = 0;
late Directory outDir;

Future<void> main(List<String> args) async {
  String? arg(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  port = int.tryParse(arg('--port') ?? '') ?? 9100;
  outDir = Directory(
    arg('--out') ?? '${Directory.systemTemp.path}/fake_printer',
  )..createSync(recursive: true);
  paperOut = args.contains('--paper-out');
  coverOpen = args.contains('--cover-open');
  delayMs = int.tryParse(arg('--delay') ?? '') ?? 0;
  final startAfter = int.tryParse(arg('--start-after') ?? '') ?? 0;

  final ips = [
    for (final n in await NetworkInterface.list(type: InternetAddressType.IPv4))
      for (final a in n.addresses)
        if (!a.isLoopback) a.address,
  ];
  if (startAfter > 0) {
    // Cổng chưa mở: kết nối bị TỪ CHỐI như máy in đang phục vụ máy khác.
    busy = true;
    _log('⛔ Từ chối kết nối trong ${startAfter}ms đầu (máy in bận)');
    Timer(Duration(milliseconds: startAfter), () async {
      busy = false;
      await _listen();
      _log('Máy in hết bận — nhận kết nối');
    });
  } else {
    await _listen();
  }

  // Dòng này báo đã sẵn sàng (test chờ dòng này) — cổng đã mở (hoặc đang
  // cố tình từ chối với --start-after).
  _log('Máy in giả nghe cổng $port — IP: ${ips.join(', ')}');
  _log('Phiếu lưu ở: ${outDir.path}');
  _printState();
  _log('Lệnh: p (hết giấy) · c (mở nắp) · b (bận) · d <ms> · s · q');

  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final cmd = line.trim().split(RegExp(r'\s+'));
    switch (cmd.first) {
      case 'p':
        paperOut = !paperOut;
      case 'c':
        coverOpen = !coverOpen;
      case 'b':
        busy = !busy;
        // Máy in thật đang bận TỪ CHỐI kết nối (ECONNREFUSED): đóng cổng nghe.
        if (busy) {
          await server?.close();
          server = null;
        } else {
          await _listen();
        }
      case 'd':
        delayMs = cmd.length > 1 ? int.tryParse(cmd[1]) ?? 0 : 0;
      case 'q':
        await server?.close();
        exit(0);
    }
    _printState();
  }
}

Future<void> _listen() async {
  if (server != null) return;
  final s = server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
  s.listen(_Session.new);
}

void _printState() => _log(
  'Trạng thái: ${paperOut ? 'HẾT GIẤY' : 'có giấy'} · '
  '${coverOpen ? 'MỞ NẮP' : 'nắp đóng'} · ${busy ? 'BẬN' : 'rảnh'}'
  '${delayMs > 0 ? ' · chậm ${delayMs}ms' : ''}',
);

void _log(String message) {
  final t = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  stdout.writeln('${two(t.hour)}:${two(t.minute)}:${two(t.second)}  $message');
}

/// Một kết nối: đọc luồng byte ESC/POS (có thể bị chia nhiều gói) và xử lý.
class _Session {
  _Session(this.socket) {
    from = socket.remoteAddress.address;
    socket.listen(_onData, onDone: _onDone, onError: (Object _) => _onDone());
  }

  final Socket socket;
  late final String from;
  final List<int> _buf = [];
  int _received = 0;

  // Phiếu đang dựng.
  int _width = 0;
  final List<Uint8List> _rows = [];
  final StringBuffer _text = StringBuffer();
  bool _dataWhileBlocked = false;

  Future<void> _onData(Uint8List data) async {
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    _buf.addAll(data);
    _received += data.length;
    _parse();
  }

  void _onDone() {
    if (_rows.isNotEmpty || _text.isNotEmpty) _finishTicket(cut: false);
    if (_received > 0 && _received <= 6) {
      _log('… $from chỉ hỏi trạng thái / dò cổng');
    }
  }

  void _reply(int b) {
    try {
      socket.add([b]);
    } catch (_) {}
  }

  void _parse() {
    var i = 0;
    bool need(int n) => i + n <= _buf.length;
    while (i < _buf.length) {
      final b = _buf[i];
      // DLE EOT n — hỏi trạng thái thời gian thực.
      if (b == 0x10) {
        if (!need(3)) break;
        if (_buf[i + 1] == 0x04) {
          final n = _buf[i + 2];
          _reply(switch (n) {
            4 => paperOut ? 0x72 : 0x12,
            2 => (coverOpen ? 0x16 : 0x12) | (paperOut ? 0x20 : 0),
            _ => 0x12,
          });
        }
        i += 3;
        continue;
      }
      if (b == 0x1B) {
        if (!need(2)) break;
        final c = _buf[i + 1];
        if (c == 0x40) {
          // ESC @ — đầu phiếu.
          i += 2;
        } else if (c == 0x70) {
          if (!need(5)) break;
          _log('💰 $from: MỞ KÉT');
          i += 5;
        } else if (c == 0x42) {
          if (!need(4)) break;
          _log('🔔 $from: CÒI BÁO BẾP');
          i += 4;
        } else {
          // ESC x n (căn lề, cỡ chữ, đậm...): bỏ qua 1 tham số.
          if (!need(3)) break;
          i += 3;
        }
        continue;
      }
      if (b == 0x1D) {
        if (!need(2)) break;
        final c = _buf[i + 1];
        if (c == 0x76) {
          // GS v 0 m xL xH yL yH d...
          if (!need(8)) break;
          final w = _buf[i + 4] | (_buf[i + 5] << 8);
          final h = _buf[i + 6] | (_buf[i + 7] << 8);
          if (!need(8 + w * h)) break;
          _checkBlocked();
          if (_width != 0 && _width != w) _finishTicket(cut: false);
          _width = w;
          for (var y = 0; y < h; y++) {
            final start = i + 8 + y * w;
            _rows.add(Uint8List.fromList(_buf.sublist(start, start + w)));
          }
          i += 8 + w * h;
        } else if (c == 0x56) {
          // GS V m [n] — cắt giấy: hết một bản.
          if (!need(3)) break;
          final m = _buf[i + 2];
          final withN = m == 0x41 || m == 0x42;
          if (withN && !need(4)) break;
          i += withN ? 4 : 3;
          _finishTicket(cut: true);
        } else {
          if (!need(3)) break;
          i += 3;
        }
        continue;
      }
      if (b == 0x0A) {
        _text.writeln();
      } else if (b >= 0x20 && b < 0x7F) {
        _checkBlocked();
        _text.writeCharCode(b);
      }
      i++;
    }
    _buf.removeRange(0, i);
  }

  /// Máy thật hết giấy / mở nắp vẫn nhận dữ liệu vào bộ nhớ rồi in khi thay
  /// giấy — phiếu ra trễ, dễ in đúp. Agent đúng phải hỏi trạng thái và KHÔNG
  /// gửi; gửi thì cảnh báo.
  void _checkBlocked() {
    if ((paperOut || coverOpen) && !_dataWhileBlocked) {
      _dataWhileBlocked = true;
      _log(
        '⚠️  $from GỬI DỮ LIỆU khi máy in đang '
        '${paperOut ? 'hết giấy' : 'mở nắp'} — Agent lẽ ra phải giữ phiếu',
      );
    }
  }

  void _finishTicket({required bool cut}) {
    final parts = <String>[];
    if (_rows.isNotEmpty) {
      ticketNo++;
      final file = File(
        '${outDir.path}/ticket_${ticketNo.toString().padLeft(3, '0')}.png',
      );
      file.writeAsBytesSync(_png(_width * 8, _rows));
      parts.add('ảnh ${_width * 8}×${_rows.length}px → ${file.path}');
    }
    final text = _text.toString().trim();
    if (text.isNotEmpty) parts.add('chữ: ${text.replaceAll('\n', ' | ')}');
    if (!cut) parts.add('(không có lệnh cắt giấy)');
    if (parts.isNotEmpty) _log('🧾 Phiếu từ $from: ${parts.join(' · ')}');
    _rows.clear();
    _text.clear();
    _width = 0;
  }
}

/// PNG đen trắng 1-bit từ các dòng raster ESC/POS (bit 1 = điểm đen).
Uint8List _png(int width, List<Uint8List> rows) {
  final rowBytes = (width + 7) >> 3;
  final raw = BytesBuilder();
  for (final row in rows) {
    raw.addByte(0); // bộ lọc: không
    for (var x = 0; x < rowBytes; x++) {
      // PNG xám 1-bit: 0 = đen → đảo bit.
      raw.addByte(x < row.length ? (~row[x]) & 0xFF : 0xFF);
    }
  }
  final out = BytesBuilder()
    ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final typeBytes = ascii.encode(type);
    out
      ..add(_u32(data.length))
      ..add(typeBytes)
      ..add(data)
      ..add(_u32(_crc32([...typeBytes, ...data])));
  }

  chunk('IHDR', [
    ..._u32(width),
    ..._u32(rows.length),
    1, // độ sâu bit
    0, // xám
    0,
    0,
    0,
  ]);
  chunk('IDAT', ZLibCodec().encode(raw.takeBytes()));
  chunk('IEND', const []);
  return out.takeBytes();
}

List<int> _u32(int v) => [
  (v >> 24) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 8) & 0xFF,
  v & 0xFF,
];

final List<int> _crcTable = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> data) {
  var c = 0xFFFFFFFF;
  for (final b in data) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}
