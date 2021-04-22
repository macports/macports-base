
[//000000001]: # (base32::hex \- Base32 encoding)
[//000000002]: # (Generated from file 'base32hex\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Public domain)
[//000000004]: # (base32::hex\(n\) 0\.1 tcllib "Base32 encoding")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

base32::hex \- base32 extended hex encoding

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
package require base32::hex ?0\.1?  

[__::base32::hex::encode__ *string*](#1)  
[__::base32::hex::decode__ *estring*](#2)  

# <a name='description'></a>DESCRIPTION

This package provides commands for encoding and decoding of strings into and out
of the extended hex base32 encoding as specified in the RFC 3548bis draft\.

# <a name='section2'></a>API

  - <a name='1'></a>__::base32::hex::encode__ *string*

    This command encodes the given *string* in extended hex base32 and returns
    the encoded string as its result\. The result may be padded with the
    character __=__ to signal a partial encoding at the end of the input
    string\.

  - <a name='2'></a>__::base32::hex::decode__ *estring*

    This commands takes the *estring* and decodes it under the assumption that
    it is a valid extended hex base32 encoded string\. The result of the decoding
    is returned as the result of the command\.

    Note that while the encoder will generate only uppercase characters this
    decoder accepts input in lowercase as well\.

    The command will always throw an error whenever encountering conditions
    which signal some type of bogus input, namely if

      1. the input contains characters which are not valid output of a extended
         hex base32 encoder,

      1. the length of the input is not a multiple of eight,

      1. padding appears not at the end of input, but in the middle,

      1. the padding has not of length six, four, three, or one characters,

# <a name='section3'></a>Code map

The code map used to convert 5\-bit sequences is shown below, with the numeric id
of the bit sequences to the left and the character used to encode it to the
right\. The important feature of the extended hex mapping is that the first 16
codes map to the digits and hex characters\.

    0 0    9 9        18 I   27 R
    1 1   10 A        19 J   28 S
    2 2   11 B        20 K   29 T
    3 3   12 C        21 L   30 U
    4 4   13 D        22 M   31 V
    5 5   14 E        23 N
    6 6   15 F        24 O
    7 7        16 G   25 P
    8 8        17 H   26 Q

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

[base32](\.\./\.\./\.\./\.\./index\.md\#base32), [hex](\.\./\.\./\.\./\.\./index\.md\#hex),
[rfc3548](\.\./\.\./\.\./\.\./index\.md\#rfc3548)

# <a name='category'></a>CATEGORY

Text processing

# <a name='copyright'></a>COPYRIGHT

Public domain
