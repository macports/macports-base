
[//000000001]: # (grammar::peg::interp \- Grammar operations and usage)
[//000000002]: # (Generated from file 'peg\_interp\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005\-2011 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (grammar::peg::interp\(n\) 0\.1\.1 tcllib "Grammar operations and usage")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

grammar::peg::interp \- Interpreter for parsing expression grammars

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [THE INTERPRETER API](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require grammar::mengine ?0\.1?  
package require grammar::peg::interp ?0\.1\.1?  

[__::grammar::peg::interp::setup__ *peg*](#1)  
[__::grammar::peg::interp::parse__ *nextcmd* *errorvar* *astvar*](#2)  

# <a name='description'></a>DESCRIPTION

This package provides commands for the controlled matching of a character stream
via a parsing expression grammar and the creation of an abstract syntax tree for
the stream and partials\.

It is built on top of the virtual machine provided by the package
__[grammar::me::tcl](\.\./grammar\_me/me\_tcl\.md)__ and directly interprets
the parsing expression grammar given to it\. In other words, the grammar is
*not* pre\-compiled but used as is\.

The grammar to be interpreted is taken from a container object following the
interface specified by the package __grammar::peg::container__\. Only the
relevant parts are copied into the state of this package\.

It should be noted that the package provides exactly one instance of the
interpreter, and interpreting a second grammar requires the user to either abort
or complete a running interpretation, or to put them into different Tcl
interpreters\.

Also of note is that the implementation assumes a pull\-type handling of the
input\. In other words, the interpreter pulls characters from the input stream as
it needs them\. For usage in a push environment, i\.e\. where the environment
pushes new characters as they come we have to put the engine into its own
thread\.

# <a name='section2'></a>THE INTERPRETER API

The package exports the following API

  - <a name='1'></a>__::grammar::peg::interp::setup__ *peg*

    This command \(re\)initializes the interpreter\. It returns the empty string\.
    This command has to be invoked first, before any matching run\.

    Its argument *peg* is the handle of an object containing the parsing
    expression grammar to interpret\. This grammar has to be valid, or an error
    will be thrown\.

  - <a name='2'></a>__::grammar::peg::interp::parse__ *nextcmd* *errorvar* *astvar*

    This command interprets the loaded grammar and tries to match it against the
    stream of characters represented by the command prefix *nextcmd*\.

    The command prefix *nextcmd* represents the input stream of characters and
    is invoked by the interpreter whenever the a new character from the stream
    is required\. The callback has to return either the empty list, or a list of
    4 elements containing the token, its lexeme attribute, and its location as
    line number and column index, in this order\. The empty list is the signal
    that the end of the input stream has been reached\. The lexeme attribute is
    stored in the terminal cache, but otherwise not used by the machine\.

    The result of the command is a boolean value indicating whether the matching
    process was successful \(__true__\), or not \(__false__\)\. In the case
    of a match failure error information will be stored into the variable
    referenced by *errorvar*\. The variable referenced by *astvar* will
    always contain the generated abstract syntax tree, however in the case of an
    error it will be only partial and possibly malformed\.

    The abstract syntax tree is represented by a nested list, as described in
    section __AST VALUES__ of document
    *[grammar::me\_ast](\.\./grammar\_me/me\_ast\.md)*\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *grammar\_peg* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[LL\(k\)](\.\./\.\./\.\./\.\./index\.md\#ll\_k\_), [TDPL](\.\./\.\./\.\./\.\./index\.md\#tdpl),
[context\-free languages](\.\./\.\./\.\./\.\./index\.md\#context\_free\_languages),
[expression](\.\./\.\./\.\./\.\./index\.md\#expression),
[grammar](\.\./\.\./\.\./\.\./index\.md\#grammar),
[matching](\.\./\.\./\.\./\.\./index\.md\#matching),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing), [parsing
expression](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression), [parsing expression
grammar](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression\_grammar), [push down
automaton](\.\./\.\./\.\./\.\./index\.md\#push\_down\_automaton), [recursive
descent](\.\./\.\./\.\./\.\./index\.md\#recursive\_descent),
[state](\.\./\.\./\.\./\.\./index\.md\#state), [top\-down parsing
languages](\.\./\.\./\.\./\.\./index\.md\#top\_down\_parsing\_languages),
[transducer](\.\./\.\./\.\./\.\./index\.md\#transducer), [virtual
machine](\.\./\.\./\.\./\.\./index\.md\#virtual\_machine)

# <a name='category'></a>CATEGORY

Grammars and finite automata

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005\-2011 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
