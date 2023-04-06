/*
 * Copyright 2020-2023 Hewlett Packard Enterprise Development LP
 * Copyright 2004-2019 Cray Inc.
 * Other additional copyright holders may be indicated within.
 *
 * The entirety of this work is licensed under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 *
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*

Basic types and utilities in support of I/O operation.

Most of Chapel's I/O support is within the :mod:`IO` module.  This section
describes automatically included basic types and routines that support the
:mod:`IO` module.

Writing
~~~~~~~~~~~~~~~~~~~

The :proc:`writeln` function allows for a simple implementation
of a Hello World program:

.. code-block:: chapel

 writeln("Hello, World!");
 // outputs
 // Hello, World!

.. _readThis-writeThis:

The readThis() and writeThis() Methods
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A Chapel program can implement ``readThis`` and ``writeThis`` methods on a
custom data type to define how that type is read from a fileReader or written to
a fileWriter.  ``readThis`` accepts a fileReader as its only argument and the
file must be readable.  ``writeThis`` accepts a fileWriter as its only argument
and the file must be writable. If neither of these methods is defined, a default
version of ``readThis`` and ``writeThis`` will be generated by the compiler.

Note that arguments to ``readThis`` and ``writeThis`` may be locked; as a
result, calling methods on the fileReader or fileWriter in parallel from within
a ``readThis`` or ``writeThis`` may cause undefined behavior.  Additionally,
performing I/O on a global fileReader or fileWriter that is the same as the one
``readThis`` or ``writeThis`` is operating on can result in a deadlock. In
particular, these methods should not refer to :var:`~IO.stdin`,
:var:`~IO.stdout`, or :var:`~IO.stderr` explicitly or implicitly (such as by
calling the global :proc:`writeln` function).  Instead, these methods should
only perform I/O on the fileReader or fileWriter passed as an argument.

Note that the types :type:`IO.ioLiteral` and :type:`IO.ioNewline` may be useful
when implementing ``readThis`` and ``writeThis`` methods. :type:`IO.ioLiteral`
represents some string that must be read or written as-is (e.g. ``","`` when
working with a tuple), and :type:`IO.ioNewline` will emit a newline when
writing but skip to and consume a newline when reading. Note that these types
are not included by default.

This example defines a writeThis method - so that there will be a function
resolution error if the record NoRead is read.

.. code-block:: chapel

  record NoRead {
    var x: int;
    var y: int;
    proc writeThis(f) throws {
      f.write("hello");
    }
    // Note that no readThis function will be generated.
  }
  var nr = new NoRead();
  write(nr);
  // prints out
  // hello

  // Note that read(nr) will generate a compiler error.

.. _default-readThis-writeThis:

Default writeThis and readThis Methods
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Default ``writeThis`` methods are created for all types for which a
user-defined ``writeThis`` method is not provided.  They have the following
semantics:

* for a class: outputs the values within the fields of the class prefixed by
  the name of the field and the character ``=``.  Each field is separated by a
  comma.  The output is delimited by ``{`` and ``}``.
* for a record: outputs the values within the fields of the class prefixed by
  the name of the field and the character ``=``.  Each field is separated by a
  comma.  The output is delimited by ``(`` and ``)``.

Default ``readThis`` methods are created for all types for which a user-defined
``readThis`` method is not provided.  The default ``readThis`` methods are
defined to read in the output of the default ``writeThis`` method.

Additionally, the Chapel implementation includes ``writeThis`` methods for
built-in types as follows:

* for an array: outputs the elements of the array in row-major order
  where rows are separated by line-feeds and blank lines are used to separate
  other dimensions.
* for a domain: outputs the dimensions of the domain enclosed by
  ``{`` and ``}``.
* for a range: output the lower bound of the range, output ``..``,
  then output the upper bound of the range.  If the stride of the range
  is not ``1``, output the word ``by`` and then the stride of the range.
  If the range has special alignment, output the word ``align`` and then the
  alignment.
* for tuples, outputs the components of the tuple in order delimited by ``(``
  and ``)``, and separated by commas.

These types also include ``readThis`` methods to read the corresponding format.
Note that when reading an array, the domain of the array must be set up
appropriately before the elements can be read.

.. note::

  Note that it is not currently possible to read and write circular
  data structures with these mechanisms.

 */
