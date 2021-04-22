
[//000000001]: # (generator \- Tcl Generator Commands)
[//000000002]: # (Generated from file 'generator\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (generator\(n\) 0\.2 tcllib "Tcl Generator Commands")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

generator \- Procedures for creating and using generators\.

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [PRELUDE](#section3)

  - [BUGS, IDEAS, FEEDBACK](#section4)

  - [Keywords](#keywords)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require generator ?0\.2?  

[__generator__ __define__ *name* *params* *body*](#1)  
[__generator__ __yield__ *arg* ?*args\.\.*?](#2)  
[__generator__ __foreach__ *varList* *generator* *varList* *generator* ?\.\.\.? *body*](#3)  
[__generator__ __next__ *generator* ?*varName\.\.*?](#4)  
[__generator__ __exists__ *generator*](#5)  
[__generator__ __names__](#6)  
[__generator__ __destroy__ ?*generator\.\.*?](#7)  
[__generator__ __finally__ *cmd* ?*arg\.\.*?](#8)  
[__generator__ __from__ *format* *value*](#9)  
[__generator__ __to__ *format* *generator*](#10)  
[__generator__ __map__ *function* *generator*](#11)  
[__generator__ __filter__ *predicate* *generator*](#12)  
[__generator__ __reduce__ *function* *zero* *generator*](#13)  
[__generator__ __foldl__ *function* *zero* *generator*](#14)  
[__generator__ __foldr__ *function* *zero* *generator*](#15)  
[__generator__ __all__ *predicate* *generator*](#16)  
[__generator__ __and__ *generator*](#17)  
[__generator__ __any__ *generator*](#18)  
[__generator__ __concat__ *generator* ?*generator\.\.*?](#19)  
[__generator__ __concatMap__ *function* *generator*](#20)  
[__generator__ __drop__ *n* *generator*](#21)  
[__generator__ __dropWhile__ *predicate* *generator*](#22)  
[__generator__ __contains__ *element* *generator*](#23)  
[__generator__ __foldl1__ *function* *generator*](#24)  
[__generator__ __foldli__ *function* *zero* *generator*](#25)  
[__generator__ __foldri__ *function* *zero* *generator*](#26)  
[__generator__ __head__ *generator*](#27)  
[__generator__ __tail__ *generator*](#28)  
[__generator__ __init__ *generator*](#29)  
[__generator__ __takeList__ *n* *generator*](#30)  
[__generator__ __take__ *n* *generator*](#31)  
[__generator__ __iterate__ *function* *init*](#32)  
[__generator__ __last__ *generator*](#33)  
[__generator__ __length__ *generator*](#34)  
[__generator__ __or__ *predicate* *generator*](#35)  
[__generator__ __product__ *generator*](#36)  
[__generator__ __repeat__ *n* *value\.\.*](#37)  
[__generator__ __sum__ *generator*](#38)  
[__generator__ __takeWhile__ *predicate* *generator*](#39)  
[__generator__ __splitWhen__ *predicate* *generator*](#40)  
[__generator__ __scanl__ *function* *zero* *generator*](#41)  

# <a name='description'></a>DESCRIPTION

The __generator__ package provides commands to define and iterate over
generator expressions\. A *generator* is a command that returns a sequence of
values\. However, unlike an ordinary command that returns a list, a generator
*yields* each value and then suspends, allowing subsequent values to be
fetched on\-demand\. As such, generators can be used to efficiently iterate over a
set of values, without having to generate all answers in\-memory\. Generators can
be used to iterate over elements of a data structure, or rows in the result set
of a database query, or to decouple producer/consumer software designs such as
parsers and tokenizers, or to implement sophisticated custom control strategies
such as backtracking search\. Generators reduce the need to implement custom
control structures, as many such structures can be recast as generators, leading
to both a simpler implementation and a more standardised interface\. The
generator mechanism is built on top of the Tcl 8\.6 coroutine mechanism\.

The package exports a single ensemble command, __generator__\. All
functionality is provided as subcommands of this command\. The core subcommands
of the package are __define__, __yield__, and __foreach__\. The
__define__ command works like Tcl's
__[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ command, but creates a generator
procedure; that is, a procedure that returns a generator when called\. The
generator itself is a command that can be called multiple times: each time it
returns the next value in the generated series\. When the series has been
exhausted, the generator command returns an empty list and then destroys itself\.
Rather than manually call a generator, however, the package also provides a
flexible __foreach__ command that loops through the values of one or more
generators\. This loop construct mimicks the functionality of the built\-in Tcl
__[foreach](\.\./\.\./\.\./\.\./index\.md\#foreach)__ command, including handling
multiple return values and looping over multiple generators at once\. Writing a
generator is also a simple task, much like writing a normal procedure: simply
use the __define__ command to define the generator, and then call
__yield__ instead of __[return](\.\./\.\./\.\./\.\./index\.md\#return)__\. For
example, we can define a generator for looping through the integers in a
particular range:

    generator define range {n m} {
        for {set i $n} {$i <= $m} {incr i} { generator yield $i }
    }
    generator foreach x [range 1 10] {
        puts "x = $x"
    }

The above example will print the numbers from 1 to 10 in sequence, as you would
expect\. The difference from a normal loop over a list is that the numbers are
only generated as they are needed\. If we insert a break into the loop then any
remaining numbers in the sequence would never be generated\. To illustrate, we
can define a generator that produces the sequence of natural numbers: an
infinite series\. A normal procedure would never return trying to produce this
series as a list\. By using a generator we only have to generate those values
which are actually used:

    generator define nats {} {
        while 1 { generator yield [incr nat] }
    }
    generator foreach n [nats] {
        if {$n > 100} { break }
    }

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__generator__ __define__ *name* *params* *body*

    Creates a new generator procedure\. The arguments to the command are
    identical to those for __[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__: a
    *name*, a list of parameters, and a body\. The parameter list format is
    identical to a procedure\. In particular, default values and the ?args?
    syntax can be used as usual\. Each time the resulting generator procedure is
    called it creates a new generator command \(coroutine\) that will yield a list
    of values on each call\. Each result from a generator is guaranteed to be a
    non\-empty list of values\. When a generator is exhausted it returns an empty
    list and then destroys itself to free up resources\. It is an error to
    attempt to call an exhausted generator as the command no longer exists\.

  - <a name='2'></a>__generator__ __yield__ *arg* ?*args\.\.*?

    Used in the definition of a generator, this command returns the next set of
    values to the consumer\. Once the __yield__ command has been called the
    generator will suspend to allow the consumer to process that value\. When the
    next value is requested, the generator will resume as if the yield command
    had just returned, and can continue processing to yield the next result\. The
    __yield__ command must be called with at least one argument, but can be
    called with multiple arguments, in which case this is equivalent to calling
    __yield__ once for each argument\.

  - <a name='3'></a>__generator__ __foreach__ *varList* *generator* *varList* *generator* ?\.\.\.? *body*

    Loops through one or more generators, assigning the next values to variables
    and then executing the loop body\. Works much like the built\-in
    __[foreach](\.\./\.\./\.\./\.\./index\.md\#foreach)__ command, but working
    with generators rather than lists\. Multiple generators can be iterated over
    in parallel, and multiple results can be retrieved from a single generator
    at once\. Like the built\-in
    __[foreach](\.\./\.\./\.\./\.\./index\.md\#foreach)__, the loop will continue
    until all of the generators have been exhausted: variables for generators
    that are exhausted early will be set to the empty string\.

    The __foreach__ command will automatically clean\-up all of the
    generators at the end of the loop, regardless of whether the loop terminated
    early or not\. This behaviour is provided as a convenience to avoid having to
    explicitly clean up a generator in the usual cases\. Generators can however
    be destroyed before the end of the loop, in which case the loop will
    continue as normal until all the other generators have been destroyed or
    exhausted\.

    The __foreach__ command does not take a snapshot of the generator\. Any
    changes in the state of the generator made inside the loop or by other code
    will affect the state of the loop\. In particular, if the code in the loop
    invokes the generator to manually retrieve the next element, this element
    will then be excluded from the loop, and the next iteration will continue
    from the element after that one\. Care should be taken to avoid concurrent
    updates to generators unless this behaviour is required \(e\.g\., in argument
    processing\)\.

  - <a name='4'></a>__generator__ __next__ *generator* ?*varName\.\.*?

    Manually retrieves the next values from a generator\. One value is retrieved
    for each variable supplied and assigned to the corresponding variable\. If
    the generator becomes exhausted at any time then any remaining variables are
    set to the empty string\.

  - <a name='5'></a>__generator__ __exists__ *generator*

    Returns 1 if the generator \(still\) exists, or 0 otherwise\.

  - <a name='6'></a>__generator__ __names__

    Returns a list of all currently existing generator commands\.

  - <a name='7'></a>__generator__ __destroy__ ?*generator\.\.*?

    Destroys one or more generators, freeing any associated resources\.

  - <a name='8'></a>__generator__ __finally__ *cmd* ?*arg\.\.*?

    Used in the definition of a generator procedure, this command arranges for a
    resource to be cleaned up whenever the generator is destroyed, either
    explicitly or implicitly when the generator is exhausted\. This command can
    be used like a __finally__ block in the
    __[try](\.\./try/tcllib\_try\.md)__ command, except that it is tied to
    the life\-cycle of the generator rather than to a particular scope\. For
    example, if we create a generator to iterate over the lines in a text file,
    we can use __finally__ to ensure that the file is closed whenever the
    generator is destroyed:

    generator define lines file {
        set in [open $file]
        # Ensure file is always closed
        generator finally close $in
        while {[gets $in line] >= 0} {
            generator yield $line
        }
    }
    generator foreach line [lines /etc/passwd] {
        puts "[incr count]: $line"
        if {$count > 10} { break }
    }
    # File will be closed even on early exit

    If you create a generator that consumes another generator \(such as the
    standard __map__ and __filter__ generators defined later\), then you
    should use a __finally__ command to ensure that this generator is
    destroyed when its parent is\. For example, the __map__ generator is
    defined as follows:

    generator define map {f xs} {
        generator finally generator destroy $xs
        generator foreach x $xs { generator yield [{*}$f $x] }
    }

  - <a name='9'></a>__generator__ __from__ *format* *value*

    Creates a generator from a data structure\. Currently, supported formats are
    __list__, __dict__, or __string__\. The list format yields each
    element in turn\. For dictionaries, each key and value are yielded
    separately\. Finally, strings are yielded a character at a time\.

  - <a name='10'></a>__generator__ __to__ *format* *generator*

    Converts a generator into a data structure\. This is the reverse operation of
    the __from__ command, and supports the same data structures\. The two
    operations obey the following identity laws \(where __=__ is interpreted
    appropriately\):

    [generator to $fmt [generator from $fmt $value]] = $value
    [generator from $fmt [generator to $fmt $gen]]   = $gen

# <a name='section3'></a>PRELUDE

The following commands are provided as a standard library of generator
combinators and functions that perform convenience operations on generators\. The
functions in this section are loosely modelled on the equivalent functions from
the Haskell Prelude\. *Warning:* most of the functions in this prelude destroy
any generator arguments they are passed as a side\-effect\. If you want to have
persistent generators, see the streams library\.

  - <a name='11'></a>__generator__ __map__ *function* *generator*

    Apply a function to every element of a generator, returning a new generator
    of the results\. This is the classic map function from functional
    programming, applied to generators\. For example, we can generate all the
    square numbers using the following code \(where __nats__ is defined as
    earlier\):

    proc square x { expr {$x * $x} }
    generator foreach n [generator map square [nats]] {
        puts "n = $n"
        if {$n > 1000} { break }
    }

  - <a name='12'></a>__generator__ __filter__ *predicate* *generator*

    Another classic functional programming gem\. This command returns a generator
    that yields only those items from the argument generator that satisfy the
    predicate \(boolean function\)\. For example, if we had a generator
    __employees__ that returned a stream of dictionaries representing
    people, we could filter all those whose salaries are above 100,000 dollars
    \(or whichever currency you prefer\) using a simple filter:

    proc salary> {amount person} { expr {[dict get $person salary] > $amount} }
    set fat-cats [generator filter {salary> 100000} $employees]

  - <a name='13'></a>__generator__ __reduce__ *function* *zero* *generator*

    This is the classic left\-fold operation\. This command takes a function, an
    initial value, and a generator of values\. For each element in the generator
    it applies the function to the current accumulator value \(the *zero*
    argument initially\) and that element, and then uses the result as the new
    accumulator value\. This process is repeated through the entire generator
    \(eagerly\) and the final accumulator value is then returned\. If we consider
    the function to be a binary operator, and the zero argument to be the left
    identity element of that operation, then we can consider the __reduce__
    command as *folding* the operator between each successive pair of values
    in the generator in a left\-associative fashion\. For example, the sum of a
    sequence of numbers can be calculated by folding a __\+__ operator
    between them, with 0 as the identity:

    # sum xs          = reduce + 0 xs
    # sum [range 1 5] = reduce + 0 [range 1 5]
    #                 = reduce + [+ 0 1] [range 2 5]
    #                 = reduce + [+ 1 2] [range 3 5]
    #                 = ...
    #                 = reduce + [+ 10 5] <empty>
    #                 = ((((0+1)+2)+3)+4)+5
    #                 = 15
    proc + {a b} { expr {$a + $b} }
    proc sum gen { generator reduce + 0 $gen }
    puts [sum [range 1 10]]

    The __reduce__ operation is an extremely useful one, and a great variety
    of different operations can be defined using it\. For example, we can define
    a factorial function as the product of a range using generators\. This
    definition is both very clear and also quite efficient \(in both memory and
    running time\):

    proc * {x y} { expr {$x * $y} }
    proc prod gen { generator reduce * 0 $gen }
    proc fac n { prod [range 1 $n] }

    However, while the __reduce__ operation is efficient for finite
    generators, care should be taken not to apply it to an infinite generator,
    as this will result in an infinite loop:

    sum [nats]; # Never returns

  - <a name='14'></a>__generator__ __foldl__ *function* *zero* *generator*

    This is an alias for the __reduce__ command\.

  - <a name='15'></a>__generator__ __foldr__ *function* *zero* *generator*

    This is the right\-associative version of __reduce__\. This operation is
    generally inefficient, as the entire generator needs to be evaluated into
    memory \(as a list\) before the reduction can commence\. In an eagerly
    evaluated language like Tcl, this operation has limited use, and should be
    avoided if possible\.

  - <a name='16'></a>__generator__ __all__ *predicate* *generator*

    Returns true if all elements of the generator satisfy the given predicate\.

  - <a name='17'></a>__generator__ __and__ *generator*

    Returns true if all elements of the generator are true \(i\.e\., takes the
    logical conjunction of the elements\)\.

  - <a name='18'></a>__generator__ __any__ *generator*

    Returns true if any of the elements of the generator are true \(i\.e\., logical
    disjunction\)\.

  - <a name='19'></a>__generator__ __concat__ *generator* ?*generator\.\.*?

    Returns a generator which is the concatenation of each of the argument
    generators\.

  - <a name='20'></a>__generator__ __concatMap__ *function* *generator*

    Given a function which maps a value to a series of values, and a generator
    of values of that type, returns a generator of all of the results in one
    flat series\. Equivalent to __concat__ applied to the result of
    __map__\.

  - <a name='21'></a>__generator__ __drop__ *n* *generator*

    Removes the given number of elements from the front of the generator and
    returns the resulting generator with those elements removed\.

  - <a name='22'></a>__generator__ __dropWhile__ *predicate* *generator*

    Removes all elements from the front of the generator that satisfy the
    predicate\.

  - <a name='23'></a>__generator__ __contains__ *element* *generator*

    Returns true if the generator contains the given element\. Note that this
    will destroy the generator\!

  - <a name='24'></a>__generator__ __foldl1__ *function* *generator*

    A version of __foldl__ that takes the *zero* argument from the first
    element of the generator\. Therefore this function is only valid on non\-empty
    generators\.

  - <a name='25'></a>__generator__ __foldli__ *function* *zero* *generator*

    A version of __foldl__ that supplies the integer index of each element
    as the first argument to the function\. The first element in the generator at
    this point is given index 0\.

  - <a name='26'></a>__generator__ __foldri__ *function* *zero* *generator*

    Right\-associative version of __foldli__\.

  - <a name='27'></a>__generator__ __head__ *generator*

    Returns the first element of the generator\.

  - <a name='28'></a>__generator__ __tail__ *generator*

    Removes the first element of the generator, returning the rest\.

  - <a name='29'></a>__generator__ __init__ *generator*

    Returns a new generator consisting of all elements except the last of the
    argument generator\.

  - <a name='30'></a>__generator__ __takeList__ *n* *generator*

    Returns the next *n* elements of the generator as a list\. If not enough
    elements are left in the generator, then just the remaining elements are
    returned\.

  - <a name='31'></a>__generator__ __take__ *n* *generator*

    Returns the next *n* elements of the generator as a new generator\. The old
    generator is destroyed\.

  - <a name='32'></a>__generator__ __iterate__ *function* *init*

    Returns an infinite generator formed by repeatedly applying the function to
    the initial argument\. For example, the Fibonacci numbers can be defined as
    follows:

    proc fst pair { lindex $pair 0 }
    proc snd pair { lindex $pair 1 }
    proc nextFib ab { list [snd $ab] [expr {[fst $ab] + [snd $ab]}] }
    proc fibs {} { generator map fst [generator iterate nextFib {0 1}] }

  - <a name='33'></a>__generator__ __last__ *generator*

    Returns the last element of the generator \(if it exists\)\.

  - <a name='34'></a>__generator__ __length__ *generator*

    Returns the length of the generator, destroying it in the process\.

  - <a name='35'></a>__generator__ __or__ *predicate* *generator*

    Returns 1 if any of the elements of the generator satisfy the predicate\.

  - <a name='36'></a>__generator__ __product__ *generator*

    Returns the product of the numbers in a generator\.

  - <a name='37'></a>__generator__ __repeat__ *n* *value\.\.*

    Returns a generator that consists of *n* copies of the given elements\. The
    special value *Inf* can be used to generate an infinite sequence\.

  - <a name='38'></a>__generator__ __sum__ *generator*

    Returns the sum of the values in the generator\.

  - <a name='39'></a>__generator__ __takeWhile__ *predicate* *generator*

    Returns a generator of the first elements in the argument generator that
    satisfy the predicate\.

  - <a name='40'></a>__generator__ __splitWhen__ *predicate* *generator*

    Splits the generator into lists of elements using the predicate to identify
    delimiters\. The resulting lists are returned as a generator\. Elements
    matching the delimiter predicate are discarded\. For example, to split up a
    generator using the string "&#124;" as a delimiter:

    set xs [generator from list {a | b | c}]
    generator split {string equal "|"} $xs ;# returns a then b then c

  - <a name='41'></a>__generator__ __scanl__ *function* *zero* *generator*

    Similar to __foldl__, but returns a generator of all of the intermediate
    values for the accumulator argument\. The final element of this generator is
    equivalent to __foldl__ called on the same arguments\.

# <a name='section4'></a>BUGS, IDEAS, FEEDBACK

Please report any errors in this document, or in the package it describes, to
[Neil Madden](mailto:nem@cs\.nott\.ac\.uk)\.

# <a name='keywords'></a>KEYWORDS

[control structure](\.\./\.\./\.\./\.\./index\.md\#control\_structure),
[coroutine](\.\./\.\./\.\./\.\./index\.md\#coroutine),
[filter](\.\./\.\./\.\./\.\./index\.md\#filter),
[foldl](\.\./\.\./\.\./\.\./index\.md\#foldl),
[foldr](\.\./\.\./\.\./\.\./index\.md\#foldr),
[foreach](\.\./\.\./\.\./\.\./index\.md\#foreach),
[generator](\.\./\.\./\.\./\.\./index\.md\#generator),
[iterator](\.\./\.\./\.\./\.\./index\.md\#iterator),
[map](\.\./\.\./\.\./\.\./index\.md\#map), [reduce](\.\./\.\./\.\./\.\./index\.md\#reduce),
[scanl](\.\./\.\./\.\./\.\./index\.md\#scanl)
