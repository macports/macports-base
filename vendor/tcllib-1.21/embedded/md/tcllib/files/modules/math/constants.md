
[//000000001]: # (math::constants \- Tcl Math Library)
[//000000002]: # (Generated from file 'constants\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004 Arjen Markus <arjenmarkus@users\.sourceforge\.net>)
[//000000004]: # (math::constants\(n\) 1\.0\.2 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::constants \- Mathematical and numerical constants

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PROCEDURES](#section2)

  - [Constants](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl ?8\.3?  
package require math::constants ?1\.0\.2?  

[__::math::constants::constants__ *args*](#1)  
[__::math::constants::print\-constants__ *args*](#2)  

# <a name='description'></a>DESCRIPTION

This package defines some common mathematical and numerical constants\. By using
the package you get consistent values for numbers like pi and ln\(10\)\.

It defines two commands:

  - One for importing the constants

  - One for reporting which constants are defined and what values they actually
    have\.

The motivation for this package is that quite often, with \(mathematical\)
computations, you need a good approximation to, say, the ratio of degrees to
radians\. You can, of course, define this like:

    variable radtodeg [expr {180.0/(4.0*atan(1.0))}]

and use the variable radtodeg whenever you need the conversion\.

This has two drawbacks:

  - You need to remember the proper formula or value and that is error\-prone\.

  - Especially with the use of mathematical functions like *atan* you assume
    that they have been accurately implemented\. This is seldom or never the case
    and for each platform you can get subtle differences\.

Here is the way you can do it with the *math::constants* package:

    package require math::constants
    ::math::constants::constants radtodeg degtorad

which creates two variables, radtodeg and \(its reciprocal\) degtorad in the
calling namespace\.

Constants that have been defined \(their values are mostly taken from
mathematical tables with more precision than usually can be handled\) include:

  - basic constants like pi, e, gamma \(Euler's constant\)

  - derived values like ln\(10\) and sqrt\(2\)

  - purely numerical values such as 1/3 that are included for convenience and
    for the fact that certain seemingly trivial computations like:

    set value [expr {3.0*$onethird}]

    give *exactly* the value you expect \(if IEEE arithmetic is available\)\.

The full set of named constants is listed in section
[Constants](#section3)\.

# <a name='section2'></a>PROCEDURES

The package defines the following public procedures:

  - <a name='1'></a>__::math::constants::constants__ *args*

    Import the constants whose names are given as arguments

  - <a name='2'></a>__::math::constants::print\-constants__ *args*

    Print the constants whose names are given as arguments on the screen \(name,
    value and description\) or, if no arguments are given, print all defined
    constants\. This is mainly a convenience procedure\.

# <a name='section3'></a>Constants

  - __pi__

    Ratio of circle circumference to diameter

  - __e__

    Base for natural logarithm

  - __ln10__

    Natural logarithm of 10

  - __phi__

    Golden ratio

  - __gamma__

    Euler's constant

  - __sqrt2__

    Square root of 2

  - __thirdrt2__

    One\-third power of 2

  - __sqrt3__

    Square root of 3

  - __radtodeg__

    Conversion from radians to degrees

  - __degtorad__

    Conversion from degrees to radians

  - __onethird__

    One third \(0\.3333\.\.\.\.\)

  - __twothirds__

    Two thirds \(0\.6666\.\.\.\.\)

  - __onesixth__

    One sixth \(0\.1666\.\.\.\.\)

  - __huge__

    \(Approximately\) largest number

  - __tiny__

    \(Approximately\) smallest number not equal zero

  - __eps__

    Smallest number such that 1\+eps \!= 1

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: constants* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[constants](\.\./\.\./\.\./\.\./index\.md\#constants),
[degrees](\.\./\.\./\.\./\.\./index\.md\#degrees), [e](\.\./\.\./\.\./\.\./index\.md\#e),
[math](\.\./\.\./\.\./\.\./index\.md\#math), [pi](\.\./\.\./\.\./\.\./index\.md\#pi),
[radians](\.\./\.\./\.\./\.\./index\.md\#radians)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004 Arjen Markus <arjenmarkus@users\.sourceforge\.net>
