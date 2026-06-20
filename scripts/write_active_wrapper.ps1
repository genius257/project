# Write the active-version wrappers for one tool: tools\<Tool>.bat (cmd) and
# tools\<Tool> (bash, extensionless), both pointing at the specified install.
#
# Why extensionless on the bash side: bash command lookup uses the exact name
# typed, so a user typing `php` finds tools\php directly. cmd separately
# finds tools\php.bat via PATHEXT. Same bare command, both shells. Any legacy
# tools\<Tool>.sh from an earlier version of the bundle is removed.
#
# WrapperKind:
#   path  (default) — prepend the install folder to PATH and run <Tool>.
#                     Use for tools that ship a folder of executables (PHP, Node).
#   phar            — invoke `php` against a .phar inside the install folder.
#                     Use for PHP-based tools shipped as a single .phar
#                     (phpactor, composer). Requires -PharName.

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Tool,
    [Parameter(Mandatory)][string] $InstallName,
    [Parameter(Mandatory)][string] $ToolsDir,
    [ValidateSet('path','phar')][string] $WrapperKind = 'path',
    [string] $PharName
)

$ErrorActionPreference = 'Stop'

if ($WrapperKind -eq 'phar' -and -not $PharName) {
    throw 'PharName is required when WrapperKind is phar.'
}

$batPath    = Join-Path $ToolsDir ("$Tool.bat")
$bashPath   = Join-Path $ToolsDir $Tool
$legacyShPath = Join-Path $ToolsDir ("$Tool.sh")

if ($WrapperKind -eq 'phar') {
    $bat = @"
@echo off
php "%~dp0..\installs\$Tool\$InstallName\$PharName" %*
"@
    $sh = @"
#!/usr/bin/env bash
DIR="`$(cd "`$(dirname "`${BASH_SOURCE[0]}")" && pwd)"
exec "`$DIR/php" "`$DIR/../installs/$Tool/$InstallName/$PharName" "`$@"
"@
} else {
    $bat = @"
@echo off
set PATH="%~dp0..\installs\$Tool\$InstallName";%PATH%
$Tool %*
"@
    $sh = @"
#!/usr/bin/env bash
DIR="`$(cd "`$(dirname "`${BASH_SOURCE[0]}")" && pwd)"
export PATH="`$DIR/../installs/$Tool/${InstallName}:`$PATH"
exec $Tool "`$@"
"@
}

# .bat: cmd is happy with CRLF, use Set-Content default behaviour.
Set-Content -Path $batPath -Value $bat -Encoding ASCII

# Extensionless bash wrapper: must be LF-only.
$shLF = ($sh -replace "`r`n", "`n") + "`n"
[System.IO.File]::WriteAllText($bashPath, $shLF, [System.Text.ASCIIEncoding]::new())

# Drop any legacy .sh sibling from previous bundle versions.
if (Test-Path $legacyShPath) { Remove-Item -Force $legacyShPath }
