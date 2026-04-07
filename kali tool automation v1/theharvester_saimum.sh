#!/bin/bash

# ================================================================
#   THEHARVESTER - Full Automation Tool
#   Author: SAIMUM
# ================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
WHITE='\033[1;37m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

RESULTS_DIR="$HOME/theharvester_results"
HISTORY_FILE="$HOME/.theharvester_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${YELLOW}${BOLD}"
    echo ' ████████╗██╗  ██╗███████╗'
    echo ' ╚══██╔══╝██║  ██║██╔════╝'
    echo '    ██║   ███████║█████╗  '
    echo '    ██║   ██╔══██║██╔══╝  '
    echo '    ██║   ██║  ██║███████╗'
    echo '    ╚═╝   ╚═╝  ╚═╝╚══════╝'
    echo ''
    echo ' ██╗  ██╗ █████╗ ██████╗ ██╗   ██╗███████╗███████╗████████╗███████╗██████╗ '
    echo ' ██║  ██║██╔══██╗██╔══██╗██║   ██║██╔════╝██╔════╝╚══██╔══╝██╔════╝██╔══██╗'
    echo ' ███████║███████║██████╔╝██║   ██║█████╗  ███████╗   ██║   █████╗  ██████╔╝'
    echo ' ██╔══██║██╔══██║██╔══██╗╚██╗ ██╔╝██╔══╝  ╚════██║   ██║   ██╔══╝  ██╔══██╗'
    echo ' ██║  ██║██║  ██║██║  ██║ ╚████╔╝ ███████╗███████║   ██║   ███████╗██║  ██║'
    echo ' ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝'
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}         theHarvester Full Automation | OSINT & Email/Domain Recon${NC}"
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

    HARVESTER_CMD=""
    if command -v theHarvester &>/dev/null; then
        HARVESTER_CMD="theHarvester"
        echo -e "  ${GREEN}[✓] theHarvester${NC}"
    elif command -v theharvester &>/dev/null; then
        HARVESTER_CMD="theharvester"
        echo -e "  ${GREEN}[✓] theharvester${NC}"
    elif [ -f "/usr/lib/python3/dist-packages/theHarvester/theHarvester.py" ]; then
        HARVESTER_CMD="python3 /usr/lib/python3/dist-packages/theHarvester/theHarvester.py"
        echo -e "  ${GREEN}[✓] theHarvester.py${NC}"
    elif [ -f "$HOME/theHarvester/theHarvester.py" ]; then
        HARVESTER_CMD="python3 $HOME/theHarvester/theHarvester.py"
        echo -e "  ${GREEN}[✓] theHarvester.py (~/theHarvester/)${NC}"
    else
        missing+=("theHarvester")
        echo -e "  ${RED}[✗] theHarvester — পাওয়া যায়নি${NC}"
    fi

    for tool in curl python3 whois dig; do
        command -v "$tool" &>/dev/null && \
            echo -e "  ${GREEN}[✓] $tool${NC}" || \
            echo -e "  ${YELLOW}[!] $tool — নেই${NC}"
    done

    echo ""
    echo -e "${CYAN}[*] Optional tools:${NC}"
    for opt in nmap nuclei subfinder amass; do
        command -v "$opt" &>/dev/null && \
            echo -e "  ${GREEN}[✓] $opt${NC}" || \
            echo -e "  ${YELLOW}[!] $opt — নেই${NC}"
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing: ${missing[*]}${NC}"
        echo -e "${YELLOW}Install করুন:${NC}"
        echo -e "  ${WHITE}sudo apt install theharvester${NC}"
        echo -e "  ${WHITE}অথবা: pip3 install theHarvester${NC}"
        echo -e "  ${WHITE}অথবা: git clone https://github.com/laramies/theHarvester.git${NC}"
        exit 1
    fi

    echo ""
    local hver; hver=$($HARVESTER_CMD --version 2>&1 | head -1)
    echo -e "${CYAN}[*] theHarvester: ${GREEN}$hver${NC}"
    echo ""
}

