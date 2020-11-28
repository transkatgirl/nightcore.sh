echo "Compressing video..."
ffmpeg -loglevel error -y -stats -i output.mkv -vcodec libvpx-vp9 -pix_fmt yuv444p10le -g 240 -crf 30 -vf scale=w=1920:h=1080:out_color_matrix=bt709 -color_primaries bt709 -color_trc bt709 -colorspace bt709 -r 60 -sws_flags lanczos+accurate_rnd+full_chroma_int -acodec libopus -b:a 512k -map_metadata -1 -row-mt 1 -tile-columns 2 compressed.webm
