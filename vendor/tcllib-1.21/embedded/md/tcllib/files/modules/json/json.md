
[//000000001]: # (json \- JSON)
[//000000002]: # (Generated from file 'json\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006 ActiveState Software Inc\.)
[//000000004]: # (Copyright &copy; 2009 Thomas Maeder, Glue Software Engineering AG)
[//000000005]: # (json\(n\) 1\.3\.4 tcllib "JSON")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

json \- JSON parser

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [EXAMPLES](#section3)

  - [RELATED](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require json ?1\.3\.4?  

[__::json::json2dict__ *txt*](#1)  
[__::json::many\-json2dict__ *txt* ?*max*?](#2)  

# <a name='description'></a>DESCRIPTION

The __json__ package provides a simple Tcl\-only library for parsing the JSON
[http://www\.json\.org/](http://www\.json\.org/) data exchange format as
specified in RFC 4627
[http://www\.ietf\.org/rfc/rfc4627\.txt](http://www\.ietf\.org/rfc/rfc4627\.txt)\.
There is some ambiguity in parsing JSON because JSON has type information that
is not maintained by the Tcl conversion\. The __json__ package returns data
as a Tcl __[dict](\.\./\.\./\.\./\.\./index\.md\#dict)__\. Either the
__[dict](\.\./\.\./\.\./\.\./index\.md\#dict)__ package or Tcl 8\.5 is required for
use\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::json::json2dict__ *txt*

    Parse JSON formatted text *txt* into a Tcl dict and return the value\.

    If *txt* contains more than one JSON entity only the first one is
    returned\.

  - <a name='2'></a>__::json::many\-json2dict__ *txt* ?*max*?

    Parse JSON formatted text *txt* containing multiple JSON entities into a
    list of dictionaries and return that list\.

    If *max* is specified exactly that many entities are extracted from
    *txt*\. By default the command will attempt to extract all, without limits\.
    A value of "*max* == 0" does not make sense and will cause the command to
    throw an error\.

# <a name='section3'></a>EXAMPLES

An example of a JSON array converted to Tcl\. A JSON array is returned as a
single item with multiple elements\.

    [
        {
           "precision": "zip",
           "Latitude":  37.7668,
           "Longitude": -122.3959,
           "Address":   "",
           "City":      "SAN FRANCISCO",
           "State":     "CA",
           "Zip":       "94107",
           "Country":   "US"
        },
        {
           "precision": "zip",
           "Latitude":  37.371991,
           "Longitude": -122.026020,
           "Address":   "",
           "City":      "SUNNYVALE",
           "State":     "CA",
           "Zip":       "94085",
           "Country":   "US"
        }
    ]
    =>
    {Country US Latitude 37.7668 precision zip State CA City {SAN FRANCISCO} Address {} Zip 94107 Longitude -122.3959} {Country US Latitude 37.371991 precision zip State CA City SUNNYVALE Address {} Zip 94085 Longitude -122.026020}

An example of a JSON object converted to Tcl\. A JSON object is returned as a
multi\-element list \(a dict\)\.

    {
        "Image": {
            "Width":  800,
            "Height": 600,
            "Title":  "View from 15th Floor",
            "Thumbnail": {
                "Url":    "http://www.example.com/image/481989943",
                "Height": 125,
                "Width":  "100"
            },
            "IDs": [116, 943, 234, 38793]
        }
    }
    =>
    Image {IDs {116 943 234 38793} Thumbnail {Width 100 Height 125 Url http://www.example.com/image/481989943} Width 800 Height 600 Title {View from 15th Floor}}

# <a name='section4'></a>RELATED

To write json, instead of parsing it, see package
__[json::write](json\_write\.md)__\.

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *json* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[data exchange](\.\./\.\./\.\./\.\./index\.md\#data\_exchange), [exchange
format](\.\./\.\./\.\./\.\./index\.md\#exchange\_format),
[javascript](\.\./\.\./\.\./\.\./index\.md\#javascript),
[json](\.\./\.\./\.\./\.\./index\.md\#json)

# <a name='category'></a>CATEGORY

CGI programming

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006 ActiveState Software Inc\.  
Copyright &copy; 2009 Thomas Maeder, Glue Software Engineering AG
