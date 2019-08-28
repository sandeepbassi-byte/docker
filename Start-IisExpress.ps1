param(
    [switch]$RunSignalRHub,
    [switch]$RunDentalWeb,
    [switch]$RunPatientPortal,
    [string]$iisExpressPath='%programfiles(x86)%\IIS Express'
)

$iisExecutable = "`"$iisExpressPath\iisexpress.exe`"" # Needs to be quoted due to powershell quirks
$configOutputPath = "$PSScriptRoot\applicationhost.config"

function New-SiteTemplate($name, $path, $port, $id) {
    return "
    <site name=`"$name`" id=`"$id`" serverAutoStart=`"true`">
        <application path=`"/`">
            <virtualDirectory path=`"/`" physicalPath=`"$path`"/>
        </application>
        <bindings>
            <binding protocol=`"http`" bindingInformation=`":$($port):localhost`"/>
        </bindings>
    </site>
    "
}

function Write-HostConfig($xmlToInsert) {
    $configTemplatePath = "$PSScriptRoot\applicationhost.config.template"

    (Get-Content $configTemplatePath).replace("{{SiteDefinitions}}", $xmlToInsert) |
        Set-Content $configOutputPath
}

function Start-Iis {
    $iisParams = "/config:$configOutputPath /apppool:IISExpressAppPool"
    $command = "$iisExecutable $iisParams"
    cmd /c "$command"
}

$siteXml = ""
$siteCount = 0

if ($RunSignalRHub) {
    $siteCount++
    $path = (Resolve-Path "$PSScriptRoot\..\CareStack.Backend\CareStack.Hub").Path
    $siteXml += New-SiteTemplate "CareStack.Hub" $path 46552 $siteCount
}

if ($RunDentalWeb) {
    $siteCount++
    $path = (Resolve-Path "$PSScriptRoot\..\CareStack.Backend\CareStack.Web").Path
    $siteXml += New-SiteTemplate "CareStack.Web" $path 46551 $siteCount
}

if ($RunPatientPortal) {
    $siteCount++
    $path = (Resolve-Path "$PSScriptRoot\..\CareStack.Backend\CareStack.PatientPortal").Path
    $siteXml += New-SiteTemplate "CareStack.PatientPortal" $path 50366 $siteCount
}

if ($siteCount -eq 0) {
    Write-Error "At least one site must be specified (e.g. -RunSignalRHub -RunDentalWeb)"
    exit
}

Write-HostConfig $siteXml
Start-Iis


