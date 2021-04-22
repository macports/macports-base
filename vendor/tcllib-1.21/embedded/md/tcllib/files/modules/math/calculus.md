
[//000000001]: # (math::calculus \- Tcl Math Library)
[//000000002]: # (Generated from file 'calculus\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002,2003,2004 Arjen Markus)
[//000000004]: # (math::calculus\(n\) 0\.8\.2 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::calculus \- Integration and ordinary differential equations

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PROCEDURES](#section2)

  - [EXAMPLES](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require math::calculus 0\.8\.2  

[__::math::calculus::integral__ *begin* *end* *nosteps* *func*](#1)  
[__::math::calculus::integralExpr__ *begin* *end* *nosteps* *expression*](#2)  
[__::math::calculus::integral2D__ *xinterval* *yinterval* *func*](#3)  
[__::math::calculus::integral2D\_accurate__ *xinterval* *yinterval* *func*](#4)  
[__::math::calculus::integral3D__ *xinterval* *yinterval* *zinterval* *func*](#5)  
[__::math::calculus::integral3D\_accurate__ *xinterval* *yinterval* *zinterval* *func*](#6)  
[__::math::calculus::qk15__ *xstart* *xend* *func* *nosteps*](#7)  
[__::math::calculus::qk15\_detailed__ *xstart* *xend* *func* *nosteps*](#8)  
[__::math::calculus::eulerStep__ *t* *tstep* *xvec* *func*](#9)  
[__::math::calculus::heunStep__ *t* *tstep* *xvec* *func*](#10)  
[__::math::calculus::rungeKuttaStep__ *t* *tstep* *xvec* *func*](#11)  
[__::math::calculus::boundaryValueSecondOrder__ *coeff\_func* *force\_func* *leftbnd* *rightbnd* *nostep*](#12)  
[__::math::calculus::solveTriDiagonal__ *acoeff* *bcoeff* *ccoeff* *dvalue*](#13)  
[__::math::calculus::newtonRaphson__ *func* *deriv* *initval*](#14)  
[__::math::calculus::newtonRaphsonParameters__ *maxiter* *tolerance*](#15)  
[__::math::calculus::regula\_falsi__ *f* *xb* *xe* *eps*](#16)  

# <a name='description'></a>DESCRIPTION

This package implements several simple mathematical algorithms:

  - The integration of a function over an interval

  - The numerical integration of a system of ordinary differential equations\.

  - Estimating the root\(s\) of an equation of one variable\.

The package is fully implemented in Tcl\. No particular attention has been paid
to the accuracy of the calculations\. Instead, well\-known algorithms have been
used in a straightforward manner\.

This document describes the procedures and explains their usage\.

# <a name='section2'></a>PROCEDURES

This package defines the following public procedures:

  - <a name='1'></a>__::math::calculus::integral__ *begin* *end* *nosteps* *func*

    Determine the integral of the given function using the Simpson rule\. The
    interval for the integration is \[*begin*, *end*\]\. The remaining
    arguments are:

      * *nosteps*

        Number of steps in which the interval is divided\.

      * *func*

        Function to be integrated\. It should take one single argument\.

  - <a name='2'></a>__::math::calculus::integralExpr__ *begin* *end* *nosteps* *expression*

    Similar to the previous proc, this one determines the integral of the given
    *expression* using the Simpson rule\. The interval for the integration is
    \[*begin*, *end*\]\. The remaining arguments are:

      * *nosteps*

        Number of steps in which the interval is divided\.

      * *expression*

        Expression to be integrated\. It should use the variable "x" as the only
        variable \(the "integrate"\)

  - <a name='3'></a>__::math::calculus::integral2D__ *xinterval* *yinterval* *func*

  - <a name='4'></a>__::math::calculus::integral2D\_accurate__ *xinterval* *yinterval* *func*

    The commands __integral2D__ and __integral2D\_accurate__ calculate
    the integral of a function of two variables over the rectangle given by the
    first two arguments, each a list of three items, the start and stop interval
    for the variable and the number of steps\.

    The command __integral2D__ evaluates the function at the centre of each
    rectangle, whereas the command __integral2D\_accurate__ uses a four\-point
    quadrature formula\. This results in an exact integration of polynomials of
    third degree or less\.

    The function must take two arguments and return the function value\.

  - <a name='5'></a>__::math::calculus::integral3D__ *xinterval* *yinterval* *zinterval* *func*

  - <a name='6'></a>__::math::calculus::integral3D\_accurate__ *xinterval* *yinterval* *zinterval* *func*

    The commands __integral3D__ and __integral3D\_accurate__ are the
    three\-dimensional equivalent of __integral2D__ and
    __integral3D\_accurate__\. The function *func* takes three arguments and
    is integrated over the block in 3D space given by three intervals\.

  - <a name='7'></a>__::math::calculus::qk15__ *xstart* *xend* *func* *nosteps*

    Determine the integral of the given function using the Gauss\-Kronrod 15
    points quadrature rule\. The returned value is the estimate of the integral
    over the interval \[*xstart*, *xend*\]\. The remaining arguments are:

      * *func*

        Function to be integrated\. It should take one single argument\.

      * ?nosteps?

        Number of steps in which the interval is divided\. Defaults to 1\.

  - <a name='8'></a>__::math::calculus::qk15\_detailed__ *xstart* *xend* *func* *nosteps*

    Determine the integral of the given function using the Gauss\-Kronrod 15
    points quadrature rule\. The interval for the integration is \[*xstart*,
    *xend*\]\. The procedure returns a list of four values:

      * The estimate of the integral over the specified interval \(I\)\.

      * An estimate of the absolute error in I\.

      * The estimate of the integral of the absolute value of the function over
        the interval\.

      * The estimate of the integral of the absolute value of the function minus
        its mean over the interval\.

    The remaining arguments are:

      * *func*

        Function to be integrated\. It should take one single argument\.

      * ?nosteps?

        Number of steps in which the interval is divided\. Defaults to 1\.

  - <a name='9'></a>__::math::calculus::eulerStep__ *t* *tstep* *xvec* *func*

    Set a single step in the numerical integration of a system of differential
    equations\. The method used is Euler's\.

      * *t*

        Value of the independent variable \(typically time\) at the beginning of
        the step\.

      * *tstep*

        Step size for the independent variable\.

      * *xvec*

        List \(vector\) of dependent values

      * *func*

        Function of t and the dependent values, returning a list of the
        derivatives of the dependent values\. \(The lengths of xvec and the return
        value of "func" must match\)\.

  - <a name='10'></a>__::math::calculus::heunStep__ *t* *tstep* *xvec* *func*

    Set a single step in the numerical integration of a system of differential
    equations\. The method used is Heun's\.

      * *t*

        Value of the independent variable \(typically time\) at the beginning of
        the step\.

      * *tstep*

        Step size for the independent variable\.

      * *xvec*

        List \(vector\) of dependent values

      * *func*

        Function of t and the dependent values, returning a list of the
        derivatives of the dependent values\. \(The lengths of xvec and the return
        value of "func" must match\)\.

  - <a name='11'></a>__::math::calculus::rungeKuttaStep__ *t* *tstep* *xvec* *func*

    Set a single step in the numerical integration of a system of differential
    equations\. The method used is Runge\-Kutta 4th order\.

      * *t*

        Value of the independent variable \(typically time\) at the beginning of
        the step\.

      * *tstep*

        Step size for the independent variable\.

      * *xvec*

        List \(vector\) of dependent values

      * *func*

        Function of t and the dependent values, returning a list of the
        derivatives of the dependent values\. \(The lengths of xvec and the return
        value of "func" must match\)\.

  - <a name='12'></a>__::math::calculus::boundaryValueSecondOrder__ *coeff\_func* *force\_func* *leftbnd* *rightbnd* *nostep*

    Solve a second order linear differential equation with boundary values at
    two sides\. The equation has to be of the form \(the "conservative" form\):

        d      dy     d
        -- A(x)--  +  -- B(x)y + C(x)y  =  D(x)
        dx     dx     dx

    Ordinarily, such an equation would be written as:

            d2y        dy
        a(x)---  + b(x)-- + c(x) y  =  D(x)
            dx2        dx

    The first form is easier to discretise \(by integrating over a finite volume\)
    than the second form\. The relation between the two forms is fairly
    straightforward:

        A(x)  =  a(x)
        B(x)  =  b(x) - a'(x)
        C(x)  =  c(x) - B'(x)  =  c(x) - b'(x) + a''(x)

    Because of the differentiation, however, it is much easier to ask the user
    to provide the functions A, B and C directly\.

      * *coeff\_func*

        Procedure returning the three coefficients \(A, B, C\) of the equation,
        taking as its one argument the x\-coordinate\.

      * *force\_func*

        Procedure returning the right\-hand side \(D\) as a function of the
        x\-coordinate\.

      * *leftbnd*

        A list of two values: the x\-coordinate of the left boundary and the
        value at that boundary\.

      * *rightbnd*

        A list of two values: the x\-coordinate of the right boundary and the
        value at that boundary\.

      * *nostep*

        Number of steps by which to discretise the interval\. The procedure
        returns a list of x\-coordinates and the approximated values of the
        solution\.

  - <a name='13'></a>__::math::calculus::solveTriDiagonal__ *acoeff* *bcoeff* *ccoeff* *dvalue*

    Solve a system of linear equations Ax = b with A a tridiagonal matrix\.
    Returns the solution as a list\.

      * *acoeff*

        List of values on the lower diagonal

      * *bcoeff*

        List of values on the main diagonal

      * *ccoeff*

        List of values on the upper diagonal

      * *dvalue*

        List of values on the righthand\-side

  - <a name='14'></a>__::math::calculus::newtonRaphson__ *func* *deriv* *initval*

    Determine the root of an equation given by

        func(x) = 0

    using the method of Newton\-Raphson\. The procedure takes the following
    arguments:

      * *func*

        Procedure that returns the value the function at x

      * *deriv*

        Procedure that returns the derivative of the function at x

      * *initval*

        Initial value for x

  - <a name='15'></a>__::math::calculus::newtonRaphsonParameters__ *maxiter* *tolerance*

    Set the numerical parameters for the Newton\-Raphson method:

      * *maxiter*

        Maximum number of iteration steps \(defaults to 20\)

      * *tolerance*

        Relative precision \(defaults to 0\.001\)

  - <a name='16'></a>__::math::calculus::regula\_falsi__ *f* *xb* *xe* *eps*

    Return an estimate of the zero or one of the zeros of the function contained
    in the interval \[xb,xe\]\. The error in this estimate is of the order of
    eps\*abs\(xe\-xb\), the actual error may be slightly larger\.

    The method used is the so\-called *regula falsi* or *false position*
    method\. It is a straightforward implementation\. The method is robust, but
    requires that the interval brackets a zero or at least an uneven number of
    zeros, so that the value of the function at the start has a different sign
    than the value at the end\.

    In contrast to Newton\-Raphson there is no need for the computation of the
    function's derivative\.

      * command *f*

        Name of the command that evaluates the function for which the zero is to
        be returned

      * float *xb*

        Start of the interval in which the zero is supposed to lie

      * float *xe*

        End of the interval

      * float *eps*

        Relative allowed error \(defaults to 1\.0e\-4\)

*Notes:*

Several of the above procedures take the *names* of procedures as arguments\.
To avoid problems with the *visibility* of these procedures, the
fully\-qualified name of these procedures is determined inside the calculus
routines\. For the user this has only one consequence: the named procedure must
be visible in the calling procedure\. For instance:

    namespace eval ::mySpace {
       namespace export calcfunc
       proc calcfunc { x } { return $x }
    }
    #
    # Use a fully-qualified name
    #
    namespace eval ::myCalc {
       proc detIntegral { begin end } {
          return [integral $begin $end 100 ::mySpace::calcfunc]
       }
    }
    #
    # Import the name
    #
    namespace eval ::myCalc {
       namespace import ::mySpace::calcfunc
       proc detIntegral { begin end } {
          return [integral $begin $end 100 calcfunc]
       }
    }

Enhancements for the second\-order boundary value problem:

  - Other types of boundary conditions \(zero gradient, zero flux\)

  - Other schematisation of the first\-order term \(now central differences are
    used, but upstream differences might be useful too\)\.

# <a name='section3'></a>EXAMPLES

Let us take a few simple examples:

Integrate x over the interval \[0,100\] \(20 steps\):

    proc linear_func { x } { return $x }
    puts "Integral: [::math::calculus::integral 0 100 20 linear_func]"

For simple functions, the alternative could be:

    puts "Integral: [::math::calculus::integralExpr 0 100 20 {$x}]"

Do not forget the braces\!

The differential equation for a dampened oscillator:

    x'' + rx' + wx = 0

can be split into a system of first\-order equations:

    x' = y
    y' = -ry - wx

Then this system can be solved with code like this:

    proc dampened_oscillator { t xvec } {
       set x  [lindex $xvec 0]
       set x1 [lindex $xvec 1]
       return [list $x1 [expr {-$x1-$x}]]
    }

    set xvec   { 1.0 0.0 }
    set t      0.0
    set tstep  0.1
    for { set i 0 } { $i < 20 } { incr i } {
       set result [::math::calculus::eulerStep $t $tstep $xvec dampened_oscillator]
       puts "Result ($t): $result"
       set t      [expr {$t+$tstep}]
       set xvec   $result
    }

Suppose we have the boundary value problem:

    Dy'' + ky = 0
    x = 0: y = 1
    x = L: y = 0

This boundary value problem could originate from the diffusion of a decaying
substance\.

It can be solved with the following fragment:

    proc coeffs { x } { return [list $::Diff 0.0 $::decay] }
    proc force  { x } { return 0.0 }

    set Diff   1.0e-2
    set decay  0.0001
    set length 100.0

    set y [::math::calculus::boundaryValueSecondOrder \
       coeffs force {0.0 1.0} [list $length 0.0] 100]

# <a name='section4'></a>Bugs, Ideas, Feedback

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

romberg

# <a name='keywords'></a>KEYWORDS

[calculus](\.\./\.\./\.\./\.\./index\.md\#calculus), [differential
equations](\.\./\.\./\.\./\.\./index\.md\#differential\_equations),
[integration](\.\./\.\./\.\./\.\./index\.md\#integration),
[math](\.\./\.\./\.\./\.\./index\.md\#math), [roots](\.\./\.\./\.\./\.\./index\.md\#roots)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002,2003,2004 Arjen Markus
