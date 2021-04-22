
[//000000001]: # (SASL::NTLM \- Simple Authentication and Security Layer \(SASL\))
[//000000002]: # (Generated from file 'ntlm\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005\-2006, Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000004]: # (SASL::NTLM\(n\) 1\.1\.2 tcllib "Simple Authentication and Security Layer \(SASL\)")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

SASL::NTLM \- Implementation of SASL NTLM mechanism for Tcl

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [REFERENCES](#section2)

  - [AUTHORS](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require SASL::NTLM ?1\.1\.2?  

# <a name='description'></a>DESCRIPTION

This package provides the NTLM authentication mechanism for the Simple
Authentication and Security Layer \(SASL\)\.

Please read the documentation for package __sasl__ for details\.

# <a name='section2'></a>REFERENCES

  1. No official specification is available\. However,
     [http://davenport\.sourceforge\.net/ntlm\.html](http://davenport\.sourceforge\.net/ntlm\.html)
     provides a good description\.

# <a name='section3'></a>AUTHORS

Pat Thoyts

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *sasl* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[NTLM](\.\./\.\./\.\./\.\./index\.md\#ntlm), [SASL](\.\./\.\./\.\./\.\./index\.md\#sasl),
[authentication](\.\./\.\./\.\./\.\./index\.md\#authentication)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005\-2006, Pat Thoyts <patthoyts@users\.sourceforge\.net>
