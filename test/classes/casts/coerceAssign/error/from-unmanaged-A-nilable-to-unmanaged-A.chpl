// AUTO-GENERATED: Do not edit
class A {}
class Parent {}
class Child : Parent {}
proc foo() {
  // coercing from unmanaged A? to unmanaged A
  var allocFrom = new unmanaged A();
  var allocTo = new unmanaged A();
  var a:unmanaged A? = allocFrom;
  var a_:unmanaged A = allocTo;
  a_ = a;
}
proc main() {
  foo();
}
