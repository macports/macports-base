
[//000000001]: # (page \- Development Tools)
[//000000002]: # (Generated from file 'page\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (page\(n\) 1\.0 tcllib "Development Tools")

<hr> [ <a href="../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../toc.md">Table Of Contents</a> &#124; <a
href="../../../index.md">Keyword Index</a> &#124; <a
href="../../../toc0.md">Categories</a> &#124; <a
href="../../../toc1.md">Modules</a> &#124; <a
href="../../../toc2.md">Applications</a> ] <hr>

# NAME

page \- Parser Generator

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

      - [COMMAND LINE](#subsection1)

      - [OPERATION](#subsection2)

      - [OPTIONS](#subsection3)

      - [PLUGINS](#subsection4)

      - [PLUGIN LOCATIONS](#subsection5)

  - [Bugs, Ideas, Feedback](#section2)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

[__page__ ?*options*\.\.\.? ?*input* ?*output*??](#1)  

# <a name='description'></a>DESCRIPTION

The application described by this document, __page__, is actually not just a
parser generator, as the name implies, but a generic tool for the execution of
arbitrary transformations on texts\.

Its genericity comes through the use of *plugins* for reading, transforming,
and writing data, and the predefined set of plugins provided by Tcllib is for
the generation of memoizing recursive descent parsers \(aka *packrat parsers*\)
from grammar specifications \(*Parsing Expression Grammars*\)\.

__page__ is written on top of the package __page::pluginmgr__, wrapping
its functionality into a command line based application\. All the other
__page::\*__ packages are plugin and/or supporting packages for the
generation of parsers\. The parsers themselves are based on the packages
__[grammar::peg](\.\./modules/grammar\_peg/peg\.md)__,
__[grammar::peg::interp](\.\./modules/grammar\_peg/peg\_interp\.md)__, and
__grammar::mengine__\.

## <a name='subsection1'></a>COMMAND LINE

  - <a name='1'></a>__page__ ?*options*\.\.\.? ?*input* ?*output*??

    This is general form for calling __page__\. The application will read the
    contents of the file *input*, process them under the control of the
    specified *options*, and then write the result to the file *output*\.

    If *input* is the string __\-__ the data to process will be read from
    __stdin__ instead of a file\. Analogously the result will be written to
    __stdout__ instead of a file if *output* is the string __\-__\. A
    missing output or input specification causes the application to assume
    __\-__\.

    The detailed specifications of the recognized *options* are provided in
    section [OPTIONS](#subsection3)\.

      * path *input* \(in\)

        This argument specifies the path to the file to be processed by the
        application, or __\-__\. The last value causes the application to read
        the text from __stdin__\. Otherwise it has to exist, and be readable\.
        If the argument is missing __\-__ is assumed\.

      * path *output* \(in\)

        This argument specifies where to write the generated text\. It can be the
        path to a file, or __\-__\. The last value causes the application to
        write the generated documented to __stdout__\.

        If the file *output* does not exist then \[file dirname $output\] has to
        exist and must be a writable directory, as the application will create
        the fileto write to\.

        If the argument is missing __\-__ is assumed\.

## <a name='subsection2'></a>OPERATION

\.\.\. reading \.\.\. transforming \.\.\. writing \- plugins \- pipeline \.\.\.

## <a name='subsection3'></a>OPTIONS

This section describes all the options available to the user of the application\.
Options are always processed in order\. I\.e\. of both __\-\-help__ and
__\-\-version__ are specified the option encountered first has precedence\.

Unknown options specified before any of the options __\-rd__, __\-wr__, or
__\-tr__ will cause processing to abort with an error\. Unknown options coming
in between these options, or after the last of them are assumed to always take a
single argument and are associated with the last plugin option coming before
them\. They will be checked after all the relevant plugins, and thus the options
they understand, are known\. I\.e\. such unknown options cause error if and only if
the plugin option they are associated with does not understand them, and was not
superceded by a plugin option coming after\.

Default options are used if and only if the command line did not contain any
options at all\. They will set the application up as a PEG\-based parser
generator\. The exact list of options is

    -c peg

And now the recognized options and their arguments, if they have any:

  - __\-\-help__

  - __\-h__

  - __\-?__

    When one of these options is found on the command line all arguments coming
    before or after are ignored\. The application will print a short description
    of the recognized options and exit\.

  - __\-\-version__

  - __\-V__

    When one of these options is found on the command line all arguments coming
    before or after are ignored\. The application will print its own revision and
    exit\.

  - __\-P__

    This option signals the application to activate visual feedback while
    reading the input\.

  - __\-T__

    This option signals the application to collect statistics while reading the
    input and to print them after reading has completed, before processing
    started\.

  - __\-D__

    This option signals the application to activate logging in the Safe base,
    for the debugging of problems with plugins\.

  - __\-r__ parser

  - __\-rd__ parser

  - __\-\-reader__ parser

    These options specify the plugin the application has to use for reading the
    *input*\. If the options are used multiple times the last one will be used\.

  - __\-w__ generator

  - __\-wr__ generator

  - __\-\-writer__ generator

    These options specify the plugin the application has to use for generating
    and writing the final *output*\. If the options are used multiple times the
    last one will be used\.

  - __\-t__ process

  - __\-tr__ process

  - __\-\-transform__ process

    These options specify a plugin to run on the input\. In contrast to readers
    and writers each use will *not* supersede previous uses, but add each
    chosen plugin to a list of transformations, either at the front, or the end,
    per the last seen use of either option __\-p__ or __\-a__\. The initial
    default is to append the new transformations\.

  - __\-a__

  - __\-\-append__

    These options signal the application that all following transformations
    should be added at the end of the list of transformations\.

  - __\-p__

  - __\-\-prepend__

    These options signal the application that all following transformations
    should be added at the beginning of the list of transformations\.

  - __\-\-reset__

    This option signals the application to clear the list of transformations\.
    This is necessary to wipe out the default transformations used\.

  - __\-c__ file

  - __\-\-configuration__ file

    This option causes the application to load a configuration file and/or
    plugin\. This is a plugin which in essence provides a pre\-defined set of
    commandline options\. They are processed exactly as if they have been
    specified in place of the option and its arguments\. This means that unknown
    options found at the beginning of the configuration file are associated with
    the last plugin, even if that plugin was specified before the configuration
    file itself\. Conversely, unknown options coming after the configuration file
    can be associated with a plugin specified in the file\.

    If the argument is a file which cannot be loaded as a plugin the application
    will assume that its contents are a list of options and their arguments,
    separated by space, tabs, and newlines\. Options and argumentes containing
    spaces can be quoted via double\-quotes \("\) and quotes \('\)\. The quote
    character can be specified within in a quoted string by doubling it\.
    Newlines in a quoted string are accepted as is\.

## <a name='subsection4'></a>PLUGINS

__page__ makes use of four different types of plugins, namely: readers,
writers, transformations, and configurations\. Here we provide only a basic
introduction on how to use them from __page__\. The exact APIs provided to
and expected from the plugins can be found in the documentation for
__page::pluginmgr__, for those who wish to write their own plugins\.

Plugins are specified as arguments to the options __\-r__, __\-w__,
__\-t__, __\-c__, and their equivalent longer forms\. See the section
[OPTIONS](#subsection3) for reference\.

Each such argument will be first treated as the name of a file and this file is
loaded as the plugin\. If however there is no file with that name, then it will
be translated into the name of a package, and this package is then loaded\. For
each type of plugins the package management searches not only the regular paths,
but a set application\- and type\-specific paths as well\. Please see the section
[PLUGIN LOCATIONS](#subsection5) for a listing of all paths and their
sources\.

  - __\-c__ *name*

    Configurations\. The name of the package for the plugin *name* is
    "page::config::*name*"\.

    We have one predefined plugin:

      * *peg*

        It sets the application up as a parser generator accepting parsing
        expression grammars and writing a packrat parser in Tcl\. The actual
        arguments it specifies are:

    --reset
    --append
    --reader    peg
    --transform reach
    --transform use
    --writer    me

  - __\-r__ *name*

    Readers\. The name of the package for the plugin *name* is
    "page::reader::*name*"\.

    We have five predefined plugins:

      * *peg*

        Interprets the input as a parsing expression grammar
        \(*[PEG](\.\./\.\./\.\./index\.md\#peg)*\) and generates a tree
        representation for it\. Both the syntax of PEGs and the structure of the
        tree representation are explained in their own manpages\.

      * *hb*

        Interprets the input as Tcl code as generated by the writer plugin
        *hb* and generates its tree representation\.

      * *ser*

        Interprets the input as the serialization of a PEG, as generated by the
        writer plugin *ser*, using the package
        __[grammar::peg](\.\./modules/grammar\_peg/peg\.md)__\.

      * *lemon*

        Interprets the input as a grammar specification as understood by Richard
        Hipp's *[LEMON](\.\./\.\./\.\./index\.md\#lemon)* parser generator and
        generates a tree representation for it\. Both the input syntax and the
        structure of the tree representation are explained in their own
        manpages\.

      * *treeser*

        Interprets the input as the serialization of a
        __[struct::tree](\.\./modules/struct/struct\_tree\.md)__\. It is
        validated as such, but nothing else\. It is *not* assumed to be the
        tree representation of a grammar\.

  - __\-w__ *name*

    Writers\. The name of the package for the plugin *name* is
    "page::writer::*name*"\.

    We have eight predefined plugins:

      * *identity*

        Simply writes the incoming data as it is, without making any changes\.
        This is good for inspecting the raw result of a reader or
        transformation\.

      * *null*

        Generates nothing, and ignores the incoming data structure\.

      * *tree*

        Assumes that the incoming data structure is a
        __[struct::tree](\.\./modules/struct/struct\_tree\.md)__ and
        generates an indented textual representation of all nodes, their
        parental relationships, and their attribute information\.

      * *peg*

        Assumes that the incoming data structure is a tree representation of a
        *[PEG](\.\./\.\./\.\./index\.md\#peg)* or other other grammar and writes
        it out as a PEG\. The result is nicely formatted and partially simplified
        \(strings as sequences of characters\)\. A pretty printer in essence, but
        can also be used to obtain a canonical representation of the input
        grammar\.

      * *tpc*

        Assumes that the incoming data structure is a tree representation of a
        *[PEG](\.\./\.\./\.\./index\.md\#peg)* or other other grammar and writes
        out Tcl code defining a package which defines a
        __[grammar::peg](\.\./modules/grammar\_peg/peg\.md)__ object
        containing the grammar when it is loaded into an interpreter\.

      * *hb*

        This is like the writer plugin *tpc*, but it writes only the
        statements which define stat expression and grammar rules\. The code
        making the result a package is left out\.

      * *ser*

        Assumes that the incoming data structure is a tree representation of a
        *[PEG](\.\./\.\./\.\./index\.md\#peg)* or other other grammar, transforms
        it internally into a
        __[grammar::peg](\.\./modules/grammar\_peg/peg\.md)__ object and
        writes out its serialization\.

      * *me*

        Assumes that the incoming data structure is a tree representation of a
        *[PEG](\.\./\.\./\.\./index\.md\#peg)* or other other grammar and writes
        out Tcl code defining a package which implements a memoizing recursive
        descent parser based on the match engine \(ME\) provided by the package
        __grammar::mengine__\.

  - __\-t__ *name*

    Transformers\. The name of the package for the plugin *name* is
    "page::transform::*name*"\.

    We have two predefined plugins:

      * *reach*

        Assumes that the incoming data structure is a tree representation of a
        *[PEG](\.\./\.\./\.\./index\.md\#peg)* or other other grammar\. It
        determines which nonterminal symbols and rules are reachable from
        start\-symbol/expression\. All nonterminal symbols which were not reached
        are removed\.

      * *use*

        Assumes that the incoming data structure is a tree representation of a
        *[PEG](\.\./\.\./\.\./index\.md\#peg)* or other other grammar\. It
        determines which nonterminal symbols and rules are able to generate a
        *finite* sequences of terminal symbols \(in the sense for a Context
        Free Grammar\)\. All nonterminal symbols which were not deemed useful in
        this sense are removed\.

## <a name='subsection5'></a>PLUGIN LOCATIONS

The application\-specific paths searched by __page__ either are, or come
from:

  1. The directory "~/\.page/plugin"

  1. The environment variable *PAGE\_PLUGINS*

  1. The registry entry *HKEY\_LOCAL\_MACHINE\\SOFTWARE\\PAGE\\PLUGINS*

  1. The registry entry *HKEY\_CURRENT\_USER\\SOFTWARE\\PAGE\\PLUGINS*

The type\-specific paths searched by __page__ either are, or come from:

  1. The directory "~/\.page/plugin/<TYPE>"

  1. The environment variable *PAGE\_<TYPE>\_PLUGINS*

  1. The registry entry *HKEY\_LOCAL\_MACHINE\\SOFTWARE\\PAGE\\<TYPE>\\PLUGINS*

  1. The registry entry *HKEY\_CURRENT\_USER\\SOFTWARE\\PAGE\\<TYPE>\\PLUGINS*

Where the placeholder *<TYPE>* is always one of the values below, properly
capitalized\.

  1. reader

  1. writer

  1. transform

  1. config

The registry entries are specific to the Windows\(tm\) platform, all other
platforms will ignore them\.

The contents of both environment variables and registry entries are interpreted
as a list of paths, with the elements separated by either colon \(Unix\), or
semicolon \(Windows\)\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *page* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

page::pluginmgr

# <a name='keywords'></a>KEYWORDS

[parser generator](\.\./\.\./\.\./index\.md\#parser\_generator), [text
processing](\.\./\.\./\.\./index\.md\#text\_processing)

# <a name='category'></a>CATEGORY

Page Parser Generator

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
