set -euo pipefail

# Command abbreviations

alias ffmpeg="ffmpeg -loglevel error"
alias ffprobe="ffprobe -loglevel error -of csv=p=0"
alias sox="sox -V1"

# Input media format list

audio_ext=( "flac" "wv" "tta" "ddf" "dsf" "wav" "wave" "caf" "mka" "opus" "ogg" "oga" "vorbis" "spx" "m4a" "m4b" "m4r" "mp3" "bit" )
image_ext=( "png" "tiff" "tif" "pam" "pnm" "ppm" "pgm" "pbm" "bmp" "dib" "psd" "apng" "exr" "webp" "jp2" "jpg" "jpeg" "jpe" "jfi" "jfif" "jif" "gif" "mkv" )
lyric_ext=( "vtt" "srt" "ssa" "ass" "lrc" )

# Output media format settings

# Output sample rate should be ideally be *slightly* greater than (or at least fairly close to) the input sample rate.
# Most music is 44100hz, so we go with 48000hz as our output sample rate.
# Using 48000hz also provides the advantage of allowing Opus compression (used by sites like YouTube, and the compress.sh script) without resampling.
output_sample_rate=48000

# Note: Maximum possible resoultion is currently 4267x2000, higher resoultions will cause issues with the music visualizer.
# Note: Aspect ratio must be 16:9. Support for arbitrary aspect ratios may be implemented in the future.
output_width=3840
output_height=2160

# There's no realistic maximum framerate, apart from what's realistic to render & decode.
# You'll ideally want the framerate to be the same as (or a multiple of) the display's refresh rate.
# We go with 60hz, because the vast majority of displays are either 60hz or a multiple of it (120hz, 30hz, etc).
output_framerate=60

# This sets the target (in LUFS) used for the volume normalization.
# Warning: Setting this too high can cause the audio processing step to fail!
# Common LUFS targets:
# -11 LUFS = Amazon Music
# -14 LUFS = Spotify, YouTube
# -16 LUFS = Apple Music
# -24 LUFS = EBU R128 target
loudness_target_lufs=-16

# Glide area calculations

glide_margin=$(($output_width/48))
glide_area=$(($glide_margin*2))

padded_width=$(($output_width+$glide_area))
padded_height=$(($output_height+$glide_area))

# Number processing commands

alias floor="awk '{ print int(\$1) }'"
alias ceil="awk '{ print int(\$1 + 1) }'"
alias abs="tr -d -"
alias rand="shuf --random-source=/dev/random -n 1 -i "
alias max="awk '{ print (\$1>\$2)?\$1:\$2 }'"

# Text processing commands

alias trim_whitespace="tr '\n' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'"
alias remove_quotes="tr -d \\\""
alias replace_commas="sed 's/, / \& /g'"
alias remove_ampersand="sed 's/&.*//' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'"
alias remove_parenthesis="sed 's/([^)]*)//g;s/  / /g'"
alias remove_featuring="sed 's/Featuring.*//'"

# Fontconfig configuration

fontconfig="$tmpdir/font.ttf\:weight=50\:antialias=true\:hinting=false\:lcdfilter=0\:minspace=true"

# Font configuration tools

calculate_sizes() {
	padding=`echo $output_width $padding_multiplier | awk '{print int($1 * $2 * (5/768))}'`
	font_size=`echo $output_width $font_multiplier | awk '{print int($1 * $2 *  (1/48))}'`
	info_font_size=`echo $output_width $font_multiplier $info_multiplier | awk '{print int($1 * $2 * $3 * (1/48))}'`

	if [ "$font_align" == "right" ]; then
		font_x="$(($output_width-($padding*3)))-text_w"
		font_alt_x="$(($padding*3))"
	elif [ "$font_align" == "center" ]; then
		font_x="$(($output_width/2))-(text_w/2)"
		font_alt_x="$(($output_width/2))-(text_w/2)"
	else
		font_x="$(($padding*3))"
		font_alt_x="$(($output_width-($padding*3)))-text_w"
	fi

	drawtext="drawtext=box=1:boxcolor=#000000:boxborderw=$padding:fontcolor=#ffffff:fontfile=\'$fontconfig\':alpha=0.76"
}
