#!/bin/bash
# Made by katattakd. Dependencies: FFMPEG, SoX, ImageMagick, GNU Coreutils, waifu2xcpp
# Note: Make sure you have at least 6GB of available RAM before running this script.
# Encoding is purely CPU based, and may take a while on slower CPUs.

##### Tunables:

# Directory that the script uses to store temporary files. If you need to run multiple instances of the script, this must be different for every instance.
# This directory is cleaned out every time the script starts (or created if it does not exist), and removed after the script sucessfully completes.
export temporary_directory="/tmp/nightcore.sh.$(date +"%s")_$RANDOM"

# Change the colors used for text. The first option affects the text itself, the second option affects the overlay box. Set the second option to "#00000000" to disable rendering the overlay box.
export text_color="#ffffff"
export text_overlay_color="#000000"

# Change the color used for the audio visualizer.
export visualizer_overlay_color="#000000"

# Change the background color used for transparent images.
export alpha_background_color="#c2c2c2"

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

# Change the font alignment. The first option affects video text, and the second affects thumbnail text. Available options are "left" (default), "center", and "right".
export video_font_align="left"
export thumbnail_font_align="left"

# Change the opacity of overlays. The first option affects the video text, the second option affects the audio visualizer, and the third option affects the thumbnail text.
export video_overlay_alpha=0.76
export visualizer_overlay_alpha=0.8
export thumbnail_overlay_alpha=0.8

# Change the number of bars shown on the visualizer. If you want a smooth graph instead of a bargraph, set this to 0.
export visualizer_bars=110

# Change the blur used to further smooth the visualizer during processing (ignored when rendering a bargraph visualizer). Set the visualizer_blur_power to 0 to disable blurring.
export visualizer_blur_radius=8
export visualizer_blur_power=3

# Change the maximum frequency shown on the visualizer in (will be adjusted slightly based on speed multiplier). Supported range is 120Hz - 20000Hz.
export visualizer_max_freq=12500

# Change the sensitivity of the visualizer. Supported range is 1 - 0.001
export visualizer_sens=0.2

# Change advanced visualizer options. These act more-or-less the same way as the options in visualizer.sh (https://gist.github.com/katattakd/cc81d24f3b05db19a02373a085f207f7)
export visualizer_sh_sono_gamma=1 # the sonograph is not actually rendered, but this still influences how the bargraph looks
export visualizer_sh_bar_gamma=3
export visualizer_sh_timeclamp=0.15
export visualizer_sh_vmult=12
export visualizer_sh_sspeed=3 # although there's no actual sonograph, this still affects how quickly the bargraph updates
export visualizer_sh_afchain="volume=5dB"

# Change the lossless x264 video compression preset used. Available options are ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow, and placebo. Slower presets will result in more efficient compression.
export x264_encoder_preset="medium"

##### Start of code

if [ -s "options.sh" ]; then
	echo "Loading config..."
	source ./options.sh
fi
if [ "$visualizer_bars" -eq 0 ]; then
	visualizer_bars=3840
else
	visualizer_blur_power=0
fi
ffloglevelstr="-loglevel error -y"
fploglevelstr="-loglevel error -of csv=p=0"
sxloglevelstr="-V1"
w2loglevelstr="-v 0"
afiletypes=( "input.flac" "input.wv" "input.tta" "input.ddf" "input.dsf" "input.wav" "input.wave" "input.caf" "input.mka" "input.opus" "input.ogg" "input.oga" "input.vorbis" "input.spx" "input.m4a" "input.m4b" "input.m4r" "input.mp3" "input.bit" )
vfiletypes=( "input.png" "input.tiff" "input.tif" "input.pam" "input.pnm" "input.ppm" "input.pgm" "input.pbm" "input.bmp" "input.dib" "input.psd" "input.apng" "input.exr" "input.webp" "input.jp2" "input.jpg" "input.jpeg" "input.jpe" "input.jfi" "input.jfif" "input.jif" "input.gif" "input.mkv" )
sfiletypes=( "input.vtt" "input.srt" "input.ssa" "input.ass" "input.lrc" )
script_dir="$(dirname "$0")"
set -Eeuo pipefail

