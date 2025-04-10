#Function declarations
function New-AutoRip {
[CmdletBinding()]
param (
    [ValidateSet("Movies", "TV")]
    [string]$MediaType,
    [string]$Device = ""
    )
    
    If ($MediaType -eq "Movies")
    {
        $ToDir = "E:\Media\Movies"
    }
    elseif ($MediaType -eq "TV"){

        $ToDir = "E:\Media\TV"

    }
    
    $DeviceID = ""
    $VolumeName = ""
    $Err = ""
    $MakeMKVPath = 'C:\Program Files (x86)\MakeMKV'
    #Generic test, in case somehow mediatype isn't set
    if(!(Test-Path $ToDir)) {
        $ToDir = Read-Host -Prompt "Please enter path to save files to"
    }
    $Dir1 = $ToDir
    $Dir1 = $Dir1 -replace '\\','/'
    if($Dir1[$Dir1.Length -1] -eq '/') {
        $Dir1 = $Dir1.Substring(0,$($Dir1.length-1))
    }
    if (!(Test-Path $MakeMKVPath\makemkvcon.exe)) {
        $MakeMKVPath = Read-Host 'What is your makemkvcon.exe folder path'
    }
    Write-Host "Welcome to autorip-v2."
    if(!($Device)) {
        $Device = Read-Host -Prompt "Please enter your drive letter. Example: D"
    }
    $X = 0
    try {

        # Grab WMI object
        $W = Get-WmiObject -Class Win32_LogicalDisk -Errorvariable MyErr -ErrorAction Stop | Where-Object {
           ($_.DeviceID -like "*$Device*") -and ($_.DriveType -eq 5)
        } | Select-Object DeviceID, DriveType, VolumeName
    
        #Begin RIP
        $DeviceID = $W.DeviceID
        $VolumeName = $W.VolumeName
        Write-Host 'Mounted successfully. Beginning process...'
        $Dir2 = $Dir1 + '/' + $VolumeName
        if(!(Test-Path $Dir2)){
            New-Item $Dir2 -Type Directory -Force
        }
          
        &"$MakeMKVPath\makemkvcon.exe" "--minlength=300" "mkv" "disc:0" "all" "$Dir2"
        Write-Host "Movie saved successfully to $dir2" -ForegroundColor Green
            

    }
    Catch [System.Exception] {

        Write-Error "Error ripping movie at line $($_.InvocationInfo.ScriptLineNumber): $_"
    }
    <#Finally {
        $FileList = Get-ChildItem "$Dir2/"
        $FileList | ForEach-Object {
            Write-Host $_.BaseName
        }
    }
    #>
}


