use BlockDist;

proc foo(X: [{1..3} dmapped blockDist({1..3})] real) {
  writeln("In foo!");
}

var A: [{1..3} dmapped blockDist({1..10})] real;

foo(A);
