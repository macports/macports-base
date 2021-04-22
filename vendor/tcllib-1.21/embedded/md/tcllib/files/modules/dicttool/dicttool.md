
[//000000001]: # (dicttool \- Extensions to the standard "dict" command)
[//000000002]: # (Generated from file 'dicttool\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2017 Sean Woods <yoda@etoyoc\.com>)
[//000000004]: # (dicttool\(n\) 1\.0 tcllib "Extensions to the standard "dict" command")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

dicttool \- Dictionary Tools

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require dicttool ?1\.0?  

[__ladd__ *varname* *args*](#1)  
[__ldelete__ *varname* *args*](#2)  
[__dict getnull__ *args*](#3)  
[__dict print__ *dict*](#4)  
[__dict is\_dict__ *value*](#5)  
[__rmerge__ *args*](#6)  

# <a name='description'></a>DESCRIPTION

The __dicttool__ package enhances the standard *dict* command with several
new commands\. In addition, the package also defines several "creature comfort"
list commands as well\. Each command checks to see if a command already exists of
the same name before adding itself, just in case any of these slip into the
core\.

  - <a name='1'></a>__ladd__ *varname* *args*

    This command will add a new instance of each element in *args* to
    *varname*, but only if that element is not already present\.

  - <a name='2'></a>__ldelete__ *varname* *args*

    This command will delete all instances of each element in *args* from
    *varname*\.

  - <a name='3'></a>__dict getnull__ *args*

    Operates like __dict get__, however if the key *args* does not exist,
    it returns an empty list instead of throwing an error\.

  - <a name='4'></a>__dict print__ *dict*

    This command will produce a string representation of *dict*, with each
    nested branch on a newline, and indented with two spaces for every level\.

  - <a name='5'></a>__dict is\_dict__ *value*

    This command will return true if *value* can be interpreted as a dict\. The
    command operates in such a way as to not force an existing dict
    representation to shimmer into another internal rep\.

  - <a name='6'></a>__rmerge__ *args*

    Return a dict which is the product of a recursive merge of all of the
    arguments\. Unlike __dict merge__, this command descends into all of the
    levels of a dict\. Dict keys which end in a : indicate a leaf, which will be
    interpreted as a literal value, and not descended into further\.

        set items [dict merge {
          option {color {default: green}}
        } {
          option {fruit {default: mango}}
        } {
          option {color {default: blue} fruit {widget: select values: {mango apple cherry grape}}}
        }]
        puts [dict print $items]

    Prints the following result:

        option {
          color {
            default: blue
          }
          fruit {
            widget: select
            values: {mango apple cherry grape}
          }
        }

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *dict* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[dict](\.\./\.\./\.\./\.\./index\.md\#dict)

# <a name='category'></a>CATEGORY

Utilities

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2017 Sean Woods <yoda@etoyoc\.com>
