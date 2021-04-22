
[//000000001]: # (yencode \- Text encoding & decoding binary data)
[//000000002]: # (Generated from file 'yencode\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002, Pat Thoyts)
[//000000004]: # (yencode\(n\) 1\.1\.2 tcllib "Text encoding & decoding binary data")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

yencode \- Y\-encode/decode binary data

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [OPTIONS](#section2)

  - [References](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require yencode ?1\.1\.2?  

[__::yencode::encode__ *string*](#1)  
[__::yencode::decode__ *string*](#2)  
[__::yencode::yencode__ ?__\-name__ *string*? ?__\-line__ *integer*? ?__\-crc32__ *boolean*? \(__\-file__ *filename* &#124; ?__\-\-__? *string*\)](#3)  
[__::yencode::ydecode__ \(__\-file__ *filename* &#124; ?__\-\-__? *string*\)](#4)  

# <a name='description'></a>DESCRIPTION

This package provides a Tcl\-only implementation of the yEnc file encoding\. This
is a recently introduced method of encoding binary files for transmission
through Usenet\. This encoding packs binary data into a format that requires an
8\-bit clean transmission layer but that escapes characters special to the
*[NNTP](\.\./\.\./\.\./\.\./index\.md\#nntp)* posting protocols\. See
[http://www\.yenc\.org/](http://www\.yenc\.org/) for details concerning the
algorithm\.

  - <a name='1'></a>__::yencode::encode__ *string*

    returns the yEnc encoded data\.

  - <a name='2'></a>__::yencode::decode__ *string*

    Decodes the given yEnc encoded data\.

  - <a name='3'></a>__::yencode::yencode__ ?__\-name__ *string*? ?__\-line__ *integer*? ?__\-crc32__ *boolean*? \(__\-file__ *filename* &#124; ?__\-\-__? *string*\)

    Encode a file or block of data\.

  - <a name='4'></a>__::yencode::ydecode__ \(__\-file__ *filename* &#124; ?__\-\-__? *string*\)

    Decode a file or block of data\. A file may contain more than one embedded
    file so the result is a list where each element is a three element list of
    filename, file size and data\.

# <a name='section2'></a>OPTIONS

  - \-filename name

    Cause the yencode or ydecode commands to read their data from the named file
    rather that taking a string parameter\.

  - \-name string

    The encoded data header line contains the suggested file name to be used
    when unpacking the data\. Use this option to change this from the default of
    "data\.dat"\.

  - \-line integer

    The yencoded data header line contains records the line length used during
    the encoding\. Use this option to select a line length other that the default
    of 128\. Note that NNTP imposes a 1000 character line length limit and some
    gateways may have trouble with more than 255 characters per line\.

  - \-crc32 boolean

    The yEnc specification recommends the inclusion of a cyclic redundancy check
    value in the footer\. Use this option to change the default from *true* to
    *false*\.

    % set d [yencode::yencode -file testfile.txt]
    =ybegin line=128 size=584 name=testfile.txt
     -o- data not shown -o-
    =yend size=584 crc32=ded29f4f

# <a name='section3'></a>References

  1. [http://www\.yenc\.org/yenc\-draft\.1\.3\.txt](http://www\.yenc\.org/yenc\-draft\.1\.3\.txt)

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *base64* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[encoding](\.\./\.\./\.\./\.\./index\.md\#encoding),
[yEnc](\.\./\.\./\.\./\.\./index\.md\#yenc),
[ydecode](\.\./\.\./\.\./\.\./index\.md\#ydecode),
[yencode](\.\./\.\./\.\./\.\./index\.md\#yencode)

# <a name='category'></a>CATEGORY

Text processing

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002, Pat Thoyts
