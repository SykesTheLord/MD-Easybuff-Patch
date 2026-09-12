<#
.SYNOPSIS
    Install "+Easybuff - MD Systems" into a Hearts of Iron IV user data directory.

.DESCRIPTION
    HOI4 loads mods from the USER DATA directory, not the Steam game folder:
        %USERPROFILE%\Documents\Paradox Interactive\Hearts of Iron IV
    That directory holds "mod\", where this script places the mod and its .mod pointer.

    Default is a directory junction, so edits in the repo apply without reinstalling.
    Junctions do not require administrator rights; -Copy is available if you prefer.

.EXAMPLE
    .\install.ps1
    Link into the default path.

.EXAMPLE
    .\install.ps1 -Path "D:\Games\Paradox Interactive\Hearts of Iron IV"
    Link into a path you choose.

.EXAMPLE
    .\install.ps1 -Copy
    Copy the files instead of linking.

.EXAMPLE
    .\install.ps1 -Uninstall
    Remove it again.
#>
[CmdletBinding()]
param(
    [string]$Path,
    [switch]$Copy,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$ModDirName = 'MD-Easybuff-Patch'
$ModFile    = '+Easybuff-MD-Systems.mod'
$Src        = $PSScriptRoot

function Write-Ok   ($m) { Write-Host "OK  $m" -ForegroundColor Green }
function Write-Note ($m) { Write-Host "    $m" }
function Write-Warn ($m) { Write-Host "warning: $m" -ForegroundColor Yellow }
function Die        ($m) { Write-Host "error: $m" -ForegroundColor Red; exit 1 }

$DefaultUserDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Paradox Interactive\Hearts of Iron IV'

# Source sanity: refuse to install something that isn't this mod.
if (-not (Test-Path (Join-Path $Src 'descriptor.mod')) -or -not (Test-Path (Join-Path $Src $ModFile))) {
    Die "run this from the mod folder (no descriptor.mod / $ModFile beside the script)"
}

# Resolve the target directory.
if (-not $Path) {
    Write-Host 'HOI4 user data directory'
    Write-Note "default: $DefaultUserDir"
    $reply = Read-Host 'Path (blank for default)'
    $Path = if ([string]::IsNullOrWhiteSpace($reply)) { $DefaultUserDir } else { $reply }
}

$Path = $Path.Trim().Trim('"').TrimEnd('\', '/')
if ($Path -like '~*') { $Path = $Path -replace '^~', $HOME }

# Accept being handed the mod\ directory itself.
if ((Split-Path $Path -Leaf) -eq 'mod') { $Path = Split-Path $Path -Parent }

if (-not (Test-Path -LiteralPath $Path -PathType Container)) { Die "no such directory: $Path" }

# Catch the common mistake of pointing at the Steam game install.
if (Test-Path -LiteralPath (Join-Path $Path 'hoi4.exe')) {
    Write-Warn 'that looks like the Steam game folder, not the user data folder.'
    Write-Warn "mods belong in: $DefaultUserDir"
    Die 're-run with the user data path'
}

$ModRoot    = Join-Path $Path 'mod'
$Dest       = Join-Path $ModRoot $ModDirName
$Descriptor = Join-Path $ModRoot $ModFile

if ($Uninstall) {
    $removed = $false
    if (Test-Path -LiteralPath $Dest) {
        $item = Get-Item -LiteralPath $Dest -Force
        if ($item.LinkType) {
            # Remove the junction itself, never follow into the target.
            $item.Delete()
            Write-Ok "removed link $Dest"
        } else {
            Remove-Item -LiteralPath $Dest -Recurse -Force
            Write-Ok "removed folder $Dest"
        }
        $removed = $true
    }
    if (Test-Path -LiteralPath $Descriptor) {
        Remove-Item -LiteralPath $Descriptor -Force
        Write-Ok "removed $Descriptor"
        $removed = $true
    }
    if (-not $removed) { Write-Note "nothing installed at $ModRoot" }
    exit 0
}

New-Item -ItemType Directory -Path $ModRoot -Force | Out-Null

# Clear any previous install so copy/link modes can be swapped freely.
if (Test-Path -LiteralPath $Dest) {
    $item = Get-Item -LiteralPath $Dest -Force
    if ($item.LinkType) { $item.Delete() } else { Remove-Item -LiteralPath $Dest -Recurse -Force }
}

function Copy-ModContent {
    param([string]$From, [string]$To)
    New-Item -ItemType Directory -Path $To -Force | Out-Null
    # Ship only what the game reads - not the repo's docs, scripts or .claude config.
    foreach ($item in @('common', 'events', 'localisation', 'descriptor.mod', 'thumbnail.png')) {
        $p = Join-Path $From $item
        if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination $To -Recurse -Force }
    }
}

if (-not $Copy) {
    # Refuse to link a source that lives inside the target - it would nest into itself.
    if ($Src.TrimEnd('\') -like ((Join-Path $ModRoot '*'))) {
        Die "source is already inside $ModRoot; use -Copy or move the repo"
    }

    $linkError = $null
    try { New-Item -ItemType Junction -Path $Dest -Target $Src -ErrorAction Stop | Out-Null }
    catch { $linkError = $_.Exception.Message }

    # New-Item can report success yet leave an unusable link - seen on non-NTFS volumes,
    # network shares and OneDrive-redirected Documents folders. Prove it resolves before
    # trusting it, or the install looks fine and the game silently loads nothing.
    if (-not $linkError -and -not (Test-Path -LiteralPath (Join-Path $Dest 'common'))) {
        $linkError = 'the junction was created but its contents are not readable'
        $stale = Get-Item -LiteralPath $Dest -Force -ErrorAction SilentlyContinue
        if ($stale) { if ($stale.LinkType) { $stale.Delete() } else { Remove-Item -LiteralPath $Dest -Recurse -Force } }
    }

    if ($linkError) {
        Write-Warn "could not link: $linkError"
        Write-Warn 'falling back to a copy. Re-run with -Copy to skip this check next time.'
        $Copy = $true
    } else {
        Write-Ok "linked $Dest -> $Src"
        Write-Note 'edits in the repo apply immediately; no reinstall needed'
    }
}

if ($Copy) {
    Copy-ModContent -From $Src -To $Dest
    Write-Ok "copied mod files to $Dest"
}

Copy-Item -LiteralPath (Join-Path $Src $ModFile) -Destination $Descriptor -Force
Write-Ok "installed descriptor $Descriptor"

# Verify the game will actually find content.
if (-not (Test-Path -LiteralPath (Join-Path $Dest 'common')) -or
    -not (Test-Path -LiteralPath (Join-Path $Dest 'events'))) {
    Die "install looks incomplete - $Dest is missing common\ or events\"
}

Write-Host ''
Write-Ok 'installed'
Write-Note 'Enable in the launcher, then set load order:'
Write-Note '  Millennium Dawn  ->  +Easybuff  ->  +Easybuff - MD Systems'
Write-Note 'This mod must load LAST. Requires Millennium Dawn 2.0.x.'
