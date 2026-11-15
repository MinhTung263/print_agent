import 'package:flutter/material.dart';

/// Màu + kiểu dùng chung — theo nhận diện EasyPOS (xanh chủ đạo, máy Agent tím).
abstract final class AgentColors {
  static const primary = Color(0xFF1F6FEB);
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
      fillColor: AgentColors.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
  );
}

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
