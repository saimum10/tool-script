#!/bin/bash

# ================================================================
#   SUBFINDER - Full Automation Tool
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

RESULTS_DIR="$HOME/subfinder_results"
HISTORY_FILE="$HOME/.subfinder_saimum_history.log"
CONFIG_FILE="$HOME/.config/subfinder/config.yaml"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo ' ███████╗██╗   ██╗██████╗ ███████╗██╗███╗   ██╗██████╗ ███████╗██████╗ '
    echo ' ██╔════╝██║   ██║██╔══██╗██╔════╝██║████╗  ██║██╔══██╗██╔════╝██╔══██╗'
    echo ' ███████╗██║   ██║██████╔╝█████╗  ██║██╔██╗ ██║██║  ██║█████╗  ██████╔╝'
    echo ' ╚════██║██║   ██║██╔══██╗██╔══╝  ██║██║╚██╗██║██║  ██║██╔══╝  ██╔══██╗'
    echo ' ███████║╚██████╔╝██████╔╝██║     ██║██║ ╚████║██████╔╝███████╗██║  ██║'
    echo ' ╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝  ╚═╝'
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}        Subfinder Full Automation Tool | Passive Subdomain Enumeration${NC}"
    echo ""
}

# ================================================================
# CHECK DEPENDENCIES
# ================================================================
check_deps() {
    echo -e "${CYAN}[*] Dependencies চেক করা হচ্ছে...${NC}"
    local missing=()
    for tool in subfinder whois curl dig host; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
            echo -e "  ${RED}[✗] $tool — পাওয়া যায়নি${NC}"
        else
            echo -e "  ${GREEN}[✓] $tool${NC}"
        fi
    done

    # httpx optional
    echo ""
    if command -v httpx &>/dev/null; then
        echo -e "  ${GREEN}[✓] httpx — available (active check করা যাবে)${NC}"
        HTTPX_AVAILABLE=true
    else
        echo -e "  ${YELLOW}[!] httpx — নেই (optional, active check করা যাবে না)${NC}"
        HTTPX_AVAILABLE=false
    fi

    # Config file check
    echo ""
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "  ${GREEN}[✓] Subfinder config পাওয়া গেছে: $CONFIG_FILE${NC}"
    else
        echo -e "  ${YELLOW}[!] Config file নেই — API key ছাড়া চলবে কিন্তু result কম আসবে।${NC}"
        echo -e "  ${DIM}    Path: $CONFIG_FILE${NC}"
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing tools: ${missing[*]}${NC}"
        echo -e "${YELLOW}[*] Install করুন:${NC}"
        echo -e "    ${CYAN}go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest${NC}"
        echo -e "    ${CYAN}অথবা: sudo apt install subfinder${NC}"
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
    echo -e "${GREEN}${BOLD}┌─── DNS RECORD CHECK ──────────────────────────────┐${NC}"
    local ip
    ip=$(dig +short "$domain" 2>/dev/null | grep -E '^[0-9]+\.' | head -1)
    local ns
    ns=$(dig +short NS "$domain" 2>/dev/null | head -3)
    local mx
    mx=$(dig +short MX "$domain" 2>/dev/null | head -3)

    echo -e "  ${WHITE}Domain    :${NC} ${GREEN}$domain${NC}"
    echo -e "  ${WHITE}IP        :${NC} ${GREEN}${ip:-পাওয়া যায়নি}${NC}"
    [ -n "$ns" ] && echo -e "  ${WHITE}NS Records:${NC} ${GREEN}$ns${NC}"
    [ -n "$mx" ] && echo -e "  ${WHITE}MX Records:${NC} ${GREEN}$mx${NC}"

    # Zone transfer check
    echo ""
    echo -e "  ${CYAN}[*] DNS Zone Transfer চেক করা হচ্ছে...${NC}"
    local zt_result
    zt_result=$(dig axfr "$domain" 2>/dev/null | head -5)
    if echo "$zt_result" | grep -q "Transfer failed\|connection timed\|REFUSED"; then
        echo -e "  ${GREEN}  [✓] Zone Transfer বন্ধ আছে (ভালো)${NC}"
    elif [ -n "$zt_result" ]; then
        echo -e "  ${RED}  [!] Zone Transfer সম্ভব! DNS misconfiguration!${NC}"
    else
        echo -e "  ${YELLOW}  [!] Zone Transfer result অস্পষ্ট।${NC}"
    fi

    echo -e "${GREEN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# PRE-SCAN RECON
# ================================================================
pre_scan_recon() {
    local domain=$1
    echo ""
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}${BOLD}   PRE-SCAN RECON  ›  $domain${NC}"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    whois_lookup "$domain"
    geoip_lookup "$domain"
    reverse_dns  "$domain"
}

