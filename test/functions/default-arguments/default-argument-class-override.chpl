

class C {
  proc foo(x = 10) { writeln("C.foo:", x); }
}

class D : C {
  override proc foo(x = 20) { writeln("D.foo:", x); }
}

class E : D {
  override proc foo(x = 30) { writeln("E.foo:", x); }
}  

var d = (new owned D()).borrow();
d.foo();

var c: borrowed C = (new owned D()).borrow();
c.foo();

var c2: borrowed C = (new owned C()).borrow();
c2.foo();

var e = (new owned E()).borrow();
e.foo();

var e2: borrowed D = (new owned E()).borrow();
e2.foo();

var e3: borrowed C = (new owned E()).borrow();
e3.foo();
