#!/bin/sh

# Color Palette
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Fungsi Animasi Progress Real-Time yang Sangat Smooth (Pro Look)
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

# 1. Pengecekan & Instalasi Dependensi dengan Progress Smooth
printf "${BLUE}[1/4] Memeriksa & Menginstall Modul Pendukung...${NC}\n"

if command -v opkg >/dev/null 2>&1; then
    run_with_progress 0 15 "Update repository (opkg)..." "opkg update"
    run_with_progress 15 30 "Memeriksa modul curl..." "opkg list-installed | grep -q '^curl ' || opkg install curl"
    run_with_progress 30 50 "Memeriksa modul ip-full..." "opkg list-installed | grep -q '^ip-full ' || opkg install ip-full"
    run_with_progress 50 65 "Memeriksa modul iw..." "opkg list-installed | grep -q '^iw ' || opkg install iw"
    run_with_progress 65 80 "Memeriksa modul bash..." "opkg list-installed | grep -q '^bash ' || opkg install bash"
    run_with_progress 80 100 "Memeriksa modul arping..." "opkg list-installed | grep -q '^arping ' || opkg install arping"
elif command -v apt-get >/dev/null 2>&1; then
    run_with_progress 0 40 "Update repository (apt)..." "apt-get update -y"
    run_with_progress 40 100 "Memasang modul penting..." "apt-get install -y curl iproute2 iw iputils-arping"
fi

printf "\n\n${GREEN}✔ Semua modul pendukung berhasil dipasang!${NC}\n\n"

# 2. Input Konfigurasi dari Pengguna
printf "${BLUE}[2/4] Konfigurasi Bot Telegram${NC}\n"
printf "${YELLOW}----------------------------------------------------${NC}\n"

USER_TOKEN=""
while [ -z "$USER_TOKEN" ]; do
    printf "Masukkan Token Bot Telegram : "
    read USER_TOKEN
    if [ -z "$USER_TOKEN" ]; then
        printf "${RED}Token Bot tidak boleh kosong!${NC}\n"
    fi
done

USER_CHAT_ID=""
while [ -z "$USER_CHAT_ID" ]; do
    printf "Masukkan Chat ID Telegram   : "
    read USER_CHAT_ID
    if [ -z "$USER_CHAT_ID" ]; then
        printf "${RED}Chat ID tidak boleh kosong!${NC}\n"
    fi
done

printf "Masukkan Nama Router [Default: KIEL] : "
read USER_ROUTER_NAME
if [ -z "$USER_ROUTER_NAME" ]; then
    ROUTER_NAME="KIEL"
else
    ROUTER_NAME="$USER_ROUTER_NAME"
fi

printf "${GREEN}✔ Konfigurasi berhasil disimpan!${NC}\n\n"

# 3. Membuat Script Utama (/usr/bin/telenotif)
printf "${BLUE}[3/4] Membuat File Script Utama...${NC}\n"

cat << 'EOF' > /usr/bin/telenotif
#!/bin/sh

TELEGRAM_TOKEN="CONF_TOKEN"
CHAT_ID="CONF_CHAT_ID"
ROUTER_NAME="CONF_ROUTER_NAME"

LEASE_FILE="/tmp/dhcp.leases"
STATE_FILE="/tmp/known_macs_v2.txt"
CURRENT_FILE="/tmp/current_active_v2.txt"
ALIAS_FILE="/etc/config/host_alias.conf"

touch "$STATE_FILE"

send_telegram() {
    local message="$1"
    # Background process (&) agar bot tidak lag
    curl -k -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        --data-urlencode "text=${message}" \
        -d "parse_mode=HTML" > /dev/null 2>&1 &
}

get_device_name() {
    local mac="$1"
    local hostname="$2"
    local alias_name=""

    if [ -f "$ALIAS_FILE" ]; then
        alias_name=$(grep -i "^$mac" "$ALIAS_FILE" | awk '{print $2}')
    fi

    if [ -n "$alias_name" ]; then
        echo "$alias_name"
    elif [ -n "$hostname" ] && [ "$hostname" != "*" ]; then
        echo "$hostname"
    else
        echo "Perangkat Tanpa Nama"
    fi
}

is_device_online() {
    local ip="$1"
    local mac="$2"

    # 1. Coba ARPING (Paling real-time & akurat)
    if command -v arping >/dev/null 2>&1; then
        if arping -c 1 -w 1 -I br-lan "$ip" >/dev/null 2>&1; then
            return 0
        fi
    fi

    # 2. Fallback ICMP Ping biasa
    if ping -c 1 -W 1 "$ip" > /dev/null 2>&1; then
        return 0
    fi

    # 3. Cek station Wi-Fi STB
    if echo "$STB_WIFI_CLIENTS" | grep -q -i "$mac"; then
        return 0
    fi

    # 4. Fallback ARP Table
    if ip neigh show | grep -i "$mac" | grep -qE "REACHABLE|DELAY"; then
        return 0
    fi

    return 1
}

send_telegram "🤖 <b>Sistem Monitor Aktif!</b>\nRouter <b>${ROUTER_NAME}</b> siap memantau jaringan."