# ================================================================
# STEP 1 — TARGET
# ================================================================
get_targets() {
    TARGETS=()
    DOMAIN_FILE=""

    echo -e "${BLUE}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║      STEP 1 — TARGET                 ║${NC}"
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Single domain  ${DIM}(e.g. example.com)${NC}"
    echo -e "  ${GREEN}2)${NC} Multiple domains (একটা একটা করে)"
    echo -e "  ${GREEN}3)${NC} File থেকে domain list"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-3]: "${NC})" ttype

    case $ttype in
        1)
            read -p "$(echo -e ${WHITE}"Domain দিন: "${NC})" t
            t=$(echo "$t" | sed 's|https\?://||' | cut -d'/' -f1)
            TARGETS=("$t")
            ;;
        2)
            echo -e "${WHITE}একটা একটা করে দিন। শেষ হলে 'done' লিখুন:${NC}"
            while true; do
                read -p "$(echo -e ${WHITE}"Domain: "${NC})" t
                [[ "$t" == "done" || -z "$t" ]] && break
                t=$(echo "$t" | sed 's|https\?://||' | cut -d'/' -f1)
                TARGETS+=("$t")
            done
            ;;
        3)
            read -p "$(echo -e ${WHITE}"File path দিন: "${NC})" fpath
            if [ ! -f "$fpath" ]; then
                echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
                get_targets; return
            fi
            DOMAIN_FILE="$fpath"
            while IFS= read -r line; do
                [[ -z "$line" || "$line" == \#* ]] && continue
                line=$(echo "$line" | sed 's|https\?://||' | cut -d'/' -f1)
                TARGETS+=("$line")
            done < "$fpath"
            echo -e "${GREEN}[✓] ${#TARGETS[@]} টি domain লোড হয়েছে।${NC}"
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
    echo ""
}

# ================================================================
# STEP 2 — SOURCES CONFIG
# ================================================================
get_sources() {
    SOURCES_OPT=""
    ALL_SOURCES=false

    echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║      STEP 2 — SOURCES CONFIG                                        ║${NC}"
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Subfinder অনেক জায়গা থেকে subdomain খোঁজে।"
    echo -e "  কোথা থেকে খুঁজবে সেটা এখানে ঠিক করুন।"
    echo ""
    echo -e "  ${GREEN}1)${NC} ${YELLOW}সব sources একসাথে${NC} ${DIM}(-all) — সবচেয়ে বেশি result, সময় বেশি${NC}"
    echo -e "  ${GREEN}2)${NC} Default sources ${DIM}— দ্রুত, reliable result${NC}"
    echo -e "  ${GREEN}3)${NC} Specific sources বেছে নাও"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-3]: "${NC})" src_ch

    case $src_ch in
        1)
            SOURCES_OPT="-all"
            ALL_SOURCES=true
            echo -e "  ${GREEN}[✓] সব sources চালু।${NC}"
            ;;
        2)
            echo -e "  ${GREEN}[✓] Default sources ব্যবহার হবে।${NC}"
            ;;
        3)
            echo ""
            echo -e "  ${CYAN}Available Sources:${NC}"
            echo -e "  ${DIM}(একাধিক হলে comma দিয়ে লিখুন, e.g: crtsh,dnsdumpster,waybackarchive)${NC}"
            echo ""
            echo -e "  ${WHITE}Free Sources (API key লাগে না):${NC}"
            echo -e "    ${GREEN}crtsh${NC}          — Certificate Transparency logs"
            echo -e "    ${GREEN}dnsdumpster${NC}    — DNS records database"
            echo -e "    ${GREEN}waybackarchive${NC} — Wayback Machine"
            echo -e "    ${GREEN}hackertarget${NC}   — HackerTarget API"
            echo -e "    ${GREEN}rapiddns${NC}       — RapidDNS database"
            echo -e "    ${GREEN}riddler${NC}        — Riddler.io"
            echo -e "    ${GREEN}threatcrowd${NC}    — ThreatCrowd"
            echo -e "    ${GREEN}urlscan${NC}        — URLScan.io"
            echo ""
            echo -e "  ${WHITE}API Key দরকার (বেশি result):${NC}"
            echo -e "    ${YELLOW}shodan${NC}         — Shodan.io"
            echo -e "    ${YELLOW}censys${NC}         — Censys.io"
            echo -e "    ${YELLOW}virustotal${NC}     — VirusTotal"
            echo -e "    ${YELLOW}securitytrails${NC} — SecurityTrails"
            echo -e "    ${YELLOW}binaryedge${NC}     — BinaryEdge"
            echo -e "    ${YELLOW}github${NC}         — GitHub code search"
            echo ""
            read -p "$(echo -e ${WHITE}"Sources লিখুন: "${NC})" src_in
            if [ -n "$src_in" ]; then
                SOURCES_OPT="-sources $src_in"
                echo -e "  ${GREEN}[✓] Sources: $src_in${NC}"
            fi
            ;;
        *)
            echo -e "  ${YELLOW}[!] Default sources ব্যবহার হবে।${NC}"
            ;;
    esac
    echo ""
}

