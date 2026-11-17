#!/usr/bin/env bash
# Đóng gói "Agent" thành file .deb (Ubuntu/Debian amd64).
#
# Chạy sau `flutter build linux --release` (từ đâu cũng được):
#   bash apps/desktop/installer/linux/build_deb.sh
# Biến môi trường tuỳ chọn:
#   BUNDLE_DIR  bản build (mặc định apps/desktop/build/linux/x64/release/bundle)
#   OUT_DIR     nơi ghi .deb (mặc định apps/desktop/build/installer)
#   VERSION     phiên bản deb (mặc định lấy `version:` trong pubspec.yaml)
#   MAINTAINER  trường Maintainer của gói
#
# Cài vào máy:
#   /opt/easypos-print-agent/            bản build Flutter
#   /usr/bin/easypos-print-agent         symlink tới file chạy
#   /usr/share/applications/<app-id>.desktop, icon hicolor 256x256
#   /etc/udev/rules.d/60-easypos-printer.rules  quyền ghi máy in USB
#   /etc/modules-load.d/easypos-print-agent.conf nạp module usblp khi khởi động
# Tự chạy khi đăng nhập: app tự quản (~/.config/autostart), gói không tạo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

PKG_NAME="easypos-print-agent"
BINARY_NAME="easypos_print_agent"
# Khớp APPLICATION_ID trong linux/CMakeLists.txt (g_set_prgname → WM_CLASS).
APP_ID="vn.softdreams.easypos.easypos_print_agent"
DISPLAY_NAME="Agent"
INSTALL_DIR="/opt/$PKG_NAME"
ICON_SRC="$APP_DIR/assets/app/app_icon.png"

BUNDLE_DIR="${BUNDLE_DIR:-$APP_DIR/build/linux/x64/release/bundle}"
OUT_DIR="${OUT_DIR:-$APP_DIR/build/installer}"
# TODO: thay bằng email hỗ trợ thật của EasyPOS.
MAINTAINER="${MAINTAINER:-EasyPOS <support@easypos.vn>}"

if [[ -z "${VERSION:-}" ]]; then
  VERSION="$(sed -n -E 's/^version:[[:space:]]*([^[:space:]#]+).*/\1/p' "$APP_DIR/pubspec.yaml" | head -n1)"
fi
if [[ -z "$VERSION" ]]; then
  echo "Không đọc được version trong pubspec.yaml" >&2
  exit 1
fi
# Debian cho phép dấu + (0.1.0+1) — giữ nguyên.

if [[ ! -x "$BUNDLE_DIR/$BINARY_NAME" ]]; then
  echo "Không thấy $BUNDLE_DIR/$BINARY_NAME — chạy 'flutter build linux --release' trước." >&2
  exit 1
fi
if [[ ! -f "$ICON_SRC" ]]; then
  echo "Không thấy icon $ICON_SRC" >&2
  exit 1
fi

ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ROOT="$WORK/root"

# --- Tệp chương trình ---
mkdir -p "$ROOT$INSTALL_DIR"
cp -a "$BUNDLE_DIR/." "$ROOT$INSTALL_DIR/"
chmod 0755 "$ROOT$INSTALL_DIR/$BINARY_NAME"

mkdir -p "$ROOT/usr/bin"
ln -s "$INSTALL_DIR/$BINARY_NAME" "$ROOT/usr/bin/$PKG_NAME"

# --- Icon + lối tắt menu ---
install -d "$ROOT/usr/share/icons/hicolor/256x256/apps"
install -m 0644 "$ICON_SRC" "$ROOT/usr/share/icons/hicolor/256x256/apps/$PKG_NAME.png"

install -d "$ROOT/usr/share/applications"
cat > "$ROOT/usr/share/applications/$APP_ID.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=$DISPLAY_NAME
GenericName=$DISPLAY_NAME
Comment=Nhận phiếu in từ EasyPOS và in ra máy in hoá đơn
Exec=$INSTALL_DIR/$BINARY_NAME
Icon=$PKG_NAME
Terminal=false
Categories=Office;Utility;
Keywords=EasyPOS;print;printer;in;
StartupWMClass=$APP_ID
StartupNotify=true
EOF
chmod 0644 "$ROOT/usr/share/applications/$APP_ID.desktop"

