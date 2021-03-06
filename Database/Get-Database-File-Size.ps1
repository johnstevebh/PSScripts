[CmdletBinding(SupportsShouldProcess=$true)]
param ( 
	[Parameter(Mandatory=$true)]	
    [string] $instance
)

$current_dir = $PWD.Path

. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
Import-Module sqlps -EA Stop -DisableNameChecking

cd $current_dir

$query = "sp_helpfile"

function main
{
    $dbs = @()

	$sql = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -Argument $instance
			
    foreach( $database in $sql.Databases ) {
        $files = Invoke-Sqlcmd -ServerInstance $instance -Database $database.Name -Query $query
        foreach( $file in $files ) {
            $dbs += ( New-Object PSObject -Property @{
                File = $file.name
                Database = $database
                Path = $file.filename
                Size = [math]::round( $file.size.Split(" ")[0] / 1kb, 2)
            })
        }    		
    }
    
    return $dbs	
} 
main
