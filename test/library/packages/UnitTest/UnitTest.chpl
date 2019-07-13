/*
Module UnitTest provides support for automated testing in Chapel .
Any function of the form

.. code-block:: chapel
  
  proc funcName(test: Test) throws {}

is treated as a test function.

Example

.. code-block:: chapel

   use UnitTest;

   proc test1(test: Test) throws {
     test.assertTrue(True);
   }

   UnitTest.runTest(test1);

Specifying locales

.. code-block:: chapel

   proc test2(test: Test) throws {
     test.addNumLocales(16);
   }

   proc test3(test: Test) throws {
     test.addNumLocales(16,8);
   }
  
   proc test4(test: Test) throws {
     test.maxLocales(4);
     test.minLocales(2);
   }

Specifying Dependencies:

.. code-block:: chapel

   proc test5(test: Test) throws {
     test.dependsOn(test3);
   }

   proc test6(test: Test) throws {
     test.dependsOn(test2, test5);
   }



*/
module UnitTest {
  use Reflection;
  use TestError;
  pragma "no doc"
  config const testNames: string = "None";
  pragma "no doc"
  config const failedTestNames: string = "None";
  pragma "no doc"
  config const errorTestNames: string = "None";
  pragma "no doc"
  config const ranTests: string = "None";
  // This is a dummy test to capture the function signature
  private
  proc testSignature(test: Test) throws { }
  pragma "no doc"
  var tempFcf = testSignature;
  pragma "no doc"
  type argType = tempFcf.type;  //Type of First Class Test Functions

  class Test {
    pragma "no doc"
    var numMaxLocales = max(int),
        numMinLocales = min(int);
    pragma "no doc"
    var dictDomain: domain(int);
    pragma "no doc"
    var testDependsOn: [1..0] argType;

    /* Unconditionally skip a test.

      :arg reason: the reason for skipping
      :type reason: `string` 
    */
    proc skip(reason: string = "") throws {
      throw new owned TestSkipped(reason);
    }

    /*
    Skip a test if the condition is true.

    :arg condition: the boolean condition
    :type condition: `bool`

    :arg reason: the reason for skipping
    :type reason: `string`
   */
    proc skipIf(condition: bool, reason: string = "") throws {
      if condition then
        skip(reason);
    }

    /*
      Assert that a boolean condition is true.  If it is false, prints
      'assert failed' and rasies AssertionError. 

      :arg test: the boolean condition
      :type test: `bool`
    */
    pragma "insert line file info"
    pragma "always propagate line file info"
    proc assertTrue(test: bool) throws {
      if !test then
        throw new owned AssertionError("assertTrue failed. Given expression is False");
    }

    /*
      Assert that a boolean condition is false.  If it is true, prints
      'assert failed' and raises AssertionError.

      :arg test: the boolean condition
      :type test: `bool`
    */
    pragma "insert line file info"
    pragma "always propagate line file info"
    proc assertFalse(test: bool) throws {
      if test then
        throw new owned AssertionError("assertFalse failed. Given expression is True");
    }
    
    pragma "no doc"
    /*Function to call the respective method for equality checking based on the type of argument*/
    proc checkAssertEquality(first, second) throws {
      type firstType = first.type, 
          secondType = second.type;

      if isTupleType(firstType) && isTupleType(secondType) {
        // both are tuples.
        assertTupleEqual(first, second);
        return;
      }
      else if isArrayType(firstType) && isArrayType(secondType) {
        // both are arrays
        assertArrayEqual(first, second);
        return;
      }
      else if isRangeType(firstType) && isRangeType(secondType) {
        // both are Range
        assertRangeEqual(first, second);
      }
      else if isString(first) && isString(second) {
        // both are Strings
        assertStringEqual(first, second);
      }
      else {
        __baseAssertEqual(first, second);
      }
    }
    
    pragma "no doc"
    /*
      Check that a boolean array is true.  If any element is false, returns 'false'
      else return 'true'.

      :arg it: the iterator to the array
      :type it: `iterator`
    */
    proc all(it: _iteratorRecord) {
      for b in it do if b == false then return false;
      return true;
    }

