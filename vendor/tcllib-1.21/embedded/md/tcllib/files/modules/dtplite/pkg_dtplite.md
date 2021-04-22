
[//000000001]: # (pkg\_dtplite \- Documentation toolbox)
[//000000002]: # (Generated from file 'pkg\_dtplite\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004\-2013 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pkg\_dtplite\(n\) 1\.3\.1 tcllib "Documentation toolbox")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pkg\_dtplite \- Lightweight DocTools Markup Processor

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require dtplite ?1\.3\.1?  

[__dtplite::print\-via__ *cmd*](#1)  
[__dtplite::do__ *arguments*](#2)  

# <a name='description'></a>DESCRIPTION

The package provided by this document,
__[dtplite](\.\./\.\./apps/dtplite\.md)__, is the foundation for the
__[dtplite](\.\./\.\./apps/dtplite\.md)__ application\. It is a light wrapper
around the various __[doctools](\.\./doctools/doctools\.md)__ packages\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__dtplite::print\-via__ *cmd*

    Redirect print operations of the package to the specified *cmd*\.

    The result of the command is the empty string\.

  - <a name='2'></a>__dtplite::do__ *arguments*

    The main command it takes a *single list* of *arguments*, processes
    them, and performs the specified action\.

    The result of the command is the empty string\.

    The details of the syntax inside of the *arguments* list are explained in
    section *COMMAND LINE* of the documentation for the
    __[dtplite](\.\./\.\./apps/dtplite\.md)__ application\.

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

[docidx introduction](\.\./doctools/docidx\_intro\.md), [doctoc
introduction](\.\./doctools/doctoc\_intro\.md), [doctools
introduction](\.\./doctools/doctools\_intro\.md)

# <a name='keywords'></a>KEYWORDS

[HTML](\.\./\.\./\.\./\.\./index\.md\#html), [TMML](\.\./\.\./\.\./\.\./index\.md\#tmml),
[conversion](\.\./\.\./\.\./\.\./index\.md\#conversion),
[docidx](\.\./\.\./\.\./\.\./index\.md\#docidx),
[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc),
[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools),
[manpage](\.\./\.\./\.\./\.\./index\.md\#manpage),
[markup](\.\./\.\./\.\./\.\./index\.md\#markup),
[nroff](\.\./\.\./\.\./\.\./index\.md\#nroff)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004\-2013 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
