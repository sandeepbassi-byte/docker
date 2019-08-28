param(
    [Parameter(Mandatory=$true, Position = 0)]
    [ValidateSet("CoreDatabase", "AuditTrail")]
    [string]$DatabaseToDeploy,

    [string]$BackupFileName,
    [string]$DatabaseName,
    [string]$DbPassword="YourNewStrong!Passw0rd"
)

$ErrorActionPreference = 'Stop'

function Validate-ContainerIsRunning($containerName) {
    $count = docker ps -f "name=$containerName" | ConvertFrom-csv | Measure-Object | Select-Object -ExpandProperty Count
    if ($count -lt 1) {
        Write-Error "The docker container '$containerName' is not running.  Please run ./Start-LocalResources.ps1 to load it"
    }
}

function Restore-CoreDatabase() {
    Validate-ContainerIsRunning("carestack_mssql")

    if (!$DatabaseName) {
        $DatabaseName = "carestack_bluepay"
    }

    if (!$BackupFileName) {
        $BackupFileName = "dev_db.bak"
    }

    $dropIfExistsSql = "
    if exists (select * from master.dbo.sysdatabases where [name] = '$DatabaseName')
    begin
        alter database $DatabaseName set single_user with rollback after 10;
        drop database $DatabaseName
    end
    "

    $restoreSql = "
    RESTORE DATABASE $DatabaseName 
    FROM DISK = '/var/opt/mssql/$BackupFileName' 
    WITH MOVE 'PH_Production_Copy_may_Data' TO '/var/opt/mssql/data/$DatabaseName.mdf', 
        MOVE 'PH_Production_Copy_may_Log' TO '/var/opt/mssql/data/$DatabaseName.ldf'
    "

    Write-Host "Deleting existing database $DatabaseName if it exists"
    docker exec -it carestack_mssql /opt/mssql-tools/bin/sqlcmd `
        -S localhost -U SA -P "$DbPassword" `
        -Q $dropIfExistsSql

    # If a previous restore failed or had errors than the mdf and ldf files might still be hanging around, 
    # and thus will block further attempts to restore this build
    if (Test-Path "$PSScriptRoot/data/$DatabaseName.mdf") {
        Remove-Item -Force "$PSScriptRoot/data/$DatabaseName.mdf"
    }

    if (Test-Path "$PSScriptRoot/data/$DatabaseName.ldf") {
        Remove-Item -Force "$PSScriptRoot/data/$DatabaseName.ldf"
    }

    Write-Host "Restoring database"
    docker exec -it carestack_mssql /opt/mssql-tools/bin/sqlcmd `
        -S localhost -U SA -P "$DbPassword" `
        -Q $restoreSql

    Write-Host "Running latest database migrations"
    ./Run-DockerFlyway migrate CoreDatabase
}

function Restore-AuditTrailDatabase {
    Validate-ContainerIsRunning("carestack_mysql")

    if (!$DatabaseName) {
        $DatabaseName = 'carestack_audit'
    }

    $dropIfExistsSql = "drop database if exists $DatabaseName"
    $createSql = "create database $DatabaseName"
    $setGroupByMode = "SET GLOBAL sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));"

    Write-Host "Deleting existing database $DatabaseName"
    docker exec -it -e MYSQL_PWD=$DbPassword carestack_mysql mysql -uroot -e "$dropIfExistsSql"

    Write-Host "Creating new database $DatabaseName"
    docker exec -it -e MYSQL_PWD=$DbPassword carestack_mysql mysql -uroot -e "$createSql"

    # The generated flyway scripts require the db to not be in ONLY_FULL_GROUP_BY mode
    Write-Host "Making sure database is not in ONLY_FULL_GROUP_BY mode"
    docker exec -it -e MYSQL_PWD=$DbPassword carestack_mysql mysql -uroot -e "$setGroupByMode"

    Write-Host "Running latest database migrations"
    ./Run-DockerFlyway migrate AuditTrail
}

switch ($DatabaseToDeploy) {
    "CoreDatabase" { Restore-CoreDatabase }
    "AuditTrail" { Restore-AuditTrailDatabase }
    default { Write-Error "No known way to handle database '$DatabaseToDeploy'" }
}

