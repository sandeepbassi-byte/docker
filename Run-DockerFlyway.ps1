param(
    [Parameter(Mandatory=$true, Position = 0)]
    [ValidateSet("migrate", "info", "validate")]
    [string]$Action,

    [Parameter(Position=1)]
    [ValidateSet("CoreDatabase", "AuditTrail")]
    [string]$DatabaseToDeploy = "CoreDatabase",

    [string]$DatabaseName
)

switch ($DatabaseToDeploy) {
    "CoreDatabase" {
        $scriptFolder = "$PSScriptRoot/../CareStack.Backend/CareStack.Database"
        $defaultDbName = "carestack_bluepay"
        $dbPort = 1401 # sql server docker port
        $dbUser = "sa"
        $dbType = "mssql"
    }

    "AuditTrail" {
        $scriptFolder = "$PSScriptRoot/../CareStack.Backend/CareStack.Database.AuditTrail"
        $defaultDbName = "carestack_audit"
        $dbPort =  3306 # mysql docker port
        $dbUser = "root"
        $dbType = "mysql"
    }
}

if (!$DatabaseName) {
    $DatabaseName = $defaultDbName
}

./Run-Flyway.ps1 -Action $Action `
    -DbHost localhost `
    -Port $dbPort `
    -User $dbUser `
    -Password YourNewStrong!Passw0rd `
    -DatabaseName $DatabaseName `
    -ScriptFolder $scriptFolder `
    -DatabaseType $dbType `
    -CreateDatabase