# ================================================================
# STEP 2b — API KEY SETUP
# ================================================================
check_api_keys() {
    echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║      API KEY SETUP (optional, বেশি result পেতে)                    ║${NC}"
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ -f "$CONFIG_FILE" ]; then
        echo -e "  ${GREEN}[✓] Config file আছে — আগের API keys ব্যবহার হবে।${NC}"
        read -p "$(echo -e ${WHITE}"  নতুন API key যোগ করবেন? (y/n): "${NC})" add_key
        [[ ! "$add_key" =~ ^[Yy]$ ]] && { echo ""; return; }
    fi

    echo -e "  ${DIM}API key থাকলে দিন, না থাকলে Enter দিয়ে skip করুন।${NC}"
    echo ""

    local shodan_key virustotal_key censys_id censys_secret github_key sectrails_key

    read -p "$(echo -e ${WHITE}"  Shodan API Key: "${NC})"       shodan_key
    read -p "$(echo -e ${WHITE}"  VirusTotal API Key: "${NC})"   virustotal_key
    read -p "$(echo -e ${WHITE}"  Censys API ID: "${NC})"        censys_id
    read -p "$(echo -e ${WHITE}"  Censys API Secret: "${NC})"    censys_secret
    read -p "$(echo -e ${WHITE}"  GitHub Token: "${NC})"         github_key
    read -p "$(echo -e ${WHITE}"  SecurityTrails Key: "${NC})"   sectrails_key

    # Save to config if any key provided
    local any_key=false
    for k in "$shodan_key" "$virustotal_key" "$censys_id" "$github_key" "$sectrails_key"; do
        [ -n "$k" ] && any_key=true && break
    done

    if $any_key; then
        mkdir -p "$(dirname "$CONFIG_FILE")"
        {
            echo "version: 1"
            [ -n "$shodan_key"      ] && echo "shodan: [\"$shodan_key\"]"
            [ -n "$virustotal_key"  ] && echo "virustotal: [\"$virustotal_key\"]"
            [ -n "$sectrails_key"   ] && echo "securitytrails: [\"$sectrails_key\"]"
            [ -n "$github_key"      ] && echo "github: [\"$github_key\"]"
            if [ -n "$censys_id" ] && [ -n "$censys_secret" ]; then
                echo "censys: [{\"username\": \"$censys_id\", \"password\": \"$censys_secret\"}]"
            fi
        } > "$CONFIG_FILE"
        echo -e "  ${GREEN}[✓] API keys config এ save হয়েছে: $CONFIG_FILE${NC}"
    else
        echo -e "  ${YELLOW}[!] কোনো API key দেওয়া হয়নি। Free sources দিয়ে চলবে।${NC}"
    fi
    echo ""
}

