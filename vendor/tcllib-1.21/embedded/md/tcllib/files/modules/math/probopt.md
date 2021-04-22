
[//000000001]: # (math::probopt \- Tcl Math Library)
[//000000002]: # (Generated from file 'probopt\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (math::probopt\(n\) 1 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::probopt \- Probabilistic optimisation methods

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [DETAILS ON THE ALGORITHMS](#section2)

  - [References](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require TclOO  
package require math::probopt 1  

[__::math::probopt::pso__ *function* *bounds* *args*](#1)  
[__::math::probopt::sce__ *function* *bounds* *args*](#2)  
[__::math::probopt::diffev__ *function* *bounds* *args*](#3)  
[__::math::probopt::lipoMax__ *function* *bounds* *args*](#4)  
[__::math::probopt::adaLipoMax__ *function* *bounds* *args*](#5)  

# <a name='description'></a>DESCRIPTION

The purpose of the __math::probopt__ package is to provide various
optimisation algorithms that are based on probabilistic techniques\. The results
of these algorithms may therefore vary from one run to the next\. The algorithms
are all well\-known and well described and proponents generally claim they are
efficient and reliable\.

As most of these algorithms have one or more tunable parameters or even
variations, the interface to each accepts options to set these parameters or the
select the variation\. These take the form of key\-value pairs, for instance,
*\-iterations 100*\.

This manual does not offer any recommendations with regards to these algorithms,
nor does it provide much in the way of guidelines for the parameters\. For this
we refer to online articles on the algorithms in question\.

A few notes, however:

  - With the exception of LIPO, the algorithms are capable of dealing with
    irregular \(non\-smooth\) and even discontinuous functions\.

  - The results depend on the random number seeding and are likely not to be
    very accurate, especially if the function varies slowly in the vicinty of
    the optimum\. They do give a good starting point for a deterministic
    algorithm\.

The collection consists of the following algorithms:

  - PSO \- particle swarm optimisation

  - SCE \- shuffled complexes evolution

  - DE \- differential evolution

  - LIPO \- Lipschitz optimisation

The various procedures have a uniform interface:

    set result [::math::probopt::algorithm function bounds args]

The arguments have the following meaning:

  - The argument *function* is the name of the procedure that evaluates the
    function\. Its interface is:

    set value [function coords]

    where *coords* is a list of coordinates at which to evaluate the function\.
    It is supposed to return the function value\.

  - The argument *bounds* is a list of pairs of minimum and maximum for each
    coordinate\. This list implicitly determines the dimension of the coordinate
    space in which the optimum is to be sought, for instance for a function like
    *x\*\*2 \+ \(y\-1\)\*\*4*, you may specify the bounds as *\{\{\-1 1\} \{\-1 1\}\}*, that
    is, two pairs for the two coordinates\.

  - The rest \(*args*\) consists of zero or more key\-value pairs to specify the
    options\. Which options are supported by which algorithm, is documented
    below\.

The result of the various optimisation procedures is a dictionary containing at
least the following elements:

  - *optimum\-coordinates* is a list containing the coordinates of the optimum
    that was found\.

  - *optimum\-value* is the function value at those coordinates\.

  - *evaluations* is the number of function evaluations\.

  - *best\-values* is a list of successive best values, obtained as part of the
    iterations\.

# <a name='section2'></a>DETAILS ON THE ALGORITHMS

The algorithms in the package are the following:

  - <a name='1'></a>__::math::probopt::pso__ *function* *bounds* *args*

    The "particle swarm optimisation" algorithm uses the idea that the candidate
    optimum points should swarm around the best point found so far, with
    variations to allow for improvements\.

    It recognises the following options:

      * *\-swarmsize number*: Number of particles to consider \(default: 50\)

      * *\-vweight value*: Weight for the current "velocity" \(0\-1, default:
        0\.5\)

      * *\-pweight value*: Weight for the individual particle's best position
        \(0\-1, default: 0\.3\)

      * *\-gweight value*: Weight for the "best" overall position as per
        particle \(0\-1, default: 0\.3\)

      * *\-type local/global*: Type of optimisation

      * *\-neighbours number*: Size of the neighbourhood \(default: 5, used if
        "local"\)

      * *\-iterations number*: Maximum number of iterations

      * *\-tolerance value*: Absolute minimal improvement for minimum value

  - <a name='2'></a>__::math::probopt::sce__ *function* *bounds* *args*

    The "shuffled complex evolution" algorithm is an extension of the
    Nelder\-Mead algorithm that uses multiple complexes and reorganises these
    complexes to find the "global" optimum\.

    It recognises the following options:

      * *\-complexes number*: Number of particles to consider \(default: 2\)

      * *\-mincomplexes number*: Minimum number of complexes \(default: 2; not
        currently used\)

      * *\-newpoints number*: Number of new points to be generated \(default: 1\)

      * *\-shuffle number*: Number of iterations after which to reshuffle the
        complexes \(if set to 0, the default, a number will be calculated from
        the number of dimensions\)

      * *\-pointspercomplex number*: Number of points per complex \(if set to 0,
        the default, a number will be calculated from the number of dimensions\)

      * *\-pointspersubcomplex number*: Number of points per subcomplex \(used
        to select the best points in each complex; if set to 0, the default, a
        number will be calculated from the number of dimensions\)

      * *\-iterations number*: Maximum number of iterations \(default: 100\)

      * *\-maxevaluations number*: Maximum number of function evaluations \(when
        this number is reached the iteration is broken off\. Default: 1000
        million\)

      * *\-abstolerance value*: Absolute minimal improvement for minimum value
        \(default: 0\.0\)

      * *\-reltolerance value*: Relative minimal improvement for minimum value
        \(default: 0\.001\)

  - <a name='3'></a>__::math::probopt::diffev__ *function* *bounds* *args*

    The "differential evolution" algorithm uses a number of initial points that
    are then updated using randomly selected points\. It is more or less akin to
    genetic algorithms\. It is controlled by two parameters, factor and lambda,
    where the first determines the update via random points and the second the
    update with the best point found sofar\.

    It recognises the following options:

      * *\-iterations number*: Maximum number of iterations \(default: 100\)

      * *\-number number*: Number of point to work with \(if set to 0, the
        default, it is calculated from the number of dimensions\)

      * *\-factor value*: Weight of randomly selected points in the updating
        \(0\-1, default: 0\.6\)

      * *\-lambda value*: Weight of the best point found so far in the updating
        \(0\-1, default: 0\.0\)

      * *\-crossover value*: Fraction of new points to be considered for
        replacing the old ones \(0\-1, default: 0\.5\)

      * *\-maxevaluations number*: Maximum number of function evaluations \(when
        this number is reached the iteration is broken off\. Default: 1000
        million\)

      * *\-abstolerance value*: Absolute minimal improvement for minimum value
        \(default: 0\.0\)

      * *\-reltolerance value*: Relative minimal improvement for minimum value
        \(default: 0\.001\)

  - <a name='4'></a>__::math::probopt::lipoMax__ *function* *bounds* *args*

    The "Lipschitz optimisation" algorithm uses the "Lipschitz" property of the
    given function to find a *maximum* in the given bounding box\. There are
    two variants, *lipoMax* assumes a fixed estimate for the Lipschitz
    parameter\.

    It recognises the following options:

      * *\-iterations number*: Number of iterations \(equals the actual number
        of function evaluations, default: 100\)

      * *\-lipschitz value*: Estimate of the Lipschitz parameter \(default:
        10\.0\)

  - <a name='5'></a>__::math::probopt::adaLipoMax__ *function* *bounds* *args*

    The "adaptive Lipschitz optimisation" algorithm uses the "Lipschitz"
    property of the given function to find a *maximum* in the given bounding
    box\. The adaptive variant actually uses two phases to find a suitable
    estimate for the Lipschitz parameter\. This is controlled by the "Bernoulli"
    parameter\.

    When you specify a large number of iterations, the algorithm may take a very
    long time to complete as it is trying to improve on the Lipschitz parameter
    and the chances of hitting a better estimate diminish fast\.

    It recognises the following options:

      * *\-iterations number*: Number of iterations \(equals the actual number
        of function evaluations, default: 100\)

      * *\-bernoulli value*: Parameter for random decisions \(exploration versus
        exploitation, default: 0\.1\)

# <a name='section3'></a>References

The various algorithms have been described in on\-line publications\. Here are a
few:

  - *PSO*: Maurice Clerc, Standard Particle Swarm Optimisation \(2012\)
    [https://hal\.archives\-ouvertes\.fr/file/index/docid/764996/filename/SPSO\_descriptions\.pdf](https://hal\.archives\-ouvertes\.fr/file/index/docid/764996/filename/SPSO\_descriptions\.pdf)

    Alternatively:
    [https://en\.wikipedia\.org/wiki/Particle\_swarm\_optimization](https://en\.wikipedia\.org/wiki/Particle\_swarm\_optimization)

  - *SCE*: Qingyuan Duan, Soroosh Sorooshian, Vijai K\. Gupta, Optimal use offo
    the SCE\-UA global optimization method for calibrating watershed models
    \(1994\), Journal of Hydrology 158, pp 265\-284

    [https://www\.researchgate\.net/publication/223408756\_Optimal\_Use\_of\_the\_SCE\-UA\_Global\_Optimization\_Method\_for\_Calibrating\_Watershed\_Models](https://www\.researchgate\.net/publication/223408756\_Optimal\_Use\_of\_the\_SCE\-UA\_Global\_Optimization\_Method\_for\_Calibrating\_Watershed\_Models)

  - *[DE](\.\./\.\./\.\./\.\./index\.md\#de)*: Rainer Storn and Kenneth Price,
    Differential Evolution \- A simple and efficient adaptivescheme for
    globaloptimization over continuous spaces \(1996\)

    [http://www1\.icsi\.berkeley\.edu/~storn/TR\-95\-012\.pdf](http://www1\.icsi\.berkeley\.edu/~storn/TR\-95\-012\.pdf)

  - *LIPO*: Cedric Malherbe and Nicolas Vayatis, Global optimization of
    Lipschitz functions, \(june 2017\)

    [https://arxiv\.org/pdf/1703\.02628\.pdf](https://arxiv\.org/pdf/1703\.02628\.pdf)

# <a name='keywords'></a>KEYWORDS

[mathematics](\.\./\.\./\.\./\.\./index\.md\#mathematics),
[optimisation](\.\./\.\./\.\./\.\./index\.md\#optimisation), [probabilistic
calculations](\.\./\.\./\.\./\.\./index\.md\#probabilistic\_calculations)

# <a name='category'></a>CATEGORY

Mathematics
