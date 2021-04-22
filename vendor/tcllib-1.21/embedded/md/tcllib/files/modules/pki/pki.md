
[//000000001]: # (pki \- public key encryption)
[//000000002]: # (Generated from file 'pki\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2010, 2011, 2012, 2013, 2021 Roy Keene, Andreas Kupries, Ashok P\. Nadkarni)
[//000000004]: # (pki\(n\) 0\.10 tcllib "public key encryption")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pki \- Implementation of the public key cipher

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [EXAMPLES](#section3)

  - [REFERENCES](#section4)

  - [AUTHORS](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require pki ?0\.10?  

[__::pki::encrypt__ ?*\-binary*? ?*\-hex*? ?*\-pad*? ?*\-nopad*? ?*\-priv*? ?*\-pub*? ?*\-\-*? *input* *key*](#1)  
[__::pki::decrypt__ ?*\-binary*? ?*\-hex*? ?*\-unpad*? ?*\-nounpad*? ?*\-priv*? ?*\-pub*? ?*\-\-*? *input* *key*](#2)  
[__::pki::sign__ *input* *key* ?*algo*?](#3)  
[__::pki::verify__ *signedmessage* *plaintext* *key* ?*algo*?](#4)  
[__::pki::key__ *key* ?*password*? ?*encodePem*?](#5)  
[__::pki::pkcs::parse\_key__ *key* ?*password*?](#6)  
[__::pki::x509::parse\_cert__ *cert*](#7)  
[__::pki::rsa::generate__ *bitlength* ?*exponent*?](#8)  
[__::pki::x509::verify\_cert__ *cert* *trustedcerts* ?*intermediatecerts*?](#9)  
[__::pki::x509::validate\_cert__ *cert* ?__\-sign\_message__ *dn\_of\_signer*? ?__\-encrypt\_message__ *dn\_of\_signer*? ?__\-sign\_cert__ *dn\_to\_be\_signed* *ca\_depth*? ?__\-ssl__ *dn*?](#10)  
[__::pki::pkcs::create\_csr__ *keylist* *namelist* ?*encodePem*? ?*algo*?](#11)  
[__::pki::pkcs::parse\_csr__ *csr*](#12)  
[__::pki::x509::create\_cert__ *signreqlist* *cakeylist* *serial\_number* *notBefore* *notAfter* *isCA* *extensions* ?*encodePem*? ?*algo*?](#13)  

# <a name='description'></a>DESCRIPTION

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::pki::encrypt__ ?*\-binary*? ?*\-hex*? ?*\-pad*? ?*\-nopad*? ?*\-priv*? ?*\-pub*? ?*\-\-*? *input* *key*

    Encrypt a message using PKI \(probably RSA\)\.

    Requires the caller to specify either __\-priv__ to encrypt with the
    private key or __\-pub__ to encrypt with the public key\. The default
    option is to pad and return in hex\. One of __\-pub__ or __\-priv__
    must be specified\.

    The __\-hex__ option causes the data to be returned in encoded as a
    hexidecimal string, while the __\-binary__ option causes the data to be
    returned as a binary string\. If they are specified multiple times, the last
    one specified is used\.

    The __\-pad__ option causes the data to be padded per PKCS\#1 prior to
    being encrypted\. The __\-nopad__ inhibits this behaviour\. If they are
    specified multiple times, the last one specified is used\.

    The input to encrypt is specified as *input*\.

    The *key* parameter, holding the key to use, is a return value from either
    __::pki::pkcs::parse\_key__, __::pki::x509::parse\_cert__, or
    __::pki::rsa::generate__\.

    Mapping to OpenSSL's __openssl__ application:

      1. "openssl rsautl \-encrypt" == "::pki::encrypt \-binary \-pub"

      1. "openssl rsautl \-sign" == "::pki::encrypt \-binary \-priv"

  - <a name='2'></a>__::pki::decrypt__ ?*\-binary*? ?*\-hex*? ?*\-unpad*? ?*\-nounpad*? ?*\-priv*? ?*\-pub*? ?*\-\-*? *input* *key*

    Decrypt a message using PKI \(probably RSA\)\. See __::pki::encrypt__ for
    option handling\.

    Mapping to OpenSSL's __openssl__ application:

      1. "openssl rsautl \-decrypt" == "::pki::decrypt \-binary \-priv"

      1. "openssl rsautl \-verify" == "::pki::decrypt \-binary \-pub"

  - <a name='3'></a>__::pki::sign__ *input* *key* ?*algo*?

    Digitally sign message *input* using the private *key*\.

    If *algo* is ommited "sha1" is assumed\. Possible values for *algo*
    include "__md5__", "__sha1__", "__sha256__", and "__raw__"\.
    Specifying "__raw__" for *algo* will inhibit the building of an ASN\.1
    structure to encode which hashing algorithm was chosen\. *Attention*: In
    this case the corresponding __pkgi::verify__ must be called __with__
    algorithm information\. Conversely, specifying a non\-"__raw__" algorithm
    here means that the corresponding __pkgi::verify__ invokation has to be
    made *without* algorithm information\.

    The *input* should be the plain text, hashing will be performed on it\.

    The *key* should include the private key\.

  - <a name='4'></a>__::pki::verify__ *signedmessage* *plaintext* *key* ?*algo*?

    Verify a digital signature using a public *key*\. Returns true or false\.

    *Attention*: The algorithm information *algo* has to be specified if and
    only if the __pki::sign__ which generated the *signedmessage* was
    called with algorithm "__raw__"\. This inhibited the building of the
    ASN\.1 structure encoding the chosen hashing algorithm\. Conversely, if a
    proper algorithm was specified during signing then you *must not* specify
    an algorithm here\.

  - <a name='5'></a>__::pki::key__ *key* ?*password*? ?*encodePem*?

    Convert a key structure into a serialized PEM \(default\) or DER encoded
    private key suitable for other applications\. For RSA keys this means PKCS\#1\.

  - <a name='6'></a>__::pki::pkcs::parse\_key__ *key* ?*password*?

    Convert a PKCS\#1 private *key* into a usable key, i\.e\. one which can be
    used as argument for __::pki::encrypt__, __::pki::decrypt__,
    __::pki::sign__, and __::pki::verify__\.

  - <a name='7'></a>__::pki::x509::parse\_cert__ *cert*

    Convert an X\.509 certificate to a usable \(public\) key\. The returned
    dictionary can be used as argument for __::pki:encrypt__,
    __::pki::decrypt__, and __::pki::verify__\. The *cert* argument can
    be either PEM or DER encoded\. In addition to the public keying information,
    the dictionary contains the following keys containing certificate content as
    defined in
    [RFC5280](https://www\.rfc\-editor\.org/rfc/rfc5280\#section\-4\.1):

      * __subject__ holds the name of the subject from the certificate\.

      * __issuer__ holds the name of the issuing CA\.

      * __serial\_number__ holds the serial number of the certificate\.

      * __notBefore__ holds the starting date for certificate validity\.

      * __notAfter__ holds the ending date for certificate validity\.

      * __version__ holds the X\.509 version format\.

      * __extensions__ holds a dictionary containing the extensions included
        in the certificate \(see below\)\.

    The dictionary holds additional entries related to keying\. These are
    intended for use of the above\-mentioned commands for cryptographic
    operations\.

    The __extensions__ key in the returned dictionary holds a nested
    dictionary whose keys correspond to the names \(with same exact case\) in
    [Certificate
    Extensions](https://www\.rfc\-editor\.org/rfc/rfc5280\#section\-4\.2) in
    RFC5280\. The format of each value is also based on the ASN\.1 structures
    defined there\. See the [Examples](\#section3) for an illustration\.

  - <a name='8'></a>__::pki::rsa::generate__ *bitlength* ?*exponent*?

    Generate a new RSA key pair, the parts of which can be used as argument for
    __::pki::encrypt__, __::pki::decrypt__, __::pki::sign__, and
    __::pki::verify__\.

    The *bitlength* argument is the length of the public key modulus\.

    The *exponent* argument should generally not be specified unless you
    really know what you are doing\.

  - <a name='9'></a>__::pki::x509::verify\_cert__ *cert* *trustedcerts* ?*intermediatecerts*?

    Verify that a trust can be found between the certificate specified in the
    *cert* argument and one of the certificates specified in the list of
    certificates in the *trustedcerts* argument\. \(Eventually the chain can be
    through untrusted certificates listed in the *intermediatecerts* argument,
    but this is currently unimplemented\)\. The certificates specified in the
    *cert* and *trustedcerts* option should be parsed \(from
    __::pki::x509::parse\_cert__\)\.

  - <a name='10'></a>__::pki::x509::validate\_cert__ *cert* ?__\-sign\_message__ *dn\_of\_signer*? ?__\-encrypt\_message__ *dn\_of\_signer*? ?__\-sign\_cert__ *dn\_to\_be\_signed* *ca\_depth*? ?__\-ssl__ *dn*?

    Validate that a certificate is valid to be used in some capacity\. If
    multiple options are specified they must all be met for this procedure to
    return "true"\.

    Currently, only the __\-sign\_cert__ option is functional\. Its arguments
    are *dn\_to\_be\_signed* and *ca\_depth*\. The *dn\_to\_be\_signed* is the
    distinguished from the subject of a certificate to verify that the
    certificate specified in the *cert* argument can sign\. The *ca\_depth*
    argument is used to indicate at which depth the verification should be done
    at\. Some certificates are limited to how far down the chain they can be used
    to verify a given certificate\.

  - <a name='11'></a>__::pki::pkcs::create\_csr__ *keylist* *namelist* ?*encodePem*? ?*algo*?

    Generate a certificate signing request from a key pair specified in the
    *keylist* argument\.

    The *namelist* argument is a list of "name" followed by "value" pairs to
    encoding as the requested distinguished name in the CSR\.

    The *encodePem* option specifies whether or not the result should be PEM
    encoded or DER encoded\. A "true" value results in the result being PEM
    encoded, while any other value 9results in the the result being DER encoded\.
    DER encoding is the default\.

    The *algo* argument specifies the hashing algorithm we should use to sign
    this certificate signing request with\. The default is "sha1"\. Other possible
    values include "md5" and "sha256"\.

  - <a name='12'></a>__::pki::pkcs::parse\_csr__ *csr*

    Parse a Certificate Signing Request\. The *csr* argument can be either PEM
    or DER encoded\. The command returns a dictionary that includes the following
    keys:

      * __subject__ \- contains the subject name from the CSR\.

      * __type__ \- contains the public key algorithm name\. Currently only
        __rsa__ is supported\.

      * __extensionRequest__ \- contains a dictionary with the contents of
        the
        [__extensionRequest__](https://datatracker\.ietf\.org/doc/html/rfc2986\#page\-5)
        information in the CSR\. This has the same form as described for the
        __extensions__ dictionary in the documentation for
        __parse\_cert__\.

    There may be other keys in the dictionary related to the public key
    algorithm in use\.

  - <a name='13'></a>__::pki::x509::create\_cert__ *signreqlist* *cakeylist* *serial\_number* *notBefore* *notAfter* *isCA* *extensions* ?*encodePem*? ?*algo*?

    Sign a signing request \(usually from __::pki::pkcs::create\_csr__ or
    __::pki::pkcs::parse\_csr__\) with a Certificate Authority \(CA\)
    certificate\.

    The *signreqlist* argument should be the parsed signing request\.

    The *cakeylist* argument should be the parsed CA certificate\.

    The *serial\_number* argument should be a serial number unique to this
    certificate from this certificate authority\.

    The *notBefore* and *notAfter* arguments should contain the time before
    and after which \(respectively\) the certificate should be considered invalid\.
    The time should be encoded as something __clock format__ will accept
    \(i\.e\., the results of __clock seconds__ and __clock add__\)\.

    The *isCA* argument is a boolean argument describing whether or not the
    signed certificate should be a a CA certificate\. If specified as true the
    "id\-ce\-basicConstraints" extension is added with the arguments of "critical"
    being true, "allowCA" being true, and caDepth being \-1 \(infinite\)\.

    The *extensions* argument is a list of extensions and their parameters
    that should be encoded into the created certificate\. Currently only one
    extension is understood \("id\-ce\-basicConstraints"\)\. It accepts three
    arguments *critical* *allowCA* *caDepth*\. The *critical* argument to
    this extension \(and any extension\) whether or not the validator should
    reject the certificate as invalid if it does not understand the extension
    \(if set to "true"\) or should ignore the extension \(if set to "false"\)\. The
    *allowCA* argument is used to specify as a boolean value whether or not we
    can be used a certificate authority \(CA\)\. The *caDepth* argument indicates
    how many children CAs can be children of this CA in a depth\-wise fashion\. A
    value of "0" for the *caDepth* argument means that this CA cannot sign a
    CA certificate and have the result be valid\. A value of "\-1" indicates
    infinite depth\.

# <a name='section3'></a>EXAMPLES

The example below retrieves a certificate from *www\.example\.com* using the TLS
extension and dumps its content\.

    % set so [tls::socket www.example.com 443]
    sock00000229EB84E710
    % tls::handshake $so
    1
    % set status [tls::status $so]
    ...output not shown...
    % set cert_pem [dict get $status certificate]
    ...output not shown...
    % set cert [::pki::x509::parse_cert $cert_pem]
    ...output not shown...
    % dict get $cert subject
    C=US, ST=California, L=Los Angeles, O=Internet Corporation for Assigned Names and Numbers, CN=www.example.org
    % dict get $cert issuer
    C=US, O=DigiCert Inc, CN=DigiCert TLS RSA SHA256 2020 CA1
    % clock format [dict get $cert notAfter]
    Sun Dec 26 05:29:59 +0530 2021
    % set extensions [dict get $cert extensions]
    ...output not shown...
    % dict keys $extensions
    authorityKeyIdentifier subjectKeyIdentifier subjectAltName keyUsage extKeyUsage cRLDistributionPoints certificatePolicies authorityInfoAccess id-ce-basicConstraints basicConstraints 1.3.6.1.4.1.11129.2.4.2
    dict get $extensions basicConstraints
    1 {0 -1}
    % dict get $extensions keyUsage
    1 {5 digitalSignature keyEncipherment}
    % dict get $extensions extKeyUsage
    0 {serverAuth clientAuth}
    % dict get $extensions subjectAltName
    0 {dNSName www.example.org dNSName example.com dNSName example.edu dNSName example.net dNSName example.org dNSName www.example.com dNSName www.example.edu dNSName www.example.net}
    % dict get $extensions basicConstraints
    1 {0 -1}
    % dict get $extensions keyUsage
    1 {5 digitalSignature keyEncipherment}
    % dict get $extensions extKeyUsage
    0 {serverAuth clientAuth}

# <a name='section4'></a>REFERENCES

  1. [Internet X\.509 Public Key Infrastructure Certificate and Certificate
     Revocation List \(CRL\) Profile](https://www\.rfc\-editor\.org/rfc/rfc5280)

  1. [New ASN\.1 Modules for the Public Key Infrastructure Using X\.509
     \(PKIX\)](https://www\.rfc\-editor\.org/rfc/rfc5912)

  1. [PKCS \#10: Certification Request Syntax
     Specification](https://www\.rfc\-editor\.org/rfc/rfc2986)

# <a name='section5'></a>AUTHORS

Roy Keene, Ashok P\. Nadkarni

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *rsa* of the [Tcllib
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
[des\(n\)](\.\./des/des\.md), [md5\(n\)](\.\./md5/md5\.md),
[sha1\(n\)](\.\./sha1/sha1\.md)

# <a name='keywords'></a>KEYWORDS

[cipher](\.\./\.\./\.\./\.\./index\.md\#cipher), [data
integrity](\.\./\.\./\.\./\.\./index\.md\#data\_integrity),
[encryption](\.\./\.\./\.\./\.\./index\.md\#encryption), [public key
cipher](\.\./\.\./\.\./\.\./index\.md\#public\_key\_cipher),
[rsa](\.\./\.\./\.\./\.\./index\.md\#rsa),
[security](\.\./\.\./\.\./\.\./index\.md\#security)

# <a name='category'></a>CATEGORY

Hashes, checksums, and encryption

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2010, 2011, 2012, 2013, 2021 Roy Keene, Andreas Kupries, Ashok P\. Nadkarni
