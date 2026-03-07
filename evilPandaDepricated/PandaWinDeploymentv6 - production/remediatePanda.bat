@echo off
setlocal

:: ============================================================
::  PANDA REMEDIATE  -  Purple Team Training Exercise
::  Must be run from an admin cmd window manually.
::  DO NOT double-click - open cmd as admin, then run this.
:: ============================================================

set DEPLOY_DIR=C:\ProgramData\WindowsUpdateManager\DiagCache
set TASK_NAME=MicrosoftDiagnosticsHost
set REG_KEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Run
set REG_VAL=DiagnosticsHost
set KILLER=%TEMP%\panda_kill.ps1

echo ============================================================
echo  PANDA REMEDIATION CHECKLIST
echo  Running as: %USERNAME%
echo ============================================================
echo.

:: -- Step 1: Kill processes -----------------------------------
echo [STEP 1] Killing payload processes...

if exist "%KILLER%" del "%KILLER%" >nul 2>&1
echo Get-WmiObject Win32_Process ^| Where-Object { $_.CommandLine -like '*DiagCache*' -or $_.CommandLine -like '*diagtrack*' } ^| ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } >> "%KILLER%"

taskkill /F /IM wscript.exe /T >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%KILLER%" >nul 2>&1
del "%KILLER%" >nul 2>&1
ping -n 3 127.0.0.1 >nul 2>&1

tasklist /FI "IMAGENAME eq wscript.exe" 2>nul | find /I "wscript.exe" >nul
if %ERRORLEVEL% EQU 0 (echo [FAIL] wscript.exe still running.) else (echo [ OK ] wscript.exe stopped.)

powershell -NoProfile -ExecutionPolicy Bypass -Command "if ((Get-WmiObject Win32_Process | Where-Object { $_.CommandLine -like '*DiagCache*' -or $_.CommandLine -like '*diagtrack*' }).Count -gt 0) { exit 1 } else { exit 0 }" >nul 2>&1
if %ERRORLEVEL% EQU 1 (echo [FAIL] diagtrack process still running.) else (echo [ OK ] No diagtrack process found.)
echo.

:: -- Step 2: Remove registry run key -------------------------
echo [STEP 2] Removing registry persistence...
reg delete "%REG_KEY%" /v "%REG_VAL%" /f >nul 2>&1
reg query "%REG_KEY%" /v "%REG_VAL%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (echo [FAIL] Registry key still exists.) else (echo [ OK ] Registry key removed.)
echo.

:: -- Step 3: Remove scheduled task ---------------------------
echo [STEP 3] Removing scheduled task...
schtasks /end /tn "%TASK_NAME%" >nul 2>&1
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
:: Fallback: use PowerShell Unregister-ScheduledTask which handles elevated tasks reliably
powershell -NoProfile -ExecutionPolicy Bypass -Command "Unregister-ScheduledTask -TaskName '%TASK_NAME%' -Confirm:$false -ErrorAction SilentlyContinue" >nul 2>&1
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (echo [FAIL] Scheduled task still exists.) else (echo [ OK ] Scheduled task removed.)
echo.

:: -- Step 4: Delete payload files ----------------------------
echo [STEP 4] Deleting payload files...
attrib -h -s "%DEPLOY_DIR%\.logs\*"   >nul 2>&1
attrib -h -s "%DEPLOY_DIR%\.logs"     >nul 2>&1
attrib -h -s "%DEPLOY_DIR%\*.*"       >nul 2>&1
attrib -h -s "%DEPLOY_DIR%"           >nul 2>&1
rd /S /Q "%DEPLOY_DIR%"               >nul 2>&1
:: Also clean up empty parent if nothing else is in it
rd "%DEPLOY_DIR%\.." >nul 2>&1
if exist "%DEPLOY_DIR%" (echo [FAIL] DiagCache directory still exists.) else (echo [ OK ] Payload directory removed.)
echo.

:: -- Step 5: Final verification ------------------------------
echo [STEP 5] Final verification...
reg query "%REG_KEY%" /v "%REG_VAL%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (echo [FAIL] Registry key still present.) else (echo [ OK ] Registry clean.)
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (echo [FAIL] Scheduled task still present.) else (echo [ OK ] Scheduled tasks clean.)
if exist "%DEPLOY_DIR%" (echo [FAIL] DiagCache still exists.) else (echo [ OK ] Filesystem clean.)
echo.

echo ============================================================
echo  Done. Review any [FAIL] items above.
echo    Registry  : regedit - %REG_KEY%
echo    Tasks     : taskschd.msc
echo    Files     : %DEPLOY_DIR%
echo ============================================================
echo.
pause
endlocal
