
[//000000001]: # (page\_util\_norm\_lemon \- Parser generator tools)
[//000000002]: # (Generated from file 'page\_util\_norm\_lemon\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (page\_util\_norm\_lemon\(n\) 1\.0 tcllib "Parser generator tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

page\_util\_norm\_lemon \- page AST normalization, LEMON

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require page::util::norm\_lemon ?0\.1?  
package require snit  

[__::page::util::norm::lemon__ *tree*](#1)  

# <a name='description'></a>DESCRIPTION

This package provides a single utility command which takes an AST for a lemon
grammar and normalizes it in various ways\. The result is called a *Normalized
Lemon Grammar Tree*\.

*Note* that this package can only be used from within a plugin managed by the
package __page::pluginmgr__\.

# <a name='section2'></a>API

  - <a name='1'></a>__::page::util::norm::lemon__ *tree*

    This command assumes the *tree* object contains for a lemon grammar\. It
    normalizes this tree in place\. The result is called a *Normalized Lemon
    Grammar Tree*\.

    The exact operations performed are left undocumented for the moment\.

# <a name='section3'></a>Bugs, Ideas, Feedback

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

[graph walking](\.\./\.\./\.\./\.\./index\.md\#graph\_walking),
[lemon](\.\./\.\./\.\./\.\./index\.md\#lemon),
[normalization](\.\./\.\./\.\./\.\./index\.md\#normalization),
[page](\.\./\.\./\.\./\.\./index\.md\#page), [parser
generator](\.\./\.\./\.\./\.\./index\.md\#parser\_generator), [text
processing](\.\./\.\./\.\./\.\./index\.md\#text\_processing), [tree
walking](\.\./\.\./\.\./\.\./index\.md\#tree\_walking)

# <a name='category'></a>CATEGORY

Page Parser Generator

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
