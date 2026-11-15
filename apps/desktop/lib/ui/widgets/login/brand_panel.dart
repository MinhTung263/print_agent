import 'package:flutter/material.dart';

import '../../agent_theme.dart';

/// Cột giới thiệu (màn rộng): nền gradient, biểu tượng Agent, 3 ý chính.
class BrandPanel extends StatelessWidget {
  const BrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6D3AF0), Color(0xFF1F6FEB)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Logo(size: 64, light: true),
          SizedBox(height: 28),
          Text(
            'EasyPOS\nPrint Agent',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Biến máy tính này thành máy Agent in hộ cho cả cửa hàng.',
            style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 16),
          ),
          SizedBox(height: 36),
          _Point(
            icon: Icons.cloud_sync_rounded,
            title: 'Nhận lệnh từ mọi máy bán hàng',
            text: 'Điện thoại, máy POS dùng 4G hay khác mạng vẫn in được.',
          ),
          _Point(
            icon: Icons.print_rounded,
            title: 'In ra máy in của máy tính',
            text: 'Máy in hoá đơn LAN hoặc USB đã cài trên máy này.',
          ),
          _Point(
            icon: Icons.lock_rounded,
            title: 'Mã hoá khi truyền',
            text: 'Lệnh in được mã hoá khi gửi qua mạng.',
          ),
        ],
      ),
    );
  }
}

/// Đầu trang gọn (màn hẹp): logo + tên.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _Logo(size: 56),
        SizedBox(height: 12),
        Text(
          'EasyPOS Print Agent',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 4),
        Text(
          'Biến máy tính này thành máy Agent in hộ',
          style: TextStyle(fontSize: 13, color: AgentColors.textSecondary),
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.size, this.light = false});

  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: light ? Colors.white.withValues(alpha: 0.16) : null,
        gradient: light
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9B6BFA), AgentColors.agent],
              ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: light
            ? Border.all(color: Colors.white.withValues(alpha: 0.3))
            : null,
      ),
      child: Icon(Icons.hub_rounded, color: Colors.white, size: size * 0.54),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
