import 'package:flutter/material.dart';

/// Lớp tương thích nhỏ với design system của app EasyPOS (sds_core /
/// sds_shared_dep) — cùng tên + tham số + giá trị, để dùng lại nguyên code giao
/// diện màn Máy Agent của app (sơ đồ mạng...) mà không kéo cả thư viện nội bộ.
abstract final class AppColors {
  static const Color primaryBlueBase = Color(0xFF0074BD);
  static const Color successGreen = Color(0xff09b409);
  static const Color errorRed = Color(0xFFDF0000);
  static const Color orange = Color(0xFFe2530c);
  static const Color dsGray2 = Color(0xFF58647A);
  static const Color dsGray4 = Color(0xFFD5D8DD);
  static const Color dsGray5 = Color(0xFF8A8A8A);
  static const Color purpleAccent = Color(0xFF8443F7);
  static const Color backgroundPrimary = Color(0xFFF4F6F8);
  static const Color textPrimary = Color(0xFF111111);
  static const Color white = Colors.white;
}

abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

abstract final class ShareDimens {
  static const double itemSpacing = 12;
}

const Widget sdsSizedBox4 = SizedBox(height: 4, width: 4);

enum AppTextVariant {
  caption(12, FontWeight.w400),
  captionStrong(12, FontWeight.w600),
  body(14, FontWeight.w400),
  title(14, FontWeight.w600),
  titleMedium(16, FontWeight.w600),
  titleLarge(18, FontWeight.w600);

  const AppTextVariant(this.size, this.weight);
  final double size;
  final FontWeight weight;
}

enum AppTextTone {
  primary(AppColors.textPrimary),
  secondary(AppColors.dsGray2),
  brand(AppColors.primaryBlueBase),
  danger(AppColors.errorRed),
  success(AppColors.successGreen);

  const AppTextTone(this.color);
  final Color color;
}

/// Chữ theo kiểu của app: [variant] (cỡ + đậm), [tone] / [textColor].
class AppText extends StatelessWidget {
  const AppText(
    this.text, {
    super.key,
    this.variant = AppTextVariant.body,
    this.tone = AppTextTone.primary,
    this.textColor,
    this.maxLines,
    this.textAlign,
  });

  const AppText.raw(
    this.text, {
    super.key,
    this.variant = AppTextVariant.body,
    this.tone = AppTextTone.primary,
    this.textColor,
    this.maxLines,
    this.textAlign,
  });

  final String text;
  final AppTextVariant variant;
  final AppTextTone tone;
  final Color? textColor;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      textAlign: textAlign,
      style: TextStyle(
        fontSize: variant.size,
        fontWeight: variant.weight,
        height: 1.33,
        color: textColor ?? tone.color,
      ),
    );
  }
}

class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    required this.children,
    this.spacing = 0,
    this.mainAxisSize = MainAxisSize.max,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final List<Widget> children;
  final double spacing;
  final MainAxisSize mainAxisSize;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => Row(
    spacing: spacing,
    mainAxisSize: mainAxisSize,
    mainAxisAlignment: mainAxisAlignment,
    crossAxisAlignment: crossAxisAlignment,
    children: children,
  );
}

class AppColumn extends StatelessWidget {
  const AppColumn({
    super.key,
    required this.children,
    this.spacing = 0,
    this.mainAxisSize = MainAxisSize.max,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final List<Widget> children;
  final double spacing;
  final MainAxisSize mainAxisSize;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => Column(
    spacing: spacing,
    mainAxisSize: mainAxisSize,
    mainAxisAlignment: mainAxisAlignment,
    crossAxisAlignment: crossAxisAlignment,
    children: children,
  );
}

/// Vùng bấm không hiệu ứng gợn (giống BaseTap của app) + con trỏ tay trên web.
class BaseTap extends StatelessWidget {
  const BaseTap({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    ),
  );
}

/// Thẻ trắng bo góc 8, padding chuẩn (giống `BaseCard.section`).
class BaseCard extends StatelessWidget {
  const BaseCard.section({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
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
}

class AppDivider extends StatelessWidget {
  const AppDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: Color(0xFFEDEFF2));
}
