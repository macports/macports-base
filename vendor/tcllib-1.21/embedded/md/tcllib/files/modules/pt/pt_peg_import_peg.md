
[//000000001]: # (pt::peg::import::peg \- Parser Tools)
[//000000002]: # (Generated from file 'plugin\.inc' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pt::peg::import::peg\(n\) 1 tcllib "Parser Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pt::peg::import::peg \- PEG Import Plugin\. Read PEG format

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [PEG Specification Language](#section3)

      - [Example](#subsection1)

  - [PEG serialization format](#section4)

      - [Example](#subsection2)

  - [PE serialization format](#section5)

      - [Example](#subsection3)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require pt::peg::import::peg ?1?  
package require pt::peg::to::peg  

[__[import](\.\./\.\./\.\./\.\./index\.md\#import)__ *text*](#1)  

# <a name='description'></a>DESCRIPTION

Are you lost ? Do you have trouble understanding this document ? In that case
please read the overview provided by the *[Introduction to Parser
Tools](pt\_introduction\.md)*\. This document is the entrypoint to the whole
system the current package is a part of\.

This package implements the parsing expression grammar import plugin processing
PEG markup\.

It resides in the Import section of the Core Layer of Parser Tools and is
intended to be used by __[pt::peg::import](pt\_peg\_import\.md)__, the
import manager, sitting between it and the corresponding core conversion
functionality provided by __[pt::peg::from::peg](pt\_peg\_from\_peg\.md)__\.

![](\.\./\.\./\.\./\.\./image/arch\_core\_iplugins\.png)

While the direct use of this package with a regular interpreter is possible,
this is strongly disrecommended and requires a number of contortions to provide
the expected environment\. The proper way to use this functionality depends on
the situation:

  1. In an untrusted environment the proper access is through the package
     __[pt::peg::import](pt\_peg\_import\.md)__ and the import manager
     objects it provides\.

  1. In a trusted environment however simply use the package
     __[pt::peg::from::peg](pt\_peg\_from\_peg\.md)__ and access the core
     conversion functionality directly\.

# <a name='section2'></a>API

The API provided by this package satisfies the specification of the Plugin API
found in the *[Parser Tools Import API](pt\_from\_api\.md)* specification\.

  - <a name='1'></a>__[import](\.\./\.\./\.\./\.\./index\.md\#import)__ *text*

    This command takes the PEG markup encoding a parsing expression grammar and
    contained in *text*, and generates the canonical serialization of said
    grammar, as specified in section [PEG serialization format](#section4)\.
    The created value is then returned as the result of the command\.

# <a name='section3'></a>PEG Specification Language

__peg__, a language for the specification of parsing expression grammars is
meant to be human readable, and writable as well, yet strict enough to allow its
processing by machine\. Like any computer language\. It was defined to make
writing the specification of a grammar easy, something the other formats found
in the Parser Tools do not lend themselves too\.

It is formally specified by the grammar shown below, written in itself\. For a
tutorial / introduction to the language please go and read the *[PEG Language
Tutorial](pt\_peg\_language\.md)*\.

    PEG pe-grammar-for-peg (Grammar)

    	# --------------------------------------------------------------------
            # Syntactical constructs

            Grammar         <- WHITESPACE Header Definition* Final EOF ;

            Header          <- PEG Identifier StartExpr ;
            Definition      <- Attribute? Identifier IS Expression SEMICOLON ;
            Attribute       <- (VOID / LEAF) COLON ;
            Expression      <- Sequence (SLASH Sequence)* ;
            Sequence        <- Prefix+ ;
            Prefix          <- (AND / NOT)? Suffix ;
            Suffix          <- Primary (QUESTION / STAR / PLUS)? ;
            Primary         <- ALNUM / ALPHA / ASCII / CONTROL / DDIGIT / DIGIT
                            /  GRAPH / LOWER / PRINTABLE / PUNCT / SPACE / UPPER
                            /  WORDCHAR / XDIGIT
                            / Identifier
                            /  OPEN Expression CLOSE
                            /  Literal
                            /  Class
                            /  DOT
                            ;
            Literal         <- APOSTROPH  (!APOSTROPH  Char)* APOSTROPH  WHITESPACE
                            /  DAPOSTROPH (!DAPOSTROPH Char)* DAPOSTROPH WHITESPACE ;
            Class           <- OPENB (!CLOSEB Range)* CLOSEB WHITESPACE ;
            Range           <- Char TO Char / Char ;

            StartExpr       <- OPEN Expression CLOSE ;
    void:   Final           <- "END" WHITESPACE SEMICOLON WHITESPACE ;

            # --------------------------------------------------------------------
            # Lexing constructs

            Identifier      <- Ident WHITESPACE ;
    leaf:   Ident           <- ([_:] / <alpha>) ([_:] / <alnum>)* ;
            Char            <- CharSpecial / CharOctalFull / CharOctalPart
                            /  CharUnicode / CharUnescaped
                            ;

    leaf:   CharSpecial     <- "\\" [nrt'"\[\]\\] ;
    leaf:   CharOctalFull   <- "\\" [0-2][0-7][0-7] ;
    leaf:   CharOctalPart   <- "\\" [0-7][0-7]? ;
    leaf:   CharUnicode     <- "\\" 'u' HexDigit (HexDigit (HexDigit HexDigit?)?)? ;
    leaf:   CharUnescaped   <- !"\\" . ;

    void:   HexDigit        <- [0-9a-fA-F] ;

    void:   TO              <- '-'           ;
    void:   OPENB           <- "["           ;
    void:   CLOSEB          <- "]"           ;
    void:   APOSTROPH       <- "'"           ;
    void:   DAPOSTROPH      <- '"'           ;
    void:   PEG             <- "PEG" !([_:] / <alnum>) WHITESPACE ;
    void:   IS              <- "<-"    WHITESPACE ;
    leaf:   VOID            <- "void"  WHITESPACE ; # Implies that definition has no semantic value.
    leaf:   LEAF            <- "leaf"  WHITESPACE ; # Implies that definition has no terminals.
    void:   SEMICOLON       <- ";"     WHITESPACE ;
    void:   COLON           <- ":"     WHITESPACE ;
    void:   SLASH           <- "/"     WHITESPACE ;
    leaf:   AND             <- "&"     WHITESPACE ;
    leaf:   NOT             <- "!"     WHITESPACE ;
    leaf:   QUESTION        <- "?"     WHITESPACE ;
    leaf:   STAR            <- "*"     WHITESPACE ;
    leaf:   PLUS            <- "+"     WHITESPACE ;
    void:   OPEN            <- "("     WHITESPACE ;
    void:   CLOSE           <- ")"     WHITESPACE ;
    leaf:   DOT             <- "."     WHITESPACE ;

    leaf:   ALNUM           <- "<alnum>"    WHITESPACE ;
    leaf:   ALPHA           <- "<alpha>"    WHITESPACE ;
    leaf:   ASCII           <- "<ascii>"    WHITESPACE ;
    leaf:   CONTROL         <- "<control>"  WHITESPACE ;
    leaf:   DDIGIT          <- "<ddigit>"   WHITESPACE ;
    leaf:   DIGIT           <- "<digit>"    WHITESPACE ;
    leaf:   GRAPH           <- "<graph>"    WHITESPACE ;
    leaf:   LOWER           <- "<lower>"    WHITESPACE ;
    leaf:   PRINTABLE       <- "<print>"    WHITESPACE ;
    leaf:   PUNCT           <- "<punct>"    WHITESPACE ;
    leaf:   SPACE           <- "<space>"    WHITESPACE ;
    leaf:   UPPER           <- "<upper>"    WHITESPACE ;
    leaf:   WORDCHAR        <- "<wordchar>" WHITESPACE ;
    leaf:   XDIGIT          <- "<xdigit>"   WHITESPACE ;

    void:   WHITESPACE      <- (" " / "\t" / EOL / COMMENT)* ;
    void:   COMMENT         <- '#' (!EOL .)* EOL ;
    void:   EOL             <- "\n\r" / "\n" / "\r" ;
    void:   EOF             <- !. ;

            # --------------------------------------------------------------------
    END;

## <a name='subsection1'></a>Example

Our example specifies the grammar for a basic 4\-operation calculator\.

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

Using higher\-level features of the notation, i\.e\. the character classes
\(predefined and custom\), this example can be rewritten as

    PEG calculator (Expression)
        Sign       <- [-+] 						;
        Number     <- Sign? <ddigit>+				;
        Expression <- '(' Expression ')' / (Factor (MulOp Factor)*)	;
        MulOp      <- [*/]						;
        Factor     <- Term (AddOp Term)*				;
        AddOp      <- [-+]						;
        Term       <- Number					;
    END;

# <a name='section4'></a>PEG serialization format

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
                      in the section [PE serialization format](#section5)\.

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
             format](#section5)\.

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

# <a name='section5'></a>PE serialization format

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

# <a name='section6'></a>Bugs, Ideas, Feedback

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
[import](\.\./\.\./\.\./\.\./index\.md\#import),
[matching](\.\./\.\./\.\./\.\./index\.md\#matching),
[parser](\.\./\.\./\.\./\.\./index\.md\#parser), [parsing
expression](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression), [parsing expression
grammar](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression\_grammar),
[plugin](\.\./\.\./\.\./\.\./index\.md\#plugin), [push down
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
