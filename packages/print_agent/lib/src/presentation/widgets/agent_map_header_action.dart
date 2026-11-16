import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

/// Nút biểu tượng trên đầu sơ đồ: vùng chạm 44x44 (dễ bấm bằng ngón tay), nền
/// xanh nhạt để thấy rõ là nút, [busy] thì hiện vòng xoay thay biểu tượng.
class AgentMapHeaderAction extends StatelessWidget {
  const AgentMapHeaderAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  /// Cạnh vùng chạm (tối thiểu 44 theo chuẩn thao tác bằng ngón tay).
  static const double size = 44;

  final IconData icon;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return BaseTap(
      onTap: busy ? null : onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryBlueBase.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: busy
            ? PrintAgentUi.kit.spinner(size: 20)
            : Icon(icon, size: 24, color: AppColors.primaryBlueBase),
      ),
    );
  }
}
