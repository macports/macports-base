
[//000000001]: # (math \- Tcl Math Library)
[//000000002]: # (Generated from file 'math\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (math\(n\) 1\.2\.5 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math \- Tcl Math Library

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [BASIC COMMANDS](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require math ?1\.2\.5?  

[__::math::cov__ *value* *value* ?*value \.\.\.*?](#1)  
[__::math::integrate__ *list of xy value pairs*](#2)  
[__::math::fibonacci__ *n*](#3)  
[__::math::max__ *value* ?*value \.\.\.*?](#4)  
[__::math::mean__ *value* ?*value \.\.\.*?](#5)  
[__::math::min__ *value* ?*value \.\.\.*?](#6)  
[__::math::product__ *value* ?*value \.\.\.*?](#7)  
[__::math::random__ ?*value1*? ?*value2*?](#8)  
[__::math::sigma__ *value* *value* ?*value \.\.\.*?](#9)  
[__::math::stats__ *value* *value* ?*value \.\.\.*?](#10)  
[__::math::sum__ *value* ?*value \.\.\.*?](#11)  

# <a name='description'></a>DESCRIPTION

The __math__ package provides utility math functions\.

Besides a set of basic commands, available via the package *math*, there are
more specialised packages:

  - __[math::bigfloat](bigfloat\.md)__ \- Arbitrary\-precision
    floating\-point arithmetic

  - __[math::bignum](bignum\.md)__ \- Arbitrary\-precision integer
    arithmetic

  - __[math::calculus::romberg](romberg\.md)__ \- Robust integration
    methods for functions of one variable, using Romberg integration

  - __[math::calculus](calculus\.md)__ \- Integration of functions,
    solving ordinary differential equations

  - __[math::combinatorics](combinatorics\.md)__ \- Procedures for various
    combinatorial functions \(for instance the Gamma function and "k out of n"\)

  - __[math::complexnumbers](qcomplex\.md)__ \- Complex number arithmetic

  - __[math::constants](constants\.md)__ \- A set of well\-known
    mathematical constants, such as Pi, E, and the golden ratio

  - __[math::fourier](fourier\.md)__ \- Discrete Fourier transforms

  - __[math::fuzzy](fuzzy\.md)__ \- Fuzzy comparisons of floating\-point
    numbers

  - __[math::geometry](math\_geometry\.md)__ \- 2D geometrical computations

  - __[math::interpolate](interpolate\.md)__ \- Various interpolation
    methods

  - __[math::linearalgebra](linalg\.md)__ \- Linear algebra package

  - __[math::optimize](optimize\.md)__ \- Optimization methods

  - __[math::polynomials](polynomials\.md)__ \- Polynomial arithmetic
    \(includes families of classical polynomials\)

  - __[math::rationalfunctions](rational\_funcs\.md)__ \- Arithmetic of
    rational functions

  - __[math::roman](roman\.md)__ \- Manipulation \(including arithmetic\) of
    Roman numerals

  - __[math::special](special\.md)__ \- Approximations of special
    functions from mathematical physics

  - __[math::statistics](statistics\.md)__ \- Statistical operations and
    tests

# <a name='section2'></a>BASIC COMMANDS

  - <a name='1'></a>__::math::cov__ *value* *value* ?*value \.\.\.*?

    Return the coefficient of variation expressed as percent of two or more
    numeric values\.

  - <a name='2'></a>__::math::integrate__ *list of xy value pairs*

    Return the area under a "curve" defined by a set of x,y pairs and the error
    bound as a list\.

  - <a name='3'></a>__::math::fibonacci__ *n*

    Return the *n*'th Fibonacci number\.

  - <a name='4'></a>__::math::max__ *value* ?*value \.\.\.*?

    Return the maximum of one or more numeric values\.

  - <a name='5'></a>__::math::mean__ *value* ?*value \.\.\.*?

    Return the mean, or "average" of one or more numeric values\.

  - <a name='6'></a>__::math::min__ *value* ?*value \.\.\.*?

    Return the minimum of one or more numeric values\.

  - <a name='7'></a>__::math::product__ *value* ?*value \.\.\.*?

    Return the product of one or more numeric values\.

  - <a name='8'></a>__::math::random__ ?*value1*? ?*value2*?

    Return a random number\. If no arguments are given, the number is a floating
    point value between 0 and 1\. If one argument is given, the number is an
    integer value between 0 and *value1*\. If two arguments are given, the
    number is an integer value between *value1* and *value2*\.

  - <a name='9'></a>__::math::sigma__ *value* *value* ?*value \.\.\.*?

    Return the population standard deviation of two or more numeric values\.

  - <a name='10'></a>__::math::stats__ *value* *value* ?*value \.\.\.*?

    Return the mean, standard deviation, and coefficient of variation \(as
    percent\) as a list\.

  - <a name='11'></a>__::math::sum__ *value* ?*value \.\.\.*?

    Return the sum of one or more numeric values\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[math](\.\./\.\./\.\./\.\./index\.md\#math),
[statistics](\.\./\.\./\.\./\.\./index\.md\#statistics)

# <a name='category'></a>CATEGORY

Mathematics
