# ripemd160.tcl - Copyright (C) 2003 Pat Thoyts <patthoyts@users.sf.net>
#
# This is a Tcl-only implementation of the RIPEMD-160 hash algorithm as 
# described in [RIPE].
# Included is an implementation of keyed message authentication using 
# the RIPEMD-160 function [HMAC].
#
# See http://www.esat.kuleuven.ac.be/~cosicart/pdf/AB-9601/
#
# [RIPE] Dobbertin, H., Bosselaers A., and Preneel, B.
#        "RIPEMD-160: A Strengthened Version of RIPEMD" 
#        Fast Software Encryption, LNCS 1039, D. Gollmann, Ed., 
#        Springer-Verlag, 1996, pp. 71-82
# [HMAC] Krawczyk, H., Bellare, M., and R. Canetti, 
#       "HMAC: Keyed-Hashing for Message Authentication",
#        RFC 2104, February 1997.
#
# RFC 2286, ``Test cases for HMAC-RIPEMD160 and HMAC-RIPEMD128,''
# Internet Request for Comments 2286, J. Kapp, 
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

package require Tcl 8.2;                # tcl minimum version
#catch {package require ripemdc 1.0};   # tcllib critcl alternative

namespace eval ::ripemd {
    namespace eval ripemd160 {
        variable  accel
        array set accel {cryptkit 0 trf 0}

        variable uid
        if {![info exists uid]} {
            set uid 0
        }

        namespace export ripemd160 hmac160 Hex \
            RIPEMD160Init RIPEMD160Update RIPEMD160Final \
            RIPEHMAC160Init RIPEHMAC160Update RIPEHMAC160Final
    }
}

# -------------------------------------------------------------------------

# RIPEMD160Init - create and initialize the state variable. This will be
# cleaned up when we call RIPEMD160Final
#
proc ::ripemd::ripemd160::RIPEMD160Init {} {
    variable accel
    variable uid
    set token [namespace current]::[incr uid]
    upvar #0 $token state

    # Initialize RIPEMD-160 state structure (same as MD4).
    array set state \
        [list \
             A [expr {0x67452301}] \
             B [expr {0xefcdab89}] \
             C [expr {0x98badcfe}] \
             D [expr {0x10325476}] \
             E [expr {0xc3d2e1f0}] \
             n 0 i "" ]
    if {$accel(cryptkit)} {
        cryptkit::cryptCreateContext state(ckctx) \
            CRYPT_UNUSED CRYPT_ALGO_RIPEMD160
    } elseif {$accel(trf)} {
        set s {}
        switch -exact -- $::tcl_platform(platform) {
            windows { set s [open NUL w] }
            unix    { set s [open /dev/null w] }
        }
        if {$s != {}} {
            fconfigure $s -translation binary -buffering none
            ::ripemd160 -attach $s -mode write \
                -read-type variable \
                -read-destination [subst $token](trfread) \
                -write-type variable \
                -write-destination [subst $token](trfwrite)
            array set state [list trfread 0 trfwrite 0 trf $s]
        }
    }
    return $token
}

proc ::ripemd::ripemd160::RIPEMD160Update {token data} {
    upvar #0 $token state

    if {[info exists state(ckctx)]} {
        if {[string length $data] > 0} {
            cryptkit::cryptEncrypt $state(ckctx) $data
        }
        return
    } elseif {[info exists state(trf)]} {
        puts -nonewline $state(trf) $data
        return
    }

    # Update the state values
    incr state(n) [string length $data]
    append state(i) $data

    # Calculate the hash for any complete blocks
    set len [string length $state(i)]
    for {set n 0} {($n + 64) <= $len} {} {
        RIPEMD160Hash $token [string range $state(i) $n [incr n 64]]
    }

    # Adjust the state for the blocks completed.
    set state(i) [string range $state(i) $n end]
    return
}