    pragma "no doc"
    /* Method overloading for the above function. Return the argument itself
    */
    proc all(check: bool) {
      return check;
    }
    
    pragma "no doc"
    /*An equality assertion for sequences (like arrays, tuples, strings, range).
      Args:
      seq1: The first sequence to compare.
      seq2: The second sequence to compare.
      seq_type_name: The name of datatype of the sequences
    */
    proc assertSequenceEqual(seq1, seq2, seq_type_name) throws {
      var tmpString: string;
      const len1 = seq1.size,
            len2 = seq2.size;
      if len1 == 0 && len2 == 0 then return;
      if len1 == 0 {
        tmpString = "First "+seq_type_name+" has no length.";
      }
      if tmpString == "" {
        if len2 == 0 {
          tmpString = "Second "+seq_type_name+" has no length.";
        }
      }
      if tmpString == "" {
        if len1 == len2 {
          if all(seq1 == seq2) then return;
        }
        tmpString = seq_type_name+"s differ: ";
        if seq_type_name == "Array" {
          tmpString += "'[";
          for i in 1..seq1.size {
            if i != seq1.size then tmpString+= seq1[i]+", ";
            else tmpString += seq1[i]+"]' != '[";
          }
          for i in 1..seq2.size {
            if i != seq2.size then tmpString+= seq2[i]+", ";
            else tmpString += seq2[i]+"]'";
          }
        }
        else {
          tmpString += "'"+stringify(seq1)+"' != '"+stringify(seq2)+"'" ;
        }
        for i in 1..min(len1,len2) {
          var item1 = seq1[i],
              item2 = seq2[i];
          if item1 != item2 {
            tmpString += "\nFirst differing element at index "+i +":\n'"+item1+"'\n'"+item2+"'\n";
            break;
          }
        }
        if len1 > len2 {
          var size_diff = len1 - len2;
          tmpString += "\nFirst "+seq_type_name+" contains "+ size_diff +" additionl elements.\n";
          tmpString += "First extra element is at index "+(len2+1)+"\n'"+seq1[len2+1]+"'\n";
        }
        else if len1 < len2 {
          var size_diff = len2 - len1;
          tmpString += "\nSecond "+seq_type_name+" contains "+ size_diff +" additionl elements.\n";
          tmpString += "First extra element is at index "+(len1+1)+"\n'"+seq2[len1+1]+"'\n";
        }
      }
      throw new owned AssertionError(tmpString);
    }

    pragma "no doc"
    /*An array-specific equality assertion.
      Args:
      array1: The first array to compare.
      array2: The second array to compare.
    */
    proc assertArrayEqual(array1, array2) throws {
      type firstType = array1.type,
          secondType = array2.type;
      if firstType == secondType {
        if array1.rank == 1 {
          assertSequenceEqual(array1, array2, "Array");
        }
        else {
          if !array1.equals(array2) {
            var tmpString = "assert failed - \n'" + stringify(array1) +"'\n!=\n'"+stringify(array2)+"'";
            throw new owned AssertionError(tmpString);
          }
        }
      }
      else {
        var tmpString = "assert failed - \n'" + stringify(array1) +"'\nand\n'"+stringify(array2) + "'\nare not of same type";
        throw new owned AssertionError(tmpString);
      }
    }

    pragma "no doc"
    /*
      A tuple-specific equality assertion.
      Args:
      tuple1: The first tuple to compare.
      tuple2: The second tuple to compare.
    */
    proc assertTupleEqual(tuple1, tuple2) throws {
      type firstType = tuple1.type,
          secondType = tuple2.type;
      if firstType == secondType {
        assertSequenceEqual(tuple1,tuple2,"tuple("+firstType: string+")");
      }
      else {
        var tmpString = "assert failed - '" + stringify(tuple1) +"' and '"+stringify(tuple2) + "' are not of same type";
        throw new owned AssertionError(tmpString);
      }
    }

    pragma "no doc"
    /*
      A range-specific equality assertion.
      Args:
      range1: The first range to compare.
      range2: The second range to compare.
    */
    proc assertRangeEqual(range1, range2) throws {
      __baseAssertEqual(range1,range2);
    }

