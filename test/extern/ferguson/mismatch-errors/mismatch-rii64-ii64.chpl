require "header.h";
use SysCTypes;

extern proc returnIntFromIntArg(arg: int): int;

proc main() {
  var x = returnIntFromIntArg(1);
  writeln(x);
}
