
[//000000001]: # (math::special \- Tcl Math Library)
[//000000002]: # (Generated from file 'special\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004 Arjen Markus <arjenmarkus@users\.sourceforge\.net>)
[//000000004]: # (math::special\(n\) 0\.4 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::special \- Special mathematical functions

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [OVERVIEW](#section2)

  - [PROCEDURES](#section3)

  - [THE ORTHOGONAL POLYNOMIALS](#section4)

  - [REMARKS ON THE IMPLEMENTATION](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl ?8\.5?  
package require math::special ?0\.5?  

[__::math::special::eulerNumber__ *index*](#1)  
[__::math::special::bernoulliNumber__ *index*](#2)  
[__::math::special::Beta__ *x* *y*](#3)  
[__::math::special::incBeta__ *a* *b* *x*](#4)  
[__::math::special::regIncBeta__ *a* *b* *x*](#5)  
[__::math::special::Gamma__ *x*](#6)  
[__::math::special::digamma__ *x*](#7)  
[__::math::special::erf__ *x*](#8)  
[__::math::special::erfc__ *x*](#9)  
[__::math::special::invnorm__ *p*](#10)  
[__::math::special::J0__ *x*](#11)  
[__::math::special::J1__ *x*](#12)  
[__::math::special::Jn__ *n* *x*](#13)  
[__::math::special::J1/2__ *x*](#14)  
[__::math::special::J\-1/2__ *x*](#15)  
[__::math::special::I\_n__ *x*](#16)  
[__::math::special::cn__ *u* *k*](#17)  
[__::math::special::dn__ *u* *k*](#18)  
[__::math::special::sn__ *u* *k*](#19)  
[__::math::special::elliptic\_K__ *k*](#20)  
[__::math::special::elliptic\_E__ *k*](#21)  
[__::math::special::exponential\_Ei__ *x*](#22)  
[__::math::special::exponential\_En__ *n* *x*](#23)  
[__::math::special::exponential\_li__ *x*](#24)  
[__::math::special::exponential\_Ci__ *x*](#25)  
[__::math::special::exponential\_Si__ *x*](#26)  
[__::math::special::exponential\_Chi__ *x*](#27)  
[__::math::special::exponential\_Shi__ *x*](#28)  
[__::math::special::fresnel\_C__ *x*](#29)  
[__::math::special::fresnel\_S__ *x*](#30)  
[__::math::special::sinc__ *x*](#31)  
[__::math::special::legendre__ *n*](#32)  
[__::math::special::chebyshev__ *n*](#33)  
[__::math::special::laguerre__ *alpha* *n*](#34)  
[__::math::special::hermite__ *n*](#35)  

# <a name='description'></a>DESCRIPTION

This package implements several so\-called special functions, like the Gamma
function, the Bessel functions and such\.

Each function is implemented by a procedure that bears its name \(well, in close
approximation\):

  - J0 for the zeroth\-order Bessel function of the first kind

  - J1 for the first\-order Bessel function of the first kind

  - Jn for the nth\-order Bessel function of the first kind

  - J1/2 for the half\-order Bessel function of the first kind

  - J\-1/2 for the minus\-half\-order Bessel function of the first kind

  - I\_n for the modified Bessel function of the first kind of order n

  - Gamma for the Gamma function, erf and erfc for the error function and the
    complementary error function

  - fresnel\_C and fresnel\_S for the Fresnel integrals

  - elliptic\_K and elliptic\_E \(complete elliptic integrals\)

  - exponent\_Ei and other functions related to the so\-called exponential
    integrals

  - legendre, hermite: some of the classical orthogonal polynomials\.

# <a name='section2'></a>OVERVIEW

In the following table several characteristics of the functions in this package
are summarized: the domain for the argument, the values for the parameters and
error bounds\.

    Family       | Function    | Domain x    | Parameter   | Error bound
    -------------+-------------+-------------+-------------+--------------
    Bessel       | J0, J1,     | all of R    | n = integer |   < 1.0e-8
                 | Jn          |             |             |  (|x|<20, n<20)
    Bessel       | J1/2, J-1/2,|  x > 0      | n = integer |   exact
    Bessel       | I_n         | all of R    | n = integer |   < 1.0e-6
                 |             |             |             |
    Elliptic     | cn          | 0 <= x <= 1 |     --      |   < 1.0e-10
    functions    | dn          | 0 <= x <= 1 |     --      |   < 1.0e-10
                 | sn          | 0 <= x <= 1 |     --      |   < 1.0e-10
    Elliptic     | K           | 0 <= x < 1  |     --      |   < 1.0e-6
    integrals    | E           | 0 <= x < 1  |     --      |   < 1.0e-6
                 |             |             |             |
    Error        | erf         |             |     --      |
    functions    | erfc        |             |             |
                 |             |             |             |
    Inverse      | invnorm     | 0 < x < 1   |     --      |   < 1.2e-9
    normal       |             |             |             |
    distribution |             |             |             |
                 |             |             |             |
    Exponential  | Ei          |  x != 0     |     --      |   < 1.0e-10 (relative)
    integrals    | En          |  x >  0     |     --      |   as Ei
                 | li          |  x > 0      |     --      |   as Ei
                 | Chi         |  x > 0      |     --      |   < 1.0e-8
                 | Shi         |  x > 0      |     --      |   < 1.0e-8
                 | Ci          |  x > 0      |     --      |   < 2.0e-4
                 | Si          |  x > 0      |     --      |   < 2.0e-4
                 |             |             |             |
    Fresnel      | C           |  all of R   |     --      |   < 2.0e-3
    integrals    | S           |  all of R   |     --      |   < 2.0e-3
                 |             |             |             |
    general      | Beta        | (see Gamma) |     --      |   < 1.0e-9
                 | Gamma       |  x != 0,-1, |     --      |   < 1.0e-9
                 |             |  -2, ...    |             |
                 | incBeta     |             |  a, b > 0   |   < 1.0e-9
                 | regIncBeta  |             |  a, b > 0   |   < 1.0e-9
                 | digamma     |  x != 0,-1  |             |   < 1.0e-9
                 |             |  -2, ...    |             |
                 |             |             |             |
                 | sinc        |  all of R   |     --      |   exact
                 |             |             |             |
    orthogonal   | Legendre    |  all of R   | n = 0,1,... |   exact
    polynomials  | Chebyshev   |  all of R   | n = 0,1,... |   exact
                 | Laguerre    |  all of R   | n = 0,1,... |   exact
                 |             |             | alpha el. R |
                 | Hermite     |  all of R   | n = 0,1,... |   exact

*Note:* Some of the error bounds are estimated, as no "formal" bounds were
available with the implemented approximation method, others hold for the
auxiliary functions used for estimating the primary functions\.

The following well\-known functions are currently missing from the package:

  - Bessel functions of the second kind \(Y\_n, K\_n\)

  - Bessel functions of arbitrary order \(and hence the Airy functions\)

  - Chebyshev polynomials of the second kind \(U\_n\)

  - The incomplete gamma function

# <a name='section3'></a>PROCEDURES

The package defines the following public procedures:

  - <a name='1'></a>__::math::special::eulerNumber__ *index*

    Return the index'th Euler number \(note: these are integer values\)\. As the
    size of these numbers grows very fast, only a limited number are available\.

      * int *index*

        Index of the number to be returned \(should be between 0 and 54\)

  - <a name='2'></a>__::math::special::bernoulliNumber__ *index*

    Return the index'th Bernoulli number\. As the size of the numbers grows very
    fast, only a limited number are available\.

      * int *index*

        Index of the number to be returned \(should be between 0 and 52\)

  - <a name='3'></a>__::math::special::Beta__ *x* *y*

    Compute the Beta function for arguments "x" and "y"

      * float *x*

        First argument for the Beta function

      * float *y*

        Second argument for the Beta function

  - <a name='4'></a>__::math::special::incBeta__ *a* *b* *x*

    Compute the incomplete Beta function for argument "x" with parameters "a"
    and "b"

      * float *a*

        First parameter for the incomplete Beta function, a > 0

      * float *b*

        Second parameter for the incomplete Beta function, b > 0

      * float *x*

        Argument for the incomplete Beta function

  - <a name='5'></a>__::math::special::regIncBeta__ *a* *b* *x*

    Compute the regularized incomplete Beta function for argument "x" with
    parameters "a" and "b"

      * float *a*

        First parameter for the incomplete Beta function, a > 0

      * float *b*

        Second parameter for the incomplete Beta function, b > 0

      * float *x*

        Argument for the regularized incomplete Beta function

  - <a name='6'></a>__::math::special::Gamma__ *x*

    Compute the Gamma function for argument "x"

      * float *x*

        Argument for the Gamma function

  - <a name='7'></a>__::math::special::digamma__ *x*

    Compute the digamma function \(psi\) for argument "x"

      * float *x*

        Argument for the digamma function

  - <a name='8'></a>__::math::special::erf__ *x*

    Compute the error function for argument "x"

      * float *x*

        Argument for the error function

  - <a name='9'></a>__::math::special::erfc__ *x*

    Compute the complementary error function for argument "x"

      * float *x*

        Argument for the complementary error function

  - <a name='10'></a>__::math::special::invnorm__ *p*

    Compute the inverse of the normal distribution function for argument "p"

      * float *p*

        Argument for the inverse normal distribution function \(p must be greater
        than 0 and lower than 1\)

  - <a name='11'></a>__::math::special::J0__ *x*

    Compute the zeroth\-order Bessel function of the first kind for the argument
    "x"

      * float *x*

        Argument for the Bessel function

  - <a name='12'></a>__::math::special::J1__ *x*

    Compute the first\-order Bessel function of the first kind for the argument
    "x"

      * float *x*

        Argument for the Bessel function

  - <a name='13'></a>__::math::special::Jn__ *n* *x*

    Compute the nth\-order Bessel function of the first kind for the argument "x"

      * integer *n*

        Order of the Bessel function

      * float *x*

        Argument for the Bessel function

  - <a name='14'></a>__::math::special::J1/2__ *x*

    Compute the half\-order Bessel function of the first kind for the argument
    "x"

      * float *x*

        Argument for the Bessel function

  - <a name='15'></a>__::math::special::J\-1/2__ *x*

    Compute the minus\-half\-order Bessel function of the first kind for the
    argument "x"

      * float *x*

        Argument for the Bessel function

  - <a name='16'></a>__::math::special::I\_n__ *x*

    Compute the modified Bessel function of the first kind of order n for the
    argument "x"

      * int *x*

        Positive integer order of the function

      * float *x*

        Argument for the function

  - <a name='17'></a>__::math::special::cn__ *u* *k*

    Compute the elliptic function *cn* for the argument "u" and parameter "k"\.

      * float *u*

        Argument for the function

      * float *k*

        Parameter

  - <a name='18'></a>__::math::special::dn__ *u* *k*

    Compute the elliptic function *dn* for the argument "u" and parameter "k"\.

      * float *u*

        Argument for the function

      * float *k*

        Parameter

  - <a name='19'></a>__::math::special::sn__ *u* *k*

    Compute the elliptic function *sn* for the argument "u" and parameter "k"\.

      * float *u*

        Argument for the function

      * float *k*

        Parameter

  - <a name='20'></a>__::math::special::elliptic\_K__ *k*

    Compute the complete elliptic integral of the first kind for the argument
    "k"

      * float *k*

        Argument for the function

  - <a name='21'></a>__::math::special::elliptic\_E__ *k*

    Compute the complete elliptic integral of the second kind for the argument
    "k"

      * float *k*

        Argument for the function

  - <a name='22'></a>__::math::special::exponential\_Ei__ *x*

    Compute the exponential integral of the second kind for the argument "x"

      * float *x*

        Argument for the function \(x \!= 0\)

  - <a name='23'></a>__::math::special::exponential\_En__ *n* *x*

    Compute the exponential integral of the first kind for the argument "x" and
    order n

      * int *n*

        Order of the integral \(n >= 0\)

      * float *x*

        Argument for the function \(x >= 0\)

  - <a name='24'></a>__::math::special::exponential\_li__ *x*

    Compute the logarithmic integral for the argument "x"

      * float *x*

        Argument for the function \(x > 0\)

  - <a name='25'></a>__::math::special::exponential\_Ci__ *x*

    Compute the cosine integral for the argument "x"

      * float *x*

        Argument for the function \(x > 0\)

  - <a name='26'></a>__::math::special::exponential\_Si__ *x*

    Compute the sine integral for the argument "x"

      * float *x*

        Argument for the function \(x > 0\)

  - <a name='27'></a>__::math::special::exponential\_Chi__ *x*

    Compute the hyperbolic cosine integral for the argument "x"

      * float *x*

        Argument for the function \(x > 0\)

  - <a name='28'></a>__::math::special::exponential\_Shi__ *x*

    Compute the hyperbolic sine integral for the argument "x"

      * float *x*

        Argument for the function \(x > 0\)

  - <a name='29'></a>__::math::special::fresnel\_C__ *x*

    Compute the Fresnel cosine integral for real argument x

      * float *x*

        Argument for the function

  - <a name='30'></a>__::math::special::fresnel\_S__ *x*

    Compute the Fresnel sine integral for real argument x

      * float *x*

        Argument for the function

  - <a name='31'></a>__::math::special::sinc__ *x*

    Compute the sinc function for real argument x

      * float *x*

        Argument for the function

  - <a name='32'></a>__::math::special::legendre__ *n*

    Return the Legendre polynomial of degree n \(see [THE ORTHOGONAL
    POLYNOMIALS](#section4)\)

      * int *n*

        Degree of the polynomial

  - <a name='33'></a>__::math::special::chebyshev__ *n*

    Return the Chebyshev polynomial of degree n \(of the first kind\)

      * int *n*

        Degree of the polynomial

  - <a name='34'></a>__::math::special::laguerre__ *alpha* *n*

    Return the Laguerre polynomial of degree n with parameter alpha

      * float *alpha*

        Parameter of the Laguerre polynomial

      * int *n*

        Degree of the polynomial

  - <a name='35'></a>__::math::special::hermite__ *n*

    Return the Hermite polynomial of degree n

      * int *n*

        Degree of the polynomial

# <a name='section4'></a>THE ORTHOGONAL POLYNOMIALS

For dealing with the classical families of orthogonal polynomials, the package
relies on the *math::polynomials* package\. To evaluate the polynomial at some
coordinate, use the *evalPolyn* command:

    set leg2 [::math::special::legendre 2]
    puts "Value at x=$x: [::math::polynomials::evalPolyn $leg2 $x]"

The return value from the *legendre* and other commands is actually the
definition of the corresponding polynomial as used in that package\.

# <a name='section5'></a>REMARKS ON THE IMPLEMENTATION

It should be noted, that the actual implementation of J0 and J1 depends on
straightforward Gaussian quadrature formulas\. The \(absolute\) accuracy of the
results is of the order 1\.0e\-4 or better\. The main reason to implement them like
that was that it was fast to do \(the formulas are simple\) and the computations
are fast too\.

The implementation of J1/2 does not suffer from this: this function can be
expressed exactly in terms of elementary functions\.

The functions J0 and J1 are the ones you will encounter most frequently in
practice\.

The computation of I\_n is based on Miller's algorithm for computing the minimal
function from recurrence relations\.

The computation of the Gamma and Beta functions relies on the combinatorics
package, whereas that of the error functions relies on the statistics package\.

The computation of the complete elliptic integrals uses the AGM algorithm\.

Much information about these functions can be found in:

Abramowitz and Stegun: *Handbook of Mathematical Functions* \(Dover, ISBN
486\-61272\-4\)

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: special* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[Bessel functions](\.\./\.\./\.\./\.\./index\.md\#bessel\_functions), [error
function](\.\./\.\./\.\./\.\./index\.md\#error\_function),
[math](\.\./\.\./\.\./\.\./index\.md\#math), [special
functions](\.\./\.\./\.\./\.\./index\.md\#special\_functions)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004 Arjen Markus <arjenmarkus@users\.sourceforge\.net>
