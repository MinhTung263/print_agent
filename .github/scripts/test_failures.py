"""Đọc báo cáo `flutter test --reporter json` (đường dẫn ở argv[1]) và in mỗi
test hỏng thành chú thích GitHub (::error) — xem được ở trang lần chạy / API
check-runs/annotations mà không cần quyền tải log. Thoát mã 1 nếu có test hỏng."""
import json
import sys

# Console Windows mặc định không phải UTF-8 — in chữ tiếng Việt sẽ lỗi.
sys.stdout.reconfigure(encoding='utf-8')

names, errors, failed = {}, {}, []
for line in open(sys.argv[1], encoding='utf-8', errors='replace'):
    try:
        e = json.loads(line)
    except ValueError:
        continue
    if not isinstance(e, dict):
        continue
    t = e.get('type')
    if t == 'testStart':
        names[e['test']['id']] = e['test']['name']
    elif t == 'error':
        errors.setdefault(e['testID'], []).append(
            (e.get('error') or '') + '\n' + (e.get('stackTrace') or ''))
    elif t == 'testDone' and e.get('result') != 'success' and not e.get('hidden'):
        failed.append(e['testID'])

for tid in failed:
    msg = '\n'.join(errors.get(tid, ['(không có chi tiết)']))[:3000]
    msg = msg.replace('%', '%25').replace('\r', '').replace('\n', '%0A')
    print(f"::error title=TEST HỎNG: {names.get(tid, tid)}::{msg}")
print(f'{len(failed)} test hỏng')
sys.exit(1 if failed else 0)
