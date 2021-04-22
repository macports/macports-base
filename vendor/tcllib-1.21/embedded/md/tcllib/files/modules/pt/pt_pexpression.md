
[//000000001]: # (pt::pe \- Parser Tools)
[//000000002]: # (Generated from file 'pt\_pexpression\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pt::pe\(n\) 1\.0\.1 tcllib "Parser Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pt::pe \- Parsing Expression Serialization

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [PE serialization format](#section3)

      - [Example](#subsection1)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require pt::pe ?1\.0\.1?  
package require char  

[__::pt::pe__ __verify__ *serial* ?*canonvar*?](#1)  
[__::pt::pe__ __verify\-as\-canonical__ *serial*](#2)  
[__::pt::pe__ __canonicalize__ *serial*](#3)  
[__::pt::pe__ __print__ *serial*](#4)  
[__::pt::pe__ __bottomup__ *cmdprefix* *pe*](#5)  
[__cmdprefix__ *pe* *op* *arguments*](#6)  
[__::pt::pe__ __topdown__ *cmdprefix* *pe*](#7)  
[__::pt::pe__ __equal__ *seriala* *serialb*](#8)  
[__::pt::pe__ __epsilon__](#9)  
[__::pt::pe__ __dot__](#10)  
[__::pt::pe__ __alnum__](#11)  
[__::pt::pe__ __alpha__](#12)  
[__::pt::pe__ __ascii__](#13)  
[__::pt::pe__ __control__](#14)  
[__::pt::pe__ __digit__](#15)  
[__::pt::pe__ __graph__](#16)  
[__::pt::pe__ __lower__](#17)  
[__::pt::pe__ __print__](#18)  
[__::pt::pe__ __punct__](#19)  
[__::pt::pe__ __space__](#20)  
[__::pt::pe__ __upper__](#21)  
[__::pt::pe__ __wordchar__](#22)  
[__::pt::pe__ __xdigit__](#23)  
[__::pt::pe__ __ddigit__](#24)  
[__::pt::pe__ __terminal__ *t*](#25)  
[__::pt::pe__ __range__ *ta* *tb*](#26)  
[__::pt::pe__ __nonterminal__ *nt*](#27)  
[__::pt::pe__ __choice__ *pe*\.\.\.](#28)  
[__::pt::pe__ __sequence__ *pe*\.\.\.](#29)  
[__::pt::pe__ __repeat0__ *pe*](#30)  
[__::pt::pe__ __repeat1__ *pe*](#31)  
[__::pt::pe__ __optional__ *pe*](#32)  
[__::pt::pe__ __ahead__ *pe*](#33)  
[__::pt::pe__ __notahead__ *pe*](#34)  

# <a name='description'></a>DESCRIPTION

Are you lost ? Do you have trouble understanding this document ? In that case
please read the overview provided by the *[Introduction to Parser
Tools](pt\_introduction\.md)*\. This document is the entrypoint to the whole
system the current package is a part of\.

This package provides commands to work with the serializations of parsing
expressions as managed by the Parser Tools, and specified in section [PE
serialization format](#section3)\.

This is a supporting package in the Core Layer of Parser Tools\.

![](\.\./\.\./\.\./\.\./image/arch\_core\_support\.png)

# <a name='section2'></a>API

  - <a name='1'></a>__::pt::pe__ __verify__ *serial* ?*canonvar*?

    This command verifies that the content of *serial* is a valid
    serialization of a parsing expression and will throw an error if that is not
    the case\. The result of the command is the empty string\.

    If the argument *canonvar* is specified it is interpreted as the name of a
    variable in the calling context\. This variable will be written to if and
    only if *serial* is a valid regular serialization\. Its value will be a
    boolean, with __True__ indicating that the serialization is not only
    valid, but also *canonical*\. __False__ will be written for a valid,
    but non\-canonical serialization\.

    For the specification of serializations see the section [PE serialization
    format](#section3)\.

  - <a name='2'></a>__::pt::pe__ __verify\-as\-canonical__ *serial*

    This command verifies that the content of *serial* is a valid
    *canonical* serialization of a parsing expression and will throw an error
    if that is not the case\. The result of the command is the empty string\.

    For the specification of canonical serializations see the section [PE
    serialization format](#section3)\.

  - <a name='3'></a>__::pt::pe__ __canonicalize__ *serial*

    This command assumes that the content of *serial* is a valid *regular*
    serialization of a parsing expression and will throw an error if that is not
    the case\.

    It will then convert the input into the *canonical* serialization of this
    parsing expression and return it as its result\. If the input is already
    canonical it will be returned unchanged\.

    For the specification of regular and canonical serializations see the
    section [PE serialization format](#section3)\.

  - <a name='4'></a>__::pt::pe__ __print__ *serial*

    This command assumes that the argument *serial* contains a valid
    serialization of a parsing expression and returns a string containing that
    PE in a human readable form\.

    The exact format of this form is not specified and cannot be relied on for
    parsing or other machine\-based activities\.

    For the specification of serializations see the section [PE serialization
    format](#section3)\.

  - <a name='5'></a>__::pt::pe__ __bottomup__ *cmdprefix* *pe*

    This command walks the parsing expression *pe* from the bottom up to the
    root, invoking the command prefix *cmdprefix* for each partial expression\.
    This implies that the children of a parsing expression PE are handled before
    PE\.

    The command prefix has the signature

      * <a name='6'></a>__cmdprefix__ *pe* *op* *arguments*

        I\.e\. it is invoked with the parsing expression *pe* the walk is
        currently at, the *op*'erator in the *pe*, and the operator's
        *arguments*\.

        The result returned by the command prefix replaces *pe* in the parsing
        expression it was a child of, allowing transformations of the expression
        tree\.

        This also means that for all inner parsing expressions the contents of
        *arguments* are the results of the command prefix invoked for the
        children of this inner parsing expression\.

  - <a name='7'></a>__::pt::pe__ __topdown__ *cmdprefix* *pe*

    This command walks the parsing expression *pe* from the root down to the
    leaves, invoking the command prefix *cmdprefix* for each partial
    expression\. This implies that the children of a parsing expression PE are
    handled after PE\.

    The command prefix has the same signature as for __bottomup__, see
    above\.

    The result returned by the command prefix is *ignored*\.

  - <a name='8'></a>__::pt::pe__ __equal__ *seriala* *serialb*

    This command tests the two parsing expressions *seriala* and *serialb*
    for structural equality\. The result of the command is a boolean value\. It
    will be set to __true__ if the expressions are identical, and
    __false__ otherwise\.

    String equality is usable only if we can assume that the two parsing
    expressions are pure Tcl lists\.

  - <a name='9'></a>__::pt::pe__ __epsilon__

    This command constructs the atomic parsing expression for epsilon\.

  - <a name='10'></a>__::pt::pe__ __dot__

    This command constructs the atomic parsing expression for dot\.

  - <a name='11'></a>__::pt::pe__ __alnum__

    This command constructs the atomic parsing expression for alnum\.

  - <a name='12'></a>__::pt::pe__ __alpha__

    This command constructs the atomic parsing expression for alpha\.

  - <a name='13'></a>__::pt::pe__ __ascii__

    This command constructs the atomic parsing expression for ascii\.

  - <a name='14'></a>__::pt::pe__ __control__

    This command constructs the atomic parsing expression for control\.

  - <a name='15'></a>__::pt::pe__ __digit__

    This command constructs the atomic parsing expression for digit\.

  - <a name='16'></a>__::pt::pe__ __graph__

    This command constructs the atomic parsing expression for graph\.

  - <a name='17'></a>__::pt::pe__ __lower__

    This command constructs the atomic parsing expression for lower\.

  - <a name='18'></a>__::pt::pe__ __print__

    This command constructs the atomic parsing expression for print\.

  - <a name='19'></a>__::pt::pe__ __punct__

    This command constructs the atomic parsing expression for punct\.

  - <a name='20'></a>__::pt::pe__ __space__

    This command constructs the atomic parsing expression for space\.

  - <a name='21'></a>__::pt::pe__ __upper__

    This command constructs the atomic parsing expression for upper\.

  - <a name='22'></a>__::pt::pe__ __wordchar__

    This command constructs the atomic parsing expression for wordchar\.

  - <a name='23'></a>__::pt::pe__ __xdigit__

    This command constructs the atomic parsing expression for xdigit\.

  - <a name='24'></a>__::pt::pe__ __ddigit__

    This command constructs the atomic parsing expression for ddigit\.

  - <a name='25'></a>__::pt::pe__ __terminal__ *t*

    This command constructs the atomic parsing expression for the terminal
    symbol *t*\.

  - <a name='26'></a>__::pt::pe__ __range__ *ta* *tb*

    This command constructs the atomic parsing expression for the range of
    terminal symbols *ta* \.\.\. *tb*\.

  - <a name='27'></a>__::pt::pe__ __nonterminal__ *nt*

    This command constructs the atomic parsing expression for the nonterminal
    symbol *nt*\.

  - <a name='28'></a>__::pt::pe__ __choice__ *pe*\.\.\.

    This command constructs the parsing expression representing the ordered or
    prioritized choice between the argument parsing expressions\. The first
    argument has the highest priority\.

  - <a name='29'></a>__::pt::pe__ __sequence__ *pe*\.\.\.

    This command constructs the parsing expression representing the sequence of
    the argument parsing expression\. The first argument is the first element of
    the sequence\.

  - <a name='30'></a>__::pt::pe__ __repeat0__ *pe*

    This command constructs the parsing expression representing the zero or more
    repetition of the argument parsing expression *pe*, also known as the
    kleene closure\.

  - <a name='31'></a>__::pt::pe__ __repeat1__ *pe*

    This command constructs the parsing expression representing the one or more
    repetition of the argument parsing expression *pe*, also known as the
    positive kleene closure\.

  - <a name='32'></a>__::pt::pe__ __optional__ *pe*

    This command constructs the parsing expression representing the optionality
    of the argument parsing expression *pe*\.

  - <a name='33'></a>__::pt::pe__ __ahead__ *pe*

    This command constructs the parsing expression representing the positive
    lookahead of the argument parsing expression *pe*\.

  - <a name='34'></a>__::pt::pe__ __notahead__ *pe*

    This command constructs the parsing expression representing the negative
    lookahead of the argument parsing expression *pe*\.

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

## <a name='subsection1'></a>Example

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
