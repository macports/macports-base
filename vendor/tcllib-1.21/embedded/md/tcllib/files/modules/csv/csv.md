
[//000000001]: # (csv \- CSV processing)
[//000000002]: # (Generated from file 'csv\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002\-2015 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (csv\(n\) 0\.8\.1 tcllib "CSV processing")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

csv \- Procedures to handle CSV data\.

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [FORMAT](#section3)

  - [EXAMPLE](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require csv ?0\.8\.1?  

[__::csv::iscomplete__ *data*](#1)  
[__::csv::join__ *values* ?*sepChar*? ?*delChar*? ?*delMode*?](#2)  
[__::csv::joinlist__ *values* ?*sepChar*? ?*delChar*? ?*delMode*?](#3)  
[__::csv::joinmatrix__ *matrix* ?*sepChar*? ?*delChar*? ?*delMode*?](#4)  
[__::csv::read2matrix__ ?__\-alternate__? *chan m* \{*sepChar* ,\} \{*expand* none\}](#5)  
[__::csv::read2queue__ ?__\-alternate__? *chan q* \{*sepChar* ,\}](#6)  
[__::csv::report__ *cmd matrix* ?*chan*?](#7)  
[__::csv::split__ ?__\-alternate__? *line* ?*sepChar*? ?*delChar*?](#8)  
[__::csv::split2matrix__ ?__\-alternate__? *m line* \{*sepChar* ,\} \{*expand* none\}](#9)  
[__::csv::split2queue__ ?__\-alternate__? *q line* \{*sepChar* ,\}](#10)  
[__::csv::writematrix__ *m chan* ?*sepChar*? ?*delChar*?](#11)  
[__::csv::writequeue__ *q chan* ?*sepChar*? ?*delChar*?](#12)  

# <a name='description'></a>DESCRIPTION

The __csv__ package provides commands to manipulate information in CSV
[FORMAT](#section3) \(CSV = Comma Separated Values\)\.

# <a name='section2'></a>COMMANDS

The following commands are available:

  - <a name='1'></a>__::csv::iscomplete__ *data*

    A predicate checking if the argument *data* is a complete csv record\. The
    result is a boolean flag indicating the completeness of the data\. The result
    is true if the data is complete\.

  - <a name='2'></a>__::csv::join__ *values* ?*sepChar*? ?*delChar*? ?*delMode*?

    Takes a list of values and returns a string in CSV format containing these
    values\. The separator character can be defined by the caller, but this is
    optional\. The default is ","\. The quoting aka delimiting character can be
    defined by the caller, but this is optional\. The default is '"'\. By default
    the quoting mode *delMode* is "auto", surrounding values with *delChar*
    only when needed\. When set to "always" however, values are always surrounded
    by the *delChar* instead\.

  - <a name='3'></a>__::csv::joinlist__ *values* ?*sepChar*? ?*delChar*? ?*delMode*?

    Takes a list of lists of values and returns a string in CSV format
    containing these values\. The separator character can be defined by the
    caller, but this is optional\. The default is ","\. The quoting character can
    be defined by the caller, but this is optional\. The default is '"'\. By
    default the quoting mode *delMode* is "auto", surrounding values with
    *delChar* only when needed\. When set to "always" however, values are
    always surrounded by the *delChar* instead\. Each element of the outer list
    is considered a record, these are separated by newlines in the result\. The
    elements of each record are formatted as usual \(via __::csv::join__\)\.

  - <a name='4'></a>__::csv::joinmatrix__ *matrix* ?*sepChar*? ?*delChar*? ?*delMode*?

    Takes a *matrix* object following the API specified for the struct::matrix
    package and returns a string in CSV format containing these values\. The
    separator character can be defined by the caller, but this is optional\. The
    default is ","\. The quoting character can be defined by the caller, but this
    is optional\. The default is '"'\. By default the quoting mode *delMode* is
    "auto", surrounding values with *delChar* only when needed\. When set to
    "always" however, values are always surrounded by the *delChar* instead\.
    Each row of the matrix is considered a record, these are separated by
    newlines in the result\. The elements of each record are formatted as usual
    \(via __::csv::join__\)\.

  - <a name='5'></a>__::csv::read2matrix__ ?__\-alternate__? *chan m* \{*sepChar* ,\} \{*expand* none\}

    A wrapper around __::csv::split2matrix__ \(see below\) reading
    CSV\-formatted lines from the specified channel \(until EOF\) and adding them
    to the given matrix\. For an explanation of the *expand* argument see
    __::csv::split2matrix__\.

  - <a name='6'></a>__::csv::read2queue__ ?__\-alternate__? *chan q* \{*sepChar* ,\}

    A wrapper around __::csv::split2queue__ \(see below\) reading
    CSV\-formatted lines from the specified channel \(until EOF\) and adding them
    to the given queue\.

  - <a name='7'></a>__::csv::report__ *cmd matrix* ?*chan*?

    A report command which can be used by the matrix methods __format
    2string__ and __format 2chan__\. For the latter this command delegates
    the work to __::csv::writematrix__\. *cmd* is expected to be either
    __printmatrix__ or __printmatrix2channel__\. The channel argument,
    *chan*, has to be present for the latter and must not be present for the
    first\.

  - <a name='8'></a>__::csv::split__ ?__\-alternate__? *line* ?*sepChar*? ?*delChar*?

    converts a *line* in CSV format into a list of the values contained in the
    line\. The character used to separate the values from each other can be
    defined by the caller, via *sepChar*, but this is optional\. The default is
    ","\. The quoting character can be defined by the caller, but this is
    optional\. The default is '"'\.

    If the option __\-alternate__ is specified a slightly different syntax is
    used to parse the input\. This syntax is explained below, in the section
    [FORMAT](#section3)\.

  - <a name='9'></a>__::csv::split2matrix__ ?__\-alternate__? *m line* \{*sepChar* ,\} \{*expand* none\}

    The same as __::csv::split__, but appends the resulting list as a new
    row to the matrix *m*, using the method __add row__\. The expansion
    mode specified via *expand* determines how the command handles a matrix
    with less columns than contained in *line*\. The allowed modes are:

      * __none__

        This is the default mode\. In this mode it is the responsibility of the
        caller to ensure that the matrix has enough columns to contain the full
        line\. If there are not enough columns the list of values is silently
        truncated at the end to fit\.

      * __empty__

        In this mode the command expands an empty matrix to hold all columns of
        the specified line, but goes no further\. The overall effect is that the
        first of a series of lines determines the number of columns in the
        matrix and all following lines are truncated to that size, as if mode
        __none__ was set\.

      * __auto__

        In this mode the command expands the matrix as needed to hold all
        columns contained in *line*\. The overall effect is that after adding a
        series of lines the matrix will have enough columns to hold all columns
        of the longest line encountered so far\.

  - <a name='10'></a>__::csv::split2queue__ ?__\-alternate__? *q line* \{*sepChar* ,\}

    The same as __::csv::split__, but appending the resulting list as a
    single item to the queue *q*, using the method __put__\.

  - <a name='11'></a>__::csv::writematrix__ *m chan* ?*sepChar*? ?*delChar*?

    A wrapper around __::csv::join__ taking all rows in the matrix *m* and
    writing them CSV formatted into the channel *chan*\.

  - <a name='12'></a>__::csv::writequeue__ *q chan* ?*sepChar*? ?*delChar*?

    A wrapper around __::csv::join__ taking all items in the queue *q*
    \(assumes that they are lists\) and writing them CSV formatted into the
    channel *chan*\.

# <a name='section3'></a>FORMAT

The format of regular CSV files is specified as

  1. Each record of a csv file \(comma\-separated values, as exported e\.g\. by
     Excel\) is a set of ASCII values separated by ","\. For other languages it
     may be ";" however, although this is not important for this case as the
     functions provided here allow any separator character\.

  1. If and only if a value contains itself the separator ",", then it \(the
     value\) has to be put between ""\. If the value does not contain the
     separator character then quoting is optional\.

  1. If a value contains the character ", that character is represented by ""\.

  1. The output string "" represents the value "\. In other words, it is assumed
     that it was created through rule 3, and only this rule, i\.e\. that the value
     was not quoted\.

An alternate format definition mainly used by MS products specifies that the
output string "" is a representation of the empty string\. In other words, it is
assumed that the output was generated out of the empty string by quoting it
\(i\.e\. rule 2\), and not through rule 3\. This is the only difference between the
regular and the alternate format\.

The alternate format is activated through specification of the option
__\-alternate__ to the various split commands\.

# <a name='section4'></a>EXAMPLE

Using the regular format the record

    123,"123,521.2","Mary says ""Hello, I am Mary""",""

is parsed into the items

    a) 123
    b) 123,521.2
    c) Mary says "Hello, I am Mary"
    d) "

Using the alternate format the result is

    a) 123
    b) 123,521.2
    c) Mary says "Hello, I am Mary"
    d) (the empty string)

instead\. As can be seen only item \(d\) is different, now the empty string instead
of a "\.

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *csv* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[matrix](\.\./\.\./\.\./\.\./index\.md\#matrix),
[queue](\.\./\.\./\.\./\.\./index\.md\#queue)

# <a name='keywords'></a>KEYWORDS

[csv](\.\./\.\./\.\./\.\./index\.md\#csv), [matrix](\.\./\.\./\.\./\.\./index\.md\#matrix),
[package](\.\./\.\./\.\./\.\./index\.md\#package),
[queue](\.\./\.\./\.\./\.\./index\.md\#queue),
[tcllib](\.\./\.\./\.\./\.\./index\.md\#tcllib)

# <a name='category'></a>CATEGORY

Text processing

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002\-2015 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
