param(
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$Port = 4000
$Distro = 'Ubuntu-24.04'

Write-Host "[1/2] Stopping LiteLLM process in WSL..."

# Try graceful stop by process name.
wsl -d $Distro -u root -- bash -lc "pkill -f litellm || true" | Out-Null

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
