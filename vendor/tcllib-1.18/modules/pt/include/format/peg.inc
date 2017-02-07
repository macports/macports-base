
[section {PEG Specification Language}]

[include whatis_peg.inc]
[para]

It is formally specified by the grammar shown below, written in
itself. For a tutorial / introduction to the language please go and
read the [manpage {PEG Language Tutorial}].

[para]
[example {
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
}]

[subsection Example]

Our example specifies the grammar for a basic 4-operation calculator.

[para]
[include ../example/expr_peg.inc]
[para]

Using higher-level features of the notation, i.e. the character
classes (predefined and custom), this example can be rewritten as

[para]
[include ../example/expr_peg_compact.inc]
[para]
