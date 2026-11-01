#!/bin/sh

# Color Palette
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Fungsi Animasi Progress Real-Time
run_with_progress() {
    local start=$1
    local end=$2
    local text=$3
    shift 3
    local cmd="$@"

    eval "$cmd" >/dev/null 2>&1 &
    local pid=$!
    local current=$start
    local width=25

    while kill -0 $pid 2>/dev/null; do
        local filled=$(( current * width / 100 ))
        local empty=$(( width - filled ))
        
        local bar=""
        local i=0; while [ $i -lt $filled ]; do bar="${bar}#"; i=$((i + 1)); done
        local i=0; while [ $i -lt $empty ]; do bar="${bar}-"; i=$((i + 1)); done
        
        printf "\r    ${YELLOW}[%s] %3d%% - %-35s${NC}" "$bar" "$current" "$text"
        
        if [ $current -lt $((end - 1)) ]; then
            current=$((current + 1))
        fi
        sleep 0.15
    done
    wait $pid

    while [ $current -le $end ]; do
        local filled=$(( current * width / 100 ))
        local empty=$(( width - filled ))
        
        local bar=""
        local i=0; while [ $i -lt $filled ]; do bar="${bar}#"; i=$((i + 1)); done
        local i=0; while [ $i -lt $empty ]; do bar="${bar}-"; i=$((i + 1)); done
        
        printf "\r    ${YELLOW}[%s] %3d%% - %-35s${NC}" "$bar" "$current" "$text"
        current=$((current + 1))
        sleep 0.02
    done
}

clear

# Banner Pembukaan
printf "${CYAN}====================================================${NC}\n"
printf "${YELLOW}       NOTIFIKASI TELEGRAM BY.KIHEO               ${NC}\n"
printf "${CYAN}====================================================${NC}\n"
printf "${GREEN} Memulai Proses Pemasangan Bot Notifikasi STB...    ${NC}\n"
printf "${CYAN}====================================================${NC}\n\n"

# 1. Pengecekan Dependensi (Curl & Arping)
printf "${BLUE}[1/4] Memeriksa Modul Pendukung...${NC}\n"
if command -v opkg >/dev/null 2>&1; then
    run_with_progress 0 25 "Update repository..." "opkg update"
    run_with_progress 25 50 "Memeriksa modul curl..." "opkg list-installed | grep -q '^curl ' || opkg install curl"
    run_with_progress 50 100 "Memeriksa modul arping..." "opkg list-installed | grep -q '^arping ' || opkg install arping"
elif command -v apt-get >/dev/null 2>&1; then
    run_with_progress 0 50 "Update repository..." "apt-get update -y"
    run_with_progress 50 100 "Memasang modul penting..." "apt-get install -y curl iputils-arping"
fi
printf "\n\n${GREEN}✔ Modul pendukung siap!${NC}\n\n"

# 2. Input Konfigurasi
printf "${BLUE}[2/4] Konfigurasi Bot Telegram${NC}\n"
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
printf "${BLUE}[3/4] Membuat File Script Utama...${NC}\n"

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

# Fungsi format MAC dari XX-XX-XX-XX-XX-XX ke XX:XX:XX:XX:XX:XX
format_mac() {
    echo "$1" | tr '-' ':' | tr '[:upper:]' '[:lower:]'
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
        
        while read -r mac_raw ip status session_id remaining username _ ; do
            [ -z "$mac_raw" ] && continue
            
            # Format ulang MAC address dengan titik dua (:)
            mac=$(format_mac "$mac_raw")
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
printf "${BLUE}[4/4] Mengatur Layanan Latar Belakang (Auto-Start)...${NC}\n"
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
printf "Cara Uninstall  : Ketik ${RED}unbotnotif${NC} di terminal\n"
printf "${CYAN}====================================================${NC}\n"
