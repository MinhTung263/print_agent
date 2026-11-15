import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../agent/desktop_agent.dart';
import '../../agent/agent_config.dart';
import '../../desktop/autostart.dart';
import 'package:printer_label/desktop.dart';
import '../ds/ds.dart';
import 'printer_picker_dialog.dart';

/// Cài đặt Agent: máy in, khổ giấy, in hộ máy in LAN, cửa hàng.
class AgentSettingsCard extends StatelessWidget {
  const AgentSettingsCard({super.key, required this.agent});

  final DesktopAgent agent;

  Future<void> _pickPrinter(BuildContext context) async {
    final picked = await showPrinterPickerDialog(
      context,
      current: agent.config.printer,
    );
    if (picked != null) {
      await agent.update(agent.config.copyWith(printer: picked));
    }
  }

  Future<void> _printTest(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await agent.printTest();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: error == null
            ? AppColors.successGreen
            : AppColors.errorRed,
        content: Text(error ?? 'Đã gửi phiếu in thử'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: agent,
    builder: (context, _) => _card(context),
  );

  Widget _card(BuildContext context) {
    final config = agent.config;
    return BaseCard.section(
      child: AppColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpace.sm,
        children: [
          const AppText('Cài đặt máy in', variant: .title),
          AppRow(
            spacing: AppSpace.sm,
            children: [
              Expanded(
                child: AppColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppText('Máy in của Agent'),
                    AppText(
                      config.hasPrinter
                          ? '${UsbPrinters.label(config.printer)}${agent.printerOk == false ? ' · không kết nối được' : ''}'
                          : 'Chưa chọn — máy bán hàng chọn "máy in tích hợp" của Agent sẽ in ra đây',
                      variant: .caption,
                      tone: .secondary,
                      textColor: agent.printerOk == false
                          ? AppColors.errorRed
                          : null,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              if (config.hasPrinter)
                TextButton(
                  onPressed: () => unawaited(_printTest(context)),
                  child: const Text('In thử'),
                ),
              TextButton(
                onPressed: () => unawaited(_pickPrinter(context)),
                child: Text(config.hasPrinter ? 'Đổi' : 'Chọn'),
              ),
            ],
          ),
          const AppDivider(),
          AppRow(
            children: [
              const Expanded(child: AppText('Khổ giấy')),
              CupertinoSlidingSegmentedControl<PaperSize>(
                groupValue: config.paper,
                children: const {
                  PaperSize.size80: Text('80mm'),
                  PaperSize.size58: Text('58mm'),
                },
                onValueChanged: (p) {
                  if (p != null) {
                    unawaited(agent.update(config.copyWith(paper: p)));
                  }
                },
              ),
            ],
          ),
          const AppDivider(),
          AppRow(
            children: [
              Expanded(
                child: AppColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppText('In hộ máy in LAN của cửa hàng'),
                    AppText(
                      config.acceptAll
                          ? 'Nhận cả hoá đơn gửi tới máy in LAN mà máy này kết nối được'
                          : 'Chỉ in lệnh gửi tới máy in của Agent này',
                      variant: .caption,
                      tone: .secondary,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: config.acceptAll,
                activeTrackColor: AppColors.primaryBlueBase,
                onChanged: (v) =>
                    unawaited(agent.update(config.copyWith(acceptAll: v))),
              ),
            ],
          ),
          if (Autostart.supported) ...[
            const AppDivider(),
            ValueListenableBuilder<bool>(
              valueListenable: Autostart.instance.enabled,
              builder: (_, on, _) => AppRow(
                children: [
                  const Expanded(
                    child: AppColumn(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText('Tự chạy khi bật máy'),
                        AppText(
                          'Chạy ẩn dưới khay hệ thống để luôn nhận lệnh in',
                          variant: .caption,
                          tone: .secondary,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  CupertinoSwitch(
                    value: on,
                    activeTrackColor: AppColors.primaryBlueBase,
                    onChanged: (v) => unawaited(Autostart.instance.set(v)),
                  ),
                ],
              ),
            ),
          ],
          const AppDivider(),
          AppRow(
            spacing: AppSpace.sm,
            children: [
              const Icon(
                Icons.storefront_outlined,
                size: 18,
                color: AppColors.dsGray2,
              ),
              Expanded(
                child: AppText(
                  [
                    if (config.companyName.isNotEmpty) config.companyName,
                    '#${config.companyId}',
                    config.env,
                    if (config.userName.isNotEmpty) config.userName,
                  ].join(' · '),
                  variant: .caption,
                  tone: .secondary,
                  maxLines: 2,
                ),
              ),
              TextButton.icon(
                onPressed: () => unawaited(agent.logout()),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Đăng xuất'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
