#!/bin/bash
# =============================================================
#  PANDA KALI REMEDIATE  -  Purple Team Training Exercise
#  Removes all artifacts left by panda_kali.sh.
#  Walk through each step manually first, then run this
#  to verify your remediation was complete.
# =============================================================

DEPLOY_DIR="$HOME/.config/.diagtrack"
SCRIPT_NAME="diagtrack_runner.sh"
SERVICE_NAME="diagtrack-host"
SERVICE_FILE="$HOME/.config/systemd/user/${SERVICE_NAME}.service"

RED='\e[31m'; GREEN='\e[32m'; YELLOW='\e[33m'
CYAN='\e[36m'; BOLD='\e[1m'; RESET='\e[0m'

pass() { echo -e "  ${GREEN}[ OK ]${RESET} $1"; }
fail() { echo -e "  ${RED}[FAIL]${RESET} $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${RESET} $1"; }
info() { echo -e "  ${CYAN}[INFO]${RESET} $1"; }

echo -e "${BOLD}"
cat << 'BANNER'
  ############################
  ################         ###
  ##############  # ### ###  #
  ##################### ######      PANDA REMEDIATE
  ############################       Purple Team Exercise
  ############################
  ########  ##################
  ############################
BANNER
echo -e "${RESET}"

FAIL_COUNT=0

# ── Step 1: Kill running processes ────────────────────────────
echo -e "${BOLD}[STEP 1] Killing payload processes...${RESET}"

# Kill the main loop
if pgrep -f "$SCRIPT_NAME" > /dev/null 2>&1; then
    pkill -f "$SCRIPT_NAME" 2>/dev/null
    sleep 1
    if pgrep -f "$SCRIPT_NAME" > /dev/null 2>&1; then
        pkill -9 -f "$SCRIPT_NAME" 2>/dev/null
    fi
fi
if pgrep -f "$SCRIPT_NAME" > /dev/null 2>&1; then
    fail "$SCRIPT_NAME still running (PID $(pgrep -f $SCRIPT_NAME))"
    (( FAIL_COUNT++ ))
else
    pass "$SCRIPT_NAME not running."
fi

# Kill any orphaned panda terminal scripts
PANDA_PIDS=$(pgrep -f '/tmp/.panda_' 2>/dev/null)
if [ -n "$PANDA_PIDS" ]; then
    pkill -f '/tmp/.panda_' 2>/dev/null
    sleep 0.5
    if pgrep -f '/tmp/.panda_' > /dev/null 2>&1; then
        fail "Orphaned panda terminal scripts still running."
        (( FAIL_COUNT++ ))
    else
        pass "Orphaned panda terminal scripts killed."
    fi
else
    pass "No orphaned panda terminal scripts found."
fi

# Clean up any leftover /tmp panda scripts
TMP_COUNT=$(ls /tmp/.panda_*.sh 2>/dev/null | wc -l)
if [ "$TMP_COUNT" -gt 0 ]; then
    rm -f /tmp/.panda_*.sh
    pass "Removed $TMP_COUNT leftover /tmp panda script(s)."
else
    pass "No leftover /tmp panda scripts found."
fi
echo ""

# ── Step 2: Remove systemd user service ───────────────────────
echo -e "${BOLD}[STEP 2] Removing systemd user service...${RESET}"

if systemctl --user is-active "$SERVICE_NAME" &>/dev/null; then
    systemctl --user stop "$SERVICE_NAME" 2>/dev/null
    pass "Service stopped."
elif systemctl --user is-enabled "$SERVICE_NAME" &>/dev/null; then
    info "Service was enabled but not active (killed in step 1)."
else
    info "Service was not active."
fi

if systemctl --user is-enabled "$SERVICE_NAME" &>/dev/null; then
    systemctl --user disable "$SERVICE_NAME" 2>/dev/null
    pass "Service disabled."
else
    info "Service was not enabled."
fi

if [ -f "$SERVICE_FILE" ]; then
    rm -f "$SERVICE_FILE"
    systemctl --user daemon-reload 2>/dev/null
    if [ ! -f "$SERVICE_FILE" ]; then
        pass "Service file removed: $SERVICE_FILE"
    else
        fail "Service file still exists: $SERVICE_FILE"
        (( FAIL_COUNT++ ))
    fi
else
    info "Service file not found (already removed)."
fi

# Verify it's fully gone
if systemctl --user list-units --all 2>/dev/null | grep -q "$SERVICE_NAME"; then
    fail "$SERVICE_NAME still appears in systemd unit list."
    (( FAIL_COUNT++ ))