function Convert-VideoWithCropFix {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MediaPath,

        [switch]$KeepOriginal
    )

    $ffmpeg = "C:\Program Files (x86)\ffmpeg\bin\ffmpeg.exe"
    $handbrake = "C:\Program Files\HandBrake\HandBrakeCLI.exe"

    if (!(Test-Path $MediaPath)) {
        Write-Error "File not found: $MediaPath"
        return
    }

    $file = Get-Item $MediaPath
    $outputPath = Join-Path $file.Directory "$($file.BaseName)-converted.mkv"

    Write-Host "Running cropdetect via ffmpeg..." -ForegroundColor Cyan

    $cropResult = & $ffmpeg -ss 00:00:30 -i "$MediaPath" -t 10 -vf cropdetect -an -sn -f null NUL 2>&1 |
        Select-String -Pattern "crop=" | Select-Object -Last 1

    if (-not $cropResult) {
        Write-Warning "Could not detect crop, using full frame"
        $cropTop = 0; $cropBottom = 0; $cropLeft = 0; $cropRight = 0
    } else {
        $cropText = ($cropResult -split "crop=")[1].Trim()
        # Example: crop=704:352:8:64
        $parts = $cropText -split ":"
        $cropWidth = [int]$parts[0]
        $cropHeight = [int]$parts[1]
        $cropX = [int]$parts[2]
        $cropY = [int]$parts[3]

        # Convert ffmpeg crop format to HandBrake format: top:bottom:left:right
        $cropTop = $cropY
        $cropBottom = 480 - $cropHeight - $cropY
        $cropLeft = $cropX
        $cropRight = 720 - $cropWidth - $cropX
    }

    Write-Host "Final crop: Top=$cropTop, Bottom=$cropBottom, Left=$cropLeft, Right=$cropRight"

    $args = @(
        "-i", "$MediaPath",
        "-o", "$outputPath",
        "--encoder", "x265",
        "--quality", "22",
        "--crop", "${cropTop}:${cropBottom}:${cropLeft}:${cropRight}",
        "--width", "854",
        "--height", "480",
        "--auto-anamorphic", "0",
        "--optimize",
        "--audio", "1",
        "--aencoder", "copy",
        "--subtitle", "1",
        "--markers"
    )

    Write-Host "Transcoding with HandBrakeCLI..."
    & $handbrake @args 2>&1 | Write-Host

    if ((Test-Path $outputPath) -and ((Get-Item $outputPath).Length -gt 0)) {
        if (-not $KeepOriginal) {
            Remove-Item $MediaPath -Force
            Write-Host "Original deleted. Final file: $outputPath" -ForegroundColor Green
        } else {
            Write-Host "Original preserved. Final file: $outputPath" -ForegroundColor Green
        }
    } else {
        Write-Warning "Transcoding failed. Original preserved."
    }

    Write-Host "============================="
}


<############################################################################################################################################
Ripping the DVD
#>

#Initialize $MediaType
$MediaType = $null

#Prompt user to select media type
do {
    Write-Host "What type of media are you ripping?"
    Write-Host "1. Movies"
    Write-Host "2. TV Show"

    #Capture user choice
    $choice = Read-Host "Enter 1 for Movies or 2 for TV Shows"

    switch ($choice) {
        "1" {
            $MediaType = "Movies"
            Write-Host "You selected Movie."
            $valid = $true
            cls
        }
        "2" {
            $MediaType = "TV"
            Write-Host "You selected TV Show."
            $valid = $true
            cls
        }
        default {
            Write-Host "Invalid choice. Please enter 1 for Movies or 2 for TV Show."
            $valid = $false
        }
    }
} while (-not $valid)

#Output the selected media type
Write-Host "Media type set to: $MediaType, beginning autorip..." -ForegroundColor Cyan

If ((Test-Path -path "C:\Temp\Ripper.log" -PathType Leaf)){

    Clear-Content "C:\Temp\Ripper.log"

}
Start-Transcript -Path "C:\Temp\Ripper.log"
#Begin Ripping
New-AutoRip -Device "F" -MediaType $MediaType
Write-Host "================"

<############################################################################################################################################
Transcoding
#>

#Filebot and transcoding variables
$FileBotPath = "C:/Program Files/FileBot/filebot.exe"
$WMI = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 5 }
$Volume = $WMI.VolumeName
$Input = "E:/Media/$MediaType/$Volume/"
$MainMovieFile = Get-ChildItem $Input -File | Sort-Object Length -Descending | Select-Object -First 1

#Transcoding the main movie
Try{

    Write-Host "Beginning transcoding for $($MainMovieFile.FullName)..." -ForegroundColor Cyan
    Convert-VideoWithCropFix -MediaPath $MainMovieFile.FullName

}
Catch{

    Write-Error "Error transcoding $($MainMovieFile.FullName) at line $($_.InvocationInfo.ScriptLineNumber): $_"

}

<############################################################################################################################################
Renaming and moving the main movie
#>

