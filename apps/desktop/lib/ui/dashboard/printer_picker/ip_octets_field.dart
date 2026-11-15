import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../agent_theme.dart';

/// Ô nhập IP dạng 4 ô số (192 . 168 . 1 . 42) — như ô IP của app EasyPOS:
/// - Ba ô đầu điền sẵn theo dải mạng của máy này (thường chỉ gõ ô cuối).
/// - Gõ đủ 3 số hoặc dấu "." → sang ô sau; Xoá ở ô trống → về ô trước.
/// - Dán "192.168.1.42" vào ô nào cũng tự tách đủ 4 ô.
class IpOctetsField extends StatefulWidget {
  const IpOctetsField({
    super.key,
    required this.onChanged,
    this.onSubmitted,
    this.prefill,
  });

  /// IP của máy này (điền sẵn 3 số đầu); `null` = không điền.
  final Future<String?> Function()? prefill;

  /// IP đầy đủ hợp lệ, hoặc `null` khi chưa đủ / sai.
  final ValueChanged<String?> onChanged;
  final VoidCallback? onSubmitted;

  @override
  State<IpOctetsField> createState() => _IpOctetsFieldState();
}

class _IpOctetsFieldState extends State<IpOctetsField> {
  final _ctrls = List.generate(4, (_) => TextEditingController());
  final _nodes = List.generate(4, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 4; i++) {
      _nodes[i].onKeyEvent = (_, e) => _onKey(i, e);
    }
    unawaited(_prefill());
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// Điền sẵn 3 số đầu theo IP của máy này rồi đặt con trỏ vào ô cuối.
  Future<void> _prefill() async {
    final ip = await widget.prefill?.call();
    final p = ip?.split('.') ?? const <String>[];
    if (p.length != 4 || !mounted) return;
    for (var i = 0; i < 3; i++) {
      _ctrls[i].text = p[i];
    }
    _nodes[3].requestFocus();
  }

  KeyEventResult _onKey(int i, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.backspace &&
        _ctrls[i].text.isEmpty &&
        i > 0) {
      _nodes[i - 1].requestFocus();
      _ctrls[i - 1].selection = TextSelection.collapsed(
        offset: _ctrls[i - 1].text.length,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _changed(int i, String value) {
    // Dán cả IP.
    final parts = value.split('.');
    if (parts.length == 4 && parts.every((p) => int.tryParse(p) != null)) {
      for (var k = 0; k < 4; k++) {
        _ctrls[k].text = parts[k];
      }
      _nodes[3].requestFocus();
    } else if (value.endsWith('.')) {
      _ctrls[i].text = value.replaceAll('.', '');
      if (i < 3) _nodes[i + 1].requestFocus();
    } else if (value.length > 3 && i < 3) {
      // Gõ quá 3 số: phần thừa sang ô sau.
      _ctrls[i].text = value.substring(0, 3);
      _ctrls[i + 1].text = value.substring(3, value.length.clamp(3, 6));
      _nodes[i + 1].requestFocus();
    } else if (value.length > 3) {
      _ctrls[i].text = value.substring(0, 3);
    } else if (value.length == 3 && i < 3) {
      _nodes[i + 1].requestFocus();
    }
    widget.onChanged(_ip);
    setState(() {});
  }

  String? get _ip {
    final nums = [for (final c in _ctrls) int.tryParse(c.text)];
    if (nums.any((n) => n == null || n < 0 || n > 255)) return null;
    return nums.join('.');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          Expanded(child: _box(i)),
        ],
      ],
    );
  }

  Widget _box(int i) {
    final n = int.tryParse(_ctrls[i].text);
    final bad = _ctrls[i].text.isNotEmpty && (n == null || n > 255);
    return TextField(
      controller: _ctrls[i],
      focusNode: _nodes[i],
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      textInputAction: i < 3 ? TextInputAction.next : TextInputAction.done,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        LengthLimitingTextInputFormatter(15),
      ],
      decoration: InputDecoration(
        hintText: '0',
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        enabledBorder: bad
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AgentColors.error),
              )
            : null,
      ),
      onChanged: (v) => _changed(i, v),
      onSubmitted: (_) =>
          i < 3 ? _nodes[i + 1].requestFocus() : widget.onSubmitted?.call(),
    );
  }
}
