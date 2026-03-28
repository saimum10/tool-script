#!/bin/bash

# ================================================================
#   GOBUSTER - Full Automation Tool
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

RESULTS_DIR="$HOME/gobuster_results"
HISTORY_FILE="$HOME/.gobuster_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# Common wordlists
WL_COMMON="/usr/share/wordlists/dirb/common.txt"
WL_BIG="/usr/share/wordlists/dirb/big.txt"
WL_DIRBUSTER="/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
WL_DNS="/usr/share/wordlists/dnsmap.txt"
WL_SUBDOMAINS="/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo ' ██████╗  ██████╗ ██████╗ ██╗   ██╗███████╗████████╗███████╗██████╗ '
    echo ' ██╔════╝ ██╔═══██╗██╔══██╗██║   ██║██╔════╝╚══██╔══╝██╔════╝██╔══██╗'
    echo ' ██║  ███╗██║   ██║██████╔╝██║   ██║███████╗   ██║   █████╗  ██████╔╝'
    echo ' ██║   ██║██║   ██║██╔══██╗██║   ██║╚════██║   ██║   ██╔══╝  ██╔══██╗'
    echo ' ╚██████╔╝╚██████╔╝██████╔╝╚██████╔╝███████║   ██║   ███████╗██║  ██║'
    echo '  ╚═════╝  ╚═════╝ ╚═════╝  ╚═════╝ ╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝'
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}      Gobuster Full Automation Tool | Directory & DNS Brute Force${NC}"
    echo ""
}

# ================================================================
# CHECK DEPENDENCIES
# ================================================================
check_deps() {
    echo -e "${CYAN}[*] Dependencies চেক করা হচ্ছে...${NC}"
    local missing=()
    for tool in gobuster whois curl dig host; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
            echo -e "  ${RED}[✗] $tool — পাওয়া যায়নি${NC}"
        else
            echo -e "  ${GREEN}[✓] $tool${NC}"
        fi
    done

    # Wordlist check
    echo ""
    echo -e "${CYAN}[*] Wordlist চেক করা হচ্ছে...${NC}"
    for wl in "$WL_COMMON" "$WL_BIG" "$WL_DIRBUSTER"; do
        if [ -f "$wl" ]; then
            echo -e "  ${GREEN}[✓] $wl${NC}"
        else
            echo -e "  ${YELLOW}[!] $wl — নেই (custom wordlist দিতে পারবেন)${NC}"
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing tools: ${missing[*]}${NC}"
        echo -e "${YELLOW}[*] Install করুন: sudo apt install ${missing[*]}${NC}"
        exit 1
    fi
    echo ""
}

