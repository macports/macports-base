
[//000000001]: # (tcldocstrip \- Textprocessing toolbox)
[//000000002]: # (Generated from file 'tcldocstrip\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (tcldocstrip\(n\) 1\.0 tcllib "Textprocessing toolbox")

<hr> [ <a href="../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../toc.md">Table Of Contents</a> &#124; <a
href="../../../index.md">Keyword Index</a> &#124; <a
href="../../../toc0.md">Categories</a> &#124; <a
href="../../../toc1.md">Modules</a> &#124; <a
href="../../../toc2.md">Applications</a> ] <hr>

# NAME

tcldocstrip \- Tcl\-based Docstrip Processor

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

      - [USE CASES](#subsection1)

      - [COMMAND LINE](#subsection2)

      - [OPTIONS](#subsection3)

  - [Bugs, Ideas, Feedback](#section2)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

[__tcldocstrip__ *output* ?options? *input* ?*guards*?](#1)  
[__tcldocstrip__ ?options? *output* \(?options? *input* *guards*\)\.\.\.](#2)  
[__tcldocstrip__ __\-guards__ *input*](#3)  

# <a name='description'></a>DESCRIPTION

The application described by this document, __tcldocstrip__, is a relative
of __[docstrip](\.\./modules/docstrip/docstrip\.md)__, a simple literate
programming tool for LaTeX\.

__tcldocstrip__ is based upon the package
__[docstrip](\.\./modules/docstrip/docstrip\.md)__\.

## <a name='subsection1'></a>USE CASES

__tcldocstrip__ was written with the following three use cases in mind\.

  1. Conversion of a single input file according to the listed guards into the
     stripped output\. This handles the most simple case of a set of guards
     specifying a single document found in a single input file\.

  1. Stitching, or the assembly of an output from several sets of guards, in a
     specific order, and possibly from different files\. This is the second
     common case\. One document spread over several inputs, and/or spread over
     different guard sets\.

  1. Extraction and listing of all the unique guard expressions and guards used
     within a document to help a person which did not author the document in
     question in familiarizing itself with it\.

## <a name='subsection2'></a>COMMAND LINE

  - <a name='1'></a>__tcldocstrip__ *output* ?options? *input* ?*guards*?

    This is the form for use case \[1\]\. It converts the *input* file according
    to the specified *guards* and options\. The result is written to the named
    *output* file\. Usage of the string __\-__ as the name of the output
    signals that the result should be written to __stdout__\. The guards are
    document\-specific and have to be known to the caller\. The *options* will
    be explained later, in section [OPTIONS](#subsection3)\.

      * path *output* \(in\)

        This argument specifies where to write the generated document\. It can be
        the path to a file or directory, or __\-__\. The last value causes the
        application to write the generated documented to __stdout__\.

        If the *output* does not exist then \[file dirname $output\] has to
        exist and must be a writable directory\.

      * path *inputfile* \(in\)

        This argument specifies the path to the file to process\. It has to
        exist, must be readable, and written in
        *[docstrip](\.\./\.\./\.\./index\.md\#docstrip)* format\.

  - <a name='2'></a>__tcldocstrip__ ?options? *output* \(?options? *input* *guards*\)\.\.\.

    This is the form for use case \[2\]\. It differs from the form for use case \[1\]
    by the possibility of having options before the output file, which apply in
    general, and specifying more than one inputfile, each with its own set of
    input specific options and guards\.

    It extracts data from the various *input* files, according to the
    specified *options* and *guards*, and writes the result to the given
    *output*, in the order of their specification on the command line\. Options
    specified before the output are global settings, whereas the options
    specified before each input are valid only just for this input file\.
    Unspecified values are taken from the global settings, or defaults\. As for
    form \[1\] using the string __\-__ as output causes the application to
    write to stdout\. Using the string __\.__ for an input file signals that
    the last input file should be used again\. This enables the assembly of the
    output from one input file using multiple and different sets of guards,
    without having to specify the full name of the file every time\.

  - <a name='3'></a>__tcldocstrip__ __\-guards__ *input*

    This is the form for use case \[3\]\. It determines the guards, and unique
    guard expressions used within the provided *input* document\. The found
    strings are written to stdout, one string per line\.

## <a name='subsection3'></a>OPTIONS

This section describes all the options available to the user of the application,
with the exception of the option __\-guards__\. This option was described
already, in section [COMMAND LINE](#subsection2)\.

  - __\-metaprefix__ string

    This option is inherited from the command __docstrip::extract__ provided
    by the package __[docstrip](\.\./modules/docstrip/docstrip\.md)__\.

    It specifies the string by which the '%%' prefix of a metacomment line will
    be replaced\. Defaults to '%%'\. For Tcl code this would typically be '\#'\.

  - __\-onerror__ mode

    This option is inherited from the command __docstrip::extract__ provided
    by the package __[docstrip](\.\./modules/docstrip/docstrip\.md)__\.

    It controls what will be done when a format error in the *text* being
    processed is detected\. The settings are:

      * __ignore__

        Just ignore the error; continue as if nothing happened\.

      * __puts__

        Write an error message to __stderr__, then continue processing\.

      * __throw__

        Throw an error\. __::errorCode__ is set to a list whose first element
        is __DOCSTRIP__, second element is the type of error, and third
        element is the line number where the error is detected\. This is the
        default\.

  - __\-trimlines__ bool

    This option is inherited from the command __docstrip::extract__ provided
    by the package __[docstrip](\.\./modules/docstrip/docstrip\.md)__\.

    Controls whether *spaces* at the end of a line should be trimmed away
    before the line is processed\. Defaults to __true__\.

  - __\-preamble__ text

  - __\-postamble__ text

  - __\-nopreamble__

  - __\-nopostamble__

    The \-no\*amble options deactivate file pre\- and postambles altogether,
    whereas the \-\*amble options specify the *user* part of the file pre\- and
    postambles\. This part can be empty, in that case only the standard parts are
    shown\. This is the default\.

    Preambles, when active, are written before the actual content of a generated
    file\. In the same manner postambles are, when active, written after the
    actual content of a generated file\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *docstrip* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[docstrip](\.\./modules/docstrip/docstrip\.md)

# <a name='keywords'></a>KEYWORDS

[\.dtx](\.\./\.\./\.\./index\.md\#\_dtx), [LaTeX](\.\./\.\./\.\./index\.md\#latex),
[conversion](\.\./\.\./\.\./index\.md\#conversion),
[docstrip](\.\./\.\./\.\./index\.md\#docstrip),
[documentation](\.\./\.\./\.\./index\.md\#documentation), [literate
programming](\.\./\.\./\.\./index\.md\#literate\_programming),
[markup](\.\./\.\./\.\./index\.md\#markup), [source](\.\./\.\./\.\./index\.md\#source)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
