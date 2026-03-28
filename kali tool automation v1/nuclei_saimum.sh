#!/bin/bash

# ================================================================
#   NUCLEI - Full Automation Tool
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

RESULTS_DIR="$HOME/nuclei_results"
HISTORY_FILE="$HOME/.nuclei_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo ' ███╗   ██╗██╗   ██╗ ██████╗██╗     ███████╗██╗'
    echo ' ████╗  ██║██║   ██║██╔════╝██║     ██╔════╝██║'
    echo ' ██╔██╗ ██║██║   ██║██║     ██║     █████╗  ██║'
    echo ' ██║╚██╗██║██║   ██║██║     ██║     ██╔══╝  ██║'
    echo ' ██║ ╚████║╚██████╔╝╚██████╗███████╗███████╗██║'
    echo ' ╚═╝  ╚═══╝ ╚═════╝  ╚═════╝╚══════╝╚══════╝╚═╝'
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}         Nuclei Full Automation Tool | Vulnerability Scanner${NC}"
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
    for tool in nuclei curl whois dig host; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
            echo -e "  ${RED}[✗] $tool — পাওয়া যায়নি${NC}"
        else
            echo -e "  ${GREEN}[✓] $tool${NC}"
        fi
    done

    # Nuclei templates check
    echo ""
    echo -e "${CYAN}[*] Nuclei templates চেক করা হচ্ছে...${NC}"
    local tmpl_dirs=(
        "$HOME/nuclei-templates"
        "$HOME/.local/nuclei-templates"
        "/usr/share/nuclei-templates"
    )
    TEMPLATE_DIR=""
    for d in "${tmpl_dirs[@]}"; do
        if [ -d "$d" ]; then
            TEMPLATE_DIR="$d"
            echo -e "  ${GREEN}[✓] Templates: $d${NC}"
            break
        fi
    done
    if [ -z "$TEMPLATE_DIR" ]; then
        echo -e "  ${YELLOW}[!] Templates পাওয়া যায়নি। 'nuclei -update-templates' চালান।${NC}"
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing tools: ${missing[*]}${NC}"
        echo -e "${YELLOW}Install করুন:${NC}"
        for m in "${missing[@]}"; do
            case "$m" in
                nuclei) echo -e "  ${WHITE}go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest${NC}" ;;
                curl)   echo -e "  ${WHITE}sudo apt install curl${NC}" ;;
                whois)  echo -e "  ${WHITE}sudo apt install whois${NC}" ;;
                dig)    echo -e "  ${WHITE}sudo apt install dnsutils${NC}" ;;
                host)   echo -e "  ${WHITE}sudo apt install bind9-host${NC}" ;;
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

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║         TARGET TYPE SELECT           ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo -e "  ${GREEN}1)${NC} Single URL / IP / Domain"
    echo -e "  ${GREEN}2)${NC} Multiple URLs (একটা একটা করে)"
    echo -e "  ${GREEN}3)${NC} File থেকে URL list (.txt)"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-3]: "${NC})" ttype

    case $ttype in
        1)
            read -p "$(echo -e ${WHITE}"URL / IP / Domain দিন: "${NC})" t
            [[ ! "$t" =~ ^https?:// ]] && t="http://$t"
            TARGETS=("${t%/}")
            ;;
        2)
            echo -e "${WHITE}একটা একটা করে দিন। শেষ হলে 'done' লিখুন:${NC}"
            while true; do
                read -p "$(echo -e ${WHITE}"URL: "${NC})" t
                [[ "$t" == "done" || -z "$t" ]] && break
                [[ ! "$t" =~ ^https?:// ]] && t="http://$t"
                TARGETS+=("${t%/}")
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
    local target=$1
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)
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
    local target=$1
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)
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
        echo -e "  ${YELLOW}[!] GeoIP data পাওয়া যায়নি (private IP হলে কাজ করে না)।${NC}"
    fi
    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# REVERSE DNS
# ================================================================
reverse_dns() {
    local target=$1
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)
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
    headers=$(curl -s -I --max-time 8 "$target" 2>/dev/null | head -25)
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
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}   PRE-SCAN RECON  ›  $target${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    whois_lookup      "$target"
    geoip_lookup      "$target"
    reverse_dns       "$target"
    http_header_check "$target"
}

