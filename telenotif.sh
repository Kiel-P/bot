#!/bin/sh

# ====================================================
#   TELEGRAM NETWORK MONITOR & NOTIFIER BY. K I H E O
#   Support: OpenWrt 21.02 - 25.12+ (opkg & apk)
# ====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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
        [ $current -lt $((end - 1)) ] && current=$((current + 1))
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
printf "${CYAN}====================================================${NC}\n"
printf "${YELLOW}       NOTIFIKASI TELEGRAM BY.KIHEO               ${NC}\n"
printf "${CYAN}====================================================${NC}\n"
printf "${GREEN} Memulai Proses Pemasangan Bot Notifikasi STB...    ${NC}\n"
printf "${CYAN}====================================================${NC}\n\n"

# 1. Instalasi Dependensi (Support apk & opkg)
printf "${BLUE}[1/4] Memeriksa Modul Pendukung...${NC}\n"
if command -v apk >/dev/null 2>&1; then
    run_with_progress 0 30 "Update repository apk..." "apk update"
    run_with_progress 30 65 "Memeriksa modul curl..." "apk info -e curl || apk add curl"
    run_with_progress 65 100 "Memeriksa modul arping..." "apk info -e arping || apk add arping"
elif command -v opkg >/dev/null 2>&1; then
    run_with_progress 0 30 "Update repository opkg..." "opkg update"
    run_with_progress 30 65 "Memeriksa modul curl..." "opkg list-installed | grep -q '^curl ' || opkg install curl"
    run_with_progress 65 100 "Memeriksa modul arping..." "opkg list-installed | grep -q '^arping ' || opkg install arping"
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

printf "Masukkan Interface LAN [Default: br-lan] : "
read USER_IFACE
[ -z "$USER_IFACE" ] && FALLBACK_IFACE="br-lan" || FALLBACK_IFACE="$USER_IFACE"

INSTALL_TIME=$(date +"%d-%m-%Y %H:%M:%S")

cat << EOF > /etc/telenotif.conf
TELEGRAM_TOKEN="${USER_TOKEN}"
CHAT_ID="${USER_CHAT_ID}"
ROUTER_NAME="${ROUTER_NAME}"
FALLBACK_IFACE="${FALLBACK_IFACE}"
INSTALL_TIME="${INSTALL_TIME}"
EOF

printf "${GREEN}✔ Konfigurasi berhasil disimpan!${NC}\n\n"

# 3. Membuat Daemon Utama (/usr/bin/telenotif)
printf "${BLUE}[3/4] Membuat File Script Utama...${NC}\n"

cat << 'EOF' > /usr/bin/telenotif
#!/bin/sh

[ -f /etc/telenotif.conf ] && . /etc/telenotif.conf

STATE_FILE="/tmp/telenotif_state.txt"
CURRENT_FILE="/tmp/telenotif_current.txt"
CANDIDATE_FILE="/tmp/telenotif_candidates.txt"
CHILLI_TEMP="/tmp/chilli_raw.txt"
ALIAS_FILE="/etc/config/host_alias.conf"

touch "$STATE_FILE"

ARPING_FLAG="-w"
if command -v arping >/dev/null 2>&1; then
    (arping -h 2>&1; arping --help 2>&1) | grep -q -- "-W " && ARPING_FLAG="-W"
fi

WAN_IFACE=$(ip -4 route show default 2>/dev/null | awk '{print $5}' | head -n1)

