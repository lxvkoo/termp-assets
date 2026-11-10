<#
  termp + pi.dev -> Discord presence (Windows 11)

  Install / one-liner:
    irm https://raw.githubusercontent.com/lxvkoo/termp-assets/main/setup.ps1 | iex

  What it does:
    1. ensures Scoop
    2. adds the polter-dev bucket and installs `termp`
    3. drops the reference config.toml (with the Pi icon) into %APPDATA%\termp
    4. disables the broken autostart and starts the daemon hidden
    5. prints `termp status`
#>

$ErrorActionPreference = 'Stop'

$RepoRaw  = 'https://raw.githubusercontent.com/lxvkoo/termp-assets/main'
$CfgUrl   = "$RepoRaw/config.toml"
$CfgDir   = Join-Path $env:APPDATA 'termp'
$CfgPath  = Join-Path $CfgDir 'config.toml'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "    $msg" -ForegroundColor Yellow }

function Refresh-Path {
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $env:Path = "$machine;$user"
}

if (-not (Get-Process Discord -ErrorAction SilentlyContinue)) {
    Warn 'Discord Desktop does not look like it is running - presence only shows up with the desktop app open.'
}

# ---------------------------------------------------------------- 1. Scoop ---
Step 'Checking Scoop'
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Ok 'Scoop is already installed.'
} else {
    Warn 'Scoop not found, installing it...'
    try { Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force } catch { }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Warn 'git is required by Scoop, installing Git.Git via winget...'
            winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements | Out-Null
            Refresh-Path
        }
    }
    Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression
    Refresh-Path
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Warn 'Scoop did not land on PATH. Close this window, open a new terminal and run the same command again.'
        return
    }
    Ok 'Scoop installed.'
}

# ----------------------------------------------------------------- 2. termp ---
Step 'Installing termp'
$scoopRoot  = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
$bucketDir  = Join-Path $scoopRoot 'buckets\polter-dev'
if (-not (Test-Path $bucketDir)) {
    & scoop bucket add polter-dev https://github.com/polter-dev/scoop-bucket | Out-Null
    Ok 'Bucket polter-dev added.'
} else {
    Ok 'Bucket polter-dev already present.'
}
& scoop install termp | Out-Host
Refresh-Path
$termp = (Get-Command termp -ErrorAction SilentlyContinue).Source
if (-not $termp) {
    Warn 'termp is not on PATH yet. Reopen the terminal and run the command again.'
    return
}
Ok "termp: $termp"

# ------------------------------------------------------------------ 3. cfg ---
Step 'Writing config.toml'
if (-not (Test-Path $CfgDir)) { New-Item -ItemType Directory -Path $CfgDir -Force | Out-Null }
if (Test-Path $CfgPath) {
    $backup = "$CfgPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $CfgPath $backup -Force
    Ok "Old config backed up to $backup"
}
Invoke-WebRequest -UseBasicParsing -Uri $CfgUrl -OutFile $CfgPath
Ok "Config written to $CfgPath"
Ok 'Custom tool rule: pi-coding-agent -> Pi, icon from raw.githubusercontent.com'

# ------------------------------------------------- 4. hidden start helper ---
Step 'Installing the hidden launcher'
$HelperPath = Join-Path $env:LOCALAPPDATA 'termp\start-hidden.ps1'
$HelperBody = @'
# Starts the termp daemon in the background with no console window.
$ErrorActionPreference = 'SilentlyContinue'

$termp = (Get-Command termp).Source
if (-not $termp) { $termp = Join-Path $env:USERPROFILE 'scoop\shims\termp.exe' }
if (-not (Test-Path $termp)) { return }

function Test-Daemon {
    $out = & $termp status 2>$null | Out-String
    return [bool]($out -match '(?m)^\s*Running\s+yes')
}

if (Test-Daemon) { return }

# wait for Discord Desktop (Rich Presence needs it), max 2 minutes
$deadline = (Get-Date).AddSeconds(120)
while (-not (Get-Process Discord -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 5
}

Start-Process -FilePath $termp -ArgumentList 'start', '--foreground' -WindowStyle Hidden
Start-Sleep -Seconds 5

if (-not (Test-Daemon)) {
    Start-Process -FilePath $termp -ArgumentList 'start', '--foreground' -WindowStyle Hidden
}
'@
[IO.File]::WriteAllText($HelperPath, $HelperBody, (New-Object System.Text.UTF8Encoding($false)))
Ok "Launcher written to $HelperPath"

# ------------------------------------------------- 5. daemon + autostart ---
Step 'Starting the daemon (hidden)'
# NOTE: termp's own autostart is deliberately NOT used - on Windows the
# detached `termp start` fails with "being used by another process".
& $termp stop 2>$null | Out-Null
Start-Sleep -Milliseconds 500
& $termp autostart disable 2>$null | Out-Null
Start-Process -FilePath $termp -ArgumentList 'start', '--foreground' -WindowStyle Hidden | Out-Null
Start-Sleep -Seconds 4

Step 'Registering the logon task'
try {
    $user      = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $action    = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument ('-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $HelperPath)
    $trigger   = New-ScheduledTaskTrigger -AtLogOn -User $user
    $trigger.Delay = 'PT20S'
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)
    Register-ScheduledTask -TaskName 'termp presence' -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force `
        -Description 'Start the termp Discord presence daemon hidden at logon' | Out-Null
    Ok 'Task "termp presence" registered - presence comes back by itself after a reboot.'
} catch {
    Warn "Could not register the logon task: $($_.Exception.Message)"
    Warn 'Presence still works now, but you will have to start the daemon manually after a reboot.'
}

# ---------------------------------------------------------------- 6. status ---
Step 'Status'
& $termp status | Out-Host

Write-Host "`nDone. Launch pi in a terminal and check your Discord profile:" -ForegroundColor Cyan
Write-Host '  "Using Pi" + the Pi icon' -ForegroundColor Gray
Write-Host "`nAfter a reboot the task starts the daemon for you (~20s after logon)." -ForegroundColor Gray
Write-Host "Manual start:`n  powershell -NoProfile -WindowStyle Hidden -File `"$HelperPath`"`n" -ForegroundColor Gray
