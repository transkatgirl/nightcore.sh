set -euo pipefail
source "$script_dir/steps/_const.sh"

for ext in "${audio_ext[@]}"; do
	input_file="input.$ext"

	if [[ -s "$input_file" ]]; then
		echo "Importing $input_file..."
		ffmpeg -i "$input_file" -vn -map_metadata -1 "$tmpdir/input.wav"

		if [[ -s "title.txt" ]]; then
			echo "Importing title.txt..."
			cat title.txt | trim_whitespace > "$tmpdir/title.txt"
			if [[ -s "title_short.txt" ]]; then
				echo "Importing title_short.txt..."
				cat title_short.txt | trim_whitespace > "$tmpdir/title_short.txt"
			else
				cat "$tmpdir/title.txt" | remove_quotes | remove_parenthesis | remove_featuring > "$tmpdir/title_short.txt"
			fi
		else
			artist=`ffprobe -select_streams a:0 -show_entries format_tags=ARTIST "$input_file"`
			title=`ffprobe -select_streams a:0 -show_entries format_tags=TITLE "$input_file"`

			if [ ! -z "$artist" ] && [ ! -z "$title" ]; then
				echo "$artist - $title" | remove_quotes | replace_commas > "$tmpdir/title.txt"
				echo "`echo "$artist" | replace_commas | remove_ampersand` - $title" | remove_quotes | remove_parenthesis | remove_featuring > "$tmpdir/title_short.txt"
			elif [ ! -z "$artist" ]; then
				echo "$artist" | remove_quotes | replace_commas > "$tmpdir/title.txt"
				cat "$tmpdir/title.txt" | remove_parenthesis | remove_featuring > "$tmpdir/title_short.txt"
			elif [ ! -z "$title" ]; then
				echo "$title" | remove_quotes | replace_commas  > "$tmpdir/title.txt"
				cat "$tmpdir/title.txt" | remove_parenthesis | remove_featuring > "$tmpdir/title_short.txt"
			else
				echo "Unable to find song title!"
				exit 1
			fi
		fi

		break
	fi
done

if [[ -s "speed.txt" ]]; then
	cat speed.txt | trim_whitespace | awk '{ print $1 }' > "$tmpdir/speed.txt"
else
	echo "Unable to find speed multiplier!"
	exit 1
fi

if [[ ! -s "$tmpdir/input.wav" ]]; then
	echo "Unable to find input audio!"
	exit 1
fi

for ext in "${image_ext[@]}"; do
	input_file="input.$ext"

	if [[ -s "$input_file" ]]; then
		echo "Importing $input_file..."
		ffmpeg -i "$input_file" -an -vframes 1 -map_metadata -1 -filter_complex "color=#c2c2c2,format=rgb24[c];[c][0]scale2ref[c][i];[c][i]overlay=format=rgb:shortest=1,setsar=1" -sws_flags +accurate_rnd+full_chroma_int "$tmpdir/input.ppm"
		break
	fi
done

if [[ ! -s "$tmpdir/input.ppm" ]]; then
	echo "Unable to find input image!"
	exit 1
fi

for ext in "${lyric_ext[@]}"; do
	adjusted_file="adjusted.$ext"

	if [[ -s "$adjusted_file" ]]; then
		echo "Importing $adjusted_file..."
		ffmpeg -i "$adjusted_file" -map_metadata -1 "$tmpdir/output.srt"
		break
	fi

	input_file="input.$ext"

	if [[ -s "$input_file" ]]; then
		echo "Importing $input_file..."
		ffmpeg -i "$input_file" -map_metadata -1 "$tmpdir/input.srt"
		break
	fi
done

if [[ -s "info.txt" ]]; then
	echo "Importing info.txt..."
	cat info.txt | trim_whitespace > "$tmpdir/info.txt"
elif [ -d "$script_dir/../.git" ]; then
	echo "nightcore.sh v`git -C "$script_dir" log -1 --format=%cs`" > "$tmpdir/info.txt"
else
	echo "Made with nightcore.sh" > "$tmpdir/info.txt"
fi

if [[ -s "options.sh" ]]; then
	cat "$script_dir/steps/_default_settings.sh" options.sh > "$tmpdir/prefs.sh"
else
	cat "$script_dir/steps/_default_settings.sh" > "$tmpdir/prefs.sh"
fi

cp "$script_dir/steps/dependencies/fonts/NotoSans-Light.ttf" "$tmpdir/font.ttf"
cp "$script_dir/steps/dependencies/fonts/fonts.conf" "$tmpdir/fonts.conf"