# ================================================================
# WHOIS LOOKUP
# ================================================================
whois_lookup() {
    local domain=$1
    echo -e "${MAGENTA}${BOLD}┌─── WHOIS INFORMATION ─────────────────────────────┐${NC}"
    local result
    result=$(whois "$domain" 2>/dev/null | grep -E \
        "Registrar:|Registrant Name:|Country:|Creation Date:|Updated Date:|Name Server:|Organization:|Admin Email:" \
        | head -15)
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
    local domain=$1
    echo -e "${BLUE}${BOLD}┌─── GEO IP INFORMATION ────────────────────────────┐${NC}"
    local geo
    geo=$(curl -s --max-time 5 "http://ip-api.com/json/$domain" 2>/dev/null)
    if echo "$geo" | grep -q '"status":"success"'; then
        local country region city isp lat lon
        country=$(echo "$geo" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        region=$(echo  "$geo" | grep -o '"regionName":"[^"]*"' | cut -d'"' -f4)
        city=$(echo    "$geo" | grep -o '"city":"[^"]*"'       | cut -d'"' -f4)
        isp=$(echo     "$geo" | grep -o '"isp":"[^"]*"'        | cut -d'"' -f4)
        lat=$(echo     "$geo" | grep -o '"lat":[^,]*'          | cut -d':' -f2)
        lon=$(echo     "$geo" | grep -o '"lon":[^,]*'          | cut -d':' -f2)
        echo -e "  ${WHITE}Country   :${NC} ${GREEN}$country${NC}"
        echo -e "  ${WHITE}Region    :${NC} ${GREEN}$region${NC}"
        echo -e "  ${WHITE}City      :${NC} ${GREEN}$city${NC}"
        echo -e "  ${WHITE}ISP       :${NC} ${GREEN}$isp${NC}"
        echo -e "  ${WHITE}Lat / Lon :${NC} ${GREEN}$lat / $lon${NC}"
    else
        echo -e "  ${YELLOW}[!] GeoIP data পাওয়া যায়নি।${NC}"
    fi
    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# REVERSE DNS
# ================================================================
reverse_dns() {
    local domain=$1
    echo -e "${GREEN}${BOLD}┌─── REVERSE DNS LOOKUP ────────────────────────────┐${NC}"
    local ip result
    ip=$(dig +short "$domain" 2>/dev/null | grep -E '^[0-9]+\.' | head -1)
    result=$(dig -x "$ip" +short 2>/dev/null)
    echo -e "  ${WHITE}Domain    :${NC} ${GREEN}$domain${NC}"
    echo -e "  ${WHITE}IP        :${NC} ${GREEN}${ip:-পাওয়া যায়নি}${NC}"
    echo -e "  ${WHITE}Hostname  :${NC} ${GREEN}${result:-কোনো rDNS রেকর্ড নেই}${NC}"
    echo -e "${GREEN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# HTTP HEADER CHECK  (dir/vhost/fuzz mode এ relevant)
# ================================================================
http_header_check() {
    local target=$1
    echo -e "${CYAN}${BOLD}┌─── HTTP HEADER PRE-CHECK ─────────────────────────┐${NC}"
    local headers
    headers=$(curl -s -I --max-time 8 "$target" 2>/dev/null | head -20)
    if [ -n "$headers" ]; then
        local server powered code
        code=$(echo    "$headers" | head -1)
        server=$(echo  "$headers" | grep -i "^Server:"       | head -1)
        powered=$(echo "$headers" | grep -i "^X-Powered-By:" | head -1)
        echo -e "  ${WHITE}Status    :${NC} ${GREEN}$code${NC}"
        [ -n "$server"  ] && echo -e "  ${WHITE}Server    :${NC} ${YELLOW}$server${NC}"
        [ -n "$powered" ] && echo -e "  ${WHITE}Powered By:${NC} ${YELLOW}$powered${NC}"
        echo ""
        echo -e "  ${CYAN}Security Headers:${NC}"
        for hdr in "Strict-Transport-Security" "Content-Security-Policy" \
                   "X-Frame-Options" "X-XSS-Protection" "X-Content-Type-Options"; do
            if echo "$headers" | grep -qi "^$hdr:"; then
                echo -e "    ${GREEN}[✓] $hdr${NC}"
            else
                echo -e "    ${RED}[✗] $hdr — Missing!${NC}"
            fi
        done
    else
        echo -e "  ${YELLOW}[!] Target HTTP response নেই বা unreachable।${NC}"
    fi
    echo -e "${CYAN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# PRE-SCAN RECON
# ================================================================
pre_scan_recon() {
    local target=$1
    local mode=$2
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)

    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}   PRE-SCAN RECON  ›  $target${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    whois_lookup "$domain"
    geoip_lookup "$domain"
    reverse_dns  "$domain"

    # HTTP header check শুধু web-based mode এ
    if [[ "$mode" == "dir" || "$mode" == "vhost" || "$mode" == "fuzz" ]]; then
        http_header_check "$target"
    fi
}

# ================================================================
# STEP 1 — TARGET
# ================================================================
get_target() {
    TARGET=""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║      STEP 1 — TARGET                 ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""
    read -p "$(echo -e ${WHITE}"Target দিন: "${NC})" TARGET

    if [ -z "$TARGET" ]; then
        echo -e "${RED}[!] Target দেওয়া হয়নি!${NC}"
        get_target
    fi
    echo ""
}

# ================================================================
# STEP 2 — MODE SELECT
# ================================================================
get_mode() {
    MODE=""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║      STEP 2 — MODE SELECT                                           ║${NC}"
    echo -e "${GREEN}${BOLD}╠══════════╦══════════════════════╦══════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${WHITE}Mode${NC}      ${GREEN}║${NC} ${WHITE}কী করে${NC}               ${GREEN}║${NC} ${WHITE}কখন ব্যবহার করবেন${NC}                  ${GREEN}║${NC}"
    echo -e "${GREEN}${BOLD}╠══════════╬══════════════════════╬══════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}1) dir${NC}    ${GREEN}║${NC} Directory/File hunt      ${GREEN}║${NC} Website এ hidden files খুঁজতে          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}2) dns${NC}    ${GREEN}║${NC} Subdomain enumeration    ${GREEN}║${NC} Hidden subdomain বের করতে              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}3) vhost${NC}  ${GREEN}║${NC} Virtual host discovery   ${GREEN}║${NC} Same IP এ একাধিক site খুঁজতে          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}4) fuzz${NC}   ${GREEN}║${NC} Custom fuzzing           ${GREEN}║${NC} URL এর যেকোনো অংশে wordlist দিতে     ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}5) s3${NC}     ${GREEN}║${NC} AWS S3 bucket hunt       ${GREEN}║${NC} Exposed S3 bucket খুঁজতে              ${GREEN}║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════╩══════════════════════╩══════════════════════════════════════╝${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Mode select করুন [1-5]: "${NC})" mode_ch

    case $mode_ch in
        1) MODE="dir"   ;;
        2) MODE="dns"   ;;
        3) MODE="vhost" ;;
        4) MODE="fuzz"  ;;
        5) MODE="s3"    ;;
        *)
            echo -e "${RED}[!] ভুল অপশন।${NC}"
            get_mode
            ;;
    esac
    echo -e "  ${GREEN}[✓] Mode: ${BOLD}$MODE${NC}"
    echo ""
}

