#!/bin/bash
# Made by katattakd. Dependencies: FFMPEG, SoX, ImageMagick, GNU Coreutils, waifu2xcpp
# Note: Make sure you have at least 6GB of available RAM before running this script.
# Encoding is purely CPU based, and may take a while on slower CPUs.

##### Tunables:

# Directory that the script uses to store temporary files. If you need to run multiple instances of the script, this must be different for every instance.
# This directory is cleaned out every time the script starts (or created if it does not exist), and removed after the script sucessfully completes.
export temporary_directory="/tmp/nightcore.sh"

# Change the amount that waifu2x denoises the image (0-3). Setting this too high can result in loss of detail, especially in non-anime images. 2 is a good middle-ground for anime images, where noise is significantly reduced without noticeable detail loss. If the background is not anime-style or is already high quality, try lowering this value.
export waifu2x_denoise_amount=2

# Change the fontconfig settings used to draw text. Colons must be escaped.
export fontconfig='family=sans-serif\:weight=50\:antialias=true\:hinting=false\:lcdfilter=0\:minspace=true'

# Change the font size multipliers. The first option affects video text, the second option affects video info text, the third affects thumbnail text, and the forth affects thumbnail info text.
export video_font_multiplier=1.1
export video_info_multiplier=0.65
export thumbnail_font_multiplier=1.87
export thumbnail_info_multiplier=0.7

# Change the font padding multipliers. The first option affects video text, the second affects thumbnail text.
export video_padding_multiplier=1.1
export thumbnail_padding_multiplier=3

# Change the opacity of overlays. The first option affects the video text, the second option affects the audio visualizer, and the third option affects the thumbnail text.
export video_overlay_alpha=0.74
export visualizer_overlay_alpha=0.78
export thumbnail_overlay_alpha=0.8

# Change the number of bars shown on the visualizer.
export visualizer_bars=100

# Change the maximum frequency shown on the visualizer in (will be adjusted slightly based on speed multiplier). Supported range is 120Hz - 20000Hz.
export visualizer_max_freq=12500

# Change the x265 video compression preset used. Available options are ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, and veryslow. Slower presets will result in more efficient compression.
export x265_encoder_preset="slow"

##### Start of code

ffloglevelstr="-loglevel error -y"
fploglevelstr="-loglevel error -of csv=p=0"
sxloglevelstr="-V1"
w2loglevelstr="-v 0"
afiletypes=( "input.flac" "input.wv" "input.tta" "input.ddf" "input.dsf" "input.wav" "input.wave" "input.caf" "input.mka" "input.opus" "input.ogg" "input.oga" "input.vorbis" "input.spx" "input.m4a" "input.m4b" "input.m4r" "input.mp3" "input.bit" )
vfiletypes=( "input.png" "input.tiff" "input.tif" "input.pam" "input.pnm" "input.ppm" "input.pgm" "input.pbm" "input.bmp" "input.dib" "input.psd" "input.apng" "input.exr" "input.webp" "input.jp2" "input.jpg" "input.jpeg" "input.jpe" "input.jfi" "input.jfif" "input.jif" "input.gif" "input.mkv" )
script_dir="$(dirname "$0")"
set -euo pipefail

if [[ ! (`command -v sox` && `command -v soxi` && `command -v ffmpeg` && `command -v ffprobe` && `command -v magick` && `command -v waifu2x-converter-cpp`) ]]; then
	echo "Please install the required dependencies before attempting to run the script."
	exit
fi

if [[ ! -s "speed.txt" ]]; then
	echo "Please create a speed.txt file stating the speed multiplier you want to use (like 1.1 or 1.2)."
	exit
fi
audio_speed=$(cat speed.txt)

# Initalize temporary directory.
tmpdir="$temporary_directory"
rm -rf $tmpdir
mkdir -p $tmpdir

echo "Processing input files..."

# Generate info text
info_text="$tmpdir/info.txt"
info_text_short="$tmpdir/info_short.txt"
if [ -f "info.txt" ]; then
	cp info.txt $info_text
	if [ -f "info_short.txt" ]; then
		cp info_short.txt $info_text_short
	else
		cp info.txt $info_text_short
	fi
