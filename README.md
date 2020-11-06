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
- FLAC (for further compressing audio)

## Usage
Once dependencies are installed, download the script to your computer. Then, open the script, and adjust the built-in options as you see fit (there are options both at the beginning and the end of the script).

Once the script is configured, name your input files `input.(audio format)` and `input.(image format)`, and create a `speed.txt` file with a numeric speed multiplier (like `1.2`). Then run the script like so: `bash nightcore.sh`.

Useful speed multipliers range from 1.1 to 1.3, different songs will likely need to be set to different speeds.

When running the script, please make sure you have at least 6GB of available system RAM.

### Special files
Different input files can be used to affect the functionality of nightcore.sh. A list of all files nightcore.sh can use is below.
- \[required\] input.(audio format) - Audio that will be processed and used as the video's music.
- \[required\] input.(image format) - Image that will be processed and used as the video's background.
  - If the file is animated, only the first frame of the animation will be used.
  - If the file is transparent, transparency will be replaced with solid white.
- \[required\] speed.txt - Speed multiplier to speed up/slow down audio by.
  - Should not contain any whitespace.
  - Must be non-empty and a valid number.
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

## Demos
Want to see what this script is capable of? Demo videos can be found on [my YouTube channel](https://www.youtube.com/channel/UCbgvvnk-Tb_ixyj7UDWnXaQ).
