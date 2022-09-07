
[//000000001]: # (md4 \- MD4 Message\-Digest Algorithm)
[//000000002]: # (Generated from file 'md4\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2003, Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000004]: # (md4\(n\) 1\.0\.7 tcllib "MD4 Message\-Digest Algorithm")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

md4 \- MD4 Message\-Digest Algorithm

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [PROGRAMMING INTERFACE](#section3)

  - [EXAMPLES](#section4)

  - [REFERENCES](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require md4 ?1\.0\.7?  

[__::md4::md4__ ?*\-hex*? \[ *\-channel channel* &#124; *\-file filename* &#124; *string* \]](#1)  
[__::md4::hmac__ ?*\-hex*? *\-key key* \[ *\-channel channel* &#124; *\-file filename* &#124; *string* \]](#2)  
[__::md4::MD4Init__](#3)  
[__::md4::MD4Update__ *token* *data*](#4)  
[__::md4::MD4Final__ *token*](#5)  
[__::md4::HMACInit__ *key*](#6)  
[__::md4::HMACUpdate__ *token* *data*](#7)  
[__::md4::HMACFinal__ *token*](#8)  

# <a name='description'></a>DESCRIPTION

This package is an implementation in Tcl of the MD4 message\-digest algorithm as
described in RFC 1320 \(1\) and \(2\)\. This algorithm takes an arbitrary quantity of
data and generates a 128\-bit message digest from the input\. The MD4 algorithm is
faster but potentially weaker than the related MD5 algorithm \(3\)\.

If you have __critcl__ and have built the __tcllibc__ package then the
implementation of the hashing function will be performed by compiled code\.
Alternatively if __cryptkit__ is available this will be used\. If no
accelerator package can be found then the pure\-tcl implementation is used\. The
programming interface remains the same in all cases\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::md4::md4__ ?*\-hex*? \[ *\-channel channel* &#124; *\-file filename* &#124; *string* \]

    Calculate the MD4 digest of the data given in string\. This is returned as a
    binary string by default\. Giving the *\-hex* option will return a
    hexadecimal encoded version of the digest\.

    The data to be hashed can be specified either as a string argument to the
    md4 command, or as a filename or a pre\-opened channel\. If the *\-filename*
    argument is given then the file is opened, the data read and hashed and the
    file is closed\. If the *\-channel* argument is given then data is read from
    the channel until the end of file\. The channel is not closed\.

    Only one of *\-file*, *\-channel* or *string* should be given\.

  - <a name='2'></a>__::md4::hmac__ ?*\-hex*? *\-key key* \[ *\-channel channel* &#124; *\-file filename* &#124; *string* \]

    Calculate an Hashed Message Authentication digest \(HMAC\) using the MD4
    digest algorithm\. HMACs are described in RFC 2104 \(4\) and provide an MD4
    digest that includes a key\. All options other than *\-key* are as for the
    __::md4::md4__ command\.

# <a name='section3'></a>PROGRAMMING INTERFACE

For the programmer, the MD4 hash can be viewed as a bucket into which one pours
data\. When you have finished, you extract a value that is derived from the data
that was poured into the bucket\. The programming interface to the MD4 hash
operates on a token \(equivalent to the bucket\)\. You call __MD4Init__ to
obtain a token and then call __MD4Update__ as many times as required to add
data to the hash\. To release any resources and obtain the hash value, you then
call __MD4Final__\. An equivalent set of functions gives you a keyed digest
\(HMAC\)\.

  - <a name='3'></a>__::md4::MD4Init__

    Begins a new MD4 hash\. Returns a token ID that must be used for the
    remaining functions\.

  - <a name='4'></a>__::md4::MD4Update__ *token* *data*

    Add data to the hash identified by token\. Calling *MD4Update $token
    "abcd"* is equivalent to calling *MD4Update $token "ab"* followed by
    *MD4Update $token "cb"*\. See [EXAMPLES](#section4)\.

  - <a name='5'></a>__::md4::MD4Final__ *token*

    Returns the hash value and releases any resources held by this token\. Once
    this command completes the token will be invalid\. The result is a binary
    string of 16 bytes representing the 128 bit MD4 digest value\.

  - <a name='6'></a>__::md4::HMACInit__ *key*

    This is equivalent to the __::md4::MD4Init__ command except that it
    requires the key that will be included in the HMAC\.

  - <a name='7'></a>__::md4::HMACUpdate__ *token* *data*

  - <a name='8'></a>__::md4::HMACFinal__ *token*

    These commands are identical to the MD4 equivalent commands\.

# <a name='section4'></a>EXAMPLES

    % md4::md4 -hex "Tcl does MD4"
    858da9b31f57648a032230447bd15f25

    % md4::hmac -hex -key Sekret "Tcl does MD4"
    c324088e5752872689caedf2a0464758

    % set tok [md4::MD4Init]
    ::md4::1
    % md4::MD4Update $tok "Tcl "
    % md4::MD4Update $tok "does "
    % md4::MD4Update $tok "MD4"
    % md4::Hex [md4::MD4Final $tok]
    858da9b31f57648a032230447bd15f25

# <a name='section5'></a>REFERENCES

  1. Rivest, R\., "The MD4 Message Digest Algorithm", RFC 1320, MIT, April 1992\.
     \([http://www\.rfc\-editor\.org/rfc/rfc1320\.txt](http://www\.rfc\-editor\.org/rfc/rfc1320\.txt)\)

  1. Rivest, R\., "The MD4 message digest algorithm", in A\.J\. Menezes and S\.A\.
     Vanstone, editors, Advances in Cryptology \- CRYPTO '90 Proceedings, pages
     303\-311, Springer\-Verlag, 1991\.

  1. Rivest, R\., "The MD5 Message\-Digest Algorithm", RFC 1321, MIT and RSA Data
     Security, Inc, April 1992\.
     \([http://www\.rfc\-editor\.org/rfc/rfc1321\.txt](http://www\.rfc\-editor\.org/rfc/rfc1321\.txt)\)

  1. Krawczyk, H\., Bellare, M\. and Canetti, R\. "HMAC: Keyed\-Hashing for Message
     Authentication", RFC 2104, February 1997\.
     \([http://www\.rfc\-editor\.org/rfc/rfc2104\.txt](http://www\.rfc\-editor\.org/rfc/rfc2104\.txt)\)

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *md4* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[md5](\.\./md5/md5\.md), [sha1](\.\./sha1/sha1\.md)

# <a name='keywords'></a>KEYWORDS

[hashing](\.\./\.\./\.\./\.\./index\.md\#hashing),
[md4](\.\./\.\./\.\./\.\./index\.md\#md4),
[message\-digest](\.\./\.\./\.\./\.\./index\.md\#message\_digest), [rfc
1320](\.\./\.\./\.\./\.\./index\.md\#rfc\_1320), [rfc
1321](\.\./\.\./\.\./\.\./index\.md\#rfc\_1321), [rfc
2104](\.\./\.\./\.\./\.\./index\.md\#rfc\_2104),
[security](\.\./\.\./\.\./\.\./index\.md\#security)

# <a name='category'></a>CATEGORY

Hashes, checksums, and encryption

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2003, Pat Thoyts <patthoyts@users\.sourceforge\.net>
