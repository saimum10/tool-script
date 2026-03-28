#!/bin/bash

# ================================================================
#   SSLSCAN - Full Automation Tool
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

RESULTS_DIR="$HOME/sslscan_results"
HISTORY_FILE="$HOME/.sslscan_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo ' ███████╗███████╗██╗      ███████╗ ██████╗ █████╗ ███╗   ██╗'
    echo ' ██╔════╝██╔════╝██║      ██╔════╝██╔════╝██╔══██╗████╗  ██║'
    echo ' ███████╗███████╗██║      ███████╗██║     ███████║██╔██╗ ██║'
    echo ' ╚════██║╚════██║██║      ╚════██║██║     ██╔══██║██║╚██╗██║'
    echo ' ███████║███████║███████╗ ███████║╚██████╗██║  ██║██║ ╚████║'
    echo ' ╚══════╝╚══════╝╚══════╝ ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝'
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}          SSLScan Full Automation Tool | SSL/TLS Analyzer${NC}"
    echo ""
}

# ================================================================
# CHECK DEPENDENCIES
# ================================================================
check_deps() {
    echo -e "${CYAN}[*] Dependencies চেক করা হচ্ছে...${NC}"
    local missing=()
    for tool in sslscan whois curl dig openssl; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
            echo -e "  ${RED}[✗] $tool — পাওয়া যায়নি${NC}"
        else
            echo -e "  ${GREEN}[✓] $tool${NC}"
        fi
    done

    # testssl optional
    echo ""
    if command -v testssl &>/dev/null || command -v testssl.sh &>/dev/null; then
        echo -e "  ${GREEN}[✓] testssl.sh — available (extra verification করা যাবে)${NC}"
        TESTSSL_AVAILABLE=true
    else
        echo -e "  ${YELLOW}[!] testssl.sh — নেই (optional)${NC}"
        TESTSSL_AVAILABLE=false
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing tools: ${missing[*]}${NC}"
        echo -e "${YELLOW}[*] Install করুন: sudo apt install sslscan openssl${NC}"
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
        "Registrar:|Registrant Name:|Country:|Creation Date:|Updated Date:|Organization:" \
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
# CERTIFICATE PRE-CHECK
# ================================================================
cert_precheck() {
    local target=$1
    local port=$2
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)

    echo -e "${CYAN}${BOLD}┌─── CERTIFICATE PRE-CHECK ─────────────────────────┐${NC}"

    # Get certificate info via openssl
    local cert_info
    cert_info=$(echo | timeout 8 openssl s_client \
        -connect "$domain:$port" \
        -servername "$domain" 2>/dev/null | \
        openssl x509 -noout \
        -subject -issuer -dates -fingerprint 2>/dev/null)

    if [ -n "$cert_info" ]; then
        local subject issuer not_before not_after fingerprint
        subject=$(echo     "$cert_info" | grep "^subject" | sed 's/subject=//')
        issuer=$(echo      "$cert_info" | grep "^issuer"  | sed 's/issuer=//')
        not_before=$(echo  "$cert_info" | grep "^notBefore" | cut -d'=' -f2)
        not_after=$(echo   "$cert_info" | grep "^notAfter"  | cut -d'=' -f2)
        fingerprint=$(echo "$cert_info" | grep "^SHA1" | cut -d'=' -f2)

        echo -e "  ${WHITE}Subject     :${NC} ${GREEN}$subject${NC}"
        echo -e "  ${WHITE}Issuer      :${NC} ${GREEN}$issuer${NC}"
        echo -e "  ${WHITE}Valid From  :${NC} ${GREEN}$not_before${NC}"
        echo -e "  ${WHITE}Valid Until :${NC} ${GREEN}$not_after${NC}"
        [ -n "$fingerprint" ] && \
            echo -e "  ${WHITE}Fingerprint :${NC} ${DIM}$fingerprint${NC}"

        # Expiry check
        if [ -n "$not_after" ]; then
            local expiry_epoch now_epoch days_left
            expiry_epoch=$(date -d "$not_after" +%s 2>/dev/null)
            now_epoch=$(date +%s)
            if [ -n "$expiry_epoch" ]; then
                days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
                echo ""
                if [ "$days_left" -lt 0 ]; then
                    echo -e "  ${RED}[!] Certificate EXPIRED ${days_left#-} দিন আগে!${NC}"
                elif [ "$days_left" -lt 14 ]; then
                    echo -e "  ${RED}[!] Certificate মাত্র $days_left দিন বাকি — জরুরি renew করুন!${NC}"
                elif [ "$days_left" -lt 30 ]; then
                    echo -e "  ${YELLOW}[!] Certificate $days_left দিনে expire হবে — renew করুন।${NC}"
                else
                    echo -e "  ${GREEN}[✓] Certificate valid — $days_left দিন বাকি।${NC}"
                fi
            fi
        fi

        # Self-signed check
        if echo "$cert_info" | grep -q "^issuer" && \
           [ "$(echo "$cert_info" | grep "^subject")" == "$(echo "$cert_info" | grep "^issuer" | sed 's/issuer/subject/')" ]; then
            echo -e "  ${YELLOW}[!] Self-signed certificate — browser warning দেখাবে।${NC}"
        fi

        # Wildcard cert
        if echo "$cert_info" | grep -qi "\*\."; then
            echo -e "  ${CYAN}[i] Wildcard certificate detect হয়েছে।${NC}"
        fi

    else
        echo -e "  ${YELLOW}[!] Certificate তথ্য পাওয়া যায়নি।${NC}"
        echo -e "  ${DIM}    Port $port তে SSL service নাও থাকতে পারে।${NC}"
    fi

    echo -e "${CYAN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# PRE-SCAN RECON
# ================================================================
pre_scan_recon() {
    local target=$1
    local port=$2
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)

    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}   PRE-SCAN RECON  ›  $target${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    whois_lookup  "$domain"
    geoip_lookup  "$domain"
    reverse_dns   "$domain"
    cert_precheck "$domain" "$port"
}

