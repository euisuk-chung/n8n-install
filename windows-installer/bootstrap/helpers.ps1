# Shared helpers for bootstrap scripts.
# Dot-sourced by first-run-install.ps1 / update-n8n.ps1.

function Write-Step {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message"
}

function Test-NodeBundle {
    param([Parameter(Mandatory=$true)][string]$InstallDir)
    $nodeExe = Join-Path $InstallDir 'node\node.exe'
    $npmCmd  = Join-Path $InstallDir 'node\npm.cmd'
    return (Test-Path $nodeExe) -and (Test-Path $npmCmd)
}

function Get-N8nVersion {
    param([Parameter(Mandatory=$true)][string]$InstallDir)
    $pkg = Join-Path $InstallDir 'n8n-data\node_modules\n8n\package.json'
    if (-not (Test-Path $pkg)) { return $null }
    try {
        $json = Get-Content $pkg -Raw | ConvertFrom-Json
        return $json.version
    } catch {
        return $null
    }
}

function Invoke-Npm {
    # Runs npm with the bundled Node.js on PATH. Streams npm's stdout/stderr
    # to the visible console AND mirrors the same lines to bootstrap.log via
    # Tee-Object. Exit code is exposed through the global $LASTEXITCODE,
    # never as the function's return value — see prior commit for why.
    param(
        [Parameter(Mandatory=$true)][string]$InstallDir,
        [Parameter(Mandatory=$true)][string[]]$Args
    )
    $npm = Join-Path $InstallDir 'node\npm.cmd'
    $nodeDir = Join-Path $InstallDir 'node'
    $logFile = Join-Path $env:USERPROFILE '.n8n\logs\bootstrap.log'
    New-Item -ItemType Directory -Force -Path (Split-Path $logFile) | Out-Null
    $oldPath = $env:PATH
    try {
        $env:PATH = "$nodeDir;$oldPath"
        & $npm @Args 2>&1 | Tee-Object -FilePath $logFile -Append
    } finally {
        $env:PATH = $oldPath
    }
}

function Wait-Or-AutoClose {
    # Used at the end of bootstrap scripts so the user can read the result
    # before the visible console window vanishes. Failure -> wait for Enter.
    # Success -> short countdown then auto-close.
    param(
        [Parameter(Mandatory=$true)][int]$ExitCode
    )
    Write-Host ""
    if ($ExitCode -ne 0) {
        Write-Host "FAILED (exit code $ExitCode). Press Enter to close this window..." -ForegroundColor Yellow
        $null = Read-Host
    } else {
        Write-Host "Done. This window will close in 5 seconds..." -ForegroundColor Green
        Start-Sleep -Seconds 5
    }
}