if [[ ! (`command -v sox` && `command -v soxi` && `command -v ffmpeg` && `command -v ffprobe` && `command -v magick` && `command -v waifu2x-converter-cpp`) ]]; then
	echo "Please install the required dependencies before attempting to run the script."
	exit
fi
if [ `command -v npm` ] && [ `command -v node` ] && [ -d "$script_dir/subtitles" ] && [ ! -d "$script_dir/subtitles/node_modules" ]; then
	npm install --prefix "$script_dir/subtitles"
fi

if [[ ! -s "speed.txt" ]]; then
	echo "Please create a speed.txt file stating the speed multiplier you want to use (like 1.1 or 1.2)."
	exit
fi
audio_speed="$(cat "speed.txt")"

# Initalize temporary directory.
tmpdir="$temporary_directory"
rm -rf "$tmpdir"
mkdir -p "$tmpdir"

trap ctrl_c INT
trap ctrl_c ERR

function ctrl_c() {
	echo "Exit signal detected, stopping and cleaning up..."
        rm -rf "$tmpdir"
}

echo "Note: Image and audio processing is multi-threaded, so the last console log message may not be the active processing step."

# Generate info text
info_text=""
info_text_short=""
if [ -f "info.txt" ]; then
	info_text="$(cat info.txt)"
	if [ -f "info_short.txt" ]; then
		info_text_short="$(cat info_short.txt)"
	else
		info_text_short="$info_text"
	fi
elif [ -d "$script_dir/.git" ]; then
	info_text="nightcore.sh commit $(git -C "$script_dir" rev-parse --short HEAD)"
	info_text_short="$info_text"
fi