# ================================================================
# GET TARGET
# ================================================================
get_target() {
    TARGET=""

    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║         TARGET SELECT                ║${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo -e "  ${GREEN}1)${NC} Single Domain"
    echo -e "  ${GREEN}2)${NC} Multiple Domains"
    echo -e "  ${GREEN}3)${NC} File থেকে Domain list"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-3]: "${NC})" ttype

    case $ttype in
        1)
            read -p "$(echo -e ${WHITE}"Domain দিন (e.g. target.com): "${NC})" t
            t=$(echo "$t" | sed 's|https\?://||' | cut -d'/' -f1)
            TARGET="$t"
            TARGET_LIST=("$t")
            ;;
        2)
            TARGET_LIST=()
            echo -e "${WHITE}Domains দিন। 'done' লিখলে শেষ:${NC}"
            while true; do
                read -p "$(echo -e ${WHITE}"Domain: "${NC})" t
                [[ "$t" == "done" || -z "$t" ]] && break
                t=$(echo "$t" | sed 's|https\?://||' | cut -d'/' -f1)
                TARGET_LIST+=("$t")
            done
            TARGET="${TARGET_LIST[0]}"
            ;;
        3)
            read -p "$(echo -e ${WHITE}"File path: "${NC})" domain_file
            [ ! -f "$domain_file" ] && echo -e "${RED}[!] File নেই।${NC}" && get_target && return
            TARGET_FILE="$domain_file"
            TARGET=$(head -1 "$domain_file")
            TARGET_LIST=()
            while IFS= read -r d; do
                [ -n "$d" ] && TARGET_LIST+=("$d")
            done < "$domain_file"
            ;;
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
    local domain=$1

    echo ""
    echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}${BOLD}   PRE-SCAN RECON  ›  $domain${NC}"
    echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    echo -e "${MAGENTA}${BOLD}┌─── WHOIS ──────────────────────────────────────────┐${NC}"
    whois "$domain" 2>/dev/null | grep -E "Registrar:|Country:|Organization:|Creation Date:|Admin Email:|Registrant Email:" | head -8 | \
        while IFS= read -r l; do echo -e "  ${WHITE}$l${NC}"; done
    echo -e "${MAGENTA}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${BLUE}${BOLD}┌─── DNS INFO ────────────────────────────────────────┐${NC}"
    local ip_a; ip_a=$(dig +short "$domain" A 2>/dev/null | head -3)
    local mx;   mx=$(dig +short "$domain" MX 2>/dev/null | head -3)
    local ns;   ns=$(dig +short "$domain" NS 2>/dev/null | head -3)
    local txt;  txt=$(dig +short "$domain" TXT 2>/dev/null | head -3)
    [ -n "$ip_a" ] && echo -e "  ${WHITE}A Record  : ${GREEN}$ip_a${NC}"
    [ -n "$mx"   ] && echo -e "  ${WHITE}MX Record : ${GREEN}$mx${NC}"
    [ -n "$ns"   ] && echo -e "  ${WHITE}NS Record : ${GREEN}$ns${NC}"
    [ -n "$txt"  ] && echo -e "  ${WHITE}TXT Record: ${GREEN}$txt${NC}"
    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}┌─── GEO IP ──────────────────────────────────────────┐${NC}"
    local geo; geo=$(curl -s --max-time 5 "http://ip-api.com/json/$domain" 2>/dev/null)
    if echo "$geo" | grep -q '"status":"success"'; then
        local ip country city isp
        ip=$(echo "$geo"      | grep -o '"query":"[^"]*"'   | cut -d'"' -f4)
        country=$(echo "$geo" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        city=$(echo "$geo"    | grep -o '"city":"[^"]*"'    | cut -d'"' -f4)
        isp=$(echo "$geo"     | grep -o '"isp":"[^"]*"'     | cut -d'"' -f4)
        echo -e "  ${WHITE}IP: ${GREEN}$ip${NC}  |  ${WHITE}$city, $country${NC}  |  ${WHITE}$isp${NC}"
    fi
    echo -e "${CYAN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# SOURCE LIST
# ================================================================
show_sources() {
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                  AVAILABLE DATA SOURCES                             ║${NC}"
    echo -e "${CYAN}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}Free Sources:${NC}"
    echo -e "${CYAN}║${NC}  bing, google, yahoo, duckduckgo, baidu, ask"
    echo -e "${CYAN}║${NC}  crtsh, certspotter, dnsdumpster, hackertarget"
    echo -e "${CYAN}║${NC}  urlscan, otx, alienvault, threatcrowd"
    echo -e "${CYAN}║${NC}  anubis, rapiddns, sublist3r"
    echo -e "${CYAN}║${NC} ${YELLOW}API Key Required:${NC}"
    echo -e "${CYAN}║${NC}  shodan, hunter, virustotal, securitytrails"
    echo -e "${CYAN}║${NC}  spyse, fullhunt, binaryedge, zoomeye"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ================================================================
# SCAN MENU
# ================================================================
show_menu() {
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║               THEHARVESTER SCAN OPTIONS                             ║${NC}"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ BASIC SCANS ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}1${NC}  Quick OSINT Scan         — top free sources দিয়ে"
    echo -e "${YELLOW}║${NC} ${GREEN}2${NC}  Full OSINT Scan          — সব available sources"
    echo -e "${YELLOW}║${NC} ${GREEN}3${NC}  Email Harvest            — শুধু emails collect"
    echo -e "${YELLOW}║${NC} ${GREEN}4${NC}  Subdomain Harvest        — শুধু subdomains collect"
    echo -e "${YELLOW}║${NC} ${GREEN}5${NC}  IP / Host Harvest        — IPs এবং hosts collect"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ SOURCE-SPECIFIC ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}6${NC}  Search Engine Scan       — Google, Bing, Yahoo, DuckDuckGo"
    echo -e "${YELLOW}║${NC} ${GREEN}7${NC}  Certificate Transparency — crtsh, certspotter"
    echo -e "${YELLOW}║${NC} ${GREEN}8${NC}  DNS Sources Scan         — dnsdumpster, hackertarget"
    echo -e "${YELLOW}║${NC} ${GREEN}9${NC}  Threat Intel Scan        — OTX, ThreatCrowd, URLScan"
    echo -e "${YELLOW}║${NC} ${GREEN}10${NC} Shodan Source Scan       — Shodan দিয়ে harvest"
    echo -e "${YELLOW}║${NC} ${GREEN}11${NC} Hunter.io Email Scan     — Hunter.io API"
    echo -e "${YELLOW}║${NC} ${GREEN}12${NC} Custom Source Scan       — নিজে source বেছে নাও"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ ADVANCED ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}13${NC} DNS Brute Force          — subdomain brute force"
    echo -e "${YELLOW}║${NC} ${GREEN}14${NC} Virtual Host Discovery   — vhosts enumerate"
    echo -e "${YELLOW}║${NC} ${GREEN}15${NC} Multiple Domain Scan     — একাধিক domain একসাথে"
    echo -e "${YELLOW}║${NC} ${GREEN}16${NC} Deep Scan (All + DNS)    — sources + DNS brute"
    echo -e "${YELLOW}║${NC} ${GREEN}17${NC} Screenshot Capture       — found hosts screenshot"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ OUTPUT / FILTER ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}18${NC} Email-Only Output        — শুধু emails filter করো"
    echo -e "${YELLOW}║${NC} ${GREEN}19${NC} Subdomain-Only Output    — শুধু subdomains filter"
    echo -e "${YELLOW}║${NC} ${GREEN}20${NC} IP-Only Output           — শুধু IPs filter করো"
    echo -e "${YELLOW}║${NC} ${GREEN}21${NC} Export XML Report        — XML format এ save"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ COMBO ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}22${NC} Smart OSINT Recon        — email+subdomain+IP একসাথে"
    echo -e "${YELLOW}║${NC} ${GREEN}23${NC} All-in-One Mega Harvest  — সব source + সব data"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${RED}0)${NC} Exit                                                               ${YELLOW}║${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ================================================================
# EXTRA OPTIONS
# ================================================================
get_extra_options() {
    LIMIT_OPT=""; START_OPT=""; DNS_OPT=""; VHOST_OPT=""

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║         EXTRA OPTIONS                ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""

    read -p "$(echo -e ${WHITE}"Result limit (Enter=500): "${NC})" lim
    [ -n "$lim" ] && LIMIT_OPT="-l $lim" || LIMIT_OPT="-l 500"

    read -p "$(echo -e ${WHITE}"Start result (Enter=0): "${NC})" start
    [ -n "$start" ] && START_OPT="-S $start"

    read -p "$(echo -e ${WHITE}"DNS brute force? (y/n, Enter=n): "${NC})" dns
    [[ "$dns" =~ ^[Yy]$ ]] && DNS_OPT="-dns-brute"

    read -p "$(echo -e ${WHITE}"Virtual hosts? (y/n, Enter=n): "${NC})" vh
    [[ "$vh" =~ ^[Yy]$ ]] && VHOST_OPT="-virtual-host"

    echo ""
}

# ================================================================
# RUN HARVESTER CORE
# ================================================================
run_harvester() {
    local label=$1 sources=$2 domain="${3:-$TARGET}"

    SCAN_LABEL="$label"
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$domain" | sed 's/[^a-zA-Z0-9._-]/_/g')
    OUTPUT_FILE="$RESULTS_DIR/${label// /_}_${safe}_${ts}"
    local xml_out="${OUTPUT_FILE}.xml"
    local txt_out="${OUTPUT_FILE}.txt"

    local cmd="$HARVESTER_CMD -d $domain -b $sources $LIMIT_OPT $START_OPT $DNS_OPT $VHOST_OPT -f $OUTPUT_FILE"

    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}Scan Type : ${YELLOW}${BOLD}$label${NC}"
    echo -e "  ${WHITE}Domain    : ${GREEN}${BOLD}$domain${NC}"
    echo -e "  ${WHITE}Sources   : ${CYAN}$sources${NC}"
    echo -e "  ${WHITE}Output    : ${CYAN}$txt_out${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] Scan শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    echo ""
    echo -e "${GREEN}${BOLD}[*] theHarvester চালু হচ্ছে...${NC}"
    echo ""

    eval "$cmd" 2>&1 | tee "$txt_out"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Scan সম্পন্ন!${NC}"
    echo ""

    bangla_analysis "$txt_out" "$domain"
    suggest_next_tool "$txt_out" "$domain"
    save_results "$txt_out"
}

