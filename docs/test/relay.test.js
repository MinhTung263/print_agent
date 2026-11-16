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

test('stationFresh: trạm báo gần đây còn sống, trạm báo từ lâu coi như đã tắt', () => {
  const now = 1_000_000;
  assert.equal(R.stationFresh({ at: now - 30_000 }, now), true);
  assert.equal(R.stationFresh({ at: now - 149_000 }, now), true);
  assert.equal(R.stationFresh({ at: now - 151_000 }, now), false);
  assert.equal(R.stationFresh({ at: now - 3 * 3600_000 }, now), false);
  // Thông tin rất cũ không có `at`: không giấu nhầm.
  assert.equal(R.stationFresh({ name: 'x' }, now), true);
  assert.equal(R.stationFresh(null, now), true);
});

test('replacedStationIds: gom mã cũ mà trạm mới báo đã thay', () => {
  const m = new Map([
    ['new1', { name: 'A', prev: ['old1', 'old2', ''] }],
    ['old1', { name: 'A' }],
    ['other', { name: 'B', prev: 'không phải mảng' }],
  ]);
  const r = R.replacedStationIds(m);
  assert.deepEqual([...r].sort(), ['old1', 'old2']);
  assert.equal(R.replacedStationIds(new Map()).size, 0);
});

test('progressTarget: tăng đều theo bước và theo thời gian, không lùi, không chạm 100% trước khi xong', () => {
  let prev = -1;
  for (let step = 0; step < 4; step++) {
    for (const ms of [0, 100, 400, 1500, 10000]) {
      const v = R.progressTarget(step, ms);
      assert.ok(v >= prev, `lùi ở bước ${step}, ${ms}ms: ${v} < ${prev}`);
      assert.ok(v < 1);
      prev = v;
    }
  }
  // Bước sau luôn cao hơn bước trước dù bước trước đã chờ rất lâu.
  assert.ok(R.progressTarget(1, 0) > R.progressTarget(0, 60000));
  assert.ok(R.progressTarget(3, 0) > R.progressTarget(2, 60000));
  // Vừa vào bước: nhích ngay (không đứng yên).
  assert.ok(R.progressTarget(2, 300) > R.progressTarget(2, 0));
});

test('printerOptions: nhận loại máy in (tem / hoá đơn) và gồm cả máy USB của trạm', () => {
  const info = {
    builtIn: { templates: ['label'] },
    printers: { names: [
      { name: 'Máy in tem · XP-420B', kind: 'lan', addr: '192.168.1.100', ok: true },
      { name: 'Máy in hoá đơn · Gprinter', kind: 'usb', addr: 'cups:EasyPOS_G', ok: true },
      { name: 'Máy in của trạm', kind: 'builtin', ok: true },
      { name: 'Không địa chỉ', kind: 'usb', ok: true },
    ] },
  };
  const o = R.printerOptions(info);
  assert.deepEqual(o.map((x) => [x.type, x.isLabel]), [['builtin', true], ['lan', true], ['usb', false]]);
  assert.equal(o[2].addr, 'cups:EasyPOS_G');
  assert.match(o[0].label, /máy in tem/);
  // Máy in của trạm là máy hoá đơn.
  assert.equal(R.printerOptions({ builtIn: { templates: ['temporaryPrintForm', 'paymentPrintingForm'] } })[0].isLabel, false);
  assert.deepEqual(R.printerOptions(null), []);
});

test('job tới máy USB của trạm mang địa chỉ cổng + loại usb', () => {
  const j = R.receiptJob({ imageBase64: 'x', printer: { type: 'usb', addr: 'cups:Q', name: 'G' }, stationId: 's1', paper: 'size80' });
  assert.equal(j.printerType, 'usb');
  assert.equal(j.printerIp, 'cups:Q');
  assert.equal(j.usbDeviceId, 'cups:Q');
  const l = R.labelJob({ images: ['x'], printer: { type: 'usb', addr: 'cups:T' }, stationId: 's1', labelSize: 'double' });
  assert.equal(l.printerType, 'usb');
  assert.equal(R.receiptJob({ imageBase64: 'x', printer: { type: 'builtin' }, paper: 'size80' }).printerType, 'builtin');
});
