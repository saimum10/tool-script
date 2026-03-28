#!/bin/bash

# ================================================================
#   JOHN THE RIPPER - Full Automation Tool
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

RESULTS_DIR="$HOME/john_results"
HISTORY_FILE="$HOME/.john_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${RED}${BOLD}"
    echo ' ██╗ ██████╗ ██╗  ██╗███╗   ██╗'
    echo ' ██║██╔═══██╗██║  ██║████╗  ██║'
    echo ' ██║██║   ██║███████║██╔██╗ ██║'
    echo ' ██║██║   ██║██╔══██║██║╚██╗██║'
    echo ' ██║╚██████╔╝██║  ██║██║ ╚████║'
    echo ' ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝'
    echo ''
    echo ' ████████╗██╗  ██╗███████╗'
    echo ' ╚══██╔══╝██║  ██║██╔════╝'
    echo '    ██║   ███████║█████╗  '
    echo '    ██║   ██╔══██║██╔══╝  '
    echo '    ██║   ██║  ██║███████╗'
    echo '    ╚═╝   ╚═╝  ╚═╝╚══════╝'
    echo ''
    echo ' ██████╗ ██╗██████╗ ██████╗ ███████╗██████╗ '
    echo ' ██╔══██╗██║██╔══██╗██╔══██╗██╔════╝██╔══██╗'
    echo ' ██████╔╝██║██████╔╝██████╔╝█████╗  ██████╔╝'
    echo ' ██╔══██╗██║██╔═══╝ ██╔═══╝ ██╔══╝  ██╔══██╗'
    echo ' ██║  ██║██║██║     ██║     ███████╗██║  ██║'
    echo ' ╚═╝  ╚═╝╚═╝╚═╝     ╚═╝     ╚══════╝╚═╝  ╚═╝'
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}         John The Ripper Full Automation | Password Cracker${NC}"
    echo ""
    echo -e "  ${RED}${BOLD}⚠  Ethics Warning:${NC} ${WHITE}শুধুমাত্র নিজের বা অনুমতি আছে এমন hash crack করুন।${NC}"
    echo ""
}

# ================================================================
# CHECK DEPENDENCIES
# ================================================================
check_deps() {
    echo -e "${CYAN}[*] Dependencies চেক করা হচ্ছে...${NC}"
    local missing=()

    # Check john variants
    JOHN_CMD=""
    for variant in john john-the-ripper; do
        if command -v "$variant" &>/dev/null; then
            JOHN_CMD="$variant"
            echo -e "  ${GREEN}[✓] $variant — found${NC}"
            break
        fi
    done
    if [ -z "$JOHN_CMD" ]; then
        missing+=("john")
        echo -e "  ${RED}[✗] john — পাওয়া যায়নি${NC}"
    fi

    for tool in curl file; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
            echo -e "  ${RED}[✗] $tool — পাওয়া যায়নি${NC}"
        else
            echo -e "  ${GREEN}[✓] $tool${NC}"
        fi
    done

    # Optional helper tools
    echo ""
    echo -e "${CYAN}[*] Optional / Helper tools:${NC}"
    for opt in hashcat zip2john rar2john ssh2john pdf2john gpg2john unshadow; do
        if command -v "$opt" &>/dev/null; then
            echo -e "  ${GREEN}[✓] $opt — available${NC}"
        else
            echo -e "  ${YELLOW}[!] $opt — নেই (কিছু mode কাজ নাও করতে পারে)${NC}"
        fi
    done

    # Default wordlists check
    echo ""
    echo -e "${CYAN}[*] Wordlist চেক করা হচ্ছে...${NC}"
    local wordlists=(
        "/usr/share/wordlists/rockyou.txt"
        "/usr/share/john/password.lst"
        "/usr/share/wordlists/fasttrack.txt"
        "$HOME/wordlists/rockyou.txt"
    )
    DEFAULT_WORDLIST=""
    for wl in "${wordlists[@]}"; do
        if [ -f "$wl" ]; then
            DEFAULT_WORDLIST="$wl"
            echo -e "  ${GREEN}[✓] $wl${NC}"
            break
        fi
    done
    if [ -z "$DEFAULT_WORDLIST" ]; then
        echo -e "  ${YELLOW}[!] Default wordlist পাওয়া যায়নি। Custom path দিতে হবে।${NC}"
    fi

    # John's built-in wordlist
    JOHN_WORDLIST=$(find /usr/share/john /usr/local/share/john 2>/dev/null -name "password.lst" | head -1)
    [ -n "$JOHN_WORDLIST" ] && echo -e "  ${GREEN}[✓] John built-in: $JOHN_WORDLIST${NC}"

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing: ${missing[*]}${NC}"
        echo -e "${YELLOW}Install করুন: sudo apt install john${NC}"
        exit 1
    fi

    # John version
    echo ""
    local jver
    jver=$($JOHN_CMD --version 2>&1 | head -1)
    echo -e "${CYAN}[*] John version: ${GREEN}$jver${NC}"
    echo ""
}

