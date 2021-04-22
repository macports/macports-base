
[//000000001]: # (pt::peg::interp \- Parser Tools)
[//000000002]: # (Generated from file 'pt\_peg\_interp\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pt::peg::interp\(n\) 1\.0\.1 tcllib "Parser Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pt::peg::interp \- Interpreter for parsing expression grammars

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

      - [Class API](#subsection1)

      - [Object API](#subsection2)

  - [AST serialization format](#section2)

      - [Example](#subsection3)

  - [PE serialization format](#section3)

      - [Example](#subsection4)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require pt::peg::interp ?1\.0\.1?  
package require pt::rde ?1?  
package require snit  

[__::pt::peg::interp__ *objectName* *grammar*](#1)  
[*objectName* __use__ *grammar*](#2)  
[*objectName* __destroy__](#3)  
[*objectName* __parse__ *chan*](#4)  
[*objectName* __parset__ *text*](#5)  

# <a name='description'></a>DESCRIPTION

Are you lost ? Do you have trouble understanding this document ? In that case
please read the overview provided by the *[Introduction to Parser
Tools](pt\_introduction\.md)*\. This document is the entrypoint to the whole
system the current package is a part of\.

This package provides a class whose instances are Packrat parsers configurable
with a parsing expression grammar\. The grammar is executed directly, i\.e\.
interpreted, with the underlying runtime provided by the package
__[pt::rde](pt\_rdengine\.md)__, basing everything on the PARAM\.

Like the supporting runtime this package resides in the Execution section of the
Core Layer of Parser Tools\.

![](\.\./\.\./\.\./\.\./image/arch\_core\_transform\.png)

The interpreted grammar is copied from an instance of
__[pt::peg::container](pt\_peg\_container\.md)__, or anything providing the
same API, like the container classes created by
__[pt::peg::to::container](pt\_peg\_to\_container\.md)__ or the associated
export plugin
__[pt::peg::export::container](pt\_peg\_export\_container\.md)__\.

## <a name='subsection1'></a>Class API

The package exports the API described here\.

  - <a name='1'></a>__::pt::peg::interp__ *objectName* *grammar*

    The command creates a new parser object and returns the fully qualified name
    of the object command as its result\. The API of this object command is
    described in the section [Object API](#subsection2)\. It may be used to
    invoke various operations on the object\.

    This new parser is configured for the execution of an empty PEG\. To
    configure the object for any other PEG use the method __use__ of the
    [Object API](#subsection2)\.

## <a name='subsection2'></a>Object API

All objects created by this package provide the following methods\.

  - <a name='2'></a>*objectName* __use__ *grammar*

    This method configures the grammar interpreter / parser for the execution of
    the PEG stored in *grammar*, an object which is API\-compatible to
    instances of __[pt::peg::container](pt\_peg\_container\.md)__\. The
    parser copies the relevant information of the grammar, and does *not* take
    ownership of the object\.

    The information of any previously used grammar is overwritten\.

    The result of the method the empty string\.

  - <a name='3'></a>*objectName* __destroy__

    This method destroys the parser instance, releasing all claimed memory and
    other resources, and deleting the instance command\.

    The result of the command is the empty string\.

  - <a name='4'></a>*objectName* __parse__ *chan*

    This method runs the parser using the contents of *chan* as input
    \(starting at the current location in the channel\), until parsing is not
    possible anymore, either because parsing has completed, or run into a syntax
    error\.

    Note here that the Parser Tools are based on Tcl 8\.5\+\. In other words, the
    channel argument is not restricted to files, sockets, etc\. We have the full
    power of *reflected channels* available\.

    It should also be noted that the parser pulls the characters from the input
    stream as it needs them\. If a parser created by this package has to be
    operated in a push aka event\-driven manner it will be necessary to go to Tcl
    8\.6\+ and use the __[coroutine::auto](\.\./coroutine/coro\_auto\.md)__ to
    wrap it into a coroutine where __[read](\.\./\.\./\.\./\.\./index\.md\#read)__
    is properly changed for push\-operation\.

    Upon successful completion the command returns an abstract syntax tree as
    its result\. This AST is in the form specified in section [AST serialization
    format](#section2)\. As a plain nested Tcl\-list it can then be processed
    with any Tcl commands the user likes, doing transformations, semantic
    checks, etc\. To help in this the package __[pt::ast](pt\_astree\.md)__
    provides a set of convenience commands for validation of the tree's basic
    structure, printing it for debugging, and walking it either from the bottom
    up, or top down\.

    When encountering a syntax error the command will throw an error instead\.
    This error will be a 4\-element Tcl\-list, containing, in the order listed
    below:

      1. The string __pt::rde__ identifying it as parser runtime error\.

      1. The location of the parse error, as character offset from the beginning
         of the parsed input\.

      1. The location of parse error, now as a 2\-element list containing
         line\-number and column in the line\.

      1. A set of atomic parsing expressions indicating encoding the characters
         and/or nonterminal symbols the parser expected to see at the location
         of the parse error, but did not get\. For the specification of atomic
         parsing expressions please see the section [PE serialization
         format](#section3)\.

  - <a name='5'></a>*objectName* __parset__ *text*

    This method runs the parser using the string in *text* as input\. In all
    other ways it behaves like the method __parse__, shown above\.

# <a name='section2'></a>AST serialization format

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

## <a name='subsection3'></a>Example

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

# <a name='section3'></a>PE serialization format

Here we specify the format used by the Parser Tools to serialize Parsing
Expressions as immutable values for transport, comparison, etc\.

We distinguish between *regular* and *canonical* serializations\. While a
parsing expression may have more than one regular serialization only exactly one
of them will be *canonical*\.

  - Regular serialization

      * __Atomic Parsing Expressions__

          1. The string __epsilon__ is an atomic parsing expression\. It
             matches the empty string\.

          1. The string __dot__ is an atomic parsing expression\. It matches
             any character\.

          1. The string __alnum__ is an atomic parsing expression\. It
             matches any Unicode alphabet or digit character\. This is a custom
             extension of PEs based on Tcl's builtin command __string is__\.

          1. The string __alpha__ is an atomic parsing expression\. It
             matches any Unicode alphabet character\. This is a custom extension
             of PEs based on Tcl's builtin command __string is__\.

          1. The string __ascii__ is an atomic parsing expression\. It
             matches any Unicode character below U0080\. This is a custom
             extension of PEs based on Tcl's builtin command __string is__\.

          1. The string __control__ is an atomic parsing expression\. It
             matches any Unicode control character\. This is a custom extension
             of PEs based on Tcl's builtin command __string is__\.

          1. The string __digit__ is an atomic parsing expression\. It
             matches any Unicode digit character\. Note that this includes
             characters outside of the \[0\.\.9\] range\. This is a custom extension
             of PEs based on Tcl's builtin command __string is__\.

          1. The string __graph__ is an atomic parsing expression\. It
             matches any Unicode printing character, except for space\. This is a
             custom extension of PEs based on Tcl's builtin command __string
             is__\.

          1. The string __lower__ is an atomic parsing expression\. It
             matches any Unicode lower\-case alphabet character\. This is a custom
             extension of PEs based on Tcl's builtin command __string is__\.

          1. The string __print__ is an atomic parsing expression\. It
             matches any Unicode printing character, including space\. This is a
             custom extension of PEs based on Tcl's builtin command __string
             is__\.

          1. The string __punct__ is an atomic parsing expression\. It
             matches any Unicode punctuation character\. This is a custom
             extension of PEs based on Tcl's builtin command __string is__\.

          1. The string __space__ is an atomic parsing expression\. It
             matches any Unicode space character\. This is a custom extension of
             PEs based on Tcl's builtin command __string is__\.

          1. The string __upper__ is an atomic parsing expression\. It
             matches any Unicode upper\-case alphabet character\. This is a custom
             extension of PEs based on Tcl's builtin command __string is__\.

          1. The string __wordchar__ is an atomic parsing expression\. It
             matches any Unicode word character\. This is any alphanumeric
             character \(see alnum\), and any connector punctuation characters
             \(e\.g\. underscore\)\. This is a custom extension of PEs based on Tcl's
             builtin command __string is__\.

          1. The string __xdigit__ is an atomic parsing expression\. It
             matches any hexadecimal digit character\. This is a custom extension
             of PEs based on Tcl's builtin command __string is__\.

          1. The string __ddigit__ is an atomic parsing expression\. It
             matches any decimal digit character\. This is a custom extension of
             PEs based on Tcl's builtin command __regexp__\.

          1. The expression \[list t __x__\] is an atomic parsing expression\.
             It matches the terminal string __x__\.

          1. The expression \[list n __A__\] is an atomic parsing expression\.
             It matches the nonterminal __A__\.

      * __Combined Parsing Expressions__

          1. For parsing expressions __e1__, __e2__, \.\.\. the result of
             \[list / __e1__ __e2__ \.\.\. \] is a parsing expression as
             well\. This is the *ordered choice*, aka *prioritized choice*\.

          1. For parsing expressions __e1__, __e2__, \.\.\. the result of
             \[list x __e1__ __e2__ \.\.\. \] is a parsing expression as
             well\. This is the *sequence*\.

          1. For a parsing expression __e__ the result of \[list \* __e__\]
             is a parsing expression as well\. This is the *kleene closure*,
             describing zero or more repetitions\.

          1. For a parsing expression __e__ the result of \[list \+ __e__\]
             is a parsing expression as well\. This is the *positive kleene
             closure*, describing one or more repetitions\.

          1. For a parsing expression __e__ the result of \[list & __e__\]
             is a parsing expression as well\. This is the *and lookahead
             predicate*\.

          1. For a parsing expression __e__ the result of \[list \! __e__\]
             is a parsing expression as well\. This is the *not lookahead
             predicate*\.

          1. For a parsing expression __e__ the result of \[list ? __e__\]
             is a parsing expression as well\. This is the *optional input*\.

  - Canonical serialization

    The canonical serialization of a parsing expression has the format as
    specified in the previous item, and then additionally satisfies the
    constraints below, which make it unique among all the possible
    serializations of this parsing expression\.

      1. The string representation of the value is the canonical representation
         of a pure Tcl list\. I\.e\. it does not contain superfluous whitespace\.

      1. Terminals are *not* encoded as ranges \(where start and end of the
         range are identical\)\.

## <a name='subsection4'></a>Example

Assuming the parsing expression shown on the right\-hand side of the rule

    Expression <- Term (AddOp Term)*

then its canonical serialization \(except for whitespace\) is

    {x {n Term} {* {x {n AddOp} {n Term}}}}

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
