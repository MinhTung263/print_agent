/*
 * Vẽ tem ly trà sữa (đen trắng, chữ đậm) lên canvas theo khổ tem — dùng cho trang
 * thử in. Mỗi ảnh là MỘT HÀNG tem (1 hoặc 2 tem); Trạm in co ảnh về đúng khổ giấy
 * (8 chấm = 1mm) nên chỉ cần đúng tỉ lệ.
 */
(function (g) {
  /**
   * Danh mục khổ tem theo SỐ TEM TRÊN MỘT HÀNG. `w x h` (mm) là cả hàng; `tem` là
   * khổ một tem. `name` khớp `LabelPerRow` của app EasyPOS; `custom: true` là khổ
   * app chưa có tên — chỉ Agent máy tính in đúng (đọc kích thước kèm trong lệnh).
   */
  const SIZES = [
    // 1 tem / hàng
    { name: 'single_35_22', count: 1, w: 35, h: 22, gap: 2, tem: '35×22', use: 'Tem giá, ly nhỏ' },
    { name: 'single_40_30', count: 1, w: 40, h: 30, gap: 2, tem: '40×30', use: 'Tem sản phẩm / ly trà sữa' },
    { name: 'single', count: 1, w: 50, h: 30, gap: 2, tem: '50×30', use: 'Tem sản phẩm' },
    { name: 'single_58_40', count: 1, w: 58, h: 40, gap: 2, tem: '58×40', use: 'Tem sản phẩm lớn' },
    { name: 'single_70_30', count: 1, w: 70, h: 30, gap: 2, tem: '70×30', use: 'Tem dài' },
    { name: 'single_60_80', count: 1, w: 60, h: 80, gap: 2, tem: '60×80', use: 'Tem dọc' },
    { name: 'single_100_100', count: 1, w: 100, h: 100, gap: 2, tem: '100×100', use: 'Tem thùng / vuông lớn' },
    { name: 'single_100_150', count: 1, w: 100, h: 150, gap: 2, tem: '100×150', use: 'Tem vận chuyển' },
    { name: 'single_102_152', count: 1, w: 102, h: 152, gap: 2, tem: '102×152', use: 'Tem giao hàng A6' },
    { name: 'single', custom: true, id: 'c_single_100_50', count: 1, w: 100, h: 50, gap: 2, tem: '100×50', use: 'Tem dán thùng carton' },
    // 2 tem / hàng
    { name: 'double', count: 2, w: 72, h: 22, gap: 1, tem: '35×22', use: 'Tem giá siêu thị / cửa hàng' },
    { name: 'double_38_25', count: 2, w: 81, h: 25, gap: 1, tem: '38×25', use: 'Tem giá nhỏ gọn' },
    { name: 'double_40_30', count: 2, w: 85, h: 30, gap: 1, tem: '40×30', use: 'Tem sản phẩm / ly trà sữa' },
    { name: 'double_46_34', count: 2, w: 97, h: 34, gap: 1, tem: '46×34', use: 'Tem sản phẩm' },
    { name: 'double_50_30', count: 2, w: 105, h: 30, gap: 1, tem: '50×30', use: 'Tem giá, mã vạch' },
    { name: 'double_50_50', count: 2, w: 105, h: 50, gap: 1, tem: '50×50', use: 'Tem vuông' },
    { name: 'double', custom: true, id: 'c_double_40_25', count: 2, w: 85, h: 25, gap: 1, tem: '40×25', use: 'Tem giá, mã vạch nhỏ' },
    { name: 'double', custom: true, id: 'c_double_50_40', count: 2, w: 105, h: 40, gap: 1, tem: '50×40', use: 'Tem sản phẩm' },
    // 3 tem / hàng
    { name: 'triple', count: 3, w: 106, h: 22, gap: 1, tem: '35×22', use: 'Tem nhỏ (trang sức, mỹ phẩm)' },
    { name: 'triple_26_26', count: 3, w: 85, h: 26, gap: 1, tem: '26×26', use: 'Tem nhỏ vuông' },
    { name: 'triple_30_30', count: 3, w: 101, h: 30, gap: 1, tem: '30×30', use: 'Tem nhỏ vuông' },
    { name: 'triple_35_25', count: 3, w: 112, h: 25, gap: 1, tem: '35×25', use: 'Tem mã vạch hàng hoá' },
    // 4 tem / hàng
    { name: 'triple', custom: true, id: 'c_quad_25_15', count: 4, w: 106, h: 15, gap: 2, tem: '25×15', use: 'Tem rất nhỏ (ống nghiệm, kho)' },
  ].map((z) => ({ ...z, id: z.id || z.name, title: `${z.tem}mm${z.custom ? ' · Agent máy tính' : ''}` }));

  const COUNTS = [1, 2, 3, 4];
  const bySize = (id) => SIZES.find((z) => z.id === id);
  const ofCount = (count) => SIZES.filter((z) => z.count === count);

  /** Vài ly mẫu để thử (xoay vòng khi in nhiều ly). */
  const MENU = [
    { name: 'Trà sữa trân châu đường đen', size: 'L', sugar: '70%', ice: '50%', toppings: 'Trân châu, Pudding', note: 'Ít ngọt', price: 45000 },
    { name: 'Trà đào cam sả', size: 'M', sugar: '100%', ice: '100%', toppings: 'Đào miếng', note: '', price: 39000 },
    { name: 'Matcha latte', size: 'L', sugar: '50%', ice: '70%', toppings: 'Kem cheese', note: 'Không đá', price: 49000 },
    { name: 'Hồng trà macchiato', size: 'M', sugar: '30%', ice: '100%', toppings: '', note: '', price: 42000 },
  ];

  const money = (v) => v.toLocaleString('vi-VN') + 'đ';

  /** Bẻ chữ theo bề rộng; quá [maxLines] dòng thì cắt và thêm "…". */
  function wrap(ctx, text, maxW, maxLines) {
    const words = String(text).split(/\s+/);
    const lines = [];
    let cur = '';
    for (const w of words) {
      const next = cur ? cur + ' ' + w : w;
      if (ctx.measureText(next).width <= maxW || !cur) cur = next;
      else { lines.push(cur); cur = w; }
    }
    if (cur) lines.push(cur);
    if (lines.length > maxLines) {
      lines.length = maxLines;
      let last = lines[maxLines - 1];
      while (last && ctx.measureText(last + '…').width > maxW) last = last.slice(0, -1);
      lines[maxLines - 1] = last + '…';
    }
    return lines;
  }

  /**
   * Vẽ MỘT tem vào ô (x, y, w, h) tính bằng chấm. [info]: {shop, order, time, index, total}.
   * Cỡ chữ theo chiều cao ô nên tem 22mm và 40mm đều cân đối.
   */
  /** Tem nhỏ (hẹp / thấp): chỉ giữ tên ly, cỡ, đường/đá, giá — chữ vẫn đủ đọc. */
  function drawSmall(ctx, w, h, item, info) {
    const k = Math.min(w / 260, h / 170);
    const pad = 6 * k + 3;
    const f = (px, weight = 'bold') => `${weight} ${Math.max(10, Math.round(px * k))}px "Helvetica Neue", Arial, sans-serif`;
    ctx.fillStyle = '#000'; ctx.strokeStyle = '#000'; ctx.textBaseline = 'top'; ctx.textAlign = 'left';
    ctx.lineWidth = Math.max(1.5, 2.5 * k);
    if (info.frame !== false) ctx.strokeRect(1, 1, w - 2, h - 2);
    ctx.font = f(22);
    const head = `#${info.order} · ${item.size}`;
    ctx.fillText(head, pad, pad);
    let cy = pad + 24 * k;
    ctx.font = f(26);
    wrap(ctx, item.name, w - pad * 2, 2).forEach((l) => { ctx.fillText(l, pad, cy); cy += 28 * k; });
    ctx.font = f(20, 'normal');
    ctx.fillText(`Đ${item.sugar} · Đá ${item.ice}`, pad, cy);
    ctx.font = f(24);
    ctx.textBaseline = 'bottom';
    ctx.fillText(money(item.price), pad, h - pad);
  }


  // ---- Mã vạch Code 128 (bảng mẫu chuẩn: 107 mẫu, mỗi mẫu 11 module; STOP 13) ----
  const C128 = ["11011001100", "11001101100", "11001100110", "10010011000", "10010001100", "10001001100", "10011001000", "10011000100", "10001100100", "11001001000", "11001000100", "11000100100", "10110011100", "10011011100", "10011001110", "10111001100", "10011101100", "10011100110", "11001110010", "11001011100", "11001001110", "11011100100", "11001110100", "11101101110", "11101001100", "11100101100", "11100100110", "11101100100", "11100110100", "11100110010", "11011011000", "11011000110", "11000110110", "10100011000", "10001011000", "10001000110", "10110001000", "10001101000", "10001100010", "11010001000", "11000101000", "11000100010", "10110111000", "10110001110", "10001101110", "10111011000", "10111000110", "10001110110", "11101110110", "11010001110", "11000101110", "11011101000", "11011100010", "11011101110", "11101011000", "11101000110", "11100010110", "11101101000", "11101100010", "11100011010", "11101111010", "11001000010", "11110001010", "10100110000", "10100001100", "10010110000", "10010000110", "10000101100", "10000100110", "10110010000", "10110000100", "10011010000", "10011000010", "10000110100", "10000110010", "11000010010", "11001010000", "11110111010", "11000010100", "10001111010", "10100111100", "10010111100", "10010011110", "10111100100", "10011110100", "10011110010", "11110100100", "11110010100", "11110010010", "11011011110", "11011110110", "11110110110", "10101111000", "10100011110", "10001011110", "10111101000", "10111100010", "11110101000", "11110100010", "10111011110", "10111101110", "11101011110", "11110101110", "11010000100", "11010010000", "11010011100", "1100011101011"];

  /** Chuỗi module (1 = vạch đen, 0 = trắng) của mã Code 128, KHÔNG có vùng trống. */
  function code128(text) {
    const s = String(text);
    const digits = /^\d+$/.test(s) && s.length % 2 === 0;
    const values = [];
    if (digits) {
      values.push(105); // START C — mỗi cặp số một ký hiệu (gọn hơn, quét chắc hơn)
      for (let i = 0; i < s.length; i += 2) values.push(parseInt(s.slice(i, i + 2), 10));
    } else {
      values.push(104); // START B
      for (const ch of s) { const c = ch.charCodeAt(0); values.push(c >= 32 && c <= 126 ? c - 32 : 31); }
    }
    let sum = values[0];
    for (let i = 1; i < values.length; i++) sum += values[i] * i;
    values.push(sum % 103, 106);
    return values.map((v) => C128[v]).join('');
  }

  /** Vẽ mã vạch vào ô (x, y, w, h): mỗi module là SỐ NGUYÊN chấm (nét sắc cho đầu in). */
  function drawBarcode(ctx, x, y, w, h, text) {
    const bits = code128(text);
    const quiet = 10; // vùng trống 10 module hai bên
    const mod = Math.max(1, Math.floor(w / (bits.length + quiet * 2)));
    const total = mod * bits.length;
    let px = x + Math.floor((w - total) / 2);
    ctx.fillStyle = '#000';
    for (let i = 0; i < bits.length; ) {
      let j = i;
      while (j < bits.length && bits[j] === bits[i]) j++;
      if (bits[i] === '1') ctx.fillRect(px, y, (j - i) * mod, h);
      px += (j - i) * mod;
      i = j;
    }
    return mod;
  }

  /** Hàng hoá mẫu (tem sản phẩm / quần áo). */
  const PRODUCTS = [
    { name: 'Áo Dài Truyền Thống', code: '12345678', price: 190000 },
    { name: 'Áo Sơ Mi Nam Công Sở', code: '20250101', price: 259000 },
    { name: 'Váy Hoa Nhí Dáng Xòe', code: 'SP00123', price: 320000 },
    { name: 'Quần Tây Âu Slim Fit', code: '88001234', price: 275000 },
  ];

  /** Co cỡ chữ cho vừa MỘT dòng trong [maxW] (không nhỏ hơn [minPx]). */
  function fitFont(ctx, text, maxW, startPx, minPx, weight) {
    let px = startPx;
    for (; px > minPx; px -= 1) {
      ctx.font = `${weight} ${px}px "Helvetica Neue", Arial, sans-serif`;
      if (ctx.measureText(text).width <= maxW) break;
    }
    ctx.font = `${weight} ${px}px "Helvetica Neue", Arial, sans-serif`;
    return px;
  }

  /**
   * Tem sản phẩm kiểu tem thị trường: tên hàng, mã vạch, số mã, "Giá: ... VND". Chừa
   * lề an toàn ~1,5mm quanh tem (đầu in / cuộn tem lệch nhẹ vẫn không cắt chữ).
   */
  function drawProduct(ctx, w, h, item) {
    const u = Math.min(h / 176, w / 288);
    const m = Math.round(12 * u) + 2;
    const inner = w - m * 2;
    ctx.fillStyle = '#000'; ctx.textBaseline = 'top'; ctx.textAlign = 'left';
    let y = Math.round(8 * u);
    // Tên hàng: một dòng, co chữ cho vừa; dài quá thì bẻ 2 dòng.
    ctx.font = `bold ${Math.round(23 * u)}px "Helvetica Neue", Arial, sans-serif`;
    if (ctx.measureText(item.name).width <= inner) {
      ctx.fillText(item.name, m, y); y += Math.round(28 * u);
    } else {
      const px = fitFont(ctx, item.name, inner, Math.round(23 * u), Math.round(17 * u), 'bold');
      if (ctx.measureText(item.name).width <= inner) { ctx.fillText(item.name, m, y); y += Math.round(28 * u); }
      else { wrap(ctx, item.name, inner, 2).forEach((l) => { ctx.fillText(l, m, y); y += Math.round(px * 1.15); }); }
    }
    // Mã vạch + số mã.
    const bh = Math.round(70 * u);
    drawBarcode(ctx, m, y + Math.round(2 * u), inner, bh, item.code);
    y += bh + Math.round(6 * u);
    ctx.textAlign = 'center';
    ctx.font = `normal ${Math.round(21 * u)}px "Helvetica Neue", Arial, sans-serif`;
    ctx.fillText(item.code, w / 2, y);
    // Giá ở chân tem.
    ctx.textAlign = 'left';
    const price = `Giá: ${item.price.toLocaleString('vi-VN')} VND`;
    fitFont(ctx, price, inner, Math.round(25 * u), Math.round(16 * u), 'bold');
    ctx.textBaseline = 'bottom';
    ctx.fillText(price, m, h - Math.round(8 * u));
  }

  function drawOne(ctx, x, y, w, h, item, info) {
    if (w < 260 || h < 170) {
      ctx.save(); ctx.translate(x, y); drawSmall(ctx, w, h, item, info); ctx.restore();
      return;
    }
    const k = h / 240; // 240 chấm = tem cao 30mm
    const pad = 10 * k + 4;
    const font = (px, weight = 'normal', style = '') => `${style} ${weight} ${Math.max(11, Math.round(px * k))}px "Helvetica Neue", Arial, sans-serif`.trim();
    ctx.save();
    ctx.translate(x, y);
    ctx.fillStyle = '#000';
    ctx.strokeStyle = '#000';
    ctx.textBaseline = 'top';
    ctx.lineWidth = Math.max(2, 3 * k);
    if (info.frame !== false) ctx.strokeRect(1, 1, w - 2, h - 2);

    // Dòng đầu: tên quán + số đơn (khung đen chữ trắng cho dễ thấy).
    const headH = 34 * k + 6;
    ctx.font = font(22, 'bold');
    const order = `#${info.order}`;
    const orderW = ctx.measureText(order).width + pad * 1.5;
    ctx.fillRect(w - orderW - 2, 2, orderW, headH);
    ctx.fillStyle = '#fff';
    ctx.textAlign = 'center';
    ctx.fillText(order, w - orderW / 2 - 2, 2 + (headH - 22 * k) / 2);
    ctx.fillStyle = '#000';
    ctx.textAlign = 'left';
    ctx.font = font(20, 'bold');
    ctx.fillText(info.shop.toUpperCase(), pad, 2 + (headH - 20 * k) / 2);

    // Tên ly (tối đa 2 dòng) + cỡ ly trong ô tròn.
    let cy = headH + 8 * k;
    const sizeBox = 40 * k + 4;
    ctx.font = font(30, 'bold');
    const nameLines = wrap(ctx, item.name, w - pad * 2 - sizeBox - 8, 2);
    nameLines.forEach((l) => { ctx.fillText(l, pad, cy); cy += 34 * k; });
    ctx.beginPath();
    ctx.arc(w - pad - sizeBox / 2, headH + 8 * k + sizeBox / 2, sizeBox / 2, 0, Math.PI * 2);
    ctx.lineWidth = Math.max(2, 3 * k); ctx.stroke();
    ctx.textAlign = 'center';
    ctx.font = font(28, 'bold');
    ctx.fillText(item.size, w - pad - sizeBox / 2, headH + 8 * k + (sizeBox - 28 * k) / 2);
    ctx.textAlign = 'left';

    // Đường / đá, topping, ghi chú — xếp dưới ô tròn cỡ ly (không đè), và chỉ vẽ dòng
    // nào còn vừa chỗ trước chân tem (thiếu chỗ thì bỏ dòng cuối, không chồng chữ).
    const footY = h - 34 * k - pad;
    const limit = footY - 8 * k;
    cy = Math.max(cy + 2 * k, headH + 8 * k + sizeBox + 6 * k);
    const detail = [
      { text: `Đường ${item.sugar}  ·  Đá ${item.ice}`, font: font(24, 'bold'), step: 28 },
      ...(item.toppings ? [{ text: '+ ' + item.toppings, font: font(22), step: 26 }] : []),
      ...(item.note ? [{ text: '* ' + item.note, font: font(22, 'bold', 'italic'), step: 26 }] : []),
    ];
    for (const d of detail) {
      if (cy + d.step * k > limit) break;
      ctx.font = d.font;
      wrap(ctx, d.text, w - pad * 2, 1).forEach((l) => { ctx.fillText(l, pad, cy); });
      cy += d.step * k;
    }

    // Chân tem: giá + giờ + số thứ tự ly.
    ctx.lineWidth = Math.max(1, 2 * k);
    ctx.beginPath(); ctx.moveTo(pad, footY - 4 * k); ctx.lineTo(w - pad, footY - 4 * k); ctx.stroke();
    ctx.font = font(30, 'bold');
    ctx.fillText(money(item.price), pad, footY);
    ctx.font = font(20);
    ctx.textAlign = 'right';
    ctx.fillText(`${info.index}/${info.total}  ${info.time}`, w - pad, footY + 6 * k);
    ctx.restore();
  }

  /**
   * Vẽ một hàng tem lên canvas [cv]: [items] (tối đa size.count ly; thiếu thì để
   * trống ô còn lại). [info]: {shop, order, time, total, startIndex}.
   */
  /**
   * Ép ảnh về ĐEN / TRẮNG thuần (ngưỡng 128 — cùng ngưỡng Trạm in dùng khi in): ảnh nhẹ
   * hơn nhiều lần (nét khử răng cưa nặng ~25–60KB, đen trắng ~3–8KB) nên gửi qua
   * cloud nhanh hơn và đỡ tốn băng thông; xem trước cũng là đúng cái sẽ in ra.
   */
  function binarize(cv) {
    const ctx = cv.getContext('2d');
    const im = ctx.getImageData(0, 0, cv.width, cv.height);
    const d = im.data;
    for (let i = 0; i < d.length; i += 4) {
      const gray = 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2];
      const v = d[i + 3] > 50 && gray < 128 ? 0 : 255;
      d[i] = d[i + 1] = d[i + 2] = v; d[i + 3] = 255;
    }
    ctx.putImageData(im, 0, 0);
    return cv;
  }

  function drawRow(cv, size, items, info, template = 'tea') {
    const W = size.w * 8, H = size.h * 8;
    cv.width = W; cv.height = H;
    const ctx = cv.getContext('2d');
    ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, W, H);
    const cell = W / size.count;
    items.slice(0, size.count).forEach((item, i) => {
      if (template === 'product') {
        ctx.save(); ctx.translate(i * cell, 0); drawProduct(ctx, cell, H, item); ctx.restore();
      } else {
        drawOne(ctx, i * cell + 6, 4, cell - 12, H - 8, item, { ...info, index: (info.startIndex || 1) + i });
      }
    });
    return binarize(cv);
  }

  /** Chia [cups] ly thành các hàng tem: [[item...], ...] lấy xoay vòng từ [MENU]. */
  function rows(cups, size, template = 'tea') {
    const menu = template === 'product' ? PRODUCTS : MENU;
    const items = Array.from({ length: cups }, (_, i) => menu[i % menu.length]);
    const out = [];
    for (let i = 0; i < items.length; i += size.count) out.push(items.slice(i, i + size.count));
    return out;
  }

  const TEMPLATES = [
    { id: 'tea', title: 'Tem ly trà sữa' },
    { id: 'product', title: 'Tem sản phẩm (mã vạch)' },
  ];

  g.TeaLabel = { SIZES, COUNTS, MENU, PRODUCTS, TEMPLATES, bySize, ofCount, drawRow, rows, wrap, code128, drawBarcode, binarize };
  if (typeof module !== 'undefined') module.exports = g.TeaLabel;
})(typeof globalThis !== 'undefined' ? globalThis : window);
