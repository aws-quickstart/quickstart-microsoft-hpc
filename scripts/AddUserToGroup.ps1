param(

	[Parameter(Mandatory=$True)]
	[string]
	$GroupName,

	[Parameter(Mandatory=$True)]
	[string]
	$UserName

)

try {
    Start-Transcript -Path C:\cfn\log\AddUserToGroup.ps1.txt -Append

    $ErrorActionPreference = "Stop"

    Add-LocalGroupMember -Group $GroupName -Member $UserName
}
catch {
    Write-Verbose "$($_.exception.message)@ $(Get-Date)"
    $_ | Write-AWSQuickStartException
}
