set -euo pipefail

alias ffmpeg="ffmpeg -loglevel error -y"

echo "Compressing output..."

ffmpeg -stats -i output.mkv \
	-pix_fmt yuv444p -vf fps=60,scale=w=1920:h=1080:out_color_matrix=bt709 \
	-color_primaries bt709 -color_trc bt709 -colorspace bt709 -sws_flags lanczos+accurate_rnd+full_chroma_int \
	-c:v libvpx-vp9 -b:v 0 -crf 28 \
	-row-mt 1 -quality good -speed 2 -tile-columns 6 -tile-rows 2 \
	-c:a libopus -b:a 512k \
	-c:s webvtt -map_metadata -1 \
	"compressed.webm"