# Remove metadata, fix clipping, speed up audio, normalize volume, and generate title text.
# Note: Fixing of clipped samples is done before all other effects, so that all clipped samples are detected properly.
# Fade-in must be done before silence removal, and after speed adjustment, to prevent timing issues.
# Loudness normalization must be done last, and cannot be combined with other encoding passes.
audio_begin="$tmpdir/begin_audio"
audio_end="$tmpdir/finish_audio"
audio_stage1="$tmpdir/stage1.wav"
audio_stage2="$tmpdir/output.wav"
audio_output="output.flac"
audio_title="$tmpdir/title.txt"
audio_title_short="$tmpdir/title_short.txt"
function process_audio {
	touch "$audio_begin"

	artist="$(ffprobe $fploglevelstr -select_streams a:0 -show_entries format_tags=ARTIST "$1")"
	title="$(ffprobe $fploglevelstr -select_streams a:0 -show_entries format_tags=TITLE "$1")"
	
	if [ -f "title.txt" ]; then
		cp title.txt "$audio_title"
		if [ -f "title_short.txt" ]; then
			cp title_short.txt "$audio_title_short"
		else
			cat title.txt | tr -d \" | sed 's/([^)]*)//g;s/  / /g' | sed "s/Featuring.*//" > "$audio_title_short"
		fi
	elif [ ! -z "$artist" ] && [ ! -z "$title" ]; then
		echo "$artist - $title" | tr -d \" | sed 's/, / \& /g' > "$audio_title"
		echo "$(echo "$artist" | sed 's/,.*//') - $title" | tr -d \" | sed 's/([^)]*)//g;s/  / /g' | sed "s/Featuring.*//" > "$audio_title_short"
	elif [ ! -z "$artist" ]; then
		echo "$artist" | tr -d \" | sed 's/, / \& /g' > "$audio_title"
		echo "$artist" | tr -d \" | sed 's/, / \& /g' | sed 's/([^)]*)//g;s/  / /g' | sed "s/Featuring.*//" > "$audio_title_short"
	elif [ ! -z "$title" ]; then
		echo "$title" | tr -d \" | sed 's/, / \& /g' > "$audio_title"
		echo "$title" | tr -d \" | sed 's/([^)]*)//g;s/  / /g' | sed "s/Featuring.*//" > "$audio_title_short"
	fi

	echo "Processing audio..."
	ffmpeg $ffloglevelstr -i "$1" -vn -af "volume=-15dB,adeclip=a=25:n=500:m=s" -f sox - | sox $sxloglevelstr -p -p --guard --multi-threaded --buffer 1000000 speed "$2" rate -v -I 48k gain -n | ffmpeg $ffloglevelstr -f sox -i - -af "afade=t=in:ss=0:d=0.5:curve=squ,silenceremove=start_threshold=-90dB:start_mode=all:stop_periods=-1:stop_threshold=-90dB" "$audio_stage1"

	echo "Normalizing audio loudness..."
	loudnorm="$(ffmpeg -i "$audio_stage1" -af "loudnorm=print_format=summary:tp=-1:i=-14:lra=20" -f null - 2>&1)"
	loudnorm_i="$(echo "$loudnorm" | grep "Input Integrated:" | awk '{ print $3+0 }')"
	loudnorm_tp="$(echo "$loudnorm" | grep "Input True Peak:" | awk '{ print $4+0 }')"
	loudnorm_lra="$(echo "$loudnorm" | grep "Input LRA:" | awk '{ print $3+0 }')"
	loudnorm_thresh="$(echo "$loudnorm" | grep "Input Threshold:" | awk '{ print $3+0 }')"
	loudnorm_offset="$(echo "$loudnorm" | grep "Target Offset:" | awk '{ print $3+0 }')"
	ffmpeg $ffloglevelstr -i "$audio_stage1" -af "loudnorm=linear=true:tp=-1:i=-14:lra=20:measured_i=$loudnorm_i:measured_lra=$loudnorm_lra:measured_tp=$loudnorm_tp:measured_thresh=$loudnorm_thresh:offset=$loudnorm_offset" -map_metadata -1 "$audio_stage2"

	rm "$audio_stage1"

	echo "Compressing audio..."
	if [ `command -v flac` ]; then
		flac --totally-silent --force --best -e -l 12 -p -r 0,8 -o "$audio_output" "$audio_stage2"
	else
		ffmpeg $ffloglevelstr -i "$audio_stage2" -c:a flac -compression_level 12 -exact_rice_parameters 1 "$audio_output"
	fi
	rm "$audio_stage2"

	touch "$audio_end"
}

filtergraph_end="$tmpdir/finish_filtergraph"