# ================================================================
# STEP 1 — TARGETS
# ================================================================
get_targets() {
    TARGETS=()

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║      STEP 1 — TARGET                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Single domain / IP"
    echo -e "  ${GREEN}2)${NC} Multiple (একটা একটা করে)"
    echo -e "  ${GREEN}3)${NC} File থেকে list"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-3]: "${NC})" ttype

    case $ttype in
        1)
            read -p "$(echo -e ${WHITE}"Domain বা IP দিন (e.g. example.com): "${NC})" t
            t=$(echo "$t" | sed 's|https\?://||' | cut -d'/' -f1)
            TARGETS=("$t")
            ;;
        2)
            echo -e "${WHITE}একটা একটা করে। শেষে 'done':${NC}"
            while true; do
                read -p "$(echo -e ${WHITE}"Target: "${NC})" t
                [[ "$t" == "done" || -z "$t" ]] && break
                t=$(echo "$t" | sed 's|https\?://||' | cut -d'/' -f1)
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
                line=$(echo "$line" | sed 's|https\?://||' | cut -d'/' -f1)
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
# STEP 2 — BASIC CONFIG
# ================================================================
get_basic_config() {
    PORT_OPT=""
    STARTTLS_OPT=""
    IP_VERSION_OPT=""
    SCAN_PORT="443"

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║      STEP 2 — BASIC CONFIG                                          ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Port
    read -p "$(echo -e ${WHITE}"Port দিন (Enter = 443): "${NC})" port_in
    if [ -n "$port_in" ]; then
        PORT_OPT="--port=$port_in"
        SCAN_PORT="$port_in"
        echo -e "  ${GREEN}[✓] Port: $port_in${NC}"
    else
        echo -e "  ${GREEN}[✓] Port: 443 (default HTTPS)${NC}"
    fi

    # STARTTLS (email servers এর জন্য)
    echo ""
    echo -e "  ${CYAN}STARTTLS mode? (Email server হলে দরকার)${NC}"
    echo -e "  ${GREEN}1)${NC} None      ${DIM}— normal HTTPS/SSL (default)${NC}"
    echo -e "  ${GREEN}2)${NC} SMTP      ${DIM}— port 25/587 email server${NC}"
    echo -e "  ${GREEN}3)${NC} IMAP      ${DIM}— port 143 email client${NC}"
    echo -e "  ${GREEN}4)${NC} POP3      ${DIM}— port 110 email${NC}"
    echo -e "  ${GREEN}5)${NC} FTP       ${DIM}— port 21${NC}"
    echo -e "  ${GREEN}6)${NC} XMPP      ${DIM}— port 5222 chat server${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"  Select [1-6, Enter=1]: "${NC})" starttls_ch
    case $starttls_ch in
        2) STARTTLS_OPT="--starttls-smtp"; echo -e "  ${GREEN}[✓] STARTTLS: SMTP${NC}" ;;
        3) STARTTLS_OPT="--starttls-imap"; echo -e "  ${GREEN}[✓] STARTTLS: IMAP${NC}" ;;
        4) STARTTLS_OPT="--starttls-pop3"; echo -e "  ${GREEN}[✓] STARTTLS: POP3${NC}" ;;
        5) STARTTLS_OPT="--starttls-ftp";  echo -e "  ${GREEN}[✓] STARTTLS: FTP${NC}"  ;;
        6) STARTTLS_OPT="--starttls-xmpp"; echo -e "  ${GREEN}[✓] STARTTLS: XMPP${NC}" ;;
        *) echo -e "  ${GREEN}[✓] STARTTLS: None (normal SSL)${NC}" ;;
    esac

    # IPv4 / IPv6
    echo ""
    echo -e "  ${CYAN}IP Version:${NC}"
    echo -e "  ${GREEN}1)${NC} IPv4 only  ${DIM}(default)${NC}"
    echo -e "  ${GREEN}2)${NC} IPv6 only"
    read -p "$(echo -e ${YELLOW}"  Select [1-2, Enter=1]: "${NC})" ipv_ch
    case $ipv_ch in
        2) IP_VERSION_OPT="--ipv6"; echo -e "  ${GREEN}[✓] IPv6 mode${NC}" ;;
        *) IP_VERSION_OPT="--ipv4"; echo -e "  ${GREEN}[✓] IPv4 mode${NC}" ;;
    esac
    echo ""
}

