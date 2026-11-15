import 'package:flutter/material.dart';

import 'agent_map_activity.dart';

export 'agent_map_activity.dart';

/// Trạng thái một đường nối trên sơ đồ.
enum AgentLinkState { connected, disconnected, inactive }

/// Loại nút — vẽ khác nhau để không nhầm máy in với máy Agent: máy in hình
/// tròn; máy Agent khối vuông bo góc màu tím + nhãn "Agent", nằm hàng riêng.
enum AgentMapNodeKind { device, agent }

/// Một dòng phụ dưới tên nút: chữ + biểu tượng nhỏ cho biết đó là gì (VD
/// biểu tượng mạng LAN trước IP, Wi-Fi trước tên Wi-Fi).
class AgentMapLine {
  const AgentMapLine(this.text, {this.icon, this.color});

  final String text;
  final IconData? icon;

  /// Màu biểu tượng (mặc định màu chữ phụ).
  final Color? color;
}

/// Một nút trên sơ đồ (máy in / máy Agent / đám mây).
class AgentMapNode {
  const AgentMapNode({
    required this.icon,
    required this.title,
    this.lines = const [],
    this.state = AgentLinkState.connected,
    this.onTap,
    this.tapIcon = Icons.refresh_rounded,
    this.kind = AgentMapNodeKind.device,
    this.activity,
  });

  final IconData icon;
  final String title;

  /// Dòng phụ (hiện tối đa 2) — VD IP + Wi-Fi.
  final List<AgentMapLine> lines;

  /// Trạng thái đường nối từ máy này tới nút.
  final AgentLinkState state;

  /// Bấm vào nút (VD máy in lỗi → "Kết nối lại"); có thì hiện biểu tượng làm mới
  /// nhỏ ở góc vòng tròn.
  final VoidCallback? onTap;

  /// Biểu tượng nhỏ ở góc khi bấm được — mặc định "làm mới" (kết nối lại); nút
  /// Agent khác dùng biểu tượng danh sách (bấm xem máy in của Agent đó).
  final IconData tapIcon;

  final AgentMapNodeKind kind;

  /// Lệnh in hộ đang chạy / vừa xong ở nút này (máy in) — `null` khi không có.
  final AgentMapActivity? activity;

  bool get isAgent => kind == AgentMapNodeKind.agent;
}
