export script_dir="$(realpath `dirname "$0"`)/src"

if [ -n "$1" ]; then
	mode="$1"
else
	mode="help"
fi

if [ -n "$2" ]; then
	cd "$2"
fi

set -euo pipefail

if [[ ! (`command -v ffmpeg` && `command -v ffprobe` && `command -v sox` && `command -v magick`) ]]; then
	echo "Unable to find all required dependencies!
FFMPEG, SoX, and ImageMagick must be installed for the script to function properly."
	exit 1
fi

if [ -s "$script_dir/modes/$mode.sh" ]; then
	sh "$script_dir/modes/$mode.sh"
else
	echo "Invalid arguments!
Run the script with no arguments for more information."
	exit 1
fi
