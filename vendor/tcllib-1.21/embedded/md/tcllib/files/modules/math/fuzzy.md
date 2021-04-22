
[//000000001]: # (math::fuzzy \- Tcl Math Library)
[//000000002]: # (Generated from file 'fuzzy\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (math::fuzzy\(n\) 0\.2 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::fuzzy \- Fuzzy comparison of floating\-point numbers

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PROCEDURES](#section2)

  - [TEST CASES](#section3)

  - [REFERENCES](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl ?8\.3?  
package require math::fuzzy ?0\.2?  

[__::math::fuzzy::teq__ *value1* *value2*](#1)  
[__::math::fuzzy::tne__ *value1* *value2*](#2)  
[__::math::fuzzy::tge__ *value1* *value2*](#3)  
[__::math::fuzzy::tle__ *value1* *value2*](#4)  
[__::math::fuzzy::tlt__ *value1* *value2*](#5)  
[__::math::fuzzy::tgt__ *value1* *value2*](#6)  
[__::math::fuzzy::tfloor__ *value*](#7)  
[__::math::fuzzy::tceil__ *value*](#8)  
[__::math::fuzzy::tround__ *value*](#9)  
[__::math::fuzzy::troundn__ *value* *ndigits*](#10)  

# <a name='description'></a>DESCRIPTION

The package Fuzzy is meant to solve common problems with floating\-point numbers
in a systematic way:

  - Comparing two numbers that are "supposed" to be identical, like 1\.0 and
    2\.1/\(1\.2\+0\.9\) is not guaranteed to give the intuitive result\.

  - Rounding a number that is halfway two integer numbers can cause strange
    errors, like int\(100\.0\*2\.8\) \!= 28 but 27

The Fuzzy package is meant to help sorting out this type of problems by defining
"fuzzy" comparison procedures for floating\-point numbers\. It does so by allowing
for a small margin that is determined automatically \- the margin is three times
the "epsilon" value, that is three times the smallest number *eps* such that
1\.0 and 1\.0\+$eps canbe distinguished\. In Tcl, which uses double precision
floating\-point numbers, this is typically 1\.1e\-16\.

# <a name='section2'></a>PROCEDURES

Effectively the package provides the following procedures:

  - <a name='1'></a>__::math::fuzzy::teq__ *value1* *value2*

    Compares two floating\-point numbers and returns 1 if their values fall
    within a small range\. Otherwise it returns 0\.

  - <a name='2'></a>__::math::fuzzy::tne__ *value1* *value2*

    Returns the negation, that is, if the difference is larger than the margin,
    it returns 1\.

  - <a name='3'></a>__::math::fuzzy::tge__ *value1* *value2*

    Compares two floating\-point numbers and returns 1 if their values either
    fall within a small range or if the first number is larger than the second\.
    Otherwise it returns 0\.

  - <a name='4'></a>__::math::fuzzy::tle__ *value1* *value2*

    Returns 1 if the two numbers are equal according to \[teq\] or if the first is
    smaller than the second\.

  - <a name='5'></a>__::math::fuzzy::tlt__ *value1* *value2*

    Returns the opposite of \[tge\]\.

  - <a name='6'></a>__::math::fuzzy::tgt__ *value1* *value2*

    Returns the opposite of \[tle\]\.

  - <a name='7'></a>__::math::fuzzy::tfloor__ *value*

    Returns the integer number that is lower or equal to the given
    floating\-point number, within a well\-defined tolerance\.

  - <a name='8'></a>__::math::fuzzy::tceil__ *value*

    Returns the integer number that is greater or equal to the given
    floating\-point number, within a well\-defined tolerance\.

  - <a name='9'></a>__::math::fuzzy::tround__ *value*

    Rounds the floating\-point number off\.

  - <a name='10'></a>__::math::fuzzy::troundn__ *value* *ndigits*

    Rounds the floating\-point number off to the specified number of decimals
    \(Pro memorie\)\.

Usage:

    if { [teq $x $y] } { puts "x == y" }
    if { [tne $x $y] } { puts "x != y" }
    if { [tge $x $y] } { puts "x >= y" }
    if { [tgt $x $y] } { puts "x > y" }
    if { [tlt $x $y] } { puts "x < y" }
    if { [tle $x $y] } { puts "x <= y" }

    set fx      [tfloor $x]
    set fc      [tceil  $x]
    set rounded [tround $x]
    set roundn  [troundn $x $nodigits]

# <a name='section3'></a>TEST CASES

The problems that can occur with floating\-point numbers are illustrated by the
test cases in the file "fuzzy\.test":

  - Several test case use the ordinary comparisons, and they fail invariably to
    produce understandable results

  - One test case uses \[expr\] without braces \(\{ and \}\)\. It too fails\.

The conclusion from this is that any expression should be surrounded by braces,
because otherwise very awkward things can happen if you need accuracy\.
Furthermore, accuracy and understandable results are enhanced by using these
"tolerant" or fuzzy comparisons\.

Note that besides the Tcl\-only package, there is also a C\-based version\.

# <a name='section4'></a>REFERENCES

Original implementation in Fortran by dr\. H\.D\. Knoble \(Penn State University\)\.

P\. E\. Hagerty, "More on Fuzzy Floor and Ceiling," APL QUOTE QUAD 8\(4\):20\-24,
June 1978\. Note that TFLOOR=FL5 took five years of refereed evolution
\(publication\)\.

L\. M\. Breed, "Definitions for Fuzzy Floor and Ceiling", APL QUOTE QUAD
8\(3\):16\-23, March 1978\.

D\. Knuth, Art of Computer Programming, Vol\. 1, Problem 1\.2\.4\-5\.

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: fuzzy* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[floating\-point](\.\./\.\./\.\./\.\./index\.md\#floating\_point),
[math](\.\./\.\./\.\./\.\./index\.md\#math),
[rounding](\.\./\.\./\.\./\.\./index\.md\#rounding)

# <a name='category'></a>CATEGORY

Mathematics
