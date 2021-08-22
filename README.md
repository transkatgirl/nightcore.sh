# nightcore.sh
A Bash script that automates the process of creating "Nightcore" videos for songs.

**Note: The nightcore.sh project was rewritten on August 22, 2021, introducing some breaking changes. Please read the below section if you have been using nightcore.sh prior to this date.**

## Migration from nightcore.sh v1 to v2
During the time period of July - August 2021, I decided it was worth undertaking the project of rewriting the entirety of nightcore.sh. The code had become a spagetti mess over the nearly 2 years it's been since the project started, and this was making it extremely difficult to implement new features or even just improve existing code.

Although the rewrite focused on keeping the number of breaking changes low, there were breaking changes introduced whenever it was a net benefit to the overall project. This allowed for a huge overall improvement to the code, and the new version of nightcore.sh is a drastic improvement from the old codebase in almost every way.

However, this did introduce a large number of breaking changes, which users coming from older versions of the program will have to deal with. A mostly complete list of all breaking changes (this is not a changelog) is listed below:
- cli
  - unlike the previous version of nightcore.sh, which started rendering in the current directory and didn't take any cli arguments, the new version has a proper cli interface, requiring at least 1 argument (an action) to be specified. if you would like to replicate the old behavior, change `sh nightcore.sh` to `sh nightcore.sh render`
  - the log messages & error handling have changed significantly during the rewrite.
- input files
  - the configuration file (options.sh) has been drastically changed. most config options are no longer necessary and have been removed. the following config options remain:
    - `video_font_align` - no change to functionality
    - `thumbnail_font_align` - no change to functionality
    - `visualizer_overlay_color` -> `visualizer_color` - no change besides rename
  - the configuration file is run in a vastly different fashion to how it used to be run (only once at the beginning of the script).
  - the default configuration is no longer editable by modifying the `nightcore.sh` file.
  - the text font is now bundled with nightcore.sh, instead of relying on system fonts.
  - processing of input text files (such as `speed.txt` or `title.txt`), along with metadata parsing, has been significantly improved
  - the `info_short.txt` file is now ignored.
  - the default info string is different
  - lrc file parsing has been vastly improved
  - song titles are now required instead of optional
  - speed multipliers of 1.0 will be displayed (this may change in a future version)
- processing chain
  - the temporary directory format has changed, and temporary directories are more reliably cleaned up
  - temporary files have completely different names in most cases
  - waifu2x is no longer a strict dependency
  - node.js is no longer a dependency, python is used for subtitle processing instead
  - mkvtoolnix is no longer a dependency
  - flac is no longer a dependency
  - pngcrush is no longer a dependency
  - the multi-threading has been vastly improved and is no longer susceptible to most of the issues the older versions experienced.
  - the processing chains for all file types have been completely overhauled and are only vaguely similar to the original code
  - sox and imagemagick are used less internally, more of the program is handled by ffmpeg now
  - automatic cropping happens earlier in the image processing chain
- output files
  - only a single output file (audio+video+thumbnail+subtitles+metadata) is created now. if you would like to split this into multiple output files, run `sh nightcore.sh split` to do so. all output filenames are unchanged.
  - thumbnail resoultion has been increased to 3840x2160 (same as video)

If an important change is not listed here, please file an issue, and I'll add it to the list.
This notice will be removed after a month to improve the readme's readability.

## Features
- Renders high-quality visual effects (a gliding background, text overlay, and audio visualizer) without need for user configuration
- Uses advanced pre-processing to automatically fix commmon issues (unnecessary audio silence, black bars in images, slight audio clipping, volume differences between songs) that would typically require manual editing
- Has a high-quality lossless media processing pipeline to preserve image and video quality whenever possible
- Offers 4k60 lossless, single-file (video+audio+thumbnail+subtitle) outputs at reasonable filesizes
- Comes with a suite of cli tools to manipulate output files (splitting into multiple files, compression, etc)

## System requirements
Note: It may be possible to run the script on hardware that doesn't meet these requirements, but you will likely encounter issues.
- A Linux-based operating system with GNU Coreutils.
- 6+ GB of available system RAM. More is better (especially with ESRGAN).
- A fairly powerful CPU, weak CPUs will be unable to play the rendered video in real-time. Faster is better.
- Enough available storage for storing all the dependencies and your rendered videos (expect ~1GB per video).

