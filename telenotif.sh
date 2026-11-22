#!/bin/sh

# ====================================================
#   KIHEO-BOT HUB INSTALLER (UNIFIED CYBER PANEL UI)
#   Command Utama: kiheo
#   Support: OpenWrt 21.02 - 25.12+ (opkg & apk)
# ====================================================

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

mkdir -p /usr/lib/kiheo/modules
mkdir -p /etc/kiheo/plugins

# ====================================================
# 1. LIBRARY UI TERPUSAT (/usr/lib/kiheo/ui.sh)
# ====================================================
cat << 'EOF_UI' > /usr/lib/kiheo/ui.sh
#!/bin/sh

CYAN='\033[0;36m'
BCYAN='\033[1;36m'
GREEN='\033[0;32m'
BGREEN='\033[1;32m'
RED='\033[0;31m'
BRED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BMAGENTA='\033[1;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

ui_repeat() {
    local ch="$1" n="$2" out="" i=0
    while [ $i -lt $n ]; do
        out="${out}${ch}"
        i=$((i + 1))
    done
    printf '%s' "$out"
}

ui_banner() {
    printf "${BCYAN}"
    printf "    ╔═╗ ╔═╗╔═╗╔═╗╔═╗╔═══╗╔═══╗    ╔═══╗╔═══╗╔═══╗\n"
    printf "    ║ ║╔╝╔╝║ ║║ ║║ ║║ ╔═╝║ ╔╗║    ║ ╔╗║║ ╔╗║╚╗ ╔╝\n"
    printf "    ║ ╚╝╔╝ ║ ║║ ╚╝ ║║ ╚═╗║ ║║║╔══╗║ ╚╝╣║ ║║║ ║ ║ \n"
    printf "    ║ ╔╗╚╗ ║ ║║ ╔╗ ║║ ╔═╝║ ║║║╚══╝║ ╔╗╣║ ║║║ ║ ║ \n"
    printf "    ║ ║╚╗╚╗║ ║║ ║║ ║║ ╚═╗║ ╚╝║    ║ ╚╝║║ ╚╝║ ║ ║ \n"
    printf "    ╚═╝ ╚═╝╚═╝╚═╝╚═╝╚═══╝╚═══╝    ╚═══╝╚═══╝ ╚═╝ \n"
    printf "${NC}\n"
}

