// AUTO-GENERATED: Do not edit
class A {}
class Parent {}
class Child : Parent {}
proc foo() {
  // coercing from unmanaged Child? to unmanaged Parent?
  var alloc = new unmanaged Child();
  var a:unmanaged Child? = alloc;
  var a_:unmanaged Parent? = a;
}
proc main() {
  foo();
}
