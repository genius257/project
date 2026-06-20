@echo off
setlocal EnableDelayedExpansion

rem --- Configuration ---
set "PHP_DOWNLOAD_BASE_URL=https://windows.php.net/downloads/releases"
set "PORTABLE_ROOT=%~dp0..\."  rem Points to PortableTools/
set "DOWNLOAD_DIR=%PORTABLE_ROOT%\downloads"
set "PHP_EXTRACT_ROOT=%PORTABLE_ROOT%\tools\php" rem Base for extraction, if you add that later

rem --- Ensure downloads directory exists ---
if not exist "%DOWNLOAD_DIR%" (
    echo Creating download directory: %DOWNLOAD_DIR%
    mkdir "%DOWNLOAD_DIR%"
    if errorlevel 1 (
        echo Error: Could not create download directory. Exiting.
        goto :eof
    )
)

echo.
echo --- PHP Downloader from windows.php.net ---
echo.

rem --- Get PHP Version ---
set "PHP_VERSION_FULL="
:getPhpVersion
set /p "PHP_VERSION_FULL=Enter full PHP version (e.g., 8.2.10, 8.1.25): "
if not defined PHP_VERSION_FULL (
    echo Version cannot be empty.
    goto :getPhpVersion
)
rem Extract major.minor for URL path
for /f "tokens=1-2 delims=." %%a in ("%PHP_VERSION_FULL%") do (
    set "PHP_VERSION_MAJOR_MINOR=%%a.%%b"
)
if not defined PHP_VERSION_MAJOR_MINOR (
    echo Invalid PHP version format. Please use X.Y.Z.
    goto :getPhpVersion
)

rem --- Get Architecture ---
set "PHP_ARCH="
:getPhpArch
set /p "PHP_ARCH=Enter architecture (x64 or x86): "
if /i "%PHP_ARCH%"=="x64" (
    set "PHP_ARCH=x64"
) else if /i "%PHP_ARCH%"=="x86" (
    set "PHP_ARCH=x86"
) else (
    echo Invalid architecture. Please enter x64 or x86.
    goto :getPhpArch
)

rem --- Get Thread Safety ---
set "PHP_TS="
:getPhpTS
set /p "PHP_TS=Enter thread safety (TS for Thread Safe, NTS for Non-Thread Safe): "
if /i "%PHP_TS%"=="TS" (
    set "PHP_TS=TS"
) else if /i "%PHP_TS%"=="NTS" (
    set "PHP_TS=NTS"
) else (
    echo Invalid thread safety. Please enter TS or NTS.
    goto :getPhpTS
)

rem --- Construct Filename and URL ---
rem Example filename: php-8.2.10-NTS-vs16-x64.zip
rem Example URL: https://windows.php.net/downloads/releases/php-8.2.10-NTS-vs16-x64.zip

rem Determine VS version based on PHP major.minor
rem PHP 8.0+ generally uses VS16 (Visual Studio 2019)
rem PHP 7.4 might use VS16, earlier might use VS15 (2017)
rem For simplicity, we'll assume VS16 for modern PHP versions.
rem You might need to adjust this logic if you download older PHP versions.
set "PHP_VS_VERSION=vs16"
if "%PHP_VERSION_MAJOR_MINOR%" leq "7.4" (
    rem Older versions might use VS15
    rem This is a simple comparison, for production, check specific docs
    echo Warning: For PHP <= 7.4, VS_VERSION might be vs15. Using vs16 for now.
    rem set "PHP_VS_VERSION=vs15"  <-- Uncomment if needed for specific versions
)

set "PHP_FILENAME=php-%PHP_VERSION_FULL%-%PHP_TS%-%PHP_VS_VERSION%-%PHP_ARCH%.zip"
set "PHP_DOWNLOAD_URL=%PHP_DOWNLOAD_BASE_URL%/%PHP_FILENAME%"
set "OUTPUT_FILE=%DOWNLOAD_DIR%\%PHP_FILENAME%"

echo.
echo --- Download Details ---
echo PHP Version: !PHP_VERSION_FULL!
echo Architecture: !PHP_ARCH!
echo Thread Safety: !PHP_TS!
echo VS Version: !PHP_VS_VERSION!
echo Constructed Filename: !PHP_FILENAME!
echo Download URL: !PHP_DOWNLOAD_URL!
echo Output File: !OUTPUT_FILE!
echo.

rem --- Confirmation ---
set /p "CONFIRM=Do you want to proceed with the download? (Y/N): "
if /i "!CONFIRM!" neq "Y" (
    echo Download cancelled.
    goto :eof
)

rem --- Download using curl ---
echo Starting download... This may take a while.
curl -L -o "%OUTPUT_FILE%" "%PHP_DOWNLOAD_URL%"

if !errorlevel! equ 0 (
    echo.
    echo Successfully downloaded PHP to: %OUTPUT_FILE%
    echo.
    echo You can now manually extract this zip to:
    echo %PHP_EXTRACT_ROOT%\%PHP_VERSION_FULL%
    echo or consider adding extraction logic to this script.
) else (
    echo.
    echo Error during download. Curl exited with error code: !errorlevel!
    echo Please check the URL, your internet connection, and curl installation.
    echo Ensure the PHP version, architecture, and thread safety are correct for the filename.
)

endlocal
goto :eof
