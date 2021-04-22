
[//000000001]: # (doctools::toc::parse \- Documentation tools)
[//000000002]: # (Generated from file 'toc\_parse\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools::toc::parse\(n\) 1 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools::toc::parse \- Parsing text in doctoc format

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Parse errors](#section3)

  - [\[doctoc\] notation of tables of contents](#section4)

  - [ToC serialization format](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require doctools::toc::parse ?0\.1?  
package require Tcl 8\.4  
package require doctools::toc::structure  
package require doctools::msgcat  
package require doctools::tcl::parse  
package require fileutil  
package require logger  
package require snit  
package require struct::list  
package require struct::stack  

[__::doctools::toc::parse__ __text__ *text*](#1)  
[__::doctools::toc::parse__ __file__ *path*](#2)  
[__::doctools::toc::parse__ __includes__](#3)  
[__::doctools::toc::parse__ __include add__ *path*](#4)  
[__::doctools::toc::parse__ __include remove__ *path*](#5)  
[__::doctools::toc::parse__ __include clear__](#6)  
[__::doctools::toc::parse__ __vars__](#7)  
[__::doctools::toc::parse__ __var set__ *name* *value*](#8)  
[__::doctools::toc::parse__ __var unset__ *name*](#9)  
[__::doctools::toc::parse__ __var clear__ ?*pattern*?](#10)  

# <a name='description'></a>DESCRIPTION

This package provides commands to parse text written in the
*[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc)* markup language and convert it
into the canonical serialization of the table of contents encoded in the text\.
See the section [ToC serialization format](#section5) for specification of
their format\.

This is an internal package of doctools, for use by the higher level packages
handling *[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc)* documents\.

# <a name='section2'></a>API

  - <a name='1'></a>__::doctools::toc::parse__ __text__ *text*

    The command takes the string contained in *text* and parses it under the
    assumption that it contains a document written using the
    *[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc)* markup language\. An error is
    thrown if this assumption is found to be false\. The format of these errors
    is described in section [Parse errors](#section3)\.

    When successful the command returns the canonical serialization of the table
    of contents which was encoded in the text\. See the section [ToC
    serialization format](#section5) for specification of that format\.

  - <a name='2'></a>__::doctools::toc::parse__ __file__ *path*

    The same as __text__, except that the text to parse is read from the
    file specified by *path*\.

  - <a name='3'></a>__::doctools::toc::parse__ __includes__

    This method returns the current list of search paths used when looking for
    include files\.

  - <a name='4'></a>__::doctools::toc::parse__ __include add__ *path*

    This method adds the *path* to the list of paths searched when looking for
    an include file\. The call is ignored if the path is already in the list of
    paths\. The method returns the empty string as its result\.

  - <a name='5'></a>__::doctools::toc::parse__ __include remove__ *path*

    This method removes the *path* from the list of paths searched when
    looking for an include file\. The call is ignored if the path is not
    contained in the list of paths\. The method returns the empty string as its
    result\.

  - <a name='6'></a>__::doctools::toc::parse__ __include clear__

    This method clears the list of search paths for include files\.

  - <a name='7'></a>__::doctools::toc::parse__ __vars__

    This method returns a dictionary containing the current set of predefined
    variables known to the __vset__ markup command during processing\.

  - <a name='8'></a>__::doctools::toc::parse__ __var set__ *name* *value*

    This method adds the variable *name* to the set of predefined variables
    known to the __vset__ markup command during processing, and gives it the
    specified *value*\. The method returns the empty string as its result\.

  - <a name='9'></a>__::doctools::toc::parse__ __var unset__ *name*

    This method removes the variable *name* from the set of predefined
    variables known to the __vset__ markup command during processing\. The
    method returns the empty string as its result\.

  - <a name='10'></a>__::doctools::toc::parse__ __var clear__ ?*pattern*?

    This method removes all variables matching the *pattern* from the set of
    predefined variables known to the __vset__ markup command during
    processing\. The method returns the empty string as its result\.

    The pattern matching is done with __string match__, and the default
    pattern used when none is specified, is __\*__\.

# <a name='section3'></a>Parse errors

The format of the parse error messages thrown when encountering violations of
the *[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc)* markup syntax is human
readable and not intended for processing by machines\. As such it is not
documented\.

*However*, the errorCode attached to the message is machine\-readable and has
the following format:

  1. The error code will be a list, each element describing a single error found
     in the input\. The list has at least one element, possibly more\.

  1. Each error element will be a list containing six strings describing an
     error in detail\. The strings will be

       1) The path of the file the error occurred in\. This may be empty\.

       1) The range of the token the error was found at\. This range is a
          two\-element list containing the offset of the first and last character
          in the range, counted from the beginning of the input \(file\)\. Offsets
          are counted from zero\.

       1) The line the first character after the error is on\. Lines are counted
          from one\.

       1) The column the first character after the error is at\. Columns are
          counted from zero\.

       1) The message code of the error\. This value can be used as argument to
          __msgcat::mc__ to obtain a localized error message, assuming that
          the application had a suitable call of __doctools::msgcat::init__
          to initialize the necessary message catalogs \(See package
          __[doctools::msgcat](\.\./doctools2base/tcllib\_msgcat\.md)__\)\.

       1) A list of details for the error, like the markup command involved\. In
          the case of message code __doctoc/include/syntax__ this value is
          the set of errors found in the included file, using the format
          described here\.

# <a name='section4'></a>\[doctoc\] notation of tables of contents

The doctoc format for tables of contents, also called the *doctoc markup
language*, is too large to be covered in single section\. The interested reader
should start with the document

  1. *[doctoc language introduction](\.\./doctools/doctoc\_lang\_intro\.md)*

and then proceed from there to the formal specifications, i\.e\. the documents

  1. *[doctoc language syntax](\.\./doctools/doctoc\_lang\_syntax\.md)* and

  1. *[doctoc language command
     reference](\.\./doctools/doctoc\_lang\_cmdref\.md)*\.

to get a thorough understanding of the language\.

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
[lexer](\.\./\.\./\.\./\.\./index\.md\#lexer),
[parser](\.\./\.\./\.\./\.\./index\.md\#parser)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