    pragma "no doc"
    /*
      A string-specific equality assertion.
      Args:
      string1: The first string to compare.
      string2: The second string to compare.
    */
    proc assertStringEqual(string1, string2) throws {
      assertSequenceEqual(string1,string2,"String");
    }
    
    pragma "no doc"
    /*The default assertEqual implementation, not type specific.*/
    proc __baseAssertEqual(first, second) throws {
      if canResolve("!=",first,second) {
        if (first != second) {
          var tmpString = "assert failed - '" + stringify(first) +"' != '"+stringify(second)+"'";
          throw new owned AssertionError(tmpString);
        }
      }
      else {
        var tmpString = "assert failed - '" + stringify(first) +"' and '"+stringify(second) + "' are not of same type";
        throw new owned AssertionError(tmpString);
      }
    }
    
    /*
      Fail if the two objects are unequal as determined by the '==' operator.
      
      :arg first: The first object to compare.
      :arg second: The first object to compare. 
    */
    proc assertEqual(first, second) throws {
      checkAssertEquality(first, second);
    }

    pragma "no doc"
    /* Function that checks whether two arguments are unequal or not*/
    proc checkAssertInequality(first,second) throws {
      type firstType = first.type,
          secondType = second.type;
      if isTupleType(firstType) && isTupleType(secondType) {
        if firstType == secondType {
          if first == second then return false;
        }
      }
      else if isArrayType(firstType) && isArrayType(secondType) {
        if (firstType == secondType) && (first.size == second.size) {
          if first.equals(second) then return false;
        }
      }
      else {
        if first == second then return false;
      }
      return true;
    }

    
    /*
      Assert that a first argument is not equal to second argument. If it is false, 
      rasies AssertionError. Uses '==' operator and type to determine if both are equal
      or not.

      :arg first: The first object to compare.
      :arg second: The first object to compare. 
    */
    proc assertNotEqual(first, second) throws {
      if canResolve("!=",first, second) {
        if !checkAssertInequality(first,second) {
          var tmpString = "assert failed - \n'" + stringify(first) +"'\n== \n'"+stringify(second)+"'";
          throw new owned AssertionError(tmpString);
        }
      }
    }

    /*
      Assert that a first argument is greater than second argument.  If it is false, prints
      'assert failed' and rasies AssertionError. 

      :arg first: The first object to compare.
      :arg second: The first object to compare. 
    */
    proc assertGreaterThan(first, second) throws {
      if canResolve(">=",first, second) {
        checkGreater(first, second);
      }
      else {
        var tmpString = "assert failed - First element is of type " + first.type:string +" and Second is of type "+second.type:string;
        throw new owned AssertionError(tmpString);
      }
    }

    pragma "no doc"
    /*checks the type of the arguments and then do greater than comaprison */
    proc checkGreater(first, second) throws {
      type firstType = first.type,
          secondType = second.type;

      if isTupleType(firstType) && isTupleType(secondType) {
        // both are tuples.
        assertTupleGreater(first, second);
        return;
      }
      else if isArrayType(firstType) && isArrayType(secondType) {
        // both are arrays
        assertArrayGreater(first, second);
        return;
      }
      else if isRangeType(firstType) && isRangeType(secondType) {
        // both are Range
        assertRangeGreater(first, second);
      }
      else if isString(first) && isString(second) {
        // both are Strings
        assertStringGreater(first, second);
      }
      else {
        __baseAssertGreater(first, second);
      }
    }
    
