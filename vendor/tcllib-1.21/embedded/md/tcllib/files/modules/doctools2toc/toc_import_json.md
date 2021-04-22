
[//000000001]: # (doctools::toc::import::json \- Documentation tools)
[//000000002]: # (Generated from file 'plugin\.inc' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009\-2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools::toc::import::json\(n\) 0\.2\.1 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools::toc::import::json \- JSON import plugin

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [JSON notation of tables of contents](#section3)

  - [ToC serialization format](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require doctools::toc::import::json ?0\.2\.1?  
package require doctools::toc::structure  
package require json  

[__[import](\.\./\.\./\.\./\.\./index\.md\#import)__ *string* *configuration*](#1)  

# <a name='description'></a>DESCRIPTION

This package implements the doctools table of contents import plugin for the
parsing of JSON markup\.

This is an internal package of doctools, for use by the higher level management
packages handling tables of contents, especially
__[doctools::toc::import](toc\_import\.md)__, the import manager\.

Using it from a regular interpreter is possible, however only with contortions,
and is not recommended\. The proper way to use this functionality is through the
package __[doctools::toc::import](toc\_import\.md)__ and the import
manager objects it provides\.

# <a name='section2'></a>API

The API provided by this package satisfies the specification of the doctoc
import plugin API version 2\.

  - <a name='1'></a>__[import](\.\./\.\./\.\./\.\./index\.md\#import)__ *string* *configuration*

    This command takes the *string* and parses it as JSON markup encoding a
    table of contents, in the context of the specified *configuration* \(a
    dictionary\)\. The result of the command is the canonical serialization of
    that table of contents, in the form specified in section [ToC serialization
    format](#section4)\.

# <a name='section3'></a>JSON notation of tables of contents

The JSON format used for tables of contents is a direct translation of the [ToC
serialization format](#section4), mapping Tcl dictionaries as JSON objects
and Tcl lists as JSON arrays\. For example, the Tcl serialization

    doctools::toc {
        items {
            {reference {
    	    desc {DocTools - Tables of Contents}
    	     id introduction.man
    	     label doctools::toc::introduction
    	}}
    	{division {
    	     id processing.man
    	     items {
    	         {reference {
    		     desc {doctoc serialization utilities}
    		     id structure.man
    		     label doctools::toc::structure
    		 }}
    		 {reference {
    		     desc {Parsing text in doctoc format}
    		     id parse.man
    		     label doctools::toc::parse
    		 }}
    	     }
                 label Processing
            }}
        }
        label {Table of Contents}
        title TOC
    }

is equivalent to the JSON string

    {
        "doctools::toc" : {
            "items" : [{
                "reference" : {
                    "desc"  : "DocTools - Tables of Contents",
                    "id"    : "introduction.man",
                    "label" : "doctools::toc::introduction"
                }
            },{
                "division" : {
                    "id"    : "processing.man",
                    "items" : [{
                        "reference" : {
                            "desc"  : "doctoc serialization utilities",
                            "id"    : "structure.man",
                            "label" : "doctools::toc::structure"
                        }
                    },{
                        "reference" : {
                            "desc"  : "Parsing text in doctoc format",
                            "id"    : "parse.man",
                            "label" : "doctools::toc::parse"
                        }
                    }],
                    "label" : "Processing"
                }
            }],
            "label" : "Table of Contents",
            "title" : "TOC"
        }
    }

# <a name='section4'></a>ToC serialization format

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

# <a name='section5'></a>Bugs, Ideas, Feedback

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

[JSON](\.\./\.\./\.\./\.\./index\.md\#json),
[deserialization](\.\./\.\./\.\./\.\./index\.md\#deserialization),
[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools),
[import](\.\./\.\./\.\./\.\./index\.md\#import), [table of
contents](\.\./\.\./\.\./\.\./index\.md\#table\_of\_contents),
[toc](\.\./\.\./\.\./\.\./index\.md\#toc)

# <a name='category'></a>CATEGORY

Text formatter plugin

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009\-2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
