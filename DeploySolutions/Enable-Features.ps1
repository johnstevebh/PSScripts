param ( 
	[Parameter(Mandatory=$true)]
	[string] $webApp,
	
	[Parameter(Mandatory=$true)]
	[string[]] $features
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

function Enable-Feature
{
	param ( 
		[string] $featureName
	)
   
	Disable-SPFeature -Identity $featureName -Url $webApp -Confirm:$false -Verbose
	Sleep 1 
	Enable-SPFeature -Identity $featureName -Url $webApp -Verbose      
}

function main
{
	$log= $PWD.Path  + "\WFeatures-" + $(get-date).tostring("mm_dd_yyyy-hh_mm_s") + ".txt"

	Start-Transcript -Path $log -Append
	foreach ( $feature in $features ) 
	{
		Write-Host "Enabling feature - " $feature 
		Enable-Feature -featureName $feature 
	}

	$servers = Get-SPServer | where { $_.Role -ne "Invalid" } | Select -Expand Address 

	Invoke-Command -computer $servers -ScriptBlock {
		Write-Host "Restarting IIS on $ENV:COMPUTERNAME"
		iisreset 
		Restart-Service sptimerv4 -verbose
	}
	
	Stop-Transcript
}
main