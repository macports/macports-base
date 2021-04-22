
[//000000001]: # (grammar::me\_intro \- Grammar operations and usage)
[//000000002]: # (Generated from file 'me\_intro\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (grammar::me\_intro\(n\) 0\.1 tcllib "Grammar operations and usage")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

grammar::me\_intro \- Introduction to virtual machines for parsing token streams

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

This document is an introduction to and overview of the basic facilities for the
parsing and/or matching of *token* streams\. One possibility often used for the
token domain are characters\.

The packages themselves all provide variants of one *[virtual
machine](\.\./\.\./\.\./\.\./index\.md\#virtual\_machine)*, called a *match engine*
\(short *ME*\), which has all the facilities needed for the matching and parsing
of a stream, and which are either controlled directly, or are customized with a
match program\. The virtual machine is basically a pushdown automaton, with
additional elements for backtracking and/or handling of semantic data and
construction of abstract syntax trees \(*[AST](\.\./\.\./\.\./\.\./index\.md\#ast)*\)\.

Because of the high degree of similarity in the actual implementations of the
aforementioned virtual machine and the data structures they receive and generate
these common parts are specified in a separate document which will be referenced
by the documentation for packages actually implementing it\.

The relevant documents are:

  - __[grammar::me\_vm](me\_vm\.md)__

    Virtual machine specification\.

  - __[grammar::me\_ast](me\_ast\.md)__

    Specification of various representations used for abstract syntax trees\.

  - __[grammar::me::util](me\_util\.md)__

    Utility commands\.

  - __[grammar::me::tcl](me\_tcl\.md)__

    Singleton ME virtual machine implementation tied to Tcl for control flow and
    stacks\. Hardwired for pull operation\. Uninteruptible during processing\.

  - __[grammar::me::cpu](me\_cpu\.md)__

    Object\-based ME virtual machine implementation with explicit control flow,
    and stacks, using bytecodes\. Suspend/Resumable\. Push/pull operation\.

  - __[grammar::me::cpu::core](me\_cpucore\.md)__

    Core functionality for state manipulation and stepping used in the bytecode
    based implementation of ME virtual machines\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *grammar\_me* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[CFG](\.\./\.\./\.\./\.\./index\.md\#cfg), [CFL](\.\./\.\./\.\./\.\./index\.md\#cfl),
[LL\(k\)](\.\./\.\./\.\./\.\./index\.md\#ll\_k\_), [PEG](\.\./\.\./\.\./\.\./index\.md\#peg),
[TPDL](\.\./\.\./\.\./\.\./index\.md\#tpdl), [context\-free
grammar](\.\./\.\./\.\./\.\./index\.md\#context\_free\_grammar), [context\-free
languages](\.\./\.\./\.\./\.\./index\.md\#context\_free\_languages),
[expression](\.\./\.\./\.\./\.\./index\.md\#expression),
[grammar](\.\./\.\./\.\./\.\./index\.md\#grammar),
[matching](\.\./\.\./\.\./\.\./index\.md\#matching),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing), [parsing expression
grammar](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression\_grammar), [push down
automaton](\.\./\.\./\.\./\.\./index\.md\#push\_down\_automaton), [recursive
descent](\.\./\.\./\.\./\.\./index\.md\#recursive\_descent), [top\-down parsing
languages](\.\./\.\./\.\./\.\./index\.md\#top\_down\_parsing\_languages),
[transducer](\.\./\.\./\.\./\.\./index\.md\#transducer), [virtual
machine](\.\./\.\./\.\./\.\./index\.md\#virtual\_machine)

# <a name='category'></a>CATEGORY

Grammars and finite automata

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
