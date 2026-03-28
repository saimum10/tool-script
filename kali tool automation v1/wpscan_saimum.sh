#!/bin/bash

# ================================================================
#   WPSCAN - Full Automation Tool
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

RESULTS_DIR="$HOME/wpscan_results"
HISTORY_FILE="$HOME/.wpscan_saimum_history.log"
API_TOKEN_FILE="$HOME/.wpscan_api_token"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo ' ██╗    ██╗██████╗ ███████╗ ██████╗ █████╗ ███╗   ██╗'
    echo ' ██║    ██║██╔══██╗██╔════╝██╔════╝██╔══██╗████╗  ██║'
    echo ' ██║ █╗ ██║██████╔╝███████╗██║     ███████║██╔██╗ ██║'
    echo ' ██║███╗██║██╔═══╝ ╚════██║██║     ██╔══██║██║╚██╗██║'
    echo ' ╚███╔███╔╝██║     ███████║╚██████╗██║  ██║██║ ╚████║'
    echo '  ╚══╝╚══╝ ╚═╝     ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝'
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}         WPScan Full Automation Tool | WordPress Vulnerability Scanner${NC}"
    echo ""
}

# ================================================================
# CHECK DEPENDENCIES
# ================================================================
check_deps() {
    echo -e "${CYAN}[*] Dependencies চেক করা হচ্ছে...${NC}"
    local missing=()
    for tool in wpscan whois curl dig; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
            echo -e "  ${RED}[✗] $tool — পাওয়া যায়নি${NC}"
        else
            echo -e "  ${GREEN}[✓] $tool${NC}"
        fi
    done

    # API token check
    echo ""
    if [ -f "$API_TOKEN_FILE" ]; then
        SAVED_TOKEN=$(cat "$API_TOKEN_FILE")
        echo -e "  ${GREEN}[✓] WPScan API token পাওয়া গেছে।${NC}"
    else
        echo -e "  ${YELLOW}[!] WPScan API token নেই — vulnerability data কম আসবে।${NC}"
        echo -e "  ${DIM}    Free token: https://wpscan.com/register${NC}"
        SAVED_TOKEN=""
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing tools: ${missing[*]}${NC}"
        echo -e "${YELLOW}[*] Install করুন: sudo apt install wpscan${NC}"
        echo -e "${YELLOW}[*] অথবা: gem install wpscan${NC}"
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
# WORDPRESS QUICK CHECK
# ================================================================
wp_quick_check() {
    local target=$1
    echo -e "${BLUE}${BOLD}┌─── WORDPRESS PRE-CHECK ───────────────────────────┐${NC}"

    local headers
    headers=$(curl -s -I --max-time 8 "$target" 2>/dev/null)
    local body
    body=$(curl -s --max-time 8 "$target" 2>/dev/null | head -100)

    # WordPress detection
    local is_wp=false
    if echo "$body" | grep -qi "wp-content\|wp-includes\|wordpress"; then
        echo -e "  ${GREEN}[✓] WordPress detect হয়েছে!${NC}"
        is_wp=true
    else
        echo -e "  ${RED}[!] WordPress detect হয়নি — এটা WordPress site না হতে পারে।${NC}"
        read -p "$(echo -e ${YELLOW}"  তবুও scan করবেন? (y/n): "${NC})" cont
        [[ ! "$cont" =~ ^[Yy]$ ]] && exit 0
    fi

    # WordPress version
    local wp_ver
    wp_ver=$(curl -s --max-time 8 "$target/readme.html" 2>/dev/null | grep -i "version" | head -1)
    [ -n "$wp_ver" ] && echo -e "  ${YELLOW}[!] readme.html publicly accessible — version leak!${NC}"
    [ -n "$wp_ver" ] && echo -e "  ${WHITE}    $wp_ver${NC}"

    # Login page
    local login_check
    login_check=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$target/wp-login.php" 2>/dev/null)
    if [ "$login_check" == "200" ]; then
        echo -e "  ${YELLOW}[!] wp-login.php publicly accessible (Status: 200)${NC}"
    fi

    # XML-RPC
    local xmlrpc_check
    xmlrpc_check=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$target/xmlrpc.php" 2>/dev/null)
    if [ "$xmlrpc_check" == "200" ]; then
        echo -e "  ${RED}[!] xmlrpc.php accessible — Brute force amplification সম্ভব!${NC}"
    fi

    # wp-config backup
    for cfg in "wp-config.php.bak" "wp-config.php~" "wp-config.txt"; do
        local cfg_check
        cfg_check=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$target/$cfg" 2>/dev/null)
        if [ "$cfg_check" == "200" ]; then
            echo -e "  ${RED}[!] $cfg publicly accessible — DB credentials exposed!${NC}"
        fi
    done

    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────────┘${NC}"
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
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}${BOLD}   PRE-SCAN RECON  ›  $target${NC}"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    whois_lookup    "$domain"
    geoip_lookup    "$domain"
    reverse_dns     "$domain"
    wp_quick_check  "$target"
}

