#!/usr/bin/env bash
# ==============================================================================
# TRẠM IN EASYPOS - PHÁT HÀNH BẢN MỚI (Windows + Linux + macOS)
# ==============================================================================
# Một lệnh: tăng số phiên bản → commit → đẩy main → gắn tag vX.Y.Z → CI build + phát hành lên
# GitHub Releases → in link tải. Các Agent đã cài tự cập nhật (xem apps/desktop/installer/RELEASE.md).
#
#   ./release.sh                    # hỏi kiểu tăng (patch / minor / major / nhập tay)
#   ./release.sh patch|minor|major  # tăng luôn: 0.1.0+1 → 0.1.1+2
#   ./release.sh 0.3.0              # đặt đúng số phiên bản (build tự +1)
#   Thêm:  --yes (không hỏi xác nhận)   --dry-run (chỉ in việc sẽ làm)   --skip-tests (bỏ chạy test)
#
# Chỉ commit file apps/desktop/pubspec.yaml — không đụng thay đổi dở khác của bạn
# (kể cả khối "TẠM" trong pubspec.yaml gốc).
# ==============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
PUBSPEC="apps/desktop/pubspec.yaml"
REPO="MinhTung263/print_agent"

YES=0; DRY=0; SKIP_TESTS=0; ARG=""
for a in "$@"; do
  case "$a" in
    --yes|-y) YES=1 ;;
    --dry-run) DRY=1 ;;
    --skip-tests) SKIP_TESTS=1 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) ARG="$a" ;;
  esac
done

say()  { printf '\033[1;34m▶ %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }
run()  { if [ "$DRY" = 1 ]; then printf '  [dry-run] %s\n' "$*"; else "$@"; fi; }

# --- phiên bản hiện tại: "0.1.0+1" ---
CUR_LINE="$(sed -n -E 's/^version:[[:space:]]*([^[:space:]#]+).*/\1/p' "$PUBSPEC" | head -n1)"
[ -n "$CUR_LINE" ] || die "Không đọc được version trong $PUBSPEC"
CUR_VER="${CUR_LINE%%+*}"
CUR_BUILD="0"; [[ "$CUR_LINE" == *+* ]] && CUR_BUILD="${CUR_LINE##*+}"
IFS='.' read -r MAJ MIN PAT <<<"$CUR_VER"
MAJ="${MAJ:-0}"; MIN="${MIN:-0}"; PAT="${PAT:-0}"

# --- chọn phiên bản mới ---
bump() {
  case "$1" in
    patch) echo "$MAJ.$MIN.$((PAT + 1))" ;;
    minor) echo "$MAJ.$((MIN + 1)).0" ;;
    major) echo "$((MAJ + 1)).0.0" ;;
    *) echo "$1" ;;
  esac
}
if [ -z "$ARG" ]; then
  echo "Phiên bản hiện tại: $CUR_LINE   (tag mới nhất: $(git describe --tags --abbrev=0 2>/dev/null || echo 'chưa có'))"
  echo "  1) patch  → $(bump patch)   (sửa lỗi nhỏ)"
  echo "  2) minor  → $(bump minor)   (thêm tính năng)"
  echo "  3) major  → $(bump major)   (thay đổi lớn)"
  echo "  4) nhập tay"
  read -r -p "Chọn [1-4]: " pick
  case "$pick" in
    1) ARG=patch ;; 2) ARG=minor ;; 3) ARG=major ;;
    4) read -r -p "Số phiên bản (VD 0.3.0): " ARG ;;
    *) die "Không chọn" ;;
  esac
