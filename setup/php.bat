@echo off
setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "ROOT=%SCRIPT_DIR%.."
set "INSTALLS_DIR=%ROOT%\installs\php"
set "DOWNLOADS=%ROOT%\downloads"
set "SEVENZ=%ROOT%\bin\7za.exe"
set "PHP_BASE=https://windows.php.net/downloads/releases"

if not exist "%SEVENZ%" call "%SCRIPT_DIR%setup_7z.bat"
if not exist "%SEVENZ%" (
    echo Could not bootstrap bin\7za.exe. Aborting.
    pause
    exit /b 1
)

rem One-time migration: legacy layout had installs under tools\php\.
for /d %%i in ("%ROOT%\tools\php") do (
    if not exist "%ROOT%\installs\php" (
        if not exist "%ROOT%\installs" mkdir "%ROOT%\installs"
        move "%%i" "%ROOT%\installs\php" >nul
        del "%ROOT%\tools\php.bat" >nul 2>nul
        del "%ROOT%\tools\php.sh" >nul 2>nul
        powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool php -FolderPrefix "php-" -ToolsDir "%ROOT%\tools"
        echo Migrated installs from tools\php\ to installs\php\.
        echo Use [4] Select active version to refresh the active wrapper.
    )
)

if not exist "%DOWNLOADS%" mkdir "%DOWNLOADS%"
if not exist "%INSTALLS_DIR%" mkdir "%INSTALLS_DIR%"

:menu
echo.
echo --- PHP Setup ---
echo   [1] Install latest stable
echo   [2] Install a specific version
echo   [3] List/search versions
echo   [4] Select active version
echo   [5] Remove an installed version
echo   [B] Back
echo.
set "choice="
set /p "choice=> "

if /i "!choice!"=="1" goto latest
if /i "!choice!"=="2" goto pick
if /i "!choice!"=="3" goto search
if /i "!choice!"=="4" goto select
if /i "!choice!"=="5" goto remove
if /i "!choice!"=="B" exit /b 0
goto menu

