set -euo pipefail
source "$script_dir/steps/_const.sh"
source "$tmpdir/prefs.sh"

font_multiplier=1.1
info_multiplier=0.65
padding_multiplier=1.1
font_align="$video_font_align"

calculate_sizes

if [ "$video_font_align" == "right" ]; then
	title="`cat "$tmpdir/title.txt"` [`cat "$tmpdir/speed.txt"`x speed]"
else
	title="[`cat "$tmpdir/speed.txt"`x speed] `cat "$tmpdir/title.txt"`"
fi

echo "$drawtext:fontsize=$font_size:text='$title':x=$font_x:y=$(($padding*3)),\
$drawtext:fontsize=$info_font_size:textfile='$tmpdir/info.txt':x=$font_x:y=$((($padding*6)+$font_size))" > "$1"