# ================================================================
# GET HASH FILE / INPUT
# ================================================================
get_hash_input() {
    HASH_FILE=""
    HASH_TYPE=""

    echo -e "${RED}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║         HASH INPUT SELECT            ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Hash file দিন (.txt)"
    echo -e "  ${GREEN}2)${NC} Single hash manually টাইপ করুন"
    echo -e "  ${GREEN}3)${NC} /etc/shadow file (Linux password)"
    echo -e "  ${GREEN}4)${NC} /etc/passwd + /etc/shadow combine (unshadow)"
    echo -e "  ${GREEN}5)${NC} ZIP file crack করব"
    echo -e "  ${GREEN}6)${NC} RAR file crack করব"
    echo -e "  ${GREEN}7)${NC} SSH private key crack করব"
    echo -e "  ${GREEN}8)${NC} PDF file crack করব"
    echo -e "  ${GREEN}9)${NC} GPG/PGP file crack করব"
    echo -e "  ${GREEN}10)${NC} Windows NTLM hash (SAM/hashdump)"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-10]: "${NC})" inp_ch

    local ts
    ts=$(date +"%Y%m%d_%H%M%S")

    case $inp_ch in
        1)
            read -p "$(echo -e ${WHITE}"Hash file path দিন: "${NC})" HASH_FILE
            if [ ! -f "$HASH_FILE" ]; then
                echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
                get_hash_input; return
            fi
            ;;
        2)
            read -p "$(echo -e ${WHITE}"Hash টাইপ করুন: "${NC})" single_hash
            HASH_FILE="$RESULTS_DIR/single_hash_${ts}.txt"
            echo "$single_hash" > "$HASH_FILE"
            echo -e "  ${GREEN}[✓] Hash file তৈরি: $HASH_FILE${NC}"
            ;;
        3)
            if [ ! -f "/etc/shadow" ]; then
                echo -e "${RED}[!] /etc/shadow পাওয়া যায়নি। Root permission দরকার।${NC}"
                get_hash_input; return
            fi
            HASH_FILE="$RESULTS_DIR/shadow_copy_${ts}.txt"
            sudo cp /etc/shadow "$HASH_FILE" 2>/dev/null
            echo -e "  ${GREEN}[✓] Shadow file copied: $HASH_FILE${NC}"
            ;;
        4)
            echo -e "${CYAN}[*] unshadow দিয়ে passwd + shadow combine করা হচ্ছে...${NC}"
            if ! command -v unshadow &>/dev/null; then
                echo -e "${RED}[!] unshadow পাওয়া যায়নি।${NC}"
                get_hash_input; return
            fi
            HASH_FILE="$RESULTS_DIR/unshadowed_${ts}.txt"
            sudo unshadow /etc/passwd /etc/shadow > "$HASH_FILE" 2>/dev/null
            echo -e "  ${GREEN}[✓] Unshadowed file: $HASH_FILE${NC}"
            ;;
        5)
            read -p "$(echo -e ${WHITE}"ZIP file path দিন: "${NC})" zip_file
            if [ ! -f "$zip_file" ]; then
                echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
                get_hash_input; return
            fi
            HASH_FILE="$RESULTS_DIR/zip_hash_${ts}.txt"
            if command -v zip2john &>/dev/null; then
                zip2john "$zip_file" > "$HASH_FILE" 2>/dev/null
                echo -e "  ${GREEN}[✓] ZIP hash extracted: $HASH_FILE${NC}"
            else
                echo -e "${RED}[!] zip2john পাওয়া যায়নি।${NC}"
                get_hash_input; return
            fi
            ;;
        6)
            read -p "$(echo -e ${WHITE}"RAR file path দিন: "${NC})" rar_file
            if [ ! -f "$rar_file" ]; then
                echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
                get_hash_input; return
            fi
            HASH_FILE="$RESULTS_DIR/rar_hash_${ts}.txt"
            if command -v rar2john &>/dev/null; then
                rar2john "$rar_file" > "$HASH_FILE" 2>/dev/null
                echo -e "  ${GREEN}[✓] RAR hash extracted: $HASH_FILE${NC}"
            else
                echo -e "${RED}[!] rar2john পাওয়া যায়নি।${NC}"
                get_hash_input; return
            fi
            ;;
        7)
            read -p "$(echo -e ${WHITE}"SSH private key path দিন: "${NC})" ssh_file
            if [ ! -f "$ssh_file" ]; then
                echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
                get_hash_input; return
            fi
            HASH_FILE="$RESULTS_DIR/ssh_hash_${ts}.txt"
            if command -v ssh2john &>/dev/null; then
                ssh2john "$ssh_file" > "$HASH_FILE" 2>/dev/null
                echo -e "  ${GREEN}[✓] SSH hash extracted: $HASH_FILE${NC}"
            else
                # Try python path
                local ssh2john_py
                ssh2john_py=$(find /usr/share/john /usr/local/share/john 2>/dev/null -name "ssh2john.py" | head -1)
                if [ -n "$ssh2john_py" ]; then
                    python3 "$ssh2john_py" "$ssh_file" > "$HASH_FILE" 2>/dev/null
                    echo -e "  ${GREEN}[✓] SSH hash extracted: $HASH_FILE${NC}"
                else
                    echo -e "${RED}[!] ssh2john পাওয়া যায়নি।${NC}"
                    get_hash_input; return
                fi
            fi
            ;;
        8)
            read -p "$(echo -e ${WHITE}"PDF file path দিন: "${NC})" pdf_file
            if [ ! -f "$pdf_file" ]; then
                echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
                get_hash_input; return
            fi
            HASH_FILE="$RESULTS_DIR/pdf_hash_${ts}.txt"
            local pdf2john_py
            pdf2john_py=$(find /usr/share/john /usr/local/share/john 2>/dev/null -name "pdf2john.py" -o -name "pdf2john.pl" 2>/dev/null | head -1)
            if command -v pdf2john &>/dev/null; then
                pdf2john "$pdf_file" > "$HASH_FILE" 2>/dev/null
                echo -e "  ${GREEN}[✓] PDF hash extracted: $HASH_FILE${NC}"
            elif [ -n "$pdf2john_py" ]; then
                python3 "$pdf2john_py" "$pdf_file" > "$HASH_FILE" 2>/dev/null
                echo -e "  ${GREEN}[✓] PDF hash extracted: $HASH_FILE${NC}"
            else
                echo -e "${RED}[!] pdf2john পাওয়া যায়নি।${NC}"
                get_hash_input; return
            fi
            ;;
        9)
            read -p "$(echo -e ${WHITE}"GPG file path দিন: "${NC})" gpg_file
            if [ ! -f "$gpg_file" ]; then
                echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
                get_hash_input; return
            fi
            HASH_FILE="$RESULTS_DIR/gpg_hash_${ts}.txt"
            if command -v gpg2john &>/dev/null; then
                gpg2john "$gpg_file" > "$HASH_FILE" 2>/dev/null
                echo -e "  ${GREEN}[✓] GPG hash extracted: $HASH_FILE${NC}"
            else
                echo -e "${RED}[!] gpg2john পাওয়া যায়নি।${NC}"
                get_hash_input; return
            fi
            ;;
        10)
            read -p "$(echo -e ${WHITE}"NTLM hash file path দিন (hashdump output): "${NC})" HASH_FILE
            if [ ! -f "$HASH_FILE" ]; then
                echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
                get_hash_input; return
            fi
            HASH_TYPE="NT"
            echo -e "  ${GREEN}[✓] NTLM hash file set।${NC}"
            ;;
        *)
            echo -e "${RED}[!] ভুল অপশন।${NC}"
            get_hash_input; return
            ;;
    esac

    echo ""
    echo -e "  ${GREEN}[✓] Hash input ready: $HASH_FILE${NC}"
    echo ""
}

