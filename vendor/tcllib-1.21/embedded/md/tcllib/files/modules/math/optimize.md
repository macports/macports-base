
[//000000001]: # (math::optimize \- Tcl Math Library)
[//000000002]: # (Generated from file 'optimize\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004 Arjen Markus <arjenmarkus@users\.sourceforge\.net>)
[//000000004]: # (Copyright &copy; 2004,2005 Kevn B\. Kenny <kennykb@users\.sourceforge\.net>)
[//000000005]: # (math::optimize\(n\) 1\.0 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::optimize \- Optimisation routines

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PROCEDURES](#section2)

  - [NOTES](#section3)

  - [EXAMPLES](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require math::optimize ?1\.0?  

[__::math::optimize::minimum__ *begin* *end* *func* *maxerr*](#1)  
[__::math::optimize::maximum__ *begin* *end* *func* *maxerr*](#2)  
[__::math::optimize::min\_bound\_1d__ *func* *begin* *end* ?__\-relerror__ *reltol*? ?__\-abserror__ *abstol*? ?__\-maxiter__ *maxiter*? ?__\-trace__ *traceflag*?](#3)  
[__::math::optimize::min\_unbound\_1d__ *func* *begin* *end* ?__\-relerror__ *reltol*? ?__\-abserror__ *abstol*? ?__\-maxiter__ *maxiter*? ?__\-trace__ *traceflag*?](#4)  
[__::math::optimize::solveLinearProgram__ *objective* *constraints*](#5)  
[__::math::optimize::linearProgramMaximum__ *objective* *result*](#6)  
[__::math::optimize::nelderMead__ *objective* *xVector* ?__\-scale__ *xScaleVector*? ?__\-ftol__ *epsilon*? ?__\-maxiter__ *count*? ??\-trace? *flag*?](#7)  

# <a name='description'></a>DESCRIPTION

This package implements several optimisation algorithms:

  - Minimize or maximize a function over a given interval

  - Solve a linear program \(maximize a linear function subject to linear
    constraints\)

  - Minimize a function of several variables given an initial guess for the
    location of the minimum\.

The package is fully implemented in Tcl\. No particular attention has been paid
to the accuracy of the calculations\. Instead, the algorithms have been used in a
straightforward manner\.

This document describes the procedures and explains their usage\.

# <a name='section2'></a>PROCEDURES

This package defines the following public procedures:

  - <a name='1'></a>__::math::optimize::minimum__ *begin* *end* *func* *maxerr*

    Minimize the given \(continuous\) function by examining the values in the
    given interval\. The procedure determines the values at both ends and in the
    centre of the interval and then constructs a new interval of 1/2 length that
    includes the minimum\. No guarantee is made that the *global* minimum is
    found\.

    The procedure returns the "x" value for which the function is minimal\.

    *This procedure has been deprecated \- use min\_bound\_1d instead*

    *begin* \- Start of the interval

    *end* \- End of the interval

    *func* \- Name of the function to be minimized \(a procedure taking one
    argument\)\.

    *maxerr* \- Maximum relative error \(defaults to 1\.0e\-4\)

  - <a name='2'></a>__::math::optimize::maximum__ *begin* *end* *func* *maxerr*

    Maximize the given \(continuous\) function by examining the values in the
    given interval\. The procedure determines the values at both ends and in the
    centre of the interval and then constructs a new interval of 1/2 length that
    includes the maximum\. No guarantee is made that the *global* maximum is
    found\.

    The procedure returns the "x" value for which the function is maximal\.

    *This procedure has been deprecated \- use max\_bound\_1d instead*

    *begin* \- Start of the interval

    *end* \- End of the interval

    *func* \- Name of the function to be maximized \(a procedure taking one
    argument\)\.

    *maxerr* \- Maximum relative error \(defaults to 1\.0e\-4\)

  - <a name='3'></a>__::math::optimize::min\_bound\_1d__ *func* *begin* *end* ?__\-relerror__ *reltol*? ?__\-abserror__ *abstol*? ?__\-maxiter__ *maxiter*? ?__\-trace__ *traceflag*?

    Miminizes a function of one variable in the given interval\. The procedure
    uses Brent's method of parabolic interpolation, protected by golden\-section
    subdivisions if the interpolation is not converging\. No guarantee is made
    that a *global* minimum is found\. The function to evaluate, *func*, must
    be a single Tcl command; it will be evaluated with an abscissa appended as
    the last argument\.

    *x1* and *x2* are the two bounds of the interval in which the minimum is
    to be found\. They need not be in increasing order\.

    *reltol*, if specified, is the desired upper bound on the relative error
    of the result; default is 1\.0e\-7\. The given value should never be smaller
    than the square root of the machine's floating point precision, or else
    convergence is not guaranteed\. *abstol*, if specified, is the desired
    upper bound on the absolute error of the result; default is 1\.0e\-10\. Caution
    must be used with small values of *abstol* to avoid overflow/underflow
    conditions; if the minimum is expected to lie about a small but non\-zero
    abscissa, you consider either shifting the function or changing its length
    scale\.

    *maxiter* may be used to constrain the number of function evaluations to
    be performed; default is 100\. If the command evaluates the function more
    than *maxiter* times, it returns an error to the caller\.

    *traceFlag* is a Boolean value\. If true, it causes the command to print a
    message on the standard output giving the abscissa and ordinate at each
    function evaluation, together with an indication of what type of
    interpolation was chosen\. Default is 0 \(no trace\)\.

  - <a name='4'></a>__::math::optimize::min\_unbound\_1d__ *func* *begin* *end* ?__\-relerror__ *reltol*? ?__\-abserror__ *abstol*? ?__\-maxiter__ *maxiter*? ?__\-trace__ *traceflag*?

    Miminizes a function of one variable over the entire real number line\. The
    procedure uses parabolic extrapolation combined with golden\-section
    dilatation to search for a region where a minimum exists, followed by
    Brent's method of parabolic interpolation, protected by golden\-section
    subdivisions if the interpolation is not converging\. No guarantee is made
    that a *global* minimum is found\. The function to evaluate, *func*, must
    be a single Tcl command; it will be evaluated with an abscissa appended as
    the last argument\.

    *x1* and *x2* are two initial guesses at where the minimum may lie\.
    *x1* is the starting point for the minimization, and the difference
    between *x2* and *x1* is used as a hint at the characteristic length
    scale of the problem\.

    *reltol*, if specified, is the desired upper bound on the relative error
    of the result; default is 1\.0e\-7\. The given value should never be smaller
    than the square root of the machine's floating point precision, or else
    convergence is not guaranteed\. *abstol*, if specified, is the desired
    upper bound on the absolute error of the result; default is 1\.0e\-10\. Caution
    must be used with small values of *abstol* to avoid overflow/underflow
    conditions; if the minimum is expected to lie about a small but non\-zero
    abscissa, you consider either shifting the function or changing its length
    scale\.

    *maxiter* may be used to constrain the number of function evaluations to
    be performed; default is 100\. If the command evaluates the function more
    than *maxiter* times, it returns an error to the caller\.

    *traceFlag* is a Boolean value\. If true, it causes the command to print a
    message on the standard output giving the abscissa and ordinate at each
    function evaluation, together with an indication of what type of
    interpolation was chosen\. Default is 0 \(no trace\)\.

  - <a name='5'></a>__::math::optimize::solveLinearProgram__ *objective* *constraints*

    Solve a *linear program* in standard form using a straightforward
    implementation of the Simplex algorithm\. \(In the explanation below: The
    linear program has N constraints and M variables\)\.

    The procedure returns a list of M values, the values for which the objective
    function is maximal or a single keyword if the linear program is not
    feasible or unbounded \(either "unfeasible" or "unbounded"\)

    *objective* \- The M coefficients of the objective function

    *constraints* \- Matrix of coefficients plus maximum values that implement
    the linear constraints\. It is expected to be a list of N lists of M\+1
    numbers each, M coefficients and the maximum value\.

  - <a name='6'></a>__::math::optimize::linearProgramMaximum__ *objective* *result*

    Convenience function to return the maximum for the solution found by the
    solveLinearProgram procedure\.

    *objective* \- The M coefficients of the objective function

    *result* \- The result as returned by solveLinearProgram

  - <a name='7'></a>__::math::optimize::nelderMead__ *objective* *xVector* ?__\-scale__ *xScaleVector*? ?__\-ftol__ *epsilon*? ?__\-maxiter__ *count*? ??\-trace? *flag*?

    Minimizes, in unconstrained fashion, a function of several variable over all
    of space\. The function to evaluate, *objective*, must be a single Tcl
    command\. To it will be appended as many elements as appear in the initial
    guess at the location of the minimum, passed in as a Tcl list, *xVector*\.

    *xScaleVector* is an initial guess at the problem scale; the first
    function evaluations will be made by varying the co\-ordinates in *xVector*
    by the amounts in *xScaleVector*\. If *xScaleVector* is not supplied, the
    co\-ordinates will be varied by a factor of 1\.0001 \(if the co\-ordinate is
    non\-zero\) or by a constant 0\.0001 \(if the co\-ordinate is zero\)\.

    *epsilon* is the desired relative error in the value of the function
    evaluated at the minimum\. The default is 1\.0e\-7, which usually gives three
    significant digits of accuracy in the values of the x's\.

    pp *count* is a limit on the number of trips through the main loop of the
    optimizer\. The number of function evaluations may be several times this
    number\. If the optimizer fails to find a minimum to within *ftol* in
    *maxiter* iterations, it returns its current best guess and an error
    status\. Default is to allow 500 iterations\.

    *flag* is a flag that, if true, causes a line to be written to the
    standard output for each evaluation of the objective function, giving the
    arguments presented to the function and the value returned\. Default is
    false\.

    The __nelderMead__ procedure returns a list of alternating keywords and
    values suitable for use with __array set__\. The meaning of the keywords
    is:

    *x* is the approximate location of the minimum\.

    *y* is the value of the function at *x*\.

    *yvec* is a vector of the best N\+1 function values achieved, where N is
    the dimension of *x*

    *vertices* is a list of vectors giving the function arguments
    corresponding to the values in *yvec*\.

    *nIter* is the number of iterations required to achieve convergence or
    fail\.

    *status* is 'ok' if the operation succeeded, or 'too\-many\-iterations' if
    the maximum iteration count was exceeded\.

    __nelderMead__ minimizes the given function using the downhill simplex
    method of Nelder and Mead\. This method is quite slow \- much faster methods
    for minimization are known \- but has the advantage of being extremely robust
    in the face of problems where the minimum lies in a valley of complex
    topology\.

    __nelderMead__ can occasionally find itself "stuck" at a point where it
    can make no further progress; it is recommended that the caller run it at
    least a second time, passing as the initial guess the result found by the
    previous call\. The second run is usually very fast\.

    __nelderMead__ can be used in some cases for constrained optimization\.
    To do this, add a large value to the objective function if the parameters
    are outside the feasible region\. To work effectively in this mode,
    __nelderMead__ requires that the initial guess be feasible and usually
    requires that the feasible region be convex\.

# <a name='section3'></a>NOTES

Several of the above procedures take the *names* of procedures as arguments\.
To avoid problems with the *visibility* of these procedures, the
fully\-qualified name of these procedures is determined inside the optimize
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
       puts [min_bound_1d ::myCalc::calcfunc $begin $end]
    }
    #
    # Import the name
    #
    namespace eval ::myCalc {
       namespace import ::mySpace::calcfunc
       puts [min_bound_1d calcfunc $begin $end]
    }

The simple procedures *minimum* and *maximum* have been deprecated: the
alternatives are much more flexible, robust and require less function
evaluations\.

# <a name='section4'></a>EXAMPLES

Let us take a few simple examples:

Determine the maximum of f\(x\) = x^3 exp\(\-3x\), on the interval \(0,10\):

    proc efunc { x } { expr {$x*$x*$x * exp(-3.0*$x)} }
    puts "Maximum at: [::math::optimize::max_bound_1d efunc 0.0 10.0]"

The maximum allowed error determines the number of steps taken \(with each step
in the iteration the interval is reduced with a factor 1/2\)\. Hence, a maximum
error of 0\.0001 is achieved in approximately 14 steps\.

An example of a *linear program* is:

Optimise the expression 3x\+2y, where:

    x >= 0 and y >= 0 (implicit constraints, part of the
                      definition of linear programs)

    x + y   <= 1      (constraints specific to the problem)
    2x + 5y <= 10

This problem can be solved as follows:

    set solution [::math::optimize::solveLinearProgram  { 3.0   2.0 }  { { 1.0   1.0   1.0 }
         { 2.0   5.0  10.0 } } ]

Note, that a constraint like:

    x + y >= 1

can be turned into standard form using:

    -x  -y <= -1

The theory of linear programming is the subject of many a text book and the
Simplex algorithm that is implemented here is the best\-known method to solve
this type of problems, but it is not the only one\.

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: optimize* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[linear program](\.\./\.\./\.\./\.\./index\.md\#linear\_program),
[math](\.\./\.\./\.\./\.\./index\.md\#math),
[maximum](\.\./\.\./\.\./\.\./index\.md\#maximum),
[minimum](\.\./\.\./\.\./\.\./index\.md\#minimum),
[optimization](\.\./\.\./\.\./\.\./index\.md\#optimization)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004 Arjen Markus <arjenmarkus@users\.sourceforge\.net>  
Copyright &copy; 2004,2005 Kevn B\. Kenny <kennykb@users\.sourceforge\.net>
