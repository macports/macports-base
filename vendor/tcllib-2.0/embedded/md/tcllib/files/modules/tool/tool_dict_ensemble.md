
[//000000001]: # (tool::dict\_ensemble \- Standardized OO Framework for development)
[//000000002]: # (Generated from file 'tool\_dict\_ensemble\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2015 Sean Woods <yoda@etoyoc\.com>)
[//000000004]: # (tool::dict\_ensemble\(n\) 0\.4\.2 tcllib "Standardized OO Framework for development")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

tool::dict\_ensemble \- Dictionary Tools

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [AUTHORS](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require tool ?0\.4\.2?  

[*object* *ensemble* __add__ *field*](#1)  

# <a name='description'></a>DESCRIPTION

The __dict\_ensemble__ command is a keyword added by
__[tool](tool\.md)__\. It defines a public variable \(stored as a dict\),
and an access function to manipulated and access the values stored in that dict\.

  - <a name='1'></a>*object* *ensemble* __add__ *field*

    \] *value* *value \.\.\.*\] Adds elements to a list maintained with the
    *field* leaf of the dict maintained my this ensemble\. Declares a variable
    *name* which will be initialized as an array, populated with *contents*
    for objects of this class, as well as any objects for classes which are
    descendents of this class\.

# <a name='section2'></a>AUTHORS

Sean Woods

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *tool* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[TOOL](\.\./\.\./\.\./\.\./index\.md\#tool), [TclOO](\.\./\.\./\.\./\.\./index\.md\#tcloo)

# <a name='category'></a>CATEGORY

Utility

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2015 Sean Woods <yoda@etoyoc\.com>
