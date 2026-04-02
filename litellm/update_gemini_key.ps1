param(
    [switch]$NoPause,
    [string]$GeminiApiKey
)

$ErrorActionPreference = 'Stop'
$Distro = 'Ubuntu-24.04'

if (-not $GeminiApiKey) {
    $secure = Read-Host "Enter new GEMINI_API_KEY" -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $GeminiApiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

if ([string]::IsNullOrWhiteSpace($GeminiApiKey)) {
    Write-Host "Empty key. Aborted." -ForegroundColor Red
    if (-not $NoPause) { Read-Host "Press Enter to close" }
    exit 1
}

# Normalize input: remove CR/LF and surrounding spaces.
$GeminiApiKey = ($GeminiApiKey -replace "`r", "" -replace "`n", "").Trim()

# Basic validation for Google AI Studio API key.
if ($GeminiApiKey -notmatch '^AIza[0-9A-Za-z_-]{35}$') {
    Write-Host "Invalid Gemini key format. Expected something like: AIzaSy..." -ForegroundColor Red
    Write-Host "Tip: copy key from Google AI Studio API Keys page and paste it directly."
    if (-not $NoPause) { Read-Host "Press Enter to close" }
    exit 1
}

# Validate key against official Gemini endpoint before persisting.
try {
    $null = Invoke-RestMethod -Uri ("https://generativelanguage.googleapis.com/v1beta/models?key=" + $GeminiApiKey) -Method Get -TimeoutSec 20
} catch {
    Write-Host "Gemini key validation failed. Key not saved." -ForegroundColor Red
    $resp = $_.Exception.Response
    if ($resp) {
        $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
        $body = $sr.ReadToEnd()
        $sr.Close()
        Write-Host $body
    } else {
        Write-Host $_.Exception.Message
    }
    if (-not $NoPause) { Read-Host "Press Enter to close" }
    exit 1
}

# Persist key to a dedicated env file loaded by start_litellm.ps1
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($GeminiApiKey))

$cmd = @"
KEY=`$(printf '%s' '$b64' | base64 -d)
printf 'export GEMINI_API_KEY=%s\n' "`$KEY" > /root/.litellm_env
chmod 600 /root/.litellm_env
"@

& wsl -d $Distro -u root -- bash -lc $cmd | Out-Null

Write-Host "Gemini key updated in /root/.litellm_env" -ForegroundColor Green
Write-Host "Next step: restart LiteLLM using start_litellm_gemini.bat"
if (-not $NoPause) { Read-Host "Press Enter to close" }
