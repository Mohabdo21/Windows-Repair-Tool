@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "ERRORLEVEL="
set "RANDOM="
:: Per-run directory owns the command log and historical CBS SFC details.
:: Result is captured immediately; CALL arguments below are fixed tokens, not paths.
set "LogRoot=%LOCALAPPDATA%\WindowsRepairTool"
if not defined LOCALAPPDATA set "LogRoot=%TEMP%\WindowsRepairTool"
if not exist "%LogRoot%" mkdir "%LogRoot%"
if not exist "%LogRoot%" goto logFailure

:newRun
set "RunDir=%LogRoot%\run-%RANDOM%-%RANDOM%"
if exist "%RunDir%" goto newRun
mkdir "%RunDir%"
if errorlevel 1 goto logFailure
set "LogFile=%RunDir%\repair.log"
>"%LogFile%" echo Windows Repair Tool - %DATE% %TIME%
if errorlevel 1 goto logFailure
"%SystemRoot%\System32\fltmc.exe" >>"%LogFile%" 2>&1
set "Result=%errorlevel%"
if "%Result%"=="0" goto menu
echo Administrator check failed. Run this script as administrator.
echo Log: "%LogFile%"
pause
exit /b 1

:logFailure
echo Cannot create a writable repair log. No repairs will be attempted.
pause
exit /b 1

:menu
cls
echo =======================================
echo        System Health Check Menu
echo =======================================
echo 1. Quick Status Check (/CheckHealth)
echo 2. Detailed Scan (/ScanHealth)
echo 3. Repair System Image (/RestoreHealth)
echo 4. Scan and Repair System Files (sfc /scannow)
echo 5. Windows Update Cache Reset - fallback only
echo 6. RestoreHealth then SFC - stops if DISM needs a restart or fails
echo 7. Restart System
echo 8. Restart System to Firmware Settings
echo 9. Help - Command Descriptions
echo 0. Exit
echo =======================================
echo Log: "%LogFile%"
"%SystemRoot%\System32\choice.exe" /c 1234567890 /n /m "Select an option: "
if errorlevel 255 exit /b 1
if errorlevel 10 exit /b 0
if errorlevel 9 goto help
if errorlevel 8 goto restartbios
if errorlevel 7 goto restart
if errorlevel 6 goto all
if errorlevel 5 goto updatefix
if errorlevel 4 goto sfcscan
if errorlevel 3 goto restorehealth
if errorlevel 2 goto scanhealth
if errorlevel 1 goto checkhealth
exit /b 0

:checkhealth
call :runDism CheckHealth
goto operationDone

:scanhealth
call :runDism ScanHealth
goto operationDone

:restorehealth
call :runDism RestoreHealth
goto operationDone

:sfcscan
call :runSfc
goto operationDone

:all
call :runDism RestoreHealth
if not "%Result%"=="0" goto operationDone
call :runSfc
goto operationDone

:operationDone
echo Review the command output in "%LogFile%"
echo Native logs: "%SystemRoot%\Logs\DISM\dism.log" and "%SystemRoot%\Logs\CBS\CBS.log"
pause
goto menu

:runDism
set "CommandName=DISM %~1"
echo Running %CommandName%. Output is being written to the log; this can take some time.
>>"%LogFile%" echo [%DATE% %TIME%] %CommandName%
"%SystemRoot%\System32\DISM.exe" /Online /Cleanup-Image /%~1 >>"%LogFile%" 2>&1
set "Result=%errorlevel%"
if "%Result%"=="3010" echo DISM completed with restart required. Restart before continuing repairs.
if "%Result%"=="3017" echo DISM failed and requires a restart to roll back changes.
call :reportResult
exit /b %Result%

:runSfc
set "CommandName=SFC scannow"
echo Running System File Checker. Output is being written to the log.
>>"%LogFile%" echo [%DATE% %TIME%] %CommandName%
"%SystemRoot%\System32\sfc.exe" /scannow >>"%LogFile%" 2>&1
set "Result=%errorlevel%"
call :reportResult
:: SFC's code alone is not a complete health diagnosis. Preserve its output.
echo Review SFC output for findings and any restart instructions.
call :sfcDetails
exit /b %Result%

