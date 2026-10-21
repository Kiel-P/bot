#!/bin/sh

# ====================================================
#  INSTALLER NOTIFIKASI TELEGRAM BY.KIHEO
# ====================================================

# Color Palette
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Fungsi Animasi Spinner
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    # Hide cursor
    printf "\033[?25l"
    
    while [ "$(ps | grep "$pid" | grep -v grep)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    
    # Restore cursor
    printf "      \b\b\b\b\b\b"
    printf "\033[?25h"
}

clear

# Banner Pembukaan
echo -e "${CYAN}====================================================${NC}"
echo -e "${YELLOW}       NOTIFIKASI TELEGRAM BY.KIHEO               ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN} Memulai Proses Pemasangan Bot Notifikasi STB...    ${NC}"
echo -e "${CYAN}====================================================${NC}\n"

# 1. Pengecekan & Instalasi Dependensi dengan Animasi
echo -e "${BLUE}[1/4] Memeriksa & Menginstall Modul Pendukung...${NC}"

install_packages() {
    if command -v opkg >/dev/null 2>&1; then
        opkg update >/dev/null 2>&1
        
        REQUIRED_PKGS="curl ip-full iw bash"
        for pkg in $REQUIRED_PKGS; do
            if ! opkg list-installed | grep -q "^$pkg "; then
                opkg install "$pkg" >/dev/null 2>&1
            fi
        done
    elif command -v apt-get >/dev/null 2>&1; then
        apt-get update -y >/dev/null 2>&1
        apt-get install -y curl iproute2 iw >/dev/null 2>&1
    fi
}

# Jalankan instalasi di latar belakang
install_packages &
INSTALL_PID=$!

# Tampilkan teks & animasi pemrosesan
printf "    ${YELLOW}Mengunduh & Memasang Modul...${NC}"
show_spinner $INSTALL_PID

echo -e "\r${GREEN}✔ Semua modul pendukung berhasil dipasang!${NC}\n"

# 2. Input Konfigurasi dari Pengguna
echo -e "${BLUE}[2/4] Konfigurasi Bot Telegram${NC}"
echo -e "${YELLOW}----------------------------------------------------${NC}"

read -p "Masukkan Token Bot Telegram : " USER_TOKEN
while [ -z "$USER_TOKEN" ]; do
    echo -e "${RED}Token Bot tidak boleh kosong!${NC}"
    read -p "Masukkan Token Bot Telegram : " USER_TOKEN
done

read -p "Masukkan Chat ID Telegram  : " USER_CHAT_ID
while [ -z "$USER_CHAT_ID" ]; do
    echo -e "${RED}Chat ID tidak boleh kosong!${NC}"
    read -p "Masukkan Chat ID Telegram  : " USER_CHAT_ID
done

read -p "Masukkan Nama Router [Default: KIEL] : " USER_ROUTER_NAME
ROUTER_NAME=${USER_ROUTER_NAME:-KIEL}

echo -e "${GREEN}✔ Konfigurasi berhasil disimpan!${NC}\n"

# 3. Membuat Script Utama (/usr/bin/kiheo-bot)
echo -e "${BLUE}[3/4] Membuat File Script Utama...${NC}"

cat << 'EOF' > /usr/bin/kiheo-bot
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

# Kirim Notifikasi Start/Restart Bot
send_telegram "🤖 <b>Bot Notifikasi Berhasil Aktif!</b>%0ASistem siap memantau jaringan <b>${ROUTER_NAME}</b>.%0A===========================%0A                 By. K I H E O"

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

# Subtitusi Token, Chat ID, & Nama Router ke file yang baru dibuat
sed -i "s|CONF_TOKEN|${USER_TOKEN}|g" /usr/bin/kiheo-bot
sed -i "s|CONF_CHAT_ID|${USER_CHAT_ID}|g" /usr/bin/kiheo-bot
sed -i "s|CONF_ROUTER_NAME|${ROUTER_NAME}|g" /usr/bin/kiheo-bot

chmod +x /usr/bin/kiheo-bot

echo -e "${GREEN}✔ File bot dibuat di /usr/bin/kiheo-bot${NC}\n"

# 4. Membuat Service Auto-start (Procd Service untuk OpenWrt)
echo -e "${BLUE}[4/4] Mengatur Layanan Latar Belakang (Auto-Start)...${NC}"

if [ -d "/etc/init.d" ]; then
cat << 'EOF' > /etc/init.d/kiheobot
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1
PROG=/usr/bin/kiheo-bot

start_service() {
    procd_open_instance
    procd_set_param command $PROG
    procd_set_param respawn
    procd_close_instance
}

stop_service() {
    killall kiheo-bot 2>/dev/null
}
EOF

chmod +x /etc/init.d/kiheobot
/etc/init.d/kiheobot enable
/etc/init.d/kiheobot restart
else
    killall kiheo-bot 2>/dev/null
    nohup /usr/bin/kiheo-bot >/dev/null 2>&1 &
fi

echo -e "\n${CYAN}====================================================${NC}"
echo -e "${GREEN}       PEMASANGAN SELESAI & BOT AKTIF!             ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo -e "Status Bot : ${YELLOW}Berjalan di latar belakang (Background Process)${NC}"
echo -e "Cek pesan Telegram Anda untuk konfirmasi pesan aktif."
echo -e "${CYAN}====================================================${NC}\n"
