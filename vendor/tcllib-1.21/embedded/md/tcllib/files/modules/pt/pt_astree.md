
[//000000001]: # (pt::ast \- Parser Tools)
[//000000002]: # (Generated from file 'pt\_astree\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pt::ast\(n\) 1\.1 tcllib "Parser Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pt::ast \- Abstract Syntax Tree Serialization

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [AST serialization format](#section3)

      - [Example](#subsection1)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require pt::ast ?1\.1?  

[__::pt::ast__ __verify__ *serial* ?*canonvar*?](#1)  
[__::pt::ast__ __verify\-as\-canonical__ *serial*](#2)  
[__::pt::ast__ __canonicalize__ *serial*](#3)  
[__::pt::ast__ __print__ *serial*](#4)  
[__::pt::ast__ __bottomup__ *cmdprefix* *ast*](#5)  
[__cmdprefix__ *ast*](#6)  
[__::pt::ast__ __topdown__ *cmdprefix* *pe*](#7)  
[__::pt::ast__ __equal__ *seriala* *serialb*](#8)  
[__::pt::ast__ __new0__ *s* *loc* ?*child*\.\.\.?](#9)  
[__::pt::ast__ __new__ *s* *start* *end* ?*child*\.\.\.?](#10)  

# <a name='description'></a>DESCRIPTION

Are you lost ? Do you have trouble understanding this document ? In that case
please read the overview provided by the *[Introduction to Parser
Tools](pt\_introduction\.md)*\. This document is the entrypoint to the whole
system the current package is a part of\.

This package provides commands to work with the serializations of abstract
syntax trees as managed by the Parser Tools, and specified in section [AST
serialization format](#section3)\.

This is a supporting package in the Core Layer of Parser Tools\.

![](\.\./\.\./\.\./\.\./image/arch\_core\_support\.png)

# <a name='section2'></a>API

  - <a name='1'></a>__::pt::ast__ __verify__ *serial* ?*canonvar*?

    This command verifies that the content of *serial* is a valid
    serialization of an abstract syntax tree and will throw an error if that is
    not the case\. The result of the command is the empty string\.

    If the argument *canonvar* is specified it is interpreted as the name of a
    variable in the calling context\. This variable will be written to if and
    only if *serial* is a valid regular serialization\. Its value will be a
    boolean, with __True__ indicating that the serialization is not only
    valid, but also *canonical*\. __False__ will be written for a valid,
    but non\-canonical serialization\.

    For the specification of serializations see the section [AST serialization
    format](#section3)\.

  - <a name='2'></a>__::pt::ast__ __verify\-as\-canonical__ *serial*

    This command verifies that the content of *serial* is a valid
    *canonical* serialization of an abstract syntax tree and will throw an
    error if that is not the case\. The result of the command is the empty
    string\.

    For the specification of canonical serializations see the section [AST
    serialization format](#section3)\.

  - <a name='3'></a>__::pt::ast__ __canonicalize__ *serial*

    This command assumes that the content of *serial* is a valid *regular*
    serialization of an abstract syntax and will throw an error if that is not
    the case\.

    It will then convert the input into the *canonical* serialization of the
    contained tree and return it as its result\. If the input is already
    canonical it will be returned unchanged\.

    For the specification of regular and canonical serializations see the
    section [AST serialization format](#section3)\.

  - <a name='4'></a>__::pt::ast__ __print__ *serial*

    This command assumes that the argument *serial* contains a valid
    serialization of an abstract syntax tree and returns a string containing
    that tree in a human readable form\.

    The exact format of this form is not specified and cannot be relied on for
    parsing or other machine\-based activities\.

    For the specification of serializations see the section [AST serialization
    format](#section3)\.

  - <a name='5'></a>__::pt::ast__ __bottomup__ *cmdprefix* *ast*

    This command walks the abstract syntax tree *ast* from the bottom up to
    the root, invoking the command prefix *cmdprefix* for each node\. This
    implies that the children of a node N are handled before N\.

    The command prefix has the signature

      * <a name='6'></a>__cmdprefix__ *ast*

        I\.e\. it is invoked with the ast node the walk is currently at\.

        The result returned by the command prefix replaces *ast* in the node
        it was a child of, allowing transformations of the tree\.

        This also means that for all inner node the contents of the children
        elements are the results of the command prefix invoked for the children
        of this node\.

  - <a name='7'></a>__::pt::ast__ __topdown__ *cmdprefix* *pe*

    This command walks the abstract syntax tree *ast* from the root down to
    the leaves, invoking the command prefix *cmdprefix* for each node\. This
    implies that the children of a node N are handled after N\.

    The command prefix has the same signature as for __bottomup__, see
    above\.

    The result returned by the command prefix is *ignored*\.

  - <a name='8'></a>__::pt::ast__ __equal__ *seriala* *serialb*

    This command tests the two sbstract syntax trees *seriala* and *serialb*
    for structural equality\. The result of the command is a boolean value\. It
    will be set to __true__ if the trees are identical, and __false__
    otherwise\.

    String equality is usable only if we can assume that the two trees are pure
    Tcl lists\.

  - <a name='9'></a>__::pt::ast__ __new0__ *s* *loc* ?*child*\.\.\.?

    This command command constructs the ast for a nonterminal node refering
    refering to the symbol *s* at position *loc* in the input, and the set
    of child nodes *child* \.\.\., from left right\. The latter may be empty\. The
    constructed node is returned as the result of the command\. The end position
    is *loc*\-1, i\.e\. one character before the start\. This type of node is
    possible for rules containing optional parts\.

  - <a name='10'></a>__::pt::ast__ __new__ *s* *start* *end* ?*child*\.\.\.?

    This command command constructs the ast for a nonterminal node refering to
    the symbol *s* covering the range of positions *start* to *end* in the
    input, and the set of child nodes *child* \.\.\., from left right\. The latter
    may be empty\. The constructed node is returned as the result of the command\.

# <a name='section3'></a>AST serialization format

Here we specify the format used by the Parser Tools to serialize Abstract Syntax
Trees \(ASTs\) as immutable values for transport, comparison, etc\.

Each node in an AST represents a nonterminal symbol of a grammar, and the range
of tokens/characters in the input covered by it\. ASTs do not contain terminal
symbols, i\.e\. tokens/characters\. These can be recovered from the input given a
symbol's location\.

We distinguish between *regular* and *canonical* serializations\. While a
tree may have more than one regular serialization only exactly one of them will
be *canonical*\.

  - Regular serialization

      1. The serialization of any AST is the serialization of its root node\.

      1. The serialization of any node is a Tcl list containing at least three
         elements\.

           1) The first element is the name of the nonterminal symbol stored in
              the node\.

           1) The second and third element are the locations of the first and
              last token in the token stream the node represents \(covers\)\.

                1. Locations are provided as non\-negative integer offsets from
                   the beginning of the token stream, with the first token found
                   in the stream located at offset 0 \(zero\)\.

                1. The end location has to be equal to or larger than the start
                   location\.

           1) All elements after the first three represent the children of the
              node, which are themselves nodes\. This means that the
              serializations of nodes without children, i\.e\. leaf nodes, have
              exactly three elements\. The children are stored in the list with
              the leftmost child first, and the rightmost child last\.

  - Canonical serialization

    The canonical serialization of an abstract syntax tree has the format as
    specified in the previous item, and then additionally satisfies the
    constraints below, which make it unique among all the possible
    serializations of this tree\.

      1. The string representation of the value is the canonical representation
         of a pure Tcl list\. I\.e\. it does not contain superfluous whitespace\.

## <a name='subsection1'></a>Example

Assuming the parsing expression grammar below

    PEG calculator (Expression)
        Digit      <- '0'/'1'/'2'/'3'/'4'/'5'/'6'/'7'/'8'/'9'       ;
        Sign       <- '-' / '+'                                     ;
        Number     <- Sign? Digit+                                  ;
        Expression <- Term (AddOp Term)*                            ;
        MulOp      <- '*' / '/'                                     ;
        Term       <- Factor (MulOp Factor)*                        ;
        AddOp      <- '+'/'-'                                       ;
        Factor     <- '(' Expression ')' / Number                   ;
    END;

and the input string

    120+5

then a parser should deliver the abstract syntax tree below \(except for
whitespace\)

    set ast {Expression 0 4
        {Factor 0 4
            {Term 0 2
                {Number 0 2
                    {Digit 0 0}
                    {Digit 1 1}
                    {Digit 2 2}
                }
            }
            {AddOp 3 3}
            {Term 4 4
                {Number 4 4
                    {Digit 4 4}
                }
            }
        }
    }

Or, more graphical

![](\.\./\.\./\.\./\.\./image/expr\_ast\.png)

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *pt* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[EBNF](\.\./\.\./\.\./\.\./index\.md\#ebnf), [LL\(k\)](\.\./\.\./\.\./\.\./index\.md\#ll\_k\_),
[PEG](\.\./\.\./\.\./\.\./index\.md\#peg), [TDPL](\.\./\.\./\.\./\.\./index\.md\#tdpl),
[context\-free languages](\.\./\.\./\.\./\.\./index\.md\#context\_free\_languages),
[expression](\.\./\.\./\.\./\.\./index\.md\#expression),
[grammar](\.\./\.\./\.\./\.\./index\.md\#grammar),
[matching](\.\./\.\./\.\./\.\./index\.md\#matching),
[parser](\.\./\.\./\.\./\.\./index\.md\#parser), [parsing
expression](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression), [parsing expression
grammar](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression\_grammar), [push down
automaton](\.\./\.\./\.\./\.\./index\.md\#push\_down\_automaton), [recursive
descent](\.\./\.\./\.\./\.\./index\.md\#recursive\_descent),
[state](\.\./\.\./\.\./\.\./index\.md\#state), [top\-down parsing
languages](\.\./\.\./\.\./\.\./index\.md\#top\_down\_parsing\_languages),
[transducer](\.\./\.\./\.\./\.\./index\.md\#transducer)

# <a name='category'></a>CATEGORY

Parsing and Grammars

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
