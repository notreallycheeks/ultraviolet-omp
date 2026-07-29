# ultraviolet startup header — hardware/OS summary in the ultraviolet palette
# https://github.com/notreallycheeks/ultraviolet-omp
#
# Call from your $PROFILE (see README). Requires PowerShell 7+, a Nerd Font and
# a terminal with truecolor ANSI support. Run via the call operator (&) so
# nothing leaks into the session scope. Deliberately CIM/WMI-free so it stays
# fast enough (<100 ms) to never trigger pwsh's slow-profile startup notice.

$esc   = [char]27
$reset = "$esc[0m"

function fg([string]$hex) {
    "$esc[38;2;{0};{1};{2}m" -f [Convert]::ToInt32($hex.Substring(1, 2), 16),
        [Convert]::ToInt32($hex.Substring(3, 2), 16),
        [Convert]::ToInt32($hex.Substring(5, 2), 16)
}

$violet  = fg '#8B5CF6'
$bright  = fg '#C4B5FD'
$muted   = fg '#716C85'
$silver  = fg '#A9A5B8'
$text    = fg '#E8E6F0'
$overlay = fg '#3D3A47'
$alert   = fg '#F2557E'
$deep    = fg '#16141C'

# ---- banner cleanup --------------------------------------------------------
# If the console still shows the stock "PowerShell 7.x.x" banner (shell was
# started without -NoLogo, e.g. via the Start-menu shortcut), wipe it so the
# header is the first thing on screen. Only fires when the banner is the sole
# content of a fresh buffer, so nested shells never lose their scrollback.
try {
    $raw = $Host.UI.RawUI
    if ($raw.CursorPosition.Y -in 1..3) {
        $w    = [Math]::Min(40, $raw.BufferSize.Width) - 1
        $rect = [System.Management.Automation.Host.Rectangle]::new(0, 0, $w, 0)
        $row0 = (-join ($raw.GetBufferContents($rect) | ForEach-Object Character)).Trim()
        if ($row0 -match '^PowerShell \d+\.\d+\.\d+') {
            [Console]::Write("$esc[2J$esc[3J$esc[H")
        }
    }
} catch { }

# ---- gather ----------------------------------------------------------------
$nt  = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$cpu = (Get-ItemProperty 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -Name ProcessorNameString).ProcessorNameString.Trim()
$gpu = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*' -Name DriverDesc -ErrorAction SilentlyContinue).DriverDesc |
    Where-Object { $_ -and $_ -notmatch 'Basic|Remote|Virtual|USB' } | Select-Object -First 1

# ProductName still says "Windows 10" on Windows 11 — correct it via the build number
$osName = $nt.ProductName
if ([int]$nt.CurrentBuild -ge 22000) { $osName = $osName -replace 'Windows 10', 'Windows 11' }
if ($nt.DisplayVersion) { $osName += " $($nt.DisplayVersion)" }
$build = "$($nt.CurrentBuild).$($nt.UBR)"

$up    = [TimeSpan]::FromMilliseconds([Environment]::TickCount64)
$upStr = if ($up.Days) { '{0}d {1}h {2}m' -f $up.Days, $up.Hours, $up.Minutes }
         elseif ($up.Hours) { '{0}h {1}m' -f $up.Hours, $up.Minutes }
         else { '{0}m' -f $up.Minutes }

# GetGCMemoryInfo reports the state at the last GC; a fresh process has had
# none yet, so nudge gen 0 once to populate it
$mem = [System.GC]::GetGCMemoryInfo()
if ($mem.MemoryLoadBytes -eq 0) { [System.GC]::Collect(0); $mem = [System.GC]::GetGCMemoryInfo() }
$memTotal = $mem.TotalAvailableMemoryBytes / 1GB
$memUsed  = $mem.MemoryLoadBytes / 1GB
$memPct   = $memUsed / $memTotal

$disk   = [System.IO.DriveInfo]::new($env:SystemDrive)
$dUsed  = ($disk.TotalSize - $disk.TotalFreeSpace) / 1GB
$dTotal = $disk.TotalSize / 1GB

# ---- render ----------------------------------------------------------------
$barW   = 12
$fill   = [int][math]::Round($memPct * $barW)
$pctCol = if ($memPct -ge 0.85) { $alert } else { $bright }
$bar    = $pctCol + ('━' * $fill) + $overlay + ('━' * ($barW - $fill)) + $reset

$word  = 'ultraviolet'
$from  = 139, 92, 246                                  # violet
$to    = 196, 181, 253                                 # violet-bright
$title = ''
for ($i = 0; $i -lt $word.Length; $i++) {
    $t = $i / ($word.Length - 1)
    $r = [int]($from[0] + ($to[0] - $from[0]) * $t)
    $g = [int]($from[1] + ($to[1] - $from[1]) * $t)
    $b = [int]($from[2] + ($to[2] - $from[2]) * $t)
    $title += "$esc[38;2;$r;$g;${b}m$($word[$i])"
}
$title += $reset

# PowerShell logo: a sheared parallelogram painted with background color,
# vertical violet-bright -> violet-deep gradient, dark ❯_ in the middle
$logoRows = @(
    '              ',
    '              ',
    '              ',
    '   ❯_         ',
    '              ',
    '              ',
    '              '
)
$lFrom = 196, 181, 253                                 # violet-bright
$lTo   = 91, 63, 166                                   # violet-deep
$logo  = for ($i = 0; $i -lt 7; $i++) {
    $t = $i / 6
    $r = [int]($lFrom[0] + ($lTo[0] - $lFrom[0]) * $t)
    $g = [int]($lFrom[1] + ($lTo[1] - $lFrom[1]) * $t)
    $b = [int]($lFrom[2] + ($lTo[2] - $lFrom[2]) * $t)
    (' ' * (6 - $i)) + "$esc[48;2;$r;$g;${b}m$esc[1m$deep$($logoRows[$i])$reset" + (' ' * $i)
}

$info = @(
    ('', 'user', "$text$($env:USERNAME.ToLower())$muted@$reset$silver$($env:COMPUTERNAME.ToLower())$reset"),
    ('', 'os',   "$text$osName$reset $muted· $build$reset"),
    ('', 'cpu',  "$silver$cpu$reset"),
    ('', 'gpu',  "$silver$gpu$reset"),
    ('', 'mem',  ("$text{0:N1}$muted / {1:N1} GB$reset  {2} $silver{3}%$reset" -f $memUsed, $memTotal, $bar, [int][math]::Round($memPct * 100))),
    ('', 'disk', ("$text{0:N0}$muted / {1:N0} GB$reset $muted($($env:SystemDrive))$reset" -f $dUsed, $dTotal)),
    ('', 'up',   "$silver$upStr$reset $muted· pwsh $($PSVersionTable.PSVersion)$reset")
)

$lines = @("$muted╭─$reset $title")
for ($i = 0; $i -lt 7; $i++) {
    $icon, $label, $value = $info[$i]
    $lines += "$muted│$reset $($logo[$i])  $violet$icon$reset  $muted$($label.PadRight(4))$reset $value"
}
$lines += "$muted╰─$reset"
Write-Host ($lines -join [Environment]::NewLine)
