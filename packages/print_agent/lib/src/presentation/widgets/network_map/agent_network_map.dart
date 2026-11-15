import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

/// Một máy Agent trên sơ đồ + các máy in nó đang kết nối (xếp dưới nó).
class AgentMapCluster {
  const AgentMapCluster({required this.agent, this.printers = const []});

  final AgentMapNode agent;
  final List<AgentMapNode> printers;
}

/// Sơ đồ kiểu CẤU TRÚC MẠNG (cây): đám mây ở gốc → mỗi máy (máy này + từng máy
/// Agent khác) là một NHÁNH nối từ đám mây bằng đường gấp khúc → máy in của
/// máy đó nối từ thanh ngang ngay dưới nó. Mỗi nhánh có nền khung riêng (máy
/// này xanh, Agent khác tím). Nhiều nhánh quá bề ngang thì kéo ngang được.
///
/// Đường nối đổi màu theo trạng thái; đường đang thông có chấm sáng chạy dọc.
class AgentNetworkMap extends StatefulWidget {
  const AgentNetworkMap({
    super.key,
    required this.center,
    this.cloud,
    this.nodes = const [],
    this.clusters = const [],
    this.nodesLabel,
    this.clustersLabel,
    this.linkClusters = false,
    this.emptyText,
  });

  /// Máy này (nhánh đầu tiên, làm nổi).
  final AgentMapNode center;

  /// Đám mây (gốc). `null`: không có gốc — các nhánh đứng riêng.
  final AgentMapNode? cloud;

  /// Máy in của máy này.
  final List<AgentMapNode> nodes;

  /// Các máy Agent khác + máy in của từng Agent (mỗi Agent một nhánh).
  final List<AgentMapCluster> clusters;

  /// Giữ để tương thích — nhánh đã phân vùng bằng khung màu.
  final String? nodesLabel;
  final String? clustersLabel;
  final bool linkClusters;

  /// Hiện trong nhánh máy này khi máy này chưa có máy in nào.
  final String? emptyText;

  @override
  State<AgentNetworkMap> createState() => _AgentNetworkMapState();
}

/// Một nhánh: máy (Agent / máy này) + máy in của nó.
class _Branch {
  const _Branch(this.node, this.printers, {required this.self});

  final AgentMapNode node;
  final List<AgentMapNode> printers;
  final bool self;
}

