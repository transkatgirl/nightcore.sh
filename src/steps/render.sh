set -euo pipefail
source "$script_dir/steps/_const.sh"

text=`cat "$tmpdir/filtergraph_text.txt"`
glide=`cat "$tmpdir/filtergraph_glide.txt"`
visualizer=`cat "$tmpdir/filtergraph_visualizer.txt"`

filtergraph="[0:a]$visualizer[visualizer];\
[1:v]format=pix_fmts=gbrp,loop=loop=-1:size=1,fps=fps=$output_framerate,$glide,$text[background];\
[background][visualizer]overlay=shortest=1:x=0:y=main_h-overlay_h:eval=init:format=gbrp"

substr=""
if [[ -s "$3" ]]; then
	substr="-i $3"
fi

echo "Rendering video..."
ffmpeg -y -stats -i "$1" -i "$2" $substr -filter_complex "$filtergraph" \
	-c:v libx264rgb -crf 0 -g 999999 \
	-c:a copy \
	-c:s copy -attach "$4" -metadata:s:t mimetype=image/png \
	-metadata title="[Nightcore] `cat "$tmpdir/title.txt"`" \
	-metadata description="Made with nightcore.sh" \
	"$5"