proc ::ripemd::ripemd160::RIPEMD160Final {token} {
    upvar #0 $token state

    if {[info exists state(ckctx)]} {
        cryptkit::cryptEncrypt $state(ckctx) ""
        cryptkit::cryptGetAttributeString $state(ckctx) \
            CRYPT_CTXINFO_HASHVALUE r 20
        cryptkit::cryptDestroyContext $state(ckctx)
        # If nothing was hashed, we get no r variable set!
        if {[info exists r]} {
            unset state
            return $r
        }
    } elseif {[info exists state(trf)]} {
        close $state(trf)
        set r $state(trfwrite)
        unset state
        return $r
    }

    # Padding
    #
    set len [string length $state(i)]
    set pad [expr {56 - ($len % 64)}]
    if {$len % 64 > 56} {
        incr pad 64
    }
    if {$pad == 0} {
        incr pad 64
    }
    append state(i) [binary format a$pad \x80]

    # Append length in bits as little-endian wide int.
    append state(i) [binary format ii [expr {8 * $state(n)}] 0]

    # Calculate the hash for the remaining block.
    set len [string length $state(i)]
    for {set n 0} {($n + 64) <= $len} {} {
        RIPEMD160Hash $token [string range $state(i) $n [incr n 64]]
    }

    # Output
    set r [bytes $state(A)][bytes $state(B)][bytes $state(C)][bytes $state(D)][bytes $state(E)]
    unset state
    return $r
}

# -------------------------------------------------------------------------
# HMAC Hashed Message Authentication (RFC 2104)
#
# hmac = H(K xor opad, H(K xor ipad, text))
#
proc ::ripemd::ripemd160::RIPEHMAC160Init {K} {

    # Key K is adjusted to be 64 bytes long. If K is larger, then use
    # the RIPEMD-160 digest of K and pad this instead.
    set len [string length $K]
    if {$len > 64} {
        set tok [RIPEMD160Init]
        RIPEMD160Update $tok $K
        set K [RIPEMD160Final $tok]
        set len [string length $K]
    }
    set pad [expr {64 - $len}]
    append K [string repeat \0 $pad]

    # Cacluate the padding buffers.
    set Ki {}
    set Ko {}
    binary scan $K i16 Ks
    foreach k $Ks {
        append Ki [binary format i [expr {$k ^ 0x36363636}]]
        append Ko [binary format i [expr {$k ^ 0x5c5c5c5c}]]
    }

    set tok [RIPEMD160Init]
    RIPEMD160Update $tok $Ki;                 # initialize with the inner pad
    
    # preserve the Ko value for the final stage.
    # FRINK: nocheck
    set [subst $tok](Ko) $Ko

    return $tok
}

proc ::ripemd::ripemd160::RIPEHMAC160Update {token data} {
    RIPEMD160Update $token $data
    return
}

proc ::ripemd::ripemd160::RIPEHMAC160Final {token} {
    # FRINK: nocheck
    variable $token
    upvar 0 $token state

    set tok [RIPEMD160Init];            # init the outer hashing function
    RIPEMD160Update $tok $state(Ko);    # prepare with the outer pad.
    RIPEMD160Update $tok [RIPEMD160Final $token];  # hash the inner result
    return [RIPEMD160Final $tok]
}

# -------------------------------------------------------------------------