:sfcDetails
if not exist "%SystemRoot%\Logs\CBS\CBS.log" goto noCbsLog
"%SystemRoot%\System32\findstr.exe" /l /c:"[SR]" "%SystemRoot%\Logs\CBS\CBS.log" >"%RunDir%\sfcdetails.txt" 2>>"%LogFile%"
set "DetailsResult=%errorlevel%"
>>"%LogFile%" echo SFC details extraction exit code: %DetailsResult%
if "%DetailsResult%"=="0" echo SFC details: "%RunDir%\sfcdetails.txt" - includes historical entries, not just errors or this run.
if "%DetailsResult%"=="1" echo No [SR] entries found in CBS.log.
if not "%DetailsResult%"=="0" if not "%DetailsResult%"=="1" echo Could not extract SFC details. Review CBS.log directly.
exit /b 0

:noCbsLog
echo CBS.log was not found; no SFC details were extracted.
>>"%LogFile%" echo CBS.log was not found; no SFC details were extracted.
exit /b 0

:reportResult
echo %CommandName% exit code: %Result%. Review the log for findings.
>>"%LogFile%" echo [%DATE% %TIME%] %CommandName% exit code: %Result%
if not "%Result%"=="0" if not "%Result%"=="3010" echo Nonzero status. Review command output; do not assume repairs succeeded.
exit /b %Result%

:updatefix
echo Use Windows Update troubleshooting first. This is a fallback cache reset only.
echo This stops BITS, Windows Update and Cryptographic Services and backs up their caches.
echo Downloaded update data will be downloaded again. Existing backups are retained.
"%SystemRoot%\System32\choice.exe" /c YN /n /m "Troubleshooting failed and you want to reset the caches? [Y/N]: "
if errorlevel 255 goto menu
if errorlevel 2 goto menu
if not errorlevel 1 goto menu
set "UpdateFailed=1"
call :stopService bits
set "StepResult=%errorlevel%"
if not "%StepResult%"=="0" goto updateRestart
call :stopService wuauserv
set "StepResult=%errorlevel%"
if not "%StepResult%"=="0" goto updateRestart
call :stopService cryptsvc
set "StepResult=%errorlevel%"
if not "%StepResult%"=="0" goto updateRestart
call :backupCache software
set "StepResult=%errorlevel%"
if not "%StepResult%"=="0" goto updateRestart
call :backupCache catalog
set "StepResult=%errorlevel%"
if not "%StepResult%"=="0" goto updateRestart
set "UpdateFailed=0"
goto updateRestart

:updateRestart
:: Attempt every start even after a stop, rename, or another start fails.
call :startService cryptsvc
set "StepResult=%errorlevel%"
if not "%StepResult%"=="0" set "UpdateFailed=1"
call :startService wuauserv
set "StepResult=%errorlevel%"
if not "%StepResult%"=="0" set "UpdateFailed=1"
call :startService bits
set "StepResult=%errorlevel%"
if not "%StepResult%"=="0" set "UpdateFailed=1"
if "%UpdateFailed%"=="0" echo Cache reset finished. Retry Windows Update; this does not prove the issue is fixed.
if "%UpdateFailed%"=="1" echo Cache reset incomplete. Review errors; any backups already created have been retained.
>>"%LogFile%" echo Cache reset failure flag: %UpdateFailed%
goto operationDone

:stopService
set "CommandName=Stop service %~1"
set "ServiceName=%~1"
echo %CommandName%
:: SC does not force-stop dependent services. Its return code alone is not a stopped-state check.
"%SystemRoot%\System32\sc.exe" stop %~1 >>"%LogFile%" 2>&1
set "Result=%errorlevel%"
>>"%LogFile%" echo %CommandName% request exit code: %Result%
:: Already stopped is safe. Pending stops must reach Stopped within 30 seconds.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -Command "try { $s = Get-Service -Name $env:ServiceName -ErrorAction Stop; $s.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30)); exit 0 } catch { Write-Output $_; exit 1 }" >>"%LogFile%" 2>&1
set "Result=%errorlevel%"
call :reportResult
exit /b %Result%

