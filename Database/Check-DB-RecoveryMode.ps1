param(
    [string] $servers
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

$sql = "Select name, recovery_model_desc as [recovery mode] from sys.databases"

foreach ( $instance in $servers )
{
	Write-Host "Checking $instance ..." -fore green
	Query-DatabaseTable -server $instance -dbs master -sql $sql
}