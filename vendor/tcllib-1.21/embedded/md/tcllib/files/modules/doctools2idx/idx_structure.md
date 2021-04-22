
[//000000001]: # (doctools::idx::structure \- Documentation tools)
[//000000002]: # (Generated from file 'idx\_structure\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools::idx::structure\(n\) 0\.1 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools::idx::structure \- Docidx serialization utilities

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Keyword index serialization format](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require doctools::idx::structure ?0\.1?  
package require Tcl 8\.4  
package require logger  
package require snit  

[__::doctools::idx::structure__ __verify__ *serial* ?*canonvar*?](#1)  
[__::doctools::idx::structure__ __verify\-as\-canonical__ *serial*](#2)  
[__::doctools::idx::structure__ __canonicalize__ *serial*](#3)  
[__::doctools::idx::structure__ __print__ *serial*](#4)  
[__::doctools::idx::structure__ __merge__ *seriala* *serialb*](#5)  

# <a name='description'></a>DESCRIPTION

This package provides commands to work with the serializations of keyword
indices as managed by the doctools system v2, and specified in section [Keyword
index serialization format](#section3)\.

This is an internal package of doctools, for use by the higher level packages
handling keyword indices and their conversion into and out of various other
formats, like documents written using
*[docidx](\.\./\.\./\.\./\.\./index\.md\#docidx)* markup\.

# <a name='section2'></a>API

  - <a name='1'></a>__::doctools::idx::structure__ __verify__ *serial* ?*canonvar*?

    This command verifies that the content of *serial* is a valid *regular*
    serialization of a keyword index and will throw an error if that is not the
    case\. The result of the command is the empty string\.

    If the argument *canonvar* is specified it is interpreted as the name of a
    variable in the calling context\. This variable will be written to if and
    only if *serial* is a valid regular serialization\. Its value will be a
    boolean, with __True__ indicating that the serialization is not only
    valid, but also *canonical*\. __False__ will be written for a valid,
    but non\-canonical serialization\.

    For the specification of regular and canonical keyword index serializations
    see the section [Keyword index serialization format](#section3)\.

  - <a name='2'></a>__::doctools::idx::structure__ __verify\-as\-canonical__ *serial*

    This command verifies that the content of *serial* is a valid
    *canonical* serialization of a keyword index and will throw an error if
    that is not the case\. The result of the command is the empty string\.

    For the specification of canonical keyword index serializations see the
    section [Keyword index serialization format](#section3)\.

  - <a name='3'></a>__::doctools::idx::structure__ __canonicalize__ *serial*

    This command assumes that the content of *serial* is a valid *regular*
    serialization of a keyword index and will throw an error if that is not the
    case\.

    It will then convert the input into the *canonical* serialization of the
    contained keyword index and return it as its result\. If the input is already
    canonical it will be returned unchanged\.

    For the specification of regular and canonical keyword index serializations
    see the section [Keyword index serialization format](#section3)\.

  - <a name='4'></a>__::doctools::idx::structure__ __print__ *serial*

    This command assumes that the argument *serial* contains a valid regular
    serialization of a keyword index and returns a string containing that index
    in a human readable form\.

    The exact format of this form is not specified and cannot be relied on for
    parsing or other machine\-based activities\.

    For the specification of regular keyword index serializations see the
    section [Keyword index serialization format](#section3)\.

  - <a name='5'></a>__::doctools::idx::structure__ __merge__ *seriala* *serialb*

    This command accepts the regular serializations of two keyword indices and
    uses them to create their union\. The result of the command is the canonical
    serialization of this unified keyword index\.

    Title and label of the resulting index are taken from the index contained in
    *serialb*\. The set of keys, references and their connections is the union
    of the set of keys and references of the two inputs\.

    For the specification of regular and canonical keyword index serializations
    see the section [Keyword index serialization format](#section3)\.

# <a name='section3'></a>Keyword index serialization format

Here we specify the format used by the doctools v2 packages to serialize keyword
indices as immutable values for transport, comparison, etc\.

We distinguish between *regular* and *canonical* serializations\. While a
keyword index may have more than one regular serialization only exactly one of
them will be *canonical*\.

  - regular serialization

      1. An index serialization is a nested Tcl dictionary\.

      1. This dictionary holds a single key, __doctools::idx__, and its
         value\. This value holds the contents of the index\.

      1. The contents of the index are a Tcl dictionary holding the title of the
         index, a label, and the keywords and references\. The relevant keys and
         their values are

           * __title__

             The value is a string containing the title of the index\.

           * __label__

             The value is a string containing a label for the index\.

           * __keywords__

             The value is a Tcl dictionary, using the keywords known to the
             index as keys\. The associated values are lists containing the
             identifiers of the references associated with that particular
             keyword\.

             Any reference identifier used in these lists has to exist as a key
             in the __references__ dictionary, see the next item for its
             definition\.

           * __references__

             The value is a Tcl dictionary, using the identifiers for the
             references known to the index as keys\. The associated values are
             2\-element lists containing the type and label of the reference, in
             this order\.

             Any key here has to be associated with at least one keyword, i\.e\.
             occur in at least one of the reference lists which are the values
             in the __keywords__ dictionary, see previous item for its
             definition\.

      1. The *[type](\.\./\.\./\.\./\.\./index\.md\#type)* of a reference can be one
         of two values,

           * __manpage__

             The identifier of the reference is interpreted as symbolic file
             name, referring to one of the documents the index was made for\.

           * __url__

             The identifier of the reference is interpreted as an url, referring
             to some external location, like a website, etc\.

  - canonical serialization

    The canonical serialization of a keyword index has the format as specified
    in the previous item, and then additionally satisfies the constraints below,
    which make it unique among all the possible serializations of the keyword
    index\.

      1. The keys found in all the nested Tcl dictionaries are sorted in
         ascending dictionary order, as generated by Tcl's builtin command
         __lsort \-increasing \-dict__\.

      1. The references listed for each keyword of the index, if any, are listed
         in ascending dictionary order of their *labels*, as generated by
         Tcl's builtin command __lsort \-increasing \-dict__\.

# <a name='section4'></a>Bugs, Ideas, Feedback

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

[deserialization](\.\./\.\./\.\./\.\./index\.md\#deserialization),
[docidx](\.\./\.\./\.\./\.\./index\.md\#docidx),
[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools),
[serialization](\.\./\.\./\.\./\.\./index\.md\#serialization)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
