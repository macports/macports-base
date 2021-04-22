
[//000000001]: # (grammar::me::util \- Grammar operations and usage)
[//000000002]: # (Generated from file 'me\_util\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (grammar::me::util\(n\) 0\.1 tcllib "Grammar operations and usage")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

grammar::me::util \- AST utilities

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require grammar::me::util ?0\.1?  

[__::grammar::me::util::ast2tree__ *ast* *tree* ?*root*?](#1)  
[__::grammar::me::util::ast2etree__ *ast* *mcmd* *tree* ?*root*?](#2)  
[__mcmd__ __lc__ *location*](#3)  
[__mcmd__ __tok__ *from* ?*to*?](#4)  
[__::grammar::me::util::tree2ast__ *tree* ?*root*?](#5)  

# <a name='description'></a>DESCRIPTION

This package provides a number of utility command for the conversion between the
various representations of abstract syntax trees as specified in the document
__[grammar::me\_ast](me\_ast\.md)__\.

  - <a name='1'></a>__::grammar::me::util::ast2tree__ *ast* *tree* ?*root*?

    This command converts an *ast* from value to object representation\. All
    nodes in the *ast* will be converted into nodes of this *tree*, with the
    root of the AST a child of the node *root*\. If this node is not explicitly
    specified the root of the tree is used\. Existing content of tree is not
    touched, i\.e\. neither removed nor changed, with the exception of the
    specified root node, which will gain a new child\.

  - <a name='2'></a>__::grammar::me::util::ast2etree__ *ast* *mcmd* *tree* ?*root*?

    This command is like __::grammar::me::util::ast2tree__, except that the
    result is in the extended object representation of the input AST\. The source
    of the extended information is the command prefix *mcmd*\. It has to
    understand two methods, __lc__, and __tok__, with the semantics
    specified below\.

      * <a name='3'></a>__mcmd__ __lc__ *location*

        Takes the location of a token given as offset in the input stream and
        return a 2\-element list containing the associated line number and column
        index, in this order\.

      * <a name='4'></a>__mcmd__ __tok__ *from* ?*to*?

        Takes one or two locations *from* and *to* as offset in the input
        stream and returns a Tcl list containing the specified part of the input
        stream\. Both location are inclusive\. If *to* is not specified it will
        default to the value of *from*\.

        Each element of the returned list is a list containing the token, its
        associated lexeme, the line number, and column index, in this order\.

    Both the ensemble command __::grammar::me::tcl__ provided by the package
    __[grammar::me::tcl](me\_tcl\.md)__ and the objects command created by
    the package __::grammar::me::cpu__ fit the above specification\.

  - <a name='5'></a>__::grammar::me::util::tree2ast__ *tree* ?*root*?

    This command converts an *ast* in \(extended\) object representation into a
    value and returns it\. If a *root* node is specified the AST is generated
    from that node downward\. Otherwise the root of the tree object is used as
    the starting point\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *grammar\_me* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[abstract syntax tree](\.\./\.\./\.\./\.\./index\.md\#abstract\_syntax\_tree), [syntax
tree](\.\./\.\./\.\./\.\./index\.md\#syntax\_tree),
[tree](\.\./\.\./\.\./\.\./index\.md\#tree)

# <a name='category'></a>CATEGORY

Grammars and finite automata

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
