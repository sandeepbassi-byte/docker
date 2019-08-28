param(
    [ValidateSet("CoreDatabase", "AuditTrail")]
    [Parameter(Position=0, Mandatory=$true)]
    [string]$DatabaseType,

    [Parameter(Mandatory=$true, Position=1)]
    [string]$Purpose
)

$ErrorActionPreference = 'Stop'

$scriptFolder = switch ($DatabaseType) {
    "CoreDatabase" { Resolve-Path (Join-Path "$PSScriptRoot" (Join-Path ".." (Join-Path "CareStack.Backend" "CareStack.Database")))}
    "AuditTrail" { Resolve-path (Join-Path "$PSScriptRoot" (Join-Path ".." (Join-Path "CareStack.Backend" "CareStack.Database.AuditTrail")))}
}

$scriptFolder = Join-Path $scriptFolder "Migrations"

$dateString = (Get-Date).ToUniversalTime().ToString("yyyyMMddhhmm")
$normalizePurpose = $Purpose -replace "[ |@|!|.]","-"
$newScriptName = "V$($dateString)__$normalizePurpose.sql"
$newScriptFullPath = Join-Path $scriptFolder $newScriptName

if (!(Test-Path $scriptFolder)) {
    New-Item -ItemType Directory -Path $scriptFolder -Force
}

Set-Content -Path $newScriptFullPath -Value "--- $Purpose"

Write-Host "New script created: $newScriptFullPath"