# Header kotak rounded lebar total 54 kolom (inner = 52)
# Argumen: $1=border_color, $2=title_color, $3=title_ascii_len, $4=title_display
ui_panel_top() {
    local bcolor="$1"
    local tcolor="$2"
    local title_ascii="$3"
    local title_disp="$4"
    local inner=52
    local tlen=$(( ${#title_ascii} + 2 ))
    local left=$(( (inner - tlen) / 2 ))
    local right=$(( inner - tlen - left ))
    printf "${bcolor}╭%s ${tcolor}%s${bcolor} %s╮${NC}\n" \
        "$(ui_repeat "─" "$left")" "$title_disp" "$(ui_repeat "─" "$right")"
}

# Baris kotak rounded lebar inner 52 kolom
# Catatan: $2 (plain) harus ASCII murni 1-byte agar lebar kolom 100% presisi
ui_panel_line() {
    local bcolor="$1"
    local plain="$2"
    local colored="$3"
    local inner=52
    local len=${#plain}
    local pad=$((inner - len))
    [ $pad -lt 0 ] && pad=0
    printf "${bcolor}│${NC}%b%s${bcolor}│${NC}\n" "$colored" "$(ui_repeat " " "$pad")"
}

# Baris Key-Value rata kanan pada titik dua (kolom ke-14)
ui_panel_kv() {
    local bcolor="$1"
    local key="$2"
    local val_plain="$3"
    local val_colored="$4"
    local key_pad=$((13 - ${#key}))
    [ $key_pad -lt 1 ] && key_pad=1
    local prefix_plain="$(ui_repeat " " "$key_pad")${key} : "
    local prefix_color="$(ui_repeat " " "$key_pad")${CYAN}${key}${NC} : "
    ui_panel_line "$bcolor" "${prefix_plain}${val_plain}" "${prefix_color}${val_colored}"
}

ui_panel_bot() {
    local bcolor="$1"
    printf "${bcolor}╰%s╯${NC}\n" "$(ui_repeat "─" 52)"
}

ui_get_uptime() {
    if [ -r /proc/uptime ]; then
        awk '{
            t = int($1)
            d = int(t / 86400)
            h = int((t % 86400) / 3600)
            m = int((t % 3600) / 60)
            s = t % 60
            printf "%dd %dh %dm %ds", d, h, m, s
        }' /proc/uptime
    else
        printf '%s' "0d 0h 0m 0s"
    fi
}

ui_get_localtime() {
    local raw
    raw="$(date +"%d %b %Y, %H.%M.%S %Z" 2>/dev/null)"
    case "$raw" in
        *UTC) raw="${raw%UTC}WIB" ;;
    esac
    printf '%s' "$raw"
}
EOF_UI
chmod +x /usr/lib/kiheo/ui.sh

# ====================================================
# 2. SCRIPT DAEMON & PERINTAH CLI BOT NOTIF
# ====================================================
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

# Perintah: resbotnotif
cat << 'EOF_RES' > /usr/bin/resbotnotif
#!/bin/sh
. /usr/lib/kiheo/ui.sh

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
PIDS="$(pgrep -f "/usr/bin/telenotif" | tr '\n' ' ' | sed 's/ $//')"

ui_panel_top "$CYAN" "$BGREEN" "[ Kontrol Bot Notif ]" "[ Kontrol Bot Notif ]"
if [ -n "$PIDS" ]; then
    ui_panel_kv "$CYAN" "Aksi" "Start / Restart Bot" "${WHITE}Start / Restart Bot${NC}"
    ui_panel_kv "$CYAN" "Status" "* AKTIF (PID: ${PIDS})" "${BGREEN}● AKTIF${NC} ${GRAY}(PID: ${PIDS})${NC}"
else
    ui_panel_kv "$CYAN" "Aksi" "Start / Restart Bot" "${WHITE}Start / Restart Bot${NC}"
    ui_panel_kv "$CYAN" "Status" "* GAGAL MENJALANKAN" "${BRED}● GAGAL MENJALANKAN${NC}"
fi
ui_panel_bot "$CYAN"
EOF_RES
chmod +x /usr/bin/resbotnotif

# Perintah: stopbotnotif
cat << 'EOF_STOP' > /usr/bin/stopbotnotif
#!/bin/sh
. /usr/lib/kiheo/ui.sh

[ -f /etc/init.d/telenotif ] && /etc/init.d/telenotif stop >/dev/null 2>&1
for pid in $(pgrep -f "/usr/bin/telenotif"); do
    kill -9 "$pid" 2>/dev/null
done
rm -f /tmp/telenotif_current.txt /tmp/telenotif_candidates.txt /tmp/telenotif_wifi_assoc.txt /tmp/chilli_raw.txt

ui_panel_top "$CYAN" "$BGREEN" "[ Kontrol Bot Notif ]" "[ Kontrol Bot Notif ]"
ui_panel_kv "$CYAN" "Aksi" "Stop / Matikan Bot" "${WHITE}Stop / Matikan Bot${NC}"
ui_panel_kv "$CYAN" "Status" "* STOPPED (Mati)" "${BRED}● STOPPED${NC} ${GRAY}(Mati)${NC}"
ui_panel_kv "$CYAN" "Lanjut" "Ketik 'resbotnotif'" "${YELLOW}Ketik 'resbotnotif'${NC}"
ui_panel_bot "$CYAN"
EOF_STOP
chmod +x /usr/bin/stopbotnotif

# Perintah: cekbot & telenotif-status (Kotak Rounded Penuh Presisi)
cat << 'EOF_CEK' > /usr/bin/cekbot
#!/bin/sh
. /usr/lib/kiheo/ui.sh
[ -f /etc/telenotif.conf ] && . /etc/telenotif.conf
: "${MAX_MISSES:=4}"
: "${PROBE_INTERVAL:=2}"

PIDS="$(pgrep -f "/usr/bin/telenotif" | tr '\n' ' ' | sed 's/ $//')"
NOW_TIME="$(ui_get_localtime)"

ui_panel_top "$CYAN" "$BGREEN" "[ Status Bot Notifikasi ]" "[ Status Bot Notifikasi ]"
if [ -n "$PIDS" ]; then
    ui_panel_kv "$CYAN" "Status" "* AKTIF (PID: ${PIDS})" "${BGREEN}● AKTIF${NC} ${GRAY}(PID: ${PIDS})${NC}"
else
    ui_panel_kv "$CYAN" "Status" "* MATI / STOPPED" "${BRED}● MATI / STOPPED${NC}"
fi
ui_panel_kv "$CYAN" "Router / LAN" "${ROUTER_NAME:-KIHEO} (${FALLBACK_IFACE:-br-lan})" "${WHITE}${ROUTER_NAME:-KIHEO}${NC} ${GRAY}(${FALLBACK_IFACE:-br-lan})${NC}"
ui_panel_kv "$CYAN" "Local Time" "${NOW_TIME}" "${WHITE}${NOW_TIME}${NC}"
ui_panel_kv "$CYAN" "User ID Bot" "${CHAT_ID:--}" "${BMAGENTA}${CHAT_ID:--}${NC}"
ui_panel_kv "$CYAN" "Mode Probe" "${MAX_MISSES}x gagal (interval ${PROBE_INTERVAL}s)" "${YELLOW}${MAX_MISSES}x gagal${NC} (interval ${CYAN}${PROBE_INTERVAL}s${NC})"
ui_panel_bot "$CYAN"

printf "\n"

ui_panel_top "$BRED" "$BGREEN" ". Perangkat Terdeteksi ." "• Perangkat Terdeteksi •"
ui_panel_line "$BRED" \
    " MAC Address       IP Address     Host       Status " \
    " ${BMAGENTA}MAC Address       IP Address     Host       Status${NC} "

if [ -s /tmp/telenotif_state.txt ]; then
    while IFS='|' read -r mac ip iface host miss; do
        [ -z "$mac" ] && continue
        [ -z "$miss" ] && miss=0
        mac_f="$(printf '%-17s' "$mac" | cut -c1-17)"
        ip_f="$(printf '%-14s' "$ip" | cut -c1-14)"
        host_f="$(printf '%-10s' "$host" | cut -c1-10)"
        if [ "$miss" -eq 0 ]; then
            st_plain="ONLINE"
            st_color="${BGREEN}ONLINE${NC}"
        else
            st_plain="$(printf 'RTRY %s' "$miss" | cut -c1-6)"
            st_plain="$(printf '%-6s' "$st_plain")"
            st_color="${YELLOW}${st_plain}${NC}"
        fi
        row_plain=" ${mac_f} ${ip_f} ${host_f} ${st_plain} "
        row_color=" ${WHITE}${mac_f}${NC} ${CYAN}${ip_f}${NC} ${WHITE}${host_f}${NC} ${st_color} "
        ui_panel_line "$BRED" "$row_plain" "$row_color"
    done < /tmp/telenotif_state.txt
else
    ui_panel_line "$BRED" \
        "   (Belum ada perangkat aktif yang terdeteksi)     " \
        "   ${GRAY}(Belum ada perangkat aktif yang terdeteksi)${NC}     "
fi
ui_panel_bot "$BRED"
EOF_CEK
chmod +x /usr/bin/cekbot
ln -sf /usr/bin/cekbot /usr/bin/telenotif-status

# ====================================================
# 3. MODUL BOT NOTIFIKASI (/usr/lib/kiheo/modules/botnotif.sh)
# ====================================================
cat << 'EOF_MOD_NOTIF' > /usr/lib/kiheo/modules/botnotif.sh
#!/bin/sh

. /usr/lib/kiheo/ui.sh

CONF_FILE="/etc/telenotif.conf"
STATE_FILE="/tmp/telenotif_state.txt"

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
        printf "\r  ${YELLOW}[%s] %3d%% - %-32s${NC}" "$bar" "$current" "$text"
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
        printf "\r  ${YELLOW}[%s] %3d%% - %-32s${NC}" "$bar" "$current" "$text"
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
    ui_banner
    ui_panel_top "$CYAN" "$BGREEN" "[ Instalasi Bot Notifikasi ]" "[ Instalasi Bot Notifikasi ]"
    ui_panel_line "$CYAN" "  Memeriksa modul curl & arping pada OpenWrt...     " "  ${WHITE}Memeriksa modul curl & arping pada OpenWrt...${NC}     "
    ui_panel_bot "$CYAN"
    printf "\n"

    if command -v apk >/dev/null 2>&1; then
        bn_progress 0 30 "Update repository apk..." "apk update"
        bn_progress 30 65 "Memeriksa modul curl..." "apk info -e curl || apk add curl"
        bn_progress 65 100 "Memeriksa modul arping..." "apk info -e arping || apk add arping"
    elif command -v opkg >/dev/null 2>&1; then
        bn_progress 0 30 "Update repository opkg..." "opkg update"
        bn_progress 30 65 "Memeriksa modul curl..." "opkg list-installed | grep -q '^curl ' || opkg install curl"
        bn_progress 65 100 "Memeriksa modul arping..." "opkg list-installed | grep -q '^arping ' || opkg install arping"
    fi
    printf "\n\n${BGREEN}✔ Modul pendukung siap!${NC}\n\n"

    ui_panel_top "$MAGENTA" "$BMAGENTA" "KONFIGURASI BOT TELEGRAM" "KONFIGURASI BOT TELEGRAM"
    ui_panel_line "$MAGENTA" "  Isi parameter bot di bawah ini dengan benar:    " "  ${WHITE}Isi parameter bot di bawah ini dengan benar:${NC}    "
    ui_panel_bot "$MAGENTA"
    printf "\n"

    local USER_TOKEN=""
    while [ -z "$USER_TOKEN" ]; do
        printf "${CYAN}Token Bot Telegram${NC}             : "
        read USER_TOKEN
        [ -z "$USER_TOKEN" ] && printf "${RED}Token tidak boleh kosong!${NC}\n"
    done

    local USER_CHAT_ID=""
    while [ -z "$USER_CHAT_ID" ]; do
        printf "${CYAN}Chat / User ID Telegram${NC}        : "
        read USER_CHAT_ID
        [ -z "$USER_CHAT_ID" ] && printf "${RED}Chat ID tidak boleh kosong!${NC}\n"
    done

    printf "${CYAN}Nama Router [Default: KIHEO]${NC}   : "
    read USER_ROUTER_NAME
    [ -z "$USER_ROUTER_NAME" ] && ROUTER_NAME="KIHEO" || ROUTER_NAME="$USER_ROUTER_NAME"

    printf "${CYAN}Interface LAN [Default: br-lan]${NC}: "
    read USER_IFACE
    [ -z "$USER_IFACE" ] && FALLBACK_IFACE="br-lan" || FALLBACK_IFACE="$USER_IFACE"

    printf "${CYAN}Batas Gagal Probe [Default: 4]${NC} : "
    read USER_MAX_MISSES
    case "$USER_MAX_MISSES" in
        ''|*[!0-9]*|0) MAX_MISSES=4 ;;
        *) MAX_MISSES="$USER_MAX_MISSES" ;;
    esac

    printf "${CYAN}Interval Cek Detik [Default: 2]${NC}: "
    read USER_INTERVAL
    case "$USER_INTERVAL" in
        ''|*[!0-9]*|0) PROBE_INTERVAL=2 ;;
        *) PROBE_INTERVAL="$USER_INTERVAL" ;;
    esac

    WIFI_INACTIVE_MAX=20000
    INSTALL_TIME="$(ui_get_localtime)"

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

    printf "\n"
    /usr/bin/resbotnotif
}

