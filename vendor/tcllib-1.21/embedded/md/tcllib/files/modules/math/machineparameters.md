
[//000000001]: # (math::machineparameters \- tclrep)
[//000000002]: # (Generated from file 'machineparameters\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2008 Michael Baudin <michael\.baudin@sourceforge\.net>)
[//000000004]: # (math::machineparameters\(n\) 1\.0 tcllib "tclrep")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::machineparameters \- Compute double precision machine parameters\.

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [EXAMPLE](#section2)

  - [REFERENCES](#section3)

  - [CLASS API](#section4)

  - [OBJECT API](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require snit  
package require math::machineparameters 0\.1  

[__machineparameters__ create *objectname* ?*options*\.\.\.?](#1)  
[*objectname* __configure__ ?*options*\.\.\.?](#2)  
[*objectname* __cget__ *opt*](#3)  
[*objectname* __destroy__](#4)  
[*objectname* __compute__](#5)  
[*objectname* __get__ *key*](#6)  
[*objectname* __tostring__](#7)  
[*objectname* __print__](#8)  

# <a name='description'></a>DESCRIPTION

The *math::machineparameters* package is the Tcl equivalent of the DLAMCH
LAPACK function\. In floating point systems, a floating point number is
represented by

    x = +/- d1 d2 ... dt basis^e

where digits satisfy

    0 <= di <= basis - 1, i = 1, t

with the convention :

  - t is the size of the mantissa

  - basis is the basis \(the "radix"\)

The __compute__ method computes all machine parameters\. Then, the
__get__ method can be used to get each parameter\. The __print__ method
prints a report on standard output\.

# <a name='section2'></a>EXAMPLE

In the following example, one compute the parameters of a desktop under Linux
with the following Tcl 8\.4\.19 properties :

    % parray tcl_platform
    tcl_platform(byteOrder) = littleEndian
    tcl_platform(machine)   = i686
    tcl_platform(os)        = Linux
    tcl_platform(osVersion) = 2.6.24-19-generic
    tcl_platform(platform)  = unix
    tcl_platform(tip,268)   = 1
    tcl_platform(tip,280)   = 1
    tcl_platform(user)      = <username>
    tcl_platform(wordSize)  = 4

The following example creates a machineparameters object, computes the
properties and displays it\.

    set pp [machineparameters create %AUTO%]
    $pp compute
    $pp print
    $pp destroy

This prints out :

    Machine parameters
    Epsilon : 1.11022302463e-16
    Beta : 2
    Rounding : proper
    Mantissa : 53
    Maximum exponent : 1024
    Minimum exponent : -1021
    Overflow threshold : 8.98846567431e+307
    Underflow threshold : 2.22507385851e-308

That compares well with the results produced by Lapack 3\.1\.1 :

    Epsilon                      =   1.11022302462515654E-016
    Safe minimum                 =   2.22507385850720138E-308
    Base                         =    2.0000000000000000
    Precision                    =   2.22044604925031308E-016
    Number of digits in mantissa =    53.000000000000000
    Rounding mode                =   1.00000000000000000
    Minimum exponent             =   -1021.0000000000000
    Underflow threshold          =   2.22507385850720138E-308
    Largest exponent             =    1024.0000000000000
    Overflow threshold           =   1.79769313486231571E+308
    Reciprocal of safe minimum   =   4.49423283715578977E+307

The following example creates a machineparameters object, computes the
properties and gets the epsilon for the machine\.

    set pp [machineparameters create %AUTO%]
    $pp compute
    set eps [$pp get -epsilon]
    $pp destroy

# <a name='section3'></a>REFERENCES

  - "Algorithms to Reveal Properties of Floating\-Point Arithmetic", Michael A\.
    Malcolm, Stanford University, Communications of the ACM, Volume 15 , Issue
    11 \(November 1972\), Pages: 949 \- 951

  - "More on Algorithms that Reveal Properties of Floating, Point Arithmetic
    Units", W\. Morven Gentleman, University of Waterloo, Scott B\. Marovich,
    Purdue University, Communications of the ACM, Volume 17 , Issue 5 \(May
    1974\), Pages: 276 \- 277

# <a name='section4'></a>CLASS API

  - <a name='1'></a>__machineparameters__ create *objectname* ?*options*\.\.\.?

    The command creates a new machineparameters object and returns the fully
    qualified name of the object command as its result\.

      * __\-verbose__ *verbose*

        Set this option to 1 to enable verbose logging\. This option is mainly
        for debug purposes\. The default value of *verbose* is 0\.

# <a name='section5'></a>OBJECT API

  - <a name='2'></a>*objectname* __configure__ ?*options*\.\.\.?

    The command configure the options of the object *objectname*\. The options
    are the same as the static method __create__\.

  - <a name='3'></a>*objectname* __cget__ *opt*

    Returns the value of the option which name is *opt*\. The options are the
    same as the method __create__ and __configure__\.

  - <a name='4'></a>*objectname* __destroy__

    Destroys the object *objectname*\.

  - <a name='5'></a>*objectname* __compute__

    Computes the machine parameters\.

  - <a name='6'></a>*objectname* __get__ *key*

    Returns the value corresponding with given key\. The following is the list of
    available keys\.

      * \-epsilon : smallest value so that 1\+epsilon>1 is false

      * \-rounding : The rounding mode used on the machine\. The rounding occurs
        when more than t digits would be required to represent the number\. Two
        modes can be determined with the current system : "chop" means than only
        t digits are kept, no matter the value of the number "proper" means that
        another rounding mode is used, be it "round to nearest", "round up",
        "round down"\.

      * \-basis : the basis of the floating\-point representation\. The basis is
        usually 2, i\.e\. binary representation \(for example IEEE 754 machines\),
        but some machines \(like HP calculators for example\) uses 10, or 16,
        etc\.\.\.

      * \-mantissa : the number of bits in the mantissa

      * \-exponentmax : the largest positive exponent before overflow occurs

      * \-exponentmin : the largest negative exponent before \(gradual\) underflow
        occurs

      * \-vmax : largest positive value before overflow occurs

      * \-vmin : largest negative value before \(gradual\) underflow occurs

  - <a name='7'></a>*objectname* __tostring__

    Return a report for machine parameters\.

  - <a name='8'></a>*objectname* __print__

    Print machine parameters on standard output\.

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2008 Michael Baudin <michael\.baudin@sourceforge\.net>
