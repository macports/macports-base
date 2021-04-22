
[//000000001]: # (math::calculus::symdiff \- Symbolic differentiation for Tcl)
[//000000002]: # (Generated from file 'symdiff\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2010 by Kevin B\. Kenny <kennykb@acm\.org>)
[//000000004]: # (Redistribution permitted under the terms of the Open Publication License <http://www\.opencontent\.org/openpub/>)
[//000000005]: # (math::calculus::symdiff\(n\) 1\.0\.1 tcllib "Symbolic differentiation for Tcl")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::calculus::symdiff \- Symbolic differentiation for Tcl

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Procedures](#section2)

  - [Expressions](#section3)

  - [Examples](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [See Also](#seealso)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require grammar::aycock 1\.0  
package require math::calculus::symdiff 1\.0\.1  

[__math::calculus::symdiff::symdiff__ *expression* *variable*](#1)  
[__math::calculus::jacobian__ *variableDict*](#2)  

# <a name='description'></a>DESCRIPTION

The __math::calculus::symdiff__ package provides a symbolic differentiation
facility for Tcl math expressions\. It is useful for providing derivatives to
packages that either require the Jacobian of a set of functions or else are more
efficient or stable when the Jacobian is provided\.

# <a name='section2'></a>Procedures

The __math::calculus::symdiff__ package exports the two procedures:

  - <a name='1'></a>__math::calculus::symdiff::symdiff__ *expression* *variable*

    Differentiates the given *expression* with respect to the specified
    *variable*\. \(See [Expressions](#section3) below for a discussion of
    the subset of Tcl math expressions that are acceptable to
    __math::calculus::symdiff__\.\) The result is a Tcl expression that
    evaluates the derivative\. Returns an error if *expression* is not a
    well\-formed expression or is not differentiable\.

  - <a name='2'></a>__math::calculus::jacobian__ *variableDict*

    Computes the Jacobian of a system of equations\. The system is given by the
    dictionary *variableDict*, whose keys are the names of variables in the
    system, and whose values are Tcl expressions giving the values of those
    variables\. \(See [Expressions](#section3) below for a discussion of the
    subset of Tcl math expressions that are acceptable to
    __math::calculus::symdiff__\. The result is a list of lists: the i'th
    element of the j'th sublist is the partial derivative of the i'th variable
    with respect to the j'th variable\. Returns an error if any of the
    expressions cannot be differentiated, or if *variableDict* is not a
    well\-formed dictionary\.

# <a name='section3'></a>Expressions

The __math::calculus::symdiff__ package accepts only a small subset of the
expressions that are acceptable to Tcl commands such as __expr__ or
__if__\. Specifically, the only constructs accepted are:

  - Floating\-point constants such as __5__ or __3\.14159e\+00__\.

  - References to Tcl variable using $\-substitution\. The variable names must
    consist of alphanumerics and underscores: the __$\{\.\.\.\}__ notation is not
    accepted\.

  - Parentheses\.

  - The __\+__, __\-__, __\*__, __/__\. and __\*\*__ operators\.

  - Calls to the functions __acos__, __asin__, __atan__,
    __atan2__, __cos__, __cosh__, __exp__, __hypot__,
    __[log](\.\./log/log\.md)__, __log10__, __pow__, __sin__,
    __sinh__\. __sqrt__, __tan__, and __tanh__\.

Command substitution, backslash substitution, and argument expansion are not
accepted\.

# <a name='section4'></a>Examples

    math::calculus::symdiff::symdiff {($a*$x+$b)*($c*$x+$d)} x
    ==> (($c * (($a * $x) + $b)) + ($a * (($c * $x) + $d)))
    math::calculus::symdiff::jacobian {x {$a * $x + $b * $y}
                             y {$c * $x + $d * $y}}
    ==> {{$a} {$b}} {{$c} {$d}}

# <a name='section5'></a>Bugs, Ideas, Feedback

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

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2010 by Kevin B\. Kenny <kennykb@acm\.org>
Redistribution permitted under the terms of the Open Publication License <http://www\.opencontent\.org/openpub/>
