#!/bin/bash

# ================================================================
#   AMASS - Full Automation Tool
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

RESULTS_DIR="$HOME/amass_results"
HISTORY_FILE="$HOME/.amass_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${MAGENTA}${BOLD}"
    echo ' █████╗ ███╗   ███╗ █████╗ ███████╗███████╗'
    echo '██╔══██╗████╗ ████║██╔══██╗██╔════╝██╔════╝'
    echo '███████║██╔████╔██║███████║███████╗███████╗'
    echo '██╔══██║██║╚██╔╝██║██╔══██║╚════██║╚════██║'
    echo '██║  ██║██║ ╚═╝ ██║██║  ██║███████║███████║'
    echo '╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝'
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}         Amass Full Automation Tool | Subdomain Enumeration${NC}"
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
    for tool in amass curl whois dig host; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
            echo -e "  ${RED}[✗] $tool — পাওয়া যায়নি${NC}"
        else
            echo -e "  ${GREEN}[✓] $tool${NC}"
        fi
    done

    # Optional tools
    echo ""
    echo -e "${CYAN}[*] Optional tools চেক করা হচ্ছে...${NC}"
    for opt in httpx subfinder nmap; do
        if command -v "$opt" &>/dev/null; then
            echo -e "  ${GREEN}[✓] $opt — available${NC}"
        else
            echo -e "  ${YELLOW}[!] $opt — নেই (optional, next-step suggestions এ কাজে লাগবে)${NC}"
        fi
    done

    # Amass config check
    echo ""
    echo -e "${CYAN}[*] Amass config চেক করা হচ্ছে...${NC}"
    local cfg_paths=(
        "$HOME/.config/amass/config.ini"
        "$HOME/.amass/config.ini"
        "/etc/amass/config.ini"
    )
    AMASS_CONFIG=""
    for c in "${cfg_paths[@]}"; do
        if [ -f "$c" ]; then
            AMASS_CONFIG="$c"
            echo -e "  ${GREEN}[✓] Config found: $c${NC}"
            break
        fi
    done
    if [ -z "$AMASS_CONFIG" ]; then
        echo -e "  ${YELLOW}[!] Config file নেই। API keys ছাড়াই চলবে (limited results)।${NC}"
        echo -e "  ${DIM}    config.ini বানাতে: amass -help এ দেখুন।${NC}"
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing tools: ${missing[*]}${NC}"
        echo -e "${YELLOW}Install করুন:${NC}"
        for m in "${missing[@]}"; do
            case "$m" in
                amass) echo -e "  ${WHITE}go install -v github.com/owasp-amass/amass/v4/...@master${NC}"
                       echo -e "  ${WHITE}অথবা: sudo apt install amass${NC}" ;;
                curl)  echo -e "  ${WHITE}sudo apt install curl${NC}" ;;
                whois) echo -e "  ${WHITE}sudo apt install whois${NC}" ;;
                dig)   echo -e "  ${WHITE}sudo apt install dnsutils${NC}" ;;
                host)  echo -e "  ${WHITE}sudo apt install bind9-host${NC}" ;;
            esac
        done
        exit 1
    fi
    echo ""
}

