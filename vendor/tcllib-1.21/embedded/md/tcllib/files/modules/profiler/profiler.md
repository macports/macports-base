
[//000000001]: # (profiler \- Tcl Profiler)
[//000000002]: # (Generated from file 'profiler\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (profiler\(n\) 0\.6 tcllib "Tcl Profiler")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

profiler \- Tcl source code profiler

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.3  
package require profiler ?0\.6?  

[__::profiler::init__](#1)  
[__::profiler::dump__ *pattern*](#2)  
[__::profiler::print__ ?*pattern*?](#3)  
[__::profiler::reset__ ?*pattern*?](#4)  
[__::profiler::suspend__ ?*pattern*?](#5)  
[__::profiler::resume__ ?*pattern*?](#6)  
[__::profiler::new\-disabled__](#7)  
[__::profiler::new\-enabled__](#8)  
[__::profiler::sortFunctions__ *key*](#9)  

# <a name='description'></a>DESCRIPTION

The __profiler__ package provides a simple Tcl source code profiler\. It is a
function\-level profiler; that is, it collects only function\-level information,
not the more detailed line\-level information\. It operates by redefining the Tcl
__[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ command\. Profiling is initiated
via the __::profiler::init__ command\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::profiler::init__

    Initiate profiling\. All procedures created after this command is called will
    be profiled\. To profile an entire application, this command must be called
    before any other commands\.

  - <a name='2'></a>__::profiler::dump__ *pattern*

    Dump profiling information for the all functions matching *pattern*\. If no
    pattern is specified, information for all functions will be returned\. The
    result is a list of key/value pairs that maps function names to information
    about that function\. The information about each function is in turn a list
    of key/value pairs\. The keys used and their values are:

      * __totalCalls__

        The total number of times *functionName* was called\.

      * __callerDist__

        A list of key/value pairs mapping each calling function that called
        *functionName* to the number of times it called *functionName*\.

      * __compileTime__

        The runtime, in clock clicks, of *functionName* the first time that it
        was called\.

      * __totalRuntime__

        The sum of the runtimes of all calls of *functionName*\.

      * __averageRuntime__

        Average runtime of *functionName*\.

      * __descendantTime__

        Sum of the time spent in descendants of *functionName*\.

      * __averageDescendantTime__

        Average time spent in descendants of *functionName*\.

  - <a name='3'></a>__::profiler::print__ ?*pattern*?

    Print profiling information for all functions matching *pattern*\. If no
    pattern is specified, information about all functions will be displayed\. The
    return result is a human readable display of the profiling information\.

  - <a name='4'></a>__::profiler::reset__ ?*pattern*?

    Reset profiling information for all functions matching *pattern*\. If no
    pattern is specified, information will be reset for all functions\.

  - <a name='5'></a>__::profiler::suspend__ ?*pattern*?

    Suspend profiling for all functions matching *pattern*\. If no pattern is
    specified, profiling will be suspended for all functions\. It stops gathering
    profiling information after this command is issued\. However, it does not
    erase any profiling information that has been gathered previously\. Use
    resume command to re\-enable profiling\.

  - <a name='6'></a>__::profiler::resume__ ?*pattern*?

    Resume profiling for all functions matching *pattern*\. If no pattern is
    specified, profiling will be resumed for all functions\. This command should
    be invoked after suspending the profiler in the code\.

  - <a name='7'></a>__::profiler::new\-disabled__

    Change the initial profiling state for new procedures\. Invoking this command
    disables profiling for all procedures created after this command until
    __new\-enabled__ is invoked\. Activate profiling of specific procedures
    via __resume__\.

  - <a name='8'></a>__::profiler::new\-enabled__

    Change the initial profiling state for new procedures\. Invoking this command
    enables profiling for all procedures created after this command until
    __new\-disabled__ is invoked\. Prevent profiling of specific procedures
    via __suspend__\.

  - <a name='9'></a>__::profiler::sortFunctions__ *key*

    Return a list of functions sorted by a particular profiling statistic\.
    Supported values for *key* are: __calls__, __exclusiveTime__,
    __compileTime__, __nonCompileTime__, __totalRuntime__,
    __avgExclusiveTime__, and __avgRuntime__\. The return result is a
    list of lists, where each sublist consists of a function name and the value
    of *key* for that function\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *profiler* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[performance](\.\./\.\./\.\./\.\./index\.md\#performance),
[profile](\.\./\.\./\.\./\.\./index\.md\#profile),
[speed](\.\./\.\./\.\./\.\./index\.md\#speed)

# <a name='category'></a>CATEGORY

Programming tools
