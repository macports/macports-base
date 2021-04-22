
[//000000001]: # (md5 \- MD5 Message\-Digest Algorithm)
[//000000002]: # (Generated from file 'md5\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2003, Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000004]: # (md5\(n\) 2\.0\.8 tcllib "MD5 Message\-Digest Algorithm")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

md5 \- MD5 Message\-Digest Algorithm

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
package require md5 ?2\.0\.7?  

[__::md5::md5__ ?*\-hex*? \[ *\-channel channel* &#124; *\-file filename* &#124; *string* \]](#1)  
[__::md5::hmac__ ?*\-hex*? *\-key key* \[ *\-channel channel* &#124; *\-file filename* &#124; *string* \]](#2)  
[__::md5::MD5Init__](#3)  
[__::md5::MD5Update__ *token* *data*](#4)  
[__::md5::MD5Final__ *token*](#5)  
[__::md5::HMACInit__ *key*](#6)  
[__::md5::HMACUpdate__ *token* *data*](#7)  
[__::md5::HMACFinal__ *token*](#8)  

# <a name='description'></a>DESCRIPTION

This package is an implementation in Tcl of the MD5 message\-digest algorithm as
described in RFC 1321 \(1\)\. This algorithm takes an arbitrary quantity of data
and generates a 128\-bit message digest from the input\. The MD5 algorithm is
related to the MD4 algorithm \(2\) but has been strengthened against certain types
of potential attack\. MD5 should be used in preference to MD4 for new
applications\.

If you have __critcl__ and have built the __tcllibc__ package then the
implementation of the hashing function will be performed by compiled code\.
Alternatively if you have either __cryptkit__ or __Trf__ then either of
these can be used to accelerate the digest computation\. If no suitable compiled
package is available then the pure\-Tcl implementation wil be used\. The
programming interface remains the same in all cases\.

*Note* the previous version of this package always returned a hex encoded
string\. This has been changed to simplify the programming interface and to make
this version more compatible with other implementations\. To obtain the previous
usage, either explicitly specify package version 1 or use the *\-hex* option to
the __md5__ command\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::md5::md5__ ?*\-hex*? \[ *\-channel channel* &#124; *\-file filename* &#124; *string* \]

    Calculate the MD5 digest of the data given in string\. This is returned as a
    binary string by default\. Giving the *\-hex* option will return a
    hexadecimal encoded version of the digest\.

    The data to be hashed can be specified either as a string argument to the
    __md5__ command, or as a filename or a pre\-opened channel\. If the
    *\-filename* argument is given then the file is opened, the data read and
    hashed and the file is closed\. If the *\-channel* argument is given then
    data is read from the channel until the end of file\. The channel is not
    closed\.

    Only one of *\-file*, *\-channel* or *string* should be given\.

  - <a name='2'></a>__::md5::hmac__ ?*\-hex*? *\-key key* \[ *\-channel channel* &#124; *\-file filename* &#124; *string* \]

    Calculate an Hashed Message Authentication digest \(HMAC\) using the MD5
    digest algorithm\. HMACs are described in RFC 2104 \(3\) and provide an MD5
    digest that includes a key\. All options other than *\-key* are as for the
    __::md5::md5__ command\.

# <a name='section3'></a>PROGRAMMING INTERFACE

For the programmer, the MD5 hash can be viewed as a bucket into which one pours
data\. When you have finished, you extract a value that is derived from the data
that was poured into the bucket\. The programming interface to the MD5 hash
operates on a token \(equivalent to the bucket\)\. You call __MD5Init__ to
obtain a token and then call __MD5Update__ as many times as required to add
data to the hash\. To release any resources and obtain the hash value, you then
call __MD5Final__\. An equivalent set of functions gives you a keyed digest
\(HMAC\)\.

  - <a name='3'></a>__::md5::MD5Init__

    Begins a new MD5 hash\. Returns a token ID that must be used for the
    remaining functions\.

  - <a name='4'></a>__::md5::MD5Update__ *token* *data*

    Add data to the hash identified by token\. Calling *MD5Update $token
    "abcd"* is equivalent to calling *MD5Update $token "ab"* followed by
    *MD5Update $token "cb"*\. See [EXAMPLES](#section4)\.

  - <a name='5'></a>__::md5::MD5Final__ *token*

    Returns the hash value and releases any resources held by this token\. Once
    this command completes the token will be invalid\. The result is a binary
    string of 16 bytes representing the 128 bit MD5 digest value\.

  - <a name='6'></a>__::md5::HMACInit__ *key*

    This is equivalent to the __::md5::MD5Init__ command except that it
    requires the key that will be included in the HMAC\.

  - <a name='7'></a>__::md5::HMACUpdate__ *token* *data*

  - <a name='8'></a>__::md5::HMACFinal__ *token*

    These commands are identical to the MD5 equivalent commands\.

# <a name='section4'></a>EXAMPLES

    % md5::md5 -hex "Tcl does MD5"
    8AAC1EE01E20BB347104FABB90310433

    % md5::hmac -hex -key Sekret "Tcl does MD5"
    35BBA244FD56D3EDF5F3C47474DACB5D

    % set tok [md5::MD5Init]
    ::md5::1
    % md5::MD5Update $tok "Tcl "
    % md5::MD5Update $tok "does "
    % md5::MD5Update $tok "MD5"
    % md5::Hex [md5::MD5Final $tok]
    8AAC1EE01E20BB347104FABB90310433

# <a name='section5'></a>REFERENCES

  1. Rivest, R\., "The MD5 Message\-Digest Algorithm", RFC 1321, MIT and RSA Data
     Security, Inc, April 1992\.
     \([http://www\.rfc\-editor\.org/rfc/rfc1321\.txt](http://www\.rfc\-editor\.org/rfc/rfc1321\.txt)\)

  1. Rivest, R\., "The MD4 Message Digest Algorithm", RFC 1320, MIT, April 1992\.
     \([http://www\.rfc\-editor\.org/rfc/rfc1320\.txt](http://www\.rfc\-editor\.org/rfc/rfc1320\.txt)\)

  1. Krawczyk, H\., Bellare, M\. and Canetti, R\. "HMAC: Keyed\-Hashing for Message
     Authentication", RFC 2104, February 1997\.
     \([http://www\.rfc\-editor\.org/rfc/rfc2104\.txt](http://www\.rfc\-editor\.org/rfc/rfc2104\.txt)\)

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *md5* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[md4](\.\./md4/md4\.md), [sha1](\.\./sha1/sha1\.md)

# <a name='keywords'></a>KEYWORDS

[hashing](\.\./\.\./\.\./\.\./index\.md\#hashing),
[md5](\.\./\.\./\.\./\.\./index\.md\#md5),
[message\-digest](\.\./\.\./\.\./\.\./index\.md\#message\_digest), [rfc
1320](\.\./\.\./\.\./\.\./index\.md\#rfc\_1320), [rfc
1321](\.\./\.\./\.\./\.\./index\.md\#rfc\_1321), [rfc
2104](\.\./\.\./\.\./\.\./index\.md\#rfc\_2104),
[security](\.\./\.\./\.\./\.\./index\.md\#security)

# <a name='category'></a>CATEGORY

Hashes, checksums, and encryption

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2003, Pat Thoyts <patthoyts@users\.sourceforge\.net>
