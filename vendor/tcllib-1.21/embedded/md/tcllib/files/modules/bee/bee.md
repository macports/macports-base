
[//000000001]: # (bee \- BitTorrent)
[//000000002]: # (Generated from file 'bee\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (bee\(n\) 0\.1 tcllib "BitTorrent")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

bee \- BitTorrent Serialization Format Encoder/Decoder

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PUBLIC API](#section2)

      - [ENCODER](#subsection1)

      - [DECODER](#subsection2)

  - [FORMAT DEFINITION](#section3)

  - [EXAMPLES](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require bee ?0\.1?  

[__::bee::encodeString__ *string*](#1)  
[__::bee::encodeNumber__ *integer*](#2)  
[__::bee::encodeListArgs__ *value*\.\.\.](#3)  
[__::bee::encodeList__ *list*](#4)  
[__::bee::encodeDictArgs__ *key* *value*\.\.\.](#5)  
[__::bee::encodeDict__ *dict*](#6)  
[__::bee::decode__ *string* ?*endvar*? ?*start*?](#7)  
[__::bee::decodeIndices__ *string* ?*endvar*? ?*start*?](#8)  
[__::bee::decodeChannel__ *chan* __\-command__ *cmdprefix* ?__\-exact__? ?__\-prefix__ *data*?](#9)  
[__cmdprefix__ __eof__ *token*](#10)  
[__cmdprefix__ __error__ *token* *message*](#11)  
[__cmdprefix__ __value__ *token* *value*](#12)  
[__::bee::decodeCancel__ *token*](#13)  
[__::bee::decodePush__ *token* *string*](#14)  

# <a name='description'></a>DESCRIPTION

The __bee__ package provides de\- and encoder commands for data in bencoding
\(speak 'bee'\), the serialization format for data and messages used by the
BitTorrent protocol\.

# <a name='section2'></a>PUBLIC API

## <a name='subsection1'></a>ENCODER

The package provides one encoder command for each of the basic forms, and two
commands per container, one taking a proper tcl data structure to encode in the
container, the other taking the same information as several arguments\.

  - <a name='1'></a>__::bee::encodeString__ *string*

    Returns the bee\-encoding of the *string*\.

  - <a name='2'></a>__::bee::encodeNumber__ *integer*

    Returns the bee\-encoding of the *integer* number\.

  - <a name='3'></a>__::bee::encodeListArgs__ *value*\.\.\.

    Takes zero or more bee\-encoded values and returns the bee\-encoding of their
    list\.

  - <a name='4'></a>__::bee::encodeList__ *list*

    Takes a list of bee\-encoded values and returns the bee\-encoding of the list\.

  - <a name='5'></a>__::bee::encodeDictArgs__ *key* *value*\.\.\.

    Takes zero or more pairs of keys and values and returns the bee\-encoding of
    the dictionary they form\. The values are expected to be already bee\-encoded,
    but the keys must not be\. Their encoding will be done by the command itself\.

  - <a name='6'></a>__::bee::encodeDict__ *dict*

    Takes a dictionary list of string keys and bee\-encoded values and returns
    the bee\-encoding of the list\. Note that the keys in the input must not be
    bee\-encoded already\. This will be done by the command itself\.

## <a name='subsection2'></a>DECODER

The package provides two main decoder commands, one for decoding a string
expected to contain a complete data structure, the other for the incremental
decoding of bee\-values arriving on a channel\. The latter command is asynchronous
and provides the completed decoded values to the user through a command
callback\.

  - <a name='7'></a>__::bee::decode__ *string* ?*endvar*? ?*start*?

    Takes the bee\-encoding in the string and returns one decoded value\. In the
    case of this being a container all contained values are decoded recursively
    as well and the result is a properly nested tcl list and/or dictionary\.

    If the optional *endvar* is set then it is the name of a variable to store
    the index of the first character *after* the decoded value into\. In other
    words, if the string contains more than one value then *endvar* can be
    used to obtain the position of the bee\-value after the bee\-value currently
    decoded\. together with *start*, see below, it is possible to iterate over
    the string to extract all contained values\.

    The optional *start* index defaults to __0__, i\.e\. the beginning of
    the string\. It is the index of the first character of the bee\-encoded value
    to extract\.

  - <a name='8'></a>__::bee::decodeIndices__ *string* ?*endvar*? ?*start*?

    Takes the same arguments as __::bee::decode__ and returns the same
    information in *endvar*\. The result however is different\. Instead of the
    tcl value contained in the *string* it returns a list describing the value
    with respect to type and location \(indices for the first and last character
    of the bee\-value\)\. In case of a container the structure also contains the
    same information for all the embedded values\.

    Formally the results for the various types of bee\-values are:

      * string

        A list containing three elements:

          + The constant string __string__, denoting the type of the value\.

          + An integer number greater than or equal to zero\. This is the index
            of the first character of the bee\-value in the input *string*\.

          + An integer number greater than or equal to zero\. This is the index
            of the last character of the bee\-value in the input *string*\.

        *Note* that this information is present in the results for all four
        types of bee\-values, with only the first element changing according to
        the type of the value\.

      * integer

        The result is like for strings, except that the type element contains
        the constant string __integer__\.

      * list

        The result is like before, with two exceptions: One, the type element
        contains the constant string __list__\. And two, the result actually
        contains four elements\. The last element is new, and contains the index
        data as described here for all elements of the bee\-list\.

      * dictionary

        The result is like for strings, except that the type element contains
        the constant string __dict__\. A fourth element is present as well,
        with a slightly different structure than for lists\. The element is a
        dictionary mapping from the strings keys of the bee\-dictionary to a list
        containing two elements\. The first of them is the index information for
        the key, and the second element is the index information for the value
        the key maps to\. This structure is the only which contains not only
        index data, but actual values from the bee\-string\. While the index
        information of the keys is unique enough, i\.e\. serviceable as keys, they
        are not easy to navigate when trying to find particular element\. Using
        the actual keys makes this much easier\.

  - <a name='9'></a>__::bee::decodeChannel__ *chan* __\-command__ *cmdprefix* ?__\-exact__? ?__\-prefix__ *data*?

    The command creates a decoder for a series of bee\-values arriving on the
    channel *chan* and returns its handle\. This handle can be used to remove
    the decoder again\. Setting up another bee decoder on *chan* while a bee
    decoder is still active will fail with an error message\.

      * __\-command__

        The command prefix *cmdprefix* specified by the *required* option
        __\-command__ is used to report extracted values and exceptional
        situations \(error, and EOF on the channel\)\. The callback will be
        executed at the global level of the interpreter, with two or three
        arguments\. The exact call signatures are

          + <a name='10'></a>__cmdprefix__ __eof__ *token*

            The decoder has reached eof on the channel *chan*\. No further
            invocations of the callback will be made after this\. The channel has
            already been closed at the time of the call, and the *token* is
            not valid anymore as well\.

          + <a name='11'></a>__cmdprefix__ __error__ *token* *message*

            The decoder encountered an error, which is not eof\. For example a
            malformed bee\-value\. The *message* provides details about the
            error\. The decoder token is in the same state as for eof, i\.e\.
            invalid\. The channel however is kept open\.

          + <a name='12'></a>__cmdprefix__ __value__ *token* *value*

            The decoder received and successfully decoded a bee\-value\. The
            format of the equivalent tcl *value* is the same as returned by
            __::bee::decode__\. The channel is still open and the decoder
            token is valid\. This means that the callback is able to remove the
            decoder\.

      * __\-exact__

        By default the decoder assumes that the remainder of the data in the
        channel consists only of bee\-values, and reads as much as possible per
        event, without regard for boundaries between bee\-values\. This means that
        if the the input contains non\-bee data after a series of bee\-value the
        beginning of that data may be lost because it was already read by the
        decoder, but not processed\.

        The __\-exact__ was made for this situation\. When specified the
        decoder will take care to not read any characters behind the currently
        processed bee\-value, so that any non\-bee data is kept in the channel for
        further processing after removal of the decoder\.

      * __\-prefix__

        If this option is specified its value is assumed to be the beginning of
        the bee\-value and used to initialize the internal decoder buffer\. This
        feature is required if the creator of the decoder used data from the
        channel to determine if it should create the decoder or not\. Without the
        option this data would be lost to the decoding\.

  - <a name='13'></a>__::bee::decodeCancel__ *token*

    This command cancels the decoder set up by __::bee::decodeChannel__ and
    represented by the handle *token*\.

  - <a name='14'></a>__::bee::decodePush__ *token* *string*

    This command appends the *string* to the internal decoder buffer\. It is
    the runtime equivalent of the option __\-prefix__ of
    __::bee::decodeChannel__\. Use it to push data back into the decoder when
    the __value__ callback used data from the channel to determine if it
    should decode another bee\-value or not\.

# <a name='section3'></a>FORMAT DEFINITION

Data in the bee serialization format is constructed from two basic forms, and
two container forms\. The basic forms are strings and integer numbers, and the
containers are lists and dictionaries\.

  - String *S*

    A string *S* of length *L* is encoded by the string
    "*L*__:__*S*", where the length is written out in textual form\.

  - Integer *N*

    An integer number *N* is encoded by the string "__i__*N*__e__"\.

  - List *v1* \.\.\. *vn*

    A list of the values *v1* to *vn* is encoded by the string
    "__l__*BV1*\.\.\.*BVn*__e__" where "BV__i__" is the
    bee\-encoding of the value "v__i__"\.

  - Dict *k1* \-> *v1* \.\.\.

    A dictionary mapping the string key *k*__i__ to the value
    *v*__i__, for __i__ in __1__ \.\.\. __n__ is encoded by the
    string "__d__*BK*__i__*BV*__i__\.\.\.__e__" for i in
    __1__ \.\.\. __n__, where "BK__i__" is the bee\-encoding of the key
    string "k__i__"\. and "BV__i__" is the bee\-encoding of the value
    "v__i__"\.

    *Note*: The bee\-encoding does not retain the order of the keys in the
    input, but stores in a sorted order\. The sorting is done for the "raw
    strings"\.

Note that the type of each encoded item can be determined immediately from the
first character of its representation:

  - i

    Integer\.

  - l

    List\.

  - d

    Dictionary\.

  - \[0\-9\]

    String\.

By wrapping an integer number into __i__\.\.\.__e__ the format makes sure
that they are different from strings, which all begin with a digit\.

# <a name='section4'></a>EXAMPLES

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *bee* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[BitTorrent](\.\./\.\./\.\./\.\./index\.md\#bittorrent),
[bee](\.\./\.\./\.\./\.\./index\.md\#bee),
[bittorrent](\.\./\.\./\.\./\.\./index\.md\#bittorrent),
[serialization](\.\./\.\./\.\./\.\./index\.md\#serialization),
[torrent](\.\./\.\./\.\./\.\./index\.md\#torrent)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
