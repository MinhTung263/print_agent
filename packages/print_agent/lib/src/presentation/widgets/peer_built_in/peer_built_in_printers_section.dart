import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';
import 'peer_built_in_printer_tile.dart';

/// Mục "Máy in tích hợp của máy Agent": các máy in tích hợp của Agent trong
/// công ty, mỗi máy một thẻ bật / tắt riêng. Tự hỏi Agent trực tuyến khi mở để
/// phát hiện máy mới. Không có máy nào thì ẩn.
class PeerBuiltInPrintersSection extends StatefulWidget {
  const PeerBuiltInPrintersSection({super.key, this.header});

  /// Tiêu đề mục (mặc định chữ thường đậm); màn danh sách máy in truyền tiêu đề
  /// kiểu mục của danh sách.
  final Widget? header;

  @override
  State<PeerBuiltInPrintersSection> createState() =>
      _PeerBuiltInPrintersSectionState();
}

class _PeerBuiltInPrintersSectionState
    extends State<PeerBuiltInPrintersSection> {
  @override
  void initState() {
    super.initState();
    // Sau khung hình đầu: đổi danh sách (Rx) giữa lúc dựng làm Obx báo lỗi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PeerBuiltInPrinters.ensureLoaded();
      unawaited(PrintAgentUi.station.refreshPeerBuiltIns());
    });
  }

  @override
  Widget build(BuildContext context) {
    // Agent bật / tắt → "Trực tuyến / Ngoại tuyến" đổi ngay trên thẻ.
    return ValueListenableBuilder<List<Map<Object?, Object?>>>(
      valueListenable: PrintAgentUi.station.relay.stations,
      builder: (_, _, _) => Obx(() {
        final printers = PeerBuiltInPrinters.items.toList();
        if (printers.isEmpty) return const SizedBox.shrink();
        return AppColumn(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.sm,
          children: [
            widget.header ??
                const AppText(
                  LocaleKeys.printerSetting_stationBuiltInSection,
                  variant: .title,
                ),
            for (final p in printers) PeerBuiltInPrinterTile(printer: p),
          ],
        );
      }),
    );
  }
}
