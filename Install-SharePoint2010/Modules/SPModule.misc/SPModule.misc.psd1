#
# Module manifest for module 'SPModule.misc'
#
# Generated on: 29-Sep-2009
#

@{

# Script module or binary module file associated with this manifest
ModuleToProcess = ''

# Version number of this module.
ModuleVersion = '1.1'

# ID used to uniquely identify this module
GUID = '1f2b0eba-7733-42e6-b220-fa78e9ab0e46'

# Author of this module
Author = 'Microsoft Corporation'

# Company or vendor of this module
CompanyName = 'Microsoft Corporation'

# Copyright statement for this module
Copyright = '(c) 2009 Microsoft Corporation. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Module for use with miscallaneous tasks'

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
RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module
ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = @()

# Modules to import as nested modules of the module specified in ModuleToProcess
NestedModules = @('registry_access.psm1',
                  'Install-Assembly.ps1',
                  'thread_options.psm1',
                  'Test-ElevatedProcess.ps1',
                  'Compress-Files.psm1',
                  'Collect-Logs.ps1',
                  'Test-SPModuleVersion.ps1')

# Functions to export from this module
FunctionsToExport = 'Get-RegistryKey',
                    'Set-RegistryKey',
                    'Install-Assembly',
                    'Get-ThreadOptions',
                    'Set-ThreadOptions',
                    'Test-ElevatedProcess',
                    'Compress-ToZip',
                    'Backup-Logs',
                    'Test-SPModuleVersion'

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

