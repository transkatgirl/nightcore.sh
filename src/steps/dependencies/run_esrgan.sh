set -euo pipefail
source "$tmpdir/prefs.sh"

model="4x_NMKD-Yandere2_255000_G"

cd "$script_dir/steps/dependencies/esrgan-launcher"

run_scale() {
	python3 main.py "$tmpdir/esrgan_input.png" "$tmpdir/esrgan" --model "../esrgan-models/$model.pth" --tilesize "$esrgan_tile_size"

	mv "$tmpdir/esrgan/$model/esrgan_input.png" "$tmpdir/esrgan_output.png"

	rm "$tmpdir/esrgan_input.png"
}

if [ "$scale" -gt 4 ]; then
	run_scale
	mv "$tmpdir/esrgan_output.png" "$tmpdir/esrgan_input.png"
	run_scale
else
	run_scale
fi

rm -r "$tmpdir/esrgan"
