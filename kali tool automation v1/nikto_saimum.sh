#!/bin/bash

# ================================================================
#   NIKTO - Full Automation Tool
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

RESULTS_DIR="$HOME/nikto_results"
HISTORY_FILE="$HOME/.nikto_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${RED}${BOLD}"
    echo ' ███╗   ██╗██╗██╗  ██╗████████╗ ██████╗ '
    echo ' ████╗  ██║██║██║ ██╔╝╚══██╔══╝██╔═══██╗'
    echo ' ██╔██╗ ██║██║█████╔╝    ██║   ██║   ██║'
    echo ' ██║╚██╗██║██║██╔═██╗    ██║   ██║   ██║'
    echo ' ██║ ╚████║██║██║  ██╗   ██║   ╚██████╔╝'
    echo ' ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ '
    echo -e "${NC}"
    echo -e "${WHITE}${BOLD}"
    echo '  ██╗    ██╗███████╗██████╗ '
    echo '  ██║    ██║██╔════╝██╔══██╗'
    echo '  ██║ █╗ ██║█████╗  ██████╔╝'
    echo '  ██║███╗██║██╔══╝  ██╔══██╗'
    echo '  ╚███╔███╔╝███████╗██████╔╝'
    echo '   ╚══╝╚══╝ ╚══════╝╚═════╝ '
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}        Nikto Full Automation Tool | Web Vulnerability Scanner${NC}"
    echo ""
}