# ================================================================
# STEP 3 — FILTER & OUTPUT CONFIG
# ================================================================
get_filter_config() {
    RESOLVE_OPT=""
    ACTIVE_OPT=""
    WILDCARD_OPT=""
    THREADS_OPT=""
    TIMEOUT_OPT=""
    VERBOSE_OPT=""
    IP_OPT=""

    echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║      STEP 3 — FILTER & OUTPUT CONFIG                                ║${NC}"
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # IP resolve
    read -p "$(echo -e ${WHITE}"প্রতিটি subdomain এর IP resolve করবেন? (y/n): "${NC})" ip_yn
    if [[ "$ip_yn" =~ ^[Yy]$ ]]; then
        IP_OPT="-oI /tmp/subfinder_ips.txt"
        echo -e "  ${GREEN}[✓] IP resolve চালু।${NC}"
    fi

    # Active only (httpx)
    if $HTTPX_AVAILABLE; then
        echo ""
        read -p "$(echo -e ${WHITE}"শুধু active (HTTP response দেয়) subdomain দেখাবে? httpx লাগবে (y/n): "${NC})" active_yn
        if [[ "$active_yn" =~ ^[Yy]$ ]]; then
            ACTIVE_OPT="| httpx -silent"
            echo -e "  ${GREEN}[✓] Active filter চালু — শুধু live subdomain দেখাবে।${NC}"
        fi
    fi

    # Wildcard filter
    echo ""
    read -p "$(echo -e ${WHITE}"Wildcard subdomain filter করবেন? (y/n, recommended: y): "${NC})" wc_yn
    if [[ "$wc_yn" =~ ^[Yy]$ ]]; then
        WILDCARD_OPT="-nW"
        echo -e "  ${GREEN}[✓] Wildcard filter চালু।${NC}"
    fi

    # Threads
    echo ""
    read -p "$(echo -e ${WHITE}"Threads কতটা? (Enter = 10, বেশি হলে faster): "${NC})" th_in
    [ -n "$th_in" ] && THREADS_OPT="-t $th_in" || THREADS_OPT="-t 10"
    echo -e "  ${GREEN}[✓] Threads: ${th_in:-10}${NC}"

    # Timeout
    read -p "$(echo -e ${WHITE}"Timeout (seconds)? (Enter = 30): "${NC})" to_in
    [ -n "$to_in" ] && TIMEOUT_OPT="-timeout $to_in" || TIMEOUT_OPT="-timeout 30"
    echo -e "  ${GREEN}[✓] Timeout: ${to_in:-30}s${NC}"

    # Verbose
    echo ""
    read -p "$(echo -e ${WHITE}"Verbose mode চালু করবেন? (কোন source থেকে আসছে দেখাবে) (y/n): "${NC})" vb_yn
    [[ "$vb_yn" =~ ^[Yy]$ ]] && VERBOSE_OPT="-v" && \
        echo -e "  ${GREEN}[✓] Verbose: ON${NC}"

    echo ""
}

# ================================================================
# STEP 4 — EXTRA OPTIONS
# ================================================================
get_extra_options() {
    PROXY_OPT=""
    RESOLVER_OPT=""
    EXCLUDE_OPT=""

    echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║      STEP 4 — EXTRA OPTIONS (সব optional, Enter = skip)            ║${NC}"
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Proxy
    read -p "$(echo -e ${WHITE}"Proxy ব্যবহার করবেন? (y/n): "${NC})" proxy_yn
    if [[ "$proxy_yn" =~ ^[Yy]$ ]]; then
        read -p "$(echo -e ${WHITE}"  Proxy (e.g. http://127.0.0.1:8080): "${NC})" proxy_in
        PROXY_OPT="-proxy $proxy_in"
        echo -e "  ${GREEN}[✓] Proxy: $proxy_in${NC}"
    fi

    # Custom resolver
    echo ""
    read -p "$(echo -e ${WHITE}"Custom DNS resolver ব্যবহার করবেন? (y/n): "${NC})" res_yn
    if [[ "$res_yn" =~ ^[Yy]$ ]]; then
        echo -e "  ${CYAN}  Common resolvers:${NC}"
        echo -e "  ${GREEN}  1)${NC} 8.8.8.8,8.8.4.4     ${DIM}(Google)${NC}"
        echo -e "  ${GREEN}  2)${NC} 1.1.1.1,1.0.0.1     ${DIM}(Cloudflare)${NC}"
        echo -e "  ${GREEN}  3)${NC} 9.9.9.9             ${DIM}(Quad9)${NC}"
        echo -e "  ${GREEN}  4)${NC} Custom"
        read -p "$(echo -e ${YELLOW}"  Select [1-4]: "${NC})" res_ch
        case $res_ch in
            1) RESOLVER_OPT="-rL /dev/stdin <<< '8.8.8.8'" ;;
            2) RESOLVER_OPT="-rL /dev/stdin <<< '1.1.1.1'" ;;
            3) RESOLVER_OPT="-rL /dev/stdin <<< '9.9.9.9'" ;;
            4)
                read -p "$(echo -e ${WHITE}"  Resolver IP(s): "${NC})" res_in
                RESOLVER_OPT="-r $res_in"
                ;;
        esac
        echo -e "  ${GREEN}[✓] Custom resolver set।${NC}"
    fi

    # Exclude subdomains
    echo ""
    read -p "$(echo -e ${WHITE}"কোনো subdomain exclude করবেন? (Enter = skip): "${NC})" excl_in
    if [ -n "$excl_in" ]; then
        EXCLUDE_OPT="-exclude-sources $excl_in"
        echo -e "  ${GREEN}[✓] Exclude: $excl_in${NC}"
    fi

    echo ""
}