while true; do
    > "$CURRENT_FILE"
    STB_WIFI_CLIENTS=$(iw dev 2>/dev/null | grep -i "station" | awk '{print $2}')

    if [ -f "$LEASE_FILE" ]; then
        while read -r timestamp mac ip hostname client_id; do
            # Pembersihan format mencegah error carriage return
            mac=$(echo "$mac" | tr -d '\r' | tr '[:upper:]' '[:lower:]')
            ip=$(echo "$ip" | tr -d '\r')
            [ -z "$mac" ] && continue
            
            if is_device_online "$ip" "$mac"; then
                DISPLAY_NAME=$(get_device_name "$mac" "$hostname")
                echo "$mac|$DISPLAY_NAME|$ip" >> "$CURRENT_FILE"

                if ! grep -q -i "^$mac|" "$STATE_FILE"; then
                    echo "$mac|$DISPLAY_NAME|$ip" >> "$STATE_FILE"
                    
                    if echo "$STB_WIFI_CLIENTS" | grep -q -i "$mac"; then
                        CONN_TYPE="📶 STB Wi-Fi"
                    else
                        CONN_TYPE="🔌 Kabel LAN (${ROUTER_NAME})"
                    fi

                    MSG="🚀 <b>Perangkat Terhubung!</b>
📡 Router: ${ROUTER_NAME}
📱 Host: ${DISPLAY_NAME}
🌐 IP: ${ip}
🏷️ MAC: ${mac}
📶 Jalur: ${CONN_TYPE}
===========================
                 By. K I H E O"
                    send_telegram "$MSG"
                fi
            fi
        done < "$LEASE_FILE"
    fi

    if [ -f "$STATE_FILE" ]; then
        TEMP_STATE="/tmp/temp_state_v2.txt"
        > "$TEMP_STATE"

        while IFS='|' read -r mac display_name ip; do
            mac=$(echo "$mac" | tr -d '\r')
            display_name=$(echo "$display_name" | tr -d '\r')
            ip=$(echo "$ip" | tr -d '\r')
            [ -z "$mac" ] && continue
            
            if ! grep -q -i "^$mac|" "$CURRENT_FILE"; then
                # Double-Check (Anti-Flapping)
                if ! is_device_online "$ip" "$mac"; then
                    MSG="🔻 <b>Perangkat Terputus!</b>
📡 Router: ${ROUTER_NAME}
📱 Host: ${display_name}
🌐 IP: ${ip}
🏷️ MAC: ${mac}
========================
              By. K I H E O"
                    send_telegram "$MSG"
                else
                    echo "$mac|$display_name|$ip" >> "$TEMP_STATE"
                fi
            else
                echo "$mac|$display_name|$ip" >> "$TEMP_STATE"
            fi
        done < "$STATE_FILE"

        mv "$TEMP_STATE" "$STATE_FILE"
    fi

    sleep 3
done
EOF

# Subtitusi Konfigurasi ke Script Utama
sed -i "s|CONF_TOKEN|${USER_TOKEN}|g" /usr/bin/telenotif
sed -i "s|CONF_CHAT_ID|${USER_CHAT_ID}|g" /usr/bin/telenotif
sed -i "s|CONF_ROUTER_NAME|${ROUTER_NAME}|g" /usr/bin/telenotif

chmod +x /usr/bin/telenotif

# 4. Membuat Perintah Uninstall (/usr/bin/unbotnotif)
cat << 'EOF' > /usr/bin/unbotnotif
#!/bin/sh
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

printf "${CYAN}====================================================${NC}\n"
printf "${RED}       UNINSTALL NOTIFIKASI TELEGRAM BY.KIHEO      ${NC}\n"
printf "${CYAN}====================================================${NC}\n"

if [ -f /etc/init.d/telenotif ]; then
    /etc/init.d/telenotif disable 2>/dev/null
    /etc/init.d/telenotif stop 2>/dev/null
    rm -f /etc/init.d/telenotif
fi

killall telenotif 2>/dev/null
rm -f /usr/bin/telenotif
rm -f /tmp/known_macs*.txt /tmp/current_active*.txt /tmp/temp_state*.txt

printf "${GREEN}✔ Bot notifikasi telegram berhasil dihapus total!${NC}\n"
printf "${CYAN}====================================================${NC}\n"
rm -f /usr/bin/unbotnotif
EOF

chmod +x /usr/bin/unbotnotif

printf "${GREEN}✔ File bot dibuat di /usr/bin/telenotif${NC}\n"
printf "${GREEN}✔ File uninstall dibuat di /usr/bin/unbotnotif${NC}\n\n"

# 5. Membuat Service Auto-start
printf "${BLUE}[4/4] Mengatur Layanan Latar Belakang (Auto-Start)...${NC}\n"

killall telenotif 2>/dev/null

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
else
    nohup /usr/bin/telenotif >/dev/null 2>&1 &
fi

printf "\n${CYAN}====================================================${NC}\n"
printf "${GREEN}       PEMASANGAN SELESAI & BOT AKTIF!             ${NC}\n"
printf "${CYAN}====================================================${NC}\n"
printf "Status Bot      : ${YELLOW}Berjalan otomatis di latar belakang${NC}\n"
printf "Cara Hentikan   : Ketik ${RED}unbotnotif${NC} di terminal\n"
printf "${CYAN}====================================================${NC}\n"