# --- Quyền máy in USB ---
# /dev/usb/lpN (module usblp) mặc định root:lp 0660 → người dùng thường không ghi
# được. TAG+="uaccess": systemd-logind cấp quyền (ACL) cho người đang ngồi phiên
# đăng nhập tại máy, tự thu hồi khi đăng xuất / đổi người — an toàn hơn MODE="0666"
# (mọi tài khoản kể cả dịch vụ / SSH đều ghi được). Chỉ khớp máy in USB lớp
# printer (usbmisc lp*), không đụng thiết bị khác. File phải đứng trước
# 73-seat-late.rules nên đặt số 60.
install -d "$ROOT/etc/udev/rules.d"
cat > "$ROOT/etc/udev/rules.d/60-easypos-printer.rules" <<'EOF'
# Agent: cho người dùng đang đăng nhập ghi máy in USB (/dev/usb/lp*).
SUBSYSTEM=="usbmisc", KERNEL=="lp[0-9]*", TAG+="uaccess"
# Không cho kernel tự ngắt điện máy in USB (autosuspend) khi vắng khách.
SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="07", TEST=="power/control", ATTR{power/control}="on"
EOF
chmod 0644 "$ROOT/etc/udev/rules.d/60-easypos-printer.rules"

# Nạp usblp khi khởi động (một số bản phân phối không tự nạp khi cắm máy in).
install -d "$ROOT/etc/modules-load.d"
cat > "$ROOT/etc/modules-load.d/$PKG_NAME.conf" <<'EOF'
# Agent: máy in USB qua /dev/usb/lp*
usblp
EOF
chmod 0644 "$ROOT/etc/modules-load.d/$PKG_NAME.conf"

# --- Thông tin gói ---
INSTALLED_SIZE="$(du -sk "$ROOT" | cut -f1)"
mkdir -p "$ROOT/DEBIAN"

# Thư viện runtime: libflutter_linux_gtk + plugin (tray_manager dùng
# ayatana-appindicator). Ubuntu 24.04 đổi tên gói kiểu *t64 — ghi cả hai.
DEPENDS="libc6, libstdc++6, libgcc-s1"
DEPENDS+=", libgtk-3-0t64 | libgtk-3-0"
DEPENDS+=", libglib2.0-0t64 | libglib2.0-0"
DEPENDS+=", libayatana-appindicator3-1"
DEPENDS+=", libsecret-1-0"
DEPENDS+=", libepoxy0, libfontconfig1"

cat > "$ROOT/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Maintainer: $MAINTAINER
Installed-Size: $INSTALLED_SIZE
Depends: $DEPENDS
Recommends: gnome-shell-extension-appindicator
Description: Agent
 Nhận phiếu in từ app EasyPOS (qua Internet hoặc mạng LAN cổng 9101) và in
 thẳng ra máy in hoá đơn LAN/USB bằng lệnh ESC/POS, không cần driver.
EOF

# conffiles: giữ chỉnh sửa của người quản trị khi nâng cấp.
cat > "$ROOT/DEBIAN/conffiles" <<EOF
/etc/udev/rules.d/60-easypos-printer.rules
/etc/modules-load.d/$PKG_NAME.conf
EOF

cat > "$ROOT/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
  modprobe usblp >/dev/null 2>&1 || true
  if command -v udevadm >/dev/null 2>&1; then
    udevadm control --reload-rules || true
    udevadm trigger --subsystem-match=usbmisc --action=change || true
    udevadm trigger --subsystem-match=usb --action=change || true
  fi
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
  fi
fi
exit 0
EOF

cat > "$ROOT/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e
# Gỡ hẳn: dừng app đang chạy (nâng cấp thì để nguyên, chạy lại sau là bản mới).
if [ "$1" = "remove" ]; then
  pkill -x easypos_print_agent >/dev/null 2>&1 || true
fi
exit 0
EOF

cat > "$ROOT/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
  if command -v udevadm >/dev/null 2>&1; then
    udevadm control --reload-rules || true
  fi
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
  fi
fi
exit 0
EOF
chmod 0755 "$ROOT/DEBIAN/postinst" "$ROOT/DEBIAN/prerm" "$ROOT/DEBIAN/postrm"
chmod 0644 "$ROOT/DEBIAN/control" "$ROOT/DEBIAN/conffiles"

mkdir -p "$OUT_DIR"
DEB="$OUT_DIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"
# xz: dpkg cũ (Debian 11, Ubuntu 20.04) không đọc được zstd mặc định của Ubuntu mới.
dpkg-deb --root-owner-group -Zxz --build "$ROOT" "$DEB"
echo "Đã tạo $DEB"
