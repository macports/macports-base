
[//000000001]: # (doctools::toc::structure \- Documentation tools)
[//000000002]: # (Generated from file 'toc\_structure\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools::toc::structure\(n\) 0\.1 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools::toc::structure \- Doctoc serialization utilities

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [ToC serialization format](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require doctools::toc::structure ?0\.1?  
package require Tcl 8\.4  
package require logger  
package require snit  

[__::doctools::toc::structure__ __verify__ *serial* ?*canonvar*?](#1)  
[__::doctools::toc::structure__ __verify\-as\-canonical__ *serial*](#2)  
[__::doctools::toc::structure__ __canonicalize__ *serial*](#3)  
[__::doctools::toc::structure__ __print__ *serial*](#4)  
[__::doctools::toc::structure__ __merge__ *seriala* *serialb*](#5)  

# <a name='description'></a>DESCRIPTION

This package provides commands to work with the serializations of tables of
contents as managed by the doctools system v2, and specified in section [ToC
serialization format](#section3)\.

This is an internal package of doctools, for use by the higher level packages
handling tables of contents and their conversion into and out of various other
formats, like documents written using
*[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc)* markup\.

# <a name='section2'></a>API

  - <a name='1'></a>__::doctools::toc::structure__ __verify__ *serial* ?*canonvar*?

    This command verifies that the content of *serial* is a valid *regular*
    serialization of a table of contents and will throw an error if that is not
    the case\. The result of the command is the empty string\.

    If the argument *canonvar* is specified it is interpreted as the name of a
    variable in the calling context\. This variable will be written to if and
    only if *serial* is a valid regular serialization\. Its value will be a
    boolean, with __True__ indicating that the serialization is not only
    valid, but also *canonical*\. __False__ will be written for a valid,
    but non\-canonical serialization\.

    For the specification of regular and canonical serializations see the
    section [ToC serialization format](#section3)\.

  - <a name='2'></a>__::doctools::toc::structure__ __verify\-as\-canonical__ *serial*

    This command verifies that the content of *serial* is a valid
    *canonical* serialization of a table of contents and will throw an error
    if that is not the case\. The result of the command is the empty string\.

    For the specification of canonical serializations see the section [ToC
    serialization format](#section3)\.

  - <a name='3'></a>__::doctools::toc::structure__ __canonicalize__ *serial*

    This command assumes that the content of *serial* is a valid *regular*
    serialization of a table of contents and will throw an error if that is not
    the case\.

    It will then convert the input into the *canonical* serialization of the
    contained table of contents and return it as its result\. If the input is
    already canonical it will be returned unchanged\.

    For the specification of regular and canonical serializations see the
    section [ToC serialization format](#section3)\.

  - <a name='4'></a>__::doctools::toc::structure__ __print__ *serial*

    This command assumes that the argument *serial* contains a valid regular
    serialization of a table of contents and returns a string containing that
    table in a human readable form\.

    The exact format of this form is not specified and cannot be relied on for
    parsing or other machine\-based activities\.

    For the specification of regular serializations see the section [ToC
    serialization format](#section3)\.

  - <a name='5'></a>__::doctools::toc::structure__ __merge__ *seriala* *serialb*

    This command accepts the regular serializations of two tables of contents
    and uses them to create their union\. The result of the command is the
    canonical serialization of this unified table of contents\.

    Title and label of the resulting table are taken from the table contained in
    *serialb*\.

    The whole table and its divisions are merged recursively in the same manner:

      1. All reference elements which occur in both divisions \(identified by
         their label\) are unified with document id's and descriptions taken from
         the second table\.

      1. All division elements which occur in both divisions \(identified by
         their label\) are unified with the optional document id taken from the
         second table, if any, or from the first if none is in the second\. The
         elements in the division are merged recursively using the same
         algorithm as described in this list\.

      1. Type conflicts between elements, i\.e\. finding two elements with the
         same label but different types result in a merge error\.

      1. All elements found in the second division but not in the first are
         added to the end of the list of elements in the merge result\.

    For the specification of regular and canonical serializations see the
    section [ToC serialization format](#section3)\.

# <a name='section3'></a>ToC serialization format

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
[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc),
[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools),
[serialization](\.\./\.\./\.\./\.\./index\.md\#serialization)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
