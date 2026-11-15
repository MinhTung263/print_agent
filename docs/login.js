/*
 * Đăng nhập tài khoản EasyPOS để biết công ty (mã + chủ) — giống `AuthService`
 * của Agent máy tính: KHÔNG giữ mật khẩu hay token, chỉ lấy danh sách công ty.
 * Máy chủ chỉ cho trang `https://*.easypos.vn` gọi (CORS) nên trang phải được
 * đặt dưới tên miền easypos.vn; nơi khác `login` ném lỗi `cors`.
 */
(function (g) {
  const HOST = 'https://api.easypos.vn';
  const PATH = '/api/client/common/authenticate';

  class LoginError extends Error {
    constructor(code, message) { super(message); this.code = code; }
  }

  /** Đọc phản hồi của API (tách riêng để test). Ném [LoginError] khi sai tài khoản. */
  function parseLogin(json, username) {
    const data = json && typeof json === 'object' && json.data && typeof json.data === 'object' ? json.data : null;
    const companies = [];
    if (data && Array.isArray(data.companies)) {
      for (const c of data.companies) {
        if (c && Number.isInteger(c.id)) {
          companies.push({
            id: c.id,
            ownerId: Number.isInteger(c.companyOwnerId) ? c.companyOwnerId : 0,
            name: c.name ? String(c.name) : `Công ty ${c.id}`,
            address: c.address ? String(c.address) : '',
          });
        }
      }
    }
    // Tài khoản nhiều công ty: API trả status:false KÈM danh sách công ty để chọn — coi là
    // đăng nhập đúng. Chỉ báo lỗi khi không có danh sách (sai tài khoản / mật khẩu).
    if (!data || (json.status !== true && !companies.length)) {
      const reason = json && json.reason ? String(json.reason) : '';
      throw new LoginError('auth', reason || 'Đăng nhập không thành công');
    }
    if (!companies.length) throw new LoginError('empty', 'Tài khoản chưa thuộc công ty nào');
    return { fullName: data.fullName ? String(data.fullName) : username, companies };
  }

  async function login(username, password, fetchFn) {
    const f = fetchFn || g.fetch.bind(g);
    let res;
    try {
      res = await f(HOST + PATH, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
      });
    } catch (_) {
      throw new LoginError('cors', 'Không gọi được máy chủ EasyPOS. Trang này chỉ đăng nhập được khi chạy dưới tên miền *.easypos.vn.');
    }
    let json;
    try { json = await res.json(); } catch (_) { throw new LoginError('server', `Máy chủ trả lỗi (${res.status})`); }
    return parseLogin(json, username);
  }

  g.EasyposLogin = { login, parseLogin, LoginError };
  if (typeof module !== 'undefined') module.exports = g.EasyposLogin;
})(typeof globalThis !== 'undefined' ? globalThis : window);