# ================================================================
# MODE 1 — QUICK OSINT
# ================================================================
mode_quick() {
    run_harvester "Quick OSINT" "bing,google,crtsh,hackertarget,dnsdumpster,anubis"
}

# ================================================================
# MODE 2 — FULL OSINT
# ================================================================
mode_full() {
    echo -e "${YELLOW}[!] Full scan অনেক sources ব্যবহার করে — সময় লাগতে পারে।${NC}"
    run_harvester "Full OSINT" "bing,google,yahoo,duckduckgo,crtsh,certspotter,dnsdumpster,hackertarget,urlscan,otx,anubis,rapiddns,sublist3r,threatcrowd,alienvault"
}

# ================================================================
# MODE 3 — EMAIL HARVEST
# ================================================================
mode_email_harvest() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's/[^a-zA-Z0-9._-]/_/g')
    OUTPUT_FILE="$RESULTS_DIR/emails_${safe}_${ts}.txt"
    SCAN_LABEL="Email Harvest"

    echo ""
    echo -e "${GREEN}[*] Email harvest শুরু হচ্ছে: $TARGET${NC}"
    echo ""

    # Run with email-focused sources
    eval "$HARVESTER_CMD -d $TARGET -b bing,google,yahoo,hunter,crtsh $LIMIT_OPT -f ${RESULTS_DIR}/email_raw_${safe}_${ts}" 2>&1 | \
        tee "$OUTPUT_FILE"

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Found Emails ━━━${NC}"
    grep -oiE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$OUTPUT_FILE" 2>/dev/null | \
        sort -u | while IFS= read -r em; do
            echo -e "  ${GREEN}▸ $em${NC}"
        done

    local email_count; email_count=$(grep -oiE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$OUTPUT_FILE" 2>/dev/null | sort -u | wc -l)
    echo ""
    echo -e "  ${WHITE}মোট Emails: ${GREEN}$email_count${NC}"

    bangla_analysis "$OUTPUT_FILE" "$TARGET"
    suggest_next_tool "$OUTPUT_FILE" "$TARGET"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 4 — SUBDOMAIN HARVEST
# ================================================================
mode_subdomain_harvest() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's/[^a-zA-Z0-9._-]/_/g')
    OUTPUT_FILE="$RESULTS_DIR/subdomains_${safe}_${ts}.txt"
    SCAN_LABEL="Subdomain Harvest"

    echo ""
    echo -e "${GREEN}[*] Subdomain harvest শুরু হচ্ছে: $TARGET${NC}"
    echo ""

    eval "$HARVESTER_CMD -d $TARGET -b crtsh,certspotter,dnsdumpster,hackertarget,anubis,rapiddns,sublist3r $LIMIT_OPT -f ${RESULTS_DIR}/sub_raw_${safe}_${ts}" 2>&1 | \
        tee "$OUTPUT_FILE"

    echo ""
    echo -e "${CYAN}${BOLD}━━━ Found Subdomains ━━━${NC}"
    grep -iE "\.$TARGET" "$OUTPUT_FILE" 2>/dev/null | sort -u | head -30 | \
        while IFS= read -r sub; do echo -e "  ${GREEN}▸ $sub${NC}"; done

    local sub_count; sub_count=$(grep -icE "\.$TARGET" "$OUTPUT_FILE" 2>/dev/null || echo 0)
    echo -e "  ${WHITE}মোট Subdomains: ${GREEN}$sub_count${NC}"

    bangla_analysis "$OUTPUT_FILE" "$TARGET"
    suggest_next_tool "$OUTPUT_FILE" "$TARGET"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 5 — IP / HOST HARVEST
