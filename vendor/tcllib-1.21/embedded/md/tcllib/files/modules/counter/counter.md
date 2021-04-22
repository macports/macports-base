
[//000000001]: # (counter \- Counters and Histograms)
[//000000002]: # (Generated from file 'counter\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (counter\(n\) 2\.0\.4 tcllib "Counters and Histograms")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

counter \- Procedures for counters and histograms

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8  
package require counter ?2\.0\.4?  

[__::counter::init__ *tag args*](#1)  
[__::counter::count__ *tag* ?*delta*? ?*instance*?](#2)  
[__::counter::start__ *tag instance*](#3)  
[__::counter::stop__ *tag instance*](#4)  
[__::counter::get__ *tag args*](#5)  
[__::counter::exists__ *tag*](#6)  
[__::counter::names__](#7)  
[__::counter::histHtmlDisplay__ *tag args*](#8)  
[__::counter::reset__ *tag args*](#9)  

# <a name='description'></a>DESCRIPTION

The __counter__ package provides a counter facility and can compute
statistics and histograms over the collected data\.

  - <a name='1'></a>__::counter::init__ *tag args*

    This defines a counter with the name *tag*\. The *args* determines the
    characteristics of the counter\. The *args* are

      * __\-group__ *name*

        Keep a grouped counter where the name of the histogram bucket is passed
        into __::counter::count__\.

      * __\-hist__ *bucketsize*

        Accumulate the counter into histogram buckets of size *bucketsize*\.
        For example, if the samples are millisecond time values and
        *bucketsize* is 10, then each histogram bucket represents time values
        of 0 to 10 msec, 10 to 20 msec, 20 to 30 msec, and so on\.

      * __\-hist2x__ *bucketsize*

        Accumulate the statistic into histogram buckets\. The size of the first
        bucket is *bucketsize*, each other bucket holds values 2 times the
        size of the previous bucket\. For example, if *bucketsize* is 10, then
        each histogram bucket represents time values of 0 to 10 msec, 10 to 20
        msec, 20 to 40 msec, 40 to 80 msec, and so on\.

      * __\-hist10x__ *bucketsize*

        Accumulate the statistic into histogram buckets\. The size of the first
        bucket is *bucketsize*, each other bucket holds values 10 times the
        size of the previous bucket\. For example, if *bucketsize* is 10, then
        each histogram bucket represents time values of 0 to 10 msec, 10 to 100
        msec, 100 to 1000 msec, and so on\.

      * __\-lastn__ *N*

        Save the last *N* values of the counter to maintain a "running
        average" over the last *N* values\.

      * __\-timehist__ *secsPerMinute*

        Keep a time\-based histogram\. The counter is summed into a histogram
        bucket based on the current time\. There are 60 per\-minute buckets that
        have a size determined by *secsPerMinute*, which is normally 60, but
        for testing purposes can be less\. Every "hour" \(i\.e\., 60 "minutes"\) the
        contents of the per\-minute buckets are summed into the next hourly
        bucket\. Every 24 "hours" the contents of the per\-hour buckets are summed
        into the next daily bucket\. The counter package keeps all time\-based
        histograms in sync, so the first *secsPerMinute* value seen by the
        package is used for all subsequent time\-based histograms\.

  - <a name='2'></a>__::counter::count__ *tag* ?*delta*? ?*instance*?

    Increment the counter identified by *tag*\. The default increment is 1,
    although you can increment by any value, integer or real, by specifying
    *delta*\. You must declare each counter with __::counter::init__ to
    define the characteristics of counter before you start to use it\. If the
    counter type is __\-group__, then the counter identified by *instance*
    is incremented\.

  - <a name='3'></a>__::counter::start__ *tag instance*

    Record the starting time of an interval\. The *tag* is the name of the
    counter defined as a __\-hist__ value\-based histogram\. The *instance*
    is used to distinguish this interval from any other intervals that might be
    overlapping this one\.

  - <a name='4'></a>__::counter::stop__ *tag instance*

    Record the ending time of an interval\. The delta time since the
    corresponding __::counter::start__ call for *instance* is recorded in
    the histogram identified by *tag*\.

  - <a name='5'></a>__::counter::get__ *tag args*

    Return statistics about a counter identified by *tag*\. The *args*
    determine what value to return:

      * __\-total__

        Return the total value of the counter\. This is the default if *args*
        is not specified\.

      * __\-totalVar__

        Return the name of the total variable\. Useful for specifying with
        \-textvariable in a Tk widget\.

      * __\-N__

        Return the number of samples accumulated into the counter\.

      * __\-avg__

        Return the average of samples accumulated into the counter\.

      * __\-avgn__

        Return the average over the last *N* samples taken\. The *N* value is
        set in the __::counter::init__ call\.

      * __\-hist__ *bucket*

        If *bucket* is specified, then the value in that bucket of the
        histogram is returned\. Otherwise the complete histogram is returned in
        array get format sorted by bucket\.

      * __\-histVar__

        Return the name of the histogram array variable\.

      * __\-histHour__

        Return the complete hourly histogram in array get format sorted by
        bucket\.

      * __\-histHourVar__

        Return the name of the hourly histogram array variable\.

      * __\-histDay__

        Return the complete daily histogram in array get format sorted by
        bucket\.

      * __\-histDayVar__

        Return the name of the daily histogram array variable\.

      * __\-resetDate__

        Return the clock seconds value recorded when the counter was last reset\.

      * __\-all__

        Return an array get of the array used to store the counter\. This
        includes the total, the number of samples \(N\), and any type\-specific
        information\. This does not include the histogram array\.

  - <a name='6'></a>__::counter::exists__ *tag*

    Returns 1 if the counter is defined\.

  - <a name='7'></a>__::counter::names__

    Returns a list of all counters defined\.

  - <a name='8'></a>__::counter::histHtmlDisplay__ *tag args*

    Generate HTML to display a histogram for a counter\. The *args* control the
    format of the display\. They are:

      * __\-title__ *string*

        Label to display above bar chart

      * __\-unit__ *unit*

        Specify __minutes__, __hours__, or __days__ for the
        time\-base histograms\. For value\-based histograms, the *unit* is used
        in the title\.

      * __\-images__ *url*

        URL of /images directory\.

      * __\-gif__ *filename*

        Image for normal histogram bars\. The *filename* is relative to the
        __\-images__ directory\.

      * __\-ongif__ *filename*

        Image for the active histogram bar\. The *filename* is relative to the
        __\-images__ directory\.

      * __\-max__ *N*

        Maximum number of value\-based buckets to display\.

      * __\-height__ *N*

        Pixel height of the highest bar\.

      * __\-width__ *N*

        Pixel width of each bar\.

      * __\-skip__ *N*

        Buckets to skip when labeling value\-based histograms\.

      * __\-format__ *string*

        Format used to display labels of buckets\.

      * __\-text__ *boolean*

        If 1, a text version of the histogram is dumped, otherwise a graphical
        one is generated\.

  - <a name='9'></a>__::counter::reset__ *tag args*

    Resets the counter with the name *tag* to an initial state\. The *args*
    determine the new characteristics of the counter\. They have the same meaning
    as described for __::counter::init__\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *counter* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[counting](\.\./\.\./\.\./\.\./index\.md\#counting),
[histogram](\.\./\.\./\.\./\.\./index\.md\#histogram),
[statistics](\.\./\.\./\.\./\.\./index\.md\#statistics),
[tallying](\.\./\.\./\.\./\.\./index\.md\#tallying)

# <a name='category'></a>CATEGORY

Data structures
