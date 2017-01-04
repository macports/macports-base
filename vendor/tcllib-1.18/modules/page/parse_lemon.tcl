# -*- tcl -*-
## Parsing Expression Grammar 'page::parse::lemon'.
## RD parser by the PG backend 'MEwriter'.

# ### ### ### ######### ######### #########
## Package description

# The commands provided here match an input provided through a buffer
# command to the PE grammar 'page::parse::lemon'. The parser is based on the package
# 'grammar::mengine' (recursive-descent, packrat, pulling chars,
# pushing the generated AST).

# ### ### ### ######### ######### #########
## Requisites

package require grammar::me::tcl

# ### ### ### ######### ######### #########
## Implementation

namespace eval ::page::parse::lemon {
    # Import the virtual machine for matching.

    namespace import ::grammar::me::tcl::*
    upvar #0 ::grammar::me::tcl::ok ok
}

# ### ### ### ######### ######### #########
## API Implementation.

proc ::page::parse::lemon::parse {nxcmd emvar astvar} {
    variable ok
    variable se

    upvar 1 $emvar emsg $astvar ast

    init $nxcmd

    matchSymbol_LemonGrammar    ; # (n LemonGrammar)

    isv_nonterminal_reduce ALL -1
    set ast [sv]
    if {!$ok} {
        foreach {l m} [ier_get] break
        lappend l [lc $l]
	set mx {}
	foreach x $m {lappend mx "Expected $x"}
        set emsg [list $l $mx]
    }

    return $ok
}

# ### ### ### ######### ######### #########
## Internal helper methods

# Grammar 'page::parse::lemon'
#
# ASSIGN = (x (t :)
#             (t :)
#             (t =)
#             (n SPACE))
#
# C_COMMENT = (x (n CCOM_OPEN)
#                (* (x (! (n CCOM_CLOSE))
#                      (dot)))
#                (n CCOM_CLOSE))
#
# CCOM_CLOSE = (x (t *)
#                 (t /))
#
# CCOM_OPEN = (x (t /)
#                (t *))
#
# Code = (x (n DCODE)
#           (n Codeblock))
#
# Codeblock = (x (n LBRACE)
#                (* (/ (n Codeblock)
#                      (n C_COMMENT)
#                      (n Cplusplus_COMMENT)
#                      (x (! (n RBRACE))
#                         (dot))))
#                (n RBRACE))
#
# Cplusplus_COMMENT = (x (t /)
#                        (t /)
#                        (* (x (! (n EOL))
#                              (dot)))
#                        (n EOL))
#
# DCODE = (x (t c)
#            (t o)
#            (t d)
#            (t e)
#            (n SPACE))
#
# DDEFDEST = (x (t d)
#               (t e)
#               (t f)
#               (t a)
#               (t u)
#               (t l)
#               (t t)
#               (t _)
#               (t d)
#               (t e)
#               (t s)
#               (t t)
#               (t r)
#               (t u)
#               (t c)
#               (t t)
#               (t o)
#               (t r)
#               (n SPACE))
#
# DDEFTYPE = (x (t d)
#               (t e)
#               (t f)
#               (t a)
#               (t u)
#               (t l)
#               (t t)
#               (t _)
#               (t t)
#               (t y)
#               (t p)
#               (t e)
#               (n SPACE))
#
# DDEST = (x (t d)
#            (t e)
#            (t s)
#            (t t)
#            (t r)
#            (t u)
#            (t c)
#            (t t)
#            (t o)
#            (t r)
#            (n SPACE))
#
# DefaultDestructor = (x (n DDEFDEST)
#                        (n Identifier)
#                        (n Codeblock))
#
# DefaultType = (x (n DDEFTYPE)
#                  (n Codeblock))
#
# Definition = (* (x (n Identifier)
#                    (? (n Label))))
#
# DENDIF = (x (t %)
#             (t e)
#             (t n)
#             (t d)
#             (t i)
#             (t f)
#             (n SPACE))
#
# Destructor = (x (n DDEST)
#                 (n Identifier)
#                 (n Codeblock))
#
# DEXTRA = (x (t e)
#             (t x)
#             (t t)
#             (t r)
#             (t a)
#             (t _)
#             (t a)
#             (t r)
#             (t g)
#             (t u)
#             (t m)
#             (t e)
#             (t n)
#             (t t)
#             (n SPACE))
#
# DFALLBK = (x (t f)
#              (t a)
#              (t l)
#              (t l)
#              (t b)
#              (t a)
#              (t c)
#              (t k)
#              (n SPACE))
#
# DIFDEF = (x (t %)
#             (t i)
#             (t f)
#             (t d)
#             (t e)
#             (t f)
#             (n SPACE))
#
# DIFNDEF = (x (t %)
#              (t i)
#              (t f)
#              (t n)
#              (t d)
#              (t e)
#              (t f)
#              (n SPACE))
#
# DINCL = (x (t i)
#            (t n)
#            (t c)
#            (t l)
#            (t u)
#            (t d)
#            (t e)
#            (n SPACE))
#
# DINTRO = (t %)
#
# Directive = (x (n DINTRO)
#                (/ (n Code)
#                   (n DefaultDestructor)
#                   (n DefaultType)
#                   (n Destructor)
#                   (n ExtraArgument)
#                   (n Include)
#                   (n Left)
#                   (n Name)
#                   (n Nonassoc)
#                   (n ParseAccept)
#                   (n ParseFailure)
#                   (n Right)
#                   (n StackOverflow)
#                   (n Stacksize)
#                   (n StartSymbol)
#                   (n SyntaxError)
#                   (n TokenDestructor)
#                   (n TokenPrefix)
#                   (n TokenType)
#                   (n Type)
#                   (n Fallback)))
#
# DLEFT = (x (t l)
#            (t e)
#            (t f)
#            (t t)
#            (n SPACE))
#
# DNAME = (x (t n)
#            (t a)
#            (t m)
#            (t e)
#            (n SPACE))
#
# DNON = (x (t n)
#           (t o)
#           (t n)
#           (t a)
#           (t s)
#           (t s)
#           (t o)
#           (t c)
#           (n SPACE))
#
# DOT = (x (t .)
#          (n SPACE))
#
# DPACC = (x (t p)
#            (t a)
#            (t r)
#            (t s)
#            (t e)
#            (t _)
#            (t a)
#            (t c)
#            (t c)
#            (t e)
#            (t p)
#            (t t)
#            (n SPACE))
#
# DPFAIL = (x (t p)
#             (t a)
#             (t r)
#             (t s)
#             (t e)
#             (t _)
#             (t f)
#             (t a)
#             (t i)
#             (t l)
#             (t u)
#             (t r)
#             (t e)
#             (n SPACE))
#
# DRIGHT = (x (t r)
#             (t i)
#             (t g)
#             (t h)
#             (t t)
#             (n SPACE))
#
# DSTART = (x (t s)
#             (t t)
#             (t a)
#             (t r)
#             (t t)
#             (t _)
#             (t s)
#             (t y)
#             (t m)
#             (t b)
#             (t o)
#             (t l)
#             (n SPACE))
#
# DSTKOVER = (x (t s)
#               (t t)
#               (t a)
#               (t c)
#               (t k)
#               (t _)
#               (t o)
#               (t v)
#               (t e)
#               (t r)
#               (t f)
#               (t l)
#               (t o)
#               (t w)
#               (n SPACE))
#
# DSTKSZ = (x (t s)
#             (t t)
#             (t a)
#             (t c)
#             (t k)
#             (t _)
#             (t s)
#             (t i)
#             (t z)
#             (t e)
#             (n SPACE))
#
# DSYNERR = (x (t s)
#              (t y)
#              (t n)
#              (t t)
#              (t a)
#              (t x)
#              (t _)
#              (t e)
#              (t r)
#              (t r)
#              (t o)
#              (t r)
#              (n SPACE))
#
# DTOKDEST = (x (t t)
#               (t o)
#               (t k)
#               (t e)
#               (t n)
#               (t _)
#               (t d)
#               (t e)
#               (t s)
#               (t t)
#               (t r)
#               (t u)
#               (t c)
#               (t t)
#               (t o)
#               (t r)
#               (n SPACE))
#
# DTOKPFX = (x (t t)
#              (t o)
#              (t k)
#              (t e)
#              (t n)
#              (t _)
#              (t p)
#              (t r)
#              (t e)
#              (t f)
#              (t i)
#              (t x)
#              (n SPACE))
#
# DTOKTYPE = (x (t t)
#               (t o)
#               (t k)
#               (t e)
#               (t n)
#               (t _)
#               (t t)
#               (t y)
#               (t p)
#               (t e)
#               (n SPACE))
#
# DTYPE = (x (t t)
#            (t y)
#            (t p)
#            (t e)
#            (n SPACE))
#
# Endif = (n DENDIF)
#
# EOF = (! (dot))
#
# EOL = (/ (x (t \r)
#             (t \n))
#          (t \r)
#          (t \n))
#
# ExtraArgument = (x (n DEXTRA)
#                    (n Codeblock))
#
# Fallback = (x (n DFALLBK)
#               (+ (n Identifier))
#               (n DOT))
#
# Ident = (x (/ (alpha)
#               (t _))
#            (* (/ (alnum)
#                  (t _))))
#
# Identifier = (x (n Ident)
#                 (n SPACE))
#
# Ifdef = (x (n DIFDEF)
#            (n Identifier))
#
# Ifndef = (x (n DIFNDEF)
#             (n Identifier))
#
# Include = (x (n DINCL)
#              (n Codeblock))
#
# Label = (x (n LPAREN)
#            (n Identifier)
#            (n RPAREN))
#
# LBRACE = (t \{)
#
# LBRACKET = (x (t [)
#               (n SPACE))
#
# Left = (x (n DLEFT)
#           (+ (n Identifier))
#           (n DOT))
#
# LemonGrammar = (x (n SPACE)
#                   (+ (n Statement))
#                   (n EOF))
#
# LPAREN = (x (t \()
#             (n SPACE))
#
# Name = (x (n DNAME)
#           (n Identifier))
#
# NatNum = (+ (.. 0 9))
#
# NaturalNumber = (x (n NatNum)
#                    (n SPACE))
#
# Nonassoc = (x (n DNON)
#               (+ (n Identifier))
#               (n DOT))
#
# ParseAccept = (x (n DPACC)
#                  (n Codeblock))
#
# ParseFailure = (x (n DPFAIL)
#                   (n Codeblock))
#
# Precedence = (x (n LBRACKET)
#                 (n Identifier)
#                 (n RBRACKET))
#
# RBRACE = (t \})
#
# RBRACKET = (x (t ])
#               (n SPACE))
#
# Right = (x (n DRIGHT)
#            (+ (n Identifier))
#            (n DOT))
#
# RPAREN = (x (t \))
#             (n SPACE))
#
# Rule = (x (n Identifier)
#           (? (n Label))
#           (n ASSIGN)
#           (n Definition)
#           (n DOT)
#           (? (n Precedence))
#           (? (n Codeblock)))
#
# SPACE = (* (/ (t <blank>)
#               (t \t)
#               (t \n)
#               (t \r)
#               (n C_COMMENT)
#               (n Cplusplus_COMMENT)
#               (n Ifndef)
#               (n Ifdef)
#               (n Endif)))
#
# StackOverflow = (x (n DSTKOVER)
#                    (n Codeblock))
#
# Stacksize = (x (n DSTKSZ)
#                (n NaturalNumber))
#
# StartSymbol = (x (n DSTART)
#                  (n Identifier))
#
# Statement = (x (/ (n Directive)
#                   (n Rule))
#                (n SPACE))
#
# SyntaxError = (x (n DSYNERR)
#                  (n Codeblock))
#
# TokenDestructor = (x (n DTOKDEST)
#                      (n Identifier)
#                      (n Codeblock))
#
# TokenPrefix = (x (n DTOKPFX)
#                  (n Identifier))
#
# TokenType = (x (n DTOKTYPE)
#                (n Codeblock))
#
# Type = (x (n DTYPE)
#           (n Identifier)
#           (n Codeblock))
#

