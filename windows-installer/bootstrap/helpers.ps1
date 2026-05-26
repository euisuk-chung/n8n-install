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
    # Runs npm via node.exe directly instead of npm.cmd. The batch wrapper
    # routes stdout through cmd.exe, which buffers in large blocks and makes
    # the install look frozen for minutes at a time. node.exe writes to
    # stdout unbuffered, so piping through ForEach-Object delivers each line
    # as it's emitted.
    #
    # Each line is mirrored to bootstrap.log with AutoFlush so external
    # tailers and post-mortem debugging match the console exactly. Tee-Object
    # was previously used here but inherited a 4KB StreamWriter buffer.
    #
    # Exit code is exposed through the global $LASTEXITCODE, never via the
    # function's return value — returning it would mix with pipeline output
    # and break the caller's `if ($code -ne 0)` check.
    param(
        [Parameter(Mandatory=$true)][string]$InstallDir,
        [Parameter(Mandatory=$true)][string[]]$Args
    )
    $nodeDir = Join-Path $InstallDir 'node'
    $nodeExe = Join-Path $nodeDir 'node.exe'
    $npmCli  = Join-Path $nodeDir 'node_modules\npm\bin\npm-cli.js'

    if (-not (Test-Path $nodeExe)) { throw "node.exe not found at $nodeExe" }
    if (-not (Test-Path $npmCli))  { throw "npm-cli.js not found at $npmCli" }

    $logFile = Join-Path $env:USERPROFILE '.n8n\logs\bootstrap.log'
    New-Item -ItemType Directory -Force -Path (Split-Path $logFile) | Out-Null

    $writer = [System.IO.StreamWriter]::new($logFile, $true, [System.Text.UTF8Encoding]::new($false))
    $writer.AutoFlush = $true

    # Force npm to emit progress without ANSI control codes that PowerShell
    # 5.1 in the conhost-style console window can't render.
    $env:FORCE_COLOR = '0'
    $env:NPM_CONFIG_COLOR = 'false'

    # n8n's postinstall script invokes `npm ls @scarf/scarf --json --long`
    # for telemetry detection. With npm 10+ that command exits 1 when the
    # tree reports any extraneous package, which propagates up and makes
    # the entire install look failed even though every package downloaded
    # correctly. Disabling both Scarf analytics and n8n diagnostics short-
    # circuits the offending check, and respects the user's "no telemetry"
    # default for a local install.
    $env:SCARF_ANALYTICS = 'false'
    $env:DO_NOT_TRACK = '1'
    $env:N8N_DIAGNOSTICS_ENABLED = 'false'

    # n8n has ~2200 transitive dependencies. Resolving the full graph in
    # one npm install run easily exceeds Node's default old-space heap
    # (~1.5GB) and the install crashes with
    #   FATAL ERROR: MarkCompactCollector: young object promotion failed
    #   Allocation failed - JavaScript heap out of memory
    # exiting with code 134. 4GB headroom resolves it on every machine
    # we have observed.
    $env:NODE_OPTIONS = '--max-old-space-size=4096'

    # npm emits informational text (verbose, http, warn) to stderr at every
    # log level. With $ErrorActionPreference = 'Stop' inherited from the
    # caller, merging via 2>&1 turns each stderr line into a terminating
    # ErrorRecord that fires the caller's trap on the very first message.
    # Drop to 'Continue' for the duration of the npm run so those lines are
    # treated as plain data — actual npm failures are still surfaced via
    # $LASTEXITCODE.
    $oldErrPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    $oldPath = $env:PATH
    try {
        $env:PATH = "$nodeDir;$oldPath"
        & $nodeExe $npmCli @Args 2>&1 | ForEach-Object {
            $line = $_.ToString()
            Write-Host $line
            $writer.WriteLine($line)
        }
    } finally {
        $env:PATH = $oldPath
        $ErrorActionPreference = $oldErrPref
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