class _AgentNetworkMapState extends State<AgentNetworkMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  AgentLinkGeometry? _geometry;

  AgentLinkGeometry _geometryFor(List<AgentMapLink> links) {
    final cached = _geometry;
    if (cached != null && listEquals(cached.links, links)) return cached;
    return _geometry = AgentLinkGeometry(links);
  }

  void _syncFlow(bool animate) {
    if (animate == _flow.isAnimating) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (animate && !_flow.isAnimating) {
        unawaited(_flow.repeat());
      } else if (!animate && _flow.isAnimating) {
        _flow.stop();
      }
    });
  }

  /// Ô một máy in (tên + 2 dòng phụ đọc được).
  static const double _leafSlot = 96;
  static const int _maxLeavesPerRow = 4;
  static const double _minBranchWidth = 150;
  static const double _branchGap = 10;

  /// Vùng tên + tối đa 2 dòng phụ dưới vòng tròn.
  static const double _labelBlock = 56;
  static const double _rowGap = 124;
  static const double _cloudY = 34;

  static const Color _selfColor = Color(0xFF0074BD);
  static const Color _agentColor = Color(0xFF8443F7);

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  static double _branchWidth(_Branch b) => math.max(
    _minBranchWidth,
    math.min(math.max(b.printers.length, 1), _maxLeavesPerRow) * _leafSlot + 12,
  );

  @override
  Widget build(BuildContext context) {
    final w = widget;
    // [linkClusters] (máy bán hàng): máy này là GỐC (dưới đám mây), các Agent
    // là nhánh nối từ máy này. Không thì máy này cũng là một nhánh như Agent.
    final hub = w.linkClusters;
    final branches = [
      if (!hub) _Branch(w.center, w.nodes, self: true),
      for (final c in w.clusters) _Branch(c.agent, c.printers, self: false),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final widths = [for (final b in branches) _branchWidth(b)];
        final natural =
            widths.fold<double>(0, (a, b) => a + b) +
            _branchGap * (branches.length - 1);
        final cloud = w.cloud;
        // Không đủ bề ngang (điện thoại): các nhánh XẾP DỌC, mỗi nhánh rộng cả
        // khung; đám mây nối xuống bằng trục bên trái rồi rẽ vào từng nhánh.
        final stacked = natural > available && branches.length > 1;
        // Trục dọc bên trái (chế độ xếp dọc) + lề để nhánh chừa chỗ cho trục.
        const trunkX = 10.0;
        final stackLeft = cloud == null && !hub ? 0.0 : 22.0;
        if (stacked) {
          for (var i = 0; i < widths.length; i++) {
            widths[i] = available - stackLeft;
          }
        } else if (natural < available) {
          // Thừa chỗ: chia đều cho các nhánh.
          final extra = (available - natural) / branches.length;
          for (var i = 0; i < widths.length; i++) {
            widths[i] += extra;
          }
        }
        final width = stacked ? available : math.max(natural, available);

        final cloudPos = Offset(width / 2, _cloudY);
        final cloudBottom = cloudPos.translate(0, 22 + _labelBlock);
        // Gốc các nhánh: máy này ([hub]) hoặc đám mây.
        final hubPos = Offset(width / 2, cloud == null ? 44 : 190);
        final rootBottom = hub
            ? hubPos.translate(0, 34 + _labelBlock)
            : cloudBottom;
        final hasRoot = hub || cloud != null;
        // Thanh ngang từ gốc xuống các nhánh.
        final rootBusY = rootBottom.dy + 16;
        var branchTop = hasRoot ? rootBusY + 14 : 4.0;

        final links = <AgentMapLink>[
          if (hub && cloud != null)
            AgentMapLink(
              cloudBottom,
              hubPos.translate(0, -34),
              cloud.state,
              curved: false,
            ),
        ];
        final frames = <Widget>[];
        final views = <Widget>[];
        var bottom = 0.0;
        var x = stacked ? stackLeft : 0.0;
        for (var b = 0; b < branches.length; b++) {
          final br = branches[b];
          final bw = widths[b];
          final cx = x + bw / 2;
          final nodePos = Offset(cx, branchTop + 48);
          final half = br.self ? 34.0 : 28.0;
          final uplink = br.self ? cloud?.state : br.node.state;
          if (hasRoot && uplink != null) {
            if (stacked) {
              // Đám mây → trục trái → rẽ ngang vào máy của nhánh.
              final join = Offset(trunkX, nodePos.dy);
              links
                ..add(
                  AgentMapLink(
                    rootBottom,
                    join,
                    uplink,
                    curved: false,
                    busY: rootBusY,
                  ),
                )
                ..add(
                  AgentMapLink(
                    join,
                    nodePos.translate(-half, 0),
                    uplink,
                    curved: false,
                  ),
                );
            } else {
              links.add(
                AgentMapLink(
                  rootBottom,
                  nodePos.translate(0, -half),
                  uplink,
                  curved: false,
                  busY: rootBusY,
                ),
              );
            }
          }
          views.add(
            AgentMapNodeView(
              node: br.node,
              pos: nodePos,
              highlight: br.self,
              labelWidth: bw - 12,
            ),
          );
          // Máy in: lưới tối đa 4 cột dưới máy, nối từ thanh ngang của nhánh.
          final nodeBottom = nodePos.translate(
            0,
            half + _labelBlock + (br.node.isAgent && !br.self ? 6 : 0),
          );
          final firstLeafY = nodeBottom.dy + 64;
          final perRow = math.max(
            1,
            math.min(_maxLeavesPerRow, ((bw - 12) / _leafSlot).floor()),
          );
          var branchBottom = nodeBottom.dy;
          for (var i = 0; i < br.printers.length; i++) {
            final row = i ~/ perRow;
            final inRow = math.min(perRow, br.printers.length - row * perRow);
            final slot = (bw - 12) / inRow;
            final pos = Offset(
              x + 6 + slot * (i % perRow) + slot / 2,
              firstLeafY + row * _rowGap,
            );
            links.add(
              AgentMapLink(
                nodeBottom,
                pos.translate(0, -28),
                br.printers[i].state,
                curved: false,
                busY: pos.dy - 46,
              ),
            );
            views.add(
              AgentMapNodeView(
                node: br.printers[i],
                pos: pos,
                labelWidth: math.min(200, slot - 6),
              ),
            );
            branchBottom = pos.dy + 28 + _labelBlock;
          }
          if (br.printers.isEmpty && br.self && w.emptyText != null) {
            views.add(
              Positioned(
                left: x + 8,
                width: bw - 16,
                top: nodeBottom.dy + 6,
                child: AppText(
                  w.emptyText!,
                  textAlign: TextAlign.center,
                  variant: .caption,
                  tone: .secondary,
                  maxLines: 3,
                ),
              ),
            );
            branchBottom = nodeBottom.dy + 46;
          }
          final rect = Rect.fromLTRB(
            x + 1,
            branchTop,
            x + bw - 1,
            branchBottom + 10,
          );
          frames.add(
            _BranchFrame(rect: rect, color: br.self ? _selfColor : _agentColor),
          );
          bottom = math.max(bottom, rect.bottom);
          if (stacked) {
            branchTop = rect.bottom + 12;
          } else {
            x += bw + _branchGap;
          }
        }

        if (branches.isEmpty) {
          if (w.emptyText != null) {
            views.add(
              Positioned(
                left: 16,
                right: 16,
                top: rootBottom.dy + 12,
                child: AppText(
                  w.emptyText!,
                  textAlign: TextAlign.center,
                  variant: .caption,
                  tone: .secondary,
                  maxLines: 3,
                ),
              ),
            );
          }
          bottom = rootBottom.dy + 60;
        }
        final geometry = _geometryFor(links);
        final animate =
            geometry.hasFlow && !MediaQuery.disableAnimationsOf(context);
        _syncFlow(animate);
        final map = SizedBox(
          width: width,
          height: bottom + 12,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ...frames,
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: AgentLinksPainter(geometry)),
                ),
              ),
              if (animate)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: AgentFlowPainter(geometry, _flow),
                    ),
                  ),
                ),
              if (cloud != null)
                AgentMapNodeView(
                  node: cloud,
                  pos: cloudPos,
                  small: true,
                  labelWidth: math.min(280, width - 16),
                ),
              if (hub)
                AgentMapNodeView(
                  node: w.center,
                  pos: hubPos,
                  highlight: true,
                  labelWidth: math.min(280, width - 16),
                ),
              ...views,
            ],
          ),
        );
        // Rộng hơn màn hình (nhiều Agent / máy in): kéo ngang.
        if (width <= available) return map;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: map,
        );
      },
    );
  }
}

/// Nền khung một nhánh: viền mảnh + nền rất nhạt theo màu nhánh.
class _BranchFrame extends StatelessWidget {
  const _BranchFrame({required this.rect, required this.color});

  final Rect rect;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
        ),
      ),
    );
  }
}
