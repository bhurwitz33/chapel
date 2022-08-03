/***
*/
module Motivators {

  // Test with only default intents - should achieve status quo.
  proc test1() {
    var add = proc(x: int, y: int): int { return x + y; };
    var sum = add(4, 4);
    var val = add(4, 4);
    assert(val == 8);
  }
  test1();

  // Now use ref intent to prove the implementation supports intents.
  proc test2() {
    var inc = proc(ref x: int): void { x += 1; };
    var x = 0;
    inc(x);
    assert(x == 1);
  }
  test2();

  /*
  proc test() {
    extern proc foo(fn: proc(int, int): int): void;
    // Call 'foo' with our proc literal.
    foo(proc(x: int, y: int) {
      return x + y;
    });
    // Call again but with a variable.
    var fn = proc(x: int, y: int) { return x + y; };
    foo(fn);
  }
  */

  /*
  proc test() {
    type F = proc(int, int): int;
    var a: F; // Default value should be 'nil'?
    assert(a == nil);
    var b: F = proc(x: int, y: int): int { return x + y; };
    var c = b;
    assert(b.type == c.type);
  }
  */

  /*
  // Should be a typing error.
  proc test() {
    type F = proc(int, int): int;
    var a: F = proc(x: int, y: real) { return x + y; };
  }
  */

  /*
  // Print a function type.
  proc test() {
    type F = proc(int, int): int;
    writeln(F:string);
    var a: F;
    writeln(a.type:string);
  }
  */

  /*
  // Parsing error - procedure expressions cannot have unnamed formals.
  proc test() {
    var fn = proc(int, y: int, ref: int): void;
  }
  */
}

