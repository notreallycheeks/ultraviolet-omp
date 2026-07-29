# ultraviolet startup header — hardware/OS summary in the ultraviolet palette
# https://github.com/notreallycheeks/ultraviolet-omp
#
# Call from your $PROFILE (see README). Requires a Nerd Font and a terminal
# with truecolor ANSI support. Run via the call operator (&) so nothing leaks
# into the session scope.

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

# ---- gather ----------------------------------------------------------------
$os  = Get-CimInstance Win32_OperatingSystem -Property Caption, LastBootUpTime, TotalVisibleMemorySize, FreePhysicalMemory
$nt  = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$cpu = (Get-ItemProperty 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -Name ProcessorNameString).ProcessorNameString.Trim()
$gpu = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*' -Name DriverDesc -ErrorAction SilentlyContinue).DriverDesc |
    Where-Object { $_ -and $_ -notmatch 'Basic|Remote|Virtual|USB' } | Select-Object -First 1

$osName = ($os.Caption -replace '^Microsoft ', '') + $(if ($nt.DisplayVersion) { " $($nt.DisplayVersion)" })
$build  = "$($nt.CurrentBuild).$($nt.UBR)"

$up    = (Get-Date) - $os.LastBootUpTime
$upStr = if ($up.Days) { '{0}d {1}h {2}m' -f $up.Days, $up.Hours, $up.Minutes }
         elseif ($up.Hours) { '{0}h {1}m' -f $up.Hours, $up.Minutes }
         else { '{0}m' -f $up.Minutes }

$memTotal = $os.TotalVisibleMemorySize / 1MB          # KB -> GB
$memUsed  = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB
$memPct   = $memUsed / $memTotal

$disk   = Get-PSDrive -Name ($env:SystemDrive[0])
$dUsed  = $disk.Used / 1GB
$dTotal = ($disk.Used + $disk.Free) / 1GB

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

function row([string]$icon, [string]$label, [string]$value) {
    "$muted│$reset $violet$icon$reset  $muted$($label.PadRight(4))$reset $value"
}

$lines = @(
    "$muted╭─$reset $title"
    row '' 'user' "$text$($env:USERNAME.ToLower())$muted@$reset$silver$($env:COMPUTERNAME.ToLower())$reset"
    row '' 'os'   "$text$osName$reset $muted· $build$reset"
    row '' 'cpu'  "$silver$cpu$reset"
    row '' 'gpu'  "$silver$gpu$reset"
    row '' 'mem'  ("$text{0:N1}$muted / {1:N1} GB$reset  {2} $silver{3}%$reset" -f $memUsed, $memTotal, $bar, [int][math]::Round($memPct * 100))
    row '' 'disk' ("$text{0:N0}$muted / {1:N0} GB$reset $muted($($disk.Name):)$reset" -f $dUsed, $dTotal)
    row '' 'up'   "$silver$upStr$reset $muted· pwsh $($PSVersionTable.PSVersion)$reset"
    "$muted╰─$reset"
)
Write-Host ($lines -join [Environment]::NewLine)
