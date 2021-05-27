﻿<#
.SYNOPSIS
PushScriptingAgentConfig.ps1

.DESCRIPTION 
Copies the ScriptingAgentConfig.xml file to all Exchange servers in the organization.

.OUTPUTS
Results are output to screen.

.PARAMETER Verbose
See more detailed information about progress and errors/warnings.

.EXAMPLE
.\PushScriptingAgentConfig.ps1

.LINK
http://exchangeserverpro.com/powershell-script-distribute-scripting-agent-configuration-file-exchange-servers

.NOTES
Written by: Paul Cunningham

Find me on:

* My Blog:	https://paulcunningham.me
* Twitter:	https://twitter.com/paulcunningham
* LinkedIn:	https://au.linkedin.com/in/cunninghamp/
* Github:	https://github.com/cunninghamp

Change Log
V1.00, 9/01/2014 - Initial version
#>

#requires -version 2

[CmdletBinding()]

param ()

#...................................
# Initialize
#...................................

#Add Exchange snapin if not already loaded
if (!(Get-PSSnapin | where {$_.Name -eq "Microsoft.Exchange.Management.PowerShell.E2010"}))
{
	Write-Verbose "Loading the Exchange 2010 snapin"
	try
	{
		Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010 -ErrorAction STOP
	}
	catch
	{
		#Snapin not loaded
		Write-Warning $_.Exception.Message
		EXIT
	}
	. $env:ExchangeInstallPath\bin\RemoteExchange.ps1
	Connect-ExchangeServer -auto -AllowClobber
}

$exchangeservers = Get-ExchangeServer

$report = @()

[string]$date = Get-Date -F yyyyMMdd-HHmmss


foreach ($srv in $exchangeservers)
{
    $server = $srv.Name
    
    Write-Verbose "------ Processing $server"
    
    if ($srv.AdminDisplayVersion -match "Version 14") {$ver = "V14"}
    if ($srv.AdminDisplayVersion -match "Version 15") {$ver = "V15"}

    $installpath = $null
    $uncpath = "n/a"
    $reg = $null
    $renameresult = "n/a"
    $copyresult = "n/a"
    $filecheckresult = "n/a"

	try {
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey("LocalMachine",$server)
    }
    catch
    {
        Write-Warning $_.Exception.Message
        $installpath = "Unable to connect to registry"
        Write-Verbose "Unable to connect to registry"
    }

    if ($installpath -eq $null)
    {

	    $installpath = $reg.OpenSubKey("SOFTWARE\Microsoft\ExchangeServer\$ver\Setup").GetValue("MsiInstallPath")
        Write-Verbose "Install path is $installpath"

        $uncpath = "\\$server\" + ($installpath -replace(":","$")) + "Bin\CmdletExtensionAgents\ScriptingAgentConfig.xml"
        Write-Verbose "UNC path is $uncpath"

        #Check if XML file already exists
        $fileexists = Test-Path $uncpath

        #Backup file if it already exists
        if ($fileexists)
        {
            Write-Verbose "File already exists on target server"
            try {
                Rename-Item $uncpath ScriptingAgentConfig.xml.$date -ErrorAction STOP
                $renameresult = "Success"
                Write-Verbose "Rename of existing file successful"
            }
            catch
            {
                Write-Warning $_.Exception.Message
                $renameresult = "Failed"
                Write-Verbose "Rename of existing file failed"
            }
        }
        else
        {
            $renameresult = "n/a"
        }

        #Copy XML file to server
        Write-Verbose "Attempting copy of new file"
        try {
            Copy-Item ScriptingAgentConfig.xml $uncpath -ErrorAction STOP
            $copyresult = "Success"
            Write-Verbose "Copy successful"
        }
        catch
        {
            Write-Warning $_.Exception.Message
            $copyresult = "Failed"
            Write-Verbose "Copy failed"
        }

        #Final check to confirm file is on server
        $filecheck = Test-Path $uncpath
        switch ($filecheck) {
            "True" { $filecheckresult = "Found"}
            "False" { $filecheckresult = "Not found"}
            default { "Something went wrong"}
        }
    }
       
    $serverObj = New-Object PSObject
	$serverObj | Add-Member NoteProperty -Name "Server Name" -Value $server
	$serverObj | Add-Member NoteProperty -Name "Config UNC Path" -Value $uncpath
	$serverObj | Add-Member NoteProperty -Name "File Rename Result" -Value $renameresult
	$serverObj | Add-Member NoteProperty -Name "File Copy Result" -Value $copyresult
	$serverObj | Add-Member NoteProperty -Name "File Check Result" -Value $filecheckresult

    $report += $serverObj    

}

Write-Verbose "------ All servers completed"

$report