fi
NEW_VER="$(bump "$ARG")"
[[ "$NEW_VER" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] || die "Số phiên bản không hợp lệ: $NEW_VER"
NEW_BUILD=$((CUR_BUILD + 1))
NEW_LINE="$NEW_VER+$NEW_BUILD"
TAG="v$NEW_VER"

say "Phát hành $CUR_LINE → $NEW_LINE (tag $TAG)"

# --- kiểm tra an toàn ---
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" = "main" ] || die "Đang ở nhánh '$BRANCH' — chỉ phát hành từ main."
git rev-parse "$TAG" >/dev/null 2>&1 && die "Tag $TAG đã tồn tại."
command -v gh >/dev/null || die "Cần cài GitHub CLI (gh) và đăng nhập: gh auth login"
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || {
  git merge-base --is-ancestor origin/main HEAD || die "main trên máy cũ hơn origin/main — git pull trước."
}
# Thay đổi chưa commit: chỉ cho phép file ngoài những gì sẽ phát hành (không bị kéo vào commit).
DIRTY="$(git status --porcelain | grep -v '^??' | grep -v ' pubspec.yaml$' || true)"
if [ -n "$DIRTY" ]; then
  echo "Có thay đổi CHƯA commit (sẽ KHÔNG vào bản phát hành):"; echo "$DIRTY" | sed 's/^/    /'
  echo "Bản phát hành chỉ gồm những gì đã commit và push lên main."
fi
UNPUSHED="$(git log origin/main..HEAD --oneline | wc -l | tr -d ' ')"
[ "$UNPUSHED" = 0 ] || say "$UNPUSHED commit chưa push — sẽ được đẩy cùng bản phát hành."

if [ "$SKIP_TESTS" = 0 ] && [ "$DRY" = 0 ]; then
  say "Chạy test desktop (bỏ qua bằng --skip-tests)…"
  (cd apps/desktop && fvm flutter test >/dev/null 2>&1) || (cd apps/desktop && flutter test >/dev/null 2>&1) || die "Test desktop lỗi — sửa rồi phát hành lại."
  ok "Test desktop xanh"
fi

if [ "$YES" = 0 ] && [ "$DRY" = 0 ]; then
  read -r -p "Phát hành $TAG lên GitHub (công khai, khách sẽ tự cập nhật)? [y/N] " go
  [[ "$go" =~ ^[Yy]$ ]] || die "Đã huỷ."
fi

# --- tăng version, commit CHỈ pubspec của app, đẩy, gắn tag ---
say "Ghi version $NEW_LINE vào $PUBSPEC"
if [ "$DRY" = 0 ]; then
  sed -i.bak -E "s/^version:[[:space:]]*[^[:space:]#]+/version: $NEW_LINE/" "$PUBSPEC" && rm -f "$PUBSPEC.bak"
fi
run git add "$PUBSPEC"
run git commit -m "chore(release): $TAG ($NEW_LINE)" -- "$PUBSPEC"
say "Đẩy main + tag $TAG"
run git push origin main
run git tag "$TAG"
run git push origin "$TAG"

[ "$DRY" = 1 ] && { ok "Dry-run xong — chưa đổi gì."; exit 0; }

# --- chờ CI phát hành ---
say "Chờ CI build + phát hành (khoảng 10–15 phút)…"
sleep 8
RUN_ID="$(gh run list -R "$REPO" --workflow CI --branch "$TAG" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
if [ -n "$RUN_ID" ]; then
  gh run watch "$RUN_ID" -R "$REPO" --exit-status --interval 20 >/dev/null 2>&1 && ok "CI xong" || die "CI lỗi: https://github.com/$REPO/actions/runs/$RUN_ID"
fi
echo
ok "Đã phát hành $TAG"
echo "  Trang tải cho khách : https://minhtung263.github.io/print_agent/download.html"
echo "  Windows             : https://github.com/$REPO/releases/latest/download/TramInEasyPOS-Setup.exe"
echo "  Linux               : https://github.com/$REPO/releases/latest/download/easypos-print-agent_amd64.deb"
echo "  macOS               : https://github.com/$REPO/releases/latest/download/TramInEasyPOS.dmg"
echo "  Các Agent đã cài sẽ tự cập nhật khi máy rảnh (hỏi mỗi 6 giờ)."
