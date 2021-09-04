set -euo pipefail
source "$script_dir/steps/_const.sh"

echo "Processing audio..."

ffmpeg -i "$1" -af "volume=-15dB,adeclip=a=25:n=750:m=s" -f sox - | sox -p "$tmpdir/stage1.wav" speed "$2" rate -v -I "$output_sample_rate"

loudnorm=`ffmpeg -loglevel info -i "$tmpdir/stage1.wav" -af "loudnorm=print_format=summary:tp=0:i=$loudness_target_lufs:lra=20" -f null - 2>&1`
loudnorm_i=`echo "$loudnorm" | grep "Input Integrated:" | awk '{ print $3+0 }'`
loudnorm_tp=`echo "$loudnorm" | grep "Input True Peak:" | awk '{ print $4+0 }'`
loudnorm_lra=`echo "$loudnorm" | grep "Input LRA:" | awk '{ print $3+0 }'`
loudnorm_thresh=`echo "$loudnorm" | grep "Input Threshold:" | awk '{ print $3+0 }'`
loudnorm_offset=`echo "$loudnorm" | grep "Target Offset:" | awk '{ print $3+0 }'`
ffmpeg -i "$tmpdir/stage1.wav" \
	-af "loudnorm=linear=true:tp=0:i=$loudness_target_lufs:lra=20:measured_i=$loudnorm_i:measured_lra=$loudnorm_lra:measured_tp=$loudnorm_tp:measured_thresh=$loudnorm_thresh:offset=$loudnorm_offset, \
	afade=t=in:ss=0:d=0.5:curve=squ,silenceremove=start_threshold=-104dB:start_mode=all:stop_periods=-1:stop_threshold=-104dB" \
	"$3"

rm "$tmpdir/stage1.wav"

if [ `ffprobe "$3" -show_entries stream=sample_rate` != "$output_sample_rate" ]; then
	echo "Unable to normalize audio volume!"
	exit 1
fi

rm "$1"
