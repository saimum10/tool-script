#!/bin/bash

# ================================================================
#   FFUF - Full Automation Tool  v2.0
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

RESULTS_DIR="$HOME/ffuf_results"
HISTORY_FILE="$HOME/.ffuf_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${YELLOW}${BOLD}"
    echo '  ███████╗███████╗██╗   ██╗███████╗'
    echo '  ██╔════╝██╔════╝██║   ██║██╔════╝'
    echo '  █████╗  █████╗  ██║   ██║█████╗  '
    echo '  ██╔══╝  ██╔══╝  ██║   ██║██╔══╝  '
    echo '  ██║     ██║     ╚██████╔╝██║     '
    echo '  ╚═╝     ╚═╝      ╚═════╝ ╚═╝     '
    echo -e "${NC}"
    echo -e "${WHITE}${BOLD}"
    echo '  ███████╗██╗   ██╗███████╗███████╗███████╗██████╗ '
    echo '  ██╔════╝██║   ██║╚══███╔╝╚══███╔╝██╔════╝██╔══██╗'
    echo '  █████╗  ██║   ██║  ███╔╝   ███╔╝ █████╗  ██████╔╝'
    echo '  ██╔══╝  ██║   ██║ ███╔╝   ███╔╝  ██╔══╝  ██╔══██╗'
    echo '  ██║     ╚██████╔╝███████╗███████╗███████╗██║  ██║'
    echo '  ╚═╝      ╚═════╝ ╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝'
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}         FFUF Full Automation Tool | Fast Web Fuzzer${NC}"
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
    for tool in ffuf curl whois dig host; do
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
    local wordlists=(
        "/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
        "/usr/share/wordlists/dirbuster/directory-list-2.3-small.txt"
        "/usr/share/seclists/Discovery/Web-Content/common.txt"
        "/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt"
        "/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt"
    )
    for wl in "${wordlists[@]}"; do
        if [ -f "$wl" ]; then
            echo -e "  ${GREEN}[✓] $wl${NC}"
        else
            echo -e "  ${YELLOW}[!] $wl — নেই (custom path দিতে পারবেন)${NC}"
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing tools: ${missing[*]}${NC}"
        echo -e "${YELLOW}Install করুন:${NC}"
        for m in "${missing[@]}"; do
            case "$m" in
                ffuf)  echo -e "  ${WHITE}sudo apt install ffuf${NC}" ;;
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
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║         TARGET TYPE SELECT           ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo -e "  ${GREEN}1)${NC} Single URL / Domain"
    echo -e "  ${GREEN}2)${NC} Multiple URLs (একটা একটা করে)"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-2]: "${NC})" ttype

    case $ttype in
        1)
            read -p "$(echo -e ${WHITE}"URL দিন (যেমন: http://example.com): "${NC})" t
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
        local country region city isp lat lon ip
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
    # Multiple IPs = CDN hint
    local ip_count
    ip_count=$(dig +short "$domain" 2>/dev/null | grep -cE '^[0-9]+\.' || true)
    [ "$ip_count" -gt 1 ] && echo -e "  ${YELLOW}[!] Multiple IPs ($ip_count) — CDN/Load Balancer সম্ভব।${NC}"
    echo -e "${GREEN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# HTTP PRE-CHECK  (FFUF specific)
# ================================================================
http_precheck() {
    local target=$1
    echo -e "${CYAN}${BOLD}┌─── HTTP PRE-CHECK ────────────────────────────────┐${NC}"
    local headers
    headers=$(curl -sI --max-time 8 "$target" 2>/dev/null)
    if [ -z "$headers" ]; then
        echo -e "  ${RED}[!] Target unreachable।${NC}"
        echo -e "${CYAN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
        echo ""
        return
    fi

    local code server powered location
    code=$(echo     "$headers" | head -1 | tr -d '\r')
    server=$(echo   "$headers" | grep -i "^Server:"       | head -1 | cut -d: -f2- | xargs)
    powered=$(echo  "$headers" | grep -i "^X-Powered-By:" | head -1 | cut -d: -f2- | xargs)
    location=$(echo "$headers" | grep -i "^Location:"     | head -1 | cut -d: -f2- | xargs)

    echo -e "  ${WHITE}Status    :${NC} ${GREEN}$code${NC}"
    [ -n "$server"   ] && echo -e "  ${WHITE}Server    :${NC} ${YELLOW}$server${NC}"
    [ -n "$powered"  ] && echo -e "  ${WHITE}Powered By:${NC} ${YELLOW}$powered${NC}"
    [ -n "$location" ] && echo -e "  ${YELLOW}[!] Redirect → $location${NC}"

    echo ""
    echo -e "  ${CYAN}Security Headers:${NC}"
    for hdr in "Strict-Transport-Security" "Content-Security-Policy" \
               "X-Frame-Options" "X-XSS-Protection" "X-Content-Type-Options" \
               "Permissions-Policy"; do
        if echo "$headers" | grep -qi "^$hdr:"; then
            echo -e "    ${GREEN}[✓] $hdr${NC}"
        else
            echo -e "    ${RED}[✗] $hdr — Missing!${NC}"
        fi
    done

    # 404 size hint for FFUF filter
    echo ""
    echo -e "  ${CYAN}404 Response Hint (ffuf filter এর জন্য):${NC}"
    local fake_resp
    fake_resp=$(curl -si --max-time 8 "${target%/}/saimum_fake_$(date +%s)" 2>/dev/null)
    local sz wc lc
    sz=$(echo "$fake_resp" | wc -c)
    wc=$(echo "$fake_resp" | tail -1 | wc -w)
    lc=$(echo "$fake_resp" | tail -1 | wc -l)
    echo -e "  ${WHITE}404 Size  :${NC} ${YELLOW}$sz bytes${NC}  ${DIM}→ ffuf -fs $sz${NC}"
    echo -e "  ${WHITE}404 Words :${NC} ${YELLOW}$wc${NC}        ${DIM}→ ffuf -fw $wc${NC}"
    echo -e "  ${WHITE}404 Lines :${NC} ${YELLOW}$lc${NC}        ${DIM}→ ffuf -fl $lc${NC}"

    # robots.txt
    local robots_status
    robots_status=$(curl -so /dev/null --max-time 6 -w "%{http_code}" "${target%/}/robots.txt" 2>/dev/null)
    echo ""
    if [ "$robots_status" = "200" ]; then
        echo -e "  ${GREEN}[✓] robots.txt পাওয়া গেছে! (Interesting paths থাকতে পারে)${NC}"
        curl -s --max-time 6 "${target%/}/robots.txt" 2>/dev/null | head -8 | sed 's/^/     /'
    else
        echo -e "  ${DIM}[✗] robots.txt নেই।${NC}"
    fi

    # WordPress hint
    local wp
    wp=$(curl -so /dev/null --max-time 5 -w "%{http_code}" "${target%/}/wp-login.php" 2>/dev/null)
    [ "$wp" = "200" ] && echo -e "  ${YELLOW}[!] WordPress site মনে হচ্ছে! /wp-login.php পাওয়া গেছে।${NC}"

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
    echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}${BOLD}   PRE-SCAN RECON  ›  $target${NC}"
    echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    whois_lookup  "$domain"
    geoip_lookup  "$domain"
    reverse_dns   "$domain"
    http_precheck "$target"
}

