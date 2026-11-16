import 'package:flutter/material.dart';
import '../agent_spinner.dart';

import '../../agent_theme.dart';

/// Form đăng nhập: nhãn trên ô (không nhãn nổi), ô ghi nhớ mật khẩu.
class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    required this.user,
    required this.pass,
    required this.remember,
    required this.loading,
    required this.error,
    required this.onRememberChanged,
    required this.onSubmit,
  });

  final TextEditingController user;
  final TextEditingController pass;

  /// Ghi nhớ tài khoản + mật khẩu trên máy này.
  final bool remember;
  final bool loading;
  final String? error;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onSubmit;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  bool _showPass = false;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Đăng nhập',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Dùng tài khoản EasyPOS của cửa hàng.',
            style: TextStyle(fontSize: 14, color: AgentColors.textSecondary),
          ),
          const SizedBox(height: 28),
          const _Label('Tài khoản'),
          TextField(
            controller: widget.user,
            autofillHints: const [AutofillHints.username],
            textInputAction: TextInputAction.next,
            decoration: _decoration(
              hint: 'Tên đăng nhập',
              icon: Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(height: 18),
          const _Label('Mật khẩu'),
          TextField(
            controller: widget.pass,
            obscureText: !_showPass,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => widget.onSubmit(),
            decoration: _decoration(
              hint: 'Nhập mật khẩu',
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                splashRadius: 18,
                onPressed: () => setState(() => _showPass = !_showPass),
                icon: Icon(
                  _showPass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: AgentColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _RememberBox(
            value: widget.remember,
            onChanged: widget.loading ? null : widget.onRememberChanged,
          ),
          if (widget.error != null) ...[
            const SizedBox(height: 8),
            _ErrorBox(widget.error!),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: widget.loading ? null : widget.onSubmit,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: widget.loading
                  ? AgentSpinner(size: 20, color: Colors.white)
                  : const Text(
                      'Đăng nhập',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AgentColors.muted),
      prefixIcon: Icon(icon, size: 20, color: AgentColors.textSecondary),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      enabledBorder: border(AgentColors.border),
      focusedBorder: border(AgentColors.primary, 1.6),
      border: border(AgentColors.border),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Ô "Ghi nhớ mật khẩu" (bấm cả dòng chữ cũng được).
class _RememberBox extends StatelessWidget {
  const _RememberBox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: change == null ? null : () => change(!value),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: change == null ? null : (v) => change(v ?? false),
          ),
          const Text(
            'Ghi nhớ tài khoản và mật khẩu',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AgentColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AgentColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AgentColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AgentColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
