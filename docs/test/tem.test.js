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

// Mẫu do thư viện JsBarcode 3.11.6 sinh ra (Code 128): so từng module.
test('mã vạch Code 128 khớp mẫu chuẩn (Code C cho số chẵn, Code B cho chữ)', () => {
  assert.equal(T.code128('12345678'), "1101001110010110011100100010110001110001011011000010100100011101101100011101011");
  assert.equal(T.code128('20250101'), "1101001110011001001110111001011001100110110011001101100100011110101100011101011");
  assert.equal(T.code128('SP00123'), "1101001000011011101000111011101101001110110010011101100100111001101100111001011001011100100110100001100011101011");
  assert.equal(T.code128('Ab-9 z'), "11010010000101000110001001000011010011011100111001011001101100110011011110110110111001001100011101011");
});

test('mã vạch: bắt đầu START, kết thúc STOP 13 module, chỉ có 0/1', () => {
  const c = T.code128('12345678');
  assert.ok(c.startsWith('11010011100'), 'START C');
  assert.ok(c.endsWith('1100011101011'), 'STOP');
  assert.match(c, /^[01]+$/);
  // START(11) + 4 cặp số(44) + kiểm tra(11) + STOP(13).
  assert.equal(c.length, 11 + 44 + 11 + 13);
  assert.ok(T.code128('SP00123').startsWith('11010010000'), 'START B');
});

test('tem sản phẩm: rows dùng hàng hoá mẫu, 2 tem/hàng', () => {
  const two = T.bySize('double');
  const r = T.rows(3, two, 'product');
  assert.deepEqual(r.map((x) => x.length), [2, 1]);
  assert.equal(r[0][0].name, 'Áo Dài Truyền Thống');
  assert.equal(r[0][0].code, '12345678');
  assert.deepEqual(T.TEMPLATES.map((t) => t.id), ['tea', 'product', 'jewelry']);
});

test('tem vàng bạc: có khổ 50×12, rows lấy hàng trang sức mẫu', () => {
  const z = T.bySize(T.JEWELRY_DEFAULT);
  assert.ok(z && z.jewelry && z.w === 50 && z.h === 12 && z.count === 1);
  const r = T.rows(3, z, 'jewelry');
  assert.equal(r.length, 3);
  assert.ok(r[0][0].karat && r[0][0].weight && r[0][0].code);
});

test('drawQr: không có thư viện qrcode thì bỏ qua, không lỗi', () => {
  assert.equal(T.drawQr({}, 0, 0, 80, 'abc'), 0);
});