# ================================================================
# AUTO DETECT HASH TYPE
# ================================================================
auto_detect_hash() {
    local hashfile=$1
    echo -e "${CYAN}[*] Hash type auto-detect করা হচ্ছে...${NC}"

    local sample
    sample=$(head -1 "$hashfile" 2>/dev/null | awk -F: '{print $NF}' | tr -d ' \n\r')
    [ -z "$sample" ] && sample=$(head -1 "$hashfile" 2>/dev/null | tr -d ' \n\r')

    local detected=""
    local len=${#sample}

    # Identify by length and prefix
    if [[ "$sample" == "\$y\$"* ]]; then
        detected="yescrypt"
    elif [[ "$sample" == "\$6\$"* ]]; then
        detected="sha512crypt"
    elif [[ "$sample" == "\$5\$"* ]]; then
        detected="sha256crypt"
    elif [[ "$sample" == "\$2y\$"* ]] || [[ "$sample" == "\$2a\$"* ]] || [[ "$sample" == "\$2b\$"* ]]; then
        detected="bcrypt"
    elif [[ "$sample" == "\$1\$"* ]]; then
        detected="md5crypt"
    elif [[ "$sample" == "\$apr1\$"* ]]; then
        detected="md5crypt-long"
    elif [[ "$sample" == "\$P\$"* ]] || [[ "$sample" == "\$H\$"* ]]; then
        detected="phpass"
    elif [[ "$sample" == "\$S\$"* ]]; then
        detected="drupal7"
    elif [[ "$sample" == "sha1\$"* ]]; then
        detected="django-sha1"
    elif [[ "$sample" == "pbkdf2_sha256\$"* ]]; then
        detected="django"
    elif [ $len -eq 32 ] && [[ "$sample" =~ ^[0-9a-fA-F]+$ ]]; then
        detected="Raw-MD5"
    elif [ $len -eq 40 ] && [[ "$sample" =~ ^[0-9a-fA-F]+$ ]]; then
        detected="Raw-SHA1"
    elif [ $len -eq 56 ] && [[ "$sample" =~ ^[0-9a-fA-F]+$ ]]; then
        detected="Raw-SHA224"
    elif [ $len -eq 64 ] && [[ "$sample" =~ ^[0-9a-fA-F]+$ ]]; then
        detected="Raw-SHA256"
    elif [ $len -eq 96 ] && [[ "$sample" =~ ^[0-9a-fA-F]+$ ]]; then
        detected="Raw-SHA384"
    elif [ $len -eq 128 ] && [[ "$sample" =~ ^[0-9a-fA-F]+$ ]]; then
        detected="Raw-SHA512"
    elif [ $len -eq 13 ] && [[ "$sample" =~ ^[a-zA-Z0-9./]+$ ]]; then
        detected="descrypt"
    elif [ $len -eq 7 ]; then
        detected="LM"
    elif [ $len -eq 65 ] && [[ "$sample" == *:* ]]; then
        detected="NT"
    fi

    if [ -n "$detected" ]; then
        echo -e "  ${GREEN}[✓] Detected: ${YELLOW}$detected${NC}"
        DETECTED_HASH_TYPE="$detected"
    else
        echo -e "  ${YELLOW}[!] Auto-detect সম্ভব হয়নি। Manual select করুন অথবা John auto-detect করুক।${NC}"
        DETECTED_HASH_TYPE=""
    fi
    echo ""
}

# ================================================================
# SELECT HASH TYPE MANUALLY
# ================================================================
select_hash_type() {
    echo -e "${RED}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║         HASH TYPE SELECT             ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC}  Auto detect (John নিজে বুঝবে)"
    echo -e "  ${GREEN}2)${NC}  MD5         ${DIM}(Raw-MD5) — 32 char hex${NC}"
    echo -e "  ${GREEN}3)${NC}  SHA1        ${DIM}(Raw-SHA1) — 40 char hex${NC}"
    echo -e "  ${GREEN}4)${NC}  SHA256      ${DIM}(Raw-SHA256) — 64 char hex${NC}"
    echo -e "  ${GREEN}5)${NC}  SHA512      ${DIM}(Raw-SHA512) — 128 char hex${NC}"
    echo -e "  ${GREEN}6)${NC}  bcrypt      ${DIM}(\$2a\$/\$2b\$/\$2y\$)${NC}"
    echo -e "  ${GREEN}7)${NC}  MD5Crypt    ${DIM}(\$1\$ — Linux MD5)${NC}"
    echo -e "  ${GREEN}8)${NC}  SHA512Crypt ${DIM}(\$6\$ — Linux SHA512)${NC}"
    echo -e "  ${GREEN}9)${NC}  SHA256Crypt ${DIM}(\$5\$ — Linux SHA256)${NC}"
    echo -e "  ${GREEN}10)${NC} NTLM        ${DIM}(Windows NT hash)${NC}"
    echo -e "  ${GREEN}11)${NC} LM          ${DIM}(Windows LAN Manager)${NC}"
    echo -e "  ${GREEN}12)${NC} phpass      ${DIM}(\$P\$/\$H\$ — WordPress/phpBB)${NC}"
    echo -e "  ${GREEN}13)${NC} WPA/WPA2    ${DIM}(WiFi handshake)${NC}"
    echo -e "  ${GREEN}14)${NC} MYSQL       ${DIM}(MySQL old password)${NC}"
    echo -e "  ${GREEN}15)${NC} MYSQL-SHA1  ${DIM}(MySQL SHA1 password)${NC}"
    echo -e "  ${GREEN}16)${NC} MSSQL       ${DIM}(Microsoft SQL Server)${NC}"
    echo -e "  ${GREEN}17)${NC} Oracle      ${DIM}(Oracle DB hash)${NC}"
    echo -e "  ${GREEN}18)${NC} Drupal7     ${DIM}(\$S\$)${NC}"
    echo -e "  ${GREEN}19)${NC} Django      ${DIM}(pbkdf2_sha256)${NC}"
    echo -e "  ${GREEN}20)${NC} Kerberos    ${DIM}(krb5tgs / krb5asrep)${NC}"
    echo -e "  ${GREEN}21)${NC} ZIP         ${DIM}(PKZIP / WinZip)${NC}"
    echo -e "  ${GREEN}22)${NC} RAR         ${DIM}(RAR3/RAR5)${NC}"
    echo -e "  ${GREEN}23)${NC} PDF         ${DIM}(PDF password)${NC}"
    echo -e "  ${GREEN}24)${NC} SSH         ${DIM}(SSH private key passphrase)${NC}"
    echo -e "  ${GREEN}25)${NC} GPG/PGP     ${DIM}(GPG passphrase)${NC}"
    echo -e "  ${GREEN}26)${NC} descrypt    ${DIM}(Traditional DES crypt)${NC}"
    echo -e "  ${GREEN}27)${NC} yescrypt    ${DIM}(\$y\$ — modern Linux)${NC}"
    echo -e "  ${GREEN}28)${NC} Custom      ${DIM}— নিজে format লিখুন${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-28]: "${NC})" htype_ch

    case $htype_ch in
        1)  HASH_TYPE="" ;;
        2)  HASH_TYPE="Raw-MD5" ;;
        3)  HASH_TYPE="Raw-SHA1" ;;
        4)  HASH_TYPE="Raw-SHA256" ;;
        5)  HASH_TYPE="Raw-SHA512" ;;
        6)  HASH_TYPE="bcrypt" ;;
        7)  HASH_TYPE="md5crypt" ;;
        8)  HASH_TYPE="sha512crypt" ;;
        9)  HASH_TYPE="sha256crypt" ;;
        10) HASH_TYPE="NT" ;;
        11) HASH_TYPE="LM" ;;
        12) HASH_TYPE="phpass" ;;
        13) HASH_TYPE="wpapsk" ;;
        14) HASH_TYPE="mysql" ;;
        15) HASH_TYPE="mysql-sha1" ;;
        16) HASH_TYPE="mssql" ;;
        17) HASH_TYPE="oracle11" ;;
        18) HASH_TYPE="drupal7" ;;
        19) HASH_TYPE="django" ;;
        20) HASH_TYPE="krb5tgs" ;;
        21) HASH_TYPE="PKZIP" ;;
        22) HASH_TYPE="rar5" ;;
        23) HASH_TYPE="PDF" ;;
        24) HASH_TYPE="SSH" ;;
        25) HASH_TYPE="gpg" ;;
        26) HASH_TYPE="descrypt" ;;
        27) HASH_TYPE="yescrypt" ;;
        28)
            read -p "$(echo -e ${WHITE}"Hash format দিন (e.g. Raw-MD5): "${NC})" HASH_TYPE
            ;;
        *) HASH_TYPE="" ;;
    esac

    [ -n "$HASH_TYPE" ] && echo -e "  ${GREEN}[✓] Hash type: $HASH_TYPE${NC}" || echo -e "  ${CYAN}[*] Auto-detect mode${NC}"
    echo ""
}

