[CmdletBinding()]
param(
    
    [Parameter(Mandatory=$true)]
    [string]
    $DomainAdminUser,
    [Parameter(Mandatory=$true)]
    [string]
    $DomainAdminPassword

)
Start-Transcript -Path C:\cfn\log\ConfigureNetwork.ps1.txt -Append
Start-Sleep -s 60
$pass = $DomainAdminPassword
# Creating Credential Object for Administrator
$Credentials = (New-Object PSCredential($DomainAdminUser,(ConvertTo-SecureString $pass -AsPlainText -Force)))

Add-PSSnapIn Microsoft.HPC -ErrorAction SilentlyContinue

Set-HPCNetwork -Topology Enterprise -EnterpriseDnsRegistrationType FullDnsNameOnly -EnterpriseFirewall $null

Set-HpcJobCredential -Credential $Credentials
Set-HpcClusterProperty -InstallCredential $Credentials

Set-HpcClusterProperty -NodeNamingSeries "Compute%1000%"
#New-HpcNodeTemplate -Name "ComputeNode Template" -Description "Custom compute node template" -Type ComputeNode -UpdateCategory None 
Set-HpcNode -Name $env:COMPUTERNAME -Role BrokerNode
Set-HpcNodeState -Name $env:COMPUTERNAME -State online