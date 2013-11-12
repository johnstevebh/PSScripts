﻿param(
    [string] $web_site,
    [string] $path
)

Add-WindowsFeature DSC-Service
. (Join-Path $env:SCRIPTS_HOME "IIS_Funcstions.ps1")

Set-Variable -Name app_pool -Value "AppPool - DSC" -Option Constant

$settings = @(

if( !(Test-Path $path) ){ 
    mkdir $path
    mkdir (Join-Path $path "bin")
}

cp $pshome\modules\psdesiredstateconfiguration\pullserver\Global.asax $path -Verbose
cp $pshome\modules\psdesiredstateconfiguration\pullserver\PSDSCPullServer.mof $path -Verbose
cp $pshome\modules\psdesiredstateconfiguration\pullserver\PSDSCPullServer.svc $path -Verbose
cp $pshome\modules\psdesiredstateconfiguration\pullserver\PSDSCPullServer.xml $path -Verbose
cp $pshome\modules\psdesiredstateconfiguration\pullserver\PSDSCPullServer.config (Join-Path $path "web.config")
cp $pshome\modules\psdesiredstateconfiguration\pullserver\Microsoft.Powershell.DesiredStateConfiguration.Service.dll (Join-Path $path "bin")

Create-IISAppPool -apppool $app_pool -version v4.0

Create-IISWebSite -site $web_site -path $path
Set-IISAppPoolforWebSite -apppool $app_pool -site $web_site


cp $pshome/modules/psdesiredstateconfiguration/pullserver/devices.mdb $env:programfiles\WindowsPowerShell\DscService\ -Verbose

    $add.SetAttribute("key", $setting.Key)
    $add.SetAttribute("Value", $setting.Value )
    $cfg.Configuration.appSettings.AppendChild($add)