# Remove metadata, trim image, AI upscale image, crop image to 4000x2320, and generate thumbnail.
# Note: Image trimming must be done before upscaling, to ensure final image is >=4000x2320.
# Image cropping must be done after upscaling, to ensure input image >=4000x2320.
image_begin="$tmpdir/begin_image"
image_end="$tmpdir/finish_image"
image_thumbnail_end="$tmpdir/finish_image_thumbnail"
image_stage1="$tmpdir/stage1.ppm"
image_stage2="$tmpdir/stage2.ppm"
image_stage3="$tmpdir/stage3.ppm"
image_stage4="$tmpdir/stage4.ppm"
image_stage5="$tmpdir/stage5.ppm"
image_output="$tmpdir/output.ppm"
image_output_thumbnail="output.thumbnail.png"
function process_image {
	touch "$image_begin"
	echo "Processing image..."
	ffmpeg $ffloglevelstr -i "$1" -an -vframes 1 -map_metadata -1 -vcodec png -sws_flags +accurate_rnd+full_chroma_int -f image2pipe - | magick - -background "$alpha_background_color" -alpha remove -alpha off "$image_stage1"

	min_width="$(ffprobe $fploglevelstr -select_streams v:0 -show_entries stream=width "$image_stage1" | awk '{ print int($1*0.87) }')"
	min_height="$(ffprobe $fploglevelstr -select_streams v:0 -show_entries stream=height "$image_stage1" | awk '{ print int($1*0.87) }')"

	magick "$image_stage1" -fuzz 2.5% -define trim:percent-background=95% -trim +repage "$image_stage2"
	if [ "$min_width" -ge "$(ffprobe $fploglevelstr -select_streams v:0 -show_entries stream=width "$image_stage2")" ] || [ "$min_height" -ge "$(ffprobe $fploglevelstr -select_streams v:0 -show_entries stream=height "$image_stage2")" ]; then
		mv "$image_stage1" "$image_stage2"
	else
		rm "$image_stage1"
	fi

	width="$(ffprobe $fploglevelstr -select_streams v:0 -show_entries stream=width "$image_stage2")"
	width_scale="$(echo "$width" | awk '{ print int((4000/$1)+0.99999) }')"
	height="$(ffprobe $fploglevelstr -select_streams v:0 -show_entries stream=height "$image_stage2")"
	height_scale="$(echo "$height" | awk '{ print int((2320/$1)+0.99999) }')"
	if [ "$width_scale" -ge "$height_scale" ]; then
		w2x_scale="$width_scale"
	else
		w2x_scale="$height_scale"
	fi
	if [ "$w2x_scale" -le 2 ]; then
		w2x_denoise=0
	elif [ "$w2x_scale" -le 3 ]; then
		w2x_denoise=1
	elif [ "$w2x_scale" -le 5 ]; then
		w2x_denoise=2
	else
		w2x_denoise=3
	fi
	if [ "$w2x_scale" -gt 1 ]; then
		echo "Upscaling and denoising image..."
		waifu2x-converter-cpp $w2loglevelstr -m noise-scale --scale-ratio $w2x_scale --noise-level $w2x_denoise -i "$image_stage2" -o "$image_stage3"
		rm "$image_stage2"
	else
		mv "$image_stage2" "$image_stage3"
	fi

	echo "Cropping image..."
	if [ $(echo $width $height | awk '{ print int(($1/$2)*100) }') -gt 130 ]; then
		gravity="Center"
	else
		gravity="North"
	fi
	magick "$image_stage3" -filter Lanczos -resize 4000x2320^ -gravity $gravity -crop 4000x2320+0+0 +repage "$image_output"

	echo "Generating thumbnail..."

	rm "$image_stage3"
	magick "$image_output" -gravity Center -crop 3840x2160+0+0 +repage -filter Lanczos -resize 1280x720 "$image_stage4"

	while [[ ! -f "$audio_output" ]]; do
		sleep 0.1
	done
	font_size="$(echo "$thumbnail_font_multiplier" | awk '{print int(($1 * (80/3))+0.5) }')"
	info_font_size="$(echo $thumbnail_font_multiplier $thumbnail_info_multiplier | awk '{print int(($1 * $2 * (80/3))+0.5) }')"
	padding="$(echo $thumbnail_padding_multiplier | awk '{print int(($1 * (25/3))+0.5)}')"
	if [ "$thumbnail_font_align" == "right" ]; then
		font_x="$((1280-($padding*3)))-text_w"
		font_alt_x="$(($padding*3))"
	elif [ "$thumbnail_font_align" == "center" ]; then
		font_x="640-(text_w/2)"
		font_alt_x="640-(text_w/2)"
	else
		font_x="$(($padding*3))"
		font_alt_x="$((1280-($padding*3)))-text_w"
	fi
	if [ -s "$audio_title_short" ]; then
		ttext="drawtext=box=1:boxcolor=$text_overlay_color:boxborderw=$padding:fontcolor=$text_color:fontfile=\'$fontconfig\':fontsize=$font_size:textfile='$audio_title_short':x=$font_x:y=$(($padding*3)):alpha=0.8:line_spacing=-$font_size"
		if [ $(echo $audio_speed | awk '{ print int(($1 * 100)+0.5) }' ) -ne 100 ]; then
			ttext="$ttext,drawtext=box=1:boxcolor=$text_overlay_color:boxborderw=$padding:fontcolor=$text_color:fontfile=\'$fontconfig\':fontsize=$font_size:text='[${audio_speed}x speed]':x=$font_x:y=$((($padding*6)+$font_size)):alpha=$thumbnail_overlay_alpha"
		fi
		if [ -n "$info_text_short" ]; then
			ttext="$ttext,drawtext=box=1:boxcolor=$text_overlay_color:boxborderw=$padding:fontcolor=$text_color:fontfile=\'$fontconfig\':fontsize=$info_font_size:text='$info_text_short':x=$font_alt_x:y=$((720-($padding*3)))-text_h:alpha=$thumbnail_overlay_alpha"
		fi
		ffmpeg $ffloglevelstr -i "$image_stage4" -vf "$ttext" "$image_stage5"
	else
		if [ -n "$info_text_short" ]; then
			ttext="drawtext=box=1:boxcolor=$text_overlay_color:boxborderw=$padding:fontcolor=$text_color:fontfile=\'$fontconfig\':fontsize=$info_font_size:text='$info_text_short':x=$font_alt_x:y=$((720-($padding*3)))-text_h:alpha=$thumbnail_overlay_alpha"
			ffmpeg $ffloglevelstr -i "$image_stage4" -vf "$ttext" "$image_stage5"
		else
			cp "$image_stage4" "$image_stage5"
		fi
	fi
	rm "$image_stage4"

	convert "$image_stage5" -quality 100 "$image_output_thumbnail"
	rm "$image_stage5"

	if [ `command -v metaflac` ]; then
		while [[ ! -f "$filtergraph_end" ]]; do
			sleep 0.1
		done
		metaflac --import-picture-from="$image_output_thumbnail" "$audio_output"
	fi

	touch "$image_end"

	if [ `command -v pngcrush` ]; then
		pngcrush -s -brute -ow "$image_output_thumbnail"
	fi
	touch "$image_thumbnail_end"
}

