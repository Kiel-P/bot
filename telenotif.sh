#!/bin/sh

# ====================================================
#   KIHEO-BOT HUB INSTALLER (MODULAR BOT LAUNCHER)
#   Command Utama: kiheo
#   Support: OpenWrt 21.02 - 25.12+ (opkg & apk)
# ====================================================

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

clear
printf "${CYAN}====================================================${NC}\n"
printf "${YELLOW}       MEMASANG KIHEO-BOT HUB & MODUL SYSTEM        ${NC}\n"
printf "${CYAN}====================================================${NC}\n\n"

mkdir -p /usr/lib/kiheo/modules
mkdir -p /etc/kiheo/plugins

# ====================================================
# BAGIAN 1: MODUL BOT NOTIFIKASI (/usr/lib/kiheo/modules/botnotif.sh)
# ====================================================
printf "${BLUE}[1/2] Menyiapkan Modul Bot Notifikasi...${NC}\n"

cat << 'EOF_MOD_NOTIF' > /usr/lib/kiheo/modules/botnotif.sh
#!/bin/sh

CONF_FILE="/etc/telenotif.conf"
STATE_FILE="/tmp/telenotif_state.txt"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BLUE='\033[0;34m'
NC='\033[0m'

bn_spaces() {
    local n="$1" s="" i=0
    while [ $i -lt $n ]; do s="${s} "; i=$((i + 1)); done
    printf '%s' "$s"
}

bn_box_line() {
    local bcolor="$1"
    local plain="$2"
    local colored="$3"
    local inner=52
    local len=${#plain}
    local pad=$((inner - len))
    [ $pad -lt 0 ] && pad=0
    printf "${bcolor}│${NC}%b%s${bcolor}│${NC}\n" "$colored" "$(bn_spaces "$pad")"
}

bn_banner() {
    printf "${CYAN}"
    printf "    ╔═╗ ╔═╗╔═╗╔═╗╔═╗╔═══╗╔═══╗    ╔═══╗╔═══╗╔═══╗\n"
    printf "    ║ ║╔╝╔╝║ ║║ ║║ ║║ ╔═╝║ ╔╗║    ║ ╔╗║║ ╔╗║╚╗ ╔╝\n"
    printf "    ║ ╚╝╔╝ ║ ║║ ╚╝ ║║ ╚═╗║ ║║║╔══╗║ ╚╝╣║ ║║║ ║ ║ \n"
    printf "    ║ ╔╗╚╗ ║ ║║ ╔╗ ║║ ╔═╝║ ║║║╚══╝║ ╔╗╣║ ║║║ ║ ║ \n"
    printf "    ║ ║╚╗╚╗║ ║║ ║║ ║║ ╚═╗║ ╚╝║    ║ ╚╝║║ ╚╝║ ║ ║ \n"
    printf "    ╚═╝ ╚═╝╚═╝╚═╝╚═╝╚═══╝╚═══╝    ╚═══╝╚═══╝ ╚═╝ \n"
    printf "${NC}\n"
}

bn_progress() {
    local start=$1
    local end=$2
    local text="$3"
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

bn_mask_token() {
    local t="$1"
    local len=${#t}
    if [ "$len" -le 12 ]; then
        printf '%s' "****"
    else
        local head="$(printf '%s' "$t" | cut -c1-6)"
        local tail="$(printf '%s' "$t" | cut -c$((len - 4))-$len)"
        printf '%s****%s' "$head" "$tail"
    fi
}

bn_is_installed() {
    [ -x /usr/bin/telenotif ] && [ -f "$CONF_FILE" ]
}

bn_install() {
    clear
    printf "${CYAN}====================================================${NC}\n"
    printf "${YELLOW}         INSTALASI BOT NOTIFIKASI TELEGRAM          ${NC}\n"
    printf "${CYAN}====================================================${NC}\n\n"

    printf "${BLUE}[1/4] Memeriksa Modul Pendukung...${NC}\n"
    if command -v apk >/dev/null 2>&1; then
        bn_progress 0 30 "Update repository apk..." "apk update"
        bn_progress 30 65 "Memeriksa modul curl..." "apk info -e curl || apk add curl"
        bn_progress 65 100 "Memeriksa modul arping..." "apk info -e arping || apk add arping"
    elif command -v opkg >/dev/null 2>&1; then
        bn_progress 0 30 "Update repository opkg..." "opkg update"
        bn_progress 30 65 "Memeriksa modul curl..." "opkg list-installed | grep -q '^curl ' || opkg install curl"
        bn_progress 65 100 "Memeriksa modul arping..." "opkg list-installed | grep -q '^arping ' || opkg install arping"
    fi
    printf "\n\n${GREEN}✔ Modul pendukung siap!${NC}\n\n"

    printf "${BLUE}[2/4] Konfigurasi Bot Notifikasi${NC}\n"
    printf "${YELLOW}----------------------------------------------------${NC}\n"

    local USER_TOKEN=""
    while [ -z "$USER_TOKEN" ]; do
        printf "Masukkan Token Bot Telegram : "
        read USER_TOKEN
        [ -z "$USER_TOKEN" ] && printf "${RED}Token tidak boleh kosong!${NC}\n"
    done

    local USER_CHAT_ID=""
    while [ -z "$USER_CHAT_ID" ]; do
        printf "Masukkan Chat ID Telegram   : "
        read USER_CHAT_ID
        [ -z "$USER_CHAT_ID" ] && printf "${RED}Chat ID tidak boleh kosong!${NC}\n"
    done

    printf "Masukkan Nama Router [Default: KIHEO] : "
    read USER_ROUTER_NAME
    [ -z "$USER_ROUTER_NAME" ] && ROUTER_NAME="KIHEO" || ROUTER_NAME="$USER_ROUTER_NAME"

    printf "Masukkan Interface LAN [Default: br-lan] : "
    read USER_IFACE
    [ -z "$USER_IFACE" ] && FALLBACK_IFACE="br-lan" || FALLBACK_IFACE="$USER_IFACE"

    printf "Batas Gagal Probe Berturut-turut [Default: 4] : "
    read USER_MAX_MISSES
    case "$USER_MAX_MISSES" in
        ''|*[!0-9]*|0) MAX_MISSES=4 ;;
        *) MAX_MISSES="$USER_MAX_MISSES" ;;
    esac

    printf "Interval Pengecekan dalam Detik [Default: 2] : "
    read USER_INTERVAL
    case "$USER_INTERVAL" in
        ''|*[!0-9]*|0) PROBE_INTERVAL=2 ;;
        *) PROBE_INTERVAL="$USER_INTERVAL" ;;
    esac

    WIFI_INACTIVE_MAX=20000
    INSTALL_TIME="$(date +"%d-%m-%Y %H:%M:%S")"

    cat << EOF_CONF > "$CONF_FILE"