# ================================================================
# STEP 1 — TARGET
# ================================================================
get_targets() {
    TARGETS=()

    echo -e "${BLUE}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║      STEP 1 — TARGET                 ║${NC}"
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Single WordPress URL"
    echo -e "  ${GREEN}2)${NC} Multiple URLs (একটা একটা করে)"
    echo -e "  ${GREEN}3)${NC} File থেকে URL list"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-3]: "${NC})" ttype

    case $ttype in
        1)
            read -p "$(echo -e ${WHITE}"WordPress URL দিন (e.g. https://target.com): "${NC})" t
            TARGETS=("$t")
            ;;
        2)
            echo -e "${WHITE}একটা একটা করে দিন। শেষ হলে 'done' লিখুন:${NC}"
            while true; do
                read -p "$(echo -e ${WHITE}"URL: "${NC})" t
                [[ "$t" == "done" || -z "$t" ]] && break
                TARGETS+=("$t")
            done
            ;;
        3)
            read -p "$(echo -e ${WHITE}"File path দিন: "${NC})" fpath
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

    [ ${#TARGETS[@]} -eq 0 ] && { echo -e "${RED}[!] কোনো target নেই।${NC}"; get_targets; }
    echo ""
}

# ================================================================
# STEP 2 — ENUMERATE
# ================================================================
get_enumerate() {
    ENUM_OPT=""

    echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║      STEP 2 — ENUMERATE (কী কী খুঁজবে?)                            ║${NC}"
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${DIM}একাধিক select করতে পারবেন — space দিয়ে লিখুন, e.g: 1 2 3${NC}"
    echo -e "  ${DIM}অথবা শুধু 'a' লিখলে সব একসাথে।${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} u   — WordPress Users          ${DIM}username বের করো${NC}"
    echo -e "  ${GREEN}2)${NC} p   — Plugins                  ${DIM}installed plugins ও তাদের vulnerability${NC}"
    echo -e "  ${GREEN}3)${NC} vp  — Vulnerable Plugins only  ${DIM}শুধু vulnerable plugins${NC}"
    echo -e "  ${GREEN}4)${NC} ap  — All Plugins              ${DIM}সব plugins (slow)${NC}"
    echo -e "  ${GREEN}5)${NC} t   — Themes                   ${DIM}installed themes${NC}"
    echo -e "  ${GREEN}6)${NC} vt  — Vulnerable Themes only   ${DIM}শুধু vulnerable themes${NC}"
    echo -e "  ${GREEN}7)${NC} tt  — Timthumbs                ${DIM}timthumb script vulnerability${NC}"
    echo -e "  ${GREEN}8)${NC} cb  — Config Backups           ${DIM}wp-config backup files${NC}"
    echo -e "  ${GREEN}9)${NC} dbe — DB Exports               ${DIM}database export files${NC}"
    echo -e "  ${GREEN}10)${NC} m  — Media                    ${DIM}uploaded media files${NC}"
    echo -e "  ${GREEN}a)${NC}  ${YELLOW}সব একসাথে (Recommended)${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select: "${NC})" enum_raw

    local enum_str=""
    if echo "$enum_raw" | grep -qi "^a$"; then
        enum_str="u,p,t,tt,cb,dbe,m"
    else
        local parts=()
        for ch in $enum_raw; do
            case $ch in
                1)  parts+=("u")   ;;
                2)  parts+=("p")   ;;
                3)  parts+=("vp")  ;;
                4)  parts+=("ap")  ;;
                5)  parts+=("t")   ;;
                6)  parts+=("vt")  ;;
                7)  parts+=("tt")  ;;
                8)  parts+=("cb")  ;;
                9)  parts+=("dbe") ;;
                10) parts+=("m")   ;;
            esac
        done
        # Join with comma
        enum_str=$(IFS=,; echo "${parts[*]}")
    fi

    [ -n "$enum_str" ] && ENUM_OPT="--enumerate $enum_str"
    echo -e "  ${GREEN}[✓] Enumerate: ${enum_str:-default}${NC}"
    echo ""
}

