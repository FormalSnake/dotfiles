# Reclaim disk on the g815's Windows side, the twin of storage-gc.sh. Deletes
# only what the next launch regenerates: driver installer
# leftovers, game download caches, stale cargo output, temp dirs, the Windows
# component store backlog. Nothing here touches saves, worlds, replays, mods,
# media or downloads; those are sized in the "not touched" list at the end.
#
# Dry run by default. Pass -Apply to delete.
#
#   storage-gc.ps1                 what would go, plus the manual-review list
#   storage-gc.ps1 -Apply          delete it
#   storage-gc.ps1 -Apply -Deep    also the DISM component store cleanup,
#                                  which runs for minutes, so it waits for
#                                  -Deep or for C: under LowFreeGB
#   storage-gc.ps1 -Verbose        list every item, not just the totals
#
# Game state is never touched, not even sized: this is the gaming partition.
# No shader caches (NVIDIA DXCache, Steam shadercache, D3DSCache), no
# Fortnite content cache or replays, no Minecraft instances. Only a game's
# own temp and old auto-update leftovers go.
#
# Staleness: a directory goes only when its newest depth-1 entry is older
# than the cutoff, so an in-flight build is never pulled out from under
# itself. Below LowFreeGB free on C: every cutoff is cut to a quarter and
# -Deep switches itself on.
#
# Source of truth: ~/.config/nix/scripts/storage-gc.ps1 on the macbook. The
# copy at C:\Users\Kyan\.local\bin\storage-gc.ps1 runs daily from the
# "kyan-storage-gc" scheduled task; re-copy after editing (see CLAUDE.md).

[CmdletBinding()]
param(
  [switch]$Apply,
  [switch]$Deep,
  [int]$AgeDays = 30,
  [int]$TargetAgeDays = 7,
  [int]$TempAgeDays = 7,
  [int]$LowFreeGB = 30
)

$ErrorActionPreference = 'SilentlyContinue'
# -Verbose means "show every item" here; the cmdlets' own verbose chatter
# (every CIM query) is not wanted.
$showItems = [bool]$PSBoundParameters['Verbose']
$VerbosePreference = 'SilentlyContinue'
$home_ = $env:USERPROFILE
$local = Join-Path $home_ 'AppData\Local'
$roaming = Join-Path $home_ 'AppData\Roaming'
$now = Get-Date
$script:freed = [double]0
$script:plan = @()

$freeGB = [math]::Round((Get-PSDrive C).Free / 1GB)
$lowFree = $freeGB -lt $LowFreeGB
if ($lowFree) {
  $Deep = $true
  $AgeDays = [math]::Max(1, [int]($AgeDays / 4))
  $TargetAgeDays = [math]::Max(1, [int]($TargetAgeDays / 4))
  $TempAgeDays = [math]::Max(1, [int]($TempAgeDays / 4))
}

function Log($msg) { '[{0:HH:mm:ss}] {1}' -f (Get-Date), $msg }

function Human([double]$bytes) {
  if ($bytes -ge 1GB) { '{0:N1} GB' -f ($bytes / 1GB) }
  elseif ($bytes -ge 1MB) { '{0:N0} MB' -f ($bytes / 1MB) }
  else { '{0:N0} KB' -f ($bytes / 1KB) }
}

# robocopy in list mode is the fast way to size a tree; it also skips
# junctions, which keeps the AppData aliases from counting twice.
function DirBytes($path) {
  if (-not (Test-Path -LiteralPath $path)) { return 0 }
  $line = robocopy $path NUL /L /E /NFL /NDL /NJH /BYTES /XJ /R:0 /W:0 2>$null | Select-String 'Bytes :'
  if (-not $line) { return 0 }
  [double](($line.ToString().Trim() -split '\s+')[2])
}

# Age of the most recently written depth-1 entry, in days. A build always
# writes a child while the parent's own timestamp can sit unchanged for months.
function NewestAgeDays($path) {
  $items = Get-ChildItem -LiteralPath $path -Force
  if (-not $items) { return 99999 }
  $newest = ($items | Measure-Object LastWriteTime -Maximum).Maximum
  [int](($now - $newest).TotalDays)
}

