
[//000000001]: # (textutil::string \- Text and string utilities, macro processing)
[//000000002]: # (Generated from file 'textutil\_string\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (textutil::string\(n\) 0\.8 tcllib "Text and string utilities, macro processing")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

textutil::string \- Procedures to manipulate texts and strings\.

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require textutil::string ?0\.8?  

[__::textutil::string::chop__ *string*](#1)  
[__::textutil::string::tail__ *string*](#2)  
[__::textutil::string::cap__ *string*](#3)  
[__::textutil::string::capEachWord__ *string*](#4)  
[__::textutil::string::uncap__ *string*](#5)  
[__::textutil::string::longestCommonPrefixList__ *list*](#6)  
[__::textutil::string::longestCommonPrefix__ ?*string*\.\.\.?](#7)  

# <a name='description'></a>DESCRIPTION

The package __textutil::string__ provides miscellaneous string manipulation
commands\.

The complete set of procedures is described below\.

  - <a name='1'></a>__::textutil::string::chop__ *string*

    A convenience command\. Removes the last character of *string* and returns
    the shortened string\.

  - <a name='2'></a>__::textutil::string::tail__ *string*

    A convenience command\. Removes the first character of *string* and returns
    the shortened string\.

  - <a name='3'></a>__::textutil::string::cap__ *string*

    Capitalizes the first character of *string* and returns the modified
    string\.

  - <a name='4'></a>__::textutil::string::capEachWord__ *string*

    Capitalizes the first character of word of the *string* and returns the
    modified string\. Words quoted with either backslash or dollar\-sign are left
    untouched\.

  - <a name='5'></a>__::textutil::string::uncap__ *string*

    The complementary operation to __::textutil::string::cap__\. Forces the
    first character of *string* to lower case and returns the modified string\.

  - <a name='6'></a>__::textutil::string::longestCommonPrefixList__ *list*

  - <a name='7'></a>__::textutil::string::longestCommonPrefix__ ?*string*\.\.\.?

    Computes the longest common prefix for either the *string*s given to the
    command, or the strings specified in the single *list*, and returns it as
    the result of the command\.

    If no strings were specified the result is the empty string\. If only one
    string was specified, the string itself is returned, as it is its own
    longest common prefix\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *textutil* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

regexp\(n\), split\(n\), string\(n\)

# <a name='keywords'></a>KEYWORDS

[capitalize](\.\./\.\./\.\./\.\./index\.md\#capitalize),
[chop](\.\./\.\./\.\./\.\./index\.md\#chop), [common
prefix](\.\./\.\./\.\./\.\./index\.md\#common\_prefix),
[formatting](\.\./\.\./\.\./\.\./index\.md\#formatting),
[prefix](\.\./\.\./\.\./\.\./index\.md\#prefix),
[string](\.\./\.\./\.\./\.\./index\.md\#string),
[uncapitalize](\.\./\.\./\.\./\.\./index\.md\#uncapitalize)

# <a name='category'></a>CATEGORY

Text processing
