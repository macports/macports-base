
[//000000001]: # (pt\_export\_api \- Parser Tools)
[//000000002]: # (Generated from file 'pt\_to\_api\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pt\_export\_api\(i\) 1 tcllib "Parser Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pt\_export\_api \- Parser Tools Export API

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Converter API](#section2)

  - [Plugin API](#section3)

  - [Options](#section4)

  - [Usage](#section5)

  - [PEG serialization format](#section6)

      - [Example](#subsection1)

  - [PE serialization format](#section7)

      - [Example](#subsection2)

  - [Bugs, Ideas, Feedback](#section8)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  

[__CONVERTER__ __reset__](#1)  
[__CONVERTER__ __configure__](#2)  
[__CONVERTER__ __configure__ *option*](#3)  
[__CONVERTER__ __configure__ *option* *value*\.\.\.](#4)  
[__CONVERTER__ __convert__ *serial*](#5)  
[__::export__ *serial* *configuration*](#6)  

# <a name='description'></a>DESCRIPTION

Are you lost ? Do you have trouble understanding this document ? In that case
please read the overview provided by the *[Introduction to Parser
Tools](pt\_introduction\.md)*\. This document is the entrypoint to the whole
system the current package is a part of\.

This document describes two APIs\. First the API shared by all packages for the
conversion of Parsing Expression Grammars into some other format, and then the
API shared by the packages which implement the export plugins sitting on top of
the conversion packages\.

Its intended audience are people who wish to create their own converter for some
type of output, and/or an export plugin for their or some other converter\.

It resides in the Export section of the Core Layer of Parser Tools\.

![](\.\./\.\./\.\./\.\./image/arch\_core\_export\.png)

# <a name='section2'></a>Converter API

Any \(grammar\) export converter has to follow the rules set out below:

  1. A converter is a package\. Its name is arbitrary, however it is recommended
     to put it under the __::pt::peg::to__ namespace\.

  1. The package provides either a single Tcl command following the API outlined
     below, or a class command whose instances follow the same API\. The commands
     which follow the API are called *converter commands*\.

  1. A converter command has to provide the following three methods with the
     given signatures and semantics\. Converter commands are allowed to provide
     more methods of their own, but not less, and they may not provide different
     semantics for the standardized methods\.

       - <a name='1'></a>__CONVERTER__ __reset__

         This method has to reset the configuration of the converter to its
         default settings\. The result of the method has to be the empty string\.

       - <a name='2'></a>__CONVERTER__ __configure__

         This method, in this form, has to return a dictionary containing the
         current configuration of the converter\.

       - <a name='3'></a>__CONVERTER__ __configure__ *option*

         This method, in this form, has to return the current value of the
         specified configuration *option* of the converter\.

         Please read the section [Options](#section4) for the set of
         standard options any converter has to accept\. Any other options
         accepted by a specific converter will be described in its manpage\.

       - <a name='4'></a>__CONVERTER__ __configure__ *option* *value*\.\.\.

         This command, in this form, sets the specified *option*s of the
         converter to the given *value*s\.

         Please read the section [Options](#section4) for the set of
         standard options a converter has to accept\. Any other options accepted
         by a specific converter will be described in its manpage\.

       - <a name='5'></a>__CONVERTER__ __convert__ *serial*

         This method has to accept the canonical serialization of a parsing
         expression grammar, as specified in section [PEG serialization
         format](#section6), and contained in *serial*\. The result of the
         method has to be the result of converting the input grammar into
         whatever the converter is for, per its configuration\.

# <a name='section3'></a>Plugin API

Any \(grammar\) export plugin has to follow the rules set out below:

  1. A plugin is a package\.

  1. The name of a plugin package has the form pt::peg::export::__FOO__,
     where __FOO__ is the name of the format the plugin will generate output
     for\.

  1. The plugin can expect that the package __pt::peg::export::plugin__ is
     present, as indicator that it was invoked from a genuine plugin manager\.

     It is recommended that a plugin does check for the presence of this
     package\.

  1. A plugin has to provide a single command, in the global namespace, with the
     signature shown below\. Plugins are allowed to provide more command of their
     own, but not less, and they may not provide different semantics for the
     standardized command\.

       - <a name='6'></a>__::export__ *serial* *configuration*

         This command has to accept the canonical serialization of a parsing
         expression grammar and the configuration for the converter invoked by
         the plugin\. The result of the command has to be the result of the
         converter invoked by the plugin for th input grammar and configuration\.

           * string *serial*

             This argument will contain the *canonical* serialization of the
             parsing expression grammar for which to generate the output\. The
             specification of what a *canonical* serialization is can be found
             in the section [PEG serialization format](#section6)\.

           * dictionary *configuration*

             This argument will contain the configuration to configure the
             converter with before invoking it, as a dictionary mapping from
             options to values\.

             Please read the section [Options](#section4) for the set of
             standard options any converter has to accept, and thus any plugin
             as well\. Any other options accepted by a specific plugin will be
             described in its manpage\.

  1. A single usage cycle of a plugin consists of an invokation of the command
     __[export](\.\./\.\./\.\./\.\./index\.md\#export)__\. This call has to leave
     the plugin in a state where another usage cycle can be run without
     problems\.

# <a name='section4'></a>Options

Each export converter and plugin for an export converter has to accept the
options below in their __configure__ method\. Converters are allowed to
ignore the contents of these options when performing a conversion, but they must
not reject them\. Plugins are expected to pass the options given to them to the
converter they are invoking\.

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

# <a name='section5'></a>Usage

To use a converter do

    # Get the converter (single command here, not class)
    package require the-converter-package

    # Provide a configuration
    theconverter configure ...

    # Perform the conversion
    set result [theconverter convert $thegrammarserial]

    ... process the result ...

To use a plugin __FOO__ do

    # Get an export plugin manager
    package require pt::peg::export
    pt::peg::export E

    # Provide a configuration
    E configuration set ...

    # Run the plugin, and the converter inside.
    set result [E export serial $grammarserial FOO]

    ... process the result ...

# <a name='section6'></a>PEG serialization format

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
                      in the section [PE serialization format](#section7)\.

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
             format](#section7)\.

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

# <a name='section7'></a>PE serialization format

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

## <a name='subsection2'></a>Example

Assuming the parsing expression shown on the right\-hand side of the rule

    Expression <- Term (AddOp Term)*

then its canonical serialization \(except for whitespace\) is

    {x {n Term} {* {x {n AddOp} {n Term}}}}

# <a name='section8'></a>Bugs, Ideas, Feedback

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
