#!/bin/bash
# Made by katattakd. Dependencies: FFMPEG, SoX, GNU Coreutils, waifu2xcpp
# Note: Make sure your /tmp folder has at least 2GB of free space before running this script. All processing until the final encode is done with lossless H.264 and FLAC, which can result in temporary files using a LOT of space. Temporary files are deleted as soon as they are no longer needed, in order to reduce /tmp usage.
# Encoding is purely CPU based, and may take a while on slower CPUs.

##### Tunables:

# It can normally take a while and a lot of resources for this script to render videos, especially on lower-end hardware. This allows you to generate a quick preview of what the video would look like, and should render fairly quickly, even on low-end hardware.
export render_preview=true

# Change the amount that waifu2x upscales the image. Note that setting this too high won't cause issues (as the image is downscaled right after), but will increase processing time.
# Setting this too low can reduce visual quality if the input image is small. This should be set to at least "1" if the image is 4k, "2" if the image is 1080p, "3" if the image is 720p, or "5" if the image is 480p.
export waifu2x_scale_ratio=5

# Change the amount that waifu2x denoises the image (0-3). Setting this too low can result in reduced visual quality, while setting it too high can result in added visual artifacts (especially in non-anime images).
# This is set to the highest by default, as it's assumed that the user is using low-resoultion anime-style images. If you are providing high-quality or non-anime images, you may want to reduce this value. 
export waif2x_denoise_amount=3

# Change the colors used in the visualizer.
export visualizer_colors="0x111111|0x232323"

# Change the number of bars on the visualizer (note that some of these are cropped out). 120 is a decent default.
export visualizer_bars=120

# Change how the visualizer displays loudness. Possible options are lin, sqrt, cbrt, and log.
export visualizer_loudness_curve="log"

# Change the number of loudness values that are cropped out of the visualizer (1080 total). 400 is a decent default, but it may need to be changed depending on the loudness curve used.
export visualizer_crop_amount=400

# Change the opacity of the visualizer (from 0 to 1). 
export visualizer_opacity=0.7

# Change the framerate of the video. Higher framerates can result in smoother playback on high-end systems. If you intend to share the video or upload it to streaming sites, setting this higher than 60 is pointless.
export maximum_video_framerate=60

# Note that there are more tunables at the end of the code.

##### Start of code

# Resize input image (input.png), and place processed image at /tmp/resized.png.
process_image() {
	echo "Processing image..."
	waifu2x-converter-cpp -v 0 -c 0 --disable-gpu -m noise-scale --scale-ratio $waifu2x_scale_ratio --noise-level $waif2x_denoise_amount -i input.png -o /tmp/input.png
	ffmpeg -y -v error -i /tmp/input.png -vf scale=4000x2320:force_original_aspect_ratio=increase -sws_flags lanczos+accurate_rnd+full_chroma_int+full_chroma_inp /tmp/resized.png
	rm /tmp/input.png
}

# Speed up input audio (input.flac) by $speed times, and placed processed audio at /tmp/audio.flac.
process_audio() {
	echo "Processing audio..."
	sox input.flac -V1 -q -b 24 --no-dither --guard /tmp/audio.flac --multi-threaded --buffer 128000 speed $speed rate -v -I 48k gain -n
}

