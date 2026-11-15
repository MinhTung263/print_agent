import 'auth_service.dart';
import 'saved_login.dart';
import 'secret_store.dart';

/// Phiên gọi API EasyPOS của công ty đang đăng nhập (token cất trong kho bảo
/// mật). Dùng cho việc cần quyền như tự thêm máy in vào cửa hàng.
///
/// Token hết hạn: gia hạn bằng refresh token; không được thì đăng nhập lại
/// bằng tài khoản đã ghi nhớ (nếu có). Không lấy được thì trả `null` — tính
/// năng cần token tự tắt, trạm in vẫn in bình thường.
class AuthSession {
  AuthSession({
    required int? Function() companyId,
    SecretStore? store,
    SavedLoginStore? savedLogin,
    Future<AuthTokens?> Function(String refresh, String token)? refresh,
    Future<AuthTokens> Function(String user, String pass, int companyId)? login,
  }) : _companyId = companyId,
       _store = store ?? SecureSecretStore(),
       _saved = savedLogin ?? SecureSavedLoginStore(store),
       _refresh = refresh ?? AuthService.refresh,
       _login =
           login ??
           ((u, p, c) => AuthService.companyToken(
             username: u,
             password: p,
             companyId: c,
           ));

  static const String _tokenKey = 'api_token';
  static const String _refreshKey = 'api_refresh';
  static const String _companyKey = 'api_company';

  final int? Function() _companyId;
  final SecretStore _store;
  final SavedLoginStore _saved;
  final Future<AuthTokens?> Function(String refresh, String token) _refresh;
  final Future<AuthTokens> Function(String user, String pass, int companyId)
  _login;

  Future<String?>? _renewing;

  /// Vừa đăng nhập công ty: cất token.
  Future<void> signedIn(AuthTokens tokens) async {
    await _store.write(_tokenKey, tokens.idToken);
    await _store.write(_refreshKey, tokens.refreshToken);
    await _store.write(_companyKey, '${_companyId()}');
  }

  /// Token của công ty đang đăng nhập; `null` khi chưa có (hoặc của công ty
  /// khác).
  Future<String?> token() async {
    final company = _companyId();
    if (company == null) return null;
    if (await _store.read(_companyKey) != '$company') return null;
    final token = await _store.read(_tokenKey);
    return token == null || token.isEmpty ? null : token;
  }

  /// Token bị từ chối (hết hạn): lấy token mới. Gọi cùng lúc thì dùng chung
  /// một lượt.
  Future<String?> renew() => _renewing ??= _renew().whenComplete(() {
    _renewing = null;
  });

  Future<String?> _renew() async {
    final company = _companyId();
    if (company == null) return null;
    final old = await token();
    final refresh = await _store.read(_refreshKey);
    if (old != null && refresh != null && refresh.isNotEmpty) {
      final next = await _refresh(refresh, old);
      if (next != null) {
        await signedIn(next);
        return next.idToken;
      }
    }
    final saved = await _saved.read();
    if (saved == null) return null;
    try {
      final next = await _login(saved.username, saved.password, company);
      await signedIn(next);
      return next.idToken;
    } on LoginException {
      return null;
    }
  }

  /// Đăng xuất: bỏ token.
  Future<void> clear() async {
    for (final k in [_tokenKey, _refreshKey, _companyKey]) {
      await _store.write(k, null);
    }
  }
}
