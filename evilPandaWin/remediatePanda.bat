@echo off
setlocal

:: ============================================================
::  PANDA REMEDIATE  -  Purple Team Training Exercise
::  Run from an admin cmd window (right-click > Run as admin).
:: ============================================================

set DEPLOY_DIR=C:\ProgramData\WindowsUpdateManager\DiagCache
set DEPLOY_ROOT=C:\ProgramData\WindowsUpdateManager
set TASK_NAME=MicrosoftDiagnosticsHost
set REG_KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Run
set REG_VAL=DiagnosticsHost

echo ============================================================
echo  PANDA REMEDIATION
echo  Running as: %USERNAME%
echo ============================================================
echo.

:: Verify elevation
whoami /groups | findstr "S-1-16-12288" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [FAIL] Not running as administrator. Right-click cmd and run as admin.
    pause & exit /b 1
)
echo [ OK ] Elevated session confirmed.
echo.

:: -- Step 1: Kill all payload processes ----------------------
echo [STEP 1] Killing payload processes...

:: Kill wscript launcher
taskkill /F /IM wscript.exe /T >nul 2>&1

:: Kill all powershell.exe except this cmd session's parent.
:: The hidden payload loop registers as .NET-BroadcastEventWindow
:: and has no meaningful window title - we must kill by process,
:: not by title. We exclude the PID of any powershell that launched
:: this bat (none - bat runs under cmd.exe) so killing all is safe.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-Process powershell -ErrorAction SilentlyContinue | Stop-Process -Force" >nul 2>&1

ping -n 3 127.0.0.1 >nul 2>&1

tasklist /FI "IMAGENAME eq wscript.exe" 2>nul | find /I "wscript.exe" >nul
if %ERRORLEVEL% EQU 0 (echo [FAIL] wscript.exe still running.) else (echo [ OK ] wscript.exe stopped.)

tasklist /FI "IMAGENAME eq powershell.exe" 2>nul | find /I "powershell.exe" >nul
if %ERRORLEVEL% EQU 0 (echo [WARN] powershell.exe still present - may be unrelated process.) else (echo [ OK ] No powershell.exe running.)
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
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Remove-Item 'C:\Windows\System32\Tasks\%TASK_NAME%' -Force -ErrorAction SilentlyContinue" >nul 2>&1
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (echo [FAIL] Scheduled task still exists.) else (echo [ OK ] Scheduled task removed.)
echo.

:: -- Step 4: Delete payload files ----------------------------
echo [STEP 4] Deleting payload files...

:: Strip hidden/system/readonly recursively before delete
attrib -h -s -r "%DEPLOY_ROOT%" /S /D >nul 2>&1

rd /S /Q "%DEPLOY_ROOT%" >nul 2>&1

if exist "%DEPLOY_ROOT%" (echo [FAIL] Directory still exists: %DEPLOY_ROOT%) else (echo [ OK ] Payload directory removed.)
echo.

:: -- Step 5: Final verification ------------------------------
echo [STEP 5] Final verification...

reg query "%REG_KEY%" /v "%REG_VAL%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (echo [FAIL] Registry key still present.) else (echo [ OK ] Registry clean.)

schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (echo [FAIL] Scheduled task still present.) else (echo [ OK ] Scheduled tasks clean.)

if exist "%DEPLOY_ROOT%" (echo [FAIL] %DEPLOY_ROOT% still exists.) else (echo [ OK ] Filesystem clean.)

tasklist /FI "IMAGENAME eq powershell.exe" 2>nul | find /I "powershell.exe" >nul
if %ERRORLEVEL% EQU 0 (echo [WARN] powershell.exe running - verify manually in taskmgr.) else (echo [ OK ] No powershell.exe running.)

echo.
echo ============================================================
echo  Done. Review any [FAIL] or [WARN] items above.
echo    Processes : taskmgr - Details tab
echo    Registry  : regedit - %REG_KEY%
echo    Tasks     : taskschd.msc
echo    Files     : %DEPLOY_ROOT%
echo ============================================================
echo.
pause
endlocal