# ================================================================
# WORDLIST PICKER
# ================================================================
pick_wordlist() {
    local mode=$1
    WORDLIST=""

    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║      WORDLIST SELECT                                                ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ "$mode" == "dns" ]]; then
        echo -e "  ${GREEN}1)${NC} dnsmap.txt           ${DIM}(DNS default)${NC}"
        echo -e "  ${GREEN}2)${NC} subdomains-top1million ${DIM}(SecLists — বড়)${NC}"
        echo -e "  ${GREEN}3)${NC} Custom path"
    else
        echo -e "  ${GREEN}1)${NC} common.txt           ${DIM}(ছোট, দ্রুত)${NC}"
        echo -e "  ${GREEN}2)${NC} big.txt              ${DIM}(মাঝারি)${NC}"
        echo -e "  ${GREEN}3)${NC} directory-list-2.3-medium.txt ${DIM}(বড়, সময় বেশি)${NC}"
        echo -e "  ${GREEN}4)${NC} Custom path"
    fi
    echo ""

    read -p "$(echo -e ${YELLOW}"Select: "${NC})" wl_ch

    if [[ "$mode" == "dns" ]]; then
        case $wl_ch in
            1) WORDLIST="$WL_DNS"        ;;
            2) WORDLIST="$WL_SUBDOMAINS" ;;
            3)
                read -p "$(echo -e ${WHITE}"Wordlist path: "${NC})" WORDLIST
                ;;
            *) WORDLIST="$WL_DNS" ;;
        esac
    else
        case $wl_ch in
            1) WORDLIST="$WL_COMMON"     ;;
            2) WORDLIST="$WL_BIG"        ;;
            3) WORDLIST="$WL_DIRBUSTER"  ;;
            4)
                read -p "$(echo -e ${WHITE}"Wordlist path: "${NC})" WORDLIST
                ;;
            *) WORDLIST="$WL_COMMON" ;;
        esac
    fi

    # Fallback if file not found
    if [ ! -f "$WORDLIST" ]; then
        echo -e "${RED}[!] Wordlist পাওয়া যায়নি: $WORDLIST${NC}"
        echo -e "${YELLOW}[*] Manual path দিন:${NC}"
        read -p "$(echo -e ${WHITE}"Wordlist path: "${NC})" WORDLIST
        if [ ! -f "$WORDLIST" ]; then
            echo -e "${RED}[!] এই wordlist ও নেই। Common ব্যবহার করা হবে।${NC}"
            WORDLIST="$WL_COMMON"
        fi
    fi

    echo -e "  ${GREEN}[✓] Wordlist: $WORDLIST${NC}"
    echo ""
}

