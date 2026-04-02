param(
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$Port = 4000
$AuthToken = 'sk-litellm-static-key'
$Distro = 'Ubuntu-24.04'

Write-Host "[Status] LiteLLM quick check"

$apiOk = $false
try {
    $resp = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/models" -Headers @{ Authorization = "Bearer $AuthToken" } -TimeoutSec 5
    $apiOk = $true
} catch {
    $apiOk = $false
}

$procOut = & wsl -d $Distro -u root -- bash -lc "pgrep -af litellm" 2>$null
$procOk = -not [string]::IsNullOrWhiteSpace($procOut)

$listenOut = & wsl -d $Distro -u root -- bash -lc "ss -tlnp | grep :$Port" 2>$null
$listenOk = -not [string]::IsNullOrWhiteSpace($listenOut)

if ($apiOk) {
    Write-Host "API health: OK (/models reachable)" -ForegroundColor Green
    $ids = @()
    foreach ($m in $resp.data) { $ids += $m.id }
    Write-Host ("Models: " + ($ids -join ', '))
} else {
    Write-Host "API health: FAIL (/models not reachable)" -ForegroundColor Red
}

if ($procOk) {
    Write-Host "Process: RUNNING" -ForegroundColor Green
    Write-Host $procOut
} else {
    Write-Host "Process: NOT FOUND" -ForegroundColor Red
}

if ($listenOk) {
    Write-Host "Port check: LISTENING on $Port" -ForegroundColor Green
    Write-Host $listenOut
} else {
    Write-Host "Port check: NOT LISTENING on $Port" -ForegroundColor Yellow
}

if (-not $NoPause) { Read-Host "Press Enter to close" }
