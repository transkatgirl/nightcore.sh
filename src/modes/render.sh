set -euo pipefail

# Note: This path MUST NOT contain quotes or special characters.
export tmpdir="/tmp/nightcore.sh-`date +"%s.%N"`"

mkdir -p "$tmpdir"

trap cleanup EXIT
function cleanup() {
	rm -rf "$tmpdir"
}

source "$script_dir/steps/_const.sh"

# Finds & converts input files, creating the following tmpfiles:
# - input.wav (audio)
# - input.ppm (image)
# - input.srt (lyric, optional)
# - speed.txt
# - title.txt
# - title_short.txt
# - info.txt
# - prefs.sh
# - font.ttf
# Note: Only the non-media files from this script are fully processed, all other input files will require further cleanup.
source "$script_dir/steps/import.sh"

source "$tmpdir/prefs.sh"

function chain_a() {
	# Processes input audio with the following effects:
	# 1. declipping
	# 2. adjusting speed
	# 3. resampling (to 48000hz)
	# 4. volume normalization (-14LUFS)
	# 5. adding a short fade-in (500ms) to songs lacking one
	# 6. silence removal (below -90dBFS)
	source "$script_dir/steps/audio.sh" "$tmpdir/input.wav" `cat "$tmpdir/speed.txt"` "$tmpdir/output.flac"

	# Processes input subtitles with the following effects:
	# - adjusting speed to match input audio
	# - limiting lyric length to 10s (adjusted for speed multiplier)
	# - limiting subtitle length to audio length
	# Note: Due to the relatively primitive nature of the subtitle processing, the subtitle timings may not match up with the audio in some cases.
	if [[ -s "$tmpdir/input.srt" ]]; then
		source "$script_dir/steps/subtitle.sh" "$tmpdir/input.srt" `cat "$tmpdir/speed.txt"` "$tmpdir/output.srt" "$tmpdir/output.flac" &
	fi

	# Generates a glide effect filtergraph
	source "$script_dir/steps/compile_glide.sh" "$tmpdir/output.flac" "$tmpdir/filtergraph_glide.txt" &

	wait
}

function chain_v() {
	# Processes input image with the following effects:
	# 1. image border trimming
	# 2. image cropping (to 16:9)
	# 3. ai upscaling
	# 4. image downscaling & cropping
	source "$script_dir/steps/image.sh" "$tmpdir/input.ppm" "$tmpdir/output.ppm"

	# Generates a thumbnail image with the following text:
	# ${title_short.txt}
	# [${speed.txt}x speed]
	# ${info.txt}
	source "$script_dir/steps/thumbnail.sh" "$tmpdir/output.ppm" "$tmpdir/cover_land.png"
}

chain_a &
chain_v &

# Generates an text overlay filtergraph with the following text:
# [${speed.txt}x speed] ${title.txt}
# ${info.txt}
source "$script_dir/steps/compile_text.sh" "$tmpdir/filtergraph_text.txt" &

# Generates an audio visualizer filtergraph with the following configuration:
# - input file amplified by 5dB
# - 20hz - 12500hz (adjusted for speed multiplier)
# - single-color showcqt bargraph with 110 bars
# - vertical resoultion half of output, semi-transparent
source "$script_dir/steps/compile_visualizer.sh" `cat "$tmpdir/speed.txt"` "$tmpdir/filtergraph_visualizer.txt" &

wait

# Composits, renders, and encodes the following input filtergraphs into an output file:
# - filtergraph_visualizer.txt
# - filtergraph_text.txt
# - filtergraph_glide.txt
# The following codecs are used for the output file:
# - video: h.264 srgb lossless
# - audio: flac
# - subtitles: srt
# - thumbnail: png
source "$script_dir/steps/render.sh" "$tmpdir/output.flac" "$tmpdir/output.ppm" "$tmpdir/output.srt" "$tmpdir/cover_land.png" "output.mkv"