# ================================================================
# STEP 3 — WHAT TO CHECK
# ================================================================
get_check_config() {
    CHECK_OPT=""
    HEARTBLEED_OPT=""
    NO_CIPHER_OPT=""
    SCAN_LABEL=""

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║      STEP 3 — কী কী check করবে?                                   ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} ${YELLOW}সব একসাথে${NC}                  ${DIM}— Certificate + Ciphers + Protocols + Heartbleed${NC}"
    echo -e "  ${GREEN}2)${NC} শুধু Certificate info       ${DIM}— Expiry, issuer, SANs, key size${NC}"
    echo -e "  ${GREEN}3)${NC} শুধু Cipher suites          ${DIM}— কোন cipher গুলো accept করে${NC}"
    echo -e "  ${GREEN}4)${NC} শুধু Protocol versions      ${DIM}— SSLv2/v3/TLS1.0/1.1/1.2/1.3${NC}"
    echo -e "  ${GREEN}5)${NC} Heartbleed check only       ${DIM}— CVE-2014-0160 vulnerability${NC}"
    echo -e "  ${GREEN}6)${NC} Fast scan                   ${DIM}— cipher detail ছাড়া (দ্রুত)${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-6, Enter=1]: "${NC})" check_ch

    case $check_ch in
        2)
            CHECK_OPT="--no-ciphersuites"
            SCAN_LABEL="Certificate Info"
            ;;
        3)
            CHECK_OPT="--no-certificate"
            SCAN_LABEL="Cipher Suites"
            ;;
        4)
            CHECK_OPT="--no-certificate --no-ciphersuites"
            SCAN_LABEL="Protocol Versions"
            ;;
        5)
            HEARTBLEED_OPT="--heartbleed"
            CHECK_OPT="--no-certificate --no-ciphersuites"
            SCAN_LABEL="Heartbleed Check"
            ;;
        6)
            NO_CIPHER_OPT="--no-ciphersuites"
            SCAN_LABEL="Fast Scan"
            ;;
        *)
            HEARTBLEED_OPT=""
            CHECK_OPT=""
            SCAN_LABEL="Full SSL/TLS Scan"
            ;;
    esac

    echo -e "  ${GREEN}[✓] Scan type: $SCAN_LABEL${NC}"
    echo ""
}

