#!/bin/bash

# ================================================================
#   SHODAN CLI - Full Automation Tool
#   Author: SAIMUM
# ================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
WHITE='\033[1;37m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

RESULTS_DIR="$HOME/shodan_results"
HISTORY_FILE="$HOME/.shodan_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo ' ███████╗██╗  ██╗ ██████╗ ██████╗  █████╗ ███╗   ██╗'
    echo ' ██╔════╝██║  ██║██╔═══██╗██╔══██╗██╔══██╗████╗  ██║'
    echo ' ███████╗███████║██║   ██║██║  ██║███████║██╔██╗ ██║'
    echo ' ╚════██║██╔══██║██║   ██║██║  ██║██╔══██║██║╚██╗██║'
    echo ' ███████║██║  ██║╚██████╔╝██████╔╝██║  ██║██║ ╚████║'
    echo ' ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝'
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}         Shodan CLI Full Automation | Internet Device Search${NC}"
    echo ""
    echo -e "  ${RED}${BOLD}⚠  Ethics Warning:${NC} ${WHITE}শুধুমাত্র authorized reconnaissance এ ব্যবহার করুন।${NC}"
    echo ""
}

# ================================================================
# CHECK DEPENDENCIES
# ================================================================
check_deps() {
    echo -e "${CYAN}[*] Dependencies চেক করা হচ্ছে...${NC}"
    local missing=()

    if command -v shodan &>/dev/null; then
        echo -e "  ${GREEN}[✓] shodan CLI${NC}"
    else
        missing+=("shodan")
        echo -e "  ${RED}[✗] shodan — পাওয়া যায়নি${NC}"
    fi

    for tool in curl python3 whois dig jq; do
        command -v "$tool" &>/dev/null && \
            echo -e "  ${GREEN}[✓] $tool${NC}" || \
            echo -e "  ${YELLOW}[!] $tool — নেই${NC}"
    done

    # Optional tools
    echo ""
    echo -e "${CYAN}[*] Optional tools:${NC}"
    for opt in nmap nikto nuclei; do
        command -v "$opt" &>/dev/null && \
            echo -e "  ${GREEN}[✓] $opt${NC}" || \
            echo -e "  ${YELLOW}[!] $opt — নেই${NC}"
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing: ${missing[*]}${NC}"
        echo -e "${YELLOW}Install করুন:${NC}"
        echo -e "  ${WHITE}pip3 install shodan${NC}"
        echo -e "  ${WHITE}shodan init <YOUR_API_KEY>${NC}"
        echo -e "  ${DIM}API Key পেতে: https://account.shodan.io/${NC}"
        exit 1
    fi

    # API key check
    echo ""
    echo -e "${CYAN}[*] Shodan API Key চেক করা হচ্ছে...${NC}"
    local api_info
    api_info=$(shodan info 2>&1)
    if echo "$api_info" | grep -q "Query credits\|Scan credits\|plan"; then
        echo -e "  ${GREEN}[✓] API Key valid${NC}"
        echo "$api_info" | while IFS= read -r l; do
            echo -e "  ${WHITE}$l${NC}"
        done
    else
        echo -e "  ${RED}[✗] API Key invalid বা set করা হয়নি।${NC}"
        echo -e "  ${YELLOW}চালান: shodan init <YOUR_API_KEY>${NC}"
        echo -e "  ${DIM}Free API Key: https://account.shodan.io/${NC}"
        read -p "$(echo -e ${YELLOW}"তবুও continue করবেন? (y/n): "${NC})" cont
        [[ ! "$cont" =~ ^[Yy]$ ]] && exit 1
    fi
    echo ""
}

# ================================================================
# GET TARGET / QUERY
# ================================================================
get_target() {
    TARGET=""; QUERY=""

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║         TARGET / QUERY SELECT        ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo -e "  ${GREEN}1)${NC} IP Address search"
    echo -e "  ${GREEN}2)${NC} Domain / Hostname search"
    echo -e "  ${GREEN}3)${NC} Custom Shodan query"
    echo -e "  ${GREEN}4)${NC} Organization search"
    echo -e "  ${GREEN}5)${NC} ASN search"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-5]: "${NC})" ttype

    case $ttype in
        1)
            read -p "$(echo -e ${WHITE}"IP Address দিন: "${NC})" TARGET
            QUERY="$TARGET" ;;
        2)
            read -p "$(echo -e ${WHITE}"Domain / Hostname দিন: "${NC})" TARGET
            TARGET=$(echo "$TARGET" | sed 's|https\?://||' | cut -d'/' -f1)
            QUERY="hostname:$TARGET" ;;
        3)
            read -p "$(echo -e ${WHITE}"Shodan Query দিন: "${NC})" QUERY
            TARGET="custom_query" ;;
        4)
            read -p "$(echo -e ${WHITE}"Organization নাম দিন: "${NC})" org
            QUERY="org:\"$org\""
            TARGET="$org" ;;
        5)
            read -p "$(echo -e ${WHITE}"ASN দিন (e.g. AS15169): "${NC})" asn
            QUERY="asn:$asn"
            TARGET="$asn" ;;
        *)
            echo -e "${RED}[!] ভুল।${NC}" && get_target && return ;;
    esac

    echo -e "  ${GREEN}[✓] Target: $TARGET${NC}"
    echo -e "  ${GREEN}[✓] Query: $QUERY${NC}"
    echo ""
}