    pragma "no doc"
    /*An greater assertion for sequences (like arrays, tuples, strings).
      Args:
      seq1: The first sequence to compare.
      seq2: The second sequence to compare.
      seq_type_name: The name of datatype of the sequences
    */
    proc assertSequenceGreater(seq1, seq2, seq_type_name) throws {
      var checkgreater: bool = false,
          checkequal: bool = false;
      const len1 = seq1.size,
            len2 = seq2.size;
      var symbol: string,
          tmpString: string,
          tmplarge: string;

      if len1 == 0 {
        tmpString = "First "+seq_type_name+" has no length.";
      }
      if tmpString == "" {
        if len2 == 0 {
          tmpString = "Second "+seq_type_name+" has no length.";
        }
      }
      if tmpString == "" {
        for i in 1..len1 {
          var item1 = seq1[i],
              item2 = seq2[i];
          if item1 == item2 then checkequal = true;
          else if item1 < item2 {
            tmpString += "First "+seq_type_name+" < Second "+seq_type_name+" :\n";
            tmplarge += "\nFirst larger element in second "+seq_type_name+" is at index "+i +":\n'"+item1+"'\n'"+item2+"'\n";
            checkgreater = true;
            checkequal = false;
            symbol = "<";
            break;
          }
          else {
            checkequal = false;
            break;
          }
        }
        if !checkgreater && !checkequal then return;
        else if checkequal {
          tmpString += "Both "+seq_type_name+" are equal\n";
          symbol = "==";
        }
        if seq_type_name == "Array" {
          tmpString += "'[";
          for i in 1..seq1.size {
            if i != seq1.size then tmpString+= seq1[i]+", ";
            else tmpString += seq1[i]+"]' "+symbol+ " '[";
          }
          for i in 1..seq2.size {
            if i != seq2.size then tmpString+= seq2[i]+", ";
            else tmpString += seq2[i]+"]'";
          }
        }
        else {
          tmpString += "'"+stringify(seq1)+"' "+symbol+" '"+stringify(seq2)+"'" ;
        }
        tmpString+=tmplarge;
      }
      throw new owned AssertionError(tmpString);
    }

    pragma "no doc"
    /*An array-specific greater assertion.
      Args:
      array1: The first array to compare.
      array2: The second array to compare.
    */
    proc assertArrayGreater(array1, array2) throws {
      if array1.rank == array2.rank {
        if array1.shape == array2.shape {
          if array1.rank == 1 {
            assertSequenceGreater(array1, array2, "Array");
          }
          else { // can be reimplemented using `reduce`
            if all(array1 <= array2) { 
              var tmpString = "assert failed - \n'" + stringify(array1) +"'\n<=\n'"+stringify(array2)+"'";
              throw new owned AssertionError(tmpString);
            }
        }
        }
        else {
          var tmpString = "assert failed - First element is of shape " + stringify(array1.shape) +" and Second is of shape "+stringify(array2.shape);
          throw new owned AssertionError(tmpString);
        }
      }
      else {
        var tmpString = "assert failed - First element is of type " + array1.type:string +" and Second is of type "+array2.type:string;
        throw new owned AssertionError(tmpString);
      }
    }

    pragma "no doc"
    /*
      A tuple-specific greater assertion.
      Args:
      tuple1: The first tuple to compare.
      tuple2: The second tuple to compare.
    */
    proc assertTupleGreater(tuple1, tuple2) throws {
      type firstType = tuple1.type,
          secondType = tuple2.type;
      if firstType == secondType {
        assertSequenceGreater(tuple1,tuple2,"tuple("+firstType: string+")");
      }
      else {
        var tmpString = "assert failed - First element is of type " + firstType:string +" and Second is of type "+secondType:string;
        throw new owned AssertionError(tmpString);
      }
    }

    pragma "no doc"
    /*
      A range-specific greater assertion.
      Args:
      range1: The first range to compare.
      range2: The second range to compare.
    */
    proc assertRangeGreater(range1, range2) throws {
      if range1.size == range2.size {
        __baseAssertGreater(range1,range2);
      }
      else {
        var tmpString = "assert failed - Ranges are not of same length";
        throw new owned AssertionError(tmpString);
      }
    }
    
    pragma "no doc"
    /*
      A string-specific Greater assertion.
      Args:
      string1: The first string to compare.
      string2: The second string to compare.
    */
    proc assertStringGreater(string1, string2) throws {
      if string1.size == string2.size {
        assertSequenceGreater(string1,string2,"String");
      }
      else {
        var tmpString = "assert failed - Strings are not of same length";
        throw new owned AssertionError(tmpString);
      }
    }

     pragma "no doc"
    /*The default assertGreater implementation, not type specific.*/
    proc __baseAssertGreater(first, second) throws {
      if all(first <= second) {
        var tmpString = "assert failed - '" + stringify(first) +"' <= '"+stringify(second)+"'";
        throw new owned AssertionError(tmpString);
      }
    }

