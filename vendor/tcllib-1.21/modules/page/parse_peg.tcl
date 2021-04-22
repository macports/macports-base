# -*- tcl -*-
## Parsing Expression Grammar 'pg::peg::grammar'.
## Recursive Descent Packrat parser generated
## by the PAGE writer plugin 'me'.
## (C) 2005 Andreas Kupries <andreas_kupries@users.sourceforge.net>

# ### ### ### ######### ######### #########
## Package description

# The commands provided here match an input provided through a buffer
# command to the PE grammar 'pg::peg::grammar'. The parser is based on the package
# 'grammar::me::tcl' (recursive-descent, packrat, pulling chars,
# pushing the generated AST).

# ### ### ### ######### ######### #########
## Requisites

package require grammar::me::tcl

# ### ### ### ######### ######### #########
## Implementation

namespace eval ::page::parse::peg {
    # Import the virtual machine for matching.

    namespace import ::grammar::me::tcl::*
    upvar #0 ::grammar::me::tcl::ok ok
}

# ### ### ### ######### ######### #########
## API Implementation.

proc ::page::parse::peg::parse {nxcmd emvar astvar} {
    variable ok
    variable se

    upvar 1 $emvar emsg $astvar ast

    init $nxcmd

    matchSymbol_Grammar    ; # (n Grammar)

    isv_nonterminal_reduce ALL -1
    set ast [sv]
    if {!$ok} {
        foreach {l m} [ier_get] break
        lappend l [lc $l]
        set emsg [list $l $m]
    }

    return $ok
}

# ### ### ### ######### ######### #########
## Internal helper methods

# Grammar 'pg::peg::grammar'
#
# ALNUM = (x (t <)
#            (t a)
#            (t l)
#            (t n)
#            (t u)
#            (t m)
#            (t >)
#            (n SPACE))
#
# ALPHA = (x (t <)
#            (t a)
#            (t l)
#            (t p)
#            (t h)
#            (t a)
#            (t >)
#            (n SPACE))
#
# AND = (x (t &)
#          (n SPACE))
#
# APOSTROPH = (t ')
#
# Attribute = (x (/ (n VOID)
#                   (n LEAF)
#                   (n MATCH))
#                (n COLON))
#
# Char = (/ (n CharSpecial)
#           (n CharOctalFull)
#           (n CharOctalPart)
#           (n CharUnicode)
#           (n CharUnescaped))
#
# CharOctalFull = (x (t \)
#                    (.. 0 2)
#                    (.. 0 7)
#                    (.. 0 7))
#
# CharOctalPart = (x (t \)
#                    (.. 0 7)
#                    (? (.. 0 7)))
#
# CharSpecial = (x (t \)
#                  (/ (t n)
#                     (t r)
#                     (t t)
#                     (t ')
#                     (t \")
#                     (t [)
#                     (t ])
#                     (t \)))
#
# CharUnescaped = (x (! (t \))
#                    (dot))
#
# CharUnicode = (x (t \)
#                  (t u)
#                  (n HexDigit)
#                  (? (x (n HexDigit)
#                        (? (x (n HexDigit)
#                              (? (n HexDigit)))))))
#
# Class = (x (n OPENB)
#            (* (x (! (n CLOSEB))
#                  (n Range)))
#            (n CLOSEB)
#            (n SPACE))
#
# CLOSE = (x (t \))
#            (n SPACE))
#
# CLOSEB = (t ])
#
# COLON = (x (t :)
#            (n SPACE))
#
# COMMENT = (x (t #)
#              (* (x (! (n EOL))
#                    (dot)))
#              (n EOL))
#
# DAPOSTROPH = (t \")
#
# Definition = (x (? (n Attribute))
#                 (n Identifier)
#                 (n IS)
#                 (n Expression)
#                 (n SEMICOLON))
#
# DOT = (x (t .)
#          (n SPACE))
#
# END = (x (t E)
#          (t N)
#          (t D)
#          (n SPACE))
#
# EOF = (! (dot))
#
# EOL = (/ (x (t \n)
#             (t \r))
#          (t \n)
#          (t \r))
#
# Expression = (x (n Sequence)
#                 (* (x (n SLASH)
#                       (n Sequence))))
#
# Final = (x (n END)
#            (n SEMICOLON)
#            (n SPACE))
#
# Grammar = (x (n SPACE)
#              (n Header)
#              (+ (n Definition))
#              (n Final)
#              (n EOF))
#
# Header = (x (n PEG)
#             (n Identifier)
#             (n StartExpr))
#
# HexDigit = (/ (.. 0 9)
#               (.. a f)
#               (.. A F))
#
# Ident = (x (/ (t _)
#               (t :)
#               (alpha))
#            (* (/ (t _)
#                  (t :)
#                  (alnum))))
#
# Identifier = (x (n Ident)
#                 (n SPACE))
#
# IS = (x (t <)
#         (t -)
#         (n SPACE))
#
# LEAF = (x (t l)
#           (t e)
#           (t a)
#           (t f)
#           (n SPACE))
#
# Literal = (/ (x (n APOSTROPH)
#                 (* (x (! (n APOSTROPH))
#                       (n Char)))
#                 (n APOSTROPH)
#                 (n SPACE))
#              (x (n DAPOSTROPH)
#                 (* (x (! (n DAPOSTROPH))
#                       (n Char)))
#                 (n DAPOSTROPH)
#                 (n SPACE)))
#
# MATCH = (x (t m)
#            (t a)
#            (t t)
#            (t c)
#            (t h)
#            (n SPACE))
#
# NOT = (x (t !)
#          (n SPACE))
#
# OPEN = (x (t \()
#           (n SPACE))
#
# OPENB = (t [)
#
# PEG = (x (t P)
#          (t E)
#          (t G)
#          (n SPACE))
#
# PLUS = (x (t +)
#           (n SPACE))
#
# Prefix = (x (? (/ (n AND)
#                   (n NOT)))
#             (n Suffix))
#
# Primary = (/ (n ALNUM)
#              (n ALPHA)
#              (n Identifier)
#              (x (n OPEN)
#                 (n Expression)
#                 (n CLOSE))
#              (n Literal)
#              (n Class)
#              (n DOT))
#
# QUESTION = (x (t ?)
#               (n SPACE))
#
# Range = (/ (x (n Char)
#               (n TO)
#               (n Char))
#            (n Char))
#
# SEMICOLON = (x (t ;)
#                (n SPACE))
#
# Sequence = (+ (n Prefix))
#
# SLASH = (x (t /)
#            (n SPACE))
#
# SPACE = (* (/ (t <blank>)
#               (t \t)
#               (n EOL)
#               (n COMMENT)))
#
# STAR = (x (t *)
#           (n SPACE))
#
# StartExpr = (x (n OPEN)
#                (n Expression)
#                (n CLOSE))
#
# Suffix = (x (n Primary)
#             (? (/ (n QUESTION)
#                   (n STAR)
#                   (n PLUS))))
#
# TO = (t -)
#
# VOID = (x (t v)
#           (t o)
#           (t i)
#           (t d)
#           (n SPACE))
#

