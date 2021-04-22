
[//000000001]: # (pt::peg::to::param \- Parser Tools)
[//000000002]: # (Generated from file 'to\.inc' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pt::peg::to::param\(n\) 1 tcllib "Parser Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pt::peg::to::param \- PEG Conversion\. Write PARAM format

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Options](#section3)

  - [PARAM code representation of parsing expression grammars](#section4)

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
package require pt::peg::to::param ?1?  
package require pt::peg  
package require pt::pe  

[__pt::peg::to::param__ __reset__](#1)  
[__pt::peg::to::param__ __configure__](#2)  
[__pt::peg::to::param__ __configure__ *option*](#3)  
[__pt::peg::to::param__ __configure__ *option* *value*\.\.\.](#4)  
[__pt::peg::to::param__ __convert__ *serial*](#5)  

# <a name='description'></a>DESCRIPTION

Are you lost ? Do you have trouble understanding this document ? In that case
please read the overview provided by the *[Introduction to Parser
Tools](pt\_introduction\.md)*\. This document is the entrypoint to the whole
system the current package is a part of\.

This package implements the converter from parsing expression grammars to PARAM
markup\.

It resides in the Export section of the Core Layer of Parser Tools, and can be
used either directly with the other packages of this layer, or indirectly
through the export manager provided by
__[pt::peg::export](pt\_peg\_export\.md)__\. The latter is intented for use
in untrusted environments and done through the corresponding export plugin
__pt::peg::export::param__ sitting between converter and export manager\.

![](\.\./\.\./\.\./\.\./image/arch\_core\_eplugins\.png)

# <a name='section2'></a>API

The API provided by this package satisfies the specification of the Converter
API found in the *[Parser Tools Export API](pt\_to\_api\.md)* specification\.

  - <a name='1'></a>__pt::peg::to::param__ __reset__

    This command resets the configuration of the package to its default
    settings\.

  - <a name='2'></a>__pt::peg::to::param__ __configure__

    This command returns a dictionary containing the current configuration of
    the package\.

  - <a name='3'></a>__pt::peg::to::param__ __configure__ *option*

    This command returns the current value of the specified configuration
    *option* of the package\. For the set of legal options, please read the
    section [Options](#section3)\.

  - <a name='4'></a>__pt::peg::to::param__ __configure__ *option* *value*\.\.\.

    This command sets the given configuration *option*s of the package, to the
    specified *value*s\. For the set of legal options, please read the section
    [Options](#section3)\.

  - <a name='5'></a>__pt::peg::to::param__ __convert__ *serial*

    This command takes the canonical serialization of a parsing expression
    grammar, as specified in section [PEG serialization format](#section5),
    and contained in *serial*, and generates PARAM markup encoding the
    grammar, per the current package configuration\. The created string is then
    returned as the result of the command\.

# <a name='section3'></a>Options

The converter to PARAM markup recognizes the following configuration variables
and changes its behaviour as they specify\.

  - __\-template__ string

    The value of this configuration variable is a string into which to put the
    generated text and the other configuration settings\. The various locations
    for user\-data are expected to be specified with the placeholders listed
    below\. The default value is "__@code@__"\.

      * __@user@__

        To be replaced with the value of the configuration variable
        __\-user__\.

      * __@format@__

        To be replaced with the the constant __PARAM__\.

      * __@file@__

        To be replaced with the value of the configuration variable
        __\-file__\.

      * __@name@__

        To be replaced with the value of the configuration variable
        __\-name__\.

      * __@code@__

        To be replaced with the generated text\.

  - __\-name__ string

    The value of this configuration variable is the name of the grammar for
    which the conversion is run\. The default value is __a\_pe\_grammar__\.

  - __\-user__ string

    The value of this configuration variable is the name of the user for which
    the conversion is run\. The default value is __unknown__\.

  - __\-file__ string

    The value of this configuration variable is the name of the file or other
    entity from which the grammar came, for which the conversion is run\. The
    default value is __unknown__\.

# <a name='section4'></a>PARAM code representation of parsing expression grammars

The PARAM code representation of parsing expression grammars is assembler\-like
text using the instructions of the virtual machine documented in the *[PackRat
Machine Specification](pt\_param\.md)*, plus a few more for control flow \(jump
ok, jump fail, call symbol, return\)\.

It is not really useful, except possibly as a tool demonstrating how a grammar
is compiled in general, without getting distracted by the incidentials of a
framework, i\.e\. like the supporting C and Tcl code generated by the other
PARAM\-derived formats\.

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

one possible PARAM serialization for it is

    # -*- text -*-
    # Parsing Expression Grammar 'TEMPLATE'.
    # Generated for unknown, from file 'TEST'

    #
    # Grammar Start Expression
    #

    <<MAIN>>:
             call              sym_Expression
             halt

    #
    # value Symbol 'AddOp'
    #

    sym_AddOp:
    # /
    #     '-'
    #     '+'

             symbol_restore    AddOp
      found! jump              found_7
             loc_push

             call              choice_5

       fail! value_clear
         ok! value_leaf        AddOp
             symbol_save       AddOp
             error_nonterminal AddOp
             loc_pop_discard

    found_7:
         ok! ast_value_push
             return

    choice_5:
    # /
    #     '-'
    #     '+'

             error_clear

             loc_push
             error_push

             input_next        "t -"
         ok! test_char         "-"

             error_pop_merge
         ok! jump              oknoast_4

             loc_pop_rewind
             loc_push
             error_push

             input_next        "t +"
         ok! test_char         "+"

             error_pop_merge
         ok! jump              oknoast_4

             loc_pop_rewind
             status_fail
             return

    oknoast_4:
             loc_pop_discard
             return
    #
    # value Symbol 'Digit'
    #

    sym_Digit:
    # /
    #     '0'
    #     '1'
    #     '2'
    #     '3'
    #     '4'
    #     '5'
    #     '6'
    #     '7'
    #     '8'
    #     '9'

             symbol_restore    Digit
      found! jump              found_22
             loc_push

             call              choice_20

       fail! value_clear
         ok! value_leaf        Digit
             symbol_save       Digit
             error_nonterminal Digit
             loc_pop_discard

    found_22:
         ok! ast_value_push
             return

    choice_20:
    # /
    #     '0'
    #     '1'
    #     '2'
    #     '3'
    #     '4'
    #     '5'
    #     '6'
    #     '7'
    #     '8'
    #     '9'

             error_clear

             loc_push
             error_push

             input_next        "t 0"
         ok! test_char         "0"

             error_pop_merge
         ok! jump              oknoast_19

             loc_pop_rewind
             loc_push
             error_push

             input_next        "t 1"
         ok! test_char         "1"

             error_pop_merge
         ok! jump              oknoast_19

             loc_pop_rewind
             loc_push
             error_push

             input_next        "t 2"
         ok! test_char         "2"

             error_pop_merge
         ok! jump              oknoast_19

             loc_pop_rewind
             loc_push
             error_push

             input_next        "t 3"
         ok! test_char         "3"

             error_pop_merge
         ok! jump              oknoast_19

             loc_pop_rewind
             loc_push
             error_push

             input_next        "t 4"
         ok! test_char         "4"

             error_pop_merge
         ok! jump              oknoast_19

             loc_pop_rewind
             loc_push
             error_push

             input_next        "t 5"
         ok! test_char         "5"

             error_pop_merge
         ok! jump              oknoast_19

             loc_pop_rewind
             loc_push
             error_push

             input_next        "t 6"
         ok! test_char         "6"

             error_pop_merge
         ok! jump              oknoast_19

             loc_pop_rewind
             loc_push
             error_push

             input_next        "t 7"
         ok! test_char         "7"

             error_pop_merge
         ok! jump              oknoast_19

             loc_pop_rewind
             loc_push
             error_push

             input_next        "t 8"
         ok! test_char         "8"

             error_pop_merge
         ok! jump              oknoast_19

             loc_pop_rewind
             loc_push
             error_push

             input_next        "t 9"
         ok! test_char         "9"

             error_pop_merge
         ok! jump              oknoast_19

             loc_pop_rewind
             status_fail
             return

    oknoast_19:
             loc_pop_discard
             return
    #
    # value Symbol 'Expression'
    #

    sym_Expression:
    # /
    #     x
    #         '\('
    #         (Expression)
    #         '\)'
    #     x
    #         (Factor)
    #         *
    #             x
    #                 (MulOp)
    #                 (Factor)

             symbol_restore    Expression
      found! jump              found_46
             loc_push
             ast_push

             call              choice_44

       fail! value_clear
         ok! value_reduce      Expression
             symbol_save       Expression
             error_nonterminal Expression
             ast_pop_rewind
             loc_pop_discard

    found_46:
         ok! ast_value_push
             return

    choice_44:
    # /
    #     x
    #         '\('
    #         (Expression)
    #         '\)'
    #     x
    #         (Factor)
    #         *
    #             x
    #                 (MulOp)
    #                 (Factor)

             error_clear

             ast_push
             loc_push
             error_push

             call              sequence_27

             error_pop_merge
         ok! jump              ok_43

             ast_pop_rewind
             loc_pop_rewind
             ast_push
             loc_push
             error_push

             call              sequence_40

             error_pop_merge
         ok! jump              ok_43

             ast_pop_rewind
             loc_pop_rewind
             status_fail
             return

    ok_43:
             ast_pop_discard
             loc_pop_discard
             return

    sequence_27:
    # x
    #     '\('
    #     (Expression)
    #     '\)'

             loc_push
             error_clear

             error_push

             input_next        "t ("
         ok! test_char         "("

             error_pop_merge
       fail! jump              failednoast_29
             ast_push
             error_push

             call              sym_Expression

             error_pop_merge
       fail! jump              failed_28
             error_push

             input_next        "t )"
         ok! test_char         ")"

             error_pop_merge
       fail! jump              failed_28

             ast_pop_discard
             loc_pop_discard
             return

    failed_28:
             ast_pop_rewind

    failednoast_29:
             loc_pop_rewind
             return

    sequence_40:
    # x
    #     (Factor)
    #     *
    #         x
    #             (MulOp)
    #             (Factor)

             ast_push
             loc_push
             error_clear

             error_push

             call              sym_Factor

             error_pop_merge
       fail! jump              failed_41
             error_push

             call              kleene_37

             error_pop_merge
       fail! jump              failed_41

             ast_pop_discard
             loc_pop_discard
             return

    failed_41:
             ast_pop_rewind
             loc_pop_rewind
             return

    kleene_37:
    # *
    #     x
    #         (MulOp)
    #         (Factor)

             loc_push
             error_push

             call              sequence_34

             error_pop_merge
       fail! jump              failed_38
             loc_pop_discard
             jump              kleene_37

    failed_38:
             loc_pop_rewind
             status_ok
             return

    sequence_34:
    # x
    #     (MulOp)
    #     (Factor)

             ast_push
             loc_push
             error_clear

             error_push

             call              sym_MulOp

             error_pop_merge
       fail! jump              failed_35
             error_push

             call              sym_Factor

             error_pop_merge
       fail! jump              failed_35

             ast_pop_discard
             loc_pop_discard
             return

    failed_35:
             ast_pop_rewind
             loc_pop_rewind
             return
    #
    # value Symbol 'Factor'
    #

    sym_Factor:
    # x
    #     (Term)
    #     *
    #         x
    #             (AddOp)
    #             (Term)

             symbol_restore    Factor
      found! jump              found_60
             loc_push
             ast_push

             call              sequence_57

       fail! value_clear
         ok! value_reduce      Factor
             symbol_save       Factor
             error_nonterminal Factor
             ast_pop_rewind
             loc_pop_discard

    found_60:
         ok! ast_value_push
             return

    sequence_57:
    # x
    #     (Term)
    #     *
    #         x
    #             (AddOp)
    #             (Term)

             ast_push
             loc_push
             error_clear

             error_push

             call              sym_Term

             error_pop_merge
       fail! jump              failed_58
             error_push

             call              kleene_54

             error_pop_merge
       fail! jump              failed_58

             ast_pop_discard
             loc_pop_discard
             return

    failed_58:
             ast_pop_rewind
             loc_pop_rewind
             return

    kleene_54:
    # *
    #     x
    #         (AddOp)
    #         (Term)

             loc_push
             error_push

             call              sequence_51

             error_pop_merge
       fail! jump              failed_55
             loc_pop_discard
             jump              kleene_54

    failed_55:
             loc_pop_rewind
             status_ok
             return

    sequence_51:
    # x
    #     (AddOp)
    #     (Term)

             ast_push
             loc_push
             error_clear

             error_push

             call              sym_AddOp

             error_pop_merge
       fail! jump              failed_52
             error_push

             call              sym_Term

             error_pop_merge
       fail! jump              failed_52

             ast_pop_discard
             loc_pop_discard
             return

    failed_52:
             ast_pop_rewind
             loc_pop_rewind
             return
    #
    # value Symbol 'MulOp'
    #

    sym_MulOp:
    # /
    #     '*'
    #     '/'

             symbol_restore    MulOp
      found! jump              found_67
             loc_push

             call              choice_65

       fail! value_clear
         ok! value_leaf        MulOp
             symbol_save       MulOp
             error_nonterminal MulOp
             loc_pop_discard

    found_67:
         ok! ast_value_push
             return

    choice_65:
    # /
    #     '*'
    #     '/'

             error_clear

             loc_push
             error_push

             input_next        "t *"
         ok! test_char         "*"

             error_pop_merge
         ok! jump              oknoast_64

             loc_pop_rewind
             loc_push
             error_push

             input_next        "t /"
         ok! test_char         "/"

             error_pop_merge
         ok! jump              oknoast_64

             loc_pop_rewind
             status_fail
             return

    oknoast_64:
             loc_pop_discard
             return
    #
    # value Symbol 'Number'
    #

    sym_Number:
    # x
    #     ?
    #         (Sign)
    #     +
    #         (Digit)

             symbol_restore    Number
      found! jump              found_80
             loc_push
             ast_push

             call              sequence_77

       fail! value_clear
         ok! value_reduce      Number
             symbol_save       Number
             error_nonterminal Number
             ast_pop_rewind
             loc_pop_discard

    found_80:
         ok! ast_value_push
             return

    sequence_77:
    # x
    #     ?
    #         (Sign)
    #     +
    #         (Digit)

             ast_push
             loc_push
             error_clear

             error_push

             call              optional_70

             error_pop_merge
       fail! jump              failed_78
             error_push

             call              poskleene_73

             error_pop_merge
       fail! jump              failed_78

             ast_pop_discard
             loc_pop_discard
             return

    failed_78:
             ast_pop_rewind
             loc_pop_rewind
             return

    optional_70:
    # ?
    #     (Sign)

             loc_push
             error_push

             call              sym_Sign

             error_pop_merge
       fail! loc_pop_rewind
         ok! loc_pop_discard
             status_ok
             return

    poskleene_73:
    # +
    #     (Digit)

             loc_push

             call              sym_Digit

       fail! jump              failed_74

    loop_75:
             loc_pop_discard
             loc_push
             error_push

             call              sym_Digit

             error_pop_merge
         ok! jump              loop_75
             status_ok

    failed_74:
             loc_pop_rewind
             return
    #
    # value Symbol 'Sign'
    #

    sym_Sign:
    # /
    #     '-'
    #     '+'

             symbol_restore    Sign
      found! jump              found_86
             loc_push

             call              choice_5

       fail! value_clear
         ok! value_leaf        Sign
             symbol_save       Sign
             error_nonterminal Sign
             loc_pop_discard

    found_86:
         ok! ast_value_push
             return
    #
    # value Symbol 'Term'
    #

    sym_Term:
    # (Number)

             symbol_restore    Term
      found! jump              found_89
             loc_push
             ast_push

             call              sym_Number

       fail! value_clear
         ok! value_reduce      Term
             symbol_save       Term
             error_nonterminal Term
             ast_pop_rewind
             loc_pop_discard

    found_89:
         ok! ast_value_push
             return

    #
    #

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

[EBNF](\.\./\.\./\.\./\.\./index\.md\#ebnf), [LL\(k\)](\.\./\.\./\.\./\.\./index\.md\#ll\_k\_),
[PARAM](\.\./\.\./\.\./\.\./index\.md\#param), [PEG](\.\./\.\./\.\./\.\./index\.md\#peg),
[TDPL](\.\./\.\./\.\./\.\./index\.md\#tdpl), [context\-free
languages](\.\./\.\./\.\./\.\./index\.md\#context\_free\_languages),
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