elif [ -d "$script_dir/.git" ]; then
	echo "nightcore.sh commit $(git rev-parse --short HEAD)" > $info_text
	cp $info_text $info_text_short
fi

# Remove metadata, fix clipping, speed up audio, normalize volume, and generate title text.
# Note: Fixing of clipped samples is done before all other effects, so that all clipped samples are detected properly.
# Fade-in must be done before silence removal, and after speed adjustment, to prevent timing issues.
# Loudness normalization must be done last, and cannot be combined with other encoding passes.
audio_begin="$tmpdir/begin_audio"
audio_end="$tmpdir/finish_audio"
audio_stage1="$tmpdir/stage1.wav"
audio_output="$tmpdir/output.wav"
audio_title="$tmpdir/title.txt"
audio_title_short="$tmpdir/title_short.txt"
function process_audio {
	touch $audio_begin

	artist=$(ffprobe $fploglevelstr -select_streams a:0 -show_entries format_tags=ARTIST "$1")
	title=$(ffprobe $fploglevelstr -select_streams a:0 -show_entries format_tags=TITLE "$1")
	
	if [ -f "title.txt" ]; then
		cp title.txt $audio_title
		if [ -f "title_short.txt" ]; then
			cp title_short.txt $audio_title_short
		else
			cat title.txt | tr -d \" | sed 's/([^)]*)//g;s/  / /g' > $audio_title_short
		fi
	elif [ ! -z "$artist" ] && [ ! -z "$title" ]; then
		echo "$artist - $title" | tr -d \" > $audio_title
		echo "$(echo $artist | sed 's/,.*//') - $title" | tr -d \" | sed 's/([^)]*)//g;s/  / /g' > $audio_title_short
	elif [ ! -z "$artist" ]; then
		echo "$artist" | tr -d \" > $audio_title
		echo "$artist" | tr -d \" | sed 's/([^)]*)//g;s/  / /g' > $audio_title_short
	elif [ ! -z "$title" ]; then
		echo "$title" | tr -d \" > $audio_title
		echo "$title" | tr -d \" | sed 's/([^)]*)//g;s/  / /g' > $audio_title_short
	fi

	ffmpeg $ffloglevelstr -i "$1" -vn -map_metadata -1 -af "volume=-15dB,adeclip=a=25:n=500:m=s" -f sox - | sox $sxloglevelstr -p -p --guard --multi-threaded --buffer 1000000 speed "$2" rate -v -I 48k gain -n | ffmpeg $ffloglevelstr -f sox -i - -af "afade=t=in:ss=0:d=0.5:curve=squ,silenceremove=start_threshold=-95dB:start_mode=all:stop_periods=-1:stop_threshold=-95dB" $audio_stage1

	loudnorm=$(ffmpeg -i $audio_stage1 -af "loudnorm=print_format=summary:tp=-1:i=-14:lra=20" -f null - 2>&1)
	loudnorm_i=$(echo "$loudnorm" | grep "Input Integrated:" | awk '{ print $3+0 }')
	loudnorm_tp=$(echo "$loudnorm" | grep "Input True Peak:" | awk '{ print $4+0 }')
	loudnorm_lra=$(echo "$loudnorm" | grep "Input LRA:" | awk '{ print $3+0 }')
	loudnorm_thresh=$(echo "$loudnorm" | grep "Input Threshold:" | awk '{ print $3+0 }')
	loudnorm_offset=$(echo "$loudnorm" | grep "Target Offset:" | awk '{ print $3+0 }')
	ffmpeg $ffloglevelstr -i $audio_stage1 -af "loudnorm=linear=true:tp=-1:i=-14:lra=20:measured_i=$loudnorm_i:measured_lra=$loudnorm_lra:measured_tp=$loudnorm_tp:measured_thresh=$loudnorm_thresh:offset=$loudnorm_offset" $audio_output

	rm $audio_stage1
	touch $audio_end
}

