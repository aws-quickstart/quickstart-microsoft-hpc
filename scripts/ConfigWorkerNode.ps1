[CmdletBinding()]
param(

    [string]
    $QSS3BucketName,

    [string]
    $CertS3Bucket,

    [string]
    $CertS3Key,

    [string]
    $HeadNodeNetBIOSName,

    [string]
    $DomainDNSName,

    [string]
    $ADUserSecrets
)

Start-Transcript -Path c:\cfn\log\ConfigWorkerNode.ps1.txt -Append

function ConvertTo-HexIP {
<#
.Synopsis
Converts a dotted decimal IP address into a hexadecimal string.
.Description
ConvertTo-HexIP takes a dotted decimal IP and returns a single hexadecimal string value.
.Parameter IPAddress
An IP Address to convert.
#>

[CmdLetBinding()]
param(
[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
[Net.IPAddress]$IPAddress
)

process {
"$($IPAddress.GetAddressBytes() | ForEach-Object { '{0:x2}' -f $_ })" -Replace 's'
}
}

cd WSMan:\localhost\Client
set-item .\allowunencrypted $true

$instanceId = (Invoke-RestMethod -Method Get -Uri http://169.254.169.254/latest/meta-data/instance-id)
$hostIP = (Invoke-RestMethod -Method Get -Uri http://169.254.169.254/latest/meta-data/local-ipv4)
$hostName =  ConvertTo-HexIP($hostIP)
$hostName = "ip-" + $hostName -replace('\s','')
$tags = Get-EC2Tag | Where-Object {$_.ResourceId -eq $instanceId -and $_.Key -eq "MasterServerName"}
$masterName = $tags.Value
$retryCount = 4
$retryDelay = 60
$selfTestPassed = 1

######## Self Test 1 - Ping Headnode and HPC APP Service #########

$test1Passed = $false
$test1RetryCount = 0

while($test1Passed -eq $false -and $test1RetryCount -lt $retryCount)
{
$test1Result = Test-NetConnection -ComputerName $masterName 

if($test1Result.PingSucceeded -eq $true)
{
$test1Passed = $true
}
else
{
Start-Sleep -Seconds $retryDelay
$test1RetryCount = $test1RetryCount + 1
}
}

####### Self Test 2 - Test Head Node Service Running #########
$test2Passed = $false
if($test1Passed -eq $true)
{
$GLService = Get-Service -Name Dhcp

if($GLService.Status -ne 'Running')
{

Start-Service -Name Dhcp
$GLService = Get-Service -Name Dhcp
}
if($GLService.Status -eq 'Running')
{
$test2Passed = $true
}
}

######### Action Based on Tests ####################
New-EC2Tag -Resource $instanceId -Tag @{Key="Name"; Value="$HostName"}
New-EC2Tag -Resource $instanceId -Tag @{Key="Octank_InFarm"; Value="pass"}

if($test1Passed -eq $true -and $test2Passed -eq $true)
{
New-EC2Tag -Resource $instanceId -Tag @{Key="Octank_PassedTest"; Value="Pass"}
}
else
{
New-EC2Tag -Resource $instanceId -Tag @{Key="Octank_PassedTest"; Value="Fail"}
Set-ASInstanceHealth -InstanceId $instanceId -HealthStatus "Unhealthy"
}
#####  MSHPCPACK Install #############
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Write-Host "Disabling Windows Firewall"
Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled False

$Admin = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $ADUserSecrets).SecretString
$DomainAdminPassword = $Admin.password

Write-Host "Disabling IE Enhanced Security Configuration (ESC)..."
$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0

Write-Host "Download HPCPACK Software"
Write-Host "Creating Directory for HPC PACK 2019 Public Cert"
New-Item -Path C:\ms-hpcpack2019\ -ItemType directory -Force
$url = "https://download.microsoft.com/download/c/e/b/ceb6122c-1006-44f8-99b1-1792f928f155/HPC%20Pack%202019.zip"
$location = "C:\ms-hpcpack2019\HPCPack2019.zip"
$wc = New-Object net.webclient
$wc.Downloadfile($url,$location)
$installdir = "C:\install"
Set-ExecutionPolicy Bypass -Scope Process -Force;
Expand-Archive -Path $location -DestinationPath $installdir
$cerFileName = "C:\ms-hpcpack2019\myhpc.pfx"
$bucket = $QSS3BucketName
Copy-S3Object -BucketName $CertS3Bucket -Key $CertS3Key -LocalFile $cerFileName

$HeadNode = $HeadNodeNetBIOSName + "." + $DomainDNSName
$pw = $DomainAdminPassword
$Admin=[adsi]("WinNT://$env:COMPUTERNAME/Administrator, user")
$Admin.SetPassword($pw)

$setupArg = "-unattend -ComputeNode:$HeadNode -SSLPfxFilePath:$cerFileName -SSLPfxFilePassword:$pw"

$p = Start-Process -FilePath "$installdir\setup.exe" -ArgumentList $setupArg -PassThru -Wait
$p
## Bring node online
Start-Sleep -s 360
Add-PSSnapIn Microsoft.HPC

$AdminSec = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $ADUserSecrets).SecretString
$UserName = $DomainDNSName + "\" + $AdminSec.username
$pass = ConvertTo-SecureString $AdminSec.password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName,$pass

#$joincluster = {
$ErrorActionPreference = "Stop"

#Add-PSSnapIn Microsoft.HPC

Write-Host "Joining Cluster"
if ((gwmi win32_computersystem).partofdomain -eq $true) {
    write-host  "Workers will join Domain Joined Node Template"
    # This node will be a compute node
Assign-HpcNodeTemplate -NodeName $env:COMPUTERNAME -Name "Default ComputeNode Template" -Confirm:$false
} else {
    write-host  "Workers will join Non-domain Joined Node Template"
    # This node will be a compute node
Assign-HpcNodeTemplate -NodeName $env:COMPUTERNAME -Name "NonDomain ComputeNode Template" -Confirm:$false
}
#}
#Invoke-Command -ScriptBlock $joincluster -ComputerName $env:COMPUTERNAME -Credential $cred -Authentication Credssp

# Only use physical cores, and leave the OS assign the processes on the machine
#$cores = (Get-WmiObject Win32_Processor | Measure-Object -Property NumberOfCores -Sum | Select-Object -ExpandProperty Sum)
#Set-HpcNode -Name $env:COMPUTERNAME -SubscribedCores $cores -Affinity:$false

# Bring the node online
Set-HpcNodeState -Name $env:COMPUTERNAME -State online
#######end ###########