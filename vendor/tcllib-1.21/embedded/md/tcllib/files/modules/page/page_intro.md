
[//000000001]: # (page\_intro \- Parser generator tools)
[//000000002]: # (Generated from file 'page\_intro\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (page\_intro\(n\) 1\.0 tcllib "Parser generator tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

page\_intro \- page introduction

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

*[page](\.\./\.\./\.\./\.\./index\.md\#page)* \(short for *parser generator*\)
stands for a set of related packages which help in the construction of parser
generators, and other utilities doing text processing\.

They are mainly geared towards supporting the Tcllib application
__[page](\.\./\.\./apps/page\.md)__, with the package __page::pluginmgr__
in a central role as the plugin management for the application\. The other
packages are performing low\-level text processing and utility tasks geared
towards parser generation and mainly accessed by
__[page](\.\./\.\./apps/page\.md)__ through plugins\.

The packages implementing the plugins are not documented as regular packages, as
they cannot be loaded into a general interpreter, like tclsh, without extensive
preparation of the interpreter\. Preparation which is done for them by the plugin
manager\.

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

# <a name='keywords'></a>KEYWORDS

[page](\.\./\.\./\.\./\.\./index\.md\#page), [parser
generator](\.\./\.\./\.\./\.\./index\.md\#parser\_generator), [text
processing](\.\./\.\./\.\./\.\./index\.md\#text\_processing)

# <a name='category'></a>CATEGORY

Page Parser Generator

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
