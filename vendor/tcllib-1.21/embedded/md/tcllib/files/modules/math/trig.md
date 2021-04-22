
[//000000001]: # (math::trig \- Tcl Math Library)
[//000000002]: # (Generated from file 'trig\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2018 Arjen Markus)
[//000000004]: # (math::trig\(n\) 1\.0\.0 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::trig \- Trigonometric anf hyperbolic functions

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [FUNCTIONS](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require math::trig 1\.0\.0  

[__::math::trig::radian\_reduced__ *angle*](#1)  
[__::math::trig::degree\_reduced__ *angle*](#2)  
[__::math::trig::cosec__ *angle*](#3)  
[__::math::trig::sec__ *angle*](#4)  
[__::math::trig::cotan__ *angle*](#5)  
[__::math::trig::acosec__ *value*](#6)  
[__::math::trig::asec__ *value*](#7)  
[__::math::trig::acotan__ *value*](#8)  
[__::math::trig::cosech__ *value*](#9)  
[__::math::trig::sech__ *value*](#10)  
[__::math::trig::cotanh__ *value*](#11)  
[__::math::trig::asinh__ *value*](#12)  
[__::math::trig::acosh__ *value*](#13)  
[__::math::trig::atanh__ *value*](#14)  
[__::math::trig::acosech__ *value*](#15)  
[__::math::trig::asech__ *value*](#16)  
[__::math::trig::acotanh__ *value*](#17)  
[__::math::trig::sind__ *angle*](#18)  
[__::math::trig::cosd__ *angle*](#19)  
[__::math::trig::tand__ *angle*](#20)  
[__::math::trig::cosecd__ *angle*](#21)  
[__::math::trig::secd__ *angle*](#22)  
[__::math::trig::cotand__ *angle*](#23)  

# <a name='description'></a>DESCRIPTION

The *math::trig* package defines a set of trigonomic and hyperbolic functions
and their inverses\. In addition it defines versions of the trigonomic functions
that take arguments in degrees instead of radians\.

For easy use these functions may be imported into the *tcl::mathfunc*
namespace, so that they can be used directly in the *expr* command\.

# <a name='section2'></a>FUNCTIONS

The functions *radian\_reduced* and *degree\_reduced* return a reduced angle,
in respectively radians and degrees, in the intervals \[0, 2pi\) and \[0, 360\):

  - <a name='1'></a>__::math::trig::radian\_reduced__ *angle*

    Return the equivalent angle in the interval \[0, 2pi\)\.

      * float *angle*

        Angle \(in radians\)

  - <a name='2'></a>__::math::trig::degree\_reduced__ *angle*

    Return the equivalent angle in the interval \[0, 360\)\.

      * float *angle*

        Angle \(in degrees\)

The following trigonomic functions are defined in addition to the ones defined
in the *expr* command:

  - <a name='3'></a>__::math::trig::cosec__ *angle*

    Calculate the cosecant of the angle \(1/cos\(angle\)\)

      * float *angle*

        Angle \(in radians\)

  - <a name='4'></a>__::math::trig::sec__ *angle*

    Calculate the secant of the angle \(1/sin\(angle\)\)

      * float *angle*

        Angle \(in radians\)

  - <a name='5'></a>__::math::trig::cotan__ *angle*

    Calculate the cotangent of the angle \(1/tan\(angle\)\)

      * float *angle*

        Angle \(in radians\)

For these functions also the inverses are defined:

  - <a name='6'></a>__::math::trig::acosec__ *value*

    Calculate the arc cosecant of the value

      * float *value*

        Value of the argument

  - <a name='7'></a>__::math::trig::asec__ *value*

    Calculate the arc secant of the value

      * float *value*

        Value of the argument

  - <a name='8'></a>__::math::trig::acotan__ *value*

    Calculate the arc cotangent of the value

      * float *value*

        Value of the argument

The following hyperbolic and inverse hyperbolic functions are defined:

  - <a name='9'></a>__::math::trig::cosech__ *value*

    Calculate the hyperbolic cosecant of the value \(1/sinh\(value\)\)

      * float *value*

        Value of the argument

  - <a name='10'></a>__::math::trig::sech__ *value*

    Calculate the hyperbolic secant of the value \(1/cosh\(value\)\)

      * float *value*

        Value of the argument

  - <a name='11'></a>__::math::trig::cotanh__ *value*

    Calculate the hyperbolic cotangent of the value \(1/tanh\(value\)\)

      * float *value*

        Value of the argument

  - <a name='12'></a>__::math::trig::asinh__ *value*

    Calculate the arc hyperbolic sine of the value

      * float *value*

        Value of the argument

  - <a name='13'></a>__::math::trig::acosh__ *value*

    Calculate the arc hyperbolic cosine of the value

      * float *value*

        Value of the argument

  - <a name='14'></a>__::math::trig::atanh__ *value*

    Calculate the arc hyperbolic tangent of the value

      * float *value*

        Value of the argument

  - <a name='15'></a>__::math::trig::acosech__ *value*

    Calculate the arc hyperbolic cosecant of the value

      * float *value*

        Value of the argument

  - <a name='16'></a>__::math::trig::asech__ *value*

    Calculate the arc hyperbolic secant of the value

      * float *value*

        Value of the argument

  - <a name='17'></a>__::math::trig::acotanh__ *value*

    Calculate the arc hyperbolic cotangent of the value

      * float *value*

        Value of the argument

The following versions of the common trigonometric functions and their inverses
are defined:

  - <a name='18'></a>__::math::trig::sind__ *angle*

    Calculate the sine of the angle \(in degrees\)

      * float *angle*

        Angle \(in degrees\)

  - <a name='19'></a>__::math::trig::cosd__ *angle*

    Calculate the cosine of the angle \(in degrees\)

      * float *angle*

        Angle \(in radians\)

  - <a name='20'></a>__::math::trig::tand__ *angle*

    Calculate the cotangent of the angle \(in degrees\)

      * float *angle*

        Angle \(in degrees\)

  - <a name='21'></a>__::math::trig::cosecd__ *angle*

    Calculate the cosecant of the angle \(in degrees\)

      * float *angle*

        Angle \(in degrees\)

  - <a name='22'></a>__::math::trig::secd__ *angle*

    Calculate the secant of the angle \(in degrees\)

      * float *angle*

        Angle \(in degrees\)

  - <a name='23'></a>__::math::trig::cotand__ *angle*

    Calculate the cotangent of the angle \(in degrees\)

      * float *angle*

        Angle \(in degrees\)

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: trig* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[math](\.\./\.\./\.\./\.\./index\.md\#math),
[trigonometry](\.\./\.\./\.\./\.\./index\.md\#trigonometry)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2018 Arjen Markus
