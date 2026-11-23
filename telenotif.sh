#!/bin/sh

# ====================================================
#   KIHEO-BOT HUB INSTALLER (UNIFIED CYBER PANEL UI)
#   Command Utama: kiheo | cekbot | hostbot | blockbot
#   Repo: https://github.com/kiel-p/bot
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

ui_max_inner() {
    local cols=""
    if command -v stty >/dev/null 2>&1; then
        cols="$(stty size 2>/dev/null | awk '{print $2}')"
    fi
    [ -z "$cols" ] || [ "$cols" -eq 0 ] 2>/dev/null && cols="${COLUMNS:-54}"
    case "$cols" in ''|*[!0-9]*) cols=54 ;; esac
    [ "$cols" -lt 54 ] && cols=54
    [ "$cols" -gt 70 ] && cols=70
    echo $(( cols - 2 ))
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

# Header kotak rounded (default inner = 52)
ui_panel_top() {
    local bcolor="$1"
    local tcolor="$2"
    local title_ascii="$3"
    local title_disp="$4"
    local inner="${5:-52}"
    local tlen=$(( ${#title_ascii} + 2 ))
    local left=$(( (inner - tlen) / 2 ))
    [ $left -lt 1 ] && left=1
    local right=$(( inner - tlen - left ))
    [ $right -lt 1 ] && right=1
    printf "${bcolor}╭%s ${tcolor}%s${bcolor} %s╮${NC}\n" \
        "$(ui_repeat "─" "$left")" "$title_disp" "$(ui_repeat "─" "$right")"
}

# Baris kotak rounded ($2 WAJIB ASCII murni 1-byte)
ui_panel_line() {
    local bcolor="$1"
    local plain="$2"
    local colored="$3"
    local inner="${4:-52}"
    local len=${#plain}
    local pad=$((inner - len))
    [ $pad -lt 0 ] && pad=0
    printf "${bcolor}│${NC}%b%s${bcolor}│${NC}\n" "$colored" "$(ui_repeat " " "$pad")"
}

# Baris Key-Value rata kanan pada titik dua (kolom ke-14) + auto-wrap jika panjang
ui_panel_kv() {
    local bcolor="$1"
    local key="$2"
    local val_plain="$3"
    local val_colored="$4"
    local inner="${5:-52}"
    local key_pad=$((13 - ${#key}))
    [ $key_pad -lt 1 ] && key_pad=1
    local prefix_plain="$(ui_repeat " " "$key_pad")${key} : "
    local prefix_color="$(ui_repeat " " "$key_pad")${CYAN}${key}${NC} : "
    local max_val=$(( inner - 16 ))

    if [ ${#val_plain} -le $max_val ]; then
        ui_panel_line "$bcolor" "${prefix_plain}${val_plain}" "${prefix_color}${val_colored}" "$inner"
    else
        local first_chunk="$(printf '%s' "$val_plain" | cut -c1-"$max_val")"
        ui_panel_line "$bcolor" "${prefix_plain}${first_chunk}" "${prefix_color}${BMAGENTA}${first_chunk}${NC}" "$inner"
        local rest="$(printf '%s' "$val_plain" | cut -c$((max_val + 1))-)"
        while [ -n "$rest" ]; do
            local chunk="$(printf '%s' "$rest" | cut -c1-"$max_val")"
            ui_panel_line "$bcolor" "                ${chunk}" "                ${BMAGENTA}${chunk}${NC}" "$inner"
            rest="$(printf '%s' "$rest" | cut -c$((max_val + 1))-)"
        done
    fi
}

ui_panel_bot() {
    local bcolor="$1"
    local inner="${2:-52}"
    printf "${bcolor}╰%s╯${NC}\n" "$(ui_repeat "─" "$inner")"
}

# Parser multi-nomor (mendukung format: 1 | 1,2,3 | 1 2 3 | 1-3)
ui_parse_numbers() {
    local raw="$1"
    local max_n="$2"
    local cleaned="$(printf '%s' "$raw" | tr ',;' '  ')"
    local out=""
    for tok in $cleaned; do
        case "$tok" in
            *-*)
                local start="${tok%-*}"
                local end="${tok#*-}"
                case "$start" in ''|*[!0-9]*) return 1 ;; esac
                case "$end" in ''|*[!0-9]*) return 1 ;; esac
                [ "$start" -lt 1 ] || [ "$end" -gt "$max_n" ] || [ "$start" -gt "$end" ] && return 1
                local i="$start"
                while [ "$i" -le "$end" ]; do
                    case " $out " in *" $i "*) ;; *) out="$out $i" ;; esac
                    i=$((i + 1))
                done
                ;;
            *)
                case "$tok" in ''|*[!0-9]*) return 1 ;; esac
                [ "$tok" -lt 1 ] || [ "$tok" -gt "$max_n" ] && return 1
                case " $out " in *" $tok "*) ;; *) out="$out $tok" ;; esac
                ;;
        esac
    done
    [ -z "$out" ] && return 1
    printf '%s' "${out# }"
    return 0
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

ui_get_bot_pid() {
    if [ -f /var/run/telenotif.pid ]; then
        local p
        p="$(cat /var/run/telenotif.pid 2>/dev/null)"
        if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then
            printf '%s' "$p"
            return 0
        fi
    fi
    pgrep -f "/usr/bin/telenotif" 2>/dev/null | head -n1
}
EOF_UI
chmod +x /usr/lib/kiheo/ui.sh

# ====================================================
# 2. ENGINE BLOKIR KERNEL (/etc/kiheo/apply_block.sh)
# ====================================================
cat << 'EOF_APPLY_BLOCK' > /etc/kiheo/apply_block.sh
#!/bin/sh

BLOCK_FILE="/etc/telenotif_blocked.conf"

[ -f "$BLOCK_FILE" ] || exit 0

if command -v uci >/dev/null 2>&1; then
    if [ "$(uci -q get firewall.kiheo_blk_inc)" != "include" ]; then
        uci set firewall.kiheo_blk_inc='include'
        uci set firewall.kiheo_blk_inc.type='script'
        uci set firewall.kiheo_blk_inc.path='/etc/kiheo/apply_block.sh'
        uci set firewall.kiheo_blk_inc.fw4_compatible='1'
        uci commit firewall >/dev/null 2>&1
    fi
fi

# 1. Firewall4 / nftables (Prioritas -300: blokir sebelum conntrack, offload & proxy)
if command -v nft >/dev/null 2>&1; then
    nft delete table inet kiheo_block >/dev/null 2>&1
    if [ -s "$BLOCK_FILE" ]; then
        nft add table inet kiheo_block >/dev/null 2>&1
        nft 'add chain inet kiheo_block prerouting { type filter hook prerouting priority -300; policy accept; }' >/dev/null 2>&1
        nft 'add chain inet kiheo_block forward { type filter hook forward priority -300; policy accept; }' >/dev/null 2>&1
        nft 'add chain inet kiheo_block input { type filter hook input priority -300; policy accept; }' >/dev/null 2>&1

        while IFS='|' read -r raw_mac _ saved_ip; do
            mac="$(printf '%s' "$raw_mac" | tr '-' ':' | tr '[:upper:]' '[:lower:]' | tr -d ' \r\n')"
            [ -z "$mac" ] && continue

            nft add rule inet kiheo_block prerouting ether saddr "$mac" drop >/dev/null 2>&1
            nft add rule inet kiheo_block forward ether saddr "$mac" drop >/dev/null 2>&1
            nft add rule inet kiheo_block input ether saddr "$mac" drop >/dev/null 2>&1

            cur_ip="$saved_ip"
            [ -z "$cur_ip" ] && [ -f /tmp/dhcp.leases ] && cur_ip="$(awk -v m="$mac" 'tolower($2)==m {print $3; exit}' /tmp/dhcp.leases 2>/dev/null)"
            [ -z "$cur_ip" ] && cur_ip="$(ip -4 neigh show 2>/dev/null | awk -v m="$mac" 'tolower($0) ~ m {print $1; exit}')"

            if [ -n "$cur_ip" ]; then
                command -v conntrack >/dev/null 2>&1 && {
                    conntrack -D -s "$cur_ip" >/dev/null 2>&1
                    conntrack -D -d "$cur_ip" >/dev/null 2>&1
                }
                ip neigh del "$cur_ip" dev br-lan >/dev/null 2>&1
            fi

            if command -v ubus >/dev/null 2>&1; then
                for hapd in $(ubus list 'hostapd.*' 2>/dev/null); do
                    ubus call "$hapd" del_client "{\"addr\":\"${mac}\",\"reason\":5,\"deauth\":true,\"ban_time\":86400000}" >/dev/null 2>&1
                done
            fi
        done < "$BLOCK_FILE"
    fi
elif command -v iptables >/dev/null 2>&1; then
    iptables -D FORWARD -j KIHEO_BLOCK >/dev/null 2>&1
    iptables -D INPUT -j KIHEO_BLOCK >/dev/null 2>&1
    iptables -F KIHEO_BLOCK >/dev/null 2>&1
    iptables -X KIHEO_BLOCK >/dev/null 2>&1

    if [ -s "$BLOCK_FILE" ]; then
        iptables -N KIHEO_BLOCK >/dev/null 2>&1
        iptables -I FORWARD 1 -j KIHEO_BLOCK >/dev/null 2>&1
        iptables -I INPUT 1 -j KIHEO_BLOCK >/dev/null 2>&1
        while IFS='|' read -r raw_mac _ _; do
            mac="$(printf '%s' "$raw_mac" | tr '-' ':' | tr '[:upper:]' '[:lower:]' | tr -d ' \r\n')"
            [ -z "$mac" ] && continue
            iptables -A KIHEO_BLOCK -m mac --mac-source "$mac" -j DROP >/dev/null 2>&1
        done < "$BLOCK_FILE"
    fi
fi
EOF_APPLY_BLOCK
chmod +x /etc/kiheo/apply_block.sh

# ====================================================
# 3. MODUL BOT NOTIFIKASI (/usr/lib/kiheo/modules/botnotif.sh)
# ====================================================
cat << 'EOF_MOD_NOTIF' > /usr/lib/kiheo/modules/botnotif.sh
#!/bin/sh

. /usr/lib/kiheo/ui.sh

CONF_FILE="/etc/telenotif.conf"
USERS_FILE="/etc/telenotif_users.conf"
STATE_FILE="/tmp/telenotif_state.txt"
ALIAS_FILE="/etc/config/host_alias.conf"
BLOCK_FILE="/etc/telenotif_blocked.conf"
IGNORE_FILE="/etc/telenotif.ignore"

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

bn_get_user_name() {
    local uid="$1"
    local uname=""
    if [ -f "$USERS_FILE" ]; then
        uname="$(awk -F'|' -v id="$uid" '$1==id {print $2; exit}' "$USERS_FILE" 2>/dev/null)"
    fi
    [ -z "$uname" ] && uname="-"
    printf '%s' "$uname"
}

bn_set_user_name() {
    local uid="$1"
    local uname="$2"
    touch "$USERS_FILE"
    local tmp_u="/tmp/telenotif_users.tmp"
    awk -F'|' -v id="$uid" '$1 != id' "$USERS_FILE" > "$tmp_u" 2>/dev/null
    printf '%s|%s\n' "$uid" "$uname" >> "$tmp_u"
    mv "$tmp_u" "$USERS_FILE"
}

bn_del_user_name() {
    local uid="$1"
    [ -f "$USERS_FILE" ] || return 0
    local tmp_u="/tmp/telenotif_users.tmp"
    awk -F'|' -v id="$uid" '$1 != id' "$USERS_FILE" > "$tmp_u" 2>/dev/null
    mv "$tmp_u" "$USERS_FILE"
}

# Kotak Perangkat Terdeteksi: 1 baris per perangkat, otomatis menyesuaikan lebar layar & '...' jika berlebih
bn_render_devices_box() {
    local max_in="$(ui_max_inner)"
    local w_ip=13
    local longest_host=9

    if [ -s "$STATE_FILE" ]; then
        while IFS='|' read -r _ s_ip _ s_host _; do
            [ ${#s_ip} -gt $w_ip ] && w_ip=${#s_ip}
            [ ${#s_host} -gt $longest_host ] && longest_host=${#s_host}
        done < "$STATE_FILE"
    fi
    [ $w_ip -gt 15 ] && w_ip=15

    # Total inner = 1 + 2(No) + 1 + 17(MAC) + 1 + w_ip + 1 + w_host + 1 + 6(Status) = 30 + w_ip + w_host
    local fixed_cols=$(( 30 + w_ip ))
    local dev_inner=$(( fixed_cols + longest_host ))
    [ $dev_inner -lt 52 ] && dev_inner=52
    [ $dev_inner -gt $max_in ] && dev_inner=$max_in

    local w_host=$(( dev_inner - fixed_cols ))
    [ $w_host -lt 7 ] && w_host=7

    local hdr_ip="$(printf "%-${w_ip}s" "IP Address")"
    local hdr_host="$(printf "%-${w_host}s" "Host")"

    ui_panel_top "$BRED" "$BGREEN" ". Perangkat Terdeteksi ." "• Perangkat Terdeteksi •" "$dev_inner"
    ui_panel_line "$BRED" \
        " No MAC Address       ${hdr_ip} ${hdr_host} Status" \
        " ${BMAGENTA}No MAC Address       ${hdr_ip} ${hdr_host} Status${NC}" "$dev_inner"

    if [ -s "$STATE_FILE" ]; then
        local dev_idx=0
        while IFS='|' read -r mac ip iface host miss; do
            [ -z "$mac" ] && continue
            [ -z "$miss" ] && miss=0
            dev_idx=$((dev_idx + 1))
            local no_f="$(printf '%2d' "$dev_idx")"
            local mac_f="$(printf '%-17s' "$mac")"
            local ip_f="$(printf "%-${w_ip}s" "$ip")"

            local host_disp="$host"
            if [ ${#host} -gt $w_host ]; then
                local cut_len=$(( w_host - 3 ))
                [ $cut_len -lt 4 ] && cut_len=4
                host_disp="$(printf '%s' "$host" | cut -c1-"$cut_len")..."
            fi
            local host_f="$(printf "%-${w_host}s" "$host_disp")"

            local st_plain st_color
            if [ "$miss" -eq 0 ]; then
                st_plain="ONLINE"
                st_color="${BGREEN}ONLINE${NC}"
            else
                st_plain="$(printf 'RTRY %s' "$miss" | cut -c1-6)"
                st_plain="$(printf '%-6s' "$st_plain")"
                st_color="${YELLOW}${st_plain}${NC}"
            fi

            local row_plain=" ${no_f} ${mac_f} ${ip_f} ${host_f} ${st_plain}"
            local row_color=" ${BGREEN}${no_f}${NC} ${WHITE}${mac_f}${NC} ${CYAN}${ip_f}${NC} ${WHITE}${host_f}${NC} ${st_color}"
            ui_panel_line "$BRED" "$row_plain" "$row_color" "$dev_inner"
        done < "$STATE_FILE"
    else
        ui_panel_line "$BRED" \
            "   (Belum ada perangkat aktif yang terdeteksi)" \
            "   ${GRAY}(Belum ada perangkat aktif yang terdeteksi)${NC}" "$dev_inner"
    fi
    ui_panel_bot "$BRED" "$dev_inner"
}

bn_add_block_entry() {
    local mac="$(printf '%s' "$1" | tr '-' ':' | tr '[:upper:]' '[:lower:]' | tr -d ' \r\n')"
    local host="${2:-Perangkat Diblokir}"
    local ip="$(printf '%s' "$3" | tr -d ' \r\n')"
    local hex="$(printf '%s' "$mac" | tr -d ':')"

    touch "$BLOCK_FILE" "$IGNORE_FILE"
    awk -F'|' -v m="$mac" 'tolower($1) != m' "$BLOCK_FILE" > /tmp/telenotif_blk.tmp 2>/dev/null
    printf '%s|%s|%s\n' "$mac" "$host" "$ip" >> /tmp/telenotif_blk.tmp
    mv /tmp/telenotif_blk.tmp "$BLOCK_FILE"

    grep -qi "^${mac}$" "$IGNORE_FILE" || printf '%s\n' "$mac" >> "$IGNORE_FILE"

    if command -v uci >/dev/null 2>&1; then
        uci -q delete "firewall.kiheo_blk_${hex}" >/dev/null 2>&1
        uci set "firewall.kiheo_blk_${hex}=rule"
        uci set "firewall.kiheo_blk_${hex}.name=KIHEO_BLOCK_${hex}"
        uci set "firewall.kiheo_blk_${hex}.src=lan"
        uci set "firewall.kiheo_blk_${hex}.src_mac=${mac}"
        uci set "firewall.kiheo_blk_${hex}.target=DROP"
    fi

    if [ -f "$STATE_FILE" ]; then
        awk -F'|' -v m="$mac" 'tolower($1) != m' "$STATE_FILE" > /tmp/telenotif_st_blk.tmp 2>/dev/null
        mv /tmp/telenotif_st_blk.tmp "$STATE_FILE"
    fi
}

bn_del_block_entry() {
    local mac="$(printf '%s' "$1" | tr '-' ':' | tr '[:upper:]' '[:lower:]' | tr -d ' \r\n')"
    local hex="$(printf '%s' "$mac" | tr -d ':')"

    touch "$BLOCK_FILE" "$IGNORE_FILE"
    awk -F'|' -v m="$mac" 'tolower($1) != m' "$BLOCK_FILE" > /tmp/telenotif_blk.tmp 2>/dev/null
    mv /tmp/telenotif_blk.tmp "$BLOCK_FILE"

    grep -vi "^${mac}$" "$IGNORE_FILE" > /tmp/telenotif_ign.tmp 2>/dev/null
    mv /tmp/telenotif_ign.tmp "$IGNORE_FILE"

    if command -v uci >/dev/null 2>&1; then
        uci -q delete "firewall.kiheo_blk_${hex}" >/dev/null 2>&1
    fi
}

bn_sync_firewall() {
    command -v uci >/dev/null 2>&1 && uci commit firewall >/dev/null 2>&1
    [ -x /etc/kiheo/apply_block.sh ] && /etc/kiheo/apply_block.sh >/dev/null 2>&1
}

# Fitur Langsung 1: Ganti Nama Host (command: hostbot)
bn_rename_host_screen() {
    touch "$ALIAS_FILE"
    clear
    ui_banner
    bn_render_devices_box

    if [ ! -s "$STATE_FILE" ]; then
        printf "\n${YELLOW}! Belum ada perangkat terdeteksi untuk diganti namanya.${NC}\n"
        sleep 1
        return
    fi

    local total_dev=$(wc -l < "$STATE_FILE" | tr -d ' ')
    printf "\n${WHITE}Pilih Nomor perangkat yang diganti namanya (0 batal): ${NC}"
    read dev_no

    case "$dev_no" in
        0|00|'') return ;;
        *[!0-9]*)
            printf "${BRED}✖ Masukkan angka nomor yang valid!${NC}\n"
            sleep 1
            return
            ;;
    esac

    if [ "$dev_no" -lt 1 ] || [ "$dev_no" -gt "$total_dev" ]; then
        printf "${BRED}✖ Nomor perangkat tidak ditemukan!${NC}\n"
        sleep 1
        return
    fi

    local line="$(sed -n "${dev_no}p" "$STATE_FILE")"
    local t_mac="$(printf '%s' "$line" | awk -F'|' '{print $1}')"
    local t_ip="$(printf '%s' "$line" | awk -F'|' '{print $2}')"
    local t_old="$(printf '%s' "$line" | awk -F'|' '{print $4}')"

    printf "${CYAN}MAC Address${NC} : ${WHITE}%s${NC} (${CYAN}%s${NC})\n" "$t_mac" "$t_ip"
    printf "${CYAN}Nama Lama${NC}   : ${YELLOW}%s${NC}\n" "$t_old"
    printf "${WHITE}Masukkan Nama Host Baru (0 batal): ${NC}"
    read new_host

    new_host="$(printf '%s' "$new_host" | tr -d '|/\r\n')"
    [ -z "$new_host" ] || [ "$new_host" = "0" ] && return

    grep -vi "^${t_mac}[[:space:]]" "$ALIAS_FILE" > /tmp/host_alias.tmp 2>/dev/null
    printf '%s %s\n' "$t_mac" "$new_host" >> /tmp/host_alias.tmp
    mv /tmp/host_alias.tmp "$ALIAS_FILE"

    awk -F'|' -v m="$t_mac" -v nh="$new_host" 'BEGIN{OFS="|"} {if (tolower($1)==tolower(m)) $4=nh; print}' "$STATE_FILE" > /tmp/telenotif_ren.tmp 2>/dev/null
    mv /tmp/telenotif_ren.tmp "$STATE_FILE"

    printf "${BGREEN}✔ Nama host %s berhasil diubah menjadi '%s'!${NC}\n" "$t_mac" "$new_host"
    sleep 1
}

# Fitur Langsung 2: Block / Unblock Perangkat (command: blockbot)
bn_block_menu_screen() {
    touch "$BLOCK_FILE" "$IGNORE_FILE"
    while true; do
        clear
        ui_banner

        local max_in="$(ui_max_inner)"
        local longest_bhost=25
        local b_idx=0
        if [ -s "$BLOCK_FILE" ]; then
            while IFS='|' read -r b_mac b_host _; do
                [ -z "$b_mac" ] && continue
                b_idx=$((b_idx + 1))
                local bh="${b_host:-Perangkat Diblokir}"
                [ ${#bh} -gt $longest_bhost ] && longest_bhost=${#bh}
            done < "$BLOCK_FILE"
        fi

        local blk_inner=$(( 27 + longest_bhost ))
        [ $blk_inner -lt 52 ] && blk_inner=52
        [ $blk_inner -gt $max_in ] && blk_inner=$max_in
        local w_bhost=$(( blk_inner - 27 ))

        local hdr_bhost="$(printf "%-${w_bhost}s" "Nama / Host")"

        ui_panel_top "$BRED" "$BGREEN" "[ Daftar Perangkat Diblokir ]" "[ Daftar Perangkat Diblokir ]" "$blk_inner"
        ui_panel_line "$BRED" \
            "  No  MAC Address        ${hdr_bhost}  " \
            "  ${BMAGENTA}No  MAC Address        ${hdr_bhost}${NC}  " "$blk_inner"

        if [ "$b_idx" -gt 0 ]; then
            local cur_b=0
            while IFS='|' read -r b_mac b_host _; do
                [ -z "$b_mac" ] && continue
                cur_b=$((cur_b + 1))
                local no_f="$(printf '%2d' "$cur_b")"
                local mac_f="$(printf '%-17s' "$b_mac")"
                local bh_full="${b_host:-Perangkat Diblokir}"
                local bh_disp="$bh_full"
                if [ ${#bh_full} -gt $w_bhost ]; then
                    bh_disp="$(printf '%s' "$bh_full" | cut -c1-$((w_bhost - 3)))..."
                fi
                local host_f="$(printf "%-${w_bhost}s" "$bh_disp")"
                ui_panel_line "$BRED" \
                    "  ${no_f}  ${mac_f}  ${host_f}  " \
                    "  ${BGREEN}${no_f}${NC}  ${BRED}${mac_f}${NC}  ${WHITE}${host_f}${NC}  " "$blk_inner"
            done < "$BLOCK_FILE"
        else
            ui_panel_line "$BRED" \
                "  (Belum ada perangkat yang diblokir)" \
                "  ${GRAY}(Belum ada perangkat yang diblokir)${NC}" "$blk_inner"
        fi
        ui_panel_bot "$BRED" "$blk_inner"

        printf "\n"
        ui_panel_top "$CYAN" "$BGREEN" ". Menu Block Perangkat ." "• Menu Block Perangkat •"
        ui_panel_line "$CYAN" \
            "  ID  Action                                        " \
            "  ${BMAGENTA}ID  Action${NC}                                        "
        ui_panel_line "$CYAN" \
            "   1  Block Perangkat (Pilih Nomor: 1 / 1,2,3)      " \
            "   ${BGREEN}1${NC}  ${WHITE}Block Perangkat${NC} ${YELLOW}(Pilih Nomor: 1 / 1,2,3)${NC}      "
        ui_panel_line "$CYAN" \
            "   2  Block Perangkat (Input MAC Manual)            " \
            "   ${BGREEN}2${NC}  ${WHITE}Block Perangkat${NC} ${CYAN}(Input MAC Manual)${NC}            "
        ui_panel_line "$CYAN" \
            "   3  Unblock / Buka Blokir (Nomor: 1 / 1,2,3)      " \
            "   ${BGREEN}3${NC}  ${WHITE}Unblock / Buka Blokir${NC} ${GREEN}(Nomor: 1 / 1,2,3)${NC}      "
        ui_panel_line "$CYAN" \
            "   0  Kembali                                       " \
            "   ${BGREEN}0${NC}  ${WHITE}Kembali${NC}                                       "
        ui_panel_bot "$CYAN"

        printf "\n${WHITE}Pilih menu: ${NC}"
        read b_opt

        case "$b_opt" in
            1)
                if [ ! -s "$STATE_FILE" ]; then
                    printf "\n${YELLOW}! Belum ada perangkat terdeteksi.${NC}\n"
                    sleep 1
                    continue
                fi
                printf "\n${CYAN}Daftar Perangkat Terdeteksi:${NC}\n"
                local n=0
                while IFS='|' read -r s_mac s_ip _ s_host _; do
                    [ -z "$s_mac" ] && continue
                    n=$((n + 1))
                    printf "  ${BGREEN}%2d.${NC} ${WHITE}%s${NC} (${CYAN}%s${NC}) - ${YELLOW}%s${NC}\n" "$n" "$s_mac" "$s_ip" "$s_host"
                done < "$STATE_FILE"

                printf "\n${WHITE}Masukkan Nomor (contoh: 1 atau 1,2,3 / 0 batal): ${NC}"
                read pick_raw
                pick_raw="$(printf '%s' "$pick_raw" | tr -d ' \r\n')"
                [ -z "$pick_raw" ] || [ "$pick_raw" = "0" ] && continue

                local parsed_nums
                parsed_nums="$(ui_parse_numbers "$pick_raw" "$n")"
                if [ $? -ne 0 ] || [ -z "$parsed_nums" ]; then
                    printf "${BRED}✖ Format nomor tidak valid atau di luar daftar (1-%d)!${NC}\n" "$n"
                    sleep 1
                    continue
                fi

                local targets=""
                for pno in $parsed_nums; do
                    local sel_line="$(sed -n "${pno}p" "$STATE_FILE")"
                    [ -n "$sel_line" ] && targets="${targets}${sel_line}
"
                done

                printf '%s' "$targets" | while IFS='|' read -r sel_mac sel_ip _ sel_host _; do
                    [ -z "$sel_mac" ] && continue
                    bn_add_block_entry "$sel_mac" "$sel_host" "$sel_ip"
                    printf "${BGREEN}✔ Diblokir:${NC} ${WHITE}%s${NC} (${YELLOW}%s${NC})\n" "$sel_mac" "$sel_host"
                done
                bn_sync_firewall
                sleep 1
                ;;
            2)
                printf "\n${WHITE}Masukkan MAC Address (contoh 46:6e:76:d6:1b:61 / 0 batal): ${NC}"
                read man_mac
                man_mac="$(printf '%s' "$man_mac" | tr '-' ':' | tr '[:upper:]' '[:lower:]' | tr -d ' \r\n')"
                [ -z "$man_mac" ] || [ "$man_mac" = "0" ] && continue
                case "$man_mac" in
                    ??:??:??:??:??:??)
                        printf "${WHITE}Nama / Keterangan perangkat [Opsional]: ${NC}"
                        read man_host
                        [ -z "$man_host" ] && man_host="Blokir Manual"
                        bn_add_block_entry "$man_mac" "$man_host" ""
                        bn_sync_firewall
                        printf "${BGREEN}✔ MAC %s (%s) berhasil diblokir!${NC}\n" "$man_mac" "$man_host"
                        sleep 1
                        ;;
                    *)
                        printf "${BRED}✖ Format MAC Address tidak valid!${NC}\n"
                        sleep 1
                        ;;
                esac
                ;;
            3)
                if [ "$b_idx" -eq 0 ]; then
                    printf "\n${YELLOW}! Tidak ada perangkat di daftar blokir.${NC}\n"
                    sleep 1
                    continue
                fi
                printf "\n${WHITE}Masukkan Nomor blokir yang dibuka (contoh: 1 atau 1,2,3 / 0 batal): ${NC}"
                read unb_raw
                unb_raw="$(printf '%s' "$unb_raw" | tr -d ' \r\n')"
                [ -z "$unb_raw" ] || [ "$unb_raw" = "0" ] && continue

                local parsed_unb
                parsed_unb="$(ui_parse_numbers "$unb_raw" "$b_idx")"
                if [ $? -ne 0 ] || [ -z "$parsed_unb" ]; then
                    printf "${BRED}✖ Format nomor tidak valid atau di luar daftar (1-%d)!${NC}\n" "$b_idx"
                    sleep 1
                    continue
                fi

                local unb_macs=""
                for uno in $parsed_unb; do
                    local u_line="$(sed -n "${uno}p" "$BLOCK_FILE")"
                    local u_mac="$(printf '%s' "$u_line" | awk -F'|' '{print $1}')"
                    [ -n "$u_mac" ] && unb_macs="${unb_macs} ${u_mac}"
                done

                for umac in $unb_macs; do
                    bn_del_block_entry "$umac"
                    printf "${BGREEN}✔ Dibuka blokir:${NC} ${WHITE}%s${NC}\n" "$umac"
                done
                bn_sync_firewall
                sleep 1
                ;;
            0|00|q|Q)
                return
                ;;
            *)
                printf "\n${BRED}Pilihan tidak valid!${NC}\n"
                sleep 1
                ;;
        esac
    done
}

bn_create_binaries() {
    # Daemon utama /usr/bin/telenotif
    cat << 'EOF_DAEMON' > /usr/bin/telenotif
#!/bin/sh

PID_FILE="/var/run/telenotif.pid"
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && [ "$OLD_PID" != "$$" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        exit 0
    fi
fi
echo "$$" > "$PID_FILE"
trap 'rm -f "$PID_FILE"; exit 0' INT TERM EXIT

[ -f /etc/telenotif.conf ] && . /etc/telenotif.conf

: "${MAX_MISSES:=15}"
: "${PROBE_INTERVAL:=2}"
: "${WIFI_INACTIVE_MAX:=300000}"
: "${FALLBACK_IFACE:=br-lan}"

STATE_FILE="/tmp/telenotif_state.txt"
CURRENT_FILE="/tmp/telenotif_current.txt"
CANDIDATE_FILE="/tmp/telenotif_candidates.txt"
WIFI_ASSOC_FILE="/tmp/telenotif_wifi_assoc.txt"
CHILLI_TEMP="/tmp/chilli_raw.txt"
ALIAS_FILE="/etc/config/host_alias.conf"
IGNORE_FILE="/etc/telenotif.ignore"
BLOCK_FILE="/etc/telenotif_blocked.conf"

touch "$STATE_FILE" "$IGNORE_FILE" "$BLOCK_FILE"
[ -x /etc/kiheo/apply_block.sh ] && /etc/kiheo/apply_block.sh >/dev/null 2>&1

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

is_ignored_or_blocked() {
    local mac="$1"
    [ -s "$IGNORE_FILE" ] && grep -qi "^${mac}$" "$IGNORE_FILE" && return 0
    [ -s "$BLOCK_FILE" ] && grep -qi "^${mac}|" "$BLOCK_FILE" && return 0
    return 1
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
    if [ -f "$ALIAS_FILE" ]; then
        alias_name=$(grep -i "^${mac}[[:space:]]" "$ALIAS_FILE" | head -n1 | sed 's/^[^[:space:]]*[[:space:]]*//')
    fi
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
                function flush() {
                    if (mac != "" && auth == "yes" && inact <= max_ms) print mac
                }
                /^Station / {
                    flush()
                    mac = tolower($2)
                    inact = 0
                    auth = "yes"
                }
                /inactive time:/ { inact = $3 + 0 }
                /authorized:/ { auth = $2 }
                END { flush() }
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
Mode: Wi-Fi Assoc + Multi-Probe (${MAX_MISSES}x / ${PROBE_INTERVAL}s)
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
        is_ignored_or_blocked "$mac" && continue

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
            is_ignored_or_blocked "$mac" && continue
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

    # Perintah langsung: resbotnotif
    cat << 'EOF_RES' > /usr/bin/resbotnotif
#!/bin/sh
. /usr/lib/kiheo/ui.sh

[ -f /etc/init.d/telenotif ] && /etc/init.d/telenotif stop >/dev/null 2>&1
for pid in $(pgrep -f "/usr/bin/telenotif"); do
    kill -9 "$pid" 2>/dev/null
done
rm -f /var/run/telenotif.pid /tmp/telenotif_current.txt /tmp/telenotif_candidates.txt /tmp/telenotif_wifi_assoc.txt /tmp/chilli_raw.txt

if [ -f /etc/init.d/telenotif ]; then
    /etc/init.d/telenotif enable >/dev/null 2>&1
    /etc/init.d/telenotif start >/dev/null 2>&1
else
    /bin/sh /usr/bin/telenotif >/dev/null 2>&1 &
fi

sleep 1
PIDS="$(ui_get_bot_pid)"

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

    # Perintah langsung: stopbotnotif
    cat << 'EOF_STOP' > /usr/bin/stopbotnotif
#!/bin/sh
. /usr/lib/kiheo/ui.sh

[ -f /etc/init.d/telenotif ] && /etc/init.d/telenotif stop >/dev/null 2>&1
for pid in $(pgrep -f "/usr/bin/telenotif"); do
    kill -9 "$pid" 2>/dev/null
done
rm -f /var/run/telenotif.pid /tmp/telenotif_current.txt /tmp/telenotif_candidates.txt /tmp/telenotif_wifi_assoc.txt /tmp/chilli_raw.txt

ui_panel_top "$CYAN" "$BGREEN" "[ Kontrol Bot Notif ]" "[ Kontrol Bot Notif ]"
ui_panel_kv "$CYAN" "Aksi" "Stop / Matikan Bot" "${WHITE}Stop / Matikan Bot${NC}"
ui_panel_kv "$CYAN" "Status" "* STOPPED (Mati)" "${BRED}● STOPPED${NC} ${GRAY}(Mati)${NC}"
ui_panel_kv "$CYAN" "Lanjut" "Ketik 'resbotnotif'" "${YELLOW}Ketik 'resbotnotif'${NC}"
ui_panel_bot "$CYAN"
EOF_STOP
    chmod +x /usr/bin/stopbotnotif

    # Perintah langsung: cekbot & telenotif-status (LANGSUNG TAMPIL TANPA MENU)
    cat << 'EOF_CEK' > /usr/bin/cekbot
#!/bin/sh
. /usr/lib/kiheo/ui.sh
. /usr/lib/kiheo/modules/botnotif.sh

[ -f /etc/telenotif.conf ] && . /etc/telenotif.conf
: "${MAX_MISSES:=15}"
: "${PROBE_INTERVAL:=2}"

PIDS="$(ui_get_bot_pid)"
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
bn_render_devices_box
EOF_CEK
    chmod +x /usr/bin/cekbot
    ln -sf /usr/bin/cekbot /usr/bin/telenotif-status

    # Perintah langsung: hostbot (Ganti Nama Host tanpa masuk menu utama)
    cat << 'EOF_HOSTBOT' > /usr/bin/hostbot
#!/bin/sh
. /usr/lib/kiheo/ui.sh
. /usr/lib/kiheo/modules/botnotif.sh
bn_rename_host_screen
EOF_HOSTBOT
    chmod +x /usr/bin/hostbot

    # Perintah langsung: blockbot (Block / Unblock Perangkat tanpa masuk menu utama)
    cat << 'EOF_BLOCKBOT' > /usr/bin/blockbot
#!/bin/sh
. /usr/lib/kiheo/ui.sh
. /usr/lib/kiheo/modules/botnotif.sh
bn_block_menu_screen
EOF_BLOCKBOT
    chmod +x /usr/bin/blockbot

    # Perintah langsung: idbot (Kelola User ID Bot tanpa masuk menu utama)
    cat << 'EOF_IDBOT' > /usr/bin/idbot
#!/bin/sh
. /usr/lib/kiheo/ui.sh
. /usr/lib/kiheo/modules/botnotif.sh
bn_manage_user_ids
EOF_IDBOT
    chmod +x /usr/bin/idbot

    # Perintah langsung: probebot (Ubah Mode Probe tanpa masuk menu utama)
    cat << 'EOF_PROBEBOT' > /usr/bin/probebot
#!/bin/sh
. /usr/lib/kiheo/ui.sh
. /usr/lib/kiheo/modules/botnotif.sh
bn_edit_probe
EOF_PROBEBOT
    chmod +x /usr/bin/probebot
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
        printf "${CYAN}Token Bot Telegram${NC}              : "
        read USER_TOKEN
        [ -z "$USER_TOKEN" ] && printf "${RED}Token tidak boleh kosong!${NC}\n"
    done

    local USER_CHAT_ID=""
    while [ -z "$USER_CHAT_ID" ]; do
        printf "${CYAN}Chat / User ID Telegram${NC}         : "
        read USER_CHAT_ID
        [ -z "$USER_CHAT_ID" ] && printf "${RED}Chat ID tidak boleh kosong!${NC}\n"
    done

    printf "${CYAN}Nama User / Bot [Default: Admin]${NC}: "
    read USER_BOT_NAME
    [ -z "$USER_BOT_NAME" ] && USER_BOT_NAME="Admin"

    printf "${CYAN}Nama Router [Default: KIHEO]${NC}    : "
    read USER_ROUTER_NAME
    [ -z "$USER_ROUTER_NAME" ] && ROUTER_NAME="KIHEO" || ROUTER_NAME="$USER_ROUTER_NAME"

    printf "${CYAN}Interface LAN [Default: br-lan]${NC} : "
    read USER_IFACE
    [ -z "$USER_IFACE" ] && FALLBACK_IFACE="br-lan" || FALLBACK_IFACE="$USER_IFACE"

    printf "${CYAN}Batas Gagal Probe [Default: 15]${NC} : "
    read USER_MAX_MISSES
    case "$USER_MAX_MISSES" in
        ''|*[!0-9]*|0) MAX_MISSES=15 ;;
        *) MAX_MISSES="$USER_MAX_MISSES" ;;
    esac

    printf "${CYAN}Interval Cek Detik [Default: 2]${NC} : "
    read USER_INTERVAL
    case "$USER_INTERVAL" in
        ''|*[!0-9]*|0) PROBE_INTERVAL=2 ;;
        *) PROBE_INTERVAL="$USER_INTERVAL" ;;
    esac

    WIFI_INACTIVE_MAX=300000
    INSTALL_TIME="$(ui_get_localtime)"

    bn_create_binaries

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

    for init_id in $(printf '%s' "$USER_CHAT_ID" | tr ',;' '  '); do
        [ -z "$init_id" ] && continue
        bn_set_user_name "$init_id" "$USER_BOT_NAME"
    done

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

bn_edit_probe() {
    while true; do
        [ -f "$CONF_FILE" ] && . "$CONF_FILE"
        local cur_miss="${MAX_MISSES:-15}"
        local cur_int="${PROBE_INTERVAL:-2}"
        local total_sec=$(( cur_miss * cur_int ))

        clear
        ui_banner

        ui_panel_top "$CYAN" "$BGREEN" "[ Pengaturan Mode Probe ]" "[ Pengaturan Mode Probe ]"
        ui_panel_kv "$CYAN" "Batas Gagal" "${cur_miss}x percobaan" "${YELLOW}${cur_miss}x percobaan${NC}"
        ui_panel_kv "$CYAN" "Interval Cek" "${cur_int} detik" "${CYAN}${cur_int} detik${NC}"
        ui_panel_kv "$CYAN" "Total Jeda" "${total_sec} detik sebelum putus" "${WHITE}${total_sec} detik${NC} ${GRAY}sebelum putus${NC}"
        ui_panel_bot "$CYAN"

        printf "\n"
        ui_panel_top "$MAGENTA" "$BMAGENTA" "PILIH MODE PROBE" "PILIH MODE PROBE"
        ui_panel_line "$MAGENTA" \
            "  1: Cepat / Real-Time   (4x / 2s = 8 detik)        " \
            "  ${BGREEN}1:${NC} ${WHITE}Cepat / Real-Time${NC}   ${GRAY}(4x / 2s = 8 detik)${NC}        "
        ui_panel_line "$MAGENTA" \
            "  2: Normal / Seimbang   (15x / 2s = 30 detik)      " \
            "  ${BGREEN}2:${NC} ${WHITE}Normal / Seimbang${NC}   ${GRAY}(15x / 2s = 30 detik)${NC}      "
        ui_panel_line "$MAGENTA" \
            "  3: Hemat Daya / AP     (45x / 2s = 90 detik)      " \
            "  ${BGREEN}3:${NC} ${WHITE}Hemat Daya / AP${NC}     ${GRAY}(45x / 2s = 90 detik)${NC}      "
        ui_panel_line "$MAGENTA" \
            "  4: Custom Manual       (Isi Angka Sendiri)        " \
            "  ${BGREEN}4:${NC} ${CYAN}Custom Manual${NC}       ${GRAY}(Isi Angka Sendiri)${NC}        "
        ui_panel_line "$MAGENTA" \
            "  0: Kembali                                        " \
            "  ${BGREEN}0:${NC} ${WHITE}Kembali${NC}                                        "
        ui_panel_bot "$MAGENTA"

        printf "\n${WHITE}Pilihan: ${NC}"
        read p_opt

        local new_miss=""
        local new_int=""

        case "$p_opt" in
            1)
                new_miss=4
                new_int=2
                ;;
            2)
                new_miss=15
                new_int=2
                ;;
            3)
                new_miss=45
                new_int=2
                ;;
            4)
                printf "\n${CYAN}Masukkan Batas Gagal Probe [Saat ini: ${cur_miss}]${NC}   : "
                read in_miss
                case "$in_miss" in
                    '') new_miss="$cur_miss" ;;
                    *[!0-9]*|0)
                        printf "${BRED}✖ Batas gagal harus angka minimal 1!${NC}\n"
                        sleep 1
                        continue
                        ;;
                    *) new_miss="$in_miss" ;;
                esac

                printf "${CYAN}Masukkan Interval Cek Detik [Saat ini: ${cur_int}]${NC}  : "
                read in_int
                case "$in_int" in
                    '') new_int="$cur_int" ;;
                    *[!0-9]*|0)
                        printf "${BRED}✖ Interval cek harus angka minimal 1!${NC}\n"
                        sleep 1
                        continue
                        ;;
                    *) new_int="$in_int" ;;
                esac
                ;;
            0|00|q|Q)
                break
                ;;
            *)
                printf "\n${BRED}Pilihan tidak valid!${NC}\n"
                sleep 1
                continue
                ;;
        esac

        if [ -n "$new_miss" ] && [ -n "$new_int" ]; then
            if grep -q '^MAX_MISSES=' "$CONF_FILE" 2>/dev/null; then
                sed -i "s|^MAX_MISSES=.*|MAX_MISSES=\"${new_miss}\"|" "$CONF_FILE"
            else
                printf 'MAX_MISSES="%s"\n' "$new_miss" >> "$CONF_FILE"
            fi

            if grep -q '^PROBE_INTERVAL=' "$CONF_FILE" 2>/dev/null; then
                sed -i "s|^PROBE_INTERVAL=.*|PROBE_INTERVAL=\"${new_int}\"|" "$CONF_FILE"
            else
                printf 'PROBE_INTERVAL="%s"\n' "$new_int" >> "$CONF_FILE"
            fi

            local new_total=$(( new_miss * new_int ))
            printf "\n${BGREEN}✔ Mode Probe diubah menjadi ${new_miss}x gagal / ${new_int}s (Jeda ${new_total} detik)!${NC}\n"

            if [ -n "$(ui_get_bot_pid)" ]; then
                printf "${YELLOW}⟳ Menerapkan pengaturan ke layanan bot...${NC}\n"
                /usr/bin/resbotnotif >/dev/null 2>&1
            fi
            sleep 1
        fi
    done
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
    rm -f /var/run/telenotif.pid "$CONF_FILE" "$USERS_FILE" \
          /usr/bin/telenotif /usr/bin/telenotif-status /usr/bin/cekbot \
          /usr/bin/hostbot /usr/bin/blockbot /usr/bin/idbot /usr/bin/probebot \
          /usr/bin/resbotnotif /usr/bin/stopbotnotif \
          /tmp/telenotif_*.txt /tmp/chilli_raw.txt
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

        local max_in="$(ui_max_inner)"
        local ids_spaced="$(printf '%s' "$CHAT_ID" | tr ',;' '  ')"
        local w_uid=15
        local longest_name=15
        local idx=0
        for uid in $ids_spaced; do
            [ -z "$uid" ] && continue
            idx=$((idx + 1))
            local u_name="$(bn_get_user_name "$uid")"
            [ ${#uid} -gt $w_uid ] && w_uid=${#uid}
            [ ${#u_name} -gt $longest_name ] && longest_name=${#u_name}
        done
        [ $w_uid -gt 18 ] && w_uid=18

        # Total inner = 22 + w_uid + w_name
        local usr_inner=$(( 22 + w_uid + longest_name ))
        [ $usr_inner -lt 52 ] && usr_inner=52
        [ $usr_inner -gt $max_in ] && usr_inner=$max_in
        local w_name=$(( usr_inner - 22 - w_uid ))
        [ $w_name -lt 10 ] && w_name=10

        local hdr_uid="$(printf "%-${w_uid}s" "User / Chat ID")"
        local hdr_name="$(printf "%-${w_name}s" "Nama")"

        ui_panel_top "$CYAN" "$BGREEN" "[ Daftar User ID Bot ]" "[ Daftar User ID Bot ]" "$usr_inner"
        ui_panel_line "$CYAN" \
            "  No  ${hdr_uid} ${hdr_name} Tipe          " \
            "  ${BMAGENTA}No  ${hdr_uid} ${hdr_name} Tipe${NC}          " "$usr_inner"

        if [ "$idx" -gt 0 ]; then
            local cur_i=0
            for uid in $ids_spaced; do
                [ -z "$uid" ] && continue
                cur_i=$((cur_i + 1))
                local id_type="Personal"
                case "$uid" in -*) id_type="Grup/Channel" ;; esac
                local u_name="$(bn_get_user_name "$uid")"

                local uid_disp="$uid"
                [ ${#uid} -gt $w_uid ] && uid_disp="$(printf '%s' "$uid" | cut -c1-$((w_uid - 3)))..."

                local name_disp="$u_name"
                [ ${#u_name} -gt $w_name ] && name_disp="$(printf '%s' "$u_name" | cut -c1-$((w_name - 3)))..."

                local no_f="$(printf '%2d' "$cur_i")"
                local uid_f="$(printf "%-${w_uid}s" "$uid_disp")"
                local name_f="$(printf "%-${w_name}s" "$name_disp")"
                local typ_f="$(printf '%-12s' "$id_type")"
                ui_panel_line "$CYAN" \
                    "  ${no_f}  ${uid_f} ${name_f} ${typ_f}  " \
                    "  ${BGREEN}${no_f}${NC}  ${WHITE}${uid_f}${NC} ${YELLOW}${name_f}${NC} ${CYAN}${typ_f}${NC}  " "$usr_inner"
            done
        else
            ui_panel_line "$CYAN" \
                "  (Belum ada User ID yang terdaftar)" \
                "  ${GRAY}(Belum ada User ID yang terdaftar)${NC}" "$usr_inner"
        fi
        ui_panel_bot "$CYAN" "$usr_inner"

        printf "\n"
        ui_panel_top "$MAGENTA" "$BMAGENTA" "COMMANDS" "COMMANDS"
        ui_panel_line "$MAGENTA" "  1: Tambah User ID Baru                            " "  ${BGREEN}1:${NC} ${WHITE}Tambah User ID Baru${NC}                            "
        ui_panel_line "$MAGENTA" "  2: Hapus User ID (Nomor: 1 / 1,2,3)               " "  ${BGREEN}2:${NC} ${WHITE}Hapus User ID${NC} ${RED}(Nomor: 1 / 1,2,3)${NC}               "
        ui_panel_line "$MAGENTA" "  3: Ubah Nama User ID (Pilih Nomor)                " "  ${BGREEN}3:${NC} ${WHITE}Ubah Nama User ID${NC} ${YELLOW}(Pilih Nomor)${NC}                "
        ui_panel_line "$MAGENTA" "  0: Kembali                                        " "  ${BGREEN}0:${NC} ${WHITE}Kembali${NC}                                        "
        ui_panel_bot "$MAGENTA"

        printf "\n${WHITE}Pilihan: ${NC}"
        read sub_opt

        case "$sub_opt" in
            1)
                printf "\n${CYAN}Masukkan User ID / Chat ID Telegram baru (0 batal)${NC}\n"
                printf "${GRAY}(Contoh: 7480651332 atau -1001234567890 untuk grup)${NC}\n"
                printf "${WHITE}User ID : ${NC}"
                read new_uid
                new_uid="$(printf '%s' "$new_uid" | tr -d ' \r\n')"
                [ "$new_uid" = "0" ] || [ -z "$new_uid" ] && continue
                case "$new_uid" in
                    *[!0-9-]*)
                        printf "${BRED}✖ Format User ID tidak valid! Harus berupa angka.${NC}\n"
                        sleep 2
                        ;;
                    *)
                        if printf ',%s,' "$CHAT_ID" | grep -q ",${new_uid},"; then
                            printf "${YELLOW}! User ID %s sudah terdaftar.${NC}\n" "$new_uid"
                            sleep 2
                        else
                            printf "${WHITE}Nama User / Bot / Grup [Default: User]: ${NC}"
                            read new_uname
                            new_uname="$(printf '%s' "$new_uname" | tr -d '|\r\n')"
                            [ -z "$new_uname" ] && new_uname="User"

                            [ -z "$CHAT_ID" ] && updated_ids="$new_uid" || updated_ids="${CHAT_ID},${new_uid}"
                            if grep -q '^CHAT_ID=' "$CONF_FILE" 2>/dev/null; then
                                sed -i "s|^CHAT_ID=.*|CHAT_ID=\"${updated_ids}\"|" "$CONF_FILE"
                            else
                                printf 'CHAT_ID="%s"\n' "$updated_ids" >> "$CONF_FILE"
                            fi
                            bn_set_user_name "$new_uid" "$new_uname"
                            printf "${BGREEN}✔ User ID %s (%s) berhasil ditambahkan!${NC}\n" "$new_uid" "$new_uname"

                            if [ -n "$TELEGRAM_TOKEN" ]; then
                                curl -k -s --connect-timeout 5 -m 8 -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
                                    -d "chat_id=${new_uid}" \
                                    --data-urlencode "text=✅ User ID Anda (${new_uid} - ${new_uname}) berhasil ditambahkan ke KIHEO-BOT (${ROUTER_NAME:-Router})!" \
                                    -d "parse_mode=HTML" >/dev/null 2>&1 &
                            fi

                            if [ -n "$(ui_get_bot_pid)" ]; then
                                /usr/bin/resbotnotif >/dev/null 2>&1
                            fi
                            sleep 1
                        fi
                        ;;
                esac
                ;;
            2)
                if [ "$idx" -eq 0 ]; then
                    printf "\n${YELLOW}! Belum ada User ID untuk dihapus.${NC}\n"
                    sleep 1
                    continue
                fi
                printf "\n${WHITE}Masukkan Nomor yang dihapus (contoh: 1 atau 1,2,3 / 0 batal): ${NC}"
                read del_raw
                del_raw="$(printf '%s' "$del_raw" | tr -d ' \r\n')"
                [ -z "$del_raw" ] || [ "$del_raw" = "0" ] && continue

                local parsed_del
                parsed_del="$(ui_parse_numbers "$del_raw" "$idx")"
                if [ $? -ne 0 ] || [ -z "$parsed_del" ]; then
                    printf "${BRED}✖ Format nomor tidak valid atau di luar daftar (1-%d)!${NC}\n" "$idx"
                    sleep 1
                    continue
                fi

                local new_list=""
                local cur_i=0
                for uid in $ids_spaced; do
                    [ -z "$uid" ] && continue
                    cur_i=$((cur_i + 1))
                    case " $parsed_del " in
                        *" $cur_i "*)
                            bn_del_user_name "$uid"
                            printf "${BGREEN}✔ Dihapus:${NC} Nomor %s (${WHITE}%s${NC})\n" "$cur_i" "$uid"
                            ;;
                        *)
                            [ -z "$new_list" ] && new_list="$uid" || new_list="${new_list},${uid}"
                            ;;
                    esac
                done

                sed -i "s|^CHAT_ID=.*|CHAT_ID=\"${new_list}\"|" "$CONF_FILE"
                [ -n "$(ui_get_bot_pid)" ] && /usr/bin/resbotnotif >/dev/null 2>&1
                sleep 1
                ;;
            3)
                if [ "$idx" -eq 0 ]; then
                    printf "\n${YELLOW}! Belum ada User ID di daftar.${NC}\n"
                    sleep 1
                    continue
                fi
                printf "\n${WHITE}Masukkan Nomor urut yang ingin diubah namanya (0 batal): ${NC}"
                read ren_no
                ren_no="$(printf '%s' "$ren_no" | tr -d ' \r\n')"
                case "$ren_no" in
                    0|00|'') continue ;;
                    *[!0-9]*)
                        printf "${BRED}✖ Masukkan angka nomor urut yang valid!${NC}\n"
                        sleep 1
                        continue
                        ;;
                esac
                if [ "$ren_no" -lt 1 ] || [ "$ren_no" -gt "$idx" ]; then
                    printf "${BRED}✖ Nomor %s tidak ada di daftar!${NC}\n" "$ren_no"
                    sleep 1
                    continue
                fi

                local cur_i=0
                local target_uid=""
                for uid in $ids_spaced; do
                    [ -z "$uid" ] && continue
                    cur_i=$((cur_i + 1))
                    [ "$cur_i" -eq "$ren_no" ] && target_uid="$uid" && break
                done

                if [ -n "$target_uid" ]; then
                    printf "${WHITE}Masukkan Nama baru untuk %s (0 batal): ${NC}" "$target_uid"
                    read new_uname
                    new_uname="$(printf '%s' "$new_uname" | tr -d '|\r\n')"
                    [ -z "$new_uname" ] || [ "$new_uname" = "0" ] && continue
                    bn_set_user_name "$target_uid" "$new_uname"
                    printf "${BGREEN}✔ Nama untuk %s berhasil diubah menjadi '%s'!${NC}\n" "$target_uid" "$new_uname"
                    sleep 1
                fi
                ;;
            0|00|q|Q) break ;;
            *) printf "\n${BRED}Pilihan tidak valid!${NC}\n"; sleep 1 ;;
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
                "   1  Install                                       " \
                "   ${BGREEN}1${NC}  ${WHITE}Install${NC}                                       "
            ui_panel_line "$BRED" \
                "   0  Kembali                                       " \
                "   ${BGREEN}0${NC}  ${WHITE}Kembali${NC}                                       "
            ui_panel_bot "$BRED"

            printf "\n${WHITE}Pilih menu: ${NC}"
            read m_opt
            case "$m_opt" in
                1|i|I)
                    bn_install
                    printf "\n${GRAY}Tekan Enter untuk lanjut...${NC}"
                    read _
                    ;;
                0|00|q|Q) return ;;
                *) printf "\n${BRED}Pilihan tidak valid!${NC}\n"; sleep 1 ;;
            esac
        else
            . "$CONF_FILE"
            local pids="$(ui_get_bot_pid)"
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
            ui_panel_kv "$CYAN" "Mode Probe" "${MAX_MISSES:-15}x gagal / ${PROBE_INTERVAL:-2}s" "${YELLOW}${MAX_MISSES:-15}x gagal${NC} / ${CYAN}${PROBE_INTERVAL:-2}s${NC}"
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
                "   3  Ganti Nama Host Perangkat (hostbot)           " \
                "   ${BGREEN}3${NC}  ${WHITE}Ganti Nama Host Perangkat${NC} ${YELLOW}(hostbot)${NC}           "
            ui_panel_line "$BRED" \
                "   4  Block / Unblock Perangkat (blockbot)          " \
                "   ${BGREEN}4${NC}  ${WHITE}Block / Unblock Perangkat${NC} ${RED}(blockbot)${NC}          "
            ui_panel_line "$BRED" \
                "   5  Stop / Matikan Bot (stopbotnotif)             " \
                "   ${BGREEN}5${NC}  ${WHITE}Stop / Matikan Bot${NC} ${RED}(stopbotnotif)${NC}             "
            ui_panel_line "$BRED" \
                "   6  Kelola User ID Bot (idbot)                    " \
                "   ${BGREEN}6${NC}  ${WHITE}Kelola User ID Bot${NC} ${BMAGENTA}(idbot)${NC}                    "
            ui_panel_line "$BRED" \
                "   7  Ubah Mode Probe (probebot)                    " \
                "   ${BGREEN}7${NC}  ${WHITE}Ubah Mode Probe${NC} ${YELLOW}(probebot)${NC}                    "
            ui_panel_line "$BRED" \
                "   8  Install Ulang / Konfigurasi Ulang             " \
                "   ${BGREEN}8${NC}  ${WHITE}Install Ulang / Konfigurasi Ulang${NC}             "
            ui_panel_line "$BRED" \
                "   9  Hapus / Uninstall Bot Notif                   " \
                "   ${BGREEN}9${NC}  ${WHITE}Hapus / Uninstall Bot Notif${NC}                   "
            ui_panel_line "$BRED" \
                "   0  Kembali                                       " \
                "   ${BGREEN}0${NC}  ${WHITE}Kembali${NC}                                       "
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
                    bn_rename_host_screen
                    ;;
                4)
                    bn_block_menu_screen
                    ;;
                5)
                    printf "\n"
                    /usr/bin/stopbotnotif
                    printf "\n${GRAY}Tekan Enter untuk kembali...${NC}"
                    read _
                    ;;
                6)
                    bn_manage_user_ids
                    ;;
                7)
                    bn_edit_probe
                    ;;
                8)
                    bn_install
                    printf "\n${GRAY}Tekan Enter untuk kembali...${NC}"
                    read _
                    ;;
                9)
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
MENU_FLAG="/etc/kiheo/.menu_installed"

