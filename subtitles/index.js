var fs = require('fs');
var subsrt = require('subsrt');

var content = fs.readFileSync(process.argv.slice(3)[0], 'utf8');

var options = { format: "ass", eol: '\n' };
var captions = subsrt.parse(content, options);
var resynced = subsrt.resync(captions, function(a) {
	return [ a[0]/process.argv.slice(2)[0], a[1]/process.argv.slice(2)[0] ];
});

var options = { format: 'srt', eol: '\n' };
var content = subsrt.build(resynced, options);

fs.writeFileSync(process.argv.slice(4)[0], content);
