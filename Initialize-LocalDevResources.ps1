$ErrorActionPreference = "Stop"

$msbuildPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Professional\MSBuild\15.0\Bin\msbuild.exe"
$toolsProjectDirectory = Resolve-Path "..\CareStack.Backend\Tools"
$setupProjectPath = "$toolsProjectDirectory\SetupLocalEnvironment\SetupLocalEnvironment.csproj"
$setupProjectBinPath = "$toolsProjectDirectory\SetupLocalEnvironment\bin\Debug"
$setupProjectExePath = "$setupProjectBinPath\SetupLocalEnvironment.exe"
$permissionProjectPath = "$toolsProjectDirectory\DefaultPermissionsMapper\DefaultPermissionsMapper.csproj"
$permissionProjectExePath = "$toolsProjectDirectory\DefaultPermissionsMapper\bin\Debug\DefaultPermissionsMapper.exe"

function Validate-Paths {
    if (!(Test-Path $msbuildPath)) {
        Write-Error "Could not find msbuild execute (looked in $msbuildPath)"
    }

    if (!(Test-Path $setupProjectPath)) {
        Write-Error "Could not find the SetupLocalEnvironment project (looked for $setupProjectPath)"
    }
	
	if (!(Test-Path $permissionProjectPath)) {
        Write-Error "Could not find the DefaultPermissionsMapper project (looked for $permissionProjectPath)"
    }
}

function Run-Command($command)
{
  # Wrap ampersand operator to echo commands to output and automatically check exit codes
  Write-Host $command $args
  &$command @args
  if ( $LastExitCode -ne 0 ) { throw "'$command' failed with exit code $LastExitCode" }
}

function Build-SetupProject {
    Run-Command $msbuildPath $setupProjectPath /m /verbosity:minimal /p:Configuration=Debug
    if (!(Test-Path $setupProjectExePath)) {
        Write-Error "Did not find the built executable $setupProjectExePath"
    }
}

function Build-PermissionProject {
    Run-Command $msbuildPath $permissionProjectPath /m /verbosity:minimal /p:Configuration=Debug
    if (!(Test-Path $permissionProjectExePath)) {
        Write-Error "Did not find the built executable $permissionProjectExePath"
    }
}


Validate-Paths
Build-SetupProject
Build-PermissionProject

Push-Location $setupProjectBinPath
Run-Command $setupProjectExePath
Pop-Location
Run-Command $permissionProjectExePath