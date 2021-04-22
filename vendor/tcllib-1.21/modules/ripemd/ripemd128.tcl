# ripemd128.tcl - Copyright (C) 2003 Pat Thoyts <patthoyts@users.sf.net>
#
# This is a Tcl-only implementation of the RIPEMD-128 hash algorithm as 
# described in [RIPE].
# Included is an implementation of keyed message authentication using 
# the RIPEMD-128 function [HMAC].
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

namespace eval ::ripemd {
    namespace eval ripemd128 {
        variable  accel
        array set accel {trf 0}

        variable uid
        if {![info exists uid]} {
            set uid 0
        }

        namespace export ripemd128 hmac128 Hex \
            RIPEMD128Init RIPEMD128Update RIPEMD128Final \
            RIPEHMAC128Init RIPEHMAC128Update RIPEHMAC128Final
    }
}

# -------------------------------------------------------------------------

# RIPEMD128Init - create and initialize an MD4 state variable. This will be
# cleaned up when we call MD4Final
#
proc ::ripemd::ripemd128::RIPEMD128Init {} {
    variable accel
    variable uid
    set token [namespace current]::[incr uid]
    upvar #0 $token state

    # Initialize RIPEMD-128 state structure (same as MD4).
    array set state \
        [list \
             A [expr {0x67452301}] \
             B [expr {0xefcdab89}] \
             C [expr {0x98badcfe}] \
             D [expr {0x10325476}] \
             n 0 i "" ]
    if {$accel(trf)} {
        set s {}
        switch -exact -- $::tcl_platform(platform) {
            windows { set s [open NUL w] }
            unix    { set s [open /dev/null w] }
        }
        if {$s != {}} {
            fconfigure $s -translation binary -buffering none
            ::ripemd128 -attach $s -mode write \
                -read-type variable \
                -read-destination [subst $token](trfread) \
                -write-type variable \
                -write-destination [subst $token](trfwrite)
            array set state [list trfread 0 trfwrite 0 trf $s]
        }
    }
    return $token
}

proc ::ripemd::ripemd128::RIPEMD128Update {token data} {
    upvar #0 $token state

    if {[info exists state(trf)]} {
        puts -nonewline $state(trf) $data
        return
    }

    # Update the state values
    incr state(n) [string length $data]
    append state(i) $data

    # Calculate the hash for any complete blocks
    set len [string length $state(i)]
    for {set n 0} {($n + 64) <= $len} {} {
        RIPEMD128Hash $token [string range $state(i) $n [incr n 64]]
    }

    # Adjust the state for the blocks completed.
    set state(i) [string range $state(i) $n end]
    return
}

proc ::ripemd::ripemd128::RIPEMD128Final {token} {
    upvar #0 $token state

    if {[info exists state(trf)]} {
        close $state(trf)
        set r $state(trfwrite)
        unset state
        return $r
    }

    # RFC1320:3.1 - Padding
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

    # RFC1320:3.2 - Append length in bits as little-endian wide int.
    append state(i) [binary format ii [expr {8 * $state(n)}] 0]

    # Calculate the hash for the remaining block.
    set len [string length $state(i)]
    for {set n 0} {($n + 64) <= $len} {} {
        RIPEMD128Hash $token [string range $state(i) $n [incr n 64]]
    }

    # RFC1320:3.5 - Output
    set r [bytes $state(A)][bytes $state(B)][bytes $state(C)][bytes $state(D)]
    unset state
    return $r
}

