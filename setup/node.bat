@echo off
setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "ROOT=%SCRIPT_DIR%.."
set "INSTALLS_DIR=%ROOT%\installs\node"
set "DOWNLOADS=%ROOT%\downloads"
set "SEVENZ=%ROOT%\bin\7za.exe"
set "NODE_BASE=https://nodejs.org/dist"

if not exist "%SEVENZ%" call "%SCRIPT_DIR%setup_7z.bat"
if not exist "%SEVENZ%" (
    echo Could not bootstrap bin\7za.exe. Aborting.
    pause
    exit /b 1
)

rem One-time migration: legacy layout had installs under tools\node\.
for /d %%i in ("%ROOT%\tools\node") do (
    if not exist "%ROOT%\installs\node" (
        if not exist "%ROOT%\installs" mkdir "%ROOT%\installs"
        move "%%i" "%ROOT%\installs\node" >nul
        del "%ROOT%\tools\node.bat" >nul 2>nul
        del "%ROOT%\tools\node.sh" >nul 2>nul
        powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool node -FolderPrefix "node-v" -ToolsDir "%ROOT%\tools"
        powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool npm -InstallDir node -FolderPrefix "node-v" -VersionFile "node_modules\npm\package.json" -ToolsDir "%ROOT%\tools"
        powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool npx -InstallDir node -FolderPrefix "node-v" -VersionFile "node_modules\npm\package.json" -ToolsDir "%ROOT%\tools"
        echo Migrated installs from tools\node\ to installs\node\.
        echo Use [5] Select active version to refresh the active wrapper.
    )
)

if not exist "%DOWNLOADS%" mkdir "%DOWNLOADS%"
if not exist "%INSTALLS_DIR%" mkdir "%INSTALLS_DIR%"

:menu
echo.
echo --- Node.js / npm Setup ---
echo   [1] Install latest LTS
echo   [2] Install latest current
echo   [3] Install a specific version
echo   [4] List/search versions
echo   [5] Select active version
echo   [6] Remove an installed version
echo   [B] Back
echo.
set "choice="
set /p "choice=> "

if /i "!choice!"=="1" goto latest_lts
if /i "!choice!"=="2" goto latest_current
if /i "!choice!"=="3" goto pick
if /i "!choice!"=="4" goto search
if /i "!choice!"=="5" goto select
if /i "!choice!"=="6" goto remove
if /i "!choice!"=="B" exit /b 0
goto menu

:latest_lts
set "NODE_VERSION="
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "$r = Invoke-RestMethod %NODE_BASE%/index.json; ($r | Where-Object { $_.lts } | Select-Object -First 1).version"`) do set "NODE_VERSION=%%V"
goto config

:latest_current
set "NODE_VERSION="
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "$r = Invoke-RestMethod %NODE_BASE%/index.json; ($r | Select-Object -First 1).version"`) do set "NODE_VERSION=%%V"
goto config

:pick
set "NODE_VERSION="
set /p "NODE_VERSION=Enter Node version (e.g., 22.5.1 or v22.5.1): "
if not defined NODE_VERSION goto menu
if not "!NODE_VERSION:~0,1!"=="v" set "NODE_VERSION=v!NODE_VERSION!"
goto config

:search
set "TERM="
set /p "TERM=Filter (version prefix like 22, the word 'lts', or blank for latest 30): "
echo.
if /i "!TERM!"=="lts" (
    powershell -NoProfile -Command "$r = Invoke-RestMethod %NODE_BASE%/index.json; $r | Where-Object { $_.lts } | Select-Object -First 30 | ForEach-Object { '  {0,-12}  LTS: {1}' -f $_.version, $_.lts }"
) else (
    if not defined TERM (
        powershell -NoProfile -Command "$r = Invoke-RestMethod %NODE_BASE%/index.json; $r | Select-Object -First 30 | ForEach-Object { if ($_.lts) { '  {0,-12}  LTS: {1}' -f $_.version, $_.lts } else { '  {0}' -f $_.version } }"
    ) else (
        powershell -NoProfile -Command "$r = Invoke-RestMethod %NODE_BASE%/index.json; $r | Where-Object { $_.version -like 'v!TERM!*' -or $_.version -like '*!TERM!*' } | Select-Object -First 50 | ForEach-Object { if ($_.lts) { '  {0,-12}  LTS: {1}' -f $_.version, $_.lts } else { '  {0}' -f $_.version } }"
    )
)
echo.
pause
goto menu

