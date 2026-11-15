import 'package:flutter/material.dart';

import '../../agent/print_agent.dart';

/// Đặt tên máy Agent (VD "Quầy thu ngân") — máy bán hàng thấy tên này.
Future<void> showAgentRenameDialog(
  BuildContext context,
  PrintAgent agent,
) async {
  final ctrl = TextEditingController(text: agent.config.name);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tên máy Agent'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'VD "Quầy thu ngân", "Bếp"',
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, ctrl.text),
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  if (name == null) return;
  await agent.update(agent.config.copyWith(name: name.trim()));
}
