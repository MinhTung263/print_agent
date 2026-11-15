import 'dart:async';

import 'package:flutter/material.dart';

import '../agent/desktop_agent.dart';
import '../auth/auth_service.dart';
import '../auth/saved_login.dart';
import 'agent_theme.dart';
import 'widgets/login/brand_panel.dart';
import 'widgets/login/company_picker.dart';
import 'widgets/login/login_form.dart';

/// Đăng nhập tài khoản EasyPOS (luôn máy chủ thật) → chọn công ty (nếu nhiều)
/// → bật trạm in. Chọn "Ghi nhớ" thì tài khoản + mật khẩu cất trong kho bảo
/// mật của máy ([SavedLoginStore]), lần sau tự điền.
///
/// Màn rộng: 2 cột (giới thiệu | form); màn hẹp (iframe): một cột.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.agent, this.savedLogin});

  final DesktopAgent agent;

  /// Mặc định kho bảo mật của hệ điều hành.
  final SavedLoginStore? savedLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final _user = TextEditingController(text: widget.agent.config.userName);
  final _pass = TextEditingController();
  late final SavedLoginStore _saved =
      widget.savedLogin ?? SecureSavedLoginStore();
  bool _remember = false;

  /// Mật khẩu vừa đăng nhập — giữ tới khi chọn xong công ty để lấy token của
  /// công ty đó, rồi bỏ.
  String? _password;
  bool _loading = false;
  String? _error;
  LoginResult? _result;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  /// Tự điền tài khoản đã ghi nhớ.
  Future<void> _restore() async {
    final saved = await _saved.read();
    if (saved == null || !mounted) return;
    setState(() {
      _remember = true;
      _user.text = saved.username;
      _pass.text = saved.password;
    });
  }

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
      final password = _pass.text;
      final result = await AuthService.login(
        username: user,
        password: password,
      );
      await (_remember
          ? _saved.save(SavedLogin(username: user, password: password))
          : _saved.clear());
      _password = password;
      if (!_remember) _pass.clear();
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
        companyId: c.id,
        ownerId: c.ownerId,
        companyName: c.name,
        userName: _user.text.trim(),
      ),
    );
    await _signIn(c.id);
    await agent.start();
  }

  /// Lấy token của công ty (tự thêm máy in vào cửa hàng). Lỗi thì bỏ qua —
  /// trạm in vẫn chạy, chỉ không tự thêm máy in.
  Future<void> _signIn(int companyId) async {
    final password = _password;
    _password = null;
    if (password == null) return;
    try {
      await widget.agent.auth.signedIn(
        await AuthService.companyToken(
          username: _user.text.trim(),
          password: password,
          companyId: companyId,
        ),
      );
    } on LoginException catch (e) {
      debugPrint('[AUTH] Không lấy được token công ty: ${e.message}');
    }
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
      remember: _remember,
      loading: _loading,
      error: _error,
      onRememberChanged: (v) => setState(() => _remember = v),
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
