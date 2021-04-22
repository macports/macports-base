
[//000000001]: # (term::receive::bind \- Terminal control)
[//000000002]: # (Generated from file 'term\_bind\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (term::receive::bind\(n\) 0\.1 tcllib "Terminal control")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

term::receive::bind \- Keyboard dispatch from terminals

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Class API](#section2)

  - [Object API](#section3)

  - [Notes](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require term::receive::bind ?0\.1?  

[__term::receive::bind__ *object* ?*map*?](#1)  
[*object* __map__ *str* *cmd*](#2)  
[*object* __default__ *cmd*](#3)  
[*object* __listen__ ?*chan*?](#4)  
[*object* __unlisten__ ?*chan*?](#5)  
[*object* __reset__](#6)  
[*object* __next__ *char*](#7)  
[*object* __process__ *str*](#8)  
[*object* __eof__](#9)  

# <a name='description'></a>DESCRIPTION

This package provides a class for the creation of simple dispatchers from
character sequences to actions\. Internally each dispatcher is in essence a
deterministic finite automaton with tree structure\.

# <a name='section2'></a>Class API

The package exports a single command, the class command, enabling the creation
of dispatcher instances\. Its API is:

  - <a name='1'></a>__term::receive::bind__ *object* ?*map*?

    This command creates a new dispatcher object with the name *object*,
    initializes it, and returns the fully qualified name of the object command
    as its result\.

    The argument is a dictionary mapping from strings, i\.e\. character sequences
    to the command prefices to invoke when the sequence is found in the input
    stream\.

# <a name='section3'></a>Object API

The objects created by the class command provide the methods listed below:

  - <a name='2'></a>*object* __map__ *str* *cmd*

    This method adds an additional mapping from the string *str* to the action
    *cmd*\. The mapping will take effect immediately should the processor be in
    a prefix of *str*, or at the next reset operation\. The action is a command
    prefix and will be invoked with one argument appended to it, the character
    sequence causing the invokation\. It is executed in the global namespace\.

  - <a name='3'></a>*object* __default__ *cmd*

    This method defines a default action *cmd* which will be invoked whenever
    an unknown character sequence is encountered\. The command prefix is handled
    in the same as the regular action defined via method __map__\.

  - <a name='4'></a>*object* __listen__ ?*chan*?

    This methods sets up a filevent listener for the channel with handle
    *chan* and invokes the dispatcher object whenever characters have been
    received, or EOF was reached\.

    If not specified *chan* defaults to __stdin__\.

  - <a name='5'></a>*object* __unlisten__ ?*chan*?

    This methods removes the filevent listener for the channel with handle
    *chan*\.

    If not specified *chan* defaults to __stdin__\.

  - <a name='6'></a>*object* __reset__

    This method resets the character processor to the beginning of the tree\.

  - <a name='7'></a>*object* __next__ *char*

    This method causes the character processor to process the character *c*\.
    This may simply advance the internal state, or invoke an associated action
    for a recognized sequence\.

  - <a name='8'></a>*object* __process__ *str*

    This method causes the character processor to process the character sequence
    *str*, advancing the internal state and invoking action as necessary\. This
    is a callback for __listen__\.

  - <a name='9'></a>*object* __eof__

    This method causes the character processor to handle EOF on the input\. This
    is currently no\-op\. This is a callback for __listen__\.

# <a name='section4'></a>Notes

The simplicity of the DFA means that it is not possible to recognize a character
sequence with has a another recognized character sequence as its prefix\.

In other words, the set of recognized strings has to form a *prefix code*\.

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *term* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[character input](\.\./\.\./\.\./\.\./index\.md\#character\_input),
[control](\.\./\.\./\.\./\.\./index\.md\#control),
[dispatcher](\.\./\.\./\.\./\.\./index\.md\#dispatcher),
[listener](\.\./\.\./\.\./\.\./index\.md\#listener),
[receiver](\.\./\.\./\.\./\.\./index\.md\#receiver),
[terminal](\.\./\.\./\.\./\.\./index\.md\#terminal)

# <a name='category'></a>CATEGORY

Terminal control

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