# Create segments of gliding background video, using /tmp/audio.flac and /tmp/resized.png.
# The list of segments will be named /tmp/combine.txt
create_background_segments() {
	echo "Creating background segments..."
	export x=0
	export y=0
	export maxr=60
	export filterx="0"
	export filtery="0"
	for mi in $(seq 0 $(soxi -D /tmp/audio.flac | awk '{ print int(($1/60) + 1) }')); do
		for i in $(seq 0 60); do
			if [ $x -gt 0 ]; then
				export changx=$((($RANDOM % (($maxr*2)-$x))-$maxr))
			else
				export changx=$((($RANDOM % (($maxr*2)+$x))-($maxr+$x)))
			fi
			if [ $y -gt 0 ]; then
				export changy=$((($RANDOM % (($maxr*2)-$y))-$maxr))
			else
				export changy=$((($RANDOM % (($maxr*2)+$y))-($maxr+$y)))
			fi
			filterx="if(gt(t\,$i)\,$(($x-$maxr))+($changx*(sqrt(t-$i)*(sin((t-$i)*PI/2))))\,$filterx)"
			filtery="if(gt(t\,$i)\,$(($y-$maxr))+($changy*(sqrt(t-$i)*(sin((t-$i)*PI/2))))\,$filtery)"
			export x=$(($x+$changx))
			export y=$(($y+$changy))

		done
		ffmpeg -y -v error -r $maximum_video_framerate -filter_complex "color=black:s=3840x2160[background];movie=/tmp/resized.png[overlay];[background][overlay]overlay=$filterx:$filtery" -t $(($i+1)) -crf 0 -preset ultrafast /tmp/glide-tmp$mi.mp4
		printf "file /tmp/glide-tmp$mi.mp4\n" >> /tmp/combine.txt
		export filterx="$(($x-$maxr))"
		export filtery="$(($y-$maxr))"
	done
	rm /tmp/resized.png
}

# Combine segments of gliding background video using /tmp/combine.txt. The output file will be named /tmp/background.mp4.
combine_background_segments() {
	echo "Combining background segments..."
	ffmpeg -y -v error -f concat -safe 0 -i /tmp/combine.txt -c copy /tmp/background.mp4
	rm /tmp/glide-tmp*.mp4
	rm /tmp/combine.txt
}

# Add an audio visualizer (using /tmp/audio.flac) to the background (/tmp/background.mp4 or /tmp/resized.png). Output file will be named /tmp/combined.mkv
add_video_effects() {
	echo "Creating final video..."
	ffmpeg -y -v error -r $maximum_video_framerate -i /tmp/background.mp4 -i /tmp/audio.flac -filter_complex "[1:a]showfreqs=s=$(($visualizer_total_bars))x1080:mode=bar:ascale=$visualizer_loudness_curve:fscale=log:colors=$visualizer_colors:win_size=8192:win_func=blackman,crop=$visualizer_bars:1080:0:0,scale=3840x1080:sws_flags=neighbor,setsar=0,format=yuva420p,colorchannelmixer=aa=$visualizer_opacity[visualizer];[0:v][visualizer]overlay=shortest=1:x=0:y=$((1080+$visualizer_crop_amount))" -acodec copy -vcodec libx264 -crf:v 0 -preset ultrafast /tmp/combined.mkv
	rm /tmp/background.mp4
	rm /tmp/audio.flac
}

if [[ ! (`command -v sox` && `command -v soxi` && `command -v ffmpeg` && `command -v waifu2x-converter-cpp`) ]]; then
	echo "Please install the required dependencies before attempting to run the script."
	exit
fi
if [ -z $1 ]; then
	echo "Please pass a speed multiplier to the script (eg. bash nightcore.sh 1.2)."
	echo "Note that the input files need to be named input.flac and input.png for the script to detect them."
	exit
fi

if [[ ! -f "input.flac" ]]; then
	echo "A necessary input file is missing."
	exit
fi

export speed=$1
set -euo pipefail

if [[ ! -f "input.png" ]]; then
	echo "Warn: Unable to find image, creating audio-only output."
	process_audio
	mv /tmp/audio.flac "output.lossless.flac"
	exit
fi

export visualizer_total_bars=$(awk 'BEGIN{ print int('$visualizer_bars'/(18000/24000)) }')