TELEGRAM_TOKEN="${USER_TOKEN}"
CHAT_ID="${USER_CHAT_ID}"
ROUTER_NAME="${ROUTER_NAME}"
FALLBACK_IFACE="${FALLBACK_IFACE}"
MAX_MISSES="${MAX_MISSES}"
PROBE_INTERVAL="${PROBE_INTERVAL}"
WIFI_INACTIVE_MAX="${WIFI_INACTIVE_MAX}"
INSTALL_TIME="${INSTALL_TIME}"
EOF_CONF

    printf "${GREEN}✔ Konfigurasi berhasil disimpan!${NC}\n\n"

    printf "${BLUE}[3/4] Membuat Daemon & Perintah Kontrol...${NC}\n"

    cat << 'EOF_DAEMON' > /usr/bin/telenotif
#!/bin/sh

[ -f /etc/telenotif.conf ] && . /etc/telenotif.conf

: "${MAX_MISSES:=4}"
: "${PROBE_INTERVAL:=2}"
: "${WIFI_INACTIVE_MAX:=20000}"
: "${FALLBACK_IFACE:=br-lan}"

STATE_FILE="/tmp/telenotif_state.txt"
CURRENT_FILE="/tmp/telenotif_current.txt"
CANDIDATE_FILE="/tmp/telenotif_candidates.txt"
WIFI_ASSOC_FILE="/tmp/telenotif_wifi_assoc.txt"
CHILLI_TEMP="/tmp/chilli_raw.txt"
ALIAS_FILE="/etc/config/host_alias.conf"

touch "$STATE_FILE"

ARPING_FLAG="-w"
ARPING_FAST=""
if command -v arping >/dev/null 2>&1; then
    ARPING_HELP=$(arping -h 2>&1; arping --help 2>&1)
    printf '%s' "$ARPING_HELP" | grep -q -- "-W" && ARPING_FLAG="-W"
    printf '%s' "$ARPING_HELP" | grep -q -- "-f" && ARPING_FAST="-f"
fi

WAN_IFACE=$(ip -4 route show default 2>/dev/null | awk '{print $5}' | head -n1)

