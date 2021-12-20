set -euo pipefail

echo "Usage: bash nightcore.sh [mode] [input directory]


System requirements:
- GNU/Linux-based OS
- 6+ GB available RAM

Required dependencies:
- ffmpeg
- sox
- imagemagick

Optional dependencies:
- version detection:
  - git
- subtitle processing:
  - python3
  - python-srt (pip install srt)
- high quality upscaler (pick one):
  - esrgan (prefered, higher quality but 10x slower)
    - python3
    - pytorch
    - numpy
    - opencv
  - waifu2x
    - waifu2x-converter-cpp


Available modes:

- render - use the files present in the directory to render a nightcore video
  - inputs:
    - input.{audio_format}
      - note: do not speed up the input audio, as the script will perform that step using the specified speed multiplier
    - input.{image format}
      - transparency will be replaced with solid grey
      - if the image is animated, only the first frame will be used
      - if a high quality upscaler is not installed, using an input image below 4000x2320 will result in an error
    * input.{subtitle_format}
      - these subtitles will be sped up to match the audio speed
      - note: due to the fairly primitive subtitle processing used, the subtitles may loose sync with if the audio contains a lot of silence.
    * adjusted.{subtitle_format}
      - note: these subtitles will be included in the output file *without any timestamp modification*.
      - takes priority over input.{subtitle_format}
    - speed.txt
      - speed multiplier, must be in decimal (ex: 1.2) form. do not include any text besides the number itself
    ** title.txt
      - video title (ex: song artist - song title), required if not present in song metadata
      - takes priority over song metadata
    * title_short.txt
      - short video title, used on thumbnail image
    * info.txt
      - additional on-screen info. if not specified, defaults to \"nightcore.sh vYYYY-MM-DD\" or \"Made with nightcore.sh\"
    * options.sh
      - script configuration. view src/steps/_default_settings.sh for a list of config options
  - outputs:
    - output.mkv

- split - split the script's output file into multiple files
  - inputs:
    - output.mkv
  - outputs:
    - output.flac
    - output.thumbnail.png
    * output.srt

- compress - create a compressed version of the script's output file for sharing
  - inputs:
    - output.mkv
  - outputs:
    - compressed.webm

- expand - remove compressed version of output file
  - inputs:
    ! compressed.webm

- combine - remove all files split from the output file
  - inputs:
    ! output.flac
    ! output.thumbnail.png
    ! output.srt

- clean - remove all files produced by nightcore.sh from the directory
  - inputs:
    ! compressed.webm
    ! output.mkv
    ! output.flac
    ! output.thumbnail.png
    ! output.srt

- help - show a short version of this menu
- help_full - show this menu



Input/output files:
- = required file
* = optional file
** = optional in most cases
! = optional, file will be removed

Note: All input/output files are relative to the input directory.
If the input directory is not specified, it defaults to the current working directory."
