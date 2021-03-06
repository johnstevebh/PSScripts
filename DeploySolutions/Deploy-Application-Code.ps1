param ( 
	[Parameter(Mandatory=$true)][string] $src,
	[Parameter(Mandatory=$true)][string] $url,
	[Parameter(Mandatory=$true)][string] $app,
	[switch] $record
)

#Load Libraries
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")

Import-Module (Join-Path $ENV:SCRIPTS_HOME "\Libraries\Credentials.psm1")

#Global Variables
$global:deploy_steps = @()

#Constants
Set-Variable -Name log_home -Value "D:\Logs" -Option Constant
Set-Variable -Name document_link  -Value "http://example.com/sites/AppOps/Lists/Tracker/DispForm.aspx?ID={0}"
Set-Variable -Name team_site -Value "http://example.com/sites/AppOps/" -Option Constant
Set-Variable -Name team_list -Value "Deployment Tracker" -Option Constant
Set-Variable -Name team_view -Value '{}' -Option Constant
Set-Variable -Name deploy_solutions -Value (Join-Path $ENV:SCRIPTS_HOME "DeploySolutions\Deploy-Sharepoint-Solutions.ps1") -Option Constant
Set-Variable -Name deploy_configs -Value (Join-Path $ENV:SCRIPTS_HOME "DeployConfig\DeployConfigs.ps1") -Option Constant
Set-Variable -Name enable_features -Value (Join-Path $ENV:SCRIPTS_HOME "DeploySolutions\Enable-$app-Features.ps1") -Option Constant

#Script Blocks
$sptimer_script_block = { Restart-Service -Name sptimerv4 -Verbose }
$iisreset_scipt_block = { iisreset }
$sync_file_script_block = {
    param ( [string] $src, [string] $dst, [string] $log_home  )
    Write-Host "[ $(Get-Date) ] - Copying files on $ENV:COMPUTER from $src to $dst . . ."
    $log_file = Join-Path $log_home ("application-deployment-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log")
	$sync_script = (Join-Path $ENV:SCRIPTS_HOME "Sync\Sync-Files.ps1")
	&$sync_script -src $src -dst $dst -verbose -logging -log $log_file
}
$gac_script_block = {
	param( [string] $src ) 
	Write-Host "[ $(Get-Date) ] - Deploying to the GAC on $ENV:COMPUTER from $src . . ."
	$gac_script = (Join-Path $ENV:SCRIPTS_HOME "Misc-SPScripts\Install-Assemblies-To-GAC.ps1")
	&$gac_script -dir $src -verbose
}

#Menu
$menu = @(
	@{ "Text" = "Deploy SharePoint Solutions"; "ScriptBlock" = "Deploy-Solutions" },
    @{ "Text" = "Enable $app Features"; "ScriptBlock" = "Enable-Features" },
    @{ "Text" = "Deploy $app Web Config Files"; "ScriptBlock" = "Deploy-Config" },
    @{ "Text" = "Install MSI Files"; "ScriptBlock" = "Install-MSIFile" },
    @{ "Text" = "Uninstall MSI Files"; "ScriptBlock" = "Uninstall-MSIFile" },
    @{ "Text" = "Install Files to GAC"; "ScriptBlock" = "DeployTo-GAC" },
    @{ "Text" = "Sync Web Code"; "ScriptBlock" = "Sync-Files" },
    @{ "Text" = "Cycle IIS On All SharePoint Servers"; "ScriptBlock" = "Cycle-IIS" },
    @{ "Text" = "Cycle Timer Service on All SharePoint Servers"; "ScriptBlock" = "Cycle-Timer" },
    @{ "Text" = "Record and Quit"; "ScriptBlock" = "break" }
)

function Log-Step
{
    param( [string] $step )
    $global:deploy_steps += "<li>" + $step + "</li>"
}

function Get-SPServers 
{
    param( [string] $type = "Microsoft SharePoint Foundation Workflow Timer Service" )
   
	$servers = Get-SPServiceInstance | 
	    Where { $_.TypeName -eq $type -and $_.Status -eq "Online" } | 
		Select -Expand Server | 
		Select -Expand Address 

    return $servers
}

