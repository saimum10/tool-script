#!/bin/bash

# ================================================================
#   NETWORK MAPPER - Full Automation Tool
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

RESULTS_DIR="$HOME/nmap_results"
HISTORY_FILE="$HOME/.nmap_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo ' ███╗   ██╗███████╗████████╗██╗    ██╗ ██████╗ ██████╗ ██╗  ██╗'
    echo ' ████╗  ██║██╔════╝╚══██╔══╝██║    ██║██╔═══██╗██╔══██╗██║ ██╔╝'
    echo ' ██╔██╗ ██║█████╗     ██║   ██║ █╗ ██║██║   ██║██████╔╝█████╔╝ '
    echo ' ██║╚██╗██║██╔══╝     ██║   ██║███╗██║██║   ██║██╔══██╗██╔═██╗ '
    echo ' ██║ ╚████║███████╗   ██║   ╚███╔███╔╝╚██████╔╝██║  ██║██║  ██╗'
    echo ' ╚═╝  ╚═══╝╚══════╝   ╚═╝    ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝'
    echo ''
    echo '  ███╗   ███╗ █████╗ ██████╗ ██████╗ ███████╗██████╗ '
    echo '  ████╗ ████║██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗'
    echo '  ██╔████╔██║███████║██████╔╝██████╔╝█████╗  ██████╔╝'
    echo '  ██║╚██╔╝██║██╔══██║██╔═══╝ ██╔═══╝ ██╔══╝  ██╔══██╗'
    echo '  ██║ ╚═╝ ██║██║  ██║██║     ██║     ███████╗██║  ██║'
    echo '  ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝     ╚══════╝╚═╝  ╚═╝'
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}           Nmap Full Automation Tool | Network Recon${NC}"
    echo ""
}

