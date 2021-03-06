﻿#Load Sharepoint .NET assemblies 
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint")
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server.Search") 
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server") 
#[void][System.Reflection.Assembly]::LoadFrom("D:\Scripts\Libraries\Lists.dll")

$siteTypes = @{}
$siteTypes.Add("Team Site","STS#0")
$siteTypes.Add("Blank","STS#1")
$siteTypes.Add("Workspace", "STS#2")
$siteTypes.Add("Meeting Workspace","MPS#0")

$auditTypes= @{}
$auditTypes['OpenView'] = 4
$auditTypes['EditItem'] = 16
$auditTypes['CheckInOut'] = 3
$auditTypes['MoveCopyItem'] = 6144
$auditTypes['DeleteItem'] = 520
$auditTypes['EditContentType'] = 160
$auditTypes['SearchSiteContent'] = 8192
$auditTypes['UserSecurity'] = 256


function Get-SharePointServersWS()
{
	param(
		[string] $version = "2010"
	)
	
	if( $version -eq "2007" ) {
		return(	get-SPListViaWebService -Url http://teamadmin.gt.com/sites/ApplicationOperations/ -list Servers -View '{17029C2D-ABD2-45F8-9FE5-17A5F3C0DCBC}' | Select SystemName, Farm, Environment, ApplicationName)
	} else { 
		return(	get-SPListViaWebService -Url http://teamadmin.gt.com/sites/ApplicationOperations/ -list Servers  | Select SystemName, Farm, Environment, ApplicationName)
	}
}

function Get-SharePointCentralAdmins()
{
	return(	get-SPListViaWebService -Url http://teamadmin.gt.com/sites/ApplicationOperations/ -list Servers -view "{3ADCF3C7-5CCE-459C-89A8-D361B7C71CB1}" | Select SystemName, Farm, Environment, "Central Admin Address" )
}

function Get-LatestLog()
{
	begin {
		$log_path = "\Logs\Trace\"
	}
	process {
		
		$src = Join-Path ("\\" + $_ ) $log_path
		$latest_file =  ( dir $src | sort LastWriteTime -desc | select -first 1 | Select -ExpandProperty Name )
		
		Copy-Item (Join-Path $src $latest_file) . -verbose
	}
	end {
	}
}


function Get-SharePointSolutions()
{
	return (Get-SPFarm | Select -Expand Solutions | Select Name, Deployed, DeployedWebApplications, DeployedServers, ContainsGlobalAssembly, ContainsCasPolicy, SolutionId, LastOperationEndTime)
}

function Get-WebServiceURL( [String] $url )
{
	$listWebService = "_vti_bin/Lists.asmx?WSDL"
	
	if( -not $url.EndsWith($listWebService) )
	{
		return $url.Substring( 0, $url.LastIndexOf("/") ) + "/" + $listWebService
	} else
	{
		return $url
	}

}

function Get-SPListViaWebService([string] $url, [string] $list, [string] $view = $null )
{
	begin {
		$listData = @()
		
		$service = New-WebServiceProxy (Get-WebServiceURL -url $url) -Namespace List -UseDefaultCredential
		
		$FieldsWS = $service.GetList( $list )
		$Fields = $FieldsWS.Fields.Field | where { $_.Hidden -ne "TRUE"} | Select DisplayName, StaticName -Unique
		$data = $service.GetListItems( $list, $view, $null, $null, $null, $null, $null )
	}
	process {
			
		$ErrorActionPreference = "silentlycontinue"
		$data.data.row | % {
			$item = $_
			$t = new-object System.Object
			$Fields | % {
				$StaticName = "ows_" + $_.StaticName
				$DisplayName = $_.DisplayName
				if( $item.$StaticName -ne $nul ) {
					$t | add-member -type NoteProperty -name $DisplayName.ToString() -value $item.$StaticName
				}
			}
			$listData += $t
		}
	}
	end {
			return ( $listData )
	}
}

function Get-FarmAccount( [string[]] $Computername )
{
	$farmAccounts = @()
	$ComputerName | % {
		$computer = $_
		$farmAccounts += (gwmi Win32_Process -Computer $computer | Where { $_.Caption -eq "owstimer.exe"} ).GetOwner() | Select @{Name="System";Expression={$computer}}, Domain, User
	}
	return $farmAccounts

}

function WriteTo-SPListViaWebService ( [String] $url, [String] $list, [HashTable] $Item, [String] $TitleField )
{
	begin {
		$service = New-WebServiceProxy (Get-WebServiceURL -url $url) -Namespace List -UseDefaultCredential
	}
	process {

		$xml = @"
			<Batch OnError='Continue' ListVersion='1' ViewName='{0}'>  
				<Method ID='1' Cmd='New'>
					{1}
				</Method>  
			</Batch>  
"@   

		$listInfo = $service.GetListAndView($list, "")   

		foreach ($key in $item.Keys) {
			$value = $item[$key]
			if( -not [String]::IsNullOrEmpty($TitleField) -and $key -eq $TitleField ) {
				$key = "Title"
			}
			$listItem += ("<Field Name='{0}'>{1}</Field>`n" -f $key, [system.net.webutility]::htmlencode($value) )
		}   
  
		$batch = [xml]($xml -f $listInfo.View.Name,$listItem)   
				
		$response = $service.UpdateListItems($listInfo.List.Name, $batch)   
		$code = [int]$response.result.errorcode   
	
 		if ($code -ne 0) {   
			Write-Warning "Error $code - $($response.result.errortext)"     
		} else {
			Write-Host "Success"
		}
	}
	end {
		
	}
}


function Update-SPListViaWebService ( [String] $url, [String] $list, [int] $id, [HashTable] $Item, [String] $TitleField )
{
	begin {
		$service = New-WebServiceProxy (Get-WebServiceURL -url $url) -Namespace List -UseDefaultCredential
		$listItem = [String]::Empty
	}
	process {

		$xml = @"
			<Batch OnError='Continue' ListVersion='1' ViewName='{0}'>  
				<Method ID='{1}' Cmd='Update'>
				<Field Name='ID'>{1}</Field>
					{2}
				</Method>  
			</Batch>  
"@   

		$listInfo = $service.GetListAndView($list, "")   

		foreach ($key in $item.Keys) {
			$value = $item[$key]
			if( -not [String]::IsNullOrEmpty($TitleField) -and $key -eq $TitleField ) {
				$key = "Title"
			}
			$listItem += ("<Field Name='{0}'>{1}</Field>`n" -f $key,[system.net.webutility]::htmlencode($value))  
		}   
  
		$xml = ($xml -f $listInfo.View.Name,$id, $listItem)
  
		#Write-Host "XML output - $($xml) ..."
  
		$batch = [xml] $xml
		try { 		
			$response = $service.UpdateListItems($listInfo.List.Name, $batch)   
			$code = [int]$response.result.errorcode   
	
			if ($code -ne 0) {   
				Write-Warning "Error $code - $($response.result.errortext)"     
			} 
		}
		catch [System.Exception] {
			Write-Error ("Update failed with - " +  $_.Exception.ToString() )
		}
	}
	end {
		
	}
}

function Get-MOSSProfileDetails([string]$SiteURL, [string]$UserLogin) 
{ 
    [Void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server.UserProfiles")

    $site = Get-SPSite - url $SiteURL

    $srvContext = [Microsoft.Office.Server.ServerContext]::GetContext($site) 
    Write-Host "Status", $srvContext.Status 
    $userProfileManager = new-object Microsoft.Office.Server.UserProfiles.UserProfileManager($srvContext) 

    Write-Host "Profile Count:", $userProfileManager.Count 

    $UserProfile = $userProfileManager.GetUserProfile($UserLogin) 

    #Basic Data 
    Write-Host "SID :", $UserProfile["SID"].Value 
    Write-Host "Name :", $UserProfile["PreferredName"].Value 
    Write-Host "Email :", $UserProfile["WorkEmail"].Value 

    #Detailed Data 
    Write-Host "Logon Name :", $UserProfile["AccountName"].Value 
    Write-Host "SID :", $UserProfile["SID"].Value 
    Write-Host "Name :", $UserProfile["PreferredName"].Value 
    Write-Host "Job Title :", $UserProfile["Title"].Value 
    Write-Host "Department :", $UserProfile["Department"].Value 
    Write-Host "SIP Address :", $UserProfile["WorkEmail"].Value 
    Write-Host "Picture :", $UserProfile["PictureURL"].Value 
    Write-Host "About Me :", $UserProfile["AboutMe"].Value 
    Write-Host "Country :", $UserProfile["Country"].Value

    $site.Dispose() 
} 

function Get-SSPSearchContext( )
{
	$context = [Microsoft.Office.Server.ServerContext]::Default
 	$searchContext = [Microsoft.Office.Server.Search.Administration.SearchContext]::GetContext($context)
	$content = [Microsoft.Office.Server.Search.Administration.Content]$searchContext
	
	return $content
}

function Get-SSPSearchContentSources ( )
{
 	return $(Get-SSPSearchContext).ContentSources
}

function Start-SSPFullCrawl( [String] $name, [switch] $force )
{
	$idle = [Microsoft.Office.Server.Search.Administration.CrawlStatus]::Idle
	
	$ContentSource = Get-SSPSearchContentSources | where { $_.Name -eq $name }
	
	if( $force ) 
	{
		Stop-SSPCrawl -name $name
	}
	
	if( $ContentSource.CrawlStatus -eq $idle ) 
	{
		$ContentSource.StartFullCrawl()
	} else {
	 	throw "Invalid Crawl state - " +  $ContentSource.CrawlStatus
	}
}

function Stop-SSPCrawl( [String] $name )
{
	$idle = [Microsoft.Office.Server.Search.Administration.CrawlStatus]::Idle
	
	$ContentSource = Get-SSPSearchContentSources | where { $_.Name -eq $name }
	
	if( $ContentSource.CrawlStatus -ne $idle ) 
	{
		$ContentSource.StopCrawl()
	} 
	
	$count = 0
	while ( $ContentSource.CrawlStatus -ne $idle -or $count -eq 30 )
	{
		sleep -Seconds 1
		$count++
	} 

	if( $ContentSource.CrawlStatus -ne "Idle" )
	{
		throw "Invalid Crawl State. Crawl should be idle but is not"
	}
}
function Get-CrawlHistory
{
    $serverContext = [Microsoft.Office.Server.ServerContext]::Default
    $searchContext = [Microsoft.Office.Server.Search.Administration.SearchContext]::GetContext($serverContext)
    
	return ( [Microsoft.Office.Server.Search.Administration.CrawlHistory]$searchContext )
}

function Get-LastCrawlStatus( [String] $name )
{
	$history = Get-CrawlHistory	
	$contentSource = Get-SSPSearchContentSources | where { $_.Name -eq $name } 
	return ( $history.GetLastCompletedCrawlHistory($contentSource.Id) | Select CrawlId, @{Name="CrawlTimeInHours";Expression={($_.EndTime - $_.StartTime).TotalHours}}, EndTime, WarningCount, ErrorCount, SuccessCount )
}
 
function Get-FullCrawlAverage( [string] $name, [int] $days = 7)
{
	$history = Get-CrawlHistory
	$contentSource = Get-SSPSearchContentSources | where { $_.Name -eq $name } 
	return $history.GetNDayAvgStats($contentSource, 1, $days)
}

function Set-SPReadOnly ([bool] $state )
{
	begin{
	}
	process{
		Write-Host "Setting Read-Only flag on Site Collection " $_.ToString() " to " $state
		$site = Get-SPSite -url $_.ToString()
		$site.ReadOnly = $state
		$site.Dispose()
	}
	end{
	}
}

function Get-SPAudit( ) 
{	
	param(
		[Object] $obj
	)
	begin{
		
	}
	process{
		$flags = $_.Audit.AuditFlags.value__
		$Audit = ""
			
		$auditTypes.Keys.GetEnumerator() | % {
			if( $auditTypes[$_] -band $flags )
			{
				$Audit += $_ + "|"
			}
		}
		if( $Audit -eq "" ) { $Audit = "No Audits Set" }
		
		$a = new-object System.Object
		$a | add-member -type NoteProperty -name "SiteName" -value $_.RootWeb.Title
		$a | add-member -type NoteProperty -name "URL" -value $_.RootWeb.ServerRelativeURL
		$a | add-member -type NoteProperty -name "Audit" -value $Audit.TrimEnd("|")
		
		return $a
	}
	end {
	}
}

function Get-SPWebApplication( [string] $name )
{
	$WebServiceCollection = new-object microsoft.sharepoint.administration.SpWebServiceCollection( Get-SPFarm )
	$WebServiceCollection | % { $WebApplications += $_.WebApplications }
	
	return ( $webApplications | where { $_.Name.ToLower() -like "*"+$name.ToLower()+"*" } | select -Unique )
}

function Get-SPFarm()
{
	return [microsoft.sharepoint.administration.spfarm]::local
}
function Get-SPSite ( [String] $url )
{
	return new-object Microsoft.SharePoint.SPSite($url)
}

function Get-SPSiteCollections( [Object] $webApp )
{
	return ( $webApp.Sites )
}

function Get-SPWebCollections( [Object] $sc )
{
	return ( $sc.AllWebs )
}

function Get-SPWeb( [String] $url )
{
	$site = new-object Microsoft.SharePoint.SPSite($url)
	return ( $site.OpenWeb() )
}

function UploadTo-Sharepoint {
	param ( 
		[string] $lib,
		[string] $file
	)

	$wc = new-object System.Net.WebClient
	$wc.Credentials = [System.Net.CredentialCache]::DefaultCredentials
	$uploadname = $lib + $(split-path -leaf $file)
	$wc.UploadFile($uploadname,"PUT", $file) 
}

function Update-SPListEntry([String] $url, [string] $list, [int] $entryID, [HashTable] $entry)
{
	$web = Get-SPWeb -url $url
	
	$splist = $web.Lists[$list]	
	$item = $splist.GetItemByID($entryID)
	
	$entry.Keys.GetEnumerator() | % {
		$item[$_] = $entry[$_]
	}
	
	$item.Update()
	$web.Dispose()
}

function Add-ToSPList ( [String] $url, [string] $list, [HashTable] $entry)
{
	$web = Get-SPWeb -url $url
	
	$splist = $web.Lists[$list]
	$newitem = $splist.items.Add() 

	$entry.Keys.GetEnumerator() | % {
		$newitem[$_] = $entry[$_]
	}
	
	$newitem.update() 
	$web.Dispose()
}

function Get-SPList ( [string] $url, [string] $list, [string] $filter="all")
{
	begin{
		$rtList = @()
		$web = Get-SPWeb -url $url
		$splist = $web.Lists[$list]

		$Fields = $splist.Fields | where { $_.Hidden -eq $false } | Select Title -Unique
	}

	process{
		$ErrorActionPreference = "silentlycontinue"
		$i=0
		$splist.Items | % {
			$item = $_
			write-progress -activity "Searching List" -status "Progress:" -percentcomplete ($i/$splist.Items.Count*100)
			$t = new-object System.Object
			$Fields | % {
				$t | add-member -type NoteProperty -name $_.Title.ToString() -value $item[$_.Title]
			}
			$i++ 	
			$rtList += $t
		}
		
		$web.Dispose()
	}
	end {
		if( $filter -eq "all" ) 
		{
			return $rtList
		} else 
		{
			$key,$value = $filter.Split(":")
			return ( $rtList | where { $_.$key -like $value } )
		}
	}
}

function Remove-SPGroupRole( [object] $role )
{
	$role.RoleDefinitionBindings | % { 
		Write-Host "Removing " $_.ToString()
		$role.RoleDefinitionBindings.Remove($_) 
	}
	$role.Update()
}

function Remove-AllSPGroupFromSite( [String] $url )
{
	$web = Get-SPWeb -url $url
	$siteGroups = $web.RoleAssignments
	$web.RoleAssignments | % { remove-spGroupRole( $_ ) }
}

function Get-SPGroup( [String] $Url, [string] $GroupName ) 
{
	$web = Get-SPWeb -url $url
	$siteGroups = $web.SiteGroups
	
	return ( $siteGroups | where { $_.Name -like $GroupName } )
}
	
function Get-SPUser ( [String] $url, [string] $User ) 
{
	$web = Get-SPWeb -url $url
	if( $user.Contains("\") ) { $loginName = $user } else { $loginName = "*\$user" }
	return ( $web.AllUsers | where { $_.LoginName -like $loginName } )
}

function Add-SPGroupPermission( [String] $url, [string] $GroupName, [string] $perms)
{
	$web = Get-SPWeb -url $url
	
	$spRoleAssignment = New-Object Microsoft.SharePoint.spRoleAssignment((Get-spGroup -url $web -GroupName $groupName))
	$spRoleDefinition = $web.RoleDefinitions[$perms]
	
	$spRoleAssignment.RoleDefinitionBindings.Add($spRoleDefinition)
	$web.RoleAssignments.Add($spRoleAssignment)
	$web.Update()
	
	$web.Dispose()
}

function Add-MemberToSPGroup (  [String] $url, [string] $LoginName , [string] $GroupName) 
{
	$web = Get-SPWeb -url $url
	$spGroup = Get-spGroup -url $web -GroupName $GroupName
	$spGroup.Users.Add($LoginName,$nul,$nul,$nul)
	
	$web.Dispose()
}

function Add-SPUser( [string] $url, [string] $User )
{
	$web = Get-SPWeb -url $url

	$spRoleAssignment = New-Object Microsoft.SharePoint.spRoleAssignment($User, $nul, $nul, $nul)
	$spRoleDefinition = $web.RoleDefinitions["Read"]
	
	$spRoleAssignment.RoleDefinitionBindings.Add($spRoleDefinition)
	$web.RoleAssignments.Add($spRoleAssignment)
	
	$web.Update()
	$web.Dispose()
}

function Add-SPGroup( [string] $url, [string] $GroupName, [string] $owner, [string] $description)
{
	$web = Get-SPWeb -url $url
	$siteGroups = $web.SiteGroups
	
	$spUser = Get-spUser -Url $web -User $owner 
	if( $spUser -eq $null ) { 
		add-spUser -SiteCollectionUrl $SiteCollectionUrl -User $owner 
		$spUser = Get-spUser -Url $web -User $owner 
	}
		
	$rtValue = $siteGroups.Add( $GroupName, $spUser, $spUser, $description)
	
	$web.Dispose()
}

function Add-SPWeb([string] $url, [string]$WebUrl, [string]$Title, [string]$Description, [string]$Template, [bool] $Inherit) 
{
    # Create our SPSite object
    $spsite = Get-SPSite $url

	# Add a site
    $web = $spsite.Allwebs.Add($WebUrl, $Title, $Description ,[int]1033, $siteTypes.Item($Template), $Inherit, $false)
	
	$spsite.Dispose()
	
	return $web	
}

function Set-AccessRequestEmail([String] $url, [string] $email)
{
	$web = Get-SPWeb -url $url
	$web.RequestAccessEmail = $email
	$web.RequestAccessEnabled = $true
	$web.Update()
	$web.Dispose()
}

function Set-Inheritance( [String] $url, [bool] $unique)
{
	$web = Get-SPWeb -url $url
	$web.HasUniquePerm = $unique
	$web.Update()
	$web.Dispose()
}

function Set-SharedNavigation( [String] $url, [bool] $shared)
{
	$web = Get-SPWeb -url $url
	$web.Navigation.UseShared = $shared
	$web.Update()
	$web.Dispose()
}

function Set-spAssociatedGroups( [String] $url, [string] $owners, [string] $members, [string] $visitors)
{
	$web = Get-SPWeb -url $url
	$web.AssociatedOwnerGroup = Get-spGroup -url $web -GroupName $owners
	$web.AssociatedMemberGroup = Get-spGroup -url $web -GroupName $members
	$web.AssociatedVisitorGroup = Get-spGroup -url $web -GroupName $visitors
	$web.Update()
	$web.Dispose()
}
function Get-LookupFieldData
{
param
(
[String] $field
)
	$fieldarray = $field.split(";")
	[String[]] $out = @()
			$re = [regex]'^#\D'
            Foreach($fieldline in $fieldarray)
			{
                if ($re.Match($fieldline.toString()).success -eq $true)
				{
					$out += $fieldline.substring(1,($fieldline.length -1))
				}
			}
	
	return $out
}
Function Get-Servers
{
param
(
[String] $env = $(throw 'Please Enter an environment'),
[String[]] $exclude,
[String] $list = "Web"
)
Switch ($list)
{
"Web"{
		$view = '''{8B5CF22A-914F-47DE-9722-133CCFBAF14C}'''
		$listurl = '''http://teamadmin.gt.com/sites/ApplicationOperations/applicationsupport/'''
		$listname = '''appservers'''
	}

}
$filter = '$_.Updates -eq ''1'' -and $_.Environment -eq '''+$env+'''' 
if ($exclude -ne $null)
{
foreach ($ex in $exclude)
{
$filter = $filter+' -and $_.Application -notlike ''*'+$ex+''''
}

}
$exclusion = $executioncontext.invokecommand.NewScriptBlock($filter)
$appinfo = Get-SPListViaWebService -url $listurl -list $listname -view $view  | Where  [ScriptBlock]::Create($filter)  
if ($exclude -ne $null)
{
foreach ($ex in $exclude)
{
$filter = $filter+' -and $_.Application -notlike ''*'+$ex+''''
}
}
$a = @()
$b = @()
Foreach ($server in $appinfo)
{
if (-not (ping $server."SystemName"))
{
$a += $server
}
else
{
$application = Get-LookupFieldData -field $server.Application
$b += $server.SystemName+","+$application
}
$a | out-file ".\NoLongerAlive.txt"
$b | Out-File ".\ServerstoPatch.txt"
}
}


Function new-ListObject {
New-Object PSObject -Property @{
         SPWEbList = ''
         SPDocumentType = ''
		 SPPSize = ''
		 SPCSize = ''
}
}
Function Audit-SPList
{
param(
[string] $basesite,
[int] $samplesize,
[string] $sourcecsv

)
Add-PSSnapin Microsoft.Sharepoint.Powershell
$x = Import-Csv $sourcecsv
$y = 1
$length = $x.count
$rand = New-Object System.Random
$splistcollection = @()
$webs = @()
while ($y -le $samplesize)
{
$sitename = $x[$rand.Next(0,$length+1)].url 
Write-Host "Sample Number: "$y
Write-Host "Now Sampling" $sitename
$site = Get-SPSite ($basesite+$sitename) #http://team-uat.gt.com/sites/appops
$webs = $site.allwebs | ? {$_.serverrelativeURL -match "(/sites/)([\w\d\-_]*)([\w\d\-_]*)"} | select serverrelativeurl
if (($webs | measure-object | Select -ExpandProperty count) -eq 1)
#if ([String]::IsNullOrEmpty($matches[3]))
{
   Write-Host "The client has 0 webs"
   $weblist = Get-SPWeb ($basesite+$webs.serverrelativeurl)
    Write-Host "now Processing: "$weblist.Url
    $list = $weblist.lists["Document Library"]
    Write-Host "Item count: "$list.items.count
    if ($list.items.count -ne 0)
    {
        foreach ($listitem in $list.items){
            write-host "Creating List Items"
            #$listitem
            $splistitem = new-ListObject
            $splistitem.SPWebList = $web.serverrelativeurl
            #$listitem.name
            $doctype = $listitem.name -match "(\.\w*$)"
            $splistitem.SPDocumentType = $matches[0]
            $splistitem.SPPSize = [math]::Round(($listitem.file.length/1MB),2) 
            $compare = $listitem.file.length/1MB
            if ($compare -lt 1) { 
                $splistitem.SPCsize = "S"
            }
            if (($compare -gt 1) -and ($compare -lt 10)) { 
                $splistitem.SPCsize = "M"
            }
            if ($compare -gt 10) { 
                $splistitem.SPCsize = "L"
            }
            #$splistitem
            $splistcollection += $splistitem
        } 
    #$splistcollection += $splistitem
    } 
}
else
{
Write-Host "This Client Has this many Webs:"$webs.count
foreach ($web in $webs){
    #Write-host "Web:"$web.serverrelativeurl
    $checkroot = $web.serverrelativeURL -match "(/sites/)([\w\d\-_]*)(/[\w\d\-_]*)"
    #$checkroot
    
    if (-not([String]::IsNullOrEmpty($matches[3])))  
    {
       
        $weblist = Get-SPWeb ($basesite+$web.serverrelativeurl)
        Write-Host "now Processing: "$weblist.Url
        $list = $weblist.lists["Document Library"]
        Write-Host "Item count: "$list.items.count
        if ($list.items.count -ne 0)
        {
            foreach ($listitem in $list.items){
                write-host "Creating List Items"
                #$listitem
                $splistitem = new-ListObject
                $splistitem.SPWebList = $web.serverrelativeurl
                #$listitem.name
                $doctype = $listitem.name -match "(\.\w*$)"
                $splistitem.SPDocumentType = $matches[0]
                $splistitem.SPPSize = [math]::Round(($listitem.file.length/1MB),2) 
                $compare = $listitem.file.length/1MB
                if ($compare -lt 1) { 
                    $splistitem.SPCsize = "S"
                }
                if (($compare -gt 1) -and ($compare -lt 10)) { 
                    $splistitem.SPCsize = "M"
                }
                if ($compare -gt 10) { 
                    $splistitem.SPCsize = "L"
                }
                #$splistitem
                $splistcollection += $splistitem
            } 
            #$splistcollection += $splistitem
        }
    }
    else
    {
    Write-Host "The following site is a root site no proccessing done:"$web.serverrelativeURL
    }
}

}
$y++
}
return $splistcollection
}


Function get-restoreinfo
{
param
(
 $sitename,
 [switch] $extend
)
$found = $false
$a = Import-Csv \\cdc-spa-p09\d$\logs\sharepoint2010_sitecollections.csv | ? {$_.URL -eq $sitename}
if ($a.count -eq 0)
{
    write-host "Site is not in Current Archive Log"
    $files = gci \\cdc-spa-p09\d$\logs\sitecollection-archive\ | sort LastWriteTime -Descending
    $x = 0
    
	while ($stop -ne $true)
    { 
        if ($x -ne 14)
        {  
            Write-host "Checking" $files[$x].FullName 
            $a = Import-Csv $files[$x].FullName | ? {$_.URL -eq $sitename}
            if ($a.count -ne 0)
            {
                $stop = $true
				$found = $true
			}
            $x++
        }
        else
        {
            $stop=$true
			$found = $false
            Write-Host " Site not found in Archives"
        }

    }
	if ($found -ne $true)
	{
		Write-Host "Checking older archives"
		$stop=$false
        $files = gci \\cdc-nas-fs01\EntAppData\WGC\Logs\CDC-SPA-P09\Extracted\ | sort LastWriteTime -Descending
        $x = 0
        #$x = $files.count-1
        Write-host $x
        while ($stop -ne $true)
        {
        if ($x -lt ($files.count-1))
        {  
            Write-host "Checking" $files[$x].FullName 
            $a = Import-Csv $files[$x].FullName | ? {$_.URL -eq $sitename}
            if ($a.count -ne 0)
            {
                $stop = $true
				$found = $true
			}
            $x++
        }
        else
        {
            $stop=$true
			$found = $false
            Write-Host " Site not found in Archives"
        }

        }

    }
		
 }
 else
 {
    $current = $true
 }
 if ($a.count -ne 0)
    {
        $date = $a.LastItemModifiedDate
        if ($current)
		{
			write-host ("Please request the backup from: "+(gci "\\cdc-spa-p09\d$\logs\sharepoint2010_sitecollections.csv").LastWriteTime)
		}
		else
		{
			Write-Host "Please restore the backup file to \\cdc-spb-p01\restore"
			write-host "Please request the backup from: " $files[($x-1)].LastWriteTime
        }
		write-host "But no older than: " $a.LastItemModifiedDate
        $instance = $a.DatabaseInstance -match "(\d)$"
        Write-host ('From Instance: CDC-SPD-C02i'+$matches[0])
        Write-Host "Content Database: "$a.Database
        Write-Host "For Restore of:" $a.URL
 }
 }