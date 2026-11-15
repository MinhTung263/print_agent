// Sinh biểu tượng app "Trạm in EasyPOS" từ logo EasyPOS:
//
//   cd apps/desktop && fvm dart run tool/gen_app_icon.dart
//
// Nguồn: assets/branding/easypos_icon_1024.png (icon app EasyPOS, nền trắng).
// Ra:
// - windows/runner/resources/app_icon.ico (16–256).
// - macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png (ô vuông bo
//   góc, chừa lề theo kiểu icon macOS).
// - assets/app/app_icon.png (256, kèm trong app: logo màn đăng nhập + biểu
//   tượng cửa sổ Linux).
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _source = 'assets/branding/easypos_icon_1024.png';

img.Image _resize(img.Image src, int size) => img.copyResize(
  src,
  width: size,
  height: size,
  interpolation: img.Interpolation.average,
);

/// Kiểu macOS: ô bo góc chiếm ~80% khung, phần còn lại trong suốt.
img.Image _macTile(img.Image src, int size) {
  final body = (size * 824 / 1024).round();
  final offset = (size - body) ~/ 2;
  final radius = body * 0.225;
  final logo = _resize(src, body);
  final out = img.Image(width: size, height: size, numChannels: 4)
    ..clear(img.ColorRgba8(0, 0, 0, 0));
  for (var y = 0; y < body; y++) {
    for (var x = 0; x < body; x++) {
      final a = _roundedAlpha(x + 0.5, y + 0.5, body.toDouble(), radius);
      if (a <= 0) continue;
      final p = logo.getPixel(x, y);
      out.setPixelRgba(
        x + offset,
        y + offset,
        p.r,
        p.g,
        p.b,
        (a * 255).round(),
      );
    }
  }
  return out;
}

/// Độ phủ (0–1) của điểm (x, y) trong ô vuông cạnh [side] bo góc [r] — mép
/// làm mịn 1px.
double _roundedAlpha(double x, double y, double side, double r) {
  final cx = x < r ? r : (x > side - r ? side - r : x);
  final cy = y < r ? r : (y > side - r ? side - r : y);
  final dx = x - cx;
  final dy = y - cy;
  final d = math.sqrt(dx * dx + dy * dy);
  if (d == 0) return 1;
  final dist = r - d;
  return dist >= 0.5 ? 1 : (dist <= -0.5 ? 0 : dist + 0.5);
}

void main() {
  final src = img.decodePng(File(_source).readAsBytesSync());
  if (src == null) {
    stderr.writeln('Không đọc được $_source');
    exit(1);
  }

  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(
    img.IcoEncoder().encodeImages([
      for (final s in [16, 24, 32, 48, 64, 128, 256]) _resize(src, s),
    ]),
  );

  const mac = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
  for (final s in [16, 32, 64, 128, 256, 512, 1024]) {
    File(
      '$mac/app_icon_$s.png',
    ).writeAsBytesSync(img.encodePng(_macTile(src, s)));
  }

  final dir = Directory('assets/app')..createSync(recursive: true);
  File(
    '${dir.path}/app_icon.png',
  ).writeAsBytesSync(img.encodePng(_resize(src, 256)));
  stdout.writeln('Đã ghi icon Windows, macOS và ${dir.path}/app_icon.png');
}
