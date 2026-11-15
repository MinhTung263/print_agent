import 'package:flutter/material.dart';

import '../../domain/ports/agent_host.dart';
import 'agent_ui_kit.dart';

// Tên giống design system EasyPOS cho code màn Agent (chỉ dùng trong module).
typedef AppTextVariant = AgentTextVariant;
typedef AppTextTone = AgentTextTone;
typedef AppNotificationType = AgentNoticeLevel;

/// Màu — cùng giá trị design system EasyPOS.
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
  static const Color dsPrimaryBlue1 = Color(0xFF004671);
  static const Color dsPrimaryBlue4 = Color(0xFFE6F1F8);
  static const Color white = Colors.white;
}

/// Thang khoảng cách — cùng giá trị design system EasyPOS.
abstract final class AppSpace {
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class ShareDimens {
  static const double itemSpacing = 12;
}

abstract final class AppDimens {
  static const double paddingSmallest = 4;
}

abstract final class AppConfig {
  static bool isTabletDevice() => PrintAgentUi.kit.isTablet;
}

/// Khoảng cách co giãn theo màn hình (như `REdgeInsets` của app).
abstract final class AppEdgeInsets {
  static EdgeInsets all(double value) =>
      PrintAgentUi.kit.insets(EdgeInsets.all(value));

  static EdgeInsets symmetric({double horizontal = 0, double vertical = 0}) =>
      PrintAgentUi.kit.insets(
        EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      );

  static EdgeInsets only({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) => PrintAgentUi.kit.insets(
    EdgeInsets.only(left: left, top: top, right: right, bottom: bottom),
  );

  static EdgeInsets fromLTRB(double l, double t, double r, double b) =>
      PrintAgentUi.kit.insets(EdgeInsets.fromLTRB(l, t, r, b));
}

extension AgentPageInsets on BuildContext {
  EdgeInsets get pageInsets => PrintAgentUi.kit.pageInsets(this);
}
