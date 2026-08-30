# Builds the signed MSIX and gathers every recipient-facing file in installer\release.
$ErrorActionPreference = 'Stop'

$passwordPath = Join-Path $PSScriptRoot 'private\certificate-password.txt'
if (-not (Test-Path -LiteralPath $passwordPath)) {
    throw "Signing password not found: $passwordPath"
}

$certificatePassword = (Get-Content -LiteralPath $passwordPath -Raw).Trim()
& dart run msix:create --certificate-password $certificatePassword
if ($LASTEXITCODE -ne 0) {
    throw 'MSIX creation failed.'
}

$releasePath = Join-Path $PSScriptRoot 'release'
New-Item -ItemType Directory -Path $releasePath -Force | Out-Null
Copy-Item 'build\windows\x64\runner\Release\trafo_desktop.msix' (Join-Path $releasePath 'InvoiceApp.msix') -Force
Copy-Item (Join-Path $PSScriptRoot 'InvoiceApp-Signing.cer') $releasePath -Force
Copy-Item (Join-Path $PSScriptRoot 'Install-InvoiceApp.ps1') $releasePath -Force
Copy-Item (Join-Path $PSScriptRoot 'Install-InvoiceApp.cmd') $releasePath -Force

Write-Host "Share the contents of: $releasePath" -ForegroundColor Green