# ================================================================
# PRE-SCAN RECON
# ================================================================
pre_scan_recon() {
    local target=$1
    # Only run if it looks like a domain or IP
    [[ "$target" == "custom_query" ]] && return

    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}   PRE-SCAN RECON  ›  $target${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # WHOIS
    echo -e "${MAGENTA}${BOLD}┌─── WHOIS ──────────────────────────────────────────┐${NC}"
    whois "$target" 2>/dev/null | grep -E "Registrar:|Country:|Organization:|NetName:|CIDR:|inetnum:" | head -8 | \
        while IFS= read -r l; do echo -e "  ${WHITE}$l${NC}"; done
    echo -e "${MAGENTA}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""

    # GeoIP
    echo -e "${BLUE}${BOLD}┌─── GEO IP ──────────────────────────────────────────┐${NC}"
    local geo; geo=$(curl -s --max-time 5 "http://ip-api.com/json/$target" 2>/dev/null)
    if echo "$geo" | grep -q '"status":"success"'; then
        local ip country region city isp org
        ip=$(echo "$geo"      | grep -o '"query":"[^"]*"'      | cut -d'"' -f4)
        country=$(echo "$geo" | grep -o '"country":"[^"]*"'    | cut -d'"' -f4)
        region=$(echo "$geo"  | grep -o '"regionName":"[^"]*"' | cut -d'"' -f4)
        city=$(echo "$geo"    | grep -o '"city":"[^"]*"'       | cut -d'"' -f4)
        isp=$(echo "$geo"     | grep -o '"isp":"[^"]*"'        | cut -d'"' -f4)
        org=$(echo "$geo"     | grep -o '"org":"[^"]*"'        | cut -d'"' -f4)
        echo -e "  ${WHITE}IP        : ${GREEN}$ip${NC}"
        echo -e "  ${WHITE}Location  : ${GREEN}$city, $region, $country${NC}"
        echo -e "  ${WHITE}ISP       : ${GREEN}$isp${NC}"
        echo -e "  ${WHITE}Org       : ${GREEN}$org${NC}"
    else
        echo -e "  ${YELLOW}[!] GeoIP পাওয়া যায়নি।${NC}"
    fi
    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""

    # DNS lookup
    echo -e "${GREEN}${BOLD}┌─── DNS INFO ────────────────────────────────────────┐${NC}"
    local ip_res; ip_res=$(dig +short "$target" A 2>/dev/null | head -3)
    local mx_res; mx_res=$(dig +short "$target" MX 2>/dev/null | head -3)
    local ns_res; ns_res=$(dig +short "$target" NS 2>/dev/null | head -3)
    [ -n "$ip_res"  ] && echo -e "  ${WHITE}A Record  : ${GREEN}$ip_res${NC}"
    [ -n "$mx_res"  ] && echo -e "  ${WHITE}MX Record : ${GREEN}$mx_res${NC}"
    [ -n "$ns_res"  ] && echo -e "  ${WHITE}NS Record : ${GREEN}$ns_res${NC}"
    echo -e "${GREEN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# SCAN MENU
# ================================================================
show_menu() {
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║                    SHODAN SCAN OPTIONS                              ║${NC}"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ IP / HOST LOOKUP ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}1${NC}  IP Host Info              — IP এর সব info দেখো"
    echo -e "${YELLOW}║${NC} ${GREEN}2${NC}  Domain to IP Resolve      — domain এর Shodan data"
    echo -e "${YELLOW}║${NC} ${GREEN}3${NC}  Reverse DNS Lookup        — IP থেকে hostname"
    echo -e "${YELLOW}║${NC} ${GREEN}4${NC}  ASN Lookup                — ASN এর IP ranges"
    echo -e "${YELLOW}║${NC} ${GREEN}5${NC}  Open Ports Check          — IP এর open ports"
    echo -e "${YELLOW}║${NC} ${GREEN}6${NC}  Vulnerability Check       — IP এর CVEs"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ SEARCH QUERIES ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}7${NC}  Custom Search Query       — যেকোনো Shodan query"
    echo -e "${YELLOW}║${NC} ${GREEN}8${NC}  Organization Search       — একটা org এর সব devices"
    echo -e "${YELLOW}║${NC} ${GREEN}9${NC}  Country Search            — দেশভিত্তিক search"
    echo -e "${YELLOW}║${NC} ${GREEN}10${NC} Port-based Search         — নির্দিষ্ট port খোঁজো"
    echo -e "${YELLOW}║${NC} ${GREEN}11${NC} Product/Technology Search — software/tech খোঁজো"
    echo -e "${YELLOW}║${NC} ${GREEN}12${NC} Banner/String Search      — response banner search"
    echo -e "${YELLOW}║${NC} ${GREEN}13${NC} SSL Certificate Search    — SSL/TLS cert search"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ SPECIALIZED SEARCHES ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}14${NC} Exposed Databases         — MongoDB, Redis, MySQL"
    echo -e "${YELLOW}║${NC} ${GREEN}15${NC} Exposed Industrial (ICS)  — SCADA, PLC devices"
    echo -e "${YELLOW}║${NC} ${GREEN}16${NC} Default Credential Devices— default login devices"
    echo -e "${YELLOW}║${NC} ${GREEN}17${NC} Webcam Search             — exposed webcams"
    echo -e "${YELLOW}║${NC} ${GREEN}18${NC} Router/Network Devices    — exposed routers"
    echo -e "${YELLOW}║${NC} ${GREEN}19${NC} VPN/Remote Access Search  — VPN endpoints"
    echo -e "${YELLOW}║${NC} ${GREEN}20${NC} Vulnerable Services       — known vuln services"
    echo -e "${YELLOW}║${NC} ${GREEN}21${NC} Cloud Services Search     — AWS, GCP, Azure"
    echo -e "${YELLOW}║${NC} ${GREEN}22${NC} Honeypot Check            — IP honeypot কিনা"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ NETWORK / ORG RECON ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}23${NC} Network Range Scan        — CIDR range এ Shodan"
    echo -e "${YELLOW}║${NC} ${GREEN}24${NC} My IP Info                — আমার IP Shodan এ কী দেখাচ্ছে"
    echo -e "${YELLOW}║${NC} ${GREEN}25${NC} Trending CVE Search       — সম্প্রতি exploited CVEs"
    echo -e "${YELLOW}║${NC} ${GREEN}26${NC} Facet Analysis            — statistics breakdown"
    echo -e "${YELLOW}║${NC} ${GREEN}27${NC} Alert / Monitor Setup     — নতুন device alert"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ COMBO ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}28${NC} Full Target Recon         — IP/domain সম্পূর্ণ recon"
    echo -e "${YELLOW}║${NC} ${GREEN}29${NC} All-in-One Mega Scan      — সব info একসাথে"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${RED}0)${NC} Exit                                                               ${YELLOW}║${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ================================================================
# RUN AND SAVE HELPER
# ================================================================
run_and_save() {
    local label=$1 cmd=$2

    SCAN_LABEL="$label"
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 40)
    OUTPUT_FILE="$RESULTS_DIR/${label// /_}_${safe}_${ts}.txt"

    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}Mode   : ${YELLOW}${BOLD}$label${NC}"
    echo -e "  ${WHITE}Target : ${GREEN}${BOLD}$TARGET${NC}"
    echo -e "  ${WHITE}Cmd    : ${DIM}$cmd${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    echo -e "${GREEN}[*] চালু হচ্ছে...${NC}"
    echo ""

    local tmp; tmp=$(mktemp)
    eval "$cmd" 2>&1 | tee "$tmp"
    cat "$tmp" > "$OUTPUT_FILE"
    rm -f "$tmp"

    echo ""
    echo -e "${GREEN}[✓] সম্পন্ন! Output: $OUTPUT_FILE${NC}"
    echo ""

    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 1 — IP HOST INFO
