import 'package:flutter/material.dart';

/// Màu + kiểu dùng chung — CÙNG design system app EasyPOS (xanh #0074BD, nút /
/// ô nhập bo 8, nút cao 44) để màn máy tính đồng bộ với app.
abstract final class AgentColors {
  static const primary = Color(0xFF0074BD);
  static const agent = Color(0xFF8443F7);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFDC2626);
  static const bg = Color(0xFFF3F5F9);
  static const card = Colors.white;
  static const border = Color(0xFFE5E8EF);
  static const text = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const muted = Color(0xFF9CA3AF);
}

ThemeData agentTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AgentColors.primary,
      primary: AgentColors.primary,
      surface: AgentColors.card,
    ),
    scaffoldBackgroundColor: AgentColors.bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AgentColors.text,
      displayColor: AgentColors.text,
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: AgentColors.muted),
      border: _inputBorder(AgentColors.border),
      enabledBorder: _inputBorder(AgentColors.border),
      focusedBorder: _inputBorder(AgentColors.primary, 1.4),
      errorBorder: _inputBorder(AgentColors.error),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: _buttonShape,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        shape: _buttonShape,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AgentColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

final _buttonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(8),
);

OutlineInputBorder _inputBorder(Color color, [double width = 1]) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: width),
    );

/// Thẻ trắng bo góc, viền mảnh.
class AgentCard extends StatelessWidget {
  const AgentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AgentColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AgentColors.border),
      ),
      child: child,
    );
  }
}

/// Tiêu đề nhỏ của một nhóm.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AgentColors.text,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