bn_uninstall_only() {
    if [ -f /etc/init.d/telenotif ]; then
        /etc/init.d/telenotif stop 2>/dev/null
        /etc/init.d/telenotif disable 2>/dev/null
        rm -f /etc/init.d/telenotif
    fi
    for pid in $(pgrep -f "/usr/bin/telenotif"); do
        kill -9 "$pid" 2>/dev/null
    done
    rm -f "$CONF_FILE" /tmp/telenotif_*.txt /tmp/chilli_raw.txt
    printf "\n"
    ui_panel_top "$CYAN" "$BGREEN" "[ Uninstall Bot Notif ]" "[ Uninstall Bot Notif ]"
    ui_panel_line "$CYAN" "  Konfigurasi & layanan Bot Notif telah dihapus.    " "  ${BGREEN}✔ Konfigurasi & layanan Bot Notif dihapus.${NC}    "
    ui_panel_line "$CYAN" "  Menu utama 'kiheo' tetap aktif & siap digunakan.  " "  ${WHITE}Menu utama 'kiheo' tetap aktif & siap digunakan.${NC}  "
    ui_panel_bot "$CYAN"
}

bn_manage_user_ids() {
    while true; do
        [ -f "$CONF_FILE" ] && . "$CONF_FILE"
        clear
        ui_banner

        ui_panel_top "$CYAN" "$BGREEN" "[ Daftar User ID Bot ]" "[ Daftar User ID Bot ]"
        ui_panel_line "$CYAN" \
            "  No  User / Chat ID         Tipe                   " \
            "  ${BMAGENTA}No  User / Chat ID         Tipe${NC}                   "

        local idx=0
        local ids_spaced="$(printf '%s' "$CHAT_ID" | tr ',;' '  ')"
        for uid in $ids_spaced; do
            [ -z "$uid" ] && continue
            idx=$((idx + 1))
            local id_type="Personal"
            case "$uid" in -*) id_type="Grup / Channel" ;; esac
            local no_f="$(printf '%2d' "$idx")"
            local uid_f="$(printf '%-22s' "$uid" | cut -c1-22)"
            local typ_f="$(printf '%-18s' "$id_type" | cut -c1-18)"
            ui_panel_line "$CYAN" \
                "  ${no_f}  ${uid_f} ${typ_f}   " \
                "  ${BGREEN}${no_f}${NC}  ${WHITE}${uid_f}${NC} ${CYAN}${typ_f}${NC}   "
        done
        if [ "$idx" -eq 0 ]; then
            ui_panel_line "$CYAN" \
                "  (Belum ada User ID yang terdaftar)                " \
                "  ${GRAY}(Belum ada User ID yang terdaftar)${NC}                "
        fi
        ui_panel_bot "$CYAN"

        printf "\n"
        ui_panel_top "$MAGENTA" "$BMAGENTA" "COMMANDS" "COMMANDS"
        ui_panel_line "$MAGENTA" "  1: Tambah User ID Baru                            " "  ${WHITE}1: Tambah User ID Baru${NC}                            "
        ui_panel_line "$MAGENTA" "  2: Hapus User ID                                  " "  ${WHITE}2: Hapus User ID${NC}                                  "
        ui_panel_line "$MAGENTA" "  00: Kembali ke Menu Bot Notif                     " "  ${WHITE}00: Kembali ke Menu Bot Notif${NC}                     "
        ui_panel_bot "$MAGENTA"

        printf "\n${WHITE}Pilihan: ${NC}"
        read sub_opt

        case "$sub_opt" in
            1)
                printf "\n${CYAN}Masukkan User ID / Chat ID Telegram baru${NC}\n"
                printf "${GRAY}(Contoh: 7480651332 atau -1001234567890 untuk grup)${NC}\n"
                printf "${WHITE}User ID: ${NC}"
                read new_uid
                new_uid="$(printf '%s' "$new_uid" | tr -d ' \r\n')"
                case "$new_uid" in
                    ''|*[!0-9-]*)
                        printf "${BRED}✖ Format User ID tidak valid! Harus berupa angka.${NC}\n"
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
                            printf "${BGREEN}✔ User ID %s berhasil ditambahkan!${NC}\n" "$new_uid"

                            if [ -n "$TELEGRAM_TOKEN" ]; then
                                curl -k -s --connect-timeout 5 -m 8 -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
                                    -d "chat_id=${new_uid}" \
                                    --data-urlencode "text=✅ User ID Anda (${new_uid}) berhasil ditambahkan ke KIHEO-BOT (${ROUTER_NAME:-Router})!" \
                                    -d "parse_mode=HTML" >/dev/null 2>&1 &
                            fi

                            if pgrep -f "/usr/bin/telenotif" >/dev/null 2>&1; then
                                /usr/bin/resbotnotif >/dev/null 2>&1
                            fi
                            sleep 1
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
                    printf "${BGREEN}✔ User ID %s berhasil dihapus!${NC}\n" "$del_uid"
                    pgrep -f "/usr/bin/telenotif" >/dev/null 2>&1 && /usr/bin/resbotnotif >/dev/null 2>&1
                else
                    printf "${BRED}✖ User ID %s tidak ditemukan.${NC}\n" "$del_uid"
                fi
                sleep 1
                ;;
            0|00|q|Q) break ;;
        esac
    done
}

