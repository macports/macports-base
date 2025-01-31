
[//000000001]: # (docidx\_lang\_intro \- Documentation tools)
[//000000002]: # (Generated from file 'docidx\_lang\_intro\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (docidx\_lang\_intro\(n\) 1\.0 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

docidx\_lang\_intro \- docidx language introduction

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

      - [Fundamentals](#subsection1)

      - [Basic structure](#subsection2)

      - [Advanced structure](#subsection3)

      - [Escapes](#subsection4)

  - [FURTHER READING](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

This document is an informal introduction to version 1 of the docidx markup
language based on a multitude of examples\. After reading this a writer should be
ready to understand the two parts of the formal specification, i\.e\. the
*[docidx language syntax](docidx\_lang\_syntax\.md)* specification and the
*[docidx language command reference](docidx\_lang\_cmdref\.md)*\.

## <a name='subsection1'></a>Fundamentals

While the *docidx markup language* is quite similar to the *doctools markup
language*, in the broadest terms possible, there is one key difference\. An
index consists essentially only of markup commands, with no plain text
interspersed between them, except for whitespace\.

Each markup command is a Tcl command surrounded by a matching pair of __\[__
and __\]__\. Inside of these delimiters the usual rules for a Tcl command
apply with regard to word quotation, nested commands, continuation lines, etc\.
I\.e\.

    ... [key {markup language}] ...

    ... [manpage thefile \
            {file description}] ...

## <a name='subsection2'></a>Basic structure

The most simple document which can be written in docidx is

    [index_begin GROUPTITLE TITLE]
    [index_end]

Not very useful, but valid\. This also shows us that all docidx documents consist
of only one part where we will list all keys and their references\.

A more useful index will contain at least keywords, or short 'keys', i\.e\. the
phrases which were indexed\. So:

> \[index\_begin GROUPTITLE TITLE\]  
> \[__key markup__\]  
> \[__key \{semantic markup\}\]__\]  
> \[__key \{docidx markup\}__\]  
> \[__key \{docidx language\}__\]  
> \[__key \{docidx commands\}__\]  
> \[index\_end\]

In the above example the command __key__ is used to declare the keyword
phrases we wish to be part of the index\.

However a truly useful index does not only list the keyword phrases, but will
also contain references to documents associated with the keywords\. Here is a
made\-up index for all the manpages in the module
*[base64](\.\./\.\./\.\./\.\./index\.md\#base64)*:

> \[index\_begin tcllib/base64 \{De\- & Encoding\}\]  
> \[key base64\]  
> \[__manpage base64__\]  
> \[key encoding\]  
> \[__manpage base64__\]  
> \[__manpage uuencode__\]  
> \[__manpage yencode__\]  
> \[key uuencode\]  
> \[__manpage uuencode__\]  
> \[key yEnc\]  
> \[__manpage yencode__\]  
> \[key ydecode\]  
> \[__manpage yencode__\]  
> \[key yencode\]  
> \[__manpage yencode__\]  
> \[index\_end\]

In the above example the command
__[manpage](\.\./\.\./\.\./\.\./index\.md\#manpage)__ is used to insert references
to documents, using symbolic file names, with each command belonging to the last
__key__ command coming before it\.

The other command to insert references is
__[url](\.\./\.\./\.\./\.\./index\.md\#url)__\. In contrast to
__[manpage](\.\./\.\./\.\./\.\./index\.md\#manpage)__ it uses explicit \(possibly
format\-specific\) urls to describe the location of the referenced document\. As
such this command is intended for the creation of references to external
documents which could not be handled in any other way\.

## <a name='subsection3'></a>Advanced structure

In all previous examples we fudged a bit regarding the markup actually allowed
to be used before the __index\_begin__ command opening the document\.

Instead of only whitespace the two templating commands __include__ and
__vset__ are also allowed, to enable the writer to either set and/or import
configuration settings relevant to the table of contents\. I\.e\. it is possible to
write

> \[__include FILE__\]  
> \[__vset VAR VALUE__\]  
> \[index\_begin GROUPTITLE TITLE\]  
> \.\.\.  
> \[index\_end\]

Even more important, these two commands are allowed anywhere where a markup
command is allowed, without regard for any other structure\.

> \[index\_begin GROUPTITLE TITLE\]  
> \[__include FILE__\]  
> \[__vset VAR VALUE__\]  
> \.\.\.  
> \[index\_end\]

The only restriction __include__ has to obey is that the contents of the
included file must be valid at the place of the inclusion\. I\.e\. a file included
before __index\_begin__ may contain only the templating commands __vset__
and __include__, a file included after a key may contain only manape or url
references, and other keys, etc\.

## <a name='subsection4'></a>Escapes

Beyond the 6 commands shown so far we have two more available\. However their
function is not the marking up of index structure, but the insertion of
characters, namely __\[__ and __\]__\. These commands, __lb__ and
__rb__ respectively, are required because our use of \[ and \] to bracket
markup commands makes it impossible to directly use \[ and \] within the text\.

Our example of their use are the sources of the last sentence in the previous
paragraph, with some highlighting added\.

> &nbsp;&nbsp;\.\.\.  
> &nbsp;&nbsp;These commands, \[cmd lb\] and \[cmd lb\] respectively, are required  
> &nbsp;&nbsp;because our use of \[__lb__\] and \[__rb__\] to bracket markup commands makes it  
> &nbsp;&nbsp;impossible to directly use \[__lb__\] and \[__rb__\] within the text\.  
> &nbsp;&nbsp;\.\.\.

# <a name='section2'></a>FURTHER READING

Now that this document has been digested the reader, assumed to be a *writer*
of documentation should be fortified enough to be able to understand the formal
*[docidx language syntax](docidx\_lang\_syntax\.md)* specification as well\.
From here on out the *[docidx language command
reference](docidx\_lang\_cmdref\.md)* will also serve as the detailed
specification and cheat sheet for all available commands and their syntax\.

To be able to validate a document while writing it, it is also recommended to
familiarize oneself with Tclapps' ultra\-configurable __dtp__\.

On the other hand, docidx is perfectly suited for the automatic generation from
doctools documents, and this is the route Tcllib's easy and simple
__[dtplite](\.\./\.\./apps/dtplite\.md)__ goes, creating an index for a set
of documents behind the scenes, without the writer having to do so on their own\.

# <a name='section3'></a>Bugs, Ideas, Feedback

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
[docidx\_lang\_syntax](docidx\_lang\_syntax\.md)

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
