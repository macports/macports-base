
[//000000001]: # (math::calculus::romberg \- Tcl Math Library)
[//000000002]: # (Generated from file 'romberg\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004 Kevin B\. Kenny <kennykb@acm\.org>\. All rights reserved\. Redistribution permitted under the terms of the Open Publication License <http://www\.opencontent\.org/openpub/>)
[//000000004]: # (math::calculus::romberg\(n\) 0\.6 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::calculus::romberg \- Romberg integration

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PROCEDURES](#section2)

  - [PARAMETERS](#section3)

  - [OPTIONS](#section4)

  - [DESCRIPTION](#section5)

  - [IMPROPER INTEGRALS](#section6)

  - [OTHER CHANGES OF VARIABLE](#section7)

  - [Bugs, Ideas, Feedback](#section8)

  - [See Also](#seealso)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require math::calculus 0\.6  

[__::math::calculus::romberg__ *f* *a* *b* ?*\-option value*\.\.\.?](#1)  
[__::math::calculus::romberg\_infinity__ *f* *a* *b* ?*\-option value*\.\.\.?](#2)  
[__::math::calculus::romberg\_sqrtSingLower__ *f* *a* *b* ?*\-option value*\.\.\.?](#3)  
[__::math::calculus::romberg\_sqrtSingUpper__ *f* *a* *b* ?*\-option value*\.\.\.?](#4)  
[__::math::calculus::romberg\_powerLawLower__ *gamma* *f* *a* *b* ?*\-option value*\.\.\.?](#5)  
[__::math::calculus::romberg\_powerLawUpper__ *gamma* *f* *a* *b* ?*\-option value*\.\.\.?](#6)  
[__::math::calculus::romberg\_expLower__ *f* *a* *b* ?*\-option value*\.\.\.?](#7)  
[__::math::calculus::romberg\_expUpper__ *f* *a* *b* ?*\-option value*\.\.\.?](#8)  

# <a name='description'></a>DESCRIPTION

The __romberg__ procedures in the __[math::calculus](calculus\.md)__
package perform numerical integration of a function of one variable\. They are
intended to be of "production quality" in that they are robust, precise, and
reasonably efficient in terms of the number of function evaluations\.

# <a name='section2'></a>PROCEDURES

The following procedures are available for Romberg integration:

  - <a name='1'></a>__::math::calculus::romberg__ *f* *a* *b* ?*\-option value*\.\.\.?

    Integrates an analytic function over a given interval\.

  - <a name='2'></a>__::math::calculus::romberg\_infinity__ *f* *a* *b* ?*\-option value*\.\.\.?

    Integrates an analytic function over a half\-infinite interval\.

  - <a name='3'></a>__::math::calculus::romberg\_sqrtSingLower__ *f* *a* *b* ?*\-option value*\.\.\.?

    Integrates a function that is expected to be analytic over an interval
    except for the presence of an inverse square root singularity at the lower
    limit\.

  - <a name='4'></a>__::math::calculus::romberg\_sqrtSingUpper__ *f* *a* *b* ?*\-option value*\.\.\.?

    Integrates a function that is expected to be analytic over an interval
    except for the presence of an inverse square root singularity at the upper
    limit\.

  - <a name='5'></a>__::math::calculus::romberg\_powerLawLower__ *gamma* *f* *a* *b* ?*\-option value*\.\.\.?

    Integrates a function that is expected to be analytic over an interval
    except for the presence of a power law singularity at the lower limit\.

  - <a name='6'></a>__::math::calculus::romberg\_powerLawUpper__ *gamma* *f* *a* *b* ?*\-option value*\.\.\.?

    Integrates a function that is expected to be analytic over an interval
    except for the presence of a power law singularity at the upper limit\.

  - <a name='7'></a>__::math::calculus::romberg\_expLower__ *f* *a* *b* ?*\-option value*\.\.\.?

    Integrates an exponentially growing function; the lower limit of the region
    of integration may be arbitrarily large and negative\.

  - <a name='8'></a>__::math::calculus::romberg\_expUpper__ *f* *a* *b* ?*\-option value*\.\.\.?

    Integrates an exponentially decaying function; the upper limit of the region
    of integration may be arbitrarily large\.

# <a name='section3'></a>PARAMETERS

  - *f*

    Function to integrate\. Must be expressed as a single Tcl command, to which
    will be appended a single argument, specifically, the abscissa at which the
    function is to be evaluated\. The first word of the command will be processed
    with __namespace which__ in the caller's scope prior to any evaluation\.
    Given this processing, the command may local to the calling namespace rather
    than needing to be global\.

  - *a*

    Lower limit of the region of integration\.

  - *b*

    Upper limit of the region of integration\. For the
    __romberg\_sqrtSingLower__, __romberg\_sqrtSingUpper__,
    __romberg\_powerLawLower__, __romberg\_powerLawUpper__,
    __romberg\_expLower__, and __romberg\_expUpper__ procedures, the lower
    limit must be strictly less than the upper\. For the other procedures, the
    limits may appear in either order\.

  - *gamma*

    Power to use for a power law singularity; see section [IMPROPER
    INTEGRALS](#section6) for details\.

# <a name='section4'></a>OPTIONS

  - __\-abserror__ *epsilon*

    Requests that the integration machinery proceed at most until the estimated
    absolute error of the integral is less than *epsilon*\. The error may be
    seriously over\- or underestimated if the function \(or any of its
    derivatives\) contains singularities; see section [IMPROPER
    INTEGRALS](#section6) for details\. Default is 1\.0e\-08\.

  - __\-relerror__ *epsilon*

    Requests that the integration machinery proceed at most until the estimated
    relative error of the integral is less than *epsilon*\. The error may be
    seriously over\- or underestimated if the function \(or any of its
    derivatives\) contains singularities; see section [IMPROPER
    INTEGRALS](#section6) for details\. Default is 1\.0e\-06\.

  - __\-maxiter__ *m*

    Requests that integration terminate after at most *n* triplings of the
    number of evaluations performed\. In other words, given *n* for
    __\-maxiter__, the integration machinery will make at most 3\*\**n*
    evaluations of the function\. Default is 14, corresponding to a limit
    approximately 4\.8 million evaluations\. \(Well\-behaved functions will seldom
    require more than a few hundred evaluations\.\)

  - __\-degree__ *d*

    Requests that an extrapolating polynomial of degree *d* be used in Romberg
    integration; see section [DESCRIPTION](#section5) for details\. Default
    is 4\. Can be at most *m*\-1\.

# <a name='section5'></a>DESCRIPTION

The __romberg__ procedure performs Romberg integration using the modified
midpoint rule\. Romberg integration is an iterative process\. At the first step,
the function is evaluated at the midpoint of the region of integration, and the
value is multiplied by the width of the interval for the coarsest possible
estimate\. At the second step, the interval is divided into three parts, and the
function is evaluated at the midpoint of each part; the sum of the values is
multiplied by three\. At the third step, nine parts are used, at the fourth
twenty\-seven, and so on, tripling the number of subdivisions at each step\.

Once the interval has been divided at least *d* times, a polynomial is fitted
to the integrals estimated in the last *d*\+1 divisions\. The integrals are
considered to be a function of the square of the width of the subintervals \(any
good numerical analysis text will discuss this process under "Romberg
integration"\)\. The polynomial is extrapolated to a step size of zero, computing
a value for the integral and an estimate of the error\.

This process will be well\-behaved only if the function is analytic over the
region of integration; there may be removable singularities at either end of the
region provided that the limit of the function \(and of all its derivatives\)
exists as the ends are approached\. Thus, __romberg__ may be used to
integrate a function like f\(x\)=sin\(x\)/x over an interval beginning or ending at
zero\.

Note that __romberg__ will either fail to converge or else return incorrect
error estimates if the function, or any of its derivatives, has a singularity
anywhere in the region of integration \(except for the case mentioned above\)\.
Care must be used, therefore, in integrating a function like 1/\(1\-x\*\*2\) to avoid
the places where the derivative is singular\.

# <a name='section6'></a>IMPROPER INTEGRALS

Romberg integration is also useful for integrating functions over half\-infinite
intervals or functions that have singularities\. The trick is to make a change of
variable to eliminate the singularity, and to put the singularity at one end or
the other of the region of integration\. The
__[math::calculus](calculus\.md)__ package supplies a number of
__romberg__ procedures to deal with the commoner cases\.

  - __romberg\_infinity__

    Integrates a function over a half\-infinite interval; either *a* or *b*
    may be infinite\. *a* and *b* must be of the same sign; if you need to
    integrate across the axis, say, from a negative value to positive infinity,
    use __romberg__ to integrate from the negative value to a small positive
    value, and then __romberg\_infinity__ to integrate from the positive
    value to positive infinity\. The __romberg\_infinity__ procedure works by
    making the change of variable u=1/x, so that the integral from a to b of
    f\(x\) is evaluated as the integral from 1/a to 1/b of f\(1/u\)/u\*\*2\.

  - __romberg\_powerLawLower__ and __romberg\_powerLawUpper__

    Integrate a function that has an integrable power law singularity at either
    the lower or upper bound of the region of integration \(or has a derivative
    with a power law singularity there\)\. These procedures take a first
    parameter, *gamma*, which gives the power law\. The function or its first
    derivative are presumed to diverge as \(x\-*a*\)\*\*\(\-*gamma*\) or
    \(*b*\-x\)\*\*\(\-*gamma*\)\. *gamma* must be greater than zero and less than
    1\.

    These procedures are useful not only in integrating functions that go to
    infinity at one end of the region of integration, but also functions whose
    derivatives do not exist at the end of the region\. For instance, integrating
    f\(x\)=pow\(x,0\.25\) with the origin as one end of the region will result in the
    __romberg__ procedure greatly underestimating the error in the integral\.
    The problem can be fixed by observing that the first derivative of f\(x\),
    f'\(x\)=x\*\*\(\-3/4\)/4, goes to infinity at the origin\. Integrating using
    __romberg\_powerLawLower__ with *gamma* set to 0\.75 gives much more
    orderly convergence\.

    These procedures operate by making the change of variable u=\(x\-a\)\*\*\(1\-gamma\)
    \(__romberg\_powerLawLower__\) or u=\(b\-x\)\*\*\(1\-gamma\)
    \(__romberg\_powerLawUpper__\)\.

    To summarize the meaning of gamma:

      * If f\(x\) ~ x\*\*\(\-a\) \(0 < a < 1\), use gamma = a

      * If f'\(x\) ~ x\*\*\(\-b\) \(0 < b < 1\), use gamma = b

  - __romberg\_sqrtSingLower__ and __romberg\_sqrtSingUpper__

    These procedures behave identically to __romberg\_powerLawLower__ and
    __romberg\_powerLawUpper__ for the common case of *gamma*=0\.5; that is,
    they integrate a function with an inverse square root singularity at one end
    of the interval\. They have a simpler implementation involving square roots
    rather than arbitrary powers\.

  - __romberg\_expLower__ and __romberg\_expUpper__

    These procedures are for integrating a function that grows or decreases
    exponentially over a half\-infinite interval\. __romberg\_expLower__
    handles exponentially growing functions, and allows the lower limit of
    integration to be an arbitrarily large negative number\.
    __romberg\_expUpper__ handles exponentially decaying functions and allows
    the upper limit of integration to be an arbitrary large positive number\. The
    functions make the change of variable u=exp\(\-x\) and u=exp\(x\) respectively\.

# <a name='section7'></a>OTHER CHANGES OF VARIABLE

If you need an improper integral other than the ones listed here, a change of
variable can be written in very few lines of Tcl\. Because the Tcl coding that
does it is somewhat arcane, we offer a worked example here\.

Let's say that the function that we want to integrate is f\(x\)=exp\(x\)/sqrt\(1\-x\*x\)
\(not a very natural function, but a good example\), and we want to integrate it
over the interval \(\-1,1\)\. The denominator falls to zero at both ends of the
interval\. We wish to make a change of variable from x to u so that
dx/sqrt\(1\-x\*\*2\) maps to du\. Choosing x=sin\(u\), we can find that dx=cos\(u\)\*du,
and sqrt\(1\-x\*\*2\)=cos\(u\)\. The integral from a to b of f\(x\) is the integral from
asin\(a\) to asin\(b\) of f\(sin\(u\)\)\*cos\(u\)\.

We can make a function __g__ that accepts an arbitrary function __f__
and the parameter u, and computes this new integrand\.

    proc g { f u } {
        set x [expr { sin($u) }]
        set cmd $f; lappend cmd $x; set y [eval $cmd]
        return [expr { $y / cos($u) }]
    }

Now integrating __f__ from *a* to *b* is the same as integrating
__g__ from *asin\(a\)* to *asin\(b\)*\. It's a little tricky to get __f__
consistently evaluated in the caller's scope; the following procedure does it\.

    proc romberg_sine { f a b args } {
        set f [lreplace $f 0 0 [uplevel 1 [list namespace which [lindex $f 0]]]]
        set f [list g $f]
        return [eval [linsert $args 0 romberg $f [expr { asin($a) }] [expr { asin($b) }]]]
    }

This __romberg\_sine__ procedure will do any function with sqrt\(1\-x\*x\) in the
denominator\. Our sample function is f\(x\)=exp\(x\)/sqrt\(1\-x\*x\):

    proc f { x } {
        expr { exp($x) / sqrt( 1. - $x*$x ) }
    }

Integrating it is a matter of applying __romberg\_sine__ as we would any of
the other __romberg__ procedures:

    foreach { value error } [romberg_sine f -1.0 1.0] break
    puts [format "integral is %.6g +/- %.6g" $value $error]

    integral is 3.97746 +/- 2.3557e-010

# <a name='section8'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: calculus* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[math::calculus](calculus\.md), [math::interpolate](interpolate\.md)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004 Kevin B\. Kenny <kennykb@acm\.org>\. All rights reserved\. Redistribution permitted under the terms of the Open Publication License <http://www\.opencontent\.org/openpub/>
