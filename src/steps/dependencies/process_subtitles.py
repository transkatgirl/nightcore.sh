import datetime
import sys

import srt

speed = float(sys.argv[2])
endtime = float(sys.argv[4])
maxduration = (10 / speed)

with open(sys.argv[1], 'r') as file:
	subs = list(srt.parse(file.read()))

for sub in subs:
	sub.start = sub.start / speed
	sub.end = sub.end / speed

	if (sub.end - sub.start).total_seconds() > maxduration:
		sub.end = sub.start + datetime.timedelta(seconds=maxduration)

	if sub.start.total_seconds() > endtime:
		sub.start = datetime.timedelta(seconds=endtime)

	if sub.end.total_seconds() > endtime:
		sub.end = datetime.timedelta(seconds=endtime)

with open(sys.argv[3], 'w') as file:
	file.write(srt.compose(subs))