proc ::page::parse::peg::matchSymbol_ALNUM {} {
    # ALNUM = (x (t <)
    #            (t a)
    #            (t l)
    #            (t n)
    #            (t u)
    #            (t m)
    #            (t >)
    #            (n SPACE))

    variable ok
    if {[inc_restore ALNUM]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq75                ; # (x (t <)
                            #    (t a)
                            #    (t l)
                            #    (t n)
                            #    (t u)
                            #    (t m)
                            #    (t >)
                            #    (n SPACE))

    isv_nonterminal_leaf   ALNUM $pos
    inc_save               ALNUM $pos
    if {$ok} ias_push
    ier_nonterminal        "Expected ALNUM" $pos
    return
}

proc ::page::parse::peg::eseq75 {} {

    # (x (t <)
    #    (t a)
    #    (t l)
    #    (t n)
    #    (t u)
    #    (t m)
    #    (t >)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected < (got EOF)"
    if {$ok} {ict_match_token < "Expected <"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected a (got EOF)"
    if {$ok} {ict_match_token a "Expected a"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected l (got EOF)"
    if {$ok} {ict_match_token l "Expected l"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected n (got EOF)"
    if {$ok} {ict_match_token n "Expected n"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected u (got EOF)"
    if {$ok} {ict_match_token u "Expected u"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected m (got EOF)"
    if {$ok} {ict_match_token m "Expected m"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected > (got EOF)"
    if {$ok} {ict_match_token > "Expected >"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_ALPHA {} {
    # ALPHA = (x (t <)
    #            (t a)
    #            (t l)
    #            (t p)
    #            (t h)
    #            (t a)
    #            (t >)
    #            (n SPACE))

    variable ok
    if {[inc_restore ALPHA]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq74                ; # (x (t <)
                            #    (t a)
                            #    (t l)
                            #    (t p)
                            #    (t h)
                            #    (t a)
                            #    (t >)
                            #    (n SPACE))

    isv_nonterminal_leaf   ALPHA $pos
    inc_save               ALPHA $pos
    if {$ok} ias_push
    ier_nonterminal        "Expected ALPHA" $pos
    return
}

proc ::page::parse::peg::eseq74 {} {

    # (x (t <)
    #    (t a)
    #    (t l)
    #    (t p)
    #    (t h)
    #    (t a)
    #    (t >)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected < (got EOF)"
    if {$ok} {ict_match_token < "Expected <"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected a (got EOF)"
    if {$ok} {ict_match_token a "Expected a"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected l (got EOF)"
    if {$ok} {ict_match_token l "Expected l"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected p (got EOF)"
    if {$ok} {ict_match_token p "Expected p"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected h (got EOF)"
    if {$ok} {ict_match_token h "Expected h"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected a (got EOF)"
    if {$ok} {ict_match_token a "Expected a"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected > (got EOF)"
    if {$ok} {ict_match_token > "Expected >"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_AND {} {
    # AND = (x (t &)
    #          (n SPACE))

    variable ok
    if {[inc_restore AND]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq66                ; # (x (t &)
                            #    (n SPACE))

    isv_nonterminal_leaf   AND $pos
    inc_save               AND $pos
    if {$ok} ias_push
    ier_nonterminal        "Expected AND" $pos
    return
}

proc ::page::parse::peg::eseq66 {} {

    # (x (t &)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected & (got EOF)"
    if {$ok} {ict_match_token & "Expected &"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_APOSTROPH {} {
    # APOSTROPH = (t ')

    variable ok
    if {[inc_restore APOSTROPH]} return

    set pos [icl_get]

    ict_advance "Expected ' (got EOF)"
    if {$ok} {ict_match_token ' "Expected '"}

    isv_clear
    inc_save               APOSTROPH $pos
    ier_nonterminal        "Expected APOSTROPH" $pos
    return
}

proc ::page::parse::peg::matchSymbol_Attribute {} {
    # Attribute = (x (/ (n VOID)
    #                   (n LEAF)
    #                   (n MATCH))
    #                (n COLON))

    variable ok
    if {[inc_restore Attribute]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq7                ; # (x (/ (n VOID)
                           #       (n LEAF)
                           #       (n MATCH))
                           #    (n COLON))

    isv_nonterminal_reduce Attribute $pos $mrk
    inc_save               Attribute $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        "Expected Attribute" $pos
    return
}

proc ::page::parse::peg::eseq7 {} {

    # (x (/ (n VOID)
    #       (n LEAF)
    #       (n MATCH))
    #    (n COLON))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]

    set old [ier_get]
    ebra6                ; # (/ (n VOID)
                           #    (n LEAF)
                           #    (n MATCH))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_COLON    ; # (n COLON)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::ebra6 {} {

    # (/ (n VOID)
    #    (n LEAF)
    #    (n MATCH))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_VOID    ; # (n VOID)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_LEAF    ; # (n LEAF)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_MATCH    ; # (n MATCH)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    return
}

proc ::page::parse::peg::matchSymbol_Char {} {
    # Char = (/ (n CharSpecial)
    #           (n CharOctalFull)
    #           (n CharOctalPart)
    #           (n CharUnicode)
    #           (n CharUnescaped))

    variable ok
    if {[inc_restore Char]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    ebra42                ; # (/ (n CharSpecial)
                            #    (n CharOctalFull)
                            #    (n CharOctalPart)
                            #    (n CharUnicode)
                            #    (n CharUnescaped))

    isv_nonterminal_reduce Char $pos $mrk
    inc_save               Char $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        "Expected Char" $pos
    return
}

proc ::page::parse::peg::ebra42 {} {

    # (/ (n CharSpecial)
    #    (n CharOctalFull)
    #    (n CharOctalPart)
    #    (n CharUnicode)
    #    (n CharUnescaped))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_CharSpecial    ; # (n CharSpecial)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_CharOctalFull    ; # (n CharOctalFull)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_CharOctalPart    ; # (n CharOctalPart)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_CharUnicode    ; # (n CharUnicode)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_CharUnescaped    ; # (n CharUnescaped)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    return
}

proc ::page::parse::peg::matchSymbol_CharOctalFull {} {
    # CharOctalFull = (x (t \)
    #                    (.. 0 2)
    #                    (.. 0 7)
    #                    (.. 0 7))

    variable ok
    if {[inc_restore CharOctalFull]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq45                ; # (x (t \)
                            #    (.. 0 2)
                            #    (.. 0 7)
                            #    (.. 0 7))

    isv_nonterminal_range  CharOctalFull $pos
    inc_save               CharOctalFull $pos
    if {$ok} ias_push
    ier_nonterminal        "Expected CharOctalFull" $pos
    return
}

proc ::page::parse::peg::eseq45 {} {

    # (x (t \)
    #    (.. 0 2)
    #    (.. 0 7)
    #    (.. 0 7))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected \\ (got EOF)"
    if {$ok} {ict_match_token \134 "Expected \\"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected \[0..2\] (got EOF)"
    if {$ok} {ict_match_tokrange 0 2 "Expected \[0..2\]"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected \[0..7\] (got EOF)"
    if {$ok} {ict_match_tokrange 0 7 "Expected \[0..7\]"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected \[0..7\] (got EOF)"
    if {$ok} {ict_match_tokrange 0 7 "Expected \[0..7\]"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_CharOctalPart {} {
    # CharOctalPart = (x (t \)
    #                    (.. 0 7)
    #                    (? (.. 0 7)))

    variable ok
    if {[inc_restore CharOctalPart]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq47                ; # (x (t \)
                            #    (.. 0 7)
                            #    (? (.. 0 7)))

    isv_nonterminal_range  CharOctalPart $pos
    inc_save               CharOctalPart $pos
    if {$ok} ias_push
    ier_nonterminal        "Expected CharOctalPart" $pos
    return
}

proc ::page::parse::peg::eseq47 {} {

    # (x (t \)
    #    (.. 0 7)
    #    (? (.. 0 7)))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected \\ (got EOF)"
    if {$ok} {ict_match_token \134 "Expected \\"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected \[0..7\] (got EOF)"
    if {$ok} {ict_match_tokrange 0 7 "Expected \[0..7\]"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    eopt46                ; # (? (.. 0 7))
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::eopt46 {} {

    # (? (.. 0 7))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected \[0..7\] (got EOF)"
    if {$ok} {ict_match_tokrange 0 7 "Expected \[0..7\]"}
    ier_merge $old

    if {$ok} return
    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::peg::matchSymbol_CharSpecial {} {
    # CharSpecial = (x (t \)
    #                  (/ (t n)
    #                     (t r)
    #                     (t t)
    #                     (t ')
    #                     (t \")
    #                     (t [)
    #                     (t ])
    #                     (t \)))

    variable ok
    if {[inc_restore CharSpecial]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq44                ; # (x (t \)
                            #    (/ (t n)
                            #       (t r)
                            #       (t t)
                            #       (t ')
                            #       (t \")
                            #       (t [)
                            #       (t ])
                            #       (t \)))

    isv_nonterminal_range  CharSpecial $pos
    inc_save               CharSpecial $pos
    if {$ok} ias_push
    ier_nonterminal        "Expected CharSpecial" $pos
    return
}

proc ::page::parse::peg::eseq44 {} {

    # (x (t \)
    #    (/ (t n)
    #       (t r)
    #       (t t)
    #       (t ')
    #       (t \")
    #       (t [)
    #       (t ])
    #       (t \)))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected \\ (got EOF)"
    if {$ok} {ict_match_token \134 "Expected \\"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ebra43                ; # (/ (t n)
                            #    (t r)
                            #    (t t)
                            #    (t ')
                            #    (t \")
                            #    (t [)
                            #    (t ])
                            #    (t \))
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::ebra43 {} {

    # (/ (t n)
    #    (t r)
    #    (t t)
    #    (t ')
    #    (t \")
    #    (t [)
    #    (t ])
    #    (t \))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected n (got EOF)"
    if {$ok} {ict_match_token n "Expected n"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance "Expected r (got EOF)"
    if {$ok} {ict_match_token r "Expected r"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance "Expected t (got EOF)"
    if {$ok} {ict_match_token t "Expected t"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance "Expected ' (got EOF)"
    if {$ok} {ict_match_token ' "Expected '"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance "Expected \" (got EOF)"
    if {$ok} {ict_match_token \42 "Expected \""}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance "Expected \[ (got EOF)"
    if {$ok} {ict_match_token \133 "Expected \["}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance "Expected \] (got EOF)"
    if {$ok} {ict_match_token \135 "Expected \]"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance "Expected \\ (got EOF)"
    if {$ok} {ict_match_token \134 "Expected \\"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    return
}

proc ::page::parse::peg::matchSymbol_CharUnescaped {} {
    # CharUnescaped = (x (! (t \))
    #                    (dot))

    variable ok
    if {[inc_restore CharUnescaped]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq55                ; # (x (! (t \))
                            #    (dot))

    isv_nonterminal_range  CharUnescaped $pos
    inc_save               CharUnescaped $pos
    if {$ok} ias_push
    ier_nonterminal        "Expected CharUnescaped" $pos
    return
}

proc ::page::parse::peg::eseq55 {} {

    # (x (! (t \))
    #    (dot))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ebang54
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected any character (got EOF)"
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::ebang54 {} {
    variable ok

    set pos [icl_get]

    ict_advance "Expected \\ (got EOF)"
    if {$ok} {ict_match_token \134 "Expected \\"}

    icl_rewind $pos
    iok_negate
    return
}

proc ::page::parse::peg::matchSymbol_CharUnicode {} {
    # CharUnicode = (x (t \)
    #                  (t u)
    #                  (n HexDigit)
    #                  (? (x (n HexDigit)
    #                        (? (x (n HexDigit)
    #                              (? (n HexDigit)))))))

    variable ok
    if {[inc_restore CharUnicode]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq53                ; # (x (t \)
                            #    (t u)
                            #    (n HexDigit)
                            #    (? (x (n HexDigit)
                            #          (? (x (n HexDigit)
                            #                (? (n HexDigit)))))))

    isv_nonterminal_range  CharUnicode $pos
    inc_save               CharUnicode $pos
    if {$ok} ias_push
    ier_nonterminal        "Expected CharUnicode" $pos
    return
}

proc ::page::parse::peg::eseq53 {} {

    # (x (t \)
    #    (t u)
    #    (n HexDigit)
    #    (? (x (n HexDigit)
    #          (? (x (n HexDigit)
    #                (? (n HexDigit)))))))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected \\ (got EOF)"
    if {$ok} {ict_match_token \134 "Expected \\"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected u (got EOF)"
    if {$ok} {ict_match_token u "Expected u"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_HexDigit    ; # (n HexDigit)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    eopt52                ; # (? (x (n HexDigit)
                            #       (? (x (n HexDigit)
                            #             (? (n HexDigit))))))
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::eopt52 {} {

    # (? (x (n HexDigit)
    #       (? (x (n HexDigit)
    #             (? (n HexDigit))))))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    eseq51                ; # (x (n HexDigit)
                            #    (? (x (n HexDigit)
                            #          (? (n HexDigit)))))
    ier_merge $old

    if {$ok} return
    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::peg::eseq51 {} {

    # (x (n HexDigit)
    #    (? (x (n HexDigit)
    #          (? (n HexDigit)))))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_HexDigit    ; # (n HexDigit)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    eopt50                ; # (? (x (n HexDigit)
                            #       (? (n HexDigit))))
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::eopt50 {} {

    # (? (x (n HexDigit)
    #       (? (n HexDigit))))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    eseq49                ; # (x (n HexDigit)
                            #    (? (n HexDigit)))
    ier_merge $old

    if {$ok} return
    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::peg::eseq49 {} {

    # (x (n HexDigit)
    #    (? (n HexDigit)))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_HexDigit    ; # (n HexDigit)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    eopt48                ; # (? (n HexDigit))
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::eopt48 {} {

    # (? (n HexDigit))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_HexDigit    ; # (n HexDigit)
    ier_merge $old

    if {$ok} return
    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::peg::matchSymbol_Class {} {
    # Class = (x (n OPENB)
    #            (* (x (! (n CLOSEB))
    #                  (n Range)))
    #            (n CLOSEB)
    #            (n SPACE))

    variable ok
    if {[inc_restore Class]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq32                ; # (x (n OPENB)
                            #    (* (x (! (n CLOSEB))
                            #          (n Range)))
                            #    (n CLOSEB)
                            #    (n SPACE))

    isv_nonterminal_reduce Class $pos $mrk
    inc_save               Class $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        "Expected Class" $pos
    return
}

proc ::page::parse::peg::eseq32 {} {

    # (x (n OPENB)
    #    (* (x (! (n CLOSEB))
    #          (n Range)))
    #    (n CLOSEB)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_OPENB    ; # (n OPENB)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    ekleene31                ; # (* (x (! (n CLOSEB))
                               #       (n Range)))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_CLOSEB    ; # (n CLOSEB)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::ekleene31 {} {

    # (* (x (! (n CLOSEB))
    #       (n Range)))

    variable ok

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        eseq30                ; # (x (! (n CLOSEB))
                                #    (n Range))
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::peg::eseq30 {} {

    # (x (! (n CLOSEB))
    #    (n Range))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ebang29
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Range    ; # (n Range)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::ebang29 {} {
    set pos [icl_get]

    matchSymbol_CLOSEB    ; # (n CLOSEB)

    icl_rewind $pos
    iok_negate
    return
}

proc ::page::parse::peg::matchSymbol_CLOSE {} {
    # CLOSE = (x (t \))
    #            (n SPACE))

    if {[inc_restore CLOSE]} return

    set pos [icl_get]

    eseq72                ; # (x (t \))
                            #    (n SPACE))

    isv_clear
    inc_save               CLOSE $pos
    ier_nonterminal        "Expected CLOSE" $pos
    return
}

proc ::page::parse::peg::eseq72 {} {

    # (x (t \))
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected \) (got EOF)"
    if {$ok} {ict_match_token \51 "Expected \)"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_CLOSEB {} {
    # CLOSEB = (t ])

    variable ok
    if {[inc_restore CLOSEB]} return

    set pos [icl_get]

    ict_advance "Expected \] (got EOF)"
    if {$ok} {ict_match_token \135 "Expected \]"}

    isv_clear
    inc_save               CLOSEB $pos
    ier_nonterminal        "Expected CLOSEB" $pos
    return
}

proc ::page::parse::peg::matchSymbol_COLON {} {
    # COLON = (x (t :)
    #            (n SPACE))

    if {[inc_restore COLON]} return

    set pos [icl_get]

    eseq64                ; # (x (t :)
                            #    (n SPACE))

    isv_clear
    inc_save               COLON $pos
    ier_nonterminal        "Expected COLON" $pos
    return
}

proc ::page::parse::peg::eseq64 {} {

    # (x (t :)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected : (got EOF)"
    if {$ok} {ict_match_token : "Expected :"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_COMMENT {} {
    # COMMENT = (x (t #)
    #              (* (x (! (n EOL))
    #                    (dot)))
    #              (n EOL))

    if {[inc_restore COMMENT]} return

    set pos [icl_get]

    eseq81                ; # (x (t #)
                            #    (* (x (! (n EOL))
                            #          (dot)))
                            #    (n EOL))

    isv_clear
    inc_save               COMMENT $pos
    ier_nonterminal        "Expected COMMENT" $pos
    return
}

proc ::page::parse::peg::eseq81 {} {

    # (x (t #)
    #    (* (x (! (n EOL))
    #          (dot)))
    #    (n EOL))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected # (got EOF)"
    if {$ok} {ict_match_token # "Expected #"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ekleene80                ; # (* (x (! (n EOL))
                               #       (dot)))
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_EOL    ; # (n EOL)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::ekleene80 {} {

    # (* (x (! (n EOL))
    #       (dot)))

    variable ok

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        eseq79                ; # (x (! (n EOL))
                                #    (dot))
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::peg::eseq79 {} {

    # (x (! (n EOL))
    #    (dot))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ebang78
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected any character (got EOF)"
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::ebang78 {} {
    set pos [icl_get]

    matchSymbol_EOL    ; # (n EOL)

    icl_rewind $pos
    iok_negate
    return
}

proc ::page::parse::peg::matchSymbol_DAPOSTROPH {} {
    # DAPOSTROPH = (t \")

    variable ok
    if {[inc_restore DAPOSTROPH]} return

    set pos [icl_get]

    ict_advance "Expected \" (got EOF)"
    if {$ok} {ict_match_token \42 "Expected \""}

    isv_clear
    inc_save               DAPOSTROPH $pos
    ier_nonterminal        "Expected DAPOSTROPH" $pos
    return
}

proc ::page::parse::peg::matchSymbol_Definition {} {
    # Definition = (x (? (n Attribute))
    #                 (n Identifier)
    #                 (n IS)
    #                 (n Expression)
    #                 (n SEMICOLON))

    variable ok
    if {[inc_restore Definition]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq5                ; # (x (? (n Attribute))
                           #    (n Identifier)
                           #    (n IS)
                           #    (n Expression)
                           #    (n SEMICOLON))

    isv_nonterminal_reduce Definition $pos $mrk
    inc_save               Definition $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        "Expected Definition" $pos
    return
}

proc ::page::parse::peg::eseq5 {} {

    # (x (? (n Attribute))
    #    (n Identifier)
    #    (n IS)
    #    (n Expression)
    #    (n SEMICOLON))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]

    set old [ier_get]
    eopt4                ; # (? (n Attribute))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_Identifier    ; # (n Identifier)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_IS    ; # (n IS)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_Expression    ; # (n Expression)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_SEMICOLON    ; # (n SEMICOLON)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::eopt4 {} {

    # (? (n Attribute))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_Attribute    ; # (n Attribute)
    ier_merge $old

    if {$ok} return
    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::peg::matchSymbol_DOT {} {
    # DOT = (x (t .)
    #          (n SPACE))

    variable ok
    if {[inc_restore DOT]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq73                ; # (x (t .)
                            #    (n SPACE))

    isv_nonterminal_leaf   DOT $pos
    inc_save               DOT $pos
    if {$ok} ias_push
    ier_nonterminal        "Expected DOT" $pos
    return
}

proc ::page::parse::peg::eseq73 {} {

    # (x (t .)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected . (got EOF)"
    if {$ok} {ict_match_token . "Expected ."}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_END {} {
    # END = (x (t E)
    #          (t N)
    #          (t D)
    #          (n SPACE))

    if {[inc_restore END]} return

    set pos [icl_get]

    eseq62                ; # (x (t E)
                            #    (t N)
                            #    (t D)
                            #    (n SPACE))

    isv_clear
    inc_save               END $pos
    ier_nonterminal        "Expected END" $pos
    return
}

proc ::page::parse::peg::eseq62 {} {

    # (x (t E)
    #    (t N)
    #    (t D)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected E (got EOF)"
    if {$ok} {ict_match_token E "Expected E"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected N (got EOF)"
    if {$ok} {ict_match_token N "Expected N"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected D (got EOF)"
    if {$ok} {ict_match_token D "Expected D"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_EOF {} {
    # EOF = (! (dot))

    if {[inc_restore EOF]} return

    set pos [icl_get]

    ebang84

    isv_clear
    inc_save               EOF $pos
    ier_nonterminal        "Expected EOF" $pos
    return
}

proc ::page::parse::peg::ebang84 {} {
    set pos [icl_get]

    ict_advance "Expected any character (got EOF)"

    icl_rewind $pos
    iok_negate
    return
}

proc ::page::parse::peg::matchSymbol_EOL {} {
    # EOL = (/ (x (t \n)
    #             (t \r))
    #          (t \n)
    #          (t \r))

    if {[inc_restore EOL]} return

    set pos [icl_get]

    ebra83                ; # (/ (x (t \n)
                            #       (t \r))
                            #    (t \n)
                            #    (t \r))

    isv_clear
    inc_save               EOL $pos
    ier_nonterminal        "Expected EOL" $pos
    return
}

proc ::page::parse::peg::ebra83 {} {

    # (/ (x (t \n)
    #       (t \r))
    #    (t \n)
    #    (t \r))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    eseq82                ; # (x (t \n)
                            #    (t \r))
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance "Expected \\n (got EOF)"
    if {$ok} {ict_match_token \n "Expected \\n"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance "Expected \\r (got EOF)"
    if {$ok} {ict_match_token \r "Expected \\r"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    return
}

proc ::page::parse::peg::eseq82 {} {

    # (x (t \n)
    #    (t \r))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected \\n (got EOF)"
    if {$ok} {ict_match_token \n "Expected \\n"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected \\r (got EOF)"
    if {$ok} {ict_match_token \r "Expected \\r"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_Expression {} {
    # Expression = (x (n Sequence)
    #                 (* (x (n SLASH)
    #                       (n Sequence))))

    variable ok
    if {[inc_restore Expression]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq10                ; # (x (n Sequence)
                            #    (* (x (n SLASH)
                            #          (n Sequence))))

    isv_nonterminal_reduce Expression $pos $mrk
    inc_save               Expression $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        "Expected Expression" $pos
    return
}

proc ::page::parse::peg::eseq10 {} {

    # (x (n Sequence)
    #    (* (x (n SLASH)
    #          (n Sequence))))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Sequence    ; # (n Sequence)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    ekleene9                ; # (* (x (n SLASH)
                              #       (n Sequence)))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::ekleene9 {} {

    # (* (x (n SLASH)
    #       (n Sequence)))

    variable ok

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        eseq8                ; # (x (n SLASH)
                               #    (n Sequence))
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::peg::eseq8 {} {

    # (x (n SLASH)
    #    (n Sequence))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_SLASH    ; # (n SLASH)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Sequence    ; # (n Sequence)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::matchSymbol_Final {} {
    # Final = (x (n END)
    #            (n SEMICOLON)
    #            (n SPACE))

    if {[inc_restore Final]} return

    set pos [icl_get]

    eseq36                ; # (x (n END)
                            #    (n SEMICOLON)
                            #    (n SPACE))

    isv_clear
    inc_save               Final $pos
    ier_nonterminal        "Expected Final" $pos
    return
}

proc ::page::parse::peg::eseq36 {} {

    # (x (n END)
    #    (n SEMICOLON)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_END    ; # (n END)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SEMICOLON    ; # (n SEMICOLON)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_Grammar {} {
    # Grammar = (x (n SPACE)
    #              (n Header)
    #              (+ (n Definition))
    #              (n Final)
    #              (n EOF))

    variable ok
    if {[inc_restore Grammar]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq2                ; # (x (n SPACE)
                           #    (n Header)
                           #    (+ (n Definition))
                           #    (n Final)
                           #    (n EOF))

    isv_nonterminal_reduce Grammar $pos $mrk
    inc_save               Grammar $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        "Expected Grammar" $pos
    return
}

proc ::page::parse::peg::eseq2 {} {

    # (x (n SPACE)
    #    (n Header)
    #    (+ (n Definition))
    #    (n Final)
    #    (n EOF))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Header    ; # (n Header)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    epkleene1                ; # (+ (n Definition))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_Final    ; # (n Final)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_EOF    ; # (n EOF)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::epkleene1 {} {

    # (+ (n Definition))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_Definition    ; # (n Definition)
    ier_merge $old

    if {!$ok} {
        icl_rewind $pos
        return
    }

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        matchSymbol_Definition    ; # (n Definition)
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::peg::matchSymbol_Header {} {
    # Header = (x (n PEG)
    #             (n Identifier)
    #             (n StartExpr))

    variable ok
    if {[inc_restore Header]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq3                ; # (x (n PEG)
                           #    (n Identifier)
                           #    (n StartExpr))

    isv_nonterminal_reduce Header $pos $mrk
    inc_save               Header $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        "Expected Header" $pos
    return
}

proc ::page::parse::peg::eseq3 {} {

    # (x (n PEG)
    #    (n Identifier)
    #    (n StartExpr))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_PEG    ; # (n PEG)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Identifier    ; # (n Identifier)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_StartExpr    ; # (n StartExpr)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::matchSymbol_HexDigit {} {
    # HexDigit = (/ (.. 0 9)
    #               (.. a f)
    #               (.. A F))

    if {[inc_restore HexDigit]} return

    set pos [icl_get]

    ebra56                ; # (/ (.. 0 9)
                            #    (.. a f)
                            #    (.. A F))

    isv_clear
    inc_save               HexDigit $pos
    ier_nonterminal        "Expected HexDigit" $pos
    return
}

proc ::page::parse::peg::ebra56 {} {

    # (/ (.. 0 9)
    #    (.. a f)
    #    (.. A F))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected \[0..9\] (got EOF)"
    if {$ok} {ict_match_tokrange 0 9 "Expected \[0..9\]"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance "Expected \[a..f\] (got EOF)"
    if {$ok} {ict_match_tokrange a f "Expected \[a..f\]"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance "Expected \[A..F\] (got EOF)"
    if {$ok} {ict_match_tokrange A F "Expected \[A..F\]"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    return
}

proc ::page::parse::peg::matchSymbol_Ident {} {
    # Ident = (x (/ (t _)
    #               (t :)
    #               (alpha))
    #            (* (/ (t _)
    #                  (t :)
    #                  (alnum))))

    variable ok
    if {[inc_restore Ident]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq41                ; # (x (/ (t _)
                            #       (t :)
                            #       (alpha))
                            #    (* (/ (t _)
                            #          (t :)
                            #          (alnum))))

    isv_nonterminal_range  Ident $pos
    inc_save               Ident $pos
    if {$ok} ias_push
    ier_nonterminal        "Expected Ident" $pos
    return
}

proc ::page::parse::peg::eseq41 {} {

    # (x (/ (t _)
    #       (t :)
    #       (alpha))
    #    (* (/ (t _)
    #          (t :)
    #          (alnum))))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ebra38                ; # (/ (t _)
                            #    (t :)
                            #    (alpha))
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ekleene40                ; # (* (/ (t _)
                               #       (t :)
                               #       (alnum)))
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::ebra38 {} {

    # (/ (t _)
    #    (t :)
    #    (alpha))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected _ (got EOF)"
    if {$ok} {ict_match_token _ "Expected _"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance "Expected : (got EOF)"
    if {$ok} {ict_match_token : "Expected :"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance "Expected <alpha> (got EOF)"
    if {$ok} {ict_match_tokclass alpha "Expected <alpha>"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    return
}

proc ::page::parse::peg::ekleene40 {} {

    # (* (/ (t _)
    #       (t :)
    #       (alnum)))

    variable ok

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        ebra39                ; # (/ (t _)
                                #    (t :)
                                #    (alnum))
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::peg::ebra39 {} {

    # (/ (t _)
    #    (t :)
    #    (alnum))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected _ (got EOF)"
    if {$ok} {ict_match_token _ "Expected _"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance "Expected : (got EOF)"
    if {$ok} {ict_match_token : "Expected :"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance "Expected <alnum> (got EOF)"
    if {$ok} {ict_match_tokclass alnum "Expected <alnum>"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    return
}

proc ::page::parse::peg::matchSymbol_Identifier {} {
    # Identifier = (x (n Ident)
    #                 (n SPACE))

    variable ok
    if {[inc_restore Identifier]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq37                ; # (x (n Ident)
                            #    (n SPACE))

    isv_nonterminal_reduce Identifier $pos $mrk
    inc_save               Identifier $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        "Expected Identifier" $pos
    return
}

proc ::page::parse::peg::eseq37 {} {

    # (x (n Ident)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Ident    ; # (n Ident)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::matchSymbol_IS {} {
    # IS = (x (t <)
    #         (t -)
    #         (n SPACE))

    if {[inc_restore IS]} return

    set pos [icl_get]

    eseq58                ; # (x (t <)
                            #    (t -)
                            #    (n SPACE))

    isv_clear
    inc_save               IS $pos
    ier_nonterminal        "Expected IS" $pos
    return
}

proc ::page::parse::peg::eseq58 {} {

    # (x (t <)
    #    (t -)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected < (got EOF)"
    if {$ok} {ict_match_token < "Expected <"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected - (got EOF)"
    if {$ok} {ict_match_token - "Expected -"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_LEAF {} {
    # LEAF = (x (t l)
    #           (t e)
    #           (t a)
    #           (t f)
    #           (n SPACE))

    variable ok
    if {[inc_restore LEAF]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq60                ; # (x (t l)
                            #    (t e)
                            #    (t a)
                            #    (t f)
                            #    (n SPACE))

    isv_nonterminal_leaf   LEAF $pos
    inc_save               LEAF $pos
    if {$ok} ias_push
    ier_nonterminal        "Expected LEAF" $pos
    return
}

proc ::page::parse::peg::eseq60 {} {

    # (x (t l)
    #    (t e)
    #    (t a)
    #    (t f)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected l (got EOF)"
    if {$ok} {ict_match_token l "Expected l"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected e (got EOF)"
    if {$ok} {ict_match_token e "Expected e"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected a (got EOF)"
    if {$ok} {ict_match_token a "Expected a"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected f (got EOF)"
    if {$ok} {ict_match_token f "Expected f"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_Literal {} {
    # Literal = (/ (x (n APOSTROPH)
    #                 (* (x (! (n APOSTROPH))
    #                       (n Char)))
    #                 (n APOSTROPH)
    #                 (n SPACE))
    #              (x (n DAPOSTROPH)
    #                 (* (x (! (n DAPOSTROPH))
    #                       (n Char)))
    #                 (n DAPOSTROPH)
    #                 (n SPACE)))

    variable ok
    if {[inc_restore Literal]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    ebra28                ; # (/ (x (n APOSTROPH)
                            #       (* (x (! (n APOSTROPH))
                            #             (n Char)))
                            #       (n APOSTROPH)
                            #       (n SPACE))
                            #    (x (n DAPOSTROPH)
                            #       (* (x (! (n DAPOSTROPH))
                            #             (n Char)))
                            #       (n DAPOSTROPH)
                            #       (n SPACE)))

    isv_nonterminal_reduce Literal $pos $mrk
    inc_save               Literal $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        "Expected Literal" $pos
    return
}

proc ::page::parse::peg::ebra28 {} {

    # (/ (x (n APOSTROPH)
    #       (* (x (! (n APOSTROPH))
    #             (n Char)))
    #       (n APOSTROPH)
    #       (n SPACE))
    #    (x (n DAPOSTROPH)
    #       (* (x (! (n DAPOSTROPH))
    #             (n Char)))
    #       (n DAPOSTROPH)
    #       (n SPACE)))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]
    set old [ier_get]
    eseq23                ; # (x (n APOSTROPH)
                            #    (* (x (! (n APOSTROPH))
                            #          (n Char)))
                            #    (n APOSTROPH)
                            #    (n SPACE))
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    eseq27                ; # (x (n DAPOSTROPH)
                            #    (* (x (! (n DAPOSTROPH))
                            #          (n Char)))
                            #    (n DAPOSTROPH)
                            #    (n SPACE))
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    return
}

proc ::page::parse::peg::eseq23 {} {

    # (x (n APOSTROPH)
    #    (* (x (! (n APOSTROPH))
    #          (n Char)))
    #    (n APOSTROPH)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_APOSTROPH    ; # (n APOSTROPH)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    ekleene22                ; # (* (x (! (n APOSTROPH))
                               #       (n Char)))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_APOSTROPH    ; # (n APOSTROPH)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::ekleene22 {} {

    # (* (x (! (n APOSTROPH))
    #       (n Char)))

    variable ok

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        eseq21                ; # (x (! (n APOSTROPH))
                                #    (n Char))
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::peg::eseq21 {} {

    # (x (! (n APOSTROPH))
    #    (n Char))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ebang20
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Char    ; # (n Char)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::ebang20 {} {
    set pos [icl_get]

    matchSymbol_APOSTROPH    ; # (n APOSTROPH)

    icl_rewind $pos
    iok_negate
    return
}

proc ::page::parse::peg::eseq27 {} {

    # (x (n DAPOSTROPH)
    #    (* (x (! (n DAPOSTROPH))
    #          (n Char)))
    #    (n DAPOSTROPH)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DAPOSTROPH    ; # (n DAPOSTROPH)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    ekleene26                ; # (* (x (! (n DAPOSTROPH))
                               #       (n Char)))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_DAPOSTROPH    ; # (n DAPOSTROPH)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::ekleene26 {} {

    # (* (x (! (n DAPOSTROPH))
    #       (n Char)))

    variable ok

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        eseq25                ; # (x (! (n DAPOSTROPH))
                                #    (n Char))
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::peg::eseq25 {} {

    # (x (! (n DAPOSTROPH))
    #    (n Char))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ebang24
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Char    ; # (n Char)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::ebang24 {} {
    set pos [icl_get]

    matchSymbol_DAPOSTROPH    ; # (n DAPOSTROPH)

    icl_rewind $pos
    iok_negate
    return
}

proc ::page::parse::peg::matchSymbol_MATCH {} {
    # MATCH = (x (t m)
    #            (t a)
    #            (t t)
    #            (t c)
    #            (t h)
    #            (n SPACE))

    variable ok
    if {[inc_restore MATCH]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq61                ; # (x (t m)
                            #    (t a)
                            #    (t t)
                            #    (t c)
                            #    (t h)
                            #    (n SPACE))

    isv_nonterminal_leaf   MATCH $pos
    inc_save               MATCH $pos
    if {$ok} ias_push
    ier_nonterminal        "Expected MATCH" $pos
    return
}

proc ::page::parse::peg::eseq61 {} {

    # (x (t m)
    #    (t a)
    #    (t t)
    #    (t c)
    #    (t h)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected m (got EOF)"
    if {$ok} {ict_match_token m "Expected m"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected a (got EOF)"
    if {$ok} {ict_match_token a "Expected a"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected t (got EOF)"
    if {$ok} {ict_match_token t "Expected t"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected c (got EOF)"
    if {$ok} {ict_match_token c "Expected c"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected h (got EOF)"
    if {$ok} {ict_match_token h "Expected h"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_NOT {} {
    # NOT = (x (t !)
    #          (n SPACE))

    variable ok
    if {[inc_restore NOT]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq67                ; # (x (t !)
                            #    (n SPACE))

    isv_nonterminal_leaf   NOT $pos
    inc_save               NOT $pos
    if {$ok} ias_push
    ier_nonterminal        "Expected NOT" $pos
    return
}

proc ::page::parse::peg::eseq67 {} {

    # (x (t !)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected ! (got EOF)"
    if {$ok} {ict_match_token ! "Expected !"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_OPEN {} {
    # OPEN = (x (t \()
    #           (n SPACE))

    if {[inc_restore OPEN]} return

    set pos [icl_get]

    eseq71                ; # (x (t \()
                            #    (n SPACE))

    isv_clear
    inc_save               OPEN $pos
    ier_nonterminal        "Expected OPEN" $pos
    return
}

proc ::page::parse::peg::eseq71 {} {

    # (x (t \()
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected \( (got EOF)"
    if {$ok} {ict_match_token \50 "Expected \("}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_OPENB {} {
    # OPENB = (t [)

    variable ok
    if {[inc_restore OPENB]} return

    set pos [icl_get]

    ict_advance "Expected \[ (got EOF)"
    if {$ok} {ict_match_token \133 "Expected \["}

    isv_clear
    inc_save               OPENB $pos
    ier_nonterminal        "Expected OPENB" $pos
    return
}

proc ::page::parse::peg::matchSymbol_PEG {} {
    # PEG = (x (t P)
    #          (t E)
    #          (t G)
    #          (n SPACE))

    if {[inc_restore PEG]} return

    set pos [icl_get]

    eseq57                ; # (x (t P)
                            #    (t E)
                            #    (t G)
                            #    (n SPACE))

    isv_clear
    inc_save               PEG $pos
    ier_nonterminal        "Expected PEG" $pos
    return
}

proc ::page::parse::peg::eseq57 {} {

    # (x (t P)
    #    (t E)
    #    (t G)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected P (got EOF)"
    if {$ok} {ict_match_token P "Expected P"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected E (got EOF)"
    if {$ok} {ict_match_token E "Expected E"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected G (got EOF)"
    if {$ok} {ict_match_token G "Expected G"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_PLUS {} {
    # PLUS = (x (t +)
    #           (n SPACE))

    variable ok
    if {[inc_restore PLUS]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq70                ; # (x (t +)
                            #    (n SPACE))

    isv_nonterminal_leaf   PLUS $pos
    inc_save               PLUS $pos
    if {$ok} ias_push
    ier_nonterminal        "Expected PLUS" $pos
    return
}

proc ::page::parse::peg::eseq70 {} {

    # (x (t +)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected + (got EOF)"
    if {$ok} {ict_match_token + "Expected +"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_Prefix {} {
    # Prefix = (x (? (/ (n AND)
    #                   (n NOT)))
    #             (n Suffix))

    variable ok
    if {[inc_restore Prefix]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq14                ; # (x (? (/ (n AND)
                            #          (n NOT)))
                            #    (n Suffix))

    isv_nonterminal_reduce Prefix $pos $mrk
    inc_save               Prefix $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        "Expected Prefix" $pos
    return
}

proc ::page::parse::peg::eseq14 {} {

    # (x (? (/ (n AND)
    #          (n NOT)))
    #    (n Suffix))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]

    set old [ier_get]
    eopt13                ; # (? (/ (n AND)
                            #       (n NOT)))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_Suffix    ; # (n Suffix)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::eopt13 {} {

    # (? (/ (n AND)
    #       (n NOT)))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ebra12                ; # (/ (n AND)
                            #    (n NOT))
    ier_merge $old

    if {$ok} return
    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::peg::ebra12 {} {

    # (/ (n AND)
    #    (n NOT))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_AND    ; # (n AND)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_NOT    ; # (n NOT)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    return
}

proc ::page::parse::peg::matchSymbol_Primary {} {
    # Primary = (/ (n ALNUM)
    #              (n ALPHA)
    #              (n Identifier)
    #              (x (n OPEN)
    #                 (n Expression)
    #                 (n CLOSE))
    #              (n Literal)
    #              (n Class)
    #              (n DOT))

    variable ok
    if {[inc_restore Primary]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    ebra19                ; # (/ (n ALNUM)
                            #    (n ALPHA)
                            #    (n Identifier)
                            #    (x (n OPEN)
                            #       (n Expression)
                            #       (n CLOSE))
                            #    (n Literal)
                            #    (n Class)
                            #    (n DOT))

    isv_nonterminal_reduce Primary $pos $mrk
    inc_save               Primary $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        "Expected Primary" $pos
    return
}

proc ::page::parse::peg::ebra19 {} {

    # (/ (n ALNUM)
    #    (n ALPHA)
    #    (n Identifier)
    #    (x (n OPEN)
    #       (n Expression)
    #       (n CLOSE))
    #    (n Literal)
    #    (n Class)
    #    (n DOT))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_ALNUM    ; # (n ALNUM)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_ALPHA    ; # (n ALPHA)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_Identifier    ; # (n Identifier)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    eseq18                ; # (x (n OPEN)
                            #    (n Expression)
                            #    (n CLOSE))
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_Literal    ; # (n Literal)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_Class    ; # (n Class)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_DOT    ; # (n DOT)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    return
}

proc ::page::parse::peg::eseq18 {} {

    # (x (n OPEN)
    #    (n Expression)
    #    (n CLOSE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_OPEN    ; # (n OPEN)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Expression    ; # (n Expression)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_CLOSE    ; # (n CLOSE)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::matchSymbol_QUESTION {} {
    # QUESTION = (x (t ?)
    #               (n SPACE))

    variable ok
    if {[inc_restore QUESTION]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq68                ; # (x (t ?)
                            #    (n SPACE))

    isv_nonterminal_leaf   QUESTION $pos
    inc_save               QUESTION $pos
    if {$ok} ias_push
    ier_nonterminal        "Expected QUESTION" $pos
    return
}

proc ::page::parse::peg::eseq68 {} {

    # (x (t ?)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected ? (got EOF)"
    if {$ok} {ict_match_token ? "Expected ?"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_Range {} {
    # Range = (/ (x (n Char)
    #               (n TO)
    #               (n Char))
    #            (n Char))

    variable ok
    if {[inc_restore Range]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    ebra34                ; # (/ (x (n Char)
                            #       (n TO)
                            #       (n Char))
                            #    (n Char))

    isv_nonterminal_reduce Range $pos $mrk
    inc_save               Range $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        "Expected Range" $pos
    return
}

proc ::page::parse::peg::ebra34 {} {

    # (/ (x (n Char)
    #       (n TO)
    #       (n Char))
    #    (n Char))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]
    set old [ier_get]
    eseq33                ; # (x (n Char)
                            #    (n TO)
                            #    (n Char))
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_Char    ; # (n Char)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    return
}

proc ::page::parse::peg::eseq33 {} {

    # (x (n Char)
    #    (n TO)
    #    (n Char))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Char    ; # (n Char)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_TO    ; # (n TO)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_Char    ; # (n Char)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::matchSymbol_SEMICOLON {} {
    # SEMICOLON = (x (t ;)
    #                (n SPACE))

    if {[inc_restore SEMICOLON]} return

    set pos [icl_get]

    eseq63                ; # (x (t ;)
                            #    (n SPACE))

    isv_clear
    inc_save               SEMICOLON $pos
    ier_nonterminal        "Expected SEMICOLON" $pos
    return
}

proc ::page::parse::peg::eseq63 {} {

    # (x (t ;)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected \; (got EOF)"
    if {$ok} {ict_match_token \73 "Expected \;"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_Sequence {} {
    # Sequence = (+ (n Prefix))

    variable ok
    if {[inc_restore Sequence]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    epkleene11                ; # (+ (n Prefix))

    isv_nonterminal_reduce Sequence $pos $mrk
    inc_save               Sequence $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        "Expected Sequence" $pos
    return
}

proc ::page::parse::peg::epkleene11 {} {

    # (+ (n Prefix))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_Prefix    ; # (n Prefix)
    ier_merge $old

    if {!$ok} {
        icl_rewind $pos
        return
    }

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        matchSymbol_Prefix    ; # (n Prefix)
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::peg::matchSymbol_SLASH {} {
    # SLASH = (x (t /)
    #            (n SPACE))

    if {[inc_restore SLASH]} return

    set pos [icl_get]

    eseq65                ; # (x (t /)
                            #    (n SPACE))

    isv_clear
    inc_save               SLASH $pos
    ier_nonterminal        "Expected SLASH" $pos
    return
}

proc ::page::parse::peg::eseq65 {} {

    # (x (t /)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected / (got EOF)"
    if {$ok} {ict_match_token / "Expected /"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_SPACE {} {
    # SPACE = (* (/ (t <blank>)
    #               (t \t)
    #               (n EOL)
    #               (n COMMENT)))

    if {[inc_restore SPACE]} return

    set pos [icl_get]

    ekleene77                ; # (* (/ (t <blank>)
                               #       (t \t)
                               #       (n EOL)
                               #       (n COMMENT)))

    isv_clear
    inc_save               SPACE $pos
    ier_nonterminal        "Expected SPACE" $pos
    return
}

proc ::page::parse::peg::ekleene77 {} {

    # (* (/ (t <blank>)
    #       (t \t)
    #       (n EOL)
    #       (n COMMENT)))

    variable ok

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        ebra76                ; # (/ (t <blank>)
                                #    (t \t)
                                #    (n EOL)
                                #    (n COMMENT))
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::peg::ebra76 {} {

    # (/ (t <blank>)
    #    (t \t)
    #    (n EOL)
    #    (n COMMENT))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected <blank> (got EOF)"
    if {$ok} {ict_match_token \40 "Expected <blank>"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance "Expected \\t (got EOF)"
    if {$ok} {ict_match_token \t "Expected \\t"}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    matchSymbol_EOL    ; # (n EOL)
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    matchSymbol_COMMENT    ; # (n COMMENT)
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    return
}

proc ::page::parse::peg::matchSymbol_STAR {} {
    # STAR = (x (t *)
    #           (n SPACE))

    variable ok
    if {[inc_restore STAR]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq69                ; # (x (t *)
                            #    (n SPACE))

    isv_nonterminal_leaf   STAR $pos
    inc_save               STAR $pos
    if {$ok} ias_push
    ier_nonterminal        "Expected STAR" $pos
    return
}

proc ::page::parse::peg::eseq69 {} {

    # (x (t *)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected * (got EOF)"
    if {$ok} {ict_match_token * "Expected *"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::peg::matchSymbol_StartExpr {} {
    # StartExpr = (x (n OPEN)
    #                (n Expression)
    #                (n CLOSE))

    variable ok
    if {[inc_restore StartExpr]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq35                ; # (x (n OPEN)
                            #    (n Expression)
                            #    (n CLOSE))

    isv_nonterminal_reduce StartExpr $pos $mrk
    inc_save               StartExpr $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        "Expected StartExpr" $pos
    return
}

proc ::page::parse::peg::eseq35 {} {

    # (x (n OPEN)
    #    (n Expression)
    #    (n CLOSE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_OPEN    ; # (n OPEN)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Expression    ; # (n Expression)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_CLOSE    ; # (n CLOSE)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::matchSymbol_Suffix {} {
    # Suffix = (x (n Primary)
    #             (? (/ (n QUESTION)
    #                   (n STAR)
    #                   (n PLUS))))

    variable ok
    if {[inc_restore Suffix]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq17                ; # (x (n Primary)
                            #    (? (/ (n QUESTION)
                            #          (n STAR)
                            #          (n PLUS))))

    isv_nonterminal_reduce Suffix $pos $mrk
    inc_save               Suffix $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        "Expected Suffix" $pos
    return
}

proc ::page::parse::peg::eseq17 {} {

    # (x (n Primary)
    #    (? (/ (n QUESTION)
    #          (n STAR)
    #          (n PLUS))))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Primary    ; # (n Primary)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    eopt16                ; # (? (/ (n QUESTION)
                            #       (n STAR)
                            #       (n PLUS)))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::peg::eopt16 {} {

    # (? (/ (n QUESTION)
    #       (n STAR)
    #       (n PLUS)))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ebra15                ; # (/ (n QUESTION)
                            #    (n STAR)
                            #    (n PLUS))
    ier_merge $old

    if {$ok} return
    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::peg::ebra15 {} {

    # (/ (n QUESTION)
    #    (n STAR)
    #    (n PLUS))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_QUESTION    ; # (n QUESTION)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_STAR    ; # (n STAR)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_PLUS    ; # (n PLUS)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    return
}

proc ::page::parse::peg::matchSymbol_TO {} {
    # TO = (t -)

    variable ok
    if {[inc_restore TO]} return

    set pos [icl_get]

    ict_advance "Expected - (got EOF)"
    if {$ok} {ict_match_token - "Expected -"}

    isv_clear
    inc_save               TO $pos
    ier_nonterminal        "Expected TO" $pos
    return
}

proc ::page::parse::peg::matchSymbol_VOID {} {
    # VOID = (x (t v)
    #           (t o)
    #           (t i)
    #           (t d)
    #           (n SPACE))

    variable ok
    if {[inc_restore VOID]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq59                ; # (x (t v)
                            #    (t o)
                            #    (t i)
                            #    (t d)
                            #    (n SPACE))

    isv_nonterminal_leaf   VOID $pos
    inc_save               VOID $pos
    if {$ok} ias_push
    ier_nonterminal        "Expected VOID" $pos
    return
}

proc ::page::parse::peg::eseq59 {} {

    # (x (t v)
    #    (t o)
    #    (t i)
    #    (t d)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "Expected v (got EOF)"
    if {$ok} {ict_match_token v "Expected v"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected o (got EOF)"
    if {$ok} {ict_match_token o "Expected o"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected i (got EOF)"
    if {$ok} {ict_match_token i "Expected i"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "Expected d (got EOF)"
    if {$ok} {ict_match_token d "Expected d"}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

# ### ### ### ######### ######### #########
## Package Management

package provide page::parse::peg 0.1
