// Chạy: node --test docs/test/login.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const { login, parseLogin, LoginError } = require('../login.js');

const ok = (data, status = true, reason) => ({ status, reason, data });

test('một công ty: lấy mã công ty và mã chủ', () => {
  const r = parseLogin(ok({ fullName: 'A', companies: [{ id: 12, companyOwnerId: 34, name: 'Quán A', address: 'HN' }] }), 'u');
  assert.equal(r.fullName, 'A');
  assert.deepEqual(r.companies, [{ id: 12, ownerId: 34, name: 'Quán A', address: 'HN' }]);
});

test('nhiều công ty: status false kèm danh sách vẫn là đăng nhập đúng', () => {
  const r = parseLogin(ok({ companies: [{ id: 1, companyOwnerId: 2 }, { id: 3 }] }, false, 'LOGIN_ERROR'), 'u');
  assert.equal(r.fullName, 'u');
  assert.deepEqual(r.companies.map((c) => [c.id, c.ownerId, c.name]), [[1, 2, 'Công ty 1'], [3, 0, 'Công ty 3']]);
});

test('sai mật khẩu → lỗi auth kèm lý do', () => {
  assert.throws(() => parseLogin({ status: false, reason: 'Sai mật khẩu', data: {} }, 'u'), (e) => e instanceof LoginError && e.code === 'auth' && e.message === 'Sai mật khẩu');
  assert.throws(() => parseLogin({ status: false }, 'u'), (e) => e.code === 'auth' && e.message === 'Đăng nhập không thành công');
});

test('đăng nhập đúng nhưng không có công ty → lỗi empty', () => {
  assert.throws(() => parseLogin(ok({ companies: [] }), 'u'), (e) => e.code === 'empty');
});

test('login gửi đúng yêu cầu và báo cors khi trình duyệt chặn', async () => {
  let seen;
  const fetchOk = async (url, init) => { seen = { url, init }; return { status: 200, json: async () => ok({ companies: [{ id: 5, companyOwnerId: 6 }] }) }; };
  const r = await login('u', 'p', fetchOk);
  assert.equal(seen.url, 'https://api.easypos.vn/api/client/common/authenticate');
  assert.deepEqual(JSON.parse(seen.init.body), { username: 'u', password: 'p' });
  assert.equal(r.companies[0].id, 5);
  await assert.rejects(login('u', 'p', async () => { throw new TypeError('Failed to fetch'); }), (e) => e.code === 'cors');
  await assert.rejects(login('u', 'p', async () => ({ status: 502, json: async () => { throw new Error('x'); } })), (e) => e.code === 'server');
});
