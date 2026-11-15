// Sinh biểu tượng app "Agent" (trạm in) — logo RIÊNG, không dùng logo
// EasyPOS để khách không nhầm với app bán hàng:
//
//   cd apps/desktop && fvm dart run tool/gen_app_icon.dart
//
// Hình: máy in trắng nhả tờ hoá đơn + sóng tín hiệu (nhận lệnh in từ các máy
// khác) trên nền tím → xanh (cùng màu màn đăng nhập). Vẽ bằng code, siêu lấy
// mẫu 4× rồi thu nhỏ cho mép mịn.
//
// Ra:
// - windows/runner/resources/app_icon.ico (16–256).
// - macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png (ô bo góc
//   chừa lề kiểu icon macOS).
// - assets/app/app_icon.png (256, trong app: logo màn đăng nhập + biểu tượng
//   cửa sổ Linux).
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

typedef _Rgb = (int, int, int);

const _Rgb _from = (0x6D, 0x3A, 0xF0);
const _Rgb _to = (0x1F, 0x6F, 0xEB);
const _Rgb _white = (255, 255, 255);
const _Rgb _ink = (0x3B, 0x4F, 0xD8);
const _Rgb _green = (0x22, 0xC5, 0x5E);

/// Một hình: điểm (x, y) trong khung 0–1 có thuộc hình không.
class _Shape {
  const _Shape(this.contains, this.color);

  final bool Function(double x, double y) contains;

  /// `null` = màu nền (khoét lỗ trên hình trắng).
  final _Rgb? color;
}

bool Function(double, double) _roundRect(
  double x1,
  double y1,
  double x2,
  double y2,
  double r,
) => (x, y) {
  if (x < x1 || x > x2 || y < y1 || y > y2) return false;
  final cx = math.min(math.max(x, x1 + r), math.max(x1 + r, x2 - r));
  final cy = math.min(math.max(y, y1 + r), math.max(y1 + r, y2 - r));
  final dx = x - cx, dy = y - cy;
  return dx * dx + dy * dy <= r * r;
};

bool Function(double, double) _circle(double cx, double cy, double r) =>
    (x, y) => (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r;

/// Cung tròn tâm (cx, cy), bán kính [r], dày [w], từ góc [a1] tới [a2] (độ,
/// 0 = sang phải, âm = lên trên), đầu bo tròn.
bool Function(double, double) _arc(
  double cx,
  double cy,
  double r,
  double w,
  double a1,
  double a2,
) {
  final caps = [
    for (final a in [a1, a2])
      _circle(
        cx + r * math.cos(a * math.pi / 180),
        cy + r * math.sin(a * math.pi / 180),
        w / 2,
      ),
  ];
  return (x, y) {
    final d = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
    if ((d - r).abs() <= w / 2) {
      final a = math.atan2(y - cy, x - cx) * 180 / math.pi;
      if (a >= a1 && a <= a2) return true;
    }
    return caps.any((c) => c(x, y));
  };
}

/// Tờ hoá đơn: chữ nhật, mép dưới răng cưa.
bool Function(double, double) _receipt(
  double x1,
  double y1,
  double x2,
  double y2,
) {
  const teeth = 5;
  final tooth = (x2 - x1) / teeth;
  final depth = tooth * 0.55;
  return (x, y) {
    if (x < x1 || x > x2 || y < y1) return false;
    final t = ((x - x1) % tooth) / tooth;
    final edge = y2 - depth * (1 - (2 * t - 1).abs());
    return y <= edge;
  };
}

final List<_Shape> _shapes = [
  // Khay giấy phía sau.
  _Shape(_roundRect(0.29, 0.25, 0.61, 0.40, 0.025), _white),
  // Thân máy in.
  _Shape(_roundRect(0.15, 0.36, 0.75, 0.64, 0.07), _white),
  // Khe ra giấy.
  _Shape(_roundRect(0.25, 0.555, 0.65, 0.595, 0.02), null),
  // Đèn sẵn sàng.
  _Shape(_circle(0.65, 0.445, 0.028), _green),
  // Tờ hoá đơn + các dòng chữ.
  _Shape(_receipt(0.30, 0.575, 0.60, 0.84), _white),
  _Shape(_roundRect(0.35, 0.64, 0.55, 0.665, 0.012), _ink),
  _Shape(_roundRect(0.35, 0.695, 0.50, 0.72, 0.012), _ink),
  _Shape(_roundRect(0.35, 0.75, 0.53, 0.775, 0.012), _ink),
  // Sóng tín hiệu (nhận lệnh in).
  _Shape(_circle(0.80, 0.21, 0.035), _white),
  _Shape(_arc(0.80, 0.21, 0.095, 0.045, -180, -95), _white),
  _Shape(_arc(0.80, 0.21, 0.165, 0.045, -180, -95), _white),
];

/// Ô bo góc cạnh 1 (bán kính 0.225) có chứa điểm (x, y) không.
final _tile = _roundRect(0, 0, 1, 1, 0.225);

_Rgb _background(double x, double y) {
  final t = ((x + y) / 2).clamp(0.0, 1.0);
  int mix(int a, int b) => (a + (b - a) * t).round();
  return (mix(_from.$1, _to.$1), mix(_from.$2, _to.$2), mix(_from.$3, _to.$3));
}

/// Màu tại (x, y) trong khung 0–1; `null` = trong suốt (ngoài ô).
_Rgb? _colorAt(double x, double y) {
  if (!_tile(x, y)) return null;
  _Rgb color = _background(x, y);
  for (final s in _shapes) {
    if (s.contains(x, y)) color = s.color ?? _background(x, y);
  }
  return color;
}

/// Vẽ icon cạnh [size], ô bo góc chiếm [body] phần khung (macOS 824/1024).
img.Image _render(int size, {double body = 1}) {
  const ss = 4;
  final out = img.Image(width: size, height: size, numChannels: 4);
  final pad = (1 - body) / 2;
  for (var py = 0; py < size; py++) {
    for (var px = 0; px < size; px++) {
      var r = 0, g = 0, b = 0, n = 0;
      for (var sy = 0; sy < ss; sy++) {
        for (var sx = 0; sx < ss; sx++) {
          final x = ((px + (sx + 0.5) / ss) / size - pad) / body;
          final y = ((py + (sy + 0.5) / ss) / size - pad) / body;
          final c = _colorAt(x, y);
          if (c == null) continue;
          r += c.$1;
          g += c.$2;
          b += c.$3;
          n++;
        }
      }
      if (n == 0) {
        out.setPixelRgba(px, py, 0, 0, 0, 0);
      } else {
        out.setPixelRgba(
          px,
          py,
          r ~/ n,
          g ~/ n,
          b ~/ n,
          (255 * n / (ss * ss)).round(),
        );
      }
    }
  }
  return out;
}

void main() {
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(
    img.IcoEncoder().encodeImages([
      for (final s in [16, 24, 32, 48, 64, 128, 256]) _render(s),
    ]),
  );

  const mac = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
  for (final s in [16, 32, 64, 128, 256, 512, 1024]) {
    File(
      '$mac/app_icon_$s.png',
    ).writeAsBytesSync(img.encodePng(_render(s, body: 824 / 1024)));
  }

  final dir = Directory('assets/app')..createSync(recursive: true);
  File(
    '${dir.path}/app_icon.png',
  ).writeAsBytesSync(img.encodePng(_render(256)));
  stdout.writeln('Đã ghi icon Windows, macOS và ${dir.path}/app_icon.png');
}
