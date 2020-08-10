#!/bin/bash
# Made by katattakd. Dependencies: FFMPEG, SoX, GNU Coreutils, waifu2xcpp
# Note: Make sure you have at least 4GB of available RAM before running this script.
# Encoding is purely CPU based, and may take a while on slower CPUs.

##### Tunables:

# Change the amount that waifu2x denoises the image (0-3). Setting this too high can result in loss of detail, especially in non-anime images.
export waifu2x_denoise_amount=2

# Change the colors used in the visualizer.
export visualizer_colors="0x111111|0x111111"

# Change the number of bars shown on the visualizer. 120 is a decent default.
export visualizer_bars=120

# Change the opacity of the visualizer (from 0 to 1).
export visualizer_opacity=0.7

# Change the x265 video compression preset used. Available options are ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, and veryslow. Slower presets will result in more efficient compression.
export x265_encoder_preset="slow"

##### Start of code

ffloglevelstr="-loglevel error -y"
sxloglevelstr="-V1"
w2loglevelstr="-v 0"
afiletypes=( "input.flac" "input.wv" "input.tta" "input.ddf" "input.dsf" "input.wav" "input.wave" "input.caf" "input.mka" "input.opus" "input.ogg" "input.oga" "input.vorbis" "input.spx" "input.m4a" "input.m4b" "input.m4r" "input.mp3" "input.bit" )
vfiletypes=( "input.png" "input.tiff" "input.tif" "input.pam" "input.pnm" "input.ppm" "input.pgm" "input.pbm" "input.bmp" "input.dib" "input.psd" "input.apng" "input.exr" "input.webp" "input.jp2" "input.jpg" "input.jpeg" "input.jpe" "input.jfi" "input.jfif" "input.jif" "input.gif" "input.mkv" )
set -euo pipefail

if [[ ! (`command -v sox` && `command -v soxi` && `command -v ffmpeg` && `command -v waifu2x-converter-cpp`) ]]; then
	echo "Please install the required dependencies before attempting to run the script."
	exit
fi

if [[ ! -f "speed.txt" ]]; then
	echo "Please create a speed.txt file stating the speed multiplier you want to use (like 1.1 or 1.2)."
	exit
fi

# Remove metadata, fix clipping, and speed up audio.
for i in "${afiletypes[@]}"; do
	if [[ -f "$i" ]]; then
		echo "Processing audio..."
		ffmpeg $ffloglevelstr -i $i -vn -map_metadata -1 -af "volume=-15dB,adeclip=m=s,afade=t=in:ss=0:d=0.5:curve=squ,silenceremove=start_threshold=-105dB:start_mode=all:stop_periods=-1" -f sox - | sox $sxloglevelstr -p /tmp/audio.wav --guard --multi-threaded --buffer 1000000 speed "$(cat speed.txt)" rate -v -I 48k gain -n
		break
	fi
done

if [[ ! -f "/tmp/audio.wav" ]]; then
	echo "Input audio is required! File must be named input.(extension)"
	exit
fi

