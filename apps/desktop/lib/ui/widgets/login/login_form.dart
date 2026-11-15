import 'package:flutter/material.dart';

import '../../../auth/auth_service.dart';
import '../../agent_theme.dart';

/// Form đăng nhập: nhãn trên ô (không nhãn nổi), môi trường thu gọn ở góc.
class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    required this.user,
    required this.pass,
    required this.env,
    required this.loading,
    required this.error,
    required this.onEnvChanged,
    required this.onSubmit,
  });

  final TextEditingController user;
  final TextEditingController pass;
  final String env;
  final bool loading;
  final String? error;
  final ValueChanged<String> onEnvChanged;
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đăng nhập',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Dùng tài khoản EasyPOS của cửa hàng.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AgentColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _EnvButton(env: widget.env, onChanged: widget.onEnvChanged),
            ],
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
          if (widget.error != null) ...[
            const SizedBox(height: 16),
            _ErrorBox(widget.error!),
          ],
          const SizedBox(height: 24),
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
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Đăng nhập',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: AgentColors.muted),
              SizedBox(width: 6),
              Text(
                'Mật khẩu không được lưu trên máy này',
                style: TextStyle(fontSize: 12, color: AgentColors.muted),
              ),
            ],
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

/// Môi trường (ít khi đổi) — nút nhỏ ở góc, bấm chọn.
class _EnvButton extends StatelessWidget {
  const _EnvButton({required this.env, required this.onChanged});

  final String env;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final prod = env == 'Production';
    return PopupMenuButton<String>(
      tooltip: 'Môi trường',
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final e in AuthService.envs)
          CheckedPopupMenuItem(value: e, checked: e == env, child: Text(e)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (prod ? AgentColors.success : AgentColors.warning).withValues(
            alpha: 0.1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              size: 8,
              color: prod ? AgentColors.success : AgentColors.warning,
            ),
            const SizedBox(width: 6),
            Text(
              env,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: prod ? AgentColors.success : const Color(0xFFB45309),
              ),
            ),
            const Icon(Icons.expand_more_rounded, size: 16),
          ],
        ),
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