# ================================================================
# GET TARGETS
# ================================================================
get_targets() {
    TARGETS=()
    TARGET_FILE=""

    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║         TARGET TYPE SELECT           ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo -e "  ${GREEN}1)${NC} Single Domain        ${DIM}e.g. example.com${NC}"
    echo -e "  ${GREEN}2)${NC} Multiple Domains      ${DIM}একটা একটা করে${NC}"
    echo -e "  ${GREEN}3)${NC} File থেকে Domain list ${DIM}.txt file${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-3]: "${NC})" ttype

    case $ttype in
        1)
            read -p "$(echo -e ${WHITE}"Domain দিন (e.g. example.com): "${NC})" t
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
            TARGET_FILE="$fpath"
            echo -e "  ${GREEN}[✓] File loaded: $fpath${NC}"
            ;;
        *)
            echo -e "${RED}[!] ভুল অপশন।${NC}"
            get_targets; return
            ;;
    esac

    if [ ${#TARGETS[@]} -eq 0 ] && [ -z "$TARGET_FILE" ]; then
        echo -e "${RED}[!] কোনো target দেওয়া হয়নি!${NC}"
        get_targets
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
    echo -e "${GREEN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# HTTP HEADER CHECK
# ================================================================
http_header_check() {
    local domain=$1
    echo -e "${CYAN}${BOLD}┌─── HTTP HEADER PRE-CHECK ─────────────────────────┐${NC}"
    local headers
    headers=$(curl -s -I --max-time 8 "http://$domain" 2>/dev/null | head -25)
    if [ -n "$headers" ]; then
        local code server powered
        code=$(echo    "$headers" | head -1)
        server=$(echo  "$headers" | grep -i "^Server:"       | head -1)
        powered=$(echo "$headers" | grep -i "^X-Powered-By:" | head -1)
        echo -e "  ${WHITE}Status    :${NC} ${GREEN}$code${NC}"
        [ -n "$server"  ] && echo -e "  ${WHITE}Server    :${NC} ${YELLOW}$server${NC}"
        [ -n "$powered" ] && echo -e "  ${WHITE}Powered By:${NC} ${YELLOW}$powered${NC}"
        echo ""
        echo -e "  ${CYAN}WAF Detection:${NC}"
        local waf_detected=false
        for waf_header in "X-WAF" "X-Sucuri" "X-Firewall" "cf-ray" "X-CDN" "X-Mod-Security"; do
            if echo "$headers" | grep -qi "^$waf_header:"; then
                echo -e "    ${RED}[!] WAF Detected: $waf_header${NC}"
                waf_detected=true
            fi
        done
        $waf_detected || echo -e "    ${GREEN}[✓] স্পষ্ট WAF header দেখা যাচ্ছে না।${NC}"
    else
        echo -e "  ${YELLOW}[!] HTTP response নেই।${NC}"
    fi
    echo -e "${CYAN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# PRE-SCAN RECON
# ================================================================
pre_scan_recon() {
    local domain=$1
    echo ""
    echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}${BOLD}   PRE-SCAN RECON  ›  $domain${NC}"
    echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    whois_lookup      "$domain"
    geoip_lookup      "$domain"
    reverse_dns       "$domain"
    http_header_check "$domain"
}

# ================================================================
# SCAN MENU
# ================================================================
show_menu() {
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║                    AMASS SCAN OPTIONS                               ║${NC}"
    echo -e "${YELLOW}${BOLD}╠═══╦══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}1${NC}  ${YELLOW}║${NC} Passive Recon              — OSINT only, target এ request নেই"
    echo -e "${YELLOW}║${NC} ${GREEN}2${NC}  ${YELLOW}║${NC} Active Recon               — DNS probing + active enumeration"
    echo -e "${YELLOW}║${NC} ${GREEN}3${NC}  ${YELLOW}║${NC} Intel Mode                 — ASN/CIDR/Reverse Whois দিয়ে খোঁজা"
    echo -e "${YELLOW}║${NC} ${GREEN}4${NC}  ${YELLOW}║${NC} DNS Brute Force            — wordlist দিয়ে subdomain guess"
    echo -e "${YELLOW}║${NC} ${GREEN}5${NC}  ${YELLOW}║${NC} Full Subdomain Enum        — সব source একসাথে (recommended)"
    echo -e "${YELLOW}║${NC} ${GREEN}6${NC}  ${YELLOW}║${NC} ASN Lookup                 — Autonomous System Number থেকে IP range"
    echo -e "${YELLOW}║${NC} ${GREEN}7${NC}  ${YELLOW}║${NC} Certificate Transparency   — CT logs থেকে subdomain"
    echo -e "${YELLOW}║${NC} ${GREEN}8${NC}  ${YELLOW}║${NC} Reverse Whois              — organization থেকে domain খোঁজা"
    echo -e "${YELLOW}║${NC} ${GREEN}9${NC}  ${YELLOW}║${NC} Permutation / Alteration   — subdomain variation guess"
    echo -e "${YELLOW}║${NC} ${GREEN}10${NC} ${YELLOW}║${NC} Visualize / Graph          — subdomain graph তৈরি"
    echo -e "${YELLOW}║${NC} ${GREEN}11${NC} ${YELLOW}║${NC} Track Changes              — আগের scan এর সাথে compare"
    echo -e "${YELLOW}║${NC} ${GREEN}12${NC} ${YELLOW}║${NC} IP Range Scan              — CIDR block থেকে domain খোঁজা"
    echo -e "${YELLOW}║${NC} ${GREEN}13${NC} ${YELLOW}║${NC} Wayback / Archive Scan     — historical subdomain খোঁজা"
    echo -e "${YELLOW}║${NC} ${GREEN}14${NC} ${YELLOW}║${NC} Live Subdomain Check       — কোনগুলো live সেটা filter করো"
    echo -e "${YELLOW}║${NC} ${GREEN}15${NC} ${YELLOW}║${NC} Custom Wordlist Brute      — নিজের wordlist দিয়ে brute force"
    echo -e "${YELLOW}║${NC} ${GREEN}16${NC} ${YELLOW}║${NC} Multiple Modes একসাথে     — পছন্দমতো mode combine করো"
    echo -e "${YELLOW}║${NC} ${GREEN}17${NC} ${YELLOW}║${NC} All-in-One Mega Enum       — সব source + active + brute force"
    echo -e "${YELLOW}${BOLD}╠═══╩══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${RED}0)${NC} Exit                                                               ${YELLOW}║${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ================================================================
# EXTRA OPTIONS
# ================================================================
get_extra_options() {
    TIMEOUT_OPT=""
    RESOLVERS_OPT=""
    CONFIG_OPT=""
    MAX_DNS_OPT=""
    WORDLIST_OPT=""

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║         EXTRA OPTIONS                ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""

    read -p "$(echo -e ${WHITE}"DNS Timeout (seconds, Enter=5): "${NC})" to_in
    [ -n "$to_in" ] && TIMEOUT_OPT="-timeout $to_in" || TIMEOUT_OPT="-timeout 5"

    read -p "$(echo -e ${WHITE}"Max DNS queries/sec (Enter=100): "${NC})" dns_in
    [ -n "$dns_in" ] && MAX_DNS_OPT="-max-dns-queries $dns_in" || MAX_DNS_OPT="-max-dns-queries 100"

    read -p "$(echo -e ${WHITE}"Custom resolver file দিন (Enter=skip): "${NC})" res_in
    [ -n "$res_in" ] && [ -f "$res_in" ] && RESOLVERS_OPT="-rf $res_in"

    if [ -n "$AMASS_CONFIG" ]; then
        read -p "$(echo -e ${WHITE}"Amass config use করবেন? (y/n, Enter=y): "${NC})" cfg_in
        [[ ! "$cfg_in" =~ ^[Nn]$ ]] && CONFIG_OPT="-config $AMASS_CONFIG"
    fi

    read -p "$(echo -e ${WHITE}"Default wordlist path (Enter=built-in): "${NC})" wl_in
    [ -n "$wl_in" ] && [ -f "$wl_in" ] && WORDLIST_OPT="$wl_in" || WORDLIST_OPT=""

    echo ""
}

# ================================================================
# RUN SCAN
# ================================================================
run_scan() {
    local choice=$1
    local domain=$2

    local ts
    ts=$(date +"%Y%m%d_%H%M%S")
    local safe
    safe=$(echo "$domain" | sed 's/[^a-zA-Z0-9._-]/_/g')
    local outdir="$RESULTS_DIR/${safe}_${ts}"
    mkdir -p "$outdir"

    OUTPUT_FILE="$outdir/subdomains.txt"
    local json_out="$outdir/amass_output.json"
    local log_out="$outdir/amass.log"
    local scan_label=""
    local cmd=""

    case $choice in
        1)
            scan_label="Passive Recon"
            cmd="amass enum -passive -d $domain $TIMEOUT_OPT $MAX_DNS_OPT $CONFIG_OPT -o $OUTPUT_FILE -json $json_out -log $log_out"
            ;;
        2)
            scan_label="Active Recon"
            cmd="amass enum -active -d $domain $TIMEOUT_OPT $MAX_DNS_OPT $CONFIG_OPT -o $OUTPUT_FILE -json $json_out -log $log_out"
            ;;
        3)
            scan_label="Intel Mode"
            echo -e "${CYAN}Intel mode — কী দিয়ে খুঁজবেন?${NC}"
            echo -e "  ${GREEN}1)${NC} ASN number দিয়ে    ${DIM}e.g. AS15169${NC}"
            echo -e "  ${GREEN}2)${NC} CIDR range দিয়ে    ${DIM}e.g. 192.168.1.0/24${NC}"
            echo -e "  ${GREEN}3)${NC} Organization নাম দিয়ে"
            echo -e "  ${GREEN}4)${NC} Reverse Whois (Email/Org)"
            echo ""
            read -p "$(echo -e ${YELLOW}"Select [1-4]: "${NC})" intel_ch
            case $intel_ch in
                1)
                    read -p "$(echo -e ${WHITE}"ASN দিন (e.g. AS15169): "${NC})" asn_in
                    cmd="amass intel -asn ${asn_in#AS} $TIMEOUT_OPT $CONFIG_OPT -o $OUTPUT_FILE -log $log_out"
                    scan_label="Intel — ASN ($asn_in)"
                    ;;
                2)
                    read -p "$(echo -e ${WHITE}"CIDR দিন (e.g. 8.8.8.0/24): "${NC})" cidr_in
                    cmd="amass intel -cidr $cidr_in $TIMEOUT_OPT $CONFIG_OPT -o $OUTPUT_FILE -log $log_out"
                    scan_label="Intel — CIDR ($cidr_in)"
                    ;;
                3)
                    read -p "$(echo -e ${WHITE}"Organization name দিন: "${NC})" org_in
                    cmd="amass intel -org \"$org_in\" $TIMEOUT_OPT $CONFIG_OPT -o $OUTPUT_FILE -log $log_out"
                    scan_label="Intel — Org ($org_in)"
                    ;;
                4)
                    read -p "$(echo -e ${WHITE}"Email অথবা Organization দিন: "${NC})" rw_in
                    cmd="amass intel -whois -d $domain $TIMEOUT_OPT $CONFIG_OPT -o $OUTPUT_FILE -log $log_out"
                    scan_label="Reverse Whois"
                    ;;
                *)
                    echo -e "${RED}[!] ভুল অপশন।${NC}"; return ;;
            esac
            ;;
        4)
            scan_label="DNS Brute Force"
            local wl="${WORDLIST_OPT:-/usr/share/wordlists/amass/subdomains.lst}"
            if [ ! -f "$wl" ]; then
                wl="/usr/share/wordlists/dirbuster/directory-list-2.3-small.txt"
            fi
            if [ ! -f "$wl" ]; then
                read -p "$(echo -e ${WHITE}"Wordlist path দিন: "${NC})" wl
            fi
            cmd="amass enum -brute -d $domain -w $wl $TIMEOUT_OPT $MAX_DNS_OPT $CONFIG_OPT -o $OUTPUT_FILE -json $json_out -log $log_out"
            ;;
        5)
            scan_label="Full Subdomain Enumeration"
            cmd="amass enum -d $domain $TIMEOUT_OPT $MAX_DNS_OPT $CONFIG_OPT -o $OUTPUT_FILE -json $json_out -log $log_out"
            ;;
        6)
            scan_label="ASN Lookup"
            read -p "$(echo -e ${WHITE}"ASN number দিন (e.g. AS15169 বা শুধু 15169): "${NC})" asn_in
            asn_in="${asn_in#AS}"
            cmd="amass intel -asn $asn_in $TIMEOUT_OPT $CONFIG_OPT -o $OUTPUT_FILE -log $log_out"
            ;;
        7)
            scan_label="Certificate Transparency Scan"
            cmd="amass enum -passive -d $domain $TIMEOUT_OPT $CONFIG_OPT -src -o $OUTPUT_FILE -json $json_out -log $log_out"
            ;;
        8)
            scan_label="Reverse Whois"
            cmd="amass intel -whois -d $domain $TIMEOUT_OPT $CONFIG_OPT -o $OUTPUT_FILE -log $log_out"
            ;;
        9)
            scan_label="Permutation / Alteration"
            cmd="amass enum -active -d $domain -alts $TIMEOUT_OPT $MAX_DNS_OPT $CONFIG_OPT -o $OUTPUT_FILE -json $json_out -log $log_out"
            ;;
        10)
            scan_label="Visualize / Graph"
            cmd="amass enum -d $domain $TIMEOUT_OPT $CONFIG_OPT -o $OUTPUT_FILE -json $json_out -log $log_out"
            echo -e "${CYAN}[*] Graph output: $outdir/graph.dot${NC}"
            ;;
        11)
            scan_label="Track Changes"
            local db_path="$RESULTS_DIR/${safe}_amass.db"
            cmd="amass enum -d $domain $TIMEOUT_OPT $CONFIG_OPT -dir $outdir -o $OUTPUT_FILE -json $json_out -log $log_out"
            echo -e "${CYAN}[*] Database: $db_path${NC}"
            ;;
        12)
            scan_label="IP Range Scan"
            read -p "$(echo -e ${WHITE}"CIDR দিন (e.g. 192.168.1.0/24): "${NC})" cidr_in
            cmd="amass intel -cidr $cidr_in $TIMEOUT_OPT $CONFIG_OPT -o $OUTPUT_FILE -log $log_out"
            ;;
        13)
            scan_label="Wayback / Archive Scan"
            cmd="amass enum -passive -d $domain $TIMEOUT_OPT $CONFIG_OPT -src -o $OUTPUT_FILE -json $json_out -log $log_out"
            echo -e "${CYAN}[*] Wayback Machine ও OSINT sources ব্যবহার করা হচ্ছে।${NC}"
            ;;
        14)
            scan_label="Live Subdomain Check"
            # First run passive, then filter live
            cmd="amass enum -passive -d $domain $TIMEOUT_OPT $CONFIG_OPT -o $OUTPUT_FILE -json $json_out -log $log_out"
            LIVE_CHECK=true
            ;;
        15)
            scan_label="Custom Wordlist Brute Force"
            read -p "$(echo -e ${WHITE}"Wordlist path দিন: "${NC})" custom_wl
            if [ ! -f "$custom_wl" ]; then
                echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"; return
            fi
            cmd="amass enum -brute -d $domain -w $custom_wl $TIMEOUT_OPT $MAX_DNS_OPT $CONFIG_OPT -o $OUTPUT_FILE -json $json_out -log $log_out"
            ;;
        16)
            build_multimode_scan "$domain" "$outdir" "$ts" "$safe"
            return
            ;;
        17)
            scan_label="All-in-One Mega Enumeration"
            local wl="${WORDLIST_OPT:-/usr/share/wordlists/amass/subdomains.lst}"
            [ ! -f "$wl" ] && wl="/usr/share/wordlists/dirbuster/directory-list-2.3-small.txt"
            if [ -f "$wl" ]; then
                cmd="amass enum -active -brute -alts -d $domain -w $wl $TIMEOUT_OPT $MAX_DNS_OPT $CONFIG_OPT -o $OUTPUT_FILE -json $json_out -log $log_out"
            else
                cmd="amass enum -active -alts -d $domain $TIMEOUT_OPT $MAX_DNS_OPT $CONFIG_OPT -o $OUTPUT_FILE -json $json_out -log $log_out"
                echo -e "${YELLOW}[!] Wordlist পাওয়া যায়নি — brute force ছাড়াই চলবে।${NC}"
            fi
            ;;
        *)
            echo -e "${RED}[!] Invalid option.${NC}"; return ;;
    esac

    SCAN_LABEL="$scan_label"

    # Preview
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}Scan Type  : ${YELLOW}${BOLD}$scan_label${NC}"
    echo -e "  ${WHITE}Target     : ${GREEN}${BOLD}$domain${NC}"
    echo -e "  ${WHITE}Output Dir : ${CYAN}$outdir${NC}"
    echo -e "  ${WHITE}Command    : ${CYAN}$cmd${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] Scan শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    echo ""
    echo -e "${GREEN}${BOLD}[*] Amass scan শুরু হচ্ছে... (এটি সময় নিতে পারে, ধৈর্য রাখুন)${NC}"
    echo ""

    eval "$cmd" 2>&1

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Scan সম্পন্ন!${NC}"

    # Live check if requested
    if [ "${LIVE_CHECK:-false}" = true ] && command -v httpx &>/dev/null && [ -f "$OUTPUT_FILE" ]; then
        echo ""
        echo -e "${CYAN}[*] Live subdomain check করা হচ্ছে HTTPx দিয়ে...${NC}"
        local live_out="$outdir/live_subdomains.txt"
        httpx -l "$OUTPUT_FILE" -silent -o "$live_out" 2>/dev/null
        local live_count
        live_count=$(wc -l < "$live_out" 2>/dev/null || echo 0)
        echo -e "${GREEN}[✓] Live subdomains: $live_count টি → $live_out${NC}"
        OUTPUT_FILE="$live_out"
    fi
    LIVE_CHECK=false

    # Analysis
    bangla_analysis "$OUTPUT_FILE" "$outdir" "$domain"

    # Suggestions
    suggest_next_tool "$OUTPUT_FILE" "$domain"

    # Save
    save_results "$domain" "$outdir"
}

