// Chạy: node --test docs/test/relay.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const R = require('../relay.js');

// Mẫu do chính code Dart của Agent (MqttPrintRelayTransport) sinh ra.
const VEC = {
  topic: 'easypos/print_relay/da005c2e0e758a182e16c39c5530ef12',
  payload: 'AAECAwQFBgcICQoL3osMrrmUINQAwC8p3lMT8PgyKBnVo4IASxmNLsZdSL90i0oA7B/0',
  data: { a: 'xin chào', n: 5 },
};

test('shopKey chuẩn hoá môi trường', () => {
  assert.equal(R.shopKey('Production', 123, 456), 'production/c123_456');
  assert.equal(R.shopKey('Test 88', 1, 2), 'test_88/c1_2');
  assert.deepEqual(R.parseShopKey('production/c123_456'), { env: 'production', companyId: 123, ownerId: 456 });
  assert.equal(R.parseShopKey('xyz'), null);
});

test('topic giống Dart', async () => {
  const ch = await R.channel('production/c123_456');
  assert.equal(ch.root, VEC.topic);
});

test('giải mã gói do Dart mã hoá', async () => {
  const ch = await R.channel('production/c123_456');
  assert.deepEqual(await R.decrypt(ch, VEC.payload), VEC.data);
});

test('mã hoá với iv cố định ra đúng gói của Dart', async () => {
  const ch = await R.channel('production/c123_456');
  const iv = Uint8Array.from({ length: 12 }, (_, i) => i);
  assert.equal(await R.encrypt(ch, VEC.data, iv), VEC.payload);
});

test('khoá khác / gói rác / gói rỗng → null', async () => {
  const other = await R.channel('production/c999_456');
  assert.equal(await R.decrypt(other, VEC.payload), null);
  const ch = await R.channel('production/c123_456');
  assert.equal(await R.decrypt(ch, 'rac-rac'), null);
  assert.equal(await R.decrypt(ch, ''), null);
});

test('lệnh in có đủ trường Agent đọc (PrintRelayJob.fromMap)', () => {
  const j = R.receiptJob({ imageBase64: 'AAA', printer: { type: 'builtin', name: 'Máy in' }, stationId: 'st1', paper: 'size58', copies: 2, beep: true });
  assert.equal(j.kind, 'receipt');
  assert.equal(j.printerIp, 'builtin');
  assert.equal(j.printerType, 'builtin');
  assert.equal(j.targetStation, 'st1');
  assert.equal(j.size, 'size58');
  assert.equal(j.quantity, 2);
  assert.equal(j.beep, true);
  assert.equal(j.image, 'AAA');
  assert.equal(j.key.length, 24);
  const lan = R.receiptJob({ imageBase64: 'A', printer: { type: 'lan', ip: '192.168.0.9' }, paper: 'size80' });
  assert.equal(lan.printerIp, '192.168.0.9');
  assert.equal(lan.printerType, 'lan');
  assert.equal('targetStation' in lan, false);
});

test('lệnh in tem có đủ trường Agent đọc (PrintRelayJob.fromMap, kind label)', () => {
  const j = R.labelJob({ images: ['AAA', 'BBB'], printer: { type: 'lan', ip: '192.168.0.9', name: 'Tem' }, stationId: 'st1', labelSize: 'single_40_30', copies: 2 });
  assert.equal(j.kind, 'label');
  assert.equal(j.printerType, 'lan');
  assert.equal(j.printerIp, '192.168.0.9');
  assert.equal(j.targetStation, 'st1');
  assert.equal(j.labelSize, 'single_40_30');
  assert.equal(j.copies, 2);
  assert.deepEqual(j.images, ['AAA', 'BBB']);
  assert.equal('image' in j, false);
  assert.equal(R.labelJob({ images: [], printer: { type: 'builtin' }, labelSize: 'single', copies: 0 }).copies, 1);
});

test('lệnh in tem kèm kích thước thật (labelSpec) cho Agent máy tính', () => {
  const j = R.labelJob({ images: ['A'], printer: { type: 'lan', ip: '10.0.0.5' }, labelSize: 'double', spec: { w: 105, h: 40, gap: 1, count: 2 } });
  assert.deepEqual(j.labelSpec, { w: 105, h: 40, gap: 1, count: 2, shiftX: 0 });
  assert.equal('labelSpec' in R.labelJob({ images: ['A'], printer: { type: 'builtin' }, labelSize: 'single' }), false);
});
