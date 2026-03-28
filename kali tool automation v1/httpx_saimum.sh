#!/bin/bash

# ================================================================
#   HTTPX - Full Automation Tool  v2.0
#   Author  : SAIMUM
#   Updated : All features unified
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

RESULTS_DIR="$HOME/httpx_results"
HISTORY_FILE="$HOME/.httpx_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo '  ██╗  ██╗████████╗████████╗██████╗ ██╗  ██╗'
    echo '  ██║  ██║╚══██╔══╝╚══██╔══╝██╔══██╗╚██╗██╔╝'
    echo '  ███████║   ██║      ██║   ██████╔╝ ╚███╔╝ '
    echo '  ██╔══██║   ██║      ██║   ██╔═══╝  ██╔██╗ '
    echo '  ██║  ██║   ██║      ██║   ██║     ██╔╝ ██╗'
    echo '  ╚═╝  ╚═╝   ╚═╝      ╚═╝   ╚═╝     ╚═╝  ╚═╝'
    echo -e "${NC}"
    echo -e "${WHITE}${BOLD}"
    echo '  ████████╗ ██████╗  ██████╗ ██╗      ██╗  ██╗██╗████████╗'
    echo '  ╚══██╔══╝██╔═══██╗██╔═══██╗██║      ██║ ██╔╝██║╚══██╔══╝'
    echo '     ██║   ██║   ██║██║   ██║██║      █████╔╝ ██║   ██║   '
    echo '     ██║   ██║   ██║██║   ██║██║      ██╔═██╗ ██║   ██║   '
    echo '     ██║   ╚██████╔╝╚██████╔╝███████╗ ██║  ██╗██║   ██║   '
    echo '     ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝ ╚═╝  ╚═╝╚═╝   ╚═╝   '
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}       Httpx Full Automation Tool | HTTP Probing & Recon${NC}"
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
    for tool in httpx curl whois dig host; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
            echo -e "  ${RED}[✗] $tool — পাওয়া যায়নি${NC}"
        else
            echo -e "  ${GREEN}[✓] $tool${NC}"
        fi
    done

    # Optional
    if command -v chromium &>/dev/null || command -v google-chrome &>/dev/null; then
        echo -e "  ${GREEN}[✓] chromium/chrome${NC} ${DIM}(screenshot available)${NC}"
    else
        echo -e "  ${YELLOW}[!] chromium${NC} — নেই ${DIM}(screenshot feature কাজ করবে না)${NC}"
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing tools: ${missing[*]}${NC}"
        echo -e "${YELLOW}Install করুন:${NC}"
        for m in "${missing[@]}"; do
            case "$m" in
                httpx) echo -e "  ${WHITE}sudo apt install httpx-toolkit${NC}"
                       echo -e "  ${DIM}  অথবা: go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest${NC}" ;;
                curl)  echo -e "  ${WHITE}sudo apt install curl${NC}" ;;
                whois) echo -e "  ${WHITE}sudo apt install whois${NC}" ;;
                dig)   echo -e "  ${WHITE}sudo apt install dnsutils${NC}" ;;
                host)  echo -e "  ${WHITE}sudo apt install bind9-host${NC}" ;;
            esac
        done
        exit 1
    fi

    local ver
    ver=$(httpx -version 2>&1 | head -1)
    echo -e "  ${DIM}Version: $ver${NC}"
    echo ""
}

