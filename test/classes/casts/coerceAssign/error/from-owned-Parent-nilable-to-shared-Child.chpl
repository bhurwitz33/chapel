// AUTO-GENERATED: Do not edit
class A {}
class Parent {}
class Child : Parent {}
proc foo() {
  // coercing from owned Parent? to shared Child
  var allocFrom = new owned Parent();
  var allocTo = new shared Child();
  var a:owned Parent? = allocFrom;
  var a_:shared Child = allocTo;
  a_ = a;
}
proc main() {
  foo();
}
