set -euo pipefail

vr="$((16#${visualizer_color:1:2}))"
vg="$((16#${visualizer_color:3:2}))"
vb="$((16#${visualizer_color:5:2}))"

height=$(( $output_height / 2 ))
basefreq=`echo "$1" | awk '{ print $1 * 20 }'`
endfreq=`echo "$1" | awk '{ print $1 * 12500 }'`

lufs=`echo $loudness_target_lufs | abs`

# based on visualizer.sh (https://gist.github.com/katattakd/cc81d24f3b05db19a02373a085f207f7)
visualizer="showcqt=s=110x$height:r=$output_framerate:\
axis_h=0:sono_h=0:\
sono_v=12*b_weighting(f):bar_v=12*a_weighting(f):\
sono_g=1:bar_g=3:\
tc=0.15:\
count=`echo 3 $height | awk '{ print ($1 * $2)/120 }'`:\
basefreq=$basefreq:endfreq=$endfreq:\
cscheme=0.2|0.2|0.2|0.2|0.2|0.2"

echo "volume=$(($lufs-9))dB,$visualizer,\
setsar=0,format=rgba,\
colorkey=black:0.01:0,\
lut=c0=$vr:c1=$vg:c2=$vb:c3=if(val\,194\,0),\
scale=${output_width}x$height:sws_flags=neighbor" > "$2"