botnotif_menu() {
    while true; do
        clear
        ui_banner

        if ! bn_is_installed; then
            ui_panel_top "$CYAN" "$BGREEN" "[ Modul Bot Notifikasi ]" "[ Modul Bot Notifikasi ]"
            ui_panel_kv "$CYAN" "Status" "BELUM TERPASANG" "${BRED}BELUM TERPASANG${NC}"
            ui_panel_kv "$CYAN" "Fungsi" "Monitor Perangkat LAN & Wi-Fi" "${WHITE}Monitor Perangkat LAN & Wi-Fi${NC}"
            ui_panel_bot "$CYAN"

            printf "\n"
            ui_panel_top "$BRED" "$BGREEN" ". Menu Modul ." "• Menu Modul •"
            ui_panel_line "$BRED" \
                "  ID  Action                                        " \
                "  ${BMAGENTA}ID  Action${NC}                                        "
            ui_panel_line "$BRED" \
                "   I  Install Bot Notifikasi Sekarang               " \
                "   ${BGREEN}I${NC}  ${WHITE}Install Bot Notifikasi Sekarang${NC}               "
            ui_panel_line "$BRED" \
                "  00  Kembali ke Menu Utama kiheo                   " \
                "  ${BGREEN}00${NC}  ${WHITE}Kembali ke Menu Utama kiheo${NC}                   "
            ui_panel_bot "$BRED"

            printf "\n${WHITE}Pilih menu: ${NC}"
            read m_opt
            case "$m_opt" in
                i|I|1)
                    bn_install
                    printf "\n${GRAY}Tekan Enter untuk lanjut...${NC}"
                    read _
                    ;;
                0|00|q|Q) return ;;
                *) printf "\n${BRED}Pilihan tidak valid!${NC}\n"; sleep 1 ;;
            esac
        else
            . "$CONF_FILE"
            local pids="$(pgrep -f "/usr/bin/telenotif" | tr '\n' ' ' | sed 's/ $//')"
            local st_plain st_color
            if [ -n "$pids" ]; then
                st_plain="* AKTIF (PID: ${pids})"
                st_color="${BGREEN}● AKTIF${NC} ${GRAY}(PID: ${pids})${NC}"
            else
                st_plain="* MATI / STOPPED"
                st_color="${BRED}● MATI / STOPPED${NC}"
            fi

            local online_cnt=0 retry_cnt=0
            if [ -s "$STATE_FILE" ]; then
                online_cnt=$(awk -F'|' '($5=="" || $5==0){c++} END{print c+0}' "$STATE_FILE")
                retry_cnt=$(awk -F'|' '($5!="" && $5>0){c++} END{print c+0}' "$STATE_FILE")
            fi
            local masked_tok="$(bn_mask_token "${TELEGRAM_TOKEN:-none}")"

            ui_panel_top "$CYAN" "$BGREEN" "[ Info Bot Notifikasi ]" "[ Info Bot Notifikasi ]"
            ui_panel_kv "$CYAN" "Router" "${ROUTER_NAME:-KIHEO} (${FALLBACK_IFACE:-br-lan})" "${WHITE}${ROUTER_NAME:-KIHEO}${NC} ${GRAY}(${FALLBACK_IFACE:-br-lan})${NC}"
            ui_panel_kv "$CYAN" "Status" "${st_plain}" "${st_color}"
            ui_panel_kv "$CYAN" "User ID" "${CHAT_ID:--}" "${BMAGENTA}${CHAT_ID:--}${NC}"
            ui_panel_kv "$CYAN" "Perangkat" "${online_cnt} Online | ${retry_cnt} Retry" "${BGREEN}${online_cnt} Online${NC} | ${YELLOW}${retry_cnt} Retry${NC}"
            ui_panel_kv "$CYAN" "Mode Probe" "${MAX_MISSES:-4}x gagal / ${PROBE_INTERVAL:-2}s" "${YELLOW}${MAX_MISSES:-4}x gagal${NC} / ${CYAN}${PROBE_INTERVAL:-2}s${NC}"
            ui_panel_kv "$CYAN" "Token" "${masked_tok}" "${RED}${masked_tok}${NC}"
            ui_panel_bot "$CYAN"

            printf "\n"
            ui_panel_top "$BRED" "$BGREEN" ". Menu Bot Notif ." "• Menu Bot Notif •"
            ui_panel_line "$BRED" \
                "  ID  Action                                        " \
                "  ${BMAGENTA}ID  Action${NC}                                        "
            ui_panel_line "$BRED" \
                "   1  Start / Restart Bot (resbotnotif)             " \
                "   ${BGREEN}1${NC}  ${WHITE}Start / Restart Bot${NC} ${CYAN}(resbotnotif)${NC}             "
            ui_panel_line "$BRED" \
                "   2  Cek Status & Perangkat (cekbot)               " \
                "   ${BGREEN}2${NC}  ${WHITE}Cek Status & Perangkat${NC} ${GREEN}(cekbot)${NC}               "
            ui_panel_line "$BRED" \
                "   3  Stop / Matikan Bot (stopbotnotif)             " \
                "   ${BGREEN}3${NC}  ${WHITE}Stop / Matikan Bot${NC} ${RED}(stopbotnotif)${NC}             "
            ui_panel_line "$BRED" \
                "   4  Tambah / Kelola User ID Bot                   " \
                "   ${BGREEN}4${NC}  ${WHITE}Tambah / Kelola${NC} ${BMAGENTA}User ID Bot${NC}                   "
            ui_panel_line "$BRED" \
                "   5  Install Ulang / Konfigurasi Ulang             " \
                "   ${BGREEN}5${NC}  ${WHITE}Install Ulang / Konfigurasi Ulang${NC}             "
            ui_panel_line "$BRED" \
                "   6  Hapus / Uninstall Bot Notif                   " \
                "   ${BGREEN}6${NC}  ${WHITE}Hapus / Uninstall Bot Notif${NC}                   "
            ui_panel_line "$BRED" \
                "  00  Kembali ke Menu Utama kiheo                   " \
                "  ${BGREEN}00${NC}  ${WHITE}Kembali ke Menu Utama kiheo${NC}                   "
            ui_panel_bot "$BRED"

            printf "\n${WHITE}Pilih menu: ${NC}"
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
                    printf "\n${BRED}Yakin hapus Bot Notifikasi? [y/N]: ${NC}"
                    read cf
                    case "$cf" in
                        y|Y)
                            bn_uninstall_only
                            printf "\n${GRAY}Tekan Enter untuk kembali...${NC}"
                            read _
                            ;;
                    esac
                    ;;
                0|00|q|Q) return ;;
                *) printf "\n${BRED}Pilihan tidak valid!${NC}\n"; sleep 1 ;;
            esac
        fi
    done
}
EOF_MOD_NOTIF
chmod +x /usr/lib/kiheo/modules/botnotif.sh

