
[//000000001]: # (processman \- processman)
[//000000002]: # (Generated from file 'processman\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2015 Sean Woods <yoda@etoyoc\.com>)
[//000000004]: # (processman\(n\) 0\.6 tcllib "processman")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

processman \- Tool for automating the period callback of commands

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Commands](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require twapi 3\.1  
package require cron 1\.1  
package require processman ?0\.6?  

[__::processman::find\_exe__ *name*](#1)  
[__::processman::kill__ *id*](#2)  
[__::processman::kill\_all__](#3)  
[__::processman::killexe__ *name*](#4)  
[__::processman::onexit__ *id* *cmd*](#5)  
[__::processman::priority__ *id* *level*](#6)  
[__::processman::process\_list__](#7)  
[__::processman::process\_list__ *id*](#8)  
[__::processman::spawn__ *id* *cmd* *args*](#9)  

# <a name='description'></a>DESCRIPTION

The __processman__ package provides a Pure\-tcl set of utilities to manage
child processes in a platform\-generic nature\.

# <a name='section2'></a>Commands

  - <a name='1'></a>__::processman::find\_exe__ *name*

    Locate an executable by the name of *name* in the system path\. On windows,
    also add the \.exe extention if not given\.

  - <a name='2'></a>__::processman::kill__ *id*

    Kill a child process *id*\.

  - <a name='3'></a>__::processman::kill\_all__

    Kill all processes spawned by this program

  - <a name='4'></a>__::processman::killexe__ *name*

    Kill a process identified by the executable\. On Unix, this triggers a
    killall\. On windows, __twapi::get\_process\_ids__ is used to map a name
    one or more IDs, which are then killed\.

  - <a name='5'></a>__::processman::onexit__ *id* *cmd*

    Arrange to execute the script *cmd* when this programe detects that
    process *id* as terminated\.

  - <a name='6'></a>__::processman::priority__ *id* *level*

    Mark process *id* with the priorty *level*\. Valid levels: low, high,
    default\.

    On Unix, the process is tagged using the __nice__ command\.

    On Windows, the process is modifed via the __twapi::set\_priority\_class__

  - <a name='7'></a>__::processman::process\_list__

    Return a list of processes that have been triggered by this program, as well
    as a boolean flag to indicate if the process is still running\.

  - <a name='8'></a>__::processman::process\_list__ *id*

    Return true if process *id* is still running, false otherwise\.

  - <a name='9'></a>__::processman::spawn__ *id* *cmd* *args*

    Start a child process, identified by *id*\. *cmd* is the name of the
    command to execute\. *args* are arguments to pass to that command\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *odie* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[odie](\.\./\.\./\.\./\.\./index\.md\#odie),
[processman](\.\./\.\./\.\./\.\./index\.md\#processman)

# <a name='category'></a>CATEGORY

System

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2015 Sean Woods <yoda@etoyoc\.com>