set ::ripemd::ripemd160::RIPEMD160Hash_body {
    variable $token
    upvar 0 $token state

    binary scan $msg i* blocks
    foreach {X0 X1 X2 X3 X4 X5 X6 X7 X8 X9 X10 X11 X12 X13 X14 X15} $blocks {
        set A $state(A)   ;  set AA $state(A)
        set B $state(B)   ;  set BB $state(B)
        set C $state(C)   ;  set CC $state(C)
        set D $state(D)   ;  set DD $state(D)
        set E $state(E)   ;  set EE $state(E)

        FF A B C D E $X0 11
        FF E A B C D $X1 14
        FF D E A B C $X2 15
        FF C D E A B $X3 12
        FF B C D E A $X4 5
        FF A B C D E $X5 8
        FF E A B C D $X6 7
        FF D E A B C $X7 9
        FF C D E A B $X8 11
        FF B C D E A $X9 13
        FF A B C D E $X10 14
        FF E A B C D $X11 15
        FF D E A B C $X12 6
        FF C D E A B $X13 7
        FF B C D E A $X14 9
        FF A B C D E $X15 8
        
        GG E A B C D $X7 7
        GG D E A B C $X4 6
        GG C D E A B $X13 8
        GG B C D E A $X1 13
        GG A B C D E $X10 11
        GG E A B C D $X6 9
        GG D E A B C $X15 7
        GG C D E A B $X3 15
        GG B C D E A $X12 7
        GG A B C D E $X0 12
        GG E A B C D $X9 15
        GG D E A B C $X5 9
        GG C D E A B $X2 11
        GG B C D E A $X14 7
        GG A B C D E $X11 13
        GG E A B C D $X8 12
        
        HH D E A B C $X3 11
        HH C D E A B $X10 13
        HH B C D E A $X14 6
        HH A B C D E $X4 7
        HH E A B C D $X9 14
        HH D E A B C $X15 9
        HH C D E A B $X8 13
        HH B C D E A $X1 15
        HH A B C D E $X2 14
        HH E A B C D $X7 8
        HH D E A B C $X0 13
        HH C D E A B $X6 6
        HH B C D E A $X13 5
        HH A B C D E $X11 12
        HH E A B C D $X5 7
        HH D E A B C $X12 5
        
        II C D E A B $X1 11
        II B C D E A $X9 12
        II A B C D E $X11 14
        II E A B C D $X10 15
        II D E A B C $X0 14
        II C D E A B $X8 15
        II B C D E A $X12 9
        II A B C D E $X4 8
        II E A B C D $X13 9
        II D E A B C $X3 14
        II C D E A B $X7 5
        II B C D E A $X15 6
        II A B C D E $X14 8
        II E A B C D $X5 6
        II D E A B C $X6 5
        II C D E A B $X2 12
        
        JJ B C D E A $X4 9
        JJ A B C D E $X0 15
        JJ E A B C D $X5 5
        JJ D E A B C $X9 11
        JJ C D E A B $X7 6
        JJ B C D E A $X12 8
        JJ A B C D E $X2 13
        JJ E A B C D $X10 12
        JJ D E A B C $X14 5
        JJ C D E A B $X1 12
        JJ B C D E A $X3 13
        JJ A B C D E $X8 14
        JJ E A B C D $X11 11
        JJ D E A B C $X6 8
        JJ C D E A B $X15 5
        JJ B C D E A $X13 6
        
        JJJ AA BB CC DD EE $X5 8
        JJJ EE AA BB CC DD $X14 9
        JJJ DD EE AA BB CC $X7 9
        JJJ CC DD EE AA BB $X0 11
        JJJ BB CC DD EE AA $X9 13
        JJJ AA BB CC DD EE $X2 15
        JJJ EE AA BB CC DD $X11 15
        JJJ DD EE AA BB CC $X4 5
        JJJ CC DD EE AA BB $X13 7
        JJJ BB CC DD EE AA $X6 7
        JJJ AA BB CC DD EE $X15 8
        JJJ EE AA BB CC DD $X8 11
        JJJ DD EE AA BB CC $X1 14
        JJJ CC DD EE AA BB $X10 14
        JJJ BB CC DD EE AA $X3 12
        JJJ AA BB CC DD EE $X12 6
        
        III EE AA BB CC DD $X6 9
        III DD EE AA BB CC $X11 13
        III CC DD EE AA BB $X3 15
        III BB CC DD EE AA $X7 7
        III AA BB CC DD EE $X0 12
        III EE AA BB CC DD $X13 8
        III DD EE AA BB CC $X5 9
        III CC DD EE AA BB $X10 11
        III BB CC DD EE AA $X14 7
        III AA BB CC DD EE $X15 7
        III EE AA BB CC DD $X8 12
        III DD EE AA BB CC $X12 7
        III CC DD EE AA BB $X4 6
        III BB CC DD EE AA $X9 15
        III AA BB CC DD EE $X1 13
        III EE AA BB CC DD $X2 11
        
        HHH DD EE AA BB CC $X15 9
        HHH CC DD EE AA BB $X5 7
        HHH BB CC DD EE AA $X1 15
        HHH AA BB CC DD EE $X3 11
        HHH EE AA BB CC DD $X7 8
        HHH DD EE AA BB CC $X14 6
        HHH CC DD EE AA BB $X6 6
        HHH BB CC DD EE AA $X9 14
        HHH AA BB CC DD EE $X11 12
        HHH EE AA BB CC DD $X8 13
        HHH DD EE AA BB CC $X12 5
        HHH CC DD EE AA BB $X2 14
        HHH BB CC DD EE AA $X10 13
        HHH AA BB CC DD EE $X0 13
        HHH EE AA BB CC DD $X4 7
        HHH DD EE AA BB CC $X13 5
        
        GGG CC DD EE AA BB $X8 15
        GGG BB CC DD EE AA $X6 5
        GGG AA BB CC DD EE $X4 8
        GGG EE AA BB CC DD $X1 11
        GGG DD EE AA BB CC $X3 14
        GGG CC DD EE AA BB $X11 14
        GGG BB CC DD EE AA $X15 6
        GGG AA BB CC DD EE $X0 14
        GGG EE AA BB CC DD $X5 6
        GGG DD EE AA BB CC $X12 9
        GGG CC DD EE AA BB $X2 12
        GGG BB CC DD EE AA $X13 9
        GGG AA BB CC DD EE $X9 12
        GGG EE AA BB CC DD $X7 5
        GGG DD EE AA BB CC $X10 15
        GGG CC DD EE AA BB $X14 8
        
        FFF BB CC DD EE AA $X12 8
        FFF AA BB CC DD EE $X15 5
        FFF EE AA BB CC DD $X10 12
        FFF DD EE AA BB CC $X4 9
        FFF CC DD EE AA BB $X1 12
        FFF BB CC DD EE AA $X5 5
        FFF AA BB CC DD EE $X8 14
        FFF EE AA BB CC DD $X7 6
        FFF DD EE AA BB CC $X6 8
        FFF CC DD EE AA BB $X2 13
        FFF BB CC DD EE AA $X13 6
        FFF AA BB CC DD EE $X14 5
        FFF EE AA BB CC DD $X0 15
        FFF DD EE AA BB CC $X3 13
        FFF CC DD EE AA BB $X9 11
        FFF BB CC DD EE AA $X11 11

        # Then perform the following additions to combine the results.
        set DD       [expr {$state(B) + $C + $DD}]
        set state(B) [expr {$state(C) + $D + $EE}]
        set state(C) [expr {$state(D) + $E + $AA}]
        set state(D) [expr {$state(E) + $A + $BB}]
        set state(E) [expr {$state(A) + $B + $CC}]
        set state(A) $DD
    }

    return
}

