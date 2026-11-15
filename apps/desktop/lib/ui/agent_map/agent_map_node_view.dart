import 'package:flutter/material.dart';
import '../ds/ds.dart';
import 'agent_device_avatar.dart';
import 'agent_map_activity_layer.dart';
import 'agent_map_node.dart';
import 'agent_map_painters.dart';

/// Một nút trên sơ đồ: vòng tròn icon (viền theo trạng thái) + tên + dòng phụ.
class AgentMapNodeView extends StatelessWidget {
  const AgentMapNodeView({
    required this.node,
    required this.pos,
    this.small = false,
    this.highlight = false,
    this.labelWidth = 120,
  });

  final AgentMapNode node;
  final Offset pos;
  final bool small;
  final bool highlight;

  /// Độ rộng vùng tên (co theo khoảng trống mỗi nút để chữ không đè nhau).
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final size = small ? 44.0 : (highlight ? 68.0 : 56.0);
    final color = agentLinkColor(node.state);
    // Nút gốc (máy này): máy Agent → tím (màu nhận diện Agent), máy bán hàng →
    // xanh như trước.
    final ring = highlight
        ? (node.isAgent ? AgentDeviceStyle.color : AppColors.primaryBlueBase)
        : color;
    // Nhãn "Agent" chỉ cho Agent KHÁC — nút gốc đã ghi "Máy này (Agent)".
    final tagged = node.isAgent && !highlight;
    return Positioned(
      left: pos.dx - labelWidth / 2,
      top: pos.dy - size / 2,
      width: labelWidth,
      child: _Tappable(
        onTap: node.onTap,
        child: AppColumn(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpace.xs,
          children: [
            _BadgedCircle(
              size: size,
              show: node.onTap != null,
              icon: node.tapIcon,
              child: AgentMapActivityLayer(
                activity: node.activity,
                size: size,
                borderRadius: node.isAgent
                    ? AgentDeviceStyle.radiusFor(size)
                    : null,
                child: _WithAgentTag(
                  show: tagged,
                  child: _NodeShape(
                    node: node,
                    size: size,
                    color: color,
                    ring: ring,
                    highlight: highlight,
                  ),
                ),
              ),
            ),
            // Chừa chỗ cho nhãn "Agent" đè mép dưới khối.
            if (tagged) sdsSizedBox4,
            // Nền trắng sau chữ: đường nối tới nút hàng dưới đi phía sau, không
            // cắt ngang tên / dòng phụ (nền thẻ cũng trắng nên không lộ).
            ColoredBox(
              color: Colors.white,
              child: AppText.raw(
                node.title,
                variant: .captionStrong,
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
            // Đang có lệnh in hộ: dòng đầu là máy gửi ("Từ Quầy 1").
            for (final line in [
              if (node.activity?.sender case final sender?)
                AgentMapLine(
                  sender,
                  icon: Icons.devices_rounded,
                  color: node.activity!.color,
                ),
              ...node.lines,
            ].take(2))
              ColoredBox(
                color: Colors.white,
                child: _LineView(line: line),
              ),
          ],
        ),
      ),
    );
  }
}

/// Hình của nút: máy in / đám mây — vòng tròn; máy Agent — khối vuông bo góc
/// nền tím nhạt (máy này đang là Agent: nền xanh đậm như trước). Viền theo
/// trạng thái đường nối.
class _NodeShape extends StatelessWidget {
  const _NodeShape({
    required this.node,
    required this.size,
    required this.color,
    required this.ring,
    required this.highlight,
  });

  final AgentMapNode node;
  final double size;
  final Color color;
  final Color ring;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final agent = node.isAgent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: agent ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: agent ? AgentDeviceStyle.radiusFor(size) : null,
        color: highlight
            ? ring
            : (agent
                  ? Color.alphaBlend(
                      AgentDeviceStyle.color.withValues(alpha: 0.1),
                      Colors.white,
                    )
                  : Colors.white),
        border: Border.all(color: ring, width: 2),
        boxShadow: [
          BoxShadow(
            color: ring.withValues(alpha: 0.22),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        node.icon,
        size: size * 0.46,
        // Agent khác: biểu tượng tím (màu nhận diện Agent); máy in: màu trạng thái.
        color: highlight
            ? Colors.white
            : (agent ? AgentDeviceStyle.color : color),
      ),
    );
  }
}

/// Nhãn "Agent" đè giữa mép dưới khối của máy Agent.
class _WithAgentTag extends StatelessWidget {
  const _WithAgentTag({required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        child,
        const Positioned(bottom: -8, child: AgentTag(compact: true)),
      ],
    );
  }
}

/// Nút bấm được: cả vòng tròn + tên đều là vùng bấm.
class _Tappable extends StatelessWidget {
  const _Tappable({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      onTap == null ? child : BaseTap(onTap: onTap, child: child);
}

/// Biểu tượng nhỏ ở góc vòng tròn — gợi ý nút bấm được (kết nối lại / xem chi
/// tiết).
class _BadgedCircle extends StatelessWidget {
  const _BadgedCircle({
    required this.size,
    required this.show,
    required this.icon,
    required this.child,
  });

  final double size;
  final bool show;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    final circle = child;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          circle,
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppColors.primaryBlueBase,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Một dòng phụ: biểu tượng nhỏ + chữ, căn giữa, quá dài thì "…".
class _LineView extends StatelessWidget {
  const _LineView({required this.line});

  final AgentMapLine line;

  @override
  Widget build(BuildContext context) {
    final icon = line.icon;
    return AppRow(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 3,
      children: [
        if (icon != null)
          Icon(icon, size: 13, color: line.color ?? AppColors.dsGray2),
        Flexible(
          child: AppText.raw(
            line.text,
            variant: .caption,
            tone: .secondary,
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