# ================================================================
mode_ip_info() {
    local ip="${TARGET}"
    [[ "$TARGET" == "custom_query" ]] && \
        read -p "$(echo -e ${WHITE}"IP দিন: "${NC})" ip

    echo ""
    echo -e "${CYAN}[*] Shodan host info: $ip${NC}"
    echo ""

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/ip_info_${ip//./_}_${ts}.txt"
    SCAN_LABEL="IP Host Info"

    {
        echo "================================================================"
        echo "  Shodan Host Info: $ip"
        echo "  Date: $(date)"
        echo "================================================================"
        echo ""
        shodan host "$ip" 2>&1
    } | tee "$OUTPUT_FILE"

    echo ""
    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 2 — DOMAIN TO IP
# ================================================================
mode_domain_search() {
    local domain="${TARGET}"
    [[ "$TARGET" == "custom_query" ]] && \
        read -p "$(echo -e ${WHITE}"Domain দিন: "${NC})" domain

    echo ""
    echo -e "${CYAN}[*] Domain resolving: $domain${NC}"
    local ip; ip=$(dig +short "$domain" A 2>/dev/null | head -1)
    echo -e "  ${GREEN}IP: $ip${NC}"
    echo ""

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/domain_${domain//./_}_${ts}.txt"
    SCAN_LABEL="Domain Search"

    {
        echo "Domain: $domain | IP: $ip"
        echo "Date: $(date)"
        echo ""
        echo "=== Shodan DNS ==="
        shodan domain "$domain" 2>&1
        echo ""
        if [ -n "$ip" ]; then
            echo "=== Shodan Host ($ip) ==="
            shodan host "$ip" 2>&1
        fi
    } | tee "$OUTPUT_FILE"

    echo ""
    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 3 — REVERSE DNS
# ================================================================
mode_reverse_dns() {
    local ip="${TARGET}"
    [[ "$TARGET" == "custom_query" ]] && \
        read -p "$(echo -e ${WHITE}"IP দিন: "${NC})" ip

    run_and_save "Reverse DNS" "shodan reversedns $ip"
}

# ================================================================
# MODE 4 — ASN LOOKUP
# ================================================================
mode_asn_lookup() {
    local asn
    read -p "$(echo -e ${WHITE}"ASN দিন (e.g. AS15169): "${NC})" asn
    asn=$(echo "$asn" | tr '[:lower:]' '[:upper:]')
    [[ ! "$asn" =~ ^AS ]] && asn="AS$asn"
    TARGET="$asn"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/asn_${asn}_${ts}.txt"
    SCAN_LABEL="ASN Lookup"

    {
        echo "ASN: $asn"
        echo "Date: $(date)"
        echo ""
        echo "=== Shodan Search ==="
        shodan search --fields ip_str,port,org,country_code "asn:$asn" 2>&1 | head -50
        echo ""
        echo "=== Count ==="
        shodan count "asn:$asn" 2>&1
    } | tee "$OUTPUT_FILE"

    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 5 — OPEN PORTS
# ================================================================
mode_open_ports() {
    local ip="${TARGET}"
    [[ "$TARGET" == "custom_query" ]] && \
        read -p "$(echo -e ${WHITE}"IP দিন: "${NC})" ip

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/ports_${ip//./_}_${ts}.txt"
    SCAN_LABEL="Open Ports"

    echo ""
    echo -e "${CYAN}[*] Open ports checking: $ip${NC}"
    echo ""

    {
        echo "IP: $ip | Date: $(date)"
        echo ""
        echo "=== Shodan Host Ports ==="
        shodan host "$ip" 2>&1 | grep -E "Port:|port|Ports|Banner|Service|ssl|http"
        echo ""
        echo "=== Port History ==="
        shodan search --fields port "ip:$ip" 2>&1
    } | tee "$OUTPUT_FILE"

    # Parse ports for display
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Detected Open Ports ━━━${NC}"
    grep -oE "Port: [0-9]+" "$OUTPUT_FILE" 2>/dev/null | sort -u | while IFS= read -r p; do
        local port; port=$(echo "$p" | awk '{print $2}')
        local service=""
        case $port in
            21) service="FTP" ;; 22) service="SSH" ;; 23) service="Telnet" ;;
            25) service="SMTP" ;; 53) service="DNS" ;; 80) service="HTTP" ;;
            443) service="HTTPS" ;; 445) service="SMB" ;; 3306) service="MySQL" ;;
            3389) service="RDP" ;; 5900) service="VNC" ;; 6379) service="Redis" ;;
            27017) service="MongoDB" ;; 8080) service="HTTP-Alt" ;; 8443) service="HTTPS-Alt" ;;
        esac
        echo -e "  ${GREEN}▸ Port $port ${service:+($service)}${NC}"
    done

    echo ""
    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 6 — VULNERABILITY CHECK
