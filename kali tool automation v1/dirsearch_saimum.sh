#!/bin/bash

# ================================================================
#   DIRSEARCH - Full Automation Tool
#   Author: SAIMUM
# ================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
WHITE='\033[1;37m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

RESULTS_DIR="$HOME/dirsearch_results"
HISTORY_FILE="$HOME/.dirsearch_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo ' ██████╗ ██╗██████╗ ███████╗███████╗ █████╗ ██████╗  ██████╗██╗  ██╗'
    echo ' ██╔══██╗██║██╔══██╗██╔════╝██╔════╝██╔══██╗██╔══██╗██╔════╝██║  ██║'
    echo ' ██║  ██║██║██████╔╝███████╗█████╗  ███████║██████╔╝██║     ███████║'
    echo ' ██║  ██║██║██╔══██╗╚════██║██╔══╝  ██╔══██║██╔══██╗██║     ██╔══██║'
    echo ' ██████╔╝██║██║  ██║███████║███████╗██║  ██║██║  ██║╚██████╗██║  ██║'
    echo ' ╚═════╝ ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝'
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}         Dirsearch Full Automation | Web Path Discovery${NC}"
    echo ""
    echo -e "  ${RED}${BOLD}⚠  Ethics Warning:${NC} ${WHITE}শুধুমাত্র নিজের বা অনুমতি আছে এমন target এ ব্যবহার করুন।${NC}"
    echo ""
}

# ================================================================
# CHECK DEPENDENCIES
# ================================================================
check_deps() {
    echo -e "${CYAN}[*] Dependencies চেক করা হচ্ছে...${NC}"

    DIRSEARCH_CMD=""
    if command -v dirsearch &>/dev/null; then
        DIRSEARCH_CMD="dirsearch"
        echo -e "  ${GREEN}[✓] dirsearch${NC}"
    elif [ -f "$HOME/dirsearch/dirsearch.py" ]; then
        DIRSEARCH_CMD="python3 $HOME/dirsearch/dirsearch.py"
        echo -e "  ${GREEN}[✓] dirsearch.py (~/)${NC}"
    elif [ -f "/opt/dirsearch/dirsearch.py" ]; then
        DIRSEARCH_CMD="python3 /opt/dirsearch/dirsearch.py"
        echo -e "  ${GREEN}[✓] dirsearch.py (/opt/)${NC}"
    else
        echo -e "  ${RED}[✗] dirsearch — পাওয়া যায়নি${NC}"
        echo -e "${YELLOW}Install: sudo apt install dirsearch  অথবা  pip3 install dirsearch${NC}"
        exit 1
    fi

    for tool in curl whois dig python3; do
        command -v "$tool" &>/dev/null && \
            echo -e "  ${GREEN}[✓] $tool${NC}" || \
            echo -e "  ${YELLOW}[!] $tool — নেই${NC}"
    done

    echo ""
    echo -e "${CYAN}[*] Optional tools:${NC}"
    for opt in gobuster ffuf nikto sqlmap nuclei; do
        command -v "$opt" &>/dev/null && \
            echo -e "  ${GREEN}[✓] $opt${NC}" || \
            echo -e "  ${YELLOW}[!] $opt — নেই${NC}"
    done

    echo ""
    echo -e "${CYAN}[*] Wordlists:${NC}"
    DEFAULT_WORDLIST=""
    local wls=(
        "/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
        "/usr/share/wordlists/dirbuster/directory-list-2.3-small.txt"
        "/usr/share/seclists/Discovery/Web-Content/common.txt"
        "/usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt"
    )
    for wl in "${wls[@]}"; do
        if [ -f "$wl" ]; then
            DEFAULT_WORDLIST="$wl"
            echo -e "  ${GREEN}[✓] $wl${NC}"
            break
        fi
    done
    [ -z "$DEFAULT_WORDLIST" ] && echo -e "  ${YELLOW}[!] Default wordlist পাওয়া যায়নি।${NC}"
    echo ""
}

