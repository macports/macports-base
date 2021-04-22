
[//000000001]: # (math::changepoint \- Tcl Math Library)
[//000000002]: # (Generated from file 'changepoint\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2020 by Arjen Markus)
[//000000004]: # (math::changepoint\(n\) 0\.1 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::changepoint \- Change point detection methods

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PROCEDURES](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require TclOO  
package require math::statistics  
package require math::changepoint ?0\.1?  

[__::math::changepoint::cusum\-detect__ *data* ?args?](#1)  
[__::math::changepoint::cusum\-online__ ?args?](#2)  
[__$cusumObj__ examine *value*](#3)  
[__$cusumObj__ reset](#4)  
[__::math::changepoint::binary\-segmentation__ *data* ?args?](#5)  

# <a name='description'></a>DESCRIPTION

The __math::changepoint__ package implements a number of well\-known methods
to determine if a series of data contains a shift in the mean or not\. Note that
these methods only indicate if a shift in the mean is probably\. Due to the
stochastic nature of the data that will be analysed, false positives are
possible\. The CUSUM method is implemented in both an "offline" and an "online"
version, so that it can be used either for a complete data series or for
detecting changes in data that come in one by one\. The implementation has been
based on these websites mostly:

  - [https://www\.itl\.nist\.gov/div898/handbook/pmc/section3/pmc323\.htm](https://www\.itl\.nist\.gov/div898/handbook/pmc/section3/pmc323\.htm)

  - [https://en\.wikipedia\.org/wiki/CUSUM](https://en\.wikipedia\.org/wiki/CUSUM)

Basically, the deviation of the data from a given target value is accumulated
and when the total deviation becomes too large, a change point is reported\. A
second method, binary segmentation, is implemented only as an "offline" method,
as it needs to examine the data series as a whole\. In the variant contained here
the following ideas have been used:

  - The segments in which the data series may be separated shold not be too
    short, otherwise the ultimate result could be segments of only one data
    point long\. So a minimum length is used\.

  - To make the segmentation worthwhile there should be a minimum gain in
    reducing the cost function \(the sum of the squared deviations from the mean
    for each segment\)\.

This may not be in agreement with the descriptions of the method found in
various publications, but it is simple to understand and intuitive\. One
publication that provides more information on the method in general is
"Selective review of offline change point detection methods" by Truong et al\.
[https://arxiv\.org/abs/1801\.00718](https://arxiv\.org/abs/1801\.00718)\.

# <a name='section2'></a>PROCEDURES

The package defines the following public procedures:

  - <a name='1'></a>__::math::changepoint::cusum\-detect__ *data* ?args?

    Examine a given data series and return the location of the first change \(if
    any\)

      * double *data*

        Series of data to be examined

      * list *args*

        Optional list of key\-value pairs:

          + __\-target__ *value*

            The target \(or mean\) for the time series

          + __\-tolerance__ *value*

            The tolerated standard deviation

          + __\-kfactor__ *value*

            The factor by which to multiply the standard deviation \(defaults to
            0\.5, typically between 0\.5 and 1\.0\)

          + __\-hfactor__ *value*

            The factor determining the limits betweem which the "cusum"
            statistic is accepted \(typicaly 3\.0\-5\.0, default 4\.0\)

  - <a name='2'></a>__::math::changepoint::cusum\-online__ ?args?

    Class to examine data passed in against expected properties\. At least the
    keywords *\-target* and *\-tolerance* must be given\.

      * list *args*

        List of key\-value pairs:

          + __\-target__ *value*

            The target \(or mean\) for the time series

          + __\-tolerance__ *value*

            The tolerated standard deviation

          + __\-kfactor__ *value*

            The factor by which to multiply the standard deviation \(defaults to
            0\.5, typically between 0\.5 and 1\.0\)

          + __\-hfactor__ *value*

            The factor determining the limits betweem which the "cusum"
            statistic is accepted \(typicaly 3\.0\-5\.0, default 4\.0\)

  - <a name='3'></a>__$cusumObj__ examine *value*

    Pass a value to the *cusum\-online* object and examine it\. If, with this
    new value, the cumulative sum remains within the bounds, zero \(0\) is
    returned, otherwise one \(1\) is returned\.

      * double *value*

        The new value

  - <a name='4'></a>__$cusumObj__ reset

    Reset the cumulative sum, so that the examination can start afresh\.

  - <a name='5'></a>__::math::changepoint::binary\-segmentation__ *data* ?args?

    Apply the binary segmentation method recursively to find change points\.
    Returns a list of indices of potential change points

      * list *data*

        Data to be examined

      * list *args*

        Optional key\-value pairs:

          + __\-minlength__ *number*

            Minimum number of points in each segment \(default: 5\)

          + __\-threshold__ *value*

            Factor applied to the standard deviation functioning as a threshold
            for accepting the change in cost function as an improvement
            \(default: 1\.0\)

# <a name='keywords'></a>KEYWORDS

[control](\.\./\.\./\.\./\.\./index\.md\#control),
[statistics](\.\./\.\./\.\./\.\./index\.md\#statistics)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2020 by Arjen Markus