    /*
      Assert that a first argument is less than second argument.  If it is false, rasies AssertionError. 

      :arg first: The first object to compare.
      :arg second: The first object to compare. 
    */
    proc assertLessThan(first, second) throws {
      if canResolve("<=",first, second) {
        checkLessThan(first, second);
      }
      else {
        var tmpString = "assert failed - First element is of type " + first.type:string +" and Second is of type "+second.type:string;
        throw new owned AssertionError(tmpString);
      }
    }
    
    pragma "no doc"
    /*checks the type of the arguments and then do less than comaprison */
    proc checkLessThan(first, second) throws {
      type firstType = first.type,
          secondType = second.type;

      if isTupleType(firstType) && isTupleType(secondType) {
        // both are tuples.
        assertTupleLess(first, second);
        return;
      }
      else if isArrayType(firstType) && isArrayType(secondType) {
        // both are arrays
        assertArrayLess(first, second);
        return;
      }
      else if isRangeType(firstType) && isRangeType(secondType) {
        // both are Range
        assertRangeLess(first, second);
      }
      else if isString(first) && isString(second) {
        // both are Strings
        assertStringLess(first, second);
      }
      else {
        __baseAssertLess(first, second);
      }
    }

    pragma "no doc"
    /*An less than assertion for sequences (like arrays, tuples, strings).
      Args:
      seq1: The first sequence to compare.
      seq2: The second sequence to compare.
      seq_type_name: The name of datatype of the sequences
    */
    proc assertSequenceLess(seq1, seq2, seq_type_name) throws {
      var checkless: bool = false,
          checkequal: bool = false;
      const len1 = seq1.size,
            len2 = seq2.size;
      var symbol: string,
          tmpString: string,
          tmplarge: string;

      if len1 == 0 {
        tmpString = "First "+seq_type_name+" has no length.";
      }
      if tmpString == "" {
        if len2 == 0 {
          tmpString = "Second "+seq_type_name+" has no length.";
        }
      }
      if tmpString == "" {
        for i in 1..len1 {
          var item1 = seq1[i],
              item2 = seq2[i];
          if item1 == item2 then checkequal = true;
          else if item1 > item2 {
            tmpString += "First "+seq_type_name+" > Second "+seq_type_name+" :\n";
            tmplarge += "\nFirst larger element in first "+seq_type_name+" is at index "+i +":\n'"+item1+"'\n'"+item2+"'\n";
            checkless = true;
            checkequal = false;
            symbol = ">";
            break;
          }
          else {
            checkequal = false;
            break;
          }
        }
        if !checkless && !checkequal then return;
        else if checkequal {
          tmpString += "Both "+seq_type_name+" are equal\n";
          symbol = "==";
        }
        if seq_type_name == "Array" {
          tmpString += "'[";
          for i in 1..seq1.size {
            if i != seq1.size then tmpString+= seq1[i]+", ";
            else tmpString += seq1[i]+"]' "+symbol+ " '[";
          }
          for i in 1..seq2.size {
            if i != seq2.size then tmpString+= seq2[i]+", ";
            else tmpString += seq2[i]+"]'";
          }
        }
        else {
          tmpString += "'"+stringify(seq1)+"' "+symbol+" '"+stringify(seq2)+"'" ;
        }
        tmpString+=tmplarge;
      }
      throw new owned AssertionError(tmpString);
    }

    pragma "no doc"
    /*An array-specific less than assertion.
      Args:
      array1: The first array to compare.
      array2: The second array to compare.
    */
    proc assertArrayLess(array1, array2) throws {
      if array1.rank == array2.rank {
        if array1.shape == array2.shape {
          if array1.rank == 1 {
            assertSequenceLess(array1, array2, "Array");
          }
          else {
            if all(array1 >= array2) {
              var tmpString = "assert failed - \n'" + stringify(array1) +"'\n>=\n'"+stringify(array2)+"'";
              throw new owned AssertionError(tmpString);
            }
        }
        }
        else {
          var tmpString = "assert failed - First element is of shape " + stringify(array1.shape) +" and Second is of shape "+stringify(array2.shape);
          throw new owned AssertionError(tmpString);
        }
      }
      else {
        var tmpString = "assert failed - First element is of type " + array1.type:string +" and Second is of type "+array2.type:string;
        throw new owned AssertionError(tmpString);
      }
    }
    
