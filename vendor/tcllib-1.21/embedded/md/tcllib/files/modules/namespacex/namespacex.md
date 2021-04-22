
[//000000001]: # (namespacex \- Namespace utility commands)
[//000000002]: # (Generated from file 'namespacex\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 200? Neil Madden \(http://wiki\.tcl\.tk/12790\))
[//000000004]: # (Copyright &copy; 200? Various \(http://wiki\.tcl\.tk/1489\))
[//000000005]: # (Copyright &copy; 2010 Documentation, Andreas Kupries)
[//000000006]: # (namespacex\(n\) 0\.3 tcllib "Namespace utility commands")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

namespacex \- Namespace utility commands

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Commands](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require namespacex ?0\.3?  

[__::namespacex hook add__ ?*namespace*? *cmdprefix*](#1)  
[__::namespacex hook proc__ ?*namespace*? *arguments* *body*](#2)  
[__::namespacex hook on__ ?*namespace*? *guardcmdprefix* *actioncmdprefix*](#3)  
[__::namespacex hook next__ *arg*\.\.\.](#4)  
[__::namespacex import fromns__ *cmdname ?*newname* \.\.\.?*](#5)  
[__::namespacex info allchildren__ *namespace*](#6)  
[__::namespacex info allvars__ *namespace*](#7)  
[__::namespacex normalize__ *namespace*](#8)  
[__::namespacex info vars__ *namespace* ?*pattern*?](#9)  
[__::namespacex state get__ *namespace*](#10)  
[__::namespacex state set__ *namespace* *dict*](#11)  
[__::namespacex state drop__ *namespace*](#12)  
[__::namespacex strip__ *prefix* *namespaces*](#13)  

# <a name='description'></a>DESCRIPTION

This package provides a number of utility commands for working with namespaces\.
The commands fall into four categories:

  1. Hook commands provide and manipulate a chain of commands which replaces the
     single regular __[namespace
     unknown](\.\./\.\./\.\./\.\./index\.md\#namespace\_unknown)__ handler\.

  1. An import command provides the ability to import any command from another
     namespace\.

  1. Information commands allow querying of variables and child namespaces\.

  1. State commands provide a means to serialize variable values in a namespace\.

# <a name='section2'></a>Commands

  - <a name='1'></a>__::namespacex hook add__ ?*namespace*? *cmdprefix*

    Adds the *cmdprefix* to the chain of unknown command handlers that are
    invoked when the *namespace* would otherwise invoke its unknown handler\.
    If *namespace* is not specified, then *cmdprefix* is added to the chain
    of handlers for the namespace of the caller\.

    The chain of *cmdprefix* are executed in reverse order of addition,
    *i\.e\.* the most recently added *cmdprefix* is executed first\. When
    executed, *cmdprefix* has additional arguments appended to it as would any
    namespace unknown handler\.

  - <a name='2'></a>__::namespacex hook proc__ ?*namespace*? *arguments* *body*

    Adds an anonymous procedure to the chain of namespace unknown handlers for
    the *namespace*\.

    If *namespace* is not specified, then the handler is added to the chain of
    handlers for the namespace of the caller\.

    The *arguments* and *body* are specified as for the core
    __[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ command\.

  - <a name='3'></a>__::namespacex hook on__ ?*namespace*? *guardcmdprefix* *actioncmdprefix*

    Adds a guarded action to the chain of namespace unknown handlers for the
    *namespace*\.

    If *namespace* is not specified, then the handler is added to the chain of
    handlers for the namespace of the caller\.

    The *guardcmdprefix* is executed first\. If it returns a value that can be
    interpreted as false, then the next unknown hander in the chain is executed\.
    Otherwise, *actioncmdprefix* is executed and the return value of the
    handler is the value returned by *actioncmdprefix*\.

    When executed, both *guardcmdprefix* and *actioncmdprefix* have the same
    additional arguments appended as for any namespace unknown handler\.

  - <a name='4'></a>__::namespacex hook next__ *arg*\.\.\.

    This command is available to namespace hooks to execute the next hook in the
    chain of handlers for the namespace\.

  - <a name='5'></a>__::namespacex import fromns__ *cmdname ?*newname* \.\.\.?*

    Imports the command *cmdname* from the *fromns* namespace into the
    namespace of the caller\. The *cmdname* command is imported even if the
    *fromns* did not originally export the command\.

    If *newname* is specified, then the imported command will be known by that
    name\. Otherwise, the command retains is original name as given by
    *cmdname*\.

    Additional pairs of *cmdname* / *newname* arguments may also be
    specified\.

  - <a name='6'></a>__::namespacex info allchildren__ *namespace*

    Returns a list containing the names of all child namespaces in the specified
    *namespace* and its children\. The names are all fully qualified\.

  - <a name='7'></a>__::namespacex info allvars__ *namespace*

    Returns a list containing the names of all variables in the specified
    *namespace* and its children\. The names are all given relative to
    *namespace*, and *not* fully qualified\.

  - <a name='8'></a>__::namespacex normalize__ *namespace*

    Returns the absolute name of *namespace*, which is resolved relative to
    the namespace of the caller, with all unneeded colon characters removed\.

  - <a name='9'></a>__::namespacex info vars__ *namespace* ?*pattern*?

    Returns a list containing the names of all variables in the specified
    *namespace*\. If the *pattern* argument is specified, then only variables
    matching *pattern* are returned\. Matching is determined using the same
    rules as for __string match__\.

  - <a name='10'></a>__::namespacex state get__ *namespace*

    Returns a dictionary holding the names and values of all variables in the
    specified *namespace* and its child namespaces\.

    Note that the names are all relative to *namespace*, and *not* fully
    qualified\.

  - <a name='11'></a>__::namespacex state set__ *namespace* *dict*

    Takes a dictionary holding the names and values for a set of variables and
    replaces the current state of the specified *namespace* and its child
    namespaces with this state\. The result of the command is the empty string\.

  - <a name='12'></a>__::namespacex state drop__ *namespace*

    Unsets all variables in the specified *namespace* and its child
    namespaces\. The result of the command is the empty string\.

  - <a name='13'></a>__::namespacex strip__ *prefix* *namespaces*

    Each item in *namespaces* must be the absolute normalized name of a child
    namespace of namespace *prefix*\. Returns the corresponding list of
    relative names of child namespaces\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *namespacex* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[extended namespace](\.\./\.\./\.\./\.\./index\.md\#extended\_namespace),
[info](\.\./\.\./\.\./\.\./index\.md\#info), [namespace
unknown](\.\./\.\./\.\./\.\./index\.md\#namespace\_unknown), [namespace
utilities](\.\./\.\./\.\./\.\./index\.md\#namespace\_utilities), [state
\(de\)serialization](\.\./\.\./\.\./\.\./index\.md\#state\_de\_serialization), [unknown
hooking](\.\./\.\./\.\./\.\./index\.md\#unknown\_hooking),
[utilities](\.\./\.\./\.\./\.\./index\.md\#utilities)

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 200? Neil Madden \(http://wiki\.tcl\.tk/12790\)  
Copyright &copy; 200? Various \(http://wiki\.tcl\.tk/1489\)  
Copyright &copy; 2010 Documentation, Andreas Kupries