# Remove metadata, trim image, AI upscale image, crop image to 4000x2320, and generate thumbnail.
# Note: Image trimming must be done before upscaling, to ensure final image is >=4000x2320.
# Image cropping must be done after upscaling, to ensure input image >=4000x2320.
image_begin="$tmpdir/begin_image"
image_end="$tmpdir/finish_image"
image_stage1="$tmpdir/stage1.ppm"
image_stage2="$tmpdir/stage2.ppm"
image_stage3="$tmpdir/stage3.ppm"
image_stage4="$tmpdir/stage4.ppm"
image_output="$tmpdir/output.ppm"
image_output_thumbnail="output.thumbnail.png"
function process_image {
	touch $image_begin
	ffmpeg $ffloglevelstr -i $1 -an -vframes 1 -map_metadata -1 -vcodec png -f image2pipe - | magick - -background white -alpha remove -alpha off -fuzz 1% -trim $image_stage1

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

	touch $image_end

	rm $image_stage2
	magick $image_output -gravity Center -crop 3840x2160+0+0 -filter Lanczos -resize 1280x720 $image_stage3

	while [[ ! -f "$audio_output" ]]; do
		sleep 0.1
	done
	font_size=$(echo $thumbnail_font_multiplier | awk '{print int(($1 * (80/3))+0.5) }')
	info_font_size=$(echo $thumbnail_font_multiplier $thumbnail_info_multiplier | awk '{print int(($1 * $2 * (80/3))+0.5) }')
	padding=$(echo $thumbnail_padding_multiplier | awk '{print int(($1 * (25/3))+0.5)}')
	if [ -s "$audio_title_short" ]; then
		ttext="drawtext=box=1:boxcolor=black:boxborderw=$padding:fontcolor=white:fontfile=\'$fontconfig\':fontsize=$font_size:text='$(cat $audio_title_short)':x=$(($padding*3)):y=$(($padding*3)):alpha=0.8"
		if [ ! $(echo $audio_speed | awk '{ print int(($1 * 100)+0.5) }' ) -eq 100 ]; then
			ttext="$ttext,drawtext=box=1:boxcolor=black:boxborderw=$padding:fontcolor=white:fontfile=\'$fontconfig\':fontsize=$font_size:text='[${audio_speed}x speed]':x=$(($padding*3)):y=$((($padding*6)+$font_size)):alpha=$thumbnail_overlay_alpha"
		fi
		if [ -s "$info_text_short" ]; then
			ttext="$ttext,drawtext=box=1:boxcolor=black:boxborderw=$padding:fontcolor=white:fontfile=\'$fontconfig\':fontsize=$info_font_size:text='$(cat $info_text_short)':x=$((1280-($padding*3)))-text_w:y=$((720-($padding*3)))-text_h:alpha=$thumbnail_overlay_alpha"
		fi
		ffmpeg $ffloglevelstr -i $image_stage3 -vf "$ttext" $image_stage4
	else
		if [ -s "$info_text_short" ]; then
			ttext="drawtext=box=1:boxcolor=black:boxborderw=$padding:fontcolor=white:fontfile=\'$fontconfig\':fontsize=$info_font_size:text='$(cat $info_text_short)':x=$((1280-($padding*3)))-text_w:y=$((720-($padding*3)))-text_h:alpha=$thumbnail_overlay_alpha"
			ffmpeg $ffloglevelstr -i $image_stage3 -vf "$ttext" $image_stage4
		else
			cp $image_stage3 $image_stage4
		fi
	fi
	rm $image_stage3
	convert $image_stage4 -quality 100 $image_output_thumbnail
	rm $image_stage4
}

for i in "${afiletypes[@]}"; do
	if [[ -f "$i" ]]; then
		process_audio "$i" "$audio_speed" &
		break
	fi
done

sleep 0.1
if [[ ! -f "$audio_begin" ]]; then
	echo "Input audio is required! File must be named input.(extension)"
	exit
else
	rm "$audio_begin"
fi


for i in "${vfiletypes[@]}"; do
	if [[ -f "$i" ]]; then
		process_image $i &
		break
	fi
done

sleep 0.1
if [[ ! -f "$image_begin" ]]; then
	echo "Input image is required! File must be named input.(extension)"
	exit
else
	rm "$image_begin"
fi

# Wait for audio processing to complete
while [[ ! -f "$audio_end" ]]; do
	sleep 0.1
