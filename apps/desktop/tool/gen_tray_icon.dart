// Sinh biểu tượng khay hệ thống: `fvm dart run tool/gen_tray_icon.dart`.
// Ra assets/tray/tray_icon.png (Linux / macOS) và tray_icon.ico (Windows).
import 'dart:io';

import 'package:image/image.dart' as img;

img.Image _draw(int size) {
  final s = size / 64;
  final icon = img.Image(width: size, height: size, numChannels: 4)
    ..clear(img.ColorRgba8(0, 0, 0, 0));
  final blue = img.ColorRgba8(0x1E, 0x6F, 0xF1, 255);
  final white = img.ColorRgba8(255, 255, 255, 255);
  int v(num x) => (x * s).round();
  img.fillCircle(
    icon,
    x: v(32),
    y: v(32),
    radius: v(31),
    color: blue,
    antialias: true,
  );
  // Máy in: thân + khay giấy + tờ hoá đơn.
  img.fillRect(icon, x1: v(20), y1: v(14), x2: v(44), y2: v(26), color: white);
  img.fillRect(
    icon,
    x1: v(13),
    y1: v(26),
    x2: v(51),
    y2: v(42),
    color: white,
    radius: v(4),
  );
  img.fillRect(icon, x1: v(20), y1: v(36), x2: v(44), y2: v(52), color: white);
  img.fillRect(icon, x1: v(24), y1: v(41), x2: v(40), y2: v(43), color: blue);
  img.fillRect(icon, x1: v(24), y1: v(46), x2: v(36), y2: v(48), color: blue);
  return icon;
}

void main() {
  final dir = Directory('assets/tray')..createSync(recursive: true);
  File('${dir.path}/tray_icon.png').writeAsBytesSync(img.encodePng(_draw(64)));
  File('${dir.path}/tray_icon.ico').writeAsBytesSync(
    img.IcoEncoder().encodeImages([
      _draw(16),
      _draw(32),
      _draw(48),
      _draw(256),
    ]),
  );
  stdout.writeln('Đã ghi ${dir.path}/tray_icon.png, tray_icon.ico');
}