# ====================================================
# 4. LAUNCHER UTAMA (/usr/bin/kiheo)
# ====================================================
cat << 'EOF_KIHEO_MAIN' > /usr/bin/kiheo
#!/bin/sh

. /usr/lib/kiheo/ui.sh

PLUGIN_DIR="/etc/kiheo/plugins"
MODULE_DIR="/usr/lib/kiheo/modules"

mkdir -p "$PLUGIN_DIR" "$MODULE_DIR"
[ -f "$MODULE_DIR/botnotif.sh" ] && . "$MODULE_DIR/botnotif.sh"

if [ ! -f "$PLUGIN_DIR/contoh_bot.sh.example" ]; then
    cat << 'EOF_EXAMPLE' > "$PLUGIN_DIR/contoh_bot.sh.example"
#!/bin/sh
# MENU_NAME: Bot Proyek Baru (Contoh)
# Ubah ekstensi file ini dari .sh.example menjadi .sh agar otomatis muncul di menu 'kiheo'

. /usr/lib/kiheo/ui.sh
ui_panel_top "$CYAN" "$BGREEN" "[ Bot Proyek Baru ]" "[ Bot Proyek Baru ]"
ui_panel_line "$CYAN" "  Proyek bot baru berhasil dijalankan!              " "  ${WHITE}Proyek bot baru berhasil dijalankan!${NC}              "
ui_panel_bot "$CYAN"
EOF_EXAMPLE
fi

