# Rebuild the per-tier wrapper files under tools\ for one tool.
#
# Layout assumed:
#   <root>\tools\        — wrappers go here (.bat + extensionless bash)
#   <root>\installs\     — actual install folders live here (sibling of tools)
#                          e.g. <root>\installs\php\php-8.4.12-nts-Win32-vs17-x64\
#                               <root>\installs\phpactor\2026.05.30.2\
# -InstallsDir is derived from -ToolsDir's parent.
#
# Given installs like:
#   installs\php\php-8.4.12-nts-Win32-vs17-x64\        (3-part version)
#   installs\php\php-8.4.22-nts-Win32-vs17-x64\
#   installs\phpactor\2026.05.30.2\                    (4-part version)
#
# Produces (each pointing at the highest install matching that tier), in
# paired cmd + bash form, all under tools\:
#   tools\php8.bat                  tools\php8                  (-> 8.4.22)
#   tools\php8.4.bat                tools\php8.4                (-> 8.4.22)
#   tools\php8.4.22.bat             tools\php8.4.22             (-> 8.4.22)
#   tools\phpactor2026.bat          tools\phpactor2026          (-> 2026.05.30.2)
#   ...
#
# The extensionless bash wrappers are intentional — bash command lookup
# matches the exact name typed, so `php8.4` from a bash prompt finds
# tools\php8.4 directly. cmd finds tools\php8.4.bat via PATHEXT. Both
# shells, same bare command.
#
# The bare tools\<tool>.bat / tools\<tool> (active selectors) are left
# untouched. Everything else matching <tool><digit>... is wiped and rewritten,
# so removing the only install in a tier removes its wrapper too. Legacy
# .sh tier wrappers from an earlier version of the bundle are also wiped.

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Tool,
    [Parameter(Mandatory)][AllowEmptyString()][string] $FolderPrefix,
    [Parameter(Mandatory)][string] $ToolsDir,
    [ValidateSet('path','phar')][string] $WrapperKind = 'path',
    [string] $PharName,
    [string] $InstallDir,
    [string] $SubDir,
    [string] $VersionFile,
    [string] $VersionField = 'version'
)

$ErrorActionPreference = 'Stop'

if ($WrapperKind -eq 'phar' -and -not $PharName) {
    throw 'PharName is required when WrapperKind is phar.'
}

if (-not $InstallDir) { $InstallDir = $Tool }

$root = Split-Path -Parent $ToolsDir
$installRoot = Join-Path $root "installs\$InstallDir"
$toolEsc = [regex]::Escape($Tool)
$prefixEsc = [regex]::Escape($FolderPrefix)

# Wipe existing tier wrappers in all known formats. Pattern matches:
#   <tool><digit>[<digits-or-dots>]*                 — extensionless bash tier
#   <tool><digit>[<digits-or-dots>]*.bat             — cmd tier
#   <tool><digit>[<digits-or-dots>]*.sh              — legacy bash tier
# The bare active selector (no digit after the tool name) is excluded.
$tierPattern = '^' + $toolEsc + '\d[\d.]*(\.bat|\.sh)?$'
Get-ChildItem -Path $ToolsDir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match $tierPattern } |
    Remove-Item -Force

if (-not (Test-Path $installRoot)) { return }

$installs = Get-ChildItem -Path $installRoot -Directory | ForEach-Object {
    if ($VersionFile) {
        $jsonPath = Join-Path $_.FullName $VersionFile
        if (Test-Path $jsonPath) {
            $json = Get-Content $jsonPath -Raw | ConvertFrom-Json
            $ver = $json.$VersionField
            if ($ver -match '^(\d+)\.(\d+)\.(\d+)(?:\.(\d+))?$') {
                $parts = @($matches[1], $matches[2], $matches[3])
                if ($matches[4]) { $parts += $matches[4] }
                $intParts = $parts | ForEach-Object { [int]$_ }
                [PSCustomObject]@{
                    Name  = $_.Name
                    Parts = $parts
                    V     = [version]($intParts -join '.')
                }
            }
        }
    } else {
        if ($_.Name -match ('^' + $prefixEsc + '(\d+)\.(\d+)\.(\d+)(?:\.(\d+))?')) {
            $parts = @($matches[1], $matches[2], $matches[3])
            if ($matches[4]) { $parts += $matches[4] }
            $intParts = $parts | ForEach-Object { [int]$_ }
            [PSCustomObject]@{
                Name  = $_.Name
                Parts = $parts
                V     = [version]($intParts -join '.')
            }
        }
    }
}

$tiers = @{}
foreach ($i in $installs) {
    for ($n = 1; $n -le $i.Parts.Count; $n++) {
        $key = ($i.Parts[0..($n - 1)] -join '.')
        if (-not $tiers.ContainsKey($key) -or $tiers[$key].V -lt $i.V) {
            $tiers[$key] = $i
        }
    }
}

foreach ($key in $tiers.Keys) {
    $i = $tiers[$key]
    $batPath  = Join-Path $ToolsDir ("$Tool$key.bat")
    $bashPath = Join-Path $ToolsDir ("$Tool$key")

    if ($WrapperKind -eq 'phar') {
        $bat = @"
@echo off
php "%~dp0..\installs\$InstallDir\$($i.Name)\$PharName" %*
"@
        $sh = @"
#!/usr/bin/env bash
DIR="`$(cd "`$(dirname "`${BASH_SOURCE[0]}")" && pwd)"
exec "`$DIR/php" "`$DIR/../installs/$InstallDir/$($i.Name)/$PharName" "`$@"
"@
    } else {
        if ($SubDir) {
            $bat = @"
@echo off
set PATH="%~dp0..\installs\$InstallDir\$($i.Name)\$SubDir";%PATH%
$Tool %*
"@
            $sh = @"
#!/usr/bin/env bash
DIR="`$(cd "`$(dirname "`${BASH_SOURCE[0]}")" && pwd)"
export PATH="`$DIR/../installs/$InstallDir/$($i.Name)/${SubDir}:`$PATH"
exec $Tool "`$@"
"@
        } else {
            $bat = @"
@echo off
set PATH="%~dp0..\installs\$InstallDir\$($i.Name)";%PATH%
$Tool %*
"@
            $sh = @"
#!/usr/bin/env bash
DIR="`$(cd "`$(dirname "`${BASH_SOURCE[0]}")" && pwd)"
export PATH="`$DIR/../installs/$InstallDir/$($i.Name):`$PATH"
exec $Tool "`$@"
"@
        }
    }

    Set-Content -Path $batPath -Value $bat -Encoding ASCII
    $shLF = ($sh -replace "`r`n", "`n") + "`n"
    [System.IO.File]::WriteAllText($bashPath, $shLF, [System.Text.ASCIIEncoding]::new())
}