# ================================================================
# STEP 1 — FUZZING MODE
# ================================================================
get_mode() {
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║                    FFUF FUZZING MODES                               ║${NC}"
    echo -e "${YELLOW}${BOLD}╠═══╦══════════════════════════════╦═══════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${WHITE}#${NC} ${YELLOW}║${NC} ${WHITE}Mode${NC}                           ${YELLOW}║${NC} ${WHITE}Example URL${NC}                        ${YELLOW}║${NC}"
    echo -e "${YELLOW}${BOLD}╠═══╬══════════════════════════════╬═══════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}1${NC} ${YELLOW}║${NC} Directory / File Fuzzing      ${YELLOW}║${NC} ${CYAN}/FUZZ${NC}                               ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}2${NC} ${YELLOW}║${NC} File Extension Fuzzing        ${YELLOW}║${NC} ${CYAN}/index.FUZZ${NC}                        ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}3${NC} ${YELLOW}║${NC} GET Parameter Fuzzing         ${YELLOW}║${NC} ${CYAN}/page?FUZZ=test${NC}                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}4${NC} ${YELLOW}║${NC} GET Value Fuzzing             ${YELLOW}║${NC} ${CYAN}/page?id=FUZZ${NC}                      ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}5${NC} ${YELLOW}║${NC} POST Data Fuzzing             ${YELLOW}║${NC} ${CYAN}-d "user=admin&pass=FUZZ"${NC}           ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}6${NC} ${YELLOW}║${NC} VHost / Subdomain Fuzzing     ${YELLOW}║${NC} ${CYAN}Host: FUZZ.target.com${NC}              ${YELLOW}║${NC}"
    echo -e "${YELLOW}${BOLD}╚═══╩══════════════════════════════╩═══════════════════════════════════╝${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Mode select করুন [1-6]: "${NC})" mode_choice

    case "$mode_choice" in
        1) FUZZ_MODE="dir"   ;;
        2) FUZZ_MODE="ext"   ;;
        3) FUZZ_MODE="param" ;;
        4) FUZZ_MODE="value" ;;
        5) FUZZ_MODE="post"  ;;
        6) FUZZ_MODE="vhost" ;;
        *) echo -e "${RED}[!] Invalid।${NC}"; get_mode; return ;;
    esac
    echo ""
}