proc ::ripemd::ripemd160::byte {n v} {expr {((0xFF << (8 * $n)) & $v) >> (8 * $n)}}
proc ::ripemd::ripemd160::bytes {v} { 
    #format %c%c%c%c [byte 0 $v] [byte 1 $v] [byte 2 $v] [byte 3 $v]
    format %c%c%c%c \
        [expr {0xFF & $v}] \
        [expr {(0xFF00 & $v) >> 8}] \
        [expr {(0xFF0000 & $v) >> 16}] \
        [expr {((0xFF000000 & $v) >> 24) & 0xFF}]
}

#  F(x,y,z) = x ^ y ^ z
proc ::ripemd::ripemd160::F {X Y Z} {
    return [expr {$X ^ $Y ^ $Z}]
}
# G(x,y,z) = (x & y) | (~x & z)
proc ::ripemd::ripemd160::G {X Y Z} {
    return [expr {($X & $Y) | (~$X & $Z)}]
}
# H(x,y,z) = (x | ~y) ^ z
proc ::ripemd::ripemd160::H {X Y Z} {
    return [expr {($X | ~$Y) ^ $Z}]
}
# I(x,y,z) = (x & z) | (y & ~z)
proc ::ripemd::ripemd160::I {X Y Z} {
    return [expr {($X & $Z) | ($Y & ~$Z)}]
}
# J(x,y,z) = x ^ (y | ~z)
proc ::ripemd::ripemd160::J {X Y Z} {
    return [expr {($X ^ ($Y | ~$Z))}]
}

