#!/usr/bin/env bash
# ==============================================================================
# TRẠM IN EASYPOS - BUILD THỬ (không phát hành)
# ==============================================================================
# Chạy CI trên GitHub cho commit hiện tại (Windows + Linux + macOS), đợi xong rồi TẢI bộ cài về
# ~/Downloads/easypos-print-agent-build/<windows|linux|macos>/ để cài thử. Khách KHÔNG nhận bản này.
#
#   ./build.sh            # build commit đã push lên main (đẩy main trước nếu chưa)
#   ./build.sh --no-wait  # chỉ chạy CI, không chờ / không tải
# ==============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
REPO="MinhTung263/print_agent"
OUT="$HOME/Downloads/easypos-print-agent-build"
WAIT=1; [ "${1:-}" = "--no-wait" ] && WAIT=0

say() { printf '\033[1;34m▶ %s\033[0m\n' "$*"; }
ok()  { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

command -v gh >/dev/null || die "Cần cài GitHub CLI (gh) và đăng nhập: gh auth login"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
git fetch -q origin "$BRANCH" 2>/dev/null || true
if [ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$BRANCH" 2>/dev/null || echo none)" ]; then
  die "Commit hiện tại chưa có trên origin/$BRANCH — commit và push trước (CI build code đã push, không build code trên máy)."
fi
SHA="$(git rev-parse HEAD)"

say "Chạy CI cho ${SHA:0:7} (nhánh $BRANCH)…"
gh workflow run CI -R "$REPO" --ref "$BRANCH" >/dev/null
sleep 10
RUN_ID="$(gh run list -R "$REPO" --workflow CI --branch "$BRANCH" --limit 1 --json databaseId -q '.[0].databaseId')"
[ -n "$RUN_ID" ] || die "Không thấy lượt chạy CI"
echo "  https://github.com/$REPO/actions/runs/$RUN_ID"
[ "$WAIT" = 1 ] || { ok "Đã chạy CI (không chờ)."; exit 0; }

say "Chờ build (khoảng 10–15 phút)…"
gh run watch "$RUN_ID" -R "$REPO" --exit-status --interval 20 >/dev/null 2>&1 || die "CI lỗi — xem link ở trên."

say "Tải bộ cài về $OUT"
rm -rf "$OUT"; mkdir -p "$OUT/windows" "$OUT/linux" "$OUT/macos"
gh run download "$RUN_ID" -R "$REPO" -n easypos-print-agent-windows-setup -D "$OUT/windows"
gh run download "$RUN_ID" -R "$REPO" -n easypos-print-agent-linux-deb -D "$OUT/linux"
gh run download "$RUN_ID" -R "$REPO" -n easypos-print-agent-macos-dmg -D "$OUT/macos"
ok "Xong:"
find "$OUT" -type f | sed 's/^/  /'
command -v open >/dev/null && open "$OUT" || true