# Queue LABEL PATH: size it, record it, delete when -Apply is set.
function Queue($label, $path) {
  if (-not (Test-Path -LiteralPath $path)) { return }
  $bytes = DirBytes $path
  if ($bytes -lt 1MB) { return }
  $script:freed += $bytes
  $script:plan += [pscustomobject]@{ Bytes = $bytes; Label = $label; Path = $path.Replace($home_, '~') }
  if ($Apply) { Remove-Item -LiteralPath $path -Recurse -Force }
}

# Queue the stale files directly under PATH (temp dirs: never the dir itself).
function QueueOldFiles($label, $path, $days) {
  if (-not (Test-Path -LiteralPath $path)) { return }
  $cutoff = $now.AddDays(-$days)
  $items = Get-ChildItem -LiteralPath $path -Force | Where-Object { $_.LastWriteTime -lt $cutoff }
  if (-not $items) { return }
  $bytes = [double]0
  foreach ($i in $items) {
    if ($i.PSIsContainer) { $bytes += DirBytes $i.FullName } else { $bytes += $i.Length }
    if ($Apply) { Remove-Item -LiteralPath $i.FullName -Recurse -Force }
  }
  if ($bytes -lt 1MB) { return }
  $script:freed += $bytes
  $script:plan += [pscustomobject]@{ Bytes = $bytes; Label = $label; Path = "$($path.Replace($home_, '~')) ($($items.Count) entries older than ${days}d)" }
}

# RunCmd LABEL DIR SCRIPTBLOCK: for tools that prune their own cache. Sizes
# DIR before and after so the accounting matches the deletes above.
function RunCmd($label, $dir, [scriptblock]$cmd) {
  if (-not (Test-Path -LiteralPath $dir)) { return }
  $before = DirBytes $dir
  if ($before -lt 1MB) { return }
  if ($Apply) {
    & $cmd *> $null
    $after = DirBytes $dir
    $delta = $before - $after
    if ($delta -le 0) { return }
    $script:freed += $delta
    $script:plan += [pscustomobject]@{ Bytes = $delta; Label = $label; Path = $cmd.ToString().Trim() }
  } else {
    $script:plan += [pscustomobject]@{ Bytes = $before; Label = $label; Path = $cmd.ToString().Trim() }
  }
}

