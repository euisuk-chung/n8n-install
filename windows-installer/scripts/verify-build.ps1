# Sanity check for a built installer EXE.
# - Confirms file exists and size is in the expected range
# - Emits SHA256 for release notes
# - Probes the signature (warns if unsigned)

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InstallerPath,
    [int]$MinSizeMB = 25,
    [int]$MaxSizeMB = 80
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $InstallerPath)) {
    Write-Error "Installer not found: $InstallerPath"
    exit 1
}

$info = Get-Item $InstallerPath
$sizeMB = [math]::Round($info.Length / 1MB, 2)
Write-Host "File   : $($info.FullName)"
Write-Host "Size   : $sizeMB MB"

if ($sizeMB -lt $MinSizeMB) {
    Write-Error "Installer is suspiciously small ($sizeMB MB < $MinSizeMB MB). Node bundle may be missing."
    exit 2
}
if ($sizeMB -gt $MaxSizeMB) {
    Write-Warning "Installer is larger than expected ($sizeMB MB > $MaxSizeMB MB). Did n8n get bundled?"
}

$hash = (Get-FileHash -Path $InstallerPath -Algorithm SHA256).Hash
Write-Host "SHA256 : $hash"

try {
    $sig = Get-AuthenticodeSignature -FilePath $InstallerPath
    if ($sig.Status -eq 'Valid') {
        Write-Host "Sign   : valid ($($sig.SignerCertificate.Subject))"
    } else {
        Write-Warning "Sign   : not signed (SmartScreen will warn end users)"
    }
} catch {
    Write-Warning "Could not inspect signature: $_"
}

Write-Host "OK"
$global:LASTEXITCODE = 0
exit 0
