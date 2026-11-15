/*
 * Giao thức hàng đợi in của EasyPOS (kênh MQTT) cho trình duyệt — GIỐNG HỆT
 * `MqttPrintRelayTransport` (packages/print_agent_core):
 *   secret = "easypos-print-relay-v1|{môi trường}/c{công ty}_{chủ}"
 *   topic  = "easypos/print_relay/" + sha256("topic|" + secret)[0..32 hex]
 *   khoá   = sha256("key|" + secret)  (AES-256-GCM)
 *   gói    = base64( iv(12) + mã hoá + tag(16) ), nội dung là JSON.
 * Chạy được cả trình duyệt lẫn Node (test: test/relay.test.js).
 */
(function (g) {
  const te = new TextEncoder();
  const td = new TextDecoder();
  const PREFIX = 'easypos/print_relay';

  const toHex = (u8) => [...u8].map((x) => x.toString(16).padStart(2, '0')).join('');
  const toB64 = (u8) => {
    let s = '';
    for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode(...u8.subarray(i, i + 0x8000));
    return btoa(s);
  };
  const fromB64 = (s) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
  const sha256 = async (s) => new Uint8Array(await crypto.subtle.digest('SHA-256', te.encode(s)));

  function randomHex(bytes) {
    return toHex(crypto.getRandomValues(new Uint8Array(bytes)));
  }

  /** `production` / `staging`... (ký tự lạ → `_`, chữ thường). */
  const normalizeEnv = (env) => String(env).replace(/[^A-Za-z0-9]+/g, '_').toLowerCase();

  /** Mã cửa hàng: `{môi trường}/c{công ty}_{chủ}`. */
  const shopKey = (env, companyId, ownerId) => `${normalizeEnv(env)}/c${companyId}_${ownerId}`;

  /** Tách `production/c12_34` → {env, companyId, ownerId}; `null` khi sai dạng. */
  function parseShopKey(key) {
    const m = /^([a-z0-9_]+)\/c(\d+)_(\d+)$/.exec(String(key || ''));
    return m ? { env: m[1], companyId: +m[2], ownerId: +m[3] } : null;
  }

  /** Kênh của một cửa hàng: topic gốc + khoá mã hoá. */
  async function channel(key) {
    const secret = `easypos-print-relay-v1|${key}`;
    const root = `${PREFIX}/${toHex(await sha256(`topic|${secret}`)).slice(0, 32)}`;
    const raw = await sha256(`key|${secret}`);
    const cryptoKey = await crypto.subtle.importKey('raw', raw, 'AES-GCM', false, ['encrypt', 'decrypt']);
    return { root, key: cryptoKey };
  }

  async function encrypt(ch, data, iv) {
    iv = iv || crypto.getRandomValues(new Uint8Array(12));
    const ct = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, ch.key, te.encode(JSON.stringify(data))));
    const out = new Uint8Array(12 + ct.length);
    out.set(iv);
    out.set(ct, 12);
    return toB64(out);
  }

  /** `null` khi không giải mã được (khoá khác / bị sửa / gói rác) hoặc gói rỗng. */
  async function decrypt(ch, payload) {
    try {
      const text = typeof payload === 'string' ? payload : td.decode(payload);
      if (!text) return null;
      const raw = fromB64(text);
      if (raw.length < 13) return null;
      const plain = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: raw.subarray(0, 12) }, ch.key, raw.subarray(12));
      return JSON.parse(td.decode(plain));
    } catch (_) {
      return null;
    }
  }

  /**
   * Lệnh in hoá đơn (`PrintRelayJob.toMap`). `printer`: {type: 'builtin'|'lan', ip, name}.
   * `stationId`: mã Agent đích (`id` trong thông tin trạm).
   */
  function receiptJob({ imageBase64, printer, stationId, paper, copies = 1, beep = false, openDrawer = false, sender = 'Web thử in' }) {
    const builtin = printer.type === 'builtin';
    return {
      kind: 'receipt',
      status: 'pending',
      createdAt: Date.now(),
      printerId: null,
      printerIp: builtin ? 'builtin' : printer.ip,
      printerType: builtin ? 'builtin' : 'lan',
      ...(stationId ? { targetStation: stationId } : {}),
      printerName: printer.name || null,
      sender,
      key: randomHex(12),
      ...(beep ? { beep: true } : {}),
      size: paper,
      quantity: Math.max(1, copies | 0),
      openDrawer,
      image: imageBase64,
    };
  }

  g.PrintRelay = { PREFIX, randomHex, normalizeEnv, shopKey, parseShopKey, channel, encrypt, decrypt, receiptJob };
  if (typeof module !== 'undefined') module.exports = g.PrintRelay;
})(typeof globalThis !== 'undefined' ? globalThis : window);