# ================================================================
mode_ip_harvest() {
    run_harvester "IP/Host Harvest" "bing,hackertarget,dnsdumpster,shodan,urlscan"
}

# ================================================================
# MODE 6 — SEARCH ENGINES
# ================================================================
mode_search_engines() {
    echo -e "${CYAN}Search engines:${NC}"
    echo -e "  ${GREEN}1)${NC} সব  ${GREEN}2)${NC} Google only  ${GREEN}3)${NC} Bing  ${GREEN}4)${NC} DuckDuckGo  ${GREEN}5)${NC} Yahoo"
    read -p "$(echo -e ${YELLOW}"[1-5]: "${NC})" sch
    local src=""
    case $sch in
        1) src="bing,google,yahoo,duckduckgo,baidu,ask" ;;
        2) src="google" ;;
        3) src="bing" ;;
        4) src="duckduckgo" ;;
        5) src="yahoo" ;;
        *) src="bing,google,yahoo,duckduckgo" ;;
    esac
    run_harvester "Search Engine ($src)" "$src"
}

# ================================================================
# MODE 7 — CERTIFICATE TRANSPARENCY
# ================================================================
mode_cert_transparency() {
    run_harvester "Certificate Transparency" "crtsh,certspotter"
}

# ================================================================
# MODE 8 — DNS SOURCES
# ================================================================
mode_dns_sources() {
    run_harvester "DNS Sources" "dnsdumpster,hackertarget,rapiddns,anubis"
}

# ================================================================
# MODE 9 — THREAT INTEL
# ================================================================
mode_threat_intel() {
    run_harvester "Threat Intel" "otx,urlscan,threatcrowd,alienvault"
}

# ================================================================
# MODE 10 — SHODAN SOURCE
# ================================================================
mode_shodan_source() {
    echo -e "${YELLOW}[!] Shodan API key লাগবে। ~/.theHarvester/api-keys.yaml এ set করুন।${NC}"
    run_harvester "Shodan Source" "shodan"
}

# ================================================================
# MODE 11 — HUNTER.IO
# ================================================================
mode_hunter_io() {
    echo -e "${YELLOW}[!] Hunter.io API key লাগবে। ~/.theHarvester/api-keys.yaml এ set করুন।${NC}"
    run_harvester "Hunter.io Email" "hunter"
}

# ================================================================
# MODE 12 — CUSTOM SOURCE
# ================================================================
mode_custom_source() {
    show_sources
    read -p "$(echo -e ${WHITE}"Sources দিন (comma-separated): "${NC})" sources
    [ -z "$sources" ] && echo -e "${RED}[!] Source দাও।${NC}" && return
    run_harvester "Custom Source ($sources)" "$sources"
}

