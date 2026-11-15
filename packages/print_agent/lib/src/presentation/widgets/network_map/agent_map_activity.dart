import 'package:flutter/material.dart';

/// Nút máy in đang nhận lệnh in hộ: nhãn nổi phía trên ("Đang in hoá đơn" /
/// "Đã in" / "In lỗi"), máy gửi, vòng sáng lan toả khi đang in.
class AgentMapActivity {
  const AgentMapActivity({
    required this.label,
    required this.color,
    required this.icon,
    this.pulsing = false,
    this.sender,
  });

  final String label;
  final Color color;
  final IconData icon;

  /// Đang in: vòng sáng lan toả quanh nút.
  final bool pulsing;

  /// "Từ Quầy 1" — hiện thay dòng phụ đầu tiên.
  final String? sender;
}
