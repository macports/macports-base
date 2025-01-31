
[//000000001]: # (mpexpand \- Documentation toolbox)
[//000000002]: # (Generated from file 'mpexpand\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (Copyright &copy; 2003 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000005]: # (mpexpand\(n\) 1\.0 tcllib "Documentation toolbox")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

mpexpand \- Markup processor

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [NOTES](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

[__mpexpand__ ?\-module *module*? *format* *infile*&#124;\- *outfile*&#124;\-](#1)  
[__mpexpand\.all__ ?*\-verbose*? ?*module*?](#2)  

# <a name='description'></a>DESCRIPTION

This manpage describes a processor / converter for manpages in the doctools
format as specified in __doctools\_fmt__\. The processor is based upon the
package __[doctools](doctools\.md)__\.

  - <a name='1'></a>__mpexpand__ ?\-module *module*? *format* *infile*&#124;\- *outfile*&#124;\-

    The processor takes three arguments, namely the code describing which
    formatting to generate as the output, the file to read the markup from, and
    the file to write the generated output into\. If the *infile* is
    "__\-__" the processor will read from __stdin__\. If *outfile* is
    "__\-__" the processor will write to __stdout__\.

    If the option *\-module* is present its value overrides the internal
    definition of the module name\.

    The currently known output formats are

      * __nroff__

        The processor generates \*roff output, the standard format for unix
        manpages\.

      * __html__

        The processor generates HTML output, for usage in and display by web
        browsers\.

      * __tmml__

        The processor generates TMML output, the Tcl Manpage Markup Language, a
        derivative of XML\.

      * __latex__

        The processor generates LaTeX output\.

      * __wiki__

        The processor generates Wiki markup as understood by __wikit__\.

      * __list__

        The processor extracts the information provided by
        __manpage\_begin__\.

      * __null__

        The processor does not generate any output\.

  - <a name='2'></a>__mpexpand\.all__ ?*\-verbose*? ?*module*?

    This command uses __mpexpand__ to generate all possible output formats
    for all manpages in the current directory\. The manpages are recognized
    through the extension "\.man"\. If *\-verbose* is specified the command will
    list its actions before executing them\.

    The *module* information is passed to __mpexpand__\.

# <a name='section2'></a>NOTES

Possible future formats are plain text, pdf and postscript\.

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

expander\(n\), format\(n\), formatter\(n\)

# <a name='keywords'></a>KEYWORDS

[HTML](\.\./\.\./\.\./\.\./index\.md\#html), [TMML](\.\./\.\./\.\./\.\./index\.md\#tmml),
[conversion](\.\./\.\./\.\./\.\./index\.md\#conversion),
[manpage](\.\./\.\./\.\./\.\./index\.md\#manpage),
[markup](\.\./\.\./\.\./\.\./index\.md\#markup),
[nroff](\.\./\.\./\.\./\.\./index\.md\#nroff)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>  
Copyright &copy; 2003 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