# ================================================================
# MODE 13 — DNS BRUTE FORCE
# ================================================================
mode_dns_brute() {
    DNS_OPT="-dns-brute"
    echo -e "${YELLOW}[!] DNS brute force সময় নিতে পারে।${NC}"
    run_harvester "DNS Brute Force" "bing,crtsh,dnsdumpster"
    DNS_OPT=""
}

# ================================================================
# MODE 14 — VIRTUAL HOST
# ================================================================
mode_vhost() {
    VHOST_OPT="-virtual-host"
    run_harvester "Virtual Host Discovery" "bing,google,crtsh"
    VHOST_OPT=""
}

# ================================================================
# MODE 15 — MULTIPLE DOMAINS
# ================================================================
mode_multiple_domains() {
    if [ ${#TARGET_LIST[@]} -le 1 ]; then
        echo -e "${YELLOW}[!] Multiple domain select করুন (target option 2/3)।${NC}"
        return
    fi

    for domain in "${TARGET_LIST[@]}"; do
        echo ""
        echo -e "${CYAN}${BOLD}══════════════ $domain ══════════════${NC}"
        run_harvester "Multi-Domain" "bing,google,crtsh,dnsdumpster" "$domain"
    done
}

# ================================================================
# MODE 16 — DEEP SCAN
# ================================================================
mode_deep_scan() {
    DNS_OPT="-dns-brute"
    echo -e "${YELLOW}[!] Deep scan — সব sources + DNS brute। অনেক সময় লাগতে পারে।${NC}"
    run_harvester "Deep Scan" "bing,google,yahoo,crtsh,certspotter,dnsdumpster,hackertarget,anubis,rapiddns,urlscan,otx,alienvault"
    DNS_OPT=""
}

# ================================================================
# MODE 17 — SCREENSHOT
# ================================================================
mode_screenshot() {
    echo ""
    echo -e "${CYAN}[*] theHarvester এ screenshot feature (Pro version এ বা external tool):${NC}"
    echo ""

    # Run harvest first
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's/[^a-zA-Z0-9._-]/_/g')
    local sub_file="$RESULTS_DIR/subs_for_screenshot_${safe}_${ts}.txt"
    OUTPUT_FILE="$RESULTS_DIR/screenshot_${safe}_${ts}.txt"
    SCAN_LABEL="Screenshot Capture"

    eval "$HARVESTER_CMD -d $TARGET -b crtsh,dnsdumpster,hackertarget $LIMIT_OPT" 2>&1 | \
        grep -iE "\.$TARGET|^$TARGET" | sort -u > "$sub_file"

    local sub_count; sub_count=$(wc -l < "$sub_file")
    echo -e "  ${GREEN}[✓] $sub_count subdomains পাওয়া গেছে।${NC}"

    if [ "$sub_count" -gt 0 ] && command -v httpx &>/dev/null; then
        echo ""
        echo -e "${CYAN}[*] HTTPx দিয়ে live hosts filter করা হচ্ছে...${NC}"
        httpx -l "$sub_file" -silent -o "$OUTPUT_FILE" 2>/dev/null
        echo -e "  ${GREEN}[✓] Live hosts: $(wc -l < "$OUTPUT_FILE")${NC}"

        if command -v gowitness &>/dev/null; then
            echo -e "${CYAN}[*] GoWitness দিয়ে screenshot নেওয়া হচ্ছে...${NC}"
            local ss_dir="$RESULTS_DIR/screenshots_${safe}_${ts}"
            mkdir -p "$ss_dir"
            gowitness file -f "$OUTPUT_FILE" -P "$ss_dir" 2>/dev/null
            echo -e "  ${GREEN}[✓] Screenshots: $ss_dir${NC}"
        else
            echo -e "  ${YELLOW}[!] gowitness নেই — install: go install github.com/sensepost/gowitness@latest${NC}"
        fi
    else
        echo -e "  ${YELLOW}[!] httpx নেই বা কোনো subdomain পাওয়া যায়নি।${NC}"
        cat "$sub_file"
    fi

    save_results "$sub_file"
}

# ================================================================
# MODE 18 — EMAIL FILTER
# ================================================================
mode_email_filter() {
    read -p "$(echo -e ${WHITE}"Existing output file path: "${NC})" infile
    [ ! -f "$infile" ] && echo -e "${RED}[!] File নেই।${NC}" && return

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/emails_filtered_${ts}.txt"
    SCAN_LABEL="Email Filter"

    grep -oiE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$infile" | \
        sort -u | tee "$OUTPUT_FILE"

    local count; count=$(wc -l < "$OUTPUT_FILE")
    echo ""
    echo -e "${GREEN}[✓] $count unique emails → $OUTPUT_FILE${NC}"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 19 — SUBDOMAIN FILTER
# ================================================================
mode_subdomain_filter() {
    read -p "$(echo -e ${WHITE}"Existing output file path: "${NC})" infile
    [ ! -f "$infile" ] && echo -e "${RED}[!] File নেই।${NC}" && return

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/subdomains_filtered_${ts}.txt"
    SCAN_LABEL="Subdomain Filter"

    grep -iE "\.$TARGET|^$TARGET" "$infile" | sort -u | tee "$OUTPUT_FILE"

    local count; count=$(wc -l < "$OUTPUT_FILE")
    echo ""
    echo -e "${GREEN}[✓] $count subdomains → $OUTPUT_FILE${NC}"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 20 — IP FILTER
# ================================================================
mode_ip_filter() {
    read -p "$(echo -e ${WHITE}"Existing output file path: "${NC})" infile
    [ ! -f "$infile" ] && echo -e "${RED}[!] File নেই।${NC}" && return

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="$RESULTS_DIR/ips_filtered_${ts}.txt"
    SCAN_LABEL="IP Filter"

    grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" "$infile" | sort -u | tee "$OUTPUT_FILE"

    local count; count=$(wc -l < "$OUTPUT_FILE")
    echo ""
    echo -e "${GREEN}[✓] $count IPs → $OUTPUT_FILE${NC}"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 21 — XML EXPORT
# ================================================================
mode_xml_export() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's/[^a-zA-Z0-9._-]/_/g')
    local xml_base="$RESULTS_DIR/xml_report_${safe}_${ts}"
    OUTPUT_FILE="${xml_base}.xml"
    SCAN_LABEL="XML Export"

    echo ""
    echo -e "${GREEN}[*] XML report generate করা হচ্ছে...${NC}"

    eval "$HARVESTER_CMD -d $TARGET -b bing,google,crtsh,dnsdumpster $LIMIT_OPT -f $xml_base" 2>&1

    [ -f "$OUTPUT_FILE" ] && \
        echo -e "${GREEN}[✓] XML saved: $OUTPUT_FILE${NC}" || \
        echo -e "${YELLOW}[!] XML output পাওয়া যায়নি।${NC}"

    save_results "${xml_base}.txt"
}

# ================================================================
# MODE 22 — SMART OSINT RECON
# ================================================================
mode_smart_recon() {
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's/[^a-zA-Z0-9._-]/_/g')
    OUTPUT_FILE="$RESULTS_DIR/smart_recon_${safe}_${ts}.txt"
    SCAN_LABEL="Smart OSINT Recon"

    echo ""
    echo -e "${CYAN}${BOLD}Smart OSINT Recon — ৩ ধাপে:${NC}"
    echo -e "  ${WHITE}1: Emails (search engines)${NC}"
    echo -e "  ${WHITE}2: Subdomains (cert + dns)${NC}"
    echo -e "  ${WHITE}3: IPs + Hosts (shodan + hackertarget)${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    {
        echo "Smart OSINT Recon: $TARGET"
        echo "Date: $(date)"
        echo ""
    } > "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 1: Email Harvest ━━━${NC}"
    eval "$HARVESTER_CMD -d $TARGET -b bing,google,yahoo $LIMIT_OPT" 2>&1 | tee -a "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 2: Subdomain Harvest ━━━${NC}"
    eval "$HARVESTER_CMD -d $TARGET -b crtsh,certspotter,dnsdumpster,anubis $LIMIT_OPT" 2>&1 | tee -a "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 3: IP & Host Harvest ━━━${NC}"
    eval "$HARVESTER_CMD -d $TARGET -b hackertarget,urlscan,otx $LIMIT_OPT" 2>&1 | tee -a "$OUTPUT_FILE"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Smart OSINT Recon সম্পন্ন!${NC}"
    bangla_analysis "$OUTPUT_FILE" "$TARGET"
    suggest_next_tool "$OUTPUT_FILE" "$TARGET"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 23 — ALL IN ONE MEGA
# ================================================================
mode_allinone() {
    echo ""
    echo -e "${RED}${BOLD}[!] All-in-One Mega Harvest — সব sources + সব data।${NC}"
    echo -e "${YELLOW}[!] এটি অনেক সময় নিতে পারে।${NC}"
    read -p "$(echo -e ${YELLOW}"[?] শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's/[^a-zA-Z0-9._-]/_/g')
    OUTPUT_FILE="$RESULTS_DIR/mega_harvest_${safe}_${ts}.txt"
    SCAN_LABEL="All-in-One Mega"

    {
        echo "================================================================"
        echo "  theHarvester ALL-IN-ONE MEGA HARVEST — SAIMUM"
        echo "  Target: $TARGET"
        echo "  Date: $(date)"
        echo "================================================================"
        echo ""
    } > "$OUTPUT_FILE"

    local all_sources="bing,google,yahoo,duckduckgo,crtsh,certspotter,dnsdumpster,hackertarget,urlscan,otx,anubis,rapiddns,alienvault,threatcrowd"

    echo -e "${CYAN}━━━ Phase 1: Search Engines ━━━${NC}"
    eval "$HARVESTER_CMD -d $TARGET -b bing,google,yahoo,duckduckgo -l 500" 2>&1 | tee -a "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 2: Certificate Sources ━━━${NC}"
    eval "$HARVESTER_CMD -d $TARGET -b crtsh,certspotter -l 500" 2>&1 | tee -a "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 3: DNS Sources ━━━${NC}"
    eval "$HARVESTER_CMD -d $TARGET -b dnsdumpster,hackertarget,anubis,rapiddns -l 500" 2>&1 | tee -a "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 4: Threat Intel ━━━${NC}"
    eval "$HARVESTER_CMD -d $TARGET -b urlscan,otx,alienvault -l 200" 2>&1 | tee -a "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 5: DNS Brute Force ━━━${NC}"
    eval "$HARVESTER_CMD -d $TARGET -b bing,crtsh -dns-brute -l 200" 2>&1 | tee -a "$OUTPUT_FILE"

    # Summary extraction
    echo ""
    echo -e "${CYAN}━━━ Summary ━━━${NC}"
    local emails; emails=$(grep -oiE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$OUTPUT_FILE" | sort -u | wc -l)
    local subs; subs=$(grep -icE "\.$TARGET" "$OUTPUT_FILE" 2>/dev/null || echo 0)
    local ips; ips=$(grep -ocE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" "$OUTPUT_FILE" 2>/dev/null || echo 0)

    echo -e "  ${WHITE}Emails found   : ${GREEN}$emails${NC}"
    echo -e "  ${WHITE}Subdomains     : ${GREEN}$subs${NC}"
    echo -e "  ${WHITE}IPs            : ${GREEN}$ips${NC}"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] All-in-One Mega Harvest সম্পন্ন!${NC}"
    bangla_analysis "$OUTPUT_FILE" "$TARGET"
    suggest_next_tool "$OUTPUT_FILE" "$TARGET"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# BANGLA ANALYSIS
# ================================================================
bangla_analysis() {
    local outfile=$1 domain=$2

    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় OSINT রিপোর্ট বিশ্লেষণ                         ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    [ ! -f "$outfile" ] && echo -e "  ${YELLOW}[!] Output ফাঁকা।${NC}" && echo "" && return

    # Count findings
    local email_count sub_count ip_count host_count
    email_count=$(grep -oiE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$outfile" 2>/dev/null | sort -u | wc -l)
    sub_count=$(grep -icE "\.$domain" "$outfile" 2>/dev/null || echo 0)
    ip_count=$(grep -ocE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" "$outfile" 2>/dev/null || echo 0)

    echo -e "  ${CYAN}${BOLD}━━━ OSINT Findings Summary ━━━${NC}"
    echo -e "  ${GREEN}   Emails found    : $email_count${NC}"
    echo -e "  ${CYAN}   Subdomains      : $sub_count${NC}"
    echo -e "  ${BLUE}   IP Addresses    : $ip_count${NC}"
    echo ""

    local critical=0 high=0 medium=0

    # Emails found
    if [ "$email_count" -gt 0 ]; then
        medium=$((medium+1))
        echo -e "  ${YELLOW}${BOLD}📧 $email_count টি Email পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}Top emails:${NC}"
        grep -oiE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$outfile" 2>/dev/null | \
            sort -u | head -5 | while IFS= read -r em; do
                echo -e "     ${YELLOW}▸ $em${NC}"
            done
        echo -e "     ${WHITE}→ Phishing, credential stuffing বা password reset attack এ ব্যবহার হতে পারে।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # Subdomains found
    if [ "$sub_count" -gt 0 ]; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}🌐 $sub_count টি Subdomain পাওয়া গেছে!${NC}"
        grep -iE "\.$domain" "$outfile" 2>/dev/null | sort -u | head -8 | \
            while IFS= read -r sub; do echo -e "     ${CYAN}▸ $sub${NC}"; done
        echo -e "     ${WHITE}→ Dev/staging subdomains vulnerable হতে পারে।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # Dev/staging subdomains
    if grep -qiE "dev\.|staging\.|test\.|beta\.|uat\." "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${RED}${BOLD}⚠ Dev/Staging Subdomain পাওয়া গেছে!${NC}"
        grep -iE "dev\.|staging\.|test\.|beta\.|uat\." "$outfile" 2>/dev/null | head -5 | \
            while IFS= read -r s; do echo -e "  ${RED}▸ $s${NC}"; done
        echo -e "     ${WHITE}→ Development servers এ weak auth বা debug mode থাকতে পারে।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Admin subdomains
    if grep -qiE "admin\.|portal\.|vpn\.|mail\.|webmail\." "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${RED}${BOLD}🔑 Sensitive Subdomain পাওয়া গেছে!${NC}"
        grep -iE "admin\.|portal\.|vpn\.|mail\.|webmail\." "$outfile" 2>/dev/null | head -5 | \
            while IFS= read -r s; do echo -e "  ${RED}▸ $s${NC}"; done
        echo -e "     ${WHITE}→ Admin/VPN/Mail panel — brute force বা default cred attack সম্ভব।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Many IPs
    if [ "$ip_count" -gt 10 ]; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}🖥️  $ip_count+ IP Addresses Found${NC}"
        echo -e "     ${WHITE}→ বড় attack surface — প্রতিটি IP scan করুন।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # Corporate emails
    if grep -qiE "@$domain" "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${YELLOW}${BOLD}👤 Corporate Emails Found!${NC}"
        local corp_emails; corp_emails=$(grep -oiE "[a-zA-Z0-9._%+-]+@$domain" "$outfile" | sort -u | head -5)
        echo "$corp_emails" | while IFS= read -r em; do echo -e "  ${YELLOW}▸ $em${NC}"; done
        echo -e "     ${WHITE}→ Employee email format জানা গেছে — spear phishing possible।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # Risk summary
    echo -e "  ${CYAN}${BOLD}━━━ সামগ্রিক ঝুঁকি মূল্যায়ন ━━━${NC}"
    echo -e "  ${RED}   Critical : $critical টি${NC}"
    echo -e "  ${YELLOW}   High     : $high টি${NC}"
    echo -e "  ${CYAN}   Medium   : $medium টি${NC}"
    echo ""

    if   [ "$critical" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}  সার্বিক ঝুঁকি : ██████████ CRITICAL${NC}"
    elif [ "$high" -gt 0 ]; then
        echo -e "  ${YELLOW}${BOLD}  সার্বিক ঝুঁকি : ███████░░░ HIGH — sensitive assets exposed।${NC}"
    elif [ "$medium" -gt 0 ]; then
        echo -e "  ${CYAN}  সার্বিক ঝুঁকি : █████░░░░░ MEDIUM — OSINT data collected।${NC}"
    else
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW — সীমিত public data।${NC}"
    fi
    echo ""
}

# ================================================================
# NEXT TOOL SUGGESTION
# ================================================================
suggest_next_tool() {
    local outfile=$1 domain=$2

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Tool এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Subdomains found → further enumeration
    if grep -qiE "\.$domain" "$outfile" 2>/dev/null; then
        echo -e "  ${GREEN}${BOLD}🌐 Subfinder / Amass${NC} — More Subdomain Enumeration"
        echo -e "     ${WHITE}কারণ: Subdomains পাওয়া গেছে → আরো enumerate করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: subfinder -d $domain -o subdomains.txt${NC}"; echo ""

        echo -e "  ${MAGENTA}${BOLD}🔍 Nuclei${NC} — Subdomain Vulnerability Scan"
        echo -e "     ${CYAN}কমান্ড: nuclei -l subdomains.txt -t . -severity medium,high,critical${NC}"; echo ""

        echo -e "  ${CYAN}${BOLD}⚡ HTTPx${NC} — Live Subdomain Check"
        echo -e "     ${CYAN}কমান্ড: cat subdomains.txt | httpx -title -tech-detect -status-code${NC}"; echo ""
    fi

    # Emails found → password attacks
    local email_count; email_count=$(grep -oiE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$outfile" 2>/dev/null | sort -u | wc -l)
    if [ "$email_count" -gt 0 ]; then
        echo -e "  ${YELLOW}${BOLD}🔑 Hydra${NC} — Email-based Login Brute Force"
        echo -e "     ${WHITE}কারণ: Corporate emails পাওয়া গেছে।${NC}"
        echo -e "     ${CYAN}কমান্ড: hydra -L emails.txt -P rockyou.txt smtp://$domain${NC}"; echo ""
    fi

    # IPs found → port scan
    local ip_count; ip_count=$(grep -ocE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" "$outfile" 2>/dev/null || echo 0)
    if [ "$ip_count" -gt 0 ]; then
        echo -e "  ${GREEN}${BOLD}🗺️  Nmap${NC} — Port Scan Found IPs"
        echo -e "     ${CYAN}কমান্ড: nmap -iL ips.txt -F -T4${NC}"; echo ""

        echo -e "  ${CYAN}${BOLD}🌐 Shodan CLI${NC} — IP Intelligence"
        echo -e "     ${CYAN}কমান্ড: shodan host <ip>${NC}"; echo ""
    fi

    # Dev/staging found
    if grep -qiE "dev\.|staging\.|test\." "$outfile" 2>/dev/null; then
        echo -e "  ${GREEN}${BOLD}🔍 Dirsearch${NC} — Dev Server Directory Scan"
        echo -e "     ${CYAN}কমান্ড: dirsearch -u http://dev.$domain -e php,html,js,txt${NC}"; echo ""
    fi

    echo -e "  ${BLUE}${BOLD}🌐 WhatWeb${NC} — Technology Fingerprinting"
    echo -e "     ${CYAN}কমান্ড: whatweb http://$domain -a 3${NC}"; echo ""

    echo -e "  ${WHITE}${BOLD}🌐 Nikto${NC} — Web Vulnerability Scan"
    echo -e "     ${CYAN}কমান্ড: nikto -h http://$domain${NC}"; echo ""
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

        read -p "$(echo -e ${YELLOW}"[?] Scan option [0-23]: "${NC})" choice

        [[ "$choice" == "0" ]] && {
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            exit 0
        }

        case $choice in
            1)  mode_quick ;;
            2)  mode_full ;;
            3)  mode_email_harvest ;;
            4)  mode_subdomain_harvest ;;
            5)  mode_ip_harvest ;;
            6)  mode_search_engines ;;
            7)  mode_cert_transparency ;;
            8)  mode_dns_sources ;;
            9)  mode_threat_intel ;;
            10) mode_shodan_source ;;
            11) mode_hunter_io ;;
            12) mode_custom_source ;;
            13) mode_dns_brute ;;
            14) mode_vhost ;;
            15) mode_multiple_domains ;;
            16) mode_deep_scan ;;
            17) mode_screenshot ;;
            18) mode_email_filter ;;
            19) mode_subdomain_filter ;;
            20) mode_ip_filter ;;
            21) mode_xml_export ;;
            22) mode_smart_recon ;;
            23) mode_allinone ;;
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