# ================================================================
# STEP 3 — DETECTION MODE
# ================================================================
get_detection_mode() {
    DETECT_OPT=""

    echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║      STEP 3 — DETECTION MODE                                        ║${NC}"
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} ${CYAN}Passive${NC}    — শুধু publicly available info দেখে"
    echo -e "             ${DIM}কোনো extra request নেই — সবচেয়ে stealthy${NC}"
    echo ""
    echo -e "  ${GREEN}2)${NC} ${YELLOW}Mixed${NC}      — Passive + কিছু active check"
    echo -e "             ${DIM}balance — recommended for most cases${NC}"
    echo ""
    echo -e "  ${GREEN}3)${NC} ${RED}Aggressive${NC} — সব possible method দিয়ে খোঁজে"
    echo -e "             ${DIM}সবচেয়ে accurate কিন্তু noisy — IDS detect করতে পারে${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-3, Enter=2]: "${NC})" det_ch

    case $det_ch in
        1) DETECT_OPT="--detection-mode passive"    ;;
        3) DETECT_OPT="--detection-mode aggressive"
           echo -e "  ${RED}[!] Aggressive mode — IDS/WAF detect করতে পারে।${NC}" ;;
        *) DETECT_OPT="--detection-mode mixed"      ;;
    esac

    echo -e "  ${GREEN}[✓] Detection mode set।${NC}"
    echo ""
}

# ================================================================
# STEP 4 — API TOKEN & BRUTE FORCE
# ================================================================
get_api_and_bruteforce() {
    TOKEN_OPT=""
    BRUTE_OPT=""
    WORDLIST_OPT=""

    echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║      STEP 4 — API TOKEN & BRUTE FORCE                               ║${NC}"
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # API Token
    echo -e "  ${CYAN}WPScan API Token:${NC}"
    if [ -n "$SAVED_TOKEN" ]; then
        echo -e "  ${GREEN}[✓] Saved token পাওয়া গেছে।${NC}"
        read -p "$(echo -e ${WHITE}"  এই token ব্যবহার করবেন? (y/n): "${NC})" use_saved
        if [[ "$use_saved" =~ ^[Yy]$ ]]; then
            TOKEN_OPT="--api-token $SAVED_TOKEN"
        else
            read -p "$(echo -e ${WHITE}"  নতুন API token দিন (Enter = skip): "${NC})" new_token
            if [ -n "$new_token" ]; then
                TOKEN_OPT="--api-token $new_token"
                echo "$new_token" > "$API_TOKEN_FILE"
                echo -e "  ${GREEN}[✓] Token save হয়েছে।${NC}"
            fi
        fi
    else
        echo -e "  ${DIM}  Free token পেতে: https://wpscan.com/register${NC}"
        read -p "$(echo -e ${WHITE}"  API token দিন (Enter = skip): "${NC})" token_in
        if [ -n "$token_in" ]; then
            TOKEN_OPT="--api-token $token_in"
            echo "$token_in" > "$API_TOKEN_FILE"
            echo -e "  ${GREEN}[✓] Token save হয়েছে।${NC}"
        fi
    fi

    # Brute Force
    echo ""
    echo -e "  ${CYAN}Password Brute Force:${NC}"
    echo -e "  ${DIM}  User enumerate এর পর found users এ password attack করবে।${NC}"
    echo ""
    read -p "$(echo -e ${WHITE}"  Brute force চালাবেন? (y/n): "${NC})" brute_yn
    if [[ "$brute_yn" =~ ^[Yy]$ ]]; then

        # Username
        read -p "$(echo -e ${WHITE}"  Username জানা আছে? (Enter = scan থেকে auto নেবে): "${NC})" uname_in
        [ -n "$uname_in" ] && BRUTE_OPT="--username $uname_in"

        # Wordlist
        echo ""
        echo -e "  ${CYAN}  Wordlist:${NC}"
        echo -e "  ${GREEN}  1)${NC} rockyou.txt           ${DIM}(most common)${NC}"
        echo -e "  ${GREEN}  2)${NC} fasttrack.txt         ${DIM}(ছোট কিন্তু effective)${NC}"
        echo -e "  ${GREEN}  3)${NC} custom path"
        echo ""
        read -p "$(echo -e ${YELLOW}"  Select [1-3]: "${NC})" wl_ch
        case $wl_ch in
            2) WORDLIST_OPT="--passwords /usr/share/wordlists/fasttrack.txt" ;;
            3)
                read -p "$(echo -e ${WHITE}"  Wordlist path: "${NC})" wl_path
                [ -f "$wl_path" ] && WORDLIST_OPT="--passwords $wl_path" || \
                    echo -e "  ${RED}[!] File নেই — rockyou.txt ব্যবহার হবে।${NC}"
                WORDLIST_OPT="${WORDLIST_OPT:-"--passwords /usr/share/wordlists/rockyou.txt"}"
                ;;
            *) WORDLIST_OPT="--passwords /usr/share/wordlists/rockyou.txt" ;;
        esac

        # Max threads for brute
        read -p "$(echo -e ${WHITE}"  Brute force threads? (Enter = 5): "${NC})" bf_th
        local bf_thread="${bf_th:-5}"
        BRUTE_OPT="$BRUTE_OPT $WORDLIST_OPT --max-threads $bf_thread"
        echo -e "  ${GREEN}[✓] Brute force config set।${NC}"
    fi
    echo ""
}