# ================================================================
# STEP 3 — MODE-SPECIFIC CONFIG
# ================================================================
get_mode_config() {
    local mode=$1
    EXT_OPT=""
    STATUS_OPT=""
    RECURSIVE_OPT=""
    THREADS_OPT="-t 50"
    FUZZ_URL=""
    DOMAIN_ONLY=""

    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║      STEP 3 — ${mode^^} MODE CONFIG                                        ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    case $mode in

        # ── DIR MODE ──────────────────────────────────────────
        dir)
            # Extensions
            echo -e "  ${CYAN}File extension চেক করবেন? (web server identify করতে সাহায্য করে)${NC}"
            echo -e "  ${DIM}e.g: php,html,txt,js,bak,zip — একাধিক হলে comma দিয়ে লিখুন${NC}"
            read -p "$(echo -e ${WHITE}"  Extensions (Enter = skip): "${NC})" ext_in
            [ -n "$ext_in" ] && EXT_OPT="-x $ext_in" && \
                echo -e "  ${GREEN}[✓] Extensions: $ext_in${NC}"

            # Status filter
            echo ""
            echo -e "  ${CYAN}কোন HTTP status code গুলো দেখাবে?${NC}"
            echo -e "  ${GREEN}1)${NC} 200,204,301,302,307,401,403 ${DIM}(default — সব relevant)${NC}"
            echo -e "  ${GREEN}2)${NC} শুধু 200 ${DIM}(শুধু accessible files)${NC}"
            echo -e "  ${GREEN}3)${NC} 200,301,302 ${DIM}(accessible + redirects)${NC}"
            echo -e "  ${GREEN}4)${NC} Custom"
            read -p "$(echo -e ${YELLOW}"  Select [1-4]: "${NC})" st_ch
            case $st_ch in
                2) STATUS_OPT="-s 200" ;;
                3) STATUS_OPT="-s 200,301,302" ;;
                4)
                    read -p "$(echo -e ${WHITE}"  Status codes (comma separated): "${NC})" st_in
                    STATUS_OPT="-s $st_in"
                    ;;
                *) STATUS_OPT="-s 200,204,301,302,307,401,403" ;;
            esac
            echo -e "  ${GREEN}[✓] Status filter set।${NC}"

            # Recursive
            echo ""
            read -p "$(echo -e ${WHITE}"Recursive scan চালু করবেন? (subdirectory তেও ঢুকবে) (y/n): "${NC})" rec_yn
            [[ "$rec_yn" =~ ^[Yy]$ ]] && RECURSIVE_OPT="-r" && \
                echo -e "  ${GREEN}[✓] Recursive: ON${NC}"

            # Threads
            echo ""
            read -p "$(echo -e ${WHITE}"Threads কতটা? (Enter = 50, বেশি হলে দ্রুত কিন্তু noisy): "${NC})" th_in
            [ -n "$th_in" ] && THREADS_OPT="-t $th_in" || THREADS_OPT="-t 50"
            echo -e "  ${GREEN}[✓] Threads: ${th_in:-50}${NC}"
            ;;

        # ── DNS MODE ──────────────────────────────────────────
        dns)
            # Domain only (no http://)
            local raw_domain
            raw_domain=$(echo "$TARGET" | sed 's|https\?://||' | cut -d'/' -f1)
            DOMAIN_ONLY="$raw_domain"
            echo -e "  ${WHITE}Domain    : ${GREEN}$DOMAIN_ONLY${NC}"

            # Threads
            read -p "$(echo -e ${WHITE}"Threads কতটা? (Enter = 50): "${NC})" th_in
            [ -n "$th_in" ] && THREADS_OPT="-t $th_in" || THREADS_OPT="-t 50"
            echo -e "  ${GREEN}[✓] Threads: ${th_in:-50}${NC}"

            # Show IPs
            read -p "$(echo -e ${WHITE}"Found subdomain এর IP ও দেখাবে? (y/n): "${NC})" ip_yn
            [[ "$ip_yn" =~ ^[Yy]$ ]] && EXT_OPT="-i" && \
                echo -e "  ${GREEN}[✓] IP show: ON${NC}"
            ;;

        # ── VHOST MODE ────────────────────────────────────────
        vhost)
            # Threads
            read -p "$(echo -e ${WHITE}"Threads কতটা? (Enter = 50): "${NC})" th_in
            [ -n "$th_in" ] && THREADS_OPT="-t $th_in" || THREADS_OPT="-t 50"
            echo -e "  ${GREEN}[✓] Threads: ${th_in:-50}${NC}"

            # Append domain
            read -p "$(echo -e ${WHITE}"Domain append করবেন? (e.g. .target.com) (Enter = skip): "${NC})" app_in
            [ -n "$app_in" ] && EXT_OPT="--append-domain" && \
                echo -e "  ${GREEN}[✓] Append domain: ON${NC}"
            ;;

        # ── FUZZ MODE ─────────────────────────────────────────
        fuzz)
            echo -e "  ${WHITE}FUZZ mode এ URL এর যেখানে wordlist দিয়ে test করবেন${NC}"
            echo -e "  ${WHITE}সেখানে ${YELLOW}FUZZ${WHITE} keyword লিখুন।${NC}"
            echo -e "  ${DIM}e.g: https://target.com/FUZZ${NC}"
            echo -e "  ${DIM}e.g: https://target.com/page?id=FUZZ${NC}"
            echo ""
            read -p "$(echo -e ${WHITE}"FUZZ URL দিন: "${NC})" FUZZ_URL
            echo -e "  ${GREEN}[✓] FUZZ URL: $FUZZ_URL${NC}"

            # Threads
            read -p "$(echo -e ${WHITE}"Threads কতটা? (Enter = 50): "${NC})" th_in
            [ -n "$th_in" ] && THREADS_OPT="-t $th_in" || THREADS_OPT="-t 50"
            echo -e "  ${GREEN}[✓] Threads: ${th_in:-50}${NC}"

            # Status filter
            read -p "$(echo -e ${WHITE}"Hide করবেন কোন status? (e.g. 404) (Enter = skip): "${NC})" hide_in
            [ -n "$hide_in" ] && STATUS_OPT="--exclude-length 0 -b $hide_in" && \
                echo -e "  ${GREEN}[✓] Hide status: $hide_in${NC}"
            ;;

        # ── S3 MODE ───────────────────────────────────────────
        s3)
            echo -e "  ${WHITE}S3 mode এ AWS bucket name wordlist দিয়ে খোঁজে।${NC}"
            echo -e "  ${DIM}কোনো URL লাগবে না — শুধু wordlist এবং threads।${NC}"
            echo ""
            read -p "$(echo -e ${WHITE}"Threads কতটা? (Enter = 10 — S3 rate limit আছে): "${NC})" th_in
            [ -n "$th_in" ] && THREADS_OPT="-t $th_in" || THREADS_OPT="-t 10"
            echo -e "  ${GREEN}[✓] Threads: ${th_in:-10}${NC}"
            ;;
    esac
    echo ""
}