done
rm $audio_end

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
	while [ $(echo $(($newx-$x)) | tr -d -) -gt 90 ] || [ $(echo $(($newy-$y)) | tr -d -) -gt 90 ]; do
		newx=$((($RANDOM % (120-$x))))
		newy=$((($RANDOM % (120-$y))))
	done
	filterx="if(gt(t/4\,$i)\,$x+($(($newx-$x))*(sqrt((t/4)-$i)*(sin(((t/4)-$i)*PI/2))))\,$filterx)"
	filtery="if(gt(t/4\,$i)\,$y+($(($newy-$y))*(sqrt((t/4)-$i)*(sin(((t/4)-$i)*PI/2))))\,$filtery)"
	x=$newx
	y=$newy
done
visualizer_start=$(echo $audio_speed | awk '{ print $1 * 20 }')
visualizer_end=$(echo $audio_speed | awk '{ print $1 * '$visualizer_max_freq' }')
font_size=$(echo $video_font_multiplier | awk '{print int(($1 * 80)+0.5) }')
info_font_size=$(echo $video_font_multiplier $video_info_multiplier | awk '{print int(($1 * $2 * 80)+0.5) }')
padding=$(echo $video_padding_multiplier | awk '{print int(($1 * 25)+0.5)}')
if [ -s "$audio_title" ]; then
	if [ $(echo $audio_speed | awk '{ print int(($1 * 100)+0.5) }' ) -eq 100 ]; then
		rtext="$(cat $audio_title)"
	else
		rtext="[${audio_speed}x speed] $(cat $audio_title)"
	fi
	atext="drawtext=box=1:boxcolor=black:boxborderw=$padding:fontcolor=white:fontfile=\'$fontconfig\':fontsize=$font_size:text='$rtext':x=$(($padding*3)):y=$(($padding*3)):alpha=$video_overlay_alpha"
	if [ -s "$info_text" ]; then
		atext="$atext,drawtext=box=1:boxcolor=black:boxborderw=$padding:fontcolor=white:fontfile=\'$fontconfig\':fontsize=$info_font_size:text='$(cat $info_text)':x=$(($padding*3)):y=$((($padding*6)+$font_size)):alpha=$video_overlay_alpha"
	fi
elif [ -s "$info_text" ]; then
	atext="drawtext=box=1:boxcolor=black:boxborderw=$padding:fontcolor=white:fontfile=\'$fontconfig\':fontsize=$info_font_size:text='$(cat $info_text)':x=$(($padding*3)):y=$(($padding*3)):alpha=$video_overlay_alpha"
else
	atext="null"
fi
filtergraph="[0:a]showcqt=s=${visualizer_bars}x1080:r=60:axis_h=0:sono_h=0:bar_v=26dB*a_weighting(f):bar_g=6:count=30:basefreq=$visualizer_start:endfreq=$visualizer_end:cscheme=0.0001|0.0001|0.0001|0.0001|0.0001|0.0001,setsar=0,colorkey=black:0.01:0,lut=c0=0:c1=0:c2=0:c3=if(val\,$(echo $visualizer_overlay_alpha | awk '{ print int(($1 * 255)+.5) }')\,0),scale=3840x1080:sws_flags=neighbor[visualizer];
[1:v]format=pix_fmts=gbrp,loop=loop=-1:size=1,crop=3840:2160:$filterx:$filtery,$atext[background];
[background][visualizer]overlay=shortest=1:x=0:y=1080:eval=init:format=gbrp"

# Wait for image processing to complete
while [[ ! -f "$image_end" ]]; do
	sleep 0.1
done
rm "$image_end"

# Render video with generated filtergraph
echo "Rendering video..."
ffmpeg $ffloglevelstr -stats -i $audio_output -i $image_output -c:v libx265 -r 60 -filter_complex "$filtergraph" -x265-params lossless=1 -preset "$x265_encoder_preset" -c:a flac -compression_level 12 -exact_rice_parameters 1 output.mkv
rm $audio_output
rm $image_output
if [ `command -v mkvpropedit` ]; then
	mkvpropedit -q output.mkv --attachment-name cover_land.png --attachment-mime-type "image/png" --add-attachment $image_output_thumbnail
fi

# Clean up temporary directory
rm -rf $tmpdir
