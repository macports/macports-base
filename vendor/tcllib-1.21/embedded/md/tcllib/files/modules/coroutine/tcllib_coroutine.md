
[//000000001]: # (coroutine \- Coroutine utilities)
[//000000002]: # (Generated from file 'tcllib\_coroutine\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2010\-2015 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (coroutine\(n\) 1\.3 tcllib "Coroutine utilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

coroutine \- Coroutine based event and IO handling

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require coroutine 1\.3  

[__coroutine::util after__ *delay*](#1)  
[__coroutine::util await__ *varname*\.\.\.](#2)  
[__coroutine::util create__ *arg*\.\.\.](#3)  
[__coroutine::util exit__ ?*status*?](#4)  
[__coroutine::util gets__ *chan* ?*varname*?](#5)  
[__coroutine::util gets\_safety__ *chan* *limit* *varname*](#6)  
[__coroutine::util global__ *varname*\.\.\.](#7)  
[__coroutine::util puts__ ?__\-nonewline__? *channel* *string*](#8)  
[__coroutine::util read__ __\-nonewline__ *chan* ?*n*?](#9)  
[__coroutine::util socket__ ?*options\.\.\.*? *host* *port*](#10)  
[__coroutine::util update__ ?__idletasks__?](#11)  
[__coroutine::util vwait__ *varname*](#12)  

# <a name='description'></a>DESCRIPTION

The __coroutine__ package provides coroutine\-aware implementations of
various event\- and channel related commands\. It can be in multiple modes:

  1. Call the commands through their ensemble, in code which is explicitly
     written for use within coroutines\.

  1. Import the commands into a namespace, either directly, or through
     __namespace path__\. This allows the use from within code which is not
     coroutine\-aware per se and restricted to specific namespaces\.

A more agressive form of making code coroutine\-oblivious than point 2 above is
available through the package __[coroutine::auto](coro\_auto\.md)__, which
intercepts the relevant builtin commands and changes their implementation
dependending on the context they are run in, i\.e\. inside or outside of a
coroutine\.

# <a name='section2'></a>API

All the commands listed below are synchronous with respect to the coroutine
invoking them, i\.e\. this coroutine blocks until the result is available\. The
overall eventloop is not blocked however\.

  - <a name='1'></a>__coroutine::util after__ *delay*

    This command delays the coroutine invoking it by *delay* milliseconds\.

  - <a name='2'></a>__coroutine::util await__ *varname*\.\.\.

    This command is an extension form of the __coroutine::util vwait__
    command \(see below\) which waits on a write to one of many named namespace
    variables\.

  - <a name='3'></a>__coroutine::util create__ *arg*\.\.\.

    This command creates a new coroutine with an automatically assigned name and
    causes it to run the code specified by the arguments\.

  - <a name='4'></a>__coroutine::util exit__ ?*status*?

    This command exits the current coroutine, causing it to return *status*\.
    If no status was specified the default *0* is returned\.

  - <a name='5'></a>__coroutine::util gets__ *chan* ?*varname*?

    This command reads a line from the channel *chan* and returns it either as
    its result, or, if a *varname* was specified, writes it to the named
    variable and returns the number of characters read\.

  - <a name='6'></a>__coroutine::util gets\_safety__ *chan* *limit* *varname*

    This command reads a line from the channel *chan* up to size *limit* and
    stores the result in *varname*\. Of *limit* is reached before the set
    first newline, an error is thrown\. The command returns the number of
    characters read\.

  - <a name='7'></a>__coroutine::util global__ *varname*\.\.\.

    This command imports the named global variables of the coroutine into the
    current scope\. From the technical point of view these variables reside in
    level __\#1__ of the Tcl stack\. I\.e\. these are not the regular global
    variable in to the global namespace, and each coroutine can have their own
    set, independent of all others\.

  - <a name='8'></a>__coroutine::util puts__ ?__\-nonewline__? *channel* *string*

    This commands writes the string to the specified *channel*\. Contrary to
    the builtin __puts__ this command waits until the *channel* is
    writable before actually writing to it\.

  - <a name='9'></a>__coroutine::util read__ __\-nonewline__ *chan* ?*n*?

    This command reads *n* characters from the channel *chan* and returns
    them as its result\. If *n* is not specified the command will read the
    channel until EOF is reached\.

  - <a name='10'></a>__coroutine::util socket__ ?*options\.\.\.*? *host* *port*

    This command connects to the specified host and port and returns when that
    is done\. Contrary to the builtin command it performs a non\-blocking connect
    in the background\. As such, while its blocks the calling coroutine, the
    overall application is not blocked\.

  - <a name='11'></a>__coroutine::util update__ ?__idletasks__?

    This command causes the coroutine invoking it to run pending events or idle
    handlers before proceeding\.

  - <a name='12'></a>__coroutine::util vwait__ *varname*

    This command causes the coroutine calling it to wait for a write to the
    named namespace variable *varname*\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *coroutine* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[after](\.\./\.\./\.\./\.\./index\.md\#after),
[channel](\.\./\.\./\.\./\.\./index\.md\#channel),
[coroutine](\.\./\.\./\.\./\.\./index\.md\#coroutine),
[events](\.\./\.\./\.\./\.\./index\.md\#events),
[exit](\.\./\.\./\.\./\.\./index\.md\#exit), [gets](\.\./\.\./\.\./\.\./index\.md\#gets),
[global](\.\./\.\./\.\./\.\./index\.md\#global), [green
threads](\.\./\.\./\.\./\.\./index\.md\#green\_threads),
[read](\.\./\.\./\.\./\.\./index\.md\#read),
[threads](\.\./\.\./\.\./\.\./index\.md\#threads),
[update](\.\./\.\./\.\./\.\./index\.md\#update),
[vwait](\.\./\.\./\.\./\.\./index\.md\#vwait)

# <a name='category'></a>CATEGORY

Coroutine

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2010\-2015 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
