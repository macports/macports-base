
[//000000001]: # (des \- Data Encryption Standard \(DES\))
[//000000002]: # (Generated from file 'des\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005, Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000004]: # (des\(n\) 1\.1 tcllib "Data Encryption Standard \(DES\)")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

des \- Implementation of the DES and triple\-DES ciphers

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [PROGRAMMING INTERFACE](#section3)

  - [MODES OF OPERATION](#section4)

  - [EXAMPLES](#section5)

  - [REFERENCES](#section6)

  - [AUTHORS](#section7)

  - [Bugs, Ideas, Feedback](#section8)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require des 1\.1  

[__::DES::des__ ?*\-mode \[ecb&#124;cbc&#124;cfb&#124;ofb\]*? ?*\-dir \[encrypt&#124;decrypt\]*? *\-key keydata* ?*\-iv vector*? ?*\-hex*? ?*\-weak*? ?*\-out channel*? ?*\-chunksize size*? \[ *\-in channel* &#124; *data* \]](#1)  
[__::DES::Init__ *mode* *keydata* *iv* ?*weak*?](#2)  
[__::DES::Encrypt__ *Key* *data*](#3)  
[__::DES::Decrypt__ *Key* *data*](#4)  
[__::DES::Reset__ *Key* *iv*](#5)  
[__::DES::Final__ *Key*](#6)  

# <a name='description'></a>DESCRIPTION

This is an implementation in Tcl of the Data Encryption Standard \(DES\) as
published by the U\.S\. National Institute of Standards and Technology \(NIST\) \[1\]\.
This implementation also supports triple DES \(3DES\) extension to DES\. DES is a
64\-bit block cipher that uses a 56\-bit key\. 3DES uses a 168\-bit key\. DES has now
officially been superceeded by AES but is in common use in many protocols\.

The tcllib implementation of DES and 3DES uses an implementation by Mac Cody and
is available as a separate download from \[2\]\. For anyone concerned about the
details of exporting this code please see the TclDES web pages\. The tcllib
specific code is a wrapper to the TclDES API that presents same API for the DES
cipher as for other ciphers in the library\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::DES::des__ ?*\-mode \[ecb&#124;cbc&#124;cfb&#124;ofb\]*? ?*\-dir \[encrypt&#124;decrypt\]*? *\-key keydata* ?*\-iv vector*? ?*\-hex*? ?*\-weak*? ?*\-out channel*? ?*\-chunksize size*? \[ *\-in channel* &#124; *data* \]

    Perform the __[DES](\.\./\.\./\.\./\.\./index\.md\#des)__ algorithm on either
    the data provided by the argument or on the data read from the *\-in*
    channel\. If an *\-out* channel is given then the result will be written to
    this channel\.

    The *\-key* option must be given\. This parameter takes a binary string of 8
    bytes in length and is used to generate the key schedule\. In DES only 56
    bits of key data are used\. The highest bit from each byte is discarded\.

    The *\-mode* and *\-dir* options are optional and default to cbc mode and
    encrypt respectively\. The initialization vector *\-iv* takes an 8 byte
    binary argument\. This defaults to all zeros\. See [MODES OF
    OPERATION](#section4) for more about *\-mode* and the use of the
    initialization vector\.

    DES is a 64\-bit block cipher\. This means that the data must be provided in
    units that are a multiple of 8 bytes\.

# <a name='section3'></a>PROGRAMMING INTERFACE

Internal state is maintained in an opaque structure that is returned from the
__Init__ function\. In ECB mode the state is not affected by the input but
for other modes some input dependent state is maintained and may be reset by
calling the __Reset__ function with a new initialization vector value\.

  - <a name='2'></a>__::DES::Init__ *mode* *keydata* *iv* ?*weak*?

    Construct a new DES key schedule using the specified key data and the given
    initialization vector\. The initialization vector is not used with ECB mode
    but is important for other usage modes\. See [MODES OF
    OPERATION](#section4)\.

    There are a small number of keys that are known to be weak when used with
    DES\. By default if such a key is passed in then an error will be raised\. If
    there is a need to accept such keys then the *weak* parameter can be set
    true to avoid the error being thrown\.

  - <a name='3'></a>__::DES::Encrypt__ *Key* *data*

    Use a prepared key acquired by calling __Init__ to encrypt the provided
    data\. The data argument should be a binary array that is a multiple of the
    DES block size of 8 bytes\. The result is a binary array the same size as the
    input of encrypted data\.

  - <a name='4'></a>__::DES::Decrypt__ *Key* *data*

    Decipher data using the key\. Note that the same key may be used to encrypt
    and decrypt data provided that the initialization vector is reset
    appropriately for CBC mode\.

  - <a name='5'></a>__::DES::Reset__ *Key* *iv*

    Reset the initialization vector\. This permits the programmer to re\-use a key
    and avoid the cost of re\-generating the key schedule where the same key data
    is being used multiple times\.

  - <a name='6'></a>__::DES::Final__ *Key*

    This should be called to clean up resources associated with *Key*\. Once
    this function has been called the key may not be used again\.

# <a name='section4'></a>MODES OF OPERATION

  - Electronic Code Book \(ECB\)

    ECB is the basic mode of all block ciphers\. Each block is encrypted
    independently and so identical plain text will produce identical output when
    encrypted with the same key\. Any encryption errors will only affect a single
    block however this is vulnerable to known plaintext attacks\.

  - Cipher Block Chaining \(CBC\)

    CBC mode uses the output of the last block encryption to affect the current
    block\. An initialization vector of the same size as the cipher block size is
    used to handle the first block\. The initialization vector should be chosen
    randomly and transmitted as the first block of the output\. Errors in
    encryption affect the current block and the next block after which the
    cipher will correct itself\. CBC is the most commonly used mode in software
    encryption\.

  - Cipher Feedback \(CFB\)

    CFB mode can be used to convert block ciphers into stream ciphers\. In CFB
    mode the initialization vector is encrypted and the output is then xor'd
    with the plaintext stream\. The result is then used as the initialization
    vector for the next round\. Errors will affect the current block and the next
    block\.

  - Output Feedback \(OFB\)

    OFB is similar to CFB except that the output of the cipher is fed back into
    the next round and not the xor'd plain text\. This means that errors only
    affect a single block but the cipher is more vulnerable to attack\.

# <a name='section5'></a>EXAMPLES

    % set ciphertext [DES::des -mode cbc -dir encrypt -key $secret $plaintext]
    % set plaintext [DES::des -mode cbc -dir decrypt -key $secret $ciphertext]

    set iv [string repeat \\0 8]
    set Key [DES::Init cbc \\0\\1\\2\\3\\4\\5\\6\\7 $iv]
    set ciphertext [DES::Encrypt $Key "somedata"]
    append ciphertext [DES::Encrypt $Key "moredata"]
    DES::Reset $Key $iv
    set plaintext [DES::Decrypt $Key $ciphertext]
    DES::Final $Key

# <a name='section6'></a>REFERENCES

  1. "Data Encryption Standard", Federal Information Processing Standards
     Publication 46\-3, 1999,
     \([http://csrc\.nist\.gov/publications/fips/fips46\-3/fips46\-3\.pdf](http://csrc\.nist\.gov/publications/fips/fips46\-3/fips46\-3\.pdf)\)

  1. "TclDES: munitions\-grade Tcl scripting"
     [http://tcldes\.sourceforge\.net/](http://tcldes\.sourceforge\.net/)

# <a name='section7'></a>AUTHORS

Jochen C Loewer, Mac Cody, Pat Thoyts

# <a name='section8'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *des* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[aes\(n\)](\.\./aes/aes\.md), [blowfish\(n\)](\.\./blowfish/blowfish\.md),
[md5\(n\)](\.\./md5/md5\.md), [rc4\(n\)](\.\./rc4/rc4\.md),
[sha1\(n\)](\.\./sha1/sha1\.md)

# <a name='keywords'></a>KEYWORDS

[3DES](\.\./\.\./\.\./\.\./index\.md\#3des), [DES](\.\./\.\./\.\./\.\./index\.md\#des),
[block cipher](\.\./\.\./\.\./\.\./index\.md\#block\_cipher), [data
integrity](\.\./\.\./\.\./\.\./index\.md\#data\_integrity),
[encryption](\.\./\.\./\.\./\.\./index\.md\#encryption),
[security](\.\./\.\./\.\./\.\./index\.md\#security)

# <a name='category'></a>CATEGORY

Hashes, checksums, and encryption

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005, Pat Thoyts <patthoyts@users\.sourceforge\.net>
