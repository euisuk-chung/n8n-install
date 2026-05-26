# Downloads the official Node.js portable LTS zip and extracts it to vendor/node/.
# Run once before building. Re-runnable: skips download if the zip is already present.

[CmdletBinding()]
param(
    [string]$NodeVersion = 'v22.11.0',  # bump as new LTS lands
    [string]$Arch = 'x64'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$vendorDir = Join-Path $root 'vendor'
$targetDir = Join-Path $vendorDir 'node'
$zipName   = "node-$NodeVersion-win-$Arch.zip"
$zipPath   = Join-Path $vendorDir $zipName
$extractedFolderName = "node-$NodeVersion-win-$Arch"
$extractedPath = Join-Path $vendorDir $extractedFolderName

New-Item -ItemType Directory -Force -Path $vendorDir | Out-Null

if (Test-Path $targetDir) {
    Write-Host "vendor/node already populated, skipping download."
    exit 0
}

if (-not (Test-Path $zipPath)) {
    $url = "https://nodejs.org/dist/$NodeVersion/$zipName"
    Write-Host "Downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
}

Write-Host "Extracting $zipName"
Expand-Archive -Path $zipPath -DestinationPath $vendorDir -Force

if (Test-Path $extractedPath) {
    Rename-Item -Path $extractedPath -NewName 'node'
}

if (-not (Test-Path (Join-Path $targetDir 'node.exe'))) {
    Write-Error "node.exe not found after extraction."
    exit 1
}

Write-Host "Node.js bundle ready: $targetDir"