pragma "module included by default"
module ChapelIO {
  use ChapelBase; // for uint().
  use ChapelLocale;

  // TODO -- this should probably be private
  pragma "no doc"
  proc _isNilObject(val) {
    proc helper(o: borrowed object) do return o == nil;
    proc helper(o) do                  return false;
    return helper(val);
  }

  use IO;
  import CTypes.{c_int};

  /*
   Local copies of IO.{EEOF,ESHORT,EFORMAT} as these are being phased out
   and are now private in IO
   */
  private extern proc chpl_macro_int_EEOF():c_int;
  private extern proc chpl_macro_int_ESHORT():c_int;
  private extern proc chpl_macro_int_EFORMAT():c_int;
  pragma "no doc"
  private inline proc EEOF do return chpl_macro_int_EEOF():c_int;
  pragma "no doc"
  private inline proc ESHORT do return chpl_macro_int_ESHORT():c_int;
  pragma "no doc"
  private inline proc EFORMAT do return chpl_macro_int_EFORMAT():c_int;

    private
    proc isIoField(x, param i) param {
      if isType(__primitive("field by num", x, i)) ||
         isParam(__primitive("field by num", x, i)) ||
         __primitive("field by num", x, i).type == nothing {
        // I/O should ignore type or param fields
        return false;
      } else {
        return true;
      }
    }

    // ch is the fileReader or fileWriter
    // x is the record/class/union
    // i is the field number of interest
    private
    proc ioFieldNameEqLiteral(ch, type t, param i) {
      const st = ch.styleElement(QIO_STYLE_ELEMENT_AGGREGATE);
      if st == QIO_AGGREGATE_FORMAT_JSON {
        return '"' + __primitive("field num to name", t, i) + '":';
      } else {
        return __primitive("field num to name", t, i) + " = ";
      }
    }

    private
    proc ioFieldNameLiteral(ch, type t, param i) {
      const st = ch.styleElement(QIO_STYLE_ELEMENT_AGGREGATE);
      if st == QIO_AGGREGATE_FORMAT_JSON {
        return '"' + __primitive("field num to name", t, i) + '"';
      } else {
        return __primitive("field num to name", t, i);
      }
    }

    pragma "no doc"
    proc writeThisFieldsDefaultImpl(writer, x:?t, inout first:bool) throws {
      param num_fields = __primitive("num fields", t);
      var isBinary = writer.binary();

      if (isClassType(t)) {
        if _to_borrowed(t) != borrowed object {
          // only write parent fields for subclasses of object
          // since object has no .super field.
          writeThisFieldsDefaultImpl(writer, x.super, first);
        }
      }

      if isExternUnionType(t) {
        compilerError("Cannot write extern union");

      } else if !isUnionType(t) {
        // print out all fields for classes and records
        for param i in 1..num_fields {
          if isIoField(x, i) {
            if !isBinary {
              if !first then writer._writeLiteral(", ");

              const eq = ioFieldNameEqLiteral(writer, t, i);
              writer._writeLiteral(eq);
            }

            writer.write(__primitive("field by num", x, i));

            first = false;
          }
        }
      } else {
        // Handle unions.
        // print out just the set field for a union.
        var id = __primitive("get_union_id", x);
        for param i in 1..num_fields {
          if isIoField(x, i) && i == id {
            if isBinary {
              // store the union ID
              write(id);
            } else {
              const eq = ioFieldNameEqLiteral(writer, t, i);
              writer._writeLiteral(eq);
            }
            writer.write(__primitive("field by num", x, i));
          }
        }
      }
    }
    // Note; this is not a multi-method and so must be called
    // with the appropriate *concrete* type of x; that's what
    // happens now with buildDefaultWriteFunction
    // since it has the concrete type and then calls this method.