# ================================================================
# SCAN MENU
# ================================================================
show_menu() {
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║                 JOHN THE RIPPER — CRACK OPTIONS                     ║${NC}"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ WORDLIST ATTACK ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}1${NC}  Wordlist Attack (Default)    — rockyou.txt দিয়ে crack"
    echo -e "${YELLOW}║${NC} ${GREEN}2${NC}  Wordlist + Rules              — wordlist + mutation rules"
    echo -e "${YELLOW}║${NC} ${GREEN}3${NC}  Custom Wordlist               — নিজের wordlist দাও"
    echo -e "${YELLOW}║${NC} ${GREEN}4${NC}  Multiple Wordlists            — একাধিক wordlist একসাথে"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ BRUTE FORCE ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}5${NC}  Incremental (Full Brute)     — সব possible combination"
    echo -e "${YELLOW}║${NC} ${GREEN}6${NC}  Incremental Alpha            — শুধু অক্ষর (a-z)"
    echo -e "${YELLOW}║${NC} ${GREEN}7${NC}  Incremental Digits           — শুধু সংখ্যা (0-9)"
    echo -e "${YELLOW}║${NC} ${GREEN}8${NC}  Incremental AlphaNum         — অক্ষর + সংখ্যা"
    echo -e "${YELLOW}║${NC} ${GREEN}9${NC}  Custom Mask Attack            — নিজে pattern দাও"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ RULE-BASED ATTACK ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}10${NC} Single Crack Mode             — username থেকে password guess"
    echo -e "${YELLOW}║${NC} ${GREEN}11${NC} Rules: Jumbo                  — সবচেয়ে বড় ruleset"
    echo -e "${YELLOW}║${NC} ${GREEN}12${NC} Rules: KoreLogic              — CTF/competition rules"
    echo -e "${YELLOW}║${NC} ${GREEN}13${NC} Rules: Wordlist + Best64      — top 64 mutation rules"
    echo -e "${YELLOW}║${NC} ${GREEN}14${NC} Rules: d3ad0ne                — advanced mutation"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ SPECIAL MODES ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}15${NC} Loopback Mode                 — আগের cracked password দিয়ে আবার"
    echo -e "${YELLOW}║${NC} ${GREEN}16${NC} PRINCE Attack                 — word combination generator"
    echo -e "${YELLOW}║${NC} ${GREEN}17${NC} Markov Mode                   — statistical password guess"
    echo -e "${YELLOW}║${NC} ${GREEN}18${NC} External Mode                 — custom C function"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ SHOW / RESTORE / INFO ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}19${NC} Show Cracked Passwords        — crack হওয়া passwords দেখো"
    echo -e "${YELLOW}║${NC} ${GREEN}20${NC} Restore Session               — আগের session resume করো"
    echo -e "${YELLOW}║${NC} ${GREEN}21${NC} List Supported Formats        — সব supported hash format"
    echo -e "${YELLOW}║${NC} ${GREEN}22${NC} Benchmark                     — John এর speed test"
    echo -e "${YELLOW}║${NC} ${GREEN}23${NC} Auto-detect Hash & Crack      — সব auto, single command"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ COMBO ATTACKS ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}24${NC} Smart Combo Attack            — wordlist → rules → brute"
    echo -e "${YELLOW}║${NC} ${GREEN}25${NC} All-in-One Mega Crack         — সব method একসাথে"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${RED}0)${NC} Exit                                                               ${YELLOW}║${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ================================================================
# GET WORDLIST
# ================================================================
get_wordlist() {
    local prompt="${1:-Wordlist path দিন}"
    WORDLIST=""

    echo -e "${CYAN}[*] Wordlist select:${NC}"
    echo -e "  ${GREEN}1)${NC} Default (rockyou.txt বা John built-in)"
    echo -e "  ${GREEN}2)${NC} Custom path দিন"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-2]: "${NC})" wl_ch

    case $wl_ch in
        1)
            if [ -n "$DEFAULT_WORDLIST" ]; then
                WORDLIST="$DEFAULT_WORDLIST"
            elif [ -n "$JOHN_WORDLIST" ]; then
                WORDLIST="$JOHN_WORDLIST"
            else
                echo -e "${RED}[!] Default wordlist পাওয়া যায়নি। Custom path দিন।${NC}"
                read -p "$(echo -e ${WHITE}"Wordlist path: "${NC})" WORDLIST
            fi
            ;;
        2)
            read -p "$(echo -e ${WHITE}"$prompt: "${NC})" WORDLIST
            if [ ! -f "$WORDLIST" ]; then
                echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
                WORDLIST=""
                return 1
            fi
            ;;
    esac
    echo -e "  ${GREEN}[✓] Wordlist: $WORDLIST${NC}"
    echo ""
}

# ================================================================
# GET EXTRA OPTIONS
# ================================================================
get_extra_options() {
    THREADS_OPT=""
    SESSION_OPT=""
    MIN_LEN_OPT=""
    MAX_LEN_OPT=""
    POT_OPT=""

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║         EXTRA OPTIONS                ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""

    read -p "$(echo -e ${WHITE}"CPU Threads (Enter=auto): "${NC})" th_in
    [ -n "$th_in" ] && THREADS_OPT="--fork=$th_in"

    read -p "$(echo -e ${WHITE}"Session name (Enter=auto): "${NC})" sess_in
    if [ -n "$sess_in" ]; then
        SESSION_OPT="--session=$sess_in"
    else
        SESSION_OPT="--session=john_saimum_$(date +%Y%m%d_%H%M%S)"
    fi

    read -p "$(echo -e ${WHITE}"Min password length (Enter=skip): "${NC})" minl_in
    [ -n "$minl_in" ] && MIN_LEN_OPT="--min-length=$minl_in"

    read -p "$(echo -e ${WHITE}"Max password length (Enter=skip): "${NC})" maxl_in
    [ -n "$maxl_in" ] && MAX_LEN_OPT="--max-length=$maxl_in"

    read -p "$(echo -e ${WHITE}"Custom pot file (Enter=default): "${NC})" pot_in
    [ -n "$pot_in" ] && POT_OPT="--pot=$pot_in"

    echo ""
}

# ================================================================
# BUILD AND RUN JOHN
# ================================================================
run_john() {
    local mode_label=$1
    local john_args=$2

    local ts
    ts=$(date +"%Y%m%d_%H%M%S")
    local safe
    safe=$(basename "$HASH_FILE" | sed 's/[^a-zA-Z0-9._-]/_/g')
    OUTPUT_FILE="$RESULTS_DIR/john_${safe}_${ts}.txt"
    SCAN_LABEL="$mode_label"

    # Build type flag
    local type_flag=""
    [ -n "$HASH_TYPE" ] && type_flag="--format=$HASH_TYPE"

    local full_cmd="$JOHN_CMD $type_flag $SESSION_OPT $THREADS_OPT $MIN_LEN_OPT $MAX_LEN_OPT $POT_OPT $john_args $HASH_FILE"

    # Preview
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}Mode      : ${YELLOW}${BOLD}$mode_label${NC}"
    echo -e "  ${WHITE}Hash File : ${GREEN}${BOLD}$HASH_FILE${NC}"
    echo -e "  ${WHITE}Hash Type : ${CYAN}${HASH_TYPE:-Auto-detect}${NC}"
    echo -e "  ${WHITE}Command   : ${CYAN}$full_cmd${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] Crack শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local tmp
    tmp=$(mktemp)

    echo ""
    echo -e "${GREEN}${BOLD}[*] John The Ripper চালু হচ্ছে...${NC}"
    echo -e "${YELLOW}[!] চলছে... বন্ধ করতে Ctrl+C (progress save হবে)${NC}"
    echo ""

    eval "$full_cmd" 2>&1 | tee "$tmp"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Crack session সম্পন্ন!${NC}"
    echo ""

    # Show cracked passwords
    show_cracked_passwords

    # Analysis
    bangla_analysis "$tmp"

    # Next tool suggestion
    suggest_next_tool "$tmp"

    # Save
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 1 — WORDLIST DEFAULT
# ================================================================
mode_wordlist_default() {
    get_wordlist
    [ -z "$WORDLIST" ] && return
    run_john "Wordlist Attack (Default)" "--wordlist=$WORDLIST"
}

# ================================================================
# MODE 2 — WORDLIST + RULES
# ================================================================
mode_wordlist_rules() {
    get_wordlist
    [ -z "$WORDLIST" ] && return

    echo -e "${CYAN}Rules select:${NC}"
    echo -e "  ${GREEN}1)${NC} All (সব rules)"
    echo -e "  ${GREEN}2)${NC} Jumbo"
    echo -e "  ${GREEN}3)${NC} Best64"
    echo -e "  ${GREEN}4)${NC} d3ad0ne"
    echo -e "  ${GREEN}5)${NC} KoreLogic"
    echo -e "  ${GREEN}6)${NC} Custom rule name"
    read -p "$(echo -e ${YELLOW}"Select [1-6]: "${NC})" rule_ch

    local rule=""
    case $rule_ch in
        1) rule="All" ;;
        2) rule="Jumbo" ;;
        3) rule="Best64" ;;
        4) rule="d3ad0ne" ;;
        5) rule="KoreLogic" ;;
        6) read -p "$(echo -e ${WHITE}"Rule name: "${NC})" rule ;;
        *) rule="All" ;;
    esac

    run_john "Wordlist + Rules ($rule)" "--wordlist=$WORDLIST --rules=$rule"
}

