#!/bin/bash

# ================================================================
#   WHATWEB - Full Automation Tool
#   Author: SAIMUM
# ================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
WHITE='\033[1;37m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

RESULTS_DIR="$HOME/whatweb_results"
HISTORY_FILE="$HOME/.whatweb_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo ' ██╗    ██╗██╗  ██╗ █████╗ ████████╗██╗    ██╗███████╗██████╗ '
    echo ' ██║    ██║██║  ██║██╔══██╗╚══██╔══╝██║    ██║██╔════╝██╔══██╗'
    echo ' ██║ █╗ ██║███████║███████║   ██║   ██║ █╗ ██║█████╗  ██████╔╝'
    echo ' ██║███╗██║██╔══██║██╔══██║   ██║   ██║███╗██║██╔══╝  ██╔══██╗'
    echo ' ╚███╔███╔╝██║  ██║██║  ██║   ██║   ╚███╔███╔╝███████╗██████╔╝'
    echo '  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝    ╚══╝╚══╝ ╚══════╝╚═════╝ '
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}         WhatWeb Full Automation | Web Technology Fingerprinting${NC}"
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

    if command -v whatweb &>/dev/null; then
        echo -e "  ${GREEN}[✓] whatweb${NC}"
    else
        missing+=("whatweb")
        echo -e "  ${RED}[✗] whatweb — পাওয়া যায়নি${NC}"
    fi

    for tool in curl whois dig python3; do
        command -v "$tool" &>/dev/null && \
            echo -e "  ${GREEN}[✓] $tool${NC}" || \
            echo -e "  ${YELLOW}[!] $tool — নেই${NC}"
    done

    echo ""
    echo -e "${CYAN}[*] Optional tools:${NC}"
    for opt in nikto gobuster ffuf sqlmap nuclei wpscan; do
        command -v "$opt" &>/dev/null && \
            echo -e "  ${GREEN}[✓] $opt${NC}" || \
            echo -e "  ${YELLOW}[!] $opt — নেই${NC}"
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing: ${missing[*]}${NC}"
        echo -e "${YELLOW}Install: sudo apt install whatweb  অথবা  gem install whatweb${NC}"
        exit 1
    fi

    echo ""
    local wver; wver=$(whatweb --version 2>&1 | head -1)
    echo -e "${CYAN}[*] WhatWeb: ${GREEN}$wver${NC}"
    echo ""
}

# ================================================================
# GET TARGET
# ================================================================
get_target() {
    TARGET=""; TARGET_LIST=(); TARGET_FILE=""

    echo -e "${BLUE}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║         TARGET SELECT                ║${NC}"
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo -e "  ${GREEN}1)${NC} Single URL / IP"
    echo -e "  ${GREEN}2)${NC} Multiple URLs"
    echo -e "  ${GREEN}3)${NC} File থেকে URL list"
    echo -e "  ${GREEN}4)${NC} IP Range / CIDR"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-4]: "${NC})" ttype

    case $ttype in
        1)
            read -p "$(echo -e ${WHITE}"URL / IP দিন: "${NC})" t
            [[ ! "$t" =~ ^https?:// ]] && t="http://$t"
            TARGET="${t%/}"; TARGET_LIST=("$TARGET") ;;
        2)
            echo -e "${WHITE}URLs দিন। 'done' লিখলে শেষ:${NC}"
            while true; do
                read -p "$(echo -e ${WHITE}"URL: "${NC})" t
                [[ "$t" == "done" || -z "$t" ]] && break
                [[ ! "$t" =~ ^https?:// ]] && t="http://$t"
                TARGET_LIST+=("${t%/}")
            done
            TARGET="${TARGET_LIST[0]}" ;;
        3)
            read -p "$(echo -e ${WHITE}"File path: "${NC})" TARGET_FILE
            [ ! -f "$TARGET_FILE" ] && echo -e "${RED}[!] File নেই।${NC}" && get_target && return
            TARGET=$(head -1 "$TARGET_FILE")
            [[ ! "$TARGET" =~ ^https?:// ]] && TARGET="http://$TARGET" ;;
        4)
            read -p "$(echo -e ${WHITE}"IP Range দিন (e.g. 192.168.1.0/24 বা 192.168.1.1-20): "${NC})" TARGET
            TARGET_LIST=("$TARGET") ;;
        *)
            echo -e "${RED}[!] ভুল।${NC}" && get_target && return ;;
    esac

    echo -e "  ${GREEN}[✓] Target: $TARGET${NC}"
    echo ""
}

# ================================================================
# PRE-SCAN RECON
# ================================================================
pre_scan_recon() {
    local url=$1
    local domain; domain=$(echo "$url" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)

    echo ""
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}${BOLD}   PRE-SCAN RECON  ›  $url${NC}"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    echo -e "${MAGENTA}${BOLD}┌─── WHOIS ──────────────────────────────────────────┐${NC}"
    whois "$domain" 2>/dev/null | grep -E "Registrar:|Country:|Organization:|Creation Date:|Updated Date:" | head -6 | \
        while IFS= read -r l; do echo -e "  ${WHITE}$l${NC}"; done
    echo -e "${MAGENTA}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${BLUE}${BOLD}┌─── GEO IP ──────────────────────────────────────────┐${NC}"
    local geo; geo=$(curl -s --max-time 5 "http://ip-api.com/json/$domain" 2>/dev/null)
    if echo "$geo" | grep -q '"status":"success"'; then
        local ip country region city isp lat lon
        ip=$(echo "$geo"      | grep -o '"query":"[^"]*"'      | cut -d'"' -f4)
        country=$(echo "$geo" | grep -o '"country":"[^"]*"'    | cut -d'"' -f4)
        region=$(echo "$geo"  | grep -o '"regionName":"[^"]*"' | cut -d'"' -f4)
        city=$(echo "$geo"    | grep -o '"city":"[^"]*"'       | cut -d'"' -f4)
        isp=$(echo "$geo"     | grep -o '"isp":"[^"]*"'        | cut -d'"' -f4)
        lat=$(echo "$geo"     | grep -o '"lat":[^,]*'          | cut -d':' -f2)
        lon=$(echo "$geo"     | grep -o '"lon":[^,]*'          | cut -d':' -f2)
        echo -e "  ${WHITE}IP        : ${GREEN}$ip${NC}"
        echo -e "  ${WHITE}Location  : ${GREEN}$city, $region, $country${NC}"
        echo -e "  ${WHITE}ISP       : ${GREEN}$isp${NC}"
        echo -e "  ${WHITE}Lat/Lon   : ${GREEN}$lat / $lon${NC}"
    else
        echo -e "  ${YELLOW}[!] GeoIP পাওয়া যায়নি।${NC}"
    fi
    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}┌─── HTTP HEADERS ────────────────────────────────────┐${NC}"
    local headers; headers=$(curl -s -I --max-time 8 "$url" 2>/dev/null | head -25)
    if [ -n "$headers" ]; then
        local code server powered xframe csp hsts
        code=$(echo "$headers"    | head -1)
        server=$(echo "$headers"  | grep -i "^Server:"                  | head -1)
        powered=$(echo "$headers" | grep -i "^X-Powered-By:"            | head -1)
        xframe=$(echo "$headers"  | grep -i "^X-Frame-Options:"         | head -1)
        csp=$(echo "$headers"     | grep -i "^Content-Security-Policy:" | head -1)
        hsts=$(echo "$headers"    | grep -i "^Strict-Transport-Security:"| head -1)
        echo -e "  ${WHITE}Status : ${GREEN}$code${NC}"
        [ -n "$server"  ] && echo -e "  ${WHITE}Server : ${YELLOW}$server${NC}"
        [ -n "$powered" ] && echo -e "  ${WHITE}Tech   : ${YELLOW}$powered${NC}"
        echo ""
        echo -e "  ${CYAN}Security Headers:${NC}"
        [ -n "$xframe" ] && echo -e "  ${GREEN}[✓] X-Frame-Options${NC}" || echo -e "  ${RED}[✗] X-Frame-Options — Clickjacking risk!${NC}"
        [ -n "$csp"    ] && echo -e "  ${GREEN}[✓] Content-Security-Policy${NC}" || echo -e "  ${YELLOW}[!] CSP missing${NC}"
        [ -n "$hsts"   ] && echo -e "  ${GREEN}[✓] HSTS${NC}" || echo -e "  ${YELLOW}[!] HSTS missing${NC}"
        echo ""
        echo -e "  ${CYAN}WAF Detection:${NC}"
        local waf=false
        for wh in "cf-ray" "X-Sucuri-ID" "X-WAF" "X-Firewall" "X-Mod-Security" "X-CDN"; do
            echo "$headers" | grep -qi "^$wh:" && echo -e "  ${RED}[!] WAF: $wh${NC}" && waf=true
        done
        $waf || echo -e "  ${GREEN}[✓] স্পষ্ট WAF নেই${NC}"
    fi
    echo -e "${CYAN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# SCAN MENU