# ================================================================
# SCAN MENU
# ================================================================
show_menu() {
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║                    NUCLEI SCAN OPTIONS                              ║${NC}"
    echo -e "${YELLOW}${BOLD}╠═══╦══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}1${NC}  ${YELLOW}║${NC} Quick Scan                    — দ্রুত সাধারণ vulnerability scan"
    echo -e "${YELLOW}║${NC} ${GREEN}2${NC}  ${YELLOW}║${NC} Full Scan                     — সব template দিয়ে সম্পূর্ণ scan"
    echo -e "${YELLOW}║${NC} ${GREEN}3${NC}  ${YELLOW}║${NC} CVE Scan                      — শুধু CVE templates"
    echo -e "${YELLOW}║${NC} ${GREEN}4${NC}  ${YELLOW}║${NC} Technology Detection          — web tech fingerprinting"
    echo -e "${YELLOW}║${NC} ${GREEN}5${NC}  ${YELLOW}║${NC} Exposed Panels & Admin        — exposed login/admin panels"
    echo -e "${YELLOW}║${NC} ${GREEN}6${NC}  ${YELLOW}║${NC} Misconfiguration Scan         — server misconfig খোঁজা"
    echo -e "${YELLOW}║${NC} ${GREEN}7${NC}  ${YELLOW}║${NC} Default Login Scan            — default username/password check"
    echo -e "${YELLOW}║${NC} ${GREEN}8${NC}  ${YELLOW}║${NC} Subdomain Takeover            — dangling DNS / takeover check"
    echo -e "${YELLOW}║${NC} ${GREEN}9${NC}  ${YELLOW}║${NC} Network Scan                  — network protocol vulnerability"
    echo -e "${YELLOW}║${NC} ${GREEN}10${NC} ${YELLOW}║${NC} DNS Scan                      — DNS misconfiguration & vuln"
    echo -e "${YELLOW}║${NC} ${GREEN}11${NC} ${YELLOW}║${NC} SSL/TLS Scan                  — certificate & cipher weakness"
    echo -e "${YELLOW}║${NC} ${GREEN}12${NC} ${YELLOW}║${NC} Fuzzing Scan                  — parameter & endpoint fuzzing"
    echo -e "${YELLOW}║${NC} ${GREEN}13${NC} ${YELLOW}║${NC} WordPress Scan                — WP plugin/theme CVE"
    echo -e "${YELLOW}║${NC} ${GREEN}14${NC} ${YELLOW}║${NC} API Security Scan             — REST API vulnerability"
    echo -e "${YELLOW}║${NC} ${GREEN}15${NC} ${YELLOW}║${NC} Cloud Security Scan           — cloud misconfig (AWS/GCP/Azure)"
    echo -e "${YELLOW}║${NC} ${GREEN}16${NC} ${YELLOW}║${NC} Severity: Critical Only       — শুধু Critical findings"
    echo -e "${YELLOW}║${NC} ${GREEN}17${NC} ${YELLOW}║${NC} Severity: High & Critical     — High + Critical"
    echo -e "${YELLOW}║${NC} ${GREEN}18${NC} ${YELLOW}║${NC} Severity: Medium+             — Medium, High, Critical"
    echo -e "${YELLOW}║${NC} ${GREEN}19${NC} ${YELLOW}║${NC} Severity: Info (সব)          — সব severity একসাথে"
    echo -e "${YELLOW}║${NC} ${GREEN}20${NC} ${YELLOW}║${NC} Custom Template Path          — নিজের template দাও"
    echo -e "${YELLOW}║${NC} ${GREEN}21${NC} ${YELLOW}║${NC} Multiple Modes একসাথে        — পছন্দমতো mode combine করো"
    echo -e "${YELLOW}║${NC} ${GREEN}22${NC} ${YELLOW}║${NC} All-in-One Mega Scan          — সব mode + সব severity"
    echo -e "${YELLOW}${BOLD}╠═══╩══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${RED}0)${NC} Exit                                                               ${YELLOW}║${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ================================================================
# EXTRA OPTIONS
# ================================================================
get_extra_options() {
    RATE_OPT=""
    PROXY_OPT=""
    TIMEOUT_OPT=""
    RETRIES_OPT=""
    HEADER_OPT=""
    SILENT_OPT=""

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║         EXTRA OPTIONS                ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""

    read -p "$(echo -e ${WHITE}"Rate limit (req/sec, Enter=150): "${NC})" rate_in
    [ -n "$rate_in" ] && RATE_OPT="-rate-limit $rate_in" || RATE_OPT="-rate-limit 150"

    read -p "$(echo -e ${WHITE}"Timeout (seconds, Enter=10): "${NC})" to_in
    [ -n "$to_in" ] && TIMEOUT_OPT="-timeout $to_in" || TIMEOUT_OPT="-timeout 10"

    read -p "$(echo -e ${WHITE}"Retries (Enter=1): "${NC})" ret_in
    [ -n "$ret_in" ] && RETRIES_OPT="-retries $ret_in" || RETRIES_OPT="-retries 1"

    read -p "$(echo -e ${WHITE}"Proxy দিন (Enter=skip, e.g. http://127.0.0.1:8080): "${NC})" proxy_in
    [ -n "$proxy_in" ] && PROXY_OPT="-proxy $proxy_in"

    read -p "$(echo -e ${WHITE}"Custom Header দিন (Enter=skip, e.g. 'X-Token: abc'): "${NC})" hdr_in
    [ -n "$hdr_in" ] && HEADER_OPT="-H \"$hdr_in\""

    read -p "$(echo -e ${WHITE}"Silent mode? শুধু findings দেখাবে (y/n, Enter=n): "${NC})" silent_in
    [[ "$silent_in" =~ ^[Yy]$ ]] && SILENT_OPT="-silent"

    echo ""
}

# ================================================================
# BUILD NUCLEI COMMAND
# ================================================================
build_nuclei_cmd() {
    local mode=$1
    local target=$2
    local cmd="nuclei"
    local templates=""

    # Target
    if [ -n "$TARGET_FILE" ]; then
        cmd="$cmd -l \"$TARGET_FILE\""
    else
        cmd="$cmd -u \"$target\""
    fi

    # Mode → templates / flags
    case $mode in
        1)  templates="-t http/technologies -t http/misconfigured -t http/vulnerabilities -severity medium,high,critical"
            scan_label="Quick Scan" ;;
        2)  templates="-t ."
            scan_label="Full Scan" ;;
        3)  templates="-t http/cves -t network/cves"
            scan_label="CVE Scan" ;;
        4)  templates="-t http/technologies"
            scan_label="Technology Detection" ;;
        5)  templates="-t http/exposed-panels -t http/takeovers"
            scan_label="Exposed Panels & Admin" ;;
        6)  templates="-t http/misconfigured -t http/miscellaneous"
            scan_label="Misconfiguration Scan" ;;
        7)  templates="-t http/default-logins -t network/default-logins"
            scan_label="Default Login Scan" ;;
        8)  templates="-t dns/takeovers -t http/takeovers"
            scan_label="Subdomain Takeover" ;;
        9)  templates="-t network"
            scan_label="Network Scan" ;;
        10) templates="-t dns"
            scan_label="DNS Scan" ;;
        11) templates="-t ssl"
            scan_label="SSL/TLS Scan" ;;
        12) templates="-t http/fuzzing"
            scan_label="Fuzzing Scan" ;;
        13) templates="-t http/vulnerabilities/wordpress -t http/cves/wordpress"
            scan_label="WordPress Scan" ;;
        14) templates="-t http/vulnerabilities/generic -t http/fuzzing/json-fuzzing"
            scan_label="API Security Scan" ;;
        15) templates="-t cloud"
            scan_label="Cloud Security Scan" ;;
        16) templates="-severity critical"
            scan_label="Critical Only" ;;
        17) templates="-severity high,critical"
            scan_label="High & Critical" ;;
        18) templates="-severity medium,high,critical"
            scan_label="Medium+" ;;
        19) templates="-severity info,low,medium,high,critical"
            scan_label="All Severities" ;;
        20)
            read -p "$(echo -e ${WHITE}"Template path দিন: "${NC})" custom_tmpl
            templates="-t \"$custom_tmpl\""
            scan_label="Custom Template"
            ;;
    esac

    # Output file
    local ts
    ts=$(date +"%Y%m%d_%H%M%S")
    local safe_target
    safe_target=$(echo "$target" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g')
    OUTPUT_FILE="$RESULTS_DIR/nuclei_${safe_target}_${ts}.txt"
    JSON_FILE="$RESULTS_DIR/nuclei_${safe_target}_${ts}.json"

    cmd="$cmd $templates $RATE_OPT $TIMEOUT_OPT $RETRIES_OPT $PROXY_OPT $HEADER_OPT $SILENT_OPT"
    cmd="$cmd -o \"$OUTPUT_FILE\" -jsonl -output \"$JSON_FILE\""
    cmd="$cmd -stats -no-color"

    FINAL_CMD="$cmd"
    SCAN_LABEL="$scan_label"
}

