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
            'Trạm in',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Cài một lần trên máy tính ở quầy — cả quán in hoá đơn, phiếu bếp '
            'ra máy in, không phải cài driver.',
            style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 16),
          ),
          SizedBox(height: 36),
          _Point(
            icon: Icons.devices_rounded,
            title: 'In từ mọi thiết bị bán hàng',
            text:
                'Điện thoại, máy POS bấm in là ra phiếu, kể cả khi dùng mạng '
                'di động. Trang web bán hàng mở trên máy này cũng in được.',
          ),
          _Point(
            icon: Icons.print_rounded,
            title: 'Dùng luôn máy in sẵn có',
            text: 'Máy in hoá đơn cắm dây mạng hoặc cắm USB vào máy tính này.',
          ),
          _Point(
            icon: Icons.verified_user_rounded,
            title: 'Chỉ cửa hàng bạn in được',
            text:
                'Phiếu in được mã hoá, máy ngoài cửa hàng không gửi lệnh in được.',
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
          'Trạm in',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 4),
        Text(
          'In hoá đơn, phiếu bếp không phải cài driver',
          style: TextStyle(fontSize: 13, color: AgentColors.textSecondary),
        ),
      ],
    );
  }
}

/// Logo Agent (cùng biểu tượng app — tool/gen_app_icon.dart, đã có nền bo
/// góc); [light]: viền trắng mờ để nổi trên nền cùng màu.
class _Logo extends StatelessWidget {
  const _Logo({required this.size, this.light = false});

  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.225);
    return Container(
      width: size,
      height: size,
      foregroundDecoration: light
          ? BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 2,
              ),
            )
          : null,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AgentColors.agent.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          'assets/app/app_icon.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
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