# ================================================================
# STEP 4 — EXTRA OPTIONS
# ================================================================
get_extra_options() {
    PROXY_OPT=""
    AUTH_OPT=""
    AGENT_OPT=""
    COOKIE_OPT=""
    TIMEOUT_OPT=""
    INSECURE_OPT=""

    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║      STEP 4 — EXTRA OPTIONS (সব optional, Enter = skip)            ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Proxy
    read -p "$(echo -e ${WHITE}"Proxy ব্যবহার করবেন? (y/n): "${NC})" proxy_yn
    if [[ "$proxy_yn" =~ ^[Yy]$ ]]; then
        read -p "$(echo -e ${WHITE}"  Proxy (e.g. http://127.0.0.1:8080): "${NC})" proxy_in
        PROXY_OPT="-p $proxy_in"
        echo -e "  ${GREEN}[✓] Proxy: $proxy_in${NC}"
    fi

    # Auth
    read -p "$(echo -e ${WHITE}"HTTP Basic Auth লাগবে? (y/n): "${NC})" auth_yn
    if [[ "$auth_yn" =~ ^[Yy]$ ]]; then
        read -p "$(echo -e ${WHITE}"  Username: "${NC})" auth_user
        read -s -p "$(echo -e ${WHITE}"  Password: "${NC})" auth_pass
        echo ""
        AUTH_OPT="-U $auth_user -P $auth_pass"
        echo -e "  ${GREEN}[✓] Auth set।${NC}"
    fi

    # Cookie
    read -p "$(echo -e ${WHITE}"Cookie দেবেন? (Enter = skip): "${NC})" cookie_in
    if [ -n "$cookie_in" ]; then
        COOKIE_OPT="-c \"$cookie_in\""
        echo -e "  ${GREEN}[✓] Cookie set।${NC}"
    fi

    # User-Agent
    echo ""
    echo -e "  ${CYAN}User-Agent:${NC}"
    echo -e "  ${GREEN}1)${NC} Default (gobuster)"
    echo -e "  ${GREEN}2)${NC} Chrome Browser"
    echo -e "  ${GREEN}3)${NC} Googlebot"
    echo -e "  ${GREEN}4)${NC} Custom"
    read -p "$(echo -e ${YELLOW}"  Select [1-4, Enter=1]: "${NC})" ua_ch
    case $ua_ch in
        2) AGENT_OPT="-a \"Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0\"" ;;
        3) AGENT_OPT="-a \"Googlebot/2.1 (+http://www.google.com/bot.html)\"" ;;
        4)
            read -p "$(echo -e ${WHITE}"  Custom User-Agent: "${NC})" ua_in
            AGENT_OPT="-a \"$ua_in\""
            ;;
        *) ;;
    esac
    [ -n "$AGENT_OPT" ] && echo -e "  ${GREEN}[✓] User-Agent set।${NC}"

    # Timeout
    read -p "$(echo -e ${WHITE}"Timeout (seconds)? (Enter = 10): "${NC})" to_in
    [ -n "$to_in" ] && TIMEOUT_OPT="--timeout ${to_in}s" || TIMEOUT_OPT="--timeout 10s"
    echo -e "  ${GREEN}[✓] Timeout: ${to_in:-10}s${NC}"

    # SSL verify
    read -p "$(echo -e ${WHITE}"SSL certificate verify skip করবেন? self-signed cert হলে দরকার (y/n): "${NC})" ssl_yn
    [[ "$ssl_yn" =~ ^[Yy]$ ]] && INSECURE_OPT="-k" && \
        echo -e "  ${GREEN}[✓] SSL verify: OFF${NC}"

    echo ""
}

# ================================================================
# STEP 5 — BUILD COMMAND & RUN
# ================================================================
build_and_run() {
    local target=$1
    local mode=$2
    local final_cmd=""

    case $mode in
        dir)
            final_cmd="gobuster dir -u $target -w $WORDLIST $EXT_OPT $STATUS_OPT $RECURSIVE_OPT $THREADS_OPT $PROXY_OPT $AUTH_OPT $COOKIE_OPT $AGENT_OPT $TIMEOUT_OPT $INSECURE_OPT"
            ;;
        dns)
            final_cmd="gobuster dns -d $DOMAIN_ONLY -w $WORDLIST $EXT_OPT $THREADS_OPT $TIMEOUT_OPT"
            ;;
        vhost)
            final_cmd="gobuster vhost -u $target -w $WORDLIST $EXT_OPT $THREADS_OPT $PROXY_OPT $AGENT_OPT $INSECURE_OPT $TIMEOUT_OPT"
            ;;
        fuzz)
            final_cmd="gobuster fuzz -u $FUZZ_URL -w $WORDLIST $STATUS_OPT $THREADS_OPT $PROXY_OPT $AGENT_OPT $TIMEOUT_OPT"
            ;;
        s3)
            final_cmd="gobuster s3 -w $WORDLIST $THREADS_OPT $TIMEOUT_OPT"
            ;;
    esac

    # Clean multiple spaces
    final_cmd=$(echo "$final_cmd" | tr -s ' ')

    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║      STEP 5 — CONFIRM & RUN                                         ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${WHITE}Mode    : ${CYAN}${BOLD}$mode${NC}"
    echo -e "  ${WHITE}Target  : ${GREEN}${BOLD}$target${NC}"
    echo -e "  ${WHITE}Command : ${YELLOW}$final_cmd${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Scan শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local tmp_scan tmp_bangla
    tmp_scan=$(mktemp)
    tmp_bangla=$(mktemp)

    echo ""
    echo -e "${GREEN}${BOLD}[*] Gobuster scan শুরু হচ্ছে...${NC}"
    echo ""

    # Real Gobuster — হুবহু original terminal output
    eval "$final_cmd" 2>&1 | tee "$tmp_scan"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Scan সম্পন্ন!${NC}"

    bangla_analysis   "$tmp_scan" "$tmp_bangla" "$mode"
    suggest_next_tool "$tmp_scan" "$mode"
    save_results      "$target" "$tmp_scan" "$tmp_bangla" "$mode"

    rm -f "$tmp_scan" "$tmp_bangla"
}

