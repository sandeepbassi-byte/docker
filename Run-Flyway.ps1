param(
    [Parameter(Mandatory=$true, Position = 0)]
    [ValidateSet("migrate", "info", "validate")]
    [string]$Action,

    [Parameter(Mandatory=$true)][string]$DbHost,
    [Parameter(Mandatory=$true)][int]$Port,
    [string]$User,
    [string]$Password,
    [Parameter(Mandatory=$true)][string]$DatabaseName,
    [Parameter(Mandatory=$true)][string]$ScriptFolder,

    [ValidateSet("mssql", "mysql")]
    [string]$DatabaseType = "mssql",

    [switch]$CreateDatabase,
    [switch]$UseWindowsAuth
)

Add-Type -AssemblyName System.IO.Compression.FileSystem
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Stop'

$flywayVersion = "5.2.1"
$flywayDir = "$PSScriptRoot/flyway-$flywayVersion"
$flywayExe = "$flywayDir/flyway.cmd"
$flywayConfigFile = "$PSScriptRoot/flyway.conf"
$sqlAuthDll = "$PSScriptRoot/flyway-sqljdbc_auth-x64.dll"

function Extract-Item($zipFile, $outputPath) {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outputPath)
}

function Install-Flyway() {
    if (Test-Path $flywayExe) {
        Write-Host "Flyway already installed in $flywayDir"
        return 
    }

    # Recreate the directory since it's not complete
    if (Test-Path $flywayDir) {
        Remove-Item -Recurse -Force $flywayDir
    }
    
    New-Item -Type Directory -Path $flywayDir -Force

    Write-Host "Downloading Flyway $flywayVersion"
    $flywayUrl = "https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/$flywayVersion/flyway-commandline-$flywayVersion-windows-x64.zip"
    $tempZip = New-TemporaryFile
    Invoke-WebRequest -Uri $flywayUrl -OutFile $tempZip

    Write-Host "Flyway zip downloaded"
    Extract-Item $tempZip $flywayDir
    Move-Item "$flywayDir/flyway-$flywayVersion/*" $flywayDir
    Remove-Item $tempZip   

    Write-Host "Flyway extracted to $flywayDir"
}

function Install-WindowsAuthDll() {  
    # required for integrated authentication to be an option
    $dllPath = "$flywayDir/jre/bin/sqljdbc_auth.dll"
    if (Test-Path $dllPath) {
        Write-Host "Flyway Windows Authentication dll already installed"
        return
    }

    Copy-Item $sqlAuthDll $dllPath
    Write-Host "Copied $sqlAuthDll to $dllPath"
}

function Get-CommonConfig {
    return "flyway.locations=filesystem:$ScriptFolder
flyway.outOfOrder=true
flyway.ignoreMissingMigrations=true
"
}

function Get-MssqlConfig {
    $flywayUrl = "flyway.url=jdbc:sqlserver://$($DbHost):$Port;databaseName=$DatabaseName"
    if ($UseWindowsAuth) {
        $flywayUrl = "$flywayUrl;integratedSecurity=true;"
    }

    $text = "$flywayUrl
flyway.user=$User
flyway.password=$Password"

    return $text
}

function Get-MysqlConfig {
    $text = "flyway.url=jdbc:mysql://$($DbHost):$Port/$DatabaseName
flyway.user=$User
flyway.password=$Password"

    return $text
}

function New-FlywayConfigFile {
    $text = switch($DatabaseType) {
        "mssql" { Get-MssqlConfig }
        "mysql" { Get-MysqlConfig }
    }

    $commonConfig = Get-CommonConfig
    $text = $text, $commonConfig

    Set-Content -Path $flywayConfigFile -Value $text
}

function New-MssqlDatabase {
    $sql = "
if not exists (select * from master.dbo.sysdatabases where name = '$DatabaseName')
begin
    create database $DatabaseName
end
"
    $connectionString = ""
    if ($UseWindowsAuth) {
        $connectionString = "Data Source=$DbHost;Trusted_Connection=True;"
    } else {
        $connectionString = "Data Source=$DbHost,$Port;User ID=$User;Password=$Password;"
    }

    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open();

    $sqlCommand = New-Object System.Data.SqlClient.SqlCommand
    $sqlCommand.Connection = $connection
    $sqlCommand.CommandText = $sql

    Write-Host "Creating database $DatabaseName if it doesn't exist"
    $sqlCommand.ExecuteNonQuery()
}

function New-MysqlDatabase {
    try {
        [void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")
    } catch {
        Write-Error "Mysql could not be activated.  Make sure to install the Mysql .net connector (https://dev.mysql.com/downloads/connector/net/)"
    }

    $connection = New-Object MySql.Data.MySqlClient.MySqlConnection
    $connection.ConnectionString = "Server=$DbHost;Port=$Port;Uid=$User;Pwd=$Password;"
    $connection.Open()

    $sql = "CREATE DATABASE IF NOT EXISTS $DatabaseName;"
    $command = New-Object MySql.Data.MySqlClient.MySqlCommand
    $command.Connection = $connection
    $command.CommandText = $sql

    Write-Host "Creating database $DatabaseName if it doesn't exist"
    $command.ExecuteNonQuery()
}

function New-Database {
    switch($DatabaseType) {
        "mssql" { New-MssqlDatabase }
        "mysql" { Get-MysqlConfig }
    }
}

if (!$UseWindowsAuth -and (!$User -or !$Password)) {
    Write-Error "Windows authentication not specified, and no username or password given"
}

if ($UseWindowsAuth -and $DatabaseType -ne "mssql") {
    Write-Error "Windows authentication is only possible with Sql Server (mssql)"
}

if ($CreateDatabase) {
    New-Database
}

Push-Location $PSScriptRoot
Install-Flyway
Install-WindowsAuthDll
New-FlywayConfigFile
Write-Host "Running flyway"
& $flywayExe $Action
Remove-Item $flywayConfigFile
Pop-Location