# ================================================================
# STEP 5 — BUILD & RUN
# ================================================================
build_and_run() {
    local domain=$1
    local out_file="$RESULTS_DIR/subfinder_${domain}_$(date +%Y%m%d_%H%M%S).txt"

    local final_cmd
    final_cmd=$(echo "subfinder -d $domain $SOURCES_OPT $WILDCARD_OPT $THREADS_OPT $TIMEOUT_OPT $VERBOSE_OPT $PROXY_OPT $EXCLUDE_OPT -o $out_file" | tr -s ' ')

    # Append httpx pipe if active filter on
    local display_cmd="$final_cmd"
    [ -n "$ACTIVE_OPT" ] && display_cmd="$final_cmd $ACTIVE_OPT"

    echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║      STEP 5 — CONFIRM & RUN                                         ║${NC}"
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${WHITE}Domain  : ${GREEN}${BOLD}$domain${NC}"
    echo -e "  ${WHITE}Command : ${YELLOW}$display_cmd${NC}"
    echo -e "  ${WHITE}Output  : ${CYAN}$out_file${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Scan শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local tmp_scan tmp_bangla
    tmp_scan=$(mktemp)
    tmp_bangla=$(mktemp)

    echo ""
    echo -e "${GREEN}${BOLD}[*] Subfinder scan শুরু হচ্ছে...${NC}"
    echo -e "${DIM}    Passive scan হওয়ায় সময় লাগতে পারে...${NC}"
    echo ""

    # Run — original terminal output হুবহু দেখাবে
    if [ -n "$ACTIVE_OPT" ]; then
        eval "$final_cmd" 2>&1 | tee "$tmp_scan" | httpx -silent
    else
        eval "$final_cmd" 2>&1 | tee "$tmp_scan"
    fi

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Scan সম্পন্ন!${NC}"

    # Copy output file content to tmp_scan for analysis
    [ -f "$out_file" ] && cat "$out_file" >> "$tmp_scan"

    bangla_analysis   "$tmp_scan" "$tmp_bangla" "$domain"
    suggest_next_tool "$tmp_scan" "$domain"
    save_prompt       "$out_file" "$tmp_bangla" "$domain"

    rm -f "$tmp_scan" "$tmp_bangla"
}

