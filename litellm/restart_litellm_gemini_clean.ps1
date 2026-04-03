param(
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$StopScript = Join-Path $ScriptDir 'stop_litellm.ps1'
$StartScript = Join-Path $ScriptDir 'start_litellm.ps1'
$StatusScript = Join-Path $ScriptDir 'status_litellm.ps1'
$ConfigPath = Join-Path $ScriptDir 'config.gemini.yaml'

Write-Host '[1/3] Stopping existing LiteLLM instances...'
& $StopScript -NoPause
if ($LASTEXITCODE -ne 0) {
    if (-not $NoPause) { Read-Host 'Press Enter to close' }
    exit $LASTEXITCODE
}

Write-Host '[2/3] Starting Gemini route with clean state...'
& $StartScript -NoPause -ForceRestart -ConfigPath $ConfigPath
if ($LASTEXITCODE -ne 0) {
    if (-not $NoPause) { Read-Host 'Press Enter to close' }
    exit $LASTEXITCODE
}

Write-Host '[3/3] Printing final LiteLLM status...'
& $StatusScript -NoPause
if (-not $NoPause) { Read-Host 'Press Enter to close' }
exit $LASTEXITCODE