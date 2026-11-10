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
$buckets = (& scoop bucket list 2>$null) -join "`n"
if ($buckets -notmatch '(?m)^\s*polter-dev\b') {
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

# ---------------------------------------------------------------- 4. daemon ---
Step 'Starting the daemon (hidden)'
& $termp stop 2>$null | Out-Null
Start-Sleep -Milliseconds 500
# NOTE: autostart is deliberately NOT used - `termp start` in detached mode is
# broken on Windows (it fails with "being used by another process").
& $termp autostart disable 2>$null | Out-Null
Start-Process -FilePath $termp -ArgumentList 'start', '--foreground' -WindowStyle Hidden | Out-Null
Start-Sleep -Seconds 3

# ---------------------------------------------------------------- 5. status ---
Step 'Status'
& $termp status | Out-Host

Write-Host "`nDone. Launch pi in a terminal and check your Discord profile:" -ForegroundColor Cyan
Write-Host '  "Using Pi" + the Pi icon' -ForegroundColor Gray
Write-Host "Restart later with:`n  Start-Process (Get-Command termp).Source -ArgumentList 'start','--foreground' -WindowStyle Hidden`n" -ForegroundColor Gray
