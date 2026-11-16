// Chạy: node --test docs/test/tem.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const T = require('../tem.js');

test('khổ tem khớp tên LabelPerRow của app', () => {
  const names = T.SIZES.map((z) => z.name);
  for (const n of ['single', 'single_35_22', 'single_40_30', 'single_58_40', 'double', 'double_40_30', 'triple', 'triple_30_30']) assert.ok(names.includes(n), n);
  for (const z of T.SIZES) assert.ok([1, 2, 3, 4].includes(z.count), z.id);
});

test('danh mục có đủ 1–4 tem mỗi hàng và các khổ phổ biến', () => {
  for (const c of T.COUNTS) assert.ok(T.ofCount(c).length > 0, `${c} tem/hàng`);
  const has = (count, tem) => T.ofCount(count).some((z) => z.tem === tem);
  for (const t of ['40×30', '58×40', '100×50', '100×100', '102×152']) assert.ok(has(1, t), `1 tem ${t}`);
  for (const t of ['35×22', '50×30', '50×40', '40×25']) assert.ok(has(2, t), `2 tem ${t}`);
  assert.ok(has(4, '25×15'));
});

test('id khổ tem là duy nhất; khổ tuỳ chỉnh dùng tên gần nhất của app', () => {
  const ids = T.SIZES.map((z) => z.id);
  assert.equal(new Set(ids).size, ids.length);
  for (const z of T.SIZES.filter((s) => s.custom)) assert.ok(z.name && z.w > 0 && z.h > 0, z.id);
  assert.equal(T.bySize('c_double_50_40').w, 105);
});

test('chia ly thành các hàng tem theo số tem mỗi hàng', () => {
  const one = T.bySize('single');
  const two = T.bySize('double');
  assert.deepEqual(T.rows(3, one).map((r) => r.length), [1, 1, 1]);
  assert.deepEqual(T.rows(3, two).map((r) => r.length), [2, 1]);
  assert.deepEqual(T.rows(5, two).map((r) => r.length), [2, 2, 1]);
  // Xoay vòng thực đơn mẫu.
  assert.equal(T.rows(5, one)[4][0], T.MENU[0]);
});

test('bẻ chữ tối đa N dòng, quá thì thêm …', () => {
  const ctx = { measureText: (t) => ({ width: t.length * 10 }) };
  assert.deepEqual(T.wrap(ctx, 'trà sữa trân châu', 1000, 2), ['trà sữa trân châu']);
  const lines = T.wrap(ctx, 'trà sữa trân châu đường đen thơm ngon', 120, 2);
  assert.equal(lines.length, 2);
  assert.ok(lines[1].endsWith('…'));
  assert.ok(lines.every((l) => l.length * 10 <= 120));
});
