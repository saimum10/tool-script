#!/bin/bash

# ================================================================
#   HASHCAT - Full Automation Tool
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

RESULTS_DIR="$HOME/hashcat_results"
HISTORY_FILE="$HOME/.hashcat_saimum_history.log"
mkdir -p "$RESULTS_DIR"

# ================================================================
# BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${MAGENTA}${BOLD}"
    echo ' ██╗  ██╗ █████╗ ███████╗██╗  ██╗ ██████╗ █████╗ ████████╗'
    echo ' ██║  ██║██╔══██╗██╔════╝██║  ██║██╔════╝██╔══██╗╚══██╔══╝'
    echo ' ███████║███████║███████╗███████║██║     ███████║   ██║   '
    echo ' ██╔══██║██╔══██║╚════██║██╔══██║██║     ██╔══██║   ██║   '
    echo ' ██║  ██║██║  ██║███████║██║  ██║╚██████╗██║  ██║   ██║   '
    echo ' ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   '
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}    ╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}    ║                    S A I M U M                        ║${NC}"
    echo -e "${YELLOW}${BOLD}    ╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${DIM}${WHITE}         Hashcat Full Automation Tool | GPU Password Cracker${NC}"
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

    if command -v hashcat &>/dev/null; then
        echo -e "  ${GREEN}[✓] hashcat — found${NC}"
    else
        missing+=("hashcat")
        echo -e "  ${RED}[✗] hashcat — পাওয়া যায়নি${NC}"
    fi

    for tool in curl file; do
        if command -v "$tool" &>/dev/null; then
            echo -e "  ${GREEN}[✓] $tool${NC}"
        else
            missing+=("$tool")
            echo -e "  ${RED}[✗] $tool — পাওয়া যায়নি${NC}"
        fi
    done

    # GPU check
    echo ""
    echo -e "${CYAN}[*] GPU / Device চেক করা হচ্ছে...${NC}"
    if command -v nvidia-smi &>/dev/null; then
        local gpu_info
        gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1)
        echo -e "  ${GREEN}[✓] NVIDIA GPU: $gpu_info${NC}"
        GPU_AVAILABLE=true
    elif command -v rocm-smi &>/dev/null; then
        echo -e "  ${GREEN}[✓] AMD GPU (ROCm) detected${NC}"
        GPU_AVAILABLE=true
    else
        echo -e "  ${YELLOW}[!] Dedicated GPU পাওয়া যায়নি — CPU mode চলবে (ধীর)${NC}"
        GPU_AVAILABLE=false
    fi

    # Optional tools
    echo ""
    echo -e "${CYAN}[*] Optional tools:${NC}"
    for opt in john hcxtools hcxdumptool; do
        if command -v "$opt" &>/dev/null; then
            echo -e "  ${GREEN}[✓] $opt — available${NC}"
        else
            echo -e "  ${YELLOW}[!] $opt — নেই (optional)${NC}"
        fi
    done

    # Wordlist check
    echo ""
    echo -e "${CYAN}[*] Wordlist চেক করা হচ্ছে...${NC}"
    local wordlists=(
        "/usr/share/wordlists/rockyou.txt"
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
    [ -z "$DEFAULT_WORDLIST" ] && echo -e "  ${YELLOW}[!] Default wordlist পাওয়া যায়নি।${NC}"

    # Hashcat rules check
    echo ""
    echo -e "${CYAN}[*] Hashcat rules চেক করা হচ্ছে...${NC}"
    local rule_dirs=("/usr/share/hashcat/rules" "$HOME/.hashcat/rules" "/usr/local/share/hashcat/rules")
    RULES_DIR=""
    for rd in "${rule_dirs[@]}"; do
        if [ -d "$rd" ]; then
            RULES_DIR="$rd"
            echo -e "  ${GREEN}[✓] Rules dir: $rd${NC}"
            break
        fi
    done
    [ -z "$RULES_DIR" ] && echo -e "  ${YELLOW}[!] Rules directory পাওয়া যায়নি।${NC}"

    if [ ${#missing[@]} -ne 0 ]; then
        echo ""
        echo -e "${RED}[!] Missing: ${missing[*]}${NC}"
        echo -e "${YELLOW}Install করুন: sudo apt install hashcat${NC}"
        exit 1
    fi

    # Hashcat version
    echo ""
    local hver
    hver=$(hashcat --version 2>&1 | head -1)
    echo -e "${CYAN}[*] Hashcat version: ${GREEN}$hver${NC}"
    echo ""
}

# ================================================================
# HASH MODE REFERENCE TABLE
# ================================================================
show_hash_modes() {
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                  HASHCAT HASH MODE REFERENCE                        ║${NC}"
    echo -e "${CYAN}${BOLD}╠══════════╦═══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}Mode (-m)${NC} ${CYAN}║${NC} ${WHITE}Hash Type${NC}"
    echo -e "${CYAN}${BOLD}╠══════════╬═══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}0${NC}         ${CYAN}║${NC} MD5"
    echo -e "${CYAN}║${NC} ${GREEN}100${NC}       ${CYAN}║${NC} SHA1"
    echo -e "${CYAN}║${NC} ${GREEN}1400${NC}      ${CYAN}║${NC} SHA256"
    echo -e "${CYAN}║${NC} ${GREEN}1700${NC}      ${CYAN}║${NC} SHA512"
    echo -e "${CYAN}║${NC} ${GREEN}900${NC}       ${CYAN}║${NC} MD4"
    echo -e "${CYAN}║${NC} ${GREEN}1000${NC}      ${CYAN}║${NC} NTLM (Windows)"
    echo -e "${CYAN}║${NC} ${GREEN}3000${NC}      ${CYAN}║${NC} LM (Windows)"
    echo -e "${CYAN}║${NC} ${GREEN}500${NC}       ${CYAN}║${NC} MD5crypt (\$1\$ — Linux)"
    echo -e "${CYAN}║${NC} ${GREEN}1800${NC}      ${CYAN}║${NC} SHA512crypt (\$6\$ — Linux)"
    echo -e "${CYAN}║${NC} ${GREEN}7400${NC}      ${CYAN}║${NC} SHA256crypt (\$5\$ — Linux)"
    echo -e "${CYAN}║${NC} ${GREEN}3200${NC}      ${CYAN}║${NC} bcrypt (\$2a\$/\$2b\$/\$2y\$)"
    echo -e "${CYAN}║${NC} ${GREEN}400${NC}       ${CYAN}║${NC} phpass (WordPress/phpBB)"
    echo -e "${CYAN}║${NC} ${GREEN}22000${NC}     ${CYAN}║${NC} WPA-PBKDF2-PMKID+EAPOL (WiFi)"
    echo -e "${CYAN}║${NC} ${GREEN}2500${NC}      ${CYAN}║${NC} WPA/WPA2 (legacy .hccapx)"
    echo -e "${CYAN}║${NC} ${GREEN}13400${NC}     ${CYAN}║${NC} KeePass"
    echo -e "${CYAN}║${NC} ${GREEN}13100${NC}     ${CYAN}║${NC} Kerberos TGS-REP (krb5tgs)"
    echo -e "${CYAN}║${NC} ${GREEN}18200${NC}     ${CYAN}║${NC} Kerberos AS-REP (krb5asrep)"
    echo -e "${CYAN}║${NC} ${GREEN}5500${NC}      ${CYAN}║${NC} NetNTLMv1"
    echo -e "${CYAN}║${NC} ${GREEN}5600${NC}      ${CYAN}║${NC} NetNTLMv2"
    echo -e "${CYAN}║${NC} ${GREEN}1500${NC}      ${CYAN}║${NC} descrypt (DES)"
    echo -e "${CYAN}║${NC} ${GREEN}300${NC}       ${CYAN}║${NC} MySQL4.1/MySQL5+ SHA1"
    echo -e "${CYAN}║${NC} ${GREEN}1441${NC}      ${CYAN}║${NC} Episerver SID"
    echo -e "${CYAN}║${NC} ${GREEN}12${NC}        ${CYAN}║${NC} PostgreSQL"
    echo -e "${CYAN}║${NC} ${GREEN}131${NC}       ${CYAN}║${NC} MSSQL (2000)"
    echo -e "${CYAN}║${NC} ${GREEN}1731${NC}      ${CYAN}║${NC} MSSQL (2012/2014)"
    echo -e "${CYAN}║${NC} ${GREEN}7${NC}         ${CYAN}║${NC} IKE-PSK MD5"
    echo -e "${CYAN}║${NC} ${GREEN}8${NC}         ${CYAN}║${NC} IKE-PSK SHA1"
    echo -e "${CYAN}║${NC} ${GREEN}11300${NC}     ${CYAN}║${NC} Bitcoin/Litecoin wallet"
    echo -e "${CYAN}║${NC} ${GREEN}6211${NC}      ${CYAN}║${NC} TrueCrypt SHA512 + XTS 1024"
    echo -e "${CYAN}║${NC} ${GREEN}17200${NC}     ${CYAN}║${NC} PKZIP (Compressed)"
    echo -e "${CYAN}║${NC} ${GREEN}23001${NC}     ${CYAN}║${NC} SecureZIP AES-256"
    echo -e "${CYAN}║${NC} ${GREEN}9700${NC}      ${CYAN}║${NC} MS Office <= 2003 MD5"
    echo -e "${CYAN}║${NC} ${GREEN}9800${NC}      ${CYAN}║${NC} MS Office <= 2003 SHA1"
    echo -e "${CYAN}║${NC} ${GREEN}9400${NC}      ${CYAN}║${NC} MS Office 2007"
    echo -e "${CYAN}║${NC} ${GREEN}9500${NC}      ${CYAN}║${NC} MS Office 2010"
    echo -e "${CYAN}║${NC} ${GREEN}9600${NC}      ${CYAN}║${NC} MS Office 2013"
    echo -e "${CYAN}║${NC} ${GREEN}10400${NC}     ${CYAN}║${NC} PDF 1.1-1.3 (Acrobat 2-4)"
    echo -e "${CYAN}║${NC} ${GREEN}10500${NC}     ${CYAN}║${NC} PDF 1.4-1.6 (Acrobat 5-8)"
    echo -e "${CYAN}║${NC} ${GREEN}10600${NC}     ${CYAN}║${NC} PDF 1.7 Level 3"
    echo -e "${CYAN}║${NC} ${GREEN}10700${NC}     ${CYAN}║${NC} PDF 1.7 Level 8"
    echo -e "${CYAN}║${NC} ${GREEN}16200${NC}     ${CYAN}║${NC} Apple Secure Notes"
    echo -e "${CYAN}║${NC} ${GREEN}7100${NC}      ${CYAN}║${NC} macOS PBKDF2-SHA512"
    echo -e "${CYAN}${BOLD}╚══════════╩═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ================================================================
# GET HASH INPUT
# ================================================================
get_hash_input() {
    HASH_FILE=""
    HASH_MODE=""

    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║         HASH INPUT SELECT            ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Hash file দিন (.txt)"
    echo -e "  ${GREEN}2)${NC} Single hash manually টাইপ করুন"
    echo -e "  ${GREEN}3)${NC} /etc/shadow (Linux system hashes)"
    echo -e "  ${GREEN}4)${NC} Windows SAM/hashdump (NTLM)"
    echo -e "  ${GREEN}5)${NC} WiFi handshake (.cap/.hccapx/.22000)"
    echo -e "  ${GREEN}6)${NC} Kerberos ticket (.kirbi / TGS hash)"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-6]: "${NC})" inp_ch

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
                echo -e "${RED}[!] /etc/shadow নেই বা root permission দরকার।${NC}"
                get_hash_input; return
            fi
            HASH_FILE="$RESULTS_DIR/shadow_${ts}.txt"
            sudo grep -v ":\*\|:!" /etc/shadow | sudo awk -F: '$2 != "" {print $2}' > "$HASH_FILE" 2>/dev/null
            echo -e "  ${GREEN}[✓] Shadow hashes extracted: $HASH_FILE${NC}"
            ;;
        4)
            read -p "$(echo -e ${WHITE}"SAM/hashdump file path দিন: "${NC})" HASH_FILE
            if [ ! -f "$HASH_FILE" ]; then
                echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
                get_hash_input; return
            fi
            # Extract NTLM from hashdump format (user:id:LM:NT:::)
            local ntlm_file="$RESULTS_DIR/ntlm_hashes_${ts}.txt"
            awk -F: '{print $4}' "$HASH_FILE" | grep -E '^[a-fA-F0-9]{32}$' > "$ntlm_file" 2>/dev/null
            if [ -s "$ntlm_file" ]; then
                HASH_FILE="$ntlm_file"
                HASH_MODE="1000"
                echo -e "  ${GREEN}[✓] NTLM hashes extracted: $HASH_FILE${NC}"
            else
                echo -e "  ${YELLOW}[!] NTLM extract হয়নি — original file use করা হবে।${NC}"
            fi
            ;;
        5)
            read -p "$(echo -e ${WHITE}"WiFi capture file path দিন (.cap/.hccapx/.22000): "${NC})" cap_file
            if [ ! -f "$cap_file" ]; then
                echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
                get_hash_input; return
            fi
            # Convert if needed
            if [[ "$cap_file" == *.cap ]]; then
                if command -v hcxpcapngtool &>/dev/null; then
                    HASH_FILE="$RESULTS_DIR/wifi_hash_${ts}.22000"
                    hcxpcapngtool -o "$HASH_FILE" "$cap_file" 2>/dev/null
                    HASH_MODE="22000"
                    echo -e "  ${GREEN}[✓] WiFi hash converted: $HASH_FILE${NC}"
                elif command -v cap2hccapx &>/dev/null; then
                    HASH_FILE="$RESULTS_DIR/wifi_hash_${ts}.hccapx"
                    cap2hccapx "$cap_file" "$HASH_FILE" 2>/dev/null
                    HASH_MODE="2500"
                    echo -e "  ${GREEN}[✓] WiFi hash converted: $HASH_FILE${NC}"
                else
                    echo -e "${YELLOW}[!] hcxpcapngtool/cap2hccapx পাওয়া যায়নি।${NC}"
                    HASH_FILE="$cap_file"
                fi
            else
                HASH_FILE="$cap_file"
                [[ "$cap_file" == *.22000 ]] && HASH_MODE="22000"
                [[ "$cap_file" == *.hccapx ]] && HASH_MODE="2500"
            fi
            ;;
        6)
            read -p "$(echo -e ${WHITE}"Kerberos hash file path দিন: "${NC})" HASH_FILE
            if [ ! -f "$HASH_FILE" ]; then
                echo -e "${RED}[!] File পাওয়া যায়নি।${NC}"
                get_hash_input; return
            fi
            # Auto-detect TGS vs AS-REP
            if grep -q "\$krb5tgs\$" "$HASH_FILE" 2>/dev/null; then
                HASH_MODE="13100"
                echo -e "  ${GREEN}[✓] Kerberoasting (TGS) hash detected — mode 13100${NC}"
            elif grep -q "\$krb5asrep\$" "$HASH_FILE" 2>/dev/null; then
                HASH_MODE="18200"
                echo -e "  ${GREEN}[✓] AS-REP Roasting hash detected — mode 18200${NC}"
            fi
            ;;
        *)
            echo -e "${RED}[!] ভুল অপশন।${NC}"
            get_hash_input; return
            ;;
    esac

    echo ""
    echo -e "  ${GREEN}[✓] Hash file ready: $HASH_FILE${NC}"
    echo ""
}

