## Configure Jumpbox

## Setup SQL Server
[CmdletBinding()]
param(  
    [Parameter(Mandatory=$true)]
    [string]
    $ADUserSecrets,

    [Parameter(Mandatory=$true)]
    [string]
    $CertS3Bucket,

    [Parameter(Mandatory=$true)]
    [string]
    $CertS3Key

)
Start-Transcript -Path C:\cfn\log\ConfigJumpBox.ps1.txt -Append

$Admin = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $ADUserSecrets).SecretString

$installdir = "C:\install"

#Download the certs
$cerFileName = "C:\ms-hpcpack2019\myhpc.pfx"
$bucket = "${CertS3Bucket}"
$key = "${CertS3Key}"
Copy-S3Object -BucketName $bucket -Key $key -LocalFile $cerFileName

$pw = ConvertTo-SecureString $Admin.password -AsPlainText -Force

#Install HPCPACK Client Utilities - HPC Cluster Manager and Job Manager
$setupArg = "-unattend -Client -SSLPfxFilePath:$cerFileName -SSLPfxFilePassword:$DomainAdminPassword"

$p = Start-Process -FilePath "$installdir\setup.exe" -ArgumentList $setupArg -PassThru -Wait
$p
Import-PfxCertificate -FilePath $cerFileName -CertStoreLocation Cert:\LocalMachine\Root -Password $pw  | Out-Null
write-host "Succeed to Install HPC Pack HeadNode"