
[//000000001]: # (ripemd128 \- RIPEMD Message\-Digest Algorithm)
[//000000002]: # (Generated from file 'ripemd128\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004, Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000004]: # (ripemd128\(n\) 1\.0\.5 tcllib "RIPEMD Message\-Digest Algorithm")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

ripemd128 \- RIPEMD\-128 Message\-Digest Algorithm

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
package require ripemd128 ?1\.0\.5?  

[__::ripemd::ripemd128__ ?*\-hex*? \[ *\-channel channel* &#124; *\-file filename* &#124; *string* \]](#1)  
[__::ripemd::hmac128__ ?*\-hex*? *\-key key* \[ *\-channel channel* &#124; *\-file filename* &#124; *string* \]](#2)  
[__::ripemd::RIPEMD128Init__](#3)  
[__::ripemd::RIPEMD128Update__ *token* *data*](#4)  
[__::ripemd::RIPEMD128Final__ *token*](#5)  
[__::ripemd::RIPEHMAC128Init__ *key*](#6)  
[__::ripemd::RIPEHMAC128Update__ *token* *data*](#7)  
[__::ripemd::RIPEHMAC128Final__ *token*](#8)  

# <a name='description'></a>DESCRIPTION

This package is an implementation in Tcl of the RIPEMD\-128 message\-digest
algorithm \(1\)\. This algorithm takes an arbitrary quantity of data and generates
a 128\-bit message digest from the input\. The RIPEMD\-128 algorithm is based upon
the MD4 algorithm \(2, 4\) but has been cryptographically strengthened against
weaknesses that have been found in MD4 \(4\)\. RIPEMD\-128 has been designed to be a
drop\-in replacement for MD4 and MD5 \(5\)\. If security is the major consideration,
then RIPEMD\-160 or SHA1 should be considered\.

This package will use __Trf__ to accelerate the digest computation if
available\. In the absence of an accelerator package the pure\-Tcl implementation
will be used\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::ripemd::ripemd128__ ?*\-hex*? \[ *\-channel channel* &#124; *\-file filename* &#124; *string* \]

    Calculate the RIPEMD\-128 digest of the data given in string\. This is
    returned as a binary string by default\. Giving the *\-hex* option will
    return a hexadecimal encoded version of the digest\.

    The data to be hashed can be specified either as a string argument to the
    ripemd128 command, or as a filename or a pre\-opened channel\. If the
    *\-filename* argument is given then the file is opened, the data read and
    hashed and the file is closed\. If the *\-channel* argument is given then
    data is read from the channel until the end of file\. The channel is not
    closed\.

    Only one of *\-file*, *\-channel* or *string* should be given\.

  - <a name='2'></a>__::ripemd::hmac128__ ?*\-hex*? *\-key key* \[ *\-channel channel* &#124; *\-file filename* &#124; *string* \]

    Calculate an Hashed Message Authentication digest \(HMAC\) using the
    RIPEMD\-128 digest algorithm\. HMACs are described in RFC 2104 \(6\) and provide
    a RIPEMD\-128 digest that includes a key\. All options other than *\-key* are
    as for the __::ripemd::ripemd128__ command\.

# <a name='section3'></a>PROGRAMMING INTERFACE

For the programmer, hash functions can be viewed as a bucket into which one
pours data\. When you have finished, you extract a value that is uniquely derived
from the data that was poured into the bucket\. The programming interface to the
hash operates on a token \(equivalent to the bucket\)\. You call
__RIPEMD128Init__ to obtain a token and then call __RIPEMD128Update__ as
many times as required to add data to the hash\. To release any resources and
obtain the hash value, you then call __RIPEMD128Final__\. An equivalent set
of functions gives you a keyed digest \(HMAC\)\.

If you have __critcl__ and have built the __tcllibc__ package then the
implementation of the hashing function will be performed by compiled code\.
Alternatively if both the Trf and Memchan extensions are available then these
will be used\. Finally the package will revert to a pure\-Tcl implementation\. The
programming interface remains the same, however\.

  - <a name='3'></a>__::ripemd::RIPEMD128Init__

    Begins a new RIPEMD\-128 hash\. Returns a token ID that must be used for the
    remaining functions\.

  - <a name='4'></a>__::ripemd::RIPEMD128Update__ *token* *data*

    Add data to the hash identified by token\. Calling *RIPEMD128Update $token
    "abcd"* is equivalent to calling *RIPEMD128Update $token "ab"* followed
    by *RIPEMD128Update $token "cb"*\. See [EXAMPLES](#section4)\.

  - <a name='5'></a>__::ripemd::RIPEMD128Final__ *token*

    Returns the hash value and releases any resources held by this token\. Once
    this command completes the token will be invalid\. The result is a binary
    string of 16 bytes representing the 128 bit RIPEMD\-128 digest value\.

  - <a name='6'></a>__::ripemd::RIPEHMAC128Init__ *key*

    This is equivalent to the __::ripemd::RIPEMD128Init__ command except
    that it requires the key that will be included in the HMAC\.

  - <a name='7'></a>__::ripemd::RIPEHMAC128Update__ *token* *data*

  - <a name='8'></a>__::ripemd::RIPEHMAC128Final__ *token*

    These commands are identical to the RIPEMD128 equivalent commands\.

# <a name='section4'></a>EXAMPLES

    % ripemd::ripemd128 -hex "Tcl does RIPEMD-128"
    3cab177bae65205d81e7978f63556c63

    % ripemd::hmac128 -hex -key Sekret "Tcl does RIPEMD-128"
    b359dc5971a05beea0be7b106b30e389

    % set tok [ripemd::RIPEMD128Init]
    ::ripemd::1
    % ripemd::RIPEMD128Update $tok "Tcl "
    % ripemd::RIPEMD128Update $tok "does "
    % ripemd::RIPEMD128Update $tok "RIPEMD-128"
    % ripemd::Hex [ripemd::RIPEMD128Final $tok]
    3cab177bae65205d81e7978f63556c63

# <a name='section5'></a>REFERENCES

  1. H\. Dobbertin, A\. Bosselaers, B\. Preneel, "RIPEMD\-160, a strengthened
     version of RIPEMD"
     [http://www\.esat\.kuleuven\.ac\.be/~cosicart/pdf/AB\-9601/AB\-9601\.pdf](http://www\.esat\.kuleuven\.ac\.be/~cosicart/pdf/AB\-9601/AB\-9601\.pdf)

  1. Rivest, R\., "The MD4 Message Digest Algorithm", RFC 1320, MIT, April 1992\.
     \([http://www\.rfc\-editor\.org/rfc/rfc1320\.txt](http://www\.rfc\-editor\.org/rfc/rfc1320\.txt)\)

  1. Rivest, R\., "The MD4 message digest algorithm", in A\.J\. Menezes and S\.A\.
     Vanstone, editors, Advances in Cryptology \- CRYPTO '90 Proceedings, pages
     303\-311, Springer\-Verlag, 1991\.

  1. Dobbertin, H\., "Cryptanalysis of MD4", Journal of Cryptology vol 11 \(4\),
     pp\. 253\-271 \(1998\)

  1. Rivest, R\., "The MD5 Message\-Digest Algorithm", RFC 1321, MIT and RSA Data
     Security, Inc, April 1992\.
     \([http://www\.rfc\-editor\.org/rfc/rfc1321\.txt](http://www\.rfc\-editor\.org/rfc/rfc1321\.txt)\)

  1. Krawczyk, H\., Bellare, M\. and Canetti, R\. "HMAC: Keyed\-Hashing for Message
     Authentication", RFC 2104, February 1997\.
     \([http://www\.rfc\-editor\.org/rfc/rfc2104\.txt](http://www\.rfc\-editor\.org/rfc/rfc2104\.txt)\)

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *ripemd* of the [Tcllib
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
[ripemd160](ripemd160\.md), [sha1](\.\./sha1/sha1\.md)

# <a name='keywords'></a>KEYWORDS

[RIPEMD](\.\./\.\./\.\./\.\./index\.md\#ripemd),
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

Copyright &copy; 2004, Pat Thoyts <patthoyts@users\.sourceforge\.net>