# ================================================================
# CHECK DEPENDENCIES
# ================================================================
check_deps() {
    echo -e "${CYAN}[*] Dependencies চেক করা হচ্ছে...${NC}"
    local missing=()
    for tool in nikto whois curl dig host; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
            echo -e "  ${RED}[✗] $tool — পাওয়া যায়নি${NC}"
        else
            echo -e "  ${GREEN}[✓] $tool${NC}"
        fi
    done
    if [ ${#missing[@]} -ne 0 ]; then
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
    ip=$(dig +short "$domain" 2>/dev/null | head -1)
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
        echo -e "  ${RED}[!] Target unreachable বা HTTP response নেই।${NC}"
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
# STEP 1 — GET TARGETS
# ================================================================
get_targets() {
    TARGETS=()
    echo -e "${RED}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║      STEP 1 — TARGET SELECT          ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo -e "  ${GREEN}1)${NC} Single URL / Domain"
    echo -e "  ${GREEN}2)${NC} Multiple URLs (একটা একটা করে)"
    echo -e "  ${GREEN}3)${NC} File থেকে URL list"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-3]: "${NC})" ttype

    case $ttype in
        1)
            read -p "$(echo -e ${WHITE}"URL দিন (e.g. https://target.com): "${NC})" t
            TARGETS=("$t")
            ;;
        2)
            echo -e "${WHITE}একটা একটা করে দিন। শেষ হলে 'done' লিখুন:${NC}"
            while true; do
                read -p "$(echo -e ${WHITE}"Target: "${NC})" t
                [[ "$t" == "done" || -z "$t" ]] && break
                TARGETS+=("$t")
            done
            ;;
        3)
            read -p "$(echo -e ${WHITE}"File path দিন (e.g. /home/kali/urls.txt): "${NC})" fpath
            if [ ! -f "$fpath" ]; then
                echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
                get_targets; return
            fi
            while IFS= read -r line; do
                [[ -z "$line" || "$line" == \#* ]] && continue
                TARGETS+=("$line")
            done < "$fpath"
            echo -e "${GREEN}[✓] ${#TARGETS[@]} টি target লোড হয়েছে।${NC}"
            ;;
        *)
            echo -e "${RED}[!] ভুল অপশন।${NC}"
            get_targets; return
            ;;
    esac

    if [ ${#TARGETS[@]} -eq 0 ]; then
        echo -e "${RED}[!] কোনো target দেওয়া হয়নি!${NC}"
        get_targets
    fi
}

# ================================================================
# STEP 2 — BASIC CONFIG
# ================================================================
get_basic_config() {
    local target=$1
    PROTO_OPT=""
    PORT_OPT=""

    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║      STEP 2 — BASIC CONFIG           ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════╝${NC}"

    # Auto detect protocol
    if echo "$target" | grep -qi "^https://"; then
        echo -e "  ${GREEN}[✓] HTTPS detect হয়েছে — SSL scan চালু থাকবে।${NC}"
        PROTO_OPT="-ssl"
    elif echo "$target" | grep -qi "^http://"; then
        echo -e "  ${GREEN}[✓] HTTP detect হয়েছে।${NC}"
    else
        read -p "$(echo -e ${WHITE}"  Protocol কোনটা? (1=HTTP / 2=HTTPS): "${NC})" proto
        [[ "$proto" == "2" ]] && PROTO_OPT="-ssl"
    fi

    read -p "$(echo -e ${WHITE}"Custom port? (Enter = default 80/443): "${NC})" port_in
    [ -n "$port_in" ] && PORT_OPT="-p $port_in" && \
        echo -e "  ${GREEN}[✓] Port: $port_in${NC}"
    echo ""
}

# ================================================================
# STEP 3 — TUNING
# ================================================================
get_tuning() {
    TUNING_OPT=""

    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║   STEP 3 — কী কী চেক করবে? (একাধিক select করতে পারবেন)           ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Interesting Files ও Backup Files"
    echo -e "  ${GREEN}2)${NC} Misconfiguration (ভুল server config)"
    echo -e "  ${GREEN}3)${NC} Information Disclosure (server info leak)"
    echo -e "  ${GREEN}4)${NC} XSS ও Injection"
    echo -e "  ${GREEN}5)${NC} Remote File Retrieval"
    echo -e "  ${GREEN}6)${NC} Command Execution"
    echo -e "  ${GREEN}7)${NC} SQL Injection"
    echo -e "  ${GREEN}8)${NC} File Upload Vulnerability"
    echo -e "  ${GREEN}9)${NC} Authentication Bypass"
    echo -e "  ${GREEN}x)${NC} ${YELLOW}সব একসাথে (Recommended)${NC}"
    echo ""
    echo -e "  ${DIM}একাধিক চাইলে space দিয়ে লিখুন — e.g: 1 3 4 বা শুধু x${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select: "${NC})" tuning_raw

    local tuning_str=""
    if echo "$tuning_raw" | grep -qi "x"; then
        tuning_str="x"
    else
        for ch in $tuning_raw; do
            [[ "$ch" =~ ^[1-9]$ ]] && tuning_str="${tuning_str}${ch}"
        done
    fi

    [ -n "$tuning_str" ] && TUNING_OPT="-Tuning $tuning_str"
    echo -e "  ${GREEN}[✓] Tuning set: ${tuning_str:-default (সব)}${NC}"
    echo ""
}

# ================================================================
# STEP 4 — EXTRA OPTIONS
# ================================================================
get_extra_options() {
    COOKIE_OPT=""
    AUTH_OPT=""
    PROXY_OPT=""
    EVASION_OPT=""

    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║      STEP 4 — EXTRA OPTIONS (সব optional, Enter দিলে skip)         ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Cookie
    read -p "$(echo -e ${WHITE}"Cookie আছে? (Enter = skip): "${NC})" cookie_in
    if [ -n "$cookie_in" ]; then
        COOKIE_OPT="-cookies \"$cookie_in\""
        echo -e "  ${GREEN}[✓] Cookie set।${NC}"
    fi

    # Auth
    read -p "$(echo -e ${WHITE}"Login/Auth দরকার? (y/n): "${NC})" auth_yn
    if [[ "$auth_yn" =~ ^[Yy]$ ]]; then
        read -p "$(echo -e ${WHITE}"  Username: "${NC})" auth_user
        read -s -p "$(echo -e ${WHITE}"  Password: "${NC})" auth_pass
        echo ""
        AUTH_OPT="-id \"$auth_user:$auth_pass\""
        echo -e "  ${GREEN}[✓] Authentication set।${NC}"
    fi

    # Proxy
    read -p "$(echo -e ${WHITE}"Proxy ব্যবহার করবেন? (y/n): "${NC})" proxy_yn
    if [[ "$proxy_yn" =~ ^[Yy]$ ]]; then
        read -p "$(echo -e ${WHITE}"  Proxy (e.g. http://127.0.0.1:8080): "${NC})" proxy_in
        PROXY_OPT="-useproxy -proxy \"$proxy_in\""
        echo -e "  ${GREEN}[✓] Proxy set: $proxy_in${NC}"
    fi

    # Evasion
    read -p "$(echo -e ${WHITE}"IDS/Firewall Evasion চালু করবেন? (y/n): "${NC})" ev_yn
    if [[ "$ev_yn" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "  ${CYAN}Evasion Type:${NC}"
        echo -e "    ${GREEN}1)${NC} Random URI encoding"
        echo -e "    ${GREEN}2)${NC} Directory self-reference (/./) insertion"
        echo -e "    ${GREEN}3)${NC} Premature URL ending"
        echo -e "    ${GREEN}4)${NC} Long random string prepend"
        echo -e "    ${GREEN}5)${NC} Fake URL parameter"
        echo -e "    ${GREEN}6)${NC} TAB as request spacer"
        echo -e "    ${GREEN}7)${NC} Change the case of the URL"
        echo -e "    ${GREEN}8)${NC} Use Windows directory separator (\\)"
        read -p "$(echo -e ${YELLOW}"  Select [1-8]: "${NC})" ev_type
        EVASION_OPT="-evasion $ev_type"
        echo -e "  ${GREEN}[✓] Evasion type $ev_type set।${NC}"
    fi
    echo ""
}

# ================================================================
# STEP 5 — BUILD COMMAND & RUN
# ================================================================
build_and_run() {
    local target=$1

    local final_cmd
    final_cmd=$(echo "nikto -h $target $PROTO_OPT $PORT_OPT $TUNING_OPT $COOKIE_OPT $AUTH_OPT $PROXY_OPT $EVASION_OPT" | tr -s ' ')

    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║      STEP 5 — CONFIRM & RUN                                         ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${WHITE}Target  : ${GREEN}${BOLD}$target${NC}"
    echo -e "  ${WHITE}Command : ${CYAN}$final_cmd${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Scan শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local tmp_scan tmp_bangla
    tmp_scan=$(mktemp)
    tmp_bangla=$(mktemp)

    echo ""
    echo -e "${GREEN}${BOLD}[*] Nikto scan শুরু হচ্ছে... (কিছুটা সময় নিতে পারে)${NC}"
    echo ""

    # Real Nikto — হুবহু original terminal output
    eval "$final_cmd" 2>&1 | tee "$tmp_scan"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Scan সম্পন্ন!${NC}"

    bangla_analysis   "$tmp_scan" "$tmp_bangla"
    suggest_next_tool "$tmp_scan"
    save_results      "$target" "$tmp_scan" "$tmp_bangla"

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

    if grep -qi "xss\|cross.site.scripting" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 XSS (Cross-Site Scripting) পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ ব্যবহারকারীর browser এ malicious script চালানো সম্ভব।${NC}"
        echo -e "     ${WHITE}→ Session hijack, cookie চুরি করা যেতে পারে।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    if grep -qi "sql\|injection\|database error\|syntax error" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 SQL Injection এর চিহ্ন পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ Database থেকে সব data চুরি করা সম্ভব।${NC}"
        echo -e "     ${WHITE}→ Admin account bypass করা যেতে পারে।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    if grep -qi "outdated\|obsolete\|old version\|end.of.life\|deprecated" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ Outdated Software পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ পুরনো software এ known vulnerability থাকতে পারে।${NC}"
        echo -e "     ${WHITE}→ এখনই update করা উচিত।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    if grep -qi "backup\|\.bak\|\.old\|\.orig\|default\|sample\|test file" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ Backup / Default File পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ Publicly accessible backup বা config file পাওয়া গেছে।${NC}"
        echo -e "     ${WHITE}→ এগুলোতে password বা sensitive data থাকতে পারে।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    if grep -qi "directory.index\|directory.listing\|index of /" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ Directory Listing চালু আছে!${NC}"
        echo -e "     ${WHITE}→ Server এর file structure সরাসরি দেখা যাচ্ছে।${NC}"
        echo -e "     ${WHITE}→ Sensitive files download করা সম্ভব।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    if grep -qi "ssl\|tls\|cipher\|heartbleed\|poodle" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ SSL/TLS সমস্যা পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ Weak cipher বা misconfigured SSL।${NC}"
        echo -e "     ${WHITE}→ Man-in-the-Middle attack এর ঝুঁকি।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    if grep -qi "admin\|administrator\|wp-admin\|phpmyadmin\|cpanel\|login" "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}ℹ Admin Panel / Login Page পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ Admin interface publicly accessible।${NC}"
        echo -e "     ${WHITE}→ Brute force attack এর ঝুঁকি।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    if grep -qi "phpinfo\|php.info\|php version" "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}ℹ PHP Information Disclosure!${NC}"
        echo -e "     ${WHITE}→ PHP version এবং server config leak হচ্ছে।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    if grep -qi "x-frame-options\|clickjack" "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}ℹ Clickjacking Vulnerability!${NC}"
        echo -e "     ${WHITE}→ X-Frame-Options header নেই।${NC}"
        echo -e "     ${WHITE}→ Site কে iframe এ embed করে attack সম্ভব।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    if grep -qi "cookie.*httponly\|cookie.*secure" "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}ℹ Cookie Security Issue!${NC}"
        echo -e "     ${WHITE}→ Cookie তে HttpOnly বা Secure flag নেই।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    if grep -qi "server.*header\|x-powered\|version.*disclosed" "$outfile" 2>/dev/null; then
        info=$((info+1))
        echo -e "  ${WHITE}${BOLD}📌 Server Information Disclosure${NC}"
        echo -e "     ${WHITE}→ Server software/version header এ দেখা যাচ্ছে।${NC}"
        echo -e "     ${GREEN}→ ঝুঁকি: LOW / INFO${NC}"; echo ""
    fi

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
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW — স্পষ্ট vulnerability নেই।${NC}"
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

    if grep -qi "sql\|injection\|database" "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}💉 SQLmap${NC} — SQL Injection Exploitation"
        echo -e "     ${WHITE}কারণ: SQL Injection এর চিহ্ন পাওয়া গেছে।${NC}"
        echo -e "     ${CYAN}কমান্ড: sqlmap -u \"http://target.com/page?id=1\" --dbs${NC}"; echo ""
    fi

    echo -e "  ${GREEN}${BOLD}🔍 Gobuster${NC} — Directory & File Brute Force"
    echo -e "     ${WHITE}কারণ: Hidden files ও directories খুঁজে বের করতে হবে।${NC}"
    echo -e "     ${CYAN}কমান্ড: gobuster dir -u http://target.com -w /usr/share/wordlists/dirb/common.txt${NC}"; echo ""

    if grep -qi "xss\|cross.site" "$outfile" 2>/dev/null; then
        echo -e "  ${YELLOW}${BOLD}🌐 Burp Suite${NC} — Manual XSS Exploitation"
        echo -e "     ${WHITE}কারণ: XSS vulnerability পাওয়া গেছে।${NC}"
        echo -e "     ${CYAN}কমান্ড: burpsuite (GUI দিয়ে intercept করুন)${NC}"; echo ""
    fi

    if grep -qi "wordpress\|wp-admin\|wp-content" "$outfile" 2>/dev/null; then
        echo -e "  ${MAGENTA}${BOLD}🔧 WPScan${NC} — WordPress Vulnerability Scanner"
        echo -e "     ${WHITE}কারণ: WordPress detect করা গেছে।${NC}"
        echo -e "     ${CYAN}কমান্ড: wpscan --url http://target.com --enumerate u,p,t${NC}"; echo ""
    fi

    if grep -qi "ssl\|tls\|cipher" "$outfile" 2>/dev/null; then
        echo -e "  ${BLUE}${BOLD}🔒 SSLScan${NC} — SSL/TLS Deep Check"
        echo -e "     ${WHITE}কারণ: SSL সংক্রান্ত সমস্যা পাওয়া গেছে।${NC}"
        echo -e "     ${CYAN}কমান্ড: sslscan target.com${NC}"; echo ""
    fi

    if grep -qi "admin\|login\|phpmyadmin" "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}🔑 Hydra${NC} — Login Brute Force"
        echo -e "     ${WHITE}কারণ: Admin panel বা login page পাওয়া গেছে।${NC}"
        echo -e "     ${CYAN}কমান্ড: hydra -l admin -P /usr/share/wordlists/rockyou.txt http-post-form \"/login:user=^USER^&pass=^PASS^:F=incorrect\"${NC}"; echo ""
    fi

    echo -e "  ${WHITE}${BOLD}📡 OWASP ZAP${NC} — Full Web App Deep Scan"
    echo -e "     ${WHITE}কারণ: Nikto এর পর ZAP দিয়ে active scan করুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: zaproxy (GUI) বা zap-cli -t http://target.com${NC}"; echo ""

    echo -e "  ${WHITE}${BOLD}🔗 FFUF${NC} — Parameter & Endpoint Fuzzing"
    echo -e "     ${WHITE}কারণ: Hidden parameters ও endpoints খুঁজে বের করুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: ffuf -u http://target.com/FUZZ -w /usr/share/wordlists/dirb/common.txt${NC}"; echo ""
}

