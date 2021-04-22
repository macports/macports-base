
[//000000001]: # (logger::utils \- Object Oriented logging facility)
[//000000002]: # (Generated from file 'loggerUtils\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005 Aamer Akhter <aakhter@cisco\.com>)
[//000000004]: # (logger::utils\(n\) 1\.3\.1 tcllib "Object Oriented logging facility")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

logger::utils \- Utilities for logger

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require logger::utils ?1\.3\.1?  

[__::logger::utils::createFormatCmd__ *formatString*](#1)  
[__::logger::utils::createLogProc__ __\-procName__ *procName* ?*options*\.\.\.?](#2)  
[__::logger::utils::applyAppender__ __\-appender__ *appenderType* ?*options*\.\.\.?](#3)  
[__::logger::utils::autoApplyAppender__ *command* *command\-string* *log* *op* *args*\.\.\.](#4)  

# <a name='description'></a>DESCRIPTION

This package adds template based *appenders*\.

  - <a name='1'></a>__::logger::utils::createFormatCmd__ *formatString*

    This command translates *formatString* into an expandable command string\.
    The following strings are the known substitutions \(from log4perl\) allowed to
    occur in the *formatString*:

      * %c

        Category of the logging event

      * %C

        Fully qualified name of logging event

      * %d

        Current date in yyyy/MM/dd hh:mm:ss

      * %H

        Hostname

      * %m

        Message to be logged

      * %M

        Method where logging event was issued

      * %p

        Priority of logging event

      * %P

        Pid of current process

  - <a name='2'></a>__::logger::utils::createLogProc__ __\-procName__ *procName* ?*options*\.\.\.?

    This command \.\.\.

      * __\-procName__ procName

        The name of the procedure to create\.

      * __\-conversionPattern__ pattern

        See __::logger::utils::createFormatCmd__ for the substitutions
        allowed in the *pattern*\.

      * __\-category__ category

        The category \(service\)\.

      * __\-priority__ priority

        The priority \(level\)\.

      * __\-outputChannel__ channel

        channel to output on \(default stdout\)

  - <a name='3'></a>__::logger::utils::applyAppender__ __\-appender__ *appenderType* ?*options*\.\.\.?

    This command will create an appender for the specified logger services\. If
    no service is specified then the appender will be added as the default
    appender for the specified levels\. If no levels are specified, then all
    levels are assumed\.

      * __\-service__ loggerservices

      * __\-serviceCmd__ loggerserviceCmds

        Name of the logger instance to modify\. __\-serviceCmd__ takes as
        input the return of __logger::init__\.

      * __\-appender__ appenderType

        Type of the appender to use\. One of __console__,
        __colorConsole__\.

      * __\-appenderArgs__ appenderArgs

        Additional arguments to apply to the appender\. The argument of the
        option is a list of options and their arguments\.

        For example

            logger::utils::applyAppender -serviceCmd $log -appender console -appenderArgs {-conversionPattern {\[%M\] \[%p\] - %m}}

        The usual Tcl quoting rules apply\.

      * __\-levels__ levelList

        The list of levels to apply this appender to\. If not specified all
        levels are assumed\.

    Example of usage:

        % set log [logger::init testLog]
        ::logger::tree::testLog
        % logger::utils::applyAppender -appender console -serviceCmd $log
        % ${log}::error "this is an error"
        [2005/08/22 10:14:13] [testLog] [global] [error] this is an error

  - <a name='4'></a>__::logger::utils::autoApplyAppender__ *command* *command\-string* *log* *op* *args*\.\.\.

    This command is designed to be added via __trace leave__ to calls of
    __logger::init__\. It will look at preconfigured state \(via
    __::logger::utils::applyAppender__\) to autocreate appenders for newly
    created logger instances\. It will return its argument *log*\.

    Example of usage:

        logger::utils::applyAppender -appender console
        set log [logger::init applyAppender-3]
        ${log}::error "this is an error"

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
