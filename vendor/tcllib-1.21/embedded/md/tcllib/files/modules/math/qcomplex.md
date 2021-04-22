
[//000000001]: # (math::complexnumbers \- Tcl Math Library)
[//000000002]: # (Generated from file 'qcomplex\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004 Arjen Markus <arjenmarkus@users\.sourceforge\.net>)
[//000000004]: # (math::complexnumbers\(n\) 1\.0\.2 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::complexnumbers \- Straightforward complex number package

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [AVAILABLE PROCEDURES](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.3  
package require math::complexnumbers ?1\.0\.2?  

[__::math::complexnumbers::\+__ *z1* *z2*](#1)  
[__::math::complexnumbers::\-__ *z1* *z2*](#2)  
[__::math::complexnumbers::\*__ *z1* *z2*](#3)  
[__::math::complexnumbers::/__ *z1* *z2*](#4)  
[__::math::complexnumbers::conj__ *z1*](#5)  
[__::math::complexnumbers::real__ *z1*](#6)  
[__::math::complexnumbers::imag__ *z1*](#7)  
[__::math::complexnumbers::mod__ *z1*](#8)  
[__::math::complexnumbers::arg__ *z1*](#9)  
[__::math::complexnumbers::complex__ *real* *imag*](#10)  
[__::math::complexnumbers::tostring__ *z1*](#11)  
[__::math::complexnumbers::exp__ *z1*](#12)  
[__::math::complexnumbers::sin__ *z1*](#13)  
[__::math::complexnumbers::cos__ *z1*](#14)  
[__::math::complexnumbers::tan__ *z1*](#15)  
[__::math::complexnumbers::log__ *z1*](#16)  
[__::math::complexnumbers::sqrt__ *z1*](#17)  
[__::math::complexnumbers::pow__ *z1* *z2*](#18)  

# <a name='description'></a>DESCRIPTION

The mathematical module *complexnumbers* provides a straightforward
implementation of complex numbers in pure Tcl\. The philosophy is that the user
knows he or she is dealing with complex numbers in an abstract way and wants as
high a performance as can be had within the limitations of an interpreted
language\.

Therefore the procedures defined in this package assume that the arguments are
valid \(representations of\) "complex numbers", that is, lists of two numbers
defining the real and imaginary part of a complex number \(though this is a mere
detail: rely on the *complex* command to construct a valid number\.\)

Most procedures implement the basic arithmetic operations or elementary
functions whereas several others convert to and from different representations:

    set z [complex 0 1]
    puts "z = [tostring $z]"
    puts "z**2 = [* $z $z]

would result in:

    z = i
    z**2 = -1

# <a name='section2'></a>AVAILABLE PROCEDURES

The package implements all or most basic operations and elementary functions\.

*The arithmetic operations are:*

  - <a name='1'></a>__::math::complexnumbers::\+__ *z1* *z2*

    Add the two arguments and return the resulting complex number

      * complex *z1* \(in\)

        First argument in the summation

      * complex *z2* \(in\)

        Second argument in the summation

  - <a name='2'></a>__::math::complexnumbers::\-__ *z1* *z2*

    Subtract the second argument from the first and return the resulting complex
    number\. If there is only one argument, the opposite of z1 is returned \(i\.e\.
    \-z1\)

      * complex *z1* \(in\)

        First argument in the subtraction

      * complex *z2* \(in\)

        Second argument in the subtraction \(optional\)

  - <a name='3'></a>__::math::complexnumbers::\*__ *z1* *z2*

    Multiply the two arguments and return the resulting complex number

      * complex *z1* \(in\)

        First argument in the multiplication

      * complex *z2* \(in\)

        Second argument in the multiplication

  - <a name='4'></a>__::math::complexnumbers::/__ *z1* *z2*

    Divide the first argument by the second and return the resulting complex
    number

      * complex *z1* \(in\)

        First argument \(numerator\) in the division

      * complex *z2* \(in\)

        Second argument \(denominator\) in the division

  - <a name='5'></a>__::math::complexnumbers::conj__ *z1*

    Return the conjugate of the given complex number

      * complex *z1* \(in\)

        Complex number in question

*Conversion/inquiry procedures:*

  - <a name='6'></a>__::math::complexnumbers::real__ *z1*

    Return the real part of the given complex number

      * complex *z1* \(in\)

        Complex number in question

  - <a name='7'></a>__::math::complexnumbers::imag__ *z1*

    Return the imaginary part of the given complex number

      * complex *z1* \(in\)

        Complex number in question

  - <a name='8'></a>__::math::complexnumbers::mod__ *z1*

    Return the modulus of the given complex number

      * complex *z1* \(in\)

        Complex number in question

  - <a name='9'></a>__::math::complexnumbers::arg__ *z1*

    Return the argument \("angle" in radians\) of the given complex number

      * complex *z1* \(in\)

        Complex number in question

  - <a name='10'></a>__::math::complexnumbers::complex__ *real* *imag*

    Construct the complex number "real \+ imag\*i" and return it

      * float *real* \(in\)

        The real part of the new complex number

      * float *imag* \(in\)

        The imaginary part of the new complex number

  - <a name='11'></a>__::math::complexnumbers::tostring__ *z1*

    Convert the complex number to the form "real \+ imag\*i" and return the string

      * float *complex* \(in\)

        The complex number to be converted

*Elementary functions:*

  - <a name='12'></a>__::math::complexnumbers::exp__ *z1*

    Calculate the exponential for the given complex argument and return the
    result

      * complex *z1* \(in\)

        The complex argument for the function

  - <a name='13'></a>__::math::complexnumbers::sin__ *z1*

    Calculate the sine function for the given complex argument and return the
    result

      * complex *z1* \(in\)

        The complex argument for the function

  - <a name='14'></a>__::math::complexnumbers::cos__ *z1*

    Calculate the cosine function for the given complex argument and return the
    result

      * complex *z1* \(in\)

        The complex argument for the function

  - <a name='15'></a>__::math::complexnumbers::tan__ *z1*

    Calculate the tangent function for the given complex argument and return the
    result

      * complex *z1* \(in\)

        The complex argument for the function

  - <a name='16'></a>__::math::complexnumbers::log__ *z1*

    Calculate the \(principle value of the\) logarithm for the given complex
    argument and return the result

      * complex *z1* \(in\)

        The complex argument for the function

  - <a name='17'></a>__::math::complexnumbers::sqrt__ *z1*

    Calculate the \(principle value of the\) square root for the given complex
    argument and return the result

      * complex *z1* \(in\)

        The complex argument for the function

  - <a name='18'></a>__::math::complexnumbers::pow__ *z1* *z2*

    Calculate "z1 to the power of z2" and return the result

      * complex *z1* \(in\)

        The complex number to be raised to a power

      * complex *z2* \(in\)

        The complex power to be used

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: complexnumbers* of
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

[complex numbers](\.\./\.\./\.\./\.\./index\.md\#complex\_numbers),
[math](\.\./\.\./\.\./\.\./index\.md\#math)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004 Arjen Markus <arjenmarkus@users\.sourceforge\.net>
