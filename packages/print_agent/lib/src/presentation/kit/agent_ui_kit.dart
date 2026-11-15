import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/ports/agent_host.dart';
import '../ports/agent_station.dart';

/// Cỡ / đậm chữ — cùng tên với design system của app EasyPOS.
enum AgentTextVariant {
  caption,
  captionStrong,
  body,
  title,
  bodyLarge,
  titleMedium,
  titleLarge,
  headline,
  display,
  displayLarge,
}

/// Màu chữ theo ngữ nghĩa — cùng tên với design system của app EasyPOS.
enum AgentTextTone {
  primary,
  secondary,
  tertiary,
  brand,
  danger,
  warning,
  success,
  inverse,
}

/// Mô tả một dòng chữ để app chủ dựng bằng widget chữ của mình.
class AgentTextSpec {
  const AgentTextSpec({
    required this.text,
    required this.translate,
    required this.variant,
    required this.tone,
    this.textColor,
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.useVariantMaxLines = true,
    this.overflow = TextOverflow.ellipsis,
    this.softWrap,
  });

  final String text;

  /// `true`: [text] là khoá đa ngôn ngữ (dịch trước khi hiện).
  final bool translate;
  final AgentTextVariant variant;
  final AgentTextTone tone;
  final Color? textColor;
  final TextAlign textAlign;
  final int? maxLines;

  /// Không truyền `maxLines`: dùng số dòng mặc định của [variant].
  final bool useVariantMaxLines;
  final TextOverflow overflow;
  final bool? softWrap;
}

/// Cổng giao diện (presentation port): app chủ dựng các thành phần cơ bản bằng
/// design system của mình — màn Máy Agent trên app EasyPOS giữ nguyên giao
/// diện, Agent máy tính dùng bộ thành phần riêng. Module chỉ ghép bố cục.
abstract interface class AgentUiKit {
  /// Đổi khoảng cách thiết kế sang khoảng cách thật (app co giãn theo màn hình).
  EdgeInsets insets(EdgeInsets design);

  /// Khoảng trống dọc cao [size] (co giãn như [insets]).
  Widget gap(double size);

  bool get isTablet;

  /// Lề chuẩn của trang.
  EdgeInsets pageInsets(BuildContext context);

  Widget text(AgentTextSpec spec);

  /// Vùng bấm không hiệu ứng gợn.
  Widget tap({required VoidCallback? onTap, required Widget child});

  /// Thẻ trắng một khối nội dung.
  Widget card({required Widget child});

  Widget divider();

  /// Nút chính; [title] là khoá đa ngôn ngữ.
  Widget button({
    required String title,
    required VoidCallback? onPressed,
    Color? backgroundColor,
    Color? titleColor,
  });

  /// Ô nhập; [label] là khoá đa ngôn ngữ.
  Widget input({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
  });

  /// Công tắc; [leftLabel] là khoá đa ngôn ngữ.
  Widget toggle({
    required bool value,
    required ValueChanged<bool> onChanged,
    String? leftLabel,
    FontWeight? fontWeight,
    MainAxisSize mainAxisSize = MainAxisSize.min,
  });

  Widget selectableCard({
    required bool isSelected,
    required VoidCallback? onTap,
    EdgeInsetsGeometry? padding,
    required Widget child,
  });

  /// Trang có thanh tiêu đề; [title] là khoá đa ngôn ngữ.
  Widget page({required String title, required Widget body});

  /// Hộp xác nhận (dựng để mở bằng `Get.dialog`).
  Widget confirmDialog({
    required String title,
    required String content,
    required String confirmText,
    required FutureOr<void> Function() onConfirm,
  });

  /// Mở bảng trượt; [headerTitle] là khoá đa ngôn ngữ.
  Future<T?> showSheet<T>({required Widget body, String? headerTitle});

  Future<void> notify({
    required String message,
    AgentNoticeLevel type = AgentNoticeLevel.info,
    Widget? trailing,
    Duration? duration,
  });

  void dismissNotification();
}

/// Điểm nối giao diện module với app chủ: gọi [init] một lần lúc khởi động
/// (sau `PrintAgentModule.init`).
abstract final class PrintAgentUi {
  static AgentUiKit? _kit;
  static AgentStation? _station;

  /// "Thêm máy in" của app chủ (nút + trên sơ đồ, bảng trạm in này): máy tính
  /// mở hộp chọn máy in, app bán hàng mở thêm nhanh máy in. `null` = ẩn nút.
  static Future<void> Function()? onAddPrinter;

  /// [station]: điều khiển máy Agent của app chủ (màn Máy Agent cần).
  static void init(
    AgentUiKit kit, {
    AgentStation? station,
    Future<void> Function()? onAddPrinter,
  }) {
    _kit = kit;
    _station = station ?? _station;
    PrintAgentUi.onAddPrinter = onAddPrinter ?? PrintAgentUi.onAddPrinter;
  }

  static AgentStation get station {
    final s = _station;
    if (s == null) {
      throw StateError('Chưa truyền station vào PrintAgentUi.init');
    }
    return s;
  }

  static AgentUiKit get kit {
    final k = _kit;
    if (k == null) {
      throw StateError(
        'Chưa gọi PrintAgentUi.init(kit) trước khi dựng màn Agent',
      );
    }
    return k;
  }
}