subtitle_stage1="$tmpdir/stage1.ass"
subtitle_stage2="$tmpdir/stage2.srt"
subtitle_output="output.srt"
function process_subtitles {
	if [ `command -v node` ] && [ -d "$script_dir/subtitles/node_modules" ]; then
		echo "Processing subtitles..."
		ffmpeg $ffloglevelstr -i "$1" -map_metadata -1 "$subtitle_stage1"
		node "$script_dir/subtitles/index.js" "$2" "$subtitle_stage1" "$subtitle_stage2"
		rm "$subtitle_stage1"
		ffmpeg $ffloglevelstr -i "$subtitle_stage2" "$subtitle_output"
		rm "$subtitle_stage2"
	fi
}

for i in "${afiletypes[@]}"; do
	if [[ -s "$i" ]]; then
		process_audio "$i" "$audio_speed" &
		break
	fi
done

sleep 0.1
if [[ ! -f "$audio_begin" ]]; then
	echo "Input audio is required! File must be named input.(extension)"
	exit
fi


for i in "${vfiletypes[@]}"; do
	if [[ -s "$i" ]]; then
		process_image "$i" &
		break
	fi
done

sleep 0.1
if [[ ! -f "$image_begin" ]]; then
	echo "Input image is required! File must be named input.(extension)"
	exit
fi

for i in "${sfiletypes[@]}"; do
	if [[ -s "$i" ]]; then
		process_subtitles "$i" "$audio_speed" &
		break
	fi
done

# Wait for audio processing to complete
while [[ ! -f "$audio_end" ]]; do
	sleep 0.1
done

