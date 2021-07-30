## PrepareNode.ps1 Script 
Start-Transcript -Path C:\cfn\log\PrepareNode.ps1.txt -Append
$ErrorActionPreference = "Stop"
Write-Host "Disabling Windows Firewall"
Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled False

Write-Host "Creating Directory for HPC PACK 2019 Public Cert"
New-Item -Path C:\ms-hpcpack2019\ -ItemType directory -Force

Write-Host "Removing Certificate if it already exists"
(Get-ChildItem Cert:\LocalMachine\My\) | Where-Object { $_.Subject -eq "CN=mshpcpack-2019" } | Remove-Item

#Write-Host "Setting up HPCPACK2019 Certificate "
#$cert = New-SelfSignedCertificate -KeySpec KeyExchange -DnsName 'mshpcpack-2019' -HashAlgorithm SHA256 -NotAfter (Get-Date).AddYears(5) -NotBefore (Get-Date).AddDays(-1)
# Exporting the public key certificate
#$cerFileName = "C:\ms-hpcpack2019\publickeys\mshpcpack.cer"
#$cert | Export-Certificate -FilePath $cerFileName -Force
#Import-Certificate -FilePath $cerFileName -CertStoreLocation Cert:\LocalMachine\Root  | Out-Null
#Remove-Item $cerFileName -Force -ErrorAction SilentlyContinue



#Download HPCPACK Software
Write-Host "Disabling IE Enhanced Security Configuration (ESC)..."
$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0

$url = "https://download.microsoft.com/download/c/e/b/ceb6122c-1006-44f8-99b1-1792f928f155/HPC%20Pack%202019.zip"
$location = "C:\ms-hpcpack2019\HPCPack2019.zip"
$wc = New-Object net.webclient
$wc.Downloadfile($url,$location)
$installdir = "C:\install"
Set-ExecutionPolicy Bypass -Scope Process -Force;
Expand-Archive -Path $location -DestinationPath $installdir
