@echo off
setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "ROOT=%SCRIPT_DIR%.."
set "INSTALLS_DIR=%ROOT%\installs\composer"
set "DOWNLOADS=%ROOT%\downloads"
set "GH_API=https://api.github.com/repos/composer/composer/releases?per_page=100"
set "GH_DL=https://github.com/composer/composer/releases/download"

rem One-time migration: legacy layout had installs under tools\composer\.
for /d %%i in ("%ROOT%\tools\composer") do (
    if not exist "%ROOT%\installs\composer" (
        if not exist "%ROOT%\installs" mkdir "%ROOT%\installs"
        move "%%i" "%ROOT%\installs\composer" >nul
        del "%ROOT%\tools\composer.bat" >nul 2>nul
        del "%ROOT%\tools\composer.sh" >nul 2>nul
        powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool composer -FolderPrefix "" -ToolsDir "%ROOT%\tools" -WrapperKind phar -PharName composer.phar
        echo Migrated installs from tools\composer\ to installs\composer\.
        echo Use [4] Select active version to refresh the active wrapper.
    )
)

if not exist "%DOWNLOADS%" mkdir "%DOWNLOADS%"
if not exist "%INSTALLS_DIR%" mkdir "%INSTALLS_DIR%"

:menu
echo.
echo --- Composer Setup ---
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
set "C_VERSION="
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "$r = Invoke-RestMethod %GH_API%; ($r | Where-Object { $_.assets.name -contains 'composer.phar' -and $_.tag_name -notmatch '-' } | Select-Object -First 1).tag_name"`) do set "C_VERSION=%%V"
if not defined C_VERSION (
    echo Failed to fetch latest version.
    pause
    goto menu
)
echo Latest stable: !C_VERSION!
goto config

:pick
set "C_VERSION="
set /p "C_VERSION=Enter Composer version (e.g., 2.10.1, 2.10.0-RC2): "
if not defined C_VERSION goto menu
goto config

:search
set "TERM="
set /p "TERM=Filter (e.g., 2.10, 2.10.0, blank for latest 30): "
echo.
if not defined TERM (
    powershell -NoProfile -Command "$r = Invoke-RestMethod %GH_API%; $r | Where-Object { $_.assets.name -contains 'composer.phar' } | Select-Object -First 30 | ForEach-Object { '  {0,-14}  released {1}' -f $_.tag_name, $_.published_at.Substring(0,10) }"
) else (
    powershell -NoProfile -Command "$r = Invoke-RestMethod %GH_API%; $r | Where-Object { $_.assets.name -contains 'composer.phar' -and $_.tag_name -like '*!TERM!*' } | Select-Object -First 50 | ForEach-Object { '  {0,-14}  released {1}' -f $_.tag_name, $_.published_at.Substring(0,10) }"
)
echo.
pause
goto menu

:config
set "URL=%GH_DL%/!C_VERSION!/composer.phar"
set "OUTFILE=%DOWNLOADS%\composer-!C_VERSION!.phar"
set "INSTALL_DIR=%INSTALLS_DIR%\!C_VERSION!"
set "INSTALL_FILE=!INSTALL_DIR!\composer.phar"

echo.
echo --- Plan ---
echo   Version : !C_VERSION!
echo   URL     : !URL!
echo   Install : !INSTALL_FILE!
echo.
set "go="
set /p "go=Proceed? (Y/N): "
if /i "!go!" neq "Y" goto menu

if exist "!INSTALL_FILE!" (
    echo Already installed at !INSTALL_FILE!
    pause
    goto menu
)

if not exist "!OUTFILE!" (
    echo Downloading !URL!
    curl -L -f -o "!OUTFILE!" "!URL!"
    if !errorlevel! neq 0 (
        echo Download failed.
        pause
        goto menu
    )
) else (
    echo Using cached download: !OUTFILE!
)

if not exist "!INSTALL_DIR!" mkdir "!INSTALL_DIR!"
copy /y "!OUTFILE!" "!INSTALL_FILE!" >nul
if !errorlevel! neq 0 (
    echo Failed to install phar.
    pause
    goto menu
)

echo.
echo Composer installed at !INSTALL_FILE!
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool composer -FolderPrefix "" -ToolsDir "%ROOT%\tools" -WrapperKind phar -PharName composer.phar

set /a icount=0
for /d %%i in ("%INSTALLS_DIR%\*") do set /a icount+=1
set "WRAPPER=%ROOT%\tools\composer.bat"
if !icount! equ 1 if not exist "!WRAPPER!" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\write_active_wrapper.ps1" -Tool composer -InstallName "!C_VERSION!" -ToolsDir "%ROOT%\tools" -WrapperKind phar -PharName composer.phar
    echo Auto-selected !C_VERSION! as active version.
)

echo.
pause
goto menu

:remove
echo.
echo Installed Composer versions in %INSTALLS_DIR%:
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
set "WRAPPER=%ROOT%\tools\composer.bat"
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
    del "%ROOT%\tools\composer" >nul 2>nul
    del "%ROOT%\tools\composer.sh" >nul 2>nul
    echo Cleared tools\composer.bat and tools\composer ^(they pointed at the removed version^).
    echo Use [4] to set a new active version.
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool composer -FolderPrefix "" -ToolsDir "%ROOT%\tools" -WrapperKind phar -PharName composer.phar

echo.
pause
goto menu

:select
echo.
echo Installed Composer versions in %INSTALLS_DIR%:
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
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\write_active_wrapper.ps1" -Tool composer -InstallName "!STARGET!" -ToolsDir "%ROOT%\tools" -WrapperKind phar -PharName composer.phar

echo.
echo tools\composer.bat and tools\composer.sh now point at !STARGET!.
echo.
pause
goto menu
