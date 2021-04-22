
[//000000001]: # (pt\_parse\_peg \- Parser Tools)
[//000000002]: # (Generated from file 'pt\_parse\_peg\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pt\_parse\_peg\(i\) 1 tcllib "Parser Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pt\_parse\_peg \- Parser Tools PEG Parser

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Class API](#section2)

  - [Instances API](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require pt::parse::peg 1  

[__pt::parse::peg__ ?*objectName*?](#1)  
[*objectName* __destroy__](#2)  
[*objectName* __parse__ *chan*](#3)  
[*objectName* __parset__ *text*](#4)  

# <a name='description'></a>DESCRIPTION

Are you lost ? Do you have trouble understanding this document ? In that case
please read the overview provided by the *[Introduction to Parser
Tools](pt\_introduction\.md)*\. This document is the entrypoint to the whole
system the current package is a part of\.

This package provides a class whose instances are parsers for parsing expression
grammars in textual form\.

# <a name='section2'></a>Class API

  - <a name='1'></a>__pt::parse::peg__ ?*objectName*?

    The class command constructs parser instances, i\.e\. objects\. The result of
    the command is the fully\-qualified name of the instance command\.

    If no *objectName* is specified the class will generate and use an
    automatic name\. If the *objectName* was specified, but is not fully
    qualified the command will be created in the current namespace\.

# <a name='section3'></a>Instances API

All parser instances provide at least the methods shown below:

  - <a name='2'></a>*objectName* __destroy__

    This method destroys the parser instance, releasing all claimed memory and
    other resources, and deleting the instance command\.

    The result of the command is the empty string\.

  - <a name='3'></a>*objectName* __parse__ *chan*

    This method runs the parser using the contents of *chan* as input
    \(starting at the current location in the channel\), until parsing is not
    possible anymore, either because parsing has completed, or run into a syntax
    error\.

    Note here that the Parser Tools are based on Tcl 8\.5\+\. In other words, the
    channel argument is not restricted to files, sockets, etc\. We have the full
    power of *reflected channels* available\.

    It should also be noted that the parser pulls the characters from the input
    stream as it needs them\. If a parser created by this package has to be
    operated in a push aka event\-driven manner it will be necessary to go to Tcl
    8\.6\+ and use the __[coroutine::auto](\.\./coroutine/coro\_auto\.md)__ to
    wrap it into a coroutine where __[read](\.\./\.\./\.\./\.\./index\.md\#read)__
    is properly changed for push\-operation\.

    Upon successful completion the command returns an abstract syntax tree as
    its result\. This AST is in the form specified in section __AST
    serialization format__\. As a plain nested Tcl\-list it can then be
    processed with any Tcl commands the user likes, doing transformations,
    semantic checks, etc\. To help in this the package
    __[pt::ast](pt\_astree\.md)__ provides a set of convenience commands
    for validation of the tree's basic structure, printing it for debugging, and
    walking it either from the bottom up, or top down\.

    When encountering a syntax error the command will throw an error instead\.
    This error will be a 4\-element Tcl\-list, containing, in the order listed
    below:

      1. The string __pt::rde__ identifying it as parser runtime error\.

      1. The location of the parse error, as character offset from the beginning
         of the parsed input\.

      1. The location of parse error, now as a 2\-element list containing
         line\-number and column in the line\.

      1. A set of atomic parsing expressions indicating encoding the characters
         and/or nonterminal symbols the parser expected to see at the location
         of the parse error, but did not get\. For the specification of atomic
         parsing expressions please see the section __PE serialization
         format__\.

  - <a name='4'></a>*objectName* __parset__ *text*

    This method runs the parser using the string in *text* as input\. In all
    other ways it behaves like the method __parse__, shown above\.

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *pt* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[EBNF](\.\./\.\./\.\./\.\./index\.md\#ebnf), [LL\(k\)](\.\./\.\./\.\./\.\./index\.md\#ll\_k\_),
[PEG](\.\./\.\./\.\./\.\./index\.md\#peg), [TDPL](\.\./\.\./\.\./\.\./index\.md\#tdpl),
[context\-free languages](\.\./\.\./\.\./\.\./index\.md\#context\_free\_languages),
[expression](\.\./\.\./\.\./\.\./index\.md\#expression),
[grammar](\.\./\.\./\.\./\.\./index\.md\#grammar),
[matching](\.\./\.\./\.\./\.\./index\.md\#matching),
[parser](\.\./\.\./\.\./\.\./index\.md\#parser), [parsing
expression](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression), [parsing expression
grammar](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression\_grammar), [push down
automaton](\.\./\.\./\.\./\.\./index\.md\#push\_down\_automaton), [recursive
descent](\.\./\.\./\.\./\.\./index\.md\#recursive\_descent),
[state](\.\./\.\./\.\./\.\./index\.md\#state), [top\-down parsing
languages](\.\./\.\./\.\./\.\./index\.md\#top\_down\_parsing\_languages),
[transducer](\.\./\.\./\.\./\.\./index\.md\#transducer)

# <a name='category'></a>CATEGORY

Parsing and Grammars

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