# ================================================================
# STEP 2 — WORDLIST
# ================================================================
pick_wordlist() {
    local mode=$1
    echo -e "${CYAN}[*] Wordlist select করুন (Mode: $mode):${NC}"
    echo ""
    case "$mode" in
        dir)
            echo -e "  ${GREEN}1)${NC} directory-list-2.3-medium.txt ${DIM}(recommended)${NC}"
            echo -e "  ${GREEN}2)${NC} directory-list-2.3-small.txt  ${DIM}(দ্রুত)${NC}"
            echo -e "  ${GREEN}3)${NC} common.txt"
            echo -e "  ${GREEN}4)${NC} raft-medium-directories.txt"
            ;;
        ext)
            echo -e "  ${GREEN}1)${NC} web-extensions.txt ${DIM}(recommended)${NC}"
            echo -e "  ${GREEN}2)${NC} raft-small-extensions.txt"
            ;;
        param)
            echo -e "  ${GREEN}1)${NC} burp-parameter-names.txt ${DIM}(recommended)${NC}"
            echo -e "  ${GREEN}2)${NC} raft-medium-words.txt"
            ;;
        value)
            echo -e "  ${GREEN}1)${NC} LFI-Jhaddix.txt ${DIM}(LFI test)${NC}"
            echo -e "  ${GREEN}2)${NC} XSS-Jhaddix.txt ${DIM}(XSS test)${NC}"
            echo -e "  ${GREEN}3)${NC} rockyou.txt"
            ;;
        post)
            echo -e "  ${GREEN}1)${NC} burp-parameter-names.txt"
            echo -e "  ${GREEN}2)${NC} rockyou.txt"
            echo -e "  ${GREEN}3)${NC} Generic-SQLi.txt"
            ;;
        vhost)
            echo -e "  ${GREEN}1)${NC} subdomains-top1million-5000.txt ${DIM}(recommended)${NC}"
            echo -e "  ${GREEN}2)${NC} namelist.txt"
            echo -e "  ${GREEN}3)${NC} bitquark-subdomains-top100000.txt ${DIM}(বড়)${NC}"
            ;;
    esac
    echo -e "  ${GREEN}c)${NC} Custom path"
    echo ""
    read -p "$(echo -e ${YELLOW}"Choice: "${NC})" wl_choice

    local suggested=""
    case "$mode" in
        dir)
            case "$wl_choice" in
                1) suggested="/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt" ;;
                2) suggested="/usr/share/wordlists/dirbuster/directory-list-2.3-small.txt"  ;;
                3) suggested="/usr/share/seclists/Discovery/Web-Content/common.txt"          ;;
                4) suggested="/usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt" ;;
            esac ;;
        ext)
            case "$wl_choice" in
                1) suggested="/usr/share/seclists/Discovery/Web-Content/web-extensions.txt"       ;;
                2) suggested="/usr/share/seclists/Discovery/Web-Content/raft-small-extensions.txt" ;;
            esac ;;
        param)
            case "$wl_choice" in
                1) suggested="/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt" ;;
                2) suggested="/usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt"    ;;
            esac ;;
        value)
            case "$wl_choice" in
                1) suggested="/usr/share/seclists/Fuzzing/LFI/LFI-Jhaddix.txt"   ;;
                2) suggested="/usr/share/seclists/Fuzzing/XSS/XSS-Jhaddix.txt"   ;;
                3) suggested="/usr/share/wordlists/rockyou.txt"                    ;;
            esac ;;
        post)
            case "$wl_choice" in
                1) suggested="/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt" ;;
                2) suggested="/usr/share/wordlists/rockyou.txt"                                    ;;
                3) suggested="/usr/share/seclists/Fuzzing/SQLi/Generic-SQLi.txt"                  ;;
            esac ;;
        vhost)
            case "$wl_choice" in
                1) suggested="/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt"       ;;
                2) suggested="/usr/share/seclists/Discovery/DNS/namelist.txt"                           ;;
                3) suggested="/usr/share/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt"     ;;
            esac ;;
    esac

    if [ "$wl_choice" = "c" ] || [ -z "$suggested" ]; then
        read -p "$(echo -e ${WHITE}"Custom path: "${NC})" WORDLIST
    else
        WORDLIST="$suggested"
    fi

    if [ ! -f "$WORDLIST" ]; then
        echo -e "${RED}[!] File পাওয়া যায়নি: $WORDLIST${NC}"
        pick_wordlist "$mode"; return
    fi
    local lc
    lc=$(wc -l < "$WORDLIST")
    echo -e "${GREEN}[✓] Wordlist: $WORDLIST ($lc entries)${NC}"
    echo ""
}