mkdir -p "$PLUGIN_DIR" "$MODULE_DIR"
[ -f "$MODULE_DIR/botnotif.sh" ] && . "$MODULE_DIR/botnotif.sh"

install_menu_hub() {
    clear
    ui_banner
    ui_panel_top "$CYAN" "$BGREEN" "[ Instalasi Menu Utama ]" "[ Instalasi Menu Utama ]"
    ui_panel_line "$CYAN" "  Memasang struktur Menu Utama KIHEO-BOT...         " "  ${WHITE}Memasang struktur Menu Utama KIHEO-BOT...${NC}         "
    ui_panel_bot "$CYAN"
    printf "\n"

    local current=0 width=25
    while [ $current -le 100 ]; do
        local filled=$(( current * width / 100 ))
        local empty=$(( width - filled ))
        local bar=""
        local i=0; while [ $i -lt $filled ]; do bar="${bar}#"; i=$((i + 1)); done
        local i=0; while [ $i -lt $empty ]; do bar="${bar}-"; i=$((i + 1)); done
        printf "\r  ${YELLOW}[%s] %3d%% - %-32s${NC}" "$bar" "$current" "Menyiapkan Menu KIHEO-BOT..."
        current=$((current + 20))
        sleep 0.08
    done

    mkdir -p "$PLUGIN_DIR" "$MODULE_DIR"
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
    touch "$MENU_FLAG"
    printf "\n\n  ${BGREEN}✔ Menu Utama KIHEO-BOT berhasil dipasang!${NC}\n"
    sleep 1
}

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
            command -v nft >/dev/null 2>&1 && nft delete table inet kiheo_block >/dev/null 2>&1
            rm -rf /usr/lib/kiheo /etc/kiheo /usr/bin/kiheo \
                   /usr/bin/telenotif /usr/bin/telenotif-status /usr/bin/cekbot \
                   /usr/bin/hostbot /usr/bin/blockbot /usr/bin/idbot /usr/bin/probebot \
                   /usr/bin/resbotnotif /usr/bin/stopbotnotif /etc/telenotif.conf \
                   /etc/telenotif_users.conf /var/run/telenotif.pid \
                   /tmp/telenotif_*.txt /tmp/chilli_raw.txt
            printf "${BGREEN}✔ KIHEO-BOT Hub berhasil dihapus total.${NC}\n"
            exit 0
            ;;
    esac
}

