
[//000000001]: # (mkdoc \- Source code documentation using Markdown)
[//000000002]: # (Generated from file 'mkdoc\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2019\-2022, Detlef Groth <detlef\(at\)dgroth\(dot\)de>)
[//000000004]: # (mkdoc\(n\) 0\.7\.0 tcllib "Source code documentation using Markdown")

<hr> [ <a href="../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../toc.md">Table Of Contents</a> &#124; <a
href="../../../index.md">Keyword Index</a> &#124; <a
href="../../../toc0.md">Categories</a> &#124; <a
href="../../../toc1.md">Modules</a> &#124; <a
href="../../../toc2.md">Applications</a> ] <hr>

# NAME

mkdoc \- Source code documentation extractor/converter application

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Command Line](#section2)

  - [Examples](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Code Copyright](#section5)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

[__[mkdoc](\.\./modules/mkdoc/mkdoc\.md)__ __\-\-help__](#1)  
[__[mkdoc](\.\./modules/mkdoc/mkdoc\.md)__ __\-\-version__](#2)  
[__[mkdoc](\.\./modules/mkdoc/mkdoc\.md)__ __\-\-license__](#3)  
[__[mkdoc](\.\./modules/mkdoc/mkdoc\.md)__ *input* *output* ?__\-\-css__ *cssfile*?](#4)  

# <a name='description'></a>DESCRIPTION

This document describes __[mkdoc](\.\./modules/mkdoc/mkdoc\.md)__, an
application to extract documentation embedded in source code files, be they
"\.tcl", or other\.

# <a name='section2'></a>Command Line

  - <a name='1'></a>__[mkdoc](\.\./modules/mkdoc/mkdoc\.md)__ __\-\-help__

    The application prints a short help to standard output and exits\.

  - <a name='2'></a>__[mkdoc](\.\./modules/mkdoc/mkdoc\.md)__ __\-\-version__

    The application prints its version number to standard output and exits\.

  - <a name='3'></a>__[mkdoc](\.\./modules/mkdoc/mkdoc\.md)__ __\-\-license__

    The application prints its license to standard output and exits\.

  - <a name='4'></a>__[mkdoc](\.\./modules/mkdoc/mkdoc\.md)__ *input* *output* ?__\-\-css__ *cssfile*?

    The application reads the *input* file, extracts the embedded
    documentation, and writes it to the *output* file\.

    If the output file is not a "\.md" file the extracted documentation is
    converted to HTML before being written\.

    When generating and writing HTML the default CSS stylesheet can be
    overridden by specifying the path to a custom stylesheet via option
    __\-\-css__\.

    If the input file is a "\.md" file it is expected to contain Markdown as\-is,
    instead of Markdown embedded into code\.

    On the other side, when the file is considered code then the documentation
    is expected to be contained in all lines starting with the marker
    __\#'__\. For script languages like Tcl the __\#__ character of this
    marker means that the documentation is contained in the so\-flagged comments\.
    For other languages the marker and documentation may have to be embedded
    into multi\-line comments\.

# <a name='section3'></a>Examples

    # Create HTML manual for a CPP file using a custom style sheet
    mkdoc sample.cpp sample.html --css manual.css

    # Extract the documentation from code as simple Markdown, ready to be processed
    # further, for example with pandoc, or similar
    mkdoc sample.cpp sample.md

    # Convert a Markdown file to HTML
    mkdoc sample.md sample.html

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such to the author of this package\. Please also
report any ideas for enhancements you may have for either package and/or
documentation\.

# <a name='section5'></a>Code Copyright

BSD License type:

The following terms apply to all files a ssociated with the software unless
explicitly disclaimed in individual files\.

The authors hereby grant permission to use, copy, modify, distribute, and
license this software and its documentation for any purpose, provided that
existing copyright notices are retained in all copies and that this notice is
included verbatim in any distributions\. No written agreement, license, or
royalty fee is required for any of the authorized uses\. Modifications to this
software may be copyrighted by their authors and need not follow the licensing
terms described here, provided that the new terms are clearly indicated on the
first page of each file where they apply\.

In no event shall the authors or distributors be liable to any party for direct,
indirect, special, incidental, or consequential damages arising out of the use
of this software, its documentation, or any derivatives thereof, even if the
authors have been advised of the possibility of such damage\.

The authors and distributors specifically disclaim any warranties, including,
but not limited to, the implied warranties of merchantability, fitness for a
particular purpose, and non\-infringement\. This software is provided on an "as
is" basis, and the authors and distributors have no obligation to provide
maintenance, support, updates, enhancements, or modifications\.

*RESTRICTED RIGHTS*: Use, duplication or disclosure by the government is
subject to the restrictions as set forth in subparagraph \(c\) \(1\) \(ii\) of the
Rights in Technical Data and Computer Software Clause as DFARS 252\.227\-7013 and
FAR 52\.227\-19\.

# <a name='category'></a>CATEGORY

Text processing

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2019\-2022, Detlef Groth <detlef\(at\)dgroth\(dot\)de>