# ================================================================
# AUTO DETECT HASH MODE
# ================================================================
auto_detect_mode() {
    local hashfile=$1
    echo -e "${CYAN}[*] Hash mode auto-detect করা হচ্ছে...${NC}"

    local sample
    sample=$(head -1 "$hashfile" 2>/dev/null | tr -d ' \n\r')
    local len=${#sample}
    local detected_mode=""
    local detected_name=""

    if [[ "$sample" == "\$y\$"* ]]; then
        detected_mode="400"; detected_name="yescrypt"
    elif [[ "$sample" == "\$6\$"* ]]; then
        detected_mode="1800"; detected_name="SHA512crypt"
    elif [[ "$sample" == "\$5\$"* ]]; then
        detected_mode="7400"; detected_name="SHA256crypt"
    elif [[ "$sample" == "\$2y\$"* ]] || [[ "$sample" == "\$2a\$"* ]] || [[ "$sample" == "\$2b\$"* ]]; then
        detected_mode="3200"; detected_name="bcrypt"
    elif [[ "$sample" == "\$1\$"* ]]; then
        detected_mode="500"; detected_name="MD5crypt"
    elif [[ "$sample" == "\$P\$"* ]] || [[ "$sample" == "\$H\$"* ]]; then
        detected_mode="400"; detected_name="phpass (WordPress)"
    elif [[ "$sample" == "\$apr1\$"* ]]; then
        detected_mode="1600"; detected_name="Apache MD5"
    elif [[ "$sample" == "\$krb5tgs\$"* ]]; then
        detected_mode="13100"; detected_name="Kerberos TGS-REP"
    elif [[ "$sample" == "\$krb5asrep\$"* ]]; then
        detected_mode="18200"; detected_name="Kerberos AS-REP"
    elif [[ "$sample" == "pbkdf2_sha256\$"* ]]; then
        detected_mode="10000"; detected_name="Django PBKDF2"
    elif [ $len -eq 32 ] && [[ "$sample" =~ ^[0-9a-fA-F]+$ ]]; then
        detected_mode="0"; detected_name="MD5"
    elif [ $len -eq 40 ] && [[ "$sample" =~ ^[0-9a-fA-F]+$ ]]; then
        detected_mode="100"; detected_name="SHA1"
    elif [ $len -eq 56 ] && [[ "$sample" =~ ^[0-9a-fA-F]+$ ]]; then
        detected_mode="1300"; detected_name="SHA224"
    elif [ $len -eq 64 ] && [[ "$sample" =~ ^[0-9a-fA-F]+$ ]]; then
        detected_mode="1400"; detected_name="SHA256"
    elif [ $len -eq 96 ] && [[ "$sample" =~ ^[0-9a-fA-F]+$ ]]; then
        detected_mode="10800"; detected_name="SHA384"
    elif [ $len -eq 128 ] && [[ "$sample" =~ ^[0-9a-fA-F]+$ ]]; then
        detected_mode="1700"; detected_name="SHA512"
    elif [ $len -eq 13 ] && [[ "$sample" =~ ^[a-zA-Z0-9./]+$ ]]; then
        detected_mode="1500"; detected_name="DES (descrypt)"
    elif [ $len -eq 7 ]; then
        detected_mode="3000"; detected_name="LM"
    elif [ $len -eq 32 ] || [ $len -eq 65 ]; then
        detected_mode="1000"; detected_name="NTLM"
    fi

    if [ -n "$detected_mode" ]; then
        echo -e "  ${GREEN}[✓] Detected: ${YELLOW}$detected_name${NC} ${DIM}(mode: $detected_mode)${NC}"
        DETECTED_MODE="$detected_mode"
        DETECTED_NAME="$detected_name"
    else
        echo -e "  ${YELLOW}[!] Auto-detect সম্ভব হয়নি — manual select করুন।${NC}"
        DETECTED_MODE=""
        DETECTED_NAME=""
    fi
    echo ""
}

# ================================================================
# SELECT HASH MODE
# ================================================================
select_hash_mode() {
    echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}${BOLD}║         HASH MODE SELECT             ║${NC}"
    echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC}  Auto-detect (recommended)"
    echo -e "  ${GREEN}2)${NC}  MD5              ${DIM}(-m 0)${NC}"
    echo -e "  ${GREEN}3)${NC}  SHA1             ${DIM}(-m 100)${NC}"
    echo -e "  ${GREEN}4)${NC}  SHA256           ${DIM}(-m 1400)${NC}"
    echo -e "  ${GREEN}5)${NC}  SHA512           ${DIM}(-m 1700)${NC}"
    echo -e "  ${GREEN}6)${NC}  NTLM             ${DIM}(-m 1000)${NC}"
    echo -e "  ${GREEN}7)${NC}  LM               ${DIM}(-m 3000)${NC}"
    echo -e "  ${GREEN}8)${NC}  bcrypt           ${DIM}(-m 3200)${NC}"
    echo -e "  ${GREEN}9)${NC}  MD5crypt         ${DIM}(-m 500)${NC}"
    echo -e "  ${GREEN}10)${NC} SHA512crypt      ${DIM}(-m 1800)${NC}"
    echo -e "  ${GREEN}11)${NC} SHA256crypt      ${DIM}(-m 7400)${NC}"
    echo -e "  ${GREEN}12)${NC} phpass/WordPress ${DIM}(-m 400)${NC}"
    echo -e "  ${GREEN}13)${NC} WPA/WPA2         ${DIM}(-m 22000)${NC}"
    echo -e "  ${GREEN}14)${NC} NetNTLMv1        ${DIM}(-m 5500)${NC}"
    echo -e "  ${GREEN}15)${NC} NetNTLMv2        ${DIM}(-m 5600)${NC}"
    echo -e "  ${GREEN}16)${NC} Kerberos TGS     ${DIM}(-m 13100)${NC}"
    echo -e "  ${GREEN}17)${NC} Kerberos AS-REP  ${DIM}(-m 18200)${NC}"
    echo -e "  ${GREEN}18)${NC} MySQL SHA1       ${DIM}(-m 300)${NC}"
    echo -e "  ${GREEN}19)${NC} MSSQL 2012       ${DIM}(-m 1731)${NC}"
    echo -e "  ${GREEN}20)${NC} KeePass          ${DIM}(-m 13400)${NC}"
    echo -e "  ${GREEN}21)${NC} Bitcoin Wallet   ${DIM}(-m 11300)${NC}"
    echo -e "  ${GREEN}22)${NC} PDF              ${DIM}(-m 10400/10500)${NC}"
    echo -e "  ${GREEN}23)${NC} MS Office 2013   ${DIM}(-m 9600)${NC}"
    echo -e "  ${GREEN}24)${NC} Django PBKDF2    ${DIM}(-m 10000)${NC}"
    echo -e "  ${GREEN}25)${NC} Custom mode নম্বর দিন"
    echo -e "  ${GREEN}26)${NC} Hash mode table দেখো"
    echo ""
    read -p "$(echo -e ${YELLOW}"Select [1-26]: "${NC})" mode_ch

    case $mode_ch in
        1)  HASH_MODE="${DETECTED_MODE:-}" ;;
        2)  HASH_MODE="0" ;;
        3)  HASH_MODE="100" ;;
        4)  HASH_MODE="1400" ;;
        5)  HASH_MODE="1700" ;;
        6)  HASH_MODE="1000" ;;
        7)  HASH_MODE="3000" ;;
        8)  HASH_MODE="3200" ;;
        9)  HASH_MODE="500" ;;
        10) HASH_MODE="1800" ;;
        11) HASH_MODE="7400" ;;
        12) HASH_MODE="400" ;;
        13) HASH_MODE="22000" ;;
        14) HASH_MODE="5500" ;;
        15) HASH_MODE="5600" ;;
        16) HASH_MODE="13100" ;;
        17) HASH_MODE="18200" ;;
        18) HASH_MODE="300" ;;
        19) HASH_MODE="1731" ;;
        20) HASH_MODE="13400" ;;
        21) HASH_MODE="11300" ;;
        22)
            echo -e "  ${CYAN}PDF version: 1=10400, 2=10500, 3=10600, 4=10700${NC}"
            read -p "$(echo -e ${WHITE}"Mode: "${NC})" HASH_MODE ;;
        23) HASH_MODE="9600" ;;
        24) HASH_MODE="10000" ;;
        25) read -p "$(echo -e ${WHITE}"Mode number দিন: "${NC})" HASH_MODE ;;
        26) show_hash_modes; select_hash_mode; return ;;
        *)  HASH_MODE="${DETECTED_MODE:-0}" ;;
    esac

    echo -e "  ${GREEN}[✓] Hash mode: -m $HASH_MODE${NC}"
    echo ""
}