bn_is_installed && touch "$MENU_FLAG"

while true; do
    HOSTNAME_SYS="$(uci get system.@system[0].hostname 2>/dev/null || uname -n)"
    LAN_IP="$(uci get network.lan.ipaddr 2>/dev/null || echo "192.168.1.1")"
    LOCAL_TIME_SYS="$(ui_get_localtime)"
    UPTIME_SYS="$(ui_get_uptime)"

    PLUGIN_COUNT=0
    for f in "$PLUGIN_DIR"/*.sh; do
        [ -f "$f" ] && PLUGIN_COUNT=$((PLUGIN_COUNT + 1))
    done

    if [ ! -f "$MENU_FLAG" ] && ! bn_is_installed && [ "$PLUGIN_COUNT" -eq 0 ]; then
        clear
        ui_banner

        ui_panel_top "$CYAN" "$BGREEN" "[ Informasi Sistem ]" "[ Informasi Sistem ]"
        ui_panel_kv "$CYAN" "Host" "${HOSTNAME_SYS} (${LAN_IP})" "${WHITE}${HOSTNAME_SYS}${NC} ${GRAY}(${LAN_IP})${NC}"
        ui_panel_kv "$CYAN" "Local Time" "${LOCAL_TIME_SYS}" "${WHITE}${LOCAL_TIME_SYS}${NC}"
        ui_panel_kv "$CYAN" "Uptime" "${UPTIME_SYS}" "${WHITE}${UPTIME_SYS}${NC}"
        ui_panel_kv "$CYAN" "Status Menu" "BELUM TERPASANG" "${BRED}BELUM TERPASANG${NC}"
        ui_panel_bot "$CYAN"

        printf "\n"

        ui_panel_top "$BRED" "$BGREEN" ". Menu Utama ." "• Menu Utama •"
        ui_panel_line "$BRED" \
            "  ID  Action                                        " \
            "  ${BMAGENTA}ID  Action${NC}                                        "
        ui_panel_line "$BRED" \
            "   1  Install Menu KIHEO-BOT                        " \
            "   ${BGREEN}1${NC}  ${WHITE}Install Menu KIHEO-BOT${NC}                        "
        ui_panel_line "$BRED" \
            "   0  Kembali                                       " \
            "   ${BGREEN}0${NC}  ${WHITE}Kembali${NC}                                       "
        ui_panel_bot "$BRED"

        printf "\n${WHITE}Pilih menu: ${NC}"
        read CHOICE

        case "$CHOICE" in
            1|i|I)
                install_menu_hub
                ;;
            0|00|q|Q|exit)
                printf "\n${CYAN}Kembali ke terminal. Ketik 'kiheo' untuk membuka lagi.${NC}\n"
                exit 0
                ;;
            *)
                printf "\n${BRED}Pilihan tidak valid! Ketik 1 untuk Install Menu atau 0 untuk Kembali.${NC}\n"
                sleep 1
                ;;
        esac
        continue
    fi

    if bn_is_installed; then
        if [ -n "$(ui_get_bot_pid)" ]; then
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

    clear
    ui_banner

    ui_panel_top "$CYAN" "$BGREEN" "[ Informasi Sistem ]" "[ Informasi Sistem ]"
    ui_panel_kv "$CYAN" "Host" "${HOSTNAME_SYS} (${LAN_IP})" "${WHITE}${HOSTNAME_SYS}${NC} ${GRAY}(${LAN_IP})${NC}"
    ui_panel_kv "$CYAN" "Local Time" "${LOCAL_TIME_SYS}" "${WHITE}${LOCAL_TIME_SYS}${NC}"
    ui_panel_kv "$CYAN" "Uptime" "${UPTIME_SYS}" "${WHITE}${UPTIME_SYS}${NC}"
    ui_panel_kv "$CYAN" "Bot Notif" "${NOTIF_ST_PLAIN}" "${NOTIF_ST_COLOR}"
    ui_panel_kv "$CYAN" "Plugins" "${PLUGIN_COUNT} Proyek Bot Tambahan" "${BMAGENTA}${PLUGIN_COUNT} Proyek Bot Tambahan${NC}"
    ui_panel_kv "$CYAN" "Folder" "/etc/kiheo/plugins/" "${YELLOW}/etc/kiheo/plugins/${NC}"
    ui_panel_bot "$CYAN"

    printf "\n"

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
        "   0  Keluar                                        " \
        "   ${BGREEN}0${NC}  ${WHITE}Keluar${NC}                                        "
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

# Jika konfigurasi lama sudah ada, perbarui semua binary & restart otomatis tanpa ubah setting user
if [ -f /etc/telenotif.conf ]; then
    . /usr/lib/kiheo/modules/botnotif.sh
    bn_create_binaries
    if grep -q '^WIFI_INACTIVE_MAX=' /etc/telenotif.conf; then
        sed -i 's|^WIFI_INACTIVE_MAX=.*|WIFI_INACTIVE_MAX="300000"|' /etc/telenotif.conf
    else
        echo 'WIFI_INACTIVE_MAX="300000"' >> /etc/telenotif.conf
    fi
    /usr/bin/resbotnotif >/dev/null 2>&1
fi

clear
. /usr/lib/kiheo/ui.sh
ui_banner
ui_panel_top "$CYAN" "$BGREEN" "[ Pemasangan Selesai ]" "[ Pemasangan Selesai ]"
ui_panel_kv "$CYAN" "Cek Status" "Ketik 'cekbot' (Langsung tampil)" "${BGREEN}Ketik 'cekbot'${NC} ${GRAY}(Tanpa menu)${NC}"
ui_panel_kv "$CYAN" "Ganti Host" "Ketik 'hostbot'" "${YELLOW}Ketik 'hostbot'${NC}"
ui_panel_kv "$CYAN" "Block MAC" "Ketik 'blockbot'" "${BRED}Ketik 'blockbot'${NC}"
ui_panel_kv "$CYAN" "User ID Bot" "Ketik 'idbot'" "${BMAGENTA}Ketik 'idbot'${NC}"
ui_panel_kv "$CYAN" "Mode Probe" "Ketik 'probebot'" "${CYAN}Ketik 'probebot'${NC}"
ui_panel_kv "$CYAN" "Restart Bot" "Ketik 'resbotnotif'" "${WHITE}Ketik 'resbotnotif'${NC}"
ui_panel_kv "$CYAN" "Stop Bot" "Ketik 'stopbotnotif'" "${RED}Ketik 'stopbotnotif'${NC}"
ui_panel_bot "$CYAN"
