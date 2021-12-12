### Default settings are below. DO NOT modify this file!
### If you would like to change the settings, make an "options.sh" file instead, and put your modified settings there.

# Set the tile size used by ESRGAN. Higher tile size = slightly better quality, but will heavily increase RAM/VRAM usage.
# Try to set this as high as your hardware can handle.
# (This setting will be ignored if you're not using the ESRGAN upscaler.)
export esrgan_tile_size="750"
# If you're running ESRGAN on your CPU, the below code will automatically calculate (roughly) what tile size you can use.
#export esrgan_tile_size=`free -b | grep Mem | awk '{print int(sqrt(($7-2000000000)/3000))}'`

# Font alignment (on the x-axis, y-axis is unaffected). Valid options are "left", "center", and "right".
# If the string does not match one of those values, left font alignment is used.
export video_font_align="left"
export thumbnail_font_align="left"

# Set the color used for the audio visualizer. Must be in 6-digit hexadecimal form.
export visualizer_color="#000000"

# End of default settings