function Get-SPUserViaWS
{
    param ( [string] $url, [string] $name )
	$service = New-WebServiceProxy ($url + "_vti_bin/UserGroup.asmx?WSDL") -Namespace User -UseDefaultCredential
	$user = $service.GetUserInfo("i:0#.w|$name") 
    return $user.user.id + ";#" + $user.user.Name
}

function Get-SPDeploy
{
    param( [string] $version, [string] $build ) 
	$deploys = Get-SPListViaWebService -url $team_site -list $team_list -View $team_view 
    return $deploys | where { $_.CodeVersion -eq $version -and $_.VersionNumber -eq $build } | Select -First 1
}

function Record-Deployment
{ 	
	Write-Host "============================"
	$global:deploy_steps 
	Write-Host "============================"
	
	$code_version = Read-Host "Please enter the Code Version - example: $app-3.1"
	$code_number = Read-Host "Please enter the Code Build Number- example: 11"
	
    $existing_deploy = Get-SPDeploy -version $code_version -build $code_number

	$date = $(Get-Date).ToString("yyyy-MM-ddThh:mm:ssZ")
	$user = Get-SPUserViaWS -url $team_site -name ($ENV:USERDOMAIN + "\" + $ENV:USERNAME)

	if( ! $existing_deploy ) {
		$deploy = @{
			Title = "Automated $app Deployment"
            Application = ";#$app;#"
			CodeLocation = $src
			DeploymentSteps = $global:deploy_steps 
			CodeVersion = $code_version
			VersionNumber = $code_number
			Notes = "Deployed on $ENV:COMPUTERNAME from $src . . .<BR/>"
		}
			
		if( $url -imatch "-uat" ) {
			$deploy.Add( 'UAT_x0020_Deployment', $date )
			$deploy.Add( 'UAT_x0020_Deployer', $user )
		} 
		else {
			$deploy.Add( 'PROD_x0020_Deployment', $date )
			$deploy.Add( 'PROD_x0020_Deployer', $user ) 
		}
	
		WriteTo-SPListViaWebService -url $team_site -list $team_list -Item $deploy
        $existing_deploy = Get-SPDeploy -version $code_version -build $code_number
	}
	else { 
        if( $url -imatch "-uat" ) {
        	$existing_deploy | Add-Member -Type NoteProperty -Name UAT_x0020_Deployment -Value $date 
			$existing_deploy | Add-Member -Type NoteProperty -Name UAT_x0020_Deployer $user 
        }
        else {
			$existing_deploy | Add-Member -Type NoteProperty -Name PROD_x0020_Deployment -Value $date 
			$existing_deploy | Add-Member -Type NoteProperty -Name PROD_x0020_Deployer $user 
        }
 
		$existing_deploy.Notes += "Deployed on $ENV:COMPUTERNAME from $src . . .<BR/>"
		$existing_deploy.DeploymentSteps += $global:deploy_steps  
		Update-SPListViaWebService -url $team_site -list $team_list -Item (Convert-ObjectToHash $existing_deploy) -Id  $existing_deploy.Id	
	}

    $document_link = $document_link -f $existing_deploy.Id
    Write-Host "Documentation Created/Updated at - $document_link"
}

function Deploy-Solutions
{
    Log-Step -step "$deploy_solutions -web_application $url -deploy_directory $src -noupgrade"
    Log-Step -step "$deploy_configs -operation backup -url $url"

    Get-SPWebApplication $url -EA Silentlycontinue | Out-Null
    if( !$? ) {
        throw ("Could not find " + $url + " this SharePoint farm. Are you sure you're on the right one?")
        exit
    }

    cd ( Join-Path $ENV:SCRIPTS_HOME "DeploySolutions" )
	&$deploy_solutions -web_application $url -deploy_directory $src -noupgrade
	cd (Join-Path $ENV:SCRIPTS_HOME "DeployConfig" )
	&$deploy_configs -operation backup -url $url				
    cd ( Join-Path $ENV:SCRIPTS_HOME "DeploySolutions" )
}

function Deploy-Config
{
    Log-Step -step "$deploy_configs -operation deploy -url $url" 
    Log-Step -step "$deploy_configs -operation validate -url $url" 
    
	cd (Join-Path $ENV:SCRIPTS_HOME "DeployConfig" )
	&$deploy_configs -operation deploy -url $url
	&$deploy_configs -operation validate -url $url 
    cd ( Join-Path $ENV:SCRIPTS_HOME "DeploySolutions" )
}

function Enable-Features 
{
    if( !( Test-Path $enable_features ) ) { 
        Write-Error "Could not find $enable_features script"
        return
    }

	Log-Step -step "$enable_features -webApp $url"

	cd (Join-Path $ENV:SCRIPTS_HOME  "DeploySolutions" )
	&$enable_features -webApp $url			
    cd ( Join-Path $ENV:SCRIPTS_HOME "DeploySolutions" )
}

function Install-MSIFile
{
	Log-Step -step "Get-ChildItem $src -filter *.msi | % { Start-Process -FilePath msiexec.exe -ArgumentList /i, $_.FullName -Wait }"
	
	foreach( $msi in (Get-ChildItem $src -Filter *.msi) ) {
		Write-Host "[ $(Get-Date) ] - Installing MSI - $($msi.FullName)  . . ."
		Start-Process -FilePath msiexec.exe -ArgumentList /i, $msi.FullName -Wait  
	} 
}

function Uninstall-MSIFile
{ 
	Log-Step -step "Get-Content (Join-Path $src uninstall.txt) | % { Start-Process -FilePath msiexec.exe -ArgumentList /x,$_,/qn -Wait }" 

    $uninstall_file = (Join-Path $src "uninstall.txt") 
    if( !( Test-Path $uninstall_file )) {
        throw "Could not file the file that contains the MSIs to uninstall at $uninstall_file"
        return
    } 
	
    Get-Content $uninstall_file | Foreach { 
		Write-Host "[ $(Get-Date) ] - Removing MSI with ID - $_  . . ."
		Start-Process -FilePath msiexec.exe -ArgumentList /x,$_,/qn -Wait  
	} 
}

function Sync-Files
{
    $dst = Read-Host "Enter the Destination Directory to Sync Files to"
    $servers = (Read-Host "Enter servers to copy files to(separated by a comma) ").Split(",")

	Log-Step -step "Executed on $servers - (Join-Path $ENV:SCRIPTS_HOME Sync\Sync-Files.ps1) -src $src -dst $dst  -verbose -logging"

    Invoke-Command -Computer $servers -Authentication CredSSP -Credential (Get-Creds) -ScriptBlock $sync_file_script_block -ArgumentList $src, $dst, $log_home
}

function DeployTo-GAC
{
    $servers =  Get-SPServers -type "Microsoft SharePoint Foundation Web Application"
	Log-Step -step "Executed on $servers -(Join-Path $ENV:SCRIPTS_HOME Misc-SPScripts\Install-Assemblies-To-GAC.ps1) -src $src" 
	 
	Invoke-Command -Computer $servers -Authentication CredSSP -Credential (Get-Creds)-ScriptBlock $gac_script_block -ArgumentList $src
}

function Cycle-IIS 
{
    $servers = Get-SPServers
    Log-Step -step "Invoke-Command -Computer $servers -ScriptBlock $iisreset_script_block" 
    Invoke-Command -Computer $servers -ScriptBlock $iisreset_scipt_block
}

function Cycle-Timer
{
    $servers = Get-SPServers
    Log-Step -step "Invoke-Command -Computer $servers -ScriptBlock $sptimer_script_block"
    Invoke-Command -Computer $servers -ScriptBlock $sptimer_script_block
}

function main 
{
	if( $url -notmatch "http://" ) { $url = $url.Insert( 0, "http://" )  }
 
	$log = Join-Path $log_home ("Deploy-For-" + ( $url -replace "http://") + "-From-" + $ENV:COMPUTERNAME + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log")
	&{Trap{continue};Start-Transcript -Append -Path $log}

	Write-Host "============================"
	Write-Host "Deployment Source Directory - $src"
	Write-Host "Deployment URL - $url"
	Write-Host "============================"
	
    Log-Step -step "Automated with $($MyInvocation.InvocationName) from $ENV:COMPUTERNAME . . .<BR/>"
    Log-Step -step "Steps Taken include - <BR/><HR/>"

	do
	{
	    $i=1
    	foreach( $item in $menu ) { Write-Host "$i) - $($item.Text) ..."; $i++ }
        $ans = [int]( Read-Host "Please Enter the Number  " )	    
        Invoke-Expression $menu[$ans-1].ScriptBlock
	} while ( $true )

    if($record) { Record-Deployment }

	Stop-Transcript
}
main