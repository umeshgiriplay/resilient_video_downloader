import os
import subprocess
from pathlib import Path
from threading import Thread

# Variables
video_url = ""  # Replace with your video URL
output_dir = Path(r"./data")  # Replace with your desired output directory
ffmpeg_path = "ffmpeg"  # Replace with the path to your FFmpeg if not in PATH
retry_interval = 5  # Seconds to skip after a failure
segment_counter = [1]  # Using a list for thread-safe counter increment
concat_file = output_dir / "filelist.txt"
temp_error_file = output_dir / "ffmpeg_error.txt"

total_video_duration = 42 * 60  # Total duration of the video in seconds
quarter_duration = total_video_duration // 4  # Quarter of the total duration

# Create output directory if it doesn't exist
os.makedirs(output_dir, exist_ok=True)

# Empty and prepare concat file
with open(concat_file, 'w') as f:
    pass

# Function to download a segment and calculate its duration
def download_segment(start_time, segment_path, max_duration):
    command = [ffmpeg_path, "-ss", str(start_time), "-t", str(max_duration), "-i", video_url, "-c", "copy", "-y", str(segment_path)]
    with open(temp_error_file, 'w') as error_file:
        subprocess.run(command, stderr=error_file)
    if segment_path.exists():
        duration_str = subprocess.run([ffmpeg_path, "-i", str(segment_path)], capture_output=True, text=True).stderr
        if "Duration" in duration_str:
            duration_time = duration_str.split("Duration: ")[1].split(",")[0].strip()
            hours, minutes, seconds = duration_time.split(':')
            total_seconds = int(hours) * 3600 + int(minutes) * 60 + float(seconds)
            print(f"Extracted Duration: {total_seconds} seconds")
            return total_seconds
        else:
            print("Failed to extract duration from file")
            return 0
    else:
        print(f"File not found: {segment_path}")
        return 0


# Function to download segments in a thread
def download_segments(start_at, end_at, thread_label):
    current_duration = start_at
    while current_duration < end_at:
        segment_name = f"output{segment_counter[0]}.mp4"
        segment_path = output_dir / segment_name
        print(f"Downloading segment ({thread_label}): {segment_name} starting at {current_duration} seconds")
        segment_duration = download_segment(current_duration, segment_path, end_at - current_duration)
        if segment_duration > 0:
            with open(concat_file, 'a') as f:
                f.write(f"file '{segment_name}'\n")
            current_duration += segment_duration
        current_duration += retry_interval
        segment_counter[0] += 1

print("Starting Threads")

# Start downloading segments in parallel
threads = []
for i in range(4):
    start = i * quarter_duration
    end = start + quarter_duration if i < 3 else total_video_duration
    thread = Thread(target=download_segments, args=(start, end, f"Thread {i+1}"))
    threads.append(thread)
    thread.start()

# Wait for all threads to complete
for thread in threads:
    thread.join()

print("Threads completed")

# Concatenating segments
concat_path = output_dir / "final_output.mp4"
subprocess.run([ffmpeg_path, "-f", "concat", "-safe", "0", "-i", str(concat_file), "-c", "copy", "-y", str(concat_path)])

print(f"Concatenation complete. Final output at: {concat_path}")

# Cleanup
if temp_error_file.exists():
    os.remove(temp_error_file)
