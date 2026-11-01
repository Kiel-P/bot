#!/bin/sh

# Color Palette
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

# Banner Pembukaan
printf "${CYAN}====================================================${NC}\n"
printf "${YELLOW}    NOTIFIKASI TELEGRAM AUTO-ENGINE BY.KIHEO      ${NC}\n"
printf "${CYAN}====================================================${NC}\n"
printf "${GREEN} Memulai Proses Pemasangan Bot (Chilli/LAN)...      ${NC}\n"
printf "${CYAN}====================================================${NC}\n\n"

# 1. Pengecekan Dependensi (Curl & Arping)
printf "${BLUE}[1/3] Memeriksa Modul Pendukung...${NC}\n"
if command -v opkg >/dev/null 2>&1; then
    opkg update >/dev/null 2>&1
    opkg list-installed | grep -q '^curl ' || opkg install curl >/dev/null 2>&1
    opkg list-installed | grep -q '^arping ' || opkg install arping >/dev/null 2>&1
elif command -v apt-get >/dev/null 2>&1; then
    apt-get update -y >/dev/null 2>&1
    apt-get install -y curl iputils-arping >/dev/null 2>&1
fi
printf "${GREEN}✔ Modul pendukung siap!${NC}\n\n"

# 2. Input Konfigurasi
printf "${BLUE}[2/3] Konfigurasi Bot Telegram${NC}\n"
printf "${YELLOW}----------------------------------------------------${NC}\n"

USER_TOKEN=""
while [ -z "$USER_TOKEN" ]; do
    printf "Masukkan Token Bot Telegram : "
    read USER_TOKEN
    [ -z "$USER_TOKEN" ] && printf "${RED}Token tidak boleh kosong!${NC}\n"
done

USER_CHAT_ID=""
while [ -z "$USER_CHAT_ID" ]; do
    printf "Masukkan Chat ID Telegram   : "
    read USER_CHAT_ID
    [ -z "$USER_CHAT_ID" ] && printf "${RED}Chat ID tidak boleh kosong!${NC}\n"
done

printf "Masukkan Nama Router [Default: KIEL] : "
read USER_ROUTER_NAME
[ -z "$USER_ROUTER_NAME" ] && ROUTER_NAME="KIEL" || ROUTER_NAME="$USER_ROUTER_NAME"

printf "Masukkan Interface Cadangan [Default: br-lan] : "
read USER_IFACE
[ -z "$USER_IFACE" ] && FALLBACK_IFACE="br-lan" || FALLBACK_IFACE="$USER_IFACE"

INSTALL_TIME=$(date +"%d-%m-%Y %H:%M:%S")
printf "${GREEN}✔ Konfigurasi berhasil disimpan!${NC}\n\n"

# 3. Membuat Script Utama (/usr/bin/telenotif)
printf "${BLUE}[3/3] Membuat File Script Utama (Auto-Engine)...${NC}\n"

cat << 'EOF' > /usr/bin/telenotif
#!/bin/sh

TELEGRAM_TOKEN="CONF_TOKEN"
CHAT_ID="CONF_CHAT_ID"
ROUTER_NAME="CONF_ROUTER_NAME"
FALLBACK_IFACE="CONF_IFACE"
INSTALL_TIME="CONF_TIME"

STATE_FILE="/tmp/telenotif_state.txt"
CURRENT_FILE="/tmp/telenotif_current.txt"
CHILLI_TEMP="/tmp/chilli_raw.txt"
ALIAS_FILE="/etc/config/host_alias.conf"

touch "$STATE_FILE"

send_telegram() {
    curl -k -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        --data-urlencode "text=$1" \
        -d "parse_mode=HTML" > /dev/null 2>&1 &
}

get_device_name() {
    local mac="$1" hostname="$2" alias_name=""
    [ -f "$ALIAS_FILE" ] && alias_name=$(grep -i "^$mac" "$ALIAS_FILE" | awk '{print $2}')
    if [ -n "$alias_name" ]; then echo "$alias_name"
    elif [ -n "$hostname" ] && [ "$hostname" != "*" ]; then echo "$hostname"
    else echo "Perangkat Tanpa Nama"; fi
}

send_telegram "🤖 <b>Bot Notifikasi Berhasil Aktif!</b>
Sistem siap memantau jaringan <b>${ROUTER_NAME}</b>
Mode Deteksi: Auto-Switch (Chilli / LAN)
⏱️ Diinstall pada: ${INSTALL_TIME}
===========================
                 By. K I H E O"

