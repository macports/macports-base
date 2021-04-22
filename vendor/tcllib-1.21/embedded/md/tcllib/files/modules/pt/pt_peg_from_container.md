
[//000000001]: # (pt::peg::from::container \- Parser Tools)
[//000000002]: # (Generated from file 'pt\_peg\_from\_container\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pt::peg::from::container\(n\) 0 tcllib "Parser Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pt::peg::from::container \- PEG Conversion\. From CONTAINER format

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  

# <a name='description'></a>DESCRIPTION

Are you lost ? Do you have trouble understanding this document ? In that case
please read the overview provided by the *[Introduction to Parser
Tools](pt\_introduction\.md)*\. This document is the entrypoint to the whole
system the current package is a part of\.

This package does not exist\. There is no need for it\. The CONTAINER format for
parsing expression grammars is a piece of Tcl code which, then sourced, provides
a class whose instances have the grammar we wish to import loaded\. Another way
of looking at this is, the CONTAINER output is its own import package\.

# <a name='section2'></a>Bugs, Ideas, Feedback

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