uninstall_kiheo_hub() {
    printf "\n${BRED}Hapus KIHEO-BOT Hub beserta seluruh modulnya? [y/N]: ${NC}"
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
            printf "${BGREEN}✔ KIHEO-BOT Hub berhasil dihapus total.${NC}\n"
            exit 0
            ;;
    esac
}

while true; do
    HOSTNAME_SYS="$(uci get system.@system[0].hostname 2>/dev/null || uname -n)"
    LAN_IP="$(uci get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1")"
    LOCAL_TIME_SYS="$(ui_get_localtime)"
    UPTIME_SYS="$(ui_get_uptime)"

    if [ -x /usr/bin/telenotif ] && [ -f /etc/telenotif.conf ]; then
        if pgrep -f "/usr/bin/telenotif" >/dev/null 2>&1; then
            NOTIF_ST_PLAIN="* AKTIF (Running)"
            NOTIF_ST_COLOR="${BGREEN}● AKTIF${NC} ${GRAY}(Running)${NC}"
            NOTIF_MENU_PLAIN="   1  Bot Notif Telegram [AKTIF]"
            NOTIF_MENU_COLOR="   ${BGREEN}1${NC}  ${WHITE}Bot Notif Telegram${NC} ${BGREEN}[AKTIF]${NC}"
        else
            NOTIF_ST_PLAIN="* TERPASANG (Stopped)"
            NOTIF_ST_COLOR="${YELLOW}● TERPASANG${NC} ${RED}(Stopped)${NC}"
            NOTIF_MENU_PLAIN="   1  Bot Notif Telegram [STOPPED]"
            NOTIF_MENU_COLOR="   ${BGREEN}1${NC}  ${WHITE}Bot Notif Telegram${NC} ${YELLOW}[STOPPED]${NC}"
        fi
    else
        NOTIF_ST_PLAIN="BELUM TERPASANG"
        NOTIF_ST_COLOR="${BRED}BELUM TERPASANG${NC}"
        NOTIF_MENU_PLAIN="   1  Bot Notif Telegram [Install]"
        NOTIF_MENU_COLOR="   ${BGREEN}1${NC}  ${WHITE}Bot Notif Telegram${NC} ${CYAN}[Install]${NC}"
    fi

    PLUGIN_COUNT=0
    for f in "$PLUGIN_DIR"/*.sh; do
        [ -f "$f" ] && PLUGIN_COUNT=$((PLUGIN_COUNT + 1))
    done

    clear
    ui_banner

    # Kotak 1: Informasi Sistem (Rounded Cyan Border, Green Title)
    ui_panel_top "$CYAN" "$BGREEN" "[ Informasi Sistem ]" "[ Informasi Sistem ]"
    ui_panel_kv "$CYAN" "Host" "${HOSTNAME_SYS} (${LAN_IP})" "${WHITE}${HOSTNAME_SYS}${NC} ${GRAY}(${LAN_IP})${NC}"
    ui_panel_kv "$CYAN" "Local Time" "${LOCAL_TIME_SYS}" "${WHITE}${LOCAL_TIME_SYS}${NC}"
    ui_panel_kv "$CYAN" "Uptime" "${UPTIME_SYS}" "${WHITE}${UPTIME_SYS}${NC}"
    ui_panel_kv "$CYAN" "Bot Notif" "${NOTIF_ST_PLAIN}" "${NOTIF_ST_COLOR}"
    ui_panel_kv "$CYAN" "Plugins" "${PLUGIN_COUNT} Proyek Bot Tambahan" "${BMAGENTA}${PLUGIN_COUNT} Proyek Bot Tambahan${NC}"
    ui_panel_kv "$CYAN" "Folder" "/etc/kiheo/plugins/" "${YELLOW}/etc/kiheo/plugins/${NC}"
    ui_panel_bot "$CYAN"

    printf "\n"

    # Kotak 2: Menu Utama (Rounded Bold Red Border, Green Title)
    ui_panel_top "$BRED" "$BGREEN" ". Menu Utama ." "• Menu Utama •"
    ui_panel_line "$BRED" \
        "  ID  Action                                        " \
        "  ${BMAGENTA}ID  Action${NC}                                        "
    ui_panel_line "$BRED" "$NOTIF_MENU_PLAIN" "$NOTIF_MENU_COLOR"

    IDX=1
    PLUGIN_MAP=""
    for pfile in "$PLUGIN_DIR"/*.sh; do
        [ -f "$pfile" ] || continue
        IDX=$((IDX + 1))
        PNAME="$(grep -m1 '^# MENU_NAME:' "$pfile" | sed 's/^# MENU_NAME:[[:space:]]*//')"
        [ -z "$PNAME" ] && PNAME="$(basename "$pfile" .sh)"
        PNAME_TRIM="$(printf '%s' "$PNAME" | cut -c1-44)"
        ID_STR="$(printf '%2d' "$IDX")"
        ui_panel_line "$BRED" "  ${ID_STR}  ${PNAME_TRIM}" "  ${BGREEN}${ID_STR}${NC}  ${WHITE}${PNAME_TRIM}${NC}"
        PLUGIN_MAP="${PLUGIN_MAP}${IDX}:${pfile}|"
    done

    ui_panel_line "$BRED" \
        "   I  Quick Install Bot Notif                       " \
        "   ${BGREEN}I${NC}  ${CYAN}Quick Install Bot Notif${NC}                       "
    ui_panel_line "$BRED" \
        "   U  Uninstall KIHEO-BOT Hub                       " \
        "   ${BGREEN}U${NC}  ${YELLOW}Uninstall KIHEO-BOT Hub${NC}                       "
    ui_panel_line "$BRED" \
        "  00  Keluar                                        " \
        "  ${BGREEN}00${NC}  ${WHITE}Keluar${NC}                                        "
    ui_panel_bot "$BRED"

    printf "\n${WHITE}Pilih menu: ${NC}"
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
        0|00|99|q|Q|exit)
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
                printf "\n${BRED}Pilihan tidak valid!${NC}\n"
                sleep 1
            fi
            ;;
    esac