# ================================================================
# MODE 3 — CUSTOM WORDLIST
# ================================================================
mode_custom_wordlist() {
    read -p "$(echo -e ${WHITE}"Custom wordlist path দিন: "${NC})" custom_wl
    if [ ! -f "$custom_wl" ]; then
        echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
        return
    fi
    run_john "Custom Wordlist" "--wordlist=$custom_wl"
}

# ================================================================
# MODE 4 — MULTIPLE WORDLISTS
# ================================================================
mode_multiple_wordlists() {
    echo -e "${CYAN}Wordlist গুলো দিন (space দিয়ে আলাদা করুন বা একটা একটা করে):${NC}"
    local combined_wl="$RESULTS_DIR/combined_wordlist_$(date +%Y%m%d_%H%M%S).txt"

    echo -e "${WHITE}Wordlist paths দিন। শেষ হলে 'done' লিখুন:${NC}"
    while true; do
        read -p "$(echo -e ${WHITE}"Wordlist: "${NC})" wl_path
        [[ "$wl_path" == "done" || -z "$wl_path" ]] && break
        if [ -f "$wl_path" ]; then
            cat "$wl_path" >> "$combined_wl"
            echo -e "  ${GREEN}[✓] Added: $wl_path${NC}"
        else
            echo -e "  ${RED}[!] File পাওয়া যায়নি: $wl_path${NC}"
        fi
    done

    if [ ! -s "$combined_wl" ]; then
        echo -e "${RED}[!] কোনো wordlist যোগ হয়নি।${NC}"
        return
    fi

    echo -e "  ${GREEN}[✓] Combined wordlist: $combined_wl${NC}"
    run_john "Multiple Wordlists" "--wordlist=$combined_wl"
}

# ================================================================
# MODE 5 — INCREMENTAL FULL
# ================================================================
mode_incremental_full() {
    echo -e "${YELLOW}[!] এটি অনেক সময় নিতে পারে। Password complex হলে ঘণ্টার পর ঘণ্টা লাগতে পারে।${NC}"
    read -p "$(echo -e ${YELLOW}"নিশ্চিত? (y/n): "${NC})" confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && return
    run_john "Incremental — Full Brute Force" "--incremental"
}

# ================================================================
# MODE 6 — INCREMENTAL ALPHA
# ================================================================
mode_incremental_alpha() {
    run_john "Incremental — Alpha (a-z)" "--incremental=Alpha"
}

# ================================================================
# MODE 7 — INCREMENTAL DIGITS
# ================================================================
mode_incremental_digits() {
    run_john "Incremental — Digits (0-9)" "--incremental=Digits"
}

# ================================================================
# MODE 8 — INCREMENTAL ALPHANUM
# ================================================================
mode_incremental_alphanum() {
    run_john "Incremental — AlphaNum" "--incremental=LowerNum"
}

# ================================================================
# MODE 9 — CUSTOM MASK
# ================================================================
mode_custom_mask() {
    echo ""
    echo -e "${CYAN}Mask Placeholders:${NC}"
    echo -e "  ${WHITE}?l${NC} = lowercase (a-z)"
    echo -e "  ${WHITE}?u${NC} = uppercase (A-Z)"
    echo -e "  ${WHITE}?d${NC} = digit (0-9)"
    echo -e "  ${WHITE}?s${NC} = special (!@#\$...)"
    echo -e "  ${WHITE}?a${NC} = all printable"
    echo -e "${DIM}উদাহরণ: ?u?l?l?l?d?d = 1 uppercase + 3 lowercase + 2 digit${NC}"
    echo ""
    read -p "$(echo -e ${WHITE}"Mask দিন: "${NC})" mask_in

    if command -v hashcat &>/dev/null; then
        echo -e "${CYAN}[*] Mask attack এর জন্য hashcat বেশি efficient।${NC}"
        echo -e "${CYAN}    hashcat -a 3 -m <mode> $HASH_FILE $mask_in${NC}"
    fi

    # John mask via --mask
    run_john "Custom Mask ($mask_in)" "--mask=$mask_in"
}

# ================================================================
# MODE 10 — SINGLE CRACK
# ================================================================
mode_single_crack() {
    run_john "Single Crack Mode" "--single"
}

# ================================================================
# MODE 11 — RULES JUMBO
# ================================================================
mode_rules_jumbo() {
    get_wordlist
    [ -z "$WORDLIST" ] && return
    run_john "Rules: Jumbo" "--wordlist=$WORDLIST --rules=Jumbo"
}

# ================================================================
# MODE 12 — RULES KORELOGIC
# ================================================================
mode_rules_korelogic() {
    get_wordlist
    [ -z "$WORDLIST" ] && return
    run_john "Rules: KoreLogic" "--wordlist=$WORDLIST --rules=KoreLogic"
}

# ================================================================
# MODE 13 — RULES BEST64
# ================================================================
mode_rules_best64() {
    get_wordlist
    [ -z "$WORDLIST" ] && return
    run_john "Rules: Best64" "--wordlist=$WORDLIST --rules=Best64"
}

# ================================================================
# MODE 14 — RULES D3AD0NE
# ================================================================
mode_rules_d3ad0ne() {
    get_wordlist
    [ -z "$WORDLIST" ] && return
    run_john "Rules: d3ad0ne" "--wordlist=$WORDLIST --rules=d3ad0ne"
}

# ================================================================
# MODE 15 — LOOPBACK
# ================================================================
mode_loopback() {
    local pot_file
    pot_file=$(find "$HOME/.john" /root/.john 2>/dev/null -name "john.pot" | head -1)
    if [ -z "$pot_file" ]; then
        echo -e "${YELLOW}[!] john.pot file পাওয়া যায়নি। আগে কিছু crack করুন।${NC}"
        read -p "$(echo -e ${WHITE}"Pot file path দিন: "${NC})" pot_file
        [ ! -f "$pot_file" ] && return
    fi
    echo -e "  ${GREEN}[✓] Pot file: $pot_file${NC}"
    run_john "Loopback Mode" "--loopback=$pot_file"
}

# ================================================================
# MODE 16 — PRINCE
# ================================================================
mode_prince() {
    get_wordlist
    [ -z "$WORDLIST" ] && return
    if $JOHN_CMD --list=subformats 2>&1 | grep -qi "prince"; then
        run_john "PRINCE Attack" "--prince=$WORDLIST"
    else
        echo -e "${YELLOW}[!] PRINCE mode আপনার John version এ নেই।${NC}"
        echo -e "${CYAN}Alternative: pp -o output.txt wordlist.txt → তারপর wordlist হিসেবে use করুন।${NC}"
    fi
}

# ================================================================
# MODE 17 — MARKOV
# ================================================================
mode_markov() {
    if $JOHN_CMD --list=subformats 2>&1 | grep -qi "markov"; then
        run_john "Markov Mode" "--markov"
    else
        echo -e "${YELLOW}[!] Markov mode আপনার John version এ নেই।${NC}"
        echo -e "${CYAN}Jumbo version install করুন: sudo apt install john${NC}"
    fi
}

