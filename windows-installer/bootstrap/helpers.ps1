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
    param(
        [Parameter(Mandatory=$true)][string]$InstallDir,
        [Parameter(Mandatory=$true)][string[]]$Args
    )
    $npm = Join-Path $InstallDir 'node\npm.cmd'
    $nodeDir = Join-Path $InstallDir 'node'
    $oldPath = $env:PATH
    try {
        $env:PATH = "$nodeDir;$oldPath"
        & $npm @Args
        return $LASTEXITCODE
    } finally {
        $env:PATH = $oldPath
    }
}
