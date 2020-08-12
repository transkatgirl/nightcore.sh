#!/bin/bash
# Made by katattakd. Dependencies: FFMPEG, SoX, ImageMagick, GNU Coreutils, waifu2xcpp
# Note: Make sure you have at least 6GB of available RAM before running this script.
# Encoding is purely CPU based, and may take a while on slower CPUs.

##### Tunables:

# Allow multiple instances of the Nightcore.sh script to run at the same time. Note that this can result in a build-up of temporary files if the script crashes, so this should only be enabled if you need it.
export seperate_instances=false

# Change the amount that waifu2x denoises the image (0-3). Setting this too high can result in loss of detail, especially in non-anime images.
export waifu2x_denoise_amount=2

# Change the number of bars shown on the visualizer.
export visualizer_bars=100

# Change the opacity of the visualizer (from 0 to 1).
export visualizer_opacity=0.75

# Change the x265 video compression preset used. Available options are ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, and veryslow. Slower presets will result in more efficient compression.
export x265_encoder_preset="slow"

##### Start of code

ffloglevelstr="-loglevel error -y"
fploglevelstr="-loglevel error -of csv=p=0"
sxloglevelstr="-V1"
w2loglevelstr="-v 0"
afiletypes=( "input.flac" "input.wv" "input.tta" "input.ddf" "input.dsf" "input.wav" "input.wave" "input.caf" "input.mka" "input.opus" "input.ogg" "input.oga" "input.vorbis" "input.spx" "input.m4a" "input.m4b" "input.m4r" "input.mp3" "input.bit" )
vfiletypes=( "input.png" "input.tiff" "input.tif" "input.pam" "input.pnm" "input.ppm" "input.pgm" "input.pbm" "input.bmp" "input.dib" "input.psd" "input.apng" "input.exr" "input.webp" "input.jp2" "input.jpg" "input.jpeg" "input.jpe" "input.jfi" "input.jfif" "input.jif" "input.gif" "input.mkv" )
tmpdir="/tmp/nightcore.sh"
set -euo pipefail

if [[ ! (`command -v sox` && `command -v soxi` && `command -v ffmpeg` && `command -v ffprobe` && `command -v magick` && `command -v waifu2x-converter-cpp`) ]]; then
	echo "Please install the required dependencies before attempting to run the script."
	exit
fi

if [[ ! -f "speed.txt" ]]; then
	echo "Please create a speed.txt file stating the speed multiplier you want to use (like 1.1 or 1.2)."
	exit
fi

# Initalize temporary directory.
if [ "$seperate_instances" = true ]; then
	tmpdir="$tmpdir/$(date +%s)_$RANDOM"
fi
rm -rf $tmpdir
mkdir -p $tmpdir
audio_stage1="$tmpdir/stage1.wav"
audio_output="$tmpdir/output.wav"
image_stage1="$tmpdir/stage1.ppm"
image_stage2="$tmpdir/stage2.ppm"
image_output="$tmpdir/output.ppm"

# Remove metadata, fix clipping, speed up audio, and normalize volume.
# Note: Fixing of clipped samples is done before all other effects, so that all clipped samples are detected properly.
# Fade-in must be done before silence removal, and after speed adjustment, to prevent timing issues.
# Loudness normalization must be done last, and cannot be combined with other encoding passes.
for i in "${afiletypes[@]}"; do
	if [[ -f "$i" ]]; then
		echo "Processing audio..."
		ffmpeg $ffloglevelstr -i $i -vn -map_metadata -1 -af "volume=-15dB,adeclip=m=s" -f sox - | sox $sxloglevelstr -p -p --guard --multi-threaded --buffer 1000000 speed "$(cat speed.txt)" rate -v -I 48k gain -n | ffmpeg $ffloglevelstr -f sox -i - -af "afade=t=in:ss=0:d=0.5:curve=squ,silenceremove=start_threshold=-95dB:start_mode=all:stop_periods=-1" $audio_stage1

		loudnorm=$(ffmpeg -i $audio_stage1 -af "loudnorm=print_format=summary:tp=-1:i=-16" -f null - 2>&1)
		loudnorm_i=$(echo "$loudnorm" | grep "Input Integrated" | awk '{ print $3 }')
		loudnorm_tp=$(echo "$loudnorm" | grep "Input True Peak" | awk '{ print $4 }')
		loudnorm_lra=$(echo "$loudnorm" | grep "Input LRA" | awk '{ print $3 }')
		loudnorm_thresh=$(echo "$loudnorm" | grep "Input Threshold" | awk '{ print $3 }')
		ffmpeg $ffloglevelstr -i $audio_stage1 -af "loudnorm=linear=true:tp=-1:i=-16:measured_i=$loudnorm_i:measured_lra=$loudnorm_lra:measured_tp=$loudnorm_tp:measured_thresh=$loudnorm_thresh" $audio_output

		rm $audio_stage1
		break
	fi
