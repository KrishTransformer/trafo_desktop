# This script is launched by Install-InvoiceApp.cmd and runs with administrator rights.
$ErrorActionPreference = 'Stop'

$certificatePath = Join-Path $PSScriptRoot 'InvoiceApp-Signing.cer'
$packagePath = Join-Path $PSScriptRoot 'InvoiceApp.msix'

if (-not (Test-Path -LiteralPath $certificatePath)) {
    throw "Signing certificate not found: $certificatePath"
}

if (-not (Test-Path -LiteralPath $packagePath)) {
    throw "Installer package not found: $packagePath"
}

Import-Certificate -FilePath $certificatePath -CertStoreLocation 'Cert:\LocalMachine\Root' | Out-Null
Add-AppxPackage -Path $packagePath

Write-Host ''
Write-Host 'Invoice App was installed successfully.' -ForegroundColor Green
Read-Host 'Press Enter to close'
