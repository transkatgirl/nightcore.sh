# Nightcore.sh
A Bash script that allows you to easily create "Nightcore" versions of songs.

## Features
- Creates visual effects (a gliding background and audio visualizer) using only FFMPEG.
- Applies advanced input filtering, to fix common issues (noisy images, unnecessary silence, black bars in images, slight audio clipping, volume differences between songs) that would usually require manual editing.
- Designed to work with lossless files, by using lossless encoding in all processing steps.
- Preserves audio quality whenever possible by avoiding resampling, using lossless formats and using the high quality SoX resampler whenever resampling is absoutely required.
- Preserves video quality whenever possible by using lossless formats and avoiding RGB to YUV conversion.
- Offers lossless 4k60fps output at reasonable filesizes (usually under 1GB).

## Dependencies
### Required
- GNU Coreutils, Bash (for running the script)
- FFMPEG (for encoding the video)
- ImageMagick (for encoding the image)
- SoX (for encoding the audio)
- Waifu2xcpp (for AI image upscaling and noise removal)
### Optional
- MKVToolNix (for embedding thumbnail into video)
- pngcrush (for further compressing thumbnail)
- FLAC (for further compressing audio and embedding thumbnail into audio)
- NPM, NodeJS (for parsing and processing subtitles)

## Usage
Once dependencies are installed, download the script to your computer. Then, open the script in a text editor, and adjust the built-in configuration options as you see fit. If you don't know what to set an option to, leaving it at the default value is usually a good idea.

Once the script is configured, name your input files `input.(audio format)` and `input.(image format)`, and create a `speed.txt` file with a numeric speed multiplier (like `1.2`). Then run the script in a terminal using this command: `bash nightcore.sh`.

When running the script, please make sure you have at least 6GB of available system RAM.
Useful speed multipliers range from 1.1 to 1.3, different songs will likely need to be set to different speeds.

### Output
The script will typically output 2-3 files: output.mkv (generated video), output.thumbnail.png (generated thumbnail image), and output.srt (generated subtitle file, optional). If you are planning on uploading your video to a video sharing service, upload these files, and avoid doing any format conversions to the video and thumbnail files if possible (re-encoding will result in a significant quality loss).

If you would like an audio-only file, run this FFMPEG command: `ffmpeg -i output.mkv -vn -acodec copy output.flac`. This will create an output audio file for uploading to audio sharing services. Avoid doing any format conversions to this file if possible.

If you would like a smaller video file to share directly, run `sh compress.sh` in the same folder as the video file. This will create a far smaller compressed version of the video, which can be uploaded to file sharing sites and streamed directly. Do not upload the compressed video to video sharing sites like YouTube.

### Special files
Different input files can be used to affect the functionality of nightcore.sh. A list of all files nightcore.sh can use is below.
- \[required\] input.(audio format) - Audio that will be processed and used as the video's music.
  - Should not be longer than 6 minutes.
  - Metadata will be removed from the audio file during processing.
- \[required\] input.(image format) - Image that will be processed and used as the video's background.
  - If the file is animated, only the first frame of the animation will be used.
  - If the file is transparent, transparency will be replaced with solid white.
- \[required\] speed.txt - Speed multiplier to speed up/slow down audio by.
  - Should not contain any whitespace.
  - Must be non-empty and a valid number.
- input.(subtitle format) - Subtitles that will be processed and used as the video's lyrics.
  - Subtitles should match the original song's speed, as they will be sped up by the script.
  - Metadata will be removed from the subtitle file during processing.
- title.txt - Song info displayed in the video (Artist - Title).
  - If missing, it will be automatically generated from file metadata.
  - If empty, song title will not be displayed in the video.
  - Should not contain any newlines.
- title_short.txt - Song info displayed in the thumbnail (Artist - Title).
  - If missing, it will be automatically generated from title.txt.
  - If empty, song title will not be displayed in the thumbnail.
  - Should not contain any newlines.
- info.txt - Additional info displayed in the video.
  - If missing, it will be automatically generated as "nightcore.sh commit $(git rev-parse --short HEAD)".
  - If empty, additional info will not be displayed in the video.
  - Should not contain any newlines.
- info_short.txt - Additional info displayed in the thumbnail.
  - If missing, it will be a copy of info.txt.
  - If empty, additional info will not be displayed in the thumbnail.
  - Should not contain any newlines.
- options.sh - Nightcore.sh configuration file.
  - Follow same format as built-in options in script.
  - Overrides options specified in script.

## Demos
Want to see what this script is capable of? Demo videos can be found on [my YouTube channel](https://www.youtube.com/channel/UCbgvvnk-Tb_ixyj7UDWnXaQ).