# ================================================================
# GET TARGETS / INPUT MODE
# ================================================================
get_targets() {
    TARGETS=()
    INPUT_FILE=""
    INPUT_MODE=""

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║         INPUT MODE SELECT            ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo -e "  ${GREEN}1)${NC} Single Target  ${DIM}(একটা URL/domain)${NC}"
    echo -e "  ${GREEN}2)${NC} Multiple Targets ${DIM}(একটা একটা করে)${NC}"
    echo -e "  ${GREEN}3)${NC} Target List File ${DIM}(.txt file)${NC}"
    echo -e "  ${GREEN}4)${NC} FFUF / Subfinder / Amass Output File"
    echo -e "  ${GREEN}5)${NC} CIDR / IP Range  ${DIM}(যেমন: 192.168.1.0/24)${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-5]: "${NC})" ttype

    case $ttype in
        1)
            INPUT_MODE="single"
            read -p "$(echo -e ${WHITE}"URL বা domain দিন: "${NC})" t
            [[ ! "$t" =~ ^https?:// ]] && t="http://$t"
            TARGETS=("${t%/}")
            ;;
        2)
            INPUT_MODE="multi"
            echo -e "${WHITE}একটা একটা করে দিন। শেষ হলে 'done' লিখুন:${NC}"
            while true; do
                read -p "$(echo -e ${WHITE}"URL: "${NC})" t
                [[ "$t" == "done" || -z "$t" ]] && break
                [[ ! "$t" =~ ^https?:// ]] && t="http://$t"
                TARGETS+=("${t%/}")
            done
            ;;
        3|4)
            INPUT_MODE="file"
            local lbl="Target List"
            [ "$ttype" = "4" ] && lbl="FFUF/Subfinder Output"
            read -p "$(echo -e ${WHITE}"$lbl file path: "${NC})" INPUT_FILE
            if [ ! -f "$INPUT_FILE" ]; then
                echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
                get_targets; return
            fi
            local cnt
            cnt=$(wc -l < "$INPUT_FILE")
            echo -e "${GREEN}[✓] File: $INPUT_FILE ($cnt entries)${NC}"
            TARGETS=("FILE:$INPUT_FILE")
            ;;
        5)
            INPUT_MODE="cidr"
            read -p "$(echo -e ${WHITE}"CIDR range দিন (যেমন: 192.168.1.0/24): "${NC})" t
            TARGETS=("$t")
            ;;
        *)
            echo -e "${RED}[!] ভুল অপশন।${NC}"
            get_targets; return ;;
    esac

    if [ ${#TARGETS[@]} -eq 0 ]; then
        echo -e "${RED}[!] কোনো target দেওয়া হয়নি!${NC}"
        get_targets
    fi
}

# ================================================================
# WHOIS LOOKUP
# ================================================================
whois_lookup() {
    local domain=$1
    echo -e "${MAGENTA}${BOLD}┌─── WHOIS INFORMATION ─────────────────────────────┐${NC}"
    local result
    result=$(whois "$domain" 2>/dev/null | grep -E \
        "Registrar:|Registrant Name:|Country:|Creation Date:|Updated Date:|Expir|Name Server:|Organization:|Admin Email:" \
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
        local ip country region city isp lat lon
        ip=$(echo      "$geo" | grep -o '"query":"[^"]*"'      | cut -d'"' -f4)
        country=$(echo "$geo" | grep -o '"country":"[^"]*"'    | cut -d'"' -f4)
        region=$(echo  "$geo" | grep -o '"regionName":"[^"]*"' | cut -d'"' -f4)
        city=$(echo    "$geo" | grep -o '"city":"[^"]*"'       | cut -d'"' -f4)
        isp=$(echo     "$geo" | grep -o '"isp":"[^"]*"'        | cut -d'"' -f4)
        lat=$(echo     "$geo" | grep -o '"lat":[^,]*'          | cut -d':' -f2)
        lon=$(echo     "$geo" | grep -o '"lon":[^,]*'          | cut -d':' -f2)
        echo -e "  ${WHITE}IP Address:${NC} ${GREEN}$ip${NC}"
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
    local ip_count
    ip_count=$(dig +short "$domain" 2>/dev/null | grep -cE '^[0-9]+\.' || true)
    [ "$ip_count" -gt 1 ] && echo -e "  ${YELLOW}[!] Multiple IPs ($ip_count) — CDN/Load Balancer সম্ভব।${NC}"
    echo -e "${GREEN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# CONNECTIVITY PRE-CHECK  (Httpx specific)
# ================================================================
connectivity_precheck() {
    local target=$1
    echo -e "${CYAN}${BOLD}┌─── CONNECTIVITY PRE-CHECK ────────────────────────┐${NC}"

    if [ "$INPUT_MODE" = "file" ] && [ -f "$INPUT_FILE" ]; then
        local total
        total=$(wc -l < "$INPUT_FILE")
        echo -e "  ${WHITE}Input File  :${NC} ${GREEN}$INPUT_FILE${NC}"
        echo -e "  ${WHITE}Total Hosts :${NC} ${YELLOW}${BOLD}$total${NC}"
        echo ""
        if   [ "$total" -gt 1000 ]; then
            echo -e "  ${YELLOW}[!] অনেক host! Recommended threads: 100-200${NC}"
        elif [ "$total" -gt 100 ]; then
            echo -e "  ${CYAN}[*] Recommended threads: 50-100${NC}"
        else
            echo -e "  ${GREEN}[✓] ছোট list — default threads (50) যথেষ্ট।${NC}"
        fi
        # Sample probe
        local sample
        sample=$(head -1 "$INPUT_FILE")
        echo ""
        echo -e "  ${WHITE}Sample probe:${NC} $sample"
        local ss
        ss=$(curl -so /dev/null --max-time 6 -w "%{http_code}" "http://$sample" 2>/dev/null)
        echo -e "  ${WHITE}Sample status:${NC} ${YELLOW}$ss${NC}"

    elif [ "$INPUT_MODE" = "single" ] || [ "$INPUT_MODE" = "multi" ]; then
        echo -e "  ${WHITE}Target      :${NC} ${GREEN}$target${NC}"
        local st
        st=$(curl -so /dev/null --max-time 8 -w "%{http_code}" "$target" 2>/dev/null)
        if [ "$st" = "000" ]; then
            echo -e "  ${RED}[!] Target respond করছে না! Live আছে?${NC}"
        else
            echo -e "  ${WHITE}HTTP Status :${NC} ${GREEN}$st — Target live আছে ✓${NC}"
        fi
        local server
        server=$(curl -sI --max-time 8 "$target" 2>/dev/null | grep -i "^Server:" | cut -d: -f2- | xargs)
        [ -n "$server" ] && echo -e "  ${WHITE}Server      :${NC} ${YELLOW}$server${NC}"
        # CDN hint
        local cdn
        cdn=$(curl -sI --max-time 8 "$target" 2>/dev/null | grep -iE "cf-ray|x-cache|x-amz|fastly|akamai")
        [ -n "$cdn" ] && echo -e "  ${YELLOW}[!] CDN detected! Real IP hide থাকতে পারে।${NC}"

    elif [ "$INPUT_MODE" = "cidr" ]; then
        echo -e "  ${WHITE}CIDR Range  :${NC} ${GREEN}$target${NC}"
        echo -e "  ${CYAN}[*] IP range probe করা হবে। Threads ও rate মাথায় রাখুন।${NC}"
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
    if [ "$INPUT_MODE" = "file" ]; then
        domain=$(head -1 "$INPUT_FILE" | sed 's|https\?://||' | cut -d'/' -f1)
    elif [ "$INPUT_MODE" = "cidr" ]; then
        domain=$(echo "$target" | cut -d'/' -f1)
    else
        domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1)
    fi

    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}   PRE-SCAN RECON  ›  $domain${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [ "$INPUT_MODE" != "cidr" ]; then
        whois_lookup "$domain"
        geoip_lookup "$domain"
        reverse_dns  "$domain"
    fi
    connectivity_precheck "$target"
}

# ================================================================
# PROBE OPTIONS
# ================================================================
declare -A PROBE_OPT

get_probe_options() {
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                    PROBE OPTIONS                                    ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${DIM}y অথবা Enter = চালু, n = বন্ধ${NC}"
    echo ""

    local opts=(
        "status_code:Status Code        (-status-code):y"
        "title:Page Title            (-title):y"
        "tech:Tech Detection         (-tech-detect):y"
        "content_length:Content Length       (-content-length):y"
        "web_server:Web Server Header     (-web-server):y"
        "ip:IP Address            (-ip):y"
        "cdn:CDN Detection         (-cdn):y"
        "follow_redirect:Follow Redirects     (-follow-redirects):y"
        "screenshot:Screenshot           (-screenshot):n"
        "method:HTTP Method           (-method):n"
        "favicon:Favicon Hash          (-favicon):n"
        "jarm:JARM TLS Fingerprint   (-jarm):n"
    )

    for opt in "${opts[@]}"; do
        local key label default
        key=$(echo     "$opt" | cut -d: -f1)
        label=$(echo   "$opt" | cut -d: -f2)
        default=$(echo "$opt" | cut -d: -f3)
        printf "  ${WHITE}%-45s${NC}[default: %s] " "$label" "$default"
        read -r val
        val="${val:-$default}"
        if [[ "$val" =~ ^[Yy]$ ]] || [ "$val" = "y" ]; then
            PROBE_OPT["$key"]="yes"
            echo -e "  ${GREEN}  [✓] চালু${NC}"
        else
            PROBE_OPT["$key"]="no"
            echo -e "  ${DIM}  [✗] বন্ধ${NC}"
        fi
    done
    echo ""
}

# ================================================================
# FILTER CONFIG
# ================================================================
get_filter_config() {
    echo -e "${CYAN}[*] Filter / Match config:${NC}"
    echo ""
    read -p "$(echo -e ${WHITE}"Status code filter -fc [Enter=skip]: "${NC})" FILTER_CODE
    read -p "$(echo -e ${WHITE}"Content length filter -fl [Enter=skip]: "${NC})" FILTER_LEN
    read -p "$(echo -e ${WHITE}"Match status codes -mc [Enter=all]: "${NC})" MATCH_CODE
    read -p "$(echo -e ${WHITE}"Match string -ms [Enter=skip]: "${NC})" MATCH_STR
    echo ""
}

# ================================================================
# EXTRA OPTIONS
# ================================================================
get_extra_options() {
    echo -e "${CYAN}[*] Advanced options:${NC}"
    echo ""
    read -p "$(echo -e ${WHITE}"Threads [default: 50]: "${NC})" THREADS
    [ -z "$THREADS" ] && THREADS="50"
    if [ "$THREADS" -gt 200 ] 2>/dev/null; then
        echo -e "${YELLOW}[!] $THREADS threads অনেক বেশি!${NC}"
        read -p "$(echo -e ${YELLOW}"তবুও চালাবেন? [y/n]: "${NC})" ct
        [[ ! "$ct" =~ ^[Yy]$ ]] && THREADS="50"
    fi

    read -p "$(echo -e ${WHITE}"Timeout seconds [default: 10]: "${NC})" TIMEOUT
    [ -z "$TIMEOUT" ] && TIMEOUT="10"
    read -p "$(echo -e ${WHITE}"Custom ports [যেমন: 80,443,8080 — Enter=default]: "${NC})" PORTS
    read -p "$(echo -e ${WHITE}"HTTP Method [default: GET]: "${NC})" HTTP_METHOD
    [ -z "$HTTP_METHOD" ] && HTTP_METHOD="GET"
    read -p "$(echo -e ${WHITE}"Random User-Agent? [y/n]: "${NC})" ra
    [[ "$ra" =~ ^[Yy]$ ]] && RANDOM_AGENT="-random-agent" || RANDOM_AGENT=""
    read -p "$(echo -e ${WHITE}"Custom Header [Enter=skip]: "${NC})" CUSTOM_HEADER
    read -p "$(echo -e ${WHITE}"Proxy [Enter=skip, Burp: http://127.0.0.1:8080]: "${NC})" PROXY
    echo -e "  Output: ${GREEN}1)${NC} Plain  ${GREEN}2)${NC} JSON  ${GREEN}3)${NC} CSV"
    read -p "$(echo -e ${WHITE}"Format [1-3, default=1]: "${NC})" fmt
    case "$fmt" in
        2) OUTPUT_FMT="-json" ;;
        3) OUTPUT_FMT="-csv"  ;;
        *) OUTPUT_FMT=""      ;;
    esac
    echo ""
}