# ================================================================
# STEP 3 — MODE CONFIG
# ================================================================
get_mode_config() {
    local target=$1
    local mode=$2
    FUZZ_URL="" POST_DATA="" POST_CT="" EXT_LIST="" VHOST_DOMAIN=""

    case "$mode" in
        dir)
            FUZZ_URL="${target}/FUZZ"
            echo -e "${WHITE}File extensions scan করবে? ${DIM}(যেমন: php,html,bak — Enter=skip)${NC}"
            read -p "$(echo -e ${WHITE}"-e: "${NC})" EXT_LIST
            ;;
        ext)
            read -p "$(echo -e ${WHITE}"Filename (extension ছাড়া, যেমন: index): "${NC})" base
            FUZZ_URL="${target}/${base}.FUZZ"
            ;;
        param)
            read -p "$(echo -e ${WHITE}"Endpoint path (যেমন: /search.php): "${NC})" ppath
            FUZZ_URL="${target}${ppath}?FUZZ=test123"
            ;;
        value)
            read -p "$(echo -e ${WHITE}"Endpoint path: "${NC})" vpath
            read -p "$(echo -e ${WHITE}"Parameter name: "${NC})" pname
            FUZZ_URL="${target}${vpath}?${pname}=FUZZ"
            ;;
        post)
            read -p "$(echo -e ${WHITE}"Endpoint path (যেমন: /login.php): "${NC})" ppath
            FUZZ_URL="${target}${ppath}"
            echo -e "  ${GREEN}1)${NC} URL-encoded  ${GREEN}2)${NC} JSON"
            read -p "$(echo -e ${WHITE}"Format [1/2]: "${NC})" pfmt
            if [ "$pfmt" = "2" ]; then
                POST_CT="application/json"
                read -p "$(echo -e ${WHITE}"JSON POST data: "${NC})" POST_DATA
            else
                POST_CT="application/x-www-form-urlencoded"
                read -p "$(echo -e ${WHITE}"URL-encoded POST data: "${NC})" POST_DATA
            fi
            ;;
        vhost)
            VHOST_DOMAIN=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1)
            FUZZ_URL="$target"
            echo -e "${CYAN}[*] Host header: FUZZ.$VHOST_DOMAIN${NC}"
            ;;
    esac

    echo -e "${GREEN}[✓] FUZZ URL: $FUZZ_URL${NC}"
    echo ""
}

# ================================================================
# STEP 4 — FILTER CONFIG
# ================================================================
get_filter_config() {
    echo -e "${CYAN}[*] Filter / Matcher config:${NC}"
    echo ""
    echo -e "  ${WHITE}Auto-calibration চালু করবে?${NC} ${DIM}(-ac — false positive auto-filter)${NC}"
    read -p "$(echo -e ${YELLOW}"Auto-calibrate [y/n, default=y]: "${NC})" ac_ch
    ac_ch="${ac_ch:-y}"

    if [[ "$ac_ch" =~ ^[Yy]$ ]]; then
        AUTO_CALIBRATE="-ac"
        echo -e "${GREEN}[✓] Auto-calibration চালু।${NC}"
        echo ""
        return
    fi

    AUTO_CALIBRATE=""
    read -p "$(echo -e ${WHITE}"Status code filter -fc [default: 404]: "${NC})" FILTER_STATUS
    [ -z "$FILTER_STATUS" ] && FILTER_STATUS="404"
    read -p "$(echo -e ${WHITE}"Response size filter -fs [Enter=skip]: "${NC})" FILTER_SIZE
    read -p "$(echo -e ${WHITE}"Word count filter -fw [Enter=skip]: "${NC})" FILTER_WORDS
    read -p "$(echo -e ${WHITE}"Line count filter -fl [Enter=skip]: "${NC})" FILTER_LINES
    read -p "$(echo -e ${WHITE}"Match status -mc [default: 200,204,301,302,307,401,403]: "${NC})" MATCH_STATUS
    [ -z "$MATCH_STATUS" ] && MATCH_STATUS="200,204,301,302,307,401,403"
    echo ""
}