escape_html() {
    printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

format_mac() {
    printf '%s' "$1" | tr '-' ':' | tr '[:upper:]' '[:lower:]' | tr -d '\r'
}

send_telegram() {
    local text="$1"
    local ids
    ids=$(printf '%s' "$CHAT_ID" | tr ',;' '  ')
    for target_id in $ids; do
        [ -z "$target_id" ] && continue
        curl -k -s --connect-timeout 5 -m 10 -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
            -d "chat_id=${target_id}" \
            --data-urlencode "text=${text}" \
            -d "parse_mode=HTML" >/dev/null 2>&1 &
        sleep 0.1
    done
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

refresh_wifi_clients() {
    > "$WIFI_ASSOC_FILE"

    if command -v iw >/dev/null 2>&1; then
        for dev_path in /sys/class/net/*; do
            [ -e "$dev_path/wireless" ] || [ -e "$dev_path/phy80211" ] || continue
            wdev=$(basename "$dev_path")
            iw dev "$wdev" station dump 2>/dev/null | awk -v max_ms="$WIFI_INACTIVE_MAX" '
                /^Station / { mac = tolower($2); inact = 0; auth = "yes" }
                /inactive time:/ { inact = $3 + 0 }
                /authorized:/ { auth = $2 }
                /^$/ {
                    if (mac != "" && auth == "yes" && inact <= max_ms) print mac
                    mac = ""
                }
                END {
                    if (mac != "" && auth == "yes" && inact <= max_ms) print mac
                }
            ' >> "$WIFI_ASSOC_FILE"
        done
    fi

    if [ ! -s "$WIFI_ASSOC_FILE" ] && command -v iwinfo >/dev/null 2>&1; then
        for dev_path in /sys/class/net/*; do
            [ -e "$dev_path/wireless" ] || [ -e "$dev_path/phy80211" ] || continue
            wdev=$(basename "$dev_path")
            iwinfo "$wdev" assoclist 2>/dev/null | awk -v max_ms="$WIFI_INACTIVE_MAX" '
                $1 ~ /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/ {
                    mac = tolower($1); inact = 0
                    for (i = 1; i <= NF; i++) {
                        if ($i == "ms" && $(i+1) == "ago") inact = $(i-1) + 0
                    }
                    if (inact <= max_ms) print mac
                }
            ' >> "$WIFI_ASSOC_FILE"
        done
    fi

    if [ ! -s "$WIFI_ASSOC_FILE" ] && command -v ubus >/dev/null 2>&1; then
        for hapd in $(ubus list 'hostapd.*' 2>/dev/null); do
            ubus call "$hapd" get_clients 2>/dev/null | \
                grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | \
                tr '[:upper:]' '[:lower:]' >> "$WIFI_ASSOC_FILE"
        done
    fi

    [ -s "$WIFI_ASSOC_FILE" ] && sort -u "$WIFI_ASSOC_FILE" -o "$WIFI_ASSOC_FILE" 2>/dev/null
}

is_wifi_connected() {
    local mac="$1"
    [ -s "$WIFI_ASSOC_FILE" ] && grep -q -F -x "$mac" "$WIFI_ASSOC_FILE"
}

get_prev_miss_count() {
    local mac="$1"
    awk -F'|' -v m="$mac" 'tolower($1)==m {print ($5=="" ? 0 : $5); exit}' "$STATE_FILE" 2>/dev/null
}

probe_device() {
    local target_ip="$1"
    local target_iface="${2:-$FALLBACK_IFACE}"
    local prev_misses="${3:-0}"
    [ -z "$target_ip" ] && return 1

    local arp_count=1
    [ "$prev_misses" -gt 0 ] 2>/dev/null && arp_count=2

    if command -v arping >/dev/null 2>&1; then
        if arping ${ARPING_FAST} -c "$arp_count" ${ARPING_FLAG} 1 -I "$target_iface" "$target_ip" >/dev/null 2>&1; then
            return 0
        fi
    fi

    if ping -c 1 -W 1 "$target_ip" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

WAIT_NET=0
while [ $WAIT_NET -lt 30 ]; do
    if curl -k -s --connect-timeout 3 -I "https://api.telegram.org" >/dev/null 2>&1; then
        break
    fi
    WAIT_NET=$((WAIT_NET + 1))
    sleep 2
done

SAFE_ROUTER=$(escape_html "$ROUTER_NAME")

send_telegram "🤖 <b>KIHEO-BOT Notif Aktif!</b>
Sistem siap memantau jaringan <b>${SAFE_ROUTER}</b>
Mode: Real-Time Wi-Fi Assoc + Multi-Probe (${MAX_MISSES}x / ${PROBE_INTERVAL}s)
⏱️ Aktif pada: $(date +"%d-%m-%Y %H:%M:%S")
===========================
                 By. K I H E O"

while true; do
    > "$CANDIDATE_FILE"
    > "$CURRENT_FILE"
    > "$CHILLI_TEMP"

    refresh_wifi_clients

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

    if [ -f "/tmp/dhcp.leases" ]; then
        awk '{print tolower($2)"|"$3"|'"$FALLBACK_IFACE"'|"}' /tmp/dhcp.leases 2>/dev/null >> "$CANDIDATE_FILE"
    fi

    if [ -f "$STATE_FILE" ]; then
        awk -F'|' '{print tolower($1)"|"$2"|"$3"|"}' "$STATE_FILE" 2>/dev/null >> "$CANDIDATE_FILE"
    fi

    awk -F'|' '!seen[$1]++ && $1 ~ /:/ && $2 ~ /\./' "$CANDIDATE_FILE" | while IFS='|' read -r mac ip iface chilli_user; do
        probe_iface="$iface"
        case "$iface" in
            chilli:*) probe_iface="$FALLBACK_IFACE" ;;
        esac

        prev_misses=$(get_prev_miss_count "$mac")
        [ -z "$prev_misses" ] && prev_misses=0

        device_alive=0
        if is_wifi_connected "$mac"; then
            device_alive=1
        elif probe_device "$ip" "$probe_iface" "$prev_misses"; then
            device_alive=1
        fi

        if [ "$device_alive" -eq 1 ]; then
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

    if [ -f "$STATE_FILE" ]; then
        TEMP_STATE="/tmp/telenotif_temp.txt"
        > "$TEMP_STATE"
        while IFS='|' read -r mac ip iface display_name miss_count; do
            [ -z "$mac" ] && continue
            [ -z "$miss_count" ] && miss_count=0

            active_line=$(grep -i "^${mac}|" "$CURRENT_FILE" | head -n1)
            if [ -n "$active_line" ]; then
                cur_ip=$(printf '%s' "$active_line" | awk -F'|' '{print $2}')
                cur_iface=$(printf '%s' "$active_line" | awk -F'|' '{print $3}')
                cur_name=$(printf '%s' "$active_line" | awk -F'|' '{print $4}')
                printf '%s|%s|%s|%s|0\n' "$mac" "${cur_ip:-$ip}" "${cur_iface:-$iface}" "${cur_name:-$display_name}" >> "$TEMP_STATE"
            else
                miss_count=$((miss_count + 1))
                if [ "$miss_count" -ge "$MAX_MISSES" ]; then
                    ip neigh del "$ip" dev "$iface" >/dev/null 2>&1
                    SAFE_NAME=$(escape_html "$display_name")
                    MSG="🔻 <b>Perangkat Terputus!</b>
📡 Router: ${SAFE_ROUTER}
📱 Host: ${SAFE_NAME}
🌐 IP: ${ip}
🏷️ MAC: ${mac}
===========================
                 By. K I H E O"
                    send_telegram "$MSG"
                else
                    printf '%s|%s|%s|%s|%s\n' "$mac" "$ip" "$iface" "$display_name" "$miss_count" >> "$TEMP_STATE"
                fi
            fi
        done < "$STATE_FILE"
        mv "$TEMP_STATE" "$STATE_FILE"
    fi

    sleep "$PROBE_INTERVAL"
done
EOF_DAEMON
chmod +x /usr/bin/telenotif

    cat << 'EOF_RES' > /usr/bin/resbotnotif
#!/bin/sh
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

printf "${CYAN}[KIHEO-BOT]${NC} Memulai / me-restart Bot Notif...\n"
[ -f /etc/init.d/telenotif ] && /etc/init.d/telenotif stop >/dev/null 2>&1
for pid in $(pgrep -f "/usr/bin/telenotif"); do
    kill -9 "$pid" 2>/dev/null
done
rm -f /tmp/telenotif_current.txt /tmp/telenotif_candidates.txt /tmp/telenotif_wifi_assoc.txt /tmp/chilli_raw.txt

if [ -f /etc/init.d/telenotif ]; then
    /etc/init.d/telenotif enable >/dev/null 2>&1
    /etc/init.d/telenotif start >/dev/null 2>&1
else
    /bin/sh /usr/bin/telenotif >/dev/null 2>&1 &
fi

sleep 1
PIDS=$(pgrep -f "/usr/bin/telenotif")
if [ -n "$PIDS" ]; then
    printf "${GREEN}✔ Bot Notif AKTIF! (PID: %s)${NC}\n" "$PIDS"
else
    printf "${RED}✖ Gagal menjalankan Bot Notif.${NC}\n"
fi
EOF_RES
chmod +x /usr/bin/resbotnotif

    cat << 'EOF_STOP' > /usr/bin/stopbotnotif
#!/bin/sh
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

printf "${CYAN}[KIHEO-BOT]${NC} Menghentikan Bot Notif...\n"
[ -f /etc/init.d/telenotif ] && /etc/init.d/telenotif stop >/dev/null 2>&1
for pid in $(pgrep -f "/usr/bin/telenotif"); do
    kill -9 "$pid" 2>/dev/null
done
rm -f /tmp/telenotif_current.txt /tmp/telenotif_candidates.txt /tmp/telenotif_wifi_assoc.txt /tmp/chilli_raw.txt
printf "${RED}■ Bot Notif dihentikan (STOPPED).${NC}\n"
printf "${YELLOW}  Jalankan 'resbotnotif' atau menu kiheo untuk mengaktifkan lagi.${NC}\n"
EOF_STOP
chmod +x /usr/bin/stopbotnotif

    cat << 'EOF_CEK' > /usr/bin/cekbot
#!/bin/sh
[ -f /etc/telenotif.conf ] && . /etc/telenotif.conf
: "${MAX_MISSES:=4}"
: "${PROBE_INTERVAL:=2}"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
NC='\033[0m'

printf "${CYAN}┌──────────── [ Status Bot Notifikasi ] ─────────────┐${NC}\n"
PIDS=$(pgrep -f "/usr/bin/telenotif" | tr '\n' ' ')
if [ -n "$PIDS" ]; then
    printf "  Status Proses : ${GREEN}● AKTIF${NC} (PID: %s)\n" "$PIDS"
else
    printf "  Status Proses : ${RED}● MATI / STOPPED${NC}\n"
fi
printf "  Router / LAN  : ${YELLOW}%s${NC} (%s)\n" "${ROUTER_NAME:-KIHEO}" "${FALLBACK_IFACE:-br-lan}"
printf "  User ID Bot   : ${MAGENTA}%s${NC}\n" "${CHAT_ID:--}"
printf "  Mode Probe    : %sx gagal berturut-turut (interval %ss)\n" "$MAX_MISSES" "$PROBE_INTERVAL"
printf "${CYAN}└────────────────────────────────────────────────────┘${NC}\n\n"

printf "${RED}┌───────────── - Perangkat Terdeteksi - ─────────────┐${NC}\n"
if [ -s /tmp/telenotif_state.txt ]; then
    awk -F'|' -v max="$MAX_MISSES" '{
        miss = ($5 == "" ? 0 : $5)
        status = (miss == 0 ? "ONLINE" : "RETRY (" miss "/" max ")")
        printf "  %-17s | %-14s | %-12s | %s\n", $1, $2, substr($4,1,12), status
    }' /tmp/telenotif_state.txt
else
    printf "  (Kosong - belum ada perangkat aktif tercatat)\n"
fi
printf "${RED}└────────────────────────────────────────────────────┘${NC}\n"
EOF_CEK
chmod +x /usr/bin/cekbot
ln -sf /usr/bin/cekbot /usr/bin/telenotif-status

    printf "${BLUE}[4/4] Mengaktifkan Layanan PROCD...${NC}\n"
    cat << 'EOF_INIT' > /etc/init.d/telenotif
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
EOF_INIT
    chmod +x /etc/init.d/telenotif
    /usr/bin/resbotnotif

    printf "\n${GREEN}✔ Bot Notifikasi berhasil dipasang dan dijalankan!${NC}\n"
}

bn_uninstall_only() {
    printf "\n${YELLOW}Menghentikan dan menghapus Bot Notifikasi...${NC}\n"
    if [ -f /etc/init.d/telenotif ]; then
        /etc/init.d/telenotif stop 2>/dev/null
        /etc/init.d/telenotif disable 2>/dev/null
        rm -f /etc/init.d/telenotif
    fi
    for pid in $(pgrep -f "/usr/bin/telenotif"); do
        kill -9 "$pid" 2>/dev/null
    done
    rm -f /usr/bin/telenotif /usr/bin/telenotif-status /usr/bin/cekbot \
          /usr/bin/resbotnotif /usr/bin/stopbotnotif "$CONF_FILE" \
          /tmp/telenotif_*.txt /tmp/chilli_raw.txt
    printf "${GREEN}✔ Bot Notifikasi dihapus! Menu utama 'kiheo' tetap aman.${NC}\n"
}

bn_manage_user_ids() {
    while true; do
        [ -f "$CONF_FILE" ] && . "$CONF_FILE"
        clear
        bn_banner

        printf "${CYAN}┌──────────── [ Kelola User ID Bot ] ──────────────┐${NC}\n"
        local idx=0
        local ids_spaced="$(printf '%s' "$CHAT_ID" | tr ',;' '  ')"
        for uid in $ids_spaced; do
            [ -z "$uid" ] && continue
            idx=$((idx + 1))
            local p_line="$(printf "   %2d. %s" "$idx" "$uid")"
            local c_line="$(printf "   ${GREEN}%2d.${NC} ${WHITE}%s${NC}" "$idx" "$uid")"
            bn_box_line "$CYAN" "$p_line" "$c_line"
        done
        if [ "$idx" -eq 0 ]; then
            bn_box_line "$CYAN" "   (Belum ada User ID terdaftar)" "   ${GRAY}(Belum ada User ID terdaftar)${NC}"
        fi
        printf "${CYAN}└────────────────────────────────────────────────────┘${NC}\n\n"

        printf "${GREEN}  [1]${NC} Tambah User ID Baru\n"
        printf "${RED}  [2]${NC} Hapus User ID\n"
        printf "${YELLOW}  [0]${NC} Kembali\n\n"
        printf "${WHITE}Pilih opsi: ${NC}"
        read sub_opt

        case "$sub_opt" in
            1)
                printf "\n${CYAN}Masukkan User ID / Chat ID Telegram baru${NC}\n"
                printf "${GRAY}(Contoh: 123456789 atau -1001234567890 untuk grup)${NC}\n"
                printf "${WHITE}User ID : ${NC}"
                read new_uid
                new_uid="$(printf '%s' "$new_uid" | tr -d ' \r\n')"
                case "$new_uid" in
                    ''|*[!0-9-]*)
                        printf "${RED}✖ Format User ID tidak valid! Harus berupa angka.${NC}\n"
                        sleep 2
                        ;;
                    *)
                        if printf ',%s,' "$CHAT_ID" | grep -q ",${new_uid},"; then
                            printf "${YELLOW}! User ID %s sudah terdaftar.${NC}\n" "$new_uid"
                            sleep 2
                        else
                            [ -z "$CHAT_ID" ] && updated_ids="$new_uid" || updated_ids="${CHAT_ID},${new_uid}"
                            if grep -q '^CHAT_ID=' "$CONF_FILE" 2>/dev/null; then
                                sed -i "s|^CHAT_ID=.*|CHAT_ID=\"${updated_ids}\"|" "$CONF_FILE"
                            else
                                printf 'CHAT_ID="%s"\n' "$updated_ids" >> "$CONF_FILE"
                            fi
                            printf "${GREEN}✔ User ID %s berhasil ditambahkan!${NC}\n" "$new_uid"

                            if [ -n "$TELEGRAM_TOKEN" ]; then
                                curl -k -s --connect-timeout 5 -m 8 -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
                                    -d "chat_id=${new_uid}" \
                                    --data-urlencode "text=✅ User ID Anda (${new_uid}) berhasil ditambahkan ke KIHEO-BOT (${ROUTER_NAME:-Router})!" \
                                    -d "parse_mode=HTML" >/dev/null 2>&1 &
                            fi

                            if pgrep -f "/usr/bin/telenotif" >/dev/null 2>&1; then
                                /usr/bin/resbotnotif >/dev/null 2>&1
                                printf "${CYAN}↻ Bot otomatis di-restart untuk memuat User ID baru.${NC}\n"
                            fi
                            sleep 2
                        fi
                        ;;
                esac
                ;;
            2)
                printf "\n${WHITE}Masukkan User ID yang ingin dihapus: ${NC}"
                read del_uid
                del_uid="$(printf '%s' "$del_uid" | tr -d ' \r\n')"
                [ -z "$del_uid" ] && continue
                new_list=""
                found=0
                for uid in $(printf '%s' "$CHAT_ID" | tr ',;' '  '); do
                    [ -z "$uid" ] && continue
                    if [ "$uid" = "$del_uid" ]; then
                        found=1
                    else
                        [ -z "$new_list" ] && new_list="$uid" || new_list="${new_list},${uid}"
                    fi
                done
                if [ "$found" -eq 1 ]; then
                    sed -i "s|^CHAT_ID=.*|CHAT_ID=\"${new_list}\"|" "$CONF_FILE"
                    printf "${GREEN}✔ User ID %s berhasil dihapus!${NC}\n" "$del_uid"
                    pgrep -f "/usr/bin/telenotif" >/dev/null 2>&1 && /usr/bin/resbotnotif >/dev/null 2>&1
                else
                    printf "${RED}✖ User ID %s tidak ditemukan.${NC}\n" "$del_uid"
                fi
                sleep 2
                ;;
            0) break ;;
        esac
    done
}

botnotif_menu() {
    while true; do
        clear
        bn_banner

        if ! bn_is_installed; then
            printf "${CYAN}┌──────────── [ Modul Bot Notifikasi ] ────────────┐${NC}\n"
            bn_box_line "$CYAN" "   Status Paket : BELUM TERPASANG" "   ${CYAN}Status Paket :${NC} ${RED}BELUM TERPASANG${NC}"
            bn_box_line "$CYAN" "   Fungsi       : Monitor Perangkat LAN/Wi-Fi" "   ${CYAN}Fungsi       :${NC} ${WHITE}Monitor Perangkat LAN/Wi-Fi${NC}"
            printf "${CYAN}└────────────────────────────────────────────────────┘${NC}\n\n"

            printf "${RED}┌────────────────── - Menu Modul - ──────────────────┐${NC}\n"
            bn_box_line "$RED" "  ID  Action" "  ${MAGENTA}ID  Action${NC}"
            bn_box_line "$RED" "   I  Install Bot Notifikasi Sekarang" "   ${GREEN}I${NC}  ${WHITE}Install Bot Notifikasi Sekarang${NC}"
            bn_box_line "$RED" "   0  Kembali ke Menu Utama kiheo" "   ${GREEN}0${NC}  ${WHITE}Kembali ke Menu Utama kiheo${NC}"
            printf "${RED}└────────────────────────────────────────────────────┘${NC}\n\n"

            printf "${WHITE}Pilih menu: ${NC}"
            read m_opt
            case "$m_opt" in
                i|I|1)
                    bn_install
                    printf "\n${GRAY}Tekan Enter untuk lanjut...${NC}"
                    read _
                    ;;
                0|q|Q) return ;;
                *) printf "\n${RED}Pilihan tidak valid!${NC}\n"; sleep 1 ;;
            esac
        else
            . "$CONF_FILE"
            local pids="$(pgrep -f "/usr/bin/telenotif" | tr '\n' ' ' | sed 's/ $//')"
            local st_plain st_color
            if [ -n "$pids" ]; then
                st_plain="AKTIF (PID: ${pids})"
                st_color="${GREEN}AKTIF${NC} ${GRAY}(PID: ${pids})${NC}"
            else
                st_plain="MATI / STOPPED"
                st_color="${RED}MATI / STOPPED${NC}"
            fi

            local online_cnt=0
            [ -s "$STATE_FILE" ] && online_cnt=$(awk -F'|' '($5=="" || $5==0){c++} END{print c+0}' "$STATE_FILE")
            local masked_tok="$(bn_mask_token "${TELEGRAM_TOKEN:-none}")"

            printf "${CYAN}┌──────────── [ Info Bot Notifikasi ] ─────────────┐${NC}\n"
            bn_box_line "$CYAN" "      Router: ${ROUTER_NAME:-KIHEO} (${FALLBACK_IFACE:-br-lan})" "      ${CYAN}Router:${NC} ${WHITE}${ROUTER_NAME:-KIHEO}${NC} (${FALLBACK_IFACE:-br-lan})"
            bn_box_line "$CYAN" "      Status: ${st_plain}" "      ${CYAN}Status:${NC} ${st_color}"
            bn_box_line "$CYAN" "     User ID: ${CHAT_ID:--}" "     ${CYAN}User ID:${NC} ${MAGENTA}${CHAT_ID:--}${NC}"
            bn_box_line "$CYAN" "   Perangkat: ${online_cnt} Online | Probe ${MAX_MISSES:-4}x/${PROBE_INTERVAL:-2}s" "   ${CYAN}Perangkat:${NC} ${GREEN}${online_cnt} Online${NC} | Probe ${YELLOW}${MAX_MISSES:-4}x/${PROBE_INTERVAL:-2}s${NC}"
            bn_box_line "$CYAN" "       Token: ${masked_tok}" "       ${CYAN}Token:${NC} ${RED}${masked_tok}${NC}"
            printf "${CYAN}└────────────────────────────────────────────────────┘${NC}\n\n"

            printf "${RED}┌──────────────── - Menu Bot Notif - ────────────────┐${NC}\n"
            bn_box_line "$RED" "  ID  Action" "  ${MAGENTA}ID  Action${NC}"
            bn_box_line "$RED" "   1  Start / Restart Bot (resbotnotif)" "   ${GREEN}1${NC}  ${WHITE}Start / Restart Bot${NC} ${CYAN}(resbotnotif)${NC}"
            bn_box_line "$RED" "   2  Cek Status & Perangkat Aktif (cekbot)" "   ${GREEN}2${NC}  ${WHITE}Cek Status & Perangkat${NC} ${GREEN}(cekbot)${NC}"
            bn_box_line "$RED" "   3  Stop / Matikan Bot (stopbotnotif)" "   ${GREEN}3${NC}  ${WHITE}Stop / Matikan Bot${NC} ${RED}(stopbotnotif)${NC}"
            bn_box_line "$RED" "   4  Tambah / Kelola User ID Bot" "   ${GREEN}4${NC}  ${WHITE}Tambah / Kelola${NC} ${MAGENTA}User ID Bot${NC}"
            bn_box_line "$RED" "   5  Install Ulang / Re-Konfigurasi Bot Notif" "   ${GREEN}5${NC}  ${WHITE}Install Ulang / Re-Konfigurasi${NC}"
            bn_box_line "$RED" "   6  Hapus / Uninstall Bot Notif" "   ${GREEN}6${NC}  ${WHITE}Hapus / Uninstall Bot Notif${NC}"
            bn_box_line "$RED" "   0  Kembali ke Menu Utama kiheo" "   ${GREEN}0${NC}  ${WHITE}Kembali ke Menu Utama kiheo${NC}"
            printf "${RED}└────────────────────────────────────────────────────┘${NC}\n\n"

            printf "${WHITE}Pilih menu: ${NC}"
            read m_opt
            case "$m_opt" in
                1)
                    printf "\n"
                    /usr/bin/resbotnotif
                    printf "\n${GRAY}Tekan Enter untuk kembali...${NC}"
                    read _
                    ;;
                2)
                    clear
                    /usr/bin/cekbot
                    printf "\n${GRAY}Tekan Enter untuk kembali...${NC}"
                    read _
                    ;;
                3)
                    printf "\n"
                    /usr/bin/stopbotnotif
                    printf "\n${GRAY}Tekan Enter untuk kembali...${NC}"
                    read _
                    ;;
                4)
                    bn_manage_user_ids
                    ;;
                5)
                    bn_install
                    printf "\n${GRAY}Tekan Enter untuk kembali...${NC}"
                    read _
                    ;;
                6)
                    printf "\n${RED}Yakin hapus Bot Notifikasi? [y/N]: ${NC}"
                    read cf
                    case "$cf" in
                        y|Y)
                            bn_uninstall_only
                            printf "\n${GRAY}Tekan Enter untuk kembali...${NC}"
                            read _
                            ;;
                    esac
                    ;;
                0|q|Q) return ;;
                *) printf "\n${RED}Pilihan tidak valid!${NC}\n"; sleep 1 ;;
            esac
        fi
    done
}
EOF_MOD_NOTIF
chmod +x /usr/lib/kiheo/modules/botnotif.sh

# ====================================================
# BAGIAN 2: LAUNCHER UTAMA (/usr/bin/kiheo)
# ====================================================
printf "${BLUE}[2/2] Membuat Launcher Utama 'kiheo'...${NC}\n"

cat << 'EOF_KIHEO_MAIN' > /usr/bin/kiheo
#!/bin/sh

PLUGIN_DIR="/etc/kiheo/plugins"
MODULE_DIR="/usr/lib/kiheo/modules"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

mkdir -p "$PLUGIN_DIR" "$MODULE_DIR"

[ -f "$MODULE_DIR/botnotif.sh" ] && . "$MODULE_DIR/botnotif.sh"

kh_spaces() {
    local n="$1" s="" i=0
    while [ $i -lt $n ]; do s="${s} "; i=$((i + 1)); done
    printf '%s' "$s"
}

kh_box_line() {
    local bcolor="$1"
    local plain="$2"
    local colored="$3"
    local inner=52
    local len=${#plain}
    local pad=$((inner - len))
    [ $pad -lt 0 ] && pad=0
    printf "${bcolor}│${NC}%b%s${bcolor}│${NC}\n" "$colored" "$(kh_spaces "$pad")"
}

if [ ! -f "$PLUGIN_DIR/contoh_bot.sh.example" ]; then
    cat << 'EOF_EXAMPLE' > "$PLUGIN_DIR/contoh_bot.sh.example"
#!/bin/sh
# MENU_NAME: Bot Proyek Baru (Contoh)
# Ubah ekstensi file ini dari .sh.example menjadi .sh agar otomatis muncul di menu 'kiheo'

echo "Menjalankan Bot Proyek Baru..."
sleep 2
EOF_EXAMPLE
fi

uninstall_kiheo_hub() {
    printf "\n${RED}Hapus KIHEO-BOT Hub beserta seluruh modulnya? [y/N]: ${NC}"
    read cf
    case "$cf" in
        y|Y)
            [ -x /usr/bin/stopbotnotif ] && /usr/bin/stopbotnotif >/dev/null 2>&1
            if [ -f /etc/init.d/telenotif ]; then
                /etc/init.d/telenotif disable 2>/dev/null
                rm -f /etc/init.d/telenotif
            fi
            rm -rf /usr/lib/kiheo /etc/kiheo /usr/bin/kiheo \
                   /usr/bin/telenotif /usr/bin/telenotif-status /usr/bin/cekbot \
                   /usr/bin/resbotnotif /usr/bin/stopbotnotif /etc/telenotif.conf \
                   /tmp/telenotif_*.txt /tmp/chilli_raw.txt
            printf "${GREEN}✔ KIHEO-BOT Hub berhasil dihapus total.${NC}\n"
            exit 0
            ;;
    esac
}

while true; do
    HOSTNAME_SYS="$(uci get system.@system[0].hostname 2>/dev/null || uname -n)"
    UPTIME_SYS="$(uptime | awk -F'( |,|:)+' '{print $6"h "$7"m"}' 2>/dev/null)"
    LAN_IP="$(uci get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1")"

    if [ -x /usr/bin/telenotif ] && [ -f /etc/telenotif.conf ]; then
        if pgrep -f "/usr/bin/telenotif" >/dev/null 2>&1; then
            NOTIF_ST_PLAIN="AKTIF (Running)"
            NOTIF_ST_COLOR="${GREEN}AKTIF${NC} ${GRAY}(Running)${NC}"
            NOTIF_MENU_PLAIN="   1  Bot Notif Telegram [AKTIF]"
            NOTIF_MENU_COLOR="   ${GREEN}1${NC}  ${WHITE}Bot Notif Telegram${NC} ${GREEN}[AKTIF]${NC}"
        else
            NOTIF_ST_PLAIN="TERPASANG (Stopped)"
            NOTIF_ST_COLOR="${YELLOW}TERPASANG${NC} ${RED}(Stopped)${NC}"
            NOTIF_MENU_PLAIN="   1  Bot Notif Telegram [STOPPED]"
            NOTIF_MENU_COLOR="   ${GREEN}1${NC}  ${WHITE}Bot Notif Telegram${NC} ${YELLOW}[STOPPED]${NC}"
        fi
    else
        NOTIF_ST_PLAIN="BELUM TERPASANG"
        NOTIF_ST_COLOR="${RED}BELUM TERPASANG${NC}"
        NOTIF_MENU_PLAIN="   1  Bot Notif Telegram [Install]"
        NOTIF_MENU_COLOR="   ${GREEN}1${NC}  ${WHITE}Bot Notif Telegram${NC} ${CYAN}[Install]${NC}"
    fi

    PLUGIN_COUNT=0
    for f in "$PLUGIN_DIR"/*.sh; do
        [ -f "$f" ] && PLUGIN_COUNT=$((PLUGIN_COUNT + 1))
    done

    clear
    printf "${CYAN}"
    printf "    ╔═╗ ╔═╗╔═╗╔═╗╔═╗╔═══╗╔═══╗    ╔═══╗╔═══╗╔═══╗\n"
    printf "    ║ ║╔╝╔╝║ ║║ ║║ ║║ ╔═╝║ ╔╗║    ║ ╔╗║║ ╔╗║╚╗ ╔╝\n"
    printf "    ║ ╚╝╔╝ ║ ║║ ╚╝ ║║ ╚═╗║ ║║║╔══╗║ ╚╝╣║ ║║║ ║ ║ \n"
    printf "    ║ ╔╗╚╗ ║ ║║ ╔╗ ║║ ╔═╝║ ║║║╚══╝║ ╔╗╣║ ║║║ ║ ║ \n"
    printf "    ║ ║╚╗╚╗║ ║║ ║║ ║║ ╚═╗║ ╚╝║    ║ ╚╝║║ ╚╝║ ║ ║ \n"
    printf "    ╚═╝ ╚═╝╚═╝╚═╝╚═╝╚═══╝╚═══╝    ╚═══╝╚═══╝ ╚═╝ \n"
    printf "${NC}\n"

    printf "${CYAN}┌─────────────── [ Informasi Sistem ] ───────────────┐${NC}\n"
    kh_box_line "$CYAN" "       Host : ${HOSTNAME_SYS} (${LAN_IP})" "       ${CYAN}Host :${NC} ${WHITE}${HOSTNAME_SYS}${NC} (${LAN_IP})"
    kh_box_line "$CYAN" "     Uptime : ${UPTIME_SYS}" "     ${CYAN}Uptime :${NC} ${WHITE}${UPTIME_SYS}${NC}"
    kh_box_line "$CYAN" "  Bot Notif : ${NOTIF_ST_PLAIN}" "  ${CYAN}Bot Notif :${NC} ${NOTIF_ST_COLOR}"
    kh_box_line "$CYAN" "    Plugins : ${PLUGIN_COUNT} Proyek Bot Tambahan" "    ${CYAN}Plugins :${NC} ${MAGENTA}${PLUGIN_COUNT} Proyek Bot Tambahan${NC}"
    kh_box_line "$CYAN" "     Folder : /etc/kiheo/plugins/" "     ${CYAN}Folder :${NC} ${YELLOW}/etc/kiheo/plugins/${NC}"
    printf "${CYAN}└────────────────────────────────────────────────────┘${NC}\n\n"

    printf "${RED}┌───────────────── - Menu Utama - ───────────────────┐${NC}\n"
    kh_box_line "$RED" "  ID  Action" "  ${MAGENTA}ID  Action${NC}"
    kh_box_line "$RED" "$NOTIF_MENU_PLAIN" "$NOTIF_MENU_COLOR"

    IDX=1
    PLUGIN_MAP=""
    for pfile in "$PLUGIN_DIR"/*.sh; do
        [ -f "$pfile" ] || continue
        IDX=$((IDX + 1))
        PNAME="$(grep -m1 '^# MENU_NAME:' "$pfile" | sed 's/^# MENU_NAME:[[:space:]]*//')"
        [ -z "$PNAME" ] && PNAME="$(basename "$pfile" .sh)"
        PNAME_TRIM="$(printf '%s' "$PNAME" | cut -c1-36)"
        kh_box_line "$RED" "$(printf "  %2d  %s" "$IDX" "$PNAME_TRIM")" "  ${GREEN}$(printf "%2d" "$IDX")${NC}  ${WHITE}${PNAME_TRIM}${NC}"
        PLUGIN_MAP="${PLUGIN_MAP}${IDX}:${pfile}|"
    done

    kh_box_line "$RED" "   I  Quick Install Bot Notif" "   ${GREEN}I${NC}  ${CYAN}Quick Install Bot Notif${NC}"
    kh_box_line "$RED" "   U  Uninstall KIHEO-BOT Hub" "   ${GREEN}U${NC}  ${YELLOW}Uninstall KIHEO-BOT Hub${NC}"
    kh_box_line "$RED" "   0  Keluar" "   ${GREEN}0${NC}  ${WHITE}Keluar${NC}"
    printf "${RED}└────────────────────────────────────────────────────┘${NC}\n\n"

    printf "${WHITE}Pilih menu: ${NC}"
    read CHOICE

    case "$CHOICE" in
        1)
            botnotif_menu
            ;;
        i|I)
            bn_install
            printf "\n${GRAY}Tekan Enter untuk kembali ke menu kiheo...${NC}"
            read _
            ;;
        u|U)
            uninstall_kiheo_hub
            ;;
        0|99|q|Q|exit)
            printf "\n${CYAN}Keluar dari KIHEO-BOT. Ketik 'kiheo' untuk membuka lagi.${NC}\n"
            exit 0
            ;;
        *)
            TARGET_SCRIPT=""
            OLD_IFS="$IFS"
            IFS='|'
            for entry in $PLUGIN_MAP; do
                [ -z "$entry" ] && continue
                entry_id="${entry%%:*}"
                entry_path="${entry#*:}"
                if [ "$CHOICE" = "$entry_id" ]; then
                    TARGET_SCRIPT="$entry_path"
                    break
                fi
            done
            IFS="$OLD_IFS"

            if [ -n "$TARGET_SCRIPT" ] && [ -f "$TARGET_SCRIPT" ]; then
                clear
                sh "$TARGET_SCRIPT"
                printf "\n${GRAY}Tekan Enter untuk kembali ke menu kiheo...${NC}"
                read _
            else
                printf "\n${RED}Pilihan tidak valid!${NC}\n"
                sleep 1
            fi
            ;;
    esac
done
EOF_KIHEO_MAIN
chmod +x /usr/bin/kiheo

printf "\n${CYAN}====================================================${NC}\n"
printf "${GREEN}       KIHEO-BOT HUB BERHASIL TERPASANG!            ${NC}\n"
printf "${CYAN}====================================================${NC}\n"
printf "Buka Menu Bot      : Ketik ${CYAN}kiheo${NC}\n"
printf "Folder Bot Lain    : ${YELLOW}/etc/kiheo/plugins/${NC}\n"
printf "${CYAN}====================================================${NC}\n"
