
[//000000001]: # (valtype::common \- Validation types)
[//000000002]: # (Generated from file 'valtype\_common\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2011 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (valtype::common\(n\) 1 tcllib "Validation types")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

valtype::common \- Validation, common code

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Error Codes](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require valtype::common ?1?  

[__valtype::common::reject__ *code* *text*](#1)  
[__valtype::common::badchar__ *code* ?*text*?](#2)  
[__valtype::common::badcheck__ *code* ?*text*?](#3)  
[__valtype::common::badlength__ *code* *lengths* ?*text*?](#4)  
[__valtype::common::badprefix__ *code* *prefixes* ?*text*?](#5)  

# <a name='description'></a>DESCRIPTION

This package implements a number of common commands used by the validation types
in this module\. These commands essentially encapsulate the throwing of
validation errors, ensuring that a proper __\-errorcode__ is used\. See
section [Error Codes](#section3)\.

# <a name='section2'></a>API

  - <a name='1'></a>__valtype::common::reject__ *code* *text*

    The core command of this package it throws an __INVALID__ error with the
    specified *text*\. The first argument is a list of codes extending the
    __INVALID__ with detail information\.

  - <a name='2'></a>__valtype::common::badchar__ *code* ?*text*?

    This command throws an __INVALID CHAR__ error with the specified
    *text*\. The first argument is a list of codes providing details\. These are
    inserted between the codes __INVALID__ and __CHARACTER__\.

  - <a name='3'></a>__valtype::common::badcheck__ *code* ?*text*?

    This command throws an __INVALID CHECK\-DIGIT__ error with the specified
    *text*, if any, extended by the standard text "the check digit is
    incorrect"\. The first argument is a list of codes providing details\. These
    are inserted between the codes __INVALID__ and __CHECK\_DIGIT__\.

  - <a name='4'></a>__valtype::common::badlength__ *code* *lengths* ?*text*?

    This command throws an __INVALID LENGTH__ error with the specified
    *text*, if any, extended by the standard text "incorrect length, expected
    \.\.\. character\(s\)"\. The first argument is a list of codes providing details\.
    These are inserted between the codes __INVALID__ and __LENGTH__\. The
    argument *lengths* is a list of the input lengths which had been expected,
    i\.e\. these are the valid lengths\.

  - <a name='5'></a>__valtype::common::badprefix__ *code* *prefixes* ?*text*?

    This command throws an __INVALID PREFIX__ error with the specified
    *text*, if any, extended by the standard text "incorrect prefix, expected
    \.\.\."\. The first argument is a list of codes providing details\. These are
    inserted between the codes __INVALID__ and __PREFIX__\. The argument
    *prefixes* is a list of the input prefixes which had been expected, i\.e\.
    these are the valid prefixes\.

# <a name='section3'></a>Error Codes

The errors thrown by the commands of this package all use the __\-errorcode__
__INVALID__ to distinguish the input validation failures they represent from
package internal errors\.

To provide more detailed information about why the validation failed the
__\-errorCode__ goes actually beyond that\. First, it will contain a code
detailing the type itself\. This is supplied by the caller\. This is then followed
by values detailing the reason for the failure\. The full set of
__\-errorCode__s which can be thrown by this package are shown below, with
__<>__ a placeholder for both the caller\-supplied type\-information, the type
description\.

  - INVALID __<>__ CHARACTER

    The input value contained one or more bad characters, i\.e\. characters which
    must not occur in the input for it to be a __<>__\.

  - INVALID __<>__ CHECK\-DIGIT

    The check digit of the input value is wrong\. This usually signals a
    data\-entry error, with digits transposed, forgotten, etc\. Of course, th
    input may be an outright fake too\.

  - INVALID __<>__ LENGTH

    The input value is of the wrong length to be a __<>__\.

  - INVALID __<>__ PREFIX

    The input value does not start with the magic value\(s\) required for it to be
    a __<>__\.

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *valtype* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[Checking](\.\./\.\./\.\./\.\./index\.md\#checking),
[Testing](\.\./\.\./\.\./\.\./index\.md\#testing), [Type
checking](\.\./\.\./\.\./\.\./index\.md\#type\_checking),
[Validation](\.\./\.\./\.\./\.\./index\.md\#validation), [Value
checking](\.\./\.\./\.\./\.\./index\.md\#value\_checking),
[isA](\.\./\.\./\.\./\.\./index\.md\#isa)

# <a name='category'></a>CATEGORY

Validation, Type checking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2011 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
