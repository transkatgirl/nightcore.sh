#!/bin/bash
# Made by katattakd. Dependencies: FFMPEG, SoX, GNU Coreutils, waifu2xcpp (optional)
# Note: Make sure your /tmp folder has at least 800MB of free space before running this script. All processing until the final encode is done with lossless H.264 and FLAC, which can result in temporary files using a LOT of space. Temporary files are deleted as soon as they are no longer needed, in order to reduce /tmp usage.

##### Tunables:

# Change the amount that waifu2x upscales the image. Note that setting this too high won't cause issues (as the image is downscaled right after), but will increase processing time.
# Setting this too low can reduce visual quality if the input image is small.
export waifu2x_scale_ratio=4

# Change the amount that waifu2x denoises the image (0-3). Setting this too low can result in reduced visual quality, while setting it too high can result in added visual artifacts (especially in non-anime images).
# This is set to the highest by default, as it's assumed that the user is using low-resoultion anime-style images. If you are providing high-quality or non-anime images, you may want to reduce this value. 
export waif2x_denoise_amount=3

# Change the colors used in the visualizer.
export visualizer_colors="0x000000|0x000000"

# Change the number of total bars on the visualizer (note that some of these are cropped out). 160 is a decent default.
export visualizer_total_bars=160

# Change the number of loudness values that are cropped out of the visualizer (540 total). 200 is a decent default, but it may need to be decreased for some videos,
export visualizer_crop_amount=200

# Change the opacity of the visualizer (from 0 to 1). 
export visualizer_opacity=0.6

# Change the framerate of the video. Higher framerates can result in smoother playback on high-end systems. If you intend to share the video or upload it to streaming sites, setting this higher than 60 is pointless.
export maximum_video_framerate=60

# Note that there are more tunables at the end of the code.

##### Start of code

# Resize input image (input.png), and place processed image at /tmp/resized.png.
process_image() {
	echo "Processing image..."
	if [[ `command -v waifu2x-converter-cpp` ]]; then
		waifu2x-converter-cpp -v 0 -c 0 --disable-gpu -m noise-scale --scale-ratio $waifu2x_scale_ratio --noise-level $waif2x_denoise_amount -i input.png -o /tmp/input.png
	else
		cp input.png /tmp/input.png
	fi
	ffmpeg -y -v error -i /tmp/input.png -vf scale=2000x1160:force_original_aspect_ratio=increase -sws_flags lanczos+accurate_rnd+full_chroma_int+full_chroma_inp /tmp/resized.png
	rm /tmp/input.png
}

# Speed up input audio (input.flac) by $speed times, and placed processed audio at /tmp/audio.flac.
process_audio() {
	echo "Processing audio..."
	sox input.flac -V1 -q -b 24 --no-dither --guard /tmp/audio.flac --multi-threaded --buffer 128000 speed $speed rate -v -I -s 48k gain -n
}

# Create segments of gliding background video, using /tmp/audio.flac and /tmp/resized.png.
# The list of segments will be named /tmp/combine.txt
create_background_segments() {
	echo "Creating background segments..."
	export x=0
	export y=0
	export maxr=40
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
			filterx="if(gt(t\,$i)\,$(($x-$maxr))+($changx*(t-$i))\,$filterx)"
			filtery="if(gt(t\,$i)\,$(($y-$maxr))+($changy*(t-$i))\,$filtery)"
			export x=$(($x+$changx))
			export y=$(($y+$changy))

		done
		ffmpeg -y -v error -r $maximum_video_framerate -filter_complex "color=black:s=1920x1080[background];movie=/tmp/resized.png[overlay];[background][overlay]overlay=$filterx:$filtery" -t $(($i+1)) -crf 0 -preset ultrafast /tmp/glide-tmp$mi.mp4
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

# Add an audio visualizer (using /tmp/audio.flac) to the background video (/tmp/background.mp4). Output file will be named /tmp/combined.mkv
add_video_effects() {
	echo "Creating final video..."
	ffmpeg -y -v error -r $maximum_video_framerate -i /tmp/background.mp4 -i /tmp/audio.flac -filter_complex "[1:a]showfreqs=s=$(($visualizer_total_bars))x540:mode=bar:ascale=log:fscale=log:colors=$visualizer_colors:win_size=8192:win_func=blackman,scale=2275x540:sws_flags=neighbor,setsar=0,format=yuva420p,colorchannelmixer=aa=$visualizer_opacity[visualizer];[0:v][visualizer]overlay=shortest=1:x=0:y=$((540+$visualizer_crop_amount))" -acodec copy -vcodec libx264 -crf:v 0 -preset fast /tmp/combined.mkv
	rm /tmp/audio.flac
	rm /tmp/background.mp4
}

if [[ ! (`command -v sox` && `command -v soxi` && `command -v ffmpeg`) ]]; then
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
	cp /tmp/audio.flac "output.lossless.flac"
	exit
fi

process_audio
if [ -f "background.mp4" ]; then
	cp background.mp4 /tmp/background.mp4
else
	process_image
	create_background_segments
	combine_background_segments
fi
add_video_effects

##### End of processing code

# Uncomment this line for lossless video+audio output. Extremely large filesize, should only be used for quick local playback or as input for further encoding steps.
cp /tmp/combined.mkv output.lossless.mkv

# Uncomment this line for perceptibly lossless video+audio output. Recommended for uploading to streaming sites (like YouTube), should be avoided for quick sharing (like on online chats or social media).
#ffmpeg -i /tmp/combined.mkv -c:v libx264 -crf:v 14 -preset slow -profile:v high -level 4.1 -preset slow -movflags +faststart -c:a aac -b:a 320k output.lossyhq.mp4

# Uncomment this line for medium quality video+audio output. Recommended for quick sharing (like for online chats or social media), should be avoided for uploads to streaming sites (like YouTube).
#ffmpeg -i /tmp/combined.mkv -c:v libx264 -crf:v 26 -s 1280x720 -sws_flags lanczos -preset slow -movflags +faststart -c:a aac -b:a 320k output.lossymq.mp4

# Uncomment this line for low quality video+audio output. Can be useful for quick sharing in space-limited cases, should never be used for uploads to streaming sites (like YouTube).
#ffmpeg -i /tmp/combined.mkv -c:v libx264 -crf:v 33 -s 640x360 -r 30 -sws_flags lanczos -preset slow -movflags +faststart -c:a aac -b:a 128k output.lossylq.mp4

# Uncomment this line for lossless audio-only output. Recommended for quick local playback or uploads to streaming sites, should be avoided for quick sharing (like on online chats or social media).
#ffmpeg -i /tmp/combined.mkv -vn -acodec copy output.lossless.flac

# Uncomment this line for perceptibly lossless audio-only output. Recommended for quick sharing (like for online chats or social media) or uploads to streaming sites, should be avoided for uploads to streaming sites (like Soundcloud).
#ffmpeg -i /tmp/combined.mkv -vn -acodec libopus -b:a 320k -vbr on -compression_level 10 output.lossyhq.ogg

# Uncomment this line for medium quality audio-only output. Recommended for quick sharing in space-limited cases, should never be used for uploads to streaming sites (like Soundcloud).
#ffmpeg -i /tmp/combined.mkv -vn -acodec libopus -b:a 120k -vbr on -compression_level 10 output.lossymq.ogg

rm /tmp/combined.mkv

