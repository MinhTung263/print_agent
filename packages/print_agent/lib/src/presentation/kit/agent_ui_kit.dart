import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/domain/entities/agent_printer_ref.dart';

import '../../domain/ports/agent_host.dart';
import '../../domain/ports/agent_print_routing_store.dart';
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
  /// Vòng chờ (loading) cỡ [size]; [color] `null` = màu mặc định của giao diện.
  Widget spinner({double size = 18, Color? color});

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

  /// "Xoá máy in" của máy này (nút trong chi tiết máy in trên sơ đồ): app chủ xoá máy
  /// in [printer] khỏi trạm in này; `true` = đã xoá. `null` = ẩn nút.
  static Future<bool> Function(AgentPrinterRef printer)? onRemovePrinter;

  /// Cài đặt riêng của một máy in của máy này (loại, khổ giấy, căn chỉnh tem...): app chủ
  /// dựng phần giao diện, module nhúng vào chi tiết máy in trên sơ đồ. `null` hoặc trả
  /// `null` = máy in này không có cài đặt riêng.
  static Widget? Function(AgentPrinterRef printer)? printerSettings;

  /// Thiết bị này in được qua USB không? `false` (iPhone / iPad) = máy in USB hiện cảnh báo
  /// "không hỗ trợ" thay vì chờ kết nối mãi.
  static bool usbSupported = true;

  /// Nhãn nguồn của máy in [printer] hiện trên sơ đồ (VD "Từ EasyPOS" cho máy đồng bộ từ cửa
  /// hàng); `null` = không có nhãn.
  static String? Function(AgentPrinterRef printer)? printerBadge;

  /// Tên máy in trong danh sách máy in của cửa hàng ứng với [printer] (để chọn chức năng): app
  /// chủ tự khớp (VD Agent máy tính khớp theo địa chỉ IP). Trả `null` = máy này chưa có trong
  /// cửa hàng. Không đặt hook = dùng tên máy in như hiện có (app EasyPOS).
  static String? Function(AgentPrinterRef printer)? printerRoutingName;

  /// Máy in [printer] là máy in TEM (nhận ra qua loại máy)? `true` = máy tem: chỉ cho chọn chức
  /// năng "Tem nhãn"; `null` / không có = chưa rõ (cho chọn mọi chức năng).
  static bool? Function(AgentPrinterRef printer)? printerIsLabel;

  /// App chủ tự lo nút in thử của máy in [printer] (trong phần cài đặt riêng): chi tiết
  /// không hiện thêm nút "In thử" chung — tránh nhiều nút in thử cho cùng một máy.
  static bool Function(AgentPrinterRef printer)? hasOwnTestPrint;

  /// Nút hành động riêng của app chủ cho máy in [printer], đặt CÙNG HÀNG với "Xoá máy in" ở chân
  /// chi tiết máy in (VD "In thử"). `null` hoặc trả `null` = không có.
  static Widget? Function(AgentPrinterRef printer)? printerFooterAction;

  /// Cấu hình in theo chức năng của tài khoản (Tool in ver 3): app chủ cài đặt qua API tài
  /// khoản. `null` = ẩn thẻ "In theo chức năng".
  static AgentPrintRoutingStore? printRouting;

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