# ================================================================
# BUILD ALL-IN-ONE COMMAND
# ================================================================
build_allinone_cmd() {
    local target=$1
    local ts
    ts=$(date +"%Y%m%d_%H%M%S")
    local safe_target
    safe_target=$(echo "$target" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g')
    OUTPUT_FILE="$RESULTS_DIR/nuclei_ALLINONE_${safe_target}_${ts}.txt"
    JSON_FILE="$RESULTS_DIR/nuclei_ALLINONE_${safe_target}_${ts}.json"

    local base_cmd="nuclei"
    if [ -n "$TARGET_FILE" ]; then
        base_cmd="$base_cmd -l \"$TARGET_FILE\""
    else
        base_cmd="$base_cmd -u \"$target\""
    fi

    FINAL_CMD="$base_cmd -t . -severity info,low,medium,high,critical"
    FINAL_CMD="$FINAL_CMD $RATE_OPT $TIMEOUT_OPT $RETRIES_OPT $PROXY_OPT $HEADER_OPT $SILENT_OPT"
    FINAL_CMD="$FINAL_CMD -o \"$OUTPUT_FILE\" -jsonl -output \"$JSON_FILE\" -stats -no-color"
    SCAN_LABEL="All-in-One Mega Scan"
}

# ================================================================
# BUILD MULTI-MODE COMMAND
# ================================================================
build_multimode_cmd() {
    local target=$1
    echo ""
    echo -e "${CYAN}${BOLD}কোন mode গুলো একসাথে চালাবেন? (নম্বর দিন, space দিয়ে আলাদা করুন)${NC}"
    echo -e "${DIM}উদাহরণ: 3 5 6 9 (CVE + Exposed Panels + Misconfiguration + Network)${NC}"
    echo ""
    show_menu
    read -p "$(echo -e ${YELLOW}"Mode numbers দিন: "${NC})" mode_list

    local combined_templates=""
    local combined_severity=""
    local labels=()

    for m in $mode_list; do
        case $m in
            1) combined_templates="$combined_templates -t http/technologies -t http/misconfigured -t http/vulnerabilities"
               labels+=("Quick") ;;
            2) combined_templates="-t ."; labels+=("Full"); break ;;
            3) combined_templates="$combined_templates -t http/cves -t network/cves"; labels+=("CVE") ;;
            4) combined_templates="$combined_templates -t http/technologies"; labels+=("TechDetect") ;;
            5) combined_templates="$combined_templates -t http/exposed-panels -t http/takeovers"; labels+=("ExposedPanels") ;;
            6) combined_templates="$combined_templates -t http/misconfigured -t http/miscellaneous"; labels+=("Misconfiguration") ;;
            7) combined_templates="$combined_templates -t http/default-logins -t network/default-logins"; labels+=("DefaultLogin") ;;
            8) combined_templates="$combined_templates -t dns/takeovers -t http/takeovers"; labels+=("Takeover") ;;
            9) combined_templates="$combined_templates -t network"; labels+=("Network") ;;
            10) combined_templates="$combined_templates -t dns"; labels+=("DNS") ;;
            11) combined_templates="$combined_templates -t ssl"; labels+=("SSL") ;;
            12) combined_templates="$combined_templates -t http/fuzzing"; labels+=("Fuzzing") ;;
            13) combined_templates="$combined_templates -t http/vulnerabilities/wordpress"; labels+=("WordPress") ;;
            14) combined_templates="$combined_templates -t http/vulnerabilities/generic"; labels+=("API") ;;
            15) combined_templates="$combined_templates -t cloud"; labels+=("Cloud") ;;
            16) combined_severity="-severity critical"; labels+=("CriticalOnly") ;;
            17) combined_severity="-severity high,critical"; labels+=("High+Critical") ;;
            18) combined_severity="-severity medium,high,critical"; labels+=("Medium+") ;;
            19) combined_severity="-severity info,low,medium,high,critical"; labels+=("AllSeverity") ;;
        esac
    done

    local ts
    ts=$(date +"%Y%m%d_%H%M%S")
    local safe_target
    safe_target=$(echo "$target" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g')
    OUTPUT_FILE="$RESULTS_DIR/nuclei_MULTI_${safe_target}_${ts}.txt"
    JSON_FILE="$RESULTS_DIR/nuclei_MULTI_${safe_target}_${ts}.json"

    local base_cmd="nuclei"
    if [ -n "$TARGET_FILE" ]; then
        base_cmd="$base_cmd -l \"$TARGET_FILE\""
    else
        base_cmd="$base_cmd -u \"$target\""
    fi

    [ -z "$combined_severity" ] && combined_severity="-severity info,low,medium,high,critical"

    FINAL_CMD="$base_cmd $combined_templates $combined_severity"
    FINAL_CMD="$FINAL_CMD $RATE_OPT $TIMEOUT_OPT $RETRIES_OPT $PROXY_OPT $HEADER_OPT $SILENT_OPT"
    FINAL_CMD="$FINAL_CMD -o \"$OUTPUT_FILE\" -jsonl -output \"$JSON_FILE\" -stats -no-color"
    SCAN_LABEL="Multi-Mode (${labels[*]})"
}

