
[//000000001]: # (math::bigfloat \- Tcl Math Library)
[//000000002]: # (Generated from file 'bigfloat\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004\-2008, by Stephane Arnold <stephanearnold at yahoo dot fr>)
[//000000004]: # (math::bigfloat\(n\) 2\.0\.3 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::bigfloat \- Arbitrary precision floating\-point numbers

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [INTRODUCTION](#section2)

  - [ARITHMETICS](#section3)

  - [COMPARISONS](#section4)

  - [ANALYSIS](#section5)

  - [ROUNDING](#section6)

  - [PRECISION](#section7)

  - [WHAT ABOUT TCL 8\.4 ?](#section8)

  - [NAMESPACES AND OTHER PACKAGES](#section9)

  - [EXAMPLES](#section10)

  - [Bugs, Ideas, Feedback](#section11)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require math::bigfloat ?2\.0\.3?  

[__fromstr__ *number* ?*trailingZeros*?](#1)  
[__tostr__ ?__\-nosci__? *number*](#2)  
[__fromdouble__ *double* ?*decimals*?](#3)  
[__todouble__ *number*](#4)  
[__isInt__ *number*](#5)  
[__isFloat__ *number*](#6)  
[__int2float__ *integer* ?*decimals*?](#7)  
[__add__ *x* *y*](#8)  
[__sub__ *x* *y*](#9)  
[__mul__ *x* *y*](#10)  
[__div__ *x* *y*](#11)  
[__mod__ *x* *y*](#12)  
[__abs__ *x*](#13)  
[__opp__ *x*](#14)  
[__pow__ *x* *n*](#15)  
[__iszero__ *x*](#16)  
[__[equal](\.\./\.\./\.\./\.\./index\.md\#equal)__ *x* *y*](#17)  
[__compare__ *x* *y*](#18)  
[__sqrt__ *x*](#19)  
[__[log](\.\./log/log\.md)__ *x*](#20)  
[__exp__ *x*](#21)  
[__cos__ *x*](#22)  
[__sin__ *x*](#23)  
[__tan__ *x*](#24)  
[__cotan__ *x*](#25)  
[__acos__ *x*](#26)  
[__asin__ *x*](#27)  
[__atan__ *x*](#28)  
[__cosh__ *x*](#29)  
[__sinh__ *x*](#30)  
[__tanh__ *x*](#31)  
[__[pi](\.\./\.\./\.\./\.\./index\.md\#pi)__ *n*](#32)  
[__rad2deg__ *radians*](#33)  
[__deg2rad__ *degrees*](#34)  
[__round__ *x*](#35)  
[__ceil__ *x*](#36)  
[__floor__ *x*](#37)  

# <a name='description'></a>DESCRIPTION

The bigfloat package provides arbitrary precision floating\-point math
capabilities to the Tcl language\. It is designed to work with Tcl 8\.5, but for
Tcl 8\.4 is provided an earlier version of this package\. See [WHAT ABOUT TCL 8\.4
?](#section8) for more explanations\. By convention, we will talk about the
numbers treated in this library as :

  - BigFloat for floating\-point numbers of arbitrary length\.

  - integers for arbitrary length signed integers, just as basic integers since
    Tcl 8\.5\.

Each BigFloat is an interval, namely \[*m\-d, m\+d*\], where *m* is the mantissa
and *d* the uncertainty, representing the limitation of that number's
precision\. This is why we call such mathematics *interval computations*\. Just
take an example in physics : when you measure a temperature, not all digits you
read are *significant*\. Sometimes you just cannot trust all digits \- not to
mention if doubles \(f\.p\. numbers\) can handle all these digits\. BigFloat can
handle this problem \- trusting the digits you get \- plus the ability to store
numbers with an arbitrary precision\. BigFloats are internally represented at Tcl
lists: this package provides a set of procedures operating against the internal
representation in order to :

  - perform math operations on BigFloats and \(optionnaly\) with integers\.

  - convert BigFloats from their internal representations to strings, and vice
    versa\.

# <a name='section2'></a>INTRODUCTION

  - <a name='1'></a>__fromstr__ *number* ?*trailingZeros*?

    Converts *number* into a BigFloat\. Its precision is at least the number of
    digits provided by *number*\. If the *number* contains only digits and
    eventually a minus sign, it is considered as an integer\. Subsequently, no
    conversion is done at all\.

    *trailingZeros* \- the number of zeros to append at the end of the
    floating\-point number to get more precision\. It cannot be applied to an
    integer\.

        # x and y are BigFloats : the first string contained a dot, and the second an e sign
        set x [fromstr -1.000000]
        set y [fromstr 2000e30]
        # let's see how we get integers
        set t 20000000000000
        # the old way (package 1.2) is still supported for backwards compatibility :
        set m [fromstr 10000000000]
        # but we do not need fromstr for integers anymore
        set n -39
        # t, m and n are integers

    The *number*'s last digit is considered by the procedure to be true at
    \+/\-1, For example, 1\.00 is the interval \[0\.99, 1\.01\], and 0\.43 the interval
    \[0\.42, 0\.44\]\. The Pi constant may be approximated by the number "3\.1415"\.
    This string could be considered as the interval \[3\.1414 , 3\.1416\] by
    __fromstr__\. So, when you mean 1\.0 as a double, you may have to write
    1\.000000 to get enough precision\. To learn more about this subject, see
    [PRECISION](#section7)\.

    For example :

        set x [fromstr 1.0000000000]
        # the next line does the same, but smarter
        set y [fromstr 1. 10]

  - <a name='2'></a>__tostr__ ?__\-nosci__? *number*

    Returns a string form of a BigFloat, in which all digits are exacts\. *All
    exact digits* means a rounding may occur, for example to zero, if the
    uncertainty interval does not clearly show the true digits\. *number* may
    be an integer, causing the command to return exactly the input argument\.
    With the __\-nosci__ option, the number returned is never shown in
    scientific notation, i\.e\. not like '3\.4523e\+5' but like '345230\.'\.

        puts [tostr [fromstr 0.99999]] ;# 1.0000
        puts [tostr [fromstr 1.00001]] ;# 1.0000
        puts [tostr [fromstr 0.002]] ;# 0.e-2

    See [PRECISION](#section7) for that matter\. See also __iszero__ for
    how to detect zeros, which is useful when performing a division\.

  - <a name='3'></a>__fromdouble__ *double* ?*decimals*?

    Converts a double \(a simple floating\-point value\) to a BigFloat, with
    exactly *decimals* digits\. Without the *decimals* argument, it behaves
    like __fromstr__\. Here, the only important feature you might care of is
    the ability to create BigFloats with a fixed number of *decimals*\.

        tostr [fromstr 1.111 4]
        # returns : 1.111000 (3 zeros)
        tostr [fromdouble 1.111 4]
        # returns : 1.111

  - <a name='4'></a>__todouble__ *number*

    Returns a double, that may be used in *expr*, from a BigFloat\.

  - <a name='5'></a>__isInt__ *number*

    Returns 1 if *number* is an integer, 0 otherwise\.

  - <a name='6'></a>__isFloat__ *number*

    Returns 1 if *number* is a BigFloat, 0 otherwise\.

  - <a name='7'></a>__int2float__ *integer* ?*decimals*?

    Converts an integer to a BigFloat with *decimals* trailing zeros\. The
    default, and minimal, number of *decimals* is 1\. When converting back to
    string, one decimal is lost:

        set n 10
        set x [int2float $n]; # like fromstr 10.0
        puts [tostr $x]; # prints "10."
        set x [int2float $n 3]; # like fromstr 10.000
        puts [tostr $x]; # prints "10.00"

# <a name='section3'></a>ARITHMETICS

  - <a name='8'></a>__add__ *x* *y*

  - <a name='9'></a>__sub__ *x* *y*

  - <a name='10'></a>__mul__ *x* *y*

    Return the sum, difference and product of *x* by *y*\. *x* \- may be
    either a BigFloat or an integer *y* \- may be either a BigFloat or an
    integer When both are integers, these commands behave like __expr__\.

  - <a name='11'></a>__div__ *x* *y*

  - <a name='12'></a>__mod__ *x* *y*

    Return the quotient and the rest of *x* divided by *y*\. Each argument
    \(*x* and *y*\) can be either a BigFloat or an integer, but you cannot
    divide an integer by a BigFloat Divide by zero throws an error\.

  - <a name='13'></a>__abs__ *x*

    Returns the absolute value of *x*

  - <a name='14'></a>__opp__ *x*

    Returns the opposite of *x*

  - <a name='15'></a>__pow__ *x* *n*

    Returns *x* taken to the *n*th power\. It only works if *n* is an
    integer\. *x* might be a BigFloat or an integer\.

# <a name='section4'></a>COMPARISONS

  - <a name='16'></a>__iszero__ *x*

    Returns 1 if *x* is :

      * a BigFloat close enough to zero to raise "divide by zero"\.

      * the integer 0\.

    See here how numbers that are close to zero are converted to strings:

        tostr [fromstr 0.001] ; # -> 0.e-2
        tostr [fromstr 0.000000] ; # -> 0.e-5
        tostr [fromstr -0.000001] ; # -> 0.e-5
        tostr [fromstr 0.0] ; # -> 0.
        tostr [fromstr 0.002] ; # -> 0.e-2

        set a [fromstr 0.002] ; # uncertainty interval : 0.001, 0.003
        tostr  $a ; # 0.e-2
        iszero $a ; # false

        set a [fromstr 0.001] ; # uncertainty interval : 0.000, 0.002
        tostr  $a ; # 0.e-2
        iszero $a ; # true

  - <a name='17'></a>__[equal](\.\./\.\./\.\./\.\./index\.md\#equal)__ *x* *y*

    Returns 1 if *x* and *y* are equal, 0 elsewhere\.

  - <a name='18'></a>__compare__ *x* *y*

    Returns 0 if both BigFloat arguments are equal, 1 if *x* is greater than
    *y*, and \-1 if *x* is lower than *y*\. You would not be able to compare
    an integer to a BigFloat : the operands should be both BigFloats, or both
    integers\.

# <a name='section5'></a>ANALYSIS

  - <a name='19'></a>__sqrt__ *x*

  - <a name='20'></a>__[log](\.\./log/log\.md)__ *x*

  - <a name='21'></a>__exp__ *x*

  - <a name='22'></a>__cos__ *x*

  - <a name='23'></a>__sin__ *x*

  - <a name='24'></a>__tan__ *x*

  - <a name='25'></a>__cotan__ *x*

  - <a name='26'></a>__acos__ *x*

  - <a name='27'></a>__asin__ *x*

  - <a name='28'></a>__atan__ *x*

  - <a name='29'></a>__cosh__ *x*

  - <a name='30'></a>__sinh__ *x*

  - <a name='31'></a>__tanh__ *x*

    The above functions return, respectively, the following : square root,
    logarithm, exponential, cosine, sine, tangent, cotangent, arc cosine, arc
    sine, arc tangent, hyperbolic cosine, hyperbolic sine, hyperbolic tangent,
    of a BigFloat named *x*\.

  - <a name='32'></a>__[pi](\.\./\.\./\.\./\.\./index\.md\#pi)__ *n*

    Returns a BigFloat representing the Pi constant with *n* digits after the
    dot\. *n* is a positive integer\.

  - <a name='33'></a>__rad2deg__ *radians*

  - <a name='34'></a>__deg2rad__ *degrees*

    *radians* \- angle expressed in radians \(BigFloat\)

    *degrees* \- angle expressed in degrees \(BigFloat\)

    Convert an angle from radians to degrees, and *vice versa*\.

# <a name='section6'></a>ROUNDING

  - <a name='35'></a>__round__ *x*

  - <a name='36'></a>__ceil__ *x*

  - <a name='37'></a>__floor__ *x*

    The above functions return the *x* BigFloat, rounded like with the same
    mathematical function in *expr*, and returns it as an integer\.

# <a name='section7'></a>PRECISION

How do conversions work with precision ?

  - When a BigFloat is converted from string, the internal representation holds
    its uncertainty as 1 at the level of the last digit\.

  - During computations, the uncertainty of each result is internally computed
    the closest to the reality, thus saving the memory used\.

  - When converting back to string, the digits that are printed are not subject
    to uncertainty\. However, some rounding is done, as not doing so causes
    severe problems\.

Uncertainties are kept in the internal representation of the number ; it is
recommended to use __tostr__ only for outputting data \(on the screen or in a
file\), and NEVER call __fromstr__ with the result of __tostr__\. It is
better to always keep operands in their internal representation\. Due to the
internals of this library, the uncertainty interval may be slightly wider than
expected, but this should not cause false digits\.

Now you may ask this question : What precision am I going to get after calling
add, sub, mul or div? First you set a number from the string representation and,
by the way, its uncertainty is set:

    set a [fromstr 1.230]
    # $a belongs to [1.229, 1.231]
    set a [fromstr 1.000]
    # $a belongs to [0.999, 1.001]
    # $a has a relative uncertainty of 0.1% : 0.001(the uncertainty)/1.000(the medium value)

The uncertainty of the sum, or the difference, of two numbers, is the sum of
their respective uncertainties\.

    set a [fromstr 1.230]
    set b [fromstr 2.340]
    set sum [add $a $b]]
    # the result is : [3.568, 3.572] (the last digit is known with an uncertainty of 2)
    tostr $sum ; # 3.57

But when, for example, we add or substract an integer to a BigFloat, the
relative uncertainty of the result is unchanged\. So it is desirable not to
convert integers to BigFloats:

    set a [fromstr 0.999999999]
    # now something dangerous
    set b [fromstr 2.000]
    # the result has only 3 digits
    tostr [add $a $b]

    # how to keep precision at its maximum
    puts [tostr [add $a 2]]

For multiplication and division, the relative uncertainties of the product or
the quotient, is the sum of the relative uncertainties of the operands\. Take
care of division by zero : check each divider with __iszero__\.

    set num [fromstr 4.00]
    set denom [fromstr 0.01]

    puts [iszero $denom];# true
    set quotient [div $num $denom];# error : divide by zero

    # opposites of our operands
    puts [compare $num [opp $num]]; # 1
    puts [compare $denom [opp $denom]]; # 0 !!!
    # No suprise ! 0 and its opposite are the same...

Effects of the precision of a number considered equal to zero to the cos
function:

    puts [tostr [cos [fromstr 0. 10]]]; # -> 1.000000000
    puts [tostr [cos [fromstr 0. 5]]]; # -> 1.0000
    puts [tostr [cos [fromstr 0e-10]]]; # -> 1.000000000
    puts [tostr [cos [fromstr 1e-10]]]; # -> 1.000000000

BigFloats with different internal representations may be converted to the same
string\.

For most analysis functions \(cosine, square root, logarithm, etc\.\), determining
the precision of the result is difficult\. It seems however that in many cases,
the loss of precision in the result is of one or two digits\. There are some
exceptions : for example,

    tostr [exp [fromstr 100.0 10]]
    # returns : 2.688117142e+43 which has only 10 digits of precision, although the entry
    # has 14 digits of precision.

# <a name='section8'></a>WHAT ABOUT TCL 8\.4 ?

If your setup do not provide Tcl 8\.5 but supports 8\.4, the package can still be
loaded, switching back to *math::bigfloat* 1\.2\. Indeed, an important function
introduced in Tcl 8\.5 is required \- the ability to handle bignums, that we can
do with __expr__\. Before 8\.5, this ability was provided by several packages,
including the pure\-Tcl *math::bignum* package provided by *tcllib*\. In this
case, all you need to know, is that arguments to the commands explained here,
are expected to be in their internal representation\. So even with integers, you
will need to call __fromstr__ and __tostr__ in order to convert them
between string and internal representations\.

    #
    # with Tcl 8.5
    # ============
    set a [pi 20]
    # round returns an integer and 'everything is a string' applies to integers
    # whatever big they are
    puts [round [mul $a 10000000000]]
    #
    # the same with Tcl 8.4
    # =====================
    set a [pi 20]
    # bignums (arbitrary length integers) need a conversion hook
    set b [fromstr 10000000000]
    # round returns a bignum:
    # before printing it, we need to convert it with 'tostr'
    puts [tostr [round [mul $a $b]]]

# <a name='section9'></a>NAMESPACES AND OTHER PACKAGES

We have not yet discussed about namespaces because we assumed that you had
imported public commands into the global namespace, like this:

    namespace import ::math::bigfloat::*

If you matter much about avoiding names conflicts, I considere it should be
resolved by the following :

    package require math::bigfloat
    # beware: namespace ensembles are not available in Tcl 8.4
    namespace eval ::math::bigfloat {namespace ensemble create -command ::bigfloat}
    # from now, the bigfloat command takes as subcommands all original math::bigfloat::* commands
    set a [bigfloat sub [bigfloat fromstr 2.000] [bigfloat fromstr 0.530]]
    puts [bigfloat tostr $a]

# <a name='section10'></a>EXAMPLES

Guess what happens when you are doing some astronomy\. Here is an example :

    # convert acurrate angles with a millisecond-rated accuracy
    proc degree-angle {degrees minutes seconds milliseconds} {
        set result 0
        set div 1
        foreach factor {1 1000 60 60} var [list $milliseconds $seconds $minutes $degrees] {
            # we convert each entry var into milliseconds
            set div [expr {$div*$factor}]
            incr result [expr {$var*$div}]
        }
        return [div [int2float $result] $div]
    }
    # load the package
    package require math::bigfloat
    namespace import ::math::bigfloat::*
    # work with angles : a standard formula for navigation (taking bearings)
    set angle1 [deg2rad [degree-angle 20 30 40   0]]
    set angle2 [deg2rad [degree-angle 21  0 50 500]]
    set opposite3 [deg2rad [degree-angle 51  0 50 500]]
    set sinProduct [mul [sin $angle1] [sin $angle2]]
    set cosProduct [mul [cos $angle1] [cos $angle2]]
    set angle3 [asin [add [mul $sinProduct [cos $opposite3]] $cosProduct]]
    puts "angle3 : [tostr [rad2deg $angle3]]"

# <a name='section11'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: bignum :: float*
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

[computations](\.\./\.\./\.\./\.\./index\.md\#computations),
[floating\-point](\.\./\.\./\.\./\.\./index\.md\#floating\_point),
[interval](\.\./\.\./\.\./\.\./index\.md\#interval),
[math](\.\./\.\./\.\./\.\./index\.md\#math),
[multiprecision](\.\./\.\./\.\./\.\./index\.md\#multiprecision),
[tcl](\.\./\.\./\.\./\.\./index\.md\#tcl)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004\-2008, by Stephane Arnold <stephanearnold at yahoo dot fr>