# ================================================================
# STEP 5 — EXTRA OPTIONS
# ================================================================
get_extra_options() {
    PROXY_OPT=""
    AGENT_OPT=""
    DELAY_OPT=""
    THROTTLE_OPT=""
    VERBOSE_OPT=""
    FORCE_OPT=""

    echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║      STEP 5 — EXTRA OPTIONS (সব optional, Enter = skip)            ║${NC}"
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Proxy
    read -p "$(echo -e ${WHITE}"Proxy ব্যবহার করবেন? (y/n): "${NC})" proxy_yn
    if [[ "$proxy_yn" =~ ^[Yy]$ ]]; then
        read -p "$(echo -e ${WHITE}"  Proxy (e.g. http://127.0.0.1:8080): "${NC})" proxy_in
        PROXY_OPT="--proxy $proxy_in"
        echo -e "  ${GREEN}[✓] Proxy: $proxy_in${NC}"
    fi

    # User-Agent
    echo ""
    echo -e "  ${CYAN}User-Agent:${NC}"
    echo -e "  ${GREEN}1)${NC} Default (WPScan)"
    echo -e "  ${GREEN}2)${NC} Chrome Browser"
    echo -e "  ${GREEN}3)${NC} Googlebot"
    echo -e "  ${GREEN}4)${NC} Random"
    read -p "$(echo -e ${YELLOW}"  Select [1-4, Enter=2]: "${NC})" ua_ch
    case $ua_ch in
        1) ;;
        3) AGENT_OPT="--http-auth-header \"User-Agent: Googlebot/2.1\"" ;;
        4) AGENT_OPT="--random-user-agent" ;;
        *) AGENT_OPT="--http-auth-header \"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0\"" ;;
    esac
    [ -n "$AGENT_OPT" ] && echo -e "  ${GREEN}[✓] User-Agent set।${NC}"

    # Throttle / Delay
    echo ""
    read -p "$(echo -e ${WHITE}"Request throttle দেবেন? milliseconds (Enter = 0): "${NC})" throttle_in
    if [ -n "$throttle_in" ] && [ "$throttle_in" -gt 0 ] 2>/dev/null; then
        THROTTLE_OPT="--throttle $throttle_in"
        echo -e "  ${GREEN}[✓] Throttle: ${throttle_in}ms${NC}"
    fi

    # Verbose
    echo ""
    read -p "$(echo -e ${WHITE}"Verbose mode চালু করবেন? (y/n): "${NC})" vb_yn
    [[ "$vb_yn" =~ ^[Yy]$ ]] && VERBOSE_OPT="--verbose" && \
        echo -e "  ${GREEN}[✓] Verbose: ON${NC}"

    # Force scan
    echo ""
    read -p "$(echo -e ${WHITE}"WordPress না মনে হলেও force scan করবেন? (y/n): "${NC})" force_yn
    [[ "$force_yn" =~ ^[Yy]$ ]] && FORCE_OPT="--force" && \
        echo -e "  ${GREEN}[✓] Force: ON${NC}"

    echo ""
}