# ================================================================
# SCAN MENU
# ================================================================
show_menu() {
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║                   HASHCAT ATTACK OPTIONS                            ║${NC}"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ ATTACK MODE 0: WORDLIST ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}1${NC}  Wordlist Attack (Default)     — rockyou.txt দিয়ে"
    echo -e "${YELLOW}║${NC} ${GREEN}2${NC}  Wordlist + Rules               — wordlist + mutation"
    echo -e "${YELLOW}║${NC} ${GREEN}3${NC}  Custom Wordlist                — নিজের wordlist"
    echo -e "${YELLOW}║${NC} ${GREEN}4${NC}  Multiple Wordlists             — একাধিক wordlist"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ ATTACK MODE 1: COMBINATION ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}5${NC}  Combination Attack             — ২টি wordlist combine"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ ATTACK MODE 3: BRUTE FORCE / MASK ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}6${NC}  Mask: Digits Only              — ?d?d?d?d?d?d?d?d"
    echo -e "${YELLOW}║${NC} ${GREEN}7${NC}  Mask: Lowercase Only           — ?l?l?l?l?l?l?l?l"
    echo -e "${YELLOW}║${NC} ${GREEN}8${NC}  Mask: Uppercase + Lower + Dig  — common pattern"
    echo -e "${YELLOW}║${NC} ${GREEN}9${NC}  Mask: Full (All chars)         — ?a?a?a?a?a?a?a?a"
    echo -e "${YELLOW}║${NC} ${GREEN}10${NC} Mask: Custom Pattern           — নিজের mask দাও"
    echo -e "${YELLOW}║${NC} ${GREEN}11${NC} Mask: Length Range             — min-max length"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ ATTACK MODE 6 & 7: HYBRID ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}12${NC} Hybrid: Wordlist + Mask        — word + suffix mask"
    echo -e "${YELLOW}║${NC} ${GREEN}13${NC} Hybrid: Mask + Wordlist        — prefix mask + word"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ RULE-BASED ATTACKS ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}14${NC} Rules: best64                  — top 64 mutation rules"
    echo -e "${YELLOW}║${NC} ${GREEN}15${NC} Rules: rockyou-30000           — 30000 rules"
    echo -e "${YELLOW}║${NC} ${GREEN}16${NC} Rules: dive                    — comprehensive rules"
    echo -e "${YELLOW}║${NC} ${GREEN}17${NC} Rules: d3ad0ne                 — advanced mutation"
    echo -e "${YELLOW}║${NC} ${GREEN}18${NC} Rules: InsidePro               — InsidePro rules"
    echo -e "${YELLOW}║${NC} ${GREEN}19${NC} Custom Rule File               — নিজের rules"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ SPECIAL / TARGETED ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}20${NC} WPA/WPA2 WiFi Crack            — WiFi handshake crack"
    echo -e "${YELLOW}║${NC} ${GREEN}21${NC} Kerberoasting Crack            — krb5tgs hash crack"
    echo -e "${YELLOW}║${NC} ${GREEN}22${NC} NTLM Hash Crack                — Windows hash crack"
    echo -e "${YELLOW}║${NC} ${GREEN}23${NC} LinkedIn / SHA1 Salted         — salted hash crack"
    echo -e "${YELLOW}║${NC} ${GREEN}24${NC} PRINCE Attack                  — word combination"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ INFO / UTILITY ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}25${NC} Show Cracked Passwords         — cracked results দেখো"
    echo -e "${YELLOW}║${NC} ${GREEN}26${NC} Restore Session                — আগের session resume"
    echo -e "${YELLOW}║${NC} ${GREEN}27${NC} Benchmark (Speed Test)         — GPU/CPU speed test"
    echo -e "${YELLOW}║${NC} ${GREEN}28${NC} Hash Mode Table                — সব mode দেখো"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}━━━ COMBO ATTACKS ━━━${NC}"
    echo -e "${YELLOW}║${NC} ${GREEN}29${NC} Smart Combo Attack             — wordlist→rules→mask"
    echo -e "${YELLOW}║${NC} ${GREEN}30${NC} All-in-One Mega Crack          — সব method একসাথে"
    echo -e "${YELLOW}${BOLD}╠══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${RED}0)${NC} Exit                                                               ${YELLOW}║${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ================================================================
