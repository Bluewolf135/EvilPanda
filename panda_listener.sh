#!/bin/bash
# =============================================================
#  PANDA LISTENER  -  Purple Team Training Exercise
#  Dual-port listener: Windows (4444) + Kali (4445)
#  Both listeners run simultaneously, output merges to one
#  terminal. Run on your Kali attack box before deploying.
# =============================================================

# -- Configuration ---------------------------------------------
WIN_PORT="4444"
LIN_PORT="4445"
OUTPUT_DIR="./panda_logs"
LOG_INDEX="$OUTPUT_DIR/.index.log"

# -- Colors ----------------------------------------------------
RED='\e[31m'; GREEN='\e[32m'; YELLOW='\e[33m'
CYAN='\e[36m'; BLUE='\e[34m'; BOLD='\e[1m'; RESET='\e[0m'

# -- Preflight -------------------------------------------------
if ! command -v nc &>/dev/null; then
    echo -e "${RED}[FAIL]${RESET} netcat not found.  apt install netcat-openbsd"
    exit 1
fi
if ! command -v python3 &>/dev/null; then
    echo -e "${RED}[FAIL]${RESET} python3 not found."
    exit 1
fi

mkdir -p "$OUTPUT_DIR/windows"
mkdir -p "$OUTPUT_DIR/linux"

# -- Banner ----------------------------------------------------
echo -e "${BOLD}"
cat << 'BANNER'
          ##
   ###----##
   ###      \
   /        ##__
  /       ##   #     --#
 :           __/   -#   :
,'          _\     >     :
####      :'     #########:       PANDA LISTENER
##########          |  ###:       Purple Team Exercise
######################    :
#######################   :
######################...,'
BANNER
echo -e "${RESET}"
echo -e "  ${CYAN}Windows payloads :${RESET} 0.0.0.0:${WIN_PORT}  ${YELLOW}(panda_deploy.bat)${RESET}"
echo -e "  ${CYAN}Linux payloads   :${RESET} 0.0.0.0:${LIN_PORT}  ${BLUE}(panda_kali.sh)${RESET}"
echo -e "  ${CYAN}Output dir       :${RESET} $OUTPUT_DIR"
echo -e "  ${CYAN}Ctrl+C to stop both listeners.${RESET}"
echo ""

# -- Section parser --------------------------------------------
parse_sections() {
    local outfile="$1"
    python3 - "$outfile" << 'PYEOF'
import sys

sections = [
    "PASSWORD CHANGES",
    "USER CREATION",
    "USER DELETION",
    "PERMISSION / PRIVILEGE CHANGES",
    # Windows-only sections
    "LOCAL USER SNAPSHOT (Get-LocalUser)",
    "LOCAL USER SNAPSHOT (net user)",
    # Linux-only sections
    "/etc/passwd SNAPSHOT",
    "/etc/group SNAPSHOT",
]

try:
    with open(sys.argv[1], 'r', encoding='utf-8', errors='replace') as f:
        lines = f.readlines()
except Exception:
    print("NONE|parse error|0")
    sys.exit(0)

current = None
content = {s: [] for s in sections}

for line in lines:
    stripped = line.strip()
    matched = False
    for s in sections:
        if stripped == f"=== {s} ===":
            current = s
            matched = True
            break
    if matched:
        continue
    if stripped.startswith("==="):
        current = None
        continue
    if current and stripped:
        content[current].append(stripped)

windows_only = {"LOCAL USER SNAPSHOT (Get-LocalUser)", "LOCAL USER SNAPSHOT (net user)"}
linux_only   = {"/etc/passwd SNAPSHOT", "/etc/group SNAPSHOT"}

has_windows = any(content[s] for s in windows_only)
has_linux   = any(content[s] for s in linux_only)

for s in sections:
    if s in windows_only and has_linux and not has_windows:
        continue
    if s in linux_only and has_windows and not has_linux:
        continue
    items = content[s]
    denied = any("access denied" in l.lower() for l in items)
    real = [l for l in items if l not in ("(no events)", "(unavailable)")
            and "access denied" not in l.lower()]
    if real:
        print(f"HIT|{s}|{len(real)}")
    elif denied:
        print(f"DENIED|{s}|0")
    else:
        print(f"NONE|{s}|0")
PYEOF
}