# ================================================================
# CHECK DEPENDENCIES
# ================================================================
check_deps() {
    echo -e "${CYAN}[*] Dependencies চেক করা হচ্ছে...${NC}"
    local missing=()
    for tool in nmap whois curl dig host; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
        else
            echo -e "  ${GREEN}[✓] $tool${NC}"
        fi
    done
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}[!] Missing tools: ${missing[*]}${NC}"
        echo -e "${YELLOW}[*] Install করুন: sudo apt install ${missing[*]}${NC}"
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
    echo -e "  ${GREEN}1)${NC} Single IP / Domain"
    echo -e "  ${GREEN}2)${NC} Multiple IPs / Domains (একটা একটা করে)"
    echo -e "  ${GREEN}3)${NC} IP Range  (e.g. 192.168.1.1-50)"
    echo -e "  ${GREEN}4)${NC} CIDR Subnet (e.g. 192.168.1.0/24)"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-4]: "${NC})" ttype

    case $ttype in
        1)
            read -p "$(echo -e ${WHITE}"IP অথবা Domain দিন: "${NC})" t
            TARGETS=("$t")
            ;;
        2)
            echo -e "${WHITE}একটা একটা করে দিন। শেষ হলে 'done' লিখুন:${NC}"
            while true; do
                read -p "$(echo -e ${WHITE}"Target: "${NC})" t
                [[ "$t" == "done" || -z "$t" ]] && break
                TARGETS+=("$t")
            done
            ;;
        3)
            read -p "$(echo -e ${WHITE}"Range দিন (e.g. 192.168.1.1-50): "${NC})" t
            TARGETS=("$t")
            ;;
        4)
            read -p "$(echo -e ${WHITE}"CIDR দিন (e.g. 192.168.1.0/24): "${NC})" t
            TARGETS=("$t")
            ;;
        *)
            echo -e "${RED}[!] ভুল অপশন, আবার চেষ্টা করুন।${NC}"
            get_targets
            return
            ;;
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
    local target=$1
    echo -e "${MAGENTA}${BOLD}┌─── WHOIS INFORMATION ─────────────────────────────┐${NC}"
    local result
    result=$(whois "$target" 2>/dev/null | grep -E \
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
    echo -e "${BLUE}${BOLD}┌─── GEO IP INFORMATION ────────────────────────────┐${NC}"
    local geo
    geo=$(curl -s --max-time 5 "http://ip-api.com/json/$target" 2>/dev/null)

    if echo "$geo" | grep -q '"status":"success"'; then
        local country region city isp lat lon
        country=$(echo "$geo" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        region=$(echo  "$geo" | grep -o '"regionName":"[^"]*"' | cut -d'"' -f4)
        city=$(echo    "$geo" | grep -o '"city":"[^"]*"'       | cut -d'"' -f4)
        isp=$(echo     "$geo" | grep -o '"isp":"[^"]*"'        | cut -d'"' -f4)
        lat=$(echo     "$geo" | grep -o '"lat":[^,]*'           | cut -d':' -f2)
        lon=$(echo     "$geo" | grep -o '"lon":[^,]*'           | cut -d':' -f2)

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
    echo -e "${GREEN}${BOLD}┌─── REVERSE DNS LOOKUP ────────────────────────────┐${NC}"
    local result
    result=$(dig -x "$target" +short 2>/dev/null)
    if [ -z "$result" ]; then
        result=$(host "$target" 2>/dev/null | grep "domain name pointer" | awk '{print $NF}')
    fi
    if [ -n "$result" ]; then
        echo -e "  ${WHITE}Hostname  :${NC} ${GREEN}$result${NC}"
    else
        echo -e "  ${YELLOW}[!] কোনো Reverse DNS রেকর্ড পাওয়া যায়নি।${NC}"
    fi
    echo -e "${GREEN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
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
    whois_lookup "$target"
    geoip_lookup  "$target"
    reverse_dns   "$target"
}

# ================================================================
# SCAN MENU
# ================================================================
show_menu() {
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║                      NMAP SCAN OPTIONS                              ║${NC}"
    echo -e "${YELLOW}${BOLD}╠═══╦══════════════════════════════╦═══════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${WHITE}#${NC} ${YELLOW}║${NC} ${WHITE}Scan Type${NC}                     ${YELLOW}║${NC} ${WHITE}Command${NC}                           ${YELLOW}║${NC}"
    echo -e "${YELLOW}${BOLD}╠═══╬══════════════════════════════╬═══════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}1${NC} ${YELLOW}║${NC} Quick Scan (100 ports)        ${YELLOW}║${NC} ${CYAN}nmap -F <target>${NC}                   ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}2${NC} ${YELLOW}║${NC} All Ports Scan               ${YELLOW}║${NC} ${CYAN}nmap -p- <target>${NC}                  ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}3${NC} ${YELLOW}║${NC} Service Version Detection    ${YELLOW}║${NC} ${CYAN}nmap -sV <target>${NC}                  ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}4${NC} ${YELLOW}║${NC} OS Detection                 ${YELLOW}║${NC} ${CYAN}nmap -O <target>${NC}                   ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}5${NC} ${YELLOW}║${NC} OS + Service (Combined)      ${YELLOW}║${NC} ${CYAN}nmap -A <target>${NC}                   ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}6${NC} ${YELLOW}║${NC} SYN Stealth Scan             ${YELLOW}║${NC} ${CYAN}nmap -sS <target>${NC}                  ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}7${NC} ${YELLOW}║${NC} UDP Scan                     ${YELLOW}║${NC} ${CYAN}nmap -sU <target>${NC}                  ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}8${NC} ${YELLOW}║${NC} Ping / Host Discovery        ${YELLOW}║${NC} ${CYAN}nmap -sn <target>${NC}                  ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}9${NC} ${YELLOW}║${NC} Vulnerability Scan           ${YELLOW}║${NC} ${CYAN}nmap --script vuln <target>${NC}        ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}10${NC} ${YELLOW}║${NC} Default NSE Scripts          ${YELLOW}║${NC} ${CYAN}nmap -sC <target>${NC}                  ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}11${NC} ${YELLOW}║${NC} Aggressive Scan              ${YELLOW}║${NC} ${CYAN}nmap -A -T4 <target>${NC}               ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}12${NC} ${YELLOW}║${NC} Firewall Evasion Scan        ${YELLOW}║${NC} ${CYAN}nmap -f <target>${NC}                   ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}13${NC} ${YELLOW}║${NC} Decoy Scan                   ${YELLOW}║${NC} ${CYAN}nmap -D RND:5 <target>${NC}             ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}14${NC} ${YELLOW}║${NC} HTTP Directory Enum          ${YELLOW}║${NC} ${CYAN}nmap --script http-enum <target>${NC}   ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}15${NC} ${YELLOW}║${NC} SMB Vulnerability Scan       ${YELLOW}║${NC} ${CYAN}nmap --script smb-vuln-* <target>${NC}  ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}16${NC} ${YELLOW}║${NC} FTP Anonymous Check          ${YELLOW}║${NC} ${CYAN}nmap --script ftp-anon <target>${NC}    ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}17${NC} ${YELLOW}║${NC} DNS Brute Enumeration        ${YELLOW}║${NC} ${CYAN}nmap --script dns-brute <target>${NC}   ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}18${NC} ${YELLOW}║${NC} SSL/TLS Cipher Check         ${YELLOW}║${NC} ${CYAN}nmap --script ssl-enum-ciphers${NC}     ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}19${NC} ${YELLOW}║${NC} Custom Port Range            ${YELLOW}║${NC} ${CYAN}nmap -p <range> <target>${NC}           ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}20${NC} ${YELLOW}║${NC} Full Recon (সব একসাথে)      ${YELLOW}║${NC} ${CYAN}nmap -A -sV --script vuln${NC}          ${YELLOW}║${NC}"
    echo -e "${YELLOW}${BOLD}╠═══╩══════════════════════════════╩═══════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${RED}0)${NC} Exit                                                               ${YELLOW}║${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
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

    local open_ports
    open_ports=$(grep -E "^[0-9]+/(tcp|udp)\s+open" "$outfile" 2>/dev/null)

    if [ -z "$open_ports" ]; then
        echo -e "  ${YELLOW}[!] কোনো খোলা পোর্ট পাওয়া যায়নি।${NC}"
    else
        echo -e "  ${CYAN}${BOLD}━━━ খোলা পোর্টের বিস্তারিত বিশ্লেষণ ━━━${NC}"
        echo ""

        while IFS= read -r line; do
            local port service
            port=$(echo "$line"    | awk '{print $1}' | cut -d'/' -f1)
            service=$(echo "$line" | awk '{print $3}')

            echo -e "  ${GREEN}▸ পোর্ট ${BOLD}$port${NC} ${GREEN}[ $service ]${NC}"

            case $port in
                21)
                    echo -e "    ${WHITE}📌 এখানে FTP (File Transfer Protocol) সার্ভার চলছে।${NC}"
                    echo -e "    ${WHITE}   ফাইল upload/download করার কাজে ব্যবহার হয়।${NC}"
                    echo -e "    ${RED}   ⚠ ঝুঁকি: Anonymous FTP login সম্ভব হতে পারে।${NC}"
                    echo -e "    ${RED}   ⚠ সব data plaintext এ যায়, sniff করা সম্ভব।${NC}"
                    ;;
                22)
                    echo -e "    ${WHITE}📌 এখানে SSH (Secure Shell) চলছে।${NC}"
                    echo -e "    ${WHITE}   Remote login এবং encrypted file transfer হয়।${NC}"
                    echo -e "    ${YELLOW}   ⚠ ঝুঁকি: Brute force attack এর সম্ভাবনা আছে।${NC}"
                    echo -e "    ${YELLOW}   ⚠ Default password বা weak password থাকলে বিপজ্জনক।${NC}"
                    ;;
                23)
                    echo -e "    ${WHITE}📌 এখানে Telnet চলছে।${NC}"
                    echo -e "    ${RED}   ⚠ ঝুঁকি: খুবই পুরনো ও অনিরাপদ। সব data plaintext এ যায়।${NC}"
                    echo -e "    ${RED}   ⚠ এই পোর্ট open থাকা মানে বড় নিরাপত্তা ত্রুটি।${NC}"
                    ;;
                25)
                    echo -e "    ${WHITE}📌 SMTP Mail Server চলছে। Email পাঠানো/গ্রহণ হয়।${NC}"
                    echo -e "    ${YELLOW}   ⚠ ঝুঁকি: Open relay থাকলে spam পাঠানো সম্ভব।${NC}"
                    ;;
                53)
                    echo -e "    ${WHITE}📌 DNS Server চলছে। Domain name resolve করে।${NC}"
                    echo -e "    ${YELLOW}   ⚠ ঝুঁকি: Zone transfer leak বা DNS cache poisoning সম্ভব।${NC}"
                    ;;
                80)
                    echo -e "    ${WHITE}📌 HTTP Web Server চলছে। Website এখানে serve হচ্ছে।${NC}"
                    echo -e "    ${YELLOW}   ⚠ ঝুঁকি: XSS, SQL Injection, Directory Traversal সম্ভব।${NC}"
                    echo -e "    ${CYAN}   💡 Nikto বা Gobuster দিয়ে আরো গভীরে scan করুন।${NC}"
                    ;;
                443)
                    echo -e "    ${WHITE}📌 HTTPS Web Server চলছে। SSL/TLS দিয়ে encrypted।${NC}"
                    echo -e "    ${YELLOW}   ⚠ ঝুঁকি: SSL misconfiguration বা weak cipher থাকতে পারে।${NC}"
                    echo -e "    ${CYAN}   💡 ssl-enum-ciphers script দিয়ে SSL check করুন।${NC}"
                    ;;
                445)
                    echo -e "    ${WHITE}📌 SMB (Windows File Sharing) চলছে।${NC}"
                    echo -e "    ${RED}   ⚠ ঝুঁকি: EternalBlue (MS17-010) - WannaCry এর মাধ্যমে attack সম্ভব!${NC}"
                    echo -e "    ${RED}   ⚠ এটি অত্যন্ত বিপজ্জনক port। এখনই patch করুন।${NC}"
                    ;;
                3306)
                    echo -e "    ${WHITE}📌 MySQL Database Server সরাসরি open।${NC}"
                    echo -e "    ${RED}   ⚠ ঝুঁকি: Database internet এ expose! Data চুরির ঝুঁকি।${NC}"
                    echo -e "    ${RED}   ⚠ কখনোই MySQL কে publicly open রাখা উচিত না।${NC}"
                    ;;
                3389)
                    echo -e "    ${WHITE}📌 RDP (Remote Desktop Protocol) চলছে।${NC}"
                    echo -e "    ${RED}   ⚠ ঝুঁকি: Brute force, BlueKeep vulnerability সম্ভব।${NC}"
                    echo -e "    ${RED}   ⚠ এই port internet এ open রাখা অত্যন্ত বিপজ্জনক।${NC}"
                    ;;
                8080|8443|8888)
                    echo -e "    ${WHITE}📌 Alternative Web Server / Admin Panel চলছে।${NC}"
                    echo -e "    ${YELLOW}   ⚠ ঝুঁকি: Development server বা admin panel expose হতে পারে।${NC}"
                    ;;
                139)
                    echo -e "    ${WHITE}📌 NetBIOS / SMB চলছে।${NC}"
                    echo -e "    ${YELLOW}   ⚠ ঝুঁকি: Windows network share enumeration সম্ভব।${NC}"
                    ;;
                110)
                    echo -e "    ${WHITE}📌 POP3 Mail Server চলছে।${NC}"
                    echo -e "    ${YELLOW}   ⚠ ঝুঁকি: Plaintext password transmission।${NC}"
                    ;;
                *)
                    echo -e "    ${WHITE}📌 Service: $service চলছে এই পোর্টে।${NC}"
                    echo -e "    ${YELLOW}   ⚠ এই সার্ভিসের vulnerability আলাদাভাবে check করুন।${NC}"
                    ;;
            esac
            echo ""
        done <<< "$open_ports"

        # Overall risk level
        local total
        total=$(echo "$open_ports" | wc -l)
        local critical
        critical=$(echo "$open_ports" | grep -cE "^(21|23|445|3389|3306)/" 2>/dev/null || true)
        local high
        high=$(echo "$open_ports" | grep -cE "^(22|25|80|443|8080)/" 2>/dev/null || true)

        echo -e "  ${CYAN}${BOLD}━━━ সামগ্রিক ঝুঁকি মূল্যায়ন ━━━${NC}"
        echo -e "  ${WHITE}মোট খোলা পোর্ট : ${GREEN}$total${NC}"

        if [ "$critical" -gt 0 ] 2>/dev/null; then
            echo -e "  ${RED}${BOLD}  ঝুঁকির মাত্রা : ██████████ CRITICAL — এখনই পদক্ষেপ নিন!${NC}"
        elif [ "$high" -gt 0 ] 2>/dev/null; then
            echo -e "  ${YELLOW}${BOLD}  ঝুঁকির মাত্রা : ███████░░░ HIGH — দ্রুত মনোযোগ দেওয়া দরকার।${NC}"
        elif [ "$total" -gt 5 ] 2>/dev/null; then
            echo -e "  ${YELLOW}  ঝুঁকির মাত্রা : █████░░░░░ MEDIUM — কিছু port বন্ধ করা উচিত।${NC}"
        else
            echo -e "  ${GREEN}  ঝুঁকির মাত্রা : ███░░░░░░░ LOW — তবু সতর্ক থাকুন।${NC}"
        fi
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

    local found=0

    if grep -qE "^(80|443|8080|8443)/tcp.*open" "$outfile" 2>/dev/null; then
        found=1
        echo -e "  ${GREEN}${BOLD}🌐 Nikto${NC} — Web Server Vulnerability Scanner"
        echo -e "     ${WHITE}কারণ: Port 80/443 খোলা → web application এ vulnerability থাকতে পারে।${NC}"
        echo -e "     ${CYAN}কমান্ড: nikto -h <target>${NC}"
        echo ""
        echo -e "  ${GREEN}${BOLD}🔍 Gobuster${NC} — Directory & File Brute Force"
        echo -e "     ${WHITE}কারণ: Web server আছে → hidden files/directories খুঁজে বের করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: gobuster dir -u http://<target> -w /usr/share/wordlists/dirb/common.txt${NC}"
        echo ""
    fi

    if grep -qE "^22/tcp.*open" "$outfile" 2>/dev/null; then
        found=1
        echo -e "  ${GREEN}${BOLD}🔑 Hydra${NC} — SSH Brute Force"
        echo -e "     ${WHITE}কারণ: SSH port 22 খোলা → weak password আছে কিনা test করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: hydra -L users.txt -P passwords.txt ssh://<target>${NC}"
        echo ""
    fi

    if grep -qE "^21/tcp.*open" "$outfile" 2>/dev/null; then
        found=1
        echo -e "  ${GREEN}${BOLD}📂 FTP Anonymous Test${NC} — Anonymous Login Check"
        echo -e "     ${WHITE}কারণ: FTP port 21 খোলা → anonymous access আছে কিনা দেখুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: nmap --script ftp-anon -p 21 <target>${NC}"
        echo ""
    fi

    if grep -qE "^(445|139)/tcp.*open" "$outfile" 2>/dev/null; then
        found=1
        echo -e "  ${GREEN}${BOLD}💀 enum4linux${NC} — SMB / Windows Enumeration"
        echo -e "     ${WHITE}কারণ: SMB port খোলা → users, shares, policies বের করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: enum4linux -a <target>${NC}"
        echo ""
        echo -e "  ${GREEN}${BOLD}💣 Metasploit${NC} — EternalBlue Exploit Check"
        echo -e "     ${WHITE}কারণ: SMB open → MS17-010 (WannaCry) check করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: msfconsole → use exploit/windows/smb/ms17_010_eternalblue${NC}"
        echo ""
    fi

    if grep -qE "^3306/tcp.*open" "$outfile" 2>/dev/null; then
        found=1
        echo -e "  ${GREEN}${BOLD}🗄️  Hydra / MySQL${NC} — Database Brute Force"
        echo -e "     ${WHITE}কারণ: MySQL publicly open! → access test করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: hydra -l root -P passwords.txt mysql://<target>${NC}"
        echo ""
    fi

    if grep -qE "^53/(tcp|udp).*open" "$outfile" 2>/dev/null; then
        found=1
        echo -e "  ${GREEN}${BOLD}🌍 DNSRecon / dig${NC} — DNS Enumeration"
        echo -e "     ${WHITE}কারণ: DNS port খোলা → zone transfer বা subdomain বের করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: dnsrecon -d <domain> -t axfr${NC}"
        echo ""
    fi

    if [ "$found" -eq 0 ]; then
        echo -e "  ${YELLOW}কোনো specific suggestion নেই।${NC}"
        echo -e "  ${CYAN}General scan: nmap --script vuln <target>${NC}"
        echo ""
    fi
}

