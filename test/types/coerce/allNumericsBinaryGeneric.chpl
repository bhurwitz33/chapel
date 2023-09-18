// first, declare a function 'f' to report which overload is called,
// with a version having both arguments of the same type,
// but one of those for each numeric type

proc f(x: integral, y: integral) {
  writeln("  f(integral, integral)");
}
proc f(x: chpl_anyreal, y: chpl_anyreal) {
  writeln("  f(anyreal, anyreal)");
}
proc f(x: chpl_anyimag, y: chpl_anyimag) {
  writeln("  f(anyimag, anyimag)");
}
proc f(x: chpl_anycomplex, y: chpl_anycomplex) {
  writeln("  f(anycomplex, anycomplex)");
}
proc f(x, y) {
  writeln("  f(generic, generic)");
}

// next, call 'f' with all combinations of numeric types
proc callF(type t1, type t2) {
  writef(" Second actual %<12s -> ", t2:string);
  var x: t1;
  var y: t2;
  f(x, y);

  writef("      Reversed %<12s -> ", "");
  f(y, x);

  writef("               %<12s ->   ", "+");
  writeln((x+y).type:string);
}

proc callFVaryT2(type t1) {
  writeln("First actual ", t1:string);
  writeln();

  callF(t1, int(8));
  callF(t1, int(16));
  callF(t1, int(32));
  callF(t1, int(64));
  writeln();

  callF(t1, uint(8));
  callF(t1, uint(16));
  callF(t1, uint(32));
  callF(t1, uint(64));
  writeln();

  callF(t1, real(32));
  callF(t1, real(64));
  writeln();

  callF(t1, imag(32));
  callF(t1, imag(64));
  writeln();

  callF(t1, complex(64));
  callF(t1, complex(128));
  writeln();

  writeln();
  writeln();
}

proc main() {
  callFVaryT2(int(8));
  callFVaryT2(int(16));
  callFVaryT2(int(32));
  callFVaryT2(int(64));

  callFVaryT2(uint(8));
  callFVaryT2(uint(16));
  callFVaryT2(uint(32));
  callFVaryT2(uint(64));

  callFVaryT2(real(32));
  callFVaryT2(real(64));

  callFVaryT2(imag(32));
  callFVaryT2(imag(64));

  callFVaryT2(complex(64));
  callFVaryT2(complex(128));
}