done

if [[ ! -f "$audio_output" ]]; then
	echo "Input audio is required! File must be named input.(extension)"
	exit
fi

# Remove metadata, trim image, AI upscale image, and crop image to 4000x2320.
# Note: Image trimming must be done before upscaling, to ensure final image is >=4000x2320.
# Image cropping must be done after upscaling, to ensure input image >=4000x2320.
for i in "${vfiletypes[@]}"; do
	if [[ -f "$i" ]]; then
		echo "Processing image..."
		ffmpeg $ffloglevelstr -i $i -an -vframes 1 -map_metadata -1 -vcodec ppm -f image2pipe - | magick - -fuzz 1% -trim $image_stage1

		width=$(ffprobe $fploglevelstr -select_streams v:0 -show_entries stream=width $image_stage1)
		width_scale=$(echo "$width" | awk '{ print int((4000/$1)+1) }')
		height=$(ffprobe $fploglevelstr -select_streams v:0 -show_entries stream=height $image_stage1)
		height_scale=$(echo "$height" | awk '{ print int((2320/$1)+1) }')
		if [ "$width_scale" -ge "$height_scale" ]; then
			w2x_scale=$width_scale
		else
			w2x_scale=$height_scale
		fi
		waifu2x-converter-cpp $w2loglevelstr -m noise-scale --scale-ratio $w2x_scale --noise-level $waifu2x_denoise_amount -i $image_stage1 -o $image_stage2

		rm $image_stage1

		if [ $(echo $width $height | awk '{ print int(($1/$2)*100) }') -gt 130 ]; then
			gravity="Center"
		else
			gravity="North"
		fi
		magick $image_stage2 -filter Lanczos -resize 4000x2320^ -gravity $gravity -crop 4000x2320+0+0 +repage $image_output

		rm $image_stage2
		break
	fi
done

if [[ ! -f "$image_output" ]]; then
	echo "Input image is required! File must be named input.(extension)"
	exit
fi

# Create video filtergraph
x=0
y=0
newx=0
newy=0
filterx="0"
filtery="0"
for i in $(seq 0 $(soxi -D $audio_output | awk '{ print int(($1/4) + 1) }')); do
	while [ $(echo $(($newx-$x)) | tr -d -) -lt 30 ] && [ $(echo $(($newy-$y)) | tr -d -) -lt 30 ]; do
		newx=$((($RANDOM % (120-$x))))
		newy=$((($RANDOM % (120-$y))))
	done
	filterx="if(gt(t/4\,$i)\,$x+($(($newx-$x))*(sqrt((t/4)-$i)*(sin(((t/4)-$i)*PI/2))))\,$filterx)"
	filtery="if(gt(t/4\,$i)\,$y+($(($newy-$y))*(sqrt((t/4)-$i)*(sin(((t/4)-$i)*PI/2))))\,$filtery)"
	x=$newx
	y=$newy
done
filtergraph="[0:a]showcqt=s=${visualizer_bars}x1080:r=60:axis_h=0:sono_h=0:bar_v=26dB*a_weighting(f):bar_g=7:endfreq=12500:cscheme=0.0001|0.0001|0.0001|0.0001|0.0001|0.0001,scale=3840x1080:sws_flags=neighbor,setsar=0,format=rgba,colorkey=black:0.01:0,colorchannelmixer=aa=$visualizer_opacity[visualizer];
[1:v]crop=3840:2160:$filterx:$filtery[background];
[background][visualizer]overlay=shortest=1:x=0:y=1080:format=rgb"

# Render video with generated filtergraph
echo "Rendering video..."
ffmpeg $ffloglevelstr -stats -i $audio_output -loop 1 -i $image_output -c:v libx265 -r 60 -filter_complex "$filtergraph" -x265-params lossless=1 -preset "$x265_encoder_preset" -c:a flac -compression_level 12 -exact_rice_parameters 1 output.mkv
rm $audio_output

# Create video thumbnail
magick $image_output -gravity Center -crop 3840x2160+0+0 -filter Lanczos -resize 1280x720 -quality 100 output.thumbnail.png
rm $image_output

# Clean up temporary directory
rm -rf $tmpdir