# ================================================================
# STEP 5 — EXTRA OPTIONS
# ================================================================
get_extra_options() {
    echo -e "${CYAN}[*] Advanced options:${NC}"
    echo ""
    read -p "$(echo -e ${WHITE}"Threads -t [default: 40]: "${NC})" THREADS
    [ -z "$THREADS" ] && THREADS="40"
    if [ "$THREADS" -gt 100 ] 2>/dev/null; then
        echo -e "${YELLOW}[!] $THREADS threads অনেক বেশি! Server crash হতে পারে।${NC}"
        read -p "$(echo -e ${YELLOW}"তবুও চালাবেন? [y/n]: "${NC})" ct
        [[ ! "$ct" =~ ^[Yy]$ ]] && THREADS="40"
    fi

    read -p "$(echo -e ${WHITE}"Rate limit -rate [Enter=unlimited]: "${NC})" RATE
    RECURSION_FLAG=""
    if [ "$FUZZ_MODE" = "dir" ]; then
        read -p "$(echo -e ${WHITE}"Recursion চালু করবেন? [y/n]: "${NC})" rec
        if [[ "$rec" =~ ^[Yy]$ ]]; then
            RECURSION_FLAG="-recursion"
            read -p "$(echo -e ${WHITE}"Recursion depth [default: 2]: "${NC})" RECURSION_DEPTH
            [ -z "$RECURSION_DEPTH" ] && RECURSION_DEPTH="2"
        fi
    fi

    read -p "$(echo -e ${WHITE}"Proxy -x [Enter=skip, Burp: http://127.0.0.1:8080]: "${NC})" PROXY
    read -p "$(echo -e ${WHITE}"Custom Header -H [Enter=skip]: "${NC})" CUSTOM_HEADER
    read -p "$(echo -e ${WHITE}"Follow redirects? [y/n]: "${NC})" redir
    [[ "$redir" =~ ^[Yy]$ ]] && FOLLOW_REDIRECT="-r" || FOLLOW_REDIRECT=""

    echo -e "  Output format: ${GREEN}1)${NC} Plain  ${GREEN}2)${NC} JSON  ${GREEN}3)${NC} CSV"
    read -p "$(echo -e ${WHITE}"Format [1-3, default=1]: "${NC})" fmt
    case "$fmt" in
        2) OUTPUT_FORMAT="json" ;;
        3) OUTPUT_FORMAT="csv"  ;;
        *) OUTPUT_FORMAT=""     ;;
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
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1)
    local outbase="$RESULTS_DIR/${domain}_${FUZZ_MODE}_${ts}"

    # Build command
    local cmd="ffuf -u \"$FUZZ_URL\" -w \"$WORDLIST\""

    case "$FUZZ_MODE" in
        post)
            cmd+=" -X POST -d \"$POST_DATA\" -H \"Content-Type: $POST_CT\""
            ;;
        vhost)
            cmd+=" -H \"Host: FUZZ.$VHOST_DOMAIN\""
            ;;
    esac

    [ -n "$EXT_LIST"         ] && cmd+=" -e $EXT_LIST"
    [ -n "$RECURSION_FLAG"   ] && cmd+=" $RECURSION_FLAG -recursion-depth $RECURSION_DEPTH"
    [ -n "$CUSTOM_HEADER"    ] && cmd+=" -H \"$CUSTOM_HEADER\""
    cmd+=" -t $THREADS"
    [ -n "$RATE"             ] && cmd+=" -rate $RATE"
    [ -n "$PROXY"            ] && cmd+=" -x $PROXY"
    [ -n "$FOLLOW_REDIRECT"  ] && cmd+=" $FOLLOW_REDIRECT"
    if [ -n "$AUTO_CALIBRATE" ]; then
        cmd+=" $AUTO_CALIBRATE"
    else
        [ -n "$FILTER_STATUS" ] && cmd+=" -fc $FILTER_STATUS"
        [ -n "$FILTER_SIZE"   ] && cmd+=" -fs $FILTER_SIZE"
        [ -n "$FILTER_WORDS"  ] && cmd+=" -fw $FILTER_WORDS"
        [ -n "$FILTER_LINES"  ] && cmd+=" -fl $FILTER_LINES"
        [ -n "$MATCH_STATUS"  ] && cmd+=" -mc $MATCH_STATUS"
    fi
    if [ -n "$OUTPUT_FORMAT" ]; then
        cmd+=" -o \"${outbase}.${OUTPUT_FORMAT}\" -of $OUTPUT_FORMAT"
    fi
    cmd+=" -c"

    # Preview
    echo ""
    echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}Mode   : ${YELLOW}${BOLD}$FUZZ_MODE${NC}"
    echo -e "  ${WHITE}Target : ${GREEN}${BOLD}$FUZZ_URL${NC}"
    echo -e "  ${WHITE}Command: ${CYAN}$cmd${NC}"
    echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] Scan শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local tmp_scan tmp_bangla
    tmp_scan=$(mktemp)
    tmp_bangla=$(mktemp)

    echo ""
    echo -e "${GREEN}${BOLD}[*] Scan শুরু হচ্ছে...${NC}"
    echo ""

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] MODE=$FUZZ_MODE TARGET=$target" >> "$HISTORY_FILE"

    eval "$cmd" 2>&1 | tee "$tmp_scan"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Scan সম্পন্ন!${NC}"

    bangla_analysis "$tmp_scan" "$tmp_bangla" "$FUZZ_MODE"
    suggest_next_tool "$tmp_scan" "$FUZZ_MODE" "$target"
    save_results "$target" "$tmp_scan" "$tmp_bangla" "$FUZZ_MODE" "$outbase"

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
    echo -e "${MAGENTA}${BOLD}║              বাংলায় FFUF রিপোর্ট বিশ্লেষণ                        ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local critical=0 high=0 medium=0 info=0
    local found_count
    found_count=$(grep -c "\[Status:" "$outfile" 2>/dev/null || echo 0)

    if [ "$found_count" -eq 0 ]; then
        echo -e "  ${GREEN}[✓] কোনো result পাওয়া যায়নি। Target সুরক্ষিত হতে পারে।${NC}"
        echo ""
    else
        echo -e "  ${WHITE}মোট পাওয়া গেছে: ${YELLOW}${BOLD}$found_count টি${NC}"
        echo ""

        case "$mode" in
            dir|ext)
                # Sensitive files
                if grep -qiE "\.git|\.svn|\.htaccess|\.htpasswd|id_rsa|private|passwd|shadow" "$outfile" 2>/dev/null; then
                    critical=$((critical+1))
                    echo -e "  ${RED}${BOLD}🚨 Sensitive File Exposed!${NC}"
                    echo -e "     ${WHITE}→ .git, .htpasswd বা private key ধরনের file পাওয়া গেছে।${NC}"
                    echo -e "     ${WHITE}→ Source code, password বা private key leak হতে পারে।${NC}"
                    echo -e "     ${WHITE}→ Web server এ এই paths এর public access বন্ধ করুন।${NC}"
                    echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
                fi
                # Config/env files
                if grep -qiE "\.env|config\.|wp-config|settings\.|\.ini|\.conf|database\." "$outfile" 2>/dev/null; then
                    critical=$((critical+1))
                    echo -e "  ${RED}${BOLD}🚨 Config / Env File Exposed!${NC}"
                    echo -e "     ${WHITE}→ .env বা config file publicly accessible।${NC}"
                    echo -e "     ${WHITE}→ Database password, API key leak হতে পারে।${NC}"
                    echo -e "     ${WHITE}→ .htaccess বা nginx rules দিয়ে block করুন।${NC}"
                    echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
                fi
                # Backup files
                if grep -qiE "\.bak|\.old|\.backup|\.zip|\.tar|\.gz|\.sql|\.dump" "$outfile" 2>/dev/null; then
                    high=$((high+1))
                    echo -e "  ${YELLOW}${BOLD}⚠ Backup File পাওয়া গেছে!${NC}"
                    echo -e "     ${WHITE}→ Backup files web root থেকে সরিয়ে নিন।${NC}"
                    echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
                fi
                # Admin panel
                if grep -qiE "/admin|/dashboard|/login|/manager|/cpanel|/wp-admin|/phpmyadmin" "$outfile" 2>/dev/null; then
                    high=$((high+1))
                    echo -e "  ${YELLOW}${BOLD}⚠ Admin Panel / Login Page পাওয়া গেছে!${NC}"
                    echo -e "     ${WHITE}→ Administrative interface publicly accessible।${NC}"
                    echo -e "     ${WHITE}→ IP whitelist বা 2FA enforce করুন।${NC}"
                    echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
                fi
                # Upload directory
                if grep -qiE "/upload|/uploads|/files|/media" "$outfile" 2>/dev/null; then
                    medium=$((medium+1))
                    echo -e "  ${CYAN}${BOLD}ℹ Upload Directory পাওয়া গেছে!${NC}"
                    echo -e "     ${WHITE}→ Directory listing বন্ধ করুন, script execution disable করুন।${NC}"
                    echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
                fi
                # Status breakdown
                local s200 s301 s403
                s200=$(grep -c "Status: 200" "$outfile" 2>/dev/null || echo 0)
                s301=$(grep -c "\[Status: 30" "$outfile" 2>/dev/null || echo 0)
                s403=$(grep -c "Status: 403" "$outfile" 2>/dev/null || echo 0)
                info=$((info+1))
                echo -e "  ${GREEN}${BOLD}✅ Response Summary:${NC}"
                echo -e "     ${WHITE}→ 200 OK       : $s200 টি${NC}"
                echo -e "     ${WHITE}→ 3xx Redirect : $s301 টি${NC}"
                echo -e "     ${WHITE}→ 403 Forbidden: $s403 টি${NC}"
                echo -e "     ${GREEN}→ ঝুঁকি: INFO${NC}"; echo ""
                ;;

            param)
                if grep -qiE "file|path|dir|include|load|template|lang" "$outfile" 2>/dev/null; then
                    critical=$((critical+1))
                    echo -e "  ${RED}${BOLD}🚨 LFI-Prone Parameter পাওয়া গেছে!${NC}"
                    echo -e "     ${WHITE}→ file, path, include ধরনের parameter আছে।${NC}"
                    echo -e "     ${WHITE}→ ../etc/passwd দিয়ে LFI test করুন।${NC}"
                    echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
                fi
                if grep -qiE "id|user|page|cat|item|order|sort|key" "$outfile" 2>/dev/null; then
                    high=$((high+1))
                    echo -e "  ${YELLOW}${BOLD}⚠ SQLi-Prone Parameter পাওয়া গেছে!${NC}"
                    echo -e "     ${WHITE}→ id, user, cat ধরনের parameter আছে। SQLmap দিয়ে test করুন।${NC}"
                    echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
                fi
                if grep -qiE "name|query|search|q|input|data|msg" "$outfile" 2>/dev/null; then
                    medium=$((medium+1))
                    echo -e "  ${CYAN}${BOLD}ℹ XSS-Prone Parameter পাওয়া গেছে!${NC}"
                    echo -e "     ${WHITE}→ search, query ধরনের parameter। Reflected XSS test করুন।${NC}"
                    echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
                fi
                info=$((info+1))
                echo -e "  ${GREEN}${BOLD}✅ মোট $found_count টি hidden parameter পাওয়া গেছে।${NC}"
                echo -e "     ${GREEN}→ ঝুঁকি: INFO${NC}"; echo ""
                ;;

            value)
                if grep -qiE "root:|passwd|boot\.ini|win\.ini" "$outfile" 2>/dev/null; then
                    critical=$((critical+1))
                    echo -e "  ${RED}${BOLD}🚨 LFI CONFIRMED!${NC}"
                    echo -e "     ${WHITE}→ /etc/passwd এর content response এ পাওয়া গেছে।${NC}"
                    echo -e "     ${WHITE}→ এটি Local File Inclusion — অত্যন্ত গুরুতর।${NC}"
                    echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
                fi
                if grep -qiE "sql.*error|mysql.*error|ORA-|syntax.*error" "$outfile" 2>/dev/null; then
                    critical=$((critical+1))
                    echo -e "  ${RED}${BOLD}🚨 SQL Error পাওয়া গেছে — SQLi সম্ভব!${NC}"
                    echo -e "     ${WHITE}→ SQLmap দিয়ে full exploitation test করুন।${NC}"
                    echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
                fi
                info=$((info+1))
                echo -e "  ${GREEN}${BOLD}✅ Value fuzzing সম্পন্ন — $found_count unique response।${NC}"
                echo -e "     ${GREEN}→ ঝুঁকি: INFO${NC}"; echo ""
                ;;

            post)
                local redir_count
                redir_count=$(grep -c "Status: 302" "$outfile" 2>/dev/null || echo 0)
                if grep -qiE "Status: 302|dashboard|welcome|success" "$outfile" 2>/dev/null; then
                    critical=$((critical+1))
                    echo -e "  ${RED}${BOLD}🚨 Possible Login Bypass!${NC}"
                    echo -e "     ${WHITE}→ POST fuzzing এ redirect বা success পাওয়া গেছে।${NC}"
                    echo -e "     ${WHITE}→ Authentication logic review করুন।${NC}"
                    echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
                fi
                info=$((info+1))
                echo -e "  ${GREEN}${BOLD}✅ POST fuzzing সম্পন্ন।${NC}"
                echo -e "     ${WHITE}→ Redirect count: $redir_count${NC}"
                echo -e "     ${GREEN}→ ঝুঁকি: INFO${NC}"; echo ""
                ;;

            vhost)
                if grep -qiE "admin\.|internal\.|manage\." "$outfile" 2>/dev/null; then
                    critical=$((critical+1))
                    echo -e "  ${RED}${BOLD}🚨 Admin/Internal VHost পাওয়া গেছে!${NC}"
                    echo -e "     ${WHITE}→ এটি external access থেকে block করুন।${NC}"
                    echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
                fi
                if grep -qiE "dev\.|staging\.|test\.|beta\." "$outfile" 2>/dev/null; then
                    high=$((high+1))
                    echo -e "  ${YELLOW}${BOLD}⚠ Dev/Staging VHost পাওয়া গেছে!${NC}"
                    echo -e "     ${WHITE}→ Debug mode বা weak auth থাকতে পারে। IP restrict করুন।${NC}"
                    echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
                fi
                if grep -qiE "api\.|api-" "$outfile" 2>/dev/null; then
                    medium=$((medium+1))
                    echo -e "  ${CYAN}${BOLD}ℹ API VHost পাওয়া গেছে!${NC}"
                    echo -e "     ${WHITE}→ API authentication properly configured কিনা check করুন।${NC}"
                    echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
                fi
                info=$((info+1))
                echo -e "  ${GREEN}${BOLD}✅ মোট $found_count টি virtual host পাওয়া গেছে।${NC}"
                echo -e "     ${GREEN}→ ঝুঁকি: INFO${NC}"; echo ""
                ;;
        esac

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
    fi
    } | tee "$report_file"
}

