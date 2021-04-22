
[//000000001]: # (doctools::tcl::parse \- Documentation tools)
[//000000002]: # (Generated from file 'tcl\_parse\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools::tcl::parse\(n\) 1 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools::tcl::parse \- Processing text in 'subst \-novariables' format

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Error format](#section3)

  - [Tree Structure](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require snit  
package require fileutil  
package require logger  
package require struct::list  
package require struct::stack  
package require struct::set  
package require treeql  
package require doctools::tcl::parse  

[__::doctools::tcl::parse__ __text__ *tree* *text* ?*root*?](#1)  
[__::doctools::tcl::parse__ __file__ *tree* *path* ?*root*?](#2)  

# <a name='description'></a>DESCRIPTION

This package provides commands for parsing text with embedded Tcl commands as
accepted by the Tcl builtin command __subst \-novariables__\. The result of
the parsing is an abstract syntax tree\.

This is an internal package of doctools, for use by the higher level parsers
processing the *[docidx](\.\./\.\./\.\./\.\./index\.md\#docidx)*,
*[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc)*, and
*[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools)* markup languages\.

# <a name='section2'></a>API

  - <a name='1'></a>__::doctools::tcl::parse__ __text__ *tree* *text* ?*root*?

    The command takes the *text* and parses it under the assumption that it
    contains a string acceptable to the Tcl builtin command __subst
    \-novariables__\. Errors are thrown otherwise during the parsing\. The format
    used for these errors in described in section [Error
    format](#section3)\.

    The command returns the empty string as it result\. The actual result of the
    parsing is entered into the tree structure *tree*, under the node
    *root*\. If *root* is not specified the root of *tree* is used\. The
    *tree* has to exist and be the command of a tree object which supports the
    same methods as trees created by the package
    __[struct::tree](\.\./struct/struct\_tree\.md)__\.

    In case of errors *tree* will be left in an undefined state\.

  - <a name='2'></a>__::doctools::tcl::parse__ __file__ *tree* *path* ?*root*?

    The same as __text__, except that the text to parse is read from the
    file specified by *path*\.

# <a name='section3'></a>Error format

When the parser encounters a problem in the input it will throw an error using
the format described here\.

  1. The message will contain the reason for the problem \(unexpected character
     or end of input in input\), the character in question, if any, and the line
     and column the problem was found at, in a human readable form\. This part is
     not documented further as its format may change as we see fit\. It is
     intended for human consumption, not machine\.

  1. The error code however will contain a machine\-readable representation of
     the problem, in the form of a 5\-element list containing, in the order
     listed below

       1) the constant string __doctools::tcl::parse__

       1) the cause of the problem, one of

            - __char__

              Unexpected character in input

            - __eof__

              Unexpected end of the input

       1) The location of the problem as offset from the beginning of the input,
          counted in characters\. Note: Line markers count as one character\.

       1) The line the problem was found on \(counted from 1 \(one\)\),

       1) The column the problem was found at \(counted from 0 \(zero\)\)

# <a name='section4'></a>Tree Structure

After successfully parsing a string the generated tree will have the following
structure:

  1. In the following items the word 'root' refers to the node which was
     specified as the root of the tree when invoking either __text__ or
     __file__\. This may be the actual root of the tree\.

  1. All the following items further ignore the possibility of pre\-existing
     attributes in the pre\-existing nodes\. If attributes exists with the same
     names as the attributes used by the parser the pre\-existing values are
     written over\. Attributes with names not clashing with the parser's
     attributes are not touched\.

  1. The root node has no attributes\.

  1. All other nodes have the attributes

       - type

         The value is a string from the set \{ Command , Text , Word \}

       - range

         The value is either empty or a 2\-element list containing integer
         numbers\. The numbers are the offsets of the first and last character in
         the input text, of the token described by the node,\.

       - line

         The value is an integer, it describes the line in the input the token
         described by the node ends on\. Lines are counted from 1 \(__one__\)\.

       - col

         The value is an integer, it describes the column in the line in the
         input the token described by the node ends on\. Columns are counted from
         0 \(__zero__\)\.

  1. The children of the root, if any, are of type Command and Text, in
     semi\-alternation\. This means: After a Text node a Command node has to
     follow, and anything can follow a Command node, a Text or other Command
     node\.

  1. The children of a Command node, if any, are of type Command, and Text, and
     Word, they describe the arguments of the command\.

  1. The children of a Word node, if any, are of type Command, Text, in
     semi\-alternation\. This means: After a Text node a Command node has to
     follow, and anything can follow a Command node, a Text or other Command
     node\.

  1. A Word node without children represents the empty string\.

  1. All Text nodes are leaves of the tree\.

  1. All leaves of the tree are either Text or Command nodes\. Word nodes cannot
     be leaves\.

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

[Tcl syntax](\.\./\.\./\.\./\.\./index\.md\#tcl\_syntax),
[command](\.\./\.\./\.\./\.\./index\.md\#command),
[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools),
[parser](\.\./\.\./\.\./\.\./index\.md\#parser),
[subst](\.\./\.\./\.\./\.\./index\.md\#subst), [word](\.\./\.\./\.\./\.\./index\.md\#word)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