# ================================================================
# BANGLA ANALYSIS
# ================================================================
bangla_analysis() {
    local outfile=$1
    local report_file=$2
    local domain=$3

    {
    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় স্ক্যান রিপোর্ট বিশ্লেষণ                      ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local total critical=0 high=0 medium=0 info=0
    total=$(grep -c "." "$outfile" 2>/dev/null || echo "0")

    echo -e "  ${WHITE}${BOLD}📊 মোট Subdomain Found: ${GREEN}$total${NC}"
    echo ""

    # Dev/Staging/Test
    local dev_subs
    dev_subs=$(grep -iE "^dev\.|^staging\.|^test\.|^beta\.|^uat\.|^qa\.|^preprod\." "$outfile" 2>/dev/null)
    if [ -n "$dev_subs" ]; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Dev / Staging / Test Subdomain পাওয়া গেছে!${NC}"
        echo "$dev_subs" | head -5 | while read -r sub; do
            echo -e "     ${YELLOW}→ $sub${NC}"
        done
        echo -e "     ${WHITE}→ Development server এ security কম থাকে।${NC}"
        echo -e "     ${WHITE}→ Outdated code, debug mode, weak password থাকার সম্ভাবনা বেশি।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # Admin/Internal
    local admin_subs
    admin_subs=$(grep -iE "^admin\.|^internal\.|^intranet\.|^portal\.|^manage\.|^dashboard\.|^panel\." "$outfile" 2>/dev/null)
    if [ -n "$admin_subs" ]; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Admin / Internal Panel Subdomain পাওয়া গেছে!${NC}"
        echo "$admin_subs" | head -5 | while read -r sub; do
            echo -e "     ${YELLOW}→ $sub${NC}"
        done
        echo -e "     ${WHITE}→ Admin interface publicly accessible হতে পারে।${NC}"
        echo -e "     ${WHITE}→ Brute force বা credential stuffing এর ঝুঁকি।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # API subdomains
    local api_subs
    api_subs=$(grep -iE "^api\.|^rest\.|^graphql\.|^v1\.|^v2\." "$outfile" 2>/dev/null)
    if [ -n "$api_subs" ]; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ API Subdomain পাওয়া গেছে!${NC}"
        echo "$api_subs" | head -5 | while read -r sub; do
            echo -e "     ${CYAN}→ $sub${NC}"
        done
        echo -e "     ${WHITE}→ Unauthenticated API endpoint বা data leak সম্ভব।${NC}"
        echo -e "     ${WHITE}→ API key / token চুরির ঝুঁকি।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Mail/VPN/Remote access
    local sensitive_subs
    sensitive_subs=$(grep -iE "^mail\.|^smtp\.|^vpn\.|^remote\.|^rdp\.|^ssh\.|^ftp\.|^sftp\." "$outfile" 2>/dev/null)
    if [ -n "$sensitive_subs" ]; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ Sensitive Service Subdomain পাওয়া গেছে!${NC}"
        echo "$sensitive_subs" | head -5 | while read -r sub; do
            echo -e "     ${CYAN}→ $sub${NC}"
        done
        echo -e "     ${WHITE}→ Mail, VPN, FTP — targeted brute force attack সম্ভব।${NC}"
        echo -e "     ${WHITE}→ এই services এ credential attack খুব সাধারণ।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Old/Backup subdomains
    local old_subs
    old_subs=$(grep -iE "^old\.|^backup\.|^bak\.|^legacy\.|^archive\.|^deprecated\." "$outfile" 2>/dev/null)
    if [ -n "$old_subs" ]; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ Old / Backup Subdomain পাওয়া গেছে!${NC}"
        echo "$old_subs" | head -5 | while read -r sub; do
            echo -e "     ${CYAN}→ $sub${NC}"
        done
        echo -e "     ${WHITE}→ পুরনো subdomain এ patch দেওয়া হয় না — vulnerability বেশি।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Cloud/CDN subdomains
    local cloud_subs
    cloud_subs=$(grep -iE "\.amazonaws\.com|\.azurewebsites\.|\.cloudfront\.|\.herokuapp\." "$outfile" 2>/dev/null)
    if [ -n "$cloud_subs" ]; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}ℹ Cloud / CDN Subdomain পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ Subdomain takeover এর সম্ভাবনা আছে যদি service বন্ধ হয়।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # General info
    if [ "$total" -gt 0 ]; then
        info=$((info+1))
        echo -e "  ${WHITE}${BOLD}📌 Attack Surface বিশ্লেষণ${NC}"
        echo -e "     ${WHITE}→ $total টি subdomain মানে $total টি আলাদা attack surface।${NC}"
        echo -e "     ${WHITE}→ প্রতিটি subdomain আলাদাভাবে Nmap ও Nikto দিয়ে scan করুন।${NC}"
        echo -e "     ${GREEN}→ ঝুঁকি: INFO${NC}"; echo ""
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
        echo -e "  ${CYAN}  সার্বিক ঝুঁকি : █████░░░░░ MEDIUM — কিছু জিনিস দেখা দরকার।${NC}"
    elif [ "$total" -gt 0 ]; then
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW — তবু প্রতিটি subdomain আলাদা scan করুন।${NC}"
    else
        echo -e "  ${GREEN}  কোনো subdomain পাওয়া যায়নি।${NC}"
    fi
    echo ""
    } | tee "$report_file"
}

