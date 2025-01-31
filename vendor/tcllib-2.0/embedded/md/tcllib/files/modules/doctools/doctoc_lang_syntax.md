
[//000000001]: # (doctoc\_lang\_syntax \- Documentation tools)
[//000000002]: # (Generated from file 'doctoc\_lang\_syntax\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctoc\_lang\_syntax\(n\) 1\.0 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctoc\_lang\_syntax \- doctoc language syntax

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [Fundamentals](#section2)

  - [Lexical definitions](#section3)

  - [Syntax](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

This document contains the formal specification of the syntax of the doctoc
markup language, version 1\.1 in Backus\-Naur\-Form\. This document is intended to
be a reference, complementing the *[doctoc language command
reference](doctoc\_lang\_cmdref\.md)*\. A beginner should read the much more
informally written *[doctoc language introduction](doctoc\_lang\_intro\.md)*
first before trying to understand either this document or the command reference\.

# <a name='section2'></a>Fundamentals

In the broadest terms possible the *doctoc markup language* is like SGML and
similar languages\. A document written in this language consists primarily of
markup commands, with text embedded into it at some places\.

Each markup command is a just Tcl command surrounded by a matching pair of
__\[__ and __\]__\. Which commands are available, and their arguments, i\.e\.
syntax is specified in the *[doctoc language command
reference](doctoc\_lang\_cmdref\.md)*\.

In this document we specify first the lexeme, and then the syntax, i\.e\. how we
can mix text and markup commands with each other\.

# <a name='section3'></a>Lexical definitions

In the syntax rules listed in the next section

  1. <TEXT> stands for all text except markup commands\.

  1. Any XXX stands for the markup command \[xxx\] including its arguments\. Each
     markup command is a Tcl command surrounded by a matching pair of __\[__
     and __\]__\. Inside of these delimiters the usual rules for a Tcl command
     apply with regard to word quotation, nested commands, continuation lines,
     etc\.

  1. <WHITE> stands for all text consisting only of spaces, newlines, tabulators
     and the __[comment](\.\./\.\./\.\./\.\./index\.md\#comment)__ markup command\.

# <a name='section4'></a>Syntax

The rules listed here specify only the syntax of doctoc documents\. The lexical
level of the language was covered in the previous section\.

Regarding the syntax of the \(E\)BNF itself

  1. The construct \{ X \} stands for zero or more occurrences of X\.

  1. The construct \[ X \] stands for zero or one occurrence of X\.

The syntax:

    toc       = defs
                TOC_BEGIN
                contents
                TOC_END
                { <WHITE> }

    defs      = { INCLUDE | VSET | <WHITE> }
    contents  = { defs entry } [ defs ]

    entry     = ITEM | division

    division  = DIVISION_START
                contents
                DIVISION_END

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *doctools* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[doctoc\_intro](doctoc\_intro\.md),
[doctoc\_lang\_cmdref](doctoc\_lang\_cmdref\.md),
[doctoc\_lang\_faq](doctoc\_lang\_faq\.md),
[doctoc\_lang\_intro](doctoc\_lang\_intro\.md)

# <a name='keywords'></a>KEYWORDS

[doctoc commands](\.\./\.\./\.\./\.\./index\.md\#doctoc\_commands), [doctoc
language](\.\./\.\./\.\./\.\./index\.md\#doctoc\_language), [doctoc
markup](\.\./\.\./\.\./\.\./index\.md\#doctoc\_markup), [doctoc
syntax](\.\./\.\./\.\./\.\./index\.md\#doctoc\_syntax),
[markup](\.\./\.\./\.\./\.\./index\.md\#markup), [semantic
markup](\.\./\.\./\.\./\.\./index\.md\#semantic\_markup)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
