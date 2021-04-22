
[//000000001]: # (pt::peg\_language \- Parser Tools)
[//000000002]: # (Generated from file 'pt\_peg\_language\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pt::peg\_language\(n\) 1 tcllib "Parser Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pt::peg\_language \- PEG Language Tutorial

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [What is it?](#section2)

  - [The elements of the language](#section3)

      - [Basic structure](#subsection1)

      - [Names](#subsection2)

      - [Rules](#subsection3)

      - [Expressions](#subsection4)

      - [Whitespace and comments](#subsection5)

      - [Nonterminal attributes](#subsection6)

  - [PEG Specification Language](#section4)

      - [Example](#subsection7)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  

# <a name='description'></a>DESCRIPTION

Are you lost ? Do you have trouble understanding this document ? In that case
please read the overview provided by the *[Introduction to Parser
Tools](pt\_introduction\.md)*\. This document is the entrypoint to the whole
system the current package is a part of\.

Welcome to the tutorial / introduction for the [PEG Specification
Language](#section4)\. If you are already familiar with the language we are
about to discuss, and only wish to refresh your memory you can, of course, skip
ahead to the aforementioned section and just read the full formal specification\.

# <a name='section2'></a>What is it?

__peg__, a language for the specification of parsing expression grammars is
meant to be human readable, and writable as well, yet strict enough to allow its
processing by machine\. Like any computer language\. It was defined to make
writing the specification of a grammar easy, something the other formats found
in the Parser Tools do not lend themselves too\.

# <a name='section3'></a>The elements of the language

## <a name='subsection1'></a>Basic structure

The general outline of a textual PEG is

    PEG <<name>> (<<start-expression>>)
       <<rules>>
    END;

*Note*: We are using text in double angle\-brackets as place\-holders for things
not yet explained\.

## <a name='subsection2'></a>Names

Names are mostly used to identify the nonterminal symbols of the grammar, i\.e\.
that which occurs on the left\-hand side of a <rule>\. The exception to that is
the name given after the keyword __PEG__ \(see previous section\), which is
the name of the whole grammar itself\.

The structure of a name is simple:

  1. It begins with a letter, underscore, or colon, followed by

  1. zero or more letters, digits, underscores, or colons\.

Or, in formal textual notation:

    ([_:] / <alpha>) ([_:] / <alnum>)*

Examples of names:

    Hello
    ::world
    _:submarine55_

Examples of text which are *not* names:

    12
    .bogus
    0wrong
    @location

## <a name='subsection3'></a>Rules

The main body of the text of a grammar specification is taken up by the rules\.
Each rule defines the sentence structure of one nonterminal symbol\. Their basic
structure is

    <<name>>  <-  <<expression>> ;

The <name> specifies the nonterminal symbol to be defined, the <expression>
after the arrow \(<\-\) then declares its structure\.

Note that each rule ends in a single semicolon, even the last\. I\.e\. the
semicolon is a rule *terminator*, not a separator\.

We can have as many rules as we like, as long as we define each nonterminal
symbol at most once, and have at least one rule for each nonterminal symbol
which occured in an expression, i\.e\. in either the start expression of the
grammar, or the right\-hande side of a rule\.

## <a name='subsection4'></a>Expressions

The *parsing* expressions are the meat of any specification\. They declare the
structure of the whole document \(<<start\-expression>>\), and of all nonterminal
symbols\.

All expressions are made up out of *atomic expressions* and *operators*
combining them\. We have operators for choosing between alternatives, repetition
of parts, and for look\-ahead constraints\. There is no explicit operator for the
sequencing \(also known as *concatenation*\) of parts however\. This is specified
by simply placing the parts adjacent to each other\.

Here are the operators, from highest to lowest priority \(i\.e\. strength of
binding\):

    # Binary operators.

    <<expression-1>>     <<expression-2>>  # sequence. parse 1, then 2.
    <<expression-1>>  /  <<expression-2>>  # alternative. try to parse 1, and parse 2 if 1 failed to parse.

    # Prefix operators. Lookahead constraints. Same priority.

    & <<expression>>  # Parse expression, ok on successful parse.
    ! <<expression>>  # Ditto, except ok on failure to parse.

    # Suffix operators. Repetition. Same priority.

    <<expression>> ?  # Parse expression none, or once (repeat 0 or 1).
    <<expression>> *  # Parse expression zero or more times.
    <<expression>> +  # Parse expression one or more times.

    # Expression nesting

    ( <<expression>> ) # Put an expression in parens to change its priority.

With this we can now deconstruct the formal expression for names given in
section [Names](#subsection2):

    ([_:] / <alpha>) ([_:] / <alnum>)*

It is a sequence of two parts,

    [_:] / <alpha>

and

    ([_:] / <alnum>)*

The parentheses around the parts kept their inner alternatives bound together
against the normally higher priority of the sequence\. Each of the two parts is
an alternative, with the second part additionally repeated zero or more times,
leaving us with the three atomic expressions

    [_:]
    <alpha>
    <alnum>

And *atomic expressions* are our next topic\. They fall into three classes:

  1. names, i\.e\. nonterminal symbols,

  1. string literals, and

  1. character classes\.

Names we know about already, or see section [Names](#subsection2) for a
refresher\.

String literals are simple\. They are delimited by \(i\.e\. start and end with\)
either a single or double\-apostroph, and in between the delimiters we can have
any character but the delimiter itself\. They can be empty as well\. Examples of
strings are

    ''
    ""
    'hello'
    "umbra"
    "'"
    '"'

The last two examples show how to place any of the delimiters into a string\.

For the last, but not least of our atomic expressions, character classes, we
have a number of predefined classes, shown below, and the ability to construct
or own\. The predefined classes are:

    <alnum>    # Any unicode alphabet or digit character (string is alnum).
    <alpha>    # Any unicode alphabet character (string is alpha).
    <ascii>    # Any unicode character below codepoint 0x80 (string is ascii).
    <control>  # Any unicode control character (string is control).
    <ddigit>   # The digit characters [0-9].
    <digit>    # Any unicode digit character (string is digit).
    <graph>    # Any unicode printing character, except space (string is graph).
    <lower>    # Any unicode lower-case alphabet character (string is lower).
    <print>    # Any unicode printing character, incl. space (string is print).
    <punct>    # Any unicode punctuation character (string is punct).
    <space>    # Any unicode space character (string is space).
    <upper>    # Any unicode upper-case alphabet character (string is upper).
    <wordchar> # Any unicode word character (string is wordchar).
    <xdigit>   # The hexadecimal digit characters [0-9a-fA-F].
    .          # Any character, except end of input.

And the syntax of custom\-defined character classes is

    [ <<range>>* ]

where each range is either a single character, or of the form

    <<character>> - <character>>

Examples for character classes we have seen already in the course of this
introduction are

    [_:]
    [0-9]
    [0-9a-fA-F]

We are nearly done with expressions\. The only piece left is to tell how the
characters in character classes and string literals are specified\.

Basically characters in the input stand for themselves, and in addition to that
we several types of escape syntax to to repesent control characters, or
characters outside of the encoding the text is in\.

All the escaped forms are started with a backslash character \('\\', unicode
codepoint 0x5C\)\. This is then followed by a series of octal digits, or 'u' and
hexedecimal digits, or a regular character from a fixed set for various control
characters\. Some examples:

    \n \r \t \' \" \[ \] \\ #
    \000 up to \277         # octal escape, all ascii character, leading 0's can be removed.
    \u2CA7                  # hexadecimal escape, all unicode characters.
    #                       # Here 2ca7 <=> Koptic Small Letter Tau

## <a name='subsection5'></a>Whitespace and comments

One issue not touched upon so far is whitespace and comments\.

Whitespace is any unicode space character, i\.e\. anything in the character class
<space>, and comments\. The latter are sequences of characters starting with a
'\#' \(hash, unicode codepoint 0x23\) and ending at the next end\-of\-line\.

Whitespace can be freely used between all syntactical elements of a grammar
specification\. It cannot be used inside of syntactical elements, like names,
string literals, predefined character classes, etc\.

## <a name='subsection6'></a>Nonterminal attributes

Lastly, a more advanced topic\. In the section [Rules](#subsection3) we gave
the structure of a rule as

    <<name>>  <-  <<expression>> ;

This is not quite true\. It is possible to associate a semantic mode with the
nonterminal in the rule, by writing it before the name, separated from it by a
colon, i\.e\. writing

    <<mode>> : <<name>>  <-  <<expression>> ;

is also allowed\. This mode is optional\. The known modes and their meanings are:

  - __value__

    The semantic value of the nonterminal symbol is an abstract syntax tree
    consisting of a single node node for the nonterminal itself, which has the
    ASTs of the symbol's right hand side as its children\.

  - __leaf__

    The semantic value of the nonterminal symbol is an abstract syntax tree
    consisting of a single node node for the nonterminal, without any children\.
    Any ASTs generated by the symbol's right hand side are discarded\.

  - __void__

    The nonterminal has no semantic value\. Any ASTs generated by the symbol's
    right hand side are discarded \(as well\)\.

Of these three modes only __leaf__ and __void__ can be specified
directly\. __value__ is implicitly specified by the absence of a mode before
the nonterminal\.

Now, with all the above under our belt it should be possible to not only read,
but understand the formal specification of the text representation shown in the
next section, written in itself\.

# <a name='section4'></a>PEG Specification Language

__peg__, a language for the specification of parsing expression grammars is
meant to be human readable, and writable as well, yet strict enough to allow its
processing by machine\. Like any computer language\. It was defined to make
writing the specification of a grammar easy, something the other formats found
in the Parser Tools do not lend themselves too\.

It is formally specified by the grammar shown below, written in itself\. For a
tutorial / introduction to the language please go and read the *PEG Language
Tutorial*\.

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

## <a name='subsection7'></a>Example

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