proc ::ripemd::ripemd160::FF {a b c d e x s} {
    upvar $a A $b B $c C $d D $e E
    set A [<<< [expr {$A + ($B ^ $C ^ $D) + $x}] $s]
    incr A $E
    set C [<<< $C 10]
}

proc ::ripemd::ripemd160::GG {a b c d e x s} {
    upvar $a A $b B $c C $d D $e E
    set A [<<< [expr {$A + (($B & $C) | (~$B & $D)) + $x + 0x5a827999}] $s]
    incr A $E
    set C [<<< $C 10]
}

proc ::ripemd::ripemd160::HH {a b c d e x s} {
    upvar $a A $b B $c C $d D $e E
    set A [<<< [expr {$A + (($B | ~$C) ^ $D) + $x + 0x6ed9eba1}] $s]
    incr A $E
    set C [<<< $C 10]
}

proc ::ripemd::ripemd160::II {a b c d e x s} {
    upvar $a A $b B $c C $d D $e E
    set A [<<< [expr {$A + (($B & $D)|($C & ~$D)) + $x + 0x8f1bbcdc}] $s]
    incr A $E
    set C [<<< $C 10]

}

proc ::ripemd::ripemd160::JJ {a b c d e x s} {
    upvar $a A $b B $c C $d D $e E
    set A [<<< [expr {$A + ($B ^ ($C | ~$D)) + $x + 0xa953fd4e}] $s]
    incr A $E
    set C [<<< $C 10]
}


proc ::ripemd::ripemd160::FFF {a b c d e x s} {
    upvar $a A $b B $c C $d D $e E
    set A [<<< [expr {$A + ($B ^ $C ^ $D) + $x}] $s]
    incr A $E
    set C [<<< $C 10]
}

proc ::ripemd::ripemd160::GGG {a b c d e x s} {
    upvar $a A $b B $c C $d D $e E
    set A [<<< [expr {$A + (($B & $C) | (~$B & $D)) + $x + 0x7a6d76e9}] $s]
    incr A $E
    set C [<<< $C 10]
}

proc ::ripemd::ripemd160::HHH {a b c d e x s} {
    upvar $a A $b B $c C $d D $e E
    set A [<<< [expr {$A + (($B | ~$C) ^ $D) + $x + 0x6d703ef3}] $s]
    incr A $E
    set C [<<< $C 10]
}

proc ::ripemd::ripemd160::III {a b c d e x s} {
    upvar $a A $b B $c C $d D $e E
    set A [<<< [expr {$A + (($B & $D)|($C & ~$D)) + $x + 0x5c4dd124}] $s]
    incr A $E
    set C [<<< $C 10]

}

proc ::ripemd::ripemd160::JJJ {a b c d e x s} {
    upvar $a A $b B $c C $d D $e E
    set A [<<< [expr {$A + ($B ^ ($C | ~$D)) + $x + 0x50a28be6}] $s]
    incr A $E
    set C [<<< $C 10]
}

