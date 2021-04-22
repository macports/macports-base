
[//000000001]: # (textutil::patch \- Text and string utilities)
[//000000002]: # (Generated from file 'patch\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (textutil::patch\(n\) 0\.1 tcllib "Text and string utilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

textutil::patch \- Application of uni\-diff patches to directory trees

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require textutil::patch ?0\.1?  

[__::textutil::patch::apply__ *basedirectory* *striplevel* *patch* *reportcmd*](#1)  
[__\{\*\}reportcmd__ __apply__ *filename*](#2)  
[__\{\*\}reportcmd__ __fail__ *filename* *hunk* *expected* *seen*](#3)  
[__\{\*\}reportcmd__ __fail\-already__ *filename* *hunk*](#4)  

# <a name='description'></a>DESCRIPTION

This package provides a single command which applies a patch in [unified
format](https://www\.gnu\.org/software/diffutils/manual/html\_node/Detailed\-Unified\.html)
to a directory tree\.

  - <a name='1'></a>__::textutil::patch::apply__ *basedirectory* *striplevel* *patch* *reportcmd*

    Applies the *patch* \(text of the path, not file\) to the files in the
    *basedirectory* using the specified *striplevel*\. The result of the
    command is the empty string\.

    The *striplevel* argument is equivalent to option __\-p__ of the
    __[patch](\.\./\.\./\.\./\.\./index\.md\#patch)__ command\.

    Errors are thrown when the *patch* does not parse, and nothing is done to
    the files in *basedirectory*\.

    All activities during the application of the patch, including the inability
    to apply a hunk are reported through the command prefix *reportcmd*
    instead\. Files with problems are left unchanged\. Note however that this does
    *not prevent* changes to files with no problems, before and after the
    problematic file\(s\)\.

    The command prefix is called in 3 possible forms:

      * <a name='2'></a>__\{\*\}reportcmd__ __apply__ *filename*

        The caller begins operation on file *fname*, applying all hunks
        collected for said file\.

      * <a name='3'></a>__\{\*\}reportcmd__ __fail__ *filename* *hunk* *expected* *seen*

        Application of hunk number *hunk* of file *filename* has failed\. The
        command expected to find the text *expected*, and saw *seen*
        instead\.

      * <a name='4'></a>__\{\*\}reportcmd__ __fail\-already__ *filename* *hunk*

        Application of hunk number *hunk* of file *filename* has failed\. The
        command believes that this hunk has already been applied to the file\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *textutil* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[diff \-ruN](\.\./\.\./\.\./\.\./index\.md\#diff\_run), [diff, unified
format](\.\./\.\./\.\./\.\./index\.md\#diff\_unified\_format),
[fossil](\.\./\.\./\.\./\.\./index\.md\#fossil), [git](\.\./\.\./\.\./\.\./index\.md\#git),
[patch](\.\./\.\./\.\./\.\./index\.md\#patch), [unified format
diff](\.\./\.\./\.\./\.\./index\.md\#unified\_format\_diff)

# <a name='category'></a>CATEGORY

Text processing
