$storageEmulatorExe = "C:\Program Files (x86)\Microsoft SDKs\Azure\Storage Emulator\AzureStorageEmulator.exe"
$cosmosEmulatorExe = "C:\Program Files\Azure Cosmos DB Emulator\CosmosDB.Emulator.exe"

$ErrorActionPreference = 'Stop'

function IsStorageEmulatorActive {
    $statusOutput = & $storageEmulatorExe status
    return $statusOutput.contains("IsRunning: True")
}

function Start-AzureStorageEmulator {
    if (!(Test-Path $storageEmulatorExe)) {
        Write-Error "Azure storage emulator is not installed.  Please install it from https://docs.microsoft.com/en-us/azure/storage/common/storage-use-emulator#start-and-initialize-the-storage-emulator"
    }

    if (IsStorageEmulatorActive) {
        Write-Host "Azure storage emulator is already running"
        return
    }

    & $storageEmulatorExe init
    & $storageEmulatorExe start

    $attemptCount = 0
    $storageEmulatorActive = $false
    do {
        Write-Host "Waiting for Storage Emulator to become active"
        if (IsStorageEmulatorActive) {
            $storageEmulatorActive = $true
        } else {
            $attemptCount = 0
            Start-Sleep -s 1
        }
    } until ($storageEmulatorActive -or $attemptCount -gt 20)

    if ($storageEmulatorActive -eq $false) {
        Write-Error "Azure storage emulator did not start"
    }
}

function IsCosmosDbActive {
    $result = $false
    try {
        Invoke-WebRequest 'https://localhost:8081/_explorer/index.html' -UseBasicParsing | Out-Null
        $result = $true
    }
    catch {
        $result = $false
    }

    return $result
}

function Start-AzureCosmosDbEmulator {
    if (!(Test-Path $cosmosEmulatorExe)) {
        Write-Error "Azure CosmosDB emulator is not installed.  Please install it from https://docs.microsoft.com/en-us/azure/cosmos-db/local-emulator"
    }

    if (IsCosmosDbActive) {
        Write-Host "CosmosDB emulator is already running"
        return
    }

    & $cosmosEmulatorExe /NoFirewall

    $attemptCount = 0
    $emulatorIsRunning = $false
    do {
        Write-Host "Waiting for Cosmos DB emulator to become active"

        if (IsCosmosDbActive) {
            $emulatorIsRunning = $true
        } else {
            $attemptCount++
            Start-Sleep -s 1
        }
    } until ($emulatorIsRunning -or $attemptCount -gt 20)

    if ($emulatorIsRunning) {
        Write-Host "CosmosDB emulator is now active"
    } else {
        Write-Error "CosmosDB never became accessible"
    }
}

function Start-DockerServices {
    & 'docker-compose' up -d 
    [Console]::ResetColor() # for some reason docker errors cause console colors to be tweaked

    if ($lastExitCode -gt 0) {
        Write-Error "Docker services failed to start"
    }
}

Start-AzureStorageEmulator
Start-AzureCosmosDbEmulator
Start-DockerServices

Write-Host "Local development resources are now up and running"