    // MPF: We would like to entirely write the default writeThis
    // method in Chapel, but that seems to be a bit of a challenge
    // right now and I'm having trouble with scoping/modules.
    // So I'll go back to writeThis being generated by the
    // compiler.... the writeThis generated by the compiler
    // calls writeThisDefaultImpl.
    pragma "no doc"
    proc writeThisDefaultImpl(writer, x:?t) throws {
      const st = writer.styleElement(QIO_STYLE_ELEMENT_AGGREGATE);
      const isJson = st == QIO_AGGREGATE_FORMAT_JSON;

      if !writer.binary() {
        const start = if isJson then "{"
                      else if st == QIO_AGGREGATE_FORMAT_CHPL
                      then "new " + t:string + "("
                      else if isClassType(t) then "{"
                      else "(";
        writer._writeLiteral(start);
      }

      var first = true;

      writeThisFieldsDefaultImpl(writer, x, first);

      if !writer.binary() {
        const end = if isJson then "}"
                    else if st == QIO_AGGREGATE_FORMAT_CHPL then ")"
                    else if isClassType(t) then "}"
                    else ")";
        writer._writeLiteral(end);
      }
    }

    //
    // Called by the compiler to implement the default behavior for
    // the compiler-generated 'encodeTo' method.
    //
    // TODO: would any formats want to print type or param fields?
    //
    proc encodeToDefaultImpl(writer:fileWriter, const x:?t) throws {
      writer.formatter.writeTypeStart(writer, t);

      if isClassType(t) && _to_borrowed(t) != borrowed object {
        encodeToDefaultImpl(writer, x.super);
      }

      param num_fields = __primitive("num fields", t);
      for param i in 1..num_fields {
        if isIoField(x, i) {
          param name : string = __primitive("field num to name", x, i);
          writer.formatter.writeField(writer, name,
                                      __primitive("field by num", x, i));
        }
      }

      writer.formatter.writeTypeEnd(writer, t);
    }

    //
    // Used by the compiler to support the compiler-generated initializers that
    // accept a 'fileReader'. The type 'fileReader' may not be readily
    // available, but the ChapelIO module generally is available and so
    // we place the check here. For example:
    //
    //   proc R.init(r) where chpl__isFileReader(r.type) { ... }
    //
    proc chpl__isFileReader(type T) param : bool {
      return isSubtype(T, fileReader(?));
    }

    private
    proc skipFieldsAtEnd(reader, inout needsComma:bool) throws {
      const qioFmt = reader.styleElement(QIO_STYLE_ELEMENT_AGGREGATE);
      const isJson = qioFmt == QIO_AGGREGATE_FORMAT_JSON;
      const qioSkipUnknown = QIO_STYLE_ELEMENT_SKIP_UNKNOWN_FIELDS;
      const isSkipUnknown = reader.styleElement(qioSkipUnknown) != 0;

      if !isSkipUnknown || !isJson then return;

      while true {
        if needsComma {

          // Try reading a comma. If we don't, break out of the loop.
          try {
            reader._readLiteral(",", true);
            needsComma = false;
          } catch err: BadFormatError {
            break;
          }
        }

        // Skip an unknown JSON field.


        try reader.skipField();
        needsComma = true;
      }
    }

