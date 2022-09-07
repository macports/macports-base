
[//000000001]: # (doctools \- Documentation tools)
[//000000002]: # (Generated from file 'doctools\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2003\-2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools\(n\) 1\.5\.6 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools \- doctools \- Processing documents

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PUBLIC API](#section2)

      - [PACKAGE COMMANDS](#subsection1)

      - [OBJECT COMMAND](#subsection2)

      - [OBJECT METHODS](#subsection3)

      - [OBJECT CONFIGURATION](#subsection4)

      - [FORMAT MAPPING](#subsection5)

  - [PREDEFINED ENGINES](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require doctools ?1\.5\.6?  

[__::doctools::new__ *objectName* ?*option value*\.\.\.?](#1)  
[__::doctools::help__](#2)  
[__::doctools::search__ *path*](#3)  
[__objectName__ __method__ ?*arg arg \.\.\.*?](#4)  
[*objectName* __configure__](#5)  
[*objectName* __configure__ *option*](#6)  
[*objectName* __configure__ __\-option__ *value*\.\.\.](#7)  
[*objectName* __cget__ __\-option__](#8)  
[*objectName* __destroy__](#9)  
[*objectName* __format__ *text*](#10)  
[*objectName* __map__ *symbolic* *actual*](#11)  
[*objectName* __parameters__](#12)  
[*objectName* __search__ *path*](#13)  
[*objectName* __setparam__ *name* *value*](#14)  
[*objectName* __warnings__](#15)  

# <a name='description'></a>DESCRIPTION

This package provides a class for the creation of objects able to process and
convert text written in the *[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools)*
markup language into any output format X for which a *[formatting
engine](\.\./\.\./\.\./\.\./index\.md\#formatting\_engine)* is available\.

A reader interested in the markup language itself should start with the
*[doctools language introduction](doctools\_lang\_intro\.md)* and proceed
from there to the formal specifications, i\.e\. the *[doctools language
syntax](doctools\_lang\_syntax\.md)* and the *[doctools language command
reference](doctools\_lang\_cmdref\.md)*\.

If on the other hand the reader wishes to write her own formatting engine for
some format, i\.e\. is a *plugin writer* then reading and understanding the
*[doctools plugin API reference](doctools\_plugin\_apiref\.md)* is an
absolute necessity, as that document specifies the interaction between this
package and its plugins, i\.e\. the formatting engines, in detail\.

# <a name='section2'></a>PUBLIC API

## <a name='subsection1'></a>PACKAGE COMMANDS

  - <a name='1'></a>__::doctools::new__ *objectName* ?*option value*\.\.\.?

    This command creates a new doctools object with an associated Tcl command
    whose name is *objectName*\. This
    *[object](\.\./\.\./\.\./\.\./index\.md\#object)* command is explained in full
    detail in the sections [OBJECT COMMAND](#subsection2) and [OBJECT
    METHODS](#subsection3)\. The object command will be created under the
    current namespace if the *objectName* is not fully qualified, and in the
    specified namespace otherwise\.

    The options and their values coming after the name of the object are used to
    set the initial configuration of the object\.

  - <a name='2'></a>__::doctools::help__

    This is a convenience command for applications wishing to provide their user
    with a short description of the available formatting commands and their
    meanings\. It returns a string containing a standard help text\.

  - <a name='3'></a>__::doctools::search__ *path*

    Whenever an object created by this the package has to map the name of a
    format to the file containing the code for its formatting engine it will
    search for the file in a number of directories stored in a list\. See section
    [FORMAT MAPPING](#subsection5) for more explanations\.

    This list not only contains three default directories which are declared by
    the package itself, but is also extensible user of the package\. This command
    is the means to do so\. When given a *path* to an existing and readable
    directory it will prepend that directory to the list of directories to
    search\. This means that the *path* added last is later searched through
    first\.

    An error will be thrown if the *path* either does not exist, is not a
    directory, or is not readable\.

## <a name='subsection2'></a>OBJECT COMMAND

All commands created by __::doctools::new__ have the following general form
and may be used to invoke various operations on their doctools converter object\.

  - <a name='4'></a>__objectName__ __method__ ?*arg arg \.\.\.*?

    The method __method__ and its *arg*'uments determine the exact
    behavior of the command\. See section [OBJECT METHODS](#subsection3) for
    the detailed specifications\.

## <a name='subsection3'></a>OBJECT METHODS

  - <a name='5'></a>*objectName* __configure__

    The method returns a list of all known options and their current values when
    called without any arguments\.

  - <a name='6'></a>*objectName* __configure__ *option*

    The method behaves like the method __cget__ when called with a single
    argument and returns the value of the option specified by said argument\.

  - <a name='7'></a>*objectName* __configure__ __\-option__ *value*\.\.\.

    The method reconfigures the specified __option__s of the object, setting
    them to the associated *value*s, when called with an even number of
    arguments, at least two\.

    The legal options are described in the section [OBJECT
    CONFIGURATION](#subsection4)\.

  - <a name='8'></a>*objectName* __cget__ __\-option__

    This method expects a legal configuration option as argument and will return
    the current value of that option for the object the method was invoked for\.

    The legal configuration options are described in section [OBJECT
    CONFIGURATION](#subsection4)\.

  - <a name='9'></a>*objectName* __destroy__

    This method destroys the object it is invoked for\.

  - <a name='10'></a>*objectName* __format__ *text*

    This method runs the *text* through the configured formatting engine and
    returns the generated string as its result\. An error will be thrown if no
    __\-format__ was configured for the object\.

    The method assumes that the *text* is in
    *[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools)* format as specified in the
    companion document *doctools\_fmt*\. Errors will be thrown otherwise\.

  - <a name='11'></a>*objectName* __map__ *symbolic* *actual*

    This methods add one entry to the per\-object mapping from *symbolic*
    filenames to the *actual* uris\. The object just stores this mapping and
    makes it available to the configured formatting engine through the command
    __dt\_fmap__\. This command is described in more detail in the
    *[doctools plugin API reference](doctools\_plugin\_apiref\.md)* which
    specifies the interaction between the objects created by this package and
    doctools formatting engines\.

  - <a name='12'></a>*objectName* __parameters__

    This method returns a list containing the names of all engine parameters
    provided by the configured formatting engine\. It will return an empty list
    if the object is not yet configured for a specific format\.

  - <a name='13'></a>*objectName* __search__ *path*

    This method extends the per\-object list of paths searched for doctools
    formatting engines\. See also the command __::doctools::search__ on how
    to extend the per\-package list of paths\. Note that the path entered last
    will be searched first\. For more details see section [FORMAT
    MAPPING](#subsection5)\.

  - <a name='14'></a>*objectName* __setparam__ *name* *value*

    This method sets the *name*d engine parameter to the specified *value*\.
    It will throw an error if the object is either not yet configured for a
    specific format, or if the formatting engine for the configured format does
    not provide a parameter with the given *name*\. The list of parameters
    provided by the configured formatting engine can be retrieved through the
    method __parameters__\.

  - <a name='15'></a>*objectName* __warnings__

    This method returns a list containing all the warnings which were generated
    by the configured formatting engine during the last invocation of the method
    __format__\.

## <a name='subsection4'></a>OBJECT CONFIGURATION

All doctools objects understand the following configuration options:

  - __\-file__ *file*

    The argument of this option is stored in the object and made available to
    the configured formatting engine through the commands __dt\_file__ and
    __dt\_mainfile__\. These commands are described in more detail in the
    companion document *doctools\_api* which specifies the API between the
    object and formatting engines\.

    The default value of this option is the empty string\.

    The configured formatting engine should interpret the value as the name of
    the file containing the document which is currently processed\.

  - __\-ibase__ *file*

    The argument of this option is stored in the object and used as the base
    path for resolution of relative include paths\. If this option is not set
    \(empty string\) the value of __\-file__ is used instead\.

    Note that __\-file__ and __\-ibase__, while similar looking, are
    actually very different\. The value of __\-file__ is used by some engines
    for the generation of proper relative references between output documents
    \(HTML\)\. As such this is a *destination* path\. The __\-ibase__ on the
    other hand is used to resolve relative include paths, and as such deals with
    *[source](\.\./\.\./\.\./\.\./index\.md\#source)* paths\.

    The default value of this option is the empty string\.

  - __\-module__ *text*

    The argument of this option is stored in the object and made available to
    the configured formatting engine through the command __dt\_module__\. This
    command is described in more detail in the companion document
    *doctools\_api* which specifies the API between the object and formatting
    engines\.

    The default value of this option is the empty string\.

    The configured formatting engine should interpret the value as the name of
    the module the file containing the document which is currently processed
    belongs to\.

  - __\-format__ *text*

    The argument of this option specifies the format to generate and by
    implication the formatting engine to use when converting text via the method
    __format__\. Its default value is the empty string\. The method
    __format__ cannot be used if this option is not set to a valid value at
    least once\.

    The package will immediately try to map the given name to a file containing
    the code for a formatting engine generating that format\. An error will be
    thrown if this mapping fails\. In that case a previously configured format is
    left untouched\.

    The section [FORMAT MAPPING](#subsection5) explains in detail how the
    package and object will look for engine implementations\.

  - __\-deprecated__ *boolean*

    This option is a boolean flag\. The object will generate warnings if this
    flag is set and the text given to method __format__ contains the
    deprecated markup command __strong__\. Its default value is
    __FALSE__\. In other words, no warnings will be generated\.

  - __\-copyright__ *text*

    The argument of this option is stored in the object and made available to
    the configured formatting engine through the command __dt\_copyright__\.
    This command is described in more detail in the companion document
    *doctools\_api* which specifies the API between the object and formatting
    engines\.

    The default value of this option is the empty string\.

    The configured formatting engine should interpret the value as a copyright
    assignment for the document which is currently processed, or the package
    described by it\.

    This information must be used if and only if the engine is unable to find
    any copyright assignments within the document itself\. Such are specified by
    the formatting command __copyright__\. This command is described in more
    detail in the companion document *doctools\_fmt* which specifies the
    *[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools)* format itself\.

## <a name='subsection5'></a>FORMAT MAPPING

The package and object will perform the following algorithm when trying to map a
format name *foo* to a file containing an implementation of a formatting
engine for *foo*:

  1. If *foo* is the name of an existing file then this file is directly taken
     as the implementation\.

  1. If not, the list of per\-object search paths is searched\. For each directory
     in the list the package checks if that directory contains a file
     "fmt\.*foo*"\. If yes, then that file is taken as the implementation\.

     Note that this list of paths is initially empty and can be extended through
     the object method __search__\.

  1. If not, the list of package paths is searched\. For each directory in the
     list the package checks if that directory contains a file "fmt\.*foo*"\. If
     yes, then that file is taken as the implementation\.

     This list of paths can be extended through the command
     __::doctools::search__\. It contains initially one path, the
     subdirectory "mpformats" of the directory the package itself is located in\.
     In other words, if the package implementation "doctools\.tcl" is installed
     in the directory "/usr/local/lib/tcllib/doctools" then it will by default
     search the directory "/usr/local/lib/tcllib/doctools/mpformats" for format
     implementations\.

  1. The mapping fails\.

# <a name='section3'></a>PREDEFINED ENGINES

The package provides predefined engines for the following formats\. Some of the
engines support parameters\. These will be explained below as well\.

  - html

    This engine generates HTML markup, for processing by web browsers and the
    like\. This engine supports four parameters:

      * footer

        The value for this parameter has to be valid selfcontained HTML markup
        for the body section of a HTML document\. The default value is the empty
        string\. The value is inserted into the generated output just before the
        __</body>__ tag, closing the body of the generated HTML\.

        This can be used to insert boilerplate footer markup into the generated
        document\.

      * header

        The value for this parameter has to be valid selfcontained HTML markup
        for the body section of a HTML document\. The default value is the empty
        string\. The value is inserted into the generated output just after the
        __<body>__ tag, starting the body of the generated HTML\.

        This can be used to insert boilerplate header markup into the generated
        document\.

      * meta

        The value for this parameter has to be valid selfcontained HTML markup
        for the header section of a HTML document\. The default value is the
        empty string\. The value is inserted into the generated output just after
        the __<head>__ tag, starting the header section of the generated
        HTML\.

        This can be used to insert boilerplate meta data markup into the
        generated document, like references to a stylesheet, standard meta
        keywords, etc\.

      * xref

        The value for this parameter has to be a list of triples specifying
        cross\-reference information\. This information is used by the engine to
        create more hyperlinks\. Each triple is a list containing a pattern,
        symbolic filename and fragment reference, in this order\. If a pattern is
        specified multiple times the last occurrence of the pattern will be
        used\.

        The engine will consult the xref database when encountering specific
        commands and will create a link if the relevant text matches one of the
        patterns\. No link will be created if no match was found\. The link will
        go to the uri __file\#fragment__ listed in the relevant triple, after
        conversion of the symbolic file name to the actual uri via
        __dt\_fmap__ \(see the *[doctools plugin API
        reference](doctools\_plugin\_apiref\.md)*\)\. This file\-to\-uri mapping
        was build by calls to the method __map__ of the doctools object \(See
        section [OBJECT METHODS](#subsection3)\)\.

        The following formatting commands will consult the xref database:

          + __cmd__ *word*

            The command will look for the patterns __sa,__*word*, and
            *word*, in this order\. If this fails if it will convert *word*
            to all lowercase and try again\.

          + __syscmd__ *word*

            The command will look for the patterns __sa,__*word*, and
            *word*, in this order\. If this fails if it will convert *word*
            to all lowercase and try again\.

          + __[term](\.\./term/term\.md)__ *word*

            The command will look for the patterns __kw,__*word*,
            __sa,__*word*, and *word*, in this order\. If this fails if
            it will convert *word* to all lowercase and try again\.

          + __[package](\.\./\.\./\.\./\.\./index\.md\#package)__ *word*

            The command will look for the patterns __sa,__*word*,
            __kw,__*word*, and *word*, in this order\. If this fails if
            it will convert *word* to all lowercase and try again\.

          + __see\_also__ *word*\.\.\.

            The command will look for the patterns __sa,__*word*, and
            *word*, in this order, for each *word* given to the command\. If
            this fails if it will convert *word* to all lowercase and try
            again\.

          + __[keywords](\.\./\.\./\.\./\.\./index\.md\#keywords)__ *word*\.\.\.

            The command will look for the patterns __kw,__*word*, and
            *word*, in this order, for each *word* given to the command\. If
            this fails if it will convert *word* to all lowercase and try
            again\.

  - latex

    This engine generates output suitable for the
    __[latex](\.\./\.\./\.\./\.\./index\.md\#latex)__ text processor coming out of
    the TeX world\.

  - list

    This engine retrieves version, section and title of the manpage from the
    document\. As such it can be used to generate a directory listing for a set
    of manpages\.

  - nroff

    This engine generates nroff output, for processing by
    __[nroff](\.\./\.\./\.\./\.\./index\.md\#nroff)__, or __groff__\. The
    result will be standard man pages as they are known in the unix world\.

  - markdown

    This engine generates *[Markdown](\.\./\.\./\.\./\.\./index\.md\#markdown)*
    markup\. This engine supports two parameters:

      * header

        The value for this parameter has to be valid selfcontained markdown
        markup for the body section of a markdown document\. The default value is
        the empty string\. The value is inserted into the generated output just
        before the table of contents\.

        This can be used to insert boilerplate header markup into the generated
        document\.

      * xref

        The value for this parameter has to be a list of triples specifying
        cross\-reference information\.

        The full details of expected syntax and engine\-internal use are
        explained above for the *[html](\.\./\.\./\.\./\.\./index\.md\#html)*
        engine\.

  - null

    This engine generates no outout at all\. This can be used if one just wants
    to validate some input\.

  - tmml

    This engine generates TMML markup as specified by Joe English\. The Tcl
    Manpage Markup Language is a derivate of XML\.

  - wiki

    This engine generates Wiki markup as understood by Jean Claude Wippler's
    __wikit__ application\.

# <a name='section4'></a>Bugs, Ideas, Feedback

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
[doctools\_lang\_intro](doctools\_lang\_intro\.md),
[doctools\_lang\_syntax](doctools\_lang\_syntax\.md),
[doctools\_plugin\_apiref](doctools\_plugin\_apiref\.md)

# <a name='keywords'></a>KEYWORDS

[HTML](\.\./\.\./\.\./\.\./index\.md\#html), [TMML](\.\./\.\./\.\./\.\./index\.md\#tmml),
[conversion](\.\./\.\./\.\./\.\./index\.md\#conversion),
[documentation](\.\./\.\./\.\./\.\./index\.md\#documentation),
[manpage](\.\./\.\./\.\./\.\./index\.md\#manpage),
[markdown](\.\./\.\./\.\./\.\./index\.md\#markdown),
[markup](\.\./\.\./\.\./\.\./index\.md\#markup),
[nroff](\.\./\.\./\.\./\.\./index\.md\#nroff)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2003\-2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
