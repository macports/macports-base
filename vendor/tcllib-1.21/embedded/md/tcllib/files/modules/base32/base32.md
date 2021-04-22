
[//000000001]: # (base32 \- Base32 encoding)
[//000000002]: # (Generated from file 'base32\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Public domain)
[//000000004]: # (base32\(n\) 0\.1 tcllib "Base32 encoding")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

base32 \- base32 standard encoding

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Code map](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require base32::core ?0\.1?  
package require base32 ?0\.1?  

[__::base32::encode__ *string*](#1)  
[__::base32::decode__ *estring*](#2)  

# <a name='description'></a>DESCRIPTION

This package provides commands for encoding and decoding of strings into and out
of the standard base32 encoding as specified in RFC 3548\.

# <a name='section2'></a>API

  - <a name='1'></a>__::base32::encode__ *string*

    This command encodes the given *string* in base32 and returns the encoded
    string as its result\. The result may be padded with the character __=__
    to signal a partial encoding at the end of the input string\.

  - <a name='2'></a>__::base32::decode__ *estring*

    This commands takes the *estring* and decodes it under the assumption that
    it is a valid base32 encoded string\. The result of the decoding is returned
    as the result of the command\.

    Note that while the encoder will generate only uppercase characters this
    decoder accepts input in lowercase as well\.

    The command will always throw an error whenever encountering conditions
    which signal some type of bogus input, namely if

      1. the input contains characters which are not valid output of a base32
         encoder,

      1. the length of the input is not a multiple of eight,

      1. padding appears not at the end of input, but in the middle,

      1. the padding has not of length six, four, three, or one characters,

# <a name='section3'></a>Code map

The code map used to convert 5\-bit sequences is shown below, with the numeric id
of the bit sequences to the left and the character used to encode it to the
right\. It should be noted that the characters "0" and "1" are not used by the
encoding\. This is done as these characters can be easily confused with "O", "o"
and "l" \(L\)\.

    0 A    9 J   18 S   27 3
    1 B   10 K   19 T   28 4
    2 C   11 L   20 U   29 5
    3 D   12 M   21 V   30 6
    4 E   13 N   22 W   31 7
    5 F   14 O   23 X
    6 G   15 P   24 Y
    7 H   16 Q   25 Z
    8 I   17 R   26 2

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *base32* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[base32](\.\./\.\./\.\./\.\./index\.md\#base32),
[rfc3548](\.\./\.\./\.\./\.\./index\.md\#rfc3548)

# <a name='category'></a>CATEGORY

Text processing

# <a name='copyright'></a>COPYRIGHT

Public domain
