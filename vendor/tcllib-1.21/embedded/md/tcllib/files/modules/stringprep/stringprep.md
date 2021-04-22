
[//000000001]: # (stringprep \- Preparation of Internationalized Strings)
[//000000002]: # (Generated from file 'stringprep\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007\-2009, Sergei Golovan <sgolovan@nes\.ru>)
[//000000004]: # (stringprep\(n\) 1\.0\.1 tcllib "Preparation of Internationalized Strings")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

stringprep \- Implementation of stringprep

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

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.3  
package require stringprep 1\.0\.1  

[__::stringprep::register__ *profile* ?*\-mapping list*? ?*\-normalization form*? ?*\-prohibited list*? ?*\-prohibitedList list*? ?*\-prohibitedCommand command*? ?*\-prohibitedBidi boolean*?](#1)  
[__::stringprep::stringprep__ *profile* *string*](#2)  
[__::stringprep::compare__ *profile* *string1* *string2*](#3)  

# <a name='description'></a>DESCRIPTION

This is an implementation in Tcl of the Preparation of Internationalized Strings
\("stringprep"\)\. It allows to define stringprep profiles and use them to prepare
Unicode strings for comparison as defined in RFC\-3454\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::stringprep::register__ *profile* ?*\-mapping list*? ?*\-normalization form*? ?*\-prohibited list*? ?*\-prohibitedList list*? ?*\-prohibitedCommand command*? ?*\-prohibitedBidi boolean*?

    Register the __stringprep__ profile named *profile*\. Options are the
    following\.

    Option *\-mapping* specifies __stringprep__ mapping tables\. This
    parameter takes list of tables from appendix B of RFC\-3454\. The usual list
    values are \{B\.1 B\.2\} or \{B\.1 B\.3\} where B\.1 contains characters which
    commonly map to nothing, B\.3 specifies case folding, and B\.2 is used in
    profiles with unicode normalization form KC\. Defult value is \{\} which means
    no mapping\.

    Option *\-normalization* takes a string and if it is nonempty then it uses
    as a name of Unicode normalization form\. Any value of "D", "C", "KD" or "KC"
    may be used, though RFC\-3454 defines only two options: no normalization or
    normalization using form KC\.

    Option *\-prohibited* takes a list of RFC\-3454 tables with prohibited
    characters\. Current version does allow to prohibit either all tables from
    C\.3 to C\.9 or neither of them\. An example of this list for RFC\-3491 is \{A\.1
    C\.1\.2 C\.2\.2 C\.3 C\.4 C\.5 C\.6 C\.7 C\.8 C\.9\}\.

    Option *\-prohibitedList* specifies a list of additional prohibited
    characters\. The list contains not characters themselves but their Unicode
    numbers\. For example, Nodeprep specification from RFC\-3920 forbids the
    following codes: \{0x22 0x26 0x27 0x2f 0x3a 0x3c 0x3e 0x40\} \(\\" \\& \\' / : < >
    @\)\.

    Option *\-prohibitedCommand* specifies a command which is called for every
    character code in mapped and normalized string\. If the command returns true
    then the character is considered prohibited\. This option is useful when a
    list for *\-prohibitedList* is too large\.

    Option *\-prohibitedBidi* takes boolean value and if it is true then the
    bidirectional character processing rules defined in section 6 of RFC\-3454
    are used\.

  - <a name='2'></a>__::stringprep::stringprep__ *profile* *string*

    Performs __stringprep__ operations defined in profile *profile* to
    string *string*\. Result is a prepared string or one of the following
    errors: *invalid\_profile* \(profile *profile* is not defined\),
    *prohibited\_character* \(string *string* contains a prohibited character\)
    or *prohibited\_bidi* \(string *string* contains a prohibited
    bidirectional sequence\)\.

  - <a name='3'></a>__::stringprep::compare__ *profile* *string1* *string2*

    Compares two unicode strings prepared accordingly to __stringprep__
    profile *profile*\. The command returns 0 if prepared strings are equal, \-1
    if *string1* is lexicographically less than *string2*, or 1 if
    *string1* is lexicographically greater than *string2*\.

# <a name='section3'></a>EXAMPLES

Nameprep profile definition \(see RFC\-3491\):

    ::stringprep::register nameprep  -mapping {B.1 B.2}  -normalization KC  -prohibited {A.1 C.1.2 C.2.2 C.3 C.4 C.5 C.6 C.7 C.8 C.9}  -prohibitedBidi 1

Nodeprep and resourceprep profile definitions \(see RFC\-3920\):

    ::stringprep::register nodeprep  -mapping {B.1 B.2}  -normalization KC  -prohibited {A.1 C.1.1 C.1.2 C.2.1 C.2.2 C.3 C.4 C.5 C.6 C.7 C.8 C.9}  -prohibitedList {0x22 0x26 0x27 0x2f 0x3a 0x3c 0x3e 0x40}  -prohibitedBidi 1

    ::stringprep::register resourceprep  -mapping {B.1}  -normalization KC  -prohibited {A.1 C.1.2 C.2.1 C.2.2 C.3 C.4 C.5 C.6 C.7 C.8 C.9}  -prohibitedBidi 1

# <a name='section4'></a>REFERENCES

  1. "Preparation of Internationalized Strings \('stringprep'\)",
     \([http://www\.ietf\.org/rfc/rfc3454\.txt](http://www\.ietf\.org/rfc/rfc3454\.txt)\)

  1. "Nameprep: A Stringprep Profile for Internationalized Domain Names \(IDN\)",
     \([http://www\.ietf\.org/rfc/rfc3491\.txt](http://www\.ietf\.org/rfc/rfc3491\.txt)\)

  1. "Extensible Messaging and Presence Protocol \(XMPP\): Core",
     \([http://www\.ietf\.org/rfc/rfc3920\.txt](http://www\.ietf\.org/rfc/rfc3920\.txt)\)

# <a name='section5'></a>AUTHORS

Sergei Golovan

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *stringprep* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[unicode\(n\)](unicode\.md)

# <a name='keywords'></a>KEYWORDS

[stringprep](\.\./\.\./\.\./\.\./index\.md\#stringprep),
[unicode](\.\./\.\./\.\./\.\./index\.md\#unicode)

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007\-2009, Sergei Golovan <sgolovan@nes\.ru>
