
[//000000001]: # (doctools::msgcat::idx::de \- Documentation tools)
[//000000002]: # (Generated from file 'msgcat\.inc' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools::msgcat::idx::de\(n\) 0\.1 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools::msgcat::idx::de \- Message catalog for the docidx parser \(DE\)

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require msgcat  
package require doctools::msgcat::idx::de ?0\.1?  

# <a name='description'></a>DESCRIPTION

The package __doctools::msgcat::idx::de__ is a support module providing the
DE \(german\) language message catalog for the docidx parser in the doctools
system version 2\. As such it is an internal package a regular user \(developer\)
should not be in direct contact with\.

If you are such please go the documentation of either

  1. __doctools::doc__,

  1. __[doctools::toc](\.\./doctools/doctoc\.md)__, or

  1. __[doctools::idx](idx\_container\.md)__

Within the system architecture this package resides under the package
__[doctools::msgcat](\.\./doctools2base/tcllib\_msgcat\.md)__ providing the
general message catalog management within the system\. *Note* that there is
*no* explicit dependency between the manager and catalog packages\. The catalog
is a plugin which is selected and loaded dynamically\.

# <a name='section2'></a>API

This package has no exported API\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *doctools* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[DE](\.\./\.\./\.\./\.\./index\.md\#de), [catalog
package](\.\./\.\./\.\./\.\./index\.md\#catalog\_package),
[docidx](\.\./\.\./\.\./\.\./index\.md\#docidx),
[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools),
[i18n](\.\./\.\./\.\./\.\./index\.md\#i18n),
[internationalization](\.\./\.\./\.\./\.\./index\.md\#internationalization),
[l10n](\.\./\.\./\.\./\.\./index\.md\#l10n),
[localization](\.\./\.\./\.\./\.\./index\.md\#localization), [message
catalog](\.\./\.\./\.\./\.\./index\.md\#message\_catalog), [message
package](\.\./\.\./\.\./\.\./index\.md\#message\_package)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