# ================================================================
# BUILD & RUN
# ================================================================
build_and_run() {
    local target=$1
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local label
    if [ "$INPUT_MODE" = "file" ]; then
        label=$(basename "$INPUT_FILE" .txt)
    else
        label=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1 | sed 's/[^a-zA-Z0-9._-]/_/g')
    fi
    local outbase="$RESULTS_DIR/${label}_httpx_${ts}"

    # Build command
    local cmd="httpx"
    case "$INPUT_MODE" in
        single|multi) cmd+=" -u \"$target\""   ;;
        file)         cmd+=" -l \"$INPUT_FILE\"";;
        cidr)         cmd+=" -cidr \"$target\"" ;;
    esac

    [ "${PROBE_OPT[status_code]}"    = "yes" ] && cmd+=" -status-code"
    [ "${PROBE_OPT[title]}"          = "yes" ] && cmd+=" -title"
    [ "${PROBE_OPT[tech]}"           = "yes" ] && cmd+=" -tech-detect"
    [ "${PROBE_OPT[content_length]}" = "yes" ] && cmd+=" -content-length"
    [ "${PROBE_OPT[web_server]}"     = "yes" ] && cmd+=" -web-server"
    [ "${PROBE_OPT[ip]}"             = "yes" ] && cmd+=" -ip"
    [ "${PROBE_OPT[cdn]}"            = "yes" ] && cmd+=" -cdn"
    [ "${PROBE_OPT[follow_redirect]}" = "yes" ] && cmd+=" -follow-redirects"
    [ "${PROBE_OPT[screenshot]}"     = "yes" ] && cmd+=" -screenshot"
    [ "${PROBE_OPT[method]}"         = "yes" ] && cmd+=" -method"
    [ "${PROBE_OPT[favicon]}"        = "yes" ] && cmd+=" -favicon"
    [ "${PROBE_OPT[jarm]}"           = "yes" ] && cmd+=" -jarm"

    [ -n "$FILTER_CODE"  ] && cmd+=" -fc $FILTER_CODE"
    [ -n "$FILTER_LEN"   ] && cmd+=" -fl $FILTER_LEN"
    [ -n "$MATCH_CODE"   ] && cmd+=" -mc $MATCH_CODE"
    [ -n "$MATCH_STR"    ] && cmd+=" -ms \"$MATCH_STR\""
    cmd+=" -threads $THREADS -timeout $TIMEOUT"
    [ "$HTTP_METHOD" != "GET" ] && cmd+=" -x $HTTP_METHOD"
    [ -n "$PORTS"          ] && cmd+=" -ports $PORTS"
    [ -n "$RANDOM_AGENT"   ] && cmd+=" $RANDOM_AGENT"
    [ -n "$CUSTOM_HEADER"  ] && cmd+=" -H \"$CUSTOM_HEADER\""
    [ -n "$PROXY"          ] && cmd+=" -http-proxy $PROXY"

    local ext="txt"
    if [ -n "$OUTPUT_FMT" ]; then
        [ "$OUTPUT_FMT" = "-json" ] && ext="json"
        [ "$OUTPUT_FMT" = "-csv"  ] && ext="csv"
        cmd+=" -o \"${outbase}.${ext}\" $OUTPUT_FMT"
    else
        cmd+=" -o \"${outbase}.txt\""
    fi
    cmd+=" -no-color"

    # Preview
    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}Input  : ${GREEN}${BOLD}$target${NC}"
    echo -e "  ${WHITE}Command: ${CYAN}$cmd${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] Scan শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local tmp_scan tmp_bangla
    tmp_scan=$(mktemp)
    tmp_bangla=$(mktemp)

    echo ""
    echo -e "${GREEN}${BOLD}[*] Scan শুরু হচ্ছে...${NC}"
    echo ""

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INPUT=$INPUT_MODE TARGET=$target" >> "$HISTORY_FILE"

    eval "$cmd" 2>&1 | tee "$tmp_scan"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Scan সম্পন্ন!${NC}"

    bangla_analysis "$tmp_scan" "$tmp_bangla"
    suggest_next_tool "$tmp_scan" "$target"
    save_results "$target" "$tmp_scan" "$tmp_bangla" "$outbase"

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
    echo -e "${MAGENTA}${BOLD}║              বাংলায় Httpx রিপোর্ট বিশ্লেষণ                       ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local critical=0 high=0 medium=0 info=0

    if [ ! -s "$outfile" ]; then
        echo -e "  ${YELLOW}[!] Scan output পাওয়া যায়নি।${NC}"
        echo ""
        return
    fi

    # Live/dead counts
    local total live_2xx live_3xx dead_4xx dead_5xx
    total=$(grep -c "http" "$outfile" 2>/dev/null || echo 0)
    live_2xx=$(grep -c "\[2[0-9][0-9]\]" "$outfile" 2>/dev/null || echo 0)
    live_3xx=$(grep -c "\[3[0-9][0-9]\]" "$outfile" 2>/dev/null || echo 0)
    dead_4xx=$(grep -c "\[4[0-9][0-9]\]" "$outfile" 2>/dev/null || echo 0)
    dead_5xx=$(grep -c "\[5[0-9][0-9]\]" "$outfile" 2>/dev/null || echo 0)

    info=$((info+1))
    echo -e "  ${GREEN}${BOLD}✅ Host Summary:${NC}"
    echo -e "     ${WHITE}→ মোট probe করা : ${YELLOW}$total${NC}"
    echo -e "     ${WHITE}→ Live (2xx)     : ${GREEN}$live_2xx টি${NC}"
    echo -e "     ${WHITE}→ Redirect (3xx) : ${CYAN}$live_3xx টি${NC}"
    echo -e "     ${WHITE}→ 4xx Errors     : ${YELLOW}$dead_4xx টি${NC}"
    echo -e "     ${WHITE}→ Server Error (5xx): ${RED}$dead_5xx টি${NC}"
    echo -e "     ${GREEN}→ ঝুঁকি: INFO${NC}"; echo ""

    # 5xx
    if [ "$dead_5xx" -gt 0 ]; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}ℹ Server Error (5xx) পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ Debug mode চালু থাকলে stack trace leak হতে পারে।${NC}"
        echo -e "     ${WHITE}→ এই URLs manually check করুন।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # Default/setup pages
    if grep -qiE "Welcome to|Setup|Install|default page|test page" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Default / Setup Page পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ Server misconfigured বা অসম্পূর্ণ installation।${NC}"
        echo -e "     ${WHITE}→ এই pages publicly accessible থাকা উচিত না।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # Admin/login panels
    if grep -qiE "admin|dashboard|login|manager|cpanel|phpmyadmin|webmin" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ Admin / Login Panel পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ Administrative interface publicly accessible।${NC}"
        echo -e "     ${WHITE}→ IP whitelist বা 2FA enforce করুন।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Error/debug pages
    if grep -qiE "error|exception|debug|stack.trace|unauthorized" "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}ℹ Error / Debug Page পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ Stack trace বা internal path leak হতে পারে।${NC}"
        echo -e "     ${WHITE}→ Production এ debug mode বন্ধ রাখুন।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # Technology breakdown
    local wp php django laravel iis nginx apache
    wp=$(grep -ic "WordPress" "$outfile" 2>/dev/null || echo 0)
    php=$(grep -ic "PHP" "$outfile" 2>/dev/null || echo 0)
    django=$(grep -ic "Django" "$outfile" 2>/dev/null || echo 0)
    laravel=$(grep -ic "Laravel" "$outfile" 2>/dev/null || echo 0)
    iis=$(grep -ic "IIS" "$outfile" 2>/dev/null || echo 0)
    nginx=$(grep -ic "nginx" "$outfile" 2>/dev/null || echo 0)
    apache=$(grep -ic "Apache" "$outfile" 2>/dev/null || echo 0)

    local tech_total=$((wp+php+django+laravel+iis+nginx+apache))
    if [ "$tech_total" -gt 0 ]; then
        info=$((info+1))
        echo -e "  ${GREEN}${BOLD}✅ Technology Stack Breakdown:${NC}"
        [ "$wp"      -gt 0 ] && echo -e "     ${WHITE}→ WordPress : ${YELLOW}$wp টি${NC}  ${DIM}(WPScan দিয়ে scan করুন)${NC}"
        [ "$php"     -gt 0 ] && echo -e "     ${WHITE}→ PHP       : ${YELLOW}$php টি${NC}  ${DIM}(SQLmap দিয়ে injection test করুন)${NC}"
        [ "$django"  -gt 0 ] && echo -e "     ${WHITE}→ Django    : ${CYAN}$django টি${NC}"
        [ "$laravel" -gt 0 ] && echo -e "     ${WHITE}→ Laravel   : ${CYAN}$laravel টি${NC}"
        [ "$iis"     -gt 0 ] && echo -e "     ${WHITE}→ IIS       : ${YELLOW}$iis টি${NC}  ${DIM}(Windows CVE check করুন)${NC}"
        [ "$nginx"   -gt 0 ] && echo -e "     ${WHITE}→ Nginx     : $nginx টি${NC}"
        [ "$apache"  -gt 0 ] && echo -e "     ${WHITE}→ Apache    : $apache টি${NC}"
        echo -e "     ${GREEN}→ ঝুঁকি: INFO${NC}"; echo ""
    fi

    # WordPress warning
    if [ "$wp" -gt 0 ]; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ WordPress Site(s) পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ $wp টি WordPress site detected।${NC}"
        echo -e "     ${WHITE}→ Outdated plugins এ CVE থাকতে পারে। WPScan দিয়ে check করুন।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # CDN
    local cdn_c
    cdn_c=$(grep -ic "CDN\|Cloudflare\|Akamai\|Fastly\|CloudFront" "$outfile" 2>/dev/null || echo 0)
    if [ "$cdn_c" -gt 0 ]; then
        info=$((info+1))
        echo -e "  ${GREEN}${BOLD}✅ CDN Detected:${NC}"
        echo -e "     ${WHITE}→ $cdn_c টি host CDN এর পেছনে।${NC}"
        echo -e "     ${WHITE}→ Real IP খুঁজতে Shodan বা DNS history check করুন।${NC}"
        echo -e "     ${GREEN}→ ঝুঁকি: INFO${NC}"; echo ""
    fi

    # Many redirects
    if [ "$live_3xx" -gt 5 ]; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}ℹ অনেক Redirect পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ $live_3xx টি redirect — Open redirect test করুন।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # Risk summary
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
    local target=$2
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1)

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║              পরবর্তী Scan এর সাজেশন                                ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if grep -qi "WordPress" "$outfile" 2>/dev/null; then
        echo -e "  ${MAGENTA}${BOLD}🔧 WPScan${NC} — WordPress site পাওয়া গেছে!"
        echo -e "     ${WHITE}কারণ: Plugin, theme ও user enumeration করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: wpscan --url $target --enumerate u,vp,ap --api-token TOKEN${NC}"; echo ""
    fi

    if grep -qi "PHP" "$outfile" 2>/dev/null; then
        echo -e "  ${GREEN}${BOLD}💉 SQLmap${NC} — PHP site এ injection test"
        echo -e "     ${WHITE}কারণ: PHP parameter এ SQL injection test করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: sqlmap -u \"$target/page.php?id=1\" --dbs --batch${NC}"; echo ""

        echo -e "  ${YELLOW}${BOLD}🔍 FFUF${NC} — Directory fuzzing"
        echo -e "     ${WHITE}কারণ: PHP site এ hidden files ও endpoints খুঁজুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: ffuf -u $target/FUZZ -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -e php,bak -c -ac${NC}"; echo ""
    fi

    if grep -qiE "login|Login|signin" "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}🔑 Hydra${NC} — Login page এ brute force"
        echo -e "     ${WHITE}কারণ: Discovered login page এ credential attack করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: hydra -L users.txt -P passwords.txt $domain http-post-form \"/login:u=^USER^&p=^PASS^:F=incorrect\"${NC}"; echo ""
    fi

    echo -e "  ${WHITE}${BOLD}📡 Nmap${NC} — Port scan on live hosts"
    echo -e "     ${WHITE}কারণ: Live hosts এ open ports ও services discover করুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: nmap -sV -sC -p- $domain -oN nmap_out.txt${NC}"; echo ""

    echo -e "  ${YELLOW}${BOLD}🌐 Nikto${NC} — Web vulnerability scan"
    echo -e "     ${WHITE}কারণ: Live hosts এ misconfiguration ও CVE check করুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: nikto -h $target${NC}"; echo ""

    echo -e "  ${BLUE}${BOLD}🔒 SSLScan${NC} — HTTPS sites SSL check"
    echo -e "     ${WHITE}কারণ: HTTPS hosts এ SSL vulnerability check করুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: sslscan $domain:443${NC}"; echo ""
}

