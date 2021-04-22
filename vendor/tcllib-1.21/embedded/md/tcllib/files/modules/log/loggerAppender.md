
[//000000001]: # (logger::appender \- Object Oriented logging facility)
[//000000002]: # (Generated from file 'loggerAppender\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005 Aamer Akhter <aakhter@cisco\.com>)
[//000000004]: # (logger::appender\(n\) 1\.2 tcllib "Object Oriented logging facility")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

logger::appender \- Collection of predefined appenders for logger

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require logger::appender ?1\.2?  

[__::logger::appender::console__ __\-level__ *level* __\-service__ *service* ?*options*\.\.\.?](#1)  
[__::logger::appender::colorConsole__ __\-level__ *level* __\-service__ *service* ?*options*\.\.\.?](#2)  

# <a name='description'></a>DESCRIPTION

This package provides a predefined set of logger templates\.

  - <a name='1'></a>__::logger::appender::console__ __\-level__ *level* __\-service__ *service* ?*options*\.\.\.?

      * __\-level__ level

        Name of the level to fill in as "priority" in the log procedure\.

      * __\-service__ service

        Name of the service to fill in as "category" in the log procedure\.

      * __\-appenderArgs__ appenderArgs

        Any additional arguments for the log procedure in list form

      * __\-conversionPattern__ conversionPattern

        The log pattern to use \(see __logger::utils::createLogProc__ for the
        allowed substitutions\)\.

      * __\-procName__ procName

        Explicitly set the name of the created procedure\.

      * __\-procNameVar__ procNameVar

        Name of the variable to set in the calling context\. This variable will
        contain the name of the procedure\.

  - <a name='2'></a>__::logger::appender::colorConsole__ __\-level__ *level* __\-service__ *service* ?*options*\.\.\.?

    See __::logger::appender::colorConsole__ for a description of the
    applicable options\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *logger* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[appender](\.\./\.\./\.\./\.\./index\.md\#appender),
[logger](\.\./\.\./\.\./\.\./index\.md\#logger)

# <a name='category'></a>CATEGORY

Programming tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005 Aamer Akhter <aakhter@cisco\.com>