done
EOF_KIHEO_MAIN
chmod +x /usr/bin/kiheo

# Restart bot notif otomatis jika sebelumnya sudah terpasang
if [ -x /usr/bin/telenotif ] && [ -f /etc/telenotif.conf ]; then
    /usr/bin/resbotnotif >/dev/null 2>&1
fi

clear
. /usr/lib/kiheo/ui.sh
ui_banner
ui_panel_top "$CYAN" "$BGREEN" "[ Pemasangan Selesai ]" "[ Pemasangan Selesai ]"
ui_panel_kv "$CYAN" "Menu Utama" "Ketik 'kiheo'" "${BCYAN}Ketik 'kiheo'${NC}"
ui_panel_kv "$CYAN" "Cek Status" "Ketik 'cekbot'" "${BGREEN}Ketik 'cekbot'${NC}"
ui_panel_kv "$CYAN" "Restart Bot" "Ketik 'resbotnotif'" "${YELLOW}Ketik 'resbotnotif'${NC}"
ui_panel_kv "$CYAN" "Stop Bot" "Ketik 'stopbotnotif'" "${RED}Ketik 'stopbotnotif'${NC}"
ui_panel_kv "$CYAN" "Folder Bot" "/etc/kiheo/plugins/" "${BMAGENTA}/etc/kiheo/plugins/${NC}"
ui_panel_bot "$CYAN"
