// AUTO-GENERATED: Do not edit
class A {}
class Parent {}
class Child : Parent {}
proc foo() {
  // coercing from owned Child to owned Parent
  var allocFrom = new owned Child();
  var allocTo = new owned Parent();
  var a:owned Child = allocFrom;
  var a_:owned Parent = allocTo;
  a_ = a;
}
proc main() {
  foo();
}
