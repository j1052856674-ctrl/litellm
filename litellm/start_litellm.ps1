param(
    [switch]$NoPause,
    [switch]$ForceRestart,
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'

$Port = 4000
$AuthToken = 'sk-litellm-static-key'
$Distro = 'Ubuntu-24.04'

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $PSScriptRoot 'config.yaml'
}

if (-not (Test-Path $ConfigPath)) {
    Write-Host "Config file not found: $ConfigPath" -ForegroundColor Red
    if (-not $NoPause) { Read-Host "Press Enter to close" }
    exit 1
}

$LinuxConfigPath = $ConfigPath -replace '^([A-Za-z]):\\', '/mnt/$1/'
$LinuxConfigPath = $LinuxConfigPath -replace '\\', '/'
$LinuxConfigPath = $LinuxConfigPath.ToLower()

$LinuxCmd = "if [ -f /root/.litellm_env ]; then source /root/.litellm_env; fi; source /home/administrator/litellm/.venv/bin/activate; setsid -f litellm --config $LinuxConfigPath --port $Port >/tmp/litellm.log 2>&1 < /dev/null"

function Get-RunningLiteLLMCommandLine {
    try {
        $out = & wsl -d $Distro -u root -- bash -lc "pgrep -af litellm" 2>$null
        if ([string]::IsNullOrWhiteSpace($out)) { return $null }
        return ($out -split "`n" | Select-Object -First 1)
    } catch {
        return $null
    }
}

function Stop-LiteLLMQuietly {
    & wsl -d $Distro -u root -- bash -lc "pkill -f litellm || true" | Out-Null
}

function Test-LiteLLM {
    try {
        $null = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/models" -Headers @{ Authorization = "Bearer $AuthToken" } -TimeoutSec 5
        return $true
    } catch {
        return $false
    }
}

Write-Host "[1/3] Checking LiteLLM status..."
if (Test-LiteLLM) {
    $runningCmd = Get-RunningLiteLLMCommandLine
    if ($runningCmd -and $runningCmd.ToLower().Contains($LinuxConfigPath.ToLower())) {
        Write-Host "LiteLLM is already running with requested config at http://127.0.0.1:$Port" -ForegroundColor Green
        if (-not $NoPause) { Read-Host "Press Enter to close" }
        exit 0
    }

    if ($ForceRestart) {
        Write-Host "Detected another LiteLLM config. Restarting to requested config..." -ForegroundColor Yellow
        Stop-LiteLLMQuietly
    } else {
        Write-Host "LiteLLM is already running but config differs." -ForegroundColor Yellow
        Write-Host "Tip: pass -ForceRestart or stop first, then start again."
        if (-not $NoPause) { Read-Host "Press Enter to close" }
        exit 1
    }
}

try {
    $portInUse = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
} catch {
    $portInUse = $null
}

if ($portInUse) {
    if ($ForceRestart) {
        Write-Host "Port $Port is occupied. Trying to stop existing LiteLLM..." -ForegroundColor Yellow
        Stop-LiteLLMQuietly
        Start-Sleep -Seconds 1
        try {
            $portInUse = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
        } catch {
            $portInUse = $null
        }
    }
}

if ($portInUse) {
    Write-Host "Port $Port is already in use by another process." -ForegroundColor Red
    $portInUse | Select-Object LocalAddress, LocalPort, OwningProcess | Format-Table -AutoSize
    if (-not $NoPause) { Read-Host "Press Enter to close" }
    exit 1
}

Write-Host "[2/3] Starting LiteLLM in WSL background..."
& wsl -d $Distro -u root -- bash -lc $LinuxCmd | Out-Null

Write-Host "[3/3] Waiting for health check..."
$started = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 1
    if (Test-LiteLLM) {
        $started = $true
        break
    }
}

if ($started) {
    Write-Host "Started successfully: http://127.0.0.1:$Port" -ForegroundColor Green
    Write-Host "Health command: Invoke-RestMethod -Uri 'http://127.0.0.1:$Port/models' -Headers @{ Authorization = 'Bearer $AuthToken' }"
    if (-not $NoPause) { Read-Host "Press Enter to close" }
    exit 0
}

Write-Host "Start failed: service not reachable within timeout." -ForegroundColor Red
Write-Host "Manual debug command:"
Write-Host "wsl -d Ubuntu-24.04 -u root -- bash -lc 'source /root/.litellm_env; source /home/administrator/litellm/.venv/bin/activate; litellm --config $LinuxConfigPath --port 4000'"
Write-Host "Recent log: wsl -d Ubuntu-24.04 -u root -- bash -lc 'tail -n 80 /tmp/litellm.log'"
if (-not $NoPause) { Read-Host "Press Enter to close" }
exit 1
