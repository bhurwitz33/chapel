var a, b = true;

if (b) {}
if (b) then writeln("Hello");
while (b) {}
while (b) do writeln("Hello");
do {} while (b);

if(b) {}
if(b) then writeln("Hello");
while(b) {}
while(b) do writeln("Hello");
do {} while(b);

if(b){}
if(b)then writeln("Hello");
while(b){}
while(b)do writeln("Hello");
do {} while(b);

if (a &&
    b) {}
if(a &&
   b) then writeln("Hello");
while(a &&
      b) {}
while(a &&
      b) do writeln("Hello");
do {} while(a &&
            b);

// Not valid syntax, but just in case; should not warn, tuples need their parens.
if (1, 2) {}
if (1, 2) then writeln("Hello");
while (1, 2) {}
while (1, 2) do writeln("Hello");
