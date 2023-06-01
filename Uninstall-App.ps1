function Uninstall-App {

    <#
		.DESCRIPTION
		This function will search the registry for an uninstall string and invoke it - may not work if native uninstall command is 'msiexec /i{}' instead of 'msiexec /x{}'
		.PARAMETER App
		This parameter is required and specifies the target app to be removed - use name as displayed in Apps & Features
		.PARAMETER Argument
        This parameter is option and allows you to add extra arguments to the uninstall command
        .EXAMPLE
        Uninstall-App -Name 'Adobe Acrobat DC (64-bit)' <--- This will uninstall Adobe Acrobat
		
	#>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '', Scope='Function')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSPossibleIncorrectComparisonWithNull', '', Scope='Function')]
    [CmdletBinding()]
    param (

    [Parameter(Mandatory = $True)]
    [String]$Name
    
)
$paths = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
$Test = Get-ItemProperty $paths | where {$_.DisplayName -like "*$Name*"}

If ($Test -eq $Null){

    Write-Host "App not found."

    }
else{

    $App = Get-WmiObject -Class Win32_Product | ? {$_.Name -like "*$Name*"}
    $App.Uninstall()

    }
}