# ================================================================
# SAVE RESULTS
# ================================================================
save_results() {
    local target=$1
    local scan_out=$2
    local bangla_out=$3

    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Result save করবেন? (y/n): "${NC})" sc
    if [[ "$sc" =~ ^[Yy]$ ]]; then
        local ts safe fname
        ts=$(date +"%Y%m%d_%H%M%S")
        safe=$(echo "$target" | sed 's|[^a-zA-Z0-9._-]|_|g')
        fname="$RESULTS_DIR/nikto_${safe}_${ts}.txt"
        {
            echo "============================================================"
            echo "  NIKTO SCAN RESULTS  —  SAIMUM's Web Vulnerability Tool"
            echo "  Target : $target"
            echo "  Date   : $(date)"
            echo "============================================================"
            echo ""
            echo "=== NIKTO RAW OUTPUT ==="
            cat "$scan_out"
            echo ""
            echo "=== BANGLA ANALYSIS ==="
            sed 's/\x1b\[[0-9;]*m//g' "$bangla_out"
        } > "$fname"
        echo -e "${GREEN}[✓] Saved → $fname${NC}"
        echo "$(date) | $target | $fname" >> "$HISTORY_FILE"
    fi
}

# ================================================================
# MAIN LOOP
# ================================================================
main() {
    show_banner
    check_deps

    while true; do

        get_targets

        for t in "${TARGETS[@]}"; do
            pre_scan_recon "$t"
        done

        get_basic_config "${TARGETS[0]}"
        get_tuning
        get_extra_options

        for t in "${TARGETS[@]}"; do
            echo ""
            echo -e "${RED}${BOLD}══════════════ Target: $t ══════════════${NC}"
            build_and_run "$t"
        done

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