## Dependencies

### Required
- FFMPEG
- ImageMagick
- SoX

### Optional (but highly recommended)

#### Version information
- Git

#### Subtitle processing
- Python3
- srt (`pip install srt`)

#### Ultra-high-quality ESRGAN upscaler
Note: This can take upwards of 30 minutes to upscale a *single image* on a fairly decent CPU. Uses the [YandeRe ESRGAN model](https://nmkd.de/?esrgan-list).
- Python3
- [PyTorch](https://pytorch.org/get-started/locally/)
- NumPy (`pip install numpy`)
- OpenCV (`pip install opencv-python`)

#### High-quality upscaler
Delivers fairly meh quality. Much better than typical upscalers (such as Lanczos), but much worse than ESRGAN.

Roughly 10x faster than ESRGAN. If you care more about speed than quality, use this.

Note: If all the ESRGAN dependencies are installed, it will be prefered over this upscaler.
- waifu2x-converter-cpp

## Installation
Once all dependencies are installed, open a terminal in the directory you wish to install the script into, and run the following commands:
```bash
git clone https://github.com/katattakd/nightcore.shv2.git
git submodule update --init --recursive
```

## Usage
Run `sh nightcore.sh help_full` for usage information.

## Sharing output videos
The output file generated by the script's renders (`output.mkv`) is not suitable for sharing. It's huge (typically ~1GB), very high-resoultion, only has a single keyframe (so seeking isn't possible), has an embedded high-resoultion image, uses lossless codecs not supported by most video players (lossless sRGB H.264 video + FLAC audio), and uses a container format that isn't widely supported (Makroska).

As a result of this, you *will* have to re-encode the output file before you can share it (unless you're trying to share a lossless copy of the rendered video, or you're uploading to a streaming site, such as YouTube, which will re-encode the video for you). There are multiple ways to go about doing this.

The easiest way to do so is by using the script's built-in video compression tool. Simply run `sh nightcore.sh compress [optional input directory]`, and it will make a compressed version of the output.mkv file called compressed.webm. This does everything right, and results in a high-quality video that you can share with most of your friends.

But, there are some caveats to this:
- It's slow. Expect it to take a slighly longer to compress than it took to render the video.
- You're stuck with specific codecs (yuv444p vp9 + opus + webvtt), a specific resoultion (1080p60), and specific bitrates. If you need wider software support, a higher quality, or a smaller filesize, you'll have to do something else.

As a result of this, you'll likely need to manually compress the output video yourself at some point. Even if uploading to a streaming site / using the built-in tool works fine for now, you may run into a situation in the future when it doesn't.

Here's some guidelines, tips, and potential pitfalls to keep in mind (assuming you know some basic media encoding stuff):
- The renders are sRGB, and many tools ([such as FFMPEG](https://medium.com/invideo-io/talking-about-colorspaces-and-ffmpeg-f6d0b037cc2f) / anything FFMPEG based) mess up sRGB -> YUV conversion. *Make sure* that the compressed video is using the bt.709 colorspace.
  - The `src/modes/compress.sh` file may be a useful reference on how to perform sRGB -> YUV conversion correctly with FFMPEG.
- Make sure to strip out the attached image & metadata while re-encoding.
  - The `src/modes/compress.sh` file may be a useful reference on how to do this.
- If you're working with low bitrates (below 1mbit/s), give most of the bitrate to the audio stream. Bad quality audio is much more noticeable than bad quality video, especially when the audio is the main focus and the video is just eyecandy.
  - If you're working with *very low* bitrates, you may be better off sending an audio-only file. Decent audio + no video is far better than bad audio + terrible video.
- If you're uploading to a service which is going to be re-encoding the content (like a streaming site or social media), use lossless codecs if you can, and the highest bitrates possible if you can't.
- Use modern codecs if possible (especially when it comes to the audio), as they'll allow you to get much better quality at the same bitrate.
- Use yuv444p instead of yuv420p if possible. There may be a fairly noticeable difference in visual quality, *especially at lower resoultions*.
- Use 60fps if possible, even if it requires lowering the quality a bit more. The music visualizer benefits a lot from framerates >30fps.
- If filesize/bitrate isn't a huge concern, target a quantizer value (crf) instead of a bitrate. This will allow for more consistent quality between videos.
  - For audio: If lossless isn't an option, use a vbr setting.
