
[//000000001]: # (unicode \- Unicode normalization)
[//000000002]: # (Generated from file 'unicode\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007, Sergei Golovan <sgolovan@nes\.ru>)
[//000000004]: # (unicode\(n\) 1\.0\.0 tcllib "Unicode normalization")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

unicode \- Implementation of Unicode normalization

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
package require unicode 1\.0  

[__::unicode::fromstring__ *string*](#1)  
[__::unicode::tostring__ *uclist*](#2)  
[__::unicode::normalize__ *form* *uclist*](#3)  
[__::unicode::normalizeS__ *form* *string*](#4)  

# <a name='description'></a>DESCRIPTION

This is an implementation in Tcl of the Unicode normalization forms\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::unicode::fromstring__ *string*

    Converts *string* to list of integer Unicode character codes which is used
    in __unicode__ for internal string representation\.

  - <a name='2'></a>__::unicode::tostring__ *uclist*

    Converts list of integers *uclist* back to Tcl string\.

  - <a name='3'></a>__::unicode::normalize__ *form* *uclist*

    Normalizes Unicode characters list *ulist* according to *form* and
    returns the normalized list\. Form *form* takes one of the following
    values: *D* \(canonical decomposition\), *C* \(canonical decomposition,
    followed by canonical composition\), *KD* \(compatibility decomposition\), or
    *KC* \(compatibility decomposition, followed by canonical composition\)\.

  - <a name='4'></a>__::unicode::normalizeS__ *form* *string*

    A shortcut to ::unicode::tostring \[unicode::normalize \\$form
    \[::unicode::fromstring \\$string\]\]\. Normalizes Tcl string and returns
    normalized string\.

# <a name='section3'></a>EXAMPLES

    % ::unicode::fromstring "\u0410\u0411\u0412\u0413"
    1040 1041 1042 1043
    % ::unicode::tostring {49 50 51 52 53}
    12345
    %

    % ::unicode::normalize D {7692 775}
    68 803 775
    % ::unicode::normalizeS KD "\u1d2c"
    A
    %

# <a name='section4'></a>REFERENCES

  1. "Unicode Standard Annex \#15: Unicode Normalization Forms",
     \([http://unicode\.org/reports/tr15/](http://unicode\.org/reports/tr15/)\)

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

[stringprep\(n\)](stringprep\.md)

# <a name='keywords'></a>KEYWORDS

[normalization](\.\./\.\./\.\./\.\./index\.md\#normalization),
[unicode](\.\./\.\./\.\./\.\./index\.md\#unicode)

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007, Sergei Golovan <sgolovan@nes\.ru>
