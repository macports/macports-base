
[//000000001]: # (math::polynomials \- Tcl Math Library)
[//000000002]: # (Generated from file 'polynomials\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004 Arjen Markus <arjenmarkus@users\.sourceforge\.net>)
[//000000004]: # (math::polynomials\(n\) 1\.0\.1 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::polynomials \- Polynomial functions

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PROCEDURES](#section2)

  - [REMARKS ON THE IMPLEMENTATION](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl ?8\.3?  
package require math::polynomials ?1\.0\.1?  

[__::math::polynomials::polynomial__ *coeffs*](#1)  
[__::math::polynomials::polynCmd__ *coeffs*](#2)  
[__::math::polynomials::evalPolyn__ *polynomial* *x*](#3)  
[__::math::polynomials::addPolyn__ *polyn1* *polyn2*](#4)  
[__::math::polynomials::subPolyn__ *polyn1* *polyn2*](#5)  
[__::math::polynomials::multPolyn__ *polyn1* *polyn2*](#6)  
[__::math::polynomials::divPolyn__ *polyn1* *polyn2*](#7)  
[__::math::polynomials::remainderPolyn__ *polyn1* *polyn2*](#8)  
[__::math::polynomials::derivPolyn__ *polyn*](#9)  
[__::math::polynomials::primitivePolyn__ *polyn*](#10)  
[__::math::polynomials::degreePolyn__ *polyn*](#11)  
[__::math::polynomials::coeffPolyn__ *polyn* *index*](#12)  
[__::math::polynomials::allCoeffsPolyn__ *polyn*](#13)  

# <a name='description'></a>DESCRIPTION

This package deals with polynomial functions of one variable:

  - the basic arithmetic operations are extended to polynomials

  - computing the derivatives and primitives of these functions

  - evaluation through a general procedure or via specific procedures\)

# <a name='section2'></a>PROCEDURES

The package defines the following public procedures:

  - <a name='1'></a>__::math::polynomials::polynomial__ *coeffs*

    Return an \(encoded\) list that defines the polynomial\. A polynomial

        f(x) = a + b.x + c.x**2 + d.x**3

    can be defined via:

        set f [::math::polynomials::polynomial [list $a $b $c $d]

      * list *coeffs*

        Coefficients of the polynomial \(in ascending order\)

  - <a name='2'></a>__::math::polynomials::polynCmd__ *coeffs*

    Create a new procedure that evaluates the polynomial\. The name of the
    polynomial is automatically generated\. Useful if you need to evualuate the
    polynomial many times, as the procedure consists of a single \[expr\] command\.

      * list *coeffs*

        Coefficients of the polynomial \(in ascending order\) or the polynomial
        definition returned by the *polynomial* command\.

  - <a name='3'></a>__::math::polynomials::evalPolyn__ *polynomial* *x*

    Evaluate the polynomial at x\.

      * list *polynomial*

        The polynomial's definition \(as returned by the polynomial command\)\.
        order\)

      * float *x*

        The coordinate at which to evaluate the polynomial

  - <a name='4'></a>__::math::polynomials::addPolyn__ *polyn1* *polyn2*

    Return a new polynomial which is the sum of the two others\.

      * list *polyn1*

        The first polynomial operand

      * list *polyn2*

        The second polynomial operand

  - <a name='5'></a>__::math::polynomials::subPolyn__ *polyn1* *polyn2*

    Return a new polynomial which is the difference of the two others\.

      * list *polyn1*

        The first polynomial operand

      * list *polyn2*

        The second polynomial operand

  - <a name='6'></a>__::math::polynomials::multPolyn__ *polyn1* *polyn2*

    Return a new polynomial which is the product of the two others\. If one of
    the arguments is a scalar value, the other polynomial is simply scaled\.

      * list *polyn1*

        The first polynomial operand or a scalar

      * list *polyn2*

        The second polynomial operand or a scalar

  - <a name='7'></a>__::math::polynomials::divPolyn__ *polyn1* *polyn2*

    Divide the first polynomial by the second polynomial and return the result\.
    The remainder is dropped

      * list *polyn1*

        The first polynomial operand

      * list *polyn2*

        The second polynomial operand

  - <a name='8'></a>__::math::polynomials::remainderPolyn__ *polyn1* *polyn2*

    Divide the first polynomial by the second polynomial and return the
    remainder\.

      * list *polyn1*

        The first polynomial operand

      * list *polyn2*

        The second polynomial operand

  - <a name='9'></a>__::math::polynomials::derivPolyn__ *polyn*

    Differentiate the polynomial and return the result\.

      * list *polyn*

        The polynomial to be differentiated

  - <a name='10'></a>__::math::polynomials::primitivePolyn__ *polyn*

    Integrate the polynomial and return the result\. The integration constant is
    set to zero\.

      * list *polyn*

        The polynomial to be integrated

  - <a name='11'></a>__::math::polynomials::degreePolyn__ *polyn*

    Return the degree of the polynomial\.

      * list *polyn*

        The polynomial to be examined

  - <a name='12'></a>__::math::polynomials::coeffPolyn__ *polyn* *index*

    Return the coefficient of the term of the index'th degree of the polynomial\.

      * list *polyn*

        The polynomial to be examined

      * int *index*

        The degree of the term

  - <a name='13'></a>__::math::polynomials::allCoeffsPolyn__ *polyn*

    Return the coefficients of the polynomial \(in ascending order\)\.

      * list *polyn*

        The polynomial in question

# <a name='section3'></a>REMARKS ON THE IMPLEMENTATION

The implementation for evaluating the polynomials at some point uses Horn's
rule, which guarantees numerical stability and a minimum of arithmetic
operations\. To recognise that a polynomial definition is indeed a correct
definition, it consists of a list of two elements: the keyword "POLYNOMIAL" and
the list of coefficients in descending order\. The latter makes it easier to
implement Horner's rule\.

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: polynomials* of
the [Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also
report any ideas for enhancements you may have for either package and/or
documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[math](\.\./\.\./\.\./\.\./index\.md\#math), [polynomial
functions](\.\./\.\./\.\./\.\./index\.md\#polynomial\_functions)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004 Arjen Markus <arjenmarkus@users\.sourceforge\.net>