# ================================================================
# MULTI-MODE SCAN
# ================================================================
build_multimode_scan() {
    local domain=$1
    local outdir=$2
    local ts=$3
    local safe=$4

    echo ""
    echo -e "${CYAN}${BOLD}কোন mode গুলো একসাথে চালাবেন? (নম্বর দিন, space দিয়ে আলাদা করুন)${NC}"
    echo -e "${DIM}উদাহরণ: 1 4 7 9 (Passive + DNS Brute + CT + Alteration)${NC}"
    echo ""
    show_menu
    read -p "$(echo -e ${YELLOW}"Mode numbers দিন: "${NC})" mode_list

    OUTPUT_FILE="$outdir/subdomains_combined.txt"
    local json_out="$outdir/amass_combined.json"
    local log_out="$outdir/amass_combined.log"
    local labels=()
    local flags=""

    for m in $mode_list; do
        case $m in
            1) flags="$flags -passive";  labels+=("Passive") ;;
            2) flags="$flags -active";   labels+=("Active") ;;
            4) flags="$flags -brute";    labels+=("Brute") ;;
            9) flags="$flags -alts";     labels+=("Alteration") ;;
            *) labels+=("Mode$m") ;;
        esac
    done

    local wl="${WORDLIST_OPT:-/usr/share/wordlists/amass/subdomains.lst}"
    [ ! -f "$wl" ] && wl="/usr/share/wordlists/dirbuster/directory-list-2.3-small.txt"
    local wl_flag=""
    [ -f "$wl" ] && [[ "$flags" == *"-brute"* ]] && wl_flag="-w $wl"

    local cmd="amass enum $flags -d $domain $wl_flag $TIMEOUT_OPT $MAX_DNS_OPT $CONFIG_OPT -o $OUTPUT_FILE -json $json_out -log $log_out"
    SCAN_LABEL="Multi-Mode (${labels[*]})"

    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}Scan Type  : ${YELLOW}${BOLD}$SCAN_LABEL${NC}"
    echo -e "  ${WHITE}Target     : ${GREEN}${BOLD}$domain${NC}"
    echo -e "  ${WHITE}Command    : ${CYAN}$cmd${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] Scan শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    echo ""
    echo -e "${GREEN}${BOLD}[*] Multi-mode Amass scan শুরু হচ্ছে...${NC}"
    echo ""
    eval "$cmd" 2>&1

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Scan সম্পন্ন!${NC}"

    bangla_analysis "$OUTPUT_FILE" "$outdir" "$domain"
    suggest_next_tool "$OUTPUT_FILE" "$domain"
    save_results "$domain" "$outdir"
}