    pragma "no doc"
    proc readThisFieldsDefaultImpl(reader, type t, ref x,
                                   inout needsComma: bool) throws
        where !isUnionType(t) {

      param numFields = __primitive("num fields", t);
      var isBinary = reader.binary();

      if isClassType(t) && _to_borrowed(t) != borrowed object {

        //
        // Only write parent fields for subclasses of object since object has
        // no .super field.
        //
        type superType = x.super.type;

        // Copy the pointer to pass it by ref.
        var castTmp: superType = x;

        try {
          // Read superclass fields.
          readThisFieldsDefaultImpl(reader, superType, castTmp,
                                    needsComma);
        } catch err {

          // TODO: Hold superclass errors or just throw immediately?
          throw err;
        }
      }

      if isBinary {

        // Binary is simple, just read all fields in order.
        for param i in 1..numFields do
          if isIoField(x, i) then
            try reader.readIt(__primitive("field by num", x, i));
      } else if numFields > 0 {

        // This tuple helps us not read the same field twice.
        var readField: (numFields) * bool;

        // These two help us know if we've read all the fields.
        var numToRead = 0;
        var numRead = 0;

        for param i in 1..numFields do
          if isIoField(x, i) then
            numToRead += 1;

        // The order should not matter.
        while numRead < numToRead {

          // Try reading a comma. If we don't, then break.
          if needsComma then
            try {
              reader._readLiteral(",", true);
              needsComma = false;
            } catch err: BadFormatError {
              // Break out of the loop if we didn't read a comma.
              break;
            }

          //
          // Find a field name that matches.
          //
          // TODO: this is not particularly efficient. If we have a lot of
          // fields, this is O(n**2), and there are other potential problems
          // with string reallocation.
          // We could do better if we put the field names to scan for into
          // a regular expression, possibly with | and ( ) for capture
          // groups so we can know which field was read.
          //

          var st = reader.styleElement(QIO_STYLE_ELEMENT_AGGREGATE);
          const qioSkipUnknown = QIO_STYLE_ELEMENT_SKIP_UNKNOWN_FIELDS;
          var isSkipUnknown = reader.styleElement(qioSkipUnknown) != 0;

          var hasReadFieldName = false;
          const isJson = st == QIO_AGGREGATE_FORMAT_JSON;

          for param i in 1..numFields {
            if !isIoField(x, i) || hasReadFieldName || readField[i-1] then
              continue;

            try {
              const fieldName = ioFieldNameLiteral(reader, t, i);
              reader._readLiteral(fieldName);
            } catch e : BadFormatError {
              // Try reading again with a different union element.
              continue;
            } catch e : EofError {
              continue;
            }

            hasReadFieldName = true;
            needsComma = true;

            const equalSign = if isJson then ":"
                              else "=";

            try reader._readLiteral(equalSign, true);

            try reader.readIt(__primitive("field by num", x, i));
            readField[i-1] = true;
            numRead += 1;
          }


          // Try skipping fields if we're JSON and allowed to do so.
          if !hasReadFieldName then
            if isSkipUnknown && isJson {
              try reader.skipField();
              needsComma = true;
            } else {
              throw new owned
                BadFormatError("Failed to read field, could not skip");
            }
        }

        // Check that we've read all fields, return error if not.
        if numRead == numToRead {
          // TODO: Do we throw superclass error here?
        } else {
          param tag = if isClassType(t) then "class" else "record";
          const msg = "Read only " + numRead:string + " out of "
              + numToRead:string + " fields of " + tag + " " + t:string;
          throw new owned
            BadFormatError(msg);
        }
      }
    }

