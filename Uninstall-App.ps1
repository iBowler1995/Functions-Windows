function Uninstall-App {

    <#
		.DESCRIPTION
		This function will search the registry for an uninstall string and invoke it - may not work if native uninstall command is 'msiexec /i{}' instead of 'msiexec /x{}'
		.PARAMETER App
		This parameter is required and specifies the target app to be removed - use name as displayed in Apps & Features
		.PARAMETER Argument
        This parameter is option and allows you to add extra arguments to the uninstall command
        .EXAMPLE
        Uninstall-App -App 'Adobe Acrobat DC (64-bit)' <--- This will find and call the native uninstall command for the app
        Uninstall-App -App 'Adobe Acrobat DC (64-bit)' -Argument '/qn' <--- This will find the native unisntall command, add the arguments, and invoke the command
		
	#>

    [CmdletBinding()]
    param (
    [Parameter(Mandatory = $True)]
    [String]$App,
    [Parameter()]
    [String]$Argument
)
$paths = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
$Test = Get-ItemProperty $paths | where {$_.DisplayName -eq $App} | select -expand UninstallString
If ($Test -eq $Null){
Write-Host "App not found."
}
else{
    Try {

        $UninstallString = "$Test /quiet /norestart"

    }
    catch {



    }
}
}