# ================================================================
# RUN SCAN
# ================================================================
run_scan() {
    local choice=$1
    local target=$2

    # Build command based on choice
    if [ "$choice" -eq 21 ]; then
        build_multimode_cmd "$target"
    elif [ "$choice" -eq 22 ]; then
        build_allinone_cmd "$target"
    else
        build_nuclei_cmd "$choice" "$target"
    fi

    # Show preview
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}Scan Type : ${YELLOW}${BOLD}$SCAN_LABEL${NC}"
    echo -e "  ${WHITE}Target    : ${GREEN}${BOLD}$target${NC}"
    echo -e "  ${WHITE}Command   : ${CYAN}${FINAL_CMD}${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] Scan শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local tmp_out
    tmp_out=$(mktemp)

    echo ""
    echo -e "${GREEN}${BOLD}[*] Nuclei scan শুরু হচ্ছে...${NC}"
    echo ""

    eval "$FINAL_CMD" 2>&1 | tee "$tmp_out"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Scan সম্পন্ন!${NC}"
    echo ""

    # Analysis
    bangla_analysis "$tmp_out" "$OUTPUT_FILE"

    # Next tool suggestion
    suggest_next_tool "$tmp_out"

    # Save
    save_results "$target" "$tmp_out"

    rm -f "$tmp_out"
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

    local critical=0 high=0 medium=0 low=0 info=0

    # Count severities
    critical=$(grep -ci "\[critical\]" "$outfile" 2>/dev/null || echo 0)
    high=$(grep -ci "\[high\]" "$outfile" 2>/dev/null || echo 0)
    medium=$(grep -ci "\[medium\]" "$outfile" 2>/dev/null || echo 0)
    low=$(grep -ci "\[low\]" "$outfile" 2>/dev/null || echo 0)
    info=$(grep -ci "\[info\]" "$outfile" 2>/dev/null || echo 0)

    local total=$((critical + high + medium + low + info))

    if [ "$total" -eq 0 ]; then
        echo -e "  ${GREEN}[✓] কোনো vulnerability পাওয়া যায়নি বা scan output ফাঁকা।${NC}"
        echo -e "  ${YELLOW}[!] Template update করুন: nuclei -update-templates${NC}"
    else
        echo -e "  ${CYAN}${BOLD}━━━ Findings বিস্তারিত বিশ্লেষণ ━━━${NC}"
        echo ""

        # Critical findings
        if [ "$critical" -gt 0 ]; then
            echo -e "  ${RED}${BOLD}🚨 CRITICAL ($critical টি পাওয়া গেছে):${NC}"
            grep -i "\[critical\]" "$outfile" 2>/dev/null | head -10 | while IFS= read -r line; do
                echo -e "     ${RED}▸ $line${NC}"
            done
            echo -e "     ${WHITE}→ এগুলো সর্বোচ্চ ঝুঁকিপূর্ণ। এখনই fix করুন!${NC}"
            echo ""
        fi

        # High findings
        if [ "$high" -gt 0 ]; then
            echo -e "  ${YELLOW}${BOLD}⚠ HIGH ($high টি পাওয়া গেছে):${NC}"
            grep -i "\[high\]" "$outfile" 2>/dev/null | head -10 | while IFS= read -r line; do
                echo -e "     ${YELLOW}▸ $line${NC}"
            done
            echo -e "     ${WHITE}→ দ্রুত patch করা দরকার।${NC}"
            echo ""
        fi

        # Medium findings
        if [ "$medium" -gt 0 ]; then
            echo -e "  ${CYAN}${BOLD}ℹ MEDIUM ($medium টি পাওয়া গেছে):${NC}"
            grep -i "\[medium\]" "$outfile" 2>/dev/null | head -8 | while IFS= read -r line; do
                echo -e "     ${CYAN}▸ $line${NC}"
            done
            echo -e "     ${WHITE}→ মনোযোগ দেওয়া দরকার, শীঘ্রই fix করুন।${NC}"
            echo ""
        fi

        # Low findings
        if [ "$low" -gt 0 ]; then
            echo -e "  ${GREEN}${BOLD}✓ LOW ($low টি পাওয়া গেছে):${NC}"
            grep -i "\[low\]" "$outfile" 2>/dev/null | head -5 | while IFS= read -r line; do
                echo -e "     ${GREEN}▸ $line${NC}"
            done
            echo ""
        fi

        # Info findings
        if [ "$info" -gt 0 ]; then
            echo -e "  ${BLUE}${BOLD}📌 INFO ($info টি পাওয়া গেছে):${NC}"
            echo -e "     ${BLUE}→ Technology detection ও informational findings।${NC}"
            echo ""
        fi

        # Technology detected
        if grep -qi "tech-detect\|technology\|fingerprint" "$outfile" 2>/dev/null; then
            echo -e "  ${BLUE}${BOLD}🖥️  Technology Fingerprint:${NC}"
            grep -i "tech-detect\|technology" "$outfile" 2>/dev/null | head -5 | while IFS= read -r line; do
                echo -e "     ${BLUE}▸ $line${NC}"
            done
            echo ""
        fi

        # CVE found
        if grep -qi "CVE-" "$outfile" 2>/dev/null; then
            echo -e "  ${RED}${BOLD}💀 CVE Findings:${NC}"
            grep -i "CVE-" "$outfile" 2>/dev/null | grep -oE "CVE-[0-9]+-[0-9]+" | sort -u | head -10 | while IFS= read -r cve; do
                echo -e "     ${RED}▸ $cve পাওয়া গেছে — NVD এ details দেখুন।${NC}"
            done
            echo ""
        fi

        # Default login found
        if grep -qi "default-login\|default-credentials" "$outfile" 2>/dev/null; then
            echo -e "  ${RED}${BOLD}🔑 Default Login পাওয়া গেছে!${NC}"
            echo -e "     ${WHITE}→ Device/application এ factory password এখনো আছে!${NC}"
            echo -e "     ${RED}→ এখনই password change করুন। ঝুঁকি: CRITICAL${NC}"
            echo ""
        fi

        # Exposed panel found
        if grep -qi "exposed-panel\|admin-panel\|login-panel" "$outfile" 2>/dev/null; then
            echo -e "  ${YELLOW}${BOLD}🖥️  Exposed Admin Panel পাওয়া গেছে!${NC}"
            echo -e "     ${WHITE}→ Admin panel publicly accessible।${NC}"
            echo -e "     ${YELLOW}→ IP whitelist বা VPN দিয়ে protect করুন।${NC}"
            echo ""
        fi

        # Subdomain takeover
        if grep -qi "takeover\|subdomain-takeover" "$outfile" 2>/dev/null; then
            echo -e "  ${RED}${BOLD}🌐 Subdomain Takeover সম্ভব!${NC}"
            echo -e "     ${WHITE}→ Dangling DNS record আছে — কেউ এই subdomain দখল নিতে পারে।${NC}"
            echo -e "     ${RED}→ ঝুঁকি: HIGH — DNS record সরিয়ে ফেলুন।${NC}"
            echo ""
        fi

        # SSL issues
        if grep -qi "ssl\|tls\|certificate" "$outfile" 2>/dev/null; then
            echo -e "  ${CYAN}${BOLD}🔒 SSL/TLS Issues:${NC}"
            echo -e "     ${WHITE}→ Certificate বা cipher সংক্রান্ত সমস্যা পাওয়া গেছে।${NC}"
            echo -e "     ${CYAN}→ SSLScan বা testssl.sh দিয়ে বিস্তারিত দেখুন।${NC}"
            echo ""
        fi

        # Misconfiguration
        if grep -qi "misconfigur\|misconfig" "$outfile" 2>/dev/null; then
            echo -e "  ${YELLOW}${BOLD}⚙️  Misconfiguration পাওয়া গেছে!${NC}"
            echo -e "     ${WHITE}→ Server configuration এ ভুল আছে।${NC}"
            echo -e "     ${YELLOW}→ Server hardening guide ফলো করুন।${NC}"
            echo ""
        fi

        # Cloud issues
        if grep -qi "aws\|s3\|gcp\|azure\|cloud" "$outfile" 2>/dev/null; then
            echo -e "  ${YELLOW}${BOLD}☁️  Cloud Misconfiguration:${NC}"
            echo -e "     ${WHITE}→ Cloud resource publicly accessible হতে পারে।${NC}"
            echo -e "     ${RED}→ S3 bucket / cloud storage permission check করুন।${NC}"
            echo ""
        fi

        # Risk summary
        echo -e "  ${CYAN}${BOLD}━━━ সামগ্রিক ঝুঁকি মূল্যায়ন ━━━${NC}"
        echo -e "  ${RED}   Critical : $critical টি${NC}"
        echo -e "  ${YELLOW}   High     : $high টি${NC}"
        echo -e "  ${CYAN}   Medium   : $medium টি${NC}"
        echo -e "  ${GREEN}   Low      : $low টি${NC}"
        echo -e "  ${BLUE}   Info     : $info টি${NC}"
        echo -e "  ${WHITE}   মোট     : $total টি${NC}"
        echo ""

        if   [ "$critical" -gt 0 ]; then
            echo -e "  ${RED}${BOLD}  সার্বিক ঝুঁকি : ██████████ CRITICAL — এখনই পদক্ষেপ নিন!${NC}"
        elif [ "$high" -gt 0 ]; then
            echo -e "  ${YELLOW}${BOLD}  সার্বিক ঝুঁকি : ███████░░░ HIGH — দ্রুত patch করুন।${NC}"
        elif [ "$medium" -gt 0 ]; then
            echo -e "  ${CYAN}  সার্বিক ঝুঁকি : █████░░░░░ MEDIUM — মনোযোগ দিন।${NC}"
        elif [ "$low" -gt 0 ]; then
            echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW — তবু সতর্ক থাকুন।${NC}"
        else
            echo -e "  ${BLUE}  সার্বিক ঝুঁকি : ██░░░░░░░░ INFO — শুধু informational findings।${NC}"
        fi
        echo ""
    fi
    } | tee -a "$report_file"
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

    local found=0

    # CVE found → Metasploit
    if grep -qi "CVE-" "$outfile" 2>/dev/null; then
        found=1
        local cves
        cves=$(grep -oiE "CVE-[0-9]+-[0-9]+" "$outfile" | sort -u | head -3 | tr '\n' ', ')
        echo -e "  ${RED}${BOLD}💀 Metasploit${NC} — CVE Exploitation"
        echo -e "     ${WHITE}কারণ: CVE পাওয়া গেছে ($cves) → exploit আছে কিনা দেখুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: msfconsole → search <CVE-ID> → use exploit/...${NC}"
        echo ""
    fi

    # SQL injection hint → SQLmap
    if grep -qi "sql-injection\|sqli\|error-based\|sql" "$outfile" 2>/dev/null; then
        found=1
        echo -e "  ${GREEN}${BOLD}💉 SQLmap${NC} — SQL Injection Exploitation"
        echo -e "     ${WHITE}কারণ: SQL injection vulnerability পাওয়া গেছে।${NC}"
        echo -e "     ${CYAN}কমান্ড: sqlmap -u \"<url>\" --dbs --batch --level=3${NC}"
        echo ""
    fi

    # Default login → Hydra
    if grep -qi "default-login\|default-credentials" "$outfile" 2>/dev/null; then
        found=1
        echo -e "  ${YELLOW}${BOLD}🔑 Hydra${NC} — Credential Brute Force"
        echo -e "     ${WHITE}কারণ: Default login panel পাওয়া গেছে।${NC}"
        echo -e "     ${CYAN}কমান্ড: hydra -L users.txt -P rockyou.txt <target> http-post-form \"/login:user=^USER^&pass=^PASS^:F=wrong\"${NC}"
        echo ""
    fi

    # Exposed panel → Gobuster/FFUF
    if grep -qi "exposed-panel\|admin\|login" "$outfile" 2>/dev/null; then
        found=1
        echo -e "  ${MAGENTA}${BOLD}🔍 Gobuster / FFUF${NC} — Hidden Directory Discovery"
        echo -e "     ${WHITE}কারণ: Admin panel পাওয়া গেছে → আরো hidden paths থাকতে পারে।${NC}"
        echo -e "     ${CYAN}কমান্ড: gobuster dir -u <target> -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt${NC}"
        echo ""
    fi

    # WordPress → WPScan
    if grep -qi "wordpress\|wp-" "$outfile" 2>/dev/null; then
        found=1
        echo -e "  ${BLUE}${BOLD}🔧 WPScan${NC} — WordPress Deep Scan"
        echo -e "     ${WHITE}কারণ: WordPress detect হয়েছে।${NC}"
        echo -e "     ${CYAN}কমান্ড: wpscan --url <target> --enumerate u,vp,ap --api-token <TOKEN>${NC}"
        echo ""
    fi

    # Subdomain takeover → Subfinder
    if grep -qi "takeover\|subdomain" "$outfile" 2>/dev/null; then
        found=1
        echo -e "  ${GREEN}${BOLD}🌐 Subfinder${NC} — Subdomain Enumeration"
        echo -e "     ${WHITE}কারণ: Subdomain takeover সম্ভব → আরো subdomains খুঁজুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: subfinder -d <domain> -o subdomains.txt${NC}"
        echo ""
    fi

    # SSL issues → SSLScan
    if grep -qi "ssl\|tls\|certificate" "$outfile" 2>/dev/null; then
        found=1
        echo -e "  ${CYAN}${BOLD}🔒 SSLScan${NC} — SSL/TLS Deep Analysis"
        echo -e "     ${WHITE}কারণ: SSL/TLS vulnerability পাওয়া গেছে।${NC}"
        echo -e "     ${CYAN}কমান্ড: sslscan <target>${NC}"
        echo ""
    fi

    # Cloud misconfig → Manual check
    if grep -qi "aws\|s3\|gcp\|azure" "$outfile" 2>/dev/null; then
        found=1
        echo -e "  ${YELLOW}${BOLD}☁️  AWS CLI / Cloud Tools${NC} — Cloud Resource Check"
        echo -e "     ${WHITE}কারণ: Cloud misconfiguration পাওয়া গেছে।${NC}"
        echo -e "     ${CYAN}কমান্ড: aws s3 ls s3://<bucket-name> --no-sign-request${NC}"
        echo ""
    fi

    # Web tech found → Nikto
    if grep -qi "tech-detect\|technology\|apache\|nginx\|php\|iis" "$outfile" 2>/dev/null; then
        found=1
        echo -e "  ${WHITE}${BOLD}🌐 Nikto${NC} — Full Web Vulnerability Scan"
        echo -e "     ${WHITE}কারণ: Web technology fingerprint পাওয়া গেছে → deeper scan করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: nikto -h <target>${NC}"
        echo ""
        echo -e "  ${WHITE}${BOLD}⚡ HTTPx${NC} — HTTP Probe & Response Analysis"
        echo -e "     ${WHITE}কারণ: Web server আছে → status, headers, title একসাথে দেখুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: echo \"<target>\" | httpx -title -tech-detect -status-code${NC}"
        echo ""
    fi

    # Misconfiguration → Manual audit
    if grep -qi "misconfigur\|misconfig\|exposed" "$outfile" 2>/dev/null; then
        found=1
        echo -e "  ${MAGENTA}${BOLD}🔍 Burp Suite${NC} — Manual Exploitation"
        echo -e "     ${WHITE}কারণ: Misconfiguration পাওয়া গেছে → manually exploit করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: burpsuite (Repeater / Intruder)${NC}"
        echo ""
    fi

    # Network service → Nmap
    if grep -qi "network\|port\|service" "$outfile" 2>/dev/null; then
        found=1
        echo -e "  ${GREEN}${BOLD}🗺️  Nmap${NC} — Network Port Deep Scan"
        echo -e "     ${WHITE}কারণ: Network service vulnerability পাওয়া গেছে।${NC}"
        echo -e "     ${CYAN}কমান্ড: nmap -A -sV --script vuln <target>${NC}"
        echo ""
    fi

    if [ "$found" -eq 0 ]; then
        echo -e "  ${YELLOW}[!] নির্দিষ্ট কোনো finding নেই।${NC}"
        echo -e "  ${CYAN}💡 Templates update করে আবার চেষ্টা করুন: nuclei -update-templates${NC}"
        echo -e "  ${CYAN}💡 Full scan করুন: nuclei -u <target> -t . -severity info,low,medium,high,critical${NC}"
        echo ""
    fi
}

