
[//000000001]: # (docidx\_lang\_syntax \- Documentation tools)
[//000000002]: # (Generated from file 'docidx\_lang\_syntax\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (docidx\_lang\_syntax\(n\) 1\.0 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

docidx\_lang\_syntax \- docidx language syntax

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

This document contains the formal specification of the syntax of the docidx
markup language, version 1 in Backus\-Naur\-Form\. This document is intended to be
a reference, complementing the *[docidx language command
reference](docidx\_lang\_cmdref\.md)*\. A beginner should read the much more
informally written *[docidx language introduction](docidx\_lang\_intro\.md)*
first before trying to understand either this document or the command reference\.

# <a name='section2'></a>Fundamentals

In the broadest terms possible the *docidx markup language* is like SGML and
similar languages\. A document written in this language consists primarily of
markup commands, with text embedded into it at some places\.

Each markup command is a just Tcl command surrounded by a matching pair of
__\[__ and __\]__\. Which commands are available, and their arguments, i\.e\.
syntax is specified in the *[docidx language command
reference](docidx\_lang\_cmdref\.md)*\.

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

The rules listed here specify only the syntax of docidx documents\. The lexical
level of the language was covered in the previous section\.

Regarding the syntax of the \(E\)BNF itself

  1. The construct \{ X \} stands for zero or more occurrences of X\.

  1. The construct \[ X \] stands for zero or one occurrence of X\.

The syntax:

    index     = defs
                INDEX_BEGIN
                [ contents ]
                INDEX_END
                { <WHITE> }

    defs      = { INCLUDE | VSET | <WHITE> }
    contents  = keyword { keyword }

    keyword   = defs KEY ref { ref }
    ref       = MANPAGE | URL | defs

At last a rule we were unable to capture in the EBNF syntax, as it is about the
arguments of the markup commands, something which is not modeled here\.

  1. The arguments of all markup commands have to be plain text, and/or text
     markup commands, i\.e\. one of

       1) __lb__,

       1) __rb__, or

       1) __vset__ \(1\-argument form\)\.

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

[docidx\_intro](docidx\_intro\.md),
[docidx\_lang\_cmdref](docidx\_lang\_cmdref\.md),
[docidx\_lang\_faq](docidx\_lang\_faq\.md),
[docidx\_lang\_intro](docidx\_lang\_intro\.md)

# <a name='keywords'></a>KEYWORDS

[docidx commands](\.\./\.\./\.\./\.\./index\.md\#docidx\_commands), [docidx
language](\.\./\.\./\.\./\.\./index\.md\#docidx\_language), [docidx
markup](\.\./\.\./\.\./\.\./index\.md\#docidx\_markup), [docidx
syntax](\.\./\.\./\.\./\.\./index\.md\#docidx\_syntax),
[markup](\.\./\.\./\.\./\.\./index\.md\#markup), [semantic
markup](\.\./\.\./\.\./\.\./index\.md\#semantic\_markup)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
