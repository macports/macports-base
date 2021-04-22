
[//000000001]: # (math::figurate \- Tcl Math Library)
[//000000002]: # (Generated from file 'figurate\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (math::figurate\(n\) 1\.0 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::figurate \- Evaluate figurate numbers

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PROCEDURES](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require math::figurate 1\.0  

[__::math::figurate::sum\_sequence__ *n*](#1)  
[__::math::figurate::sum\_squares__ *n*](#2)  
[__::math::figurate::sum\_cubes__ *n*](#3)  
[__::math::figurate::sum\_4th\_power__ *n*](#4)  
[__::math::figurate::sum\_5th\_power__ *n*](#5)  
[__::math::figurate::sum\_6th\_power__ *n*](#6)  
[__::math::figurate::sum\_7th\_power__ *n*](#7)  
[__::math::figurate::sum\_8th\_power__ *n*](#8)  
[__::math::figurate::sum\_9th\_power__ *n*](#9)  
[__::math::figurate::sum\_10th\_power__ *n*](#10)  
[__::math::figurate::sum\_sequence\_odd__ *n*](#11)  
[__::math::figurate::sum\_squares\_odd__ *n*](#12)  
[__::math::figurate::sum\_cubes\_odd__ *n*](#13)  
[__::math::figurate::sum\_4th\_power\_odd__ *n*](#14)  
[__::math::figurate::sum\_5th\_power\_odd__ *n*](#15)  
[__::math::figurate::sum\_6th\_power\_odd__ *n*](#16)  
[__::math::figurate::sum\_7th\_power\_odd__ *n*](#17)  
[__::math::figurate::sum\_8th\_power\_odd__ *n*](#18)  
[__::math::figurate::sum\_9th\_power\_odd__ *n*](#19)  
[__::math::figurate::sum\_10th\_power\_odd__ *n*](#20)  
[__::math::figurate::oblong__ *n*](#21)  
[__::math::figurate::pronic__ *n*](#22)  
[__::math::figurate::triangular__ *n*](#23)  
[__::math::figurate::square__ *n*](#24)  
[__::math::figurate::cubic__ *n*](#25)  
[__::math::figurate::biquadratic__ *n*](#26)  
[__::math::figurate::centeredTriangular__ *n*](#27)  
[__::math::figurate::centeredSquare__ *n*](#28)  
[__::math::figurate::centeredPentagonal__ *n*](#29)  
[__::math::figurate::centeredHexagonal__ *n*](#30)  
[__::math::figurate::centeredCube__ *n*](#31)  
[__::math::figurate::decagonal__ *n*](#32)  
[__::math::figurate::heptagonal__ *n*](#33)  
[__::math::figurate::hexagonal__ *n*](#34)  
[__::math::figurate::octagonal__ *n*](#35)  
[__::math::figurate::octahedral__ *n*](#36)  
[__::math::figurate::pentagonal__ *n*](#37)  
[__::math::figurate::squarePyramidral__ *n*](#38)  
[__::math::figurate::tetrahedral__ *n*](#39)  
[__::math::figurate::pentatope__ *n*](#40)  

# <a name='description'></a>DESCRIPTION

Sums of numbers that follow a particular pattern are called figurate numbers\. A
simple example is the sum of integers 1, 2, \.\.\. up to n\. You can arrange 1,
1\+2=3, 1\+2\+3=6, \.\.\. objects in a triangle, hence the name triangular numbers:

    *
    *  *
    *  *  *
    *  *  *  *
    ...

The __math::figurate__ package consists of a collection of procedures to
evaluate a wide variety of figurate numbers\. While all formulae are
straightforward, the details are sometimes puzzling\. *Note:* The procedures
consider arguments lower than zero as to mean "no objects to be counted" and
therefore return 0\.

# <a name='section2'></a>PROCEDURES

The procedures can be arranged in a few categories: sums of integers raised to a
particular power, sums of odd integers and general figurate numbers, for
instance the pentagonal numbers\.

  - <a name='1'></a>__::math::figurate::sum\_sequence__ *n*

    Return the sum of integers 1, 2, \.\.\., n\.

      * int *n*

        Highest integer in the sum

  - <a name='2'></a>__::math::figurate::sum\_squares__ *n*

    Return the sum of squares 1\*\*2, 2\*\*2, \.\.\., n\*\*2\.

      * int *n*

        Highest base integer in the sum

  - <a name='3'></a>__::math::figurate::sum\_cubes__ *n*

    Return the sum of cubes 1\*\*3, 2\*\*3, \.\.\., n\*\*3\.

      * int *n*

        Highest base integer in the sum

  - <a name='4'></a>__::math::figurate::sum\_4th\_power__ *n*

    Return the sum of 4th powers 1\*\*4, 2\*\*4, \.\.\., n\*\*4\.

      * int *n*

        Highest base integer in the sum

  - <a name='5'></a>__::math::figurate::sum\_5th\_power__ *n*

    Return the sum of 5th powers 1\*\*5, 2\*\*5, \.\.\., n\*\*5\.

      * int *n*

        Highest base integer in the sum

  - <a name='6'></a>__::math::figurate::sum\_6th\_power__ *n*

    Return the sum of 6th powers 1\*\*6, 2\*\*6, \.\.\., n\*\*6\.

      * int *n*

        Highest base integer in the sum

  - <a name='7'></a>__::math::figurate::sum\_7th\_power__ *n*

    Return the sum of 7th powers 1\*\*7, 2\*\*7, \.\.\., n\*\*7\.

      * int *n*

        Highest base integer in the sum

  - <a name='8'></a>__::math::figurate::sum\_8th\_power__ *n*

    Return the sum of 8th powers 1\*\*8, 2\*\*8, \.\.\., n\*\*8\.

      * int *n*

        Highest base integer in the sum

  - <a name='9'></a>__::math::figurate::sum\_9th\_power__ *n*

    Return the sum of 9th powers 1\*\*9, 2\*\*9, \.\.\., n\*\*9\.

      * int *n*

        Highest base integer in the sum

  - <a name='10'></a>__::math::figurate::sum\_10th\_power__ *n*

    Return the sum of 10th powers 1\*\*10, 2\*\*10, \.\.\., n\*\*10\.

      * int *n*

        Highest base integer in the sum

  - <a name='11'></a>__::math::figurate::sum\_sequence\_odd__ *n*

    Return the sum of odd integers 1, 3, \.\.\., 2n\-1

      * int *n*

        Highest integer in the sum

  - <a name='12'></a>__::math::figurate::sum\_squares\_odd__ *n*

    Return the sum of odd squares 1\*\*2, 3\*\*2, \.\.\., \(2n\-1\)\*\*2\.

      * int *n*

        Highest base integer in the sum

  - <a name='13'></a>__::math::figurate::sum\_cubes\_odd__ *n*

    Return the sum of odd cubes 1\*\*3, 3\*\*3, \.\.\., \(2n\-1\)\*\*3\.

      * int *n*

        Highest base integer in the sum

  - <a name='14'></a>__::math::figurate::sum\_4th\_power\_odd__ *n*

    Return the sum of odd 4th powers 1\*\*4, 2\*\*4, \.\.\., \(2n\-1\)\*\*4\.

      * int *n*

        Highest base integer in the sum

  - <a name='15'></a>__::math::figurate::sum\_5th\_power\_odd__ *n*

    Return the sum of odd 5th powers 1\*\*5, 2\*\*5, \.\.\., \(2n\-1\)\*\*5\.

      * int *n*

        Highest base integer in the sum

  - <a name='16'></a>__::math::figurate::sum\_6th\_power\_odd__ *n*

    Return the sum of odd 6th powers 1\*\*6, 2\*\*6, \.\.\., \(2n\-1\)\*\*6\.

      * int *n*

        Highest base integer in the sum

  - <a name='17'></a>__::math::figurate::sum\_7th\_power\_odd__ *n*

    Return the sum of odd 7th powers 1\*\*7, 2\*\*7, \.\.\., \(2n\-1\)\*\*7\.

      * int *n*

        Highest base integer in the sum

  - <a name='18'></a>__::math::figurate::sum\_8th\_power\_odd__ *n*

    Return the sum of odd 8th powers 1\*\*8, 2\*\*8, \.\.\., \(2n\-1\)\*\*8\.

      * int *n*

        Highest base integer in the sum

  - <a name='19'></a>__::math::figurate::sum\_9th\_power\_odd__ *n*

    Return the sum of odd 9th powers 1\*\*9, 2\*\*9, \.\.\., \(2n\-1\)\*\*9\.

      * int *n*

        Highest base integer in the sum

  - <a name='20'></a>__::math::figurate::sum\_10th\_power\_odd__ *n*

    Return the sum of odd 10th powers 1\*\*10, 2\*\*10, \.\.\., \(2n\-1\)\*\*10\.

      * int *n*

        Highest base integer in the sum

  - <a name='21'></a>__::math::figurate::oblong__ *n*

    Return the nth oblong number \(twice the nth triangular number\)

      * int *n*

        Required index

  - <a name='22'></a>__::math::figurate::pronic__ *n*

    Return the nth pronic number \(synonym for oblong\)

      * int *n*

        Required index

  - <a name='23'></a>__::math::figurate::triangular__ *n*

    Return the nth triangular number

      * int *n*

        Required index

  - <a name='24'></a>__::math::figurate::square__ *n*

    Return the nth square number

      * int *n*

        Required index

  - <a name='25'></a>__::math::figurate::cubic__ *n*

    Return the nth cubic number

      * int *n*

        Required index

  - <a name='26'></a>__::math::figurate::biquadratic__ *n*

    Return the nth biquaratic number \(i\.e\. n\*\*4\)

      * int *n*

        Required index

  - <a name='27'></a>__::math::figurate::centeredTriangular__ *n*

    Return the nth centered triangular number \(items arranged in concentric
    squares\)

      * int *n*

        Required index

  - <a name='28'></a>__::math::figurate::centeredSquare__ *n*

    Return the nth centered square number \(items arranged in concentric squares\)

      * int *n*

        Required index

  - <a name='29'></a>__::math::figurate::centeredPentagonal__ *n*

    Return the nth centered pentagonal number \(items arranged in concentric
    pentagons\)

      * int *n*

        Required index

  - <a name='30'></a>__::math::figurate::centeredHexagonal__ *n*

    Return the nth centered hexagonal number \(items arranged in concentric
    hexagons\)

      * int *n*

        Required index

  - <a name='31'></a>__::math::figurate::centeredCube__ *n*

    Return the nth centered cube number \(items arranged in concentric cubes\)

      * int *n*

        Required index

  - <a name='32'></a>__::math::figurate::decagonal__ *n*

    Return the nth decagonal number \(items arranged in decagons with one common
    vertex\)

      * int *n*

        Required index

  - <a name='33'></a>__::math::figurate::heptagonal__ *n*

    Return the nth heptagonal number \(items arranged in heptagons with one
    common vertex\)

      * int *n*

        Required index

  - <a name='34'></a>__::math::figurate::hexagonal__ *n*

    Return the nth hexagonal number \(items arranged in hexagons with one common
    vertex\)

      * int *n*

        Required index

  - <a name='35'></a>__::math::figurate::octagonal__ *n*

    Return the nth octagonal number \(items arranged in octagons with one common
    vertex\)

      * int *n*

        Required index

  - <a name='36'></a>__::math::figurate::octahedral__ *n*

    Return the nth octahedral number \(items arranged in octahedrons with a
    common centre\)

      * int *n*

        Required index

  - <a name='37'></a>__::math::figurate::pentagonal__ *n*

    Return the nth pentagonal number \(items arranged in pentagons with one
    common vertex\)

      * int *n*

        Required index

  - <a name='38'></a>__::math::figurate::squarePyramidral__ *n*

    Return the nth square pyramidral number \(items arranged in a square pyramid\)

      * int *n*

        Required index

  - <a name='39'></a>__::math::figurate::tetrahedral__ *n*

    Return the nth tetrahedral number \(items arranged in a triangular pyramid\)

      * int *n*

        Required index

  - <a name='40'></a>__::math::figurate::pentatope__ *n*

    Return the nth pentatope number \(items arranged in the four\-dimensional
    analogue of a triangular pyramid\)

      * int *n*

        Required index

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: figurate* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[figurate numbers](\.\./\.\./\.\./\.\./index\.md\#figurate\_numbers),
[mathematics](\.\./\.\./\.\./\.\./index\.md\#mathematics)

# <a name='category'></a>CATEGORY

Mathematics
