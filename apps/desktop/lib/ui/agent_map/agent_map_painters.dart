import 'dart:ui';
import 'package:flutter/material.dart';
import '../ds/ds.dart';
import 'agent_map_node.dart';

Color agentLinkColor(AgentLinkState s) => switch (s) {
  AgentLinkState.connected => AppColors.successGreen,
  AgentLinkState.disconnected => AppColors.errorRed,
  AgentLinkState.inactive => AppColors.dsGray5,
};

/// Một đường nối (so sánh theo giá trị để biết khi nào cần tính lại).
@immutable
class AgentMapLink {
  const AgentMapLink(
    this.from,
    this.to,
    this.state, {
    required this.curved,
    this.busY,
  });

  final Offset from;
  final Offset to;
  final AgentLinkState state;
  final bool curved;

  /// Có giá trị: tuyến gấp khúc vuông góc kiểu sơ đồ mạng — xuống tới thanh
  /// ngang [busY], chạy ngang, rồi xuống điểm đích (góc bo tròn).
  final double? busY;

  @override
  bool operator ==(Object other) =>
      other is AgentMapLink &&
      other.from == from &&
      other.to == to &&
      other.state == state &&
      other.curved == curved &&
      other.busY == busY;

  @override
  int get hashCode => Object.hash(from, to, state, curved, busY);
}

/// Path, nét đứt và PathMetric của các đường nối — tính một lần cho mỗi bộ
/// [links], dùng lại cho mọi khung hình.
class AgentLinkGeometry {
  AgentLinkGeometry(this.links) {
    for (final link in links) {
      final path = Path()..moveTo(link.from.dx, link.from.dy);
      final busY = link.busY;
      if (busY != null) {
        _elbow(path, link.from, link.to, busY);
      } else if (link.curved) {
        final midY = (link.from.dy + link.to.dy) / 2;
        path.cubicTo(
          link.from.dx,
          midY,
          link.to.dx,
          midY,
          link.to.dx,
          link.to.dy,
        );
      } else {
        path.lineTo(link.to.dx, link.to.dy);
      }
      final color = agentLinkColor(link.state);
      if (link.state == AgentLinkState.connected) {
        solid.add((path, color));
        flows.addAll([for (final m in path.computeMetrics()) (m, color)]);
      } else {
        // Đứt nét: mất kết nối (đỏ) / không dùng được (xám).
        final dashed = Path();
        for (final metric in path.computeMetrics()) {
          for (var d = 0.0; d < metric.length; d += 13) {
            dashed.addPath(metric.extractPath(d, d + 7), Offset.zero);
          }
        }
        this.dashed.add((dashed, color));
      }
    }
  }

  /// Xuống [from] → thanh ngang [busY] → sang ngang → xuống [to], bo góc.
  static void _elbow(Path path, Offset from, Offset to, double busY) {
    const r = 10.0;
    final dx = to.dx - from.dx;
    if (dx.abs() < 1) {
      path.lineTo(to.dx, to.dy);
      return;
    }
    final dir = dx.sign;
    final rr = r.clamp(0.0, dx.abs() / 2);
    path
      ..lineTo(from.dx, busY - rr)
      ..quadraticBezierTo(from.dx, busY, from.dx + dir * rr, busY)
      ..lineTo(to.dx - dir * rr, busY)
      ..quadraticBezierTo(to.dx, busY, to.dx, busY + rr)
      ..lineTo(to.dx, to.dy);
  }

  final List<AgentMapLink> links;
  final List<(Path, Color)> solid = [];
  final List<(Path, Color)> dashed = [];
  final List<(PathMetric, Color)> flows = [];

  bool get hasFlow => flows.isNotEmpty;
}

/// Lớp tĩnh: vẽ đường nối liền / đứt nét.
class AgentLinksPainter extends CustomPainter {
  AgentLinksPainter(this.geometry);

  final AgentLinkGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final (path, color) in geometry.solid) {
      canvas.drawPath(
        path,
        paint
          ..color = color.withValues(alpha: 0.55)
          ..strokeWidth = 2.6,
      );
    }
    for (final (path, color) in geometry.dashed) {
      canvas.drawPath(
        path,
        paint
          ..color = color.withValues(alpha: 0.4)
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(AgentLinksPainter old) => old.geometry != geometry;
}

/// Lớp động: 2 chấm sáng chạy dọc mỗi đường đang thông.
class AgentFlowPainter extends CustomPainter {
  AgentFlowPainter(this.geometry, this.progress) : super(repaint: progress);

  final AgentLinkGeometry geometry;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint();
    for (final (metric, color) in geometry.flows) {
      dot.color = color.withValues(alpha: 0.9);
      for (final offset in const [0.0, 0.5]) {
        final t = (progress.value + offset) % 1.0;
        final tangent = metric.getTangentForOffset(metric.length * t);
        if (tangent != null) canvas.drawCircle(tangent.position, 4, dot);
      }
    }
  }

  @override
  bool shouldRepaint(AgentFlowPainter old) => old.geometry != geometry;
}