# ================================================================
# SAVE RESULTS
# ================================================================
save_results() {
    local target=$1
    local scan_out=$2
    local bangla_out=$3

    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Result save করবেন? (y/n): "${NC})" sc
    if [[ "$sc" =~ ^[Yy]$ ]]; then
        local ts
        ts=$(date +"%Y%m%d_%H%M%S")
        local safe
        safe=$(echo "$target" | sed 's/[^a-zA-Z0-9._-]/_/g')
        local fname="$RESULTS_DIR/scan_${safe}_${ts}.txt"

        {
            echo "============================================================"
            echo "  NMAP SCAN RESULTS  —  SAIMUM's Network Mapper Tool"
            echo "  Target : $target"
            echo "  Date   : $(date)"
            echo "============================================================"
            echo ""
            echo "=== NMAP RAW OUTPUT ==="
            cat "$scan_out"
            echo ""
            echo "=== BANGLA ANALYSIS ==="
            # Strip ANSI color codes for clean file output
            sed 's/\x1b\[[0-9;]*m//g' "$bangla_out"
        } > "$fname"

        echo -e "${GREEN}[✓] Saved → $fname${NC}"
        echo "$(date) | $target | $fname" >> "$HISTORY_FILE"
    fi
}

# ================================================================
# RUN SCAN
# ================================================================
run_scan() {
    local choice=$1
    local target=$2
    local cmd="" scan_type="" needs_root=0

    case $choice in
        1)  cmd="nmap -F";                         scan_type="Quick Scan" ;;
        2)  cmd="nmap -p-";                        scan_type="All Ports Scan" ;;
        3)  cmd="nmap -sV";                        scan_type="Service Version Detection" ;;
        4)  cmd="nmap -O";                         scan_type="OS Detection";          needs_root=1 ;;
        5)  cmd="nmap -A";                         scan_type="OS + Service (Combined)" ;;
        6)  cmd="nmap -sS";                        scan_type="SYN Stealth Scan";      needs_root=1 ;;
        7)  cmd="nmap -sU";                        scan_type="UDP Scan";              needs_root=1 ;;
        8)  cmd="nmap -sn";                        scan_type="Ping / Host Discovery" ;;
        9)  cmd="nmap --script vuln";              scan_type="Vulnerability Scan" ;;
        10) cmd="nmap -sC";                        scan_type="Default NSE Scripts" ;;
        11) cmd="nmap -A -T4";                     scan_type="Aggressive Scan"
            echo -e "${RED}[!] Warning: এই scan টা সহজেই IDS/IPS detect করতে পারে!${NC}" ;;
        12) cmd="nmap -f";                         scan_type="Firewall Evasion" ;;
        13) cmd="nmap -D RND:5";                   scan_type="Decoy Scan" ;;
        14) cmd="nmap --script http-enum -p 80,443,8080,8443"; scan_type="HTTP Enum" ;;
        15) cmd="nmap --script 'smb-vuln-*' -p 445,139"; scan_type="SMB Vuln Scan" ;;
        16) cmd="nmap --script ftp-anon -p 21";   scan_type="FTP Anonymous Check" ;;
        17) cmd="nmap --script dns-brute";         scan_type="DNS Brute Enumeration" ;;
        18) cmd="nmap --script ssl-enum-ciphers -p 443,8443"; scan_type="SSL/TLS Check" ;;
        19)
            read -p "$(echo -e ${WHITE}"Port range দিন (e.g. 80,443 বা 1-1000): "${NC})" ports
            cmd="nmap -p $ports"; scan_type="Custom Port Scan" ;;
        20) cmd="nmap -A -sV --script vuln";       scan_type="Full Recon (সব একসাথে)"
            echo -e "${YELLOW}[!] এই scan অনেক সময় নিতে পারে, ধৈর্য রাখুন...${NC}" ;;
        *)  echo -e "${RED}[!] Invalid option.${NC}"; return ;;
    esac

    # Root warning
    if [ "$needs_root" -eq 1 ] && [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}[!] এই scan টি root/sudo দরকার। 'sudo ./nmap_saimum.sh' দিয়ে চালান।${NC}"
        read -p "$(echo -e ${YELLOW}"তবুও চালাবেন? (y/n): "${NC})" rc
        [[ ! "$rc" =~ ^[Yy]$ ]] && return
    fi

    # Show command preview
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}Scan Type : ${YELLOW}${BOLD}$scan_type${NC}"
    echo -e "  ${WHITE}Target    : ${GREEN}${BOLD}$target${NC}"
    echo -e "  ${WHITE}Command   : ${CYAN}$cmd $target${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] Scan শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    # Temp files
    local tmp_scan tmp_bangla
    tmp_scan=$(mktemp)
    tmp_bangla=$(mktemp)

    echo ""
    echo -e "${GREEN}${BOLD}[*] Scan শুরু হচ্ছে...${NC}"
    echo ""

    # Run REAL nmap — output shows exactly as normal nmap does
    $cmd "$target" 2>&1 | tee "$tmp_scan"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Scan সম্পন্ন!${NC}"

    # Bangla analysis
    bangla_analysis "$tmp_scan" "$tmp_bangla"

    # Next tool suggestions
    suggest_next_tool "$tmp_scan"

    # Save
    save_results "$target" "$tmp_scan" "$tmp_bangla"

    rm -f "$tmp_scan" "$tmp_bangla"
}

# ================================================================
# MAIN LOOP
# ================================================================
main() {
    show_banner
    check_deps

    while true; do
        get_targets

        # Pre-scan recon for all targets
        for t in "${TARGETS[@]}"; do
            pre_scan_recon "$t"
        done

        show_menu
        read -p "$(echo -e ${YELLOW}"[?] Scan option select করুন [0-20]: "${NC})" choice

        if [[ "$choice" == "0" ]]; then
            echo ""
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            echo ""
            exit 0
        fi

        # Run scan for each target
        for t in "${TARGETS[@]}"; do
            echo ""
            echo -e "${CYAN}${BOLD}══════════════ Target: $t ══════════════${NC}"
            run_scan "$choice" "$t"
        done

        echo ""
        read -p "$(echo -e ${YELLOW}"[?] আরেকটি scan করবেন? (y/n): "${NC})" again
        [[ ! "$again" =~ ^[Yy]$ ]] && { echo -e "${GREEN}${BOLD} Goodbye! Stay legal! 🛡️${NC}"; exit 0; }

        show_banner
    done
}

main
