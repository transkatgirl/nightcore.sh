# Nightcore.sh
A Bash script that allows you to easily create "Nightcore" versions of songs.

## Features
- Creates visual effects (a gliding background and audio visualizer) using only FFMPEG
- Designed to work with lossless files, by using lossless encoding in all processing steps. 
- Preserves audio quality whenever possible by avoiding resampling, using lossless formats internally, and using the high quality SoX resampler whenever resampling is absoutely required.
- Offers lossless 4k60fps output at tiny filesizes (typically less than 1mb/s).

## Dependencies
- GNU Coreutils or [untested] Busybox (for running the script)
- Bash (for running the script)
- FFMPEG (for encoding the video)
- SoX (for encoding the audio)
- Waifu2xcpp (for better image upscaling)

## Usage
Once dependencies are installed, download the script to your computer. Then, open the script, and adjust the built-in options as you see fit (there are options both at the beginning and the end of the script).

Once the script is configured, name your input files `input.flac` and `input.png`, and create a `speed.txt` file with a numeric speed multiplier (like `1.2`). Then run the script like so: `bash nightcore.sh`.

Useful speed multipliers range from 1.1 to 1.3, different songs will likely need to be set to different speeds.

When running the script, please make sure you have at least 4GB of available system RAM.

## Demos
Want to see what this script is capable of? Some demo videos are posted below.

Zedd - I want you to know (1.2x speed): https://youtu.be/BD_BKzRkbek

OneRepublic - Counting Stars (1.2x speed): https://youtu.be/at4b3IaDJiY

TheFatRat - The Calling (1.2x speed): https://youtu.be/lauosCSkCkE