# ================================================================
# STEP 4 — EXTRA OPTIONS
# ================================================================
get_extra_options() {
    SNI_OPT=""
    TIMEOUT_OPT=""
    VERBOSE_OPT=""
    BUGS_OPT=""
    OCSP_OPT=""

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║      STEP 4 — EXTRA OPTIONS (সব optional, Enter = skip)            ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # SNI hostname
    read -p "$(echo -e ${WHITE}"Custom SNI hostname দেবেন? Virtual host এর জন্য (Enter = skip): "${NC})" sni_in
    if [ -n "$sni_in" ]; then
        SNI_OPT="--sni-name=$sni_in"
        echo -e "  ${GREEN}[✓] SNI: $sni_in${NC}"
    fi

    # Timeout
    echo ""
    read -p "$(echo -e ${WHITE}"Connection timeout, seconds (Enter = 3): "${NC})" to_in
    [ -n "$to_in" ] && TIMEOUT_OPT="--timeout=$to_in" || TIMEOUT_OPT="--timeout=3"
    echo -e "  ${GREEN}[✓] Timeout: ${to_in:-3}s${NC}"

    # OCSP check
    echo ""
    read -p "$(echo -e ${WHITE}"OCSP (Certificate revocation) check করবেন? (y/n): "${NC})" ocsp_yn
    [[ "$ocsp_yn" =~ ^[Yy]$ ]] && OCSP_OPT="--ocsp" && \
        echo -e "  ${GREEN}[✓] OCSP check: ON${NC}"

    # Bug workaround
    echo ""
    read -p "$(echo -e ${WHITE}"Buggy SSL server? (handshake fail হলে try করুন) (y/n): "${NC})" bugs_yn
    [[ "$bugs_yn" =~ ^[Yy]$ ]] && BUGS_OPT="--bugs" && \
        echo -e "  ${GREEN}[✓] Bug workaround: ON${NC}"

    # Verbose
    echo ""
    read -p "$(echo -e ${WHITE}"Verbose mode চালু করবেন? (y/n): "${NC})" vb_yn
    [[ "$vb_yn" =~ ^[Yy]$ ]] && VERBOSE_OPT="--verbose" && \
        echo -e "  ${GREEN}[✓] Verbose: ON${NC}"

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
    local out_file="$RESULTS_DIR/sslscan_${safe}_${ts}.txt"

    local final_cmd
    final_cmd=$(echo "sslscan \
        $PORT_OPT \
        $STARTTLS_OPT \
        $IP_VERSION_OPT \
        $CHECK_OPT \
        $HEARTBLEED_OPT \
        $NO_CIPHER_OPT \
        $SNI_OPT \
        $TIMEOUT_OPT \
        $OCSP_OPT \
        $BUGS_OPT \
        $VERBOSE_OPT \
        $target" | tr -s ' ')

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║      CONFIRM & RUN                                                  ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${WHITE}Target    : ${GREEN}${BOLD}$target${NC}"
    echo -e "  ${WHITE}Scan Type : ${YELLOW}$SCAN_LABEL${NC}"
    echo -e "  ${WHITE}Command   : ${CYAN}$final_cmd${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Scan শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local tmp_scan tmp_bangla
    tmp_scan=$(mktemp)
    tmp_bangla=$(mktemp)

    echo ""
    echo -e "${GREEN}${BOLD}[*] SSLScan শুরু হচ্ছে...${NC}"
    echo ""

    # Real SSLScan — হুবহু original terminal output
    eval "$final_cmd" 2>&1 | tee "$tmp_scan"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Scan সম্পন্ন!${NC}"

    bangla_analysis   "$tmp_scan" "$tmp_bangla" "$target"
    suggest_next_tool "$tmp_scan" "$target"
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

    {
    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় স্ক্যান রিপোর্ট বিশ্লেষণ                      ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local critical=0 high=0 medium=0 info=0

    # Heartbleed
    if grep -qi "heartbleed.*vulnerable\|VULNERABLE.*heartbleed" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Heartbleed (CVE-2014-0160) Vulnerability পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ Server এর memory থেকে sensitive data চুরি সম্ভব।${NC}"
        echo -e "     ${WHITE}→ Private key, password, session token সব exposed।${NC}"
        echo -e "     ${WHITE}→ এখনই OpenSSL update করুন!${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # SSLv2
    if grep -qi "SSLv2.*enabled\|SSLv2.*accepted" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 SSLv2 চালু আছে!${NC}"
        echo -e "     ${WHITE}→ SSLv2 সম্পূর্ণ বাতিল — multiple critical vulnerability।${NC}"
        echo -e "     ${WHITE}→ DROWN attack সম্ভব — RSA key compromise হতে পারে।${NC}"
        echo -e "     ${WHITE}→ এখনই SSLv2 disable করুন।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # SSLv3
    if grep -qi "SSLv3.*enabled\|SSLv3.*accepted" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 SSLv3 চালু আছে!${NC}"
        echo -e "     ${WHITE}→ POODLE attack সম্ভব — CBC cipher এর vulnerability।${NC}"
        echo -e "     ${WHITE}→ SSLv3 disable করুন — TLS ব্যবহার করুন।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # TLS 1.0
    if grep -qi "TLSv1.0.*enabled\|TLS 1\.0.*enabled\|TLSv1   enabled" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ TLS 1.0 চালু আছে!${NC}"
        echo -e "     ${WHITE}→ BEAST attack সম্ভব।${NC}"
        echo -e "     ${WHITE}→ PCI DSS compliance এ TLS 1.0 allowed না।${NC}"
        echo -e "     ${WHITE}→ TLS 1.2 বা 1.3 ব্যবহার করুন।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # TLS 1.1
    if grep -qi "TLSv1.1.*enabled\|TLS 1\.1.*enabled\|TLSv1\.1 enabled" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ TLS 1.1 চালু আছে!${NC}"
        echo -e "     ${WHITE}→ Deprecated protocol — modern browser support নেই।${NC}"
        echo -e "     ${WHITE}→ TLS 1.2 বা 1.3 এ migrate করুন।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # TLS 1.2 — Good
    if grep -qi "TLSv1.2.*enabled\|TLS 1\.2.*enabled" "$outfile" 2>/dev/null; then
        info=$((info+1))
        echo -e "  ${GREEN}${BOLD}✅ TLS 1.2 চালু আছে।${NC}"
        echo -e "     ${WHITE}→ Acceptable — তবে TLS 1.3 আরো ভালো।${NC}"
        echo -e "     ${GREEN}→ ঝুঁকি: INFO (ভালো)${NC}"; echo ""
    fi

    # TLS 1.3 — Best
    if grep -qi "TLSv1.3.*enabled\|TLS 1\.3.*enabled" "$outfile" 2>/dev/null; then
        info=$((info+1))
        echo -e "  ${GREEN}${BOLD}✅ TLS 1.3 চালু আছে!${NC}"
        echo -e "     ${WHITE}→ সবচেয়ে আধুনিক ও নিরাপদ protocol।${NC}"
        echo -e "     ${GREEN}→ ঝুঁকি: INFO (খুব ভালো)${NC}"; echo ""
    fi

    # Weak ciphers
    if grep -qi "RC4\|DES\|3DES\|NULL cipher\|EXPORT\|anon\|ADH\|AECDH" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Weak / Broken Cipher Suite পাওয়া গেছে!${NC}"
        grep -iE "RC4|DES |3DES|NULL|EXPORT|anon" "$outfile" | head -5 | while read -r line; do
            echo -e "     ${YELLOW}→ $line${NC}"
        done
        echo -e "     ${WHITE}→ এই ciphers ক্র্যাক করা সম্ভব — plaintext পড়া যাবে।${NC}"
        echo -e "     ${WHITE}→ Server config থেকে এই ciphers disable করুন।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # MD5 signature
    if grep -qi "md5\|signature.*md5" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ MD5 Signature Algorithm!${NC}"
        echo -e "     ${WHITE}→ MD5 collision attack সম্ভব — certificate forged হতে পারে।${NC}"
        echo -e "     ${WHITE}→ SHA-256 বা SHA-384 ব্যবহার করুন।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Weak key size
    if grep -qi "512 bit\|768 bit\|1024 bit" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ Weak RSA Key Size!${NC}"
        echo -e "     ${WHITE}→ 1024-bit বা কম key factorize করা সম্ভব।${NC}"
        echo -e "     ${WHITE}→ ন্যূনতম 2048-bit RSA বা 256-bit ECC ব্যবহার করুন।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Certificate expired
    if grep -qi "certificate.*expired\|not valid after" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ Certificate Expired বা Expiring Soon!${NC}"
        echo -e "     ${WHITE}→ Browser এ warning দেখাবে — user trust হারাবে।${NC}"
        echo -e "     ${WHITE}→ এখনই certificate renew করুন।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Self-signed
    if grep -qi "self.signed\|self signed" "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}ℹ Self-Signed Certificate!${NC}"
        echo -e "     ${WHITE}→ Browser এ security warning দেখাবে।${NC}"
        echo -e "     ${WHITE}→ Trusted CA থেকে certificate নিন (Let's Encrypt free)।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # HSTS
    if grep -qi "HSTS\|strict.transport" "$outfile" 2>/dev/null; then
        info=$((info+1))
        echo -e "  ${GREEN}${BOLD}✅ HSTS (HTTP Strict Transport Security) চালু।${NC}"
        echo -e "     ${WHITE}→ Browser কে সবসময় HTTPS ব্যবহার করতে বাধ্য করে।${NC}"
        echo -e "     ${GREEN}→ ঝুঁকি: INFO (ভালো)${NC}"; echo ""
    fi

    # Perfect Forward Secrecy
    if grep -qi "ECDHE\|DHE\|forward secrecy" "$outfile" 2>/dev/null; then
        info=$((info+1))
        echo -e "  ${GREEN}${BOLD}✅ Perfect Forward Secrecy (PFS) supported।${NC}"
        echo -e "     ${WHITE}→ Session key আলাদা — recorded traffic পরে decrypt হবে না।${NC}"
        echo -e "     ${GREEN}→ ঝুঁকি: INFO (ভালো)${NC}"; echo ""
    fi

    # Summary
    echo -e "  ${CYAN}${BOLD}━━━ সামগ্রিক SSL/TLS ঝুঁকি মূল্যায়ন ━━━${NC}"
    echo -e "  ${RED}   Critical : $critical টি${NC}"
    echo -e "  ${YELLOW}   High     : $high টি${NC}"
    echo -e "  ${CYAN}   Medium   : $medium টি${NC}"
    echo -e "  ${WHITE}   Info/Low : $info টি${NC}"
    echo ""
    if   [ "$critical" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}  সার্বিক ঝুঁকি : ██████████ CRITICAL — SSL/TLS সম্পূর্ণ insecure!${NC}"
    elif [ "$high" -gt 0 ]; then
        echo -e "  ${YELLOW}${BOLD}  সার্বিক ঝুঁকি : ███████░░░ HIGH — গুরুত্বপূর্ণ সমস্যা আছে।${NC}"
    elif [ "$medium" -gt 0 ]; then
        echo -e "  ${CYAN}  সার্বিক ঝুঁকি : █████░░░░░ MEDIUM — কিছু উন্নতি করা দরকার।${NC}"
    else
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW — SSL/TLS configuration ভালো।${NC}"
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

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Scan এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if grep -qi "heartbleed.*vulnerable" "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}💀 Metasploit${NC} — Heartbleed Exploitation"
        echo -e "     ${WHITE}কারণ: Heartbleed পাওয়া গেছে — memory dump করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: msfconsole → use auxiliary/scanner/ssl/openssl_heartbleed${NC}"; echo ""
    fi

    if grep -qi "SSLv2\|SSLv3\|RC4\|weak cipher" "$outfile" 2>/dev/null; then
        echo -e "  ${YELLOW}${BOLD}🔧 testssl.sh${NC} — Deep SSL/TLS Analysis"
        echo -e "     ${WHITE}কারণ: Weak protocol/cipher পাওয়া গেছে — further test করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: testssl.sh $target${NC}"; echo ""
    fi

    echo -e "  ${GREEN}${BOLD}🌐 Nikto${NC} — Web Vulnerability Scan"
    echo -e "     ${WHITE}কারণ: SSL check এর পর web layer scan করুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: nikto -h https://$target -ssl${NC}"; echo ""

    echo -e "  ${BLUE}${BOLD}🔍 Nmap SSL Scripts${NC} — Additional SSL Checks"
    echo -e "     ${WHITE}কারণ: Nmap এর ssl-* scripts দিয়ে আরো check করুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: nmap -sV --script ssl-enum-ciphers,ssl-dh-params,ssl-cert -p 443 $target${NC}"; echo ""

    echo -e "  ${MAGENTA}${BOLD}🔒 Amass${NC} — Next in the workflow"
    echo -e "     ${WHITE}কারণ: SSL scan এর পর deep subdomain enumeration করুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: amass enum -d $target${NC}"; echo ""
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
    read -p "$(echo -e ${YELLOW}"[?] Result save করবেন? (y/n): "${NC})" sc
    if [[ "$sc" =~ ^[Yy]$ ]]; then
        {
            echo "============================================================"
            echo "  SSLSCAN RESULTS  —  SAIMUM's SSL/TLS Automation Tool"
            echo "  Target : $target"
            echo "  Date   : $(date)"
            echo "============================================================"
            echo ""
            echo "=== SSLSCAN RAW OUTPUT ==="
            cat "$scan_out"
            echo ""
            echo "=== BANGLA ANALYSIS ==="
            sed 's/\x1b\[[0-9;]*m//g' "$bangla_out"
        } > "$out_file"
        echo -e "${GREEN}[✓] Saved → $out_file${NC}"
        echo "$(date) | $target | $out_file" >> "$HISTORY_FILE"
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

        # Step 2 — Basic config (port decide করা হয়)
        get_basic_config

        # Pre-scan recon (port জেনে cert check করে)
        for t in "${TARGETS[@]}"; do
            pre_scan_recon "$t" "$SCAN_PORT"
        done

        # Step 3 — What to check
        get_check_config

        # Step 4 — Extra options
        get_extra_options

        # Run for each target
        for t in "${TARGETS[@]}"; do
            echo ""
            echo -e "${CYAN}${BOLD}══════════════ Target: $t ══════════════${NC}"
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
