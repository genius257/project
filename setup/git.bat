@echo off
setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "ROOT=%SCRIPT_DIR%.."
set "INSTALLS_DIR=%ROOT%\installs\git"
set "DOWNLOADS=%ROOT%\downloads"
set "SEVENZ=%ROOT%\bin\7za.exe"
set "GIT_API=https://api.github.com/repos/git-for-windows/git/releases"

if not exist "%SEVENZ%" call "%SCRIPT_DIR%setup_7z.bat"
if not exist "%SEVENZ%" (
    echo Could not bootstrap bin\7za.exe. Aborting.
    pause
    exit /b 1
)

rem One-time migration: legacy layout had installs under tools\git\.
for /d %%i in ("%ROOT%\tools\git") do (
    if not exist "%ROOT%\installs\git" (
        if not exist "%ROOT%\installs" mkdir "%ROOT%\installs"
        move "%%i" "%ROOT%\installs\git" >nul
        del "%ROOT%\tools\git.bat" >nul 2>nul
        del "%ROOT%\tools\git.sh" >nul 2>nul
        powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool git -FolderPrefix "PortableGit-" -SubDir bin -ToolsDir "%ROOT%\tools"
        echo Migrated installs from tools\git\ to installs\git\.
        echo Use [4] Select active version to refresh the active wrapper.
    )
)

if not exist "%DOWNLOADS%" mkdir "%DOWNLOADS%"
if not exist "%INSTALLS_DIR%" mkdir "%INSTALLS_DIR%"

:menu
echo.
echo --- Git Setup ---
echo   [1] Install latest stable
echo   [2] Install a specific version
echo   [3] List/search versions
echo   [4] Select active version
echo   [5] Remove an installed version
echo   [B] Back
echo.
set "choice="
set /p "choice=> "

if /i "!choice!"=="1" goto latest_stable
if /i "!choice!"=="2" goto pick
if /i "!choice!"=="3" goto search
if /i "!choice!"=="4" goto select
if /i "!choice!"=="5" goto remove
if /i "!choice!"=="B" exit /b 0
goto menu

:latest_stable
set "RELEASE_TAG="
echo Fetching latest stable release from GitHub...
for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "$r = Invoke-RestMethod '%GIT_API%/latest'; if ($r.prerelease -eq $false) { $r.tag_name }"`) do set "RELEASE_TAG=%%T"
if not defined RELEASE_TAG (
    echo Could not determine latest stable release.
    pause
    goto menu
)
goto config

:pick
set "RELEASE_TAG="
set /p "RELEASE_TAG=Enter Git tag (e.g., v2.54.0.windows.1 or 2.54.0): "
if not defined RELEASE_TAG goto menu
if not "!RELEASE_TAG:~0,1!"=="v" set "RELEASE_TAG=v!RELEASE_TAG!"
goto config

:search
echo.
echo Fetching recent releases from GitHub...
echo.
powershell -NoProfile -Command ^
  "$r = Invoke-RestMethod '%GIT_API%?per_page=30'; " ^
  "$r | ForEach-Object { " ^
  "  $tag = $_.tag_name; " ^
  "  $prerelease = if ($_.prerelease) { ' (prerelease)' } else { '' }; " ^
  "  $asset = $_.assets | Where-Object { $_.name -like 'PortableGit-*-64-bit.7z.exe' } | Select-Object -First 1; " ^
  "  if ($asset) { '  {0,-30} {1}' -f $tag, $prerelease }" ^
  "}"
echo.
pause
goto menu

:remove
echo.
echo Installed Git versions in %INSTALLS_DIR%:
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
set "WRAPPER=%ROOT%\tools\git.bat"
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
    del "%ROOT%\tools\git" >nul 2>nul
    del "%ROOT%\tools\git.sh" >nul 2>nul
    echo Cleared tools\git.bat ^(it pointed at the removed version^).
    echo Use [4] to set a new active version.
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool git -FolderPrefix "PortableGit-" -SubDir bin -ToolsDir "%ROOT%\tools"

echo.
pause
goto menu

:select
echo.
echo Installed Git versions in %INSTALLS_DIR%:
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
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\write_active_wrapper.ps1" -Tool git -InstallName "!STARGET!" -SubDir bin -ToolsDir "%ROOT%\tools"

echo.
echo tools\git.bat now points at !STARGET!.
echo.
pause
goto menu

:config
if not defined RELEASE_TAG (
    echo Could not determine version.
    pause
    goto menu
)

rem Extract version from tag (e.g. v2.54.0.windows.1 -> 2.54.0)
for /f "tokens=1-4 delims=.v " %%a in ("!RELEASE_TAG!") do (
    set "GIT_MAJOR=%%a"
    set "GIT_MINOR=%%b"
    set "GIT_PATCH=%%c"
)
set "VERSION_SHORT=!GIT_MAJOR!.!GIT_MINOR!.!GIT_PATCH!"
set "DIRNAME=PortableGit-!VERSION_SHORT!-64-bit"
set "FILENAME=!DIRNAME!.7z.exe"
set "ASSET_NAME=!FILENAME!"

rem Try other version patterns if the simple one doesn't match
if "!ASSET_NAME!"=="PortableGit--64-bit.7z.exe" (
    echo Failed to parse version from tag !RELEASE_TAG!.
    pause
    goto menu
)

set "URL="
echo Determining download URL for !RELEASE_TAG!...
for /f "usebackq delims=" %%U in (`powershell -NoProfile -Command ^
  "$r = Invoke-RestMethod '%GIT_API%/tags/!RELEASE_TAG!'; " ^
  "$asset = $r.assets | Where-Object { $_.name -eq '!ASSET_NAME!' } | Select-Object -First 1; " ^
  "if ($asset) { $asset.browser_download_url }"`) do set "URL=%%U"

if not defined URL (
    echo Could not find asset !ASSET_NAME! for tag !RELEASE_TAG!.
    echo.
    echo Available assets for that tag:
    powershell -NoProfile -Command ^
      "$r = Invoke-RestMethod '%GIT_API%/tags/!RELEASE_TAG!'; " ^
      "if ($r.assets) { $r.assets | ForEach-Object { '  ' + $_.name } } else { '  ^(no assets found^)' }"
    echo.
    pause
    goto menu
)

set "OUTFILE=%DOWNLOADS%\!FILENAME!"
set "INSTALL_DIR=%INSTALLS_DIR%\!DIRNAME!"

echo.
echo --- Plan ---
echo   Release : !RELEASE_TAG!
echo   Version : !VERSION_SHORT!
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

echo Extracting to !INSTALL_DIR! ...
"%SEVENZ%" x "!OUTFILE!" -o"!INSTALL_DIR!" -y >nul
if !errorlevel! neq 0 (
    echo Extraction failed.
    pause
    goto menu
)

if not exist "!INSTALL_DIR!" (
    echo Something went wrong during extraction.
    echo Check %INSTALLS_DIR% for the extracted contents.
    pause
    goto menu
)

echo.
echo Git installed at !INSTALL_DIR!
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\rebuild_version_tiers.ps1" -Tool git -FolderPrefix "PortableGit-" -SubDir bin -ToolsDir "%ROOT%\tools"

set /a icount=0
for /d %%i in ("%INSTALLS_DIR%\*") do set /a icount+=1
set "WRAPPER=%ROOT%\tools\git.bat"
if !icount! equ 1 if not exist "!WRAPPER!" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\write_active_wrapper.ps1" -Tool git -InstallName "!DIRNAME!" -SubDir bin -ToolsDir "%ROOT%\tools"
    echo Auto-selected !DIRNAME! as active version.
)

echo.
pause
goto menu