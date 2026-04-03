param(
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$Port = 4000
$Distro = 'Ubuntu-24.04'

function Get-LiteLLMProcesses {
    try {
        $out = & wsl -d $Distro -u root -- bash -lc "pgrep -af litellm" 2>$null
        if ([string]::IsNullOrWhiteSpace($out)) { return @() }
        return $out -split "`n"
    } catch {
        return @()
    }
}

function Get-PortListenerInfo {
    try {
        $out = & wsl -d $Distro -u root -- bash -lc "ss -tlnp | grep :$Port" 2>$null
        if ([string]::IsNullOrWhiteSpace($out)) { return $null }
        return $out.Trim()
    } catch {
        return $null
    }
}

function Wait-LiteLLMStopped {
    param(
        [int]$TimeoutSeconds = 10
    )

    for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
        if ((Get-LiteLLMProcesses).Count -eq 0 -and -not (Get-PortListenerInfo)) {
            return $true
        }
        Start-Sleep -Seconds 1
    }

    return $false
}

Write-Host "[1/2] Stopping LiteLLM process in WSL..."

# Try graceful stop by process name.
wsl -d $Distro -u root -- bash -lc "pkill -f litellm || true" | Out-Null

if (-not (Wait-LiteLLMStopped)) {
    Write-Host "LiteLLM processes are still present after stop attempt." -ForegroundColor Red
    $processes = Get-LiteLLMProcesses
    if ($processes.Count -gt 0) {
        Write-Host "WSL litellm processes:"
        $processes | ForEach-Object { Write-Host $_ }
    }
    $listener = Get-PortListenerInfo
    if ($listener) {
        Write-Host "WSL port listener:"
        Write-Host $listener
    }
    if (-not $NoPause) { Read-Host "Press Enter to close" }
    exit 1
}

Write-Host "[2/2] Verifying port status..."
$portListening = $false
try {
    $null = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
    $portListening = $true
} catch {
    $portListening = $false
}

if ($portListening) {
    Write-Host "Port $Port is still listening. A non-LiteLLM process may be using it." -ForegroundColor Yellow
    Get-NetTCPConnection -LocalPort $Port -State Listen | Select-Object LocalAddress, LocalPort, OwningProcess | Format-Table -AutoSize
    if (-not $NoPause) { Read-Host "Press Enter to close" }
    exit 1
}

Write-Host "LiteLLM stopped successfully (port $Port is free)." -ForegroundColor Green
if (-not $NoPause) { Read-Host "Press Enter to close" }
exit 0