# ================================================================
# NEXT TOOL SUGGESTION
# ================================================================
suggest_next_tool() {
    local outfile=$1
    local domain=$2
    local total
    total=$(grep -c "." "$outfile" 2>/dev/null || echo "0")

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Scan এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ "$total" -gt 0 ]; then
        echo -e "  ${GREEN}${BOLD}🔍 Nmap${NC} — প্রতিটি Subdomain এ Port Scan"
        echo -e "     ${WHITE}কারণ: $total টি subdomain পাওয়া গেছে — কোন port খোলা দেখুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: nmap -iL subfinder_output.txt -sV -p 80,443,8080,22,21${NC}"; echo ""

        echo -e "  ${YELLOW}${BOLD}🌐 Httpx${NC} — Live Subdomain Check"
        echo -e "     ${WHITE}কারণ: কোন subdomain গুলো actually active সেটা দেখুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: httpx -l subfinder_output.txt -status-code -title -tech-detect${NC}"; echo ""

        echo -e "  ${RED}${BOLD}🔍 Gobuster (dir mode)${NC} — প্রতিটি Active Subdomain এ Directory Scan"
        echo -e "     ${WHITE}কারণ: Active subdomain এ hidden files খুঁজুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: gobuster dir -u http://subdomain.$domain -w wordlist.txt${NC}"; echo ""

        echo -e "  ${MAGENTA}${BOLD}🌍 Amass${NC} — Deep Enumeration"
        echo -e "     ${WHITE}কারণ: Subfinder এর পাশাপাশি Amass আরো বেশি subdomain বের করতে পারে।${NC}"
        echo -e "     ${CYAN}কমান্ড: amass enum -passive -d $domain${NC}"; echo ""
    fi

    if grep -qi "dev\.\|staging\.\|test\." "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}🎯 Nikto${NC} — Dev/Staging Server Vulnerability Scan"
        echo -e "     ${WHITE}কারণ: Dev/staging subdomain পাওয়া গেছে — এগুলো বেশি vulnerable।${NC}"
        echo -e "     ${CYAN}কমান্ড: nikto -h http://dev.$domain${NC}"; echo ""
    fi

    echo -e "  ${WHITE}${BOLD}☁ Subjack / Subzy${NC} — Subdomain Takeover Check"
    echo -e "     ${WHITE}কারণ: পাওয়া subdomains এ takeover vulnerability আছে কিনা দেখুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: subzy run --targets subfinder_output.txt${NC}"; echo ""
}

# ================================================================
# SAVE PROMPT
# ================================================================
save_prompt() {
    local out_file=$1
    local bangla_out=$2
    local domain=$3

    echo ""
    echo -e "${GREEN}[✓] Raw output automatically save হয়েছে: $out_file${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] বাংলা analysis সহ full report save করবেন? (y/n): "${NC})" sc
    if [[ "$sc" =~ ^[Yy]$ ]]; then
        local report_file="${out_file%.txt}_full_report.txt"
        {
            echo "============================================================"
            echo "  SUBFINDER SCAN RESULTS  —  SAIMUM's Automation Tool"
            echo "  Domain : $domain"
            echo "  Date   : $(date)"
            echo "============================================================"
            echo ""
            echo "=== SUBFINDER RAW OUTPUT ==="
            cat "$out_file" 2>/dev/null
            echo ""
            echo "=== BANGLA ANALYSIS ==="
            sed 's/\x1b\[[0-9;]*m//g' "$bangla_out"
        } > "$report_file"
        echo -e "${GREEN}[✓] Full report saved → $report_file${NC}"
        echo "$(date) | $domain | $report_file" >> "$HISTORY_FILE"
    fi
}

# ================================================================
# MAIN LOOP
# ================================================================
main() {
    show_banner
    check_deps

    while true; do

        # Step 1 — Targets
        get_targets

        # Pre-scan recon
        for t in "${TARGETS[@]}"; do
            pre_scan_recon "$t"
        done

        # Step 2 — Sources
        get_sources

        # API key setup
        check_api_keys

        # Step 3 — Filter config
        get_filter_config

        # Step 4 — Extra options
        get_extra_options

        # Step 5 — Run for each domain
        for t in "${TARGETS[@]}"; do
            echo ""
            echo -e "${BLUE}${BOLD}══════════════ Domain: $t ══════════════${NC}"
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