while true; do
    > "$CURRENT_FILE"
    
    # ==========================================
    # MODE 1: ENGINE CHILLI / RADMON V2
    # ==========================================
    if command -v chilli_query >/dev/null 2>&1; then
        
        # Simpan raw data untuk menghindari broken pipe saat parsing
        chilli_query list > "$CHILLI_TEMP" 2>/dev/null
        
        while read -r mac ip status session_id remaining username _ ; do
            [ -z "$mac" ] && continue
            mac=$(echo "$mac" | tr '[:upper:]' '[:lower:]' | tr -d '\r')
            ip=$(echo "$ip" | tr -d '\r')
            status=$(echo "$status" | tr -d '\r')
            [ -z "$username" ] || [ "$username" = "-" ] && username="Pengguna Voucher"
            
            # Tulis SEMUA data terkini perangkat (pass maupun dnat)
            echo "$mac|$ip|$status|$username" >> "$CURRENT_FILE"

            # Jika perangkat status PASS (Sudah login/aktif)
            if [ "$status" = "pass" ]; then
                if ! grep -q -i "^$mac|" "$STATE_FILE"; then
                    # Jika MAC tidak ada di state file, tambahkan dan kirim notif
                    echo "$mac|$ip|$status|$username" >> "$STATE_FILE"
                    MSG="🚀 <b>Perangkat Terhubung!</b>
📡 Router: ${ROUTER_NAME}
👤 User/Host: ${username}
🌐 IP: ${ip}
🏷️ MAC: ${mac}
📶 Jalur: Chilli (Terhubung/Login)
===========================
                 By. K I H E O"
                    send_telegram "$MSG"
                fi
            fi
        done < "$CHILLI_TEMP"

        # Cek Perangkat yang Terputus (berdasarkan file State yg menyimpan perangkat 'pass' sebelumnya)
        if [ -f "$STATE_FILE" ]; then
            TEMP_STATE="/tmp/telenotif_temp.txt"
            > "$TEMP_STATE"
            
            while IFS='|' read -r mac ip old_status username; do
                [ -z "$mac" ] && continue
                
                # Cek status barunya di current file
                current_status=$(grep -i "^$mac|" "$CURRENT_FILE" | cut -d'|' -f3)
                
                # Jika perangkat hilang total ATAU berubah menjadi dnat (putus/logout)
                if [ -z "$current_status" ] || [ "$current_status" = "dnat" ]; then
                    [ -z "$current_status" ] && display_stat="Offline/Keluar Jaringan" || display_stat="DNAT (Terputus/Logout)"
                    
                    MSG="🔻 <b>Perangkat Terputus!</b>
📡 Router: ${ROUTER_NAME}
👤 User/Host: ${username}
🌐 IP: ${ip}
🏷️ MAC: ${mac}
📊 Status: ${display_stat}
========================
              By. K I H E O"
                    send_telegram "$MSG"
                else
                    # Jika masih pass, pertahankan di state
                    echo "$mac|$ip|$old_status|$username" >> "$TEMP_STATE"
                fi
            done < "$STATE_FILE"
            mv "$TEMP_STATE" "$STATE_FILE"
        fi

    # ==========================================
    # MODE 2: ENGINE STANDAR (Fallback Interface)
    # ==========================================
    else
        > /tmp/active_arp.txt
        ip neigh show | grep -E "REACHABLE|DELAY" | awk '{print $5"|"$1}' | grep ":" >> /tmp/active_arp.txt
        [ -f "/tmp/dhcp.leases" ] && awk '{print $2"|"$3}' /tmp/dhcp.leases 2>/dev/null >> /tmp/active_arp.txt

        sort -u /tmp/active_arp.txt | while IFS='|' read -r mac ip; do
            mac=$(echo "$mac" | tr '[:upper:]' '[:lower:]' | tr -d '\r')
            ip=$(echo "$ip" | tr -d '\r')
            [ -z "$mac" ] && continue
            
            is_online=0
            if ip neigh show | grep -i "$mac" | grep -qE "REACHABLE|DELAY"; then is_online=1
            elif ping -c 1 -W 1 "$ip" >/dev/null 2>&1; then is_online=1
            elif command -v arping >/dev/null 2>&1 && arping -c 1 -w 1 -I "$FALLBACK_IFACE" "$ip" >/dev/null 2>&1; then is_online=1
            fi

            if [ $is_online -eq 1 ]; then
                hostname=$(awk -v m="$mac" '$2==m {print $4}' /tmp/dhcp.leases 2>/dev/null)
                DISPLAY_NAME=$(get_device_name "$mac" "$hostname")
                
                echo "$mac|$ip|pass|$DISPLAY_NAME" >> "$CURRENT_FILE"

                if ! grep -q -i "^$mac|" "$STATE_FILE"; then
                    echo "$mac|$ip|pass|$DISPLAY_NAME" >> "$STATE_FILE"
                    MSG="🚀 <b>Perangkat Terhubung!</b>
