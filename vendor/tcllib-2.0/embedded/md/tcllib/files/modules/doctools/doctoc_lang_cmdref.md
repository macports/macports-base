
[//000000001]: # (doctoc\_lang\_cmdref \- Documentation tools)
[//000000002]: # (Generated from file 'doctoc\_lang\_cmdref\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctoc\_lang\_cmdref\(n\) 1\.0 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctoc\_lang\_cmdref \- doctoc language command reference

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Commands](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

[__[comment](\.\./\.\./\.\./\.\./index\.md\#comment)__ *plaintext*](#1)  
[__division\_end__](#2)  
[__division\_start__ *text* ?*symfile*?](#3)  
[__include__ *filename*](#4)  
[__item__ *file* *text* *desc*](#5)  
[__lb__](#6)  
[__rb__](#7)  
[__toc\_begin__ *text* *title*](#8)  
[__toc\_end__](#9)  
[__vset__ *varname* *value*](#10)  
[__vset__ *varname*](#11)  

# <a name='description'></a>DESCRIPTION

This document specifies both names and syntax of all the commands which together
are the doctoc markup language, version 1\. As this document is intended to be a
reference the commands are listed in alphabetical order, and the descriptions
are relatively short\. A beginner should read the much more informally written
*[doctoc language introduction](doctoc\_lang\_intro\.md)* first\.

# <a name='section2'></a>Commands

  - <a name='1'></a>__[comment](\.\./\.\./\.\./\.\./index\.md\#comment)__ *plaintext*

    Toc markup\. The argument text is marked up as a comment standing outside of
    the actual text of the document\. Main use is in free\-form text\.

  - <a name='2'></a>__division\_end__

    Toc structure\. This command closes the division opened by the last
    __division\_begin__ command coming before it, and not yet closed\.

  - <a name='3'></a>__division\_start__ *text* ?*symfile*?

    Toc structure\. This command opens a division in the table of contents\. Its
    counterpart is __division\_end__\. Together they allow a user to give a
    table of contents additional structure\.

    The title of the new division is provided by the argument *text*\.

    If the symbolic filename *symfile* is present then the section title
    should link to the referenced document, if links are supported by the output
    format\.

  - <a name='4'></a>__include__ *filename*

    Templating\. The contents of the named file are interpreted as text written
    in the doctoc markup and processed in the place of the include command\. The
    markup in the file has to be self\-contained\. It is not possible for a markup
    command to cross the file boundaries\.

  - <a name='5'></a>__item__ *file* *text* *desc*

    Toc structure\. This command adds an individual element to the table of
    contents\. Each such element refers to a document\. The document is specified
    through the symbolic name *file*\. The *text* argument is used to label
    the reference, whereas the *desc* provides a short descriptive text of
    that document\.

    The symbolic names are used to preserve the convertibility of this format to
    any output format\. The actual name of the file will be inserted by the
    chosen formatting engine when converting the input\. This will be based on a
    mapping from symbolic to actual names given to the engine\.

  - <a name='6'></a>__lb__

    Text\. The command is replaced with a left bracket\. Use in free\-form text\.
    Required to avoid interpretation of a left bracket as the start of a markup
    command\. Its usage is restricted to the arguments of other markup commands\.

  - <a name='7'></a>__rb__

    Text\. The command is replaced with a right bracket\. Use in free\-form text\.
    Required to avoid interpretation of a right bracket as the end of a markup
    command\. Its usage is restricted to the arguments of other commands\.

  - <a name='8'></a>__toc\_begin__ *text* *title*

    Document structure\. The command to start a table of contents\. The arguments
    are a label for the whole group of documents the index refers to \(*text*\)
    and the overall title text for the index \(*title*\), without markup\.

    The label often is the name of the package \(or extension\) the documents
    belong to\.

  - <a name='9'></a>__toc\_end__

    Document structure\. Command to end a table of contents\. Anything in the
    document coming after this command is in error\.

  - <a name='10'></a>__vset__ *varname* *value*

    Templating\. In this form the command sets the named document variable to the
    specified *value*\. It does not generate output\. I\.e\. the command is
    replaced by the empty string\.

  - <a name='11'></a>__vset__ *varname*

    Templating\. In this form the command is replaced by the value of the named
    document variable

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

[doctoc\_intro](doctoc\_intro\.md), [doctoc\_lang\_faq](doctoc\_lang\_faq\.md),
[doctoc\_lang\_intro](doctoc\_lang\_intro\.md),
[doctoc\_lang\_syntax](doctoc\_lang\_syntax\.md)

# <a name='keywords'></a>KEYWORDS

[doctoc commands](\.\./\.\./\.\./\.\./index\.md\#doctoc\_commands), [doctoc
language](\.\./\.\./\.\./\.\./index\.md\#doctoc\_language), [doctoc
markup](\.\./\.\./\.\./\.\./index\.md\#doctoc\_markup),
[markup](\.\./\.\./\.\./\.\./index\.md\#markup), [semantic
markup](\.\./\.\./\.\./\.\./index\.md\#semantic\_markup)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