# ================================================================
# BUILD & RUN
# ================================================================
build_and_run() {
    local target=$1
    local ts
    ts=$(date +"%Y%m%d_%H%M%S")
    local safe
    safe=$(echo "$target" | sed 's|[^a-zA-Z0-9._-]|_|g')
    local out_file="$RESULTS_DIR/wpscan_${safe}_${ts}.txt"

    local final_cmd
    final_cmd=$(echo "wpscan --url $target \
        $ENUM_OPT \
        $DETECT_OPT \
        $TOKEN_OPT \
        $BRUTE_OPT \
        $PROXY_OPT \
        $AGENT_OPT \
        $THROTTLE_OPT \
        $VERBOSE_OPT \
        $FORCE_OPT \
        --output $out_file \
        --format cli-no-colour" | tr -s ' ')

    echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║      CONFIRM & RUN                                                  ║${NC}"
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${WHITE}Target  : ${GREEN}${BOLD}$target${NC}"
    echo -e "  ${WHITE}Command : ${YELLOW}$final_cmd${NC}"
    echo -e "  ${WHITE}Output  : ${CYAN}$out_file${NC}"
    echo ""
    echo -e "  ${RED}[!] শুধুমাত্র নিজের বা permission আছে এমন WordPress site এ ব্যবহার করুন!${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Scan শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local tmp_scan tmp_bangla
    tmp_scan=$(mktemp)
    tmp_bangla=$(mktemp)

    echo ""
    echo -e "${GREEN}${BOLD}[*] WPScan শুরু হচ্ছে...${NC}"
    echo ""

    # Real WPScan — হুবহু original terminal output
    eval "$final_cmd" 2>&1 | tee "$tmp_scan"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Scan সম্পন্ন!${NC}"

    bangla_analysis   "$tmp_scan" "$tmp_bangla"
    suggest_next_tool "$tmp_scan"
    save_results      "$tmp_scan" "$tmp_bangla" "$out_file" "$target"

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

    # WordPress version
    if grep -qi "wordpress version\|running wordpress" "$outfile" 2>/dev/null; then
        local wp_version
        wp_version=$(grep -i "wordpress version\|running wordpress" "$outfile" | head -1)
        info=$((info+1))
        echo -e "  ${WHITE}${BOLD}📌 WordPress Version Detected${NC}"
        echo -e "     ${WHITE}→ $wp_version${NC}"
        echo -e "     ${WHITE}→ Outdated WordPress মানে known vulnerability।${NC}"
        echo -e "     ${GREEN}→ ঝুঁকি: INFO${NC}"; echo ""
    fi

    # Outdated WordPress
    if grep -qi "outdated\|the latest version is\|version.*out of date" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ WordPress Outdated!${NC}"
        echo -e "     ${WHITE}→ নতুন version এ security patch আছে যা এখানে নেই।${NC}"
        echo -e "     ${WHITE}→ এখনই update করুন।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Vulnerable plugins
    if grep -qi "\[!\].*plugin\|vulnerable plugin\|plugin.*vulnerability" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Vulnerable Plugin পাওয়া গেছে!${NC}"
        grep -i "\[!\].*plugin\|plugin.*vulnerability\|CVE-" "$outfile" | head -5 | while read -r line; do
            echo -e "     ${YELLOW}→ $line${NC}"
        done
        echo -e "     ${WHITE}→ Plugin এর vulnerability দিয়ে site এ access নেওয়া সম্ভব।${NC}"
        echo -e "     ${WHITE}→ এখনই plugin update বা disable করুন।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # Vulnerable themes
    if grep -qi "\[!\] .*theme\|vulnerable theme\|theme.*vulnerability" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ Vulnerable Theme পাওয়া গেছে!${NC}"
        grep -i "\[!\].*theme\|theme.*CVE" "$outfile" | head -3 | while read -r line; do
            echo -e "     ${CYAN}→ $line${NC}"
        done
        echo -e "     ${WHITE}→ Theme এর vulnerability দিয়ে XSS বা file upload সম্ভব।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Users found
    if grep -qi "user(s) identified\|found.*user\|\[i\] user" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ WordPress User পাওয়া গেছে!${NC}"
        grep -i "user.*identified\|\[i\] user\|login:" "$outfile" | head -5 | while read -r line; do
            echo -e "     ${CYAN}→ $line${NC}"
        done
        echo -e "     ${WHITE}→ এই username দিয়ে brute force attack করা সম্ভব।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Password found
    if grep -qi "valid combination found\|password found\|credentials found" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Password Cracked!${NC}"
        grep -i "valid combination\|password found\|credentials" "$outfile" | head -3 | while read -r line; do
            echo -e "     ${YELLOW}→ $line${NC}"
        done
        echo -e "     ${WHITE}→ WordPress admin login সম্ভব!${NC}"
        echo -e "     ${WHITE}→ Admin panel থেকে shell upload করা যেতে পারে।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # XML-RPC enabled
    if grep -qi "xmlrpc.php\|xml-rpc" "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}ℹ XML-RPC Enabled!${NC}"
        echo -e "     ${WHITE}→ XML-RPC দিয়ে একটি request এ হাজার password test করা সম্ভব।${NC}"
        echo -e "     ${WHITE}→ Disable করুন যদি দরকার না থাকে।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # Readme/License exposed
    if grep -qi "readme.html\|license.txt" "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}ℹ Readme / License File Exposed!${NC}"
        echo -e "     ${WHITE}→ WordPress version সরাসরি দেখা যাচ্ছে।${NC}"
        echo -e "     ${WHITE}→ এই files publicly accessible না রাখা উচিত।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # Config backup
    if grep -qi "wp-config.*backup\|config.*bak\|\\.bak" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 wp-config Backup File Exposed!${NC}"
        echo -e "     ${WHITE}→ Database credentials সরাসরি download করা সম্ভব!${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # CVE references
    local cve_count
    cve_count=$(grep -oi "CVE-[0-9]*-[0-9]*" "$outfile" 2>/dev/null | sort -u | wc -l)
    if [ "$cve_count" -gt 0 ]; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 $cve_count টি CVE (Known Vulnerability) পাওয়া গেছে!${NC}"
        grep -oi "CVE-[0-9]*-[0-9]*" "$outfile" | sort -u | head -5 | while read -r cve; do
            echo -e "     ${YELLOW}→ $cve — https://cve.mitre.org/cgi-bin/cvename.cgi?name=$cve${NC}"
        done
        echo -e "     ${WHITE}→ প্রতিটি CVE একটি confirmed vulnerability।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # Timthumb
    if grep -qi "timthumb\|thumb.php" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ Timthumb Vulnerability পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ Timthumb script দিয়ে remote file inclusion সম্ভব।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Summary
    echo -e "  ${CYAN}${BOLD}━━━ সামগ্রিক ঝুঁকি মূল্যায়ন ━━━${NC}"
    echo -e "  ${RED}   Critical : $critical টি${NC}"
    echo -e "  ${YELLOW}   High     : $high টি${NC}"
    echo -e "  ${CYAN}   Medium   : $medium টি${NC}"
    echo -e "  ${WHITE}   Info/Low : $info টি${NC}"
    echo ""
    if   [ "$critical" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}  সার্বিক ঝুঁকি : ██████████ CRITICAL — WordPress সম্পূর্ণ compromised হওয়ার ঝুঁকি!${NC}"
    elif [ "$high" -gt 0 ]; then
        echo -e "  ${YELLOW}${BOLD}  সার্বিক ঝুঁকি : ███████░░░ HIGH — দ্রুত update ও patch করুন।${NC}"
    elif [ "$medium" -gt 0 ]; then
        echo -e "  ${CYAN}  সার্বিক ঝুঁকি : █████░░░░░ MEDIUM — কিছু configuration ঠিক করা দরকার।${NC}"
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

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Scan এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if grep -qi "user.*identified\|found.*user" "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}🔑 Hydra${NC} — WordPress Login Brute Force"
        echo -e "     ${WHITE}কারণ: Username পাওয়া গেছে — password attack করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: hydra -l found_user -P /usr/share/wordlists/rockyou.txt target.com http-post-form \"/wp-login.php:log=^USER^&pwd=^PASS^:ERROR\"${NC}"; echo ""
    fi

    if grep -qi "vulnerable plugin\|CVE-\|\[!\]" "$outfile" 2>/dev/null; then
        echo -e "  ${YELLOW}${BOLD}💉 SQLmap${NC} — Plugin SQL Injection Test"
        echo -e "     ${WHITE}কারণ: Vulnerable plugin পাওয়া গেছে — SQLi আছে কিনা test করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: sqlmap -u \"http://target.com/wp-content/plugins/plugin-name/file.php?id=1\" --dbs${NC}"; echo ""

        echo -e "  ${WHITE}${BOLD}🌐 Burp Suite${NC} — Manual Plugin Exploitation"
        echo -e "     ${WHITE}কারণ: Vulnerable plugin manually exploit করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: burpsuite (Proxy দিয়ে plugin request intercept করুন)${NC}"; echo ""
    fi

    echo -e "  ${GREEN}${BOLD}🔍 Gobuster${NC} — WordPress Directory Scan"
    echo -e "     ${WHITE}কারণ: Hidden WordPress files বের করুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: gobuster dir -u http://target.com -w /usr/share/wordlists/dirb/common.txt -x php,html${NC}"; echo ""

    echo -e "  ${MAGENTA}${BOLD}🔒 SSLScan${NC} — SSL/TLS Check"
    echo -e "     ${WHITE}কারণ: WordPress site এর SSL configuration check করুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: sslscan target.com${NC}"; echo ""

    if grep -qi "xmlrpc" "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}💥 WPScan XML-RPC Brute${NC} — XML-RPC Amplified Attack"
        echo -e "     ${WHITE}কারণ: XML-RPC চালু আছে — একটি request এ হাজার password test করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: wpscan --url http://target.com --password-attack xmlrpc -P wordlist.txt${NC}"; echo ""
    fi
}