proc ::page::parse::lemon::matchSymbol_ASSIGN {} {
    # ASSIGN = (x (t :)
    #             (t :)
    #             (t =)
    #             (n SPACE))

    if {[inc_restore ASSIGN]} return

    set pos [icl_get]

    eseq53                ; # (x (t :)
                            #    (t :)
                            #    (t =)
                            #    (n SPACE))

    isv_clear
    inc_save               ASSIGN $pos
    ier_nonterminal        ASSIGN $pos
    return
}

proc ::page::parse::lemon::eseq53 {} {

    # (x (t :)
    #    (t :)
    #    (t =)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance :
    if {$ok} {ict_match_token :}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance :
    if {$ok} {ict_match_token :}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance =
    if {$ok} {ict_match_token =}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_C_COMMENT {} {
    # C_COMMENT = (x (n CCOM_OPEN)
    #                (* (x (! (n CCOM_CLOSE))
    #                      (dot)))
    #                (n CCOM_CLOSE))

    if {[inc_restore C_COMMENT]} return

    set pos [icl_get]

    eseq90                ; # (x (n CCOM_OPEN)
                            #    (* (x (! (n CCOM_CLOSE))
                            #          (dot)))
                            #    (n CCOM_CLOSE))

    isv_clear
    inc_save               C_COMMENT $pos
    ier_nonterminal        C_COMMENT $pos
    return
}

proc ::page::parse::lemon::eseq90 {} {

    # (x (n CCOM_OPEN)
    #    (* (x (! (n CCOM_CLOSE))
    #          (dot)))
    #    (n CCOM_CLOSE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_CCOM_OPEN    ; # (n CCOM_OPEN)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ekleene89                ; # (* (x (! (n CCOM_CLOSE))
                               #       (dot)))
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_CCOM_CLOSE    ; # (n CCOM_CLOSE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::ekleene89 {} {

    # (* (x (! (n CCOM_CLOSE))
    #       (dot)))

    variable ok

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        eseq88                ; # (x (! (n CCOM_CLOSE))
                                #    (dot))
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::lemon::eseq88 {} {

    # (x (! (n CCOM_CLOSE))
    #    (dot))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ebang87
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "any character"
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::ebang87 {} {
    set pos [icl_get]

    matchSymbol_CCOM_CLOSE    ; # (n CCOM_CLOSE)

    icl_rewind $pos
    iok_negate
    return
}

proc ::page::parse::lemon::matchSymbol_CCOM_CLOSE {} {
    # CCOM_CLOSE = (x (t *)
    #                 (t /))

    if {[inc_restore CCOM_CLOSE]} return

    set pos [icl_get]

    eseq92                ; # (x (t *)
                            #    (t /))

    isv_clear
    inc_save               CCOM_CLOSE $pos
    ier_nonterminal        CCOM_CLOSE $pos
    return
}

proc ::page::parse::lemon::eseq92 {} {

    # (x (t *)
    #    (t /))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance *
    if {$ok} {ict_match_token *}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance /
    if {$ok} {ict_match_token /}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_CCOM_OPEN {} {
    # CCOM_OPEN = (x (t /)
    #                (t *))

    if {[inc_restore CCOM_OPEN]} return

    set pos [icl_get]

    eseq91                ; # (x (t /)
                            #    (t *))

    isv_clear
    inc_save               CCOM_OPEN $pos
    ier_nonterminal        CCOM_OPEN $pos
    return
}

proc ::page::parse::lemon::eseq91 {} {

    # (x (t /)
    #    (t *))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance /
    if {$ok} {ict_match_token /}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance *
    if {$ok} {ict_match_token *}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_Code {} {
    # Code = (x (n DCODE)
    #           (n Codeblock))

    variable ok
    if {[inc_restore Code]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq16                ; # (x (n DCODE)
                            #    (n Codeblock))

    isv_nonterminal_reduce Code $pos $mrk
    inc_save               Code $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        Code $pos
    return
}

proc ::page::parse::lemon::eseq16 {} {

    # (x (n DCODE)
    #    (n Codeblock))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DCODE    ; # (n DCODE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Codeblock    ; # (n Codeblock)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::matchSymbol_Codeblock {} {
    # Codeblock = (x (n LBRACE)
    #                (* (/ (n Codeblock)
    #                      (n C_COMMENT)
    #                      (n Cplusplus_COMMENT)
    #                      (x (! (n RBRACE))
    #                         (dot))))
    #                (n RBRACE))

    variable ok
    if {[inc_restore Codeblock]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq45                ; # (x (n LBRACE)
                            #    (* (/ (n Codeblock)
                            #          (n C_COMMENT)
                            #          (n Cplusplus_COMMENT)
                            #          (x (! (n RBRACE))
                            #             (dot))))
                            #    (n RBRACE))

    isv_nonterminal_range  Codeblock $pos
    inc_save               Codeblock $pos
    if {$ok} ias_push
    ier_nonterminal        Codeblock $pos
    return
}

proc ::page::parse::lemon::eseq45 {} {

    # (x (n LBRACE)
    #    (* (/ (n Codeblock)
    #          (n C_COMMENT)
    #          (n Cplusplus_COMMENT)
    #          (x (! (n RBRACE))
    #             (dot))))
    #    (n RBRACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_LBRACE    ; # (n LBRACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ekleene44                ; # (* (/ (n Codeblock)
                               #       (n C_COMMENT)
                               #       (n Cplusplus_COMMENT)
                               #       (x (! (n RBRACE))
                               #          (dot))))
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_RBRACE    ; # (n RBRACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::ekleene44 {} {

    # (* (/ (n Codeblock)
    #       (n C_COMMENT)
    #       (n Cplusplus_COMMENT)
    #       (x (! (n RBRACE))
    #          (dot))))

    variable ok

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        ebra43                ; # (/ (n Codeblock)
                                #    (n C_COMMENT)
                                #    (n Cplusplus_COMMENT)
                                #    (x (! (n RBRACE))
                                #       (dot)))
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::lemon::ebra43 {} {

    # (/ (n Codeblock)
    #    (n C_COMMENT)
    #    (n Cplusplus_COMMENT)
    #    (x (! (n RBRACE))
    #       (dot)))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    set pCodeblock [ias_mark]
    matchSymbol_Codeblock
    ias_pop2mark $pCodeblock    ; # (n Codeblock)
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    matchSymbol_C_COMMENT    ; # (n C_COMMENT)
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    matchSymbol_Cplusplus_COMMENT    ; # (n Cplusplus_COMMENT)
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    eseq42                ; # (x (! (n RBRACE))
                            #    (dot))
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    return
}

proc ::page::parse::lemon::eseq42 {} {

    # (x (! (n RBRACE))
    #    (dot))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ebang41
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "any character"
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::ebang41 {} {
    set pos [icl_get]

    matchSymbol_RBRACE    ; # (n RBRACE)

    icl_rewind $pos
    iok_negate
    return
}

proc ::page::parse::lemon::matchSymbol_Cplusplus_COMMENT {} {
    # Cplusplus_COMMENT = (x (t /)
    #                        (t /)
    #                        (* (x (! (n EOL))
    #                              (dot)))
    #                        (n EOL))

    if {[inc_restore Cplusplus_COMMENT]} return

    set pos [icl_get]

    eseq96                ; # (x (t /)
                            #    (t /)
                            #    (* (x (! (n EOL))
                            #          (dot)))
                            #    (n EOL))

    isv_clear
    inc_save               Cplusplus_COMMENT $pos
    ier_nonterminal        Cplusplus_COMMENT $pos
    return
}

proc ::page::parse::lemon::eseq96 {} {

    # (x (t /)
    #    (t /)
    #    (* (x (! (n EOL))
    #          (dot)))
    #    (n EOL))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance /
    if {$ok} {ict_match_token /}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance /
    if {$ok} {ict_match_token /}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ekleene95                ; # (* (x (! (n EOL))
                               #       (dot)))
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_EOL    ; # (n EOL)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::ekleene95 {} {

    # (* (x (! (n EOL))
    #       (dot)))

    variable ok

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        eseq94                ; # (x (! (n EOL))
                                #    (dot))
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::lemon::eseq94 {} {

    # (x (! (n EOL))
    #    (dot))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ebang93
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance "any character"
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::ebang93 {} {
    set pos [icl_get]

    matchSymbol_EOL    ; # (n EOL)

    icl_rewind $pos
    iok_negate
    return
}

proc ::page::parse::lemon::matchSymbol_DCODE {} {
    # DCODE = (x (t c)
    #            (t o)
    #            (t d)
    #            (t e)
    #            (n SPACE))

    if {[inc_restore DCODE]} return

    set pos [icl_get]

    eseq59                ; # (x (t c)
                            #    (t o)
                            #    (t d)
                            #    (t e)
                            #    (n SPACE))

    isv_clear
    inc_save               DCODE $pos
    ier_nonterminal        DCODE $pos
    return
}

proc ::page::parse::lemon::eseq59 {} {

    # (x (t c)
    #    (t o)
    #    (t d)
    #    (t e)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance c
    if {$ok} {ict_match_token c}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance o
    if {$ok} {ict_match_token o}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance d
    if {$ok} {ict_match_token d}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DDEFDEST {} {
    # DDEFDEST = (x (t d)
    #               (t e)
    #               (t f)
    #               (t a)
    #               (t u)
    #               (t l)
    #               (t t)
    #               (t _)
    #               (t d)
    #               (t e)
    #               (t s)
    #               (t t)
    #               (t r)
    #               (t u)
    #               (t c)
    #               (t t)
    #               (t o)
    #               (t r)
    #               (n SPACE))

    if {[inc_restore DDEFDEST]} return

    set pos [icl_get]

    eseq60                ; # (x (t d)
                            #    (t e)
                            #    (t f)
                            #    (t a)
                            #    (t u)
                            #    (t l)
                            #    (t t)
                            #    (t _)
                            #    (t d)
                            #    (t e)
                            #    (t s)
                            #    (t t)
                            #    (t r)
                            #    (t u)
                            #    (t c)
                            #    (t t)
                            #    (t o)
                            #    (t r)
                            #    (n SPACE))

    isv_clear
    inc_save               DDEFDEST $pos
    ier_nonterminal        DDEFDEST $pos
    return
}

proc ::page::parse::lemon::eseq60 {} {

    # (x (t d)
    #    (t e)
    #    (t f)
    #    (t a)
    #    (t u)
    #    (t l)
    #    (t t)
    #    (t _)
    #    (t d)
    #    (t e)
    #    (t s)
    #    (t t)
    #    (t r)
    #    (t u)
    #    (t c)
    #    (t t)
    #    (t o)
    #    (t r)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance d
    if {$ok} {ict_match_token d}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance f
    if {$ok} {ict_match_token f}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance a
    if {$ok} {ict_match_token a}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance u
    if {$ok} {ict_match_token u}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance l
    if {$ok} {ict_match_token l}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance _
    if {$ok} {ict_match_token _}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance d
    if {$ok} {ict_match_token d}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance s
    if {$ok} {ict_match_token s}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance u
    if {$ok} {ict_match_token u}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance c
    if {$ok} {ict_match_token c}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance o
    if {$ok} {ict_match_token o}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DDEFTYPE {} {
    # DDEFTYPE = (x (t d)
    #               (t e)
    #               (t f)
    #               (t a)
    #               (t u)
    #               (t l)
    #               (t t)
    #               (t _)
    #               (t t)
    #               (t y)
    #               (t p)
    #               (t e)
    #               (n SPACE))

    if {[inc_restore DDEFTYPE]} return

    set pos [icl_get]

    eseq61                ; # (x (t d)
                            #    (t e)
                            #    (t f)
                            #    (t a)
                            #    (t u)
                            #    (t l)
                            #    (t t)
                            #    (t _)
                            #    (t t)
                            #    (t y)
                            #    (t p)
                            #    (t e)
                            #    (n SPACE))

    isv_clear
    inc_save               DDEFTYPE $pos
    ier_nonterminal        DDEFTYPE $pos
    return
}

proc ::page::parse::lemon::eseq61 {} {

    # (x (t d)
    #    (t e)
    #    (t f)
    #    (t a)
    #    (t u)
    #    (t l)
    #    (t t)
    #    (t _)
    #    (t t)
    #    (t y)
    #    (t p)
    #    (t e)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance d
    if {$ok} {ict_match_token d}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance f
    if {$ok} {ict_match_token f}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance a
    if {$ok} {ict_match_token a}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance u
    if {$ok} {ict_match_token u}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance l
    if {$ok} {ict_match_token l}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance _
    if {$ok} {ict_match_token _}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance y
    if {$ok} {ict_match_token y}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance p
    if {$ok} {ict_match_token p}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DDEST {} {
    # DDEST = (x (t d)
    #            (t e)
    #            (t s)
    #            (t t)
    #            (t r)
    #            (t u)
    #            (t c)
    #            (t t)
    #            (t o)
    #            (t r)
    #            (n SPACE))

    if {[inc_restore DDEST]} return

    set pos [icl_get]

    eseq62                ; # (x (t d)
                            #    (t e)
                            #    (t s)
                            #    (t t)
                            #    (t r)
                            #    (t u)
                            #    (t c)
                            #    (t t)
                            #    (t o)
                            #    (t r)
                            #    (n SPACE))

    isv_clear
    inc_save               DDEST $pos
    ier_nonterminal        DDEST $pos
    return
}

proc ::page::parse::lemon::eseq62 {} {

    # (x (t d)
    #    (t e)
    #    (t s)
    #    (t t)
    #    (t r)
    #    (t u)
    #    (t c)
    #    (t t)
    #    (t o)
    #    (t r)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance d
    if {$ok} {ict_match_token d}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance s
    if {$ok} {ict_match_token s}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance u
    if {$ok} {ict_match_token u}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance c
    if {$ok} {ict_match_token c}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance o
    if {$ok} {ict_match_token o}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DefaultDestructor {} {
    # DefaultDestructor = (x (n DDEFDEST)
    #                        (n Identifier)
    #                        (n Codeblock))

    variable ok
    if {[inc_restore DefaultDestructor]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq17                ; # (x (n DDEFDEST)
                            #    (n Identifier)
                            #    (n Codeblock))

    isv_nonterminal_reduce DefaultDestructor $pos $mrk
    inc_save               DefaultDestructor $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        DefaultDestructor $pos
    return
}

proc ::page::parse::lemon::eseq17 {} {

    # (x (n DDEFDEST)
    #    (n Identifier)
    #    (n Codeblock))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DDEFDEST    ; # (n DDEFDEST)
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
    matchSymbol_Codeblock    ; # (n Codeblock)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::matchSymbol_DefaultType {} {
    # DefaultType = (x (n DDEFTYPE)
    #                  (n Codeblock))

    variable ok
    if {[inc_restore DefaultType]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq18                ; # (x (n DDEFTYPE)
                            #    (n Codeblock))

    isv_nonterminal_reduce DefaultType $pos $mrk
    inc_save               DefaultType $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        DefaultType $pos
    return
}

proc ::page::parse::lemon::eseq18 {} {

    # (x (n DDEFTYPE)
    #    (n Codeblock))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DDEFTYPE    ; # (n DDEFTYPE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Codeblock    ; # (n Codeblock)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::matchSymbol_Definition {} {
    # Definition = (* (x (n Identifier)
    #                    (? (n Label))))

    variable ok
    if {[inc_restore Definition]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    ekleene11                ; # (* (x (n Identifier)
                               #       (? (n Label))))

    isv_nonterminal_reduce Definition $pos $mrk
    inc_save               Definition $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        Definition $pos
    return
}

proc ::page::parse::lemon::ekleene11 {} {

    # (* (x (n Identifier)
    #       (? (n Label))))

    variable ok

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        eseq10                ; # (x (n Identifier)
                                #    (? (n Label)))
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::lemon::eseq10 {} {

    # (x (n Identifier)
    #    (? (n Label)))

    variable ok

    set pos [icl_get]

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
    eopt9                ; # (? (n Label))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::eopt9 {} {

    # (? (n Label))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_Label    ; # (n Label)
    ier_merge $old

    if {$ok} return
    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::lemon::matchSymbol_DENDIF {} {
    # DENDIF = (x (t %)
    #             (t e)
    #             (t n)
    #             (t d)
    #             (t i)
    #             (t f)
    #             (n SPACE))

    if {[inc_restore DENDIF]} return

    set pos [icl_get]

    eseq82                ; # (x (t %)
                            #    (t e)
                            #    (t n)
                            #    (t d)
                            #    (t i)
                            #    (t f)
                            #    (n SPACE))

    isv_clear
    inc_save               DENDIF $pos
    ier_nonterminal        DENDIF $pos
    return
}

proc ::page::parse::lemon::eseq82 {} {

    # (x (t %)
    #    (t e)
    #    (t n)
    #    (t d)
    #    (t i)
    #    (t f)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance %
    if {$ok} {ict_match_token %}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance n
    if {$ok} {ict_match_token n}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance d
    if {$ok} {ict_match_token d}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance i
    if {$ok} {ict_match_token i}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance f
    if {$ok} {ict_match_token f}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_Destructor {} {
    # Destructor = (x (n DDEST)
    #                 (n Identifier)
    #                 (n Codeblock))

    variable ok
    if {[inc_restore Destructor]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq19                ; # (x (n DDEST)
                            #    (n Identifier)
                            #    (n Codeblock))

    isv_nonterminal_reduce Destructor $pos $mrk
    inc_save               Destructor $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        Destructor $pos
    return
}

proc ::page::parse::lemon::eseq19 {} {

    # (x (n DDEST)
    #    (n Identifier)
    #    (n Codeblock))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DDEST    ; # (n DDEST)
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
    matchSymbol_Codeblock    ; # (n Codeblock)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::matchSymbol_DEXTRA {} {
    # DEXTRA = (x (t e)
    #             (t x)
    #             (t t)
    #             (t r)
    #             (t a)
    #             (t _)
    #             (t a)
    #             (t r)
    #             (t g)
    #             (t u)
    #             (t m)
    #             (t e)
    #             (t n)
    #             (t t)
    #             (n SPACE))

    if {[inc_restore DEXTRA]} return

    set pos [icl_get]

    eseq63                ; # (x (t e)
                            #    (t x)
                            #    (t t)
                            #    (t r)
                            #    (t a)
                            #    (t _)
                            #    (t a)
                            #    (t r)
                            #    (t g)
                            #    (t u)
                            #    (t m)
                            #    (t e)
                            #    (t n)
                            #    (t t)
                            #    (n SPACE))

    isv_clear
    inc_save               DEXTRA $pos
    ier_nonterminal        DEXTRA $pos
    return
}

proc ::page::parse::lemon::eseq63 {} {

    # (x (t e)
    #    (t x)
    #    (t t)
    #    (t r)
    #    (t a)
    #    (t _)
    #    (t a)
    #    (t r)
    #    (t g)
    #    (t u)
    #    (t m)
    #    (t e)
    #    (t n)
    #    (t t)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance x
    if {$ok} {ict_match_token x}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance a
    if {$ok} {ict_match_token a}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance _
    if {$ok} {ict_match_token _}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance a
    if {$ok} {ict_match_token a}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance g
    if {$ok} {ict_match_token g}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance u
    if {$ok} {ict_match_token u}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance m
    if {$ok} {ict_match_token m}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance n
    if {$ok} {ict_match_token n}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DFALLBK {} {
    # DFALLBK = (x (t f)
    #              (t a)
    #              (t l)
    #              (t l)
    #              (t b)
    #              (t a)
    #              (t c)
    #              (t k)
    #              (n SPACE))

    if {[inc_restore DFALLBK]} return

    set pos [icl_get]

    eseq79                ; # (x (t f)
                            #    (t a)
                            #    (t l)
                            #    (t l)
                            #    (t b)
                            #    (t a)
                            #    (t c)
                            #    (t k)
                            #    (n SPACE))

    isv_clear
    inc_save               DFALLBK $pos
    ier_nonterminal        DFALLBK $pos
    return
}

proc ::page::parse::lemon::eseq79 {} {

    # (x (t f)
    #    (t a)
    #    (t l)
    #    (t l)
    #    (t b)
    #    (t a)
    #    (t c)
    #    (t k)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance f
    if {$ok} {ict_match_token f}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance a
    if {$ok} {ict_match_token a}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance l
    if {$ok} {ict_match_token l}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance l
    if {$ok} {ict_match_token l}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance b
    if {$ok} {ict_match_token b}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance a
    if {$ok} {ict_match_token a}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance c
    if {$ok} {ict_match_token c}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance k
    if {$ok} {ict_match_token k}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DIFDEF {} {
    # DIFDEF = (x (t %)
    #             (t i)
    #             (t f)
    #             (t d)
    #             (t e)
    #             (t f)
    #             (n SPACE))

    if {[inc_restore DIFDEF]} return

    set pos [icl_get]

    eseq80                ; # (x (t %)
                            #    (t i)
                            #    (t f)
                            #    (t d)
                            #    (t e)
                            #    (t f)
                            #    (n SPACE))

    isv_clear
    inc_save               DIFDEF $pos
    ier_nonterminal        DIFDEF $pos
    return
}

proc ::page::parse::lemon::eseq80 {} {

    # (x (t %)
    #    (t i)
    #    (t f)
    #    (t d)
    #    (t e)
    #    (t f)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance %
    if {$ok} {ict_match_token %}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance i
    if {$ok} {ict_match_token i}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance f
    if {$ok} {ict_match_token f}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance d
    if {$ok} {ict_match_token d}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance f
    if {$ok} {ict_match_token f}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DIFNDEF {} {
    # DIFNDEF = (x (t %)
    #              (t i)
    #              (t f)
    #              (t n)
    #              (t d)
    #              (t e)
    #              (t f)
    #              (n SPACE))

    if {[inc_restore DIFNDEF]} return

    set pos [icl_get]

    eseq81                ; # (x (t %)
                            #    (t i)
                            #    (t f)
                            #    (t n)
                            #    (t d)
                            #    (t e)
                            #    (t f)
                            #    (n SPACE))

    isv_clear
    inc_save               DIFNDEF $pos
    ier_nonterminal        DIFNDEF $pos
    return
}

proc ::page::parse::lemon::eseq81 {} {

    # (x (t %)
    #    (t i)
    #    (t f)
    #    (t n)
    #    (t d)
    #    (t e)
    #    (t f)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance %
    if {$ok} {ict_match_token %}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance i
    if {$ok} {ict_match_token i}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance f
    if {$ok} {ict_match_token f}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance n
    if {$ok} {ict_match_token n}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance d
    if {$ok} {ict_match_token d}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance f
    if {$ok} {ict_match_token f}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DINCL {} {
    # DINCL = (x (t i)
    #            (t n)
    #            (t c)
    #            (t l)
    #            (t u)
    #            (t d)
    #            (t e)
    #            (n SPACE))

    if {[inc_restore DINCL]} return

    set pos [icl_get]

    eseq64                ; # (x (t i)
                            #    (t n)
                            #    (t c)
                            #    (t l)
                            #    (t u)
                            #    (t d)
                            #    (t e)
                            #    (n SPACE))

    isv_clear
    inc_save               DINCL $pos
    ier_nonterminal        DINCL $pos
    return
}

proc ::page::parse::lemon::eseq64 {} {

    # (x (t i)
    #    (t n)
    #    (t c)
    #    (t l)
    #    (t u)
    #    (t d)
    #    (t e)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance i
    if {$ok} {ict_match_token i}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance n
    if {$ok} {ict_match_token n}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance c
    if {$ok} {ict_match_token c}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance l
    if {$ok} {ict_match_token l}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance u
    if {$ok} {ict_match_token u}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance d
    if {$ok} {ict_match_token d}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DINTRO {} {
    # DINTRO = (t %)

    variable ok
    if {[inc_restore DINTRO]} return

    set pos [icl_get]

    ict_advance %
    if {$ok} {ict_match_token %}

    isv_clear
    inc_save               DINTRO $pos
    ier_nonterminal        DINTRO $pos
    return
}

proc ::page::parse::lemon::matchSymbol_Directive {} {
    # Directive = (x (n DINTRO)
    #                (/ (n Code)
    #                   (n DefaultDestructor)
    #                   (n DefaultType)
    #                   (n Destructor)
    #                   (n ExtraArgument)
    #                   (n Include)
    #                   (n Left)
    #                   (n Name)
    #                   (n Nonassoc)
    #                   (n ParseAccept)
    #                   (n ParseFailure)
    #                   (n Right)
    #                   (n StackOverflow)
    #                   (n Stacksize)
    #                   (n StartSymbol)
    #                   (n SyntaxError)
    #                   (n TokenDestructor)
    #                   (n TokenPrefix)
    #                   (n TokenType)
    #                   (n Type)
    #                   (n Fallback)))

    variable ok
    if {[inc_restore Directive]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq15                ; # (x (n DINTRO)
                            #    (/ (n Code)
                            #       (n DefaultDestructor)
                            #       (n DefaultType)
                            #       (n Destructor)
                            #       (n ExtraArgument)
                            #       (n Include)
                            #       (n Left)
                            #       (n Name)
                            #       (n Nonassoc)
                            #       (n ParseAccept)
                            #       (n ParseFailure)
                            #       (n Right)
                            #       (n StackOverflow)
                            #       (n Stacksize)
                            #       (n StartSymbol)
                            #       (n SyntaxError)
                            #       (n TokenDestructor)
                            #       (n TokenPrefix)
                            #       (n TokenType)
                            #       (n Type)
                            #       (n Fallback)))

    isv_nonterminal_reduce Directive $pos $mrk
    inc_save               Directive $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        Directive $pos
    return
}

proc ::page::parse::lemon::eseq15 {} {

    # (x (n DINTRO)
    #    (/ (n Code)
    #       (n DefaultDestructor)
    #       (n DefaultType)
    #       (n Destructor)
    #       (n ExtraArgument)
    #       (n Include)
    #       (n Left)
    #       (n Name)
    #       (n Nonassoc)
    #       (n ParseAccept)
    #       (n ParseFailure)
    #       (n Right)
    #       (n StackOverflow)
    #       (n Stacksize)
    #       (n StartSymbol)
    #       (n SyntaxError)
    #       (n TokenDestructor)
    #       (n TokenPrefix)
    #       (n TokenType)
    #       (n Type)
    #       (n Fallback)))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DINTRO    ; # (n DINTRO)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    ebra14                ; # (/ (n Code)
                            #    (n DefaultDestructor)
                            #    (n DefaultType)
                            #    (n Destructor)
                            #    (n ExtraArgument)
                            #    (n Include)
                            #    (n Left)
                            #    (n Name)
                            #    (n Nonassoc)
                            #    (n ParseAccept)
                            #    (n ParseFailure)
                            #    (n Right)
                            #    (n StackOverflow)
                            #    (n Stacksize)
                            #    (n StartSymbol)
                            #    (n SyntaxError)
                            #    (n TokenDestructor)
                            #    (n TokenPrefix)
                            #    (n TokenType)
                            #    (n Type)
                            #    (n Fallback))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::ebra14 {} {

    # (/ (n Code)
    #    (n DefaultDestructor)
    #    (n DefaultType)
    #    (n Destructor)
    #    (n ExtraArgument)
    #    (n Include)
    #    (n Left)
    #    (n Name)
    #    (n Nonassoc)
    #    (n ParseAccept)
    #    (n ParseFailure)
    #    (n Right)
    #    (n StackOverflow)
    #    (n Stacksize)
    #    (n StartSymbol)
    #    (n SyntaxError)
    #    (n TokenDestructor)
    #    (n TokenPrefix)
    #    (n TokenType)
    #    (n Type)
    #    (n Fallback))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_Code    ; # (n Code)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_DefaultDestructor    ; # (n DefaultDestructor)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_DefaultType    ; # (n DefaultType)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_Destructor    ; # (n Destructor)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_ExtraArgument    ; # (n ExtraArgument)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_Include    ; # (n Include)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_Left    ; # (n Left)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_Name    ; # (n Name)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_Nonassoc    ; # (n Nonassoc)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_ParseAccept    ; # (n ParseAccept)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_ParseFailure    ; # (n ParseFailure)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_Right    ; # (n Right)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_StackOverflow    ; # (n StackOverflow)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_Stacksize    ; # (n Stacksize)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_StartSymbol    ; # (n StartSymbol)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_SyntaxError    ; # (n SyntaxError)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_TokenDestructor    ; # (n TokenDestructor)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_TokenPrefix    ; # (n TokenPrefix)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_TokenType    ; # (n TokenType)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_Type    ; # (n Type)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_Fallback    ; # (n Fallback)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    return
}

proc ::page::parse::lemon::matchSymbol_DLEFT {} {
    # DLEFT = (x (t l)
    #            (t e)
    #            (t f)
    #            (t t)
    #            (n SPACE))

    if {[inc_restore DLEFT]} return

    set pos [icl_get]

    eseq65                ; # (x (t l)
                            #    (t e)
                            #    (t f)
                            #    (t t)
                            #    (n SPACE))

    isv_clear
    inc_save               DLEFT $pos
    ier_nonterminal        DLEFT $pos
    return
}

proc ::page::parse::lemon::eseq65 {} {

    # (x (t l)
    #    (t e)
    #    (t f)
    #    (t t)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance l
    if {$ok} {ict_match_token l}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance f
    if {$ok} {ict_match_token f}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DNAME {} {
    # DNAME = (x (t n)
    #            (t a)
    #            (t m)
    #            (t e)
    #            (n SPACE))

    if {[inc_restore DNAME]} return

    set pos [icl_get]

    eseq66                ; # (x (t n)
                            #    (t a)
                            #    (t m)
                            #    (t e)
                            #    (n SPACE))

    isv_clear
    inc_save               DNAME $pos
    ier_nonterminal        DNAME $pos
    return
}

proc ::page::parse::lemon::eseq66 {} {

    # (x (t n)
    #    (t a)
    #    (t m)
    #    (t e)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance n
    if {$ok} {ict_match_token n}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance a
    if {$ok} {ict_match_token a}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance m
    if {$ok} {ict_match_token m}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DNON {} {
    # DNON = (x (t n)
    #           (t o)
    #           (t n)
    #           (t a)
    #           (t s)
    #           (t s)
    #           (t o)
    #           (t c)
    #           (n SPACE))

    if {[inc_restore DNON]} return

    set pos [icl_get]

    eseq67                ; # (x (t n)
                            #    (t o)
                            #    (t n)
                            #    (t a)
                            #    (t s)
                            #    (t s)
                            #    (t o)
                            #    (t c)
                            #    (n SPACE))

    isv_clear
    inc_save               DNON $pos
    ier_nonterminal        DNON $pos
    return
}

proc ::page::parse::lemon::eseq67 {} {

    # (x (t n)
    #    (t o)
    #    (t n)
    #    (t a)
    #    (t s)
    #    (t s)
    #    (t o)
    #    (t c)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance n
    if {$ok} {ict_match_token n}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance o
    if {$ok} {ict_match_token o}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance n
    if {$ok} {ict_match_token n}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance a
    if {$ok} {ict_match_token a}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance s
    if {$ok} {ict_match_token s}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance s
    if {$ok} {ict_match_token s}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance o
    if {$ok} {ict_match_token o}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance c
    if {$ok} {ict_match_token c}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DOT {} {
    # DOT = (x (t .)
    #          (n SPACE))

    if {[inc_restore DOT]} return

    set pos [icl_get]

    eseq54                ; # (x (t .)
                            #    (n SPACE))

    isv_clear
    inc_save               DOT $pos
    ier_nonterminal        DOT $pos
    return
}

proc ::page::parse::lemon::eseq54 {} {

    # (x (t .)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance .
    if {$ok} {ict_match_token .}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DPACC {} {
    # DPACC = (x (t p)
    #            (t a)
    #            (t r)
    #            (t s)
    #            (t e)
    #            (t _)
    #            (t a)
    #            (t c)
    #            (t c)
    #            (t e)
    #            (t p)
    #            (t t)
    #            (n SPACE))

    if {[inc_restore DPACC]} return

    set pos [icl_get]

    eseq68                ; # (x (t p)
                            #    (t a)
                            #    (t r)
                            #    (t s)
                            #    (t e)
                            #    (t _)
                            #    (t a)
                            #    (t c)
                            #    (t c)
                            #    (t e)
                            #    (t p)
                            #    (t t)
                            #    (n SPACE))

    isv_clear
    inc_save               DPACC $pos
    ier_nonterminal        DPACC $pos
    return
}

proc ::page::parse::lemon::eseq68 {} {

    # (x (t p)
    #    (t a)
    #    (t r)
    #    (t s)
    #    (t e)
    #    (t _)
    #    (t a)
    #    (t c)
    #    (t c)
    #    (t e)
    #    (t p)
    #    (t t)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance p
    if {$ok} {ict_match_token p}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance a
    if {$ok} {ict_match_token a}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance s
    if {$ok} {ict_match_token s}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance _
    if {$ok} {ict_match_token _}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance a
    if {$ok} {ict_match_token a}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance c
    if {$ok} {ict_match_token c}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance c
    if {$ok} {ict_match_token c}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance p
    if {$ok} {ict_match_token p}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DPFAIL {} {
    # DPFAIL = (x (t p)
    #             (t a)
    #             (t r)
    #             (t s)
    #             (t e)
    #             (t _)
    #             (t f)
    #             (t a)
    #             (t i)
    #             (t l)
    #             (t u)
    #             (t r)
    #             (t e)
    #             (n SPACE))

    if {[inc_restore DPFAIL]} return

    set pos [icl_get]

    eseq69                ; # (x (t p)
                            #    (t a)
                            #    (t r)
                            #    (t s)
                            #    (t e)
                            #    (t _)
                            #    (t f)
                            #    (t a)
                            #    (t i)
                            #    (t l)
                            #    (t u)
                            #    (t r)
                            #    (t e)
                            #    (n SPACE))

    isv_clear
    inc_save               DPFAIL $pos
    ier_nonterminal        DPFAIL $pos
    return
}

proc ::page::parse::lemon::eseq69 {} {

    # (x (t p)
    #    (t a)
    #    (t r)
    #    (t s)
    #    (t e)
    #    (t _)
    #    (t f)
    #    (t a)
    #    (t i)
    #    (t l)
    #    (t u)
    #    (t r)
    #    (t e)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance p
    if {$ok} {ict_match_token p}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance a
    if {$ok} {ict_match_token a}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance s
    if {$ok} {ict_match_token s}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance _
    if {$ok} {ict_match_token _}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance f
    if {$ok} {ict_match_token f}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance a
    if {$ok} {ict_match_token a}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance i
    if {$ok} {ict_match_token i}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance l
    if {$ok} {ict_match_token l}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance u
    if {$ok} {ict_match_token u}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DRIGHT {} {
    # DRIGHT = (x (t r)
    #             (t i)
    #             (t g)
    #             (t h)
    #             (t t)
    #             (n SPACE))

    if {[inc_restore DRIGHT]} return

    set pos [icl_get]

    eseq70                ; # (x (t r)
                            #    (t i)
                            #    (t g)
                            #    (t h)
                            #    (t t)
                            #    (n SPACE))

    isv_clear
    inc_save               DRIGHT $pos
    ier_nonterminal        DRIGHT $pos
    return
}

proc ::page::parse::lemon::eseq70 {} {

    # (x (t r)
    #    (t i)
    #    (t g)
    #    (t h)
    #    (t t)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance i
    if {$ok} {ict_match_token i}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance g
    if {$ok} {ict_match_token g}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance h
    if {$ok} {ict_match_token h}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DSTART {} {
    # DSTART = (x (t s)
    #             (t t)
    #             (t a)
    #             (t r)
    #             (t t)
    #             (t _)
    #             (t s)
    #             (t y)
    #             (t m)
    #             (t b)
    #             (t o)
    #             (t l)
    #             (n SPACE))

    if {[inc_restore DSTART]} return

    set pos [icl_get]

    eseq73                ; # (x (t s)
                            #    (t t)
                            #    (t a)
                            #    (t r)
                            #    (t t)
                            #    (t _)
                            #    (t s)
                            #    (t y)
                            #    (t m)
                            #    (t b)
                            #    (t o)
                            #    (t l)
                            #    (n SPACE))

    isv_clear
    inc_save               DSTART $pos
    ier_nonterminal        DSTART $pos
    return
}

proc ::page::parse::lemon::eseq73 {} {

    # (x (t s)
    #    (t t)
    #    (t a)
    #    (t r)
    #    (t t)
    #    (t _)
    #    (t s)
    #    (t y)
    #    (t m)
    #    (t b)
    #    (t o)
    #    (t l)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance s
    if {$ok} {ict_match_token s}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance a
    if {$ok} {ict_match_token a}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance _
    if {$ok} {ict_match_token _}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance s
    if {$ok} {ict_match_token s}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance y
    if {$ok} {ict_match_token y}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance m
    if {$ok} {ict_match_token m}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance b
    if {$ok} {ict_match_token b}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance o
    if {$ok} {ict_match_token o}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance l
    if {$ok} {ict_match_token l}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DSTKOVER {} {
    # DSTKOVER = (x (t s)
    #               (t t)
    #               (t a)
    #               (t c)
    #               (t k)
    #               (t _)
    #               (t o)
    #               (t v)
    #               (t e)
    #               (t r)
    #               (t f)
    #               (t l)
    #               (t o)
    #               (t w)
    #               (n SPACE))

    if {[inc_restore DSTKOVER]} return

    set pos [icl_get]

    eseq71                ; # (x (t s)
                            #    (t t)
                            #    (t a)
                            #    (t c)
                            #    (t k)
                            #    (t _)
                            #    (t o)
                            #    (t v)
                            #    (t e)
                            #    (t r)
                            #    (t f)
                            #    (t l)
                            #    (t o)
                            #    (t w)
                            #    (n SPACE))

    isv_clear
    inc_save               DSTKOVER $pos
    ier_nonterminal        DSTKOVER $pos
    return
}

proc ::page::parse::lemon::eseq71 {} {

    # (x (t s)
    #    (t t)
    #    (t a)
    #    (t c)
    #    (t k)
    #    (t _)
    #    (t o)
    #    (t v)
    #    (t e)
    #    (t r)
    #    (t f)
    #    (t l)
    #    (t o)
    #    (t w)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance s
    if {$ok} {ict_match_token s}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance a
    if {$ok} {ict_match_token a}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance c
    if {$ok} {ict_match_token c}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance k
    if {$ok} {ict_match_token k}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance _
    if {$ok} {ict_match_token _}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance o
    if {$ok} {ict_match_token o}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance v
    if {$ok} {ict_match_token v}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance f
    if {$ok} {ict_match_token f}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance l
    if {$ok} {ict_match_token l}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance o
    if {$ok} {ict_match_token o}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance w
    if {$ok} {ict_match_token w}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DSTKSZ {} {
    # DSTKSZ = (x (t s)
    #             (t t)
    #             (t a)
    #             (t c)
    #             (t k)
    #             (t _)
    #             (t s)
    #             (t i)
    #             (t z)
    #             (t e)
    #             (n SPACE))

    if {[inc_restore DSTKSZ]} return

    set pos [icl_get]

    eseq72                ; # (x (t s)
                            #    (t t)
                            #    (t a)
                            #    (t c)
                            #    (t k)
                            #    (t _)
                            #    (t s)
                            #    (t i)
                            #    (t z)
                            #    (t e)
                            #    (n SPACE))

    isv_clear
    inc_save               DSTKSZ $pos
    ier_nonterminal        DSTKSZ $pos
    return
}

proc ::page::parse::lemon::eseq72 {} {

    # (x (t s)
    #    (t t)
    #    (t a)
    #    (t c)
    #    (t k)
    #    (t _)
    #    (t s)
    #    (t i)
    #    (t z)
    #    (t e)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance s
    if {$ok} {ict_match_token s}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance a
    if {$ok} {ict_match_token a}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance c
    if {$ok} {ict_match_token c}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance k
    if {$ok} {ict_match_token k}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance _
    if {$ok} {ict_match_token _}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance s
    if {$ok} {ict_match_token s}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance i
    if {$ok} {ict_match_token i}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance z
    if {$ok} {ict_match_token z}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DSYNERR {} {
    # DSYNERR = (x (t s)
    #              (t y)
    #              (t n)
    #              (t t)
    #              (t a)
    #              (t x)
    #              (t _)
    #              (t e)
    #              (t r)
    #              (t r)
    #              (t o)
    #              (t r)
    #              (n SPACE))

    if {[inc_restore DSYNERR]} return

    set pos [icl_get]

    eseq74                ; # (x (t s)
                            #    (t y)
                            #    (t n)
                            #    (t t)
                            #    (t a)
                            #    (t x)
                            #    (t _)
                            #    (t e)
                            #    (t r)
                            #    (t r)
                            #    (t o)
                            #    (t r)
                            #    (n SPACE))

    isv_clear
    inc_save               DSYNERR $pos
    ier_nonterminal        DSYNERR $pos
    return
}

proc ::page::parse::lemon::eseq74 {} {

    # (x (t s)
    #    (t y)
    #    (t n)
    #    (t t)
    #    (t a)
    #    (t x)
    #    (t _)
    #    (t e)
    #    (t r)
    #    (t r)
    #    (t o)
    #    (t r)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance s
    if {$ok} {ict_match_token s}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance y
    if {$ok} {ict_match_token y}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance n
    if {$ok} {ict_match_token n}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance a
    if {$ok} {ict_match_token a}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance x
    if {$ok} {ict_match_token x}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance _
    if {$ok} {ict_match_token _}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance o
    if {$ok} {ict_match_token o}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DTOKDEST {} {
    # DTOKDEST = (x (t t)
    #               (t o)
    #               (t k)
    #               (t e)
    #               (t n)
    #               (t _)
    #               (t d)
    #               (t e)
    #               (t s)
    #               (t t)
    #               (t r)
    #               (t u)
    #               (t c)
    #               (t t)
    #               (t o)
    #               (t r)
    #               (n SPACE))

    if {[inc_restore DTOKDEST]} return

    set pos [icl_get]

    eseq75                ; # (x (t t)
                            #    (t o)
                            #    (t k)
                            #    (t e)
                            #    (t n)
                            #    (t _)
                            #    (t d)
                            #    (t e)
                            #    (t s)
                            #    (t t)
                            #    (t r)
                            #    (t u)
                            #    (t c)
                            #    (t t)
                            #    (t o)
                            #    (t r)
                            #    (n SPACE))

    isv_clear
    inc_save               DTOKDEST $pos
    ier_nonterminal        DTOKDEST $pos
    return
}

proc ::page::parse::lemon::eseq75 {} {

    # (x (t t)
    #    (t o)
    #    (t k)
    #    (t e)
    #    (t n)
    #    (t _)
    #    (t d)
    #    (t e)
    #    (t s)
    #    (t t)
    #    (t r)
    #    (t u)
    #    (t c)
    #    (t t)
    #    (t o)
    #    (t r)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance o
    if {$ok} {ict_match_token o}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance k
    if {$ok} {ict_match_token k}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance n
    if {$ok} {ict_match_token n}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance _
    if {$ok} {ict_match_token _}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance d
    if {$ok} {ict_match_token d}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance s
    if {$ok} {ict_match_token s}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance u
    if {$ok} {ict_match_token u}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance c
    if {$ok} {ict_match_token c}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance o
    if {$ok} {ict_match_token o}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DTOKPFX {} {
    # DTOKPFX = (x (t t)
    #              (t o)
    #              (t k)
    #              (t e)
    #              (t n)
    #              (t _)
    #              (t p)
    #              (t r)
    #              (t e)
    #              (t f)
    #              (t i)
    #              (t x)
    #              (n SPACE))

    if {[inc_restore DTOKPFX]} return

    set pos [icl_get]

    eseq76                ; # (x (t t)
                            #    (t o)
                            #    (t k)
                            #    (t e)
                            #    (t n)
                            #    (t _)
                            #    (t p)
                            #    (t r)
                            #    (t e)
                            #    (t f)
                            #    (t i)
                            #    (t x)
                            #    (n SPACE))

    isv_clear
    inc_save               DTOKPFX $pos
    ier_nonterminal        DTOKPFX $pos
    return
}

proc ::page::parse::lemon::eseq76 {} {

    # (x (t t)
    #    (t o)
    #    (t k)
    #    (t e)
    #    (t n)
    #    (t _)
    #    (t p)
    #    (t r)
    #    (t e)
    #    (t f)
    #    (t i)
    #    (t x)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance o
    if {$ok} {ict_match_token o}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance k
    if {$ok} {ict_match_token k}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance n
    if {$ok} {ict_match_token n}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance _
    if {$ok} {ict_match_token _}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance p
    if {$ok} {ict_match_token p}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance r
    if {$ok} {ict_match_token r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance f
    if {$ok} {ict_match_token f}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance i
    if {$ok} {ict_match_token i}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance x
    if {$ok} {ict_match_token x}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DTOKTYPE {} {
    # DTOKTYPE = (x (t t)
    #               (t o)
    #               (t k)
    #               (t e)
    #               (t n)
    #               (t _)
    #               (t t)
    #               (t y)
    #               (t p)
    #               (t e)
    #               (n SPACE))

    if {[inc_restore DTOKTYPE]} return

    set pos [icl_get]

    eseq77                ; # (x (t t)
                            #    (t o)
                            #    (t k)
                            #    (t e)
                            #    (t n)
                            #    (t _)
                            #    (t t)
                            #    (t y)
                            #    (t p)
                            #    (t e)
                            #    (n SPACE))

    isv_clear
    inc_save               DTOKTYPE $pos
    ier_nonterminal        DTOKTYPE $pos
    return
}

proc ::page::parse::lemon::eseq77 {} {

    # (x (t t)
    #    (t o)
    #    (t k)
    #    (t e)
    #    (t n)
    #    (t _)
    #    (t t)
    #    (t y)
    #    (t p)
    #    (t e)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance o
    if {$ok} {ict_match_token o}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance k
    if {$ok} {ict_match_token k}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance n
    if {$ok} {ict_match_token n}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance _
    if {$ok} {ict_match_token _}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance y
    if {$ok} {ict_match_token y}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance p
    if {$ok} {ict_match_token p}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_DTYPE {} {
    # DTYPE = (x (t t)
    #            (t y)
    #            (t p)
    #            (t e)
    #            (n SPACE))

    if {[inc_restore DTYPE]} return

    set pos [icl_get]

    eseq78                ; # (x (t t)
                            #    (t y)
                            #    (t p)
                            #    (t e)
                            #    (n SPACE))

    isv_clear
    inc_save               DTYPE $pos
    ier_nonterminal        DTYPE $pos
    return
}

proc ::page::parse::lemon::eseq78 {} {

    # (x (t t)
    #    (t y)
    #    (t p)
    #    (t e)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance t
    if {$ok} {ict_match_token t}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance y
    if {$ok} {ict_match_token y}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance p
    if {$ok} {ict_match_token p}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance e
    if {$ok} {ict_match_token e}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_Endif {} {
    # Endif = (n DENDIF)

    if {[inc_restore Endif]} return

    set pos [icl_get]

    matchSymbol_DENDIF    ; # (n DENDIF)

    isv_clear
    inc_save               Endif $pos
    ier_nonterminal        Endif $pos
    return
}

proc ::page::parse::lemon::matchSymbol_EOF {} {
    # EOF = (! (dot))

    if {[inc_restore EOF]} return

    set pos [icl_get]

    ebang99

    isv_clear
    inc_save               EOF $pos
    ier_nonterminal        EOF $pos
    return
}

proc ::page::parse::lemon::ebang99 {} {
    set pos [icl_get]

    ict_advance "any character"

    icl_rewind $pos
    iok_negate
    return
}

proc ::page::parse::lemon::matchSymbol_EOL {} {
    # EOL = (/ (x (t \r)
    #             (t \n))
    #          (t \r)
    #          (t \n))

    if {[inc_restore EOL]} return

    set pos [icl_get]

    ebra98                ; # (/ (x (t \r)
                            #       (t \n))
                            #    (t \r)
                            #    (t \n))

    isv_clear
    inc_save               EOL $pos
    ier_nonterminal        EOL $pos
    return
}

proc ::page::parse::lemon::ebra98 {} {

    # (/ (x (t \r)
    #       (t \n))
    #    (t \r)
    #    (t \n))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    eseq97                ; # (x (t \r)
                            #    (t \n))
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance \\r
    if {$ok} {ict_match_token \r}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance \\n
    if {$ok} {ict_match_token \n}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    return
}

proc ::page::parse::lemon::eseq97 {} {

    # (x (t \r)
    #    (t \n))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance \\r
    if {$ok} {ict_match_token \r}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ict_advance \\n
    if {$ok} {ict_match_token \n}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_ExtraArgument {} {
    # ExtraArgument = (x (n DEXTRA)
    #                    (n Codeblock))

    variable ok
    if {[inc_restore ExtraArgument]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq20                ; # (x (n DEXTRA)
                            #    (n Codeblock))

    isv_nonterminal_reduce ExtraArgument $pos $mrk
    inc_save               ExtraArgument $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        ExtraArgument $pos
    return
}

proc ::page::parse::lemon::eseq20 {} {

    # (x (n DEXTRA)
    #    (n Codeblock))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DEXTRA    ; # (n DEXTRA)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Codeblock    ; # (n Codeblock)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::matchSymbol_Fallback {} {
    # Fallback = (x (n DFALLBK)
    #               (+ (n Identifier))
    #               (n DOT))

    variable ok
    if {[inc_restore Fallback]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq40                ; # (x (n DFALLBK)
                            #    (+ (n Identifier))
                            #    (n DOT))

    isv_nonterminal_reduce Fallback $pos $mrk
    inc_save               Fallback $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        Fallback $pos
    return
}

proc ::page::parse::lemon::eseq40 {} {

    # (x (n DFALLBK)
    #    (+ (n Identifier))
    #    (n DOT))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DFALLBK    ; # (n DFALLBK)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    epkleene39                ; # (+ (n Identifier))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_DOT    ; # (n DOT)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::epkleene39 {} {

    # (+ (n Identifier))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_Identifier    ; # (n Identifier)
    ier_merge $old

    if {!$ok} {
        icl_rewind $pos
        return
    }

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        matchSymbol_Identifier    ; # (n Identifier)
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::lemon::matchSymbol_Ident {} {
    # Ident = (x (/ (alpha)
    #               (t _))
    #            (* (/ (alnum)
    #                  (t _))))

    variable ok
    if {[inc_restore Ident]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    eseq50                ; # (x (/ (alpha)
                            #       (t _))
                            #    (* (/ (alnum)
                            #          (t _))))

    isv_nonterminal_range  Ident $pos
    inc_save               Ident $pos
    if {$ok} ias_push
    ier_nonterminal        Ident $pos
    return
}

proc ::page::parse::lemon::eseq50 {} {

    # (x (/ (alpha)
    #       (t _))
    #    (* (/ (alnum)
    #          (t _))))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ebra47                ; # (/ (alpha)
                            #    (t _))
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    ekleene49                ; # (* (/ (alnum)
                               #       (t _)))
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::ebra47 {} {

    # (/ (alpha)
    #    (t _))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance alpha
    if {$ok} {ict_match_tokclass alpha}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance _
    if {$ok} {ict_match_token _}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    return
}

proc ::page::parse::lemon::ekleene49 {} {

    # (* (/ (alnum)
    #       (t _)))

    variable ok

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        ebra48                ; # (/ (alnum)
                                #    (t _))
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::lemon::ebra48 {} {

    # (/ (alnum)
    #    (t _))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance alnum
    if {$ok} {ict_match_tokclass alnum}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance _
    if {$ok} {ict_match_token _}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    return
}

proc ::page::parse::lemon::matchSymbol_Identifier {} {
    # Identifier = (x (n Ident)
    #                 (n SPACE))

    variable ok
    if {[inc_restore Identifier]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq46                ; # (x (n Ident)
                            #    (n SPACE))

    isv_nonterminal_reduce Identifier $pos $mrk
    inc_save               Identifier $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        Identifier $pos
    return
}

proc ::page::parse::lemon::eseq46 {} {

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

proc ::page::parse::lemon::matchSymbol_Ifdef {} {
    # Ifdef = (x (n DIFDEF)
    #            (n Identifier))

    if {[inc_restore Ifdef]} return

    set pos [icl_get]

    eseq83                ; # (x (n DIFDEF)
                            #    (n Identifier))

    isv_clear
    inc_save               Ifdef $pos
    ier_nonterminal        Ifdef $pos
    return
}

proc ::page::parse::lemon::eseq83 {} {

    # (x (n DIFDEF)
    #    (n Identifier))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DIFDEF    ; # (n DIFDEF)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    set pIdentifier [ias_mark]
    matchSymbol_Identifier
    ias_pop2mark $pIdentifier    ; # (n Identifier)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_Ifndef {} {
    # Ifndef = (x (n DIFNDEF)
    #             (n Identifier))

    if {[inc_restore Ifndef]} return

    set pos [icl_get]

    eseq84                ; # (x (n DIFNDEF)
                            #    (n Identifier))

    isv_clear
    inc_save               Ifndef $pos
    ier_nonterminal        Ifndef $pos
    return
}

proc ::page::parse::lemon::eseq84 {} {

    # (x (n DIFNDEF)
    #    (n Identifier))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DIFNDEF    ; # (n DIFNDEF)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    set pIdentifier [ias_mark]
    matchSymbol_Identifier
    ias_pop2mark $pIdentifier    ; # (n Identifier)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_Include {} {
    # Include = (x (n DINCL)
    #              (n Codeblock))

    variable ok
    if {[inc_restore Include]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq21                ; # (x (n DINCL)
                            #    (n Codeblock))

    isv_nonterminal_reduce Include $pos $mrk
    inc_save               Include $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        Include $pos
    return
}

proc ::page::parse::lemon::eseq21 {} {

    # (x (n DINCL)
    #    (n Codeblock))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DINCL    ; # (n DINCL)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Codeblock    ; # (n Codeblock)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::matchSymbol_Label {} {
    # Label = (x (n LPAREN)
    #            (n Identifier)
    #            (n RPAREN))

    variable ok
    if {[inc_restore Label]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq12                ; # (x (n LPAREN)
                            #    (n Identifier)
                            #    (n RPAREN))

    isv_nonterminal_reduce Label $pos $mrk
    inc_save               Label $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        Label $pos
    return
}

proc ::page::parse::lemon::eseq12 {} {

    # (x (n LPAREN)
    #    (n Identifier)
    #    (n RPAREN))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_LPAREN    ; # (n LPAREN)
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
    matchSymbol_RPAREN    ; # (n RPAREN)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::matchSymbol_LBRACE {} {
    # LBRACE = (t \{)

    variable ok
    if {[inc_restore LBRACE]} return

    set pos [icl_get]

    ict_advance \{
    if {$ok} {ict_match_token \173}

    isv_clear
    inc_save               LBRACE $pos
    ier_nonterminal        LBRACE $pos
    return
}

proc ::page::parse::lemon::matchSymbol_LBRACKET {} {
    # LBRACKET = (x (t [)
    #               (n SPACE))

    if {[inc_restore LBRACKET]} return

    set pos [icl_get]

    eseq57                ; # (x (t [)
                            #    (n SPACE))

    isv_clear
    inc_save               LBRACKET $pos
    ier_nonterminal        LBRACKET $pos
    return
}

proc ::page::parse::lemon::eseq57 {} {

    # (x (t [)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance \[
    if {$ok} {ict_match_token \133}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_Left {} {
    # Left = (x (n DLEFT)
    #           (+ (n Identifier))
    #           (n DOT))

    variable ok
    if {[inc_restore Left]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq23                ; # (x (n DLEFT)
                            #    (+ (n Identifier))
                            #    (n DOT))

    isv_nonterminal_reduce Left $pos $mrk
    inc_save               Left $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        Left $pos
    return
}

proc ::page::parse::lemon::eseq23 {} {

    # (x (n DLEFT)
    #    (+ (n Identifier))
    #    (n DOT))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DLEFT    ; # (n DLEFT)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    epkleene22                ; # (+ (n Identifier))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_DOT    ; # (n DOT)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::epkleene22 {} {

    # (+ (n Identifier))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_Identifier    ; # (n Identifier)
    ier_merge $old

    if {!$ok} {
        icl_rewind $pos
        return
    }

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        matchSymbol_Identifier    ; # (n Identifier)
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::lemon::matchSymbol_LemonGrammar {} {
    # LemonGrammar = (x (n SPACE)
    #                   (+ (n Statement))
    #                   (n EOF))

    variable ok
    if {[inc_restore LemonGrammar]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq2                ; # (x (n SPACE)
                           #    (+ (n Statement))
                           #    (n EOF))

    isv_nonterminal_reduce LemonGrammar $pos $mrk
    inc_save               LemonGrammar $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        LemonGrammar $pos
    return
}

proc ::page::parse::lemon::eseq2 {} {

    # (x (n SPACE)
    #    (+ (n Statement))
    #    (n EOF))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    epkleene1                ; # (+ (n Statement))
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

proc ::page::parse::lemon::epkleene1 {} {

    # (+ (n Statement))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_Statement    ; # (n Statement)
    ier_merge $old

    if {!$ok} {
        icl_rewind $pos
        return
    }

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        matchSymbol_Statement    ; # (n Statement)
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::lemon::matchSymbol_LPAREN {} {
    # LPAREN = (x (t \()
    #             (n SPACE))

    if {[inc_restore LPAREN]} return

    set pos [icl_get]

    eseq55                ; # (x (t \()
                            #    (n SPACE))

    isv_clear
    inc_save               LPAREN $pos
    ier_nonterminal        LPAREN $pos
    return
}

proc ::page::parse::lemon::eseq55 {} {

    # (x (t \()
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance \(
    if {$ok} {ict_match_token \50}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_Name {} {
    # Name = (x (n DNAME)
    #           (n Identifier))

    variable ok
    if {[inc_restore Name]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq24                ; # (x (n DNAME)
                            #    (n Identifier))

    isv_nonterminal_reduce Name $pos $mrk
    inc_save               Name $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        Name $pos
    return
}

proc ::page::parse::lemon::eseq24 {} {

    # (x (n DNAME)
    #    (n Identifier))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DNAME    ; # (n DNAME)
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

    return
}

proc ::page::parse::lemon::matchSymbol_NatNum {} {
    # NatNum = (+ (.. 0 9))

    variable ok
    if {[inc_restore NatNum]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]

    epkleene52                ; # (+ (.. 0 9))

    isv_nonterminal_range  NatNum $pos
    inc_save               NatNum $pos
    if {$ok} ias_push
    ier_nonterminal        NatNum $pos
    return
}

proc ::page::parse::lemon::epkleene52 {} {

    # (+ (.. 0 9))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance "any in 0..9"
    if {$ok} {ict_match_tokrange 0 9}
    ier_merge $old

    if {!$ok} {
        icl_rewind $pos
        return
    }

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        ict_advance "any in 0..9"
        if {$ok} {ict_match_tokrange 0 9}
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::lemon::matchSymbol_NaturalNumber {} {
    # NaturalNumber = (x (n NatNum)
    #                    (n SPACE))

    variable ok
    if {[inc_restore NaturalNumber]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq51                ; # (x (n NatNum)
                            #    (n SPACE))

    isv_nonterminal_reduce NaturalNumber $pos $mrk
    inc_save               NaturalNumber $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        NaturalNumber $pos
    return
}

proc ::page::parse::lemon::eseq51 {} {

    # (x (n NatNum)
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_NatNum    ; # (n NatNum)
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

proc ::page::parse::lemon::matchSymbol_Nonassoc {} {
    # Nonassoc = (x (n DNON)
    #               (+ (n Identifier))
    #               (n DOT))

    variable ok
    if {[inc_restore Nonassoc]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq26                ; # (x (n DNON)
                            #    (+ (n Identifier))
                            #    (n DOT))

    isv_nonterminal_reduce Nonassoc $pos $mrk
    inc_save               Nonassoc $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        Nonassoc $pos
    return
}

proc ::page::parse::lemon::eseq26 {} {

    # (x (n DNON)
    #    (+ (n Identifier))
    #    (n DOT))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DNON    ; # (n DNON)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    epkleene25                ; # (+ (n Identifier))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_DOT    ; # (n DOT)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::epkleene25 {} {

    # (+ (n Identifier))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_Identifier    ; # (n Identifier)
    ier_merge $old

    if {!$ok} {
        icl_rewind $pos
        return
    }

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        matchSymbol_Identifier    ; # (n Identifier)
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::lemon::matchSymbol_ParseAccept {} {
    # ParseAccept = (x (n DPACC)
    #                  (n Codeblock))

    variable ok
    if {[inc_restore ParseAccept]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq27                ; # (x (n DPACC)
                            #    (n Codeblock))

    isv_nonterminal_reduce ParseAccept $pos $mrk
    inc_save               ParseAccept $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        ParseAccept $pos
    return
}

proc ::page::parse::lemon::eseq27 {} {

    # (x (n DPACC)
    #    (n Codeblock))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DPACC    ; # (n DPACC)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Codeblock    ; # (n Codeblock)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::matchSymbol_ParseFailure {} {
    # ParseFailure = (x (n DPFAIL)
    #                   (n Codeblock))

    variable ok
    if {[inc_restore ParseFailure]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq28                ; # (x (n DPFAIL)
                            #    (n Codeblock))

    isv_nonterminal_reduce ParseFailure $pos $mrk
    inc_save               ParseFailure $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        ParseFailure $pos
    return
}

proc ::page::parse::lemon::eseq28 {} {

    # (x (n DPFAIL)
    #    (n Codeblock))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DPFAIL    ; # (n DPFAIL)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Codeblock    ; # (n Codeblock)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::matchSymbol_Precedence {} {
    # Precedence = (x (n LBRACKET)
    #                 (n Identifier)
    #                 (n RBRACKET))

    variable ok
    if {[inc_restore Precedence]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq13                ; # (x (n LBRACKET)
                            #    (n Identifier)
                            #    (n RBRACKET))

    isv_nonterminal_reduce Precedence $pos $mrk
    inc_save               Precedence $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        Precedence $pos
    return
}

proc ::page::parse::lemon::eseq13 {} {

    # (x (n LBRACKET)
    #    (n Identifier)
    #    (n RBRACKET))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_LBRACKET    ; # (n LBRACKET)
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
    matchSymbol_RBRACKET    ; # (n RBRACKET)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::matchSymbol_RBRACE {} {
    # RBRACE = (t \})

    variable ok
    if {[inc_restore RBRACE]} return

    set pos [icl_get]

    ict_advance \}
    if {$ok} {ict_match_token \175}

    isv_clear
    inc_save               RBRACE $pos
    ier_nonterminal        RBRACE $pos
    return
}

proc ::page::parse::lemon::matchSymbol_RBRACKET {} {
    # RBRACKET = (x (t ])
    #               (n SPACE))

    if {[inc_restore RBRACKET]} return

    set pos [icl_get]

    eseq58                ; # (x (t ])
                            #    (n SPACE))

    isv_clear
    inc_save               RBRACKET $pos
    ier_nonterminal        RBRACKET $pos
    return
}

proc ::page::parse::lemon::eseq58 {} {

    # (x (t ])
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance \]
    if {$ok} {ict_match_token \135}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_Right {} {
    # Right = (x (n DRIGHT)
    #            (+ (n Identifier))
    #            (n DOT))

    variable ok
    if {[inc_restore Right]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq30                ; # (x (n DRIGHT)
                            #    (+ (n Identifier))
                            #    (n DOT))

    isv_nonterminal_reduce Right $pos $mrk
    inc_save               Right $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        Right $pos
    return
}

proc ::page::parse::lemon::eseq30 {} {

    # (x (n DRIGHT)
    #    (+ (n Identifier))
    #    (n DOT))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DRIGHT    ; # (n DRIGHT)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    epkleene29                ; # (+ (n Identifier))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_DOT    ; # (n DOT)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::epkleene29 {} {

    # (+ (n Identifier))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_Identifier    ; # (n Identifier)
    ier_merge $old

    if {!$ok} {
        icl_rewind $pos
        return
    }

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        matchSymbol_Identifier    ; # (n Identifier)
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::lemon::matchSymbol_RPAREN {} {
    # RPAREN = (x (t \))
    #             (n SPACE))

    if {[inc_restore RPAREN]} return

    set pos [icl_get]

    eseq56                ; # (x (t \))
                            #    (n SPACE))

    isv_clear
    inc_save               RPAREN $pos
    ier_nonterminal        RPAREN $pos
    return
}

proc ::page::parse::lemon::eseq56 {} {

    # (x (t \))
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance \)
    if {$ok} {ict_match_token \51}
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set old [ier_get]
    matchSymbol_SPACE    ; # (n SPACE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    return
}

proc ::page::parse::lemon::matchSymbol_Rule {} {
    # Rule = (x (n Identifier)
    #           (? (n Label))
    #           (n ASSIGN)
    #           (n Definition)
    #           (n DOT)
    #           (? (n Precedence))
    #           (? (n Codeblock)))

    variable ok
    if {[inc_restore Rule]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq8                ; # (x (n Identifier)
                           #    (? (n Label))
                           #    (n ASSIGN)
                           #    (n Definition)
                           #    (n DOT)
                           #    (? (n Precedence))
                           #    (? (n Codeblock)))

    isv_nonterminal_reduce Rule $pos $mrk
    inc_save               Rule $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        Rule $pos
    return
}

proc ::page::parse::lemon::eseq8 {} {

    # (x (n Identifier)
    #    (? (n Label))
    #    (n ASSIGN)
    #    (n Definition)
    #    (n DOT)
    #    (? (n Precedence))
    #    (? (n Codeblock)))

    variable ok

    set pos [icl_get]

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
    eopt5                ; # (? (n Label))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_ASSIGN    ; # (n ASSIGN)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_Definition    ; # (n Definition)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    matchSymbol_DOT    ; # (n DOT)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    eopt6                ; # (? (n Precedence))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    set old [ier_get]
    eopt7                ; # (? (n Codeblock))
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::eopt5 {} {

    # (? (n Label))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_Label    ; # (n Label)
    ier_merge $old

    if {$ok} return
    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::lemon::eopt6 {} {

    # (? (n Precedence))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_Precedence    ; # (n Precedence)
    ier_merge $old

    if {$ok} return
    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::lemon::eopt7 {} {

    # (? (n Codeblock))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_Codeblock    ; # (n Codeblock)
    ier_merge $old

    if {$ok} return
    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::lemon::matchSymbol_SPACE {} {
    # SPACE = (* (/ (t <blank>)
    #               (t \t)
    #               (t \n)
    #               (t \r)
    #               (n C_COMMENT)
    #               (n Cplusplus_COMMENT)
    #               (n Ifndef)
    #               (n Ifdef)
    #               (n Endif)))

    if {[inc_restore SPACE]} return

    set pos [icl_get]

    ekleene86                ; # (* (/ (t <blank>)
                               #       (t \t)
                               #       (t \n)
                               #       (t \r)
                               #       (n C_COMMENT)
                               #       (n Cplusplus_COMMENT)
                               #       (n Ifndef)
                               #       (n Ifdef)
                               #       (n Endif)))

    isv_clear
    inc_save               SPACE $pos
    ier_nonterminal        SPACE $pos
    return
}

proc ::page::parse::lemon::ekleene86 {} {

    # (* (/ (t <blank>)
    #       (t \t)
    #       (t \n)
    #       (t \r)
    #       (n C_COMMENT)
    #       (n Cplusplus_COMMENT)
    #       (n Ifndef)
    #       (n Ifdef)
    #       (n Endif)))

    variable ok

    while {1} {
        set pos [icl_get]

        set old [ier_get]
        ebra85                ; # (/ (t <blank>)
                                #    (t \t)
                                #    (t \n)
                                #    (t \r)
                                #    (n C_COMMENT)
                                #    (n Cplusplus_COMMENT)
                                #    (n Ifndef)
                                #    (n Ifdef)
                                #    (n Endif))
        ier_merge $old

        if {$ok} continue
        break
    }

    icl_rewind $pos
    iok_ok
    return
}

proc ::page::parse::lemon::ebra85 {} {

    # (/ (t <blank>)
    #    (t \t)
    #    (t \n)
    #    (t \r)
    #    (n C_COMMENT)
    #    (n Cplusplus_COMMENT)
    #    (n Ifndef)
    #    (n Ifdef)
    #    (n Endif))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    ict_advance <blank>
    if {$ok} {ict_match_token \40}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance \\t
    if {$ok} {ict_match_token \t}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance \\n
    if {$ok} {ict_match_token \n}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    ict_advance \\r
    if {$ok} {ict_match_token \r}
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    matchSymbol_C_COMMENT    ; # (n C_COMMENT)
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    matchSymbol_Cplusplus_COMMENT    ; # (n Cplusplus_COMMENT)
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    matchSymbol_Ifndef    ; # (n Ifndef)
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    matchSymbol_Ifdef    ; # (n Ifdef)
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    set old [ier_get]
    matchSymbol_Endif    ; # (n Endif)
    ier_merge $old

    if {$ok} return
    icl_rewind   $pos

    return
}

proc ::page::parse::lemon::matchSymbol_StackOverflow {} {
    # StackOverflow = (x (n DSTKOVER)
    #                    (n Codeblock))

    variable ok
    if {[inc_restore StackOverflow]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq31                ; # (x (n DSTKOVER)
                            #    (n Codeblock))

    isv_nonterminal_reduce StackOverflow $pos $mrk
    inc_save               StackOverflow $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        StackOverflow $pos
    return
}

proc ::page::parse::lemon::eseq31 {} {

    # (x (n DSTKOVER)
    #    (n Codeblock))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DSTKOVER    ; # (n DSTKOVER)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Codeblock    ; # (n Codeblock)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::matchSymbol_Stacksize {} {
    # Stacksize = (x (n DSTKSZ)
    #                (n NaturalNumber))

    variable ok
    if {[inc_restore Stacksize]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq32                ; # (x (n DSTKSZ)
                            #    (n NaturalNumber))

    isv_nonterminal_reduce Stacksize $pos $mrk
    inc_save               Stacksize $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        Stacksize $pos
    return
}

proc ::page::parse::lemon::eseq32 {} {

    # (x (n DSTKSZ)
    #    (n NaturalNumber))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DSTKSZ    ; # (n DSTKSZ)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_NaturalNumber    ; # (n NaturalNumber)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::matchSymbol_StartSymbol {} {
    # StartSymbol = (x (n DSTART)
    #                  (n Identifier))

    variable ok
    if {[inc_restore StartSymbol]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq33                ; # (x (n DSTART)
                            #    (n Identifier))

    isv_nonterminal_reduce StartSymbol $pos $mrk
    inc_save               StartSymbol $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        StartSymbol $pos
    return
}

proc ::page::parse::lemon::eseq33 {} {

    # (x (n DSTART)
    #    (n Identifier))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DSTART    ; # (n DSTART)
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

    return
}

proc ::page::parse::lemon::matchSymbol_Statement {} {
    # Statement = (x (/ (n Directive)
    #                   (n Rule))
    #                (n SPACE))

    variable ok
    if {[inc_restore Statement]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq4                ; # (x (/ (n Directive)
                           #       (n Rule))
                           #    (n SPACE))

    isv_nonterminal_reduce Statement $pos $mrk
    inc_save               Statement $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        Statement $pos
    return
}

proc ::page::parse::lemon::eseq4 {} {

    # (x (/ (n Directive)
    #       (n Rule))
    #    (n SPACE))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]

    set old [ier_get]
    ebra3                ; # (/ (n Directive)
                           #    (n Rule))
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

proc ::page::parse::lemon::ebra3 {} {

    # (/ (n Directive)
    #    (n Rule))

    variable ok

    set pos [icl_get]

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_Directive    ; # (n Directive)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    set mrk [ias_mark]
    set old [ier_get]
    matchSymbol_Rule    ; # (n Rule)
    ier_merge $old

    if {$ok} return
    ias_pop2mark $mrk
    icl_rewind   $pos

    return
}

proc ::page::parse::lemon::matchSymbol_SyntaxError {} {
    # SyntaxError = (x (n DSYNERR)
    #                  (n Codeblock))

    variable ok
    if {[inc_restore SyntaxError]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq34                ; # (x (n DSYNERR)
                            #    (n Codeblock))

    isv_nonterminal_reduce SyntaxError $pos $mrk
    inc_save               SyntaxError $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        SyntaxError $pos
    return
}

proc ::page::parse::lemon::eseq34 {} {

    # (x (n DSYNERR)
    #    (n Codeblock))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DSYNERR    ; # (n DSYNERR)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Codeblock    ; # (n Codeblock)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::matchSymbol_TokenDestructor {} {
    # TokenDestructor = (x (n DTOKDEST)
    #                      (n Identifier)
    #                      (n Codeblock))

    variable ok
    if {[inc_restore TokenDestructor]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq35                ; # (x (n DTOKDEST)
                            #    (n Identifier)
                            #    (n Codeblock))

    isv_nonterminal_reduce TokenDestructor $pos $mrk
    inc_save               TokenDestructor $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        TokenDestructor $pos
    return
}

proc ::page::parse::lemon::eseq35 {} {

    # (x (n DTOKDEST)
    #    (n Identifier)
    #    (n Codeblock))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DTOKDEST    ; # (n DTOKDEST)
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
    matchSymbol_Codeblock    ; # (n Codeblock)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::matchSymbol_TokenPrefix {} {
    # TokenPrefix = (x (n DTOKPFX)
    #                  (n Identifier))

    variable ok
    if {[inc_restore TokenPrefix]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq36                ; # (x (n DTOKPFX)
                            #    (n Identifier))

    isv_nonterminal_reduce TokenPrefix $pos $mrk
    inc_save               TokenPrefix $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        TokenPrefix $pos
    return
}

proc ::page::parse::lemon::eseq36 {} {

    # (x (n DTOKPFX)
    #    (n Identifier))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DTOKPFX    ; # (n DTOKPFX)
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

    return
}

proc ::page::parse::lemon::matchSymbol_TokenType {} {
    # TokenType = (x (n DTOKTYPE)
    #                (n Codeblock))

    variable ok
    if {[inc_restore TokenType]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq37                ; # (x (n DTOKTYPE)
                            #    (n Codeblock))

    isv_nonterminal_reduce TokenType $pos $mrk
    inc_save               TokenType $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        TokenType $pos
    return
}

proc ::page::parse::lemon::eseq37 {} {

    # (x (n DTOKTYPE)
    #    (n Codeblock))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DTOKTYPE    ; # (n DTOKTYPE)
    ier_merge $old

    if {!$ok} {icl_rewind $pos ; return}

    set mrk [ias_mark]

    set old [ier_get]
    matchSymbol_Codeblock    ; # (n Codeblock)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

proc ::page::parse::lemon::matchSymbol_Type {} {
    # Type = (x (n DTYPE)
    #           (n Identifier)
    #           (n Codeblock))

    variable ok
    if {[inc_restore Type]} {
        if {$ok} ias_push
        return
    }

    set pos [icl_get]
    set mrk [ias_mark]

    eseq38                ; # (x (n DTYPE)
                            #    (n Identifier)
                            #    (n Codeblock))

    isv_nonterminal_reduce Type $pos $mrk
    inc_save               Type $pos
    ias_pop2mark             $mrk
    if {$ok} ias_push
    ier_nonterminal        Type $pos
    return
}

proc ::page::parse::lemon::eseq38 {} {

    # (x (n DTYPE)
    #    (n Identifier)
    #    (n Codeblock))

    variable ok

    set pos [icl_get]

    set old [ier_get]
    matchSymbol_DTYPE    ; # (n DTYPE)
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
    matchSymbol_Codeblock    ; # (n Codeblock)
    ier_merge $old

    if {!$ok} {
        ias_pop2mark $mrk
        icl_rewind   $pos
        return
    }

    return
}

# ### ### ### ######### ######### #########
## Package Management

package provide page::parse::lemon 0.1