# ================================================================
# SAVE RESULTS
# ================================================================
save_results() {
    local target=$1
    local scan_out=$2
    local bangla_out=$3
    local outbase=$4

    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Result save করবেন? (y/n): "${NC})" sc
    if [[ "$sc" =~ ^[Yy]$ ]]; then
        local fname="${outbase}_report.txt"
        {
            echo "============================================================"
            echo "  HTTPX RESULTS  —  SAIMUM's Automation Tool"
            echo "  Input  : $INPUT_MODE"
            echo "  Target : $target"
            echo "  Date   : $(date)"
            echo "============================================================"
            echo ""
            echo "=== HTTPX RAW OUTPUT ==="
            cat "$scan_out"
            echo ""
            echo "=== BANGLA ANALYSIS ==="
            sed 's/\x1b\[[0-9;]*m//g' "$bangla_out"
        } > "$fname"
        echo -e "${GREEN}[✓] Saved → $fname${NC}"
        echo "$(date) | $INPUT_MODE | $target | $fname" >> "$HISTORY_FILE"
    fi
}

# ================================================================
# SERIES COMPLETE
# ================================================================
show_series_complete() {
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║            🎉  SAIMUM PENTESTING SERIES COMPLETE!  🎉               ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}[✓]${NC}  nmap_saimum.sh      — Port & Service Scan"
    echo -e "  ${GREEN}[✓]${NC}  nikto_saimum.sh     — Web Vulnerability Scan"
    echo -e "  ${GREEN}[✓]${NC}  gobuster_saimum.sh  — Directory Brute Force"
    echo -e "  ${GREEN}[✓]${NC}  subfinder_saimum.sh — Subdomain Discovery"
    echo -e "  ${GREEN}[✓]${NC}  sqlmap_saimum.sh    — SQL Injection"
    echo -e "  ${GREEN}[✓]${NC}  wpscan_saimum.sh    — WordPress Scanner"
    echo -e "  ${GREEN}[✓]${NC}  hydra_saimum.sh     — Brute Force"
    echo -e "  ${GREEN}[✓]${NC}  sslscan_saimum.sh   — SSL/TLS Analysis"
    echo -e "  ${GREEN}[✓]${NC}  amass_saimum.sh     — OSINT Recon"
    echo -e "  ${GREEN}[✓]${NC}  ffuf_saimum.sh      — Web Fuzzing"
    echo -e "  ${GREEN}[✓]${NC}  httpx_saimum.sh     — HTTP Probing  ${YELLOW}← তুমি এখানে${NC}"
    echo ""
    echo -e "  ${CYAN}${DIM}Happy Hacking — Ethically! 🛡️${NC}"
    echo ""
}