# Create video filtergraph
length=$(soxi -D "$audio_output" | awk '{ print int($1 + 1) }')

function generate_glide {
	filterin="((t-$i)/$pspeed)"              # x
	filterequ_a="((-1*(($filterin-1)^2))+1)" # a(x) = -1 * ( x - 1 )^2 + 1
	filterequ_b="sin($filterin*(PI/2))"      # b(x) = sin( x * ( pi / 2 ) )
	filterequ_c="((-1*abs($filterin-1))+1)"  # c(x) = -1 * abs( x - 1 ) + 1

	full_length_equ="false"
	filterequ="sqrt($filterequ_c)*$filterequ_b"
	#filterequ="$filterequ_b"
	#filterequ="$filterequ_a"
	#filterequ="$filterequ_a*$filterequ_b"
	#filterequ="sqrt($filterequ_a*$filterequ_b)"
	#filterequ="$filterequ_c"

	filterp="if(gt(t\,$i)\,$p+($(($newp-$p))*($filterequ))\,$filterp)"
}

x=80
y=80
filterx="80"
filtery="80"
newx=80
newy=80
speedmult=10
i=0
while [ $(echo $i | awk '{ print int( $1 ) }') -le $length ] ; do
	while [ $(echo $(($newx-$x)) | tr -d -) -lt 20 ] || [ $(echo $(($newy-$y)) | tr -d -) -lt 20 ] || [ $(echo $(($newx-$x)) | tr -d -) -gt 60 ] || [ $(echo $(($newy-$y)) | tr -d -) -gt 60 ]; do
		newx=$(shuf -i 0-$((160-x)) -n 1)
		newy=$(shuf -i 0-$((160-y)) -n 1)
	done
	xspeed=$(echo $speedmult $(echo $(($newx-$x)) | tr -d -) | awk '{ print $2 / $1 }')
	yspeed=$(echo $speedmult $(echo $(($newy-$y)) | tr -d -) | awk '{ print $2 / $1 }')
	pspeed=$(echo $xspeed $yspeed | awk '{ print ($1>$2)?$1:$2 }')

	p="$x"
	newp="$newx"
	filterp="$filterx"
	generate_glide
	filterx="$filterp"

	p="$y"
	newp="$newy"
	filterp="$filtery"
	generate_glide
	filtery="$filterp"

	if [ "$full_length_equ" == "true" ]; then
		newx=80
		newy=80
		i=$(echo $i $pspeed | awk '{ print $1 + ( $2 * 2 ) }')
	else
		x=$newx
		y=$newy
		i=$(echo $i $pspeed | awk '{ print $1 + $2 }')
	fi
done

visualizer_start=$(echo "$audio_speed" | awk '{ print $1 * 20 }')
visualizer_end=$(echo "$audio_speed" | awk '{ print $1 * '$visualizer_max_freq' }')
font_size=$(echo "$video_font_multiplier" | awk '{print int(($1 * 80)+0.5) }')
info_font_size=$(echo "$video_font_multiplier" "$video_info_multiplier" | awk '{print int(($1 * $2 * 80)+0.5) }')
padding=$(echo "$video_padding_multiplier" | awk '{print int(($1 * 25)+0.5)}')
visualizer_r="$((16#${visualizer_overlay_color:1:2}))"
visualizer_g="$((16#${visualizer_overlay_color:3:2}))"
visualizer_b="$((16#${visualizer_overlay_color:5:2}))"
if [ "$video_font_align" == "right" ]; then
	font_x="$((3840-($padding*3)))-text_w"
elif [ "$video_font_align" == "center" ]; then
	font_x="1920-(text_w/2)"
else
	font_x="$(($padding*3))"