# ================================================================
# BANGLA ANALYSIS
# ================================================================
bangla_analysis() {
    local outfile=$1
    local outdir=$2
    local domain=$3
    local report_file="$outdir/bangla_report.txt"

    {
    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় স্ক্যান রিপোর্ট বিশ্লেষণ                      ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -f "$outfile" ] || [ ! -s "$outfile" ]; then
        echo -e "  ${YELLOW}[!] কোনো subdomain পাওয়া যায়নি বা output ফাঁকা।${NC}"
        echo -e "  ${CYAN}💡 API keys config করলে বেশি result পাবেন।${NC}"
        echo ""
        return
    fi

    local total
    total=$(wc -l < "$outfile" | tr -d ' ')

    echo -e "  ${GREEN}${BOLD}✅ মোট $total টি subdomain পাওয়া গেছে!${NC}"
    echo ""

    # Interesting subdomains
    echo -e "  ${CYAN}${BOLD}━━━ গুরুত্বপূর্ণ Subdomain বিশ্লেষণ ━━━${NC}"
    echo ""

    # Admin/Login panels
    local admin_count
    admin_count=$(grep -ciE "^admin\.|^portal\.|^login\.|^dashboard\.|^manage\.|^cpanel\.|^webmail\." "$outfile" 2>/dev/null || echo 0)
    if [ "$admin_count" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}🚨 Admin / Panel Subdomains ($admin_count টি):${NC}"
        grep -iE "^admin\.|^portal\.|^login\.|^dashboard\.|^manage\.|^cpanel\.|^webmail\." "$outfile" 2>/dev/null | head -10 | while IFS= read -r line; do
            echo -e "     ${RED}▸ $line${NC}"
        done
        echo -e "     ${WHITE}→ এগুলো সরাসরি admin access দিতে পারে। Brute force বা default login check করুন।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: HIGH${NC}"
        echo ""
    fi

    # API endpoints
    local api_count
    api_count=$(grep -ciE "^api\.|^api-|^rest\.|^graphql\." "$outfile" 2>/dev/null || echo 0)
    if [ "$api_count" -gt 0 ]; then
        echo -e "  ${YELLOW}${BOLD}⚡ API Subdomains ($api_count টি):${NC}"
        grep -iE "^api\.|^api-|^rest\.|^graphql\." "$outfile" 2>/dev/null | head -8 | while IFS= read -r line; do
            echo -e "     ${YELLOW}▸ $line${NC}"
        done
        echo -e "     ${WHITE}→ API authentication check করুন। Unauthorized access সম্ভব হতে পারে।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: MEDIUM-HIGH${NC}"
        echo ""
    fi

    # Dev/Staging
    local dev_count
    dev_count=$(grep -ciE "^dev\.|^staging\.|^test\.|^beta\.|^uat\.|^qa\.|^sandbox\." "$outfile" 2>/dev/null || echo 0)
    if [ "$dev_count" -gt 0 ]; then
        echo -e "  ${YELLOW}${BOLD}🔧 Dev / Staging Subdomains ($dev_count টি):${NC}"
        grep -iE "^dev\.|^staging\.|^test\.|^beta\.|^uat\.|^qa\.|^sandbox\." "$outfile" 2>/dev/null | head -8 | while IFS= read -r line; do
            echo -e "     ${YELLOW}▸ $line${NC}"
        done
        echo -e "     ${WHITE}→ Debug mode বা weak auth থাকতে পারে। Production এর মতো secure নাও হতে পারে।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"
        echo ""
    fi

    # Mail servers
    local mail_count
    mail_count=$(grep -ciE "^mail\.|^smtp\.|^mx\.|^webmail\.|^imap\.\|^pop\." "$outfile" 2>/dev/null || echo 0)
    if [ "$mail_count" -gt 0 ]; then
        echo -e "  ${CYAN}${BOLD}📧 Mail Subdomains ($mail_count টি):${NC}"
        grep -iE "^mail\.|^smtp\.|^mx\.|^webmail\.|^imap\.|^pop\." "$outfile" 2>/dev/null | head -5 | while IFS= read -r line; do
            echo -e "     ${CYAN}▸ $line${NC}"
        done
        echo -e "     ${WHITE}→ Mail server misconfiguration check করুন।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"
        echo ""
    fi

    # VPN / Remote access
    local vpn_count
    vpn_count=$(grep -ciE "^vpn\.|^remote\.|^rdp\.|^ssh\.|^ftp\." "$outfile" 2>/dev/null || echo 0)
    if [ "$vpn_count" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}🔐 Remote Access Subdomains ($vpn_count টি):${NC}"
        grep -iE "^vpn\.|^remote\.|^rdp\.|^ssh\.|^ftp\." "$outfile" 2>/dev/null | head -5 | while IFS= read -r line; do
            echo -e "     ${RED}▸ $line${NC}"
        done
        echo -e "     ${WHITE}→ Remote access services exposed। Brute force attack এর ঝুঁকি আছে।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: HIGH${NC}"
        echo ""
    fi

    # Cloud/CDN
    local cloud_count
    cloud_count=$(grep -ciE "\.s3\.|\.azure\.|\.gcp\.|cloudfront\.|\.cdn\." "$outfile" 2>/dev/null || echo 0)
    if [ "$cloud_count" -gt 0 ]; then
        echo -e "  ${BLUE}${BOLD}☁️  Cloud / CDN Subdomains ($cloud_count টি):${NC}"
        grep -iE "\.s3\.|\.azure\.|\.gcp\.|cloudfront\.|\.cdn\." "$outfile" 2>/dev/null | head -5 | while IFS= read -r line; do
            echo -e "     ${BLUE}▸ $line${NC}"
        done
        echo -e "     ${WHITE}→ Cloud resource misconfiguration check করুন। S3 bucket takeover সম্ভব হতে পারে।${NC}"
        echo -e "     ${BLUE}→ ঝুঁকি: MEDIUM${NC}"
        echo ""
    fi

    # Database exposed
    local db_count
    db_count=$(grep -ciE "^db\.|^mysql\.|^mongo\.|^redis\.|^postgres\.|^elastic\." "$outfile" 2>/dev/null || echo 0)
    if [ "$db_count" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}🗄️  Database Subdomains ($db_count টি):${NC}"
        grep -iE "^db\.|^mysql\.|^mongo\.|^redis\.|^postgres\.|^elastic\." "$outfile" 2>/dev/null | head -5 | while IFS= read -r line; do
            echo -e "     ${RED}▸ $line${NC}"
        done
        echo -e "     ${WHITE}→ Database সরাসরি internet এ expose থাকতে পারে! Firewall rule check করুন।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"
        echo ""
    fi

    # Internal / Intranet
    local int_count
    int_count=$(grep -ciE "^internal\.|^intranet\.|^corp\.|^private\.|^local\." "$outfile" 2>/dev/null || echo 0)
    if [ "$int_count" -gt 0 ]; then
        echo -e "  ${MAGENTA}${BOLD}🏢 Internal / Intranet Subdomains ($int_count টি):${NC}"
        grep -iE "^internal\.|^intranet\.|^corp\.|^private\.|^local\." "$outfile" 2>/dev/null | head -5 | while IFS= read -r line; do
            echo -e "     ${MAGENTA}▸ $line${NC}"
        done
        echo -e "     ${WHITE}→ Internal systems publicly accessible হতে পারে!${NC}"
        echo -e "     ${RED}→ ঝুঁকি: HIGH${NC}"
        echo ""
    fi

    # Top 10 subdomains preview
    echo -e "  ${WHITE}${BOLD}━━━ প্রথম ১০টি Subdomain ━━━${NC}"
    head -10 "$outfile" | while IFS= read -r line; do
        echo -e "     ${GREEN}▸ $line${NC}"
    done
    [ "$total" -gt 10 ] && echo -e "     ${DIM}... এবং আরো $((total - 10)) টি (full list: $outfile)${NC}"
    echo ""

    # Risk summary
    local risk_score=0
    [ "$admin_count" -gt 0 ]  && risk_score=$((risk_score + 3))
    [ "$dev_count" -gt 0 ]    && risk_score=$((risk_score + 2))
    [ "$db_count" -gt 0 ]     && risk_score=$((risk_score + 5))
    [ "$vpn_count" -gt 0 ]    && risk_score=$((risk_score + 3))
    [ "$api_count" -gt 0 ]    && risk_score=$((risk_score + 2))
    [ "$int_count" -gt 0 ]    && risk_score=$((risk_score + 3))
    [ "$total" -gt 100 ]      && risk_score=$((risk_score + 1))

    echo -e "  ${CYAN}${BOLD}━━━ সামগ্রিক ঝুঁকি মূল্যায়ন ━━━${NC}"
    echo -e "  ${WHITE}   মোট Subdomains  : ${GREEN}$total${NC}"
    echo -e "  ${RED}   Admin/Panel     : $admin_count টি${NC}"
    echo -e "  ${YELLOW}   Dev/Staging     : $dev_count টি${NC}"
    echo -e "  ${RED}   Database        : $db_count টি${NC}"
    echo -e "  ${RED}   Remote Access   : $vpn_count টি${NC}"
    echo -e "  ${YELLOW}   API             : $api_count টি${NC}"
    echo -e "  ${MAGENTA}   Internal        : $int_count টি${NC}"
    echo ""

    if   [ "$db_count" -gt 0 ] || [ "$risk_score" -ge 8 ]; then
        echo -e "  ${RED}${BOLD}  সার্বিক ঝুঁকি : ██████████ CRITICAL — Database বা internal systems exposed!${NC}"
    elif [ "$risk_score" -ge 5 ]; then
        echo -e "  ${YELLOW}${BOLD}  সার্বিক ঝুঁকি : ███████░░░ HIGH — একাধিক sensitive subdomain পাওয়া গেছে।${NC}"
    elif [ "$risk_score" -ge 2 ]; then
        echo -e "  ${CYAN}  সার্বিক ঝুঁকি : █████░░░░░ MEDIUM — কিছু subdomain মনোযোগ দাবি করে।${NC}"
    else
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW — স্পষ্ট সংবেদনশীল subdomain নেই।${NC}"
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

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Tool এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -f "$outfile" ] || [ ! -s "$outfile" ]; then
        echo -e "  ${YELLOW}[!] Output ফাঁকা — suggestion দেওয়া সম্ভব হচ্ছে না।${NC}"
        echo ""
        return
    fi

    local total
    total=$(wc -l < "$outfile" | tr -d ' ')

    # Always suggest HTTPx for live check
    echo -e "  ${GREEN}${BOLD}⚡ HTTPx${NC} — Live Subdomain Probe"
    echo -e "     ${WHITE}কারণ: $total টি subdomain পাওয়া গেছে → কোনগুলো live সেটা check করুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: httpx -l $outfile -title -tech-detect -status-code -o live_subs.txt${NC}"
    echo ""

    # Nuclei scan on found subdomains
    echo -e "  ${MAGENTA}${BOLD}🔍 Nuclei${NC} — Vulnerability Scan on Subdomains"
    echo -e "     ${WHITE}কারণ: পাওয়া subdomains এ vulnerability scan করুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: nuclei -l $outfile -t . -severity medium,high,critical${NC}"
    echo ""

    # Admin panels found
    if grep -qiE "^admin\.|^portal\.|^login\.|^dashboard\." "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}🔑 Hydra${NC} — Admin Panel Brute Force"
        echo -e "     ${WHITE}কারণ: Admin panel subdomain পাওয়া গেছে।${NC}"
        echo -e "     ${CYAN}কমান্ড: hydra -L users.txt -P rockyou.txt <admin-subdomain> http-post-form \"/login:u=^USER^&p=^PASS^:F=wrong\"${NC}"
        echo ""
    fi

    # Dev/staging found
    if grep -qiE "^dev\.|^staging\.|^test\." "$outfile" 2>/dev/null; then
        echo -e "  ${YELLOW}${BOLD}🌐 Gobuster / FFUF${NC} — Directory Fuzzing on Dev Subdomains"
        echo -e "     ${WHITE}কারণ: Dev/staging subdomain পাওয়া গেছে → hidden endpoints থাকতে পারে।${NC}"
        echo -e "     ${CYAN}কমান্ড: ffuf -u http://dev.$domain/FUZZ -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt${NC}"
        echo ""
    fi

    # API found
    if grep -qiE "^api\." "$outfile" 2>/dev/null; then
        echo -e "  ${GREEN}${BOLD}💉 SQLmap${NC} — API Parameter Testing"
        echo -e "     ${WHITE}কারণ: API subdomain পাওয়া গেছে → SQL injection test করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: sqlmap -u \"http://api.$domain/endpoint?id=1\" --dbs --batch${NC}"
        echo ""
    fi

    # Suggest Subfinder for comparison
    echo -e "  ${BLUE}${BOLD}🌐 Subfinder${NC} — Cross-verify Subdomains"
    echo -e "     ${WHITE}কারণ: Amass এর result Subfinder দিয়ে verify ও compare করুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: subfinder -d $domain -o subfinder_out.txt${NC}"
    echo ""

    # Suggest Nmap on found subdomains
    echo -e "  ${GREEN}${BOLD}🗺️  Nmap${NC} — Port Scan on Live Subdomains"
    echo -e "     ${WHITE}কারণ: Live subdomains এ open port খুঁজুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: nmap -iL $outfile -F -T4 -oN nmap_subdomains.txt${NC}"
    echo ""

    # CT log suggestion
    echo -e "  ${CYAN}${BOLD}🔒 SSLScan${NC} — SSL Certificate Check"
    echo -e "     ${WHITE}কারণ: পাওয়া subdomains এর SSL certificate validity check করুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: sslscan <subdomain>${NC}"
    echo ""

    # WPScan if wordpress found
    if grep -qi "wp\|wordpress" "$outfile" 2>/dev/null; then
        echo -e "  ${BLUE}${BOLD}🔧 WPScan${NC} — WordPress Subdomain Scan"
        echo -e "     ${WHITE}কারণ: WordPress-related subdomain পাওয়া গেছে।${NC}"
        echo -e "     ${CYAN}কমান্ড: wpscan --url http://<subdomain> --enumerate u,vp,ap${NC}"
        echo ""
    fi

    # Takeover check
    echo -e "  ${RED}${BOLD}🌐 Nuclei Takeover Templates${NC} — Subdomain Takeover Check"
    echo -e "     ${WHITE}কারণ: $total subdomains এ takeover vulnerability check করুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: nuclei -l $outfile -t dns/takeovers -t http/takeovers${NC}"
    echo ""
}