# ================================================================
# MAIN LOOP
# ================================================================
main() {
    show_banner
    check_deps

    while true; do
        get_targets

        # Recon for each target
        for t in "${TARGETS[@]}"; do
            local rt="$t"
            [[ "$t" == FILE:* ]] && rt=$(head -1 "$INPUT_FILE")
            pre_scan_recon "$rt"
        done

        read -p "[Enter] চাপুন probe config এ যেতে..."

        unset PROBE_OPT; declare -A PROBE_OPT
        get_probe_options
        get_filter_config
        get_extra_options

        for t in "${TARGETS[@]}"; do
            local rt="$t"
            [[ "$t" == FILE:* ]] && rt="$INPUT_FILE"
            echo ""
            echo -e "${GREEN}${BOLD}══════════════ Target: $rt ══════════════${NC}"
            build_and_run "$rt"
        done

        echo ""
        read -p "[?] আরেকটি scan করবেন? (y/n): " again
        if [[ ! "$again" =~ ^[Yy]$ ]]; then
            show_series_complete
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical!${NC}"
            echo ""
            exit 0
        fi
        unset TARGETS INPUT_FILE INPUT_MODE
        unset THREADS TIMEOUT PORTS HTTP_METHOD RANDOM_AGENT CUSTOM_HEADER PROXY OUTPUT_FMT
        unset FILTER_CODE FILTER_LEN MATCH_CODE MATCH_STR
        show_banner
    done
}

main