    pragma "no doc"
    /*
      A tuple-specific less than assertion.
      Args:
      tuple1: The first tuple to compare.
      tuple2: The second tuple to compare.
    */
    proc assertTupleLess(tuple1, tuple2) throws {
      type firstType = tuple1.type,
          secondType = tuple2.type;
      if firstType == secondType {
        assertSequenceLess(tuple1,tuple2,"tuple("+firstType: string+")");
      }
      else {
        var tmpString = "assert failed - First element is of type " + firstType:string +" and Second is of type "+secondType:string;
        throw new owned AssertionError(tmpString);
      }
    }

    pragma "no doc"
    /*
      A range-specific Less than assertion.
      Args:
      range1: The first range to compare.
      range2: The second range to compare.
    */
    proc assertRangeLess(range1, range2) throws {
      if range1.size == range2.size {
        __baseAssertLess(range1,range2);
      }
      else {
        var tmpString = "assert failed - Ranges are not of same length";
        throw new owned AssertionError(tmpString);
      }
    }

    pragma "no doc"    
    /*
      A string-specific Less than assertion.
      Args:
      string1: The first string to compare.
      string2: The second string to compare.
    */
    proc assertStringLess(string1, string2) throws {
      if string1.size == string2.size {
        assertSequenceLess(string1,string2,"String");
      }
      else {
        var tmpString = "assert failed - Strings are not of same length";
        throw new owned AssertionError(tmpString);
      }
    }

    pragma "no doc"
    /*The default assertGreater implementation, not type specific.*/
    proc __baseAssertLess(first, second) throws {
      if all(first >= second) {
        var tmpString = "assert failed - '" + stringify(first) +"' >= '"+stringify(second)+"'";
        throw new owned AssertionError(tmpString);
      }
    }

    /*
      Specify Max Number of Locales required to run the test
    
      :arg value: Maximum number of locales with which the test can be ran.
      :type value: `int`.

      :throws UnexpectedLocalesError: If `value` is less than 1 or `minNumLocales` 
    */
    proc maxLocales(value: int) throws {
      this.numMaxLocales = value;
      if this.numMaxLocales < 1 {
        throw new owned UnexpectedLocales("Max Locales is less than 1");
      }
      if this.numMaxLocales < this.numMinLocales {
        throw new owned UnexpectedLocales("Max Locales is less than Min Locales");
      }
      if value < numLocales {
        throw new owned TestIncorrectNumLocales("Required Locales ="+value);
      }
    }

    /*
      Specify Min Number of Locales required to run the test
    
      :arg value: Minimum number of locales with which the test can be ran.
      :type value: `int`.

      :throws UnexpectedLocalesError: If `value` is more than `maxNumLocales`
    */
    proc minLocales(value: int) throws {
      this.numMinLocales = value;
      if this.numMaxLocales < this.numMinLocales {
        throw new owned UnexpectedLocales("Max Locales is less than Min Locales");
      }
      if value > numLocales {
        throw new owned TestIncorrectNumLocales("Required Locales = "+value);
      }
    }

    /*
      To add locales in which test can be run.

      :arg locales: Multiple `","` seperated locale values

      :throws UnexpectedLocalesError: If `locales` are already added.
    
    */
    proc addNumLocales(locales: int ...?n) throws {
      var canRun =  false;
      if this.dictDomain.size > 0 {
        throw new owned UnexpectedLocales("Locales already added.");
      }
      for curLocale in locales {
        this.dictDomain.add(curLocale);
        if curLocale == numLocales {
          canRun = true;
        }
      }
      if !canRun {
        var localesStr: string = this.dictDomain: string;
        var localesErrorStr: string = "Required Locales = "+localesStr:string;
        throw new owned TestIncorrectNumLocales(localesErrorStr);
      }
    }