# ================================================================
# BANGLA ANALYSIS
# ================================================================
bangla_analysis() {
    local outfile=$1
    local report_file=$2
    local mode=$3

    {
    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় স্ক্যান রিপোর্ট বিশ্লেষণ                      ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local critical=0 high=0 medium=0 info=0

    case $mode in

        dir)
            # Admin panels
            if grep -qi "/admin\|/administrator\|/wp-admin\|/phpmyadmin\|/cpanel\|/manager\|/dashboard\|/portal" "$outfile" 2>/dev/null; then
                critical=$((critical+1))
                echo -e "  ${RED}${BOLD}🚨 Admin Panel / Sensitive Path পাওয়া গেছে!${NC}"
                grep -i "/admin\|/wp-admin\|/phpmyadmin\|/cpanel\|/dashboard" "$outfile" | head -5 | while read -r line; do
                    echo -e "     ${YELLOW}→ $line${NC}"
                done
                echo -e "     ${WHITE}→ Admin interface সরাসরি accessible — Brute force এর ঝুঁকি।${NC}"
                echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
            fi

            # Backup/Config files
            if grep -qi "\.bak\|\.old\|\.orig\|\.sql\|\.zip\|\.tar\|\.gz\|backup\|config\.php\|\.env\|\.git\|\.htpasswd" "$outfile" 2>/dev/null; then
                critical=$((critical+1))
                echo -e "  ${RED}${BOLD}🚨 Backup / Config / Sensitive File পাওয়া গেছে!${NC}"
                grep -i "\.bak\|\.sql\|\.zip\|\.env\|\.git\|\.htpasswd\|config" "$outfile" | head -5 | while read -r line; do
                    echo -e "     ${YELLOW}→ $line${NC}"
                done
                echo -e "     ${WHITE}→ এই files এ password, database dump বা source code থাকতে পারে।${NC}"
                echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
            fi

            # Upload directories
            if grep -qi "/upload\|/uploads\|/files\|/media" "$outfile" 2>/dev/null; then
                high=$((high+1))
                echo -e "  ${YELLOW}${BOLD}⚠ Upload Directory পাওয়া গেছে!${NC}"
                echo -e "     ${WHITE}→ File upload vulnerability থাকলে shell upload সম্ভব।${NC}"
                echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
            fi

            # API endpoints
            if grep -qi "/api\|/rest\|/v1\|/v2\|/graphql\|/swagger" "$outfile" 2>/dev/null; then
                high=$((high+1))
                echo -e "  ${YELLOW}${BOLD}⚠ API Endpoint পাওয়া গেছে!${NC}"
                echo -e "     ${WHITE}→ Unauthenticated API access বা data leak সম্ভব।${NC}"
                echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
            fi

            # Log/debug files
            if grep -qi "\.log\|/logs\|debug\|error\.log\|access\.log" "$outfile" 2>/dev/null; then
                high=$((high+1))
                echo -e "  ${YELLOW}${BOLD}⚠ Log / Debug File পাওয়া গেছে!${NC}"
                echo -e "     ${WHITE}→ Server logs publicly accessible — sensitive data leak।${NC}"
                echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
            fi

            # Info files
            if grep -qi "/readme\|/info\|/changelog\|/license\|/robots\.txt\|/sitemap" "$outfile" 2>/dev/null; then
                medium=$((medium+1))
                echo -e "  ${CYAN}${BOLD}ℹ Information Files পাওয়া গেছে!${NC}"
                echo -e "     ${WHITE}→ CMS version বা structure leak হতে পারে।${NC}"
                echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
            fi

            # Count found paths
            local found_count
            found_count=$(grep -c "Status: 200\|Status: 301\|Status: 302\|Status: 403" "$outfile" 2>/dev/null || echo "0")
            info=$((info+1))
            echo -e "  ${WHITE}${BOLD}📌 মোট Found Paths: $found_count${NC}"
            echo -e "     ${WHITE}→ Status 200: সরাসরি accessible${NC}"
            echo -e "     ${WHITE}→ Status 301/302: Redirect — follow করে দেখুন${NC}"
            echo -e "     ${WHITE}→ Status 403: Forbidden — কিন্তু exist করে, bypass চেষ্টা করুন${NC}"
            echo -e "     ${GREEN}→ ঝুঁকি: INFO${NC}"; echo ""
            ;;

        dns)
            local sub_count
            sub_count=$(grep -c "Found:" "$outfile" 2>/dev/null || echo "0")
            echo -e "  ${WHITE}${BOLD}📌 মোট Subdomain Found: $sub_count${NC}"; echo ""

            if grep -qi "dev\.\|staging\.\|test\.\|beta\.\|old\.\|internal\." "$outfile" 2>/dev/null; then
                high=$((high+1))
                echo -e "  ${YELLOW}${BOLD}⚠ Dev/Staging/Internal Subdomain পাওয়া গেছে!${NC}"
                grep -i "dev\.\|staging\.\|test\.\|beta\." "$outfile" | head -5 | while read -r line; do
                    echo -e "     ${YELLOW}→ $line${NC}"
                done
                echo -e "     ${WHITE}→ Development server এ নিরাপত্তা কম থাকে।${NC}"
                echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
            fi

            if grep -qi "admin\.\|mail\.\|vpn\.\|ftp\.\|ssh\.\|remote\." "$outfile" 2>/dev/null; then
                high=$((high+1))
                echo -e "  ${YELLOW}${BOLD}⚠ Sensitive Service Subdomain পাওয়া গেছে!${NC}"
                echo -e "     ${WHITE}→ Mail, VPN, FTP, Admin subdomain — targeted attack সম্ভব।${NC}"
                echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
            fi

            if [ "$sub_count" -gt 0 ]; then
                info=$((info+1))
                echo -e "  ${WHITE}${BOLD}📌 Attack Surface বেড়েছে${NC}"
                echo -e "     ${WHITE}→ প্রতিটি subdomain আলাদাভাবে scan করা উচিত।${NC}"
                echo -e "     ${GREEN}→ ঝুঁকি: INFO${NC}"; echo ""
            fi
            ;;

        vhost)
            local vhost_count
            vhost_count=$(grep -c "Found:" "$outfile" 2>/dev/null || echo "0")
            echo -e "  ${WHITE}${BOLD}📌 মোট Virtual Host Found: $vhost_count${NC}"; echo ""

            if [ "$vhost_count" -gt 0 ]; then
                high=$((high+1))
                echo -e "  ${YELLOW}${BOLD}⚠ Hidden Virtual Host পাওয়া গেছে!${NC}"
                echo -e "     ${WHITE}→ Same IP এ লুকানো website বা admin interface থাকতে পারে।${NC}"
                echo -e "     ${WHITE}→ প্রতিটি vhost আলাদাভাবে scan করুন।${NC}"
                echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
            fi
            ;;

        fuzz)
            local fuzz_count
            fuzz_count=$(grep -c "Status" "$outfile" 2>/dev/null || echo "0")
            echo -e "  ${WHITE}${BOLD}📌 মোট Valid Response: $fuzz_count${NC}"; echo ""

            if grep -qi "200\|301\|302" "$outfile" 2>/dev/null; then
                high=$((high+1))
                echo -e "  ${YELLOW}${BOLD}⚠ Valid Endpoint / Parameter পাওয়া গেছে!${NC}"
                echo -e "     ${WHITE}→ এই endpoints এ further injection test করুন।${NC}"
                echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
            fi
            ;;

        s3)
            if grep -qi "Found\|Open\|Lists" "$outfile" 2>/dev/null; then
                critical=$((critical+1))
                echo -e "  ${RED}${BOLD}🚨 Exposed AWS S3 Bucket পাওয়া গেছে!${NC}"
                echo -e "     ${WHITE}→ Public S3 bucket এ sensitive data থাকতে পারে।${NC}"
                echo -e "     ${WHITE}→ সরাসরি download করা সম্ভব হতে পারে।${NC}"
                echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
            fi
            ;;
    esac

    # Summary
    echo -e "  ${CYAN}${BOLD}━━━ সামগ্রিক ঝুঁকি মূল্যায়ন ━━━${NC}"
    echo -e "  ${RED}   Critical : $critical টি${NC}"
    echo -e "  ${YELLOW}   High     : $high টি${NC}"
    echo -e "  ${CYAN}   Medium   : $medium টি${NC}"
    echo -e "  ${WHITE}   Info/Low : $info টি${NC}"
    echo ""
    if   [ "$critical" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}  সার্বিক ঝুঁকি : ██████████ CRITICAL — এখনই পদক্ষেপ নিন!${NC}"
    elif [ "$high" -gt 0 ]; then
        echo -e "  ${YELLOW}${BOLD}  সার্বিক ঝুঁকি : ███████░░░ HIGH — দ্রুত মনোযোগ দেওয়া দরকার।${NC}"
    elif [ "$medium" -gt 0 ]; then
        echo -e "  ${CYAN}  সার্বিক ঝুঁকি : █████░░░░░ MEDIUM — কিছু জিনিস ঠিক করা দরকার।${NC}"
    else
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW — স্পষ্ট সমস্যা নেই।${NC}"
    fi
    echo ""
    } | tee "$report_file"
}