# ================================================================
mode_vuln_check() {
    local ip="${TARGET}"
    [[ "$TARGET" == "custom_query" ]] && \
        read -p "$(echo -e ${WHITE}"IP দিন: "${NC})" ip

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/vulns_${ip//./_}_${ts}.txt"
    SCAN_LABEL="Vulnerability Check"

    echo ""
    echo -e "${CYAN}[*] Vulnerability check: $ip${NC}"
    echo ""

    {
        echo "IP: $ip | Date: $(date)"
        echo ""
        echo "=== Shodan Host Vulnerabilities ==="
        shodan host "$ip" 2>&1 | grep -A 2 -i "Vulnerabilities\|CVE-\|vuln"
        echo ""
        echo "=== Full Host Info ==="
        shodan host "$ip" --history 2>&1
    } | tee "$OUTPUT_FILE"

    # Extract CVEs
    echo ""
    local cves; cves=$(grep -oiE "CVE-[0-9]+-[0-9]+" "$OUTPUT_FILE" 2>/dev/null | sort -u)
    if [ -n "$cves" ]; then
        echo -e "${RED}${BOLD}[!] CVEs found:${NC}"
        echo "$cves" | while IFS= read -r cve; do
            echo -e "  ${RED}▸ $cve${NC}"
        done
        echo ""
    fi

    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 7 — CUSTOM QUERY
# ================================================================
mode_custom_query() {
    echo ""
    echo -e "${CYAN}${BOLD}Shodan Query Examples:${NC}"
    echo -e "  ${DIM}port:22 country:BD${NC}"
    echo -e "  ${DIM}product:\"Apache httpd\" version:2.4${NC}"
    echo -e "  ${DIM}org:\"Amazon\" port:443${NC}"
    echo -e "  ${DIM}vuln:CVE-2021-44228${NC}"
    echo -e "  ${DIM}ssl.cert.subject.cn:\"*.target.com\"${NC}"
    echo ""
    read -p "$(echo -e ${WHITE}"Query দিন: "${NC})" query
    [ -z "$query" ] && echo -e "${RED}[!] Query দাও।${NC}" && return

    read -p "$(echo -e ${WHITE}"Max results (Enter=20): "${NC})" max_r
    [ -z "$max_r" ] && max_r=20

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/custom_query_${ts}.txt"
    SCAN_LABEL="Custom Query"
    TARGET="custom:$query"

    {
        echo "Query: $query"
        echo "Date: $(date)"
        echo ""
        echo "=== Count ==="
        shodan count "$query" 2>&1
        echo ""
        echo "=== Results ==="
        shodan search --fields ip_str,port,org,country_code,product,version "$query" 2>&1 | head -"$max_r"
    } | tee "$OUTPUT_FILE"

    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 8 — ORGANIZATION SEARCH
# ================================================================
mode_org_search() {
    local org="${TARGET}"
    [[ "$TARGET" == "custom_query" ]] && \
        read -p "$(echo -e ${WHITE}"Organization নাম দিন: "${NC})" org

    read -p "$(echo -e ${WHITE}"Max results (Enter=30): "${NC})" max_r
    [ -z "$max_r" ] && max_r=30

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/org_${org// /_}_${ts}.txt"
    SCAN_LABEL="Org Search"
    TARGET="$org"

    {
        echo "Organization: $org"
        echo "Date: $(date)"
        echo ""
        echo "=== Total Count ==="
        shodan count "org:\"$org\"" 2>&1
        echo ""
        echo "=== Devices ==="
        shodan search --fields ip_str,port,product,os,country_code "org:\"$org\"" 2>&1 | head -"$max_r"
        echo ""
        echo "=== Top Ports ==="
        shodan stats --facets port "org:\"$org\"" 2>&1
    } | tee "$OUTPUT_FILE"

    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 9 — COUNTRY SEARCH
# ================================================================
mode_country_search() {
    echo ""
    echo -e "${CYAN}Country codes: BD=Bangladesh, US=USA, GB=UK, IN=India, CN=China${NC}"
    read -p "$(echo -e ${WHITE}"Country code দিন (e.g. BD): "${NC})" cc
    cc=$(echo "$cc" | tr '[:lower:]' '[:upper:]')
    read -p "$(echo -e ${WHITE}"Additional filter (Enter=skip, e.g. port:22): "${NC})" extra
    [ -n "$extra" ] && extra=" $extra"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/country_${cc}_${ts}.txt"
    SCAN_LABEL="Country Search ($cc)"
    TARGET="country:$cc"

    {
        echo "Country: $cc"
        echo "Date: $(date)"
        echo ""
        echo "=== Total Devices ==="
        shodan count "country:$cc$extra" 2>&1
        echo ""
        echo "=== Top Services ==="
        shodan stats --facets port "country:$cc$extra" 2>&1
        echo ""
        echo "=== Sample Results ==="
        shodan search --fields ip_str,port,org,product "country:$cc$extra" 2>&1 | head -30
    } | tee "$OUTPUT_FILE"

    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 10 — PORT-BASED SEARCH
# ================================================================
mode_port_search() {
    echo ""
    echo -e "${CYAN}Common ports: 22(SSH) 23(Telnet) 80(HTTP) 443(HTTPS) 3306(MySQL) 6379(Redis) 27017(MongoDB)${NC}"
    read -p "$(echo -e ${WHITE}"Port দিন: "${NC})" port
    read -p "$(echo -e ${WHITE}"Country filter (Enter=সব): "${NC})" cc
    read -p "$(echo -e ${WHITE}"Max results (Enter=30): "${NC})" max_r
    [ -z "$max_r" ] && max_r=30

    local query="port:$port"
    [ -n "$cc" ] && query="$query country:${cc^^}"
    TARGET="port:$port"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/port_${port}_${ts}.txt"
    SCAN_LABEL="Port $port Search"

    {
        echo "Port: $port | Query: $query"
        echo "Date: $(date)"
        echo ""
        echo "=== Count ==="
        shodan count "$query" 2>&1
        echo ""
        echo "=== Results ==="
        shodan search --fields ip_str,port,org,country_code,product,version "$query" 2>&1 | head -"$max_r"
        echo ""
        echo "=== Top Countries ==="
        shodan stats --facets country "$query" 2>&1
    } | tee "$OUTPUT_FILE"

    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 11 — PRODUCT/TECH SEARCH
# ================================================================
mode_product_search() {
    echo ""
    echo -e "${CYAN}Examples: Apache, Nginx, IIS, OpenSSH, MySQL, MongoDB, Redis, Elasticsearch${NC}"
    read -p "$(echo -e ${WHITE}"Product/Technology দিন: "${NC})" product
    read -p "$(echo -e ${WHITE}"Version (Enter=skip): "${NC})" version
    read -p "$(echo -e ${WHITE}"Country (Enter=সব): "${NC})" cc
    read -p "$(echo -e ${WHITE}"Max results (Enter=30): "${NC})" max_r
    [ -z "$max_r" ] && max_r=30

    local query="product:\"$product\""
    [ -n "$version" ] && query="$query version:\"$version\""
    [ -n "$cc" ]      && query="$query country:${cc^^}"
    TARGET="$product"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/product_${product// /_}_${ts}.txt"
    SCAN_LABEL="Product Search ($product)"

    {
        echo "Product: $product | Query: $query"
        echo "Date: $(date)"
        echo ""
        echo "=== Count ==="
        shodan count "$query" 2>&1
        echo ""
        echo "=== Top Versions ==="
        shodan stats --facets version "$query" 2>&1
        echo ""
        echo "=== Results ==="
        shodan search --fields ip_str,port,org,country_code,version "$query" 2>&1 | head -"$max_r"
    } | tee "$OUTPUT_FILE"

    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 12 — BANNER SEARCH
# ================================================================
mode_banner_search() {
    read -p "$(echo -e ${WHITE}"Banner/String দিন (e.g. 'Welcome to'): "${NC})" banner
    [ -z "$banner" ] && echo -e "${RED}[!] String দাও।${NC}" && return

    TARGET="banner:$banner"
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/banner_search_${ts}.txt"
    SCAN_LABEL="Banner Search"

    {
        echo "Banner: $banner"
        echo "Date: $(date)"
        echo ""
        echo "=== Count ==="
        shodan count "\"$banner\"" 2>&1
        echo ""
        echo "=== Results ==="
        shodan search --fields ip_str,port,org,country_code "\"$banner\"" 2>&1 | head -30
    } | tee "$OUTPUT_FILE"

    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 13 — SSL CERT SEARCH
# ================================================================
mode_ssl_search() {
    echo ""
    echo -e "${CYAN}SSL Search Examples:${NC}"
    echo -e "  ${DIM}ssl.cert.subject.cn:*.target.com${NC}"
    echo -e "  ${DIM}ssl.cert.issuer.cn:Let's Encrypt${NC}"
    echo -e "  ${DIM}ssl.cert.subject.org:\"Target Corp\"${NC}"
    echo ""
    read -p "$(echo -e ${WHITE}"Domain/Org দিন (e.g. *.target.com): "${NC})" ssl_query

    local query="ssl.cert.subject.cn:\"$ssl_query\""
    TARGET="ssl:$ssl_query"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/ssl_search_${ts}.txt"
    SCAN_LABEL="SSL Cert Search"

    {
        echo "SSL Query: $query"
        echo "Date: $(date)"
        echo ""
        echo "=== Count ==="
        shodan count "$query" 2>&1
        echo ""
        echo "=== Cert Results ==="
        shodan search --fields ip_str,port,org,ssl.cert.subject.cn,ssl.cert.expired "$query" 2>&1 | head -30
    } | tee "$OUTPUT_FILE"

    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 14 — EXPOSED DATABASES
# ================================================================
mode_exposed_dbs() {
    echo ""
    echo -e "${CYAN}Database type select:${NC}"
    echo -e "  ${GREEN}1)${NC} MongoDB (27017)    ${GREEN}2)${NC} Redis (6379)"
    echo -e "  ${GREEN}3)${NC} Elasticsearch (9200) ${GREEN}4)${NC} MySQL (3306)"
    echo -e "  ${GREEN}5)${NC} PostgreSQL (5432)  ${GREEN}6)${NC} Cassandra (9042)"
    echo -e "  ${GREEN}7)${NC} CouchDB (5984)     ${GREEN}8)${NC} সব database"
    read -p "$(echo -e ${YELLOW}"[1-8]: "${NC})" dbch

    local query="" label=""
    case $dbch in
        1) query="product:MongoDB port:27017 -authentication"; label="MongoDB" ;;
        2) query="product:Redis port:6379 -authentication"; label="Redis" ;;
        3) query="product:Elasticsearch port:9200"; label="Elasticsearch" ;;
        4) query="product:MySQL port:3306"; label="MySQL" ;;
        5) query="product:PostgreSQL port:5432"; label="PostgreSQL" ;;
        6) query="product:Cassandra port:9042"; label="Cassandra" ;;
        7) query="product:CouchDB port:5984"; label="CouchDB" ;;
        8) query="port:27017 OR port:6379 OR port:9200 OR port:5432 OR port:5984"
           label="All Databases" ;;
        *) query="product:MongoDB"; label="MongoDB" ;;
    esac

    read -p "$(echo -e ${WHITE}"Country filter (Enter=সব): "${NC})" cc
    [ -n "$cc" ] && query="$query country:${cc^^}"
    TARGET="db:$label"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/exposed_db_${label// /_}_${ts}.txt"
    SCAN_LABEL="Exposed DB ($label)"

    {
        echo "Database: $label | Query: $query"
        echo "Date: $(date)"
        echo ""
        echo "=== Total Exposed ==="
        shodan count "$query" 2>&1
        echo ""
        echo "=== Top Countries ==="
        shodan stats --facets country "$query" 2>&1
        echo ""
        echo "=== Exposed Instances ==="
        shodan search --fields ip_str,port,org,country_code,version "$query" 2>&1 | head -30
    } | tee "$OUTPUT_FILE"

    echo ""
    echo -e "${RED}${BOLD}[!] Exposed databases পাওয়া গেলে:${NC}"
    echo -e "  ${WHITE}→ এগুলো publicly accessible — authentication নেই।${NC}"
    echo -e "  ${WHITE}→ Data breach এর সরাসরি ঝুঁকি আছে।${NC}"
    echo ""

    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 15 — ICS/SCADA
# ================================================================
mode_ics_search() {
    echo ""
    echo -e "${RED}${BOLD}[!] ICS/SCADA search — শুধু authorized security research এ ব্যবহার করুন।${NC}"
    echo ""

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/ics_scan_${ts}.txt"
    SCAN_LABEL="ICS/SCADA Search"
    TARGET="ICS/SCADA"

    {
        echo "ICS/SCADA Search"
        echo "Date: $(date)"
        echo ""
        echo "=== Modbus (502) ==="
        shodan count "port:502" 2>&1
        shodan search --fields ip_str,port,org,country_code "port:502" 2>&1 | head -10
        echo ""
        echo "=== DNP3 (20000) ==="
        shodan count "port:20000" 2>&1
        echo ""
        echo "=== Siemens S7 (102) ==="
        shodan count "port:102 Siemens" 2>&1
        echo ""
        echo "=== BACnet (47808) ==="
        shodan count "port:47808" 2>&1
    } | tee "$OUTPUT_FILE"

    bangla_analysis "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 16 — DEFAULT CREDENTIALS
# ================================================================
mode_default_creds() {
    echo ""
    echo -e "${CYAN}Default credential device type:${NC}"
    echo -e "  ${GREEN}1)${NC} Router admin panels"
    echo -e "  ${GREEN}2)${NC} IP Cameras"
    echo -e "  ${GREEN}3)${NC} NAS Devices"
    echo -e "  ${GREEN}4)${NC} Printers"
    echo -e "  ${GREEN}5)${NC} Custom query"
    read -p "$(echo -e ${YELLOW}"[1-5]: "${NC})" dch

    local query="" label=""
    case $dch in
        1) query="http.title:\"Router\" OR http.title:\"admin\" port:80,443,8080"; label="Routers" ;;
        2) query="product:\"IP Camera\" OR http.title:\"IP Camera\" OR product:Hikvision"; label="IP Cameras" ;;
        3) query="product:\"QNAP\" OR product:\"Synology\" OR product:\"NAS\""; label="NAS" ;;
        4) query="product:\"HP JetDirect\" OR product:\"CUPS\""; label="Printers" ;;
        5) read -p "$(echo -e ${WHITE}"Query: "${NC})" query; label="Custom" ;;
    esac

    read -p "$(echo -e ${WHITE}"Country (Enter=সব): "${NC})" cc
    [ -n "$cc" ] && query="$query country:${cc^^}"
    TARGET="default_creds:$label"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/default_creds_${label// /_}_${ts}.txt"
    SCAN_LABEL="Default Creds ($label)"

    {
        echo "Type: $label | Query: $query"
        echo "Date: $(date)"
        echo ""
        shodan count "$query" 2>&1
        echo ""
        shodan search --fields ip_str,port,org,country_code,product "$query" 2>&1 | head -30
    } | tee "$OUTPUT_FILE"

    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 17 — WEBCAM SEARCH
# ================================================================
mode_webcam_search() {
    echo ""
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/webcam_${ts}.txt"
    SCAN_LABEL="Webcam Search"
    TARGET="webcams"

    read -p "$(echo -e ${WHITE}"Country (Enter=সব): "${NC})" cc
    local cc_filter=""
    [ -n "$cc" ] && cc_filter="country:${cc^^}"

    {
        echo "Webcam Search $cc_filter"
        echo "Date: $(date)"
        echo ""
        echo "=== Axis Cameras ==="
        shodan count "product:\"Axis\" $cc_filter" 2>&1
        shodan search --fields ip_str,port,org,country_code "product:\"Axis\" $cc_filter" 2>&1 | head -10
        echo ""
        echo "=== Hikvision ==="
        shodan count "product:Hikvision $cc_filter" 2>&1
        shodan search --fields ip_str,port,org,country_code "product:Hikvision $cc_filter" 2>&1 | head -10
        echo ""
        echo "=== Generic Webcams ==="
        shodan count "http.title:\"webcam\" $cc_filter" 2>&1
    } | tee "$OUTPUT_FILE"

    bangla_analysis "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 18 — ROUTER SEARCH
# ================================================================
mode_router_search() {
    read -p "$(echo -e ${WHITE}"Country (Enter=সব): "${NC})" cc
    local cc_filter=""
    [ -n "$cc" ] && cc_filter="country:${cc^^}"
    TARGET="routers"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/routers_${ts}.txt"
    SCAN_LABEL="Router Search"

    {
        echo "Router Search $cc_filter"
        echo "Date: $(date)"
        echo ""
        echo "=== MikroTik ==="
        shodan count "product:MikroTik $cc_filter" 2>&1
        shodan search --fields ip_str,port,org,country_code,version "product:MikroTik $cc_filter" 2>&1 | head -10
        echo ""
        echo "=== Cisco ==="
        shodan count "product:Cisco $cc_filter" 2>&1
        shodan search --fields ip_str,port,org,country_code "product:Cisco $cc_filter" 2>&1 | head -10
        echo ""
        echo "=== TP-Link ==="
        shodan count "product:\"TP-LINK\" $cc_filter" 2>&1
        echo ""
        echo "=== Exposed Telnet Routers ==="
        shodan count "port:23 $cc_filter" 2>&1
    } | tee "$OUTPUT_FILE"

    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 19 — VPN SEARCH
# ================================================================
mode_vpn_search() {
    read -p "$(echo -e ${WHITE}"Country (Enter=সব): "${NC})" cc
    local cc_filter=""
    [ -n "$cc" ] && cc_filter="country:${cc^^}"
    TARGET="vpn"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/vpn_search_${ts}.txt"
    SCAN_LABEL="VPN Search"

    {
        echo "VPN Search $cc_filter"
        echo "Date: $(date)"
        echo ""
        echo "=== Fortinet VPN ==="
        shodan count "product:FortiGate $cc_filter" 2>&1
        shodan search --fields ip_str,port,org,country_code,version "product:FortiGate $cc_filter" 2>&1 | head -10
        echo ""
        echo "=== Pulse Secure ==="
        shodan count "product:\"Pulse Secure\" $cc_filter" 2>&1
        echo ""
        echo "=== Cisco AnyConnect ==="
        shodan count "product:\"Cisco AnyConnect\" $cc_filter" 2>&1
        echo ""
        echo "=== OpenVPN ==="
        shodan count "product:OpenVPN port:1194 $cc_filter" 2>&1
        echo ""
        echo "=== RDP Exposed ==="
        shodan count "port:3389 $cc_filter" 2>&1
        shodan search --fields ip_str,port,org,country_code "port:3389 $cc_filter" 2>&1 | head -10
    } | tee "$OUTPUT_FILE"

    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 20 — VULNERABLE SERVICES
# ================================================================
mode_vuln_services() {
    echo ""
    echo -e "${CYAN}CVE-based search:${NC}"
    echo -e "  ${GREEN}1)${NC} Log4Shell (CVE-2021-44228)"
    echo -e "  ${GREEN}2)${NC} Heartbleed (CVE-2014-0160)"
    echo -e "  ${GREEN}3)${NC} EternalBlue (MS17-010)"
    echo -e "  ${GREEN}4)${NC} ProxyLogon (CVE-2021-26855)"
    echo -e "  ${GREEN}5)${NC} Custom CVE"
    read -p "$(echo -e ${YELLOW}"[1-5]: "${NC})" vch

    local cve="" label=""
    case $vch in
        1) cve="CVE-2021-44228"; label="Log4Shell" ;;
        2) cve="CVE-2014-0160";  label="Heartbleed" ;;
        3) cve="MS17-010";       label="EternalBlue" ;;
        4) cve="CVE-2021-26855"; label="ProxyLogon" ;;
        5) read -p "$(echo -e ${WHITE}"CVE ID: "${NC})" cve; label="$cve" ;;
    esac

    TARGET="vuln:$cve"
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/vuln_${cve}_${ts}.txt"
    SCAN_LABEL="Vuln Search ($label)"

    {
        echo "CVE: $cve ($label)"
        echo "Date: $(date)"
        echo ""
        echo "=== Total Vulnerable Hosts ==="
        shodan count "vuln:$cve" 2>&1
        echo ""
        echo "=== Top Countries ==="
        shodan stats --facets country "vuln:$cve" 2>&1
        echo ""
        echo "=== Vulnerable Hosts ==="
        shodan search --fields ip_str,port,org,country_code "vuln:$cve" 2>&1 | head -30
    } | tee "$OUTPUT_FILE"

    echo ""
    echo -e "${RED}${BOLD}[!] এই hosts গুলো $label এর জন্য vulnerable।${NC}"
    echo -e "  ${WHITE}→ শুধু নিজের systems এ test করুন।${NC}"
    echo ""

    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 21 — CLOUD SERVICES
# ================================================================
mode_cloud_search() {
    echo ""
    echo -e "${CYAN}Cloud provider:${NC}"
    echo -e "  ${GREEN}1)${NC} AWS  ${GREEN}2)${NC} Google Cloud  ${GREEN}3)${NC} Azure  ${GREEN}4)${NC} সব"
    read -p "$(echo -e ${YELLOW}"[1-4]: "${NC})" cch

    local query="" label=""
    case $cch in
        1) query="org:\"Amazon\""; label="AWS" ;;
        2) query="org:\"Google\""; label="GCP" ;;
        3) query="org:\"Microsoft Azure\""; label="Azure" ;;
        4) query="org:\"Amazon\" OR org:\"Google\" OR org:\"Microsoft Azure\""; label="All Cloud" ;;
    esac

    read -p "$(echo -e ${WHITE}"Port filter (Enter=skip): "${NC})" port_f
    [ -n "$port_f" ] && query="$query port:$port_f"
    TARGET="cloud:$label"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/cloud_${label// /_}_${ts}.txt"
    SCAN_LABEL="Cloud Search ($label)"

    {
        echo "Cloud: $label | Query: $query"
        echo "Date: $(date)"
        echo ""
        shodan count "$query" 2>&1
        echo ""
        shodan stats --facets port "$query" 2>&1
        echo ""
        shodan search --fields ip_str,port,product,country_code "$query" 2>&1 | head -30
    } | tee "$OUTPUT_FILE"

    bangla_analysis "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 22 — HONEYPOT CHECK
# ================================================================
mode_honeypot_check() {
    local ip="${TARGET}"
    [[ "$TARGET" == "custom_query" ]] && \
        read -p "$(echo -e ${WHITE}"IP দিন: "${NC})" ip

    echo ""
    echo -e "${CYAN}[*] Honeypot check: $ip${NC}"
    echo ""

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/honeypot_${ip//./_}_${ts}.txt"
    SCAN_LABEL="Honeypot Check"

    {
        echo "IP: $ip"
        echo "Date: $(date)"
        echo ""
        echo "=== Shodan Honeypot Score ==="
        shodan honeyscore "$ip" 2>&1
        echo ""
        echo "=== Host Info ==="
        shodan host "$ip" 2>&1
    } | tee "$OUTPUT_FILE"

    # Parse honeypot score
    local score
    score=$(grep -oE "[0-9]+\.[0-9]+" "$OUTPUT_FILE" 2>/dev/null | head -1)
    echo ""
    if [ -n "$score" ]; then
        local score_int; score_int=$(echo "$score * 10" | bc 2>/dev/null | cut -d'.' -f1 || echo "0")
        if [ "${score_int:-0}" -ge 5 ]; then
            echo -e "  ${RED}${BOLD}[!] Honeypot হওয়ার সম্ভাবনা বেশি! Score: $score${NC}"
        else
            echo -e "  ${GREEN}[✓] Honeypot হওয়ার সম্ভাবনা কম। Score: $score${NC}"
        fi
    fi

    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 23 — NETWORK RANGE
# ================================================================
mode_network_range() {
    read -p "$(echo -e ${WHITE}"CIDR range দিন (e.g. 192.168.1.0/24): "${NC})" cidr
    [ -z "$cidr" ] && echo -e "${RED}[!] CIDR দাও।${NC}" && return
    TARGET="$cidr"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/netrange_${cidr//\//_}_${ts}.txt"
    SCAN_LABEL="Network Range"

    {
        echo "CIDR: $cidr"
        echo "Date: $(date)"
        echo ""
        echo "=== Count ==="
        shodan count "net:$cidr" 2>&1
        echo ""
        echo "=== Top Ports ==="
        shodan stats --facets port "net:$cidr" 2>&1
        echo ""
        echo "=== Hosts ==="
        shodan search --fields ip_str,port,org,product "net:$cidr" 2>&1 | head -50
    } | tee "$OUTPUT_FILE"

    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 24 — MY IP INFO
# ================================================================
mode_my_ip() {
    echo ""
    echo -e "${CYAN}[*] আপনার public IP এর Shodan data দেখা হচ্ছে...${NC}"

    local my_ip
    my_ip=$(curl -s --max-time 8 ifconfig.me 2>/dev/null || \
            curl -s --max-time 8 api.ipify.org 2>/dev/null)

    echo -e "  ${GREEN}Your IP: $my_ip${NC}"
    echo ""

    TARGET="$my_ip"
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/my_ip_${ts}.txt"
    SCAN_LABEL="My IP Info"

    {
        echo "My IP: $my_ip"
        echo "Date: $(date)"
        echo ""
        shodan host "$my_ip" 2>&1
    } | tee "$OUTPUT_FILE"

    bangla_analysis "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 25 — TRENDING CVEs
# ================================================================
mode_trending_cve() {
    echo ""
    echo -e "${CYAN}[*] Shodan এ trending CVEs দেখা হচ্ছে...${NC}"
    echo ""

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/trending_cves_${ts}.txt"
    SCAN_LABEL="Trending CVEs"
    TARGET="trending_cves"

    {
        echo "Trending CVEs from Shodan"
        echo "Date: $(date)"
        echo ""
        shodan stats --facets vulns 2>&1 | head -30 ||
        echo "=== Recent High-Impact CVEs ==="
        local cves=("CVE-2023-44487" "CVE-2023-23397" "CVE-2022-41082" "CVE-2021-44228" "CVE-2021-34527")
        for cve in "${cves[@]}"; do
            echo -n "$cve: "
            shodan count "vuln:$cve" 2>&1
        done
    } | tee "$OUTPUT_FILE"

    bangla_analysis "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 26 — FACET ANALYSIS
# ================================================================
mode_facet_analysis() {
    echo ""
    echo -e "${CYAN}Facet analysis — statistics breakdown:${NC}"
    read -p "$(echo -e ${WHITE}"Search query দিন: "${NC})" query
    [ -z "$query" ] && echo -e "${RED}[!] Query দাও।${NC}" && return

    echo -e "${CYAN}Facet type:${NC}"
    echo -e "  ${GREEN}1)${NC} Country  ${GREEN}2)${NC} Port  ${GREEN}3)${NC} Product  ${GREEN}4)${NC} OS  ${GREEN}5)${NC} Version"
    read -p "$(echo -e ${YELLOW}"[1-5]: "${NC})" fch

    local facet=""
    case $fch in
        1) facet="country" ;; 2) facet="port" ;;
        3) facet="product" ;; 4) facet="os" ;; 5) facet="version" ;;
        *) facet="country" ;;
    esac
    TARGET="facet:$query"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/facet_${facet}_${ts}.txt"
    SCAN_LABEL="Facet Analysis ($facet)"

    {
        echo "Query: $query | Facet: $facet"
        echo "Date: $(date)"
        echo ""
        echo "=== Total Count ==="
        shodan count "$query" 2>&1
        echo ""
        echo "=== $facet Breakdown ==="
        shodan stats --facets "$facet" "$query" 2>&1
    } | tee "$OUTPUT_FILE"

    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 27 — ALERT SETUP
# ================================================================
mode_alert_setup() {
    echo ""
    echo -e "${CYAN}${BOLD}Shodan Alert — নতুন device পাওয়া গেলে notify করবে:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Alert তৈরি করো"
    echo -e "  ${GREEN}2)${NC} সব alerts দেখো"
    echo -e "  ${GREEN}3)${NC} Alert delete করো"
    echo -e "  ${GREEN}4)${NC} Alert triggers দেখো"
    read -p "$(echo -e ${YELLOW}"[1-4]: "${NC})" ach

    case $ach in
        1)
            read -p "$(echo -e ${WHITE}"Alert name: "${NC})" alert_name
            read -p "$(echo -e ${WHITE}"CIDR/IP range (e.g. 192.168.1.0/24): "${NC})" alert_range
            echo ""
            echo -e "${CYAN}কমান্ড: shodan alert create '$alert_name' $alert_range${NC}"
            shodan alert create "$alert_name" "$alert_range" 2>&1
            ;;
        2)
            echo ""
            shodan alert list 2>&1
            ;;
        3)
            shodan alert list 2>&1
            read -p "$(echo -e ${WHITE}"Alert ID দিন: "${NC})" alert_id
            shodan alert remove "$alert_id" 2>&1
            ;;
        4)
            read -p "$(echo -e ${WHITE}"Alert ID: "${NC})" alert_id
            shodan alert triggers "$alert_id" 2>&1
            ;;
    esac

    echo ""
    echo "$(date) | Alert Setup | $(date)" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 28 — FULL TARGET RECON
