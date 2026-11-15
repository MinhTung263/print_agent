/*
 * Lấy mã cửa hàng (môi trường, mã công ty, mã chủ) từ chuỗi người dùng dán vào:
 * lệnh curl ("Copy as cURL" trong F12 → Network), JSON phản hồi đăng nhập, hoặc
 * mã cửa hàng dạng `production/c12_34`. Chỉ ĐỌC chuỗi trong trình duyệt, không gửi
 * đi đâu; mật khẩu / token trong curl không được lưu.
 */
(function (g) {
  const KEYS = {
    company: /^(company_?id|companyid|cid)$/i,
    owner: /^(company_?owner_?id|owner_?id|companyownerid)$/i,
  };

  function decodeJwt(token) {
    try {
      const p = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
      const json = decodeURIComponent(escape(atob(p + '='.repeat((4 - (p.length % 4)) % 4))));
      return JSON.parse(json);
    } catch (_) { return null; }
  }

  function scan(value, out, depth = 0) {
    if (depth > 6 || value === null || typeof value !== 'object') return;
    if (Array.isArray(value)) { value.forEach((v) => scan(v, out, depth + 1)); return; }
    for (const [k, v] of Object.entries(value)) {
      const n = typeof v === 'string' && /^\d+$/.test(v) ? +v : v;
      if (Number.isInteger(n) && n > 0) {
        if (KEYS.company.test(k) && out.company == null) out.company = n;
        else if (KEYS.owner.test(k) && out.owner == null) out.owner = n;
      }
      // Danh sách công ty ({id, companyOwnerId}) — lấy công ty đầu tiên.
      if (k === 'companies' && Array.isArray(v) && v[0] && Number.isInteger(v[0].id) && out.company == null) {
        out.company = v[0].id;
        if (Number.isInteger(v[0].companyOwnerId)) out.owner = v[0].companyOwnerId;
        out.companies = v.length;
      }
      scan(v, out, depth + 1);
    }
  }

  /** Trả {env, companyId, ownerId} — trường nào không thấy là null. */
  function parseShop(text) {
    const s = String(text || '').trim();
    const res = { env: null, companyId: null, ownerId: null, companies: 0 };
    if (!s) return res;
    const key = /\b([a-z0-9_]+)\/c(\d+)_(\d+)\b/.exec(s);
    if (key) return { env: key[1], companyId: +key[2], ownerId: +key[3], companies: 0 };

    const out = {};
    // JSON nằm trong curl (--data-raw '...') hoặc dán thẳng.
    const objs = [];
    if (s.startsWith('{') || s.startsWith('[')) objs.push(s);
    for (const m of s.matchAll(/(?:--data(?:-raw|-binary)?|-d)\s+\$?(['"])([\s\S]*?)\1(?:\s|$)/g)) objs.push(m[2]);
    for (const o of objs) { try { scan(JSON.parse(o), out); } catch (_) {} }
    // Token JWT (Authorization: Bearer ...).
    for (const m of s.matchAll(/eyJ[\w-]+\.[\w-]+\.[\w-]*/g)) { const p = decodeJwt(m[0]); if (p) scan(p, out); }
    // Header / query / đường dẫn dạng companyId=12, 'companyId: 12', "companyId":12.
    const grab = (re) => { const m = re.exec(s); return m ? +m[1] : null; };
    if (out.company == null) out.company = grab(/company[_-]?id["'\s:=]+(\d+)/i);
    if (out.owner == null) out.owner = grab(/(?:company[_-]?)?owner[_-]?id["'\s:=]+(\d+)/i);
    const host = /https?:\/\/([^\/\s'"]+)/.exec(s);
    if (host) {
      const h = host[1].toLowerCase();
      if (h === 'api.easypos.vn' || h === 'app.easypos.vn') res.env = 'production';
    }
    res.companyId = out.company ?? null; res.ownerId = out.owner ?? null; res.companies = out.companies || 0;
    return res;
  }

  g.CurlShop = { parseShop };
  if (typeof module !== 'undefined') module.exports = g.CurlShop;
})(typeof globalThis !== 'undefined' ? globalThis : window);