# ================================================================
# NEXT TOOL SUGGESTION
# ================================================================
suggest_next_tool() {
    local outfile=$1
    local mode=$2

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Scan এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    case $mode in
        dir)
            if grep -qi "/admin\|/login\|/wp-admin\|/phpmyadmin" "$outfile" 2>/dev/null; then
                echo -e "  ${RED}${BOLD}🔑 Hydra${NC} — Login Brute Force"
                echo -e "     ${WHITE}কারণ: Admin/Login page পাওয়া গেছে।${NC}"
                echo -e "     ${CYAN}কমান্ড: hydra -l admin -P /usr/share/wordlists/rockyou.txt http-post-form \"/login:u=^USER^&p=^PASS^:F=incorrect\"${NC}"; echo ""
            fi

            if grep -qi "\.php\|\.asp" "$outfile" 2>/dev/null; then
                echo -e "  ${GREEN}${BOLD}💉 SQLmap${NC} — SQL Injection Test"
                echo -e "     ${WHITE}কারণ: PHP/ASP page পাওয়া গেছে — parameter injection test করুন।${NC}"
                echo -e "     ${CYAN}কমান্ড: sqlmap -u \"http://target.com/page.php?id=1\" --dbs${NC}"; echo ""
            fi

            echo -e "  ${YELLOW}${BOLD}🌐 Nikto${NC} — Web Vulnerability Scan"
            echo -e "     ${WHITE}কারণ: পাওয়া paths এ deep vulnerability scan করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: nikto -h http://target.com${NC}"; echo ""

            echo -e "  ${WHITE}${BOLD}🌐 Burp Suite${NC} — Manual Inspection"
            echo -e "     ${WHITE}কারণ: পাওয়া directories manually inspect করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: burpsuite (GUI)${NC}"; echo ""
            ;;

        dns)
            echo -e "  ${GREEN}${BOLD}🔍 Gobuster (dir mode)${NC} — প্রতিটি Subdomain এ Directory Scan"
            echo -e "     ${WHITE}কারণ: পাওয়া subdomain গুলো আলাদাভাবে scan করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: gobuster dir -u http://subdomain.target.com -w wordlist.txt${NC}"; echo ""

            echo -e "  ${MAGENTA}${BOLD}🌍 Amass / Subfinder${NC} — Deep Subdomain Enumeration"
            echo -e "     ${WHITE}কারণ: আরো subdomain খুঁজে বের করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: amass enum -d target.com${NC}"; echo ""

            echo -e "  ${YELLOW}${BOLD}🔎 Nmap${NC} — Subdomain Port Scan"
            echo -e "     ${WHITE}কারণ: পাওয়া subdomain এ কোন port খোলা আছে দেখুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: nmap -sV -p- subdomain.target.com${NC}"; echo ""
            ;;

        vhost)
            echo -e "  ${GREEN}${BOLD}🔍 Gobuster (dir mode)${NC} — প্রতিটি Vhost এ Directory Scan"
            echo -e "     ${WHITE}কারণ: পাওয়া vhost এ আলাদাভাবে scan করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: gobuster dir -u http://vhost.target.com -w wordlist.txt${NC}"; echo ""

            echo -e "  ${YELLOW}${BOLD}🌐 Nikto${NC} — Web Vulnerability Scan on Vhosts"
            echo -e "     ${WHITE}কারণ: প্রতিটি vhost এ Nikto scan করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: nikto -h http://vhost.target.com${NC}"; echo ""
            ;;

        fuzz)
            echo -e "  ${RED}${BOLD}💉 SQLmap${NC} — Injection Test on Found Parameters"
            echo -e "     ${WHITE}কারণ: Valid parameter পাওয়া গেছে — injection test করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: sqlmap -u \"http://target.com/page?param=1\" --dbs${NC}"; echo ""

            echo -e "  ${YELLOW}${BOLD}🌐 Burp Suite${NC} — Parameter Manipulation"
            echo -e "     ${WHITE}কারণ: Found endpoints manually test করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: burpsuite (Intruder/Repeater)${NC}"; echo ""
            ;;

        s3)
            echo -e "  ${RED}${BOLD}☁ AWS CLI${NC} — S3 Bucket Content List"
            echo -e "     ${WHITE}কারণ: Exposed bucket পাওয়া গেছে — contents দেখুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: aws s3 ls s3://bucket-name --no-sign-request${NC}"; echo ""

            echo -e "  ${YELLOW}${BOLD}🔧 S3Scanner${NC} — Deeper S3 Analysis"
            echo -e "     ${WHITE}কারণ: Bucket permission ও content আরো ভালোভাবে check করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: s3scanner scan --bucket bucket-name${NC}"; echo ""
            ;;
    esac
}

