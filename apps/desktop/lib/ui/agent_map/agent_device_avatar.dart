import 'package:flutter/material.dart';
import '../ds/ds.dart';

/// Nhận diện riêng của MÁY AGENT (khác máy in) dùng chung mọi nơi: màu tím,
/// hình vuông bo góc (máy in luôn tròn), nhãn "Agent".
abstract final class AgentDeviceStyle {
  static const Color color = AppColors.purpleAccent;
  static const IconData icon = Icons.hub_rounded;

  /// Độ bo góc theo kích thước khối — giống biểu tượng thiết bị.
  static BorderRadius radiusFor(double size) =>
      BorderRadius.circular(size * 0.28);
}

/// Biểu tượng một máy Agent trong danh sách: khối vuông bo góc màu tím + chấm
/// trạng thái ở góc (xanh trực tuyến / đỏ ngoại tuyến).
class AgentDeviceAvatar extends StatelessWidget {
  const AgentDeviceAvatar({super.key, required this.online, this.size = 36});

  final bool online;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AgentDeviceStyle.color.withValues(alpha: 0.12),
              borderRadius: AgentDeviceStyle.radiusFor(size),
            ),
            child: Icon(
              AgentDeviceStyle.icon,
              color: AgentDeviceStyle.color,
              size: size * 0.56,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: online ? AppColors.successGreen : AppColors.errorRed,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhãn nhỏ "Agent" (nền tím, chữ trắng) — đặt cạnh / dưới tên máy Agent.
class AgentTag extends StatelessWidget {
  const AgentTag({super.key, this.compact = false});

  /// Nhỏ hơn (dùng trên sơ đồ).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 6,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: AgentDeviceStyle.color,
        borderRadius: BorderRadius.circular(6),
        border: compact ? Border.all(color: Colors.white, width: 1.5) : null,
      ),
      child: Text(
        'Agent',
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
