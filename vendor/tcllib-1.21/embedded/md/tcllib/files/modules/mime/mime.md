
[//000000001]: # (mime \- Mime)
[//000000002]: # (Generated from file 'mime\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 1999\-2000 Marshall T\. Rose)
[//000000004]: # (mime\(n\) 1\.6\.3 tcllib "Mime")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

mime \- Manipulation of MIME body parts

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [KNOWN BUGS](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require mime ?1\.6\.3?  

[__::mime::initialize__ ?__\-canonical__ *type/subtype* ?__\-param__ \{*key value*\}\.\.\.? ?__\-encoding__ *value*? ?__\-header__ \{*key value*\}\.\.\.?? \(__\-file__ *name* &#124; __\-string__ *value* &#124; __\-parts__ \{*token1* \.\.\. *tokenN*\}\)](#1)  
[__::mime::finalize__ *token* ?__\-subordinates__ __all__ &#124; __dynamic__ &#124; __none__?](#2)  
[__::mime::getproperty__ *token* ?*property* &#124; __\-names__?](#3)  
[__::mime::getheader__ *token* ?*key* &#124; __\-names__?](#4)  
[__::mime::setheader__ *token* *key value* ?__\-mode__ __write__ &#124; __append__ &#124; __delete__?](#5)  
[__::mime::getbody__ *token* ?__\-decode__? ?__\-command__ *callback* ?__\-blocksize__ *octets*??](#6)  
[__::mime::copymessage__ *token* *channel*](#7)  
[__::mime::buildmessage__ *token*](#8)  
[__::mime::parseaddress__ *string*](#9)  
[__::mime::parsedatetime__ \(*string* &#124; __\-now__\) *property*](#10)  
[__::mime::mapencoding__ *encoding\_name*](#11)  
[__::mime::reversemapencoding__ *charset\_type*](#12)  

# <a name='description'></a>DESCRIPTION

The __mime__ library package provides the commands to create and manipulate
MIME body parts\.

  - <a name='1'></a>__::mime::initialize__ ?__\-canonical__ *type/subtype* ?__\-param__ \{*key value*\}\.\.\.? ?__\-encoding__ *value*? ?__\-header__ \{*key value*\}\.\.\.?? \(__\-file__ *name* &#124; __\-string__ *value* &#124; __\-parts__ \{*token1* \.\.\. *tokenN*\}\)

    Creates a MIME part and returns a token representing it\.

      * If the __\-canonical__ option is present, then the body is in
        canonical \(raw\) form and is found by consulting either the
        __\-file__, __\-string__, or __\-parts__ option\.

        In addition, both the __\-param__ and __\-header__ options may
        occur zero or more times to specify __Content\-Type__ parameters
        \(e\.g\., __charset__\) and header keyword/values \(e\.g\.,
        __Content\-Disposition__\), respectively\.

        Also, __\-encoding__, if present, specifies the
        __Content\-Transfer\-Encoding__ when copying the body\.

      * If the __\-canonical__ option is not present, then the MIME part
        contained in either the __\-file__ or the __\-string__ option is
        parsed, dynamically generating subordinates as appropriate\.

  - <a name='2'></a>__::mime::finalize__ *token* ?__\-subordinates__ __all__ &#124; __dynamic__ &#124; __none__?

    Destroys the MIME part represented by *token*\. It returns an empty string\.

    If the __\-subordinates__ option is present, it specifies which
    subordinates should also be destroyed\. The default value is __dynamic__,
    destroying all subordinates which were created by __::mime::initialize__
    together with the containing body part\.

  - <a name='3'></a>__::mime::getproperty__ *token* ?*property* &#124; __\-names__?

    Returns a string or a list of strings containing the properties of a MIME
    part\. If the command is invoked with the name of a specific property, then
    the corresponding value is returned; instead, if __\-names__ is
    specified, a list of all properties is returned; otherwise, a serialized
    array of properties and values is returned\.

    The possible properties are:

      * __content__

        The type/subtype describing the content

      * __encoding__

        The "Content\-Transfer\-Encoding"

      * __params__

        A list of "Content\-Type" parameters

      * __parts__

        A list of tokens for the part's subordinates\. This property is present
        only if the MIME part has subordinates\.

      * __size__

        The approximate size of the content \(unencoded\)

  - <a name='4'></a>__::mime::getheader__ *token* ?*key* &#124; __\-names__?

    Returns the header of a MIME part as a dictionary with possibly\-redundant
    keys\.

    If *key* is provided, then a list of values of matching names, without
    regard to case, is returned\.

    If __\-names__ is provided, a list of all keys is returned\.

  - <a name='5'></a>__::mime::setheader__ *token* *key value* ?__\-mode__ __write__ &#124; __append__ &#124; __delete__?

    If __append__ is provided, creates a new header named *key* with the
    value of *value* is added\. If __write__ is provided, deletes any
    existing headers whose names match *key* and then creates a new header
    named *key* with the value of *value*\. If __delete__ is provided any
    existing header having a name that matches *key* is deleted\. Returns a
    list of strings containing the previous value associated with the key\.

    The value for __\-mode__ is one of:

      * __write__

        The *key*/*value* is either created or overwritten \(the default\)\.

      * __append__

        A new *value* is appended for the *key* \(creating it as necessary\)\.

      * __delete__

        All values associated with the key are removed \(the *value* parameter
        is ignored\)\.

  - <a name='6'></a>__::mime::getbody__ *token* ?__\-decode__? ?__\-command__ *callback* ?__\-blocksize__ *octets*??

    Returns a string containing the body of the leaf MIME part represented by
    *token* in canonical form\.

    If the __\-command__ option is present, then it is repeatedly invoked
    with a fragment of the body as this:

        uplevel #0 $callback [list "data" $fragment]

    \(The __\-blocksize__ option, if present, specifies the maximum size of
    each fragment passed to the callback\.\)

    When the end of the body is reached, the callback is invoked as:

        uplevel #0 $callback "end"

    Alternatively, if an error occurs, the callback is invoked as:

        uplevel #0 $callback [list "error" reason]

    Regardless, the return value of the final invocation of the callback is
    propagated upwards by __::mime::getbody__\.

    If the __\-command__ option is absent, then the return value of
    __::mime::getbody__ is a string containing the MIME part's entire body\.

    If the option __\-decode__ is absent the return value computed above is
    returned as is\. This means that it will be in the charset specified for the
    token and not the usual utf\-8\. If the option __\-decode__ is present
    however the command will use the charset information associated with the
    token to convert the string from its encoding into utf\-8 before returning
    it\.

  - <a name='7'></a>__::mime::copymessage__ *token* *channel*

    Copies the MIME represented by *token* part to the specified *channel*\.
    The command operates synchronously, and uses fileevent to allow asynchronous
    operations to proceed independently\. It returns an empty string\.

  - <a name='8'></a>__::mime::buildmessage__ *token*

    Returns the MIME part represented by *token* as a string\. It is similar to
    __::mime::copymessage__, only it returns the data as a return string
    instead of writing to a channel\.

  - <a name='9'></a>__::mime::parseaddress__ *string*

    Takes a string containing one or more 822\-style address specifications and
    returns a list of serialized arrays, one element for each address specified
    in the argument\. If the string contains more than one address they will be
    separated by commas\.

    Each serialized array contains the properties below\. Note that one or more
    of these properties may be empty\.

      * __address__

        local@domain

      * __comment__

        822\-style comment

      * __domain__

        the domain part \(rhs\)

      * __error__

        non\-empty on a parse error

      * __group__

        this address begins a group

      * __friendly__

        user\-friendly rendering

      * __local__

        the local part \(lhs\)

      * __memberP__

        this address belongs to a group

      * __phrase__

        the phrase part

      * __proper__

        822\-style address specification

      * __route__

        822\-style route specification \(obsolete\)

  - <a name='10'></a>__::mime::parsedatetime__ \(*string* &#124; __\-now__\) *property*

    Takes a string containing an 822\-style date\-time specification and returns
    the specified property as a serialized array\.

    The list of properties and their ranges are:

      * __hour__

        0 \.\. 23

      * __lmonth__

        January, February, \.\.\., December

      * __lweekday__

        Sunday, Monday, \.\.\. Saturday

      * __mday__

        1 \.\. 31

      * __min__

        0 \.\. 59

      * __mon__

        1 \.\. 12

      * __month__

        Jan, Feb, \.\.\., Dec

      * __proper__

        822\-style date\-time specification

      * __rclock__

        elapsed seconds between then and now

      * __sec__

        0 \.\. 59

      * __wday__

        0 \.\. 6 \(Sun \.\. Mon\)

      * __weekday__

        Sun, Mon, \.\.\., Sat

      * __yday__

        1 \.\. 366

      * __year__

        1900 \.\.\.

      * __zone__

        \-720 \.\. 720 \(minutes east of GMT\)

  - <a name='11'></a>__::mime::mapencoding__ *encoding\_name*

    Maps tcl encodings onto the proper names for their MIME charset type\. This
    is only done for encodings whose charset types were known\. The remaining
    encodings return "" for now\.

  - <a name='12'></a>__::mime::reversemapencoding__ *charset\_type*

    Maps MIME charset types onto tcl encoding names\. Those that are unknown
    return ""\.

# <a name='section2'></a>KNOWN BUGS

  - Tcllib Bug \#447037

    This problem affects only people which are using Tcl and Mime on a 64\-bit
    system\. The currently recommended fix for this problem is to upgrade to Tcl
    version 8\.4\. This version has extended 64 bit support and the bug does not
    appear anymore\.

    The problem could have been generally solved by requiring the use of Tcl 8\.4
    for this package\. We decided against this solution as it would force a large
    number of unaffected users to upgrade their Tcl interpreter for no reason\.

    See [Ticket 447037](/tktview?name=447037) for additional information\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *mime* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[ftp](\.\./ftp/ftp\.md), [http](\.\./\.\./\.\./\.\./index\.md\#http),
[pop3](\.\./pop3/pop3\.md), [smtp](smtp\.md)

# <a name='keywords'></a>KEYWORDS

[email](\.\./\.\./\.\./\.\./index\.md\#email),
[internet](\.\./\.\./\.\./\.\./index\.md\#internet),
[mail](\.\./\.\./\.\./\.\./index\.md\#mail), [mime](\.\./\.\./\.\./\.\./index\.md\#mime),
[net](\.\./\.\./\.\./\.\./index\.md\#net), [rfc
2045](\.\./\.\./\.\./\.\./index\.md\#rfc\_2045), [rfc
2046](\.\./\.\./\.\./\.\./index\.md\#rfc\_2046), [rfc
2049](\.\./\.\./\.\./\.\./index\.md\#rfc\_2049), [rfc
821](\.\./\.\./\.\./\.\./index\.md\#rfc\_821), [rfc
822](\.\./\.\./\.\./\.\./index\.md\#rfc\_822), [smtp](\.\./\.\./\.\./\.\./index\.md\#smtp)

# <a name='category'></a>CATEGORY

Text processing

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 1999\-2000 Marshall T\. Rose
