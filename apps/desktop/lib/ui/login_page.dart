import 'dart:async';

import 'package:flutter/material.dart';

import '../agent/desktop_agent.dart';
import '../auth/auth_service.dart';
import 'agent_theme.dart';
import 'widgets/login/brand_panel.dart';
import 'widgets/login/company_picker.dart';
import 'widgets/login/login_form.dart';

/// Đăng nhập tài khoản EasyPOS → chọn công ty (nếu nhiều) → bật Agent. Chỉ dùng để
/// biết công ty; KHÔNG lưu mật khẩu.
///
/// Màn rộng: 2 cột (giới thiệu | form); màn hẹp (iframe): một cột.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.agent});

  final DesktopAgent agent;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final _user = TextEditingController(text: widget.agent.config.userName);
  final _pass = TextEditingController();
  late String _env = AuthService.envs.contains(widget.agent.config.env)
      ? widget.agent.config.env
      : 'Production';
  bool _loading = false;
  String? _error;
  LoginResult? _result;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final user = _user.text.trim();
    if (user.isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Nhập tài khoản và mật khẩu');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AuthService.login(
        env: _env,
        username: user,
        password: _pass.text,
      );
      _pass.clear();
      if (result.companies.length == 1) {
        await _choose(result.companies.first);
      } else if (mounted) {
        setState(() => _result = result);
      }
    } on LoginException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _choose(CompanyChoice c) async {
    final agent = widget.agent;
    await agent.update(
      agent.config.copyWith(
        env: _env,
        companyId: c.id,
        ownerId: c.ownerId,
        companyName: c.name,
        userName: _user.text.trim(),
      ),
    );
    await agent.start();
  }

  Widget _panel() {
    final result = _result;
    if (result != null) {
      return CompanyPicker(
        result: result,
        onBack: () => setState(() => _result = null),
        onChoose: (c) => unawaited(_choose(c)),
      );
    }
    return LoginForm(
      user: _user,
      pass: _pass,
      env: _env,
      loading: _loading,
      error: _error,
      onEnvChanged: (e) => setState(() => _env = e),
      onSubmit: () => unawaited(_login()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 860;
          final card = Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AgentColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: _panel(),
          );
          if (!wide) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const BrandHeader(),
                    const SizedBox(height: 20),
                    card,
                  ],
                ),
              ),
            );
          }
          return Row(
            children: [
              const Expanded(flex: 5, child: BrandPanel()),
              Expanded(
                flex: 6,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: card,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
