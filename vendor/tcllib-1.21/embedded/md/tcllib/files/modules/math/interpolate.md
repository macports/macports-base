
[//000000001]: # (math::interpolate \- Tcl Math Library)
[//000000002]: # (Generated from file 'interpolate\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004 Arjen Markus <arjenmarkus@users\.sourceforge\.net>)
[//000000004]: # (Copyright &copy; 2004 Kevn B\. Kenny <kennykb@users\.sourceforge\.net>)
[//000000005]: # (math::interpolate\(n\) 1\.1 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::interpolate \- Interpolation routines

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [INCOMPATIBILITY WITH VERSION 1\.0\.3](#section2)

  - [PROCEDURES](#section3)

  - [EXAMPLES](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl ?8\.4?  
package require struct  
package require math::interpolate ?1\.1?  

[__::math::interpolate::defineTable__ *name* *colnames* *values*](#1)  
[__::math::interpolate::interp\-1d\-table__ *name* *xval*](#2)  
[__::math::interpolate::interp\-table__ *name* *xval* *yval*](#3)  
[__::math::interpolate::interp\-linear__ *xyvalues* *xval*](#4)  
[__::math::interpolate::interp\-lagrange__ *xyvalues* *xval*](#5)  
[__::math::interpolate::prepare\-cubic\-splines__ *xcoord* *ycoord*](#6)  
[__::math::interpolate::interp\-cubic\-splines__ *coeffs* *x*](#7)  
[__::math::interpolate::interp\-spatial__ *xyvalues* *coord*](#8)  
[__::math::interpolate::interp\-spatial\-params__ *max\_search* *power*](#9)  
[__::math::interpolate::neville__ *xlist* *ylist* *x*](#10)  

# <a name='description'></a>DESCRIPTION

This package implements several interpolation algorithms:

  - Interpolation into a table \(one or two independent variables\), this is
    useful for example, if the data are static, like with tables of statistical
    functions\.

  - Linear interpolation into a given set of data \(organised as \(x,y\) pairs\)\.

  - Lagrange interpolation\. This is mainly of theoretical interest, because
    there is no guarantee about error bounds\. One possible use: if you need a
    line or a parabola through given points \(it will calculate the values, but
    not return the coefficients\)\.

    A variation is Neville's method which has better behaviour and error bounds\.

  - Spatial interpolation using a straightforward distance\-weight method\. This
    procedure allows any number of spatial dimensions and any number of
    dependent variables\.

  - Interpolation in one dimension using cubic splines\.

This document describes the procedures and explains their usage\.

# <a name='section2'></a>INCOMPATIBILITY WITH VERSION 1\.0\.3

The interpretation of the tables in the
__::math::interpolate::interpolate\-1d\-table__ command has been changed to be
compatible with the interpretation for 2D interpolation in the
__::math::interpolate::interpolate\-table__ command\. As a consequence this
version is incompatible with the previous versions of the command \(1\.0\.x\)\.

# <a name='section3'></a>PROCEDURES

The interpolation package defines the following public procedures:

  - <a name='1'></a>__::math::interpolate::defineTable__ *name* *colnames* *values*

    Define a table with one or two independent variables \(the distinction is
    implicit in the data\)\. The procedure returns the name of the table \- this
    name is used whenever you want to interpolate the values\. *Note:* this
    procedure is a convenient wrapper for the struct::matrix procedure\.
    Therefore you can access the data at any location in your program\.

      * string *name* \(in\)

        Name of the table to be created

      * list *colnames* \(in\)

        List of column names

      * list *values* \(in\)

        List of values \(the number of elements should be a multiple of the
        number of columns\. See [EXAMPLES](#section4) for more information
        on the interpretation of the data\.

        The values must be sorted with respect to the independent variable\(s\)\.

  - <a name='2'></a>__::math::interpolate::interp\-1d\-table__ *name* *xval*

    Interpolate into the one\-dimensional table "name" and return a list of
    values, one for each dependent column\.

      * string *name* \(in\)

        Name of an existing table

      * float *xval* \(in\)

        Value of the independent *row* variable

  - <a name='3'></a>__::math::interpolate::interp\-table__ *name* *xval* *yval*

    Interpolate into the two\-dimensional table "name" and return the
    interpolated value\.

      * string *name* \(in\)

        Name of an existing table

      * float *xval* \(in\)

        Value of the independent *row* variable

      * float *yval* \(in\)

        Value of the independent *column* variable

  - <a name='4'></a>__::math::interpolate::interp\-linear__ *xyvalues* *xval*

    Interpolate linearly into the list of x,y pairs and return the interpolated
    value\.

      * list *xyvalues* \(in\)

        List of pairs of \(x,y\) values, sorted to increasing x\. They are used as
        the breakpoints of a piecewise linear function\.

      * float *xval* \(in\)

        Value of the independent variable for which the value of y must be
        computed\.

  - <a name='5'></a>__::math::interpolate::interp\-lagrange__ *xyvalues* *xval*

    Use the list of x,y pairs to construct the unique polynomial of lowest
    degree that passes through all points and return the interpolated value\.

      * list *xyvalues* \(in\)

        List of pairs of \(x,y\) values

      * float *xval* \(in\)

        Value of the independent variable for which the value of y must be
        computed\.

  - <a name='6'></a>__::math::interpolate::prepare\-cubic\-splines__ *xcoord* *ycoord*

    Returns a list of coefficients for the second routine
    *interp\-cubic\-splines* to actually interpolate\.

      * list *xcoord*

        List of x\-coordinates for the value of the function to be interpolated
        is known\. The coordinates must be strictly ascending\. At least three
        points are required\.

      * list *ycoord*

        List of y\-coordinates \(the values of the function at the given
        x\-coordinates\)\.

  - <a name='7'></a>__::math::interpolate::interp\-cubic\-splines__ *coeffs* *x*

    Returns the interpolated value at coordinate x\. The coefficients are
    computed by the procedure *prepare\-cubic\-splines*\.

      * list *coeffs*

        List of coefficients as returned by prepare\-cubic\-splines

      * float *x*

        x\-coordinate at which to estimate the function\. Must be between the
        first and last x\-coordinate for which values were given\.

  - <a name='8'></a>__::math::interpolate::interp\-spatial__ *xyvalues* *coord*

    Use a straightforward interpolation method with weights as function of the
    inverse distance to interpolate in 2D and N\-dimensional space

    The list xyvalues is a list of lists:

            {   {x1 y1 z1 {v11 v12 v13 v14}}
        	{x2 y2 z2 {v21 v22 v23 v24}}
        	...
            }

    The last element of each inner list is either a single number or a list in
    itself\. In the latter case the return value is a list with the same number
    of elements\.

    The method is influenced by the search radius and the power of the inverse
    distance

      * list *xyvalues* \(in\)

        List of lists, each sublist being a list of coordinates and of dependent
        values\.

      * list *coord* \(in\)

        List of coordinates for which the values must be calculated

  - <a name='9'></a>__::math::interpolate::interp\-spatial\-params__ *max\_search* *power*

    Set the parameters for spatial interpolation

      * float *max\_search* \(in\)

        Search radius \(data points further than this are ignored\)

      * integer *power* \(in\)

        Power for the distance \(either 1 or 2; defaults to 2\)

  - <a name='10'></a>__::math::interpolate::neville__ *xlist* *ylist* *x*

    Interpolates between the tabulated values of a function whose abscissae are
    *xlist* and whose ordinates are *ylist* to produce an estimate for the
    value of the function at *x*\. The result is a two\-element list; the first
    element is the function's estimated value, and the second is an estimate of
    the absolute error of the result\. Neville's algorithm for polynomial
    interpolation is used\. Note that a large table of values will use an
    interpolating polynomial of high degree, which is likely to result in
    numerical instabilities; one is better off using only a few tabulated values
    near the desired abscissa\.

# <a name='section4'></a>EXAMPLES

*Example of using one\-dimensional tables:*

Suppose you have several tabulated functions of one variable:

      x     y1     y2
    0.0    0.0    0.0
    1.0    1.0    1.0
    2.0    4.0    8.0
    3.0    9.0   27.0
    4.0   16.0   64.0

Then to estimate the values at 0\.5, 1\.5, 2\.5 and 3\.5, you can use:

    set table [::math::interpolate::defineTable table1  {x y1 y2} {   -      1      2
                    0.0    0.0    0.0
                    1.0    1.0    1.0
                    2.0    4.0    8.0
                    3.0    9.0   27.0
                    4.0   16.0   64.0}]
    foreach x {0.5 1.5 2.5 3.5} {
        puts "$x: [::math::interpolate::interp-1d-table $table $x]"
    }

For one\-dimensional tables the first row is not used\. For two\-dimensional
tables, the first row represents the values for the second independent variable\.

*Example of using the cubic splines:*

Suppose the following values are given:

      x       y
    0.1     1.0
    0.3     2.1
    0.4     2.2
    0.8     4.11
    1.0     4.12

Then to estimate the values at 0\.1, 0\.2, 0\.3, \.\.\. 1\.0, you can use:

    set coeffs [::math::interpolate::prepare-cubic-splines  {0.1 0.3 0.4 0.8  1.0}  {1.0 2.1 2.2 4.11 4.12}]
    foreach x {0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0} {
       puts "$x: [::math::interpolate::interp-cubic-splines $coeffs $x]"
    }

to get the following output:

    0.1: 1.0
    0.2: 1.68044117647
    0.3: 2.1
    0.4: 2.2
    0.5: 3.11221507353
    0.6: 4.25242647059
    0.7: 5.41804227941
    0.8: 4.11
    0.9: 3.95675857843
    1.0: 4.12

As you can see, the values at the abscissae are reproduced perfectly\.

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: interpolate* of
the [Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also
report any ideas for enhancements you may have for either package and/or
documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[interpolation](\.\./\.\./\.\./\.\./index\.md\#interpolation),
[math](\.\./\.\./\.\./\.\./index\.md\#math), [spatial
interpolation](\.\./\.\./\.\./\.\./index\.md\#spatial\_interpolation)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004 Arjen Markus <arjenmarkus@users\.sourceforge\.net>  
Copyright &copy; 2004 Kevn B\. Kenny <kennykb@users\.sourceforge\.net>
