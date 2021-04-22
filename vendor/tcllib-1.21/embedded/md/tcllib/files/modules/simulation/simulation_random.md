
[//000000001]: # (simulation::random \- Tcl Simulation Tools)
[//000000002]: # (Generated from file 'simulation\_random\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004 Arjen Markus <arjenmarkus@users\.sourceforge\.net>)
[//000000004]: # (simulation::random\(n\) 0\.4 tcllib "Tcl Simulation Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

simulation::random \- Pseudo\-random number generators

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PROCEDURES](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl ?8\.4?  
package require simulation::random 0\.4  

[__::simulation::random::prng\_Bernoulli__ *p*](#1)  
[__::simulation::random::prng\_Discrete__ *n*](#2)  
[__::simulation::random::prng\_Poisson__ *lambda*](#3)  
[__::simulation::random::prng\_Uniform__ *min* *max*](#4)  
[__::simulation::random::prng\_Triangular__ *min* *max*](#5)  
[__::simulation::random::prng\_SymmTriangular__ *min* *max*](#6)  
[__::simulation::random::prng\_Exponential__ *min* *mean*](#7)  
[__::simulation::random::prng\_Normal__ *mean* *stdev*](#8)  
[__::simulation::random::prng\_Pareto__ *min* *steep*](#9)  
[__::simulation::random::prng\_Gumbel__ *min* *f*](#10)  
[__::simulation::random::prng\_chiSquared__ *df*](#11)  
[__::simulation::random::prng\_Disk__ *rad*](#12)  
[__::simulation::random::prng\_Sphere__ *rad*](#13)  
[__::simulation::random::prng\_Ball__ *rad*](#14)  
[__::simulation::random::prng\_Rectangle__ *length* *width*](#15)  
[__::simulation::random::prng\_Block__ *length* *width* *depth*](#16)  

# <a name='description'></a>DESCRIPTION

This package consists of commands to generate pseudo\-random number generators\.
These new commands deliver

  - numbers that are distributed normally, uniformly, according to a Pareto or
    Gumbel distribution and so on

  - coordinates of points uniformly spread inside a sphere or a rectangle

For example:

    set p [::simulation::random::prng_Normal -1.0 10.0]

produces a new command \(whose name is stored in the variable "p"\) that generates
normally distributed numbers with a mean of \-1\.0 and a standard deviation of
10\.0\.

# <a name='section2'></a>PROCEDURES

The package defines the following public procedures for *discrete*
distributions:

  - <a name='1'></a>__::simulation::random::prng\_Bernoulli__ *p*

    Create a command \(PRNG\) that generates numbers with a Bernoulli
    distribution: the value is either 1 or 0, with a chance p to be 1

      * float *p*

        Chance the outcome is 1

  - <a name='2'></a>__::simulation::random::prng\_Discrete__ *n*

    Create a command \(PRNG\) that generates numbers 0 to n\-1 with equal
    probability\.

      * int *n*

        Number of different values \(ranging from 0 to n\-1\)

  - <a name='3'></a>__::simulation::random::prng\_Poisson__ *lambda*

    Create a command \(PRNG\) that generates numbers according to the Poisson
    distribution\.

      * float *lambda*

        Mean number per time interval

The package defines the following public procedures for *continuous*
distributions:

  - <a name='4'></a>__::simulation::random::prng\_Uniform__ *min* *max*

    Create a command \(PRNG\) that generates uniformly distributed numbers between
    "min" and "max"\.

      * float *min*

        Minimum number that will be generated

      * float *max*

        Maximum number that will be generated

  - <a name='5'></a>__::simulation::random::prng\_Triangular__ *min* *max*

    Create a command \(PRNG\) that generates triangularly distributed numbers
    between "min" and "max"\. If the argument min is lower than the argument max,
    then smaller values have higher probability and vice versa\. In the first
    case the probability density function is of the form *f\(x\) = 2\(1\-x\)* and
    the other case it is of the form *f\(x\) = 2x*\.

      * float *min*

        Minimum number that will be generated

      * float *max*

        Maximum number that will be generated

  - <a name='6'></a>__::simulation::random::prng\_SymmTriangular__ *min* *max*

    Create a command \(PRNG\) that generates numbers distributed according to a
    symmetric triangle around the mean of "min" and "max"\.

      * float *min*

        Minimum number that will be generated

      * float *max*

        Maximum number that will be generated

  - <a name='7'></a>__::simulation::random::prng\_Exponential__ *min* *mean*

    Create a command \(PRNG\) that generates exponentially distributed numbers
    with a given minimum value and a given mean value\.

      * float *min*

        Minimum number that will be generated

      * float *mean*

        Mean value for the numbers

  - <a name='8'></a>__::simulation::random::prng\_Normal__ *mean* *stdev*

    Create a command \(PRNG\) that generates normally distributed numbers with a
    given mean value and a given standard deviation\.

      * float *mean*

        Mean value for the numbers

      * float *stdev*

        Standard deviation

  - <a name='9'></a>__::simulation::random::prng\_Pareto__ *min* *steep*

    Create a command \(PRNG\) that generates numbers distributed according to
    Pareto with a given minimum value and a given distribution steepness\.

      * float *min*

        Minimum number that will be generated

      * float *steep*

        Steepness of the distribution

  - <a name='10'></a>__::simulation::random::prng\_Gumbel__ *min* *f*

    Create a command \(PRNG\) that generates numbers distributed according to
    Gumbel with a given minimum value and a given scale factor\. The probability
    density function is:

    P(v) = exp( -exp(f*(v-min)))

      * float *min*

        Minimum number that will be generated

      * float *f*

        Scale factor for the values

  - <a name='11'></a>__::simulation::random::prng\_chiSquared__ *df*

    Create a command \(PRNG\) that generates numbers distributed according to the
    chi\-squared distribution with df degrees of freedom\. The mean is 0 and the
    standard deviation is 1\.

      * float *df*

        Degrees of freedom

The package defines the following public procedures for random point sets:

  - <a name='12'></a>__::simulation::random::prng\_Disk__ *rad*

    Create a command \(PRNG\) that generates \(x,y\)\-coordinates for points
    uniformly spread over a disk of given radius\.

      * float *rad*

        Radius of the disk

  - <a name='13'></a>__::simulation::random::prng\_Sphere__ *rad*

    Create a command \(PRNG\) that generates \(x,y,z\)\-coordinates for points
    uniformly spread over the surface of a sphere of given radius\.

      * float *rad*

        Radius of the disk

  - <a name='14'></a>__::simulation::random::prng\_Ball__ *rad*

    Create a command \(PRNG\) that generates \(x,y,z\)\-coordinates for points
    uniformly spread within a ball of given radius\.

      * float *rad*

        Radius of the ball

  - <a name='15'></a>__::simulation::random::prng\_Rectangle__ *length* *width*

    Create a command \(PRNG\) that generates \(x,y\)\-coordinates for points
    uniformly spread over a rectangle\.

      * float *length*

        Length of the rectangle \(x\-direction\)

      * float *width*

        Width of the rectangle \(y\-direction\)

  - <a name='16'></a>__::simulation::random::prng\_Block__ *length* *width* *depth*

    Create a command \(PRNG\) that generates \(x,y,z\)\-coordinates for points
    uniformly spread over a block

      * float *length*

        Length of the block \(x\-direction\)

      * float *width*

        Width of the block \(y\-direction\)

      * float *depth*

        Depth of the block \(z\-direction\)

# <a name='keywords'></a>KEYWORDS

[math](\.\./\.\./\.\./\.\./index\.md\#math), [random
numbers](\.\./\.\./\.\./\.\./index\.md\#random\_numbers),
[simulation](\.\./\.\./\.\./\.\./index\.md\#simulation), [statistical
distribution](\.\./\.\./\.\./\.\./index\.md\#statistical\_distribution)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004 Arjen Markus <arjenmarkus@users\.sourceforge\.net>
