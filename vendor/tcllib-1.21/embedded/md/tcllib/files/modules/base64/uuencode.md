
[//000000001]: # (uuencode \- Text encoding & decoding binary data)
[//000000002]: # (Generated from file 'uuencode\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002, Pat Thoyts)
[//000000004]: # (uuencode\(n\) 1\.1\.4 tcllib "Text encoding & decoding binary data")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

uuencode \- UU\-encode/decode binary data

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [OPTIONS](#section2)

  - [EXAMPLES](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8  
package require uuencode ?1\.1\.4?  

[__::uuencode::encode__ *string*](#1)  
[__::uuencode::decode__ *string*](#2)  
[__::uuencode::uuencode__ ?__\-name__ *string*? ?__\-mode__ *octal*? \(__\-file__ *filename* &#124; ?__\-\-__? *string*\)](#3)  
[__::uuencode::uudecode__ \(__\-file__ *filename* &#124; ?__\-\-__? *string*\)](#4)  

# <a name='description'></a>DESCRIPTION

This package provides a Tcl\-only implementation of the __uuencode\(1\)__ and
__uudecode\(1\)__ commands\. This encoding packs binary data into printable
ASCII characters\.

  - <a name='1'></a>__::uuencode::encode__ *string*

    returns the uuencoded data\. This will encode all the data passed in even if
    this is longer than the uuencode maximum line length\. If the number of input
    bytes is not a multiple of 3 then additional 0 bytes are added to pad the
    string\.

  - <a name='2'></a>__::uuencode::decode__ *string*

    Decodes the given encoded data\. This will return any padding characters as
    well and it is the callers responsibility to deal with handling the actual
    length of the encoded data\. \(see uuencode\)\.

  - <a name='3'></a>__::uuencode::uuencode__ ?__\-name__ *string*? ?__\-mode__ *octal*? \(__\-file__ *filename* &#124; ?__\-\-__? *string*\)

  - <a name='4'></a>__::uuencode::uudecode__ \(__\-file__ *filename* &#124; ?__\-\-__? *string*\)

    UUDecode a file or block of data\. A file may contain more than one embedded
    file so the result is a list where each element is a three element list of
    filename, mode value and data\.

# <a name='section2'></a>OPTIONS

  - \-filename name

    Cause the uuencode or uudecode commands to read their data from the named
    file rather that taking a string parameter\.

  - \-name string

    The uuencoded data header line contains the suggested file name to be used
    when unpacking the data\. Use this option to change this from the default of
    "data\.dat"\.

  - \-mode octal

    The uuencoded data header line contains a suggested permissions bit pattern
    expressed as an octal string\. To change the default of 0644 you can set this
    option\. For instance, 0755 would be suitable for an executable\. See
    __chmod\(1\)__\.

# <a name='section3'></a>EXAMPLES

    % set d [uuencode::encode "Hello World!"]
    2&5L;&\\@5V]R;&0A

    % uuencode::uudecode $d
    Hello World!

    % set d [uuencode::uuencode -name hello.txt "Hello World"]
    begin 644 hello.txt
    +2&5L;&\@5V]R;&0`
    `
    end

    % uuencode::uudecode $d
    {hello.txt 644 {Hello World}}

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
[uuencode](\.\./\.\./\.\./\.\./index\.md\#uuencode)

# <a name='category'></a>CATEGORY

Text processing

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002, Pat Thoyts
