function Update-Hosts { <#
    IMPORTANT:
    ===========================================================================
    This script is provided 'as is' without any warranty. Any issues stemming 
    from use is on the user.
    ===========================================================================
    .DESCRIPTION
    Updates Hosts file based on txt file with entries
    ===========================================================================
    .PARAMETER Path
    REQUIRED - Path to txt file
    ===========================================================================
    .EXAMPLE
     Update-Hosts -Path C:\Temp\IPs.txt <--- This adds any entries from C:\Temp\IPs.txt to the Hosts file
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $TRUE)]
    [String]$Path
)

$Hosts = "C:\Windows\System32\Drivers\etc\hosts"
$UpdateHosts = "$Env:Temp\HostsUpdate.txt"
$GetUpdates = Get-Content $UpdateHosts
foreach ($Update in $GetUpdates) {
$Update | Out-File $Hosts -Encoding Ascii -Append
}

If ((Get-Content -Path $Hosts) | select-String "10.100.110.72") {
exit 0
}
else { 
exit 1
}



}