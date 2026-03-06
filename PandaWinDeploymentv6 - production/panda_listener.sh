#!/bin/bash
# =============================================================
#  PANDA LISTENER  -  Purple Team Training Exercise
#  Receives exfil dumps from panda_deploy.bat (Windows) and
#  panda_kali.sh (Linux) via HTTP POST to netcat listener.
#  Run this on your Kali attack box before deploying payloads.
# =============================================================

# ── Configuration ─────────────────────────────────────────────
LISTEN_PORT="4444"
OUTPUT_DIR="./panda_logs"
LOG_INDEX="$OUTPUT_DIR/.index.log"

# ── Colors ────────────────────────────────────────────────────
RED='\e[31m'; GREEN='\e[32m'; YELLOW='\e[33m'
CYAN='\e[36m'; BOLD='\e[1m'; RESET='\e[0m'

# ── Preflight ─────────────────────────────────────────────────
if ! command -v nc &>/dev/null; then
    echo -e "${RED}[FAIL]${RESET} netcat not found. Install: apt install netcat-openbsd"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

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
echo -e "${CYAN}Output dir   :${RESET} $OUTPUT_DIR"
echo -e "${CYAN}Listening on :${RESET} 0.0.0.0:$LISTEN_PORT"
echo -e "${CYAN}Ctrl+C to stop.${RESET}"
echo ""

# ── Handle one incoming connection ────────────────────────────
handle_connection() {
    local tmpfile
    tmpfile=$(mktemp /tmp/.panda_recv_XXXXXX)

    # Slurp everything nc gives us
    cat > "$tmpfile"

    # Must have received something
    if [ ! -s "$tmpfile" ]; then
        rm -f "$tmpfile"
        return
    fi

    # ── Parse HTTP headers ────────────────────────────────────
    local hostname timestamp filename
    hostname=$(grep -i  "^X-Hostname:"  "$tmpfile" | head -1 | awk '{print $2}' | tr -d '\r\n')
    timestamp=$(grep -i "^X-Timestamp:" "$tmpfile" | head -1 | awk '{print $2}' | tr -d '\r\n')
    filename=$(grep -i  "^X-Filename:"  "$tmpfile" | head -1 | awk '{print $2}' | tr -d '\r\n')

    # ── Separate body (everything after the blank line) ───────
    local body
    body=$(awk 'found{print} /^\r?$/{found=1}' "$tmpfile")

    # Fallback if no HTTP headers (raw dump)
    if [ -z "$hostname" ]; then
        hostname="unknown_$(date +%H%M%S)"
        timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        filename="raw_$(date +%Y%m%d_%H%M%S).txt"
        body=$(cat "$tmpfile")
    fi

    # Sanitize filename
    filename=$(echo "$filename" | tr -cd '[:alnum:]_.-')
    [ -z "$filename" ] && filename="dump_$(date +%Y%m%d_%H%M%S).txt"

    # Save to output dir, prefixed with hostname so multi-machine
    # deployments don't collide
    local outfile="$OUTPUT_DIR/${hostname}_${filename}"
    printf '%s' "$body" > "$outfile"

    local linecount bytecount
    linecount=$(wc -l < "$outfile")
    bytecount=$(wc -c < "$outfile")

    # ── Index entry ───────────────────────────────────────────
    echo "$(date '+%Y-%m-%d %H:%M:%S') | host=$hostname | ts=$timestamp | file=$outfile | bytes=$bytecount" \
        >> "$LOG_INDEX"

    # ── Print live summary ────────────────────────────────────
    echo -e "${GREEN}[+] DUMP RECEIVED${RESET}  $(date '+%H:%M:%S')"
    echo -e "    ${CYAN}Host      :${RESET} $hostname"
    echo -e "    ${CYAN}Timestamp :${RESET} $timestamp"
    echo -e "    ${CYAN}Saved to  :${RESET} $outfile"
    echo -e "    ${CYAN}Size      :${RESET} $bytecount bytes  /  $linecount lines"
    echo -e "    ${CYAN}Contents  :${RESET}"

    # Scan each section and report what was found
    # Uses python3 for reliable section parsing - no awk delimiter issues
    local scan_result
    scan_result=$(python3 - "$outfile" << 'PYEOF'
import sys

sections = [
    "PASSWORD CHANGES",
    "USER CREATION",
    "USER DELETION",
    "PERMISSION / PRIVILEGE CHANGES",
    "LOCAL USER SNAPSHOT (Get-LocalUser)",
    "LOCAL USER SNAPSHOT (net user)",
]

with open(sys.argv[1], 'r', encoding='utf-8', errors='replace') as f:
    lines = f.readlines()

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

for s in sections:
    items = content[s]
    # Filter out noise lines
    denied = any("access denied" in l.lower() for l in items)
    real = [l for l in items if l not in ("(no events)", "(unavailable)") and "access denied" not in l.lower()]
    if real:
        print(f"HIT|{s}|{len(real)}")
    elif denied:
        print(f"DENIED|{s}|0")
    else:
        print(f"NONE|{s}|0")
PYEOF
)

    while IFS='|' read -r status section count; do
        case "$status" in
            HIT)    echo -e "      ${YELLOW}[!]${RESET} $section: $count line(s)" ;;
            DENIED) echo -e "      ${RED}[!]${RESET} $section: access denied (needs admin)" ;;
            NONE)   echo -e "          $section: (none)" ;;
        esac
    done <<< "$scan_result"

    echo ""
    rm -f "$tmpfile"
}

# ── Signal handler ────────────────────────────────────────────
cleanup() {
    echo -e "\n${YELLOW}[*] Listener stopped.${RESET}"
    echo -e "${CYAN}[*] Dumps saved to: $OUTPUT_DIR${RESET}"
    echo -e "${CYAN}[*] Index log: $LOG_INDEX${RESET}"
    exit 0
}
trap cleanup INT TERM

# ── Main loop ─────────────────────────────────────────────────
echo -e "${GREEN}[*] Waiting for connections...${RESET}"
echo ""

while true; do
    nc -lvp "$LISTEN_PORT" 2>/dev/null | handle_connection
    sleep 0.3
done
