
[//000000001]: # (pt::peg::to::container \- Parser Tools)
[//000000002]: # (Generated from file 'to\.inc' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pt::peg::to::container\(n\) 1 tcllib "Parser Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pt::peg::to::container \- PEG Conversion\. Write CONTAINER format

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Options](#section3)

  - [Grammar Container](#section4)

      - [Example](#subsection1)

  - [PEG serialization format](#section5)

      - [Example](#subsection2)

  - [PE serialization format](#section6)

      - [Example](#subsection3)

  - [Bugs, Ideas, Feedback](#section7)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require pt::peg::to::container ?1?  
package require pt::peg  
package require text::write  
package require char  

[__pt::peg::to::container__ __reset__](#1)  
[__pt::peg::to::container__ __configure__](#2)  
[__pt::peg::to::container__ __configure__ *option*](#3)  
[__pt::peg::to::container__ __configure__ *option* *value*\.\.\.](#4)  
[__pt::peg::to::container__ __convert__ *serial*](#5)  

# <a name='description'></a>DESCRIPTION

Are you lost ? Do you have trouble understanding this document ? In that case
please read the overview provided by the *[Introduction to Parser
Tools](pt\_introduction\.md)*\. This document is the entrypoint to the whole
system the current package is a part of\.

This package implements the converter from parsing expression grammars to
CONTAINER markup\.

It resides in the Export section of the Core Layer of Parser Tools, and can be
used either directly with the other packages of this layer, or indirectly
through the export manager provided by
__[pt::peg::export](pt\_peg\_export\.md)__\. The latter is intented for use
in untrusted environments and done through the corresponding export plugin
__[pt::peg::export::container](pt\_peg\_export\_container\.md)__ sitting
between converter and export manager\.

![](\.\./\.\./\.\./\.\./image/arch\_core\_eplugins\.png)

# <a name='section2'></a>API

The API provided by this package satisfies the specification of the Converter
API found in the *[Parser Tools Export API](pt\_to\_api\.md)* specification\.

  - <a name='1'></a>__pt::peg::to::container__ __reset__

    This command resets the configuration of the package to its default
    settings\.

  - <a name='2'></a>__pt::peg::to::container__ __configure__

    This command returns a dictionary containing the current configuration of
    the package\.

  - <a name='3'></a>__pt::peg::to::container__ __configure__ *option*

    This command returns the current value of the specified configuration
    *option* of the package\. For the set of legal options, please read the
    section [Options](#section3)\.

  - <a name='4'></a>__pt::peg::to::container__ __configure__ *option* *value*\.\.\.

    This command sets the given configuration *option*s of the package, to the
    specified *value*s\. For the set of legal options, please read the section
    [Options](#section3)\.

  - <a name='5'></a>__pt::peg::to::container__ __convert__ *serial*

    This command takes the canonical serialization of a parsing expression
    grammar, as specified in section [PEG serialization format](#section5),
    and contained in *serial*, and generates CONTAINER markup encoding the
    grammar, per the current package configuration\. The created string is then
    returned as the result of the command\.

# <a name='section3'></a>Options

The converter to the CONTAINER format recognizes the following options and
changes its behaviour as they specify\.

  - __\-file__ string

    The value of this option is the name of the file or other entity from which
    the grammar came, for which the command is run\. The default value is
    __unknown__\.

  - __\-name__ string

    The value of this option is the name of the grammar we are processing\. The
    default value is __a\_pe\_grammar__\.

  - __\-user__ string

    The value of this option is the name of the user for which the command is
    run\. The default value is __unknown__\.

  - __\-mode__ __bulk__&#124;__incremental__

    The value of this option controls which methods of
    __[pt::peg::container](pt\_peg\_container\.md)__ instances are used to
    specify the grammar, i\.e\. preload it into the container\. There are two legal
    values, as listed below\. The default is __bulk__\.

      * __bulk__

        In this mode the methods __start__, __add__, __modes__, and
        __rules__ are used to specify the grammar in a bulk manner, i\.e\. as
        a set of nonterminal symbols, and two dictionaries mapping from the
        symbols to their semantic modes and parsing expressions\.

        This mode is the default\.

      * __incremental__

        In this mode the methods __start__, __add__, __mode__, and
        __rule__ are used to specify the grammar piecemal, with each
        nonterminal having its own block of defining commands\.

  - __\-template__ string

    The value of this option is a string into which to put the generated code
    and the other configuration settings\. The various locations for user\-data
    are expected to be specified with the placeholders listed below\. The default
    value is "__@code@__"\.

      * __@user@__

        To be replaced with the value of the option __\-user__\.

      * __@format@__

        To be replaced with the the constant __CONTAINER__\.

      * __@file@__

        To be replaced with the value of the option __\-file__\.

      * __@name@__

        To be replaced with the value of the option __\-name__\.

      * __@mode@__

        To be replaced with the value of the option __\-mode__\.

      * __@code@__

        To be replaced with the generated code\.

# <a name='section4'></a>Grammar Container

The __container__ format is another form of describing parsing expression
grammars\. While data in this format is executable it does not constitute a
parser for the grammar\. It always has to be used in conjunction with the package
__[pt::peg::interp](pt\_peg\_interp\.md)__, a grammar interpreter\.

The format represents grammars by a __snit::type__, i\.e\. class, whose
instances are API\-compatible to the instances of the
__[pt::peg::container](pt\_peg\_container\.md)__ package, and which are
preloaded with the grammar in question\.

It has no direct formal specification beyond what was said above\.

## <a name='subsection1'></a>Example

Assuming the following PEG for simple mathematical expressions

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

one possible CONTAINER serialization for it is

    snit::type a_pe_grammar {
        constructor {} {
            install myg using pt::peg::container ${selfns}::G
            $myg start {n Expression}
            $myg add   AddOp Digit Expression Factor MulOp Number Sign Term
            $myg modes {
                AddOp      value
                Digit      value
                Expression value
                Factor     value
                MulOp      value
                Number     value
                Sign       value
                Term       value
            }
            $myg rules {
                AddOp      {/ {t -} {t +}}
                Digit      {/ {t 0} {t 1} {t 2} {t 3} {t 4} {t 5} {t 6} {t 7} {t 8} {t 9}}
                Expression {/ {x {t \50} {n Expression} {t \51}} {x {n Factor} {* {x {n MulOp} {n Factor}}}}}
                Factor     {x {n Term} {* {x {n AddOp} {n Term}}}}
                MulOp      {/ {t *} {t /}}
                Number     {x {? {n Sign}} {+ {n Digit}}}
                Sign       {/ {t -} {t +}}
                Term       {n Number}
            }
            return
        }

        component myg
        delegate method * to myg
    }

# <a name='section5'></a>PEG serialization format

Here we specify the format used by the Parser Tools to serialize Parsing
Expression Grammars as immutable values for transport, comparison, etc\.

We distinguish between *regular* and *canonical* serializations\. While a PEG
may have more than one regular serialization only exactly one of them will be
*canonical*\.

  - regular serialization

      1. The serialization of any PEG is a nested Tcl dictionary\.

      1. This dictionary holds a single key, __pt::grammar::peg__, and its
         value\. This value holds the contents of the grammar\.

      1. The contents of the grammar are a Tcl dictionary holding the set of
         nonterminal symbols and the starting expression\. The relevant keys and
         their values are

           * __rules__

             The value is a Tcl dictionary whose keys are the names of the
             nonterminal symbols known to the grammar\.

               1) Each nonterminal symbol may occur only once\.

               1) The empty string is not a legal nonterminal symbol\.

               1) The value for each symbol is a Tcl dictionary itself\. The
                  relevant keys and their values in this dictionary are

                    + __is__

                      The value is the serialization of the parsing expression
                      describing the symbols sentennial structure, as specified
                      in the section [PE serialization format](#section6)\.

                    + __mode__

                      The value can be one of three values specifying how a
                      parser should handle the semantic value produced by the
                      symbol\.

                        - __value__

                          The semantic value of the nonterminal symbol is an
                          abstract syntax tree consisting of a single node node
                          for the nonterminal itself, which has the ASTs of the
                          symbol's right hand side as its children\.

                        - __leaf__

                          The semantic value of the nonterminal symbol is an
                          abstract syntax tree consisting of a single node node
                          for the nonterminal, without any children\. Any ASTs
                          generated by the symbol's right hand side are
                          discarded\.

                        - __void__

                          The nonterminal has no semantic value\. Any ASTs
                          generated by the symbol's right hand side are
                          discarded \(as well\)\.

           * __start__

             The value is the serialization of the start parsing expression of
             the grammar, as specified in the section [PE serialization
             format](#section6)\.

      1. The terminal symbols of the grammar are specified implicitly as the set
         of all terminal symbols used in the start expression and on the RHS of
         the grammar rules\.

  - canonical serialization

    The canonical serialization of a grammar has the format as specified in the
    previous item, and then additionally satisfies the constraints below, which
    make it unique among all the possible serializations of this grammar\.

      1. The keys found in all the nested Tcl dictionaries are sorted in
         ascending dictionary order, as generated by Tcl's builtin command
         __lsort \-increasing \-dict__\.

      1. The string representation of the value is the canonical representation
         of a Tcl dictionary\. I\.e\. it does not contain superfluous whitespace\.

## <a name='subsection2'></a>Example

Assuming the following PEG for simple mathematical expressions

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

then its canonical serialization \(except for whitespace\) is

    pt::grammar::peg {
        rules {
            AddOp      {is {/ {t -} {t +}}                                                                mode value}
            Digit      {is {/ {t 0} {t 1} {t 2} {t 3} {t 4} {t 5} {t 6} {t 7} {t 8} {t 9}}                mode value}
            Expression {is {x {n Term} {* {x {n AddOp} {n Term}}}}                                        mode value}
            Factor     {is {/ {x {t (} {n Expression} {t )}} {n Number}}                                  mode value}
            MulOp      {is {/ {t *} {t /}}                                                                mode value}
            Number     {is {x {? {n Sign}} {+ {n Digit}}}                                                 mode value}
            Sign       {is {/ {t -} {t +}}                                                                mode value}
            Term       {is {x {n Factor} {* {x {n MulOp} {n Factor}}}}                                    mode value}
        }
        start {n Expression}
    }

# <a name='section6'></a>PE serialization format

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

## <a name='subsection3'></a>Example

Assuming the parsing expression shown on the right\-hand side of the rule

    Expression <- Term (AddOp Term)*

then its canonical serialization \(except for whitespace\) is

    {x {n Term} {* {x {n AddOp} {n Term}}}}

# <a name='section7'></a>Bugs, Ideas, Feedback

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

[CONTAINER](\.\./\.\./\.\./\.\./index\.md\#container),
[EBNF](\.\./\.\./\.\./\.\./index\.md\#ebnf), [LL\(k\)](\.\./\.\./\.\./\.\./index\.md\#ll\_k\_),
[PEG](\.\./\.\./\.\./\.\./index\.md\#peg), [TDPL](\.\./\.\./\.\./\.\./index\.md\#tdpl),
[context\-free languages](\.\./\.\./\.\./\.\./index\.md\#context\_free\_languages),
[conversion](\.\./\.\./\.\./\.\./index\.md\#conversion),
[expression](\.\./\.\./\.\./\.\./index\.md\#expression), [format
conversion](\.\./\.\./\.\./\.\./index\.md\#format\_conversion),
[grammar](\.\./\.\./\.\./\.\./index\.md\#grammar),
[matching](\.\./\.\./\.\./\.\./index\.md\#matching),
[parser](\.\./\.\./\.\./\.\./index\.md\#parser), [parsing
expression](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression), [parsing expression
grammar](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression\_grammar), [push down
automaton](\.\./\.\./\.\./\.\./index\.md\#push\_down\_automaton), [recursive
descent](\.\./\.\./\.\./\.\./index\.md\#recursive\_descent),
[serialization](\.\./\.\./\.\./\.\./index\.md\#serialization),
[state](\.\./\.\./\.\./\.\./index\.md\#state), [top\-down parsing
languages](\.\./\.\./\.\./\.\./index\.md\#top\_down\_parsing\_languages),
[transducer](\.\./\.\./\.\./\.\./index\.md\#transducer)

# <a name='category'></a>CATEGORY

Parsing and Grammars

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
