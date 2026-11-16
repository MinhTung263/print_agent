/* Kênh hàng đợi in cho trình duyệt — khớp bản Dart (xem test/relay.test.js). */
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

  /**
   * Lệnh in tem (`PrintRelayJob.toMap`, kind label). [images]: mỗi ảnh (PNG base64,
   * không có tiền tố data:) là MỘT HÀNG tem; [labelSize]: tên khổ tem của app
   * (`single`, `single_40_30`, `double`...); [copies]: số lần in mỗi hàng.
   */
  function labelJob({ images, printer, stationId, labelSize, copies = 1, spec, sender = 'Web thử in' }) {
    const builtin = printer.type === 'builtin';
    return {
      kind: 'label',
      status: 'pending',
      createdAt: Date.now(),
      printerId: null,
      printerIp: builtin ? 'builtin' : printer.ip,
      printerType: builtin ? 'builtin' : 'lan',
      ...(stationId ? { targetStation: stationId } : {}),
      printerName: printer.name || null,
      sender,
      key: randomHex(12),
      labelSize,
      copies: Math.max(1, copies | 0),
      images,
      // Kích thước thật của hàng tem (mm): Agent máy tính dùng đúng số này (khổ app
      // chưa có tên vẫn in đúng); app bản cũ bỏ qua và dùng [labelSize].
      ...(spec ? { labelSpec: { w: spec.w, h: spec.h, gap: spec.gap, count: spec.count, shiftX: 0 } } : {}),
    };
  }

  /**
   * Trạm in còn "sống": thông tin trạm (retained trên broker, không tự mất khi trạm tắt)
   * kèm `at` = lúc trạm báo lần cuối. Trạm đang chạy báo lại mỗi 45s và khi có lệnh dò
   * (ping), nên quá [maxAgeMs] không thấy báo = trạm đã tắt / gỡ / cài lại với mã mới.
   * Thông tin cũ không có `at` (bản rất cũ) coi như còn sống — không giấu nhầm.
   */
  const STATION_MAX_AGE_MS = 150000;
  function stationFresh(info, now = Date.now(), maxAgeMs = STATION_MAX_AGE_MS) {
    const at = info && Number(info.at);
    if (!at) return true;
    return now - at <= maxAgeMs;
  }

  /**
   * Mã trạm cũ đã được thay: trạm đổi sang mã theo máy báo kèm `prev` = các mã cũ của nó (cài lại,
   * đổi cách sinh mã). Trạm cũ còn tin retained trên broker thì ẩn đi — chính là trạm này.
   */
  function replacedStationIds(stations) {
    const out = new Set();
    for (const info of stations.values()) {
      if (info && Array.isArray(info.prev)) for (const id of info.prev) if (typeof id === 'string' && id) out.add(id);
    }
    return out;
  }

  /**
   * Mục tiêu (0..1) của thanh tiến trình in: mỗi bước có một mốc, trong bước nhích dần tới mốc kế
   * (nhanh lúc đầu rồi chậm lại) nhưng KHÔNG chạm mốc kế — chỉ khi sang bước mới mới tới. Tăng
   * đều theo bước và theo thời gian, không bao giờ đứng yên, không lùi.
   */
  const PROGRESS_MARKS = [0.04, 0.22, 0.5, 0.78, 1];
  function progressTarget(step, msInStep, etaMs = 1500) {
    const i = Math.max(0, Math.min(PROGRESS_MARKS.length - 2, step | 0));
    const from = PROGRESS_MARKS[i], to = PROGRESS_MARKS[i + 1];
    const frac = 1 - Math.exp(-Math.max(0, msInStep) / Math.max(300, etaMs / 2));
    return from + (to - from) * 0.85 * frac;
  }

  g.PrintRelay = { PREFIX, progressTarget, replacedStationIds, stationFresh, STATION_MAX_AGE_MS, randomHex, normalizeEnv, shopKey, parseShopKey, channel, encrypt, decrypt, receiptJob, labelJob };
  if (typeof module !== 'undefined') module.exports = g.PrintRelay;
})(typeof globalThis !== 'undefined' ? globalThis : window);