    pragma "no doc"
    proc readThisFieldsDefaultImpl(reader, type t, ref x,
                                   inout needsComma: bool) throws
        where isUnionType(t) && !isExternUnionType(t) {

      param numFields = __primitive("num fields", t);
      var isBinary = reader.binary();


      if isBinary {
        var id = __primitive("get_union_id", x);

        // Read the ID.
        try reader.readIt(id);
        for param i in 1..numFields do
          if isIoField(x, i) && i == id then
            try reader.readIt(__primitive("field by num", x, i));
      } else {

        // Read the field name = part until we get one that worked.
        var hasFoundAtLeastOneField = false;

        for param i in 1..numFields {
          if !isIoField(x, i) then continue;

          try {
            const fieldName = ioFieldNameLiteral(reader, t, i);
            reader._readLiteral(fieldName);
          } catch e : BadFormatError {
            // Try reading again with a different union element.
            continue;
          } catch e : EofError {
            continue;
          }

          hasFoundAtLeastOneField = true;

          const st = reader.styleElement(QIO_STYLE_ELEMENT_AGGREGATE);
          const isJson = st == QIO_AGGREGATE_FORMAT_JSON;
          const eq = if isJson then ":"
                     else "=";

          try reader._readLiteral(eq, true);

          // We read the 'name = ', so now read the value!
          __primitive("set_union_id", x, i);
          try reader.readIt(__primitive("field by num", x, i));
        }

        if !hasFoundAtLeastOneField then
          throw new owned
            BadFormatError("Failed to find any union fields");
      }
    }

    // Note; this is not a multi-method and so must be called
    // with the appropriate *concrete* type of x; that's what
    // happens now with buildDefaultWriteFunction
    // since it has the concrete type and then calls this method.
    pragma "no doc"
    proc readThisDefaultImpl(reader, x:?t) throws where isClassType(t) {
      const st = reader.styleElement(QIO_STYLE_ELEMENT_AGGREGATE);

      if !reader.binary() {
        const start = if st == QIO_AGGREGATE_FORMAT_CHPL
                      then "new " + t:string + "("
                      else "{";

        try reader._readLiteral(start);
      }

      var needsComma = false;

      // Make a copy of the reference that we can modify.
      var obj = x;

      try readThisFieldsDefaultImpl(reader, t, obj, needsComma);
      try skipFieldsAtEnd(reader, needsComma);

      if !reader.binary() {
        const end = if st == QIO_AGGREGATE_FORMAT_CHPL then ")"
                    else "}";

        try reader._readLiteral(end);
      }
    }

    pragma "no doc"
    proc readThisDefaultImpl(reader, ref x:?t) throws where !isClassType(t) {
      const st = reader.styleElement(QIO_STYLE_ELEMENT_AGGREGATE);
      const isJson = st ==  QIO_AGGREGATE_FORMAT_JSON;

      if !reader.binary() {
        const start = if st ==  QIO_AGGREGATE_FORMAT_CHPL
                      then "new " + t:string + "("
                      else if isJson then "{"
                      else "(";

        try reader._readLiteral(start);
      }

      var needsComma = false;

      try readThisFieldsDefaultImpl(reader, t, x, needsComma);
      try skipFieldsAtEnd(reader, needsComma);

      if !reader.binary() {
        const end = if isJson then "}"
                    else ")";

        try reader._readLiteral(end);
      }
    }

  pragma "no doc"
  proc locale.writeThis(f) throws {
    // FIXME this doesn't resolve without `this`
    f.write(this._instance);
  }

  pragma "no doc"
  proc _ddata.writeThis(f) throws {
    compilerWarning("printing _ddata class");
    f.write("<_ddata class cannot be printed>");
  }

  pragma "no doc"
  proc _ddata.encodeTo(f) throws { writeThis(f); }

  pragma "no doc"
  proc chpl_taskID_t.writeThis(f) throws {
    f.write(this : uint(64));
  }
  pragma "no doc"
  proc chpl_taskID_t.encodeTo(f) throws { writeThis(f); }

  pragma "no doc"
  proc chpl_taskID_t.readThis(f) throws {
    this = f.read(uint(64)) : chpl_taskID_t;
  }

  pragma "no doc"
  proc type chpl_taskID_t.decodeFrom(f) throws {
    var ret : chpl_taskID_t;
    ret.readThis(f);
    return ret;
  }

  pragma "no doc"
  proc nothing.writeThis(f) {}
  pragma "no doc"
  proc nothing.encodeTo(f) {}