📡 Router: ${ROUTER_NAME}
📱 Host: ${DISPLAY_NAME}
🌐 IP: ${ip}
🏷️ MAC: ${mac}
📶 Jalur: ${FALLBACK_IFACE}
===========================
                 By. K I H E O"
                    send_telegram "$MSG"
                fi
            fi
        done

        if [ -f "$STATE_FILE" ]; then
            TEMP_STATE="/tmp/telenotif_temp.txt"
            > "$TEMP_STATE"
            while IFS='|' read -r mac ip status display_name; do
                [ -z "$mac" ] && continue
                if ! grep -q -i "^$mac|" "$CURRENT_FILE"; then
                    if ! ping -c 1 -W 1 "$ip" >/dev/null 2>&1 && ! (command -v arping >/dev/null 2>&1 && arping -c 1 -w 1 -I "$FALLBACK_IFACE" "$ip" >/dev/null 2>&1); then
                        MSG="🔻 <b>Perangkat Terputus!</b>
📡 Router: ${ROUTER_NAME}
📱 Host: ${display_name}
🌐 IP: ${ip}
🏷️ MAC: ${mac}
========================
              By. K I H E O"
                        send_telegram "$MSG"
                    else
                        echo "$mac|$ip|$status|$display_name" >> "$TEMP_STATE"
                    fi
                else
                    echo "$mac|$ip|$status|$display_name" >> "$TEMP_STATE"
                fi
            done < "$STATE_FILE"
            mv "$TEMP_STATE" "$STATE_FILE"
        fi
    fi

    sleep 3
done
EOF

# Subtitusi Variabel ke dalam Script
sed -i "s|CONF_TOKEN|${USER_TOKEN}|g" /usr/bin/telenotif
sed -i "s|CONF_CHAT_ID|${USER_CHAT_ID}|g" /usr/bin/telenotif
sed -i "s|CONF_ROUTER_NAME|${ROUTER_NAME}|g" /usr/bin/telenotif
sed -i "s|CONF_IFACE|${FALLBACK_IFACE}|g" /usr/bin/telenotif
sed -i "s|CONF_TIME|${INSTALL_TIME}|g" /usr/bin/telenotif

chmod +x /usr/bin/telenotif

# 4. Membuat Perintah Uninstall (/usr/bin/unbotnotif)
cat << 'EOF' > /usr/bin/unbotnotif
#!/bin/sh
if [ -f /etc/init.d/telenotif ]; then
    /etc/init.d/telenotif disable 2>/dev/null
    /etc/init.d/telenotif stop 2>/dev/null
    rm -f /etc/init.d/telenotif
fi
killall telenotif 2>/dev/null
rm -f /usr/bin/telenotif /tmp/telenotif_*.txt /tmp/chilli_raw.txt /tmp/active_arp.txt
echo -e "\033[0;32m✔ Bot berhasil dihapus total!\033[0m"
rm -f /usr/bin/unbotnotif
EOF
chmod +x /usr/bin/unbotnotif

# 5. Konfigurasi Autostart dan Menjalankan Bot
if [ -d "/etc/init.d" ]; then
cat << 'EOF' > /etc/init.d/telenotif
#!/bin/sh /etc/rc.common
START=99
STOP=10
start() {
    killall telenotif 2>/dev/null
    /usr/bin/telenotif >/dev/null 2>&1 &
}
stop() {
    killall telenotif 2>/dev/null
}
EOF
chmod +x /etc/init.d/telenotif
/etc/init.d/telenotif enable 2>/dev/null
/etc/init.d/telenotif start 2>/dev/null
fi

killall telenotif 2>/dev/null
/usr/bin/telenotif >/dev/null 2>&1 &

printf "\n${CYAN}====================================================${NC}\n"
printf "${GREEN}       PEMASANGAN SELESAI & BOT AKTIF!             ${NC}\n"
printf "${CYAN}====================================================${NC}\n"
printf "Status Bot      : ${YELLOW}Berjalan Otomatis${NC}\n"
printf "Waktu Install   : ${YELLOW}${INSTALL_TIME}${NC}\n"
printf "Cara Hentikan   : Ketik ${RED}unbotnotif${NC} di terminal\n"
printf "${CYAN}====================================================${NC}\n"
