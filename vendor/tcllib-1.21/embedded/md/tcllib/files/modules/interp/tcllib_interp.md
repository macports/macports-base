
[//000000001]: # (interp \- Interpreter utilities)
[//000000002]: # (Generated from file 'tcllib\_interp\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (interp\(n\) 0\.1\.2 tcllib "Interpreter utilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

interp \- Interp creation and aliasing

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

package require Tcl 8\.3  
package require interp ?0\.1\.2?  

[__::interp::createEmpty__ ?*path*?](#1)  
[__::interp::snitLink__ *path* *methodlist*](#2)  
[__::interp::snitDictLink__ *path* *methoddict*](#3)  

# <a name='description'></a>DESCRIPTION

This package provides a number of commands for the convenient creation of Tcl
interpreters for highly restricted execution\.

# <a name='section2'></a>API

  - <a name='1'></a>__::interp::createEmpty__ ?*path*?

    This commands creates an empty Tcl interpreter and returns it name\. Empty
    means that the new interpreter has neither namespaces, nor any commands\. It
    is useful only for the creation of aliases\.

    If a *path* is specified then it is taken as the name of the new
    interpreter\.

  - <a name='2'></a>__::interp::snitLink__ *path* *methodlist*

    This command assumes that it was called from within a method of a snit
    object, and that the command __mymethod__ is available\.

    It extends the interpreter specified by *path* with aliases for all
    methods found in the *methodlist*, with the alias directing execution to
    the same\-named method of the snit object invoking this command\. Each element
    of *methodlist* is actually interpreted as a command prefix, with the
    first word of each prefix the name of the method to link to\.

    The result of the command is the empty string\.

  - <a name='3'></a>__::interp::snitDictLink__ *path* *methoddict*

    This command behaves like __::interp::snitLink__, except that it takes a
    dictionary mapping from commands to methods as its input, and not a list of
    methods\. Like for __::interp::snitLink__ the method references are
    actually command prefixes\. This command allows the creation of more complex
    command\-method mappings than __::interp::snitLink__\.

    The result of the command is the empty string\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *interp* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[alias](\.\./\.\./\.\./\.\./index\.md\#alias), [empty
interpreter](\.\./\.\./\.\./\.\./index\.md\#empty\_interpreter),
[interpreter](\.\./\.\./\.\./\.\./index\.md\#interpreter),
[method](\.\./\.\./\.\./\.\./index\.md\#method), [snit](\.\./\.\./\.\./\.\./index\.md\#snit)

# <a name='category'></a>CATEGORY

Programming tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
