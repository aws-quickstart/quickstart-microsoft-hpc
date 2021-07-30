## Configure HeadNode1

## Setup SQL Server
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]
    $DomainNetBIOSName,

    [Parameter(Mandatory=$true)]
    [string]
    $DomainAdminUser,
    [Parameter(Mandatory=$true)]
    [string]
    $DomainAdminPassword,
    [Parameter(Mandatory=$true)]
    [string]
    $QSS3BucketName

)
Start-Transcript -Path C:\cfn\log\ConfigHeadNode.ps1.txt -Append
$SSLThumbprint = (get-childitem -path cert:\LocalMachine\root | where { $_.subject -eq "CN=mshpcpack-2019" }).Thumbprint
$ClusterName = $env:COMPUTERNAME
$ServerInstance = $env:COMPUTERNAME
$HeadNodelist = $DomainNetBIOSName +'\'+ $env:COMPUTERNAME+"$"
$installdir = "C:\install"
#Install-module -Force Sqlserver
#allow remote access
$querystr = "EXEC sp_configure 'remote access', 1 ;RECONFIGURE ;"
Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $querystr


$q2 = "create login [$DomainAdminUser] from windows"
$q3 = "ALTER SERVER ROLE [sysadmin] ADD MEMBER [$DomainAdminUser]"
Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $q2
Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $q3


#Download the certs
$cerFileName = "C:\ms-hpcpack2019\myhpc.pfx"
$bucket = "${QSS3BucketName}"
Copy-S3Object -BucketName $bucket -Key mypfx.pfx -LocalFile $cerFileName
$pw = "${DomainAdminPassword}"

##Setupdatabase
Set-ExecutionPolicy Bypass -Scope Process -Force;
cd $installdir\setup
.\SetupHpcDatabase.ps1 -ServerInstance $ServerInstance  -HpcSetupUser $DomainAdminUser -HeadNodeList $HeadNodelist -ErrorAction SilentlyContinue

#Install HPCPACK HeadNODE
$setupArg = "-unattend -HeadNode -ClusterName:$ClusterName -SSLPfxFilePath:$cerFileName -SSLPfxFilePassword:$pw"
$SQLServerInstance = $ServerInstance
$secinfo = "Integrated Security=True"
$mgmtConstr = "Data Source=$SQLServerInstance;Initial Catalog=HpcManagement;$secinfo"
$schdConstr = "Data Source=$SQLServerInstance;Initial Catalog=HpcScheduler;$secinfo"
$monConstr  = "Data Source=$SQLServerInstance;Initial Catalog=HPCMonitoring;$secinfo"
$rptConstr  = "Data Source=$SQLServerInstance;Initial Catalog=HPCReporting;$secinfo"
$diagConstr = "Data Source=$SQLServerInstance;Initial Catalog=HPCDiagnostics;$secinfo"
$HAstoConstr = "Data Source=$SQLServerInstance;Initial Catalog=HPCHAStorage;$secinfo"
$HAwitConstr = "Data Source=$SQLServerInstance;Initial Catalog=HPCHAWitness;$secinfo"

$setupArg = "$setupArg -MGMTDBCONSTR:`"$mgmtConstr`" -HAStorageDbConstr:`"$HAstoConstr`" -HAWitnessDbConstr:`"$HAwitConstr`" -SCHDDBCONSTR:`"$schdConstr`" -RPTDBCONSTR:`"$rptConstr`" -DIAGDBCONSTR:`"$diagConstr`" -MONDBCONSTR:`"$monConstr`""           

$p = Start-Process -FilePath "$installdir\setup.exe" -ArgumentList $setupArg -PassThru -Wait
$p
write-host "Succeed to Install HPC Pack HeadNode"
