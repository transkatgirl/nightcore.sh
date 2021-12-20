set -euo pipefail

font_multiplier=1.87
info_multiplier=0.7
padding_multiplier=3
font_align="$thumbnail_font_align"

calculate_sizes

ffmpeg -i "$1" -vf "crop=$output_width:$output_height,\
	$drawtext:fontsize=$font_size:textfile='$tmpdir/title_short.txt':x=$font_x:y=$(($padding*3)),\
	$drawtext:fontsize=$font_size:text='[`cat "$tmpdir/speed.txt"`x speed]':x=$font_x:y=$((($padding*6)+$font_size)),\
	$drawtext:fontsize=$info_font_size:textfile='$tmpdir/info.txt':x=$font_alt_x:y=$(($output_height-($padding*3)))-text_h\
	" "$2"