else
    pass "$SERVICE_NAME not present in systemd."
fi
echo ""

# ── Step 3: Remove cron entry ─────────────────────────────────
echo -e "${BOLD}[STEP 3] Removing cron persistence...${RESET}"

if crontab -l 2>/dev/null | grep -q "$SCRIPT_NAME"; then
    crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME" | crontab -
    if crontab -l 2>/dev/null | grep -q "$SCRIPT_NAME"; then
        fail "Cron entry still present."
        (( FAIL_COUNT++ ))
    else
        pass "Cron entry removed."
    fi
else
    info "No cron entry found (already removed)."
    pass "Cron clean."
fi
echo ""

# -- Step 4: Remove autostart desktop entry ------------------
echo -e "${BOLD}[STEP 4] Removing autostart persistence...${RESET}"

AUTOSTART_FILE="$HOME/.config/autostart/gnome-diagnostics-helper.desktop"
if [ -f "$AUTOSTART_FILE" ]; then
    rm -f "$AUTOSTART_FILE"
    if [ -f "$AUTOSTART_FILE" ]; then
        fail "Autostart file still exists: $AUTOSTART_FILE"
        (( FAIL_COUNT++ ))
    else
        pass "Autostart entry removed: $AUTOSTART_FILE"
    fi
else
    info "Autostart file not found (already removed)."
    pass "Autostart clean."
fi
echo ""

# -- Step 5: Remove deployment directory ---------------------
echo -e "${BOLD}[STEP 5] Removing payload files...${RESET}"

if [ -d "$DEPLOY_DIR" ]; then
    rm -rf "$DEPLOY_DIR"
    if [ -d "$DEPLOY_DIR" ]; then
        fail "Directory still exists: $DEPLOY_DIR"
        (( FAIL_COUNT++ ))
    else
        pass "Removed: $DEPLOY_DIR"
    fi
else
    info "Deploy directory not found (already removed)."
    pass "Filesystem clean."
fi
echo ""

# -- Step 6: Verify nothing remains --------------------------
echo -e "${BOLD}[STEP 6] Final verification...${RESET}"

# Check for the script anywhere under home
STRAY=$(find "$HOME" -name "$SCRIPT_NAME" 2>/dev/null)
if [ -n "$STRAY" ]; then
    fail "Stray copy of $SCRIPT_NAME found:"
    echo "         $STRAY"
    (( FAIL_COUNT++ ))
else
    pass "No stray copies of $SCRIPT_NAME found."
fi

# Check for the deploy dir or any .diagtrack dir
STRAY_DIR=$(find "$HOME" -name ".diagtrack" -type d 2>/dev/null)
if [ -n "$STRAY_DIR" ]; then
    fail "Stray .diagtrack directory found: $STRAY_DIR"
    (( FAIL_COUNT++ ))
else
    pass "No stray .diagtrack directories found."
fi

# Check autostart one more time
if [ -f "$AUTOSTART_FILE" ]; then
    fail "Autostart file still present: $AUTOSTART_FILE"
    (( FAIL_COUNT++ ))
else
    pass "Autostart clean."
fi

# Check cron one more time
if crontab -l 2>/dev/null | grep -qi "diagtrack\|panda"; then
    fail "Cron still contains a suspicious diagtrack/panda entry."
    crontab -l 2>/dev/null | grep -i "diagtrack\|panda"
    (( FAIL_COUNT++ ))
else
    pass "Cron is clean."
fi

# Check systemd one more time
if systemctl --user list-unit-files 2>/dev/null | grep -q "$SERVICE_NAME"; then
    fail "$SERVICE_NAME still registered with systemd."
    (( FAIL_COUNT++ ))
else
    pass "systemd is clean."
fi
echo ""

# ── Summary ───────────────────────────────────────────────────
echo -e "${BOLD}============================================================${RESET}"
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}All checks passed. System fully remediated.${RESET}"
else
    echo -e "  ${RED}${BOLD}$FAIL_COUNT check(s) failed. Review [FAIL] items above.${RESET}"
    echo ""
    echo -e "  ${CYAN}Manual investigation hints:${RESET}"
    echo -e "    Processes : ps aux | grep diagtrack"
    echo -e "    Cron      : crontab -l"
    echo -e "    systemd   : systemctl --user list-unit-files"
    echo -e "    Files     : find ~ -name '.diagtrack' -o -name 'diagtrack_runner.sh'"
    echo -e "    Tmp       : ls /tmp/.panda_*.sh"
fi
echo -e "${BOLD}============================================================${RESET}"
echo ""
