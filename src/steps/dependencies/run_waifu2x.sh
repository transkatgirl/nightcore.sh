set -euo pipefail

if [ "$scale" -le 2 ]; then
	denoise=0
elif [ "$scale" -le 3 ]; then
	denoise=1
elif [ "$scale" -le 5 ]; then
	denoise=2
else
	denoise=3
fi

waifu2x-converter-cpp -c 0 -v 0 -m noise-scale --scale-ratio "$scale" --noise-level "$denoise" \
	-i "$tmpdir/waifu2x_input.png" -o "$tmpdir/waifu2x_output.png"

rm "$tmpdir/waifu2x_input.png"
