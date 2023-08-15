extern proc chpl_cache_print();
config const verbose=false;

proc doit(a:locale, b:locale, c:locale)
{
  use CTypes;
  extern proc printf(fmt: c_ptrConst(c_char), vals...?numvals): int;

  on a {
    if verbose then printf("on %d\n", here.id:c_int);
    var x = 17;
    var y = 29;
    on b {
      x = 64;
      y = 22;
      cobegin with (ref x, ref y) {
        { on c { assert(x == 64); x = 99; assert(x == 99); } }
        { on c { assert(y == 22); y = 124; assert(y==124); } }
      }
      assert( x == 99 );
      assert( y == 124 );
    }
    assert( x == 99 );
    assert( y == 124 );
  }
}

doit(Locales[1], Locales[0], Locales[2]);
doit(Locales[1], Locales[2], Locales[0]);
doit(Locales[0], Locales[1], Locales[2]);
doit(Locales[0], Locales[2], Locales[1]);
doit(Locales[2], Locales[0], Locales[1]);
doit(Locales[2], Locales[1], Locales[0]);

