
[//000000001]: # (yaml \- YAML processing)
[//000000002]: # (Generated from file 'yaml\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2008 KATO Kanryu <kanryu6@users\.sourceforge\.net>)
[//000000004]: # (yaml\(n\) 0\.4\.1 tcllib "YAML processing")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

yaml \- YAML Format Encoder/Decoder

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [EXAMPLES](#section3)

  - [LIMITATIONS](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require yaml ?0\.4\.1?  

[__::yaml::yaml2dict__ ?*options*? *txt*](#1)  
[__::yaml::yaml2huddle__ ?*options*? *txt*](#2)  
[__::yaml::setOption__ ?*options*?](#3)  
[__::yaml::dict2yaml__ *dict* ?*indent*? ?*wordwrap*?](#4)  
[__::yaml::list2yaml__ *list* ?*indent*? ?*wordwrap*?](#5)  
[__::yaml::huddle2yaml__ *huddle* ?*indent*? ?*wordwrap*?](#6)  

# <a name='description'></a>DESCRIPTION

The __yaml__ package provides a simple Tcl\-only library for parsing the YAML
[http://www\.yaml\.org/](http://www\.yaml\.org/) data exchange format as
specified in [http://www\.yaml\.org/spec/1\.1/](http://www\.yaml\.org/spec/1\.1/)\.

The __yaml__ package returns data as a Tcl
__[dict](\.\./\.\./\.\./\.\./index\.md\#dict)__\. Either the
__[dict](\.\./\.\./\.\./\.\./index\.md\#dict)__ package or Tcl 8\.5 is required for
use\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::yaml::yaml2dict__ ?*options*? *txt*

  - <a name='2'></a>__::yaml::yaml2huddle__ ?*options*? *txt*

    Parse yaml formatted text *txt* into a Tcl dict/huddle and return the
    value\.

      * ____\-file____

        *txt* is a filename of YAML\-stream\.

      * ____\-stream____

        *txt* is just a YAML\-stream\.

      * ____\-types__ *list*__

        The *list* is a type list for the yaml\-scalar types\.\(e\.g\. \!\!str
        \!\!timestamp \!\!integer \!\!true \.\.\.\)

            -types {timestamp integer null true false}

        In this case, if a string matched "timestamp", converted to the TCL
        internal timestamp\.\(e\.g\. "2001\-12\-15T02:59:43\.1Z" => 1008385183\)

      * ____\-m:true__ *param*__

        The *param* is two elements of list for the value of true, and
        considered strings\.

            -m:true {1 {true on + yes y}}

        In this case, the string "yes" found in YAML Stream, automatically
        converted 1\.

      * ____\-m:false__ *param*__

        The *param* is two elements of list for the value of false, and
        considered strings\.

            -m:false {0 {false off - no n}}

      * ____\-m:null__ *param*__

        The *param* is two elements of list for the value of null, and
        considered strings\.

            -m:null {"" {null nil "" ~}}

      * ____\-validate____

        Experiment,old: Output stream contains YAML's\-tag, each node\.

            % puts [::yaml::load -validate {[aaa, bbb]}]
            =>
            !!seq {{!!str aaa} {!!str bbb}}

  - <a name='3'></a>__::yaml::setOption__ ?*options*?

    Change implicit options for the library\. Now, the params are the same as
    __::yaml::yaml2dict__\. Arguments of__::yaml::yaml2dict__ is more
    priority than this setting\.

  - <a name='4'></a>__::yaml::dict2yaml__ *dict* ?*indent*? ?*wordwrap*?

  - <a name='5'></a>__::yaml::list2yaml__ *list* ?*indent*? ?*wordwrap*?

  - <a name='6'></a>__::yaml::huddle2yaml__ *huddle* ?*indent*? ?*wordwrap*?

    Convert a dict/list/huddle object into YAML stream\.

      * indent

        spaces indent of each block node\. currently default is 2\.

      * wordwrap

        word wrap for YAML stream\. currently default is 40\.

# <a name='section3'></a>EXAMPLES

An example of a yaml stream converted to Tcl\. A yaml stream is returned as a
single item with multiple elements\.

    {
    --- !<tag:clarkevans.com,2002:invoice>
    invoice: 34843
    date   : 2001-01-23
    bill-to: &id001
        given  : Chris
        family : Dumars
        address:
            lines: |
                458 Walkman Dr.
                Suite #292
            city    : Royal Oak
            state   : MI
            postal  : 48046
    ship-to: *id001
    product:
        - sku         : BL394D
          quantity    : 4
          description : Basketball
          price       : 450.00
        - sku         : BL4438H
          quantity    : 1
          description : Super Hoop
          price       : 2392.00
    tax  : 251.42
    total: 4443.52
    comments:
        Late afternoon is best.
        Backup contact is Nancy
        Billsmer @ 338-4338.
    }
    =>
    invoice 34843 date 2001-01-23 bill-to {given Chris family Dumars address {lines {458 Walkman Dr.
    Suite #292
    } city {Royal Oak} state MI postal 48046}} ship-to {given Chris family Dumars address {lines {458 Walkman Dr.
    Suite #292
    } city {Royal Oak} state MI postal 48046}} product {{sku BL394D quantity 4 description Basketball price 450.00} {sku BL4438H quantity 1 description {Super Hoop} price 2392.00}} tax 251.42 total 4443.52 comments {Late afternoon is best. Backup contact is Nancy Billsmer @ 338-4338.}

An example of a yaml object converted to Tcl\. A yaml object is returned as a
multi\-element list \(a dict\)\.

    {
    ---
    - [name        , hr, avg  ]
    - [Mark McGwire, 65, 0.278]
    - [Sammy Sosa  , 63, 0.288]
    -
      Mark McGwire: {hr: 65, avg: 0.278}
      Sammy Sosa: { hr: 63, avg: 0.288}
    }
    =>
    {name hr avg} {{Mark McGwire} 65 0.278} {{Sammy Sosa} 63 0.288} {{Mark McGwire} {hr 65 avg 0.278} {Sammy Sosa} {hr 63 avg 0.288}}

# <a name='section4'></a>LIMITATIONS

tag parser not implemented\. currentry, tags are merely ignored\.

Only Anchor => Aliases ordering\. back alias\-referring is not supported\.

Too many braces, or too few braces\.

Not enough character set of line feeds\. Please use only "\\n" as line breaks\.

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *yaml* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[base64](\.\./base64/base64\.md), [huddle](huddle\.md),
[json](\.\./json/json\.md)

# <a name='keywords'></a>KEYWORDS

[data exchange](\.\./\.\./\.\./\.\./index\.md\#data\_exchange),
[huddle](\.\./\.\./\.\./\.\./index\.md\#huddle),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing), [text
processing](\.\./\.\./\.\./\.\./index\.md\#text\_processing),
[yaml](\.\./\.\./\.\./\.\./index\.md\#yaml)

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2008 KATO Kanryu <kanryu6@users\.sourceforge\.net>