# ================================================================
# SAVE RESULTS
# ================================================================
save_results() {
    local domain=$1
    local outdir=$2

    echo ""
    echo -e "${GREEN}[✓] সব output automatically save হয়েছে: ${CYAN}$outdir${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Summary report আলাদা file এ save করবেন? (y/n): "${NC})" sc
    if [[ "$sc" =~ ^[Yy]$ ]]; then
        local fname="$outdir/full_summary.txt"
        {
            echo "============================================================"
            echo "  AMASS SCAN RESULTS  —  SAIMUM's Amass Automation Tool"
            echo "  Domain  : $domain"
            echo "  Mode    : $SCAN_LABEL"
            echo "  Date    : $(date)"
            echo "============================================================"
            echo ""
            if [ -f "$OUTPUT_FILE" ]; then
                echo "=== SUBDOMAINS FOUND ==="
                cat "$OUTPUT_FILE"
                echo ""
                echo "Total: $(wc -l < "$OUTPUT_FILE") subdomains"
            fi
            echo ""
            echo "=== BANGLA REPORT ==="
            sed 's/\x1b\[[0-9;]*m//g' "$outdir/bangla_report.txt" 2>/dev/null
        } > "$fname"
        echo -e "${GREEN}[✓] Summary saved → $fname${NC}"
    fi
    echo "$(date) | $SCAN_LABEL | $domain | $outdir" >> "$HISTORY_FILE"
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
        get_extra_options

        # Pre-scan recon
        if [ -n "$TARGET_FILE" ]; then
            echo -e "${CYAN}[*] File mode — প্রথম domain এ recon চালানো হচ্ছে...${NC}"
            first_domain=$(head -1 "$TARGET_FILE")
            pre_scan_recon "$first_domain"
        else
            for t in "${TARGETS[@]}"; do
                pre_scan_recon "$t"
            done
        fi

        show_menu
        read -p "$(echo -e ${YELLOW}"[?] Scan option select করুন [0-17]: "${NC})" choice

        if [[ "$choice" == "0" ]]; then
            echo ""
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            echo ""
            exit 0
        fi

        if [ -n "$TARGET_FILE" ]; then
            while IFS= read -r domain; do
                [ -z "$domain" ] && continue
                echo ""
                echo -e "${MAGENTA}${BOLD}══════════════ Target: $domain ══════════════${NC}"
                run_scan "$choice" "$domain"
            done < "$TARGET_FILE"
        else
            for t in "${TARGETS[@]}"; do
                echo ""
                echo -e "${MAGENTA}${BOLD}══════════════ Target: $t ══════════════${NC}"
                run_scan "$choice" "$t"
            done
        fi

        echo ""
        read -p "$(echo -e ${YELLOW}"[?] আরেকটি scan করবেন? (y/n): "${NC})" again
        [[ ! "$again" =~ ^[Yy]$ ]] && {
            echo ""
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            echo ""
            exit 0
        }
        unset TARGETS TARGET_FILE LIVE_CHECK
        show_banner
    done
}

main