# EXTRA OPTIONS
# ================================================================
get_extra_options() {
    DEVICE_OPT=""
    WORKLOAD_OPT=""
    SESSION_OPT=""
    OUTFILE_OPT=""
    POTFILE_OPT=""
    STATUS_OPT="--status --status-timer=10"
    FORCE_OPT=""

    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║         EXTRA OPTIONS                ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""

    # Device selection
    echo -e "${CYAN}Device select:${NC}"
    echo -e "  ${GREEN}1)${NC} Auto (hashcat নিজে বেছে নেবে)"
    echo -e "  ${GREEN}2)${NC} GPU only (-D 2)"
    echo -e "  ${GREEN}3)${NC} CPU only (-D 1)"
    echo -e "  ${GREEN}4)${NC} GPU + CPU (-D 1,2)"
    read -p "$(echo -e ${YELLOW}"Select [1-4, Enter=1]: "${NC})" dev_ch
    case $dev_ch in
        2) DEVICE_OPT="-D 2" ;;
        3) DEVICE_OPT="-D 1" ;;
        4) DEVICE_OPT="-D 1,2" ;;
        *) DEVICE_OPT="" ;;
    esac

    # Workload
    echo ""
    echo -e "${CYAN}Workload profile:${NC}"
    echo -e "  ${GREEN}1)${NC} Low       — system responsive থাকবে"
    echo -e "  ${GREEN}2)${NC} Default   — balanced"
    echo -e "  ${GREEN}3)${NC} High      — দ্রুত, system slow হতে পারে"
    echo -e "  ${GREEN}4)${NC} Nightmare — সর্বোচ্চ speed, system freeze হতে পারে"
    read -p "$(echo -e ${YELLOW}"Select [1-4, Enter=2]: "${NC})" wl_ch
    case $wl_ch in
        1) WORKLOAD_OPT="-w 1" ;;
        3) WORKLOAD_OPT="-w 3" ;;
        4) WORKLOAD_OPT="-w 4" ;;
        *) WORKLOAD_OPT="-w 2" ;;
    esac

    # Session name
    read -p "$(echo -e ${WHITE}"Session name (Enter=auto): "${NC})" sess_in
    if [ -n "$sess_in" ]; then
        SESSION_OPT="--session=$sess_in"
    else
        SESSION_OPT="--session=hashcat_saimum_$(date +%Y%m%d_%H%M%S)"
    fi

    # Output file
    local ts; ts=$(date +"%Y%m%d_%H%M%S")
    local safe; safe=$(basename "$HASH_FILE" | sed 's/[^a-zA-Z0-9._-]/_/g')
    CRACK_OUTPUT="$RESULTS_DIR/cracked_${safe}_${ts}.txt"
    OUTFILE_OPT="--outfile=$CRACK_OUTPUT"

    # Force flag (bypass warnings)
    read -p "$(echo -e ${WHITE}"--force flag use করবেন? (y/n, Enter=n): "${NC})" force_in
    [[ "$force_in" =~ ^[Yy]$ ]] && FORCE_OPT="--force"

    echo ""
}

# ================================================================
# GET WORDLIST
# ================================================================
get_wordlist() {
    WORDLIST=""
    echo -e "${CYAN}Wordlist select:${NC}"
    echo -e "  ${GREEN}1)${NC} Default (rockyou.txt)"
    echo -e "  ${GREEN}2)${NC} Custom path"
    read -p "$(echo -e ${YELLOW}"[1-2]: "${NC})" wl_ch

    case $wl_ch in
        1)
            if [ -n "$DEFAULT_WORDLIST" ]; then
                WORDLIST="$DEFAULT_WORDLIST"
            else
                read -p "$(echo -e ${WHITE}"Wordlist path: "${NC})" WORDLIST
            fi
            ;;
        2)
            read -p "$(echo -e ${WHITE}"Wordlist path: "${NC})" WORDLIST
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
# GET RULE FILE
# ================================================================
get_rule_file() {
    local rule_name=$1
    RULE_FILE=""

    if [ -n "$RULES_DIR" ] && [ -f "$RULES_DIR/${rule_name}.rule" ]; then
        RULE_FILE="$RULES_DIR/${rule_name}.rule"
    elif [ -n "$RULES_DIR" ] && [ -f "$RULES_DIR/${rule_name}" ]; then
        RULE_FILE="$RULES_DIR/${rule_name}"
    else
        echo -e "  ${YELLOW}[!] $rule_name rule file পাওয়া যায়নি।${NC}"
        read -p "$(echo -e ${WHITE}"Rule file path দিন (Enter=skip): "${NC})" RULE_FILE
        [ ! -f "$RULE_FILE" ] && RULE_FILE=""
    fi

    [ -n "$RULE_FILE" ] && echo -e "  ${GREEN}[✓] Rule: $RULE_FILE${NC}"
}

# ================================================================
# BUILD AND RUN HASHCAT
# ================================================================
run_hashcat() {
    local mode_label=$1
    local attack_mode=$2
    local extra_args=$3

    SCAN_LABEL="$mode_label"
    local mode_flag="-m $HASH_MODE"
    [ -z "$HASH_MODE" ] && mode_flag=""

    local full_cmd="hashcat $mode_flag -a $attack_mode $DEVICE_OPT $WORKLOAD_OPT $SESSION_OPT $OUTFILE_OPT $STATUS_OPT $FORCE_OPT $extra_args $HASH_FILE"

    # Preview
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}Attack Mode : ${YELLOW}${BOLD}$mode_label${NC}"
    echo -e "  ${WHITE}Hash File   : ${GREEN}${BOLD}$HASH_FILE${NC}"
    echo -e "  ${WHITE}Hash Mode   : ${CYAN}-m ${HASH_MODE:-auto}${NC}"
    echo -e "  ${WHITE}Output      : ${CYAN}$CRACK_OUTPUT${NC}"
    echo -e "  ${WHITE}Command     : ${CYAN}$full_cmd${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}"[?] Crack শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local tmp; tmp=$(mktemp)

    echo ""
    echo -e "${GREEN}${BOLD}[*] Hashcat চালু হচ্ছে...${NC}"
    echo -e "${YELLOW}[!] চলছে... বন্ধ করতে 'q' চাপুন (progress save হবে)${NC}"
    echo ""

    eval "$full_cmd" 2>&1 | tee "$tmp"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Attack সম্পন্ন!${NC}"
    echo ""

    show_cracked_passwords
    bangla_analysis "$tmp"
    suggest_next_tool "$tmp"
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 1 — WORDLIST DEFAULT
# ================================================================
mode_wordlist_default() {
    get_wordlist
    [ -z "$WORDLIST" ] && return
    run_hashcat "Wordlist Attack (Default)" "0" "$WORDLIST"
}

# ================================================================
# MODE 2 — WORDLIST + RULES
# ================================================================
mode_wordlist_rules() {
    get_wordlist
    [ -z "$WORDLIST" ] && return

    echo -e "${CYAN}Rule select:${NC}"
    echo -e "  ${GREEN}1)${NC} best64  ${GREEN}2)${NC} rockyou-30000  ${GREEN}3)${NC} dive  ${GREEN}4)${NC} d3ad0ne  ${GREEN}5)${NC} Custom"
    read -p "$(echo -e ${YELLOW}"[1-5]: "${NC})" rch
    local rname
    case $rch in
        1) rname="best64" ;; 2) rname="rockyou-30000" ;;
        3) rname="dive" ;;   4) rname="d3ad0ne" ;;
        5) read -p "$(echo -e ${WHITE}"Rule file path: "${NC})" RULE_FILE; rname="" ;;
        *) rname="best64" ;;
    esac
    [ -n "$rname" ] && get_rule_file "$rname"

    if [ -n "$RULE_FILE" ]; then
        run_hashcat "Wordlist + Rules ($rname)" "0" "$WORDLIST -r $RULE_FILE"
    else
        run_hashcat "Wordlist (no rule)" "0" "$WORDLIST"
    fi
}

