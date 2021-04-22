
[//000000001]: # (asn \- ASN\.1 processing)
[//000000002]: # (Generated from file 'asn\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (Copyright &copy; 2004 Jochen Loewer <loewerj@web\.de>)
[//000000005]: # (Copyright &copy; 2004\-2011 Michael Schlenker <mic42@users\.sourceforge\.net>)
[//000000006]: # (asn\(n\) 0\.8 tcllib "ASN\.1 processing")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

asn \- ASN\.1 BER encoder/decoder

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PUBLIC API](#section2)

      - [ENCODER](#subsection1)

      - [DECODER](#subsection2)

      - [HANDLING TAGS](#subsection3)

  - [EXAMPLES](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require asn ?0\.8\.4?  

[__::asn::asnSequence__ *evalue*\.\.\.](#1)  
[__::asn::asnSequenceFromList__ *elist*](#2)  
[__::asn::asnSet__ *evalue*\.\.\.](#3)  
[__::asn::asnSetFromList__ *elist*](#4)  
[__::asn::asnApplicationConstr__ *appNumber* *evalue*\.\.\.](#5)  
[__::asn::asnApplication__ *appNumber* *data*](#6)  
[__::asn::asnChoice__ *appNumber* *evalue*\.\.\.](#7)  
[__::asn::asnChoiceConstr__ *appNumber* *evalue*\.\.\.](#8)  
[__::asn::asnInteger__ *number*](#9)  
[__::asn::asnEnumeration__ *number*](#10)  
[__::asn::asnBoolean__ *bool*](#11)  
[__::asn::asnContext__ *context* *data*](#12)  
[__::asn::asnContextConstr__ *context* *evalue*\.\.\.](#13)  
[__::asn::asnObjectIdentifier__ *idlist*](#14)  
[__::asn::asnUTCTime__ *utcstring*](#15)  
[__::asn::asnNull__](#16)  
[__::asn::asnBitString__ *string*](#17)  
[__::asn::asnOctetString__ *string*](#18)  
[__::asn::asnNumericString__ *string*](#19)  
[__::asn::asnPrintableString__ *string*](#20)  
[__::asn::asnIA5String__ *string*](#21)  
[__::asn::asnBMPString__ *string*](#22)  
[__::asn::asnUTF8String__ *string*](#23)  
[__::asn::asnString__ *string*](#24)  
[__::asn::defaultStringType__ ?*type*?](#25)  
[__::asn::asnPeekByte__ *data\_var* *byte\_var*](#26)  
[__::asn::asnGetLength__ *data\_var* *length\_var*](#27)  
[__::asn::asnGetResponse__ *chan* *data\_var*](#28)  
[__::asn::asnGetInteger__ *data\_var* *int\_var*](#29)  
[__::asn::asnGetEnumeration__ *data\_var* *enum\_var*](#30)  
[__::asn::asnGetOctetString__ *data\_var* *string\_var*](#31)  
[__::asn::asnGetString__ *data\_var* *string\_var* ?*type\_var*?](#32)  
[__::asn::asnGetNumericString__ *data\_var* *string\_var*](#33)  
[__::asn::asnGetPrintableString__ *data\_var* *string\_var*](#34)  
[__::asn::asnGetIA5String__ *data\_var* *string\_var*](#35)  
[__::asn::asnGetBMPString__ *data\_var* *string\_var*](#36)  
[__::asn::asnGetUTF8String__ *data\_var* *string\_var*](#37)  
[__::asn::asnGetUTCTime__ *data\_var* *utc\_var*](#38)  
[__::asn::asnGetBitString__ *data\_var* *bits\_var*](#39)  
[__::asn::asnGetObjectIdentifier__ *data\_var* *oid\_var*](#40)  
[__::asn::asnGetBoolean__ *data\_var* *bool\_var*](#41)  
[__::asn::asnGetNull__ *data\_var*](#42)  
[__::asn::asnGetSequence__ *data\_var* *sequence\_var*](#43)  
[__::asn::asnGetSet__ *data\_var* *set\_var*](#44)  
[__::asn::asnGetApplication__ *data\_var* *appNumber\_var* ?*content\_var*? ?*encodingType\_var*?](#45)  
[__::asn::asnGetContext__ *data\_var* *contextNumber\_var* ?*content\_var*? ?*encodingType\_var*?](#46)  
[__::asn::asnPeekTag__ *data\_var* *tag\_var* *tagtype\_var* *constr\_var*](#47)  
[__::asn::asnTag__ *tagnumber* ?*class*? ?*tagstyle*?](#48)  
[__::asn::asnRetag__ *data\_var* *newTag*](#49)  

# <a name='description'></a>DESCRIPTION

The __asn__ package provides *partial* de\- and encoder commands for BER
encoded ASN\.1 data\. It can also be used for decoding DER, which is a restricted
subset of BER\.

ASN\.1 is a standard *Abstract Syntax Notation*, and BER are its *Basic
Encoding Rules*\.

See
[http://asn1\.elibel\.tm\.fr/en/standards/index\.htm](http://asn1\.elibel\.tm\.fr/en/standards/index\.htm)
for more information about the standard\.

Also see
[http://luca\.ntop\.org/Teaching/Appunti/asn1\.html](http://luca\.ntop\.org/Teaching/Appunti/asn1\.html)
for *A Layman's Guide to a Subset of ASN\.1, BER, and DER*, an RSA Laboratories
Technical Note by Burton S\. Kaliski Jr\. \(Revised November 1, 1993\)\. A text
version of this note is part of the module sources and should be read by any
implementor\.

# <a name='section2'></a>PUBLIC API

## <a name='subsection1'></a>ENCODER

  - <a name='1'></a>__::asn::asnSequence__ *evalue*\.\.\.

    Takes zero or more encoded values, packs them into an ASN sequence and
    returns its encoded binary form\.

  - <a name='2'></a>__::asn::asnSequenceFromList__ *elist*

    Takes a list of encoded values, packs them into an ASN sequence and returns
    its encoded binary form\.

  - <a name='3'></a>__::asn::asnSet__ *evalue*\.\.\.

    Takes zero or more encoded values, packs them into an ASN set and returns
    its encoded binary form\.

  - <a name='4'></a>__::asn::asnSetFromList__ *elist*

    Takes a list of encoded values, packs them into an ASN set and returns its
    encoded binary form\.

  - <a name='5'></a>__::asn::asnApplicationConstr__ *appNumber* *evalue*\.\.\.

    Takes zero or more encoded values, packs them into an ASN application
    construct and returns its encoded binary form\.

  - <a name='6'></a>__::asn::asnApplication__ *appNumber* *data*

    Takes a single encoded value *data*, packs it into an ASN application
    construct and returns its encoded binary form\.

  - <a name='7'></a>__::asn::asnChoice__ *appNumber* *evalue*\.\.\.

    Takes zero or more encoded values, packs them into an ASN choice construct
    and returns its encoded binary form\.

  - <a name='8'></a>__::asn::asnChoiceConstr__ *appNumber* *evalue*\.\.\.

    Takes zero or more encoded values, packs them into an ASN choice construct
    and returns its encoded binary form\.

  - <a name='9'></a>__::asn::asnInteger__ *number*

    Returns the encoded form of the specified integer *number*\.

  - <a name='10'></a>__::asn::asnEnumeration__ *number*

    Returns the encoded form of the specified enumeration id *number*\.

  - <a name='11'></a>__::asn::asnBoolean__ *bool*

    Returns the encoded form of the specified boolean value *bool*\.

  - <a name='12'></a>__::asn::asnContext__ *context* *data*

    Takes an encoded value and packs it into a constructed value with
    application tag, the *context* number\.

  - <a name='13'></a>__::asn::asnContextConstr__ *context* *evalue*\.\.\.

    Takes zero or more encoded values and packs them into a constructed value
    with application tag, the *context* number\.

  - <a name='14'></a>__::asn::asnObjectIdentifier__ *idlist*

    Takes a list of at least 2 integers describing an object identifier \(OID\)
    value, and returns the encoded value\.

  - <a name='15'></a>__::asn::asnUTCTime__ *utcstring*

    Returns the encoded form of the specified UTC time string\.

  - <a name='16'></a>__::asn::asnNull__

    Returns the NULL encoding\.

  - <a name='17'></a>__::asn::asnBitString__ *string*

    Returns the encoded form of the specified *string*\.

  - <a name='18'></a>__::asn::asnOctetString__ *string*

    Returns the encoded form of the specified *string*\.

  - <a name='19'></a>__::asn::asnNumericString__ *string*

    Returns the *string* encoded as ASN\.1 NumericString\. Raises an error if
    the *string* contains characters other than decimal numbers and space\.

  - <a name='20'></a>__::asn::asnPrintableString__ *string*

    Returns the *string* encoding as ASN\.1 PrintableString\. Raises an error if
    the *string* contains characters which are not allowed by the Printable
    String datatype\. The allowed characters are A\-Z, a\-z, 0\-9, space,
    apostrophe, colon, parentheses, plus, minus, comma, period, forward slash,
    question mark, and the equals sign\.

  - <a name='21'></a>__::asn::asnIA5String__ *string*

    Returns the *string* encoded as ASN\.1 IA5String\. Raises an error if the
    *string* contains any characters outside of the US\-ASCII range\.

  - <a name='22'></a>__::asn::asnBMPString__ *string*

    Returns the *string* encoded as ASN\.1 Basic Multilingual Plane string
    \(Which is essentialy big\-endian UCS2\)\.

  - <a name='23'></a>__::asn::asnUTF8String__ *string*

    Returns the *string* encoded as UTF8 String\. Note that some legacy
    applications such as Windows CryptoAPI do not like UTF8 strings\. Use
    BMPStrings if you are not sure\.

  - <a name='24'></a>__::asn::asnString__ *string*

    Returns an encoded form of *string*, choosing the most restricted ASN\.1
    string type possible\. If the string contains non\-ASCII characters, then
    there is more than one string type which can be used\. See
    __::asn::defaultStringType__\.

  - <a name='25'></a>__::asn::defaultStringType__ ?*type*?

    Selects the string type to use for the encoding of non\-ASCII strings\.
    Returns current default when called without argument\. If the argument
    *type* is supplied, it should be either __UTF8__ or __BMP__ to
    choose UTF8String or BMPString respectively\.

## <a name='subsection2'></a>DECODER

General notes:

  1. Nearly all decoder commands take two arguments\. These arguments are
     variable names, except for __::asn::asnGetResponse__\. The first
     variable contains the encoded ASN value to decode at the beginning, and
     more, and the second variable is where the value is stored to\. The
     remainder of the input after the decoded value is stored back into the
     datavariable\.

  1. After extraction the data variable is always modified first, before by
     writing the extracted value to its variable\. This means that if both
     arguments refer to the same variable, it will always contain the extracted
     value after the call, and not the remainder of the input\.

  - <a name='26'></a>__::asn::asnPeekByte__ *data\_var* *byte\_var*

    Retrieve the first byte of the data, without modifing *data\_var*\. This can
    be used to check for implicit tags\.

  - <a name='27'></a>__::asn::asnGetLength__ *data\_var* *length\_var*

    Decode the length information for a block of BER data\. The tag has already
    to be removed from the data\.

  - <a name='28'></a>__::asn::asnGetResponse__ *chan* *data\_var*

    Reads an encoded ASN *sequence* from the channel *chan* and stores it
    into the variable named by *data\_var*\.

  - <a name='29'></a>__::asn::asnGetInteger__ *data\_var* *int\_var*

    Assumes that an encoded integer value is at the front of the data stored in
    the variable named *data\_var*, extracts and stores it into the variable
    named by *int\_var*\. Additionally removes all bytes associated with the
    value from the data for further processing by the following decoder
    commands\.

  - <a name='30'></a>__::asn::asnGetEnumeration__ *data\_var* *enum\_var*

    Assumes that an enumeration id is at the front of the data stored in the
    variable named *data\_var*, and stores it into the variable named by
    *enum\_var*\. Additionally removes all bytes associated with the value from
    the data for further processing by the following decoder commands\.

  - <a name='31'></a>__::asn::asnGetOctetString__ *data\_var* *string\_var*

    Assumes that a string is at the front of the data stored in the variable
    named *data\_var*, and stores it into the variable named by *string\_var*\.
    Additionally removes all bytes associated with the value from the data for
    further processing by the following decoder commands\.

  - <a name='32'></a>__::asn::asnGetString__ *data\_var* *string\_var* ?*type\_var*?

    Decodes a user\-readable string\. This is a convenience function which is able
    to automatically distinguish all supported ASN\.1 string types and convert
    the input value appropriately\. See __::asn::asnGetPrintableString__,
    __::asnGetIA5String__, etc\. below for the type\-specific conversion
    commands\.

    If the optional third argument *type\_var* is supplied, then the type of
    the incoming string is stored in the variable named by it\.

    The function throws the error "Invalid command name
    asnGetSome__UnsupportedString__" if the unsupported string type
    __Unsupported__ is encountered\. You can create the appropriate function
    "asn::asnGetSome__UnsupportedString__" in your application if
    neccessary\.

  - <a name='33'></a>__::asn::asnGetNumericString__ *data\_var* *string\_var*

    Assumes that a numeric string value is at the front of the data stored in
    the variable named *data\_var*, and stores it into the variable named by
    *string\_var*\. Additionally removes all bytes associated with the value
    from the data for further processing by the following decoder commands\.

  - <a name='34'></a>__::asn::asnGetPrintableString__ *data\_var* *string\_var*

    Assumes that a printable string value is at the front of the data stored in
    the variable named *data\_var*, and stores it into the variable named by
    *string\_var*\. Additionally removes all bytes associated with the value
    from the data for further processing by the following decoder commands\.

  - <a name='35'></a>__::asn::asnGetIA5String__ *data\_var* *string\_var*

    Assumes that a IA5 \(ASCII\) string value is at the front of the data stored
    in the variable named *data\_var*, and stores it into the variable named by
    *string\_var*\. Additionally removes all bytes associated with the value
    from the data for further processing by the following decoder commands\.

  - <a name='36'></a>__::asn::asnGetBMPString__ *data\_var* *string\_var*

    Assumes that a BMP \(two\-byte unicode\) string value is at the front of the
    data stored in the variable named *data\_var*, and stores it into the
    variable named by *string\_var*, converting it into a proper Tcl string\.
    Additionally removes all bytes associated with the value from the data for
    further processing by the following decoder commands\.

  - <a name='37'></a>__::asn::asnGetUTF8String__ *data\_var* *string\_var*

    Assumes that a UTF8 string value is at the front of the data stored in the
    variable named *data\_var*, and stores it into the variable named by
    *string\_var*, converting it into a proper Tcl string\. Additionally removes
    all bytes associated with the value from the data for further processing by
    the following decoder commands\.

  - <a name='38'></a>__::asn::asnGetUTCTime__ *data\_var* *utc\_var*

    Assumes that a UTC time value is at the front of the data stored in the
    variable named *data\_var*, and stores it into the variable named by
    *utc\_var*\. The UTC time value is stored as a string, which has to be
    decoded with the usual clock scan commands\. Additionally removes all bytes
    associated with the value from the data for further processing by the
    following decoder commands\.

  - <a name='39'></a>__::asn::asnGetBitString__ *data\_var* *bits\_var*

    Assumes that a bit string value is at the front of the data stored in the
    variable named *data\_var*, and stores it into the variable named by
    *bits\_var* as a string containing only 0 and 1\. Additionally removes all
    bytes associated with the value from the data for further processing by the
    following decoder commands\.

  - <a name='40'></a>__::asn::asnGetObjectIdentifier__ *data\_var* *oid\_var*

    Assumes that a object identifier \(OID\) value is at the front of the data
    stored in the variable named *data\_var*, and stores it into the variable
    named by *oid\_var* as a list of integers\. Additionally removes all bytes
    associated with the value from the data for further processing by the
    following decoder commands\.

  - <a name='41'></a>__::asn::asnGetBoolean__ *data\_var* *bool\_var*

    Assumes that a boolean value is at the front of the data stored in the
    variable named *data\_var*, and stores it into the variable named by
    *bool\_var*\. Additionally removes all bytes associated with the value from
    the data for further processing by the following decoder commands\.

  - <a name='42'></a>__::asn::asnGetNull__ *data\_var*

    Assumes that a NULL value is at the front of the data stored in the variable
    named *data\_var* and removes the bytes used to encode it from the data\.

  - <a name='43'></a>__::asn::asnGetSequence__ *data\_var* *sequence\_var*

    Assumes that an ASN sequence is at the front of the data stored in the
    variable named *data\_var*, and stores it into the variable named by
    *sequence\_var*\. Additionally removes all bytes associated with the value
    from the data for further processing by the following decoder commands\.

    The data in *sequence\_var* is encoded binary and has to be further decoded
    according to the definition of the sequence, using the decoder commands
    here\.

  - <a name='44'></a>__::asn::asnGetSet__ *data\_var* *set\_var*

    Assumes that an ASN set is at the front of the data stored in the variable
    named *data\_var*, and stores it into the variable named by *set\_var*\.
    Additionally removes all bytes associated with the value from the data for
    further processing by the following decoder commands\.

    The data in *set\_var* is encoded binary and has to be further decoded
    according to the definition of the set, using the decoder commands here\.

  - <a name='45'></a>__::asn::asnGetApplication__ *data\_var* *appNumber\_var* ?*content\_var*? ?*encodingType\_var*?

    Assumes that an ASN application construct is at the front of the data stored
    in the variable named *data\_var*, and stores its id into the variable
    named by *appNumber\_var*\. Additionally removes all bytes associated with
    the value from the data for further processing by the following decoder
    commands\. If a *content\_var* is specified, then the command places all
    data associated with it into the named variable, in the binary form which
    can be processed using the decoder commands of this package\. If a
    *encodingType\_var* is specified, then that var is set to 1 if the encoding
    is constructed and 0 if it is primitive\.

    Otherwise it is the responsibility of the caller to decode the remainder of
    the application construct based on the id retrieved by this command, using
    the decoder commands of this package\.

  - <a name='46'></a>__::asn::asnGetContext__ *data\_var* *contextNumber\_var* ?*content\_var*? ?*encodingType\_var*?

    Assumes that an ASN context tag construct is at the front of the data stored
    in the variable named *data\_var*, and stores its id into the variable
    named by *contextNumber\_var*\. Additionally removes all bytes associated
    with the value from the data for further processing by the following decoder
    commands\. If a *content\_var* is specified, then the command places all
    data associated with it into the named variable, in the binary form which
    can be processed using the decoder commands of this package\. If a
    *encodingType\_var* is specified, then that var is set to 1 if the encoding
    is constructed and 0 if it is primitive\.

    Otherwise it is the responsibility of the caller to decode the remainder of
    the construct based on the id retrieved by this command, using the decoder
    commands of this package\.

## <a name='subsection3'></a>HANDLING TAGS

Working with ASN\.1 you often need to decode tagged values, which use a tag thats
different from the universal tag for a type\. In those cases you have to replace
the tag with the universal tag used for the type, to decode the value\. To decode
a tagged value use the __::asn::asnRetag__ to change the tag to the
appropriate type to use one of the decoders for primitive values\. To help with
this the module contains three functions:

  - <a name='47'></a>__::asn::asnPeekTag__ *data\_var* *tag\_var* *tagtype\_var* *constr\_var*

    The __::asn::asnPeekTag__ command can be used to take a peek at the data
    and decode the tag value, without removing it from the data\. The *tag\_var*
    gets set to the tag number, while the *tagtype\_var* gets set to the class
    of the tag\. \(Either UNIVERSAL, CONTEXT, APPLICATION or PRIVATE\)\. The
    *constr\_var* is set to 1 if the tag is for a constructed value, and to 0
    for not constructed\. It returns the length of the tag\.

  - <a name='48'></a>__::asn::asnTag__ *tagnumber* ?*class*? ?*tagstyle*?

    The __::asn::asnTag__ can be used to create a tag value\. The
    *tagnumber* gives the number of the tag, while the *class* gives one of
    the classes \(UNIVERSAL,CONTEXT,APPLICATION or PRIVATE\)\. The class may be
    abbreviated to just the first letter \(U,C,A,P\), default is UNIVERSAL\. The
    *tagstyle* is either C for Constructed encoding, or P for primitve
    encoding\. It defaults to P\. You can also use 1 instead of C and 0 instead of
    P for direct use of the values returned by __::asn::asnPeekTag__\.

  - <a name='49'></a>__::asn::asnRetag__ *data\_var* *newTag*

    Replaces the tag in front of the data in *data\_var* with *newTag*\. The
    new Tag can be created using the __::asn::asnTag__ command\.

# <a name='section3'></a>EXAMPLES

Examples for the usage of this package can be found in the implementation of
package __[ldap](\.\./ldap/ldap\.md)__\.

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *asn* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[asn](\.\./\.\./\.\./\.\./index\.md\#asn), [ber](\.\./\.\./\.\./\.\./index\.md\#ber),
[cer](\.\./\.\./\.\./\.\./index\.md\#cer), [der](\.\./\.\./\.\./\.\./index\.md\#der),
[internet](\.\./\.\./\.\./\.\./index\.md\#internet),
[protocol](\.\./\.\./\.\./\.\./index\.md\#protocol),
[x\.208](\.\./\.\./\.\./\.\./index\.md\#x\_208), [x\.209](\.\./\.\./\.\./\.\./index\.md\#x\_209)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>  
Copyright &copy; 2004 Jochen Loewer <loewerj@web\.de>  
Copyright &copy; 2004\-2011 Michael Schlenker <mic42@users\.sourceforge\.net>