# ================================================================
# MODE 18 — EXTERNAL
# ================================================================
mode_external() {
    echo -e "${CYAN}External mode — custom C function দিয়ে password generate।${NC}"
    echo -e "${DIM}john.conf এ [List.External:MyMode] section define করতে হবে।${NC}"
    read -p "$(echo -e ${WHITE}"External mode name দিন: "${NC})" ext_name
    run_john "External Mode ($ext_name)" "--external=$ext_name"
}

# ================================================================
# MODE 19 — SHOW CRACKED
# ================================================================
show_cracked_passwords() {
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║             Crack হওয়া Passwords                                    ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local type_flag=""
    [ -n "$HASH_TYPE" ] && type_flag="--format=$HASH_TYPE"

    local cracked
    cracked=$($JOHN_CMD $type_flag --show "$HASH_FILE" 2>/dev/null)

    if [ -n "$cracked" ]; then
        echo "$cracked" | while IFS= read -r line; do
            echo -e "  ${GREEN}▸ $line${NC}"
        done
    else
        echo -e "  ${YELLOW}[!] এখনো কোনো password crack হয়নি।${NC}"
    fi
    echo ""
}

# ================================================================
# MODE 20 — RESTORE SESSION
# ================================================================
mode_restore_session() {
    echo ""
    echo -e "${CYAN}Available sessions:${NC}"
    find "$HOME/.john" /root/.john 2>/dev/null -name "*.rec" | while IFS= read -r f; do
        echo -e "  ${GREEN}▸ $(basename "$f" .rec)${NC}"
    done
    echo ""
    read -p "$(echo -e ${WHITE}"Session name দিন (Enter=john_saimum): "${NC})" sess_name
    [ -z "$sess_name" ] && sess_name="john_saimum"

    echo ""
    echo -e "${GREEN}[*] Session restore করা হচ্ছে: $sess_name${NC}"
    $JOHN_CMD --restore="$sess_name" 2>&1
}

# ================================================================
# MODE 21 — LIST FORMATS
# ================================================================
mode_list_formats() {
    echo ""
    echo -e "${CYAN}[*] Supported hash formats:${NC}"
    echo ""
    $JOHN_CMD --list=formats 2>&1 | tr ',' '\n' | while IFS= read -r fmt; do
        fmt=$(echo "$fmt" | tr -d ' ')
        [ -n "$fmt" ] && echo -e "  ${GREEN}▸ $fmt${NC}"
    done
    echo ""
}

# ================================================================
# MODE 22 — BENCHMARK
# ================================================================
mode_benchmark() {
    local type_flag=""
    [ -n "$HASH_TYPE" ] && type_flag="--format=$HASH_TYPE"

    echo ""
    echo -e "${CYAN}[*] John benchmark চালানো হচ্ছে...${NC}"
    echo ""
    $JOHN_CMD --test $type_flag 2>&1 | head -30
}

# ================================================================
# MODE 23 — AUTO DETECT AND CRACK
# ================================================================
mode_auto_crack() {
    auto_detect_hash "$HASH_FILE"
    [ -n "$DETECTED_HASH_TYPE" ] && HASH_TYPE="$DETECTED_HASH_TYPE"

    get_wordlist
    [ -z "$WORDLIST" ] && WORDLIST="$JOHN_WORDLIST"

    local args="--wordlist=$WORDLIST"
    [ -n "$WORDLIST" ] || args="--incremental"

    run_john "Auto-detect & Crack" "$args"
}

