# Updates the installed n8n payload to the latest version.
# Invoked from the tray app via the "Update n8n" menu item.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InstallDir
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'helpers.ps1')

if (-not (Test-NodeBundle -InstallDir $InstallDir)) {
    Write-Error "Node.js 번들을 찾을 수 없습니다."
    exit 2
}

$n8nDataDir = Join-Path $InstallDir 'n8n-data'
if (-not (Test-Path (Join-Path $n8nDataDir 'package.json'))) {
    Write-Error "n8n 이 아직 설치되어 있지 않습니다. 먼저 'n8n 시작' 을 눌러 첫 설치를 진행해 주세요."
    exit 3
}

$before = Get-N8nVersion -InstallDir $InstallDir
Write-Step "현재 버전: $before"
Write-Step "npm update n8n 실행 중…"

$code = Invoke-Npm -InstallDir $InstallDir -Args @(
    'install',
    'n8n@latest',
    '--prefix', $n8nDataDir,
    '--no-audit',
    '--no-fund',
    '--loglevel', 'error'
)

if ($code -ne 0) {
    Write-Error "npm install 실패 (exit code $code)"
    exit $code
}

$after = Get-N8nVersion -InstallDir $InstallDir
Write-Step "업데이트 완료: $before -> $after"
exit 0
