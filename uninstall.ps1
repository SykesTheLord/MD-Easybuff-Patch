<#
.SYNOPSIS
    Uninstall the local (Beta) install of "+Easybuff - MD Systems" from a Hearts of Iron IV
    user data directory - what install.ps1 put there, and nothing else.

.DESCRIPTION
    Removes:
        mod\MD-Easybuff-Patch          the junction (never the repo it points at) or copied folder
        mod\+Easybuff-MD-Systems.mod   the launcher pointer
        its entry in dlc_load.json     the game's enabled-mods list (backed up first)
    A Steam Workshop subscription is never touched: those are mod\ugc_<id>.mod.

.EXAMPLE
    .\uninstall.ps1
    Remove from the default path.

.EXAMPLE
    .\uninstall.ps1 -Path "D:\Games\Paradox Interactive\Hearts of Iron IV"
    Remove from a path you choose.

.EXAMPLE
    .\uninstall.ps1 -DryRun
    Show what would be removed, change nothing.

.EXAMPLE
    .\uninstall.ps1 -Force
    Remove a folder even if it does not look like this mod.
#>
[CmdletBinding()]
param(
    [string]$Path,
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$ModDirName = 'MD-Easybuff-Patch'
$ModFile    = '+Easybuff-MD-Systems.mod'
$NameRegex  = '^\s*name\s*=\s*"\+Easybuff - MD Systems( Beta)?"'
$Entry      = "mod/$ModFile"

function Write-Ok   ($m) { Write-Host "OK  $m" -ForegroundColor Green }
function Write-Note ($m) { Write-Host "    $m" }
function Write-Warn ($m) { Write-Host "warning: $m" -ForegroundColor Yellow }
function Die        ($m) { Write-Host "error: $m" -ForegroundColor Red; exit 1 }

$DefaultUserDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Paradox Interactive\Hearts of Iron IV'

if (-not $Path) {
    Write-Host 'HOI4 user data directory'
    Write-Note "default: $DefaultUserDir"
    $reply = Read-Host 'Path (blank for default)'
    $Path = if ([string]::IsNullOrWhiteSpace($reply)) { $DefaultUserDir } else { $reply }
}

$Path = $Path.Trim().Trim('"').TrimEnd('\', '/')
if ($Path -like '~*') { $Path = $Path -replace '^~', $HOME }
if ((Split-Path $Path -Leaf) -eq 'mod') { $Path = Split-Path $Path -Parent }
if (-not (Test-Path -LiteralPath $Path -PathType Container)) { Die "no such directory: $Path" }

if ((Test-Path -LiteralPath (Join-Path $Path 'hoi4.exe')) -or (Test-Path -LiteralPath (Join-Path $Path 'hoi4'))) {
    Write-Warn 'that looks like the Steam game folder, not the user data folder.'
    Write-Warn "the local install lives in: $DefaultUserDir"
    Die 're-run with the user data path'
}

$ModRoot = Join-Path $Path 'mod'
$Dest    = Join-Path $ModRoot $ModDirName
$Pointer = Join-Path $ModRoot $ModFile
$DlcLoad = Join-Path $Path 'dlc_load.json'

if ($DryRun) { Write-Note 'dry run - nothing will be changed' }
$removed = $false

# 1. The mod itself. A junction is only unlinked; a real folder must identify itself as this mod.
if (Test-Path -LiteralPath $Dest) {
    $item = Get-Item -LiteralPath $Dest -Force
    if ($item.LinkType) {
        if ($DryRun) { Write-Note "would remove link $Dest" }
        else { $item.Delete(); Write-Ok "removed link $Dest (its target is untouched)" }
    } else {
        $desc = Join-Path $Dest 'descriptor.mod'
        $isThisMod = (Test-Path -LiteralPath $desc) -and (Select-String -LiteralPath $desc -Pattern $NameRegex -Quiet)
        if (-not ($Force -or $isThisMod)) {
            Die "$Dest exists but its descriptor.mod is not +Easybuff - MD Systems; refusing to delete it (use -Force if you are sure)"
        }
        if ($DryRun) { Write-Note "would remove folder $Dest" }
        else { Remove-Item -LiteralPath $Dest -Recurse -Force; Write-Ok "removed folder $Dest" }
    }
    $removed = $true
}

# 2. The launcher pointer - only if it points at this mod's folder.
if (Test-Path -LiteralPath $Pointer) {
    $pointsHere = Select-String -LiteralPath $Pointer -Pattern "^\s*path\s*=\s*`"mod/$ModDirName`"" -Quiet
    if (-not ($Force -or $pointsHere)) {
        Die "$Pointer does not point at mod/$ModDirName; refusing to delete it (use -Force if you are sure)"
    }
    if ($DryRun) { Write-Note "would remove $Pointer" }
    else { Remove-Item -LiteralPath $Pointer -Force; Write-Ok "removed $Pointer" }
    $removed = $true
}

# 3. The enabled-mods list. Left in place, the game keeps asking for a mod that is gone.
#    The launcher's own database is not edited; it drops the entry when it next rescans.
if ((Test-Path -LiteralPath $DlcLoad) -and (Select-String -LiteralPath $DlcLoad -SimpleMatch "`"$Entry`"" -Quiet)) {
    if ($DryRun) {
        Write-Note "would remove `"$Entry`" from $DlcLoad"
    } else {
        Copy-Item -LiteralPath $DlcLoad -Destination "$DlcLoad.bak" -Force
        try {
            $json = Get-Content -LiteralPath $DlcLoad -Raw | ConvertFrom-Json
            $json.enabled_mods = @($json.enabled_mods | Where-Object { $_ -ne $Entry })
            $out = $json | ConvertTo-Json -Compress -Depth 5
            # Written without a BOM, matching the file the game writes.
            [IO.File]::WriteAllText($DlcLoad, $out, (New-Object Text.UTF8Encoding $false))
            Write-Ok "removed it from the enabled mods in $DlcLoad (backup: dlc_load.json.bak)"
        } catch {
            Copy-Item -LiteralPath "$DlcLoad.bak" -Destination $DlcLoad -Force
            Write-Warn "could not update $DlcLoad ($($_.Exception.Message)) - left unchanged; disable the mod in the launcher instead"
        }
    }
    $removed = $true
}

if (-not $removed) {
    Write-Note "nothing installed at $ModRoot"
} elseif (-not $DryRun) {
    Write-Host ''
    Write-Ok 'uninstalled'
    Write-Note 'If the launcher still lists the mod, restart the launcher so it rescans.'
}
