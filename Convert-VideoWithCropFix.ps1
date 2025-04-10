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