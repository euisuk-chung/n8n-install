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
    # Runs npm with the bundled Node.js on PATH. Streams every npm line to
    # the visible console AND appends it to bootstrap.log with AutoFlush so
    # external tailers see each line immediately. Tee-Object was previously
    # used here but its default 4KB stream buffer made the log appear stalled
    # for minutes at a time during long installs.
    #
    # Exit code is exposed through the global $LASTEXITCODE, never as the
    # function's return value — returning it would mix with pipeline output
    # and break the caller's `if ($code -ne 0)` check.
    param(
        [Parameter(Mandatory=$true)][string]$InstallDir,
        [Parameter(Mandatory=$true)][string[]]$Args
    )
    $npm = Join-Path $InstallDir 'node\npm.cmd'
    $nodeDir = Join-Path $InstallDir 'node'
    $logFile = Join-Path $env:USERPROFILE '.n8n\logs\bootstrap.log'
    New-Item -ItemType Directory -Force -Path (Split-Path $logFile) | Out-Null

    $writer = [System.IO.StreamWriter]::new($logFile, $true, [System.Text.UTF8Encoding]::new($false))
    $writer.AutoFlush = $true

    $oldPath = $env:PATH
    try {
        $env:PATH = "$nodeDir;$oldPath"
        & $npm @Args 2>&1 | ForEach-Object {
            $line = $_.ToString()
            Write-Host $line
            $writer.WriteLine($line)
        }
    } finally {
        $env:PATH = $oldPath
        try { $writer.Dispose() } catch {}
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
