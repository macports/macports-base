
[//000000001]: # (doctools::toc::export::doctoc \- Documentation tools)
[//000000002]: # (Generated from file 'plugin\.inc' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009\-2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools::toc::export::doctoc\(n\) 0\.2\.1 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools::toc::export::doctoc \- doctoc export plugin

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [\[doctoc\] notation of tables of contents](#section3)

  - [Configuration](#section4)

  - [ToC serialization format](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require doctools::toc::export::doctoc ?0\.2\.1?  

[__[export](\.\./\.\./\.\./\.\./index\.md\#export)__ *serial* *configuration*](#1)  

# <a name='description'></a>DESCRIPTION

This package implements the doctools table of contents export plugin for the
generation of doctoc markup\.

This is an internal package of doctools, for use by the higher level management
packages handling tables of contents, especially
__[doctools::toc::export](toc\_export\.md)__, the export manager\.

Using it from a regular interpreter is possible, however only with contortions,
and is not recommended\. The proper way to use this functionality is through the
package __[doctools::toc::export](toc\_export\.md)__ and the export
manager objects it provides\.

# <a name='section2'></a>API

The API provided by this package satisfies the specification of the doctoc
export plugin API version 2\.

  - <a name='1'></a>__[export](\.\./\.\./\.\./\.\./index\.md\#export)__ *serial* *configuration*

    This command takes the canonical serialization of a table of contents, as
    specified in section [ToC serialization format](#section5), and
    contained in *serial*, the *configuration*, a dictionary, and generates
    doctoc markup encoding the table\. The created string is then returned as the
    result of the command\.

# <a name='section3'></a>\[doctoc\] notation of tables of contents

The doctoc format for tables of contents, also called the *doctoc markup
language*, is too large to be covered in single section\. The interested reader
should start with the document

  1. *[doctoc language introduction](\.\./doctools/doctoc\_lang\_intro\.md)*

and then proceed from there to the formal specifications, i\.e\. the documents

  1. *[doctoc language syntax](\.\./doctools/doctoc\_lang\_syntax\.md)* and

  1. *[doctoc language command
     reference](\.\./doctools/doctoc\_lang\_cmdref\.md)*\.

to get a thorough understanding of the language\.

# <a name='section4'></a>Configuration

The doctoc export plugin recognizes the following configuration variables and
changes its behaviour as they specify\.

  - string *user*

    This standard configuration variable contains the name of the user running
    the process which invoked the export plugin\. The plugin puts this
    information into the provenance comment at the beginning of the generated
    document\.

  - string *file*

    This standard configuration variable contains the name of the file the table
    of contents came from\. This variable may not be set or contain the empty
    string\. The plugin puts this information, if defined, i\.e\. set and not the
    empty string, into the provenance comment at the beginning of the generated
    document\.

  - boolean *newlines*

    If this flag is set the plugin will break the generated doctoc code across
    lines, with each markup command on a separate line\.

    If this flag is not set \(the default\), the whole document will be written on
    a single line, with minimum spacing between all elements\.

  - boolean *indented*

    If this flag is set the plugin will indent the markup commands according to
    the structure of tables of contents\. To make this work this also implies
    that __newlines__ is set\. This effect is independent of the value for
    __aligned__ however\.

    If this flag is not set \(the default\), the output is formatted as per the
    value of __newlines__, and no indenting is done\.

  - boolean *aligned*

    If this flag is set the generator ensures that the arguments for the
    __item__ commands in a division are aligned vertically for a nice table
    effect\. To make this work this also implies that __newlines__ is set\.
    This effect is independent of the value for __indented__ however\.

    If this flag is not set \(the default\), the output is formatted as per the
    values of __newlines__ and __indented__, and no alignment is done\.

*Note* that this plugin ignores the standard configuration variables
__format__, and __map__, and their values\.

# <a name='section5'></a>ToC serialization format

Here we specify the format used by the doctools v2 packages to serialize tables
of contents as immutable values for transport, comparison, etc\.

We distinguish between *regular* and *canonical* serializations\. While a
table of contents may have more than one regular serialization only exactly one
of them will be *canonical*\.

  - regular serialization

      1. The serialization of any table of contents is a nested Tcl dictionary\.

      1. This dictionary holds a single key, __doctools::toc__, and its
         value\. This value holds the contents of the table of contents\.

      1. The contents of the table of contents are a Tcl dictionary holding the
         title of the table of contents, a label, and its elements\. The relevant
         keys and their values are

           * __title__

             The value is a string containing the title of the table of
             contents\.

           * __label__

             The value is a string containing a label for the table of contents\.

           * __items__

             The value is a Tcl list holding the elements of the table, in the
             order they are to be shown\.

             Each element is a Tcl list holding the type of the item, and its
             description, in this order\. An alternative description would be
             that it is a Tcl dictionary holding a single key, the item type,
             mapped to the item description\.

             The two legal item types and their descriptions are

               + __reference__

                 This item describes a single entry in the table of contents,
                 referencing a single document\. To this end its value is a Tcl
                 dictionary containing an id for the referenced document, a
                 label, and a longer textual description which can be associated
                 with the entry\. The relevant keys and their values are

                   - __id__

                     The value is a string containing the id of the document
                     associated with the entry\.

                   - __label__

                     The value is a string containing a label for this entry\.
                     This string also identifies the entry, and no two entries
                     \(references and divisions\) in the containing list are
                     allowed to have the same label\.

                   - __desc__

                     The value is a string containing a longer description for
                     this entry\.

               + __division__

                 This item describes a group of entries in the table of
                 contents, inducing a hierarchy of entries\. To this end its
                 value is a Tcl dictionary containing a label for the group, an
                 optional id to a document for the whole group, and the list of
                 entries in the group\. The relevant keys and their values are

                   - __id__

                     The value is a string containing the id of the document
                     associated with the whole group\. This key is optional\.

                   - __label__

                     The value is a string containing a label for the group\.
                     This string also identifies the entry, and no two entries
                     \(references and divisions\) in the containing list are
                     allowed to have the same label\.

                   - __items__

                     The value is a Tcl list holding the elements of the group,
                     in the order they are to be shown\. This list has the same
                     structure as the value for the keyword __items__ used
                     to describe the whole table of contents, see above\. This
                     closes the recusrive definition of the structure, with
                     divisions holding the same type of elements as the whole
                     table of contents, including other divisions\.

  - canonical serialization

    The canonical serialization of a table of contents has the format as
    specified in the previous item, and then additionally satisfies the
    constraints below, which make it unique among all the possible
    serializations of this table of contents\.

      1. The keys found in all the nested Tcl dictionaries are sorted in
         ascending dictionary order, as generated by Tcl's builtin command
         __lsort \-increasing \-dict__\.

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

[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc),
[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools),
[export](\.\./\.\./\.\./\.\./index\.md\#export),
[serialization](\.\./\.\./\.\./\.\./index\.md\#serialization), [table of
contents](\.\./\.\./\.\./\.\./index\.md\#table\_of\_contents),
[toc](\.\./\.\./\.\./\.\./index\.md\#toc)

# <a name='category'></a>CATEGORY

Text formatter plugin

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009\-2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
