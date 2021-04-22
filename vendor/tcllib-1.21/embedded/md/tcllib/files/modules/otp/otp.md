
[//000000001]: # (otp \- RFC 2289 A One\-Time Password System)
[//000000002]: # (Generated from file 'otp\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006, Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000004]: # (otp\(n\) 1\.0\.0 tcllib "RFC 2289 A One\-Time Password System")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

otp \- One\-Time Passwords

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [EXAMPLES](#section3)

  - [REFERENCES](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require otp ?1\.0\.0?  

[__::otp::otp\-md4__ ?*\-hex*? ?*\-words*? *\-seed seed* *\-count count* *data*](#1)  
[__::otp::otp\-md5__ ?*\-hex*? ?*\-words*? *\-seed seed* *\-count count* *data*](#2)  
[__::otp::otp\-sha1__ ?*\-hex*? ?*\-words*? *\-seed seed* *\-count count* *data*](#3)  
[__::otp::otp\-rmd160__ ?*\-hex*? ?*\-words*? *\-seed seed* *\-count count* *data*](#4)  

# <a name='description'></a>DESCRIPTION

This package is an implementation in Tcl of the One\-Time Password system as
described in RFC 2289 \(1\)\. This system uses message\-digest algorithms to
sequentially hash a passphrase to create single\-use passwords\. The resulting
data is then provided to the user as either hexadecimal digits or encoded using
a dictionary of 2048 words\. This system is used by OpenBSD for secure login and
can be used as a SASL mechanism for authenticating users\.

In this implementation we provide support for four algorithms that are included
in the tcllib distribution: MD5 \(2\), MD4 \(3\), RIPE\-MD160 \(4\) and SHA\-1 \(5\)\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::otp::otp\-md4__ ?*\-hex*? ?*\-words*? *\-seed seed* *\-count count* *data*

  - <a name='2'></a>__::otp::otp\-md5__ ?*\-hex*? ?*\-words*? *\-seed seed* *\-count count* *data*

  - <a name='3'></a>__::otp::otp\-sha1__ ?*\-hex*? ?*\-words*? *\-seed seed* *\-count count* *data*

  - <a name='4'></a>__::otp::otp\-rmd160__ ?*\-hex*? ?*\-words*? *\-seed seed* *\-count count* *data*

# <a name='section3'></a>EXAMPLES

    % otp::otp-md5 -count 99 -seed host67821 "My Secret Pass Phrase"
    (binary gibberish)
    % otp::otp-md5 -words -count 99 -seed host67821 "My Secret Pass Phrase"
    SOON ARAB BURG LIMB FILE WAD
    % otp::otp-md5 -hex -count 99 -seed host67821 "My Secret Pass Phrase"
    e249b58257c80087

# <a name='section4'></a>REFERENCES

  1. Haller, N\. et al\., "A One\-Time Password System", RFC 2289, February 1998\.
     [http://www\.rfc\-editor\.org/rfc/rfc2289\.txt](http://www\.rfc\-editor\.org/rfc/rfc2289\.txt)

  1. Rivest, R\., "The MD5 Message\-Digest Algorithm", RFC 1321, MIT and RSA Data
     Security, Inc, April 1992\.
     \([http://www\.rfc\-editor\.org/rfc/rfc1321\.txt](http://www\.rfc\-editor\.org/rfc/rfc1321\.txt)\)

  1. Rivest, R\., "The MD4 Message Digest Algorithm", RFC 1320, MIT, April 1992\.
     \([http://www\.rfc\-editor\.org/rfc/rfc1320\.txt](http://www\.rfc\-editor\.org/rfc/rfc1320\.txt)\)

  1. H\. Dobbertin, A\. Bosselaers, B\. Preneel, "RIPEMD\-160, a strengthened
     version of RIPEMD"
     [http://www\.esat\.kuleuven\.ac\.be/~cosicart/pdf/AB\-9601/AB\-9601\.pdf](http://www\.esat\.kuleuven\.ac\.be/~cosicart/pdf/AB\-9601/AB\-9601\.pdf)

  1. "Secure Hash Standard", National Institute of Standards and Technology,
     U\.S\. Department Of Commerce, April 1995\.
     \([http://www\.itl\.nist\.gov/fipspubs/fip180\-1\.htm](http://www\.itl\.nist\.gov/fipspubs/fip180\-1\.htm)\)

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *otp* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[SASL](\.\./sasl/sasl\.md), [md4](\.\./md4/md4\.md), [md5](\.\./md5/md5\.md),
[ripemd160](\.\./ripemd/ripemd160\.md), [sha1](\.\./sha1/sha1\.md)

# <a name='keywords'></a>KEYWORDS

[hashing](\.\./\.\./\.\./\.\./index\.md\#hashing),
[message\-digest](\.\./\.\./\.\./\.\./index\.md\#message\_digest),
[password](\.\./\.\./\.\./\.\./index\.md\#password), [rfc
2289](\.\./\.\./\.\./\.\./index\.md\#rfc\_2289),
[security](\.\./\.\./\.\./\.\./index\.md\#security)

# <a name='category'></a>CATEGORY

Hashes, checksums, and encryption

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006, Pat Thoyts <patthoyts@users\.sourceforge\.net>
