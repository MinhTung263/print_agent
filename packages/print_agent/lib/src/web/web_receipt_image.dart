import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Chuẩn hoá ảnh phiếu trang web gửi (thường chụp từ HTML, nền trong suốt,
/// rộng tuỳ màn hình) cho máy in nhiệt: nền trắng, thu về đúng [dots] điểm
/// một dòng (80mm = 576, 58mm = 384). Ảnh hẹp hơn giữ nguyên.
abstract final class WebReceiptImage {
  /// Chạy ở isolate riêng (ảnh hoá đơn dài làm đứng giao diện).
  static Future<Uint8List> fit(Uint8List bytes, int dots) =>
      Isolate.run(() => fitSync(bytes, dots));

  /// Ném [FormatException] khi không đọc được ảnh.
  static Uint8List fitSync(Uint8List bytes, int dots) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width == 0 || decoded.height == 0) {
      throw const FormatException('Ảnh phiếu không đọc được');
    }
    var image = decoded;
    if (image.width > dots) {
      image = img.copyResize(
        image,
        width: dots,
        interpolation: img.Interpolation.average,
      );
    }
    if (image.hasAlpha) {
      final white = img.Image(width: image.width, height: image.height)
        ..clear(img.ColorRgb8(255, 255, 255));
      image = img.compositeImage(white, image);
    }
    return img.encodePng(image);
  }
}
