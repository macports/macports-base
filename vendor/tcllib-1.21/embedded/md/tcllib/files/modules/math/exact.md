
[//000000001]: # (math::exact \- Tcl Math Library)
[//000000002]: # (Generated from file 'exact\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2015 Kevin B\. Kenny <kennykb@acm\.org>)
[//000000004]: # (Redistribution permitted under the terms of the Open Publication License <http://www\.opencontent\.org/openpub/>)
[//000000005]: # (math::exact\(n\) 1\.0\.1 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::exact \- Exact Real Arithmetic

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Procedures](#section2)

  - [Parameters](#section3)

  - [Expressions](#section4)

  - [Functions](#section5)

  - [Summary](#section6)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require grammar::aycock 1\.0  
package require math::exact 1\.0\.1  

[__::math::exact::exactexpr__ *expr*](#1)  
[*number* __ref__](#2)  
[*number* __unref__](#3)  
[*number* __asPrint__ *precision*](#4)  
[*number* __asFloat__ *precision*](#5)  

# <a name='description'></a>DESCRIPTION

The __exactexpr__ command in the __math::exact__ package allows for
exact computations over the computable real numbers\. These are not
arbitrary\-precision calculations; rather they are exact, with numbers
represented by algorithms that produce successive approximations\. At the end of
a calculation, the caller can request a given precision for the end result, and
intermediate results are computed to whatever precision is necessary to satisfy
the request\.

# <a name='section2'></a>Procedures

The following procedure is the primary entry into the __math::exact__
package\.

  - <a name='1'></a>__::math::exact::exactexpr__ *expr*

    Accepts a mathematical expression in Tcl syntax, and returns an object that
    represents the program to calculate successive approximations to the
    expression's value\. The result will be referred to as an exact real number\.

  - <a name='2'></a>*number* __ref__

    Increases the reference count of a given exact real number\.

  - <a name='3'></a>*number* __unref__

    Decreases the reference count of a given exact real number, and destroys the
    number if the reference count is zero\.

  - <a name='4'></a>*number* __asPrint__ *precision*

    Formats the given *number* for printing, with the specified *precision*\.
    \(See below for how *precision* is interpreted\)\. Numbers that are known to
    be rational are formatted as fractions\.

  - <a name='5'></a>*number* __asFloat__ *precision*

    Formats the given *number* for printing, with the specified *precision*\.
    \(See below for how *precision* is interpreted\)\. All numbers are formatted
    in floating\-point E format\.

# <a name='section3'></a>Parameters

  - *expr*

    Expression to evaluate\. The syntax for expressions is the same as it is in
    Tcl, but the set of operations is smaller\. See [Expressions](#section4)
    below for details\.

  - *number*

    The object returned by an earlier invocation of
    __math::exact::exactexpr__

  - *precision*

    The requested 'precision' of the result\. The precision is \(approximately\)
    the absolute value of the binary exponent plus the number of bits of the
    binary significand\. For instance, to return results to IEEE\-754 double
    precision, 56 bits plus the exponent are required\. Numbers between 1/2 and 2
    will require a precision of 57; numbers between 1/4 and 1/2 or between 2 and
    4 will require 58; numbers between 1/8 and 1/4 or between 4 and 8 will
    require 59; and so on\.

# <a name='section4'></a>Expressions

The __math::exact::exactexpr__ command accepts expressions in a subset of
Tcl's syntax\. The following components may be used in an expression\.

  - Decimal integers\.

  - Variable references with the dollar sign \(__$__\)\. The value of the
    variable must be the result of another call to
    __math::exact::exactexpr__\. The reference count of the value will be
    increased by one for each position at which it appears in the expression\.

  - The exponentiation operator \(__\*\*__\)\.

  - Unary plus \(__\+__\) and minus \(__\-__\) operators\.

  - Multiplication \(__\*__\) and division \(__/__\) operators\.

  - Parentheses used for grouping\.

  - Functions\. See [Functions](#section5) below for the functions that are
    available\.

# <a name='section5'></a>Functions

The following functions are available for use within exact real expressions\.

  - __acos\(__*x*__\)__

    The inverse cosine of *x*\. The result is expressed in radians\. The
    absolute value of *x* must be less than 1\.

  - __acosh\(__*x*__\)__

    The inverse hyperbolic cosine of *x*\. *x* must be greater than 1\.

  - __asin\(__*x*__\)__

    The inverse sine of *x*\. The result is expressed in radians\. The absolute
    value of *x* must be less than 1\.

  - __asinh\(__*x*__\)__

    The inverse hyperbolic sine of *x*\.

  - __atan\(__*x*__\)__

    The inverse tangent of *x*\. The result is expressed in radians\.

  - __atanh\(__*x*__\)__

    The inverse hyperbolic tangent of *x*\. The absolute value of *x* must be
    less than 1\.

  - __cos\(__*x*__\)__

    The cosine of *x*\. *x* is expressed in radians\.

  - __cosh\(__*x*__\)__

    The hyperbolic cosine of *x*\.

  - __e\(\)__

    The base of the natural logarithms = __2\.71828\.\.\.__

  - __exp\(__*x*__\)__

    The exponential function of *x*\.

  - __log\(__*x*__\)__

    The natural logarithm of *x*\. *x* must be positive\.

  - __pi\(\)__

    The value of pi = __3\.15159\.\.\.__

  - __sin\(__*x*__\)__

    The sine of *x*\. *x* is expressed in radians\.

  - __sinh\(__*x*__\)__

    The hyperbolic sine of *x*\.

  - __sqrt\(__*x*__\)__

    The square root of *x*\. *x* must be positive\.

  - __tan\(__*x*__\)__

    The tangent of *x*\. *x* is expressed in radians\.

  - __tanh\(__*x*__\)__

    The hyperbolic tangent of *x*\.

# <a name='section6'></a>Summary

The __math::exact::exactexpr__ command provides a system that performs exact
arithmetic over computable real numbers, representing the numbers as algorithms
for successive approximation\. An example, which implements the high\-school
quadratic formula, is shown below\.

    namespace import math::exact::exactexpr
    proc exactquad {a b c} {
        set d [[exactexpr {sqrt($b*$b - 4*$a*$c)}] ref]
        set r0 [[exactexpr {(-$b - $d) / (2 * $a)}] ref]
        set r1 [[exactexpr {(-$b + $d) / (2 * $a)}] ref]
        $d unref
        return [list $r0 $r1]
    }

    set a [[exactexpr 1] ref]
    set b [[exactexpr 200] ref]
    set c [[exactexpr {(-3/2) * 10**-12}] ref]
    lassign [exactquad $a $b $c] r0 r1
    $a unref; $b unref; $c unref
    puts [list [$r0 asFloat 70] [$r1 asFloat 110]]
    $r0 unref; $r1 unref

The program prints the result:

    -2.000000000000000075e2 7.499999999999999719e-15

Note that if IEEE\-754 floating point had been used, a catastrophic roundoff
error would yield a smaller root that is a factor of two too high:

    -200.0 1.4210854715202004e-14

The invocations of __exactexpr__ should be fairly self\-explanatory\. The
other commands of note are __ref__ and __unref__\. It is necessary for
the caller to keep track of references to exact expressions \- to call
__ref__ every time an exact expression is stored in a variable and
__unref__ every time the variable goes out of scope or is overwritten\. The
__asFloat__ method emits decimal digits as long as the requested precision
supports them\. It terminates when the requested precision yields an uncertainty
of more than one unit in the least significant digit\.

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2015 Kevin B\. Kenny <kennykb@acm\.org>
Redistribution permitted under the terms of the Open Publication License <http://www\.opencontent\.org/openpub/>
