###
#Script - Subscribe-ToServiceApplications
#Purpose - To subscribe to SharePoint 2010 service applications
#Author - Brian Denicola
###
[CmdletBinding(SupportsShouldProcess=$true)]
param(	
	[string] $config = ".\config\master_setup.xml"
)

function Get-ScriptBlock( [string] $file )
{
	[ScriptBlock]::Create( (gc $file | Out-String) )
}

Add-PSSnapin Microsoft.SharePoint.Powershell –EA SilentlyContinue

. ..\libraries\SharePoint2010_functions.ps1
. ..\libraries\Standard_functions.ps1

$set_perms_scriptblock = Get-ScriptBlock .\Modules\Setup-Publishing-Permissions-ScriptBlock.ps1
$exchange_certs_scriptblock = Get-ScriptBlock .\Modules\Setup-Cert-Exchange-ScriptBlock.ps1

$PublishedServiceApps = @(
	@{ "Name" = "Metadata"; "Application" = "Managed Metadata Service Application"; "Function" = "New-SPMetadataServiceApplicationProxy" },
	@{ "Name" = "UserProfile"; "Application" = "User Profile Service Application"; "Function" = "New-SPProfileServiceApplicationProxy" },
	@{ "Name" = "Search"; "Application" = "Search Service Application"; "Function" = "New-SPEnterpriseSearchServiceApplicationProxy" },
	@{ "Name" = "WebAnalytics"; "Application" = "Web Analytics Service Application"; "Function" = "New-SPWebAnalyticsServiceApplicationProxy" }
)

function Get-FarmType
{
	$xpath = "/SharePoint/Farms/farm/server[@name='" + $ENV:COMPUTERNAME + "']"
	$global:farm_type = (Select-Xml -xpath $xpath  $cfg | Select @{Name="Farm";Expression={$_.Node.ParentNode.name}}).Farm
	
	if( $global:farm_type -ne $null )
	{
		Write-Host "Found $ENV:COMPUTERNAME in $global:farm_type Farm Configuration"
	}
	
	return $global:farm_type
}

function Import-ServicesRootCert
{
	param(
		[string] $ServicesCentralAdmin
	)
	
	$authority = "GT-ServicesFarm"
	if( (Get-SPTrustedRootAuthority $authority ) ) 
	{
		Write-Host "[$(Get-Date)] - A Trusted Root Authority is already configured"
		return
	}
	
	if( Test-Path ( "\\$ServicesCentralAdmin\D$\Certs\ServicesFarmRoot.cer" ) )
	{
		Copy-Item \\$ServicesCentralAdmin\D$\Certs\ServicesFarmRoot.cer D:\Certs\
		$trustCert = Get-PfxCertificate "D:\Certs\ServicesFarmRoot.cer"
		New-SPTrustedRootAuthority $authority -Certificate $trustCert
	}
}

function main 
{
	$log = "D:\Logs\Subscribe-To-Service-Applications-" + $ENV:COMPUTERNAME + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log"
	Start-Transcript -Append -Path $log

	$creds = Get-Credential ($ENV:USERDOMAIN + "\" + $ENV:USERNAME)
	
	$farm_id = Get-SPFarm | Select -Expand id | Select -Expand Guid
	$users = Get-SPManagedAccount | Select -ExpandProperty UserName
	
	$central_admin = $cfg.SharePoint.Farms.Farm | where { $_.Name -eq "Services"} | Select -Expand Server | ? { $_.Role -eq "central-admin" } | Select -Expand Name
	$farm_type = Get-FarmType 
	
	if( $farm_type -eq "services" -or $farm_type -eq $null )
	{
		throw "[ERROR] This script should not be run on the services farm or farm type could not be determined"
	}
	
	Write-Host "[$(Get-Date)] - Attempting to Import Certificates from Publishing Farm - $central_admin server"
	Import-ServicesRootCert -ServicesCentralAdmin $central_admin 
	
	Write-Host "[$(Get-Date)] - Attempting to Exchange Trust Certificates with Publishing Farm - $central_admin server"
	Invoke-Command -ComputerName $central_admin -Authentication Credssp -Credential $creds -ScriptBlock $exchange_certs_scriptblock -ArgumentList $ENV:COMPUTERNAME, $farm_type
	
	Write-Host "[$(Get-Date)] - Attempting to Set Permission on Publishing Farm - $central_admin server"
	Invoke-Command -ComputerName $central_admin -Authentication Credssp -Credential $creds -ScriptBlock $set_perms_scriptblock -ArgumentList $farm_id, $users
	
	Write-Host "[$(Get-Date)] - Getting Service Application Connection Info"
	$publishing_url = "https://{0}:32844/Topology/topology.svc" -f $central_admin
	$connection_info = Receive-SPServiceApplicationConnectionInfo -FarmUrl $publishing_url
	
	if( $connection_info -eq $null ) 
	{
		throw "Could not Receive Service Application Connection Info"
		exit
	}
	
	foreach( $app in $PublishedServiceApps )
	{
		Write-Host "[$(Get-Date)] - Create Service Application Proxy - " $app.Name
		$uri = $connection_info | where { $_.Name -eq $app.Application } | Select -ExpandProperty Uri
		&$app.Function  -Uri $uri -Name ("Connect to: " + $app.Application)
	}
			
	Stop-Transcript
}
$cfg = [xml] (gc $config)
main