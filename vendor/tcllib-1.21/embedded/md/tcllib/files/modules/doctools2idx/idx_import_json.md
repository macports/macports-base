
[//000000001]: # (doctools::idx::import::json \- Documentation tools)
[//000000002]: # (Generated from file 'plugin\.inc' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009\-2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools::idx::import::json\(n\) 0\.2\.1 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools::idx::import::json \- JSON import plugin

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [JSON notation of keyword indices](#section3)

  - [Keyword index serialization format](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require doctools::idx::import::json ?0\.2\.1?  
package require doctools::idx::structure  
package require json  

[__[import](\.\./\.\./\.\./\.\./index\.md\#import)__ *string* *configuration*](#1)  

# <a name='description'></a>DESCRIPTION

This package implements the doctools keyword index import plugin for the parsing
of JSON markup\.

This is an internal package of doctools, for use by the higher level management
packages handling keyword indices, especially
__[doctools::idx::import](idx\_import\.md)__, the import manager\.

Using it from a regular interpreter is possible, however only with contortions,
and is not recommended\. The proper way to use this functionality is through the
package __[doctools::idx::import](idx\_import\.md)__ and the import
manager objects it provides\.

# <a name='section2'></a>API

The API provided by this package satisfies the specification of the docidx
import plugin API version 2\.

  - <a name='1'></a>__[import](\.\./\.\./\.\./\.\./index\.md\#import)__ *string* *configuration*

    This command takes the *string* and parses it as JSON markup encoding a
    keyword index, in the context of the specified *configuration* \(a
    dictionary\)\. The result of the command is the canonical serialization of
    that keyword index, in the form specified in section [Keyword index
    serialization format](#section4)\.

# <a name='section3'></a>JSON notation of keyword indices

The JSON format used for keyword indices is a direct translation of the
[Keyword index serialization format](#section4), mapping Tcl dictionaries
as JSON objects and Tcl lists as JSON arrays\. For example, the Tcl serialization

    doctools::idx {
    	label {Keyword Index}
    	keywords {
    		changelog  {changelog.man cvs.man}
    		conversion {doctools.man docidx.man doctoc.man apps/dtplite.man mpexpand.man}
    		cvs        cvs.man
    	}
    	references {
    		apps/dtplite.man {manpage dtplite}
    		changelog.man    {manpage doctools::changelog}
    		cvs.man          {manpage doctools::cvs}
    		docidx.man       {manpage doctools::idx}
    		doctoc.man       {manpage doctools::toc}
    		doctools.man     {manpage doctools}
    		mpexpand.man     {manpage mpexpand}
    	}
    	title {}
    }

is equivalent to the JSON string

    {
        "doctools::idx" : {
            "label"      : "Keyword Index",
            "keywords"   : {
                "changelog"  : ["changelog.man","cvs.man"],
                "conversion" : ["doctools.man","docidx.man","doctoc.man","apps\/dtplite.man","mpexpand.man"],
                "cvs"        : ["cvs.man"],
            },
            "references" : {
                "apps\/dtplite.man" : ["manpage","dtplite"],
                "changelog.man"     : ["manpage","doctools::changelog"],
                "cvs.man"           : ["manpage","doctools::cvs"],
                "docidx.man"        : ["manpage","doctools::idx"],
                "doctoc.man"        : ["manpage","doctools::toc"],
                "doctools.man"      : ["manpage","doctools"],
                "mpexpand.man"      : ["manpage","mpexpand"]
            },
            "title"      : ""
        }
    }

# <a name='section4'></a>Keyword index serialization format

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
[import](\.\./\.\./\.\./\.\./index\.md\#import),
[index](\.\./\.\./\.\./\.\./index\.md\#index)

# <a name='category'></a>CATEGORY

Text formatter plugin

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009\-2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
