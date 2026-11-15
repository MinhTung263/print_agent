import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/presentation/widgets/network_map/agent_map_activity.dart';

/// Bọc hình nút khi có lệnh in hộ: vòng sáng lan toả (đang in) phía sau + nhãn
/// nổi phía trên ("Đang in hoá đơn" / "Đã in" / "In lỗi").
class AgentMapActivityLayer extends StatelessWidget {
  const AgentMapActivityLayer({
    super.key,
    required this.activity,
    required this.size,
    required this.borderRadius,
    required this.child,
  });

  final AgentMapActivity? activity;
  final double size;

  /// `null`: nút tròn; khác `null`: khối vuông bo góc (máy Agent).
  final BorderRadius? borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    if (a == null) return child;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (a.pulsing && !MediaQuery.disableAnimationsOf(context))
            _Pulse(size: size, color: a.color, borderRadius: borderRadius),
          child,
          Positioned(
            top: -26,
            left: -60,
            right: -60,
            child: Center(child: _ActivityChip(activity: a)),
          ),
        ],
      ),
    );
  }
}

/// Nhãn nổi: nền màu trạng thái, biểu tượng + chữ trắng.
class _ActivityChip extends StatelessWidget {
  const _ActivityChip({required this.activity});

  final AgentMapActivity activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
      decoration: BoxDecoration(
        color: activity.color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: activity.color.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppRow(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          Icon(activity.icon, size: 12, color: Colors.white),
          Text(
            activity.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vòng sáng lan toả lặp lại quanh nút đang in.
class _Pulse extends StatefulWidget {
  const _Pulse({
    required this.size,
    required this.color,
    required this.borderRadius,
  });

  final double size;
  final Color color;
  final BorderRadius? borderRadius;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          final t = Curves.easeOut.transform(_ctrl.value);
          final scale = 1 + 0.55 * t;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: widget.borderRadius == null
                    ? BoxShape.circle
                    : BoxShape.rectangle,
                borderRadius: widget.borderRadius,
                color: widget.color.withValues(alpha: 0.35 * (1 - t)),
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.8 * (1 - t)),
                  width: 2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