:startService
set "CommandName=Start service %~1"
set "ServiceName=%~1"
echo %CommandName%
:: Recovery must execute even if the log has become unwritable. Errors stay visible.
"%SystemRoot%\System32\sc.exe" start %~1
set "Result=%errorlevel%"
>>"%LogFile%" echo %CommandName% request exit code: %Result%
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -Command "try { $s = Get-Service -Name $env:ServiceName -ErrorAction Stop; $s.WaitForStatus('Running', [TimeSpan]::FromSeconds(30)); exit 0 } catch { Write-Output $_; exit 1 }"
set "Result=%errorlevel%"
call :reportResult
exit /b %Result%

:backupCache
set "CacheParent=%SystemRoot%"
set "CacheName=SoftwareDistribution"
if "%~1"=="catalog" set "CacheParent=%SystemRoot%\System32"
if "%~1"=="catalog" set "CacheName=catroot2"
if not exist "%CacheParent%\%CacheName%" exit /b 0

:backupName
:: Pick a fresh basename for EACH rename, including repeated resets in one session.
set "BackupName=%CacheName%.%RANDOM%-%RANDOM%.old"
if exist "%CacheParent%\%BackupName%" goto backupName
set "CommandName=Backup %CacheName%"
>>"%LogFile%" echo Backing up "%CacheParent%\%CacheName%" to "%BackupName%"
ren "%CacheParent%\%CacheName%" "%BackupName%" >>"%LogFile%" 2>&1
set "Result=%errorlevel%"
call :reportResult
exit /b %Result%

:restart
call :confirmRestart
if errorlevel 1 goto menu
set "CommandName=System restart"
"%SystemRoot%\System32\shutdown.exe" /r /t 0 >>"%LogFile%" 2>&1
set "Result=%errorlevel%"
call :reportResult
if not "%Result%"=="0" goto operationDone
exit /b 0

:restartbios
call :confirmRestart
if errorlevel 1 goto menu
set "CommandName=Firmware restart"
"%SystemRoot%\System32\shutdown.exe" /r /fw /t 0 >>"%LogFile%" 2>&1
set "Result=%errorlevel%"
call :reportResult
if not "%Result%"=="0" goto operationDone
exit /b 0

:confirmRestart
echo Save your work. A confirmed restart is requested immediately, without forcing apps closed.
echo Firmware restart requires supported UEFI firmware.
"%SystemRoot%\System32\choice.exe" /c YN /n /m "Restart now? [Y/N]: "
if errorlevel 255 exit /b 1
if errorlevel 2 exit /b 1
if not errorlevel 1 exit /b 1
exit /b 0

:help
cls
echo ======================= Help Section =======================
echo 1. CheckHealth: quick image corruption status, not a full scan.
echo 2. ScanHealth: detailed image scan, without performing repairs.
echo 3. RestoreHealth: repair the image, using Windows Update if needed.
echo 4. SFC: verify and repair system files. Run after a successful DISM repair.
echo 5. Update cache reset: confirmed fallback after normal troubleshooting fails.
echo    Backs up SoftwareDistribution and catroot2 and restarts the three services.
echo    A partial failure retains backups and still attempts every service start.
echo 6. RestoreHealth then SFC: continues only if DISM returns zero.
echo    Restart first if DISM returns 3010; investigate any other nonzero code.
echo 7. Confirm an immediate system restart.
echo 8. Confirm an immediate restart to supported firmware settings.
echo 9. Help. 0. Exit this script, not your command prompt.
echo Command output and exit codes: "%LogFile%"
echo SFC details include historical [SR] entries, not just errors or this run.
echo Service restart errors are also displayed directly so log failure cannot block recovery.
pause
goto menu
