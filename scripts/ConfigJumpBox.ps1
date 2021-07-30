## Configure Jumpbox

## Setup SQL Server
[CmdletBinding()]
param(  
    [Parameter(Mandatory=$true)]
    [string]
    $DomainAdminPassword,
    [Parameter(Mandatory=$true)]
    [string]
    $QSS3BucketName

)
Start-Transcript -Path C:\cfn\log\ConfigJumpBox.ps1.txt -Append

$installdir = "C:\install"

#Download the certs
$cerFileName = "C:\ms-hpcpack2019\myhpc.pfx"
$bucket = "${QSS3BucketName}"
Copy-S3Object -BucketName $bucket -Key mypfx.pfx -LocalFile $cerFileName

$pw = ConvertTo-SecureString "${DomainAdminPassword}" -AsPlainText -Force

#Install HPCPACK Client Utilities - HPC Cluster Manager and Job Manager
$setupArg = "-unattend -Client -SSLPfxFilePath:$cerFileName -SSLPfxFilePassword:$DomainAdminPassword"

$p = Start-Process -FilePath "$installdir\setup.exe" -ArgumentList $setupArg -PassThru -Wait
$p
Import-PfxCertificate -FilePath $cerFileName -CertStoreLocation Cert:\LocalMachine\Root -Password $pw  | Out-Null
write-host "Succeed to Install HPC Pack HeadNode"