# ================================================================
# MODE 3 — CUSTOM WORDLIST
# ================================================================
mode_custom_wordlist() {
    read -p "$(echo -e ${WHITE}"Custom wordlist path: "${NC})" custom_wl
    [ ! -f "$custom_wl" ] && echo -e "${RED}[!] File পাওয়া যায়নি।${NC}" && return
    run_hashcat "Custom Wordlist" "0" "$custom_wl"
}

# ================================================================
# MODE 4 — MULTIPLE WORDLISTS
# ================================================================
mode_multiple_wordlists() {
    local combined="$RESULTS_DIR/combined_wl_$(date +%Y%m%d_%H%M%S).txt"
    echo -e "${WHITE}Wordlist paths দিন। শেষ হলে 'done':${NC}"
    while true; do
        read -p "$(echo -e ${WHITE}"Path: "${NC})" wl_path
        [[ "$wl_path" == "done" || -z "$wl_path" ]] && break
        [ -f "$wl_path" ] && cat "$wl_path" >> "$combined" && \
            echo -e "  ${GREEN}[✓] Added${NC}" || echo -e "  ${RED}[!] Not found${NC}"
    done
    [ ! -s "$combined" ] && echo -e "${RED}[!] Empty.${NC}" && return
    echo -e "  ${GREEN}[✓] Combined: $combined ($(wc -l < "$combined") lines)${NC}"
    run_hashcat "Multiple Wordlists" "0" "$combined"
}

# ================================================================
# MODE 5 — COMBINATION ATTACK
# ================================================================
mode_combination() {
    echo -e "${CYAN}Combination Attack — ২টি wordlist দিন:${NC}"
    read -p "$(echo -e ${WHITE}"Wordlist 1: "${NC})" wl1
    read -p "$(echo -e ${WHITE}"Wordlist 2: "${NC})" wl2
    [ ! -f "$wl1" ] || [ ! -f "$wl2" ] && echo -e "${RED}[!] File পাওয়া যায়নি।${NC}" && return
    run_hashcat "Combination Attack" "1" "$wl1 $wl2"
}

# ================================================================
# MODE 6-11 — MASK ATTACKS
# ================================================================
mode_mask_digits() {
    read -p "$(echo -e ${WHITE}"Length দিন (Enter=8): "${NC})" len; [ -z "$len" ] && len=8
    local mask=""; for ((i=1; i<=len; i++)); do mask="${mask}?d"; done
    run_hashcat "Mask: Digits ($len chars)" "3" "$mask"
}

mode_mask_lower() {
    read -p "$(echo -e ${WHITE}"Length দিন (Enter=8): "${NC})" len; [ -z "$len" ] && len=8
    local mask=""; for ((i=1; i<=len; i++)); do mask="${mask}?l"; done
    run_hashcat "Mask: Lowercase ($len chars)" "3" "$mask"
}

mode_mask_common() {
    echo -e "${CYAN}Common patterns:${NC}"
    echo -e "  ${GREEN}1)${NC} ?u?l?l?l?l?d?d?d  (Cap+lower+digits)"
    echo -e "  ${GREEN}2)${NC} ?l?l?l?l?d?d?d?d  (lower+digits)"
    echo -e "  ${GREEN}3)${NC} ?u?l?l?l?l?l?d?d  (Cap+lower+2digits)"
    echo -e "  ${GREEN}4)${NC} ?l?l?l?l?l?l?d?s  (lower+digit+special)"
    read -p "$(echo -e ${YELLOW}"[1-4]: "${NC})" pch
    local mask
    case $pch in
        1) mask="?u?l?l?l?l?d?d?d" ;; 2) mask="?l?l?l?l?d?d?d?d" ;;
        3) mask="?u?l?l?l?l?l?d?d" ;; 4) mask="?l?l?l?l?l?l?d?s" ;;
        *) mask="?u?l?l?l?l?d?d?d" ;;
    esac
    run_hashcat "Mask: Common Pattern ($mask)" "3" "$mask"
}

mode_mask_full() {
    read -p "$(echo -e ${WHITE}"Length দিন (Enter=6): "${NC})" len; [ -z "$len" ] && len=6
    local mask=""; for ((i=1; i<=len; i++)); do mask="${mask}?a"; done
    echo -e "${YELLOW}[!] Full mask অনেক সময় নিতে পারে!${NC}"
    run_hashcat "Mask: Full All-chars ($len chars)" "3" "$mask"
}

mode_mask_custom() {
    echo ""
    echo -e "${CYAN}Mask Placeholders: ?l=lower ?u=upper ?d=digit ?s=special ?a=all${NC}"
    echo -e "${DIM}উদাহরণ: ?u?l?l?l?d?d?d = Cap+3lower+3digit${NC}"
    read -p "$(echo -e ${WHITE}"Mask দিন: "${NC})" mask
    run_hashcat "Custom Mask ($mask)" "3" "$mask"
}

mode_mask_length_range() {
    read -p "$(echo -e ${WHITE}"Min length: "${NC})" min_len
    read -p "$(echo -e ${WHITE}"Max length: "${NC})" max_len
    read -p "$(echo -e ${WHITE}"Charset (?l/?d/?a, Enter=?a): "${NC})" charset
    [ -z "$charset" ] && charset="?a"
    echo ""
    echo -e "${CYAN}[*] $min_len থেকে $max_len length এর সব combination try করা হবে...${NC}"
    for len in $(seq "$min_len" "$max_len"); do
        local mask=""
        for ((i=1; i<=len; i++)); do mask="${mask}${charset}"; done
        echo -e "${YELLOW}[*] Trying length $len: $mask${NC}"
        hashcat -m "$HASH_MODE" -a 3 $DEVICE_OPT $WORKLOAD_OPT $OUTFILE_OPT $FORCE_OPT "$HASH_FILE" "$mask" 2>&1
    done
    show_cracked_passwords
}

# ================================================================
# MODE 12-13 — HYBRID ATTACKS
# ================================================================
mode_hybrid_wordlist_mask() {
    get_wordlist
    [ -z "$WORDLIST" ] && return
    echo -e "${CYAN}Mask (suffix) দিন: ${DIM}e.g. ?d?d?d (word + 3 digits)${NC}"
    read -p "$(echo -e ${WHITE}"Mask: "${NC})" mask
    run_hashcat "Hybrid: Wordlist+Mask ($mask suffix)" "6" "$WORDLIST $mask"
}

mode_hybrid_mask_wordlist() {
    get_wordlist
    [ -z "$WORDLIST" ] && return
    echo -e "${CYAN}Mask (prefix) দিন: ${DIM}e.g. ?d?d?d (3 digits + word)${NC}"
    read -p "$(echo -e ${WHITE}"Mask: "${NC})" mask
    run_hashcat "Hybrid: Mask+Wordlist ($mask prefix)" "7" "$mask $WORDLIST"
}

# ================================================================
# MODE 14-19 — RULE FILES
# ================================================================
mode_rule_best64()       { get_wordlist; [ -z "$WORDLIST" ] && return; get_rule_file "best64";          [ -n "$RULE_FILE" ] && run_hashcat "Rules: best64"          "0" "$WORDLIST -r $RULE_FILE"; }
mode_rule_rockyou30k()   { get_wordlist; [ -z "$WORDLIST" ] && return; get_rule_file "rockyou-30000";   [ -n "$RULE_FILE" ] && run_hashcat "Rules: rockyou-30000"   "0" "$WORDLIST -r $RULE_FILE"; }
mode_rule_dive()         { get_wordlist; [ -z "$WORDLIST" ] && return; get_rule_file "dive";            [ -n "$RULE_FILE" ] && run_hashcat "Rules: dive"            "0" "$WORDLIST -r $RULE_FILE"; }
mode_rule_d3ad0ne()      { get_wordlist; [ -z "$WORDLIST" ] && return; get_rule_file "d3ad0ne";         [ -n "$RULE_FILE" ] && run_hashcat "Rules: d3ad0ne"         "0" "$WORDLIST -r $RULE_FILE"; }
mode_rule_insidepro()    { get_wordlist; [ -z "$WORDLIST" ] && return; get_rule_file "InsidePro-PasswordsPro"; [ -n "$RULE_FILE" ] && run_hashcat "Rules: InsidePro" "0" "$WORDLIST -r $RULE_FILE"; }

mode_rule_custom() {
    get_wordlist
    [ -z "$WORDLIST" ] && return
    read -p "$(echo -e ${WHITE}"Rule file path: "${NC})" custom_rule
    [ ! -f "$custom_rule" ] && echo -e "${RED}[!] File পাওয়া যায়নি।${NC}" && return
    run_hashcat "Custom Rules" "0" "$WORDLIST -r $custom_rule"
}