    /*Adds the tests in which the given test is depending.

      :arg tests: Multiple `","` seperated First Class Test Functions.
      
    */
    proc dependsOn(tests: argType ...?n) throws lifetime this < tests {
      if testDependsOn.size == 0 {
        for eachSuperTest in tests {
          this.testDependsOn.push_back(eachSuperTest);
        }
        throw new owned DependencyFound();
      }
    }
  }

  pragma "no doc"
  /*A test result class that can print formatted text results to a stream.*/
  class TextTestResult {
    var separator1 = "="* 70,
        separator2 = "-"* 70;
    
    proc startTest(test) throws {
      stdout.writeln(test: string);
    }

    proc addError(test, errMsg) throws {
      stdout.writeln("Flavour: ERROR");
      PrintError(errMsg);
    }

    proc addFailure(test, errMsg) throws {
      stdout.writeln("Flavour: FAIL");
      PrintError(errMsg);
    }

    proc addSuccess(test) throws {
      stdout.writeln("Flavour: OK");
      stdout.writeln(this.separator1);
      stdout.writeln(this.separator2);
    }

    proc addSkip(test, reason) throws {
      stdout.writeln("Flavour: SKIPPED");
      PrintError(reason);
    }

    proc addIncorrectNumLocales(test, reason) throws {
      stdout.writeln("Flavour: IncorrectNumLocales");
      PrintError(reason);
    }

    proc dependencyNotMet(test) throws {
      stdout.writeln("Flavour: Dependence");
      stdout.writeln(this.separator1);
      stdout.writeln(this.separator2);
    }

    proc PrintError(err) throws {
      stdout.writeln(this.separator1);
      stdout.writeln(err);
      stdout.writeln(this.separator2);
    }

  }
  
  pragma "no doc"
  class TestSuite {
    var testCount = 0;
    var _tests: [1..0] argType;
    
    proc addTest(test) lifetime this < test {
      // var tempTest = new Test();
      // param test_name = test: string;
      // if !canResolve(test_name,tempTest) then
      //   compilerError(test + " is not callable");
      this._tests.push_back(test);
      this.testCount += 1;
    }

    proc addTests(tests) lifetime this < tests {
      /*if isString(tests) then
        compilerError("tests must be an iterable, not a string");*/
      for test in tests do
        this.addTest(test);
    }

    proc this(i: int) ref: argType {
      return this._tests[i];
    }

    iter these() {
      for i in this._tests do
        yield i;
    }
  }

  /*Runs the tests
  
    :arg tests: Multiple `","` seperated First Class Test Functions.

    Call this as 
    
    .. code-block:: chapel

      UnitTest.runTest(test1, test2);
  */
  proc runTest(tests: argType ...?n) throws {

    var testNamesMap: domain(string),
        failedTestsMap: domain(string),
        erroredTestMap: domain(string),
        testsLocalMap: domain(string),
        testsPassedMap: domain(string);
    var testStatus: [testNamesMap] bool,
        testsFailed: [failedTestsMap] bool,
        testsErrored: [erroredTestMap] bool,
        testsLocalFails: [testsLocalMap] bool,
        testsPassed: [testsPassedMap] bool;
    // Assuming 1 global test suite for now
    // Per-module or per-class is possible too
    var testSuite = new TestSuite();
    testSuite.addTests(tests);
    
    for test in testSuite {
      testStatus[test: string] = false;
      testsLocalFails[test: string] = false;
      testsFailed[test: string] = false; // no tests failed
      testsErrored[test: string] = false;
    }
    if testNames != "None" {
      for test in testNames.split(" ") {
        testsLocalFails[test.strip()] = true;
      }
    }
    if failedTestNames != "None" {
      for test in failedTestNames.split(" ") {
        testsFailed[test.strip()] = true; // these tests failed or skipped
        testStatus[test.strip()] = true;
      }
    }
    if errorTestNames != "None" {
      for test in errorTestNames.split(" ") {
        testsErrored[test.strip()] = true; // these tests failed or skipped
        testStatus[test.strip()] = true;
      }
    }
    if ranTests != "None" {
      for test in ranTests.split(" ") {
        testsPassed[test.strip()] = true; // these tests failed or skipped
        testStatus[test.strip()] = true;
      }
    }

    for test in testSuite {
      if !testStatus[test: string] {
        // Create a test object per test
        var checkCircle: [1..0] string;
        var circleFound = false;
        var testObject = new Test();
        runTestMethod(testStatus, testObject, testsFailed, testsErrored, testsLocalFails,
                      test, checkCircle, circleFound);
      }
    }
  }

