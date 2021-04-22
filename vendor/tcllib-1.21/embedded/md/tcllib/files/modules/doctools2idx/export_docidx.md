
[//000000001]: # (doctools::idx::export::docidx \- Documentation tools)
[//000000002]: # (Generated from file 'plugin\.inc' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009\-2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools::idx::export::docidx\(n\) 0\.2\.1 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools::idx::export::docidx \- docidx export plugin

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [\[docidx\] notation of keyword indices](#section3)

  - [Configuration](#section4)

  - [Keyword index serialization format](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require doctools::idx::export::docidx ?0\.2\.1?  

[__[export](\.\./\.\./\.\./\.\./index\.md\#export)__ *serial* *configuration*](#1)  

# <a name='description'></a>DESCRIPTION

This package implements the doctools keyword index export plugin for the
generation of docidx markup\.

This is an internal package of doctools, for use by the higher level management
packages handling keyword indices, especially
__[doctools::idx::export](idx\_export\.md)__, the export manager\.

Using it from a regular interpreter is possible, however only with contortions,
and is not recommended\. The proper way to use this functionality is through the
package __[doctools::idx::export](idx\_export\.md)__ and the export
manager objects it provides\.

# <a name='section2'></a>API

The API provided by this package satisfies the specification of the docidx
export plugin API version 2\.

  - <a name='1'></a>__[export](\.\./\.\./\.\./\.\./index\.md\#export)__ *serial* *configuration*

    This command takes the canonical serialization of a keyword index, as
    specified in section [Keyword index serialization format](#section5),
    and contained in *serial*, the *configuration*, a dictionary, and
    generates docidx markup encoding the index\. The created string is then
    returned as the result of the command\.

# <a name='section3'></a>\[docidx\] notation of keyword indices

The docidx format for keyword indices, also called the *docidx markup
language*, is too large to be covered in single section\. The interested reader
should start with the document

  1. *[docidx language introduction](\.\./doctools/docidx\_lang\_intro\.md)*

and then proceed from there to the formal specifications, i\.e\. the documents

  1. *[docidx language syntax](\.\./doctools/docidx\_lang\_syntax\.md)* and

  1. *[docidx language command
     reference](\.\./doctools/docidx\_lang\_cmdref\.md)*\.

to get a thorough understanding of the language\.

# <a name='section4'></a>Configuration

The docidx export plugin recognizes the following configuration variables and
changes its behaviour as they specify\.

  - string *user*

    This standard configuration variable contains the name of the user running
    the process which invoked the export plugin\. The plugin puts this
    information into the provenance comment at the beginning of the generated
    document\.

  - string *file*

    This standard configuration variable contains the name of the file the index
    came from\. This variable may not be set or contain the empty string\. The
    plugin puts this information, if defined, i\.e\. set and not the empty string,
    into the provenance comment at the beginning of the generated document\.

  - boolean *newlines*

    If this flag is set the plugin will break the generated docidx code across
    lines, with each markup command on a separate line\.

    If this flag is not set \(the default\), the whole document will be written on
    a single line, with minimum spacing between all elements\.

  - boolean *indented*

    If this flag is set the plugin will indent the markup commands according to
    the structure of indices\. To make this work this also implies that
    __newlines__ is set\. This effect is independent of the value for
    __aligned__ however\.

    If this flag is not set \(the default\), the output is formatted as per the
    values of __newlines__ and __aligned__, and no indenting is done\.

  - boolean *aligned*

    If this flag is set the generator ensures that the arguments for the
    __[manpage](\.\./\.\./\.\./\.\./index\.md\#manpage)__ and
    __[url](\.\./\.\./\.\./\.\./index\.md\#url)__ commands in a keyword section
    are aligned vertically for a nice table effect\. To make this work this also
    implies that __newlines__ is set\. This effect is independent of the
    value for __indented__ however\.

    If this flag is not set \(the default\), the output is formatted as per the
    values of __newlines__ and __indented__, and no alignment is done\.

*Note* that this plugin ignores the standard configuration variables
__format__, and __map__, and their values\.

# <a name='section5'></a>Keyword index serialization format

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

# <a name='section6'></a>Bugs, Ideas, Feedback

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

[docidx](\.\./\.\./\.\./\.\./index\.md\#docidx),
[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools),
[export](\.\./\.\./\.\./\.\./index\.md\#export),
[index](\.\./\.\./\.\./\.\./index\.md\#index),
[serialization](\.\./\.\./\.\./\.\./index\.md\#serialization)

# <a name='category'></a>CATEGORY

Text formatter plugin

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009\-2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
