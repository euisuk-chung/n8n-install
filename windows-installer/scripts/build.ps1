# Full build pipeline: node bundle -> tray app -> Inno Setup installer.
# Run from any working directory.

[CmdletBinding()]
param(
    [string]$Version = '0.0.0-dev',
    [string]$InnoSetupPath,
    [string]$MsBuildPath,
    [switch]$SkipNodeDownload
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    Write-Host "=== n8n Windows Installer build ==="
    Write-Host "Repo root : $root"
    Write-Host "Version   : $Version"

    # 1. Node.js bundle
    if (-not $SkipNodeDownload) {
        Write-Host "`n[1/4] Preparing Node.js portable bundle"
        & (Join-Path $PSScriptRoot 'download-nodejs.ps1')
        $nodeExe = Join-Path $root 'vendor\node\node.exe'
        if (-not (Test-Path $nodeExe)) {
            throw "download-nodejs.ps1 did not produce $nodeExe"
        }
    } else {
        Write-Host "`n[1/4] Skipping Node.js download (SkipNodeDownload)"
    }

    # 2. MSBuild for tray app
    Write-Host "`n[2/4] Building tray app (Release)"
    if (-not $MsBuildPath) {
        # Try vswhere first — works for any VS edition (Community/Pro/Enterprise/BuildTools, 2019/2022/etc)
        $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        if (Test-Path $vswhere) {
            $found = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild `
                -find 'MSBuild\**\Bin\MSBuild.exe' 2>$null | Select-Object -First 1
            if ($found) { $MsBuildPath = $found }
        }

        # Fallback: probe well-known install paths for all editions
        if (-not $MsBuildPath) {
            $editions = @('BuildTools', 'Community', 'Professional', 'Enterprise')
            $years    = @('2022', '2019')
            $roots    = @("${env:ProgramFiles}", "${env:ProgramFiles(x86)}")
            foreach ($root in $roots) {
                if (-not $root) { continue }
                foreach ($year in $years) {
                    foreach ($ed in $editions) {
                        $p = Join-Path $root "Microsoft Visual Studio\$year\$ed\MSBuild\Current\Bin\MSBuild.exe"
                        if (Test-Path $p) { $MsBuildPath = $p; break }
                    }
                    if ($MsBuildPath) { break }
                }
                if ($MsBuildPath) { break }
            }
        }

        # Last resort: PATH lookup
        if (-not $MsBuildPath) {
            $cmd = Get-Command msbuild -ErrorAction SilentlyContinue
            if ($cmd) { $MsBuildPath = $cmd.Source }
        }
    }
    if (-not $MsBuildPath -or -not (Test-Path $MsBuildPath)) {
        throw @"
MSBuild.exe not found. Install one of:
  - Visual Studio 2022 Community (free): https://visualstudio.microsoft.com/vs/community/
  - Visual Studio Build Tools 2022 (smaller): https://visualstudio.microsoft.com/downloads/?q=build+tools
During the installer, check 'Desktop development with C++' or '.NET desktop build tools' workload.

Or pass -MsBuildPath 'C:\path\to\MSBuild.exe' explicitly.
"@
    }
    Write-Host "MSBuild: $MsBuildPath"

    & $MsBuildPath (Join-Path $root 'tray-app\N8nTray.csproj') `
        /p:Configuration=Release /p:Platform=AnyCPU /v:minimal /nologo
    if ($LASTEXITCODE -ne 0) { throw "MSBuild failed" }

    $trayExe = Join-Path $root 'tray-app\bin\Release\N8nTray.exe'
    if (-not (Test-Path $trayExe)) { throw "Tray EXE not produced at $trayExe" }

    # 3. Inno Setup compiler
    Write-Host "`n[3/4] Running Inno Setup compiler"
    if (-not $InnoSetupPath) {
        $candidates = @(
            "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
            "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
        )
        foreach ($c in $candidates) {
            if ($c -and (Test-Path $c)) { $InnoSetupPath = $c; break }
        }
        if (-not $InnoSetupPath) {
            $cmd = Get-Command ISCC -ErrorAction SilentlyContinue
            if ($cmd) { $InnoSetupPath = $cmd.Source }
        }
    }
    if (-not $InnoSetupPath -or -not (Test-Path $InnoSetupPath)) {
        throw "ISCC.exe not found. Install Inno Setup 6 or pass -InnoSetupPath."
    }
    Write-Host "ISCC: $InnoSetupPath"

    $buildDir = Join-Path $root 'build'
    New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

    & $InnoSetupPath (Join-Path $root 'setup.iss') "/DAppVersion=$Version" "/Qp"
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup compile failed" }

    $installer = Join-Path $buildDir "n8n-installer-$Version.exe"
    if (-not (Test-Path $installer)) {
        # Inno Setup may output with a different filename; pick the newest .exe
        $installer = Get-ChildItem -Path $buildDir -Filter '*.exe' |
                     Sort-Object LastWriteTime -Descending |
                     Select-Object -First 1 -ExpandProperty FullName
    }

    # 4. Verify
    Write-Host "`n[4/4] Verifying installer"
    & (Join-Path $PSScriptRoot 'verify-build.ps1') -InstallerPath $installer
    if (-not (Test-Path $installer)) {
        throw "Installer not found after build: $installer"
    }

    Write-Host "`n=== Build complete ==="
    Write-Host "Installer: $installer"
} finally {
    Pop-Location
}
