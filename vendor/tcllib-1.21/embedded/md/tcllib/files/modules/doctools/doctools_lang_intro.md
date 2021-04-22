
[//000000001]: # (doctools\_lang\_intro \- Documentation tools)
[//000000002]: # (Generated from file 'doctools\_lang\_intro\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools\_lang\_intro\(n\) 1\.0 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools\_lang\_intro \- doctools language introduction

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

      - [Fundamentals](#subsection1)

      - [Basic structure](#subsection2)

      - [Advanced structure](#subsection3)

      - [Text structure](#subsection4)

      - [Text markup](#subsection5)

      - [Escapes](#subsection6)

      - [Cross\-references](#subsection7)

      - [Examples](#subsection8)

      - [Lists](#subsection9)

  - [FURTHER READING](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

This document is an informal introduction to version 1 of the doctools markup
language based on a multitude of examples\. After reading this a writer should be
ready to understand the two parts of the formal specification, i\.e\. the
*[doctools language syntax](doctools\_lang\_syntax\.md)* specification and
the *[doctools language command reference](doctools\_lang\_cmdref\.md)*\.

## <a name='subsection1'></a>Fundamentals

In the broadest terms possible the *doctools markup language* is LaTeX\-like,
instead of like SGML and similar languages\. A document written in this language
consists primarily of text, with markup commands embedded into it\.

Each markup command is a Tcl command surrounded by a matching pair of __\[__
and __\]__\. Inside of these delimiters the usual rules for a Tcl command
apply with regard to word quotation, nested commands, continuation lines, etc\.
I\.e\.

    ... [list_begin enumerated] ...

    ... [call [cmd foo] \
            [arg bar]] ...

    ... [term {complex concept}] ...

    ... [opt "[arg key] [arg value]"] ...

## <a name='subsection2'></a>Basic structure

The most simple document which can be written in doctools is

        [manpage_begin NAME SECTION VERSION]
    [see_also doctools_intro]
    [see_also doctools_lang_cmdref]
    [see_also doctools_lang_faq]
    [see_also doctools_lang_syntax]
    [keywords {doctools commands}]
    [keywords {doctools language}]
    [keywords {doctools markup}]
    [keywords {doctools syntax}]
    [keywords markup]
    [keywords {semantic markup}]
        [description]
        [vset CATEGORY doctools]
    [include ../common-text/feedback.inc]
    [manpage_end]

This also shows us that all doctools documents are split into two parts, the
*header* and the *body*\. Everything coming before \[__description__\]
belongs to the header, and everything coming after belongs to the body, with the
whole document bracketed by the two __manpage\_\*__ commands\. Before and after
these opening and closing commands we have only *whitespace*\.

In the remainder of this section we will discuss only the contents of the
header, the structure of the body will be discussed in the section [Text
structure](#subsection4)\.

The header section can be empty, and otherwise may contain only an arbitrary
sequence of the four so\-called *header* commands, plus *whitespace*\. These
commands are

  - __titledesc__

  - __moddesc__

  - __require__

  - __copyright__

They provide, through their arguments, additional information about the
document, like its title, the title of the larger group the document belongs to
\(if applicable\), the requirements of the documented packages \(if applicable\),
and copyright assignments\. All of them can occur multiple times, including none,
and they can be used in any order\. However for __titledesc__ and
__moddesc__ only the last occurrence is taken\. For the other two the
specified information is accumulated, in the given order\. Regular text is not
allowed within the header\.

Given the above a less minimal example of a document is

> \[manpage\_begin NAME SECTION VERSION\]  
> \[__copyright \{YEAR AUTHOR\}__\]  
> \[__titledesc TITLE__\]  
> \[__moddesc   MODULE\_TITLE__\]  
> \[__require   PACKAGE VERSION__\]  
> \[__require   PACKAGE__\]  
> \[description\]  
> \[manpage\_end\]

Remember that the whitespace is optional\. The document

        [manpage_begin NAME SECTION VERSION]
        [copyright {YEAR AUTHOR}][titledesc TITLE][moddesc MODULE_TITLE]
        [require PACKAGE VERSION][require PACKAGE][description]
        [vset CATEGORY doctools]
    [include ../common-text/feedback.inc]
    [manpage_end]

has the same meaning as the example before\.

On the other hand, if *whitespace* is present it consists not only of any
sequence of characters containing the space character, horizontal and vertical
tabs, carriage return, and newline, but it may contain comment markup as well,
in the form of the __[comment](\.\./\.\./\.\./\.\./index\.md\#comment)__ command\.

> \[__comment \{ \.\.\. \}__\]  
> \[manpage\_begin NAME SECTION VERSION\]  
> \[copyright \{YEAR AUTHOR\}\]  
> \[titledesc TITLE\]  
> \[moddesc   MODULE\_TITLE\]\[__comment \{ \.\.\. \}__\]  
> \[require   PACKAGE VERSION\]  
> \[require   PACKAGE\]  
> \[description\]  
> \[manpage\_end\]  
> \[__comment \{ \.\.\. \}__\]

## <a name='subsection3'></a>Advanced structure

In the simple examples of the last section we fudged a bit regarding the markup
actually allowed to be used before the __manpage\_begin__ command opening the
document\.

Instead of only whitespace the two templating commands __include__ and
__vset__ are also allowed, to enable the writer to either set and/or import
configuration settings relevant to the document\. I\.e\. it is possible to write

> \[__include FILE__\]  
> \[__vset VAR VALUE__\]  
> \[manpage\_begin NAME SECTION VERSION\]  
> \[description\]  
> \[manpage\_end\]

Even more important, these two commands are allowed anywhere where a markup
command is allowed, without regard for any other structure\. I\.e\. for example in
the header as well\.

> \[manpage\_begin NAME SECTION VERSION\]  
> \[__include FILE__\]  
> \[__vset VAR VALUE__\]  
> \[description\]  
> \[manpage\_end\]

The only restriction __include__ has to obey is that the contents of the
included file must be valid at the place of the inclusion\. I\.e\. a file included
before __manpage\_begin__ may contain only the templating commands
__vset__ and __include__, a file included in the header may contain only
header commands, etc\.

## <a name='subsection4'></a>Text structure

The body of the document consists mainly of text, possibly split into sections,
subsections, and paragraphs, with parts marked up to highlight various semantic
categories of text, and additional structure through the use of examples and
\(nested\) lists\.

This section explains the high\-level structural commands, with everything else
deferred to the following sections\.

The simplest way of structuring the body is through the introduction of
paragraphs\. The command for doing so is __para__\. Each occurrence of this
command closes the previous paragraph and automatically opens the next\. The
first paragraph is automatically opened at the beginning of the body, by
__description__\. In the same manner the last paragraph automatically ends at
__manpage\_end__\.

> \[manpage\_begin NAME SECTION VERSION\]  
> \[description\]  
> &nbsp;\.\.\.  
> \[__para__\]  
> &nbsp;\.\.\.  
> \[__para__\]  
> &nbsp;\.\.\.  
> \[manpage\_end\]

Empty paragraphs are ignored\.

A structure coarser than paragraphs are sections, which allow the writer to
split a document into larger, and labeled, pieces\. The command for doing so is
__section__\. Each occurrence of this command closes the previous section and
automatically opens the next, including its first paragraph\. The first section
is automatically opened at the beginning of the body, by __description__
\(This section is labeled "DESCRIPTION"\)\. In the same manner the last section
automatically ends at __manpage\_end__\.

Empty sections are *not* ignored\. We are free to \(not\) use paragraphs within
sections\.

> \[manpage\_begin NAME SECTION VERSION\]  
> \[description\]  
> &nbsp;\.\.\.  
> \[__section \{Section A\}__\]  
> &nbsp;\.\.\.  
> \[para\]  
> &nbsp;\.\.\.  
> \[__section \{Section B\}__\]  
> &nbsp;\.\.\.  
> \[manpage\_end\]

Between sections and paragraphs we have subsections, to split sections\. The
command for doing so is __subsection__\. Each occurrence of this command
closes the previous subsection and automatically opens the next, including its
first paragraph\. A subsection is automatically opened at the beginning of the
body, by __description__, and at the beginning of each section\. In the same
manner the last subsection automatically ends at __manpage\_end__\.

Empty subsections are *not* ignored\. We are free to \(not\) use paragraphs
within subsections\.

> \[manpage\_begin NAME SECTION VERSION\]  
> \[description\]  
> &nbsp;\.\.\.  
> \[section \{Section A\}\]  
> &nbsp;\.\.\.  
> \[__subsection \{Sub 1\}__\]  
> &nbsp;\.\.\.  
> \[para\]  
> &nbsp;\.\.\.  
> \[__subsection \{Sub 2\}__\]  
> &nbsp;\.\.\.  
> \[section \{Section B\}\]  
> &nbsp;\.\.\.  
> \[manpage\_end\]

## <a name='subsection5'></a>Text markup

Having handled the overall structure a writer can impose on the document we now
take a closer at the text in a paragraph\.

While most often this is just the unadorned content of the document we do have
situations where we wish to highlight parts of it as some type of thing or
other, like command arguments, command names, concepts, uris, etc\.

For this we have a series of markup commands which take the text to highlight as
their single argument\. It should be noted that while their predominant use is
the highlighting of parts of a paragraph they can also be used to mark up the
arguments of list item commands, and of other markup commands\.

The commands available to us are

  - __arg__

    Its argument is a the name of a command argument\.

  - __[class](\.\./\.\./\.\./\.\./index\.md\#class)__

    Its argument is a class name\.

  - __cmd__

    Its argument is a command name \(Tcl command\)\.

  - __const__

    Its argument is a constant\.

  - __emph__

    General, non\-semantic emphasis\.

  - __[file](\.\./\.\./\.\./\.\./index\.md\#file)__

    Its argument is a filename / path\.

  - __fun__

    Its argument is a function name\.

  - __[method](\.\./\.\./\.\./\.\./index\.md\#method)__

    Its argument is a method name

  - __namespace__

    Its argument is namespace name\.

  - __opt__

    Its argument is some optional syntax element\.

  - __option__

    Its argument is a command line switch / widget option\.

  - __[package](\.\./\.\./\.\./\.\./index\.md\#package)__

    Its argument is a package name\.

  - __sectref__

    Its argument is the title of a section or subsection, i\.e\. a section
    reference\.

  - __syscmd__

    Its argument is a command name \(external, system command\)\.

  - __[term](\.\./term/term\.md)__

    Its argument is a concept, or general terminology\.

  - __[type](\.\./\.\./\.\./\.\./index\.md\#type)__

    Its argument is a type name\.

  - __[uri](\.\./uri/uri\.md)__

    Its argument is a uniform resource identifier, i\.e an external reference\. A
    second argument can be used to specify an explicit label for the reference
    in question\.

  - __usage__

    The arguments describe the syntax of a Tcl command\.

  - __var__

    Its argument is a variable\.

  - __[widget](\.\./\.\./\.\./\.\./index\.md\#widget)__

    Its argument is a widget name\.

The example demonstrating the use of text markup is an excerpt from the
*[doctools language command reference](doctools\_lang\_cmdref\.md)*, with
some highlighting added\. It shows their use within a block of text, as the
arguments of a list item command \(__call__\), and our ability to nest them\.

> &nbsp;&nbsp;\.\.\.  
> &nbsp;&nbsp;\[call \[__cmd arg\_def__\] \[__arg type__\] \[__arg name__\] \[__opt__ \[__arg mode__\]\]\]  
>   
> &nbsp;&nbsp;Text structure\. List element\. Argument list\. Automatically closes the  
> &nbsp;&nbsp;previous list element\. Specifies the data\-\[__arg type__\] of the described  
> &nbsp;&nbsp;argument of a command, its \[__arg name__\] and its i/o\-\[__arg mode__\]\. The  
> &nbsp;&nbsp;latter is optional\.  
> &nbsp;&nbsp;\.\.\.

## <a name='subsection6'></a>Escapes

Beyond the 20 commands for simple markup shown in the previous section we have
two more available which are technically simple markup\. However their function
is not the marking up of phrases as specific types of things, but the insertion
of characters, namely __\[__ and __\]__\. These commands, __lb__ and
__rb__ respectively, are required because our use of \[ and \] to bracket
markup commands makes it impossible to directly use \[ and \] within the text\.

Our example of their use are the sources of the last sentence in the previous
paragraph, with some highlighting added\.

> &nbsp;&nbsp;\.\.\.  
> &nbsp;&nbsp;These commands, \[cmd lb\] and \[cmd lb\] respectively, are required  
> &nbsp;&nbsp;because our use of \[__lb__\] and \[__rb__\] to bracket markup commands makes it  
> &nbsp;&nbsp;impossible to directly use \[__lb__\] and \[__rb__\] within the text\.  
> &nbsp;&nbsp;\.\.\.

## <a name='subsection7'></a>Cross\-references

The last two commands we have to discuss are for the declaration of
cross\-references between documents, explicit and implicit\. They are
__[keywords](\.\./\.\./\.\./\.\./index\.md\#keywords)__ and __see\_also__\. Both
take an arbitrary number of arguments, all of which have to be plain unmarked
text\. I\.e\. it is not allowed to use markup on them\. Both commands can be used
multiple times in a document\. If that is done all arguments of all occurrences
of one of them are put together into a single set\.

  - __[keywords](\.\./\.\./\.\./\.\./index\.md\#keywords)__

    The arguments of this command are interpreted as keywords describing the
    document\. A processor can use this information to create an index indirectly
    linking the containing document to all documents with the same keywords\.

  - __see\_also__

    The arguments of this command are interpreted as references to other
    documents\. A processor can format them as direct links to these documents\.

All the cross\-reference commands can occur anywhere in the document between
__manpage\_begin__ and __manpage\_end__\. As such the writer can choose
whether she wants to have them at the beginning of the body, or at its end,
maybe near the place a keyword is actually defined by the main content, or
considers them as meta data which should be in the header, etc\.

Our example shows the sources for the cross\-references of this document, with
some highlighting added\. Incidentally they are found at the end of the body\.

> &nbsp;&nbsp;\.\.\.  
> &nbsp;&nbsp;\[__see\_also doctools\_intro__\]  
> &nbsp;&nbsp;\[__see\_also doctools\_lang\_syntax__\]  
> &nbsp;&nbsp;\[__see\_also doctools\_lang\_cmdref__\]  
> &nbsp;&nbsp;\[__keywords markup \{semantic markup\}__\]  
> &nbsp;&nbsp;\[__keywords \{doctools markup\} \{doctools language\}__\]  
> &nbsp;&nbsp;\[__keywords \{doctools syntax\} \{doctools commands\}__\]  
> &nbsp;&nbsp;\[manpage\_end\]

## <a name='subsection8'></a>Examples

Where ever we can write plain text we can write examples too\. For simple
examples we have the command __example__ which takes a single argument, the
text of the argument\. The example text must not contain markup\. If we wish to
have markup within an example we have to use the 2\-command combination
__example\_begin__ / __example\_end__ instead\.

The first opens an example block, the other closes it, and in between we can
write plain text and use all the regular text markup commands\. Note that text
structure commands are not allowed\. This also means that it is not possible to
embed examples and lists within an example\. On the other hand, we *can* use
templating commands within example blocks to read their contents from a file
\(Remember section [Advanced structure](#subsection3)\)\.

The source for the very first example in this document \(see section
[Fundamentals](#subsection1)\), with some highlighting added, is

> \[__example__ \{  
> &nbsp;&nbsp;&nbsp;&nbsp;\.\.\. \[list\_begin enumerated\] \.\.\.  
> &nbsp;&nbsp;\}\]

Using __example\_begin__ / __example\_end__ this would look like

> \[__example\_begin__\]  
> &nbsp;&nbsp;&nbsp;&nbsp;\.\.\. \[list\_begin enumerated\] \.\.\.  
> &nbsp;&nbsp;\[__example\_end__\]

## <a name='subsection9'></a>Lists

Where ever we can write plain text we can write lists too\. The main commands are
__list\_begin__ to start a list, and __list\_end__ to close one\. The
opening command takes an argument specifying the type of list started it, and
this in turn determines which of the eight existing list item commands are
allowed within the list to start list items\.

After the opening command only whitespace is allowed, until the first list item
command opens the first item of the list\. Each item is a regular series of
paragraphs and is closed by either the next list item command, or the end of the
list\. If closed by a list item command this command automatically opens the next
list item\. A consequence of a list item being a series of paragraphs is that all
regular text markup can be used within a list item, including examples and other
lists\.

The list types recognized by __list\_begin__ and their associated list item
commands are:

  - __arguments__

    \(__arg\_def__\) This opens an *argument \(declaration\) list*\. It is a
    specialized form of a term definition list where the term is an argument
    name, with its type and i/o\-mode\.

  - __commands__

    \(__cmd\_def__\) This opens a *command \(declaration\) list*\. It is a
    specialized form of a term definition list where the term is a command name\.

  - __definitions__

    \(__def__ and __call__\) This opens a general *term definition
    list*\. The terms defined by the list items are specified through the
    argument\(s\) of the list item commands, either general terms, possibly with
    markup \(__def__\), or Tcl commands with their syntax \(__call__\)\.

  - __enumerated__

    \(__enum__\) This opens a general *enumerated list*\.

  - __itemized__

    \(__item__\) This opens a general *itemized list*\.

  - __options__

    \(__opt\_def__\) This opens an *option \(declaration\) list*\. It is a
    specialized form of a term definition list where the term is an option name,
    possibly with the option's arguments\.

  - __tkoptions__

    \(__tkoption\_def__\) This opens a *widget option \(declaration\) list*\. It
    is a specialized form of a term definition list where the term is the name
    of a configuration option for a widget, with its name and class in the
    option database\.

Our example is the source of the definition list in the previous paragraph, with
most of the content in the middle removed\.

> &nbsp;&nbsp;\.\.\.  
> &nbsp;&nbsp;\[__list\_begin__ definitions\]  
> &nbsp;&nbsp;\[__def__ \[const arg\]\]  
>   
> &nbsp;&nbsp;\(\[cmd arg\_def\]\) This opens an argument \(declaration\) list\. It is a  
> &nbsp;&nbsp;specialized form of a definition list where the term is an argument  
> &nbsp;&nbsp;name, with its type and i/o\-mode\.  
>   
> &nbsp;&nbsp;\[__def__ \[const itemized\]\]  
>   
> &nbsp;&nbsp;\(\[cmd item\]\)  
> &nbsp;&nbsp;This opens a general itemized list\.  
>   
> &nbsp;&nbsp;\.\.\.  
> &nbsp;&nbsp;\[__def__ \[const tkoption\]\]  
>   
> &nbsp;&nbsp;\(\[cmd tkoption\_def\]\) This opens a widget option \(declaration\) list\. It  
> &nbsp;&nbsp;is a specialized form of a definition list where the term is the name  
> &nbsp;&nbsp;of a configuration option for a widget, with its name and class in the  
> &nbsp;&nbsp;option database\.  
>   
> &nbsp;&nbsp;\[__list\_end__\]  
> &nbsp;&nbsp;\.\.\.

Note that a list cannot begin in one \(sub\)section and end in another\.
Differently said, \(sub\)section breaks are not allowed within lists and list
items\. An example of this *illegal* construct is

> &nbsp;&nbsp;\.\.\.  
> &nbsp;&nbsp;\[list\_begin itemized\]  
> &nbsp;&nbsp;\[item\]  
> &nbsp;&nbsp;\.\.\.  
> &nbsp;&nbsp;\[__section \{ILLEGAL WITHIN THE LIST\}__\]  
> &nbsp;&nbsp;\.\.\.  
> &nbsp;&nbsp;\[list\_end\]  
> &nbsp;&nbsp;\.\.\.

# <a name='section2'></a>FURTHER READING

Now that this document has been digested the reader, assumed to be a *writer*
of documentation should be fortified enough to be able to understand the formal
*[doctools language syntax](doctools\_lang\_syntax\.md)* specification as
well\. From here on out the *[doctools language command
reference](doctools\_lang\_cmdref\.md)* will also serve as the detailed
specification and cheat sheet for all available commands and their syntax\.

To be able to validate a document while writing it, it is also recommended to
familiarize oneself with one of the applications for the processing and
conversion of doctools documents, i\.e\. either Tcllib's easy and simple
__[dtplite](\.\./\.\./apps/dtplite\.md)__, or Tclapps' ultra\-configurable
__dtp__\.

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

[doctools\_intro](doctools\_intro\.md),
[doctools\_lang\_cmdref](doctools\_lang\_cmdref\.md),
[doctools\_lang\_faq](doctools\_lang\_faq\.md),
[doctools\_lang\_syntax](doctools\_lang\_syntax\.md)

# <a name='keywords'></a>KEYWORDS

[doctools commands](\.\./\.\./\.\./\.\./index\.md\#doctools\_commands), [doctools
language](\.\./\.\./\.\./\.\./index\.md\#doctools\_language), [doctools
markup](\.\./\.\./\.\./\.\./index\.md\#doctools\_markup), [doctools
syntax](\.\./\.\./\.\./\.\./index\.md\#doctools\_syntax),
[markup](\.\./\.\./\.\./\.\./index\.md\#markup), [semantic
markup](\.\./\.\./\.\./\.\./index\.md\#semantic\_markup)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