''
'storage-gc (Windows) - {0}{1} | stale after {2}d, target {3}d, temp {4}d{5}' -f `
  $(if ($Apply) { 'APPLY' } else { 'dry run, pass -Apply to delete' }),
  $(if ($lowFree) { " | LOW FREE ($freeGB GB < $LowFreeGB GB), cutoffs cut to a quarter, -Deep on" } else { '' }),
  $AgeDays, $TargetAgeDays, $TempAgeDays, $(if ($Deep) { ' | deep' } else { '' })
Get-PSDrive C | ForEach-Object { 'before: {0} GB used of {1} GB, {2} GB free on C:' -f [math]::Round($_.Used / 1GB), [math]::Round(($_.Used + $_.Free) / 1GB), [math]::Round($_.Free / 1GB) }
''

### 1. Build output under the project trees

# Every cargo target dir carries a CACHEDIR.TAG, whatever it is called and
# wherever CARGO_TARGET_DIR put it. C:\nd is where the g815's Windows VM
# checks out agent worktrees (systems/g815/windows-vm.nix).
foreach ($root in @((Join-Path $home_ 'Developer'), 'C:\nd', (Join-Path $home_ '.dx'))) {
  if (-not (Test-Path -LiteralPath $root)) { continue }
  Get-ChildItem -LiteralPath $root -Recurse -Force -Depth 6 -Filter CACHEDIR.TAG |
    Where-Object { (Get-Content -LiteralPath $_.FullName -TotalCount 1) -like 'Signature: 8a477f597d28d172789f06886806bc55*' } |
    ForEach-Object {
      $dir = $_.DirectoryName
      if ((NewestAgeDays $dir) -ge $TargetAgeDays) { Queue 'cachedir-tag' $dir }
    }
  Get-ChildItem -LiteralPath $root -Recurse -Force -Depth 4 -Directory -Filter node_modules |
    ForEach-Object { if ((NewestAgeDays $_.FullName) -ge $AgeDays) { Queue 'node_modules' $_.FullName } }
}

### 2. Package manager caches

# Cargo re-downloads crates on the next build; the toolchains in .rustup are
# listed for review instead, since rust-toolchain files pin them.
foreach ($d in @('registry\cache', 'registry\src', 'git\checkouts')) {
  $p = Join-Path $home_ ".cargo\$d"
  if ((Test-Path -LiteralPath $p) -and ((NewestAgeDays $p) -ge $AgeDays)) { Queue 'cargo-cache' $p }
}
$p = Join-Path $home_ '.nuget\packages'
if ((Test-Path -LiteralPath $p) -and ((NewestAgeDays $p) -ge $AgeDays)) { Queue 'nuget-cache' $p }
$p = Join-Path $home_ '.bun\install\cache'
if ((Test-Path -LiteralPath $p) -and ((NewestAgeDays $p) -ge $AgeDays)) { Queue 'bun-cache' $p }
QueueOldFiles 'pip-cache' (Join-Path $local 'pip\cache') $AgeDays
QueueOldFiles 'uv-cache' (Join-Path $local 'uv\cache') $AgeDays

### 3. Windows itself

QueueOldFiles 'user-temp' $env:TEMP $TempAgeDays
QueueOldFiles 'windows-temp' 'C:\Windows\Temp' $TempAgeDays
QueueOldFiles 'update-download' 'C:\Windows\SoftwareDistribution\Download' $TempAgeDays
QueueOldFiles 'crash-dumps' (Join-Path $local 'CrashDumps') $AgeDays
QueueOldFiles 'crash-dumps' 'C:\Windows\Minidump' $AgeDays
if (Test-Path 'C:\Windows\MEMORY.DMP') { Queue 'crash-dumps' 'C:\Windows\MEMORY.DMP' }
if ($Apply) { Clear-RecycleBin -Force }

# The component store keeps superseded versions of every updated component.
# DISM's cleanup is the only supported way to drop them; it runs for minutes,
# so it is -Deep only. The reclaimable size comes from its own analysis.
if ($Deep) {
  $analysis = Dism /Online /Cleanup-Image /AnalyzeComponentStore 2>$null
  $recommended = ($analysis | Select-String 'Cleanup Recommended : Yes')
  if ($recommended) {
    $sizeLine = ($analysis | Select-String 'Actual Size of Component Store : ([\d.]+) GB').Matches
    $gb = if ($sizeLine) { [double]$sizeLine[0].Groups[1].Value } else { 0 }
    if ($Apply) {
      Dism /Online /Cleanup-Image /StartComponentCleanup *> $null
      $after = Dism /Online /Cleanup-Image /AnalyzeComponentStore 2>$null | Select-String 'Actual Size of Component Store : ([\d.]+) GB'
      $gbAfter = if ($after) { [double]$after.Matches[0].Groups[1].Value } else { $gb }
      $delta = ($gb - $gbAfter) * 1GB
      if ($delta -gt 0) {
        $script:freed += $delta
        $script:plan += [pscustomobject]@{ Bytes = $delta; Label = 'component-store'; Path = 'Dism /StartComponentCleanup' }
      }
    } else {
      $script:plan += [pscustomobject]@{ Bytes = 0; Label = 'component-store'; Path = "Dism /StartComponentCleanup (store is $gb GB, cleanup recommended; size freed only known after a run)" }
    }
  }
  if ($Apply) { Delete-DeliveryOptimizationCache -Force }
}

### 4. Drivers and games

# NVIDIA keeps every driver package it ever downloaded or unpacked.
QueueOldFiles 'nvidia-installer' 'C:\ProgramData\NVIDIA Corporation\Downloader' $AgeDays
QueueOldFiles 'nvidia-installer' 'C:\ProgramData\NVIDIA Corporation\Installer2' $AgeDays
QueueOldFiles 'nvidia-installer' 'C:\ProgramData\NVIDIA\Downloader' $AgeDays

# Roblox keeps each build it ever auto-updated through; only the newest runs.
$versions = Join-Path $local 'Roblox\Versions'
if (Test-Path -LiteralPath $versions) {
  Get-ChildItem -LiteralPath $versions -Directory | Sort-Object LastWriteTime -Descending | Select-Object -Skip 1 |
    ForEach-Object { Queue 'roblox-old-build' $_.FullName }
}

# BeamNG's cache and temp regenerate on launch; mods, vehicles and settings
# sit next to them under current\ and stay.
QueueOldFiles 'beamng-cache' (Join-Path $local 'BeamNG\BeamNG.drive\current\cache') $AgeDays
QueueOldFiles 'beamng-cache' (Join-Path $local 'BeamNG\BeamNG.drive\current\temp') $TempAgeDays

foreach ($lib in @('C:\Program Files (x86)\Steam', 'D:\SteamLibrary', 'Z:\SteamLibrary')) {
  $p = Join-Path $lib 'steamapps\downloading'
  if ((Test-Path -LiteralPath $p) -and ((NewestAgeDays $p) -ge $AgeDays)) { Queue 'steam-abandoned-download' $p }
  QueueOldFiles 'steam-temp' (Join-Path $lib 'steamapps\temp') $AgeDays
}
QueueOldFiles 'fortnite-logs' (Join-Path $local 'FortniteGame\Saved\Logs') $AgeDays

### Report

if ($script:plan.Count -eq 0) {
  'nothing to reclaim.'
} else {
  $script:plan | Group-Object Label | ForEach-Object {
    [pscustomobject]@{ Bytes = ($_.Group | Measure-Object Bytes -Sum).Sum; Label = $_.Name; Count = $_.Count }
  } | Sort-Object Bytes -Descending | ForEach-Object {
    '{0,10}  {1,-26} {2}' -f (Human $_.Bytes), $_.Label, $(if ($_.Count -gt 1) { "$($_.Count) items" } else { '' })
  }
  if ($showItems) {
    ''
    $script:plan | Sort-Object Bytes -Descending | ForEach-Object { '{0,10}  {1,-26} {2}' -f (Human $_.Bytes), $_.Label, $_.Path }
  }
  ''
  '{0} {1}' -f $(if ($Apply) { 'reclaimed:' } else { 'reclaimable:' }), (Human $script:freed)
}
''
Get-PSDrive C | ForEach-Object { 'after:  {0} GB used of {1} GB, {2} GB free on C:' -f [math]::Round($_.Used / 1GB), [math]::Round(($_.Used + $_.Free) / 1GB), [math]::Round($_.Free / 1GB) }

### Manual review: sized, never touched

''
'not touched, decide by hand:'
foreach ($p in @(
  (Join-Path $home_ 'Downloads'),
  (Join-Path $home_ '.rustup\toolchains'),
  (Join-Path $roaming 'ModrinthApp'),
  (Join-Path $roaming 'PrismLauncher'),
  (Join-Path $local 'FortniteGame\Saved\Demos'),
  'F:\Movies',
  'F:\minecraft-backups',
  'Z:\Epic',
  'Z:\Ubisoft'
)) {
  if (Test-Path -LiteralPath $p) { '{0,10}  {1}' -f (Human (DirBytes $p)), $p.Replace($home_, '~') }
}
$toolchains = rustup toolchain list 2>$null
if ($toolchains) { '            rustup toolchains: ' + (($toolchains | ForEach-Object { ($_ -split ' ')[0] }) -join ', ') }
