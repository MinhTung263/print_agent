import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/ports/agent_host.dart';
import 'agent_ui_kit.dart';
import 'kit_tokens.dart';

/// Bộ giao diện dựng bằng Material thuần, cùng màu / cỡ chữ / khoảng cách với
/// design system EasyPOS — cho app chủ không có sds (Agent máy tính) và cho
/// test. Không co giãn theo màn hình (máy tính dùng chuột, cỡ cố định).
class MaterialAgentUiKit implements AgentUiKit {
  const MaterialAgentUiKit({this.tablet = true});

  /// Màn rộng: bố cục 2 cột (máy tính luôn rộng).
  final bool tablet;

  static const Color _border = Color(0xFFEDEFF2);

  @override
  EdgeInsets insets(EdgeInsets design) => design;

  @override
  Widget gap(double size) => SizedBox(height: size);

  @override
  bool get isTablet => tablet;

  @override
  EdgeInsets pageInsets(BuildContext context) =>
      const EdgeInsets.all(AppSpace.lg);

  static (double, FontWeight, int) _variant(AgentTextVariant v) => switch (v) {
    AgentTextVariant.caption => (12, FontWeight.w400, 5),
    AgentTextVariant.captionStrong => (12, FontWeight.w600, 2),
    AgentTextVariant.body => (14, FontWeight.w400, 5),
    AgentTextVariant.title => (14, FontWeight.w600, 2),
    AgentTextVariant.bodyLarge => (16, FontWeight.w400, 5),
    AgentTextVariant.titleMedium => (16, FontWeight.w600, 2),
    AgentTextVariant.titleLarge => (18, FontWeight.w600, 2),
    AgentTextVariant.headline => (18, FontWeight.w700, 2),
    AgentTextVariant.display => (24, FontWeight.w600, 2),
    AgentTextVariant.displayLarge => (32, FontWeight.w600, 2),
  };

  static Color _tone(AgentTextTone t) => switch (t) {
    AgentTextTone.primary => AppColors.textPrimary,
    AgentTextTone.secondary => AppColors.dsGray2,
    AgentTextTone.tertiary => AppColors.dsGray5,
    AgentTextTone.brand => AppColors.primaryBlueBase,
    AgentTextTone.danger => AppColors.errorRed,
    AgentTextTone.warning => AppColors.orange,
    AgentTextTone.success => AppColors.successGreen,
    AgentTextTone.inverse => Colors.white,
  };

  @override
  Widget text(AgentTextSpec spec) {
    final (size, weight, lines) = _variant(spec.variant);
    final maxLines = spec.useVariantMaxLines ? lines : spec.maxLines;
    return Text(
      spec.translate && spec.text.isNotEmpty ? spec.text.tr : spec.text,
      textAlign: spec.textAlign,
      maxLines: maxLines,
      softWrap: spec.softWrap,
      overflow: maxLines == null ? TextOverflow.clip : spec.overflow,
      style: TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: 1.33,
        color: spec.textColor ?? _tone(spec.tone),
      ),
    );
  }

  @override
  Widget tap({required VoidCallback? onTap, required Widget child}) =>
      MouseRegion(
        cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: child,
        ),
      );

  @override
  Widget card({required Widget child}) => Container(
    padding: const EdgeInsets.all(AppSpace.md),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: child,
  );

  @override
  Widget divider() => const Divider(height: 1, thickness: 1, color: _border);

  @override
  Widget button({
    required String title,
    required VoidCallback? onPressed,
    Color? backgroundColor,
    Color? titleColor,
  }) => SizedBox(
    height: 44,
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor ?? AppColors.primaryBlueBase,
        foregroundColor: titleColor ?? Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        title.tr,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );

  @override
  Widget input({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Nhãn phía trên ô (như ô nhập của app EasyPOS), không nhãn nổi.
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          label.tr,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: 13,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.dsGray4),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: AppColors.primaryBlueBase,
              width: 1.4,
            ),
          ),
        ),
      ),
    ],
  );

  @override
  Widget toggle({
    required bool value,
    required ValueChanged<bool> onChanged,
    String? leftLabel,
    FontWeight? fontWeight,
    MainAxisSize mainAxisSize = MainAxisSize.min,
  }) => Row(
    mainAxisSize: mainAxisSize,
    children: [
      if (leftLabel != null)
        Expanded(
          flex: mainAxisSize == MainAxisSize.max ? 1 : 0,
          child: Text(
            leftLabel.tr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: fontWeight ?? FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primaryBlueBase,
      ),
    ],
  );

  @override
  Widget selectableCard({
    required bool isSelected,
    required VoidCallback? onTap,
    EdgeInsetsGeometry? padding,
    required Widget child,
  }) => tap(
    onTap: onTap,
    child: Container(
      padding: padding ?? const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.dsPrimaryBlue4 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppColors.primaryBlueBase : _border,
        ),
      ),
      child: child,
    ),
  );

  @override
  Widget page({required String title, required Widget body}) => Scaffold(
    backgroundColor: AppColors.backgroundPrimary,
    appBar: AppBar(
      title: Text(title.tr),
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
    ),
    body: body,
  );

  @override
  Widget confirmDialog({
    required String title,
    required String content,
    required String confirmText,
    required FutureOr<void> Function() onConfirm,
  }) => AlertDialog(
    title: Text(title),
    content: Text(content),
    actions: [
      Builder(
        builder: (context) => TextButton(
          onPressed: Get.back<void>,
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ),
      FilledButton(
        onPressed: () => unawaited(Future.sync(onConfirm)),
        child: Text(confirmText),
      ),
    ],
  );

  @override
  Future<T?> showSheet<T>({required Widget body, String? headerTitle}) =>
      Get.dialog<T>(
        Dialog(
          clipBehavior: Clip.antiAlias,
          backgroundColor: AppColors.backgroundPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (headerTitle != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg + 4,
                      AppSpace.md,
                      AppSpace.sm,
                      0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            headerTitle.tr,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: Get.back<void>,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                Flexible(child: SingleChildScrollView(child: body)),
              ],
            ),
          ),
        ),
      );

  @override
  Future<void> notify({
    required String message,
    AgentNoticeLevel type = AgentNoticeLevel.info,
    Widget? trailing,
    Duration? duration,
  }) async {
    final context = Get.context;
    if (context == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        duration: duration ?? const Duration(seconds: 3),
        backgroundColor: switch (type) {
          AgentNoticeLevel.success => AppColors.successGreen,
          AgentNoticeLevel.warning => AppColors.orange,
          AgentNoticeLevel.error => AppColors.errorRed,
          AgentNoticeLevel.info => AppColors.dsGray2,
        },
        content: Row(
          children: [
            Expanded(child: Text(message.tr)),
            ?trailing,
          ],
        ),
      ),
    );
  }

  @override
  void dismissNotification() {
    final context = Get.context;
    if (context == null) return;
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  }
}
