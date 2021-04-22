
[//000000001]: # (sha1 \- SHA\-x Message\-Digest Algorithm)
[//000000002]: # (Generated from file 'sha1\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005, Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000004]: # (sha1\(n\) 2\.0\.4 tcllib "SHA\-x Message\-Digest Algorithm")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

sha1 \- SHA1 Message\-Digest Algorithm

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
package require sha1 ?2\.0\.4?  

[__::sha1::sha1__ ?__\-hex&#124;\-bin__? \[ __\-channel channel__ &#124; __\-file filename__ &#124; ?__\-\-__? *string* \]](#1)  
[__::sha1::hmac__ *key* *string*](#2)  
[__::sha1::hmac__ ?__\-hex&#124;\-bin__? __\-key key__ \[ __\-channel channel__ &#124; __\-file filename__ &#124; ?__\-\-__? *string* \]](#3)  
[__::sha1::SHA1Init__](#4)  
[__::sha1::SHA1Update__ *token* *data*](#5)  
[__::sha1::SHA1Final__ *token*](#6)  
[__::sha1::HMACInit__ *key*](#7)  
[__::sha1::HMACUpdate__ *token* *data*](#8)  
[__::sha1::HMACFinal__ *token*](#9)  

# <a name='description'></a>DESCRIPTION

This package provides an implementation in Tcl of the SHA1 message\-digest
algorithm as specified by FIPS PUB 180\-1 \(1\)\. This algorithm takes a message and
generates a 160\-bit digest from the input\. The SHA1 algorithm is related to the
MD4 algorithm \(2\) but has been strengthend against certain types of
cryptographic attack\. SHA1 should be used in preference to MD4 or MD5 in new
applications\.

This package also includes support for creating keyed message\-digests using the
HMAC algorithm from RFC 2104 \(3\) with SHA1 as the message\-digest\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::sha1::sha1__ ?__\-hex&#124;\-bin__? \[ __\-channel channel__ &#124; __\-file filename__ &#124; ?__\-\-__? *string* \]

    The command takes a message and returns the SHA1 digest of this message as a
    hexadecimal string\. You may request the result as binary data by giving
    *\-bin*\.

    The data to be hashed can be specified either as a string argument to the
    __sha1__ command, or as a filename or a pre\-opened channel\. If the
    *\-filename* argument is given then the file is opened, the data read and
    hashed and the file is closed\. If the *\-channel* argument is given then
    data is read from the channel until the end of file\. The channel is not
    closed\. *NOTE* use of the channel or filename options results in the
    internal use of __[vwait](\.\./\.\./\.\./\.\./index\.md\#vwait)__\. To avoid
    nested event loops in Tk or tclhttpd applications you should use the
    incremental programming API \(see below\)\.

    Only one of *\-file*, *\-channel* or *string* should be given\.

    If the *string* to hash can be mistaken for an option \(leading dash "\-"\),
    use the option __\-\-__ before it to terminate option processing and force
    interpretation as a string\.

  - <a name='2'></a>__::sha1::hmac__ *key* *string*

  - <a name='3'></a>__::sha1::hmac__ ?__\-hex&#124;\-bin__? __\-key key__ \[ __\-channel channel__ &#124; __\-file filename__ &#124; ?__\-\-__? *string* \]

    Calculate an Hashed Message Authentication digest \(HMAC\) using the SHA1
    digest algorithm\. HMACs are described in RFC 2104 \(3\) and provide an SHA1
    digest that includes a key\. All options other than *\-key* are as for the
    __::sha1::sha1__ command\.

    If the *string* to hash can be mistaken for an option \(leading dash "\-"\),
    use the option __\-\-__ before it to terminate option processing and force
    interpretation as a string\.

# <a name='section3'></a>PROGRAMMING INTERFACE

For the programmer, the SHA1 hash can be viewed as a bucket into which one pours
data\. When you have finished, you extract a value that is derived from the data
that was poured into the bucket\. The programming interface to the SHA1 hash
operates on a token \(equivalent to the bucket\)\. You call __SHA1Init__ to
obtain a token and then call __SHA1Update__ as many times as required to add
data to the hash\. To release any resources and obtain the hash value, you then
call __SHA1Final__\. An equivalent set of functions gives you a keyed digest
\(HMAC\)\.

If you have __critcl__ and have built the __tcllibc__ package then the
implementation of the hashing function will be performed by compiled code\.
Failing that if you have the __Trf__ package then this can be used otherwise
there is a pure\-tcl equivalent\. The programming interface remains the same in
all cases\.

  - <a name='4'></a>__::sha1::SHA1Init__

    Begins a new SHA1 hash\. Returns a token ID that must be used for the
    remaining functions\.

  - <a name='5'></a>__::sha1::SHA1Update__ *token* *data*

    Add data to the hash identified by token\. Calling *SHA1Update $token
    "abcd"* is equivalent to calling *SHA1Update $token "ab"* followed by
    *SHA1Update $token "cb"*\. See [EXAMPLES](#section4)\.

  - <a name='6'></a>__::sha1::SHA1Final__ *token*

    Returns the hash value and releases any resources held by this token\. Once
    this command completes the token will be invalid\. The result is a binary
    string of 20 bytes representing the 160 bit SHA1 digest value\.

  - <a name='7'></a>__::sha1::HMACInit__ *key*

    This is equivalent to the __::sha1::SHA1Init__ command except that it
    requires the key that will be included in the HMAC\.

  - <a name='8'></a>__::sha1::HMACUpdate__ *token* *data*

  - <a name='9'></a>__::sha1::HMACFinal__ *token*

    These commands are identical to the SHA1 equivalent commands\.

# <a name='section4'></a>EXAMPLES

    % sha1::sha1 "Tcl does SHA1"
    285a6a91c45a9066bf39fcf24425796ef0b2a8bf

    % sha1::hmac Sekret "Tcl does SHA1"
    ae6251fa51b95b18cba2be95eb031d07475ff03c

    % set tok [sha1::SHA1Init]
    ::sha1::1
    % sha1::SHA1Update $tok "Tcl "
    % sha1::SHA1Update $tok "does "
    % sha1::SHA1Update $tok "SHA1"
    % sha1::Hex [sha1::SHA1Final $tok]
    285a6a91c45a9066bf39fcf24425796ef0b2a8bf

# <a name='section5'></a>REFERENCES

  1. "Secure Hash Standard", National Institute of Standards and Technology,
     U\.S\. Department Of Commerce, April 1995\.
     \([http://www\.itl\.nist\.gov/fipspubs/fip180\-1\.htm](http://www\.itl\.nist\.gov/fipspubs/fip180\-1\.htm)\)

  1. Rivest, R\., "The MD4 Message Digest Algorithm", RFC 1320, MIT, April 1992\.
     \([http://www\.rfc\-editor\.org/rfc/rfc1320\.txt](http://www\.rfc\-editor\.org/rfc/rfc1320\.txt)\)

  1. Krawczyk, H\., Bellare, M\. and Canetti, R\. "HMAC: Keyed\-Hashing for Message
     Authentication", RFC 2104, February 1997\.
     \([http://www\.rfc\-editor\.org/rfc/rfc2104\.txt](http://www\.rfc\-editor\.org/rfc/rfc2104\.txt)\)

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *sha1* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[md4](\.\./md4/md4\.md), [md5](\.\./md5/md5\.md),
[ripemd128](\.\./ripemd/ripemd128\.md), [ripemd160](\.\./ripemd/ripemd160\.md)

# <a name='keywords'></a>KEYWORDS

[FIPS 180\-1](\.\./\.\./\.\./\.\./index\.md\#fips\_180\_1),
[hashing](\.\./\.\./\.\./\.\./index\.md\#hashing),
[message\-digest](\.\./\.\./\.\./\.\./index\.md\#message\_digest), [rfc
2104](\.\./\.\./\.\./\.\./index\.md\#rfc\_2104),
[security](\.\./\.\./\.\./\.\./index\.md\#security),
[sha1](\.\./\.\./\.\./\.\./index\.md\#sha1)

# <a name='category'></a>CATEGORY

Hashes, checksums, and encryption

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005, Pat Thoyts <patthoyts@users\.sourceforge\.net>
