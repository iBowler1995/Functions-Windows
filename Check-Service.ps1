function Check-Service {

    [cmdletbinding()]
    param(
        [parameter()]
        [String]$Name,
        [Parameter()]
        [Switch]$Report,
        [parameter()]
        [String]$From,
        [Parameter()]
        [String]$To,
        [Parameter()]
        [String]$Server,
        [Parameter()]
        [String]$Port
    )

    If ($Report){

        $CredsExist = Test-Path '.\Creds.xml'
        If ($CredsExist -eq $False){

            Write-Host "Please enter email credentials..."
            $Creds = Get-Credential
            $Creds | Export-CliXml -Path '.\Creds.xml' -Force
            $Credential = Import-CliXml -Path '.\Creds.xml'

        }
        else{

            $Credential = Import-CliXml -Path '.\Creds.xml'

        }
        $Services = Get-Service | where {($_.DisplayName -like "$Name*") -and ($_.Status -ne 'Running')}
        foreach ($Service in $Services) {
        
            While ($Service.Status -ne 'Running') {

                Start-Service $Service
                $Service.Refresh()

                If ($Service.Status -eq 'Running') {

                    $Subject = "$($Service.DisplayName) failure on $Env:Computername"
                    $Body = "$($Service.DisplayName) service successfully restarted."
                    Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -SMTPServer $Server -Port $Port -Credential $Credential -UseSSL

                }
                else {

                    Start-Service $Service
                    $Service.Refresh()

                    If ($Service.Status -eq 'Running'){

                        $Subject = "$($Service.DisplayName) failure on $Env:Computername"
                        $Body = "$($Service.DisplayName) service successfully restarted."
                        Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -SMTPServer $Server -Port $Port -Credential $Credential -UseSSL

                    }
                    else {

                        $Subject = "$($Service.DisplayName) failure on $Env:Computername"
                        $Body = "$($Service.DisplayName) service restart failed. Please investigate on server."
                        Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -SMTPServer $Server -Port $Port -Credential $Credential -UseSSL

                    }

                }

            }
        
        }

    }
    else {

        $Services = Get-Service | where {($_.DisplayName -like "$Name*") -and ($_.Status -ne 'Running')}
        foreach ($Service in $Services) {
        
            While ($Service.Status -ne 'Running') {

                Start-Service $Service
                $Service.Refresh()

                If ($Service.Status -eq 'Running') {

                    Write-host "Fixed!"

                }
                else {

                    Start-Service $Service
                    $Service.Refresh()

                    If ($Service.Status -eq 'Running'){

                        Write-Host "Fixed!"

                    }
                    else {

                        Write-Host "Not fixed."

                    }

                }

            }
        
        }

    }

}