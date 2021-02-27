for dir in ./*/; do
	cd "$dir"
	echo "$PWD
"
	bash ../nightcore.sh && sh ../compress.sh
	echo '

'
	cd ..
done
 
