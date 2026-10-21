#!/bin/sh

# Color Palette
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Fungsi Progress Bar dan Persentase
show_progress() {
    local percent=$1
    local text=$2
    local width=20
    local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))
    
    local bar=""
    local i=0
    while [ $i -lt $filled ]; do
        bar="${bar}#"
        i=$((i + 1))
    done
    i=0
    while [ $i -lt $empty ]; do
        bar="${bar}-"
        i=$((i + 1))
    done
    
    printf "\r    ${YELLOW}[%-20s] %3d%% - %s${NC}" "$bar" "$percent" "$text"
}

clear

# Banner Pembukaan
printf "${CYAN}====================================================${NC}\n"
printf "${YELLOW}       NOTIFIKASI TELEGRAM BY.KIHEO               ${NC}\n"
printf "${CYAN}====================================================${NC}\n"
printf "${GREEN} Memulai Proses Pemasangan Bot Notifikasi STB...    ${NC}\n"
printf "${CYAN}====================================================${NC}\n\n"

# 1. Pengecekan & Instalasi Dependensi dengan Persentase
printf "${BLUE}[1/4] Memeriksa & Menginstall Modul Pendukung...${NC}\n"

show_progress 0 "Menyiapkan sistem..."

if command -v opkg >/dev/null 2>&1; then
    show_progress 10 "Memperbarui daftar paket (opkg)..."
    opkg update >/dev/null 2>&1
    
    show_progress 30 "Memeriksa modul curl..."
    if ! opkg list-installed | grep -q "^curl "; then
        opkg install curl >/dev/null 2>&1
    fi
    
    show_progress 50 "Memeriksa modul ip-full..."
    if ! opkg list-installed | grep -q "^ip-full "; then
        opkg install ip-full >/dev/null 2>&1
    fi
    
    show_progress 70 "Memeriksa modul iw..."
    if ! opkg list-installed | grep -q "^iw "; then
        opkg install iw >/dev/null 2>&1
    fi
    
    show_progress 90 "Memeriksa modul bash..."
    if ! opkg list-installed | grep -q "^bash "; then
        opkg install bash >/dev/null 2>&1
    fi
elif command -v apt-get >/dev/null 2>&1; then
    show_progress 20 "Memperbarui daftar paket (apt)..."
    apt-get update -y >/dev/null 2>&1
    
    show_progress 60 "Memasang modul curl, iproute2, iw..."
    apt-get install -y curl iproute2 iw >/dev/null 2>&1
fi

show_progress 100 "Selesai memasang semua modul!"
printf "\n${GREEN}✔ Semua modul pendukung berhasil dipasang!${NC}\n\n"

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
    printf "Masukkan Chat ID Telegram  : "
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
STATE_FILE="/tmp/known_macs.txt"
CURRENT_FILE="/tmp/current_active.txt"
ALIAS_FILE="/etc/config/host_alias.conf"

touch "$STATE_FILE"

send_telegram() {
    local message="$1"
    curl -k -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        --data-urlencode "text=${message}" \
        -d "parse_mode=HTML" > /dev/null
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

    if ping -c 2 -W 1 "$ip" > /dev/null 2>&1; then
        return 0
    fi

    if command -v ip >/dev/null 2>&1; then
        if ip neigh show | grep -i "$mac" | grep -qv "REACHABLE\|STALE\|DELAY"; then
            return 0
        fi
    fi

    return 1
}

# Kirim pesan selamat datang
START_MSG="🤖 <b>Bot Notifikasi Berhasil Aktif!</b>
Sistem siap memantau jaringan <b>${ROUTER_NAME}</b>.
===========================
                 By. K I H E O"
send_telegram "$START_MSG"

while true; do
    > "$CURRENT_FILE"

    STB_WIFI_CLIENTS=$(iw dev 2>/dev/null | grep -i "station" | awk '{print $2}')

    if [ -f "$LEASE_FILE" ]; then
        while read -r timestamp mac ip hostname client_id; do
            [ -z "$mac" ] && continue
            
            MAC_LOWER=$(echo "$mac" | tr '[:upper:]' '[:lower:]')

            if is_device_online "$ip" "$MAC_LOWER"; then
                DISPLAY_NAME=$(get_device_name "$MAC_LOWER" "$hostname")
                echo "$MAC_LOWER|$DISPLAY_NAME|$ip" >> "$CURRENT_FILE"

                if ! grep -q -i "^$MAC_LOWER|" "$STATE_FILE"; then
                    echo "$MAC_LOWER|$DISPLAY_NAME|$ip" >> "$STATE_FILE"
                    
                    if echo "$STB_WIFI_CLIENTS" | grep -q -i "$MAC_LOWER"; then
                        CONN_TYPE="📶 STB Wi-Fi"
                    else
                        CONN_TYPE="🔌 Kabel LAN (${ROUTER_NAME})"
                    fi

                    MSG="🚀 <b>Perangkat Terhubung!</b>
📡 Router: ${ROUTER_NAME}
📱 Host: ${DISPLAY_NAME}
🌐 IP: ${ip}
🏷️ MAC: ${MAC_LOWER}
📶 Jalur: ${CONN_TYPE}
===========================
                 By. K I H E O"
                    send_telegram "$MSG"
                fi
            fi
        done < "$LEASE_FILE"
    fi

    if [ -f "$STATE_FILE" ]; then
        TEMP_STATE="/tmp/temp_state.txt"
        > "$TEMP_STATE"

        while IFS='|' read -r mac display_name ip; do
            [ -z "$mac" ] && continue
            
            MAC_LOWER=$(echo "$mac" | tr '[:upper:]' '[:lower:]')

            if ! grep -q -i "^$MAC_LOWER|" "$CURRENT_FILE"; then
                MSG="🔻 <b>Perangkat Terputus!</b>
📡 Router: ${ROUTER_NAME}
📱 Host: ${display_name}
🌐 IP: ${ip}
🏷️ MAC: ${MAC_LOWER}
========================
              By. K I H E O"
                send_telegram "$MSG"
            else
                echo "$MAC_LOWER|$display_name|$ip" >> "$TEMP_STATE"
            fi
        done < "$STATE_FILE"

        mv "$TEMP_STATE" "$STATE_FILE"
    fi

    sleep 10
done
EOF

# Subtitusi Konfigurasi
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
rm -f /tmp/known_macs.txt /tmp/current_active.txt /tmp/temp_state.txt

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
printf "Status Bot      : ${YELLOW}Berjalan di latar belakang${NC}\n"
printf "Cara Uninstall  : Ketik ${RED}unbotnotif${NC} di terminal\n"
printf "${CYAN}====================================================${NC}\n\n"