# ================================================================
mode_full_recon() {
    local ip="${TARGET}"
    [[ "$TARGET" == "custom_query" ]] && \
        read -p "$(echo -e ${WHITE}"IP / Domain দিন: "${NC})" ip

    # Resolve domain to IP if needed
    if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        local resolved; resolved=$(dig +short "$ip" A 2>/dev/null | head -1)
        [ -n "$resolved" ] && echo -e "  ${GREEN}$ip → $ip${NC}" && ip="$resolved"
    fi

    TARGET="$ip"
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/full_recon_${ip//./_}_${ts}.txt"
    SCAN_LABEL="Full Target Recon"

    echo ""
    echo -e "${CYAN}${BOLD}[*] Full Recon: $ip${NC}"
    echo ""

    {
        echo "================================================================"
        echo "  Full Target Recon: $ip"
        echo "  Date: $(date)"
        echo "================================================================"
        echo ""

        echo "=== 1. Shodan Host Info ==="
        shodan host "$ip" 2>&1
        echo ""

        echo "=== 2. Open Ports & Services ==="
        shodan host "$ip" 2>&1 | grep -E "Port:|Banner:|SSL:|HTTP:"
        echo ""

        echo "=== 3. Vulnerabilities ==="
        shodan host "$ip" 2>&1 | grep -A 3 "Vulnerabilities\|CVE-"
        echo ""

        echo "=== 4. Honeypot Score ==="
        shodan honeyscore "$ip" 2>&1
        echo ""

        echo "=== 5. Historical Data ==="
        shodan host "$ip" --history 2>&1 | head -30

    } | tee "$OUTPUT_FILE"

    echo ""
    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 29 — ALL IN ONE MEGA
# ================================================================
mode_allinone() {
    local ip="${TARGET}"
    [[ "$TARGET" == "custom_query" ]] && \
        read -p "$(echo -e ${WHITE}"IP দিন: "${NC})" ip

    # Resolve if domain
    if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        local resolved; resolved=$(dig +short "$ip" A 2>/dev/null | head -1)
        [ -n "$resolved" ] && ip="$resolved"
    fi

    TARGET="$ip"
    echo ""
    echo -e "${RED}${BOLD}[!] All-in-One Mega Scan — সব info একসাথে।${NC}"
    read -p "$(echo -e ${YELLOW}"[?] শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/mega_scan_${ip//./_}_${ts}.txt"
    SCAN_LABEL="All-in-One Mega"

    {
        echo "================================================================"
        echo "  SHODAN ALL-IN-ONE MEGA SCAN — SAIMUM"
        echo "  Target: $ip"
        echo "  Date: $(date)"
        echo "================================================================"
        echo ""
    } > "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 1: Host Info ━━━${NC}"
    shodan host "$ip" 2>&1 | tee -a "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 2: Vulnerabilities ━━━${NC}"
    shodan host "$ip" 2>&1 | grep -iE "CVE-|vuln|Vulnerability" | tee -a "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 3: Honeypot Score ━━━${NC}"
    shodan honeyscore "$ip" 2>&1 | tee -a "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 4: Network Range ━━━${NC}"
    local octet123; octet123=$(echo "$ip" | cut -d'.' -f1-3)
    shodan count "net:${octet123}.0/24" 2>&1 | tee -a "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 5: SSL Certs ━━━${NC}"
    shodan search --fields ip_str,port,ssl.cert.subject.cn "ip:$ip" 2>&1 | head -10 | tee -a "$OUTPUT_FILE"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] All-in-One Mega Scan সম্পন্ন!${NC}"
    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# BANGLA ANALYSIS
# ================================================================
bangla_analysis() {
    local outfile=$1

    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় স্ক্যান রিপোর্ট বিশ্লেষণ                      ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    [ ! -f "$outfile" ] && echo -e "  ${YELLOW}[!] Output ফাঁকা।${NC}" && echo "" && return

    local critical=0 high=0 medium=0 low=0

    # CVEs found
    local cve_count; cve_count=$(grep -coiE "CVE-[0-9]+-[0-9]+" "$outfile" 2>/dev/null || echo 0)
    if [ "$cve_count" -gt 0 ]; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 $cve_count টি CVE পাওয়া গেছে!${NC}"
        grep -oiE "CVE-[0-9]+-[0-9]+" "$outfile" | sort -u | head -5 | \
            while IFS= read -r cve; do echo -e "  ${RED}▸ $cve${NC}"; done
        echo -e "     ${WHITE}→ এই vulnerabilities exploit করা সম্ভব।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # Open critical ports
    if grep -qiE "port.*23|port.*telnet" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Telnet (Port 23) Open!${NC}"
        echo -e "     ${WHITE}→ Plaintext protocol — সব data intercept করা যায়।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    if grep -qiE "port.*3389|RDP" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ RDP (Port 3389) Exposed!${NC}"
        echo -e "     ${WHITE}→ Remote Desktop publicly accessible — brute force risk।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Exposed database
    if grep -qiE "MongoDB|Redis|Elasticsearch|CouchDB|Cassandra" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}🗄️  Database Service Detected!${NC}"
        grep -oiE "MongoDB|Redis|Elasticsearch|CouchDB|Cassandra|MySQL|PostgreSQL" \
            "$outfile" | sort -u | while IFS= read -r db; do
            echo -e "  ${YELLOW}▸ $db${NC}"
        done
        echo -e "     ${WHITE}→ Database authentication check করুন।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # ICS/SCADA
    if grep -qiE "Modbus|SCADA|Siemens|port.*502|BACnet" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🏭 ICS/SCADA Device Detected!${NC}"
        echo -e "     ${WHITE}→ Industrial control system publicly accessible!${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL — Critical infrastructure!${NC}"; echo ""
    fi

    # Default credentials device
    if grep -qiE "IP Camera|Webcam|Router|admin.*panel" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}📷 Exposed Device (Camera/Router) Detected!${NC}"
        echo -e "     ${WHITE}→ Default credential দিয়ে access পাওয়া সম্ভব।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Outdated software
    if grep -qiE "OpenSSH [1-6]\.|Apache/1\.|Apache/2\.[0-3]\." "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}⚠ Outdated Software Detected!${NC}"
        echo -e "     ${WHITE}→ পুরনো software version — known vulnerabilities থাকতে পারে।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # High device count
    local device_count; device_count=$(grep -cE "^[0-9]+\." "$outfile" 2>/dev/null || echo 0)
    if [ "$device_count" -gt 20 ]; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}📊 $device_count+ Devices/Results পাওয়া গেছে${NC}"
        echo -e "     ${WHITE}→ বড় attack surface।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # Honeypot warning
    if grep -qiE "honeypot|honeyscore" "$outfile" 2>/dev/null; then
        low=$((low+1))
        echo -e "  ${BLUE}${BOLD}🍯 Honeypot Score Available${NC}"
        echo -e "     ${WHITE}→ Score 0.0-1.0 scale এ। 0.5+ মানে honeypot হওয়ার সম্ভাবনা।${NC}"
        echo -e "     ${BLUE}→ Info${NC}"; echo ""
    fi

    # Risk summary
    echo -e "  ${CYAN}${BOLD}━━━ সামগ্রিক ঝুঁকি মূল্যায়ন ━━━${NC}"
    echo -e "  ${RED}   Critical : $critical টি${NC}"
    echo -e "  ${YELLOW}   High     : $high টি${NC}"
    echo -e "  ${CYAN}   Medium   : $medium টি${NC}"
    echo -e "  ${BLUE}   Low/Info : $low টি${NC}"
    echo ""

    if   [ "$critical" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}  সার্বিক ঝুঁকি : ██████████ CRITICAL — এখনই পদক্ষেপ নিন!${NC}"
    elif [ "$high" -gt 0 ]; then
        echo -e "  ${YELLOW}${BOLD}  সার্বিক ঝুঁকি : ███████░░░ HIGH — দ্রুত fix করুন।${NC}"
    elif [ "$medium" -gt 0 ]; then
        echo -e "  ${CYAN}  সার্বিক ঝুঁকি : █████░░░░░ MEDIUM — মনোযোগ দিন।${NC}"
    else
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW — তবু সতর্ক থাকুন।${NC}"
    fi
    echo ""
}

