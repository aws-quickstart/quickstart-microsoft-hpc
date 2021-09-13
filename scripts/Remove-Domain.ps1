[CmdletBinding()]
param(
    [string]
    $DomainNetBIOSName,
    [string]
    $ADUserSecrets
)

$ErrorActionPreference = "Stop"
Add-PSSnapIn Microsoft.HPC -ErrorAction SilentlyContinue
$Admin = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $ADUserSecrets).SecretString

$UserName = $DomainName + "\" + $Admin.username
$pass = ConvertTo-SecureString $Admin.password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName,$pass

Set-HpcNodeState -Name $env:COMPUTERNAME -State "Offline" -Force
Remove-HpcNode  -Name $env:COMPUTERNAME -Confirm:$False
Remove-Computer  -ComputerName $env:COMPUTERNAME -UnjoinDomainCredential $cred -ErrorAction Stop -Force

# Execute restart after script exit and allow time for external services
$shutdown = Start-Process -FilePath "shutdown.exe" -ArgumentList @("/r", "/t 10") -Wait -NoNewWindow -PassThru
if ($shutdown.ExitCode -ne 0) {
    throw "[ERROR] shutdown.exe exit code was not 0. It was actually $($shutdown.ExitCode)."
}