# 32bit rotate-left
proc ::ripemd::ripemd160::<<< {v n} {
    return [expr {((($v << $n) \
                        | (($v >> (32 - $n)) \
                               & (0x7FFFFFFF >> (31 - $n))))) \
                      & 0xFFFFFFFF}]
}

# -------------------------------------------------------------------------
# Inline the algorithm functions
#
# On my test system inlining the functions like this improves
#   time {ripmd::ripmd160 [string repeat a 100]} 100
# from 28ms per iteration to 13ms per iteration.
#
# This means that the functions above (F - J, FF - JJ and FFF-JJJ) are
# not actually required for the code to operate. However, they provide
# a readable way to document what is going on so have been left in.
#
namespace eval ::ripemd::ripemd160 {

    # Inline function FF and FFF
    set Split {(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)}
    
    regsub -all -line \
        "^\\s+FFF?\\s+$Split$" \
        $RIPEMD160Hash_body \
        {set \1 [<<< [expr {$\1 + ($\2 ^ $\3 ^ $\4) + \6}] \7];\
             incr \1 $\5; set \3 [<<< $\3 10]} \
        RIPEMD160Hash_body
    
    # Inline function GG
    regsub -all -line \
        "^\\s+GG\\s+$Split$" \
        $RIPEMD160Hash_body \
        {set \1 [<<< [expr {$\1 + (($\2 \& $\3) | (~$\2 \& $\4)) + \6 \
                                + 0x5a827999}] \7];\
             incr \1 $\5; set \3 [<<< $\3 10]} \
        RIPEMD160Hash_body

    # Inline function GGG
    regsub -all -line \
        "^\\s+GGG\\s+$Split$" \
        $RIPEMD160Hash_body \
        {set \1 [<<< [expr {$\1 + (($\2 \& $\3) | (~$\2 \& $\4)) + \6 \
                                + 0x7a6d76e9}] \7];\
             incr \1 $\5; set \3 [<<< $\3 10]} \
        RIPEMD160Hash_body

    # Inline function HH
    regsub -all -line \
        "^\\s+HH\\s+$Split$" \
        $RIPEMD160Hash_body \
        {set \1 [<<< [expr {$\1 + (($\2 | ~$\3) ^ $\4) + \6 \
                                + 0x6ed9eba1}] \7];\
             incr \1 $\5; set \3 [<<< $\3 10]} \
        RIPEMD160Hash_body

    # Inline function HHH
    regsub -all -line \
        "^\\s+HHH\\s+$Split$" \
        $RIPEMD160Hash_body \
        {set \1 [<<< [expr {$\1 + (($\2 | ~$\3) ^ $\4) + \6 \
                                + 0x6d703ef3}] \7];\
             incr \1 $\5; set \3 [<<< $\3 10]} \
        RIPEMD160Hash_body

    # Inline function II
    regsub -all -line \
        "^\\s+II\\s+$Split$" \
        $RIPEMD160Hash_body \
        {set \1 [<<< [expr {$\1 + (($\2 \& $\4) | ($\3 \& ~$\4)) + \6 \
                                + 0x8f1bbcdc}] \7];\
             incr \1 $\5; set \3 [<<< $\3 10]} \
        RIPEMD160Hash_body

    # Inline function III
    regsub -all -line \
        "^\\s+III\\s+$Split$" \
        $RIPEMD160Hash_body \
        {set \1 [<<< [expr {$\1 + (($\2 \& $\4) | ($\3 \& ~$\4)) + \6 \
                                + 0x5c4dd124}] \7];\
             incr \1 $\5; set \3 [<<< $\3 10]} \
        RIPEMD160Hash_body

    # Inline function JJ
    regsub -all -line \
        "^\\s+JJ\\s+$Split$" \
        $RIPEMD160Hash_body \
        {set \1 [<<< [expr {$\1 + ($\2 ^ ($\3 | ~$\4)) + \6 \
                                + 0xa953fd4e}] \7];\
             incr \1 $\5; set \3 [<<< $\3 10]} \
        RIPEMD160Hash_body

