
[//000000001]: # (ascii85 \- Text encoding & decoding binary data)
[//000000002]: # (Generated from file 'ascii85\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2010, Emiliano Gavilán)
[//000000004]: # (ascii85\(n\) 1\.0 tcllib "Text encoding & decoding binary data")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

ascii85 \- ascii85\-encode/decode binary data

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [EXAMPLES](#section2)

  - [References](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require ascii85 ?1\.0?  

[__::ascii85::encode__ ?__\-maxlen__ *maxlen*? ?__\-wrapchar__ *wrapchar*? *string*](#1)  
[__::ascii85::decode__ *string*](#2)  

# <a name='description'></a>DESCRIPTION

This package provides procedures to encode binary data into ascii85 and back\.

  - <a name='1'></a>__::ascii85::encode__ ?__\-maxlen__ *maxlen*? ?__\-wrapchar__ *wrapchar*? *string*

    Ascii85 encodes the given binary *string* and returns the encoded result\.
    Inserts the character *wrapchar* every *maxlen* characters of output\.
    *wrapchar* defaults to newline\. *maxlen* defaults to __76__\.

    *Note well*: If your string is not simple ascii you should fix the string
    encoding before doing ascii85 encoding\. See the examples\.

    The command will throw an error for negative values of *maxlen*, or if
    *maxlen* is not an integer number\.

  - <a name='2'></a>__::ascii85::decode__ *string*

    Ascii85 decodes the given *string* and returns the binary data\. The
    decoder ignores whitespace in the string, as well as tabs and newlines\.

# <a name='section2'></a>EXAMPLES

    % ascii85::encode "Hello, world"
    87cURD_*#TDfTZ)

    % ascii85::encode [string repeat xyz 24]
    G^4U[H$X^\H?a^]G^4U[H$X^\H?a^]G^4U[H$X^\H?a^]G^4U[H$X^\H?a^]G^4U[H$X^\H?a^]G
    ^4U[H$X^\H?a^]
    % ascii85::encode -wrapchar "" [string repeat xyz 24]
    G^4U[H$X^\H?a^]G^4U[H$X^\H?a^]G^4U[H$X^\H?a^]G^4U[H$X^\H?a^]G^4U[H$X^\H?a^]G^4U[H$X^\H?a^]

    # NOTE: ascii85 encodes BINARY strings.
    % set chemical [encoding convertto utf-8 "C\u2088H\u2081\u2080N\u2084O\u2082"]
    % set encoded [ascii85::encode $chemical]
    6fN]R8E,5Pidu\UiduhZidua
    % set caffeine [encoding convertfrom utf-8 [ascii85::decode $encoded]]

# <a name='section3'></a>References

  1. [http://en\.wikipedia\.org/wiki/Ascii85](http://en\.wikipedia\.org/wiki/Ascii85)

  1. Postscript Language Reference Manual, 3rd Edition, page 131\.
     [http://www\.adobe\.com/devnet/postscript/pdfs/PLRM\.pdf](http://www\.adobe\.com/devnet/postscript/pdfs/PLRM\.pdf)

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

[ascii85](\.\./\.\./\.\./\.\./index\.md\#ascii85),
[encoding](\.\./\.\./\.\./\.\./index\.md\#encoding)

# <a name='category'></a>CATEGORY

Text processing

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2010, Emiliano Gavilán
