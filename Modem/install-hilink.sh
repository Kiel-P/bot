#!/bin/sh
# Auto-Installer & Fixer LuCI Huawei HiLink (OpenWrt 25.12+ / APK)
# By KIHEO

set -e

# Ganti URL di bawah ini dengan link raw/release file .apk di GitHub Anda
APK_URL="https://github.com/USERNAME/REPO/releases/download/v2.1/luci-app-huawei-hilink-2.1-r1_aarch64_generic.apk"
TMP_APK="/tmp/luci-app-huawei-hilink.apk"

echo "=========================================="
echo "  Installing LuCI Huawei HiLink (APK)     "
echo "=========================================="

echo "[1/5] Memperbarui repo & memasang dependensi..."
apk update
apk add curl luci-compat

echo "[2/5] Menyiapkan file paket..."
if [ -f "/root/luci-app-huawei-hilink-2.1-r1_aarch64_generic.apk" ]; then
    cp "/root/luci-app-huawei-hilink-2.1-r1_aarch64_generic.apk" "$TMP_APK"
else
    wget -qO "$TMP_APK" "$APK_URL" || curl -fsSL "$APK_URL" -o "$TMP_APK"
fi

echo "[3/5] Memasang paket luci-app-huawei-hilink..."
apk add --allow-untrusted "$TMP_APK"
rm -f "$TMP_APK"

echo "[4/5] Memperbaiki symlink CGI & izin eksekusi..."
mkdir -p /www/cgi-bin
ln -sf /usr/bin/hilink_api /www/cgi-bin/hilink_api
chmod +x /usr/bin/hilink_api
rm -f /etc/uci-defaults/99-huawei-hilink

echo "[5/5] Membersihkan cache & me-restart layanan..."
rm -rf /tmp/luci-*
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart

# Jeda 2 detik agar uhttpd selesai booting sebelum pengecekan API
sleep 2

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/cgi-bin/hilink_api || true)
echo "=========================================="
if [ "$HTTP_CODE" = "200" ]; then
    echo " [OK] Instalasi berhasil! API Status: 200"
else
    echo " [INFO] Instalasi selesai (HTTP: $HTTP_CODE). Silakan refresh LuCI."
fi
echo "=========================================="