    # Inline function JJJ
    regsub -all -line \
        "^\\s+JJJ\\s+$Split$" \
        $RIPEMD160Hash_body \
        {set \1 [<<< [expr {$\1 + ($\2 ^ ($\3 | ~$\4)) + \6 \
                                + 0x50a28be6}] \7];\
             incr \1 $\5; set \3 [<<< $\3 10]} \
        RIPEMD160Hash_body

    # Inline simple <<<
    regsub -all -line \
        {\[<<< (\$\S+)\s+(\d+)\]$} \
        $RIPEMD160Hash_body \
        {[expr {(((\1 << \2) \
                      | ((\1 >> (32 - \2)) \
                             \& (0x7FFFFFFF >> (31 - \2))))) \
                    \& 0xFFFFFFFF}]} \
        RIPEMD160Hash_body
}

# -------------------------------------------------------------------------

# Define the hashing procedure with inline functions.
proc ::ripemd::ripemd160::RIPEMD160Hash {token msg} \
    $::ripemd::ripemd160::RIPEMD160Hash_body

unset ::ripemd::ripemd160::RIPEMD160Hash_body

# -------------------------------------------------------------------------

proc ::ripemd::ripemd160::Hex {data} {
    binary scan $data H* result
    return $result
}

# -------------------------------------------------------------------------

# LoadAccelerator --
#
#	This package can make use of a number of compiled extensions to
#	accelerate the digest computation. This procedure manages the
#	use of these extensions within the package. During normal usage
#	this should not be called, but the test package manipulates the
#	list of enabled accelerators.
#
proc ::ripemd::ripemd160::LoadAccelerator {name} {
    variable accel
    set r 0
    switch -exact -- $name {
        #critcl {
        #    if {![catch {package require tcllibc}]
        #        || ![catch {package require sha1c}]} {
        #        set r [expr {[info commands ::sha1::sha1c] != {}}]
        #    }
        #}
        cryptkit {
            if {![catch {package require cryptkit}]} {
                set r [expr {![catch {cryptkit::cryptInit}]}]
            }
        }
        trf {
            if {![catch {package require Trf}]} {
                set r [expr {![catch {::ripemd160 aa} msg]}]
            }
        }
        default {
            return -code error "invalid accelerator package:\
                must be one of [join [array names accel] {, }]"
        }
    }
    set accel($name) $r
}

# -------------------------------------------------------------------------

# Description:
#  Pop the nth element off a list. Used in options processing.
#
proc ::ripemd::ripemd160::Pop {varname {nth 0}} {
    upvar $varname args
    set r [lindex $args $nth]
    set args [lreplace $args $nth $nth]
    return $r
}

# -------------------------------------------------------------------------

# fileevent handler for chunked file hashing.
#
proc ::ripemd::ripemd160::Chunk {token channel {chunksize 4096}} {
    # FRINK: nocheck
    variable $token
    upvar 0 $token state
    
    if {[eof $channel]} {
        fileevent $channel readable {}
        set state(reading) 0
    }
        
    RIPEMD160Update $token [read $channel $chunksize]
}

# -------------------------------------------------------------------------

