
[//000000001]: # (math::rationalfunctions \- Math)
[//000000002]: # (Generated from file 'rational\_funcs\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005 Arjen Markus <arjenmarkus@users\.sourceforge\.net>)
[//000000004]: # (math::rationalfunctions\(n\) 1\.0\.1 tcllib "Math")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::rationalfunctions \- Polynomial functions

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

package require Tcl ?8\.4?  
package require math::rationalfunctions ?1\.0\.1?  

[__::math::rationalfunctions::rationalFunction__ *num* *den*](#1)  
[__::math::rationalfunctions::ratioCmd__ *num* *den*](#2)  
[__::math::rationalfunctions::evalRatio__ *rational* *x*](#3)  
[__::math::rationalfunctions::addRatio__ *ratio1* *ratio2*](#4)  
[__::math::rationalfunctions::subRatio__ *ratio1* *ratio2*](#5)  
[__::math::rationalfunctions::multRatio__ *ratio1* *ratio2*](#6)  
[__::math::rationalfunctions::divRatio__ *ratio1* *ratio2*](#7)  
[__::math::rationalfunctions::derivPolyn__ *ratio*](#8)  
[__::math::rationalfunctions::coeffsNumerator__ *ratio*](#9)  
[__::math::rationalfunctions::coeffsDenominator__ *ratio*](#10)  

# <a name='description'></a>DESCRIPTION

This package deals with rational functions of one variable:

  - the basic arithmetic operations are extended to rational functions

  - computing the derivatives of these functions

  - evaluation through a general procedure or via specific procedures\)

# <a name='section2'></a>PROCEDURES

The package defines the following public procedures:

  - <a name='1'></a>__::math::rationalfunctions::rationalFunction__ *num* *den*

    Return an \(encoded\) list that defines the rational function\. A rational
    function

                  1 + x^3
        f(x) = ------------
               1 + 2x + x^2

    can be defined via:

        set f [::math::rationalfunctions::rationalFunction [list 1 0 0 1]  [list 1 2 1]]

      * list *num*

        Coefficients of the numerator of the rational function \(in ascending
        order\)

      * list *den*

        Coefficients of the denominator of the rational function \(in ascending
        order\)

  - <a name='2'></a>__::math::rationalfunctions::ratioCmd__ *num* *den*

    Create a new procedure that evaluates the rational function\. The name of the
    function is automatically generated\. Useful if you need to evaluate the
    function many times, as the procedure consists of a single \[expr\] command\.

      * list *num*

        Coefficients of the numerator of the rational function \(in ascending
        order\)

      * list *den*

        Coefficients of the denominator of the rational function \(in ascending
        order\)

  - <a name='3'></a>__::math::rationalfunctions::evalRatio__ *rational* *x*

    Evaluate the rational function at x\.

      * list *rational*

        The rational function's definition \(as returned by the rationalFunction
        command\)\. order\)

      * float *x*

        The coordinate at which to evaluate the function

  - <a name='4'></a>__::math::rationalfunctions::addRatio__ *ratio1* *ratio2*

    Return a new rational function which is the sum of the two others\.

      * list *ratio1*

        The first rational function operand

      * list *ratio2*

        The second rational function operand

  - <a name='5'></a>__::math::rationalfunctions::subRatio__ *ratio1* *ratio2*

    Return a new rational function which is the difference of the two others\.

      * list *ratio1*

        The first rational function operand

      * list *ratio2*

        The second rational function operand

  - <a name='6'></a>__::math::rationalfunctions::multRatio__ *ratio1* *ratio2*

    Return a new rational function which is the product of the two others\. If
    one of the arguments is a scalar value, the other rational function is
    simply scaled\.

      * list *ratio1*

        The first rational function operand or a scalar

      * list *ratio2*

        The second rational function operand or a scalar

  - <a name='7'></a>__::math::rationalfunctions::divRatio__ *ratio1* *ratio2*

    Divide the first rational function by the second rational function and
    return the result\. The remainder is dropped

      * list *ratio1*

        The first rational function operand

      * list *ratio2*

        The second rational function operand

  - <a name='8'></a>__::math::rationalfunctions::derivPolyn__ *ratio*

    Differentiate the rational function and return the result\.

      * list *ratio*

        The rational function to be differentiated

  - <a name='9'></a>__::math::rationalfunctions::coeffsNumerator__ *ratio*

    Return the coefficients of the numerator of the rational function\.

      * list *ratio*

        The rational function to be examined

  - <a name='10'></a>__::math::rationalfunctions::coeffsDenominator__ *ratio*

    Return the coefficients of the denominator of the rational function\.

      * list *ratio*

        The rational function to be examined

# <a name='section3'></a>REMARKS ON THE IMPLEMENTATION

The implementation of the rational functions relies on the math::polynomials
package\. For further remarks see the documentation on that package\.

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: rationalfunctions*
of the [Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also
report any ideas for enhancements you may have for either package and/or
documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[math](\.\./\.\./\.\./\.\./index\.md\#math), [rational
functions](\.\./\.\./\.\./\.\./index\.md\#rational\_functions)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005 Arjen Markus <arjenmarkus@users\.sourceforge\.net>