# -- Connection handler ----------------------------------------
# Args: $1=platform label  $2=color  $3=subdir
handle_connection() {
    local platform="$1" color="$2" subdir="$3"
    local tmpfile
    tmpfile=$(mktemp /tmp/.panda_recv_XXXXXX)
    cat > "$tmpfile"

    if [ ! -s "$tmpfile" ]; then
        rm -f "$tmpfile"
        return
    fi

    local hostname timestamp filename
    hostname=$( grep -i "^X-Hostname:"  "$tmpfile" | head -1 | awk '{print $2}' | tr -d '\r\n')
    timestamp=$(grep -i "^X-Timestamp:" "$tmpfile" | head -1 | awk '{print $2}' | tr -d '\r\n')
    filename=$( grep -i "^X-Filename:"  "$tmpfile" | head -1 | awk '{print $2}' | tr -d '\r\n')

    local body
    body=$(awk 'found{print} /^\r?$/{found=1}' "$tmpfile")

    if [ -z "$hostname" ]; then
        hostname="unknown_$(date +%H%M%S)"
        timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        filename="raw_$(date +%Y%m%d_%H%M%S).txt"
        body=$(cat "$tmpfile")
    fi

    filename=$(echo "$filename" | tr -cd '[:alnum:]_.-')
    [ -z "$filename" ] && filename="dump_$(date +%Y%m%d_%H%M%S).txt"

    local outfile="$OUTPUT_DIR/$subdir/${hostname}_${filename}"
    printf '%s' "$body" > "$outfile"

    local linecount bytecount
    linecount=$(wc -l < "$outfile")
    bytecount=$(wc -c < "$outfile")

    echo "$(date '+%Y-%m-%d %H:%M:%S') | platform=$platform | host=$hostname | ts=$timestamp | file=$outfile | bytes=$bytecount" \
        >> "$LOG_INDEX"

    local tag
    tag=$(echo -e "${color}[${platform}]${RESET}")

    echo -e "${GREEN}[+] DUMP RECEIVED${RESET}  $tag  $(date '+%H:%M:%S')"
    echo -e "    ${CYAN}Host      :${RESET} $hostname"
    echo -e "    ${CYAN}Timestamp :${RESET} $timestamp"
    echo -e "    ${CYAN}Saved to  :${RESET} $outfile"
    echo -e "    ${CYAN}Size      :${RESET} $bytecount bytes / $linecount lines"
    echo -e "    ${CYAN}Contents  :${RESET}"

    local scan_result
    scan_result=$(parse_sections "$outfile")

    while IFS='|' read -r status section count; do
        case "$status" in
            HIT)    echo -e "      ${YELLOW}[!]${RESET} $section: $count line(s)" ;;
            DENIED) echo -e "      ${RED}[X]${RESET} $section: access denied (needs admin)" ;;
            NONE)   echo -e "          $section: (none)" ;;
        esac
    done <<< "$scan_result"

    echo ""
    rm -f "$tmpfile"
}

# -- Per-port loops --------------------------------------------
listen_windows() {
    while true; do
        nc -lvp "$WIN_PORT" 2>/dev/null | handle_connection "WINDOWS" "$YELLOW" "windows"
        sleep 0.3
    done
}

listen_linux() {
    while true; do
        nc -lvp "$LIN_PORT" 2>/dev/null | handle_connection "LINUX  " "$BLUE" "linux"
        sleep 0.3
    done
}

# -- Signal handler --------------------------------------------
cleanup() {
    echo -e "\n${YELLOW}[*] Shutting down listeners...${RESET}"
    kill "$WIN_PID" "$LIN_PID" 2>/dev/null
    wait "$WIN_PID" "$LIN_PID" 2>/dev/null
    echo -e "${CYAN}[*] Windows dumps : $OUTPUT_DIR/windows/${RESET}"
    echo -e "${CYAN}[*] Linux dumps   : $OUTPUT_DIR/linux/${RESET}"
    echo -e "${CYAN}[*] Index log     : $LOG_INDEX${RESET}"
    exit 0
}
trap cleanup INT TERM

# -- Launch ----------------------------------------------------
echo -e "${GREEN}[*] Both listeners active. Waiting for connections...${RESET}"
echo ""

listen_windows &
WIN_PID=$!

listen_linux &
LIN_PID=$!

wait