# ================================================================
# SAVE RESULTS
# ================================================================
save_results() {
    local scan_out=$1
    local bangla_out=$2
    local out_file=$3
    local target=$4

    echo ""
    echo -e "${GREEN}[✓] WPScan output automatically save হয়েছে: $out_file${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] বাংলা analysis সহ full report save করবেন? (y/n): "${NC})" sc
    if [[ "$sc" =~ ^[Yy]$ ]]; then
        local report_file="${out_file%.txt}_bangla_report.txt"
        {
            echo "============================================================"
            echo "  WPSCAN RESULTS  —  SAIMUM's WordPress Automation Tool"
            echo "  Target : $target"
            echo "  Date   : $(date)"
            echo "============================================================"
            echo ""
            echo "=== WPSCAN RAW OUTPUT ==="
            cat "$scan_out"
            echo ""
            echo "=== BANGLA ANALYSIS ==="
            sed 's/\x1b\[[0-9;]*m//g' "$bangla_out"
        } > "$report_file"
        echo -e "${GREEN}[✓] Full report saved → $report_file${NC}"
        echo "$(date) | $target | $report_file" >> "$HISTORY_FILE"
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

        get_enumerate
        get_detection_mode
        get_api_and_bruteforce
        get_extra_options

        for t in "${TARGETS[@]}"; do
            echo ""
            echo -e "${BLUE}${BOLD}══════════════ Target: $t ══════════════${NC}"
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