# ================================================================
# GET TARGET
# ================================================================
get_target() {
    TARGET=""; TARGET_LIST=(); TARGET_FILE=""

    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║         TARGET SELECT                ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo -e "  ${GREEN}1)${NC} Single URL"
    echo -e "  ${GREEN}2)${NC} Multiple URLs"
    echo -e "  ${GREEN}3)${NC} File থেকে URL list"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-3]: "${NC})" ttype

    case $ttype in
        1)
            read -p "$(echo -e ${WHITE}"URL দিন: "${NC})" t
            [[ ! "$t" =~ ^https?:// ]] && t="http://$t"
            TARGET="${t%/}"; TARGET_LIST=("$TARGET") ;;
        2)
            echo -e "${WHITE}URLs দিন। 'done' লিখলে শেষ:${NC}"
            while true; do
                read -p "$(echo -e ${WHITE}"URL: "${NC})" t
                [[ "$t" == "done" || -z "$t" ]] && break
                [[ ! "$t" =~ ^https?:// ]] && t="http://$t"
                TARGET_LIST+=("${t%/}")
            done
            TARGET="${TARGET_LIST[0]}" ;;
        3)
            read -p "$(echo -e ${WHITE}"File path: "${NC})" TARGET_FILE
            [ ! -f "$TARGET_FILE" ] && echo -e "${RED}[!] File নেই।${NC}" && get_target && return
            TARGET=$(head -1 "$TARGET_FILE")
            [[ ! "$TARGET" =~ ^https?:// ]] && TARGET="http://$TARGET" ;;
        *) echo -e "${RED}[!] ভুল।${NC}" && get_target && return ;;
    esac

    echo -e "  ${GREEN}[✓] Target: $TARGET${NC}"
    echo ""
}

# ================================================================
# PRE-SCAN RECON
# ================================================================
pre_scan_recon() {
    local url=$1
    local domain; domain=$(echo "$url" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)

    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}   PRE-SCAN RECON  ›  $url${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    echo -e "${MAGENTA}${BOLD}┌─── WHOIS ──────────────────────────────────────────┐${NC}"
    whois "$domain" 2>/dev/null | grep -E "Registrar:|Country:|Organization:|Creation Date:" | head -5 | \
        while IFS= read -r l; do echo -e "  ${WHITE}$l${NC}"; done
    echo -e "${MAGENTA}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${BLUE}${BOLD}┌─── GEO IP ──────────────────────────────────────────┐${NC}"
    local geo; geo=$(curl -s --max-time 5 "http://ip-api.com/json/$domain" 2>/dev/null)
    if echo "$geo" | grep -q '"status":"success"'; then
        local ip country city isp
        ip=$(echo "$geo"      | grep -o '"query":"[^"]*"'      | cut -d'"' -f4)
        country=$(echo "$geo" | grep -o '"country":"[^"]*"'    | cut -d'"' -f4)
        city=$(echo "$geo"    | grep -o '"city":"[^"]*"'       | cut -d'"' -f4)
        isp=$(echo "$geo"     | grep -o '"isp":"[^"]*"'        | cut -d'"' -f4)
        echo -e "  ${WHITE}IP: ${GREEN}$ip${NC}  |  ${WHITE}$country, $city${NC}  |  ${WHITE}$isp${NC}"
    else
        echo -e "  ${YELLOW}[!] GeoIP পাওয়া যায়নি।${NC}"
    fi
    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}┌─── HTTP HEADERS ────────────────────────────────────┐${NC}"
    local headers; headers=$(curl -s -I --max-time 8 "$url" 2>/dev/null | head -25)
    if [ -n "$headers" ]; then
        local code server powered
        code=$(echo "$headers"   | head -1)
        server=$(echo "$headers" | grep -i "^Server:"       | head -1)
        powered=$(echo "$headers"| grep -i "^X-Powered-By:" | head -1)
        echo -e "  ${WHITE}Status: ${GREEN}$code${NC}"
        [ -n "$server"  ] && echo -e "  ${WHITE}Server    : ${YELLOW}$server${NC}"
        [ -n "$powered" ] && echo -e "  ${WHITE}Powered-By: ${YELLOW}$powered${NC}"
        echo ""
        echo -e "  ${CYAN}WAF Detection:${NC}"
        local waf=false
        for wh in "cf-ray" "X-Sucuri-ID" "X-WAF" "X-Firewall" "X-Mod-Security"; do
            echo "$headers" | grep -qi "^$wh:" && echo -e "  ${RED}[!] WAF: $wh${NC}" && waf=true
        done
        $waf || echo -e "  ${GREEN}[✓] স্পষ্ট WAF নেই${NC}"
    fi
    echo -e "${CYAN}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ================================================================
# SCAN MENU
# ================================================================
show_menu() {
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║                   DIRSEARCH SCAN OPTIONS                            ║${NC}"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ BASIC SCANS ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}1${NC}  Quick Scan               — fast, common paths"
    echo -e "${YELLOW}║${NC} ${GREEN}2${NC}  Full Scan                — complete wordlist scan"
    echo -e "${YELLOW}║${NC} ${GREEN}3${NC}  Custom Wordlist Scan     — নিজের wordlist"
    echo -e "${YELLOW}║${NC} ${GREEN}4${NC}  Multiple URL Scan        — একাধিক target"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ EXTENSION-BASED ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}5${NC}  PHP Scan                 — .php, .php5, .phtml"
    echo -e "${YELLOW}║${NC} ${GREEN}6${NC}  ASP/ASPX Scan            — .asp, .aspx, .ashx"
    echo -e "${YELLOW}║${NC} ${GREEN}7${NC}  JSP/Java Scan            — .jsp, .do, .action"
    echo -e "${YELLOW}║${NC} ${GREEN}8${NC}  Config/Backup File Scan  — .bak, .conf, .env, .sql"
    echo -e "${YELLOW}║${NC} ${GREEN}9${NC}  Source Code Leak Scan    — .git, .svn, .DS_Store"
    echo -e "${YELLOW}║${NC} ${GREEN}10${NC} Log/Text File Scan       — .log, .txt, .xml, .json"
    echo -e "${YELLOW}║${NC} ${GREEN}11${NC} Archive File Scan        — .zip, .tar, .gz, .rar"
    echo -e "${YELLOW}║${NC} ${GREEN}12${NC} Custom Extension Scan    — নিজের extensions"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ TARGETED SCANS ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}13${NC} Admin Panel Hunt         — /admin, /dashboard, /cpanel"
    echo -e "${YELLOW}║${NC} ${GREEN}14${NC} API Endpoint Discovery   — /api/, /v1/, /graphql"
    echo -e "${YELLOW}║${NC} ${GREEN}15${NC} WordPress Scan           — wp-admin, wp-content"
    echo -e "${YELLOW}║${NC} ${GREEN}16${NC} Joomla Scan              — Joomla specific paths"
    echo -e "${YELLOW}║${NC} ${GREEN}17${NC} Drupal Scan              — Drupal specific paths"
    echo -e "${YELLOW}║${NC} ${GREEN}18${NC} Login Page Hunt          — /login, /signin, /auth"
    echo -e "${YELLOW}║${NC} ${GREEN}19${NC} Upload Directory Hunt    — /upload, /files, /media"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ ADVANCED OPTIONS ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}20${NC} Recursive Scan           — subdirectory ও scan করো"
    echo -e "${YELLOW}║${NC} ${GREEN}21${NC} Proxy Scan (Burp)        — Burp proxy দিয়ে"
    echo -e "${YELLOW}║${NC} ${GREEN}22${NC} Auth Scan                — Basic/Bearer auth সহ"
    echo -e "${YELLOW}║${NC} ${GREEN}23${NC} Cookie Scan              — session cookie সহ"
    echo -e "${YELLOW}║${NC} ${GREEN}24${NC} Status Filter Scan       — নির্দিষ্ট status code"
    echo -e "${YELLOW}║${NC} ${GREEN}25${NC} Subdomain Path Scan      — subdomains + paths"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ COMBO ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}26${NC} Smart Combo Scan         — extensions + wordlist combo"
    echo -e "${YELLOW}║${NC} ${GREEN}27${NC} All-in-One Mega Scan     — সব mode একসাথে"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${RED}0)${NC} Exit                                                               ${YELLOW}║${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ================================================================
# EXTRA OPTIONS
# ================================================================
get_extra_options() {
    THREADS_OPT="-t 25"; TIMEOUT_OPT="--timeout 10"
    DELAY_OPT=""; FOLLOW_OPT="--follow-redirects"
    EXCLUDE_OPT="--exclude-status 404,400,500"
    PROXY_OPT=""; HEADERS_OPT=""; AUTH_OPT=""

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║         EXTRA OPTIONS                ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""

    read -p "$(echo -e ${WHITE}"Threads (Enter=25): "${NC})" th
    [ -n "$th" ] && THREADS_OPT="-t $th"

    read -p "$(echo -e ${WHITE}"Timeout seconds (Enter=10): "${NC})" to
    [ -n "$to" ] && TIMEOUT_OPT="--timeout $to"

    read -p "$(echo -e ${WHITE}"Request delay ms (Enter=0): "${NC})" dl
    [ -n "$dl" ] && DELAY_OPT="--delay $dl"

    read -p "$(echo -e ${WHITE}"Exclude status codes (Enter=404,400,500): "${NC})" ex
    [ -n "$ex" ] && EXCLUDE_OPT="--exclude-status $ex"

    read -p "$(echo -e ${WHITE}"Proxy (Enter=skip, e.g. http://127.0.0.1:8080): "${NC})" px
    [ -n "$px" ] && PROXY_OPT="--proxy $px"

    read -p "$(echo -e ${WHITE}"Custom header (Enter=skip): "${NC})" hdr
    [ -n "$hdr" ] && HEADERS_OPT="-H '$hdr'"

    echo ""
}

# ================================================================
# RUN DIRSEARCH CORE
# ================================================================
run_dirsearch() {
    local label=$1 extra=$2 url="${3:-$TARGET}"

    SCAN_LABEL="$label"
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$url" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g')
    OUTPUT_FILE="$RESULTS_DIR/${label// /_}_${safe}_${ts}.txt"

    local cmd="$DIRSEARCH_CMD -u '$url' $THREADS_OPT $TIMEOUT_OPT $DELAY_OPT $FOLLOW_OPT $EXCLUDE_OPT $PROXY_OPT $HEADERS_OPT $AUTH_OPT --plain-text-report='$OUTPUT_FILE' $extra"

    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}Scan Type : ${YELLOW}${BOLD}$label${NC}"
    echo -e "  ${WHITE}Target    : ${GREEN}${BOLD}$url${NC}"
    echo -e "  ${WHITE}Output    : ${CYAN}$OUTPUT_FILE${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] Scan শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    echo ""
    echo -e "${GREEN}${BOLD}[*] Dirsearch চালু হচ্ছে...${NC}"
    echo ""

    eval "$cmd" 2>&1

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Scan সম্পন্ন!${NC}"
    echo ""

    bangla_analysis "$OUTPUT_FILE" "$url"
    suggest_next_tool "$OUTPUT_FILE" "$url"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# TEMP WORDLIST HELPER
# ================================================================
make_temp_wordlist() {
    local tmpfile="/tmp/ds_wl_$$.txt"
    echo "$@" | tr ',' '\n' | tr ' ' '\n' | grep -v '^$' > "$tmpfile"
    echo "$tmpfile"
}

# ================================================================
# MODE 1 — QUICK
# ================================================================
mode_quick() {
    run_dirsearch "Quick Scan" "-e php,html,js,txt,xml,json -w /usr/share/seclists/Discovery/Web-Content/common.txt 2>/dev/null || -e php,html,js,txt"
}

# ================================================================
# MODE 2 — FULL
# ================================================================
mode_full() {
    local wl="${DEFAULT_WORDLIST}"
    [ -z "$wl" ] && read -p "$(echo -e ${WHITE}"Wordlist: "${NC})" wl
    [ ! -f "$wl" ] && echo -e "${RED}[!] File নেই।${NC}" && return
    run_dirsearch "Full Scan" "-w '$wl' -e php,html,js,txt,json,xml,asp,aspx,jsp,bak,zip,env"
}

# ================================================================
# MODE 3 — CUSTOM WORDLIST
# ================================================================
mode_custom_wordlist() {
    read -p "$(echo -e ${WHITE}"Wordlist: "${NC})" wl
    [ ! -f "$wl" ] && echo -e "${RED}[!] File নেই।${NC}" && return
    read -p "$(echo -e ${WHITE}"Extensions (e.g. php,html): "${NC})" exts
    [ -z "$exts" ] && exts="php,html,txt,js"
    run_dirsearch "Custom Wordlist" "-w '$wl' -e $exts"
}

# ================================================================
# MODE 4 — MULTIPLE URLS
# ================================================================
mode_multiple_urls() {
    if [ -n "$TARGET_FILE" ]; then
        local ts; ts=$(date +"%Y%m%d_%H%M%S")
        local out="$RESULTS_DIR/multi_scan_${ts}.txt"
        echo -e "${GREEN}[*] File-based multi-scan চলছে...${NC}"
        eval "$DIRSEARCH_CMD --url-list '$TARGET_FILE' $THREADS_OPT $TIMEOUT_OPT $EXCLUDE_OPT -e php,html,js,txt --plain-text-report='$out'" 2>&1
        bangla_analysis "$out" "$TARGET"
        suggest_next_tool "$out" "$TARGET"
    elif [ ${#TARGET_LIST[@]} -gt 1 ]; then
        for url in "${TARGET_LIST[@]}"; do
            echo ""
            echo -e "${CYAN}${BOLD}══════════════ $url ══════════════${NC}"
            run_dirsearch "Multi-URL" "-e php,html,js,txt" "$url"
        done
    else
        echo -e "${YELLOW}[!] Multiple URL mode এ target select করুন (option 2/3)।${NC}"
    fi
}

# ================================================================
# MODE 5-12 — EXTENSION SCANS
# ================================================================
mode_php_scan()     { run_dirsearch "PHP Scan"     "-e php,php5,php7,phtml,php3,php4"; }
mode_asp_scan()     { run_dirsearch "ASP Scan"     "-e asp,aspx,ashx,asmx,svc"; }
mode_jsp_scan()     { run_dirsearch "JSP Scan"     "-e jsp,jsf,jspx,do,action,java,war"; }

mode_config_scan() {
    local wl; wl=$(make_temp_wordlist \
        "config,config.php,config.bak,config.old,configuration,database,database.php,db.php,db.sql,\
backup,backup.zip,backup.sql,.env,.env.bak,.env.local,.htaccess,.htpasswd,web.config,settings.php,\
settings.py,appsettings.json,secrets.json,credentials.json,passwords.txt,users.sql,dump.sql,site.sql")
    run_dirsearch "Config/Backup Scan" "-w '$wl' -e bak,old,tmp,conf,sql,env,ini,xml,json,yaml"
    rm -f "$wl"
}

mode_source_leak() {
    local wl; wl=$(make_temp_wordlist \
        ".git,.git/HEAD,.git/config,.svn,.svn/entries,.DS_Store,.hg,.idea,.vscode,\
src,source,app,application,dist,build,node_modules,vendor,\
composer.json,package.json,requirements.txt,Pipfile,Gemfile")
    run_dirsearch "Source Code Leak" "-w '$wl'"
    rm -f "$wl"
}

mode_log_scan()     { run_dirsearch "Log/Text Scan"    "-e log,txt,xml,json,csv,yaml,md"; }
mode_archive_scan() { run_dirsearch "Archive Scan"     "-e zip,tar,gz,tar.gz,tgz,rar,7z,bz2,war,jar"; }

mode_custom_ext() {
    read -p "$(echo -e ${WHITE}"Extensions (e.g. php,html,js): "${NC})" exts
    [ -z "$exts" ] && echo -e "${RED}[!] Extension দাও।${NC}" && return
    local wl="${DEFAULT_WORDLIST}"; [ -z "$wl" ] && read -p "$(echo -e ${WHITE}"Wordlist: "${NC})" wl
    run_dirsearch "Custom Extension ($exts)" "-e $exts -w '$wl'"
}

# ================================================================
# MODE 13 — ADMIN HUNT
# ================================================================
mode_admin_hunt() {
    local wl; wl=$(make_temp_wordlist \
        "admin,admin/,admin/login,admin/login.php,admin/index.php,administrator,administrator/,\
management,manager,manager/,panel,panel/,cpanel,cpanel/,dashboard,dashboard/,\
backend,cms,cms/,login,login.php,signin,auth,auth/,secure,staff,\
wp-admin,wp-admin/,phpmyadmin,phpmyadmin/,pma,adminer,adminer.php,\
filemanager,webmin,user/login,account/login,superadmin,sysadmin")
    run_dirsearch "Admin Panel Hunt" "-w '$wl' -e php,html,asp,aspx"
    rm -f "$wl"
}

# ================================================================
# MODE 14 — API DISCOVERY
# ================================================================
mode_api_scan() {
    local wl; wl=$(make_temp_wordlist \
        "api,api/,api/v1,api/v1/,api/v2,api/v2/,api/v3,v1,v1/,v2,v2/,\
graphql,graphql/,graphiql,rest,rest/,swagger,swagger.json,swagger.yaml,\
api-docs,openapi,openapi.json,openapi.yaml,docs,docs/,redoc,\
api/users,api/user,api/auth,api/login,api/register,api/health,\
api/status,api/ping,api/info,api/admin,api/search,ws,websocket,rpc,xmlrpc,xmlrpc.php")
    run_dirsearch "API Discovery" "-w '$wl' -e json,xml,yaml,php"
    rm -f "$wl"
}

# ================================================================
# MODE 15 — WORDPRESS
# ================================================================
mode_wordpress() {
    local wl; wl=$(make_temp_wordlist \
        "wp-admin,wp-admin/,wp-admin/admin.php,wp-admin/admin-ajax.php,\
wp-content,wp-content/,wp-content/uploads,wp-content/plugins,wp-content/themes,\
wp-includes,wp-includes/,wp-login.php,wp-config.php,wp-config.php.bak,\
wp-cron.php,xmlrpc.php,wp-json,wp-json/wp/v2,wp-json/wp/v2/users,\
wp-sitemap.xml,readme.html,license.txt")
    run_dirsearch "WordPress Scan" "-w '$wl' -e php,html"
    rm -f "$wl"
}

# ================================================================
# MODE 16 — JOOMLA
# ================================================================
mode_joomla() {
    local wl; wl=$(make_temp_wordlist \
        "administrator,administrator/,administrator/index.php,\
components,modules,plugins,templates,cache,logs,tmp,\
configuration.php,configuration.php.bak,\
libraries,includes,language,media,\
index.php,index2.php,robots.txt,README.txt,htaccess.txt")
    run_dirsearch "Joomla Scan" "-w '$wl' -e php,html"
    rm -f "$wl"
}

# ================================================================
# MODE 17 — DRUPAL
# ================================================================
mode_drupal() {
    local wl; wl=$(make_temp_wordlist \
        "admin,admin/,user,user/login,user/register,\
sites,sites/default,sites/default/settings.php,\
modules,themes,includes,misc,profiles,\
CHANGELOG.txt,COPYRIGHT.txt,INSTALL.txt,LICENSE.txt,\
README.txt,UPGRADE.txt,install.php,update.php,\
?q=admin,?q=user/login,xmlrpc.php")
    run_dirsearch "Drupal Scan" "-w '$wl' -e php,html"
    rm -f "$wl"
}

# ================================================================
# MODE 18 — LOGIN HUNT
# ================================================================
mode_login_hunt() {
    local wl; wl=$(make_temp_wordlist \
        "login,login.php,login.html,login.asp,login.aspx,\
signin,signin.php,sign-in,sign-in.php,\
auth,auth/,auth/login,authenticate,\
account,account/login,user/login,member/login,\
portal,portal/login,secure,secure/login,\
oauth,oauth/authorize,sso,saml,\
forgot,forgot-password,reset-password,\
register,register.php,signup,sign-up")
    run_dirsearch "Login Page Hunt" "-w '$wl' -e php,html,asp,aspx"
    rm -f "$wl"
}

# ================================================================
# MODE 19 — UPLOAD HUNT
# ================================================================
mode_upload_hunt() {
    local wl; wl=$(make_temp_wordlist \
        "upload,upload/,uploads,uploads/,files,files/,\
media,media/,images,images/,img,img/,\
assets,assets/,static,static/,content,content/,\
data,data/,docs,documents,documents/,\
attachments,attachments/,temp,tmp,\
file-manager,filemanager,file_manager")
    run_dirsearch "Upload Directory Hunt" "-w '$wl'"
    rm -f "$wl"
}

# ================================================================
# MODE 20 — RECURSIVE
# ================================================================
mode_recursive() {
    local wl="${DEFAULT_WORDLIST}"
    [ -z "$wl" ] && read -p "$(echo -e ${WHITE}"Wordlist: "${NC})" wl
    read -p "$(echo -e ${WHITE}"Recursion depth (Enter=2): "${NC})" depth
    [ -z "$depth" ] && depth=2
    echo -e "${YELLOW}[!] Recursive scan অনেক সময় নিতে পারে।${NC}"
    run_dirsearch "Recursive Scan (depth=$depth)" "-w '$wl' -e php,html,js,txt --recursive -R $depth"
}

# ================================================================
# MODE 21 — PROXY SCAN
# ================================================================
mode_proxy_scan() {
    read -p "$(echo -e ${WHITE}"Proxy (e.g. http://127.0.0.1:8080): "${NC})" proxy
    [ -z "$proxy" ] && proxy="http://127.0.0.1:8080"
    PROXY_OPT="--proxy $proxy"
    local wl="${DEFAULT_WORDLIST}"
    [ -z "$wl" ] && read -p "$(echo -e ${WHITE}"Wordlist: "${NC})" wl
    run_dirsearch "Proxy Scan" "-w '$wl' -e php,html,js,txt"
    PROXY_OPT=""
}

# ================================================================
# MODE 22 — AUTH SCAN
# ================================================================
mode_auth_scan() {
    echo -e "${CYAN}Auth type:${NC}"
    echo -e "  ${GREEN}1)${NC} Basic Auth  ${GREEN}2)${NC} Bearer Token"
    read -p "$(echo -e ${YELLOW}"[1-2]: "${NC})" ach
    case $ach in
        1)
            read -p "$(echo -e ${WHITE}"Username: "${NC})" u
            read -p "$(echo -e ${WHITE}"Password: "${NC})" p
            AUTH_OPT="--auth $u:$p --auth-type basic" ;;
        2)
            read -p "$(echo -e ${WHITE}"Token: "${NC})" tok
            HEADERS_OPT="-H 'Authorization: Bearer $tok'" ;;
    esac
    local wl="${DEFAULT_WORDLIST}"
    [ -z "$wl" ] && read -p "$(echo -e ${WHITE}"Wordlist: "${NC})" wl
    run_dirsearch "Auth Scan" "-w '$wl' -e php,html,json,xml"
    AUTH_OPT=""; HEADERS_OPT=""
}

# ================================================================
# MODE 23 — COOKIE SCAN
# ================================================================
mode_cookie_scan() {
    read -p "$(echo -e ${WHITE}"Cookie দিন (e.g. PHPSESSID=abc123): "${NC})" cookie
    [ -z "$cookie" ] && echo -e "${RED}[!] Cookie দাও।${NC}" && return
    local wl="${DEFAULT_WORDLIST}"
    [ -z "$wl" ] && read -p "$(echo -e ${WHITE}"Wordlist: "${NC})" wl
    run_dirsearch "Cookie Scan" "-w '$wl' -e php,html,json --cookie '$cookie'"
}

# ================================================================
# MODE 24 — STATUS FILTER
# ================================================================
mode_status_filter() {
    read -p "$(echo -e ${WHITE}"Show only status codes (e.g. 200,301,302): "${NC})" codes
    [ -z "$codes" ] && codes="200,301,302"
    local wl="${DEFAULT_WORDLIST}"
    [ -z "$wl" ] && read -p "$(echo -e ${WHITE}"Wordlist: "${NC})" wl
    EXCLUDE_OPT=""
    run_dirsearch "Status Filter ($codes)" "-w '$wl' -e php,html,js,txt --include-status $codes"
    EXCLUDE_OPT="--exclude-status 404,400,500"
}

# ================================================================
# MODE 25 — SUBDOMAIN PATHS
# ================================================================
mode_subdomain_paths() {
    echo -e "${WHITE}Subdomains দিন (comma-separated):${NC}"
    read -p "$(echo -e ${WHITE}"Subdomains: "${NC})" subs
    local base_domain; base_domain=$(echo "$TARGET" | sed 's|https\?://||' | cut -d'/' -f1)
    local wl="${DEFAULT_WORDLIST}"
    [ -z "$wl" ] && read -p "$(echo -e ${WHITE}"Wordlist: "${NC})" wl

    for sub in $(echo "$subs" | tr ',' ' '); do
        local sub_url="http://${sub}.${base_domain}"
        echo ""
        echo -e "${CYAN}${BOLD}══════════════ $sub_url ══════════════${NC}"
        run_dirsearch "Subdomain ($sub)" "-w '$wl' -e php,html,js,txt" "$sub_url"
    done
}

# ================================================================
# MODE 26 — SMART COMBO
# ================================================================
mode_smart_combo() {
    local wl="${DEFAULT_WORDLIST}"
    [ -z "$wl" ] && read -p "$(echo -e ${WHITE}"Wordlist: "${NC})" wl
    [ ! -f "$wl" ] && echo -e "${RED}[!] File নেই।${NC}" && return

    echo ""
    echo -e "${CYAN}${BOLD}Smart Combo — ৩ ধাপে scan:${NC}"
    echo -e "  ${WHITE}1: Common paths  2: PHP/Config  3: Admin+API${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g')
    local out="$RESULTS_DIR/smart_combo_${safe}_${ts}.txt"

    echo -e "${CYAN}━━━ Phase 1: Common Paths ━━━${NC}"
    eval "$DIRSEARCH_CMD -u '$TARGET' $THREADS_OPT $TIMEOUT_OPT $EXCLUDE_OPT \
        -w '$wl' -e php,html,js,txt --plain-text-report='${out}_phase1.txt'" 2>&1

    echo -e "${CYAN}━━━ Phase 2: PHP + Config + Backup ━━━${NC}"
    eval "$DIRSEARCH_CMD -u '$TARGET' $THREADS_OPT $TIMEOUT_OPT $EXCLUDE_OPT \
        -e php,php5,bak,env,sql,conf --plain-text-report='${out}_phase2.txt'" 2>&1

    echo -e "${CYAN}━━━ Phase 3: Admin + API + Git ━━━${NC}"
    local admin_wl; admin_wl=$(make_temp_wordlist \
        "admin,administrator,dashboard,api,api/v1,api/v2,graphql,.git,.git/HEAD,.env,wp-admin,phpmyadmin")
    eval "$DIRSEARCH_CMD -u '$TARGET' $THREADS_OPT $TIMEOUT_OPT $EXCLUDE_OPT \
        -w '$admin_wl' --plain-text-report='${out}_phase3.txt'" 2>&1
    rm -f "$admin_wl"

    cat "${out}_phase1.txt" "${out}_phase2.txt" "${out}_phase3.txt" 2>/dev/null | \
        grep -v "^$" | sort -u > "$out"
    rm -f "${out}_phase1.txt" "${out}_phase2.txt" "${out}_phase3.txt"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Smart Combo সম্পন্ন!${NC}"
    OUTPUT_FILE="$out"
    SCAN_LABEL="Smart Combo"
    bangla_analysis "$out" "$TARGET"
    suggest_next_tool "$out" "$TARGET"
    save_results "$out"
}

# ================================================================
# MODE 27 — ALL IN ONE MEGA SCAN
# ================================================================
mode_allinone() {
    local wl="${DEFAULT_WORDLIST}"
    [ -z "$wl" ] && read -p "$(echo -e ${WHITE}"Wordlist: "${NC})" wl
    [ ! -f "$wl" ] && echo -e "${RED}[!] File নেই।${NC}" && return

    echo ""
    echo -e "${RED}${BOLD}[!] All-in-One Mega Scan — সব mode একসাথে।${NC}"
    echo -e "${YELLOW}[!] এটি অনেক সময় নিতে পারে।${NC}"
    read -p "$(echo -e ${YELLOW}"[?] শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g')
    local out="$RESULTS_DIR/mega_scan_${safe}_${ts}.txt"

    local phases=(
        "php,html,js,txt,json,xml -w '$wl'"
        "-e asp,aspx,bak,env,sql,conf,zip,tar.gz"
        "-e php5,phtml,php3,jsp,do,action"
    )
    local phase_num=0
    for phase in "${phases[@]}"; do
        phase_num=$((phase_num + 1))
        echo -e "${CYAN}━━━ Phase $phase_num ━━━${NC}"
        eval "$DIRSEARCH_CMD -u '$TARGET' $THREADS_OPT $TIMEOUT_OPT $EXCLUDE_OPT \
            $phase --plain-text-report='${out}_p${phase_num}.txt'" 2>&1
    done

    # Admin + API + Source
    local meta_wl; meta_wl=$(make_temp_wordlist \
        "admin,administrator,dashboard,api,api/v1,api/v2,graphql,swagger,swagger.json,\
.git,.git/HEAD,.git/config,.env,.env.bak,.htaccess,.htpasswd,\
wp-admin,wp-login.php,phpmyadmin,pma,adminer,backup,backup.zip")
    echo -e "${CYAN}━━━ Phase 4: Admin+API+Source ━━━${NC}"
    eval "$DIRSEARCH_CMD -u '$TARGET' $THREADS_OPT $TIMEOUT_OPT $EXCLUDE_OPT \
        -w '$meta_wl' --plain-text-report='${out}_p4.txt'" 2>&1
    rm -f "$meta_wl"

    cat "${out}_p"*.txt 2>/dev/null | grep -v "^$" | sort -u > "$out"
    rm -f "${out}_p"*.txt

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Mega Scan সম্পন্ন!${NC}"
    OUTPUT_FILE="$out"
    SCAN_LABEL="All-in-One Mega"
    bangla_analysis "$out" "$TARGET"
    suggest_next_tool "$out" "$TARGET"
    save_results "$out"
}

# ================================================================
# BANGLA ANALYSIS
# ================================================================
bangla_analysis() {
    local outfile=$1 url=$2

    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় স্ক্যান রিপোর্ট বিশ্লেষণ                      ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ ! -f "$outfile" ] || [ ! -s "$outfile" ]; then
        echo -e "  ${YELLOW}[!] কোনো result পাওয়া যায়নি।${NC}"
        echo ""
        return
    fi

    local total; total=$(grep -c "" "$outfile" 2>/dev/null || echo 0)
    local ok_count; ok_count=$(grep -c " 200 " "$outfile" 2>/dev/null || echo 0)
    local redir_count; redir_count=$(grep -cE " 30[0-9] " "$outfile" 2>/dev/null || echo 0)
    local forbidden; forbidden=$(grep -c " 403 " "$outfile" 2>/dev/null || echo 0)

    echo -e "  ${CYAN}${BOLD}━━━ Findings Statistics ━━━${NC}"
    echo -e "  ${WHITE}মোট Found    : ${GREEN}$total${NC}"
    echo -e "  ${GREEN}   200 OK    : $ok_count${NC}"
    echo -e "  ${YELLOW}   Redirects : $redir_count${NC}"
    echo -e "  ${CYAN}   Forbidden : $forbidden${NC}"
    echo ""

    local critical=0 high=0 medium=0

    # .git exposed
    if grep -qiE "\.git/HEAD|\.git/config" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 .git Repository Exposed!${NC}"
        echo -e "     ${WHITE}→ Source code সম্পূর্ণ download করা সম্ভব।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # .env exposed
    if grep -qiE "\.env|\.env\.local|\.env\.production" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 .env File Exposed!${NC}"
        echo -e "     ${WHITE}→ DB credentials, API keys, secret tokens সব exposed!${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # Config/backup exposed
    if grep -qiE "config\.php|wp-config|database\.php|backup\.zip|dump\.sql|\.sql" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Config/Backup File Exposed!${NC}"
        echo -e "     ${WHITE}→ Database credentials বা full backup publicly accessible!${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # Admin panel found
    if grep -qiE "/admin|/administrator|/dashboard|/cpanel|/panel|phpmyadmin|adminer" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ Admin Panel পাওয়া গেছে!${NC}"
        grep -iE "/admin|/administrator|/dashboard|/cpanel|phpmyadmin|adminer" "$outfile" | \
            grep " 200 \| 302 " | head -5 | while IFS= read -r l; do
                echo -e "     ${YELLOW}▸ $l${NC}"
            done
        echo -e "     ${WHITE}→ Brute force বা default credential attack করুন।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # API endpoints
    if grep -qiE "/api/|graphql|swagger|openapi" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚡ API Endpoints পাওয়া গেছে!${NC}"
        grep -iE "/api/|graphql|swagger" "$outfile" | grep " 200 " | head -5 | \
            while IFS= read -r l; do echo -e "     ${YELLOW}▸ $l${NC}"; done
        echo -e "     ${WHITE}→ API authentication ও authorization test করুন।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Upload dir
    if grep -qiE "/upload|/uploads|/files|/media" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}📁 Upload Directory পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ File upload vulnerability test করুন।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Login pages
    if grep -qiE "/login|/signin|/auth" "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}🔑 Login Page পাওয়া গেছে!${NC}"
        echo -e "     ${WHITE}→ Brute force, SQLi, default credential test করুন।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # WordPress
    if grep -qiE "wp-admin|wp-login|wp-content|xmlrpc" "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}🔧 WordPress Detected!${NC}"
        echo -e "     ${WHITE}→ WPScan দিয়ে বিস্তারিত scan করুন।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # .htaccess/htpasswd
    if grep -qiE "\.htaccess|\.htpasswd" "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}ℹ .htaccess/.htpasswd Found${NC}"
        echo -e "     ${WHITE}→ Access control rules ও credentials এখানে থাকতে পারে।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # Risk summary
    echo -e "  ${CYAN}${BOLD}━━━ সামগ্রিক ঝুঁকি মূল্যায়ন ━━━${NC}"
    echo -e "  ${RED}   Critical : $critical টি${NC}"
    echo -e "  ${YELLOW}   High     : $high টি${NC}"
    echo -e "  ${CYAN}   Medium   : $medium টি${NC}"
    echo -e "  ${WHITE}   Total    : $total paths found${NC}"
    echo ""

    if   [ "$critical" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}  সার্বিক ঝুঁকি : ██████████ CRITICAL — এখনই পদক্ষেপ নিন!${NC}"
    elif [ "$high" -gt 0 ]; then
        echo -e "  ${YELLOW}${BOLD}  সার্বিক ঝুঁকি : ███████░░░ HIGH — দ্রুত fix করুন।${NC}"
    elif [ "$medium" -gt 0 ]; then
        echo -e "  ${CYAN}  সার্বিক ঝুঁকি : █████░░░░░ MEDIUM — মনোযোগ দিন।${NC}"
    elif [ "$total" -gt 0 ]; then
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW — তবু manually review করুন।${NC}"
    else
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ██░░░░░░░░ INFO — কোনো interesting path নেই।${NC}"
    fi
    echo ""
}

# ================================================================
# NEXT TOOL SUGGESTION
# ================================================================
suggest_next_tool() {
    local outfile=$1 url=$2

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             পরবর্তী Tool এর সাজেশন                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if grep -qiE "\.git|\.env|config\.php|backup|\.sql" "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}🚨 GitTools / wget${NC} — Source Code Download"
        echo -e "     ${WHITE}কারণ: .git বা sensitive file exposed।${NC}"
        echo -e "     ${CYAN}কমান্ড: git-dumper $url/.git ./source_code${NC}"; echo ""
    fi

    if grep -qiE "wp-admin|wp-login|xmlrpc" "$outfile" 2>/dev/null; then
        echo -e "  ${BLUE}${BOLD}🔧 WPScan${NC} — WordPress Deep Scan"
        echo -e "     ${CYAN}কমান্ড: wpscan --url $url --enumerate u,vp,ap --api-token TOKEN${NC}"; echo ""
    fi

    if grep -qiE "/api/|graphql|swagger" "$outfile" 2>/dev/null; then
        echo -e "  ${GREEN}${BOLD}💉 SQLmap${NC} — API Injection Test"
        echo -e "     ${CYAN}কমান্ড: sqlmap -u '$url/api/v1/users?id=1' --dbs --batch${NC}"; echo ""
        echo -e "  ${MAGENTA}${BOLD}🔍 Nuclei${NC} — API Vulnerability Scan"
        echo -e "     ${CYAN}কমান্ড: nuclei -u $url -t http/vulnerabilities/generic -t http/cves${NC}"; echo ""
    fi

    if grep -qiE "/login|/admin|/signin" "$outfile" 2>/dev/null; then
        echo -e "  ${YELLOW}${BOLD}🔑 Hydra${NC} — Login Brute Force"
        echo -e "     ${CYAN}কমান্ড: hydra -L users.txt -P rockyou.txt $url http-post-form '/login:u=^USER^&p=^PASS^:F=wrong'${NC}"; echo ""
    fi

    if grep -qiE "/upload|/uploads" "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}📤 File Upload Test${NC} — Web Shell Upload"
        echo -e "     ${WHITE}Burp Suite দিয়ে upload request intercept করে test করুন।${NC}"; echo ""
    fi

    echo -e "  ${WHITE}${BOLD}🌐 Nikto${NC} — Full Web Vulnerability Scan"
    echo -e "     ${CYAN}কমান্ড: nikto -h $url${NC}"; echo ""

    echo -e "  ${MAGENTA}${BOLD}🔍 FFUF${NC} — Fast Fuzzing (alternative)"
    echo -e "     ${CYAN}কমান্ড: ffuf -u $url/FUZZ -w ${DEFAULT_WORDLIST:-wordlist.txt}${NC}"; echo ""

    echo -e "  ${GREEN}${BOLD}🔍 Gobuster${NC} — Directory Brute Force"
    echo -e "     ${CYAN}কমান্ড: gobuster dir -u $url -w ${DEFAULT_WORDLIST:-wordlist.txt}${NC}"; echo ""
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

        read -p "$(echo -e ${YELLOW}"[?] Scan option [0-27]: "${NC})" choice

        [[ "$choice" == "0" ]] && {
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            exit 0
        }

        case $choice in
            1)  mode_quick ;;
            2)  mode_full ;;
            3)  mode_custom_wordlist ;;
            4)  mode_multiple_urls ;;
            5)  mode_php_scan ;;
            6)  mode_asp_scan ;;
            7)  mode_jsp_scan ;;
            8)  mode_config_scan ;;
            9)  mode_source_leak ;;
            10) mode_log_scan ;;
            11) mode_archive_scan ;;
            12) mode_custom_ext ;;
            13) mode_admin_hunt ;;
            14) mode_api_scan ;;
            15) mode_wordpress ;;
            16) mode_joomla ;;
            17) mode_drupal ;;
            18) mode_login_hunt ;;
            19) mode_upload_hunt ;;
            20) mode_recursive ;;
            21) mode_proxy_scan ;;
            22) mode_auth_scan ;;
            23) mode_cookie_scan ;;
            24) mode_status_filter ;;
            25) mode_subdomain_paths ;;
            26) mode_smart_combo ;;
            27) mode_allinone ;;
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
