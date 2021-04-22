
[//000000001]: # (math::decimal \- Tcl Decimal Arithmetic Library)
[//000000002]: # (Generated from file 'decimal\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2011 Mark Alston <mark at beernut dot com>)
[//000000004]: # (math::decimal\(n\) 1\.0\.3 tcllib "Tcl Decimal Arithmetic Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::decimal \- General decimal arithmetic

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [EXAMPLES](#section2)

  - [API](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl ?8\.5?  
package require math::decimal 1\.0\.3  

[__::math::decimal::fromstr__ *string*](#1)  
[__::math::decimal::tostr__ *decimal*](#2)  
[__::math::decimal::setVariable__ *variable* *setting*](#3)  
[__::math::decimal::add__ *a* *b*](#4)  
[__::math::decimal::\+__ *a* *b*](#5)  
[__::math::decimal::subtract__ *a* *b*](#6)  
[__::math::decimal::\-__ *a* *b*](#7)  
[__::math::decimal::multiply__ *a* *b*](#8)  
[__::math::decimal::\*__ *a* *b*](#9)  
[__::math::decimal::divide__ *a* *b*](#10)  
[__::math::decimal::/__ *a* *b*](#11)  
[__::math::decimal::divideint__ *a* *b*](#12)  
[__::math::decimal::remainder__ *a* *b*](#13)  
[__::math::decimal::abs__ *decimal*](#14)  
[__::math::decimal::compare__ *a* *b*](#15)  
[__::math::decimal::max__ *a* *b*](#16)  
[__::math::decimal::maxmag__ *a* *b*](#17)  
[__::math::decimal::min__ *a* *b*](#18)  
[__::math::decimal::minmag__ *a* *b*](#19)  
[__::math::decimal::plus__ *a*](#20)  
[__::math::decimal::minus__ *a*](#21)  
[__::math::decimal::copynegate__ *a*](#22)  
[__::math::decimal::copysign__ *a* *b*](#23)  
[__::math::decimal::is\-signed__ *decimal*](#24)  
[__::math::decimal::is\-zero__ *decimal*](#25)  
[__::math::decimal::is\-NaN__ *decimal*](#26)  
[__::math::decimal::is\-infinite__ *decimal*](#27)  
[__::math::decimal::is\-finite__ *decimal*](#28)  
[__::math::decimal::fma__ *a* *b* *c*](#29)  
[__::math::decimal::round\_half\_even__ *decimal* *digits*](#30)  
[__::math::decimal::round\_half\_up__ *decimal* *digits*](#31)  
[__::math::decimal::round\_half\_down__ *decimal* *digits*](#32)  
[__::math::decimal::round\_down__ *decimal* *digits*](#33)  
[__::math::decimal::round\_up__ *decimal* *digits*](#34)  
[__::math::decimal::round\_floor__ *decimal* *digits*](#35)  
[__::math::decimal::round\_ceiling__ *decimal* *digits*](#36)  
[__::math::decimal::round\_05up__ *decimal* *digits*](#37)  

# <a name='description'></a>DESCRIPTION

The decimal package provides decimal arithmetic support for both limited
precision floating point and arbitrary precision floating point\. Additionally,
integer arithmetic is supported\.

More information and the specifications on which this package depends can be
found on the general decimal arithmetic page at http://speleotrove\.com/decimal
This package provides for:

  - A new data type decimal which is represented as a list containing sign,
    mantissa and exponent\.

  - Arithmetic operations on those decimal numbers such as addition,
    subtraction, multiplication, etc\.\.\.

Numbers are converted to decimal format using the operation
::math::decimal::fromstr\.

Numbers are converted back to string format using the operation
::math::decimal::tostr\.

# <a name='section2'></a>EXAMPLES

This section shows some simple examples\. Since the purpose of this library is to
perform decimal math operations, examples may be the simplest way to learn how
to work with it and to see the difference between using this package and
sticking with expr\. Consult the API section of this man page for information
about individual procedures\.

    package require math::decimal

    # Various operations on two numbers.
    # We first convert them to decimal format.
    set a [::math::decimal::fromstr 8.2]
    set b [::math::decimal::fromstr .2]

    # Then we perform our operations. Here we add
    set c [::math::decimal::+ $a $b]

    # Finally we convert back to string format for presentation to the user.
    puts [::math::decimal::tostr $c] ; # => will output 8.4

    # Other examples
    #
    # Subtraction
    set c [::math::decimal::- $a $b]
    puts [::math::decimal::tostr $c] ; # => will output 8.0

    # Why bother using this instead of simply expr?
    puts [expr {8.2 + .2}] ; # => will output 8.399999999999999
    puts [expr {8.2 - .2}] ; # => will output 7.999999999999999
    # See http://speleotrove.com/decimal to learn more about why this happens.

# <a name='section3'></a>API

  - <a name='1'></a>__::math::decimal::fromstr__ *string*

    Convert *string* into a decimal\.

  - <a name='2'></a>__::math::decimal::tostr__ *decimal*

    Convert *decimal* into a string representing the number in base 10\.

  - <a name='3'></a>__::math::decimal::setVariable__ *variable* *setting*

    Sets the *variable* to *setting*\. Valid variables are:

      * *rounding* \- Method of rounding to use during rescale\. Valid methods
        are round\_half\_even, round\_half\_up, round\_half\_down, round\_down,
        round\_up, round\_floor, round\_ceiling\.

      * *precision* \- Maximum number of digits allowed in mantissa\.

      * *extended* \- Set to 1 for extended mode\. 0 for simplified mode\.

      * *maxExponent* \- Maximum value for the exponent\. Defaults to 999\.

      * *minExponent* \- Minimum value for the exponent\. Default to \-998\.

  - <a name='4'></a>__::math::decimal::add__ *a* *b*

  - <a name='5'></a>__::math::decimal::\+__ *a* *b*

    Return the sum of the two decimals *a* and *b*\.

  - <a name='6'></a>__::math::decimal::subtract__ *a* *b*

  - <a name='7'></a>__::math::decimal::\-__ *a* *b*

    Return the differnece of the two decimals *a* and *b*\.

  - <a name='8'></a>__::math::decimal::multiply__ *a* *b*

  - <a name='9'></a>__::math::decimal::\*__ *a* *b*

    Return the product of the two decimals *a* and *b*\.

  - <a name='10'></a>__::math::decimal::divide__ *a* *b*

  - <a name='11'></a>__::math::decimal::/__ *a* *b*

    Return the quotient of the division between the two decimals *a* and
    *b*\.

  - <a name='12'></a>__::math::decimal::divideint__ *a* *b*

    Return a the integer portion of the quotient of the division between
    decimals *a* and *b*

  - <a name='13'></a>__::math::decimal::remainder__ *a* *b*

    Return the remainder of the division between the two decimals *a* and
    *b*\.

  - <a name='14'></a>__::math::decimal::abs__ *decimal*

    Return the absolute value of the decimal\.

  - <a name='15'></a>__::math::decimal::compare__ *a* *b*

    Compare the two decimals a and b, returning *0* if *a == b*, *1* if
    *a > b*, and *\-1* if *a < b*\.

  - <a name='16'></a>__::math::decimal::max__ *a* *b*

    Compare the two decimals a and b, and return *a* if *a >= b*, and *b*
    if *a < b*\.

  - <a name='17'></a>__::math::decimal::maxmag__ *a* *b*

    Compare the two decimals a and b while ignoring their signs, and return
    *a* if *abs\(a\) >= abs\(b\)*, and *b* if *abs\(a\) < abs\(b\)*\.

  - <a name='18'></a>__::math::decimal::min__ *a* *b*

    Compare the two decimals a and b, and return *a* if *a <= b*, and *b*
    if *a > b*\.

  - <a name='19'></a>__::math::decimal::minmag__ *a* *b*

    Compare the two decimals a and b while ignoring their signs, and return
    *a* if *abs\(a\) <= abs\(b\)*, and *b* if *abs\(a\) > abs\(b\)*\.

  - <a name='20'></a>__::math::decimal::plus__ *a*

    Return the result from *::math::decimal::\+ 0 $a*\.

  - <a name='21'></a>__::math::decimal::minus__ *a*

    Return the result from *::math::decimal::\- 0 $a*\.

  - <a name='22'></a>__::math::decimal::copynegate__ *a*

    Returns *a* with the sign flipped\.

  - <a name='23'></a>__::math::decimal::copysign__ *a* *b*

    Returns *a* with the sign set to the sign of the *b*\.

  - <a name='24'></a>__::math::decimal::is\-signed__ *decimal*

    Return the sign of the decimal\. The procedure returns 0 if the number is
    positive, 1 if it's negative\.

  - <a name='25'></a>__::math::decimal::is\-zero__ *decimal*

    Return true if *decimal* value is zero, otherwise false is returned\.

  - <a name='26'></a>__::math::decimal::is\-NaN__ *decimal*

    Return true if *decimal* value is NaN \(not a number\), otherwise false is
    returned\.

  - <a name='27'></a>__::math::decimal::is\-infinite__ *decimal*

    Return true if *decimal* value is Infinite, otherwise false is returned\.

  - <a name='28'></a>__::math::decimal::is\-finite__ *decimal*

    Return true if *decimal* value is finite, otherwise false is returned\.

  - <a name='29'></a>__::math::decimal::fma__ *a* *b* *c*

    Return the result from first multiplying *a* by *b* and then adding
    *c*\. Rescaling only occurs after completion of all operations\. In this way
    the result may vary from that returned by performing the operations
    individually\.

  - <a name='30'></a>__::math::decimal::round\_half\_even__ *decimal* *digits*

    Rounds *decimal* to *digits* number of decimal points with the following
    rules: Round to the nearest\. If equidistant, round so the final digit is
    even\.

  - <a name='31'></a>__::math::decimal::round\_half\_up__ *decimal* *digits*

    Rounds *decimal* to *digits* number of decimal points with the following
    rules: Round to the nearest\. If equidistant, round up\.

  - <a name='32'></a>__::math::decimal::round\_half\_down__ *decimal* *digits*

    Rounds *decimal* to *digits* number of decimal points with the following
    rules: Round to the nearest\. If equidistant, round down\.

  - <a name='33'></a>__::math::decimal::round\_down__ *decimal* *digits*

    Rounds *decimal* to *digits* number of decimal points with the following
    rules: Round toward 0\. \(Truncate\)

  - <a name='34'></a>__::math::decimal::round\_up__ *decimal* *digits*

    Rounds *decimal* to *digits* number of decimal points with the following
    rules: Round away from 0

  - <a name='35'></a>__::math::decimal::round\_floor__ *decimal* *digits*

    Rounds *decimal* to *digits* number of decimal points with the following
    rules: Round toward \-Infinity\.

  - <a name='36'></a>__::math::decimal::round\_ceiling__ *decimal* *digits*

    Rounds *decimal* to *digits* number of decimal points with the following
    rules: Round toward Infinity

  - <a name='37'></a>__::math::decimal::round\_05up__ *decimal* *digits*

    Rounds *decimal* to *digits* number of decimal points with the following
    rules: Round zero or five away from 0\. The same as round\-up, except that
    rounding up only occurs if the digit to be rounded up is 0 or 5, and after
    overflow the result is the same as for round\-down\.

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *decimal* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[decimal](\.\./\.\./\.\./\.\./index\.md\#decimal),
[math](\.\./\.\./\.\./\.\./index\.md\#math), [tcl](\.\./\.\./\.\./\.\./index\.md\#tcl)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2011 Mark Alston <mark at beernut dot com>