  pragma "no doc"
  proc _tuple.readThis(f) throws {
    _readWriteHelper(f);
  }

  pragma "no doc"
  proc _tuple.writeThis(f) throws {
    _readWriteHelper(f);
  }

  // Moved here to avoid circular dependencies in ChapelTuple.
  pragma "no doc"
  proc _tuple._readWriteHelper(f) throws {
    const st = f.styleElement(QIO_STYLE_ELEMENT_TUPLE);
    const isJson = st == QIO_TUPLE_FORMAT_JSON;
    const binary = f.binary();

    // Returns a 4-tuple containing strings representing:
    // - start of a tuple
    // - the comma/separator between elements
    // - a comma/separator for 1-tuples
    // - end of a tuple
    proc getLiterals() : 4*string {
      if st == QIO_TUPLE_FORMAT_SPACE {
        return ("", " ", "", "");
      } else if isJson {
        return ("[", ", ", "", "]");
      } else {
        return ("(", ", ", ",", ")");
      }
    }

    const (start, comma, comma1tup, end) = getLiterals();

    proc helper(const ref arg) throws where f.writing { f.write(arg); }
    proc helper(ref arg) throws where !f.writing { arg = f.read(arg.type); }

    proc rwLiteral(lit:string) throws {
      if f.writing then f._writeLiteral(lit); else f._readLiteral(lit);
    }

    if !binary {
      rwLiteral(start);
    }
    if size > 1 {
      helper(this(0));
      for param i in 1..size-1 {
        if !binary {
          rwLiteral(comma);
        }
        helper(this(i));
      }
    } else if size == 1 {
      helper(this(0));
      if !binary then
        rwLiteral(comma1tup);
    } else {
      // size < 1, print nothing
    }
    if !binary {
      rwLiteral(end);
    }
  }

  proc type _tuple.decodeFrom(f) throws {
    ref fmt = f.formatter;
    pragma "no init"
    var ret : this;
    fmt.readTypeStart(f, this);
    for param i in 0..<this.size {
      pragma "no auto destroy"
      var elt = fmt.readField(f, "", this(i));
      __primitive("=", ret(i), elt);
    }
    fmt.readTypeEnd(f, this);
    return ret;
  }

  proc const _tuple.encodeTo(w) throws {
    ref fmt = w.formatter;
    fmt.writeTypeStart(w, this.type);
    for param i in 0..<size {
      const ref elt = this(i);
      // TODO: should probably have something like 'writeElement'
      fmt.writeField(w, "", elt);
    }
    fmt.writeTypeEnd(w, this.type);
  }

  // Moved here to avoid circular dependencies in ChapelRange
  // Write implementation for ranges
  pragma "no doc"
  proc range.writeThis(f) throws
  {
    // a range with a more normalized alignment
    // a separate variable so 'this' can be const
    var alignCheckRange = this;
    if f.writing {
      alignCheckRange.normalizeAlignment();
    }

    if (boundedType == BoundedRangeType.bounded ||
        boundedType == BoundedRangeType.boundedLow) then
      f.write(lowBound);
    f._writeLiteral("..");
    if (boundedType == BoundedRangeType.bounded ||
        boundedType == BoundedRangeType.boundedHigh) {
      if (chpl__singleValIdxType(this.idxType) && this._low != this._high) {
        f._writeLiteral("<");
        f.write(lowBound);
      } else {
        f.write(highBound);
      }
    }
    if stride != 1 {
      f._writeLiteral(" by ");
      f.write(stride);
    }

    // Write out the alignment only if it differs from natural alignment.
    // We take alignment modulo the stride for consistency.
    if ! alignCheckRange.isNaturallyAligned() && aligned {
      f._writeLiteral(" align ");
      f.write(chpl_intToIdx(chpl__mod(chpl__idxToInt(alignment), stride)));
    }
  }

