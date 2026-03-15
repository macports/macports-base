
[//000000001]: # (file::home \- Forward compatibility implementation of \[file home\])
[//000000002]: # (Generated from file 'tcllib\_fhome\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2024 Andreas Kupries, BSD licensed)
[//000000004]: # (file::home\(n\) 1 tcllib "Forward compatibility implementation of \[file home\]")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

file::home \- file home \- Return home directory of current or other user

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.x  
package require fhome ?1?  

[__[file](\.\./\.\./\.\./\.\./index\.md\#file)__ __home__ ?*user*?](#1)  

# <a name='description'></a>DESCRIPTION

This package provides a forward\-compatibility implementation of Tcl 9's __file
home__ command \(TIP 602\), for Tcl 8\.x\.

  - <a name='1'></a>__[file](\.\./\.\./\.\./\.\./index\.md\#file)__ __home__ ?*user*?

    Without argument, return the home directory of the current user\.

    With argument, return the home directory of the specified *user*\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *file* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='category'></a>CATEGORY

Utility

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2024 Andreas Kupries, BSD licensed
