// Chạy: node --test docs/test/curl.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const { parseShop } = require('../curl.js');

const jwt = (p) => `eyJhbGciOiJIUzI1NiJ9.${Buffer.from(JSON.stringify(p)).toString('base64url')}.sig`;

test('mã cửa hàng dán thẳng', () => {
  assert.deepEqual(parseShop('production/c12_34'), { env: 'production', companyId: 12, ownerId: 34, companies: 0 });
});

test('curl có JWT chứa mã công ty và mã chủ', () => {
  const t = jwt({ sub: 'u', companyId: 12, companyOwnerId: 34 });
  const r = parseShop(`curl 'https://api.easypos.vn/api/x' -H 'authorization: Bearer ${t}' -H 'accept: */*'`);
  assert.equal(r.companyId, 12); assert.equal(r.ownerId, 34); assert.equal(r.env, 'production');
});

test('curl có header / query companyId', () => {
  const r = parseShop(`curl 'https://api.easypos.vn/api/list?companyId=77&page=1' -H 'x-company-id: 77'`);
  assert.equal(r.companyId, 77); assert.equal(r.ownerId, null);
});

test('JSON phản hồi đăng nhập có danh sách công ty', () => {
  const r = parseShop(JSON.stringify({ status: false, data: { companies: [{ id: 5, companyOwnerId: 6 }, { id: 7, companyOwnerId: 8 }] } }));
  assert.equal(r.companyId, 5); assert.equal(r.ownerId, 6); assert.equal(r.companies, 2);
});

test('body JSON trong curl', () => {
  const r = parseShop(`curl 'https://api.easypos.vn/api/x' --data-raw '{"companyId":9,"ownerId":10}'`);
  assert.equal(r.companyId, 9); assert.equal(r.ownerId, 10);
});

test('không có gì → null, không ném lỗi', () => {
  assert.deepEqual(parseShop('curl https://example.com'), { env: null, companyId: null, ownerId: null, companies: 0 });
  assert.deepEqual(parseShop(''), { env: null, companyId: null, ownerId: null, companies: 0 });
  assert.equal(parseShop('eyJxxx.yyy.zzz').companyId, null);
});
