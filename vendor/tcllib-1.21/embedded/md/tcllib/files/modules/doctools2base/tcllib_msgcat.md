
[//000000001]: # (doctools::msgcat \- Documentation tools)
[//000000002]: # (Generated from file 'tcllib\_msgcat\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools::msgcat\(n\) 0\.1 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools::msgcat \- Message catalog management for the various document parsers

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
package require doctools::msgcat ?0\.1?  

[__::doctools::msgcat::init__ *prefix*](#1)  

# <a name='description'></a>DESCRIPTION

The package __doctools::msgcat__ is a support module handling the selection
of message catalogs for the various document processing packages in the doctools
system version 2\. As such it is an internal package a regular user \(developer\)
should not be in direct contact with\.

If you are such please go the documentation of either

  1. __doctools::doc__,

  1. __[doctools::toc](\.\./doctools/doctoc\.md)__, or

  1. __[doctools::idx](\.\./doctools2idx/idx\_container\.md)__

Within the system architecture this package resides under the various parser
packages, and is shared by them\. Underneath it, but not explicit dependencies,
are the packages providing the message catalogs for the various languages\.

# <a name='section2'></a>API

  - <a name='1'></a>__::doctools::msgcat::init__ *prefix*

    The command locates and loads the message catalogs for all the languages
    returned by __msgcat::mcpreferences__, provided that they could be
    found\. It returns an integer number describing how many packages were found
    and loaded\.

    The names of the packages the command will look for have the form
    "doctools::msgcat::*prefix*::__langcode__", with *prefix* the
    argument to the command, and the __langcode__ supplied by the result of
    __msgcat::mcpreferences__\.

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

[catalog package](\.\./\.\./\.\./\.\./index\.md\#catalog\_package),
[docidx](\.\./\.\./\.\./\.\./index\.md\#docidx),
[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc),
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