# ================================================================
# MODE 20 — WIFI WPA/WPA2
# ================================================================
mode_wifi_wpa() {
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║          WPA/WPA2 WiFi Password Crack                   ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ "$HASH_MODE" != "22000" ]] && [[ "$HASH_MODE" != "2500" ]]; then
        echo -e "${CYAN}WiFi hash mode select:${NC}"
        echo -e "  ${GREEN}1)${NC} 22000 — WPA-PBKDF2-PMKID+EAPOL (modern, recommended)"
        echo -e "  ${GREEN}2)${NC} 2500  — WPA/WPA2 legacy .hccapx"
        read -p "$(echo -e ${YELLOW}"[1-2]: "${NC})" wifi_ch
        [ "$wifi_ch" == "2" ] && HASH_MODE="2500" || HASH_MODE="22000"
    fi

    get_wordlist
    [ -z "$WORDLIST" ] && return

    echo ""
    echo -e "${CYAN}Extra WiFi options:${NC}"
    read -p "$(echo -e ${WHITE}"ESSID filter দিন (Enter=সব): "${NC})" essid_in
    local essid_opt=""
    [ -n "$essid_in" ] && essid_opt="--essid=$essid_in"

    run_hashcat "WPA/WPA2 WiFi Crack (mode $HASH_MODE)" "0" "$WORDLIST $essid_opt"
}

# ================================================================
# MODE 21 — KERBEROASTING
# ================================================================
mode_kerberoasting() {
    if [[ "$HASH_MODE" != "13100" ]] && [[ "$HASH_MODE" != "18200" ]]; then
        echo -e "${CYAN}Kerberos type:${NC}"
        echo -e "  ${GREEN}1)${NC} 13100 — Kerberoasting (TGS-REP)"
        echo -e "  ${GREEN}2)${NC} 18200 — AS-REP Roasting"
        read -p "$(echo -e ${YELLOW}"[1-2]: "${NC})" krb_ch
        [ "$krb_ch" == "2" ] && HASH_MODE="18200" || HASH_MODE="13100"
    fi
    get_wordlist
    [ -z "$WORDLIST" ] && return
    run_hashcat "Kerberoasting (mode $HASH_MODE)" "0" "$WORDLIST"
}

# ================================================================
# MODE 22 — NTLM
# ================================================================
mode_ntlm() {
    HASH_MODE="1000"
    echo -e "${CYAN}[*] NTLM mode (-m 1000) set করা হয়েছে।${NC}"
    get_wordlist
    [ -z "$WORDLIST" ] && return

    echo -e "${CYAN}Rule যোগ করবেন?${NC}"
    read -p "$(echo -e ${YELLOW}"(y/n): "${NC})" rule_yn
    if [[ "$rule_yn" =~ ^[Yy]$ ]]; then
        get_rule_file "best64"
        [ -n "$RULE_FILE" ] && run_hashcat "NTLM + Rules" "0" "$WORDLIST -r $RULE_FILE" && return
    fi
    run_hashcat "NTLM Wordlist Crack" "0" "$WORDLIST"
}

# ================================================================
# MODE 23 — SALTED HASH
# ================================================================
mode_salted() {
    echo -e "${CYAN}Salted hash format দিন:${NC}"
    echo -e "  ${DIM}উদাহরণ: hash:salt অথবা salt:hash${NC}"
    echo -e "  ${DIM}hashcat auto-detect করতে পারে format অনুযায়ী।${NC}"
    get_wordlist
    [ -z "$WORDLIST" ] && return
    run_hashcat "Salted Hash Crack" "0" "$WORDLIST"
}

# ================================================================
# MODE 24 — PRINCE ATTACK
# ================================================================
mode_prince() {
    if hashcat --help 2>&1 | grep -q "PRINCE"; then
        get_wordlist
        [ -z "$WORDLIST" ] && return
        run_hashcat "PRINCE Attack" "0" "--prince $WORDLIST"
    else
        echo -e "${YELLOW}[!] PRINCE mode এই version এ নেই।${NC}"
        echo -e "${CYAN}Alternative: pp wordlist.txt | hashcat -m $HASH_MODE -a 0 $HASH_FILE${NC}"
    fi
}

# ================================================================
# MODE 25 — SHOW CRACKED
# ================================================================
show_cracked_passwords() {
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║             Crack হওয়া Passwords                                    ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # From outfile
    if [ -f "$CRACK_OUTPUT" ] && [ -s "$CRACK_OUTPUT" ]; then
        local count; count=$(wc -l < "$CRACK_OUTPUT")
        echo -e "  ${GREEN}[✓] $count টি password crack হয়েছে:${NC}"
        echo ""
        cat "$CRACK_OUTPUT" | while IFS= read -r line; do
            echo -e "  ${GREEN}▸ $line${NC}"
        done
    else
        # Try hashcat --show
        local mode_flag=""
        [ -n "$HASH_MODE" ] && mode_flag="-m $HASH_MODE"
        local shown
        shown=$(hashcat $mode_flag --show "$HASH_FILE" $FORCE_OPT 2>/dev/null)
        if [ -n "$shown" ]; then
            echo "$shown" | while IFS= read -r line; do
                echo -e "  ${GREEN}▸ $line${NC}"
            done
        else
            echo -e "  ${YELLOW}[!] এখনো কোনো password crack হয়নি।${NC}"
        fi
    fi
    echo ""
}

# ================================================================
# MODE 26 — RESTORE SESSION
# ================================================================
mode_restore() {
    echo ""
    echo -e "${CYAN}Available sessions:${NC}"
    find "$HOME/.hashcat/sessions" /tmp 2>/dev/null -name "*.restore" 2>/dev/null | while IFS= read -r f; do
        echo -e "  ${GREEN}▸ $(basename "$f" .restore)${NC}"
    done
    echo ""
    read -p "$(echo -e ${WHITE}"Session name দিন: "${NC})" sess_name
    echo ""
    echo -e "${GREEN}[*] Session restore করা হচ্ছে...${NC}"
    hashcat --restore --session="$sess_name" 2>&1
}

# ================================================================
# MODE 27 — BENCHMARK
# ================================================================
mode_benchmark() {
    echo ""
    echo -e "${CYAN}[*] Hashcat benchmark চালানো হচ্ছে...${NC}"
    echo ""
    local mode_flag=""
    [ -n "$HASH_MODE" ] && mode_flag="-m $HASH_MODE"

    if [ -n "$mode_flag" ]; then
        echo -e "${CYAN}[*] Mode $HASH_MODE এর জন্য benchmark:${NC}"
        hashcat $mode_flag -b $DEVICE_OPT $FORCE_OPT 2>&1
    else
        echo -e "${CYAN}[*] সব popular modes এর benchmark:${NC}"
        hashcat -b $DEVICE_OPT $FORCE_OPT 2>&1 | head -50
    fi
}

# ================================================================
# MODE 29 — SMART COMBO
# ================================================================
mode_smart_combo() {
    get_wordlist
    [ -z "$WORDLIST" ] && return

    echo ""
    echo -e "${CYAN}${BOLD}[*] Smart Combo — ৪ ধাপে crack:${NC}"
    echo -e "    ${WHITE}1: Wordlist  2: +best64  3: +dive  4: Hybrid mask${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"[?] শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local mode_flag="-m $HASH_MODE"
    [ -z "$HASH_MODE" ] && mode_flag=""
    SCAN_LABEL="Smart Combo Attack"
    local tmp; tmp=$(mktemp)

    echo -e "${CYAN}━━━ Step 1: Wordlist ━━━${NC}"
    hashcat $mode_flag -a 0 $DEVICE_OPT $WORKLOAD_OPT $OUTFILE_OPT $FORCE_OPT "$HASH_FILE" "$WORDLIST" 2>&1 | tee -a "$tmp"

    get_rule_file "best64"
    if [ -n "$RULE_FILE" ]; then
        echo -e "${CYAN}━━━ Step 2: Wordlist + best64 ━━━${NC}"
        hashcat $mode_flag -a 0 $DEVICE_OPT $WORKLOAD_OPT $OUTFILE_OPT $FORCE_OPT "$HASH_FILE" "$WORDLIST" -r "$RULE_FILE" 2>&1 | tee -a "$tmp"
    fi

    get_rule_file "dive"
    if [ -n "$RULE_FILE" ]; then
        echo -e "${CYAN}━━━ Step 3: Wordlist + dive ━━━${NC}"
        hashcat $mode_flag -a 0 $DEVICE_OPT $WORKLOAD_OPT $OUTFILE_OPT $FORCE_OPT "$HASH_FILE" "$WORDLIST" -r "$RULE_FILE" 2>&1 | tee -a "$tmp"
    fi

    echo -e "${CYAN}━━━ Step 4: Hybrid Wordlist+?d?d?d ━━━${NC}"
    hashcat $mode_flag -a 6 $DEVICE_OPT $WORKLOAD_OPT $OUTFILE_OPT $FORCE_OPT "$HASH_FILE" "$WORDLIST" "?d?d?d" 2>&1 | tee -a "$tmp"

    echo ""
    echo -e "${GREEN}${BOLD}[✓] Smart Combo সম্পন্ন!${NC}"
    show_cracked_passwords
    bangla_analysis "$tmp"
    suggest_next_tool "$tmp"
    save_results "$tmp"
    rm -f "$tmp"
}

