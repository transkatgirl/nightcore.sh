set -euo pipefail

alias ffmpeg="ffmpeg -loglevel error -y"

echo "Splitting output..."

ffmpeg -i output.mkv -map v:1 -map a -vcodec copy -acodec copy output.flac

ffmpeg -i output.mkv -map v:1 output.thumbnail.png

ffmpeg -i output.mkv -c copy output.srt