Try{

    $TranscodedFile = Join-Path $MainMovieFile.Directory "$($MainMovieFile.BaseName)-converted.mkv"
    Write-Host "Renaming item(s)..." -ForegroundColor Cyan
    & "$FileBotPath" -rename $TranscodedFile `
    --db TheMovieDB `
    --format "{n} ({y})/{n} ({y})" `
    --output "E:/Media/Movies" `
    --action move `
    --conflict index `
    --log all `
    --log-file "C:/temp/filebot.log" `
    -non-strict

    Write-Host "Successfully renamed item(s)!" -ForegroundColor Green

    #Grab the last line that includes [MOVE] and "to ["
    $logPath = 'C:\temp\filebot.log'
    $lastMoveLine = Get-Content $logPath | Where-Object { $_ -match '\[MOVE\].* to \[.*\]' } | Select-Object -Last 1

    #Extract the destination path and trim to the folder
    if ($lastMoveLine -match 'to \[(.*?)\]') {
        $fullFilePath = $matches[1]
        $RenamedFolder = Split-Path $fullFilePath -Parent
    } else {
        Write-Warning "No destination path found in line:`n$lastMoveLine"
    }

    Write-Host "Renamed folder is... $RenamedFolder"

}
Catch {
      
      Write-Error "Error renaming file(s) at line $($_.InvocationInfo.ScriptLineNumber): $_"

}

<############################################################################################################################################
Handling the extras
#>

#Variables for extras
#$RenamedFolder = Get-ChildItem "E:/Media/Movies" -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$Extras = Join-Path $RenamedFolder "extras"
$AllFiles = Get-ChildItem $Input -File
$counter = 1

#Create extras folder (if not exist) and move extras there (using the logic of extras should be <1gb)
Try{

    If (!(Test-Path $Extras)){

        Write-Host "No extras folder found, creating..." -ForegroundColor Yellow
        New-Item -Path $Extras -ItemType Directory -Force | out-null

    }
    foreach ($file in $AllFiles) {

        if ($file.Length -lt 700mb) {
        
            Write-Host "Moving extras file $counter..." -ForegroundColor Cyan
            Move-Item $file.FullName -Destination $Extras
            $counter++

        }

    }
    Write-Host "All extras files moved successfully!" -ForegroundColor Green
    Write-Host "================"

}
Catch{

    Write-Error "Error moving extras at line $($_.InvocationInfo.ScriptLineNumber): $_"

}

#Transcoding extras
Try{

    Write-Host "Transcoding extras..." -ForegroundColor Cyan
    $ExtraFiles = Get-ChildItem $Extras -File -Filter *.mkv
    foreach ($Extra in $ExtraFiles){

        Convert-VideoWithCropFix -MediaPath $Extra.FullName

    }
    Write-Host "Extras transcoded successfully!" -ForegroundColor Green

}
Catch{

        Write-Error "Error transcoding extras at line $($_.InvocationInfo.ScriptLineNumber): $_"

}

#Deleting original rip folder (MOVIE_TITLE)
$FolderContents = Get-ChildItem -Path $Input -Force -Recurse | Where-Object { $_.FullName -notmatch "\\extras\\" }
If (-not $FolderContents) {
    Remove-Item -Path $Input -Force -Recurse
    Write-Host "Folder $Input was empty and has been deleted." -ForegroundColor Green
}
else{
    Write-Host "Not all files were moved from $Input. Check before deleting." -ForegroundColor Yellow
}

Stop-Transcript

Start-Process "wmplayer.exe" -ArgumentList '"C:\Users\icuri\OneDrive\Documents\Scripts\Final\Misc\mariomushroom.mp3"' -WindowStyle Hidden
<#Write-Host "Press any key to continue..."
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")#>
do {
    #Capture user choice
    $choice = Read-Host "Rip successful. Enter 1 to rip another DVD or 2 to exit."

    switch ($choice) {
        "1" {
            Write-Host "Starting new rip..." -ForegroundColor Yellow
            Start-Sleep -seconds 1
            cls
            & "$PSCommandPath"
        }
        "2" {
            Write-Host "Exiting script!" -ForegroundColor Green
            Break
        }
        default {
            Write-Host "Invalid choice. Please enter 1 to rip another DVD or 2 to exit." -ForegroundColor Red
            $valid = $false
        }
    }
} while ($true)