# ================================================================
show_menu() {
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║                   WHATWEB SCAN OPTIONS                              ║${NC}"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ BASIC SCANS ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}1${NC}  Quick Scan (Level 1)         — fast, single request"
    echo -e "${YELLOW}║${NC} ${GREEN}2${NC}  Aggressive Scan (Level 3)    — deep fingerprinting"
    echo -e "${YELLOW}║${NC} ${GREEN}3${NC}  Stealthy Scan (Level 1)      — slow + random UA"
    echo -e "${YELLOW}║${NC} ${GREEN}4${NC}  Verbose Scan                 — সব details দেখাও"
    echo -e "${YELLOW}║${NC} ${GREEN}5${NC}  Custom Level Scan            — level 1-4 নিজে বেছে নাও"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ MULTI-TARGET ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}6${NC}  Multiple URL Scan            — একাধিক URL একসাথে"
    echo -e "${YELLOW}║${NC} ${GREEN}7${NC}  URL List File Scan           — file থেকে URLs"
    echo -e "${YELLOW}║${NC} ${GREEN}8${NC}  IP Range Scan                — CIDR / range scan"
    echo -e "${YELLOW}║${NC} ${GREEN}9${NC}  Subdomain List Scan          — subdomains fingerprint"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ OUTPUT FORMATS ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}10${NC} JSON Output Scan             — machine-readable JSON"
    echo -e "${YELLOW}║${NC} ${GREEN}11${NC} XML Output Scan              — XML format"
    echo -e "${YELLOW}║${NC} ${GREEN}12${NC} CSV Output Scan              — spreadsheet ready"
    echo -e "${YELLOW}║${NC} ${GREEN}13${NC} Brief Output                 — শুধু technology names"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ FILTERED / TARGETED ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}14${NC} CMS Detection Only           — WordPress/Joomla/Drupal"
    echo -e "${YELLOW}║${NC} ${GREEN}15${NC} Server Technology Scan       — Apache/Nginx/IIS/PHP"
    echo -e "${YELLOW}║${NC} ${GREEN}16${NC} JavaScript Framework Scan    — React/Angular/Vue/jQuery"
    echo -e "${YELLOW}║${NC} ${GREEN}17${NC} Security Headers Check       — headers analysis"
    echo -e "${YELLOW}║${NC} ${GREEN}18${NC} Login Page Detection         — auth endpoints খোঁজো"
    echo -e "${YELLOW}║${NC} ${GREEN}19${NC} Email / Contact Info Scan    — emails, phone extract"
    echo -e "${YELLOW}║${NC} ${GREEN}20${NC} Error Page Fingerprint       — 404/500 tech leak"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ ADVANCED ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}21${NC} Proxy Scan (Burp)            — Burp proxy দিয়ে"
    echo -e "${YELLOW}║${NC} ${GREEN}22${NC} Auth Scan                    — Basic/Cookie auth"
    echo -e "${YELLOW}║${NC} ${GREEN}23${NC} Custom Plugin Scan           — নির্দিষ্ট plugin দিয়ে"
    echo -e "${YELLOW}║${NC} ${GREEN}24${NC} Follow Redirect Scan         — সব redirect follow"
    echo -e "${YELLOW}║${NC} ${GREEN}25${NC} User-Agent Spoof Scan        — custom UA দিয়ে"
    echo -e "${YELLOW}║${NC} ${GREEN}26${NC} Parallel Scan                — একসাথে অনেক request"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ COMBO ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}27${NC} Smart Tech Recon             — level3 + JSON + filter"
    echo -e "${YELLOW}║${NC} ${GREEN}28${NC} All-in-One Mega Scan         — সব mode একসাথে"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${RED}0)${NC} Exit                                                               ${YELLOW}║${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ================================================================
# EXTRA OPTIONS
# ================================================================
get_extra_options() {
    THREADS_OPT="--open-timeout=10 --read-timeout=30"
    PROXY_OPT=""; UA_OPT=""; COOKIE_OPT=""; AUTH_OPT=""
    COLOR_OPT="--color=always"; FOLLOW_OPT=""

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║         EXTRA OPTIONS                ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""

    read -p "$(echo -e ${WHITE}"Threads (Enter=4): "${NC})" th
    [ -n "$th" ] && THREADS_OPT="$THREADS_OPT --max-threads=$th" || \
        THREADS_OPT="$THREADS_OPT --max-threads=4"

    read -p "$(echo -e ${WHITE}"Proxy (Enter=skip): "${NC})" px
    [ -n "$px" ] && PROXY_OPT="--proxy=$px"

    read -p "$(echo -e ${WHITE}"Custom User-Agent (Enter=default): "${NC})" ua
    [ -n "$ua" ] && UA_OPT="--user-agent='$ua'"

    read -p "$(echo -e ${WHITE}"Cookie (Enter=skip): "${NC})" cookie
    [ -n "$cookie" ] && COOKIE_OPT="--cookie='$cookie'"

    read -p "$(echo -e ${WHITE}"Follow redirects? (y/n, Enter=y): "${NC})" fr
    [[ ! "$fr" =~ ^[Nn]$ ]] && FOLLOW_OPT="--follow-redirect=never" || FOLLOW_OPT=""

    echo ""
}

# ================================================================
# RUN WHATWEB CORE
# ================================================================
run_whatweb() {
    local label=$1 extra=$2 url="${3:-$TARGET}"

    SCAN_LABEL="$label"
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$url" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/${label// /_}_${safe}_${ts}.txt"
    OUTPUT_JSON="$RESULTS_DIR/${label// /_}_${safe}_${ts}.json"

    local cmd="whatweb $url $THREADS_OPT $PROXY_OPT $UA_OPT $COOKIE_OPT $AUTH_OPT $COLOR_OPT $FOLLOW_OPT --log-brief='$OUTPUT_FILE' $extra"

    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}Scan Type : ${YELLOW}${BOLD}$label${NC}"
    echo -e "  ${WHITE}Target    : ${GREEN}${BOLD}$url${NC}"
    echo -e "  ${WHITE}Output    : ${CYAN}$OUTPUT_FILE${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] Scan শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    echo ""
    echo -e "${GREEN}${BOLD}[*] WhatWeb চালু হচ্ছে...${NC}"
    echo ""

    eval "$cmd" 2>&1 | tee /tmp/whatweb_live_$$.txt
    cat /tmp/whatweb_live_$$.txt >> "$OUTPUT_FILE"
    rm -f /tmp/whatweb_live_$$.txt

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Scan সম্পন্ন!${NC}"
    echo ""

    bangla_analysis "$OUTPUT_FILE" "$url"
    suggest_next_tool "$OUTPUT_FILE" "$url"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 1 — QUICK (LEVEL 1)
# ================================================================
mode_quick() {
    run_whatweb "Quick Scan L1" "-a 1"
}

# ================================================================
# MODE 2 — AGGRESSIVE (LEVEL 3)
# ================================================================
mode_aggressive() {
    echo -e "${YELLOW}[!] Level 3 scan অনেক request পাঠায় — IDS trigger হতে পারে।${NC}"
    run_whatweb "Aggressive Scan L3" "-a 3"
}

# ================================================================
# MODE 3 — STEALTHY
# ================================================================
mode_stealthy() {
    local random_uas=(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15"
        "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0"
        "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15"
    )
    local rand_ua="${random_uas[$RANDOM % ${#random_uas[@]}]}"
    run_whatweb "Stealthy Scan" "-a 1 --user-agent='$rand_ua'"
}

# ================================================================
# MODE 4 — VERBOSE
# ================================================================
mode_verbose() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/verbose_${safe}_${ts}.txt"
    SCAN_LABEL="Verbose Scan"

    echo ""
    echo -e "${GREEN}${BOLD}[*] Verbose scan শুরু হচ্ছে...${NC}"
    echo ""

    whatweb "$TARGET" -a 3 -v $THREADS_OPT $PROXY_OPT $UA_OPT $COOKIE_OPT 2>&1 | tee "$OUTPUT_FILE"

    echo ""
    bangla_analysis "$OUTPUT_FILE" "$TARGET"
    suggest_next_tool "$OUTPUT_FILE" "$TARGET"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 5 — CUSTOM LEVEL
# ================================================================
mode_custom_level() {
    echo -e "${CYAN}Aggression Level:${NC}"
    echo -e "  ${GREEN}1)${NC} Stealthy     — 1 request per host"
    echo -e "  ${GREEN}2)${NC} Unused       — "
    echo -e "  ${GREEN}3)${NC} Aggressive   — request per path"
    echo -e "  ${GREEN}4)${NC} Heavy        — request per file extension"
    read -p "$(echo -e ${YELLOW}"Level [1-4]: "${NC})" lvl
    [[ ! "$lvl" =~ ^[1-4]$ ]] && lvl=1
    run_whatweb "Custom Level $lvl" "-a $lvl"
}

# ================================================================
# MODE 6 — MULTIPLE URLS
# ================================================================
mode_multiple_urls() {
    if [ ${#TARGET_LIST[@]} -gt 1 ]; then
        for url in "${TARGET_LIST[@]}"; do
            echo ""
            echo -e "${CYAN}${BOLD}══════════════ $url ══════════════${NC}"
            run_whatweb "Multi-URL" "-a 1" "$url"
        done
    else
        echo -e "${YELLOW}[!] Multiple URL mode এ target select করুন (option 2)।${NC}"
    fi
}

# ================================================================
# MODE 7 — URL FILE SCAN
# ================================================================
mode_url_file() {
    local file="${TARGET_FILE}"
    [ -z "$file" ] && read -p "$(echo -e ${WHITE}"URL file path: "${NC})" file
    [ ! -f "$file" ] && echo -e "${RED}[!] File নেই।${NC}" && return

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/url_file_scan_${ts}.txt"
    SCAN_LABEL="URL File Scan"

    echo ""
    echo -e "${GREEN}[*] File-based scan শুরু হচ্ছে: $file${NC}"
    echo ""

    # Process each URL
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        [[ ! "$url" =~ ^https?:// ]] && url="http://$url"
        echo -e "${CYAN}[*] Scanning: $url${NC}"
        whatweb "$url" -a 1 $THREADS_OPT $PROXY_OPT 2>&1 | tee -a "$OUTPUT_FILE"
        echo ""
    done < "$file"

    bangla_analysis "$OUTPUT_FILE" "$TARGET"
    suggest_next_tool "$OUTPUT_FILE" "$TARGET"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 8 — IP RANGE SCAN
# ================================================================
mode_ip_range() {
    local range="${TARGET}"
    [ -z "$range" ] && read -p "$(echo -e ${WHITE}"IP Range (e.g. 192.168.1.0/24): "${NC})" range

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/ip_range_${ts}.txt"
    SCAN_LABEL="IP Range Scan"

    echo ""
    echo -e "${YELLOW}[!] IP Range scan অনেক সময় নিতে পারে।${NC}"
    echo -e "${GREEN}[*] Scanning range: $range${NC}"
    echo ""

    whatweb "$range" -a 1 $THREADS_OPT $PROXY_OPT \
        --log-brief="$OUTPUT_FILE" 2>&1

    bangla_analysis "$OUTPUT_FILE" "$range"
    suggest_next_tool "$OUTPUT_FILE" "$range"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 9 — SUBDOMAIN LIST
# ================================================================
mode_subdomain_scan() {
    local base; base=$(echo "$TARGET" | sed 's|https\?://||' | cut -d'/' -f1)

    echo -e "${WHITE}Subdomains দিন (comma-separated, e.g. www,api,dev,mail):${NC}"
    read -p "$(echo -e ${WHITE}"Subdomains: "${NC})" subs

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/subdomain_scan_${ts}.txt"
    SCAN_LABEL="Subdomain Scan"

    for sub in $(echo "$subs" | tr ',' ' '); do
        local sub_url="http://${sub}.${base}"
        echo ""
        echo -e "${CYAN}[*] Scanning: $sub_url${NC}"
        whatweb "$sub_url" -a 1 $THREADS_OPT $PROXY_OPT 2>&1 | tee -a "$OUTPUT_FILE"
    done

    echo ""
    bangla_analysis "$OUTPUT_FILE" "$TARGET"
    suggest_next_tool "$OUTPUT_FILE" "$TARGET"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 10 — JSON OUTPUT
# ================================================================
mode_json_output() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/json_scan_${safe}_${ts}.json"
    SCAN_LABEL="JSON Output Scan"

    echo ""
    echo -e "${GREEN}[*] JSON output scan শুরু হচ্ছে...${NC}"
    echo ""

    whatweb "$TARGET" -a 3 $THREADS_OPT $PROXY_OPT \
        --log-json="$OUTPUT_FILE" 2>&1

    echo ""
    echo -e "${GREEN}[✓] JSON output: $OUTPUT_FILE${NC}"

    # Parse and display JSON
    if command -v python3 &>/dev/null && [ -f "$OUTPUT_FILE" ]; then
        echo ""
        echo -e "${CYAN}[*] JSON parsed results:${NC}"
        python3 -c "
import json, sys
try:
    with open('$OUTPUT_FILE') as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    data = json.loads(line)
                    target = data.get('target', '')
                    plugins = data.get('plugins', {})
                    print(f'  Target: {target}')
                    for name, info in plugins.items():
                        version = info.get('version', [])
                        string = info.get('string', [])
                        v = version[0] if version else (string[0] if string else '')
                        print(f'    [{name}] {v}')
                    print()
                except:
                    pass
except Exception as e:
    print(f'Parse error: {e}')
" 2>/dev/null
    fi

    bangla_analysis_raw "$TARGET"
    suggest_next_tool "$OUTPUT_FILE" "$TARGET"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 11 — XML OUTPUT
# ================================================================
mode_xml_output() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/xml_scan_${safe}_${ts}.xml"
    SCAN_LABEL="XML Output Scan"

    echo ""
    echo -e "${GREEN}[*] XML output scan শুরু হচ্ছে...${NC}"
    whatweb "$TARGET" -a 3 $THREADS_OPT $PROXY_OPT \
        --log-xml="$OUTPUT_FILE" 2>&1
    echo -e "${GREEN}[✓] XML output: $OUTPUT_FILE${NC}"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 12 — CSV OUTPUT
# ================================================================
mode_csv_output() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/csv_scan_${safe}_${ts}.csv"
    SCAN_LABEL="CSV Output Scan"

    echo ""
    echo -e "${GREEN}[*] CSV output scan শুরু হচ্ছে...${NC}"
    whatweb "$TARGET" -a 3 $THREADS_OPT $PROXY_OPT \
        --log-csv="$OUTPUT_FILE" 2>&1
    echo -e "${GREEN}[✓] CSV output: $OUTPUT_FILE${NC}"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 13 — BRIEF OUTPUT
# ================================================================
mode_brief() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/brief_${safe}_${ts}.txt"
    SCAN_LABEL="Brief Scan"

    echo ""
    echo -e "${GREEN}[*] Brief scan শুরু হচ্ছে...${NC}"
    echo ""
    whatweb "$TARGET" -a 1 --log-brief="$OUTPUT_FILE" 2>&1
    echo ""
    echo -e "${GREEN}[✓] Brief output: $OUTPUT_FILE${NC}"
    cat "$OUTPUT_FILE" | while IFS= read -r l; do echo -e "  ${CYAN}▸ $l${NC}"; done
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 14 — CMS DETECTION
# ================================================================
mode_cms_detect() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/cms_detect_${safe}_${ts}.txt"
    SCAN_LABEL="CMS Detection"

    echo ""
    echo -e "${GREEN}[*] CMS detection শুরু হচ্ছে...${NC}"
    echo ""

    # Level 3 scan focused on CMS
    whatweb "$TARGET" -a 3 $THREADS_OPT $PROXY_OPT \
        --log-brief="$OUTPUT_FILE" 2>&1

    echo ""
    echo -e "${CYAN}${BOLD}━━━ CMS Detection Result ━━━${NC}"

    local cms_found=""
    if [ -f "$OUTPUT_FILE" ]; then
        if grep -qi "WordPress" "$OUTPUT_FILE"; then
            cms_found="WordPress"
            echo -e "  ${RED}${BOLD}[✓] CMS: WordPress detected!${NC}"
            local wp_ver; wp_ver=$(grep -oiE "WordPress\[([0-9.]+)\]" "$OUTPUT_FILE" | head -1)
            [ -n "$wp_ver" ] && echo -e "  ${YELLOW}Version: $wp_ver${NC}"
        fi
        if grep -qi "Joomla" "$OUTPUT_FILE"; then
            cms_found="Joomla"
            echo -e "  ${RED}${BOLD}[✓] CMS: Joomla detected!${NC}"
        fi
        if grep -qi "Drupal" "$OUTPUT_FILE"; then
            cms_found="Drupal"
            echo -e "  ${RED}${BOLD}[✓] CMS: Drupal detected!${NC}"
        fi
        if grep -qi "Magento" "$OUTPUT_FILE"; then
            cms_found="Magento"
            echo -e "  ${RED}${BOLD}[✓] CMS: Magento detected!${NC}"
        fi
        if grep -qi "Shopify" "$OUTPUT_FILE"; then
            cms_found="Shopify"
            echo -e "  ${CYAN}[✓] Platform: Shopify detected!${NC}"
        fi
        if grep -qi "Wix\|Squarespace\|Webflow" "$OUTPUT_FILE"; then
            echo -e "  ${CYAN}[✓] Website builder detected!${NC}"
        fi
        [ -z "$cms_found" ] && echo -e "  ${YELLOW}[!] পরিচিত CMS পাওয়া যায়নি।${NC}"
    fi

    bangla_analysis "$OUTPUT_FILE" "$TARGET"
    suggest_next_tool "$OUTPUT_FILE" "$TARGET"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 15 — SERVER TECH SCAN
# ================================================================
mode_server_tech() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/server_tech_${safe}_${ts}.txt"
    SCAN_LABEL="Server Tech Scan"

    echo ""
    echo -e "${GREEN}[*] Server technology fingerprinting শুরু হচ্ছে...${NC}"
    echo ""

    whatweb "$TARGET" -a 3 $THREADS_OPT $PROXY_OPT 2>&1 | tee "$OUTPUT_FILE"

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Server Technologies ━━━${NC}"

    local techs=("Apache" "Nginx" "IIS" "PHP" "Python" "Ruby" "Node.js" "ASP.NET" "Java" "Tomcat" "OpenSSL" "mod_ssl")
    for tech in "${techs[@]}"; do
        if grep -qi "$tech" "$OUTPUT_FILE" 2>/dev/null; then
            local ver; ver=$(grep -oiE "${tech}\[([^\]]*)\]" "$OUTPUT_FILE" | head -1)
            echo -e "  ${GREEN}[✓] $tech${NC} ${DIM}$ver${NC}"
        fi
    done

    echo ""
    bangla_analysis "$OUTPUT_FILE" "$TARGET"
    suggest_next_tool "$OUTPUT_FILE" "$TARGET"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 16 — JS FRAMEWORK SCAN
# ================================================================
mode_js_framework() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/js_framework_${safe}_${ts}.txt"
    SCAN_LABEL="JS Framework Scan"

    echo ""
    echo -e "${GREEN}[*] JavaScript framework detection শুরু হচ্ছে...${NC}"
    echo ""

    whatweb "$TARGET" -a 3 $THREADS_OPT $PROXY_OPT 2>&1 | tee "$OUTPUT_FILE"

    # Also check page source for JS frameworks
    echo ""
    echo -e "${CYAN}[*] Page source থেকে JS framework check:${NC}"
    local page; page=$(curl -s --max-time 15 "$TARGET" 2>/dev/null)

    local js_frameworks=("React" "Angular" "Vue.js" "jQuery" "Bootstrap" "Backbone.js" "Ember.js" "Next.js" "Nuxt.js" "Svelte" "Alpine.js" "Tailwind")
    for fw in "${js_frameworks[@]}"; do
        if echo "$page" | grep -qi "$fw"; then
            echo -e "  ${GREEN}[✓] $fw detected${NC}"
            echo "JS Framework: $fw" >> "$OUTPUT_FILE"
        fi
    done

    echo ""
    bangla_analysis "$OUTPUT_FILE" "$TARGET"
    suggest_next_tool "$OUTPUT_FILE" "$TARGET"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 17 — SECURITY HEADERS
# ================================================================
mode_security_headers() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/sec_headers_${safe}_${ts}.txt"
    SCAN_LABEL="Security Headers"

    echo ""
    echo -e "${GREEN}[*] Security headers analysis শুরু হচ্ছে...${NC}"
    echo ""

    local headers; headers=$(curl -s -I --max-time 10 "$TARGET" 2>/dev/null)

    {
        echo "Security Headers Analysis: $TARGET"
        echo "Date: $(date)"
        echo "=============================="
        echo ""

        echo "=== WhatWeb Scan ==="
        whatweb "$TARGET" -a 1 $THREADS_OPT 2>/dev/null
        echo ""

        echo "=== Security Headers ==="
        local score=0 total=8

        local h_list=(
            "Strict-Transport-Security:HSTS:enforce HTTPS"
            "Content-Security-Policy:CSP:prevent XSS"
            "X-Frame-Options:Clickjacking protection:prevent iframe embedding"
            "X-Content-Type-Options:MIME sniffing:prevent content type sniffing"
            "Referrer-Policy:Referrer control:control referrer info"
            "Permissions-Policy:Feature policy:control browser features"
            "X-XSS-Protection:XSS filter:browser XSS protection"
            "Cache-Control:Cache control:prevent sensitive data caching"
        )

        for entry in "${h_list[@]}"; do
            local hname; hname=$(echo "$entry" | cut -d':' -f1)
            local hlabel; hlabel=$(echo "$entry" | cut -d':' -f2)
            local hdesc; hdesc=$(echo "$entry" | cut -d':' -f3)
            if echo "$headers" | grep -qi "^$hname:"; then
                local val; val=$(echo "$headers" | grep -i "^$hname:" | head -1)
                echo -e "  ${GREEN}[✓] $hname${NC}"
                echo -e "     ${DIM}$val${NC}"
                echo "[PASS] $hname: $val" >> "$OUTPUT_FILE"
                score=$((score+1))
            else
                echo -e "  ${RED}[✗] $hname MISSING — $hdesc${NC}"
                echo "[FAIL] $hname: MISSING" >> "$OUTPUT_FILE"
            fi
        done

        echo ""
        echo "Security Score: $score/$total"

    } | tee -a "$OUTPUT_FILE"

    echo ""
    bangla_analysis "$OUTPUT_FILE" "$TARGET"
    suggest_next_tool "$OUTPUT_FILE" "$TARGET"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 18 — LOGIN DETECTION
# ================================================================
mode_login_detect() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/login_detect_${safe}_${ts}.txt"
    SCAN_LABEL="Login Detection"

    echo ""
    echo -e "${GREEN}[*] Login page detection শুরু হচ্ছে...${NC}"
    echo ""

    whatweb "$TARGET" -a 3 $THREADS_OPT $PROXY_OPT 2>&1 | tee "$OUTPUT_FILE"

    echo ""
    echo -e "${CYAN}[*] Common login paths check করা হচ্ছে...${NC}"

    local login_paths=("/login" "/signin" "/admin" "/wp-login.php" "/administrator" "/user/login" "/auth/login" "/account/login" "/portal")

    for path in "${login_paths[@]}"; do
        local url="${TARGET}${path}"
        local code; code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 "$url" 2>/dev/null)
        if [ "$code" == "200" ] || [ "$code" == "301" ] || [ "$code" == "302" ]; then
            echo -e "  ${RED}[✓] $code — $url${NC}"
            echo "LOGIN FOUND $code: $url" >> "$OUTPUT_FILE"
        fi
    done

    echo ""
    bangla_analysis "$OUTPUT_FILE" "$TARGET"
    suggest_next_tool "$OUTPUT_FILE" "$TARGET"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 19 — EMAIL/CONTACT EXTRACT
# ================================================================
mode_email_extract() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/email_extract_${safe}_${ts}.txt"
    SCAN_LABEL="Email Extraction"

    echo ""
    echo -e "${GREEN}[*] Email/Contact info extraction শুরু হচ্ছে...${NC}"
    echo ""

    # WhatWeb scan
    whatweb "$TARGET" -a 1 $THREADS_OPT 2>/dev/null | tee "$OUTPUT_FILE"

    # Email extraction from page
    echo ""
    echo -e "${CYAN}[*] Page source থেকে emails extract করা হচ্ছে...${NC}"
    local page; page=$(curl -s --max-time 15 "$TARGET" 2>/dev/null)

    local emails; emails=$(echo "$page" | grep -oiE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' | sort -u)
    local phones; phones=$(echo "$page" | grep -oiE '(\+?[0-9]{1,3}[-. ]?)?\(?[0-9]{3}\)?[-. ]?[0-9]{3}[-. ]?[0-9]{4}' | sort -u | head -10)

    if [ -n "$emails" ]; then
        echo -e "${GREEN}[✓] Emails found:${NC}"
        echo "$emails" | while IFS= read -r em; do
            echo -e "  ${GREEN}▸ $em${NC}"
            echo "EMAIL: $em" >> "$OUTPUT_FILE"
        done
    else
        echo -e "  ${YELLOW}[!] কোনো email পাওয়া যায়নি।${NC}"
    fi

    if [ -n "$phones" ]; then
        echo ""
        echo -e "${GREEN}[✓] Phone numbers:${NC}"
        echo "$phones" | while IFS= read -r ph; do
            echo -e "  ${GREEN}▸ $ph${NC}"
            echo "PHONE: $ph" >> "$OUTPUT_FILE"
        done
    fi

    echo ""
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 20 — ERROR PAGE FINGERPRINT
# ================================================================
mode_error_fingerprint() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/error_fp_${safe}_${ts}.txt"
    SCAN_LABEL="Error Page Fingerprint"

    echo ""
    echo -e "${GREEN}[*] Error page fingerprinting শুরু হচ্ছে...${NC}"
    echo ""

    # Check various error pages
    local test_paths=("/thispagedoesnotexist_12345" "/admin/../../../etc/passwd" "/.git/config" "/nonexistent.php")

    for path in "${test_paths[@]}"; do
        local url="${TARGET}${path}"
        local resp; resp=$(curl -s --max-time 8 "$url" 2>/dev/null | head -50)
        local code; code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 "$url" 2>/dev/null)

        echo -e "${CYAN}[*] $code — $url${NC}"

        # Tech detection from error page
        local techs=("Apache" "Nginx" "IIS" "PHP" "Python" "Ruby" "Tomcat" "Spring" "Django" "Laravel" "Express")
        for t in "${techs[@]}"; do
            echo "$resp" | grep -qi "$t" && echo -e "  ${YELLOW}→ $t leaked in error page!${NC}" && \
                echo "TECH LEAK in error: $t at $url" >> "$OUTPUT_FILE"
        done

        # Stack trace / debug info
        if echo "$resp" | grep -qiE "stack trace|debug|exception|traceback|at line|syntax error"; then
            echo -e "  ${RED}→ Debug info / Stack trace leaked!${NC}"
            echo "DEBUG LEAK at: $url" >> "$OUTPUT_FILE"
        fi
    done

    echo ""
    whatweb "$TARGET" -a 1 $THREADS_OPT 2>/dev/null | tee -a "$OUTPUT_FILE"
    echo ""
    bangla_analysis "$OUTPUT_FILE" "$TARGET"
    suggest_next_tool "$OUTPUT_FILE" "$TARGET"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 21 — PROXY SCAN
# ================================================================
mode_proxy_scan() {
    read -p "$(echo -e ${WHITE}"Proxy (e.g. http://127.0.0.1:8080): "${NC})" proxy
    [ -z "$proxy" ] && proxy="http://127.0.0.1:8080"
    PROXY_OPT="--proxy=$proxy"
    run_whatweb "Proxy Scan" "-a 3"
    PROXY_OPT=""
}

# ================================================================
# MODE 22 — AUTH SCAN
# ================================================================
mode_auth_scan() {
    echo -e "${CYAN}Auth type:${NC}"
    echo -e "  ${GREEN}1)${NC} Basic Auth  ${GREEN}2)${NC} Cookie  ${GREEN}3)${NC} Bearer Token"
    read -p "$(echo -e ${YELLOW}"[1-3]: "${NC})" ach

    case $ach in
        1)
            read -p "$(echo -e ${WHITE}"User: "${NC})" u
            read -p "$(echo -e ${WHITE}"Pass: "${NC})" p
            AUTH_OPT="--user=$u:$p" ;;
        2)
            read -p "$(echo -e ${WHITE}"Cookie: "${NC})" ck
            COOKIE_OPT="--cookie='$ck'" ;;
        3)
            read -p "$(echo -e ${WHITE}"Token: "${NC})" tok
            UA_OPT="--header='Authorization: Bearer $tok'" ;;
    esac

    run_whatweb "Auth Scan" "-a 3"
    AUTH_OPT=""; COOKIE_OPT=""; UA_OPT=""
}

# ================================================================
# MODE 23 — CUSTOM PLUGIN
# ================================================================
mode_custom_plugin() {
    echo ""
    echo -e "${CYAN}Available plugins দেখতে: whatweb --list-plugins${NC}"
    read -p "$(echo -e ${WHITE}"Plugin name(s) দিন (comma-separated): "${NC})" plugins
    [ -z "$plugins" ] && echo -e "${RED}[!] Plugin দাও।${NC}" && return
    run_whatweb "Custom Plugin ($plugins)" "-a 3 --plugins=$plugins"
}

# ================================================================
# MODE 24 — FOLLOW REDIRECT
# ================================================================
mode_follow_redirect() {
    FOLLOW_OPT=""  # Allow following
    run_whatweb "Follow Redirect Scan" "-a 3 --follow-redirect=always"
    FOLLOW_OPT="--follow-redirect=never"
}

# ================================================================
# MODE 25 — UA SPOOF
# ================================================================
mode_ua_spoof() {
    echo -e "${CYAN}User-Agent type:${NC}"
    echo -e "  ${GREEN}1)${NC} Googlebot  ${GREEN}2)${NC} Mobile (iPhone)  ${GREEN}3)${NC} IE11  ${GREEN}4)${NC} Custom"
    read -p "$(echo -e ${YELLOW}"[1-4]: "${NC})" uach

    local ua=""
    case $uach in
        1) ua="Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" ;;
        2) ua="Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148" ;;
        3) ua="Mozilla/5.0 (Windows NT 10.0; Trident/7.0; rv:11.0) like Gecko" ;;
        4) read -p "$(echo -e ${WHITE}"Custom UA: "${NC})" ua ;;
    esac

    UA_OPT="--user-agent='$ua'"
    run_whatweb "UA Spoof" "-a 3"
    UA_OPT=""
}

# ================================================================
# MODE 26 — PARALLEL SCAN
# ================================================================
mode_parallel() {
    read -p "$(echo -e ${WHITE}"Parallel threads (Enter=10): "${NC})" threads
    [ -z "$threads" ] && threads=10
    THREADS_OPT="--max-threads=$threads --open-timeout=10 --read-timeout=30"
    run_whatweb "Parallel Scan (t=$threads)" "-a 1"
}

# ================================================================
# MODE 27 — SMART TECH RECON
# ================================================================
mode_smart_recon() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/smart_recon_${safe}_${ts}.txt"
    SCAN_LABEL="Smart Tech Recon"

    echo ""
    echo -e "${CYAN}${BOLD}Smart Tech Recon — ৩ ধাপে:${NC}"
    echo -e "  ${WHITE}1: Level 1 quick  2: Level 3 deep  3: Security headers${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    echo -e "${CYAN}━━━ Phase 1: Quick Fingerprint ━━━${NC}"
    whatweb "$TARGET" -a 1 $THREADS_OPT $PROXY_OPT 2>&1 | tee "$OUTPUT_FILE"

    echo ""
    echo -e "${CYAN}━━━ Phase 2: Deep Fingerprint ━━━${NC}"
    whatweb "$TARGET" -a 3 $THREADS_OPT $PROXY_OPT 2>&1 | tee -a "$OUTPUT_FILE"

    echo ""
    echo -e "${CYAN}━━━ Phase 3: JSON Output ━━━${NC}"
    whatweb "$TARGET" -a 3 $THREADS_OPT --log-json="${OUTPUT_FILE%.txt}.json" 2>/dev/null
    echo -e "  ${GREEN}[✓] JSON saved: ${OUTPUT_FILE%.txt}.json${NC}"

    echo ""
    echo -e "${CYAN}━━━ Phase 4: Security Headers ━━━${NC}"
    local headers; headers=$(curl -s -I --max-time 10 "$TARGET" 2>/dev/null)
    local sec_hdrs=("Strict-Transport-Security" "Content-Security-Policy" "X-Frame-Options" "X-Content-Type-Options")
    for h in "${sec_hdrs[@]}"; do
        echo "$headers" | grep -qi "^$h:" && \
            echo -e "  ${GREEN}[✓] $h${NC}" || \
            echo -e "  ${RED}[✗] $h MISSING${NC}"
        echo "HEADER_CHECK $h: $(echo "$headers" | grep -qi "^$h:" && echo PRESENT || echo MISSING)" >> "$OUTPUT_FILE"
    done

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Smart Recon সম্পন্ন!${NC}"
    bangla_analysis "$OUTPUT_FILE" "$TARGET"
    suggest_next_tool "$OUTPUT_FILE" "$TARGET"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 28 — ALL IN ONE MEGA
# ================================================================
mode_allinone() {
    echo ""
    echo -e "${RED}${BOLD}[!] All-in-One Mega Scan — সব mode একসাথে।${NC}"
    read -p "$(echo -e ${YELLOW}"[?] শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/mega_scan_${safe}_${ts}.txt"
    SCAN_LABEL="All-in-One Mega"

    {
        echo "================================================================"
        echo "  WhatWeb ALL-IN-ONE SCAN — SAIMUM"
        echo "  Target: $TARGET"
        echo "  Date: $(date)"
        echo "================================================================"
    } > "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 1: Quick Scan (L1) ━━━${NC}"
    whatweb "$TARGET" -a 1 $THREADS_OPT $PROXY_OPT 2>&1 | tee -a "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 2: Aggressive Scan (L3) ━━━${NC}"
    whatweb "$TARGET" -a 3 $THREADS_OPT $PROXY_OPT 2>&1 | tee -a "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 3: JSON Export ━━━${NC}"
    whatweb "$TARGET" -a 3 --log-json="${OUTPUT_FILE%.txt}.json" 2>/dev/null
    echo "JSON: ${OUTPUT_FILE%.txt}.json" >> "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 4: Email Extraction ━━━${NC}"
    local page; page=$(curl -s --max-time 15 "$TARGET" 2>/dev/null)
    local emails; emails=$(echo "$page" | grep -oiE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' | sort -u)
    [ -n "$emails" ] && echo "$emails" | while IFS= read -r em; do
        echo -e "  ${GREEN}EMAIL: $em${NC}"
        echo "EMAIL: $em" >> "$OUTPUT_FILE"
    done

    echo -e "${CYAN}━━━ Phase 5: Security Headers ━━━${NC}"
    local headers; headers=$(curl -s -I --max-time 10 "$TARGET" 2>/dev/null)
    local score=0
    for h in "Strict-Transport-Security" "Content-Security-Policy" "X-Frame-Options" "X-Content-Type-Options" "Referrer-Policy"; do
        if echo "$headers" | grep -qi "^$h:"; then
            echo -e "  ${GREEN}[✓] $h${NC}"; score=$((score+1))
        else
            echo -e "  ${RED}[✗] $h MISSING${NC}"
        fi
        echo "HEADER $h: $(echo "$headers" | grep -qi "^$h:" && echo OK || echo MISSING)" >> "$OUTPUT_FILE"
    done
    echo "Security Header Score: $score/5" >> "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 6: CMS Check ━━━${NC}"
    local cms_list=("WordPress" "Joomla" "Drupal" "Magento" "Shopify" "Laravel" "Django")
    for cms in "${cms_list[@]}"; do
        if grep -qi "$cms" "$OUTPUT_FILE" 2>/dev/null || \
           whatweb "$TARGET" -a 1 2>/dev/null | grep -qi "$cms"; then
            echo -e "  ${RED}[✓] CMS/Framework: $cms detected!${NC}"
            echo "CMS: $cms" >> "$OUTPUT_FILE"
        fi
    done

    echo ""
    echo -e "${GREEN}${BOLD}[✓] All-in-One Mega Scan সম্পন্ন!${NC}"
    bangla_analysis "$OUTPUT_FILE" "$TARGET"
    suggest_next_tool "$OUTPUT_FILE" "$TARGET"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# BANGLA ANALYSIS
# ================================================================
bangla_analysis() {
    local outfile=$1 url=$2

    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় স্ক্যান রিপোর্ট বিশ্লেষণ                      ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -f "$outfile" ] || [ ! -s "$outfile" ]; then
        echo -e "  ${YELLOW}[!] Output ফাঁকা।${NC}"; echo ""; return
    fi

    local critical=0 high=0 medium=0 low=0

    # CMS Detection
    if grep -qi "WordPress" "$outfile" 2>/dev/null; then
        local wp_ver; wp_ver=$(grep -oiE "WordPress[^,\]]*" "$outfile" | head -1)
        echo -e "  ${RED}${BOLD}🔧 WordPress Detected: $wp_ver${NC}"
        echo -e "     ${WHITE}→ WPScan দিয়ে plugins, themes, users enumerate করুন।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH (outdated হলে CRITICAL)${NC}"; echo ""
        high=$((high+1))
    fi
    if grep -qi "Joomla" "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}🔧 Joomla Detected!${NC}"
        echo -e "     ${WHITE}→ Joomscan বা manual audit করুন।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""; high=$((high+1))
    fi
    if grep -qi "Drupal" "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}🔧 Drupal Detected!${NC}"
        echo -e "     ${WHITE}→ Droopescan বা Nuclei Drupal templates ব্যবহার করুন।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""; high=$((high+1))
    fi

    # Outdated tech
    if grep -qiE "PHP/[45]\.|PHP/7\.[01]" "$outfile" 2>/dev/null; then
        local php_ver; php_ver=$(grep -oiE "PHP/[0-9.]+" "$outfile" | head -1)
        echo -e "  ${RED}${BOLD}⚠ Outdated PHP: $php_ver${NC}"
        echo -e "     ${WHITE}→ End-of-life PHP version — known vulnerabilities আছে।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""; critical=$((critical+1))
    fi
    if grep -qiE "Apache/1\.|Apache/2\.[0-3]" "$outfile" 2>/dev/null; then
        local ap_ver; ap_ver=$(grep -oiE "Apache/[0-9.]+" "$outfile" | head -1)
        echo -e "  ${YELLOW}${BOLD}⚠ Outdated Apache: $ap_ver${NC}"
        echo -e "     ${WHITE}→ পুরনো Apache — known exploits থাকতে পারে।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""; high=$((high+1))
    fi
    if grep -qiE "IIS/[0-7]\." "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}⚠ Outdated IIS Detected!${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""; critical=$((critical+1))
    fi

    # Debug info leak
    if grep -qi "DEBUG LEAK\|stack trace\|X-Powered-By" "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}ℹ Technology Information Leaked via Headers${NC}"
        echo -e "     ${WHITE}→ Server technology error page বা header এ দেখা যাচ্ছে।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # Login found
    if grep -qi "LOGIN FOUND" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}🔑 Login Pages Found!${NC}"
        grep "LOGIN FOUND" "$outfile" | while IFS= read -r l; do echo -e "  ${YELLOW}▸ $l${NC}"; done
        echo -e "     ${WHITE}→ Brute force বা default credential test করুন।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Email found
    if grep -qi "^EMAIL:" "$outfile" 2>/dev/null; then
        low=$((low+1))
        echo -e "  ${BLUE}${BOLD}📧 Emails Found:${NC}"
        grep "^EMAIL:" "$outfile" | while IFS= read -r l; do echo -e "  ${BLUE}▸ $l${NC}"; done
        echo -e "     ${WHITE}→ Social engineering বা phishing এ ব্যবহার হতে পারে।${NC}"
        echo -e "     ${BLUE}→ ঝুঁকি: LOW/INFO${NC}"; echo ""
    fi

    # Security headers missing
    local missing_count; missing_count=$(grep -c "MISSING" "$outfile" 2>/dev/null || echo 0)
    if [ "$missing_count" -gt 2 ]; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}🛡️  Security Headers Missing ($missing_count টি)${NC}"
        echo -e "     ${WHITE}→ XSS, Clickjacking, MIME sniffing protection নেই।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # Risk summary
    echo -e "  ${CYAN}${BOLD}━━━ সামগ্রিক ঝুঁকি মূল্যায়ন ━━━${NC}"
    echo -e "  ${RED}   Critical : $critical টি${NC}"
    echo -e "  ${YELLOW}   High     : $high টি${NC}"
    echo -e "  ${CYAN}   Medium   : $medium টি${NC}"
    echo -e "  ${GREEN}   Low      : $low টি${NC}"
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
# BANGLA ANALYSIS (raw — no file)
# ================================================================
bangla_analysis_raw() {
    local url=$1
    echo -e "  ${CYAN}[*] Scan সম্পন্ন — JSON file এ বিস্তারিত দেখুন।${NC}"
}

# ================================================================
# NEXT TOOL SUGGESTION
# ================================================================
suggest_next_tool() {
    local outfile=$1 url=$2

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Tool এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if grep -qi "WordPress" "$outfile" 2>/dev/null; then
        echo -e "  ${BLUE}${BOLD}🔧 WPScan${NC} — WordPress Deep Audit"
        echo -e "     ${CYAN}কমান্ড: wpscan --url $url --enumerate u,vp,ap --api-token TOKEN${NC}"; echo ""
    fi

    if grep -qi "PHP\|Apache\|Nginx\|IIS" "$outfile" 2>/dev/null; then
        echo -e "  ${WHITE}${BOLD}🌐 Nikto${NC} — Web Server Vulnerability Scan"
        echo -e "     ${CYAN}কমান্ড: nikto -h $url${NC}"; echo ""
    fi

    echo -e "  ${GREEN}${BOLD}🔍 Dirsearch${NC} — Directory & File Discovery"
    echo -e "     ${CYAN}কমান্ড: dirsearch -u $url -e php,html,js,txt,bak${NC}"; echo ""

    echo -e "  ${MAGENTA}${BOLD}🔍 Nuclei${NC} — CVE & Vulnerability Scan"
    echo -e "     ${CYAN}কমান্ড: nuclei -u $url -t . -severity medium,high,critical${NC}"; echo ""

    if grep -qi "LOGIN FOUND\|login\|signin" "$outfile" 2>/dev/null; then
        echo -e "  ${YELLOW}${BOLD}🔑 Hydra${NC} — Login Brute Force"
        echo -e "     ${CYAN}কমান্ড: hydra -L users.txt -P rockyou.txt $url http-post-form '/login:u=^USER^&p=^PASS^:F=wrong'${NC}"; echo ""
    fi

    if grep -qiE "PHP|MySQ|API" "$outfile" 2>/dev/null; then
        echo -e "  ${GREEN}${BOLD}💉 SQLmap${NC} — SQL Injection Test"
        echo -e "     ${CYAN}কমান্ড: sqlmap -u '$url?id=1' --dbs --batch${NC}"; echo ""
    fi

    echo -e "  ${RED}${BOLD}🔒 SSLScan${NC} — SSL/TLS Analysis"
    echo -e "     ${CYAN}কমান্ড: sslscan $url${NC}"; echo ""

    echo -e "  ${CYAN}${BOLD}⚡ HTTPx${NC} — HTTP Probe"
    echo -e "     ${CYAN}কমান্ড: echo '$url' | httpx -title -tech-detect -status-code${NC}"; echo ""
}

# ================================================================
# SAVE RESULTS
# ================================================================
save_results() {
    local file=$1
    echo ""
    echo -e "${GREEN}[✓] Results saved → $file${NC}"
    echo "$(date) | ${SCAN_LABEL:-scan} | $TARGET | $file" >> "$HISTORY_FILE"
    echo ""
}

# ================================================================
# MAIN
# ================================================================
main() {
    show_banner
    check_deps

    while true; do
        get_target
        get_extra_options
        pre_scan_recon "$TARGET"
        show_menu

        read -p "$(echo -e ${YELLOW}"[?] Scan option [0-28]: "${NC})" choice

        [[ "$choice" == "0" ]] && {
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            exit 0
        }

        case $choice in
            1)  mode_quick ;;
            2)  mode_aggressive ;;
            3)  mode_stealthy ;;
            4)  mode_verbose ;;
            5)  mode_custom_level ;;
            6)  mode_multiple_urls ;;
            7)  mode_url_file ;;
            8)  mode_ip_range ;;
            9)  mode_subdomain_scan ;;
            10) mode_json_output ;;
            11) mode_xml_output ;;
            12) mode_csv_output ;;
            13) mode_brief ;;
            14) mode_cms_detect ;;
            15) mode_server_tech ;;
            16) mode_js_framework ;;
            17) mode_security_headers ;;
            18) mode_login_detect ;;
            19) mode_email_extract ;;
            20) mode_error_fingerprint ;;
            21) mode_proxy_scan ;;
            22) mode_auth_scan ;;
            23) mode_custom_plugin ;;
            24) mode_follow_redirect ;;
            25) mode_ua_spoof ;;
            26) mode_parallel ;;
            27) mode_smart_recon ;;
            28) mode_allinone ;;
            *)  echo -e "${RED}[!] ভুল অপশন।${NC}" ;;
        esac

        echo ""
        read -p "$(echo -e ${YELLOW}"[?] আরেকটি scan করবেন? (y/n): "${NC})" again
        [[ ! "$again" =~ ^[Yy]$ ]] && {
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            exit 0
        }
        unset TARGET TARGET_LIST TARGET_FILE
        show_banner
    done
}

main