fi
if [ -s "$audio_title" ]; then
	if [ $(echo $audio_speed | awk '{ print int(($1 * 100)+0.5) }' ) -ne 100 ]; then
		if [ "$video_font_align" == "right" ]; then
			echo "$(cat $audio_title) [${audio_speed}x speed]" > $audio_title
		else
			echo "[${audio_speed}x speed] $(cat $audio_title)" > $audio_title
		fi
	fi
	atext="drawtext=box=1:boxcolor=$text_overlay_color:boxborderw=$padding:fontcolor=$text_color:fontfile=\'$fontconfig\':fontsize=$font_size:textfile='$audio_title':x=$font_x:y=$(($padding*3)):alpha=$video_overlay_alpha:line_spacing=-$font_size"
	if [ -n "$info_text" ]; then
		atext="$atext,drawtext=box=1:boxcolor=$text_overlay_color:boxborderw=$padding:fontcolor=$text_color:fontfile=\'$fontconfig\':fontsize=$info_font_size:text='$info_text':x=$font_x:y=$((($padding*6)+$font_size)):alpha=$video_overlay_alpha"
	fi
elif [ -n "$info_text" ]; then
	atext="drawtext=box=1:boxcolor=$text_overlay_color:boxborderw=$padding:fontcolor=$text_color:fontfile=\'$fontconfig\':fontsize=$info_font_size:text='$info_text':x=$font_x:y=$(($padding*3)):alpha=$video_overlay_alpha"
else
	atext="null"
fi
filtergraph="[0:a]$visualizer_sh_afchain,showcqt=s=${visualizer_bars}x1080:r=60:axis_h=0:sono_h=0:sono_v=$visualizer_sh_vmult*b_weighting(f):bar_v=$visualizer_sh_vmult*a_weighting(f):sono_g=$visualizer_sh_sono_gamma:bar_g=$visualizer_sh_bar_gamma:tc=$visualizer_sh_timeclamp:count=$(echo $visualizer_sh_sspeed 1080 | awk '{ print ($1 * $2)/120 }'):basefreq=$visualizer_start:endfreq=$visualizer_end:cscheme=$visualizer_sens|$visualizer_sens|$visualizer_sens|$visualizer_sens|$visualizer_sens|$visualizer_sens,setsar=0,format=rgba,boxblur=luma_radius=$visualizer_blur_radius:luma_power=$visualizer_blur_power,colorkey=black:0.01:0,lut=c0=$visualizer_r:c1=$visualizer_g:c2=$visualizer_b:c3=if(val\,$(echo "$visualizer_overlay_alpha" | awk '{ print int(($1 * 255)+.5) }')\,0),scale=3840x1080:sws_flags=neighbor[visualizer];
[1:v]format=pix_fmts=gbrp,loop=loop=-1:size=1,fps=fps=60,crop=3840:2160:$filterx:$filtery,$atext[background];
[background][visualizer]overlay=shortest=1:x=0:y=1080:eval=init:format=gbrp"
touch "$filtergraph_end"

# Wait for image processing to complete
while [[ ! -f "$image_end" ]]; do
	sleep 0.1
done

# Render video with generated filtergraph
echo "Rendering video..."
video_output="output.mkv"
ffmpeg $ffloglevelstr -stats -i "$audio_output" -i "$image_output" -c:v libx264rgb -crf 0 -g 999999 -filter_complex "$filtergraph" -sws_flags +accurate_rnd+full_chroma_int -preset "$x264_encoder_preset" -c:a copy -map_metadata -1 "$video_output"
rm "$image_output"
while [[ ! -f "$image_thumbnail_end" ]]; do
	sleep 0.1
done
if [ `command -v metaflac` ]; then
	metaflac --remove --block-type=PICTURE --dont-use-padding "$audio_output"
	metaflac --import-picture-from="$image_output_thumbnail" "$audio_output"
fi
if [ `command -v mkvpropedit` ]; then
	mkvpropedit -q "$video_output" --attachment-name cover_land.png --attachment-mime-type "image/png" --add-attachment "$image_output_thumbnail"
fi

# Clean up temporary directory
rm -rf "$tmpdir"
