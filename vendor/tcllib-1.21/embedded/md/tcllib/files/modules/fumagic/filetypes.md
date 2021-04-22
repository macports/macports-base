
[//000000001]: # (fileutil::magic::filetype \- file utilities)
[//000000002]: # (Generated from file 'filetypes\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (fileutil::magic::filetype\(n\) 2\.0 tcllib "file utilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

fileutil::magic::filetype \- Procedures implementing file\-type recognition

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [REFERENCES](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require fileutil::magic::filetype ?2\.0?  

[__::fileutil::magic::filetype__ *filename*](#1)  

# <a name='description'></a>DESCRIPTION

This package provides a command for the recognition of file types in pure Tcl\.

The core part of the recognizer was generated from a "magic\(5\)" file containing
the checks to perform to recognize files, and associated file\-types\.

*Beware\!* This recognizer is large, about 752 Kilobyte of generated Tcl code\.

  - <a name='1'></a>__::fileutil::magic::filetype__ *filename*

    This command is similar to the command __fileutil::fileType__\.

    Returns a list containing a list of descriptions, a list of mimetype
    components, and a list file extensions\. Returns an empty string if the file
    content is not recognized\.

# <a name='section2'></a>REFERENCES

  1. [File\(1\) sources](ftp://ftp\.astron\.com/pub/file/) This site contains
     the current sources for the file command, including the magic definitions
     used by it\. The latter were used by us to generate this recognizer\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *fileutil :: magic* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

file\(1\), [fileutil](\.\./fileutil/fileutil\.md), magic\(5\)

# <a name='keywords'></a>KEYWORDS

[file recognition](\.\./\.\./\.\./\.\./index\.md\#file\_recognition), [file
type](\.\./\.\./\.\./\.\./index\.md\#file\_type), [file
utilities](\.\./\.\./\.\./\.\./index\.md\#file\_utilities),
[type](\.\./\.\./\.\./\.\./index\.md\#type)

# <a name='category'></a>CATEGORY

Programming tools
