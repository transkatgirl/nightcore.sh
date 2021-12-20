set -euo pipefail

min_glide=$(( $glide_margin / 4 ))
max_glide=$(( $min_glide * 3 ))
glide_speed=$(( $glide_margin / 8 ))

length=`ffprobe -show_entries format=duration "$1" | ceil`


x="$glide_margin"
y="$glide_margin"

filter_x="$x"
filter_y="$y"

new_x="$x"
new_y="$y"

i=0

calculate_diffs() {
	x_diff=`echo $(($new_x - $x)) | abs`
	y_diff=`echo $(($new_y - $y)) | abs`
}

generate_glide() {
	filterin="((t-$i)/$speed)"              # x
	filterequ_a="sin($filterin*(PI/2))"     # a(x) = sin( x * ( pi / 2 ) )
	filterequ_b="((-1*abs($filterin-1))+1)" # b(x) = -1 * abs( x - 1 ) + 1

	filterequ="sqrt($filterequ_b)*$filterequ_a"

	echo "if(gt(t\,$i)\,$1+($(($2-$1))*($filterequ))\,$3)"
}

while [ `echo $i | floor` -le $length ]; do
	calculate_diffs
	while [ $x_diff -lt $min_glide ] || [ $y_diff -lt $min_glide ] || [ $x_diff -gt $max_glide ] || [ $y_diff -gt $max_glide ]; do
		new_x=`rand 0-$(($glide_area-x))`
		new_y=`rand 0-$(($glide_area-y))`
		calculate_diffs
	done
	speed=`echo $x_diff $y_diff | max | awk '{ print $1 / '$glide_speed' }'`

	filter_x=`generate_glide $x $new_x $filter_x`
	filter_y=`generate_glide $y $new_y $filter_y`

	x="$new_x"
	y="$new_y"
	i=`echo $i $speed | awk '{ print $1 + $2 }'`
done

echo "crop=$output_width:$output_height:$filter_x:$filter_y" > "$2"
