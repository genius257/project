@echo off
setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "ROOT=%SCRIPT_DIR%.."
set "BIN=%ROOT%\bin"
set "DOWNLOADS=%ROOT%\downloads"

if not exist "%BIN%" mkdir "%BIN%"
if not exist "%DOWNLOADS%" mkdir "%DOWNLOADS%"

rem --- 7zr.exe: minimal bootstrap, reads .7z/.lzma/.xz ---
if not exist "%BIN%\7zr.exe" (
    echo Downloading 7zr.exe...
    curl -L -f -o "%BIN%\7zr.exe" "https://7-zip.org/a/7zr.exe"
    if !errorlevel! neq 0 (
        echo Failed to download 7zr.exe
        exit /b 1
    )
)

rem --- 7za.exe: full standalone, reads .zip and most formats ---
rem    Bootstrapped by using 7zr.exe to extract it from the 7-Zip Extras .7z package.
if not exist "%BIN%\7za.exe" (
    rem TODO: resolve the current 7-Zip release dynamically (e.g. via
    rem        api.github.com/repos/ip7z/7zip/releases/latest) rather than
    rem        hardcoding the package filename and tag below.
    set "EXTRA_VER=24.09"
    set "EXTRA_TAG=24.09"
    set "EXTRA_PKG=7z2409-extra.7z"
    set "EXTRA_URL=https://github.com/ip7z/7zip/releases/download/!EXTRA_TAG!/!EXTRA_PKG!"
    set "EXTRA_OUT=%DOWNLOADS%\!EXTRA_PKG!"

    if not exist "!EXTRA_OUT!" (
        echo Downloading !EXTRA_PKG!...
        curl -L -f -o "!EXTRA_OUT!" "!EXTRA_URL!"
        if !errorlevel! neq 0 (
            echo Failed to download !EXTRA_PKG!
            exit /b 1
        )
    )

    echo Extracting 7za.exe to %BIN% ...
    "%BIN%\7zr.exe" e "!EXTRA_OUT!" -o"%BIN%" 7za.exe -y >nul
    if !errorlevel! neq 0 (
        echo Failed to extract 7za.exe
        exit /b 1
    )
)

echo bin\7zr.exe and bin\7za.exe ready.
endlocal
