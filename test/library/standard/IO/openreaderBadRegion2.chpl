use IO;

var filename = "openreaderLimited.txt";
var readCh = openreader(filename, region=3..0);
var readRes: string;
readCh.readLine(readRes, stripNewline=true);
writeln(readRes);
readCh.close();