# ================================================================
# NEXT TOOL SUGGESTION
# ================================================================
suggest_next_tool() {
    local outfile=$1
    local mode=$2
    local target=$3
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1)

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║              পরবর্তী Scan এর সাজেশন                                ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    case "$mode" in
        dir|ext)
            if grep -qiE "wp-admin|wp-login|wp-content" "$outfile" 2>/dev/null; then
                echo -e "  ${MAGENTA}${BOLD}🔧 WPScan${NC} — WordPress site পাওয়া গেছে!"
                echo -e "     ${WHITE}কারণ: WordPress plugins, themes ও users enumerate করুন।${NC}"
                echo -e "     ${CYAN}কমান্ড: wpscan --url $target --enumerate u,vp,ap --api-token TOKEN${NC}"; echo ""
            fi
            if grep -qiE "\.php" "$outfile" 2>/dev/null; then
                echo -e "  ${GREEN}${BOLD}💉 SQLmap${NC} — PHP pages পাওয়া গেছে"
                echo -e "     ${WHITE}কারণ: PHP parameter এ SQL injection test করুন।${NC}"
                echo -e "     ${CYAN}কমান্ড: sqlmap -u \"$target/page.php?id=1\" --dbs --batch${NC}"; echo ""
            fi
            if grep -qiE "/admin|/login" "$outfile" 2>/dev/null; then
                echo -e "  ${RED}${BOLD}🔑 Hydra${NC} — Admin panel পাওয়া গেছে"
                echo -e "     ${WHITE}কারণ: Login page এ brute force করুন।${NC}"
                echo -e "     ${CYAN}কমান্ড: hydra -L users.txt -P rockyou.txt $domain http-post-form \"/login:u=^USER^&p=^PASS^:F=incorrect\"${NC}"; echo ""
            fi
            echo -e "  ${YELLOW}${BOLD}🌐 Nikto${NC} — Web Vulnerability Scan"
            echo -e "     ${WHITE}কারণ: Discovered directories এ deep vulnerability scan করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: nikto -h $target${NC}"; echo ""
            echo -e "  ${WHITE}${BOLD}⚡ Httpx${NC} — Found paths verify করুন"
            echo -e "     ${WHITE}কারণ: Multiple endpoints এর status ও tech একসাথে check করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: cat ffuf_results.txt | httpx -title -tech-detect -status-code${NC}"; echo ""
            ;;
        param|value)
            echo -e "  ${GREEN}${BOLD}💉 SQLmap${NC} — SQL Injection Test"
            echo -e "     ${WHITE}কারণ: Found parameters এ deep SQL injection test করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: sqlmap -u \"$FUZZ_URL\" --level 3 --risk 2 --dbs --batch${NC}"; echo ""
            echo -e "  ${YELLOW}${BOLD}🌐 Burp Suite${NC} — Manual Exploitation"
            echo -e "     ${WHITE}কারণ: Found parameters manually test করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: burpsuite (Intruder / Repeater)${NC}"; echo ""
            ;;
        post)
            echo -e "  ${RED}${BOLD}🔑 Hydra${NC} — Login Brute Force"
            echo -e "     ${WHITE}কারণ: POST endpoint এ credential brute force করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: hydra -L users.txt -P passwords.txt $domain http-post-form \"/login:u=^USER^&p=^PASS^:F=incorrect\"${NC}"; echo ""
            echo -e "  ${GREEN}${BOLD}💉 SQLmap${NC} — POST Injection"
            echo -e "     ${WHITE}কারণ: POST data তে SQL injection test করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: sqlmap -u \"$FUZZ_URL\" --data \"$POST_DATA\" --level 3 --batch${NC}"; echo ""
            ;;
        vhost)
            echo -e "  ${WHITE}${BOLD}⚡ Httpx${NC} — Discovered vhosts verify করুন"
            echo -e "     ${WHITE}কারণ: Found hosts এর status, title ও tech একসাথে check করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: httpx -l vhosts.txt -title -tech-detect -status-code${NC}"; echo ""
            echo -e "  ${MAGENTA}${BOLD}🌍 Subfinder / Amass${NC} — More subdomains"
            echo -e "     ${WHITE}কারণ: OSINT দিয়ে আরো subdomains খুঁজুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: subfinder -d $domain -o subdomains.txt${NC}"; echo ""
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
    local outbase=$5

    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Result save করবেন? (y/n): "${NC})" sc
    if [[ "$sc" =~ ^[Yy]$ ]]; then
        local fname="${outbase}_report.txt"
        {
            echo "============================================================"
            echo "  FFUF RESULTS  —  SAIMUM's Automation Tool"
            echo "  Mode   : $mode"
            echo "  Target : $target"
            echo "  Date   : $(date)"
            echo "============================================================"
            echo ""
            echo "=== FFUF RAW OUTPUT ==="
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
        get_targets
        get_mode

        for t in "${TARGETS[@]}"; do
            pre_scan_recon "$t"
        done

        read -p "[Enter] চাপুন scan config এ যেতে..."

        pick_wordlist     "$FUZZ_MODE"
        get_filter_config
        get_extra_options

        for t in "${TARGETS[@]}"; do
            get_mode_config "$t" "$FUZZ_MODE"
            echo ""
            echo -e "${YELLOW}${BOLD}══════════════ Target: $t ══════════════${NC}"
            build_and_run "$t"
        done

        echo ""
        read -p "[?] আরেকটি scan করবেন? (y/n): " again
        if [[ ! "$again" =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical!${NC}"
            echo ""
            exit 0
        fi
        # Reset globals
        unset TARGETS FUZZ_MODE WORDLIST FUZZ_URL POST_DATA POST_CT EXT_LIST VHOST_DOMAIN
        unset AUTO_CALIBRATE FILTER_STATUS FILTER_SIZE FILTER_WORDS FILTER_LINES MATCH_STATUS
        unset THREADS RATE RECURSION_FLAG RECURSION_DEPTH PROXY CUSTOM_HEADER FOLLOW_REDIRECT OUTPUT_FORMAT
        show_banner
    done
}

main