# -------------------------------------------------------------------------
# HMAC Hashed Message Authentication (RFC 2104)
#
# hmac = H(K xor opad, H(K xor ipad, text))
#
proc ::ripemd::ripemd128::RIPEHMAC128Init {K} {

    # Key K is adjusted to be 64 bytes long. If K is larger, then use
    # the RIPEMD-128 digest of K and pad this instead.
    set len [string length $K]
    if {$len > 64} {
        set tok [RIPEMD128Init]
        RIPEMD128Update $tok $K
        set K [RIPEMD128Final $tok]
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

    set tok [RIPEMD128Init]
    RIPEMD128Update $tok $Ki;                 # initialize with the inner pad
    
    # preserve the Ko value for the final stage.
    # FRINK: nocheck
    set [subst $tok](Ko) $Ko

    return $tok
}

proc ::ripemd::ripemd128::RIPEHMAC128Update {token data} {
    RIPEMD128Update $token $data
    return
}

proc ::ripemd::ripemd128::RIPEHMAC128Final {token} {
    # FRINK: nocheck
    variable $token
    upvar 0 $token state

    set tok [RIPEMD128Init];            # init the outer hashing function
    RIPEMD128Update $tok $state(Ko);    # prepare with the outer pad.
    RIPEMD128Update $tok [RIPEMD128Final $token];  # hash the inner result
    return [RIPEMD128Final $tok]
}

# -------------------------------------------------------------------------

set ::ripemd::ripemd128::RIPEMD128Hash_body {
    variable $token
    upvar 0 $token state

    # RFC1320:3.4 - Process Message in 16-Word Blocks
    binary scan $msg i* blocks
    foreach {X0 X1 X2 X3 X4 X5 X6 X7 X8 X9 X10 X11 X12 X13 X14 X15} $blocks {
        set A $state(A)   ;  set AA $state(A)
        set B $state(B)   ;  set BB $state(B)
        set C $state(C)   ;  set CC $state(C)
        set D $state(D)   ;  set DD $state(D)

        # Round 1 (track 1). 
        #    F(x,y,z) = x ^ y ^ z
        # Let [abcd x s] denote the operation
        #    a = (a + F(b,c,d) + X[x]) <<< s.
        # Do the following 16 operations.
        # [ABCD  0  11]  [DABC  1  14]  [CDAB  2 15]  [BCDA  3 12]
        set A [expr {($A + [F $B $C $D] + $X0)  <<< 11}]
        set D [expr {($D + [F $A $B $C] + $X1)  <<< 14}]
        set C [expr {($C + [F $D $A $B] + $X2)  <<< 15}]
        set B [expr {($B + [F $C $D $A] + $X3)  <<< 12}]
        # [ABCD  4  5]  [DABC  5  8]  [CDAB  6 7]  [BCDA  7 9]
        set A [expr {($A + [F $B $C $D] + $X4)  <<< 5}]
        set D [expr {($D + [F $A $B $C] + $X5)  <<< 8}]
        set C [expr {($C + [F $D $A $B] + $X6)  <<< 7}]
        set B [expr {($B + [F $C $D $A] + $X7)  <<< 9}]
        # [ABCD  8  11]  [DABC  9  13]  [CDAB 10 14]  [BCDA 11 15]
        set A [expr {($A + [F $B $C $D] + $X8)  <<< 11}]
        set D [expr {($D + [F $A $B $C] + $X9)  <<< 13}]
        set C [expr {($C + [F $D $A $B] + $X10) <<< 14}]
        set B [expr {($B + [F $C $D $A] + $X11) <<< 15}]
        # [ABCD 12  6]  [DABC 13  7]  [CDAB 14 9]  [BCDA 15 8]
        set A [expr {($A + [F $B $C $D] + $X12) <<< 6}]
        set D [expr {($D + [F $A $B $C] + $X13) <<< 7}]
        set C [expr {($C + [F $D $A $B] + $X14) <<< 9}]
        set B [expr {($B + [F $C $D $A] + $X15) <<< 8}]

        # Round 2 (track 1).
        #   G(x, y, z) = (x & y) | (~x & z)
        # Let [abcd k s] denote the operation
        #   a = (a + G(b,c,d) + X[k] + 5A827999) <<< s
        # Do the following 16 operations.
        # [ABCD  7  7]  [DABC  4  6]  [CDAB  13  8]  [BCDA 1 13]
        set A [expr {($A + [G $B $C $D] + $X7  + 0x5a827999) <<< 7}]
        set D [expr {($D + [G $A $B $C] + $X4  + 0x5a827999) <<< 6}]
        set C [expr {($C + [G $D $A $B] + $X13 + 0x5a827999) <<< 8}]
        set B [expr {($B + [G $C $D $A] + $X1  + 0x5a827999) <<< 13}]
        # [ABCD  10  11]  [DABC  6  9]  [CDAB  15  7]  [BCDA 3 15]
        set A [expr {($A + [G $B $C $D] + $X10 + 0x5a827999) <<< 11}]
        set D [expr {($D + [G $A $B $C] + $X6  + 0x5a827999) <<< 9}]
        set C [expr {($C + [G $D $A $B] + $X15 + 0x5a827999) <<< 7}]
        set B [expr {($B + [G $C $D $A] + $X3  + 0x5a827999) <<< 15}]
        # [ABCD 12  7]  [DABC  0  12]  [CDAB 9  15]  [BCDA 5 9]
        set A [expr {($A + [G $B $C $D] + $X12 + 0x5a827999) <<< 7}]
        set D [expr {($D + [G $A $B $C] + $X0  + 0x5a827999) <<< 12}]
        set C [expr {($C + [G $D $A $B] + $X9  + 0x5a827999) <<< 15}]
        set B [expr {($B + [G $C $D $A] + $X5  + 0x5a827999) <<< 9}]
        # [ABCD  2  11]  [DABC  14  7]  [CDAB 11  13]  [BCDA 8 12]
        set A [expr {($A + [G $B $C $D] + $X2  + 0x5a827999) <<< 11}]
        set D [expr {($D + [G $A $B $C] + $X14 + 0x5a827999) <<< 7}]
        set C [expr {($C + [G $D $A $B] + $X11 + 0x5a827999) <<< 13}]
        set B [expr {($B + [G $C $D $A] + $X8  + 0x5a827999) <<< 12}]
        
        # Round 3 (track 1).
        #   H(x,y,z) = (x | ~y) ^ z
        # Let [abcd k s] denote the operation
        #   a = (a + H(b,c,d) + X[k] + 6ED9EBA1) <<< s.
        # Do the following 16 operations.
        # [ABCD  3  11]  [DABC  10  13]  [CDAB  14 6]  [BCDA 4 7]
        set A [expr {($A + [H $B $C $D] + $X3  + 0x6ed9eba1) <<< 11}]
        set D [expr {($D + [H $A $B $C] + $X10 + 0x6ed9eba1) <<< 13}]
        set C [expr {($C + [H $D $A $B] + $X14 + 0x6ed9eba1) <<< 6}]
        set B [expr {($B + [H $C $D $A] + $X4  + 0x6ed9eba1) <<< 7}]
        # [ABCD  9  14]  [DABC 15  9]  [CDAB  8 13]  [BCDA 1 15]
        set A [expr {($A + [H $B $C $D] + $X9  + 0x6ed9eba1) <<< 14}]
        set D [expr {($D + [H $A $B $C] + $X15 + 0x6ed9eba1) <<< 9}]
        set C [expr {($C + [H $D $A $B] + $X8  + 0x6ed9eba1) <<< 13}]
        set B [expr {($B + [H $C $D $A] + $X1  + 0x6ed9eba1) <<< 15}]
        # [ABCD  2  14]  [DABC  7  8]  [CDAB  0 13]  [BCDA 6 6]
        set A [expr {($A + [H $B $C $D] + $X2  + 0x6ed9eba1) <<< 14}]
        set D [expr {($D + [H $A $B $C] + $X7  + 0x6ed9eba1) <<< 8}]
        set C [expr {($C + [H $D $A $B] + $X0  + 0x6ed9eba1) <<< 13}]
        set B [expr {($B + [H $C $D $A] + $X6  + 0x6ed9eba1) <<< 6}]
        # [ABCD  13  5]  [DABC 11  12]  [CDAB  5 7]  [BCDA 12  5]
        set A [expr {($A + [H $B $C $D] + $X13 + 0x6ed9eba1) <<< 5}]
        set D [expr {($D + [H $A $B $C] + $X11 + 0x6ed9eba1) <<< 12}]
        set C [expr {($C + [H $D $A $B] + $X5  + 0x6ed9eba1) <<< 7}]
        set B [expr {($B + [H $C $D $A] + $X12 + 0x6ed9eba1) <<< 5}]

        # Round 4 (track 1).
        #   I(x,y,z) = (x & z) | (y & ^ ~z)
        # Let [abcd k s] denote the operation
        #   a = (a + I(b,c,d) + X[k] + 8F1BBCDC) <<< s.
        # Do the following 16 operations.
        # [ABCD  1  11]  [DABC  9  12]  [CDAB  11 14]  [BCDA 10 15]
        set A [expr {($A + [I $B $C $D] + $X1  + 0x8f1bbcdc) <<< 11}]
        set D [expr {($D + [I $A $B $C] + $X9  + 0x8f1bbcdc) <<< 12}]
        set C [expr {($C + [I $D $A $B] + $X11 + 0x8f1bbcdc) <<< 14}]
        set B [expr {($B + [I $C $D $A] + $X10 + 0x8f1bbcdc) <<< 15}]
        # [ABCD  0  14]  [DABC 8  15]  [CDAB 12 9]  [BCDA 4 8]
        set A [expr {($A + [I $B $C $D] + $X0  + 0x8f1bbcdc) <<< 14}]
        set D [expr {($D + [I $A $B $C] + $X8  + 0x8f1bbcdc) <<< 15}]
        set C [expr {($C + [I $D $A $B] + $X12 + 0x8f1bbcdc) <<< 9}]
        set B [expr {($B + [I $C $D $A] + $X4  + 0x8f1bbcdc) <<< 8}]
        # [ABCD  13  9]  [DABC  3  14]  [CDAB  7 5]  [BCDA 15 6]
        set A [expr {($A + [I $B $C $D] + $X13 + 0x8f1bbcdc) <<< 9}]
        set D [expr {($D + [I $A $B $C] + $X3  + 0x8f1bbcdc) <<< 14}]
        set C [expr {($C + [I $D $A $B] + $X7  + 0x8f1bbcdc) <<< 5}]
        set B [expr {($B + [I $C $D $A] + $X15 + 0x8f1bbcdc) <<< 6}]
        # [ABCD  14  8]  [DABC 5  6]  [CDAB  6 5]  [BCDA 2 12]
        set A [expr {($A + [I $B $C $D] + $X14 + 0x8f1bbcdc) <<< 8}]
        set D [expr {($D + [I $A $B $C] + $X5  + 0x8f1bbcdc) <<< 6}]
        set C [expr {($C + [I $D $A $B] + $X6  + 0x8f1bbcdc) <<< 5}]
        set B [expr {($B + [I $C $D $A] + $X2  + 0x8f1bbcdc) <<< 12}]


        # Round 1 (track 2).
        #   I(x,y,z) = (x & z) | (y & ^ ~z)
        # Let [abcd k s] denote the operation
        #   a = (a + I(b,c,d) + X[k] + 50A28BE6) <<< s.
        # Do the following 16 operations.
        # [ABCD  5  8]  [DABC  14  9]  [CDAB  7 9]  [BCDA 0 11]
        set AA [expr {($AA + [I $BB $CC $DD] + $X5  + 0x50a28be6) <<< 8}]
        set DD [expr {($DD + [I $AA $BB $CC] + $X14 + 0x50a28be6) <<< 9}]
        set CC [expr {($CC + [I $DD $AA $BB] + $X7  + 0x50a28be6) <<< 9}]
        set BB [expr {($BB + [I $CC $DD $AA] + $X0  + 0x50a28be6) <<< 11}]
        # [ABCD  9  13]  [DABC 2  15]  [CDAB 11 15]  [BCDA 4 5]
        set AA [expr {($AA + [I $BB $CC $DD] + $X9  + 0x50a28be6) <<< 13}]
        set DD [expr {($DD + [I $AA $BB $CC] + $X2  + 0x50a28be6) <<< 15}]
        set CC [expr {($CC + [I $DD $AA $BB] + $X11 + 0x50a28be6) <<< 15}]
        set BB [expr {($BB + [I $CC $DD $AA] + $X4  + 0x50a28be6) <<< 5}]
        # [ABCD  13  7]  [DABC  6  7]  [CDAB  15 8]  [BCDA 8 11]
        set AA [expr {($AA + [I $BB $CC $DD] + $X13 + 0x50a28be6) <<< 7}]
        set DD [expr {($DD + [I $AA $BB $CC] + $X6  + 0x50a28be6) <<< 7}]
        set CC [expr {($CC + [I $DD $AA $BB] + $X15 + 0x50a28be6) <<< 8}]
        set BB [expr {($BB + [I $CC $DD $AA] + $X8  + 0x50a28be6) <<< 11}]
        # [ABCD  1  14]  [DABC 10  14]  [CDAB  3 12]  [BCDA 12 6]
        set AA [expr {($AA + [I $BB $CC $DD] + $X1  + 0x50a28be6) <<< 14}]
        set DD [expr {($DD + [I $AA $BB $CC] + $X10 + 0x50a28be6) <<< 14}]
        set CC [expr {($CC + [I $DD $AA $BB] + $X3  + 0x50a28be6) <<< 12}]
        set BB [expr {($BB + [I $CC $DD $AA] + $X12 + 0x50a28be6) <<< 6}]

        # Round 2 (track 2).
        #   H(x,y,z) = (x | ~y) ^ z
        # Let [abcd k s] denote the operation
        #   a = (a + H(b,c,d) + X[k] + 5C4DD124) <<< s.
        # Do the following 16 operations.
        # [ABCD  6  9]  [DABC  11  13]  [CDAB  3 15]  [BCDA 7 7]
        set AA [expr {($AA + [H $BB $CC $DD] + $X6  + 0x5c4dd124) <<< 9}]
        set DD [expr {($DD + [H $AA $BB $CC] + $X11 + 0x5c4dd124) <<< 13}]
        set CC [expr {($CC + [H $DD $AA $BB] + $X3  + 0x5c4dd124) <<< 15}]
        set BB [expr {($BB + [H $CC $DD $AA] + $X7  + 0x5c4dd124) <<< 7}]
        # [ABCD  0  12]  [DABC 13  8]  [CDAB 5 9]  [BCDA 10 11]
        set AA [expr {($AA + [H $BB $CC $DD] + $X0  + 0x5c4dd124) <<< 12}]
        set DD [expr {($DD + [H $AA $BB $CC] + $X13 + 0x5c4dd124) <<< 8}]
        set CC [expr {($CC + [H $DD $AA $BB] + $X5  + 0x5c4dd124) <<< 9}]
        set BB [expr {($BB + [H $CC $DD $AA] + $X10 + 0x5c4dd124) <<< 11}]
        # [ABCD  14  7]  [DABC  15  7]  [CDAB  8 12]  [BCDA 12 7]
        set AA [expr {($AA + [H $BB $CC $DD] + $X14 + 0x5c4dd124) <<< 7}]
        set DD [expr {($DD + [H $AA $BB $CC] + $X15 + 0x5c4dd124) <<< 7}]
        set CC [expr {($CC + [H $DD $AA $BB] + $X8  + 0x5c4dd124) <<< 12}]
        set BB [expr {($BB + [H $CC $DD $AA] + $X12 + 0x5c4dd124) <<< 7}]
        # [ABCD  4  6]  [DABC 9  15]  [CDAB  1 13]  [BCDA 2 11]
        set AA [expr {($AA + [H $BB $CC $DD] + $X4  + 0x5c4dd124) <<< 6}]
        set DD [expr {($DD + [H $AA $BB $CC] + $X9  + 0x5c4dd124) <<< 15}]
        set CC [expr {($CC + [H $DD $AA $BB] + $X1  + 0x5c4dd124) <<< 13}]
        set BB [expr {($BB + [H $CC $DD $AA] + $X2  + 0x5c4dd124) <<< 11}]

        # Round 3 (track 2).
        #   G(x, y, z) = (x & y) | (~x & z)
        # Let [abcd k s] denote the operation
        #   a = (a + G(b,c,d) + X[k] + 6D703EF3) <<< s.
        # Do the following 16 operations.
        # [ABCD  15  9]  [DABC  5 7]  [CDAB  1 15]  [BCDA 3 11]
        set AA [expr {($AA + [G $BB $CC $DD] + $X15 + 0x6d703ef3) <<< 9}]
        set DD [expr {($DD + [G $AA $BB $CC] + $X5  + 0x6d703ef3) <<< 7}]
        set CC [expr {($CC + [G $DD $AA $BB] + $X1  + 0x6d703ef3) <<< 15}]
        set BB [expr {($BB + [G $CC $DD $AA] + $X3  + 0x6d703ef3) <<< 11}]
        # [ABCD  7  8]  [DABC 14  6]  [CDAB 6 6]  [BCDA 9 14]
        set AA [expr {($AA + [G $BB $CC $DD] + $X7  + 0x6d703ef3) <<< 8}]
        set DD [expr {($DD + [G $AA $BB $CC] + $X14 + 0x6d703ef3) <<< 6}]
        set CC [expr {($CC + [G $DD $AA $BB] + $X6  + 0x6d703ef3) <<< 6}]
        set BB [expr {($BB + [G $CC $DD $AA] + $X9  + 0x6d703ef3) <<< 14}]
        # [ABCD  11  12]  [DABC  8  13]  [CDAB  12 5]  [BCDA 2 14]
        set AA [expr {($AA + [G $BB $CC $DD] + $X11 + 0x6d703ef3) <<< 12}]
        set DD [expr {($DD + [G $AA $BB $CC] + $X8  + 0x6d703ef3) <<< 13}]
        set CC [expr {($CC + [G $DD $AA $BB] + $X12 + 0x6d703ef3) <<< 5}]
        set BB [expr {($BB + [G $CC $DD $AA] + $X2  + 0x6d703ef3) <<< 14}]
        # [ABCD  10  13]  [DABC 0  13]  [CDAB  4 7]  [BCDA 13 5]
        set AA [expr {($AA + [G $BB $CC $DD] + $X10 + 0x6d703ef3) <<< 13}]
        set DD [expr {($DD + [G $AA $BB $CC] + $X0  + 0x6d703ef3) <<< 13}]
        set CC [expr {($CC + [G $DD $AA $BB] + $X4  + 0x6d703ef3) <<< 7}]
        set BB [expr {($BB + [G $CC $DD $AA] + $X13 + 0x6d703ef3) <<< 5}]

        # Round 4 (track 2).
        #   F(x,y,z) = x ^ y ^ z
        # Let [abcd k s] denote the operation
        #   a = (a + F(b,c,d) + X[k]) <<< s.
        # Do the following 16 operations.
        # [ABCD  8  15]  [DABC  6 5]  [CDAB  4 8]  [BCDA 1 11]
        set AA [expr {($AA + [F $BB $CC $DD] + $X8)  <<< 15}]
        set DD [expr {($DD + [F $AA $BB $CC] + $X6)  <<< 5}]
        set CC [expr {($CC + [F $DD $AA $BB] + $X4)  <<< 8}]
        set BB [expr {($BB + [F $CC $DD $AA] + $X1)  <<< 11}]
        # [ABCD  3  14]  [DABC 11 14]  [CDAB 15 6]  [BCDA 0 14]
        set AA [expr {($AA + [F $BB $CC $DD] + $X3)  <<< 14}]
        set DD [expr {($DD + [F $AA $BB $CC] + $X11) <<< 14}]
        set CC [expr {($CC + [F $DD $AA $BB] + $X15) <<< 6}]
        set BB [expr {($BB + [F $CC $DD $AA] + $X0)  <<< 14}]
        # [ABCD  5  6]  [DABC  12 9]  [CDAB  2 12]  [BCDA 13 9]
        set AA [expr {($AA + [F $BB $CC $DD] + $X5)  <<< 6}]
        set DD [expr {($DD + [F $AA $BB $CC] + $X12) <<< 9}]
        set CC [expr {($CC + [F $DD $AA $BB] + $X2)  <<< 12}]
        set BB [expr {($BB + [F $CC $DD $AA] + $X13) <<< 9}]
        # [ABCD  9  12]  [DABC 7  5]  [CDAB  10 15]  [BCDA 14 8]
        set AA [expr {($AA + [F $BB $CC $DD] + $X9)  <<< 12}]
        set DD [expr {($DD + [F $AA $BB $CC] + $X7)  <<< 5}]
        set CC [expr {($CC + [F $DD $AA $BB] + $X10) <<< 15}]
        set BB [expr {($BB + [F $CC $DD $AA] + $X14) <<< 8}]

        # Then perform the following additions to combine the results.
        set DD       [expr {$state(B) + $C + $DD}]
        set state(B) [expr {$state(C) + $D + $AA}]
        set state(C) [expr {$state(D) + $A + $BB}]
        set state(D) [expr {$state(A) + $B + $CC}]
        set state(A) $DD
    }

    return
}

proc ::ripemd::ripemd128::byte {n v} {expr {((0xFF << (8 * $n)) & $v) >> (8 * $n)}}
proc ::ripemd::ripemd128::bytes {v} { 
    #format %c%c%c%c [byte 0 $v] [byte 1 $v] [byte 2 $v] [byte 3 $v]
    format %c%c%c%c \
        [expr {0xFF & $v}] \
        [expr {(0xFF00 & $v) >> 8}] \
        [expr {(0xFF0000 & $v) >> 16}] \
        [expr {((0xFF000000 & $v) >> 24) & 0xFF}]
}

# 32bit rotate-left
proc ::ripemd::ripemd128::<<< {v n} {
    return [expr {((($v << $n) \
                        | (($v >> (32 - $n)) \
                               & (0x7FFFFFFF >> (31 - $n))))) \
                      & 0xFFFFFFFF}]
}

# Convert our <<< pseudo-operator into a procedure call.
regsub -all -line \
    {\[expr {(.*) <<< (\d+)}\]} \
    $::ripemd::ripemd128::RIPEMD128Hash_body \
    {[<<< [expr {\1}] \2]} \
    ::ripemd::ripemd128::RIPEMD128Hash_body

#  F(x,y,z) = x ^ y ^ z
proc ::ripemd::ripemd128::F {X Y Z} {
    return [expr {$X ^ $Y ^ $Z}]
}
# Inline the F function F
regsub -all -line \
    {\[F (\$[ABCD]{1,2}) (\$[ABCD]{1,2}) (\$[ABCD]{1,2})\]} \
    $::ripemd::ripemd128::RIPEMD128Hash_body \
    {(\1 ^ \2 ^ \3)} \
    ::ripemd::ripemd128::RIPEMD128Hash_body
    
# G(x,y,z) = (x & y) | (~x & z)
proc ::ripemd::ripemd128::G {X Y Z} {
    return [expr {($X & $Y) | (~$X & $Z)}]
}
# Inline the G function
regsub -all -line \
    {\[G (\$[ABCD]{1,2}) (\$[ABCD]{1,2}) (\$[ABCD]{1,2})\]} \
    $::ripemd::ripemd128::RIPEMD128Hash_body \
    {((\1 \& \2) | (~\1 \& \3))} \
    ::ripemd::ripemd128::RIPEMD128Hash_body

# H(x,y,z) = (x | ~y) ^ z
proc ::ripemd::ripemd128::H {X Y Z} {
    return [expr {($X | ~$Y) ^ $Z}]
}
# Inline the H function
regsub -all -line \
    {\[H (\$[ABCD]{1,2}) (\$[ABCD]{1,2}) (\$[ABCD]{1,2})\]} \
    $::ripemd::ripemd128::RIPEMD128Hash_body \
    {( (\1 | ~\2) ^ \3)} \
    ::ripemd::ripemd128::RIPEMD128Hash_body

# I(x,y,z) = (x & z) | (y & ~z)
proc ::ripemd::ripemd128::I {X Y Z} {
    return [expr {($X & $Z) | ($Y & ~$Z)}]
}
# Inline the I function
regsub -all -line \
    {\[I (\$[ABCD]{1,2}) (\$[ABCD]{1,2}) (\$[ABCD]{1,2})\]} \
    $::ripemd::ripemd128::RIPEMD128Hash_body \
    {( (\1 \& \3) | (\2 \& ~\3) )} \
    ::ripemd::ripemd128::RIPEMD128Hash_body

# Define the MD4 hashing procedure with inline functions.
proc ::ripemd::ripemd128::RIPEMD128Hash {token msg} \
    $::ripemd::ripemd128::RIPEMD128Hash_body

unset ::ripemd::ripemd128::RIPEMD128Hash_body

# -------------------------------------------------------------------------

proc ::ripemd::ripemd128::Hex {data} {
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
proc ::ripemd::ripemd128::LoadAccelerator {name} {
    variable accel
    set r 0
    switch -exact -- $name {
        #critcl {
        #    if {![catch {package require tcllibc}]
        #        || ![catch {package require sha1c}]} {
        #        set r [expr {[info commands ::sha1::sha1c] != {}}]
        #    }
        #}
        #cryptkit {
        #    if {![catch {package require cryptkit}]} {
        #        set r [expr {![catch {cryptkit::cryptInit}]}]
        #    }
        #}
        trf {
            if {![catch {package require Trf}]} {
                set r [expr {![catch {::ripemd128 aa} msg]}]
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
proc ::ripemd::ripemd128::Pop {varname {nth 0}} {
    upvar $varname args
    set r [lindex $args $nth]
    set args [lreplace $args $nth $nth]
    return $r
}

# -------------------------------------------------------------------------

# fileevent handler for chunked file hashing.
#
proc ::ripemd::ripemd128::Chunk {token channel {chunksize 4096}} {
    # FRINK: nocheck
    variable $token
    upvar 0 $token state
    
    if {[eof $channel]} {
        fileevent $channel readable {}
        set state(reading) 0
    }
        
    RIPEMD128Update $token [read $channel $chunksize]
}

# -------------------------------------------------------------------------

proc ::ripemd::ripemd128::ripemd128 {args} {
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
                should be \"ripemd128 ?-hex? -filename file | string\""
        }
        set tok [RIPEMD128Init]
        RIPEMD128Update $tok [lindex $args 0]
        set r [RIPEMD128Final $tok]

    } else {

        set tok [RIPEMD128Init]
        # FRINK: nocheck
        set [subst $tok](reading) 1
        fileevent $opts(-channel) readable \
            [list [namespace origin Chunk] \
                 $tok $opts(-channel) $opts(-chunksize)]
        vwait [subst $tok](reading)
        set r [RIPEMD128Final $tok]

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

proc ::ripemd::ripemd128::hmac128 {args} {
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
            should be \"hmac128 ?-hex? -key key -filename file | string\""
    }

    if {$opts(-filename) != {}} {
        set opts(-channel) [open $opts(-filename) r]
        fconfigure $opts(-channel) -translation binary
    }

    if {$opts(-channel) == {}} {

        if {[llength $args] != 1} {
            return -code error "wrong # args:\
                should be \"hmac128 ?-hex? -key key -filename file | string\""
        }
        set tok [RIPEHMAC128Init $opts(-key)]
        RIPEHMAC128Update $tok [lindex $args 0]
        set r [RIPEHMAC128Final $tok]

    } else {

        set tok [RIPEHMAC128Init $opts(-key)]
        # FRINK: nocheck
        set [subst $tok](reading) 1
        fileevent $opts(-channel) readable \
            [list [namespace origin Chunk] \
                 $tok $opts(-channel) $opts(-chunksize)]
        vwait [subst $tok](reading)
        set r [RIPEHMAC128Final $tok]

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

    namespace import -force [namespace current]::ripemd128::*

    namespace export ripemd128 hmac128 \
        RIPEMD128Init RIPEMD128Update RIPEMD128Final \
        RIPEHMAC128Init RIPEHMAC128Update RIPEHMAC128Final
}

# -------------------------------------------------------------------------

# Try and load a compiled extension to help.
namespace eval ::ripemd::ripemd128 {
    variable e {}
    foreach e {trf} {
        if {[LoadAccelerator $e]} break
    }
    unset e
}

package provide ripemd128 1.0.5

# -------------------------------------------------------------------------
# Local Variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
