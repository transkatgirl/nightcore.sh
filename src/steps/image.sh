set -euo pipefail
source "$script_dir/steps/_const.sh"

magick "$1" -fuzz 2.5% -define trim:percent-background=95% -trim +repage "$tmpdir/stage1.ppm"

min_width=`ffprobe -select_streams v:0 -show_entries stream=width "$1" | awk '{ print int($1*0.87) }'`
min_height=`ffprobe -select_streams v:0 -show_entries stream=height "$1" | awk '{ print int($1*0.87) }'`

width=`ffprobe -select_streams v:0 -show_entries stream=width "$tmpdir/stage1.ppm"`
height=`ffprobe -select_streams v:0 -show_entries stream=height "$tmpdir/stage1.ppm"`

if [ "$width" -lt "$min_width" ] || [ "$height" -lt "$min_height" ]; then
	rm "$tmpdir/stage1.ppm"
	cp "$1" "$tmpdir/stage1.ppm"

	width=`ffprobe -select_streams v:0 -show_entries stream=width "$tmpdir/stage1.ppm"`
	height=`ffprobe -select_streams v:0 -show_entries stream=height "$tmpdir/stage1.ppm"`
fi

if [ `echo "$width" "$height" | awk '{ print int(($1/$2)*100) }'` -gt 130 ]; then
	gravity="Center"
else
	gravity="North"
fi

magick "$tmpdir/stage1.ppm" -gravity $gravity -crop 16:9 +repage "$tmpdir/stage2.ppm"

rm "$tmpdir/stage1.ppm"

width_scale=`echo "$width" "$padded_width" | awk '{ print int(($2/$1)+0.99999) }'`
height_scale=`echo "$height" "$padded_height" | awk '{ print int(($2/$1)+0.99999) }'`

if [ "$width_scale" -ge "$height_scale" ]; then
	export scale="$width_scale"
else
	export scale="$height_scale"
fi

if [[ (`command -v pip` && `command -v python3` ) ]] && python -c "import torch" &>/dev/null && python -c "import numpy" &>/dev/null && python -c "import cv2" &>/dev/null; then
	scaler="esrgan"
elif [[ (`command -v waifu2x-converter-cpp` ) ]]; then
	scaler="waifu2x"
else
	scaler="nearest"
fi

if [ "$scale" -gt 16 ] || [ "$scaler" == "nearest" ] && [ "$scale" -gt 1 ]; then
	echo "Error: Unable to use a high-quality image upscaler!
Please install a high-quality upscaler, find a larger image, or upscale the image externally."
	exit 1
elif [ "$scale" -gt 1 ]; then
	ffmpeg -i "$tmpdir/stage2.ppm" -compression_level 0 "$tmpdir/${scaler}_input.png"
	rm "$tmpdir/stage2.ppm"

	echo "Processing image..."

	sh "$script_dir/steps/dependencies/run_${scaler}.sh"

	magick "$tmpdir/${scaler}_output.png" -filter Lanczos -resize "${padded_width}x${padded_height}^" -gravity $gravity -crop "${padded_width}x${padded_height}+0+0" +repage "$2"
	rm "$tmpdir/${scaler}_output.png"
else
	magick "$tmpdir/stage2.ppm" -filter Lanczos -resize "${padded_width}x${padded_height}^" -gravity $gravity -crop "${padded_width}x${padded_height}+0+0" +repage "$2"
	rm "$tmpdir/stage2.ppm"
fi

rm "$1"