:remove
echo.
echo Installed Node.js versions in %INSTALLS_DIR%:
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
set "WRAPPER=%ROOT%\tools\node.bat"
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
    del "%ROOT%\tools\node" >nul 2>nul
    del "%ROOT%\tools\node.sh" >nul 2>nul
    del "%ROOT%\tools\npm.bat" >nul 2>nul
    del "%ROOT%\tools\npm" >nul 2>nul
    del "%ROOT%\tools\npx.bat" >nul 2>nul
    del "%ROOT%\tools\npx" >nul 2>nul
    echo Cleared tools\node.bat, tools\npm.bat, tools\npx.bat ^(they pointed at the removed version^).
    echo Use [5] to set a new active version.
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool node -FolderPrefix "node-v" -ToolsDir "%ROOT%\tools"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool npm -InstallDir node -FolderPrefix "node-v" -VersionFile "node_modules\npm\package.json" -ToolsDir "%ROOT%\tools"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool npx -InstallDir node -FolderPrefix "node-v" -VersionFile "node_modules\npm\package.json" -ToolsDir "%ROOT%\tools"

echo.
pause
goto menu

:select
echo.
echo Installed Node.js versions in %INSTALLS_DIR%:
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
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\write_active_wrapper.ps1" -Tool node -InstallName "!STARGET!" -ToolsDir "%ROOT%\tools"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\write_active_wrapper.ps1" -Tool npm -InstallName "!STARGET!" -InstallDir node -ToolsDir "%ROOT%\tools"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\write_active_wrapper.ps1" -Tool npx -InstallName "!STARGET!" -InstallDir node -ToolsDir "%ROOT%\tools"

echo.
echo tools\node.bat, tools\npm.bat, tools\npx.bat now point at !STARGET!.
echo.
pause
goto menu

:config
if not defined NODE_VERSION (
    echo Could not determine version.
    pause
    goto menu
)

set "NODE_ARCH=x64"
set "ans="
set /p "ans=Architecture - x64 (default) or x86? "
if /i "!ans!"=="x86" set "NODE_ARCH=x86"

set "DIRNAME=node-!NODE_VERSION!-win-!NODE_ARCH!"
set "FILENAME=!DIRNAME!.zip"
set "URL=%NODE_BASE%/!NODE_VERSION!/!FILENAME!"
set "OUTFILE=%DOWNLOADS%\!FILENAME!"
set "INSTALL_DIR=%INSTALLS_DIR%\!DIRNAME!"

echo.
echo --- Plan ---
echo   Version : !NODE_VERSION!
echo   Arch    : !NODE_ARCH!
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
        echo Download failed.
        pause
        goto menu
    )
) else (
    echo Using cached download: !OUTFILE!
)

echo Extracting to %INSTALLS_DIR% ...
"%SEVENZ%" x "!OUTFILE!" -o"%INSTALLS_DIR%" -y >nul
if !errorlevel! neq 0 (
    echo Extraction failed.
    pause
    goto menu
)

rem Pin npm's cache and global prefix inside the bundle (instead of %APPDATA%)
rem via the builtin npmrc that ships with npm.
if exist "!INSTALL_DIR!\node_modules\npm" (
    for %%a in ("%ROOT%") do set "RESOLVED_ROOT=%%~fa"
    set "ROOT_FS=!RESOLVED_ROOT:\=/!"
    (
        echo cache=!ROOT_FS!/.npm-cache
        echo prefix=!ROOT_FS!/.npm-prefix
    ) > "!INSTALL_DIR!\node_modules\npm\npmrc"
)

echo.
echo Node.js installed at !INSTALL_DIR!
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool node -FolderPrefix "node-v" -ToolsDir "%ROOT%\tools"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool npm -InstallDir node -FolderPrefix "node-v" -VersionFile "node_modules\npm\package.json" -ToolsDir "%ROOT%\tools"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool npx -InstallDir node -FolderPrefix "node-v" -VersionFile "node_modules\npm\package.json" -ToolsDir "%ROOT%\tools"

set /a icount=0
for /d %%i in ("%INSTALLS_DIR%\*") do set /a icount+=1
set "WRAPPER=%ROOT%\tools\node.bat"
if !icount! equ 1 if not exist "!WRAPPER!" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\write_active_wrapper.ps1" -Tool node -InstallName "!DIRNAME!" -ToolsDir "%ROOT%\tools"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\write_active_wrapper.ps1" -Tool npm -InstallName "!DIRNAME!" -InstallDir node -ToolsDir "%ROOT%\tools"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\write_active_wrapper.ps1" -Tool npx -InstallName "!DIRNAME!" -InstallDir node -ToolsDir "%ROOT%\tools"
    echo Auto-selected !DIRNAME! as active version.
)

echo.
pause
goto menu
