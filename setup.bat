@echo off
setlocal EnableDelayedExpansion

set "ROOT=%~dp0"

:menu
cls
echo ================================
echo   Portable Tools Setup
echo ================================
echo.
echo   [1] PHP
echo   [2] Node.js / npm
echo   [3] phpactor
echo   [4] Composer
echo   [Q] Quit
echo.
set "choice="
set /p "choice=Select a tool: "

if /i "!choice!"=="1" (
    call "%ROOT%setup\php.bat"
    goto :menu
)
if /i "!choice!"=="2" (
    call "%ROOT%setup\node.bat"
    goto :menu
)
if /i "!choice!"=="3" (
    call "%ROOT%setup\phpactor.bat"
    goto :menu
)
if /i "!choice!"=="4" (
    call "%ROOT%setup\composer.bat"
    goto :menu
)
if /i "!choice!"=="Q" goto :end

echo Invalid choice.
timeout /t 1 >nul
goto :menu

:end
endlocal
