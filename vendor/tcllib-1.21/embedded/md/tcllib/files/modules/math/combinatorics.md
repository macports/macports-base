
[//000000001]: # (math::combinatorics \- Tcl Math Library)
[//000000002]: # (Generated from file 'combinatorics\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (math::combinatorics\(n\) 2\.0 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::combinatorics \- Combinatorial functions in the Tcl Math Library

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require math ?1\.2\.3?  
package require Tcl 8\.6  
package require TclOO  
package require math::combinatorics ?2\.0?  

[__::math::ln\_Gamma__ *z*](#1)  
[__::math::factorial__ *x*](#2)  
[__::math::choose__ *n k*](#3)  
[__::math::Beta__ *z w*](#4)  
[__::math::combinatorics::permutations__ *n*](#5)  
[__::math::combinatorics::variations__ *n* *k*](#6)  
[__::math::combinatorics::combinations__ *n* *k*](#7)  
[__::math::combinatorics::derangements__ *n*](#8)  
[__::math::combinatorics::catalan__ *n*](#9)  
[__::math::combinatorics::firstStirling__ *n* *m*](#10)  
[__::math::combinatorics::secondStirling__ *n* *m*](#11)  
[__::math::combinatorics::partitionP__ *n*](#12)  
[__::math::combinatorics::list\-permutations__ *n*](#13)  
[__::math::combinatorics::list\-variations__ *n* *k*](#14)  
[__::math::combinatorics::list\-combinations__ *n* *k*](#15)  
[__::math::combinatorics::list\-derangements__ *n*](#16)  
[__::math::combinatorics::list\-powerset__ *n*](#17)  
[__::math::combinatorics::permutationObj__ new/create NAME *n*](#18)  
[__$perm__ next](#19)  
[__$perm__ reset](#20)  
[__$perm__ setElements *elements*](#21)  
[__$perm__ setElements](#22)  
[__::math::combinatorics::combinationObj__ new/create NAME *n* *k*](#23)  
[__$combin__ next](#24)  
[__$combin__ reset](#25)  
[__$combin__ setElements *elements*](#26)  
[__$combin__ setElements](#27)  

# <a name='description'></a>DESCRIPTION

The __[math](math\.md)__ package contains implementations of several
functions useful in combinatorial problems\. The __math::combinatorics__
extends the collections based on features in Tcl 8\.6\. Note: the meaning of the
partitionP function, Catalan and Stirling numbers is explained on the
[MathWorld website](http://mathworld\.wolfram\.com)

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::math::ln\_Gamma__ *z*

    Returns the natural logarithm of the Gamma function for the argument *z*\.

    The Gamma function is defined as the improper integral from zero to positive
    infinity of

        t**(x-1)*exp(-t) dt

    The approximation used in the Tcl Math Library is from Lanczos, *ISIAM J\.
    Numerical Analysis, series B,* volume 1, p\. 86\. For "__x__ > 1", the
    absolute error of the result is claimed to be smaller than 5\.5\*10\*\*\-10 \-\-
    that is, the resulting value of Gamma when

        exp( ln_Gamma( x) )

    is computed is expected to be precise to better than nine significant
    figures\.

  - <a name='2'></a>__::math::factorial__ *x*

    Returns the factorial of the argument *x*\.

    For integer *x*, 0 <= *x* <= 12, an exact integer result is returned\.

    For integer *x*, 13 <= *x* <= 21, an exact floating\-point result is
    returned on machines with IEEE floating point\.

    For integer *x*, 22 <= *x* <= 170, the result is exact to 1 ULP\.

    For real *x*, *x* >= 0, the result is approximated by computing
    *Gamma\(x\+1\)* using the __::math::ln\_Gamma__ function, and the result
    is expected to be precise to better than nine significant figures\.

    It is an error to present *x* <= \-1 or *x* > 170, or a value of *x*
    that is not numeric\.

  - <a name='3'></a>__::math::choose__ *n k*

    Returns the binomial coefficient *C\(n, k\)*

        C(n,k) = n! / k! (n-k)!

    If both parameters are integers and the result fits in 32 bits, the result
    is rounded to an integer\.

    Integer results are exact up to at least *n* = 34\. Floating point results
    are precise to better than nine significant figures\.

  - <a name='4'></a>__::math::Beta__ *z w*

    Returns the Beta function of the parameters *z* and *w*\.

        Beta(z,w) = Beta(w,z) = Gamma(z) * Gamma(w) / Gamma(z+w)

    Results are returned as a floating point number precise to better than nine
    significant digits provided that *w* and *z* are both at least 1\.

  - <a name='5'></a>__::math::combinatorics::permutations__ *n*

    Return the number of permutations of n items\. The returned number is always
    an integer, it is not limited by the range of 32\-or 64\-bits integers using
    the arbitrary precision integers available in Tcl 8\.5 and later\.

      * int *n*

        The number of items to be permuted\.

  - <a name='6'></a>__::math::combinatorics::variations__ *n* *k*

    Return the number of variations k items selected from the total of n items\.
    The order of the items is taken into account\.

      * int *n*

        The number of items to be selected from\.

      * int *k*

        The number of items to be selected in each variation\.

  - <a name='7'></a>__::math::combinatorics::combinations__ *n* *k*

    Return the number of combinations of k items selected from the total of n
    items\. The order of the items is not important\.

      * int *n*

        The number of items to be selected from\.

      * int *k*

        The number of items to be selected in each combination\.

  - <a name='8'></a>__::math::combinatorics::derangements__ *n*

    Return the number of derangements of n items\. A derangement is a permutation
    where each item is displaced from the original position\.

      * int *n*

        The number of items to be rearranged\.

  - <a name='9'></a>__::math::combinatorics::catalan__ *n*

    Return the n'th Catalan number\. The number n is expected to be 1 or larger\.
    These numbers occur in various combinatorial problems\.

      * int *n*

        The index of the Catalan number

  - <a name='10'></a>__::math::combinatorics::firstStirling__ *n* *m*

    Calculate a Stirling number of the first kind \(signed version, m cycles in a
    permutation of n items\)

      * int *n*

        Number of items

      * int *m*

        Number of cycles

  - <a name='11'></a>__::math::combinatorics::secondStirling__ *n* *m*

    Calculate a Stirling number of the second kind \(m non\-empty subsets from n
    items\)

      * int *n*

        Number of items

      * int *m*

        Number of subsets

  - <a name='12'></a>__::math::combinatorics::partitionP__ *n*

    Calculate the number of ways an integer n can be written as the sum of
    positive integers\.

      * int *n*

        Number in question

  - <a name='13'></a>__::math::combinatorics::list\-permutations__ *n*

    Return the list of permutations of the numbers 0, \.\.\., n\-1\.

      * int *n*

        The number of items to be permuted\.

  - <a name='14'></a>__::math::combinatorics::list\-variations__ *n* *k*

    Return the list of variations of k numbers selected from the numbers 0, \.\.\.,
    n\-1\. The order of the items is taken into account\.

      * int *n*

        The number of items to be selected from\.

      * int *k*

        The number of items to be selected in each variation\.

  - <a name='15'></a>__::math::combinatorics::list\-combinations__ *n* *k*

    Return the list of combinations of k numbers selected from the numbers 0,
    \.\.\., n\-1\. The order of the items is ignored\.

      * int *n*

        The number of items to be selected from\.

      * int *k*

        The number of items to be selected in each combination\.

  - <a name='16'></a>__::math::combinatorics::list\-derangements__ *n*

    Return the list of derangements of the numbers 0, \.\.\., n\-1\.

      * int *n*

        The number of items to be rearranged\.

  - <a name='17'></a>__::math::combinatorics::list\-powerset__ *n*

    Return the list of all subsets of the numbers 0, \.\.\., n\-1\.

      * int *n*

        The number of items to be rearranged\.

  - <a name='18'></a>__::math::combinatorics::permutationObj__ new/create NAME *n*

    Create a TclOO object for returning permutations one by one\. If the last
    permutation has been reached an empty list is returned\.

      * int *n*

        The number of items to be rearranged\.

  - <a name='19'></a>__$perm__ next

    Return the next permutation of n objects\.

  - <a name='20'></a>__$perm__ reset

    Reset the object, so that the command *next* returns the complete list
    again\.

  - <a name='21'></a>__$perm__ setElements *elements*

    Register a list of items to be permuted, using the *nextElements* command\.

      * list *elements*

        The list of n items that will be permuted\.

  - <a name='22'></a>__$perm__ setElements

    Return the next permulation of the registered items\.

  - <a name='23'></a>__::math::combinatorics::combinationObj__ new/create NAME *n* *k*

    Create a TclOO object for returning combinations one by one\. If the last
    combination has been reached an empty list is returned\.

      * int *n*

        The number of items to be rearranged\.

  - <a name='24'></a>__$combin__ next

    Return the next combination of n objects\.

  - <a name='25'></a>__$combin__ reset

    Reset the object, so that the command *next* returns the complete list
    again\.

  - <a name='26'></a>__$combin__ setElements *elements*

    Register a list of items to be permuted, using the *nextElements* command\.

      * list *elements*

        The list of n items that will be permuted\.

  - <a name='27'></a>__$combin__ setElements

    Return the next combination of the registered items\.

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

# <a name='category'></a>CATEGORY

Mathematics
