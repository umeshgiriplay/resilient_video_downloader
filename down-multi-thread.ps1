# PowerShell Script to Download Video in Segments and Concatenate Using Parallel Downloading

# Variables
$videoURL = "https://asd.com/asd.mp4" # Replace with your video URL
$outputDir = ".\data" # Replace with your desired output directory
$ffmpegPath = "ffmpeg" # Replace with the path to your FFmpeg if not in PATH
$retryInterval = 5 # Seconds to skip after a failure
$segmentCounter = 1
$concatFile = Join-Path $outputDir "filelist.txt"
$tempErrorFile = Join-Path $outputDir "ffmpeg_error.txt"

$totalVideoDuration = 42*60 # Total duration of the video in seconds
$halfDuration = $totalVideoDuration / 2 # Half of the total duration

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
function Download-Segment {
    param(
        [int]$StartTime,
        [string]$SegmentPath,
        [int]$MaxDuration
    )
    Start-Process -FilePath $ffmpegPath -ArgumentList "-ss", $StartTime, "-t", $MaxDuration, "-i", $videoURL, "-c", "copy", "-y", $SegmentPath -PassThru -Wait -NoNewWindow -RedirectStandardError $tempErrorFile
    if (Test-Path $SegmentPath) {
        $durationString = & $ffmpegPath -i $SegmentPath 2>&1 | Select-String -Pattern "Duration" | Select-Object -First 1 | ForEach-Object { $_ -replace ".*Duration: ([0-9:.]*),.*", '$1' }
        if ($durationString -and $durationString -ne "N/A") {
            $timespan = [TimeSpan]::Parse($durationString)
            $totalSeconds = ($timespan.Hours * 3600) + ($timespan.Minutes * 60) + $timespan.Seconds
            if ($totalSeconds -gt 0) {
                Write-Host "Extracted Duration: $totalSeconds seconds"
                return $totalSeconds
            } else {
                Write-Host "Duration extracted but is 0 seconds"
                return 0
            }
        } else {
            Write-Host "Failed to extract duration from file"
            return 0
        }
    } else {
        Write-Host "File not found: $SegmentPath"
        return 0
    }
}

# Function to download segments in a job
function Download-Segments {
    param(
        [int]$StartAt,
        [int]$EndAt,
        [string]$ThreadLabel
    )
	Write-Host "Downloading segment ($ThreadLabel)"
    $currentDuration = $StartAt
    while ($currentDuration -lt $EndAt) {
        $segmentName = "output$segmentCounter.mp4"
        $segmentPath = Join-Path $outputDir $segmentName
        Write-Host "Downloading segment ($ThreadLabel): $segmentName starting at $currentDuration seconds"
        $segmentDuration = Download-Segment -StartTime $currentDuration -SegmentPath $segmentPath -MaxDuration ($EndAt - $currentDuration)
        if ($segmentDuration -gt 0) {
            "file '$segmentName'" | Out-File -Encoding utf8 -Append $concatFile
            $currentDuration += $segmentDuration
        }
        $currentDuration += $retryInterval
        $segmentCounter++
    }
}

Write-Host "Starting Threads"

# Start downloading segments in parallel
$firstThread = Start-Job -ScriptBlock ${function:Download-Segments} -ArgumentList 0, $halfDuration, "Thread 1"
$secondThread = Start-Job -ScriptBlock ${function:Download-Segments} -ArgumentList $halfDuration, $totalVideoDuration, "Thread 2"

Write-Host "Started Threads"

# Wait for both threads to complete
Wait-Job $firstThread, $secondThread
Write-Host "Waiting for  Threads"

Receive-Job $firstThread
Write-Host "Received First Thread"
Receive-Job $secondThread
Write-Host "Received Second Thread"

# Concatenating segments
$concatPath = Join-Path $outputDir "final_output.mp4"
& $ffmpegPath -f concat -safe 0 -i $concatFile -c copy -y $concatPath

Write-Host "Concatenation complete. Final output at: $concatPath"

# Cleanup
Remove-Job $firstThread
Remove-Job $secondThread
Remove-Item $tempErrorFile