# ================================================================
# SAVE RESULTS
# ================================================================
save_results() {
    local target=$1
    local tmp_out=$2

    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Result আলাদা report file এ save করবেন? (y/n): "${NC})" sc
    if [[ "$sc" =~ ^[Yy]$ ]]; then
        local ts
        ts=$(date +"%Y%m%d_%H%M%S")
        local safe
        safe=$(echo "$target" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g')
        local fname="$RESULTS_DIR/report_${safe}_${ts}.txt"

        {
            echo "============================================================"
            echo "  NUCLEI SCAN RESULTS  —  SAIMUM's Nuclei Automation Tool"
            echo "  Target  : $target"
            echo "  Mode    : $SCAN_LABEL"
            echo "  Date    : $(date)"
            echo "============================================================"
            echo ""
            echo "=== NUCLEI RAW OUTPUT ==="
            cat "$tmp_out"
            echo ""
            echo "=== BANGLA ANALYSIS ==="
            sed 's/\x1b\[[0-9;]*m//g' "$OUTPUT_FILE" 2>/dev/null
        } > "$fname"

        echo -e "${GREEN}[✓] Report saved → $fname${NC}"
        echo "$(date) | $SCAN_LABEL | $target | $fname" >> "$HISTORY_FILE"
    else
        echo -e "${GREEN}[✓] Raw output saved → $OUTPUT_FILE${NC}"
        echo "$(date) | $SCAN_LABEL | $target | $OUTPUT_FILE" >> "$HISTORY_FILE"
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
        get_targets
        get_extra_options

        # Pre-scan recon
        if [ -n "$TARGET_FILE" ]; then
            echo -e "${CYAN}[*] File mode — pre-scan recon skip (multiple targets)${NC}"
        else
            for t in "${TARGETS[@]}"; do
                pre_scan_recon "$t"
            done
        fi

        show_menu
        read -p "$(echo -e ${YELLOW}"[?] Scan option select করুন [0-22]: "${NC})" choice

        if [[ "$choice" == "0" ]]; then
            echo ""
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            echo ""
            exit 0
        fi

        if [ -n "$TARGET_FILE" ]; then
            run_scan "$choice" "file:$TARGET_FILE"
        else
            for t in "${TARGETS[@]}"; do
                echo ""
                echo -e "${CYAN}${BOLD}══════════════ Target: $t ══════════════${NC}"
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
        unset TARGETS TARGET_FILE
        show_banner
    done
}

main
