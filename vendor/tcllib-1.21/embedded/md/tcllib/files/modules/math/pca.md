
[//000000001]: # (math::PCA \- Principal Components Analysis)
[//000000002]: # (Generated from file 'pca\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (math::PCA\(n\) 1\.0 tcllib "Principal Components Analysis")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::PCA \- Package for Principal Component Analysis

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Commands](#section2)

  - [EXAMPLE](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl ?8\.6?  
package require math::linearalgebra 1\.0  

[__::math::PCA::createPCA__ *data* ?args?](#1)  
[__$pca using__ ?number?&#124;?\-minproportion value?](#2)  
[__$pca eigenvectors__ ?option?](#3)  
[__$pca eigenvalues__ ?option?](#4)  
[__$pca proportions__ ?option?](#5)  
[__$pca approximate__ *observation*](#6)  
[__$pca approximatOriginal__](#7)  
[__$pca scores__ *observation*](#8)  
[__$pca distance__ *observation*](#9)  
[__$pca qstatistic__ *observation* ?option?](#10)  

# <a name='description'></a>DESCRIPTION

The PCA package provides a means to perform principal components analysis in
Tcl, using an object\-oriented technique as facilitated by TclOO\. It actually
defines a single public method, *::math::PCA::createPCA*, which constructs an
object based on the data that are passed to perform the actual analysis\.

The methods of the PCA objects that are created with this command allow one to
examine the principal components, to approximate \(new\) observations using all or
a selected number of components only and to examine the properties of the
components and the statistics of the approximations\.

The package has been modelled after the PCA example provided by the original
linear algebra package by Ed Hume\.

# <a name='section2'></a>Commands

The *math::PCA* package provides one public command:

  - <a name='1'></a>__::math::PCA::createPCA__ *data* ?args?

    Create a new object, based on the data that are passed via the *data*
    argument\. The principal components may be based on either correlations or
    covariances\. All observations will be normalised according to the mean and
    standard deviation of the original data\.

      * list *data*

        \- A list of observations \(see the example below\)\.

      * list *args*

        \- A list of key\-value pairs defining the options\. Currently there is
        only one key: *\-covariances*\. This indicates if covariances are to be
        used \(if the value is 1\) or instead correlations \(value is 0\)\. The
        default is to use correlations\.

The PCA object that is created has the following methods:

  - <a name='2'></a>__$pca using__ ?number?&#124;?\-minproportion value?

    Set the number of components to be used in the analysis \(the number of
    retained components\)\. Returns the number of components, also if no argument
    is given\.

      * int *number*

        \- The number of components to be retained

      * double *value*

        \- Select the number of components based on the minimum proportion of
        variation that is retained by them\. Should be a value between 0 and 1\.

  - <a name='3'></a>__$pca eigenvectors__ ?option?

    Return the eigenvectors as a list of lists\.

      * string *option*

        \- By default only the *retained* components are returned\. If all
        eigenvectors are required, use the option *\-all*\.

  - <a name='4'></a>__$pca eigenvalues__ ?option?

    Return the eigenvalues as a list of lists\.

      * string *option*

        \- By default only the eigenvalues of the *retained* components are
        returned\. If all eigenvalues are required, use the option *\-all*\.

  - <a name='5'></a>__$pca proportions__ ?option?

    Return the proportions for all components, that is, the amount of variations
    that each components can explain\.

  - <a name='6'></a>__$pca approximate__ *observation*

    Return an approximation of the observation based on the retained components

      * list *observation*

        \- The values for the observation\.

  - <a name='7'></a>__$pca approximatOriginal__

    Return an approximation of the original data, using the retained components\.
    It is a convenience method that works on the complete set of original data\.

  - <a name='8'></a>__$pca scores__ *observation*

    Return the scores per retained component for the given observation\.

      * list *observation*

        \- The values for the observation\.

  - <a name='9'></a>__$pca distance__ *observation*

    Return the distance between the given observation and its approximation\.
    \(Note: this distance is based on the normalised vectors\.\)

      * list *observation*

        \- The values for the observation\.

  - <a name='10'></a>__$pca qstatistic__ *observation* ?option?

    Return the Q statistic, basically the square of the distance, for the given
    observation\.

      * list *observation*

        \- The values for the observation\.

      * string *option*

        \- If the observation is part of the original data, you may want to use
        the corrected Q statistic\. This is achieved with the option "\-original"\.

# <a name='section3'></a>EXAMPLE

TODO: NIST example

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *PCA* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[PCA](\.\./\.\./\.\./\.\./index\.md\#pca), [math](\.\./\.\./\.\./\.\./index\.md\#math),
[statistics](\.\./\.\./\.\./\.\./index\.md\#statistics),
[tcl](\.\./\.\./\.\./\.\./index\.md\#tcl)

# <a name='category'></a>CATEGORY

Mathematics