# Remove metadata, crop image to 16:9, and AI upscale image.
for i in "${vfiletypes[@]}"; do
	if [[ -f "$i" ]]; then
		echo "Processing image..."
		ffmpeg $ffloglevelstr -i $i -an -vframes 1 -map_metadata -1 -vf "crop=iw:round((iw/16)*9)" /tmp/input.ppm
		width=$(ffprobe -v 0 -of csv=p=0 -select_streams v:0 -show_entries stream=width /tmp/input.ppm)
		height=$(ffprobe -v 0 -of csv=p=0 -select_streams v:0 -show_entries stream=height /tmp/input.ppm)
		if [ "$width" -ge "4000" ] && [ "$height" -ge "2320" ]; then
			w2x_scale=1
		elif [ "$width" -ge "2000" ] && [ "$height" -ge "1160" ]; then
			w2x_scale=2
		elif [ "$width" -ge "1334" ] && [ "$height" -ge "774" ]; then
			w2x_scale=3
		elif [ "$width" -ge "1000" ] && [ "$height" -ge "580" ]; then
			w2x_scale=4
		elif [ "$width" -ge "800" ] && [ "$height" -ge "464" ]; then
			w2x_scale=5
		elif [ "$width" -ge "667" ] && [ "$height" -ge "387" ]; then
			w2x_scale=6
		elif [ "$width" -ge "572" ] && [ "$height" -ge "332" ]; then
			w2x_scale=7
		elif [ "$width" -ge "500" ] && [ "$height" -ge "290" ]; then
			w2x_scale=8
		else
			echo "Input image is too small!"
			rm /tmp/input.ppm
			exit
		fi
		waifu2x-converter-cpp $w2loglevelstr -m noise-scale --scale-ratio $w2x_scale --noise-level $waifu2x_denoise_amount -i /tmp/input.ppm -o /tmp/background.ppm
		rm /tmp/input.ppm
		break
	fi
done

if [[ ! -f "/tmp/background.ppm" ]]; then
	echo "Input image is required! File must be named input.(extension)"
	exit
fi

# Create video filtergraph
echo "Generating filtergraph..."
x=0
y=0
filterx="0"
filtery="0"
for i in $(seq 0 $(soxi -D /tmp/audio.wav | awk '{ print int(($1/4) + 1) }')); do
	newx=$((($RANDOM % (120-$x))))
	newy=$((($RANDOM % (120-$y))))
	filterx="if(gt(t/4\,$i)\,$x+($(($newx-$x))*(sqrt((t/4)-$i)*(sin(((t/4)-$i)*PI/2))))\,$filterx)"
	filtery="if(gt(t/4\,$i)\,$y+($(($newy-$y))*(sqrt((t/4)-$i)*(sin(((t/4)-$i)*PI/2))))\,$filtery)"
	x=$newx
	y=$newy
done
loudnorm=$(ffmpeg -i /tmp/audio.wav -af "loudnorm=print_format=summary" -f null - 2>&1)
loudnorm_i=$(echo "$loudnorm" | grep "Input Integrated" | awk '{ print $3 }')
loudnorm_tp=$(echo "$loudnorm" | grep "Input True Peak" | awk '{ print $4 }')
loudnorm_lra=$(echo "$loudnorm" | grep "Input LRA" | awk '{ print $3 }')
loudnorm_thresh=$(echo "$loudnorm" | grep "Input Threshold" | awk '{ print $3 }')
filtergraph="[0:a]loudnorm=linear=true:measured_i=$loudnorm_i:measured_lra=$loudnorm_lra:measured_tp=$loudnorm_tp:measured_thresh=$loudnorm_thresh,showcqt=s=${visualizer_bars}x1080:r=60:axis_h=0:sono_h=0:bar_v=36dB*a_weighting(f):bar_g=7:count=30:cscheme=0.0001|0.0001|0.0001|0.0001|0.0001|0.0001,scale=3840x1080:sws_flags=neighbor,setsar=0,format=rgba,colorkey=black:0.01:0,colorchannelmixer=aa=$visualizer_opacity[visualizer];
[1:v]scale=4000x2320:force_original_aspect_ratio=increase:sws_flags=lanczos+accurate_rnd+full_chroma_int+full_chroma_inp+bitexact,crop=3840:2160:$filterx:$filtery[background];
[background][visualizer]overlay=shortest=1:x=0:y=1080:format=rgb"

# Render video with generated filtergraph
echo "Rendering video..."
ffmpeg $ffloglevelstr -stats -i /tmp/audio.wav -loop 1 -i /tmp/background.ppm -c:v libx265 -r 60 -filter_complex "$filtergraph" -x265-params lossless=1 -preset "$x265_encoder_preset" -c:a flac -compression_level 12 -exact_rice_parameters 1 output.mkv
rm /tmp/background.ppm
rm /tmp/audio.wav

