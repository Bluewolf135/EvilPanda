@echo off
setlocal

:: ============================================================
::  PANDA REMEDIATE  -  Purple Team Training Exercise
:: ============================================================

set DEPLOY_ROOT=C:\ProgramData\WindowsUpdateManager
set DEPLOY_DIR=C:\ProgramData\WindowsUpdateManager\DiagCache
set PS1_NAME=diagtrack_runner.ps1
set VBS_NAME=diagtrack_host.vbs
set TASK_NAME=MicrosoftDiagnosticsHost
set REG_KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Run
set REG_VAL=DiagnosticsHost

echo ============================================================
echo  PANDA REMEDIATION CHECKLIST
echo ============================================================
echo.

:: -- Step 1: Kill the hidden payload loop ---------------------
echo [STEP 1] Killing payload processes...

:: Kill the VBS launcher
taskkill /F /IM wscript.exe /T >nul 2>&1

:: Kill the hidden PowerShell loop by matching the script path
:: This is the process with no window that survives title-based kills
powershell -NoProfile -Command "Get-WinEvent -ErrorAction SilentlyContinue; Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { try { $_.MainModule.FileName } catch {} } | ForEach-Object { try { $cmd = (Get-WmiObject Win32_Process -Filter \"ProcessId=$($_.Id)\").CommandLine; if ($cmd -like '*diagtrack*') { $_.Kill() } } catch {} }"

:: Also kill any visible panda windows by title
taskkill /F /FI "WINDOWTITLE eq Bao Bao"          >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq Mei Xiang"         >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq Tian Tian"         >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq Bei Bei"           >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq Xiao Qi Ji"        >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq Buttercup"         >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq Dumpling"          >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq Wonton"            >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq Mr. Fluffybottom"  >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq Professor Bamboo"  >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq Noodle"            >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq Mochi"             >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq Pudding"           >nul 2>&1
taskkill /F /FI "WINDOWTITLE eq Lord Bambington"   >nul 2>&1

:: Verify wscript gone
tasklist /FI "IMAGENAME eq wscript.exe" 2>nul | find /I "wscript.exe" >nul
if %ERRORLEVEL% EQU 0 (echo [FAIL] wscript.exe still running.) else (echo [ OK ] wscript.exe stopped.)

:: Verify no diagtrack powershell remains
powershell -NoProfile -Command "exit (Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { try { (Get-WmiObject Win32_Process -Filter \"ProcessId=$($_.Id)\").CommandLine -like '*diagtrack*' } catch { $false } }).Count" >nul 2>&1
if %ERRORLEVEL% EQU 0 (echo [ OK ] No diagtrack PowerShell process found.) else (echo [FAIL] diagtrack PowerShell process still running.)
echo.

:: -- Step 2: Remove registry run key -------------------------
echo [STEP 2] Removing registry persistence...
reg delete "%REG_KEY%" /v "%REG_VAL%" /f >nul 2>&1
reg query "%REG_KEY%" /v "%REG_VAL%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (echo [FAIL] Registry key still exists.) else (echo [ OK ] Registry key removed.)
echo.

:: -- Step 3: Remove scheduled task ---------------------------
echo [STEP 3] Removing scheduled task...
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (echo [FAIL] Scheduled task still exists.) else (echo [ OK ] Scheduled task removed.)
echo.

:: -- Step 4: Delete payload files ----------------------------
echo [STEP 4] Deleting payload files...
attrib -h -s "%DEPLOY_DIR%"           >nul 2>&1
attrib -h -s "%DEPLOY_DIR%\*.*"       >nul 2>&1
attrib -h -s "%DEPLOY_DIR%\.logs"     >nul 2>&1
attrib -h -s "%DEPLOY_DIR%\.logs\*"   >nul 2>&1
attrib -h -s "%DEPLOY_ROOT%"          >nul 2>&1
rd /S /Q "%DEPLOY_ROOT%"              >nul 2>&1
if exist "%DEPLOY_ROOT%" (echo [FAIL] Directory still exists: %DEPLOY_ROOT%) else (echo [ OK ] Payload directory removed.)
echo.

:: -- Step 5: Final verification ------------------------------
echo [STEP 5] Final verification...
reg query "%REG_KEY%" /v "%REG_VAL%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (echo [FAIL] Registry key still present.) else (echo [ OK ] Registry clean.)
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (echo [FAIL] Scheduled task still present.) else (echo [ OK ] Scheduled tasks clean.)
if exist "%DEPLOY_ROOT%" (echo [FAIL] %DEPLOY_ROOT% still exists.) else (echo [ OK ] Filesystem clean.)
echo.

echo ============================================================
echo  Done. Review any [FAIL] items above.
echo    Processes : taskmgr - Details tab, filter CommandLine
echo    Registry  : regedit - %REG_KEY%
echo    Tasks     : taskschd.msc
echo    Files     : %DEPLOY_ROOT%
echo ============================================================
echo.
pause
endlocal