  pragma "no doc"
  proc ref range.readThis(f) throws {
    if hasLowBound() then _low = f.read(_low.type);

    f._readLiteral("..");

    if hasHighBound() then _high = f.read(_high.type);

    if stride != 1 {
      f._readLiteral(" by ");
      _stride = f.read(stride.type);
    }

    try {
      f._readLiteral(" align ");

      if stridable {
        _alignment = f.read(intIdxType);
      } else {
        throw new owned
          BadFormatError("Range is not stridable, cannot store alignment");
      }
    } catch err: BadFormatError {
      // Range is naturally aligned.
    }
  }

  proc range.init(type idxType = int,
                  param boundedType : BoundedRangeType = BoundedRangeType.bounded,
                  param stridable : bool = false,
                  reader: fileReader(?)) {
    this.init(idxType, boundedType, stridable);

    // TODO:
    // The alignment logic here is pretty tricky, so fall back on the
    // actual operators for the time being...

    // TODO: experiment with using throwing initializers in this case.
    try! {
      if hasLowBound() then _low = reader.read(_low.type);
      reader._readLiteral("..");
      if hasHighBound() then _high = reader.read(_high.type);

      if stridable {
        if reader.matchLiteral(" by ") {
          //_stride = reader.read(stride.type);
          this = this by reader.read(stride.type);
        }
      }
    }

    try! {
      try {
        if reader.matchLiteral(" align ") {
          if stridable {
            //_alignment = reader.read(intIdxType);
            this = this align reader.read(intIdxType);
          }
        } else {
          // TODO: throw error if not stridable
        }
      } catch err: BadFormatError {
        // Range is naturally aligned.
      }
    }
  }

  pragma "no doc"
  override proc LocaleModel.writeThis(f) throws {
    f._writeLiteral("LOCALE");
    f.write(chpl_id());
  }

  /* Errors can be printed out. In that event, they will
     show information about the error including the result
     of calling :proc:`Error.message`.
  */
  pragma "no doc"
  override proc Error.writeThis(f) throws {
    f.write(chpl_describe_error(this));
  }

  /* Equivalent to ``try! stdout.write``. See :proc:`IO.fileWriter.write` */
  proc write(const args ...?n) {
    try! stdout.write((...args));
  }
  /* Equivalent to ``try! stdout.writeln``. See :proc:`IO.fileWriter.writeln` */
  proc writeln(const args ...?n) {
    try! stdout.writeln((...args));
  }

  // documented in the arguments version.
  pragma "no doc"
  proc writeln() {
    try! stdout.writeln();
  }

 /* Equivalent to ``try! stdout.writef``. See
     :proc:`FormattedIO.fileWriter.writef`. */
  proc writef(fmt:?t, const args ...?k)
      where isStringType(t) || isBytesType(t)
  {
    try! { stdout.writef(fmt, (...args)); }
  }
  // documented in string version
  pragma "no doc"
  proc writef(fmt:?t)
      where isStringType(t) || isBytesType(t)
  {
    try! { stdout.writef(fmt); }
  }

  @chpldoc.nodoc
  proc chpl_stringify_wrapper(const args ...):string {
    use IO only chpl_stringify;
    return chpl_stringify((...args));
  }

  //
  // Catch all
  //
  // Convert 'x' to a string just the way it would be written out.
  //
  // This is marked as last resort so it doesn't take precedence over
  // generated casts for types like enums
  //
  // This version only applies to non-primitive types
  // (primitive types should support :string directly)
  pragma "last resort"
  @chpldoc.nodoc
  operator :(x, type t:string) where !isPrimitiveType(x.type) {
    compilerWarning(
      "universal 'x:string' is deprecated; please define a cast-to-string operator on the type '" +
      x.type:string +
      "', or use 'try! \"%t\".format(x)' from IO.FormattedIO instead"
    );
    return chpl_stringify_wrapper(x);
  }
}
