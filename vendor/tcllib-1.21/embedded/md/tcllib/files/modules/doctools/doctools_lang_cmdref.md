
[//000000001]: # (doctools\_lang\_cmdref \- Documentation tools)
[//000000002]: # (Generated from file 'doctools\_lang\_cmdref\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007\-2010 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools\_lang\_cmdref\(n\) 1\.0 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools\_lang\_cmdref \- doctools language command reference

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

[__arg__ *text*](#1)  
[__arg\_def__ *type* *name* ?*mode*?](#2)  
[__bullet__](#3)  
[__call__ *args*](#4)  
[__category__ *text*](#5)  
[__[class](\.\./\.\./\.\./\.\./index\.md\#class)__ *text*](#6)  
[__cmd__ *text*](#7)  
[__cmd\_def__ *command*](#8)  
[__[comment](\.\./\.\./\.\./\.\./index\.md\#comment)__ *plaintext*](#9)  
[__const__ *text*](#10)  
[__copyright__ *text*](#11)  
[__def__ *text*](#12)  
[__description__](#13)  
[__enum__](#14)  
[__emph__ *text*](#15)  
[__example__ *text*](#16)  
[__example\_begin__](#17)  
[__example\_end__](#18)  
[__[file](\.\./\.\./\.\./\.\./index\.md\#file)__ *text*](#19)  
[__fun__ *text*](#20)  
[__[image](\.\./\.\./\.\./\.\./index\.md\#image)__ *name* ?*label*?](#21)  
[__include__ *filename*](#22)  
[__item__](#23)  
[__[keywords](\.\./\.\./\.\./\.\./index\.md\#keywords)__ *args*](#24)  
[__lb__](#25)  
[__list\_begin__ *what*](#26)  
[__list\_end__](#27)  
[__lst\_item__ *text*](#28)  
[__manpage\_begin__ *command* *section* *version*](#29)  
[__manpage\_end__](#30)  
[__[method](\.\./\.\./\.\./\.\./index\.md\#method)__ *text*](#31)  
[__moddesc__ *text*](#32)  
[__namespace__ *text*](#33)  
[__nl__](#34)  
[__opt__ *text*](#35)  
[__opt\_def__ *name* ?*arg*?](#36)  
[__option__ *text*](#37)  
[__[package](\.\./\.\./\.\./\.\./index\.md\#package)__ *text*](#38)  
[__para__](#39)  
[__rb__](#40)  
[__require__ *package* ?*version*?](#41)  
[__section__ *name*](#42)  
[__sectref__ *id* ?*text*?](#43)  
[__sectref\-external__ *text*](#44)  
[__see\_also__ *args*](#45)  
[__strong__ *text*](#46)  
[__subsection__ *name*](#47)  
[__syscmd__ *text*](#48)  
[__[term](\.\./term/term\.md)__ *text*](#49)  
[__titledesc__ *desc*](#50)  
[__tkoption\_def__ *name* *dbname* *dbclass*](#51)  
[__[type](\.\./\.\./\.\./\.\./index\.md\#type)__ *text*](#52)  
[__[uri](\.\./uri/uri\.md)__ *text* ?*text*?](#53)  
[__usage__ *args*](#54)  
[__var__ *text*](#55)  
[__vset__ *varname* *value*](#56)  
[__vset__ *varname*](#57)  
[__[widget](\.\./\.\./\.\./\.\./index\.md\#widget)__ *text*](#58)  

# <a name='description'></a>DESCRIPTION

This document specifies both names and syntax of all the commands which together
are the doctools markup language, version 1\. As this document is intended to be
a reference the commands are listed in alphabetical order, and the descriptions
are relatively short\. A beginner should read the much more informally written
*[doctools language introduction](doctools\_lang\_intro\.md)* first\.

# <a name='section2'></a>Commands

  - <a name='1'></a>__arg__ *text*

    Text markup\. The argument text is marked up as the *argument* of a
    command\. Main uses are the highlighting of command arguments in free\-form
    text, and for the argument parameters of the markup commands __call__
    and __usage__\.

  - <a name='2'></a>__arg\_def__ *type* *name* ?*mode*?

    Text structure\. List element\. Argument list\. Automatically closes the
    previous list element\. Specifies the data\-*type* of the described argument
    of a command, its *name* and its i/o\-*mode*\. The latter is optional\.

  - <a name='3'></a>__bullet__

    *Deprecated*\. Text structure\. List element\. Itemized list\. See
    __item__ for the canonical command to open a list item in an itemized
    list\.

  - <a name='4'></a>__call__ *args*

    Text structure\. List element\. Definition list\. Automatically closes the
    previous list element\. Defines the term as a command and its arguments\. The
    first argument is the name of the command described by the following
    free\-form text, and all arguments coming after that are descriptions of the
    command's arguments\. It is expected that the arguments are marked up with
    __arg__, __[method](\.\./\.\./\.\./\.\./index\.md\#method)__,
    __option__ etc\., as is appropriate, and that the command itself is
    marked up with __cmd__\. It is expected that the formatted term is not
    only printed in place, but also in the table of contents of the document, or
    synopsis, depending on the output format\.

  - <a name='5'></a>__category__ *text*

    Document information\. Anywhere\. This command registers its plain text
    arguments as the category this document belongs to\. If this command is used
    multiple times the last value specified is used\.

  - <a name='6'></a>__[class](\.\./\.\./\.\./\.\./index\.md\#class)__ *text*

    Text markup\. The argument is marked up as the name of a
    *[class](\.\./\.\./\.\./\.\./index\.md\#class)*\. The text may have other markup
    already applied to it\. Main use is the highlighting of class names in
    free\-form text\.

  - <a name='7'></a>__cmd__ *text*

    Text markup\. The argument text is marked up as the name of a *Tcl
    command*\. The text may have other markup already applied to it\. Main uses
    are the highlighting of commands in free\-form text, and for the command
    parameters of the markup commands __call__ and __usage__\.

  - <a name='8'></a>__cmd\_def__ *command*

    Text structure\. List element\. Command list\. Automatically closes the
    previous list element\. The argument specifies the name of the *Tcl
    command* to be described by the list element\. Expected to be marked up in
    the output as if it had been formatted with __cmd__\.

  - <a name='9'></a>__[comment](\.\./\.\./\.\./\.\./index\.md\#comment)__ *plaintext*

    Text markup\. The argument text is marked up as a comment standing outside of
    the actual text of the document\. Main use is in free\-form text\.

  - <a name='10'></a>__const__ *text*

    Text markup\. The argument is marked up as a *constant* value\. The text may
    have other markup already applied to it\. Main use is the highlighting of
    constants in free\-form text\.

  - <a name='11'></a>__copyright__ *text*

    Document information\. Anywhere\. The command registers the plain text
    argument as a copyright assignment for the manpage\. When invoked more than
    once the assignments are accumulated\.

  - <a name='12'></a>__def__ *text*

    Text structure\. List element\. Definition list\. Automatically closes the
    previous list element\. The argument text is the term defined by the new list
    element\. Text markup can be applied to it\.

  - <a name='13'></a>__description__

    Document structure\. This command separates the header from the document
    body\. Implicitly starts a section named "DESCRIPTION" \(See command
    __section__\)\.

  - <a name='14'></a>__enum__

    Text structure\. List element\. Enumerated list\. Automatically closes the
    previous list element\.

  - <a name='15'></a>__emph__ *text*

    Text markup\. The argument text is marked up as emphasized\. Main use is for
    general highlighting of pieces of free\-form text without attaching special
    meaning to the pieces\.

  - <a name='16'></a>__example__ *text*

    Text structure, Text markup\. This command marks its argument up as an
    *example*\. Main use is the simple embedding of examples in free\-form text\.
    It should be used if the example does *not* need special markup of its
    own\. Otherwise use a sequence of __example\_begin__ \.\.\.
    __example\_end__\.

  - <a name='17'></a>__example\_begin__

    Text structure\. This commands starts an example\. All text until the next
    __example\_end__ belongs to the example\. Line breaks, spaces, and tabs
    have to be preserved literally\. Examples cannot be nested\.

  - <a name='18'></a>__example\_end__

    Text structure\. This command closes the example started by the last
    __example\_begin__\.

  - <a name='19'></a>__[file](\.\./\.\./\.\./\.\./index\.md\#file)__ *text*

    Text markup\. The argument is marked up as a
    *[file](\.\./\.\./\.\./\.\./index\.md\#file)* or *directory*, i\.e\. in general
    a *path*\. The text may have other markup already applied to it\. Main use
    is the highlighting of paths in free\-form text\.

  - <a name='20'></a>__fun__ *text*

    Text markup\. The argument is marked up as the name of a *function*\. The
    text may have other markup already applied to it\. Main use is the
    highlighting of function names in free\-form text\.

  - <a name='21'></a>__[image](\.\./\.\./\.\./\.\./index\.md\#image)__ *name* ?*label*?

    Text markup\. The argument is the symbolic name of an
    *[image](\.\./\.\./\.\./\.\./index\.md\#image)* and replaced with the image
    itself, if a suitable variant is found by the backend\. The second argument,
    should it be present, will be interpreted the human\-readable description of
    the image, and put into the output in a suitable position, if such is
    supported by the format\. The HTML format, for example, can place it into the
    *alt* attribute of image references\.

  - <a name='22'></a>__include__ *filename*

    Templating\. The contents of the named file are interpreted as text written
    in the doctools markup and processed in the place of the include command\.
    The markup in the file has to be self\-contained\. It is not possible for a
    markup command to cross the file boundaries\.

  - <a name='23'></a>__item__

    Text structure\. List element\. Itemized list\. Automatically closes the
    previous list element\.

  - <a name='24'></a>__[keywords](\.\./\.\./\.\./\.\./index\.md\#keywords)__ *args*

    Document information\. Anywhere\. This command registers all its plain text
    arguments as keywords applying to this document\. Each argument is a single
    keyword\. If this command is used multiple times all the arguments
    accumulate\.

  - <a name='25'></a>__lb__

    Text\. The command is replaced with a left bracket\. Use in free\-form text\.
    Required to avoid interpretation of a left bracket as the start of a markup
    command\.

  - <a name='26'></a>__list\_begin__ *what*

    Text structure\. This command starts a list\. The exact nature of the list is
    determined by the argument *what* of the command\. This further determines
    which commands are have to be used to start the list elements\. Lists can be
    nested, i\.e\. it is allowed to start a new list within a list element\.

    The allowed types \(and their associated item commands\) are:

      * __arguments__

        __arg\_def__\.

      * __commands__

        __cmd\_def__\.

      * __definitions__

        __def__ and __call__\.

      * __enumerated__

        __enum__

      * __itemized__

        __item__

      * __options__

        __opt\_def__

      * __tkoptions__

        __tkoption\_def__

    Additionally the following names are recognized as shortcuts for some of the
    regular types:

      * __args__

        Short for __arguments__\.

      * __cmds__

        Short for __commands__\.

      * __enum__

        Short for __enumerated__\.

      * __item__

        Short for __itemized__\.

      * __opts__

        Short for __options__\.

    At last the following names are still recognized for backward compatibility,
    but are otherwise considered to be *deprecated*\.

      * __arg__

        *Deprecated*\. See __arguments__\.

      * __bullet__

        *Deprecated*\. See __itemized__\.

      * __cmd__

        *Deprecated*\. See __commands__\.

      * __opt__

        *Deprecated*\. See __options__\.

      * __tkoption__

        *Deprecated*\. See __tkoptions__\.

  - <a name='27'></a>__list\_end__

    Text structure\. This command closes the list opened by the last
    __list\_begin__ command coming before it\.

  - <a name='28'></a>__lst\_item__ *text*

    *Deprecated*\. Text structure\. List element\. Definition list\. See
    __def__ for the canonical command to open a general list item in a
    definition list\.

  - <a name='29'></a>__manpage\_begin__ *command* *section* *version*

    Document structure\. The command to start a manpage\. The arguments are the
    name of the *command* described by the manpage, the *section* of the
    manpages this manpage resides in, and the *version* of the module
    containing the command\. All arguments have to be plain text, without markup\.

  - <a name='30'></a>__manpage\_end__

    Document structure\. Command to end a manpage/document\. Anything in the
    document coming after this command is in error\.

  - <a name='31'></a>__[method](\.\./\.\./\.\./\.\./index\.md\#method)__ *text*

    Text markup\. The argument text is marked up as the name of an
    *[object](\.\./\.\./\.\./\.\./index\.md\#object)*
    *[method](\.\./\.\./\.\./\.\./index\.md\#method)*, i\.e\. subcommand of a Tcl
    command\. The text may have other markup already applied to it\. Main uses are
    the highlighting of method names in free\-form text, and for the command
    parameters of the markup commands __call__ and __usage__\.

  - <a name='32'></a>__moddesc__ *text*

    Document information\. Header\. Registers the plain text argument as a short
    description of the module the manpage resides in\.

  - <a name='33'></a>__namespace__ *text*

    Text markup\. The argument text is marked up as a namespace name\. The text
    may have other markup already applied to it\. Main use is the highlighting of
    namespace names in free\-form text\.

  - <a name='34'></a>__nl__

    *Deprecated*\. Text structure\. See __para__ for the canonical command
    to insert paragraph breaks into the text\.

  - <a name='35'></a>__opt__ *text*

    Text markup\. The argument text is marked up as *optional*\. The text may
    have other markup already applied to it\. Main use is the highlighting of
    optional arguments, see the command arg __arg__\.

  - <a name='36'></a>__opt\_def__ *name* ?*arg*?

    Text structure\. List element\. Option list\. Automatically closes the previous
    list element\. Specifies *name* and arguments of the *option* described
    by the list element\. It is expected that the name is marked up using
    __option__\.

  - <a name='37'></a>__option__ *text*

    Text markup\. The argument is marked up as *option*\. The text may have
    other markup already applied to it\. Main use is the highlighting of options,
    also known as command\-switches, in either free\-form text, or the arguments
    of the __call__ and __usage__ commands\.

  - <a name='38'></a>__[package](\.\./\.\./\.\./\.\./index\.md\#package)__ *text*

    Text markup\. The argument is marked up as the name of a
    *[package](\.\./\.\./\.\./\.\./index\.md\#package)*\. The text may have other
    markup already applied to it\. Main use is the highlighting of package names
    in free\-form text\.

  - <a name='39'></a>__para__

    Text structure\. This command breaks free\-form text into paragraphs\. Each
    command closes the paragraph coming before it and starts a new paragraph for
    the text coming after it\. Higher\-level forms of structure are sections and
    subsections\.

  - <a name='40'></a>__rb__

    Text\. The command is replaced with a right bracket\. Use in free\-form text\.
    Required to avoid interpretation of a right bracket as the end of a markup
    command\.

  - <a name='41'></a>__require__ *package* ?*version*?

    Document information\. Header\. This command registers its argument
    *package* as the name of a package or application required by the
    described package or application\. A minimum version can be provided as well\.
    This argument can be marked up\. The usual markup is __opt__\.

  - <a name='42'></a>__section__ *name*

    Text structure\. This command starts a new named document section\. The
    argument has to be plain text\. Implicitly closes the last paragraph coming
    before it and also implicitly opens the first paragraph of the new section\.

  - <a name='43'></a>__sectref__ *id* ?*text*?

    Text markup\. Formats a reference to the section identified by *id*\. If no
    *text* is specified the title of the referenced section is used in the
    output, otherwise *text* is used\.

  - <a name='44'></a>__sectref\-external__ *text*

    Text markup\. Like __sectref__, except that the section is assumed to be
    in a different document and therefore doesn't need to be identified, nor are
    any checks for existence made\. Only the text to format is needed\.

  - <a name='45'></a>__see\_also__ *args*

    Document information\. Anywhere\. The command defines direct cross\-references
    to other documents\. Each argument is a plain text label identifying the
    referenced document\. If this command is used multiple times all the
    arguments accumulate\.

  - <a name='46'></a>__strong__ *text*

    *Deprecated*\. Text markup\. See __emph__ for the canonical command to
    emphasize text\.

  - <a name='47'></a>__subsection__ *name*

    Text structure\. This command starts a new named subsection of a section\. The
    argument has to be plain text\. Implicitly closes the last paragraph coming
    before it and also implicitly opens the first paragraph of the new
    subsection\.

  - <a name='48'></a>__syscmd__ *text*

    Text markup\. The argument text is marked up as the name of an external
    command\. The text may have other markup already applied to it\. Main use is
    the highlighting of external commands in free\-form text\.

  - <a name='49'></a>__[term](\.\./term/term\.md)__ *text*

    Text markup\. The argument is marked up as unspecific terminology\. The text
    may have other markup already applied to it\. Main use is the highlighting of
    important terms and concepts in free\-form text\.

  - <a name='50'></a>__titledesc__ *desc*

    Document information\. Header\. Optional\. Registers the plain text argument as
    the title of the manpage\. Defaults to the value registered by
    __moddesc__\.

  - <a name='51'></a>__tkoption\_def__ *name* *dbname* *dbclass*

    Text structure\. List element\. Widget option list\. Automatically closes the
    previous list element\. Specifies the *name* of the option as used in
    scripts, the name used by the option database \(*dbname*\), and its class
    \(*dbclass*\), i\.e\. its type\. It is expected that the name is marked up
    using __option__\.

  - <a name='52'></a>__[type](\.\./\.\./\.\./\.\./index\.md\#type)__ *text*

    Text markup\. The argument is marked up as the name of a *data type*\. The
    text may have other markup already applied to it\. Main use is the
    highlighting of data types in free\-form text\.

  - <a name='53'></a>__[uri](\.\./uri/uri\.md)__ *text* ?*text*?

    Text markup\. The argument is marked up as an
    *[uri](\.\./\.\./\.\./\.\./index\.md\#uri)* \(i\.e\. a *uniform resource
    identifier*\. The text may have other markup already applied to it\. Main use
    is the highlighting of uris in free\-form text\. The second argument, should
    it be present, will be interpreted the human\-readable description of the
    uri\. In other words, as its label\. Without an explicit label the uri will be
    its own label\.

  - <a name='54'></a>__usage__ *args*

    Text markup\. See __call__ for the full description, this command is
    syntactically identical, as it is in its expectations for the markup of its
    arguments\. In contrast to __call__ it is however not allowed to generate
    output where this command occurs in the text\. The command is *silent*\. The
    formatted text may only appear in a different section of the output, for
    example a table of contents, or synopsis, depending on the output format\.

  - <a name='55'></a>__var__ *text*

    Text markup\. The argument is marked up as the name of a *variable*\. The
    text may have other markup already applied to it\. Main use is the
    highlighting of variables in free\-form text\.

  - <a name='56'></a>__vset__ *varname* *value*

    Templating\. In this form the command sets the named document variable to the
    specified *value*\. It does not generate output\. I\.e\. the command is
    replaced by the empty string\.

  - <a name='57'></a>__vset__ *varname*

    Templating\. In this form the command is replaced by the value of the named
    document variable

  - <a name='58'></a>__[widget](\.\./\.\./\.\./\.\./index\.md\#widget)__ *text*

    Text markup\. The argument is marked up as the name of a
    *[widget](\.\./\.\./\.\./\.\./index\.md\#widget)*\. The text may have other
    markup already applied to it\. Main use is the highlighting of widget names
    in free\-form text\.

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
[doctools\_lang\_faq](doctools\_lang\_faq\.md),
[doctools\_lang\_intro](doctools\_lang\_intro\.md),
[doctools\_lang\_syntax](doctools\_lang\_syntax\.md)

# <a name='keywords'></a>KEYWORDS

[doctools commands](\.\./\.\./\.\./\.\./index\.md\#doctools\_commands), [doctools
language](\.\./\.\./\.\./\.\./index\.md\#doctools\_language), [doctools
markup](\.\./\.\./\.\./\.\./index\.md\#doctools\_markup),
[markup](\.\./\.\./\.\./\.\./index\.md\#markup), [semantic
markup](\.\./\.\./\.\./\.\./index\.md\#semantic\_markup)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007\-2010 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