escape_html() {
    printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

format_mac() {
    printf '%s' "$1" | tr '-' ':' | tr '[:upper:]' '[:lower:]' | tr -d '\r'
}

send_telegram() {
    curl -k -s --connect-timeout 5 -m 10 -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        --data-urlencode "text=$1" \
        -d "parse_mode=HTML" >/dev/null 2>&1 &
    sleep 0.2
}

get_device_name() {
    local mac="$1" hostname="$2" alias_name=""
    [ -f "$ALIAS_FILE" ] && alias_name=$(grep -i "^${mac}" "$ALIAS_FILE" | awk '{print $2}' | head -n1)
    if [ -n "$alias_name" ]; then
        printf '%s' "$alias_name"
    elif [ -n "$hostname" ] && [ "$hostname" != "*" ]; then
        printf '%s' "$hostname"
    else
        printf '%s' "Perangkat Tanpa Nama"
    fi
}

probe_device() {
    local target_ip="$1"
    local target_iface="${2:-$FALLBACK_IFACE}"
    [ -z "$target_ip" ] && return 1

    if ping -c 1 -W 1 "$target_ip" >/dev/null 2>&1; then
        return 0
    fi

    if command -v arping >/dev/null 2>&1; then
        if arping -c 1 ${ARPING_FLAG} 1 -I "$target_iface" "$target_ip" >/dev/null 2>&1; then
            return 0
        fi
    fi

    return 1
}

# Tunggu koneksi internet siap saat boot (maks 60 detik)
WAIT_NET=0
while [ $WAIT_NET -lt 30 ]; do
    if curl -k -s --connect-timeout 3 -I "https://api.telegram.org" >/dev/null 2>&1; then
        break
    fi
    WAIT_NET=$((WAIT_NET + 1))
    sleep 2
done

SAFE_ROUTER=$(escape_html "$ROUTER_NAME")

send_telegram "🤖 <b>Bot Notifikasi Berhasil Aktif!</b>
Sistem siap memantau jaringan <b>${SAFE_ROUTER}</b>
Mode Deteksi: Active Probe (LAN + Chilli)
⏱️ Aktif pada: $(date +"%d-%m-%Y %H:%M:%S")
===========================
                 By. K I H E O"

while true; do
    > "$CANDIDATE_FILE"
    > "$CURRENT_FILE"
    > "$CHILLI_TEMP"

    # 1. Kandidat dari CoovaChilli (jika tersedia)
    if command -v chilli_query >/dev/null 2>&1; then
        chilli_query list > "$CHILLI_TEMP" 2>/dev/null
        while read -r mac_raw ip status session_id auth_state username _ ; do
            [ -z "$mac_raw" ] && continue
            mac=$(format_mac "$mac_raw")
            ip=$(printf '%s' "$ip" | tr -d '\r')
            status=$(printf '%s' "$status" | tr -d '\r')
            [ -n "$mac" ] && [ -n "$ip" ] && printf '%s|%s|chilli:%s|%s\n' "$mac" "$ip" "$status" "$username" >> "$CANDIDATE_FILE"
        done < "$CHILLI_TEMP"
    fi

    # 2. Kandidat dari tabel ARP IPv4 (kecuali WAN)
    ip -4 neigh show 2>/dev/null | grep -E "REACHABLE|DELAY|STALE|PROBE" | while read -r line; do
        ip=$(printf '%s' "$line" | awk '{print $1}')
        dev=$(printf '%s' "$line" | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')
        mac_raw=$(printf '%s' "$line" | awk '{for(i=1;i<=NF;i++) if($i=="lladdr") print $(i+1)}')
        [ -z "$mac_raw" ] || [ -z "$ip" ] && continue
        [ "$dev" = "lo" ] && continue
        if [ -n "$WAN_IFACE" ] && [ "$dev" = "$WAN_IFACE" ] && [ "$dev" != "$FALLBACK_IFACE" ]; then
            continue
        fi
        mac=$(format_mac "$mac_raw")
        printf '%s|%s|%s|\n' "$mac" "$ip" "${dev:-$FALLBACK_IFACE}" >> "$CANDIDATE_FILE"
    done

    # 3. Kandidat dari DHCP leases
    if [ -f "/tmp/dhcp.leases" ]; then
        awk '{print tolower($2)"|"$3"|'"$FALLBACK_IFACE"'|"}' /tmp/dhcp.leases 2>/dev/null >> "$CANDIDATE_FILE"
    fi

    # 4. Pertahankan kandidat dari state sebelumnya
    if [ -f "$STATE_FILE" ]; then
        awk -F'|' '{print tolower($1)"|"$2"|"$3"|"}' "$STATE_FILE" 2>/dev/null >> "$CANDIDATE_FILE"
    fi

    # Cek aktif per perangkat unik
    awk -F'|' '!seen[$1]++ && $1 ~ /:/ && $2 ~ /\./' "$CANDIDATE_FILE" | while IFS='|' read -r mac ip iface chilli_user; do
        probe_iface="$iface"
        case "$iface" in
            chilli:*) probe_iface="$FALLBACK_IFACE" ;;
        esac

        if probe_device "$ip" "$probe_iface"; then
            hostname=$(awk -v m="$mac" 'tolower($2)==m {print $4}' /tmp/dhcp.leases 2>/dev/null | head -n1)
            if [ -n "$chilli_user" ] && [ "$chilli_user" != "-" ]; then
                DISPLAY_NAME="$chilli_user"
            else
                DISPLAY_NAME=$(get_device_name "$mac" "$hostname")
            fi

            printf '%s|%s|%s|%s\n' "$mac" "$ip" "$probe_iface" "$DISPLAY_NAME" >> "$CURRENT_FILE"

            if ! grep -q -i "^${mac}|" "$STATE_FILE"; then
                printf '%s|%s|%s|%s|0\n' "$mac" "$ip" "$probe_iface" "$DISPLAY_NAME" >> "$STATE_FILE"
                SAFE_NAME=$(escape_html "$DISPLAY_NAME")
                MSG="🚀 <b>Perangkat Terhubung!</b>
📡 Router: ${SAFE_ROUTER}
📱 Host: ${SAFE_NAME}
🌐 IP: ${ip}
🏷️ MAC: ${mac}
📶 Jalur: ${probe_iface}
===========================
                 By. K I H E O"
                send_telegram "$MSG"
            fi
        fi
    done

    # 5. Deteksi perangkat terputus (2x gagal probe berturut-turut)
    if [ -f "$STATE_FILE" ]; then
        TEMP_STATE="/tmp/telenotif_temp.txt"
        > "$TEMP_STATE"
        while IFS='|' read -r mac ip iface display_name miss_count; do
            [ -z "$mac" ] && continue
            [ -z "$miss_count" ] && miss_count=0

            if grep -q -i "^${mac}|" "$CURRENT_FILE"; then
                printf '%s|%s|%s|%s|0\n' "$mac" "$ip" "$iface" "$display_name" >> "$TEMP_STATE"
            else
                miss_count=$((miss_count + 1))
                if [ $miss_count -ge 2 ]; then
                    ip neigh del "$ip" dev "$iface" >/dev/null 2>&1
                    SAFE_NAME=$(escape_html "$display_name")
                    MSG="🔻 <b>Perangkat Terputus!</b>
📡 Router: ${SAFE_ROUTER}
📱 Host: ${SAFE_NAME}
🌐 IP: ${ip}
🏷️ MAC: ${mac}
========================
              By. K I H E O"
                    send_telegram "$MSG"
                else
                    printf '%s|%s|%s|%s|%s\n' "$mac" "$ip" "$iface" "$display_name" "$miss_count" >> "$TEMP_STATE"
                fi
            fi
        done < "$STATE_FILE"
        mv "$TEMP_STATE" "$STATE_FILE"
    fi

    sleep 2
done
EOF

chmod +x /usr/bin/telenotif

# 4. Membuat Utilitas Status & Uninstall
cat << 'EOF' > /usr/bin/telenotif-status
#!/bin/sh
echo "=== STATUS BOT TELENOTIF ==="
PIDS=$(pgrep -f "/usr/bin/telenotif")
if [ -n "$PIDS" ]; then
    echo "Status Proses : AKTIF (PID: $PIDS)"
else
    echo "Status Proses : MATI"
fi
echo ""
echo "=== PERANGKAT TERDETEKSI SAAT INI ==="
if [ -s /tmp/telenotif_state.txt ]; then
    cat /tmp/telenotif_state.txt
else
    echo "(Kosong - belum ada perangkat aktif)"
fi
EOF
chmod +x /usr/bin/telenotif-status

cat << 'EOF' > /usr/bin/unbotnotif
#!/bin/sh
if [ -f /etc/init.d/telenotif ]; then
    /etc/init.d/telenotif stop 2>/dev/null
    /etc/init.d/telenotif disable 2>/dev/null
    rm -f /etc/init.d/telenotif
fi
for pid in $(pgrep -f "/usr/bin/telenotif"); do
    kill -9 "$pid" 2>/dev/null
done
rm -f /usr/bin/telenotif /usr/bin/telenotif-status /etc/telenotif.conf /tmp/telenotif_*.txt /tmp/chilli_raw.txt
printf "\033[0;32m✔ Bot berhasil dihapus total!\033[0m\n"
rm -f /usr/bin/unbotnotif
EOF
chmod +x /usr/bin/unbotnotif

# 5. Konfigurasi Layanan PROCD (Auto-Start & Auto-Respawn)
printf "${BLUE}[4/4] Mengatur Layanan PROCD (Auto-Start)...${NC}\n"

if [ -f /etc/init.d/telenotif ]; then
    /etc/init.d/telenotif stop 2>/dev/null
fi
for pid in $(pgrep -f "/usr/bin/telenotif"); do
    kill -9 "$pid" 2>/dev/null
done
rm -f /tmp/telenotif_*.txt /tmp/chilli_raw.txt

cat << 'EOF' > /etc/init.d/telenotif
#!/bin/sh /etc/rc.common

USE_PROCD=1
START=99
STOP=10

start_service() {
    procd_open_instance
    procd_set_param command /bin/sh /usr/bin/telenotif
    procd_set_param respawn 3600 5 5
    procd_close_instance
}
EOF

chmod +x /etc/init.d/telenotif
/etc/init.d/telenotif enable
/etc/init.d/telenotif start

printf "\n${CYAN}====================================================${NC}\n"
printf "${GREEN}       PEMASANGAN SELESAI & BOT AKTIF!             ${NC}\n"
printf "${CYAN}====================================================${NC}\n"
printf "Status Bot      : ${YELLOW}Berjalan Otomatis (PROCD)${NC}\n"
printf "Waktu Install   : ${YELLOW}${INSTALL_TIME}${NC}\n"
printf "Cek Status      : Ketik ${CYAN}telenotif-status${NC}\n"
printf "Cara Uninstall  : Ketik ${RED}unbotnotif${NC}\n"
printf "${CYAN}====================================================${NC}\n"
