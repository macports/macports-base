
[//000000001]: # (simulation::annealing \- Tcl Simulation Tools)
[//000000002]: # (Generated from file 'annealing\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2008 Arjen Markus <arjenmarkus@users\.sourceforge\.net>)
[//000000004]: # (simulation::annealing\(n\) 0\.2 tcllib "Tcl Simulation Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

simulation::annealing \- Simulated annealing

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PROCEDURES](#section2)

  - [TIPS](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl ?8\.4?  
package require simulation::annealing 0\.2  

[__::simulation::annealing::getOption__ *keyword*](#1)  
[__::simulation::annealing::hasOption__ *keyword*](#2)  
[__::simulation::annealing::setOption__ *keyword* *value*](#3)  
[__::simulation::annealing::findMinimum__ *args*](#4)  
[__::simulation::annealing::findCombinatorialMinimum__ *args*](#5)  

# <a name='description'></a>DESCRIPTION

The technique of *simulated annealing* provides methods to estimate the global
optimum of a function\. It is described in some detail on the Wiki
[http://wiki\.tcl\.tk/\.\.\.](http://wiki\.tcl\.tk/\.\.\.)\. The idea is simple:

  - randomly select points within a given search space

  - evaluate the function to be optimised for each of these points and select
    the point that has the lowest \(or highest\) function value or \- sometimes \-
    accept a point that has a less optimal value\. The chance by which such a
    non\-optimal point is accepted diminishes over time\.

  - Accepting less optimal points means the method does not necessarily get
    stuck in a local optimum and theoretically it is capable of finding the
    global optimum within the search space\.

The method resembles the cooling of material, hence the name\.

The package *simulation::annealing* offers the command *findMinimum*:

    puts [::simulation::annealing::findMinimum  -trials 300  -parameters {x -5.0 5.0 y -5.0 5.0}  -function {$x*$x+$y*$y+sin(10.0*$x)+4.0*cos(20.0*$y)}]

prints the estimated minimum value of the function f\(x,y\) =
*x\*\*2\+y\*\*2\+sin\(10\*x\)\+4\*cos\(20\*y\)* and the values of x and y where the minimum
was attained:

    result -4.9112922923 x -0.181647676593 y 0.155743646974

# <a name='section2'></a>PROCEDURES

The package defines the following auxiliary procedures:

  - <a name='1'></a>__::simulation::annealing::getOption__ *keyword*

    Get the value of an option given as part of the *findMinimum* command\.

      * string *keyword*

        Given keyword \(without leading minus\)

  - <a name='2'></a>__::simulation::annealing::hasOption__ *keyword*

    Returns 1 if the option is available, 0 if not\.

      * string *keyword*

        Given keyword \(without leading minus\)

  - <a name='3'></a>__::simulation::annealing::setOption__ *keyword* *value*

    Set the value of the given option\.

      * string *keyword*

        Given keyword \(without leading minus\)

      * string *value*

        \(New\) value for the option

The main procedures are *findMinimum* and *findCombinatorialMinimum*:

  - <a name='4'></a>__::simulation::annealing::findMinimum__ *args*

    Find the minimum of a function using simulated annealing\. The function and
    the method's parameters is given via a list of keyword\-value pairs\.

      * int *n*

        List of keyword\-value pairs, all of which are available during the
        execution via the *getOption* command\.

  - <a name='5'></a>__::simulation::annealing::findCombinatorialMinimum__ *args*

    Find the minimum of a function of discrete variables using simulated
    annealing\. The function and the method's parameters is given via a list of
    keyword\-value pairs\.

      * int *n*

        List of keyword\-value pairs, all of which are available during the
        execution via the *getOption* command\.

The *findMinimum* command predefines the following options:

  - *\-parameters list*: triples defining parameters and ranges

  - *\-function expr*: expression defining the function

  - *\-code body*: body of code to define the function \(takes precedence over
    *\-function*\)\. The code should set the variable "result"

  - *\-init code*: code to be run at start up *\-final code*: code to be run
    at the end *\-trials n*: number of trials before reducing the temperature
    *\-reduce factor*: reduce the temperature by this factor \(between 0 and 1\)
    *\-initial\-temp t*: initial temperature *\-scale s*: scale of the function
    \(order of magnitude of the values\) *\-estimate\-scale y/n*: estimate the
    scale \(only if *\-scale* is not present\) *\-verbose y/n*: print detailed
    information on progress to the report file \(1\) or not \(0\) *\-reportfile
    file*: opened file to print to \(defaults to stdout\)

Any other options can be used via the getOption procedure in the body\. The
*findCombinatorialMinimum* command predefines the following options:

  - *\-number\-params n*: number of binary parameters \(the solution space
    consists of lists of 1s and 0s\)\. This is a required option\.

  - *\-initial\-values*: list of 1s and 0s constituting the start of the search\.

The other predefined options are identical to those of *findMinimum*\.

# <a name='section3'></a>TIPS

The procedure *findMinimum* works by constructing a temporary procedure that
does the actual work\. It loops until the point representing the estimated
optimum does not change anymore within the given number of trials\. As the
temperature gets lower and lower the chance of accepting a point with a higher
value becomes lower too, so the procedure will in practice terminate\.

It is possible to optimise over a non\-rectangular region, but some care must be
taken:

  - If the point is outside the region of interest, you can specify a very high
    value\.

  - This does mean that the automatic determination of a scale factor is out of
    the question \- the high function values that force the point inside the
    region would distort the estimation\.

Here is an example of finding an optimum inside a circle:

    puts [::simulation::annealing::findMinimum  -trials 3000  -reduce 0.98  -parameters {x -5.0 5.0 y -5.0 5.0}  -code {
            if { hypot($x-5.0,$y-5.0) < 4.0 } {
                set result [expr {$x*$x+$y*$y+sin(10.0*$x)+4.0*cos(20.0*$y)}]
            } else {
                set result 1.0e100
            }
        }]

The method is theoretically capable of determining the global optimum, but often
you need to use a large number of trials and a slow reduction of temperature to
get reliable and repeatable estimates\.

You can use the *\-final* option to use a deterministic optimization method,
once you are sure you are near the required optimum\.

The *findCombinatorialMinimum* procedure is suited for situations where the
parameters have the values 0 or 1 \(and there can be many of them\)\. Here is an
example:

  - We have a function that attains an absolute minimum if the first ten numbers
    are 1 and the rest is 0:

    proc cost {params} {
        set cost 0
        foreach p [lrange $params 0 9] {
            if { $p == 0 } {
                incr cost
            }
        }
        foreach p [lrange $params 10 end] {
            if { $p == 1 } {
                incr cost
            }
        }
        return $cost
    }

  - We want to find the solution that gives this minimum for various lengths of
    the solution vector *params*:

    foreach n {100 1000 10000} {
        break
        puts "Problem size: $n"
        puts [::simulation::annealing::findCombinatorialMinimum  -trials 300  -verbose 0  -number-params $n  -code {set result [cost $params]}]
    }

  - As the vector grows, the computation time increases, but the procedure will
    stop if some kind of equilibrium is reached\. To achieve a useful solution
    you may want to try different values of the trials parameter for instance\.
    Also ensure that the function to be minimized depends on all or most
    parameters \- see the source code for a counter example and run that\.

# <a name='keywords'></a>KEYWORDS

[math](\.\./\.\./\.\./\.\./index\.md\#math),
[optimization](\.\./\.\./\.\./\.\./index\.md\#optimization), [simulated
annealing](\.\./\.\./\.\./\.\./index\.md\#simulated\_annealing)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2008 Arjen Markus <arjenmarkus@users\.sourceforge\.net>
