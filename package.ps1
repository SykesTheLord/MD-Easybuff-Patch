<#
.SYNOPSIS
    Build a clean Steam Workshop package folder for "+Easybuff - MD Systems".

.DESCRIPTION
    Produces build\MD-Easybuff-Patch\ containing ONLY what the game reads --
    common\, events\, localisation\, interface\, descriptor.mod, thumbnail.png.
    The repo's docs, install scripts, .claude\ config and .git\ are deliberately
    left out: a Workshop upload should carry no build-side files.

    Validates before staging, because a broken brace or a missing BOM produces
    no error in-game -- it just silently loads nothing, and by then it is
    published. PowerShell port of package.sh; keep the two in sync.

.PARAMETER Output
    Directory to write the package into (default: build).

.PARAMETER Zip
    Also produce a distributable .zip archive.

.PARAMETER Clean
    Delete the build output and exit.

.EXAMPLE
    .\package.ps1
    Build the package folder.

.EXAMPLE
    .\package.ps1 -Zip
    Build and also produce a .zip archive.

.EXAMPLE
    .\package.ps1 -Output dist
    Write somewhere other than build\.

.EXAMPLE
    .\package.ps1 -Clean
    Delete the build output and exit.
#>
[CmdletBinding()]
param(
    [Alias('o')][string]$Output = 'build',
    [Alias('z')][switch]$Zip,
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'

$ModDirName = 'MD-Easybuff-Patch'
$Src = $PSScriptRoot
$MdSrc = if ($env:MD_SRC) { $env:MD_SRC } else { Join-Path $HOME 'Projects/Millennium-Dawn' }
$Vanilla = if ($env:VANILLA) { $env:VANILLA } else { Join-Path $HOME '.local/share/Steam/steamapps/common/Hearts of Iron IV' }

# Only these are shipped. Add to this list when the mod gains a new content dir
# (gfx/, interface/, music/ ...), or the game will not see it.
$Content = @('common', 'events', 'localisation', 'interface', 'descriptor.mod', 'thumbnail.png')

function Write-Ok    ($m) { Write-Host "✓ $m" -ForegroundColor Green }
function Write-Note  ($m) { Write-Host "  $m" }
function Write-Warn2 ($m) { Write-Host "! $m" -ForegroundColor Yellow }
function Write-Head2 ($m) { Write-Host ''; Write-Host $m -ForegroundColor White }
function Die         ($m) { Write-Host "error: $m" -ForegroundColor Red; exit 1 }

$Script:ErrorCount = 0
$Script:Blockers = @()
function Write-Fail ($m) { Write-Host "  ✗ $m" -ForegroundColor Red; $Script:ErrorCount++ }
function Add-Blocker($m) { $Script:Blockers += $m }

function Get-RelPath($path) {
    $full = [System.IO.Path]::GetFullPath($path)
    if ($full.StartsWith($Src)) { return ($full.Substring($Src.Length + 1) -replace '\\', '/') }
    return ($full -replace '\\', '/')
}

function Test-Bom([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
}

function Format-Size([long]$bytes) {
    $units = 'B', 'K', 'M', 'G', 'T'
    $i = 0
    $val = [double]$bytes
    while ($val -ge 1024 -and $i -lt $units.Length - 1) { $val /= 1024; $i++ }
    if ($i -eq 0) { return "$([long]$val)$($units[$i])" }
    return ('{0:N1}{1}' -f $val, $units[$i])
}

Set-Location -LiteralPath $Src
if (-not (Test-Path 'descriptor.mod')) {
    Die 'run this from the mod folder (no descriptor.mod beside the script)'
}

$OutRoot = $Output.TrimEnd('\', '/')
if (-not [System.IO.Path]::IsPathRooted($OutRoot)) { $OutRoot = Join-Path $Src $OutRoot }
$Stage = Join-Path $OutRoot $ModDirName

if ($Clean) {
    if (Test-Path -LiteralPath $OutRoot) {
        Remove-Item -LiteralPath $OutRoot -Recurse -Force
        Write-Ok "removed $OutRoot/"
    } else {
        Write-Note "nothing to clean at $OutRoot/"
    }
    exit 0
}

# ---------------------------------------------------------------- validation
# Same checks as /validate. A package is the worst place to discover these.
Write-Head2 'Validating content'

$scriptFiles = @()
foreach ($dir in 'common', 'events', 'interface') {
    if (Test-Path -LiteralPath $dir) {
        $scriptFiles += Get-ChildItem -LiteralPath $dir -Recurse -File -Include *.txt, *.gfx, *.gui
    }
}
$scriptFiles += Get-Item 'descriptor.mod'

foreach ($f in $scriptFiles) {
    $fileText = Get-Content -LiteralPath $f.FullName -Raw
    if ($null -eq $fileText) { $fileText = '' }
    $open = ([regex]::Matches($fileText, '\{')).Count
    $close = ([regex]::Matches($fileText, '\}')).Count
    if ($open -ne $close) {
        Write-Fail "unbalanced braces in $(Get-RelPath $f.FullName) ($open open / $close close)"
    }
}
if ($Script:ErrorCount -eq 0) { Write-Ok 'brace balance' }

if (Test-Path -LiteralPath (Join-Path $MdSrc 'common/scripted_effects')) {
    $calls = New-Object System.Collections.Generic.HashSet[string]
    foreach ($dir in 'common', 'events') {
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        Get-ChildItem -LiteralPath $dir -Recurse -File -Include *.txt | ForEach-Object {
            Get-Content -LiteralPath $_.FullName | ForEach-Object {
                if ($_ -match '^\s+([a-z_][a-z_0-9]*) = yes\s*$') { [void]$calls.Add($Matches[1]) }
            }
        }
    }

    $ours = New-Object System.Collections.Generic.HashSet[string]
    foreach ($dir in 'common/scripted_effects', 'common/scripted_triggers') {
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        Get-ChildItem -LiteralPath $dir -Recurse -File -Include *.txt | ForEach-Object {
            Get-Content -LiteralPath $_.FullName | ForEach-Object {
                if ($_ -match '^([a-z_][a-z_0-9]*) = \{') { [void]$ours.Add($Matches[1]) }
            }
        }
    }

    # Engine triggers and keys, not script: visible_when_empty is a decision-category key,
    # instant_build a parameter of add_building_construction.
    $excluded = @('always', 'is_major', 'is_triggered_only', 'is_ai', 'has_war', 'is_subject', 'visible_when_empty', 'instant_build')
    $unresolvedFound = $false
    $mdEffectFiles = @()
    foreach ($dir in 'common/scripted_effects', 'common/scripted_triggers') {
        $p = Join-Path $MdSrc $dir
        if (Test-Path -LiteralPath $p) { $mdEffectFiles += Get-ChildItem -LiteralPath $p -Recurse -File -Include *.txt }
    }
    foreach ($e in ($calls | Sort-Object)) {
        if ($ours.Contains($e) -or $excluded -contains $e) { continue }
        $found = $mdEffectFiles | Select-String -Pattern "^$e = \{" -Quiet
        if (-not $found) {
            Write-Fail "calls an effect that does not exist in MD 2.0: $e"
            $unresolvedFound = $true
        }
    }
    if (-not $unresolvedFound) { Write-Ok 'every MD effect call resolves' }

    # The generated tech list is a snapshot of MD's tree; a stale one silently grants
    # the wrong set, or names techs that no longer exist.
    if (Test-Path -LiteralPath 'tools/gen_tech_effect.py') {
        $py = Get-Command python3 -ErrorAction SilentlyContinue
        if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
        if ($py) {
            & $py.Source tools/gen_tech_effect.py --md $MdSrc --check *> $null
            if ($LASTEXITCODE -eq 0) {
                Write-Ok 'generated technology list matches MD'
            } else {
                Write-Fail 'technology list is stale - run: python3 tools/gen_tech_effect.py'
            }
        } else {
            Write-Warn2 'no python found on PATH - skipped technology list check'
        }
    }
} else {
    Write-Warn2 "MD source not at $MdSrc - skipped effect resolution"
    Write-Note 'set $env:MD_SRC to the Millennium-Dawn path to enable this check'
}

$encBad = $false
foreach ($f in $scriptFiles) {
    if ($f.Name -eq 'descriptor.mod' -or $f.Extension -in '.txt', '.gfx', '.gui') {
        if (Test-Bom $f.FullName) {
            Write-Fail "$(Get-RelPath $f.FullName) has a UTF-8 BOM (script files must not)"
            $encBad = $true
        }
    }
}
if (Test-Path -LiteralPath 'localisation/english') {
    Get-ChildItem -LiteralPath 'localisation/english' -File -Filter *.yml | ForEach-Object {
        if (-not (Test-Bom $_.FullName)) {
            Write-Fail "$(Get-RelPath $_.FullName) is missing its UTF-8 BOM"
            $encBad = $true
        }
    }
}
if (-not $encBad) { Write-Ok 'encodings (no BOM on script, BOM on localisation)' }

$locKeys = New-Object System.Collections.Generic.HashSet[string]
if (Test-Path -LiteralPath 'localisation/english') {
    Get-ChildItem -LiteralPath 'localisation/english' -File -Filter *.yml | ForEach-Object {
        Get-Content -LiteralPath $_.FullName | ForEach-Object {
            if ($_ -match '^ ([A-Za-z0-9_.]+):') { [void]$locKeys.Add($Matches[1]) }
        }
    }
}
$usedKeys = New-Object System.Collections.Generic.HashSet[string]
if (Test-Path -LiteralPath 'events') {
    Get-ChildItem -LiteralPath 'events' -File -Filter *.txt | ForEach-Object {
        Get-Content -LiteralPath $_.FullName | ForEach-Object {
            foreach ($m in [regex]::Matches($_, 'name = ([A-Za-z0-9_.]+)')) { [void]$usedKeys.Add($m.Groups[1].Value) }
            foreach ($m in [regex]::Matches($_, '(?:title|desc) = ([A-Za-z0-9_.]+)')) { [void]$usedKeys.Add($m.Groups[1].Value) }
        }
    }
}
$locMiss = $false
foreach ($k in ($usedKeys | Sort-Object)) {
    if (-not $locKeys.Contains($k)) { Write-Fail "no localisation for $k"; $locMiss = $true }
}
if (-not $locMiss) { Write-Ok 'localisation coverage' }

# A button with no handler does nothing when clicked; a handler with no button never
# fires. Neither produces an error in-game, so cross-check the two sides.
$guiBad = $false
if (Test-Path -LiteralPath 'interface') {
    Get-ChildItem -LiteralPath 'interface' -File -Filter *.gui | ForEach-Object {
        $g = $_.FullName
        $sgPath = Join-Path 'common/scripted_guis' ($_.BaseName + '.txt')
        if (-not (Test-Path -LiteralPath $sgPath)) { return }

        $buttons = New-Object System.Collections.Generic.HashSet[string]
        $inButton = $false
        foreach ($l in (Get-Content -LiteralPath $g)) {
            if ($l -match 'buttonType\s*=\s*\{') { $inButton = $true; continue }
            if ($inButton -and $l -match 'name\s*=\s*"([^"]+)"') {
                [void]$buttons.Add($Matches[1])
                $inButton = $false
            }
        }

        $handlers = New-Object System.Collections.Generic.HashSet[string]
        $triggers = New-Object System.Collections.Generic.HashSet[string]
        foreach ($l in (Get-Content -LiteralPath $sgPath)) {
            if ($l -match '^\s+(ebmd_[a-z_0-9]+)_click\s*=\s*\{') { [void]$handlers.Add($Matches[1]) }
            if ($l -match '^\s+(ebmd_[a-z_0-9]+)_(?:click_enabled|visible)\s*=\s*\{') { [void]$triggers.Add($Matches[1]) }
        }

        foreach ($n in $buttons) {
            if (-not $handlers.Contains($n)) { Write-Fail "button with no handler: $n ($(Get-RelPath $g))"; $guiBad = $true }
        }
        foreach ($n in $handlers) {
            if (-not $buttons.Contains($n)) { Write-Fail "handler with no button: $n ($(Get-RelPath $sgPath))"; $guiBad = $true }
        }
        # _click_enabled / _visible triggers are keyed by element name too; a typo leaves the
        # button permanently enabled or visible, again with no error.
        foreach ($n in $triggers) {
            if (-not $buttons.Contains($n)) { Write-Fail "trigger for a missing button: $n ($(Get-RelPath $sgPath))"; $guiBad = $true }
        }
    }
}
if (-not $guiBad -and (Test-Path -LiteralPath 'common/scripted_guis')) { Write-Ok 'scripted GUI bindings' }

if ($Script:ErrorCount -gt 0) { Die "$($Script:ErrorCount) content problem(s) above - fix before packaging" }

# ------------------------------------------------------- Workshop metadata
Write-Head2 'Checking Workshop metadata'

foreach ($key in 'name', 'version', 'supported_version', 'tags') {
    $found = Select-String -LiteralPath 'descriptor.mod' -Pattern "^\s*$key\s*=" -Quiet
    if (-not $found) { Add-Blocker "descriptor.mod has no '$key='" }
}

if (Test-Path -LiteralPath 'thumbnail.png') {
    $bytes = (Get-Item -LiteralPath 'thumbnail.png').Length
    $dims = 'unknown'
    try {
        $fs = [System.IO.File]::OpenRead((Resolve-Path 'thumbnail.png'))
        try {
            $buf = New-Object byte[] 24
            [void]$fs.Read($buf, 0, 24)
        } finally { $fs.Close() }
        $w = ([uint32]$buf[16] -shl 24) -bor ([uint32]$buf[17] -shl 16) -bor ([uint32]$buf[18] -shl 8) -bor [uint32]$buf[19]
        $h = ([uint32]$buf[20] -shl 24) -bor ([uint32]$buf[21] -shl 16) -bor ([uint32]$buf[22] -shl 8) -bor [uint32]$buf[23]
        $dims = "${w}x${h}"
    } catch { }
    Write-Ok "thumbnail.png present ($dims, $bytes bytes)"
    if ($bytes -gt 1048576) { Add-Blocker "thumbnail.png is over Steam's 1 MB limit" }
} else {
    Add-Blocker "no thumbnail.png (Steam requires one; Millennium Dawn ships 500x500 PNG)"
}

if (-not (Select-String -LiteralPath 'descriptor.mod' -Pattern '^\s*picture\s*=' -Quiet)) {
    Add-Blocker "descriptor.mod has no 'picture=' line pointing at the thumbnail"
}

if (-not (Select-String -LiteralPath 'descriptor.mod' -Pattern '^\s*remote_file_id\s*=' -Quiet)) {
    Write-Note 'no remote_file_id yet - expected until the first upload assigns one'
}

if ($Script:Blockers.Count -eq 0) { Write-Ok 'descriptor is upload-ready' }

# ------------------------------------------------------------------ staging
Write-Head2 'Staging'

if (Test-Path -LiteralPath $Stage) { Remove-Item -LiteralPath $Stage -Recurse -Force }
New-Item -ItemType Directory -Path $Stage -Force | Out-Null
foreach ($item in $Content) {
    if (Test-Path -LiteralPath $item) { Copy-Item -LiteralPath $item -Destination $Stage -Recurse -Force }
}
Write-Ok "staged to $Stage/"

# The working copy is named "... Beta" so the launcher shows which build is
# installed locally. The published package drops that word: Steam should carry
# the release name. Only the STAGED descriptor is rewritten - the repo keeps Beta.
$devNameMatch = Select-String -LiteralPath 'descriptor.mod' -Pattern '^\s*name\s*=\s*"(.*)"' | Select-Object -First 1
if (-not $devNameMatch) { Die 'could not read name= from descriptor.mod' }
$devName = $devNameMatch.Matches[0].Groups[1].Value
$relName = ($devName -replace '(?i)\bBeta\b', '') -replace '\s{2,}', ' '
$relName = $relName.Trim() -replace '\s+-$', ''

if (-not $relName) {
    Die "stripping 'Beta' from `"$devName`" leaves an empty name - check descriptor.mod"
}

if ($relName -ne $devName) {
    $stagedDescriptor = Join-Path $Stage 'descriptor.mod'
    $lines = Get-Content -LiteralPath $stagedDescriptor
    $seen = $false
    $newLines = foreach ($l in $lines) {
        if (-not $seen -and $l -match '^\s*name\s*=') {
            $seen = $true
            "name=`"$relName`""
        } else {
            $l
        }
    }
    # No BOM: descriptor.mod follows the plain-script encoding rule.
    [System.IO.File]::WriteAllLines($stagedDescriptor, $newLines, (New-Object System.Text.UTF8Encoding($false)))

    # Scoped to the name line: a dependency legitimately may contain "Beta"
    # (Millennium Dawn ships "A Beta Test Mod"), and stripping that would break it.
    if (Select-String -LiteralPath $stagedDescriptor -Pattern '^\s*name\s*=.*beta' -Quiet) {
        Die 'staged descriptor name still says beta'
    }
    Write-Ok "release name: `"$devName`" -> `"$relName`""
} else {
    Write-Note "name has no 'Beta' to strip - packaging as `"$devName`""
}

# Verify the staged copy rather than trusting Copy-Item: a package that lost its BOMs
# or picked up stray files looks fine until the game silently ignores it.
if (-not (Test-Path -LiteralPath (Join-Path $Stage 'common')) -or -not (Test-Path -LiteralPath (Join-Path $Stage 'events'))) {
    Die 'staging incomplete - missing common/ or events/'
}

$stagedLoc = Join-Path $Stage 'localisation'
if (Test-Path -LiteralPath $stagedLoc) {
    Get-ChildItem -LiteralPath $stagedLoc -Recurse -File -Filter *.yml | ForEach-Object {
        if (-not (Test-Bom $_.FullName)) { Die "staged $(Get-RelPath $_.FullName) lost its BOM" }
    }
}

$stray = Get-ChildItem -LiteralPath $Stage -Recurse -Force -File | Where-Object {
    $_.Name.StartsWith('.') -or $_.Name -like '*.md' -or $_.Name -like '*.sh' -or $_.Name -like '*.ps1'
} | Select-Object -First 1
if ($stray) { Die "stray non-game file staged: $(Get-RelPath $stray.FullName)" }
Write-Ok 'staged copy verified (encodings intact, no build-side files)'

# ---------------------------------------------------------------- archive
if ($Zip) {
    Write-Head2 'Archiving'
    $verMatch = Select-String -LiteralPath 'descriptor.mod' -Pattern '^\s*version\s*=\s*"(.*)"' | Select-Object -First 1
    $ver = if ($verMatch) { $verMatch.Matches[0].Groups[1].Value } else { 'unversioned' }
    $zipPath = Join-Path $OutRoot "$ModDirName-$ver.zip"
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    Compress-Archive -LiteralPath $Stage -DestinationPath $zipPath -Force
    Write-Ok "wrote $zipPath ($((Get-Item -LiteralPath $zipPath).Length) bytes)"
}

# ----------------------------------------------------------------- summary
Write-Head2 'Package contents'
$stageFull = (Resolve-Path -LiteralPath $Stage).Path
$stagedFiles = Get-ChildItem -LiteralPath $Stage -Recurse -File
$stagedFiles | ForEach-Object {
    $rel = $_.FullName.Substring($stageFull.Length + 1) -replace '\\', '/'
    "  $rel"
} | Sort-Object | ForEach-Object { Write-Host $_ }
Write-Host ''
$totalSize = ($stagedFiles | Measure-Object -Property Length -Sum).Sum
Write-Note "$($stagedFiles.Count) files, $(Format-Size $totalSize)"

if ($Script:Blockers.Count -gt 0) {
    Write-Host ''
    Write-Host 'NOT READY FOR WORKSHOP' -ForegroundColor Red
    foreach ($b in $Script:Blockers) { Write-Host "  ✗ $b" -ForegroundColor Red }
    Write-Host ''
    Write-Host 'The folder is built and usable for local testing, but fix the above before uploading.'
    exit 0
}

Write-Host ''
Write-Ok 'ready to upload'
Write-Note "Point the Paradox launcher at $Stage/ to publish, or upload the zip manually."