# ================================================================
# SAVE RESULTS
# ================================================================
save_results() {
    local target=$1
    local scan_out=$2
    local bangla_out=$3
    local mode=$4

    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Result save করবেন? (y/n): "${NC})" sc
    if [[ "$sc" =~ ^[Yy]$ ]]; then
        local ts safe fname
        ts=$(date +"%Y%m%d_%H%M%S")
        safe=$(echo "$target" | sed 's|[^a-zA-Z0-9._-]|_|g')
        fname="$RESULTS_DIR/gobuster_${mode}_${safe}_${ts}.txt"
        {
            echo "============================================================"
            echo "  GOBUSTER SCAN RESULTS  —  SAIMUM's Automation Tool"
            echo "  Mode   : $mode"
            echo "  Target : $target"
            echo "  Date   : $(date)"
            echo "============================================================"
            echo ""
            echo "=== GOBUSTER RAW OUTPUT ==="
            cat "$scan_out"
            echo ""
            echo "=== BANGLA ANALYSIS ==="
            sed 's/\x1b\[[0-9;]*m//g' "$bangla_out"
        } > "$fname"
        echo -e "${GREEN}[✓] Saved → $fname${NC}"
        echo "$(date) | $mode | $target | $fname" >> "$HISTORY_FILE"
    fi
}

# ================================================================
# MAIN LOOP
# ================================================================
main() {
    show_banner
    check_deps

    while true; do

        # Step 1 — Target
        get_target

        # Step 2 — Mode
        get_mode

        # Pre-scan recon (mode জেনে HTTP header check decide করে)
        pre_scan_recon "$TARGET" "$MODE"

        # Wordlist pick
        pick_wordlist "$MODE"

        # Step 3 — Mode specific config
        get_mode_config "$MODE"

        # Step 4 — Extra options
        get_extra_options

        # Step 5 — Build & Run
        build_and_run "$TARGET" "$MODE"

        echo ""
        read -p "$(echo -e ${YELLOW}"[?] আরেকটি scan করবেন? (y/n): "${NC})" again
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