proc ::ripemd::ripemd160::ripemd160 {args} {
    array set opts {-hex 0 -filename {} -channel {} -chunksize 4096}
    while {[string match -* [set option [lindex $args 0]]]} {
        switch -glob -- $option {
            -hex       { set opts(-hex) 1 }
            -file*     { set opts(-filename) [Pop args 1] }
            -channel   { set opts(-channel) [Pop args 1] }
            -chunksize { set opts(-chunksize) [Pop args 1] }
            default {
                if {[llength $args] == 1} { break }
                if {[string compare $option "--"] == 0} { Pop args; break }
                set err [join [lsort [array names opts]] ", "]
                return -code error "bad option $option:\
                    must be one of $err"
            }
        }
        Pop args
    }

    if {$opts(-filename) != {}} {
        set opts(-channel) [open $opts(-filename) r]
        fconfigure $opts(-channel) -translation binary
    }

    if {$opts(-channel) == {}} {

        if {[llength $args] != 1} {
            return -code error "wrong # args:\
                should be \"ripemd160 ?-hex? -filename file | string\""
        }
        set tok [RIPEMD160Init]
        RIPEMD160Update $tok [lindex $args 0]
        set r [RIPEMD160Final $tok]

    } else {

        set tok [RIPEMD160Init]
        # FRINK: nocheck
        set [subst $tok](reading) 1
        fileevent $opts(-channel) readable \
            [list [namespace origin Chunk] \
                 $tok $opts(-channel) $opts(-chunksize)]
        vwait [subst $tok](reading)
        set r [RIPEMD160Final $tok]

        # If we opened the channel - we should close it too.
        if {$opts(-filename) != {}} {
            close $opts(-channel)
        }
    }
    
    if {$opts(-hex)} {
        set r [Hex $r]
    }
    return $r
}

# -------------------------------------------------------------------------

proc ::ripemd::ripemd160::hmac160 {args} {
    array set opts {-hex 0 -filename {} -channel {} -chunksize 4096}
    while {[string match -* [set option [lindex $args 0]]]} {
        switch -glob -- $option {
            -key       { set opts(-key) [Pop args 1] }
            -hex       { set opts(-hex) 1 }
            -file*     { set opts(-filename) [Pop args 1] }
            -channel   { set opts(-channel) [Pop args 1] }
            -chunksize { set opts(-chunksize) [Pop args 1] }
            default {
                if {[llength $args] == 1} { break }
                if {[string compare $option "--"] == 0} { Pop args; break }
                set err [join [lsort [array names opts]] ", "]
                return -code error "bad option $option:\
                    must be one of $err"
            }
        }
        Pop args
    }

    if {![info exists opts(-key)]} {
        return -code error "wrong # args:\
            should be \"hmac160 ?-hex? -key key -filename file | string\""
    }

    if {$opts(-filename) != {}} {
        set opts(-channel) [open $opts(-filename) r]
        fconfigure $opts(-channel) -translation binary
    }

    if {$opts(-channel) == {}} {

        if {[llength $args] != 1} {
            return -code error "wrong # args:\
                should be \"hmac160 ?-hex? -key key -filename file | string\""
        }
        set tok [RIPEHMAC160Init $opts(-key)]
        RIPEHMAC160Update $tok [lindex $args 0]
        set r [RIPEHMAC160Final $tok]

    } else {

        set tok [RIPEHMAC160Init $opts(-key)]
        # FRINK: nocheck
        set [subst $tok](reading) 1
        fileevent $opts(-channel) readable \
            [list [namespace origin Chunk] \
                 $tok $opts(-channel) $opts(-chunksize)]
        vwait [subst $tok](reading)
        set r [RIPEHMAC160Final $tok]

        # If we opened the channel - we should close it too.
        if {$opts(-filename) != {}} {
            close $opts(-channel)
        }
    }
    
    if {$opts(-hex)} {
        set r [Hex $r]
    }
    return $r
}

# -------------------------------------------------------------------------

namespace eval ::ripemd {

    namespace import -force [namespace current]::ripemd160::*

    namespace export ripemd160 hmac160 \
        RIPEMD160Init RIPEMD160Update RIPEMD160Final \
        RIPEHMAC160Init RIPEHMAC160Update RIPEHMAC160Final
}

# -------------------------------------------------------------------------

# Try and load a compiled extension to help.
namespace eval ::ripemd::ripemd160 {
    variable e {}
    foreach e {cryptkit trf} {
        if {[LoadAccelerator $e]} break
    }
    unset e
}

package provide ripemd160 1.0.5

# -------------------------------------------------------------------------
# Local Variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:


