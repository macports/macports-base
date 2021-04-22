
[//000000001]: # (pt::peg::container \- Parser Tools)
[//000000002]: # (Generated from file 'pt\_peg\_container\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pt::peg::container\(n\) 1 tcllib "Parser Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pt::peg::container \- PEG Storage

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

      - [Class API](#subsection1)

      - [Object API](#subsection2)

  - [PEG serialization format](#section2)

      - [Example](#subsection3)

  - [PE serialization format](#section3)

      - [Example](#subsection4)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require snit  
package require pt::peg::container ?1?  

[__::pt::peg__ *objectName* ?__=__&#124;__:=__&#124;__<\-\-__&#124;__as__&#124;__deserialize__ *src*?](#1)  
[*objectName* __destroy__](#2)  
[*objectName* __clear__](#3)  
[*objectName* __importer__](#4)  
[*objectName* __importer__ *object*](#5)  
[*objectName* __exporter__](#6)  
[*objectName* __exporter__ *object*](#7)  
[*objectName* __=__ *source*](#8)  
[*objectName* __\-\->__ *destination*](#9)  
[*objectName* __serialize__ ?*format*?](#10)  
[*objectName* __deserialize =__ *data* ?*format*?](#11)  
[*objectName* __deserialize \+=__ *data* ?*format*?](#12)  
[*objectName* __start__](#13)  
[*objectName* __start__ *pe*](#14)  
[*objectName* __nonterminals__](#15)  
[*objectName* __modes__](#16)  
[*objectName* __modes__ *dict*](#17)  
[*objectName* __rules__](#18)  
[*objectName* __rules__ *dict*](#19)  
[*objectName* __add__ ?*nt*\.\.\.?](#20)  
[*objectName* __remove__ ?*nt*\.\.\.?](#21)  
[*objectName* __exists__ *nt*](#22)  
[*objectName* __rename__ *ntold* *ntnew*](#23)  
[*objectName* __mode__ *nt*](#24)  
[*objectName* __mode__ *nt* *mode*](#25)  
[*objectName* __rule__ *nt*](#26)  
[*objectName* __rule__ *nt* *pe*](#27)  

# <a name='description'></a>DESCRIPTION

Are you lost ? Do you have trouble understanding this document ? In that case
please read the overview provided by the *[Introduction to Parser
Tools](pt\_introduction\.md)*\. This document is the entrypoint to the whole
system the current package is a part of\.

This package provides a container class for parsing expression grammars, with
each instance storing a single grammar and allowing the user to manipulate and
query its definition\.

It resides in the Storage section of the Core Layer of Parser Tools, and is one
of the three pillars the management of parsing expression grammars resides on\.

![](\.\./\.\./\.\./\.\./image/arch\_core\_container\.png) The other two pillars are,
as shown above

  1. *[PEG Import](pt\_peg\_import\.md)*, and

  1. *[PEG Export](pt\_peg\_export\.md)*

Packages related to this are:

  - __[pt::rde](pt\_rdengine\.md)__

    This package provides an implementation of PARAM, a virtual machine for the
    parsing of a channel, geared towards the needs of handling PEGs\.

  - __[pt::peg::interp](pt\_peg\_interp\.md)__

    This package implements an interpreter for PEGs on top of the virtual
    machine provided by __pt::peg::rde__

## <a name='subsection1'></a>Class API

The package exports the API described here\.

  - <a name='1'></a>__::pt::peg__ *objectName* ?__=__&#124;__:=__&#124;__<\-\-__&#124;__as__&#124;__deserialize__ *src*?

    The command creates a new container object for a parsing expression grammar
    and returns the fully qualified name of the object command as its result\.
    The API of this object command is described in the section [Object
    API](#subsection2)\. It may be used to invoke various operations on the
    object\.

    The new container will be empty if no *src* is specified\. Otherwise it
    will contain a copy of the grammar contained in the *src*\. All operators
    except __deserialize__ interpret *src* as a container object command\.
    The __deserialize__ operator interprets *src* as the serialization of
    a parsing expression grammar instead, as specified in section [PEG
    serialization format](#section2)\.

    An empty grammar has no nonterminal symbols, and the start expression is the
    empty expression, i\.e\. epsilon\. It is *valid*, but not *useful*\.

## <a name='subsection2'></a>Object API

All objects created by this package provide the following methods for the
manipulation and querying of their contents:

  - <a name='2'></a>*objectName* __destroy__

    This method destroys the object, releasing all claimed memory, and deleting
    the associated object command\.

  - <a name='3'></a>*objectName* __clear__

    This method resets the object to contain the empty grammar\. It does *not*
    destroy the object itself\.

  - <a name='4'></a>*objectName* __importer__

    This method returns the import manager object currently attached to the
    container, if any\.

  - <a name='5'></a>*objectName* __importer__ *object*

    This method attaches the *object* as import manager to the container, and
    returns it as the result of the command\. Note that the *object* is *not*
    put into ownership of the container\. I\.e\., destruction of the container will
    *not* destroy the *object*\.

    It is expected that *object* provides a method named __import text__
    which takes a text and a format name, and returns the canonical
    serialization of the table of contents contained in the text, assuming the
    given format\.

  - <a name='6'></a>*objectName* __exporter__

    This method returns the export manager object currently attached to the
    container, if any\.

  - <a name='7'></a>*objectName* __exporter__ *object*

    This method attaches the *object* as export manager to the container, and
    returns it as the result of the command\. Note that the *object* is *not*
    put into ownership of the container\. I\.e\., destruction of the container will
    *not* destroy the *object*\.

    It is expected that *object* provides a method named __export object__
    which takes the container and a format name, and returns a text encoding
    table of contents stored in the container, in the given format\. It is
    further expected that the *object* will use the container's method
    __serialize__ to obtain the serialization of the table of contents from
    which to generate the text\.

  - <a name='8'></a>*objectName* __=__ *source*

    This method assigns the contents of the PEG object *source* to ourselves,
    overwriting the existing definition\. This is the assignment operator for
    grammars\.

    This operation is in effect equivalent to

    > *objectName* __deserialize =__ \[*source* __serialize__\]

  - <a name='9'></a>*objectName* __\-\->__ *destination*

    This method assigns our contents to the PEG object *destination*,
    overwriting the existing definition\. This is the reverse assignment operator
    for grammars\.

    This operation is in effect equivalent to

    > *destination* __deserialize =__ \[*objectName* __serialize__\]

  - <a name='10'></a>*objectName* __serialize__ ?*format*?

    This method returns our grammar in some textual form usable for transfer,
    persistent storage, etc\. If no *format* is not specified the returned
    result is the canonical serialization of the grammar, as specified in the
    section [PEG serialization format](#section2)\.

    Otherwise the object will use the attached export manager to convert the
    data to the specified format\. In that case the method will fail with an
    error if the container has no export manager attached to it\.

  - <a name='11'></a>*objectName* __deserialize =__ *data* ?*format*?

    This is the complementary method to __serialize__\. It replaces the
    current definition with the grammar contained in the *data*\. If no
    *format* was specified it is assumed to be the regular serialization of a
    grammar, as specified in the section [PEG serialization
    format](#section2)

    Otherwise the object will use the attached import manager to convert the
    data from the specified format to a serialization it can handle\. In that
    case the method will fail with an error if the container has no import
    manager attached to it\.

    The result of the method is the empty string\.

  - <a name='12'></a>*objectName* __deserialize \+=__ *data* ?*format*?

    This method behaves like __deserialize =__ in its essentials, except
    that it merges the grammar in the *data* to its contents instead of
    replacing it\. The method will fail with an error and leave the grammar
    unchanged if merging is not possible, i\.e\. would produce an invalid grammar\.

    The result of the method is the empty string\.

  - <a name='13'></a>*objectName* __start__

    This method returns the current start expression of the grammar\.

  - <a name='14'></a>*objectName* __start__ *pe*

    This method defines the *start expression* of the grammar\. It replaces the
    current start expression with the parsing expression *pe*, and returns the
    new start expression\.

    The method will fail with an error and leave the grammar unchanged if *pe*
    does not contain a valid parsing expression as specified in the section [PE
    serialization format](#section3)\.

  - <a name='15'></a>*objectName* __nonterminals__

    This method returns the set of all nonterminal symbols known to the grammar\.

  - <a name='16'></a>*objectName* __modes__

    This method returns a dictionary mapping the set of all nonterminal symbols
    known to the grammar to their semantic modes\.

  - <a name='17'></a>*objectName* __modes__ *dict*

    This method takes a dictionary mapping a set of nonterminal symbols known to
    the grammar to their semantic modes, and returns the new full mapping of
    nonterminal symbols to semantic modes\.

    The method will fail with an error if any of the nonterminal symbols in the
    dictionary is not known to the grammar, or the empty string, i\.e\. an invalid
    nonterminal symbol, or if any the chosen *mode*s is not one of the legal
    values\.

  - <a name='18'></a>*objectName* __rules__

    This method returns a dictionary mapping the set of all nonterminal symbols
    known to the grammar to their parsing expressions \(right\-hand sides\)\.

  - <a name='19'></a>*objectName* __rules__ *dict*

    This method takes a dictionary mapping a set of nonterminal symbols known to
    the grammar to their parsing expressions \(right\-hand sides\), and returns the
    new full mapping of nonterminal symbols to parsing expressions\.

    The method will fail with an error any of the nonterminal symbols in the
    dictionary is not known to the grammar, or the empty string, i\.e\. an invalid
    nonterminal symbol, or any of the chosen parsing expressions is not a valid
    parsing expression as specified in the section [PE serialization
    format](#section3)\.

  - <a name='20'></a>*objectName* __add__ ?*nt*\.\.\.?

    This method adds the nonterminal symbols *nt*, etc\. to the grammar, and
    defines default semantic mode and expression for it \(__value__ and
    __epsilon__ respectively\)\. The method returns the empty string as its
    result\.

    The method will fail with an error and leaves the grammar unchanged if any
    of the nonterminal symbols are either already defined in our grammar, or are
    the empty string \(an invalid nonterminal symbol\)\.

    The method does nothing if no symbol was specified as argument\.

  - <a name='21'></a>*objectName* __remove__ ?*nt*\.\.\.?

    This method removes the named nonterminal symbols *nt*, etc\. from the set
    of nonterminal symbols known to our grammar\. The method returns the empty
    string as its result\.

    The method will fail with an error and leave the grammar unchanged if any of
    the nonterminal symbols is not known to the grammar, or is the empty string,
    i\.e\. an invalid nonterminal symbol\.

  - <a name='22'></a>*objectName* __exists__ *nt*

    This method tests whether the nonterminal symbol *nt* is known to our
    grammar or not\. The result is a boolean value\. It will be set to
    __true__ if *nt* is known, and __false__ otherwise\.

    The method will fail with an error if *nt* is the empty string, i\.e\. an
    invalid nonterminal symbol\.

  - <a name='23'></a>*objectName* __rename__ *ntold* *ntnew*

    This method renames the nonterminal symbol *ntold* to *ntnew*\. The
    method returns the empty string as its result\.

    The method will fail with an error and leave the grammar unchanged if either
    *ntold* is not known to the grammar, or *ntnew* is already known, or any
    of them is the empty string, i\.e\. an invalid nonterminal symbol\.

  - <a name='24'></a>*objectName* __mode__ *nt*

    This method returns the current semantic mode for the nonterminal symbol
    *nt*\.

    The method will fail with an error if *nt* is not known to the grammar, or
    the empty string, i\.e\. an invalid nonterminal symbol\.

  - <a name='25'></a>*objectName* __mode__ *nt* *mode*

    This mode sets the semantic mode for the nonterminal symbol *nt*, and
    returns the new mode\. The method will fail with an error if *nt* is not
    known to the grammar, or the empty string, i\.e\. an invalid nonterminal
    symbol, or the chosen *mode* is not one of the legal values\.

    The following modes are legal:

      * __value__

        The semantic value of the nonterminal symbol is an abstract syntax tree
        consisting of a single node node for the nonterminal itself, which has
        the ASTs of the symbol's right hand side as its children\.

      * __leaf__

        The semantic value of the nonterminal symbol is an abstract syntax tree
        consisting of a single node node for the nonterminal, without any
        children\. Any ASTs generated by the symbol's right hand side are
        discarded\.

      * __void__

        The nonterminal has no semantic value\. Any ASTs generated by the
        symbol's right hand side are discarded \(as well\)\.

  - <a name='26'></a>*objectName* __rule__ *nt*

    This method returns the current parsing expression \(right\-hand side\) for the
    nonterminal symbol *nt*\.

    The method will fail with an error if *nt* is not known to the grammar, or
    the empty string, i\.e\. an invalid nonterminal symbol\.

  - <a name='27'></a>*objectName* __rule__ *nt* *pe*

    This method set the parsing expression \(right\-hand side\) of the nonterminal
    *nt* to *pe*, and returns the new parsing expression\.

    The method will fail with an error if *nt* is not known to the grammar, or
    the empty string, i\.e\. an invalid nonterminal symbol, or *pe* does not
    contain a valid parsing expression as specified in the section [PE
    serialization format](#section3)\.

# <a name='section2'></a>PEG serialization format

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
                      in the section [PE serialization format](#section3)\.

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
             format](#section3)\.

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

## <a name='subsection3'></a>Example

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