# ================================================================
# MODE 30 — ALL IN ONE MEGA CRACK
# ================================================================
mode_allinone() {
    echo ""
    echo -e "${RED}${BOLD}[!] All-in-One Mega Crack — সব method একসাথে।${NC}"
    echo -e "${YELLOW}[!] এটি অনেক সময় নিতে পারে।${NC}"
    read -p "$(echo -e ${YELLOW}"[?] শুরু করবেন? (y/n): "${NC})" go
    [[ ! "$go" =~ ^[Yy]$ ]] && return

    local wl="${DEFAULT_WORDLIST}"
    if [ -z "$wl" ]; then
        read -p "$(echo -e ${WHITE}"Wordlist path দিন: "${NC})" wl
        [ ! -f "$wl" ] && echo -e "${RED}[!] File পাওয়া যায়নি।${NC}" && return
    fi

    local mode_flag="-m $HASH_MODE"
    [ -z "$HASH_MODE" ] && mode_flag=""
    SCAN_LABEL="All-in-One Mega Crack"
    local tmp; tmp=$(mktemp)

    echo -e "${CYAN}━━━ Phase 1: Wordlist ━━━${NC}"
    hashcat $mode_flag -a 0 $DEVICE_OPT $WORKLOAD_OPT $OUTFILE_OPT $FORCE_OPT "$HASH_FILE" "$wl" 2>&1 | tee -a "$tmp"

    get_rule_file "best64"
    if [ -n "$RULE_FILE" ]; then
        echo -e "${CYAN}━━━ Phase 2: Wordlist + best64 ━━━${NC}"
        hashcat $mode_flag -a 0 $DEVICE_OPT $WORKLOAD_OPT $OUTFILE_OPT $FORCE_OPT "$HASH_FILE" "$wl" -r "$RULE_FILE" 2>&1 | tee -a "$tmp"
    fi

    get_rule_file "rockyou-30000"
    if [ -n "$RULE_FILE" ]; then
        echo -e "${CYAN}━━━ Phase 3: Wordlist + rockyou-30000 ━━━${NC}"
        hashcat $mode_flag -a 0 $DEVICE_OPT $WORKLOAD_OPT $OUTFILE_OPT $FORCE_OPT "$HASH_FILE" "$wl" -r "$RULE_FILE" 2>&1 | tee -a "$tmp"
    fi

    get_rule_file "dive"
    if [ -n "$RULE_FILE" ]; then
        echo -e "${CYAN}━━━ Phase 4: Wordlist + dive ━━━${NC}"
        hashcat $mode_flag -a 0 $DEVICE_OPT $WORKLOAD_OPT $OUTFILE_OPT $FORCE_OPT "$HASH_FILE" "$wl" -r "$RULE_FILE" 2>&1 | tee -a "$tmp"
    fi

    echo -e "${CYAN}━━━ Phase 5: Hybrid Wordlist + ?d?d?d ━━━${NC}"
    hashcat $mode_flag -a 6 $DEVICE_OPT $WORKLOAD_OPT $OUTFILE_OPT $FORCE_OPT "$HASH_FILE" "$wl" "?d?d?d" 2>&1 | tee -a "$tmp"

    echo -e "${CYAN}━━━ Phase 6: Hybrid ?d?d?d + Wordlist ━━━${NC}"
    hashcat $mode_flag -a 7 $DEVICE_OPT $WORKLOAD_OPT $OUTFILE_OPT $FORCE_OPT "$HASH_FILE" "?d?d?d" "$wl" 2>&1 | tee -a "$tmp"

    echo -e "${CYAN}━━━ Phase 7: Mask Digits 6-8 ━━━${NC}"
    for len in 6 7 8; do
        local mask=""
        for ((i=1; i<=len; i++)); do mask="${mask}?d"; done
        timeout 60 hashcat $mode_flag -a 3 $DEVICE_OPT $WORKLOAD_OPT $OUTFILE_OPT $FORCE_OPT "$HASH_FILE" "$mask" 2>&1 | tee -a "$tmp"
    done

    echo -e "${CYAN}━━━ Phase 8: Mask Common Pattern ━━━${NC}"
    timeout 120 hashcat $mode_flag -a 3 $DEVICE_OPT $WORKLOAD_OPT $OUTFILE_OPT $FORCE_OPT "$HASH_FILE" "?u?l?l?l?d?d?d?d" 2>&1 | tee -a "$tmp"

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

    # Count from outfile
    local cracked_count=0
    local total_count=0

    [ -f "$CRACK_OUTPUT" ] && cracked_count=$(wc -l < "$CRACK_OUTPUT" 2>/dev/null || echo 0)
    total_count=$(wc -l < "$HASH_FILE" 2>/dev/null || echo 0)

    local remaining=$((total_count - cracked_count))
    [ "$remaining" -lt 0 ] && remaining=0

    echo -e "  ${CYAN}${BOLD}━━━ Crack পরিসংখ্যান ━━━${NC}"
    echo -e "  ${WHITE}মোট Hash       : ${CYAN}$total_count${NC}"
    echo -e "  ${GREEN}Crack হয়েছে   : $cracked_count${NC}"
    echo -e "  ${RED}Crack হয়নি    : $remaining${NC}"
    echo ""

    # Speed info from output
    local speed
    speed=$(grep -oE "[0-9.]+ [MKG]H/s" "$outfile" 2>/dev/null | tail -1)
    [ -n "$speed" ] && echo -e "  ${CYAN}[*] Crack speed: ${YELLOW}$speed${NC}" && echo ""

    # Status from output
    if grep -q "Status\.\.\.\.\.\.: Cracked" "$outfile" 2>/dev/null; then
        echo -e "  ${GREEN}${BOLD}[✓] Status: সব hash crack হয়েছে!${NC}"
    elif grep -q "Status\.\.\.\.\.\.: Exhausted" "$outfile" 2>/dev/null; then
        echo -e "  ${YELLOW}[!] Status: Wordlist/Mask শেষ হয়ে গেছে — সব try করা হয়েছে।${NC}"
    elif grep -q "Status\.\.\.\.\.\.: Quit" "$outfile" 2>/dev/null; then
        echo -e "  ${YELLOW}[!] Status: Manual stop — session save হয়েছে।${NC}"
    fi
    echo ""

    if [ "$cracked_count" -gt 0 ]; then
        local crack_rate=0
        [ "$total_count" -gt 0 ] && crack_rate=$((cracked_count * 100 / total_count))
        echo -e "  ${GREEN}${BOLD}✅ $cracked_count টি password crack হয়েছে! ($crack_rate%)${NC}"
        echo ""

        # Password quality analysis
        if [ -f "$CRACK_OUTPUT" ]; then
            echo -e "  ${CYAN}${BOLD}━━━ Password দুর্বলতা বিশ্লেষণ ━━━${NC}"
            echo ""
            local weak=0 medium=0 strong=0

            while IFS= read -r line; do
                local passwd
                passwd=$(echo "$line" | awk -F: '{print $NF}')
                local plen=${#passwd}
                local types=0
                echo "$passwd" | grep -q '[a-z]' && types=$((types+1))
                echo "$passwd" | grep -q '[A-Z]' && types=$((types+1))
                echo "$passwd" | grep -q '[0-9]' && types=$((types+1))
                echo "$passwd" | grep -q '[^a-zA-Z0-9]' && types=$((types+1))

                if [ "$plen" -lt 8 ] || [ "$types" -le 1 ]; then
                    weak=$((weak+1))
                elif [ "$plen" -lt 12 ] || [ "$types" -le 2 ]; then
                    medium=$((medium+1))
                else
                    strong=$((strong+1))
                fi
            done < "$CRACK_OUTPUT"

            echo -e "  ${RED}   অত্যন্ত দুর্বল  : $weak টি${NC}"
            echo -e "  ${YELLOW}   মাঝারি দুর্বল  : $medium টি${NC}"
            echo -e "  ${GREEN}   তুলনামূলক শক্ত : $strong টি${NC}"
            echo ""
        fi

        echo -e "  ${CYAN}${BOLD}━━━ সামগ্রিক ঝুঁকি মূল্যায়ন ━━━${NC}"
        local crack_rate_num=$((cracked_count * 100 / (total_count > 0 ? total_count : 1)))
        if [ "$crack_rate_num" -ge 75 ]; then
            echo -e "  ${RED}${BOLD}  সার্বিক ঝুঁকি : ██████████ CRITICAL — বেশিরভাগ password crack হয়েছে!${NC}"
        elif [ "$crack_rate_num" -ge 40 ]; then
            echo -e "  ${YELLOW}${BOLD}  সার্বিক ঝুঁকি : ███████░░░ HIGH — অনেক password দুর্বল।${NC}"
        elif [ "$crack_rate_num" -ge 10 ]; then
            echo -e "  ${CYAN}  সার্বিক ঝুঁকি : █████░░░░░ MEDIUM — কিছু password দুর্বল।${NC}"
        else
            echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW — বেশিরভাগ password শক্তিশালী।${NC}"
        fi
    else
        echo -e "  ${YELLOW}[!] এখনো কোনো password crack হয়নি।${NC}"
        echo ""
        echo -e "  ${CYAN}[*] কারণ ও সমাধান:${NC}"
        if grep -q "No hashes loaded" "$outfile" 2>/dev/null; then
            echo -e "     ${RED}→ Hash load হয়নি — hash mode (-m) সঠিক কিনা দেখুন।${NC}"
        else
            echo -e "     ${WHITE}→ Wordlist এ password নেই — বড় wordlist try করুন।${NC}"
            echo -e "     ${WHITE}→ Rule যোগ করুন (best64/dive)।${NC}"
            echo -e "     ${WHITE}→ Mask attack try করুন।${NC}"
            echo -e "     ${WHITE}→ Hash type ভুল হতে পারে।${NC}"
        fi
        echo -e "  ${GREEN}  সার্বিক ঝুঁকি : ███░░░░░░░ LOW (এখনো crack হয়নি)${NC}"
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

    local cracked_count=0
    [ -f "$CRACK_OUTPUT" ] && cracked_count=$(wc -l < "$CRACK_OUTPUT" 2>/dev/null || echo 0)

    if [ "$cracked_count" -gt 0 ]; then
        echo -e "  ${GREEN}${BOLD}✅ Password crack হয়েছে — এখন কী করবেন:${NC}"
        echo ""

        echo -e "  ${RED}${BOLD}🔑 Hydra${NC} — Cracked Password দিয়ে Login Test"
        echo -e "     ${WHITE}কারণ: Cracked password দিয়ে SSH/RDP/Web login test করুন।${NC}"
        echo -e "     ${CYAN}কমান্ড: hydra -L users.txt -P $CRACK_OUTPUT ssh://<target>${NC}"
        echo ""

        echo -e "  ${MAGENTA}${BOLD}💀 Metasploit${NC} — Valid Credential দিয়ে Exploit"
        echo -e "     ${WHITE}কারণ: Cracked credential দিয়ে system access নিন।${NC}"
        echo -e "     ${CYAN}কমান্ড: msfconsole → use auxiliary/scanner/ssh/ssh_login${NC}"
        echo ""

        if [[ "$HASH_MODE" == "1000" ]] || [[ "$SCAN_LABEL" == *"NTLM"* ]]; then
            echo -e "  ${RED}${BOLD}🏴 CrackMapExec${NC} — Pass-the-Hash / SMB Attack"
            echo -e "     ${WHITE}কারণ: NTLM hash বা cracked password দিয়ে SMB access।${NC}"
            echo -e "     ${CYAN}কমান্ড: crackmapexec smb <target> -u users.txt -p $CRACK_OUTPUT${NC}"
            echo ""
        fi

        if [[ "$HASH_MODE" == "13100" ]] || [[ "$HASH_MODE" == "18200" ]]; then
            echo -e "  ${RED}${BOLD}🎫 Impacket${NC} — Kerberos Ticket Attack"
            echo -e "     ${WHITE}কারণ: Cracked Kerberos password দিয়ে domain access।${NC}"
            echo -e "     ${CYAN}কমান্ড: python3 psexec.py domain/user:<password>@<dc-ip>${NC}"
            echo ""
        fi
    else
        echo -e "  ${CYAN}${BOLD}Crack না হলে চেষ্টা করুন:${NC}"
        echo ""

        echo -e "  ${YELLOW}${BOLD}📝 John The Ripper${NC} — Alternative Cracker"
        echo -e "     ${WHITE}কারণ: Different rules ও modes try করুন John দিয়ে।${NC}"
        echo -e "     ${CYAN}কমান্ড: john --wordlist=$DEFAULT_WORDLIST --rules=Jumbo $HASH_FILE${NC}"
        echo ""

        echo -e "  ${BLUE}${BOLD}📚 CeWL${NC} — Target-specific Wordlist Generator"
        echo -e "     ${WHITE}কারণ: Target এর website থেকে custom wordlist বানান।${NC}"
        echo -e "     ${CYAN}কমান্ড: cewl http://target.com -d 3 -m 5 -o custom.txt${NC}"
        echo ""

        echo -e "  ${GREEN}${BOLD}📝 Crunch${NC} — Pattern Wordlist Generator"
        echo -e "     ${WHITE}কারণ: Password pattern জানলে targeted list বানান।${NC}"
        echo -e "     ${CYAN}কমান্ড: crunch 8 12 'abcdefghijklmnopqrstuvwxyz0123456789' -o out.txt${NC}"
        echo ""

        echo -e "  ${MAGENTA}${BOLD}🧠 CUPP${NC} — Social Engineering Wordlist"
        echo -e "     ${WHITE}কারণ: Target এর personal info দিয়ে targeted wordlist।${NC}"
        echo -e "     ${CYAN}কমান্ড: python3 cupp.py -i${NC}"
        echo ""
    fi

    echo -e "  ${WHITE}${BOLD}🗃️  Hashcat Mode Reference:${NC}"
    echo -e "     ${DIM}MD5=0 SHA1=100 SHA256=1400 SHA512=1700 NTLM=1000${NC}"
    echo -e "     ${DIM}bcrypt=3200 WPA=22000 SHA512crypt=1800 Kerberos=13100${NC}"
    echo ""
}

# ================================================================
# SAVE RESULTS
# ================================================================
save_results() {
    local tmp=$1

    echo ""
    read -p "$(echo -e ${YELLOW}"[?] Full report save করবেন? (y/n): "${NC})" sc
    if [[ "$sc" =~ ^[Yy]$ ]]; then
        local ts; ts=$(date +"%Y%m%d_%H%M%S")
        local safe; safe=$(basename "$HASH_FILE" | sed 's/[^a-zA-Z0-9._-]/_/g')
        local fname="$RESULTS_DIR/report_${safe}_${ts}.txt"

        {
            echo "============================================================"
            echo "  HASHCAT RESULTS  —  SAIMUM's Hashcat Automation Tool"
            echo "  Hash File  : $HASH_FILE"
            echo "  Hash Mode  : ${HASH_MODE:-Auto}"
            echo "  Attack     : ${SCAN_LABEL:-custom}"
            echo "  Date       : $(date)"
            echo "============================================================"
            echo ""
            echo "=== HASHCAT OUTPUT ==="
            cat "$tmp"
            echo ""
            echo "=== CRACKED PASSWORDS ==="
            [ -f "$CRACK_OUTPUT" ] && cat "$CRACK_OUTPUT" || echo "(none)"
        } > "$fname"

        echo -e "${GREEN}[✓] Report saved → $fname${NC}"
        echo "$(date) | ${SCAN_LABEL:-custom} | $HASH_FILE | $fname" >> "$HISTORY_FILE"
    else
        echo -e "${GREEN}[✓] Cracked passwords → $CRACK_OUTPUT${NC}"
        echo "$(date) | ${SCAN_LABEL:-custom} | $HASH_FILE | $CRACK_OUTPUT" >> "$HISTORY_FILE"
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

        # Auto detect mode
        if [ -n "$HASH_FILE" ] && [ -f "$HASH_FILE" ] && [ -z "$HASH_MODE" ]; then
            auto_detect_mode "$HASH_FILE"
            [ -n "$DETECTED_MODE" ] && HASH_MODE="$DETECTED_MODE"
        fi

        # Manual mode selection
        read -p "$(echo -e ${YELLOW}"Hash mode manually select করবেন? (y/n/Enter=n): "${NC})" man_ch
        [[ "$man_ch" =~ ^[Yy]$ ]] && select_hash_mode

        # Extra options
        get_extra_options

        # Show menu
        show_menu
        read -p "$(echo -e ${YELLOW}"[?] Attack option select করুন [0-30]: "${NC})" choice

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
            5)  mode_combination ;;
            6)  mode_mask_digits ;;
            7)  mode_mask_lower ;;
            8)  mode_mask_common ;;
            9)  mode_mask_full ;;
            10) mode_mask_custom ;;
            11) mode_mask_length_range ;;
            12) mode_hybrid_wordlist_mask ;;
            13) mode_hybrid_mask_wordlist ;;
            14) mode_rule_best64 ;;
            15) mode_rule_rockyou30k ;;
            16) mode_rule_dive ;;
            17) mode_rule_d3ad0ne ;;
            18) mode_rule_insidepro ;;
            19) mode_rule_custom ;;
            20) mode_wifi_wpa ;;
            21) mode_kerberoasting ;;
            22) mode_ntlm ;;
            23) mode_salted ;;
            24) mode_prince ;;
            25) show_cracked_passwords ;;
            26) mode_restore ;;
            27) mode_benchmark ;;
            28) show_hash_modes ;;
            29) mode_smart_combo ;;
            30) mode_allinone ;;
            *)  echo -e "${RED}[!] ভুল অপশন।${NC}" ;;
        esac

        echo ""
        read -p "$(echo -e ${YELLOW}"[?] আরেকটি attack করবেন? (y/n): "${NC})" again
        [[ ! "$again" =~ ^[Yy]$ ]] && {
            echo ""
            echo -e "${GREEN}${BOLD} Goodbye! Stay legal & ethical! 🛡️${NC}"
            echo ""
            exit 0
        }
        unset HASH_FILE HASH_MODE DETECTED_MODE CRACK_OUTPUT
        show_banner
    done
}

main
