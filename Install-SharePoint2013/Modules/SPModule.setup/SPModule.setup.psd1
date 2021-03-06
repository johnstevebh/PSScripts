#
# Module manifest for module 'SPModule.setup'
#
# Generated on: 29-Sep-2009
#

@{

# Script module or binary module file associated with this manifest
ModuleToProcess = ''

# Version number of this module.
ModuleVersion = '1.1'

# ID used to uniquely identify this module
GUID = '5df347a7-f3e1-4f2a-acd8-5c8a405aa103'

# Author of this module
Author = 'Microsoft Corporation'

# Company or vendor of this module
CompanyName = 'Microsoft Corporation'

# Copyright statement for this module
Copyright = '(c) 2009 Microsoft Corporation. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Module for use with setup tasks for SharePoint'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '2.0'

# Name of the Windows PowerShell host required by this module
PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
PowerShellHostVersion = ''

# Minimum version of the .NET Framework required by this module
DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module
CLRVersion = ''

# Processor architecture (None, X86, Amd64, IA64) required by this module
ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @('SPModule.misc')

# Assemblies that must be loaded prior to importing this module
RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module
ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = @()

# Modules to import as nested modules of the module specified in ModuleToProcess
NestedModules = @('Enable-VerboseMSILogging.ps1',
                  'Install-SharePoint.ps1',
                  'New-SharePointFarm.ps1',
                  'Join-SharePointFarm.ps1',
                  'setup_workarounds.psm1',
                  'Start-CentralAdministration.ps1',
                  'New-SharePointServices.ps1')

# Functions to export from this module
FunctionsToExport = 'Disable-OfficeSigningCheck',
                    'Disable-SQLSigningCheck',
                    'Disable-AllSigningCheck',
                    'Enable-VerboseMSILogging',
                    'Install-SharePoint',
                    'New-SharePointFarm',
                    'Start-CentralAdministration',
                    'Get-SharePointResources',
                    'Join-SharePointFarm',
                    'New-SharePointServices'

# Cmdlets to export from this module
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = ''

# Aliases to export from this module
AliasesToExport = ''

# List of all modules packaged with this module
ModuleList = @()

# List of all files packaged with this module
FileList = @()

# Private data to pass to the module specified in ModuleToProcess
PrivateData = ''

}

