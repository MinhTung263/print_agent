import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kit_tokens.dart';

/// Công tắc bật / tắt giống hệt công tắc của app EasyPOS (`BaseCupertinoSwitch`): 44×24,
/// con trượt trắng 20 có bóng nhẹ, nền xanh khi bật / xám khi tắt, chuyển động 200ms, kéo
/// ngang hoặc bấm đều đổi được, vùng chạm 44×44.
class AgentSwitch extends StatelessWidget {
  const AgentSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// `false`: mờ đi và không đổi được.
  final bool enabled;

  void _change(bool v) {
    if (!enabled || v == value) return;
    HapticFeedback.lightImpact();
    onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final on = enabled ? AppColors.primaryBlueBase : AppColors.dsPrimaryBlue4;
    final off = enabled ? AppColors.dsGray4 : const Color(0xFFE9ECEF);
    return Semantics(
      toggled: value,
      enabled: enabled,
      button: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => _change(!value) : null,
            onHorizontalDragUpdate: enabled
                ? (d) {
                    final delta = d.primaryDelta ?? 0;
                    if (delta > 1.5) _change(true);
                    if (delta < -1.5) _change(false);
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: 44,
              height: 24,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                color: value ? on : off,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x26000000),
                        offset: Offset(0, 1.5),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
