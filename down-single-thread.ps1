# PowerShell Script to Download Video in Segments and Concatenate

# Variables
$videoURL = "" # Replace with your video URL
$outputDir = ".\data" # Replace with your desired output directory
$ffmpegPath = "ffmpeg" # Replace with the path to your FFmpeg if not in PATH
$retryInterval = 5 # Seconds to skip after a failure
$segmentCounter = 1
$concatFile = Join-Path $outputDir "filelist.txt"
$tempErrorFile = Join-Path $outputDir "ffmpeg_error.txt"

$totalDuration = 900 # Total duration of all downloaded segments
$totalVideoDuration = 33*60 # Total duration of all downloaded segments

# Create output directory if it doesn't exist
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir
}

# Empty and prepare concat file
if (Test-Path $concatFile) {
    Remove-Item $concatFile
}
New-Item -ItemType File -Path $concatFile

# Function to download a segment and calculate its duration


# Main loop for downloading segments
do {
    $segmentName = "output$segmentCounter.mp4"
    $segmentPath = Join-Path $outputDir $segmentName

    Write-Host "Downloading segment: $segmentName starting at $totalDuration seconds"
	
	# $segmentDuration = Download-Segment -StartTime $totalDuration -SegmentPath $segmentPath
	$StartTime = $totalDuration
    $SegmentPath = $segmentPath
	    Start-Process -FilePath $ffmpegPath -ArgumentList "-ss", $StartTime, "-i", $videoURL,"-t", $totalVideoDuration, "-c", "copy", "-y", $SegmentPath -PassThru -Wait -NoNewWindow -RedirectStandardError $tempErrorFile

    if (Test-Path $SegmentPath) {
        $durationString = & $ffmpegPath -i $SegmentPath 2>&1 | Select-String -Pattern "Duration" | Select-Object -First 1 | ForEach-Object { $_ -replace ".*Duration: ([0-9:.]*),.*", '$1' }
        if ($durationString -and $durationString -ne "N/A") {
            $timespan = [TimeSpan]::Parse($durationString)
            $totalSeconds = ($timespan.Hours * 3600) + ($timespan.Minutes * 60) + $timespan.Seconds
            if ($totalSeconds -gt 0) {
                Write-Host "Extracted Duration: $totalSeconds seconds"
                $segmentDuration =  $totalSeconds
            } else {
                Write-Host "Duration extracted but is 0 seconds"
                $segmentDuration =  0
            }
        } else {
            Write-Host "Failed to extract duration from file"
            $segmentDuration =  0
        }
    } else {
        Write-Host "File not found: $SegmentPath"
        $segmentDuration =  0
    }
	
	
	if ($segmentDuration -gt 0) {
		"file '$segmentName'" | Out-File -Encoding utf8 -Append $concatFile
		$totalDuration += $segmentDuration
	} else {
		Write-Host "Segment duration is null or invalid"
	}
	$totalDuration += $retryInterval
	$segmentCounter++
} while ($totalDuration -lt $totalVideoDuration) # Replace $totalVideoDuration with the total expected duration of the video

# Concatenating segments
$concatPath = Join-Path $outputDir "final_output.mp4"
& $ffmpegPath -f concat -safe 0 -i $concatFile -c copy -y $concatPath

Write-Host "Concatenation complete. Final output at: $concatPath"

# Cleanup
Remove-Item $tempErrorFile