# ================================================================
# NEXT TOOL SUGGESTION
# ================================================================
suggest_next_tool() {
    local outfile=$1

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Tool এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # CVE found
    if grep -qiE "CVE-" "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}💀 Metasploit${NC} — CVE Exploitation"
        echo -e "     ${WHITE}কারণ: CVE পাওয়া গেছে → exploit আছে কিনা দেখুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: msfconsole → search <CVE-ID>${NC}"; echo ""
        echo -e "  ${MAGENTA}${BOLD}🔍 Nuclei${NC} — Template-based Vulnerability Scan"
        echo -e "     ${CYAN}কমান্ড: nuclei -u http://$TARGET -t http/cves${NC}"; echo ""
    fi

    # Open ports found
    if grep -qiE "80|443|8080|8443" "$outfile" 2>/dev/null; then
        echo -e "  ${WHITE}${BOLD}🌐 Nikto${NC} — Web Vulnerability Scan"
        echo -e "     ${CYAN}কমান্ড: nikto -h http://$TARGET${NC}"; echo ""
        echo -e "  ${GREEN}${BOLD}🔍 Dirsearch${NC} — Directory Discovery"
        echo -e "     ${CYAN}কমান্ড: dirsearch -u http://$TARGET -e php,html,js${NC}"; echo ""
    fi

    # SSH found
    if grep -qiE "port.*22|OpenSSH" "$outfile" 2>/dev/null; then
        echo -e "  ${YELLOW}${BOLD}🔑 Hydra${NC} — SSH Brute Force"
        echo -e "     ${CYAN}কমান্ড: hydra -L users.txt -P rockyou.txt ssh://$TARGET${NC}"; echo ""
    fi

    # RDP found
    if grep -qiE "3389|RDP" "$outfile" 2>/dev/null; then
        echo -e "  ${YELLOW}${BOLD}🔑 Hydra${NC} — RDP Brute Force"
        echo -e "     ${CYAN}কমান্ড: hydra -L users.txt -P rockyou.txt rdp://$TARGET${NC}"; echo ""
    fi

    # Database found
    if grep -qiE "MongoDB|Redis|MySQL|PostgreSQL" "$outfile" 2>/dev/null; then
        echo -e "  ${GREEN}${BOLD}💉 Direct DB Access Test${NC}"
        echo -e "     ${CYAN}MongoDB: mongo $TARGET:27017${NC}"
        echo -e "     ${CYAN}Redis: redis-cli -h $TARGET${NC}"; echo ""
    fi

    # General suggestions
    echo -e "  ${GREEN}${BOLD}🗺️  Nmap${NC} — Detailed Port/Service Scan"
    echo -e "     ${CYAN}কমান্ড: nmap -A -sV --script vuln $TARGET${NC}"; echo ""

    echo -e "  ${CYAN}${BOLD}🔒 SSLScan${NC} — SSL/TLS Analysis"
    echo -e "     ${CYAN}কমান্ড: sslscan $TARGET${NC}"; echo ""

    echo -e "  ${BLUE}${BOLD}🌐 WhatWeb${NC} — Technology Fingerprinting"
    echo -e "     ${CYAN}কমান্ড: whatweb http://$TARGET -a 3${NC}"; echo ""
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
        pre_scan_recon "$TARGET"
        show_menu

        read -p "$(echo -e ${YELLOW}"[?] Mode select করুন [0-29]: "${NC})" choice

        [[ "$choice" == "0" ]] && {
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            exit 0
        }

        case $choice in
            1)  mode_ip_info ;;
            2)  mode_domain_search ;;
            3)  mode_reverse_dns ;;
            4)  mode_asn_lookup ;;
            5)  mode_open_ports ;;
            6)  mode_vuln_check ;;
            7)  mode_custom_query ;;
            8)  mode_org_search ;;
            9)  mode_country_search ;;
            10) mode_port_search ;;
            11) mode_product_search ;;
            12) mode_banner_search ;;
            13) mode_ssl_search ;;
            14) mode_exposed_dbs ;;
            15) mode_ics_search ;;
            16) mode_default_creds ;;
            17) mode_webcam_search ;;
            18) mode_router_search ;;
            19) mode_vpn_search ;;
            20) mode_vuln_services ;;
            21) mode_cloud_search ;;
            22) mode_honeypot_check ;;
            23) mode_network_range ;;
            24) mode_my_ip ;;
            25) mode_trending_cve ;;
            26) mode_facet_analysis ;;
            27) mode_alert_setup ;;
            28) mode_full_recon ;;
            29) mode_allinone ;;
            *)  echo -e "${RED}[!] ভুল অপশন।${NC}" ;;
        esac

        echo ""
        read -p "$(echo -e ${YELLOW}"[?] আরেকটি scan করবেন? (y/n): "${NC})" again
        [[ ! "$again" =~ ^[Yy]$ ]] && {
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            exit 0
        }
        unset TARGET QUERY
        show_banner
    done
}

main
