
[//000000001]: # (mkdoc \- Source code documentation using Markdown)
[//000000002]: # (Generated from file 'mkdoc\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2019\-2022, Detlef Groth <detlef\(at\)dgroth\(dot\)de>)
[//000000004]: # (mkdoc\(n\) 0\.7\.0 tcllib "Source code documentation using Markdown")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

mkdoc \- Extracts and optionally converts Markdown comments in source code to
HTML

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Examples](#section2)

  - [Formatting](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Code Copyright](#section5)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require Markdown ?1\.2\.1?  
package require yaml ?0\.4\.1?  
package require mkdoc ?0\.7\.0?  
package require hook  

[__::mkdoc::mkdoc__ *infile* *outfile* ?__\-css__ *cssfile*?](#1)  
[__::mkdoc::run__ *infile*](#2)  

# <a name='description'></a>DESCRIPTION

The package __mkdoc__ provides a command to extract documentation embedded
in code and optionally convert these comments into HTML\. The latter uses
Tcllib's __[Markdown](\.\./markdown/markdown\.md)__ package\. Each line of
the embedded documentation begins with the special comment marker __\#'__\.

  - <a name='1'></a>__::mkdoc::mkdoc__ *infile* *outfile* ?__\-css__ *cssfile*?

    The command reads the specified *infile* and extracts the code comments
    introduced by the __\#'__ marker\. If the *outfile* is either a "\.html"
    or "\.htm" file the Markdown is converted into HTML using either a default
    style or the specified style sheet *cssfile*\.

    All arguments are paths to the files to read from or write to\.

    The result of the command is the empty string\.

    See section [Formatting](#section3) for the supported Markdown syntax
    and extensions to it\.

  - <a name='2'></a>__::mkdoc::run__ *infile*

    The command reads the specified *infile*, extracts the embedded
    documentation, and then executes the contents of the first example, i\.e\.
    __\`\`\`__\-quoted block, found in the __Example__ section\.

    Here is such an example which will be executed by the Tcl interpreter

        #' ## <a name="example">Example</a>
        #'
        #' ```
        #' puts "Hello mkdoc package"
        #' puts "I am in the example section"
        #' ```

    *DANGER, BEWARE*\. Failing to open the *infile* causes the command to
    *exit* the entire process\.

    Use of this command in a general context is not recommended\.

# <a name='section2'></a>Examples

The example below demonstrates the conversion of the documentation embedded into
the file "mkdoc\.tcl" itself:

    package require mkdoc
    # extracting the Markdown
    mkdoc::mkdoc mkdoc.tcl mkdoc.md
    # converting Markdown to HTML
    mkdoc::mkdoc mkdoc.md mkdoc.html
    # direct conversion without intermediate file
    mkdoc::mkdoc mkdoc.tcl mkdoc.html

# <a name='section3'></a>Formatting

The package supports the syntax supported by Tcllib's
__[Markdown](\.\./markdown/markdown\.md)__ package\.

It further supports a set of simple YAML headers whose information is inserted
into appropriate HTML __meta__\-tags\. The supported keys are

  - __author__

    Set the document author\. Defaults to __NN__\.

  - __title__

    Set the document title\. Defaults to __Documentation ____filename__\]\.

  - __date__

    Sets the document date\. Defaults to the current day\.

  - __css__

    Sets a custom CSS stylesheet\. Defaults to the internal mkdoc sheet\.

*Note* that in Markdown output mode these headers are simply passed through
into the result\. This is proper, as processors like __pandoc__ are able to
use them as well\.

See the example below for the syntax:

    #' ---
    #' title: mkdoc::mkdoc 0.7.0
    #' author: Detlef Groth, Schwielowsee, Germany
    #' date: 2022-04-17
    #' css: mini.css
    #' ---
    #'

Another extension over standard Markdown is the support of a single level of
includes\.

See the example below for the syntax:

    #' #include "path/to/include/file"

*Note*, the double\-quotes around the path are part of the syntax\.

*Beware* further that relative paths are resolved relative to the current
working directory, and *not* relative to the location of the including file\.

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
