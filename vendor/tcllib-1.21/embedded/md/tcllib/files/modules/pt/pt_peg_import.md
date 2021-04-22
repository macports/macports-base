
[//000000001]: # (pt::peg::import \- Parser Tools)
[//000000002]: # (Generated from file 'pt\_peg\_import\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pt::peg::import\(n\) 1\.0\.1 tcllib "Parser Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pt::peg::import \- PEG Import

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

      - [Package commands](#subsection1)

      - [Object command](#subsection2)

      - [Object methods](#subsection3)

  - [PEG serialization format](#section3)

      - [Example](#subsection4)

  - [PE serialization format](#section4)

      - [Example](#subsection5)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require Tcl 8\.5  
package require snit  
package require fileutil::paths  
package require pt::peg  
package require pluginmgr  
package require pt::peg::import ?1\.0\.1?  

[__::pt::peg::import__ *objectName*](#1)  
[__objectName__ __method__ ?*arg arg \.\.\.*?](#2)  
[*objectName* __destroy__](#3)  
[*objectName* __import text__ *text* ?*format*?](#4)  
[*objectName* __import file__ *path* ?*format*?](#5)  
[*objectName* __import object text__ *object* *text* ?*format*?](#6)  
[*objectName* __import object file__ *object* *path* ?*format*?](#7)  
[*objectName* __includes__](#8)  
[*objectName* __include add__ *path*](#9)  
[*objectName* __include remove__ *path*](#10)  
[*objectName* __include clear__](#11)  

# <a name='description'></a>DESCRIPTION

Are you lost ? Do you have trouble understanding this document ? In that case
please read the overview provided by the *[Introduction to Parser
Tools](pt\_introduction\.md)*\. This document is the entrypoint to the whole
system the current package is a part of\.

This package provides a manager for parsing expression grammars, with each
instance handling a set of plugins for the import of them from other formats,
i\.e\. their conversion from, for example *peg*, *container*,
*[json](\.\./\.\./\.\./\.\./index\.md\#json)*, etc\.

It resides in the Import section of the Core Layer of Parser Tools, and is one
of the three pillars the management of parsing expression grammars resides on\.

![](\.\./\.\./\.\./\.\./image/arch\_core\_import\.png) The other two pillars are, as
shown above

  1. *[PEG Export](pt\_peg\_export\.md)*, and

  1. *[PEG Storage](pt\_peg\_container\.md)*

For information about the data structure which is the major output of the
manager objects provided by this package see the section [PEG serialization
format](#section3)\.

The plugin system of our class is based on the package
__[pluginmgr](\.\./pluginmgr/pluginmgr\.md)__, and configured to look for
plugins using

  1. the environment variable __GRAMMAR\_PEG\_IMPORT\_PLUGINS__,

  1. the environment variable __GRAMMAR\_PEG\_PLUGINS__,

  1. the environment variable __GRAMMAR\_PLUGINS__,

  1. the path "~/\.grammar/peg/import/plugin"

  1. the path "~/\.grammar/peg/plugin"

  1. the path "~/\.grammar/plugin"

  1. the path "~/\.grammar/peg/import/plugins"

  1. the path "~/\.grammar/peg/plugins"

  1. the path "~/\.grammar/plugins"

  1. the registry entry "HKEY\_CURRENT\_USER\\SOFTWARE\\GRAMMAR\\PEG\\IMPORT\\PLUGINS"

  1. the registry entry "HKEY\_CURRENT\_USER\\SOFTWARE\\GRAMMAR\\PEG\\PLUGINS"

  1. the registry entry "HKEY\_CURRENT\_USER\\SOFTWARE\\GRAMMAR\\PLUGINS"

The last three are used only when the package is run on a machine using the
Windows\(tm\) operating system\.

The whole system is delivered with three predefined import plugins, namely

  - container

    See *[PEG Import Plugin\. From CONTAINER
    format](pt\_peg\_import\_container\.md)* for details\.

  - json

    See *PEG Import Plugin\. From JSON format* for details\.

  - peg

    See *PEG Import Plugin\. From PEG format* for details\.

For readers wishing to write their own import plugin for some format, i\.e\.
*plugin writer*s, reading and understanding the *Parser Tools Impport API*
specification is an absolute necessity, as it documents the interaction between
this package and its plugins in detail\.

# <a name='section2'></a>API

## <a name='subsection1'></a>Package commands

  - <a name='1'></a>__::pt::peg::import__ *objectName*

    This command creates a new import manager object with an associated Tcl
    command whose name is *objectName*\. This
    *[object](\.\./\.\./\.\./\.\./index\.md\#object)* command is explained in full
    detail in the sections [Object command](#subsection2) and [Object
    methods](#subsection3)\. The object command will be created under the
    current namespace if the *objectName* is not fully qualified, and in the
    specified namespace otherwise\.

## <a name='subsection2'></a>Object command

All objects created by the __::pt::peg::import__ command have the following
general form:

  - <a name='2'></a>__objectName__ __method__ ?*arg arg \.\.\.*?

    The method __method__ and its *arg*'uments determine the exact
    behavior of the command\. See section [Object methods](#subsection3) for
    the detailed specifications\.

## <a name='subsection3'></a>Object methods

  - <a name='3'></a>*objectName* __destroy__

    This method destroys the object it is invoked for\.

  - <a name='4'></a>*objectName* __import text__ *text* ?*format*?

    This method takes the *text* and converts it from the specified *format*
    to the canonical serialization of a parsing expression grammar using the
    import plugin for the format\. An error is thrown if no plugin could be found
    for the format\. The serialization generated by the conversion process is
    returned as the result of this method\.

    If no format is specified the method defaults to __text__\.

    The specification of what a *canonical* serialization is can be found in
    the section [PEG serialization format](#section3)\.

    The plugin has to conform to the interface documented in the *[Parser
    Tools Import API](pt\_from\_api\.md)* specification\.

  - <a name='5'></a>*objectName* __import file__ *path* ?*format*?

    This method is a convenient wrapper around the __import text__ method
    described by the previous item\. It reads the contents of the specified file
    into memory, feeds the result into __import text__ and returns the
    resulting serialization as its own result\.

  - <a name='6'></a>*objectName* __import object text__ *object* *text* ?*format*?

    This method is a convenient wrapper around the __import text__ method
    described by the previous item\. It expects that *object* is an object
    command supporting a __deserialize__ method expecting the canonical
    serialization of a parsing expression grammar\. It imports the text using
    __import text__ and then feeds the resulting serialization into the
    *object* via __deserialize__\. This method returns the empty string as
    it result\.

  - <a name='7'></a>*objectName* __import object file__ *object* *path* ?*format*?

    This method behaves like __import object text__, except that it reads
    the text to convert from the specified file instead of being given it as
    argument\.

  - <a name='8'></a>*objectName* __includes__

    This method returns a list containing the currently specified paths to use
    to search for include files when processing input\. The order of paths in the
    list corresponds to the order in which they are used, from first to last,
    and also corresponds to the order in which they were added to the object\.

  - <a name='9'></a>*objectName* __include add__ *path*

    This methods adds the specified *path* to the list of paths to use to
    search for include files when processing input\. The path is added to the end
    of the list, causing it to be searched after all previously added paths\. The
    result of the command is the empty string\.

    The method does nothing if the path is already known\.

  - <a name='10'></a>*objectName* __include remove__ *path*

    This methods removes the specified *path* from the list of paths to use to
    search for include files when processing input\. The result of the command is
    the empty string\.

    The method does nothing if the path is not known\.

  - <a name='11'></a>*objectName* __include clear__

    This method clears the list of paths to use to search for include files when
    processing input\. The result of the command is the empty string\.

# <a name='section3'></a>PEG serialization format

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
                      in the section [PE serialization format](#section4)\.

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
             format](#section4)\.

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

## <a name='subsection4'></a>Example

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

# <a name='section4'></a>PE serialization format

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

## <a name='subsection5'></a>Example

Assuming the parsing expression shown on the right\-hand side of the rule

    Expression <- Term (AddOp Term)*

then its canonical serialization \(except for whitespace\) is

    {x {n Term} {* {x {n AddOp} {n Term}}}}

# <a name='section5'></a>Bugs, Ideas, Feedback

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