# ================================================================
# MODE 24 — SMART COMBO ATTACK
# ================================================================
mode_smart_combo() {
    get_wordlist
    [ -z "$WORDLIST" ] && return

    echo ""
    echo -e "${CYAN}${BOLD}[*] Smart Combo Attack — ৩ ধাপে crack করব:${NC}"
    echo -e "    ${WHITE}Step 1: Wordlist attack${NC}"
    echo -e "    ${WHITE}Step 2: Wordlist + Best64 rules${NC}"
    echo -e "    ${WHITE}Step 3: Wordlist + Jumbo rules${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local type_flag=""
    [ -n "$HASH_TYPE" ] && type_flag="--format=$HASH_TYPE"
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(basename "$HASH_FILE" | sed 's/[^a-zA-Z0-9._-]/_/g')
    OUTPUT_FILE="$RESULTS_DIR/john_combo_${safe}_${ts}.txt"
    SCAN_LABEL="Smart Combo Attack"

    local tmp; tmp=$(mktemp)

    echo -e "${CYAN}━━━ Step 1: Wordlist Attack ━━━${NC}"
    $JOHN_CMD $type_flag $THREADS_OPT $MIN_LEN_OPT $MAX_LEN_OPT \
        --wordlist="$WORDLIST" "$HASH_FILE" 2>&1 | tee -a "$tmp"

    echo ""
    echo -e "${CYAN}━━━ Step 2: Wordlist + Best64 ━━━${NC}"
    $JOHN_CMD $type_flag $THREADS_OPT $MIN_LEN_OPT $MAX_LEN_OPT \
        --wordlist="$WORDLIST" --rules=Best64 "$HASH_FILE" 2>&1 | tee -a "$tmp"

    echo ""
    echo -e "${CYAN}━━━ Step 3: Wordlist + Jumbo ━━━${NC}"
    $JOHN_CMD $type_flag $THREADS_OPT $MIN_LEN_OPT $MAX_LEN_OPT \
        --wordlist="$WORDLIST" --rules=Jumbo "$HASH_FILE" 2>&1 | tee -a "$tmp"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Smart Combo Attack সম্পন্ন!${NC}"

    show_cracked_passwords
    bangla_analysis "$tmp"
    suggest_next_tool "$tmp"
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 25 — ALL IN ONE MEGA CRACK
# ================================================================
mode_allinone() {
    echo ""
    echo -e "${RED}${BOLD}[!] All-in-One Mega Crack — সব method একসাথে চালাবে।${NC}"
    echo -e "${YELLOW}[!] এটি অনেক সময় নিতে পারে।${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    # Auto detect
    auto_detect_hash "$HASH_FILE"
    [ -n "$DETECTED_HASH_TYPE" ] && HASH_TYPE="$DETECTED_HASH_TYPE"

    local type_flag=""
    [ -n "$HASH_TYPE" ] && type_flag="--format=$HASH_TYPE"
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(basename "$HASH_FILE" | sed 's/[^a-zA-Z0-9._-]/_/g')
    OUTPUT_FILE="$RESULTS_DIR/john_MEGA_${safe}_${ts}.txt"
    SCAN_LABEL="All-in-One Mega Crack"

    local tmp; tmp=$(mktemp)
    local wl="${DEFAULT_WORDLIST:-$JOHN_WORDLIST}"

    echo -e "${CYAN}━━━ Phase 1: Single Crack ━━━${NC}"
    $JOHN_CMD $type_flag $THREADS_OPT --single "$HASH_FILE" 2>&1 | tee -a "$tmp"

    if [ -n "$wl" ]; then
        echo -e "${CYAN}━━━ Phase 2: Wordlist ━━━${NC}"
        $JOHN_CMD $type_flag $THREADS_OPT --wordlist="$wl" "$HASH_FILE" 2>&1 | tee -a "$tmp"

        echo -e "${CYAN}━━━ Phase 3: Wordlist + Best64 ━━━${NC}"
        $JOHN_CMD $type_flag $THREADS_OPT --wordlist="$wl" --rules=Best64 "$HASH_FILE" 2>&1 | tee -a "$tmp"

        echo -e "${CYAN}━━━ Phase 4: Wordlist + Jumbo ━━━${NC}"
        $JOHN_CMD $type_flag $THREADS_OPT --wordlist="$wl" --rules=Jumbo "$HASH_FILE" 2>&1 | tee -a "$tmp"

        echo -e "${CYAN}━━━ Phase 5: Wordlist + KoreLogic ━━━${NC}"
        $JOHN_CMD $type_flag $THREADS_OPT --wordlist="$wl" --rules=KoreLogic "$HASH_FILE" 2>&1 | tee -a "$tmp"
    fi

    echo -e "${CYAN}━━━ Phase 6: Incremental Digits ━━━${NC}"
    timeout 120 $JOHN_CMD $type_flag $THREADS_OPT --incremental=Digits "$HASH_FILE" 2>&1 | tee -a "$tmp"

    echo -e "${CYAN}━━━ Phase 7: Incremental Alpha ━━━${NC}"
    timeout 120 $JOHN_CMD $type_flag $THREADS_OPT --incremental=Alpha "$HASH_FILE" 2>&1 | tee -a "$tmp"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] All-in-One Mega Crack সম্পন্ন!${NC}"

    show_cracked_passwords
    bangla_analysis "$tmp"
    suggest_next_tool "$tmp"
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# BANGLA ANALYSIS
# ================================================================
bangla_analysis() {
    local outfile=$1

    echo ""
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║             বাংলায় ফলাফল বিশ্লেষণ                                 ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local type_flag=""
    [ -n "$HASH_TYPE" ] && type_flag="--format=$HASH_TYPE"

    # Count cracked
    local cracked_count=0
    local total_count=0

    cracked_count=$($JOHN_CMD $type_flag --show "$HASH_FILE" 2>/dev/null | grep -c ":" || echo 0)
    total_count=$(grep -c "" "$HASH_FILE" 2>/dev/null || echo 0)

    local remaining=$((total_count - cracked_count))
    [ "$remaining" -lt 0 ] && remaining=0

    echo -e "  ${CYAN}${BOLD}━━━ Crack পরিসংখ্যান ━━━${NC}"
    echo -e "  ${WHITE}মোট Hash       : ${CYAN}$total_count${NC}"
    echo -e "  ${GREEN}Crack হয়েছে   : $cracked_count${NC}"
    echo -e "  ${RED}Crack হয়নি    : $remaining${NC}"
    echo ""

    if [ "$cracked_count" -gt 0 ]; then
        local crack_rate=0
        [ "$total_count" -gt 0 ] && crack_rate=$((cracked_count * 100 / total_count))

        echo -e "  ${GREEN}${BOLD}✅ $cracked_count টি password crack হয়েছে! ($crack_rate%)${NC}"
        echo ""

        # Analyze cracked passwords quality
        local cracked_list
        cracked_list=$($JOHN_CMD $type_flag --show "$HASH_FILE" 2>/dev/null | grep ":" | awk -F: '{print $2}')

        if [ -n "$cracked_list" ]; then
            echo -e "  ${CYAN}${BOLD}━━━ Password দুর্বলতা বিশ্লেষণ ━━━${NC}"
            echo ""

            local weak_count=0
            local medium_count=0
            local strong_count=0

            while IFS= read -r passwd; do
                local plen=${#passwd}
                local has_upper has_lower has_digit has_special
                has_upper=$(echo "$passwd" | grep -c '[A-Z]')
                has_lower=$(echo "$passwd" | grep -c '[a-z]')
                has_digit=$(echo "$passwd" | grep -c '[0-9]')
                has_special=$(echo "$passwd" | grep -c '[^a-zA-Z0-9]')

                local complexity=$((has_upper + has_lower + has_digit + has_special))

                if [ "$plen" -lt 8 ] || [ "$complexity" -le 1 ]; then
                    weak_count=$((weak_count + 1))
                elif [ "$plen" -lt 12 ] || [ "$complexity" -le 2 ]; then
                    medium_count=$((medium_count + 1))
                else
                    strong_count=$((strong_count + 1))
                fi
            done <<< "$cracked_list"

            echo -e "  ${RED}   অত্যন্ত দুর্বল Password : $weak_count টি${NC}"
            echo -e "     ${DIM}→ ৮ অক্ষরের কম বা শুধু এক ধরনের character${NC}"
            echo -e "  ${YELLOW}   মাঝারি দুর্বল Password  : $medium_count টি${NC}"
            echo -e "     ${DIM}→ ৮-১২ অক্ষর, সীমিত variety${NC}"
            echo -e "  ${GREEN}   তুলনামূলক শক্তিশালী     : $strong_count টি${NC}"
            echo -e "     ${DIM}→ ১২+ অক্ষর, mixed character (তবু crack হয়েছে!)${NC}"
            echo ""

            # Common password check
            local common_passwords=("password" "123456" "admin" "letmein" "qwerty" "welcome" "monkey" "dragon")
            local found_common=false
            for cp in "${common_passwords[@]}"; do
                if echo "$cracked_list" | grep -qi "^${cp}$"; then
                    echo -e "  ${RED}${BOLD}⚠ Common password পাওয়া গেছে: '$cp'${NC}"
                    found_common=true
                fi
            done
            $found_common && echo ""

            # Risk assessment
            echo -e "  ${CYAN}${BOLD}━━━ সামগ্রিক ঝুঁকি মূল্যায়ন ━━━${NC}"
            if [ "$crack_rate" -ge 75 ]; then
                echo -e "  ${RED}${BOLD}  সার্বিক ঝুঁকি : ██████████ CRITICAL — বেশিরভাগ password দুর্বল!${NC}"
                echo -e "  ${RED}→ Password policy অবিলম্বে শক্তিশালী করুন।${NC}"
            elif [ "$crack_rate" -ge 40 ]; then
                echo -e "  ${YELLOW}${BOLD}  সার্বিক ঝুঁকি : ███████░░░ HIGH — অনেক password সহজেই crack হয়েছে।${NC}"
                echo -e "  ${YELLOW}→ Password reset করুন ও complexity enforce করুন।${NC}"
            elif [ "$crack_rate" -ge 10 ]; then
                echo -e "  ${CYAN}  সার্বিক ঝুঁকি : █████░░░░░ MEDIUM — কিছু password দুর্বল।${NC}"
                echo -e "  ${CYAN}→ দুর্বল password গুলো reset করুন।${NC}"
            else
                echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW — বেশিরভাগ password শক্তিশালী।${NC}"
            fi
        fi
    else
        echo -e "  ${YELLOW}[!] এখনো কোনো password crack হয়নি।${NC}"
        echo ""

        # Check why it failed
        if grep -qi "No password hashes loaded" "$outfile" 2>/dev/null; then
            echo -e "  ${RED}[!] Hash load হয়নি — hash format সঠিক কিনা দেখুন।${NC}"
            echo -e "  ${CYAN}→ john --list=formats দিয়ে সঠিক format খুঁজুন।${NC}"
        elif grep -qi "No\|0g\|Remaining" "$outfile" 2>/dev/null; then
            echo -e "  ${CYAN}[*] কারণ হতে পারে:${NC}"
            echo -e "     ${WHITE}→ Wordlist এ password নেই — বড় wordlist try করুন।${NC}"
            echo -e "     ${WHITE}→ Password complex — Rules যোগ করুন।${NC}"
            echo -e "     ${WHITE}→ Hash type ভুল — --format দিয়ে সঠিক type দিন।${NC}"
            echo -e "     ${WHITE}→ Hash strong (bcrypt) — Hashcat GPU দিয়ে try করুন।${NC}"
        fi
        echo -e "  ${CYAN}→ ঝুঁকি: LOW (password শক্তিশালী হতে পারে)${NC}"
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

    local type_flag=""
    [ -n "$HASH_TYPE" ] && type_flag="--format=$HASH_TYPE"
    local cracked_count
    cracked_count=$($JOHN_CMD $type_flag --show "$HASH_FILE" 2>/dev/null | grep -c ":" || echo 0)

    if [ "$cracked_count" -gt 0 ]; then
        echo -e "  ${GREEN}${BOLD}✅ Password পাওয়া গেছে — এখন কী করবেন:${NC}"
        echo ""

        echo -e "  ${RED}${BOLD}🔑 Hydra${NC} — Cracked Password দিয়ে Login Test"
        echo -e "     ${WHITE}কারণ: Cracked password দিয়ে SSH/FTP/Web login test করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: hydra -l <user> -p <cracked_pass> ssh://<target>${NC}"
        echo ""

        echo -e "  ${MAGENTA}${BOLD}💀 Metasploit${NC} — Credential Use করে Exploit"
        echo -e "     ${WHITE}কারণ: Valid credential দিয়ে system access নেওয়ার চেষ্টা করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: msfconsole → use auxiliary/scanner/ssh/ssh_login${NC}"
        echo ""

        if grep -qi "NT\|NTLM\|sam\|hashdump" "$outfile" 2>/dev/null; then
            echo -e "  ${RED}${BOLD}🏴 Pass-the-Hash (PTH)${NC} — NTLM Hash সরাসরি use করুন"
            echo -e "     ${WHITE}কারণ: NTLM crack না হলেও hash দিয়েই login সম্ভব।${NC}"
            echo -e "     ${CYAN}কমান্ড: pth-winexe -U 'domain/user%hash' //<target> cmd.exe${NC}"
            echo ""
        fi
    else
        echo -e "  ${CYAN}${BOLD}Crack না হলে চেষ্টা করুন:${NC}"
        echo ""

        echo -e "  ${YELLOW}${BOLD}⚡ Hashcat${NC} — GPU-based Password Cracking"
        echo -e "     ${WHITE}কারণ: GPU দিয়ে John এর চেয়ে অনেক দ্রুত crack করে।${NC}"
        echo -e "     ${CYAN}কমান্ড: hashcat -a 0 -m <mode> $HASH_FILE $DEFAULT_WORDLIST${NC}"
        echo ""

        echo -e "  ${BLUE}${BOLD}📚 CeWL${NC} — Target Website থেকে Custom Wordlist"
        echo -e "     ${WHITE}কারণ: Target specific শব্দ দিয়ে wordlist বানান।${NC}"
        echo -e "     ${CYAN}কমান্ড: cewl http://target.com -d 3 -m 5 -o custom_wordlist.txt${NC}"
        echo ""

        echo -e "  ${GREEN}${BOLD}📝 Crunch${NC} — Custom Pattern Wordlist Generator"
        echo -e "     ${WHITE}কারণ: Pattern জানলে targeted wordlist বানান।${NC}"
        echo -e "     ${CYAN}কমান্ড: crunch 8 12 abcdefghijklmnopqrstuvwxyz0123456789 -o wordlist.txt${NC}"
        echo ""

        echo -e "  ${MAGENTA}${BOLD}🔍 Mentalist / CUPP${NC} — Social Engineering Wordlist"
        echo -e "     ${WHITE}কারণ: Target সম্পর্কে জানা তথ্য দিয়ে wordlist বানান।${NC}"
        echo -e "     ${CYAN}কমান্ড: python3 cupp.py -i${NC}"
        echo ""
    fi

    echo -e "  ${WHITE}${BOLD}🗃️  Hashcat Modes Reference:${NC}"
    echo -e "     ${DIM}MD5=0, SHA1=100, SHA256=1400, SHA512=1700, NTLM=1000${NC}"
    echo -e "     ${DIM}bcrypt=3200, WPA=22000, SHA512crypt=1800, MD5crypt=500${NC}"
    echo ""
}

# ================================================================
# SAVE RESULTS
# ================================================================
save_results() {
    local tmp=$1

    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Result save করবেন? (y/n): "${NC})" sc
    if [[ "$sc" =~ ^[Yy]$ ]]; then
        local fname="${OUTPUT_FILE:-$RESULTS_DIR/john_result_$(date +%Y%m%d_%H%M%S).txt}"
        local type_flag=""
        [ -n "$HASH_TYPE" ] && type_flag="--format=$HASH_TYPE"

        {
            echo "============================================================"
            echo "  JOHN THE RIPPER RESULTS  —  SAIMUM's John Automation Tool"
            echo "  Hash File : $HASH_FILE"
            echo "  Hash Type : ${HASH_TYPE:-Auto-detect}"
            echo "  Mode      : ${SCAN_LABEL:-custom}"
            echo "  Date      : $(date)"
            echo "============================================================"
            echo ""
            echo "=== JOHN RAW OUTPUT ==="
            cat "$tmp"
            echo ""
            echo "=== CRACKED PASSWORDS ==="
            $JOHN_CMD $type_flag --show "$HASH_FILE" 2>/dev/null
            echo ""
        } > "$fname"

        echo -e "${GREEN}[✓] Saved → $fname${NC}"
        echo "$(date) | ${SCAN_LABEL:-custom} | $HASH_FILE | $fname" >> "$HISTORY_FILE"
    fi
    echo ""
}

# ================================================================
# MAIN LOOP
# ================================================================
main() {
    show_banner
    check_deps

    while true; do
        # Get hash input
        get_hash_input

        # Auto detect hash type
        if [ -n "$HASH_FILE" ] && [ -f "$HASH_FILE" ]; then
            auto_detect_hash "$HASH_FILE"
            [ -n "$DETECTED_HASH_TYPE" ] && HASH_TYPE="$DETECTED_HASH_TYPE"
        fi

        # Manual hash type selection
        echo -e "${CYAN}Hash type manually select করবেন?${NC}"
        read -p "$(echo -e ${YELLOW}"(y=manual select / n=use auto / Enter=use auto): "${NC})" manual_ch
        if [[ "$manual_ch" =~ ^[Yy]$ ]]; then
            select_hash_type
        fi

        # Extra options
        get_extra_options

        # Show menu
        show_menu
        read -p "$(echo -e ${YELLOW}"[?] Crack option select করুন [0-25]: "${NC})" choice

        if [[ "$choice" == "0" ]]; then
            echo ""
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            echo ""
            exit 0
        fi

        case $choice in
            1)  mode_wordlist_default ;;
            2)  mode_wordlist_rules ;;
            3)  mode_custom_wordlist ;;
            4)  mode_multiple_wordlists ;;
            5)  mode_incremental_full ;;
            6)  mode_incremental_alpha ;;
            7)  mode_incremental_digits ;;
            8)  mode_incremental_alphanum ;;
            9)  mode_custom_mask ;;
            10) mode_single_crack ;;
            11) mode_rules_jumbo ;;
            12) mode_rules_korelogic ;;
            13) mode_rules_best64 ;;
            14) mode_rules_d3ad0ne ;;
            15) mode_loopback ;;
            16) mode_prince ;;
            17) mode_markov ;;
            18) mode_external ;;
            19) show_cracked_passwords ;;
            20) mode_restore_session ;;
            21) mode_list_formats ;;
            22) mode_benchmark ;;
            23) mode_auto_crack ;;
            24) mode_smart_combo ;;
            25) mode_allinone ;;
            *)  echo -e "${RED}[!] ভুল অপশন।${NC}" ;;
        esac

        echo ""
        read -p "$(echo -e ${YELLOW}"[?] আরেকটি crack করবেন? (y/n): "${NC})" again
        [[ ! "$again" =~ ^[Yy]$ ]] && {
            echo ""
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            echo ""
            exit 0
        }
        unset HASH_FILE HASH_TYPE DETECTED_HASH_TYPE
        show_banner
    done
}

main