:latest
set "PHP_VERSION="
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "(Invoke-RestMethod %PHP_BASE%/releases.json).PSObject.Properties | Sort-Object Name -Descending | Select-Object -First 1 | ForEach-Object { $_.Value.version }"`) do set "PHP_VERSION=%%V"
if not defined PHP_VERSION (
    echo Failed to fetch latest version from %PHP_BASE%/releases.json
    pause
    goto menu
)
echo Latest stable: !PHP_VERSION!
goto config

:pick
set "PHP_VERSION="
set /p "PHP_VERSION=Enter PHP version (e.g., 8.4.12): "
if not defined PHP_VERSION goto menu
goto config

:search
set "TERM="
set /p "TERM=Filter by major.minor (e.g., 8.4) or blank for all current branches: "
echo.
if not defined TERM (
    powershell -NoProfile -Command "$r = Invoke-RestMethod %PHP_BASE%/releases.json; $r.PSObject.Properties | Sort-Object Name -Descending | ForEach-Object { '  {0,-6} -> {1}' -f $_.Name, $_.Value.version }"
) else (
    powershell -NoProfile -Command "$r = Invoke-RestMethod %PHP_BASE%/releases.json; $r.PSObject.Properties | Where-Object { $_.Name -like '*!TERM!*' -or $_.Value.version -like '*!TERM!*' } | ForEach-Object { '  {0,-6} -> {1}' -f $_.Name, $_.Value.version }"
)
echo.
echo Note: releases.json only lists currently supported branches.
echo Older versions may still be available under %PHP_BASE%/archives/
echo.
pause
goto menu

:remove
echo.
echo Installed PHP versions in %INSTALLS_DIR%:
echo ----------------------------------------------------
set /a rcount=0
for /d %%i in ("%INSTALLS_DIR%\*") do (
    set /a rcount+=1
    echo   [!rcount!] %%~nxi
    set "RFOLDER[!rcount!]=%%~nxi"
)
if !rcount! equ 0 (
    echo   ^(none^)
    echo.
    pause
    goto menu
)
echo.
set "rsel="
set /p "rsel=Number to remove (blank to cancel): "
if not defined rsel goto menu
if !rsel! lss 1 goto menu
if !rsel! gtr !rcount! goto menu

call set "RTARGET=%%RFOLDER[!rsel!]%%"
set "RPATH=%INSTALLS_DIR%\!RTARGET!"
set "WRAPPER=%ROOT%\tools\php.bat"
set "WAS_ACTIVE=0"
if exist "!WRAPPER!" (
    findstr /c:"!RTARGET!" "!WRAPPER!" >nul 2>nul
    if !errorlevel! equ 0 set "WAS_ACTIVE=1"
)

echo.
set "rconfirm="
set /p "rconfirm=Remove !RPATH! ? (Y/N): "
if /i "!rconfirm!" neq "Y" goto menu

rmdir /s /q "!RPATH!"
if !errorlevel! neq 0 (
    echo Failed to remove !RPATH!
    pause
    goto menu
)
echo Removed !RTARGET!.

if "!WAS_ACTIVE!"=="1" (
    del "!WRAPPER!" >nul 2>nul
    del "%ROOT%\tools\php" >nul 2>nul
    del "%ROOT%\tools\php.sh" >nul 2>nul
    echo Cleared tools\php.bat and tools\php ^(they pointed at the removed version^).
    echo Use [4] to set a new active version.
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool php -FolderPrefix "php-" -ToolsDir "%ROOT%\tools"

echo.
pause
goto menu

:select
echo.
echo Installed PHP versions in %INSTALLS_DIR%:
echo ----------------------------------------------------
set /a scount=0
for /d %%i in ("%INSTALLS_DIR%\*") do (
    set /a scount+=1
    echo   [!scount!] %%~nxi
    set "SFOLDER[!scount!]=%%~nxi"
)
if !scount! equ 0 (
    echo   ^(none^)
    echo.
    pause
    goto menu
)
echo.
set "ssel="
set /p "ssel=Number to set active (blank to cancel): "
if not defined ssel goto menu
if !ssel! lss 1 goto menu
if !ssel! gtr !scount! goto menu

call set "STARGET=%%SFOLDER[!ssel!]%%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\write_active_wrapper.ps1" -Tool php -InstallName "!STARGET!" -ToolsDir "%ROOT%\tools"

echo.
echo tools\php.bat and tools\php.sh now point at !STARGET!.
echo.
pause
goto menu

:config
set "PHP_TS=NTS"
set "ans="
set /p "ans=Thread safety - NTS (default) or TS? "
if /i "!ans!"=="TS" set "PHP_TS=TS"

set "PHP_ARCH=x64"
set "ans="
set /p "ans=Architecture - x64 (default) or x86? "
if /i "!ans!"=="x86" set "PHP_ARCH=x86"

for /f "tokens=1-2 delims=." %%a in ("!PHP_VERSION!") do (
    set "PHP_MAJOR=%%a"
    set "PHP_MINOR=%%b"
)
set "PHP_VS=vs17"
if "!PHP_MAJOR!"=="8" if !PHP_MINOR! lss 4 set "PHP_VS=vs16"
if "!PHP_MAJOR!"=="7" set "PHP_VS=vc15"

if /i "!PHP_TS!"=="NTS" (
    set "TS_SEGMENT=-nts"
) else (
    set "TS_SEGMENT="
)

set "FILENAME=php-!PHP_VERSION!!TS_SEGMENT!-Win32-!PHP_VS!-!PHP_ARCH!.zip"
set "URL=%PHP_BASE%/!FILENAME!"
set "ARCHIVE_URL=%PHP_BASE%/archives/!FILENAME!"
set "OUTFILE=%DOWNLOADS%\!FILENAME!"
set "INSTALL_NAME=php-!PHP_VERSION!!TS_SEGMENT!-Win32-!PHP_VS!-!PHP_ARCH!"
set "INSTALL_DIR=%INSTALLS_DIR%\!INSTALL_NAME!"

echo.
echo --- Plan ---
echo   Version : !PHP_VERSION!
echo   Build   : !PHP_TS!  !PHP_VS!  !PHP_ARCH!
echo   URL     : !URL!
echo   Install : !INSTALL_DIR!
echo.
set "go="
set /p "go=Proceed? (Y/N): "
if /i "!go!" neq "Y" goto menu

if exist "!INSTALL_DIR!" (
    echo Already installed at !INSTALL_DIR!
    pause
    goto menu
)

if not exist "!OUTFILE!" (
    echo Downloading !URL!
    curl -L -f -o "!OUTFILE!" "!URL!"
    if !errorlevel! neq 0 (
        echo Primary URL failed, trying archive...
        curl -L -f -o "!OUTFILE!" "!ARCHIVE_URL!"
        if !errorlevel! neq 0 (
            echo Download failed.
            pause
            goto menu
        )
    )
) else (
    echo Using cached download: !OUTFILE!
)

echo Extracting to !INSTALL_DIR! ...
if not exist "!INSTALL_DIR!" mkdir "!INSTALL_DIR!"
"%SEVENZ%" x "!OUTFILE!" -o"!INSTALL_DIR!" -y >nul
if !errorlevel! neq 0 (
    echo Extraction failed.
    pause
    goto menu
)

rem Seed php.ini from the bundled development template so PHP has a usable
rem default config out of the box. Production users can swap for php.ini-production.
if exist "!INSTALL_DIR!\php.ini-development" if not exist "!INSTALL_DIR!\php.ini" (
    copy /y "!INSTALL_DIR!\php.ini-development" "!INSTALL_DIR!\php.ini" >nul
)

echo.
echo PHP installed at !INSTALL_DIR!
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool php -FolderPrefix "php-" -ToolsDir "%ROOT%\tools"

set /a icount=0
for /d %%i in ("%INSTALLS_DIR%\*") do set /a icount+=1
set "WRAPPER=%ROOT%\tools\php.bat"
if !icount! equ 1 if not exist "!WRAPPER!" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\write_active_wrapper.ps1" -Tool php -InstallName "!INSTALL_NAME!" -ToolsDir "%ROOT%\tools"
    echo Auto-selected !INSTALL_NAME! as active version.
)

echo.
pause
goto menu