  private
  proc runTestMethod(ref testStatus, ref testObject, ref testsFailed, ref testsErrored,
                  ref testsLocalFails, test, ref checkCircle, ref circleFound) throws 
  {
    var testResult = new TextTestResult();
    var testName = test: string; //test is a FCF:
    checkCircle.push_back(testName);
    try {
      testResult.startTest(testName);
      test(testObject);
      testResult.addSuccess(testName);
      testsLocalFails[testName] = false;
    }
    // A variety of catch statements will handle errors thrown
    catch e: AssertionError {
      testResult.addFailure(testName, e: string);
      // print info of the assertion error
    }
    catch e: DependencyFound {
      var allTestsRan = true;
      for superTest in testObject.testDependsOn {
        var checkCircleStatus = checkCircle.find(superTest: string);
        // cycle is checked
        if checkCircleStatus[1]{
          testsErrored[testName] = true;
          circleFound = true;
          var failReason = testName + " skipped as circular dependency found";
          testResult.addSkip(testName, failReason);
          return;
        }
        // if super test didn't Error or Failed
        if !testsErrored[superTest: string] && !testsFailed[superTest: string] {
          // checking if super test ran or not.
          if !testStatus[superTest: string] {
            // Create a test object per test
            var superTestObject = new Test();
            // running the super test
            runTestMethod(testStatus, superTestObject, testsFailed, testsErrored, 
                  testsLocalFails, superTest, checkCircle, circleFound);
            
            // if super test failed or skipped
            if testsFailed[superTest: string] {
              testsFailed[testName] = true; // current test have failed or skipped
              var skipReason = testName + " skipped as " + superTest: string +" failed";
              testResult.addSkip(testName, skipReason);
              break;
            }
            // this superTest has not yet finished.
            if testsLocalFails[superTest: string] {
              allTestsRan = false;
            }
            // if superTest error then
            if testsErrored[superTest: string] {
              testsFailed[testName] = true;
              var skipReason = testName + " skipped as " + superTest: string +" gave an Error";
              testResult.addSkip(testName, skipReason);
              break;
            }

            // if Circle Found running the superTests
            if circleFound then break;
          }
        }
        // super test Errored
        else if testsErrored[superTest: string] {
          testsFailed[testName] = true;
          var skipReason = testName + " skipped as " + superTest: string +" gave an Error";
          testResult.addSkip(testName, skipReason);
          break;
        }
        //super test failed
        else {
          testsFailed[testName] = true; // current test have failed or skipped
          var skipReason = testName + " skipped as " + superTest: string +" failed";
          testResult.addSkip(testName, skipReason);
        }
      }
      if circleFound {
        testsFailed[testName] = true;
        var skipReason = testName + " skipped as circular dependency found";
        testResult.addError(testName, skipReason);
      }
      // Test is not having error or failures or dependency
      else if !testsErrored[testName] && allTestsRan && !testsFailed[testName] {
        testObject.dictDomain.clear(); // clearing so that we don't get Locales already added
        runTestMethod(testStatus, testObject, testsFailed, testsErrored, testsLocalFails, 
                      test, checkCircle, circleFound);
      }
      else if !testsErrored[testName] && !allTestsRan && !testsFailed[testName] {
        testResult.dependencyNotMet(testName);
      }
    }
    catch e: TestSkipped {
      testResult.addSkip(testName, e: string);
      testsFailed[testName] = true ;
      // Print info on test skipped
    }
    catch e: TestIncorrectNumLocales {
      testResult.addIncorrectNumLocales(testName, e: string);
      testsLocalFails[testName] = true;;
    }
    catch e: UnexpectedLocales {
      testResult.addFailure(testName, e: string);
      testsFailed[testName] = true ;
    }
    catch e { 
      testResult.addError(testName, e:string);
      testsErrored[testName] = true ;
    }
    testStatus[testName] = true;
  }
}