if [ $render_preview = true ]; then
	echo "Warn: Creating a low quality uncompressed preview video."
	echo "Processing audio..."
	sox input.flac -V1 -q -b 24 --no-dither --guard /tmp/audio.flac --multi-threaded --buffer 128000 speed $speed rate -m 48k gain -n
	echo "Processing image..."
	ffmpeg -y -v error -i input.png -vf scale=266x154:force_original_aspect_ratio=increase -sws_flags lanczos /tmp/resized.png
	echo "Creating final video..."
	ffmpeg -y -v error -r 25 -i /tmp/audio.flac -filter_complex "showfreqs=s=$(($visualizer_total_bars))x72:mode=bar:ascale=$visualizer_loudness_curve:fscale=log:colors=$visualizer_colors:win_size=8192:win_func=blackman,crop=$visualizer_bars:72:0:0,scale=256x72:sws_flags=neighbor,setsar=0,format=yuva420p,colorchannelmixer=aa=$visualizer_opacity[visualizer];movie=/tmp/resized.png,crop=256:144:5:5[background];[background][visualizer]overlay=0:$((72+($visualizer_crop_amount/15)))" -c:a copy -vcodec libx264 -crf:v 0 -preset ultrafast preview.mkv
	rm /tmp/resized.png
	rm /tmp/audio.flac
	exit
fi

process_audio
process_image
create_background_segments
combine_background_segments
add_video_effects
echo "Compressing final video..."

##### End of processing code

# Uncomment this line for lossless video+audio output. Extremely large filesize, should only be used for quick local playback or as input for further encoding steps.
#cp /tmp/combined.mkv output.lossless.mkv

# Uncomment this line for fast extremely high quality video+audio output. Should only be used for quick local playback.
ffmpeg -y -v error -i /tmp/combined.mkv -c:v libx264 -crf:v 14 -preset veryfast -c:a copy output.lossyfastultrahq.mkv

# Uncomment this line for extremely high quality video+audio output. Recommended for uploading to streaming sites (like YouTube), should never be used for quick sharing (like on online chats or social media).
#ffmpeg -y -v error -i /tmp/combined.mkv -c:v libx264 -crf:v 14 -profile:v high -level 4.1 -preset slow -movflags +faststart -c:a aac -b:a 320k output.lossyultrahq.mp4

# Uncomment this line for high quality video+audio output. Recommended for uploading to streaming sites (like YouTube), should be avoided for quick sharing (like on online chats or social media).
#ffmpeg -y -v error -i /tmp/combined.mkv -c:v libx264 -crf:v 18 -s 1920x1080 -sws_flags lanczos -preset slow -profile:v high -level 4.1 -movflags +faststart -c:a aac -b:a 320k output.lossyhq.mp4

# Uncomment this line for medium quality video+audio output. Recommended for quick sharing (like for online chats or social media), should be avoided for uploads to streaming sites (like YouTube).
#ffmpeg -y -v error -i /tmp/combined.mkv -c:v libx264 -crf:v 26 -s 1280x720 -sws_flags lanczos -preset slow -movflags +faststart -c:a aac -b:a 320k output.lossymq.mp4

# Uncomment this line for low quality video+audio output. Can be useful for quick sharing in space-limited cases, should never be used for uploads to streaming sites (like YouTube).
#ffmpeg -y -v error -i /tmp/combined.mkv -c:v libx264 -crf:v 33 -s 640x360 -r 30 -sws_flags lanczos -preset slow -movflags +faststart -c:a aac -b:a 128k output.lossylq.mp4

# Uncomment this line for lossless audio-only output. Recommended for quick local playback or uploads to streaming sites, should be avoided for quick sharing (like on online chats or social media).
#ffmpeg -y -v error -i /tmp/combined.mkv -vn -acodec copy output.lossless.flac

# Uncomment this line for perceptibly lossless audio-only output. Recommended for quick sharing (like for online chats or social media) or uploads to streaming sites, should be avoided for uploads to streaming sites (like Soundcloud).
#ffmpeg -y -v error -i /tmp/combined.mkv -vn -acodec libopus -b:a 320k -vbr on -compression_level 10 output.lossyhq.ogg

# Uncomment this line for medium quality audio-only output. Recommended for quick sharing in space-limited cases, should never be used for uploads to streaming sites (like Soundcloud).
#ffmpeg -y -v error -i /tmp/combined.mkv -vn -acodec libopus -b:a 120k -vbr on -compression_level 10 output.lossymq.ogg

rm /tmp/combined.mkv
