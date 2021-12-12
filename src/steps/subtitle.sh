set -euo pipefail
source "$script_dir/steps/_const.sh"

length=`ffprobe -show_entries format=duration "$4"`

if [[ (`command -v python3` ) ]] && python -c "import srt" &>/dev/null; then
	python "$script_dir/steps/dependencies/process_subtitles.py" "$1" "$2" "$3" "$length"
fi

rm "$1"
