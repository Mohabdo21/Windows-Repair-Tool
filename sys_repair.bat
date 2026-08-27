@echo off
setlocal EnableDelayedExpansion
:: Require admin
net session >nul 2>&1
if %errorlevel% neq 0 (
echo This script requires administrator privileges. Please run it as an administrator.
pause
exit /b
)

:: Resolve real Desktop dir (handles OneDrive redirect; value is unexpanded %USERPROFILE%)
for /f "skip=1 tokens=1,2*" %%I in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /v Desktop') do (
    if /I "%%I"=="Desktop" if not "%%~K"=="" (
        set "DesktopDir=%%~K"
        :: expand %USERPROFILE% ref
        if defined DesktopDir call set "DesktopDir=!DesktopDir!" >nul 2>&1
    )
)
if not defined DesktopDir set "DesktopDir=%userprofile%\Desktop"

:menu
cls
echo =======================================
echo        System Health Check Menu
echo =======================================
echo 1. Quick Status Check (/CheckHealth)
echo 2. Detailed Scan (/ScanHealth)
echo 3. Repair System Image (/RestoreHealth)
echo 4. Scan and Repair System Files (sfc /scannow)
echo 5. System Update Repair
echo 6. Run commands 2, 3, 4 Sequentially
echo 7. Restart System
echo 8. Restart System Goto BIOS
echo 9. Help - Command Descriptions
echo 10. Exit
echo =======================================
set /p choice=Select an option (1-10):
if "%choice%"=="1" goto checkhealth
if "%choice%"=="2" goto scanhealth
if "%choice%"=="3" goto restorehealth
if "%choice%"=="4" goto sfcscan
if "%choice%"=="5" goto updatefix
if "%choice%"=="6" goto all
if "%choice%"=="7" goto restart
if "%choice%"=="8" goto restartbios
if "%choice%"=="9" goto help
if "%choice%"=="10" exit
echo Invalid option, please try again.
echo.
pause
goto menu

:checkhealth
echo Running Quick Status Check...
echo.
"%SystemRoot%\System32\DISM.exe" /Online /Cleanup-Image /CheckHealth
pause
goto menu

:scanhealth
echo Running Detailed Scan...
echo.
"%SystemRoot%\System32\DISM.exe" /Online /Cleanup-Image /ScanHealth
pause
goto menu

:restorehealth
echo Running System Image Repair...
echo.
"%SystemRoot%\System32\DISM.exe" /Online /Cleanup-Image /RestoreHealth
pause
goto menu

:sfcscan
echo Running System File Checker...
echo.
sfc /scannow
echo.
:: Extract SFC errors only if CBS log exists
if exist "%windir%\Logs\CBS\CBS.log" (
    echo File "sfcdetails.txt" is saved on your desktop with only the error logs of the SFC repair tool.
    findstr /c:"[SR]" "%windir%\Logs\CBS\CBS.log" >"%DesktopDir%\sfcdetails.txt"
)
pause
goto menu

:updatefix
echo Running System Update Repair...
echo.
:: Start TrustedInstaller so DISM/sysfile mods are allowed
echo Configuring TrustedInstaller service...
SC config trustedinstaller start= auto >nul 2>&1
net start trustedinstaller >nul 2>&1
:: Stop update svcs to free the folders/DLLs
echo Stopping update services...
net stop bits >nul 2>&1
net stop wuauserv >nul 2>&1
net stop msiserver >nul 2>&1
net stop cryptsvc >nul 2>&1
net stop appidsvc >nul 2>&1
:: Rename update folders so they're recreated fresh
echo Renaming SoftwareDistribution and catroot2 folders...
:: Locale-independent date (date /t order varies by locale)
for /f "delims=" %%T in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "datestamp=%%T"
if exist "%SystemRoot%\SoftwareDistribution" (
    Ren "%SystemRoot%\SoftwareDistribution" "SoftwareDistribution.!datestamp!.old" >nul 2>&1
)
if exist "%SystemRoot%\System32\catroot2" (
    Ren "%SystemRoot%\System32\catroot2" "catroot2.!datestamp!.old" >nul 2>&1
)
:: Re-register update DLLs
echo Re-registering system DLLs...
regsvr32.exe /s atl.dll >nul 2>&1
regsvr32.exe /s urlmon.dll >nul 2>&1
regsvr32.exe /s mshtml.dll >nul 2>&1
:: Reset network + proxy
echo Resetting network and proxy settings...
netsh winsock reset >nul 2>&1
netsh winhttp reset proxy >nul 2>&1
:: Remove unused drivers
echo Cleaning up unused drivers...
rundll32.exe pnpclean.dll,RunDLL_PnpClean /DRIVERS /MAXCLEAN >nul 2>&1
:: DISM component cleanup
echo Performing component cleanup...
"%SystemRoot%\System32\DISM.exe" /Online /Cleanup-image /StartComponentCleanup >nul 2>&1
:: Restart update svcs
echo Restarting update services...
net start bits >nul 2>&1
net start wuauserv >nul 2>&1
net start msiserver >nul 2>&1
net start cryptsvc >nul 2>&1
net start appidsvc >nul 2>&1
echo System Update Repair completed.
echo Note: A restart is required for the Winsock reset to take full effect.
pause
goto menu

:all
echo Running Core Repair Commands Sequentially...
echo.
echo Starting Detailed Scan...
"%SystemRoot%\System32\DISM.exe" /Online /Cleanup-Image /ScanHealth
echo.
echo Starting System Image Repair...
"%SystemRoot%\System32\DISM.exe" /Online /Cleanup-Image /RestoreHealth
echo.
echo Starting System File Checker...
sfc /scannow
echo.
if exist "%windir%\Logs\CBS\CBS.log" (
    echo File "sfcdetails.txt" is saved on your desktop with only the error logs of the SFC repair tool.
    findstr /c:"[SR]" "%windir%\Logs\CBS\CBS.log" >"%DesktopDir%\sfcdetails.txt"
)
echo.
echo System repair commands completed.
echo It is strongly recommended to restart your computer now to complete any repairs.
pause
goto menu

:restart
echo Restarting System...
shutdown /r /t 0
exit

:restartbios
echo Restarting System to BIOS...
shutdown /r /fw /t 0
exit

:help
cls
echo ======================= Help Section =======================
echo 1. Quick Status Check (/CheckHealth):
echo - Runs a quick check to determine if the system image has any corruption.
echo.
echo 2. Detailed Scan (/ScanHealth):
echo - Scans the system image for any signs of corruption, which may take a few minutes.
echo.
echo 3. Repair System Image (/RestoreHealth):
echo - Attempts to repair any issues found in the system image, downloading files if needed.
echo.
echo 4. Scan and Repair System Files (sfc /scannow):
echo - Runs a System File Checker scan to repair corrupted system files and ensure system integrity.
echo.
echo 5. System Update Repair:
echo - Fixes issues with Windows Update by stopping update services, renaming critical folders,
echo resetting network components, and cleaning unused drivers.
echo.
echo 6. Run commands 2, 3, 4 Sequentially:
echo - Runs the three core repair commands in optimal order: Detailed Scan, System Image Repair,
echo and System File Checker. Always recommends a restart after completion. Does not include update repair.
echo.
echo ============================================================
pause
goto menu
