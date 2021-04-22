# md4.tcl - Copyright (C) 2003 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# This is a Tcl-only implementation of the MD4 hash algorithm as described in 
# RFC 1320 ( http://www.ietf.org/rfc/rfc1320.txt )
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

package require Tcl 8.2;                # tcl minimum version

# @mdgen EXCLUDE: md4c.tcl

namespace eval ::md4 {
    variable  accel
    array set accel {critcl 0 cryptkit 0}

    namespace export md4 hmac MD4Init MD4Update MD4Final

    variable uid
    if {![info exists uid]} {
        set uid 0
    }
}

# -------------------------------------------------------------------------

# MD4Init - create and initialize an MD4 state variable. This will be
# cleaned up when we call MD4Final
#
proc ::md4::MD4Init {} {
    variable uid
    variable accel
    set token [namespace current]::[incr uid]
    upvar #0 $token state

    # RFC1320:3.3 - Initialize MD4 state structure
    array set state \
        [list \
             A [expr {0x67452301}] \
             B [expr {0xefcdab89}] \
             C [expr {0x98badcfe}] \
             D [expr {0x10325476}] \
             n 0 i "" ]
    if {$accel(cryptkit)} {
        cryptkit::cryptCreateContext state(ckctx) CRYPT_UNUSED CRYPT_ALGO_MD4
    }
    return $token
}

proc ::md4::MD4Update {token data} {
    variable accel
    upvar #0 $token state

    if {$accel(critcl)} {
        if {[info exists state(md4c)]} {
            set state(md4c) [md4c $data $state(md4c)]
        } else {
            set state(md4c) [md4c $data]
        }
        return
    } elseif {[info exists state(ckctx)]} {
        if {[string length $data] > 0} {
            cryptkit::cryptEncrypt $state(ckctx) $data
        }
        return
    }

    # Update the state values
    incr state(n) [string length $data]
    append state(i) $data

    # Calculate the hash for any complete blocks
    set len [string length $state(i)]
    for {set n 0} {($n + 64) <= $len} {} {
        MD4Hash $token [string range $state(i) $n [incr n 64]]
    }

    # Adjust the state for the blocks completed.
    set state(i) [string range $state(i) $n end]
    return
}

proc ::md4::MD4Final {token} {
    upvar #0 $token state

    if {[info exists state(md4c)]} {
        set r $state(md4c)
        unset state
        return $r
    } elseif {[info exists state(ckctx)]} {
        cryptkit::cryptEncrypt $state(ckctx) ""
        cryptkit::cryptGetAttributeString $state(ckctx) \
            CRYPT_CTXINFO_HASHVALUE r 16
        cryptkit::cryptDestroyContext $state(ckctx)
        # If nothing was hashed, we get no r variable set!
        if {[info exists r]} {
            unset state
            return $r
        }
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
        MD4Hash $token [string range $state(i) $n [incr n 64]]
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
proc ::md4::HMACInit {K} {

    # Key K is adjusted to be 64 bytes long. If K is larger, then use
    # the MD4 digest of K and pad this instead.
    set len [string length $K]
    if {$len > 64} {
        set tok [MD4Init]
        MD4Update $tok $K
        set K [MD4Final $tok]
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

    set tok [MD4Init]
    MD4Update $tok $Ki;                 # initialize with the inner pad
    
    # preserve the Ko value for the final stage.
    # FRINK: nocheck
    set [subst $tok](Ko) $Ko

    return $tok
}

proc ::md4::HMACUpdate {token data} {
    MD4Update $token $data
    return
}

proc ::md4::HMACFinal {token} {
    # FRINK: nocheck
    variable $token
    upvar 0 $token state

    set tok [MD4Init];                  # init the outer hashing function
    MD4Update $tok $state(Ko);          # prepare with the outer pad.
    MD4Update $tok [MD4Final $token];   # hash the inner result
    return [MD4Final $tok]
}

# -------------------------------------------------------------------------

set ::md4::MD4Hash_body {
    variable $token
    upvar 0 $token state

    # RFC1320:3.4 - Process Message in 16-Word Blocks
    binary scan $msg i* blocks
    foreach {X0 X1 X2 X3 X4 X5 X6 X7 X8 X9 X10 X11 X12 X13 X14 X15} $blocks {
        set A $state(A)
        set B $state(B)
        set C $state(C)
        set D $state(D)

        # Round 1
        # Let [abcd k s] denote the operation
        #   a = (a + F(b,c,d) + X[k]) <<< s.
        # Do the following 16 operations.
        # [ABCD  0  3]  [DABC  1  7]  [CDAB  2 11]  [BCDA  3 19]
        set A [expr {($A + [F $B $C $D] + $X0) <<< 3}]
        set D [expr {($D + [F $A $B $C] + $X1) <<< 7}]
        set C [expr {($C + [F $D $A $B] + $X2) <<< 11}]
        set B [expr {($B + [F $C $D $A] + $X3) <<< 19}]
        # [ABCD  4  3]  [DABC  5  7]  [CDAB  6 11]  [BCDA  7 19]
        set A [expr {($A + [F $B $C $D] + $X4) <<< 3}]
        set D [expr {($D + [F $A $B $C] + $X5) <<< 7}]
        set C [expr {($C + [F $D $A $B] + $X6) <<< 11}]
        set B [expr {($B + [F $C $D $A] + $X7) <<< 19}]
        # [ABCD  8  3]  [DABC  9  7]  [CDAB 10 11]  [BCDA 11 19]
        set A [expr {($A + [F $B $C $D] + $X8) <<< 3}]
        set D [expr {($D + [F $A $B $C] + $X9) <<< 7}]
        set C [expr {($C + [F $D $A $B] + $X10) <<< 11}]
        set B [expr {($B + [F $C $D $A] + $X11) <<< 19}]
        # [ABCD 12  3]  [DABC 13  7]  [CDAB 14 11]  [BCDA 15 19]
        set A [expr {($A + [F $B $C $D] + $X12) <<< 3}]
        set D [expr {($D + [F $A $B $C] + $X13) <<< 7}]
        set C [expr {($C + [F $D $A $B] + $X14) <<< 11}]
        set B [expr {($B + [F $C $D $A] + $X15) <<< 19}]

        # Round 2.
        # Let [abcd k s] denote the operation
        #   a = (a + G(b,c,d) + X[k] + 5A827999) <<< s
        # Do the following 16 operations.
        # [ABCD  0  3]  [DABC  4  5]  [CDAB  8  9]  [BCDA 12 13]
        set A [expr {($A + [G $B $C $D] + $X0  + 0x5a827999) <<< 3}]
        set D [expr {($D + [G $A $B $C] + $X4  + 0x5a827999) <<< 5}]
        set C [expr {($C + [G $D $A $B] + $X8  + 0x5a827999) <<< 9}]
        set B [expr {($B + [G $C $D $A] + $X12 + 0x5a827999) <<< 13}]
        # [ABCD  1  3]  [DABC  5  5]  [CDAB  9  9]  [BCDA 13 13]
        set A [expr {($A + [G $B $C $D] + $X1  + 0x5a827999) <<< 3}]
        set D [expr {($D + [G $A $B $C] + $X5  + 0x5a827999) <<< 5}]
        set C [expr {($C + [G $D $A $B] + $X9  + 0x5a827999) <<< 9}]
        set B [expr {($B + [G $C $D $A] + $X13 + 0x5a827999) <<< 13}]
        # [ABCD  2  3]  [DABC  6  5]  [CDAB 10  9]  [BCDA 14 13]
        set A [expr {($A + [G $B $C $D] + $X2  + 0x5a827999) <<< 3}]
        set D [expr {($D + [G $A $B $C] + $X6  + 0x5a827999) <<< 5}]
        set C [expr {($C + [G $D $A $B] + $X10 + 0x5a827999) <<< 9}]
        set B [expr {($B + [G $C $D $A] + $X14 + 0x5a827999) <<< 13}]
        # [ABCD  3  3]  [DABC  7  5]  [CDAB 11  9]  [BCDA 15 13]
        set A [expr {($A + [G $B $C $D] + $X3  + 0x5a827999) <<< 3}]
        set D [expr {($D + [G $A $B $C] + $X7  + 0x5a827999) <<< 5}]
        set C [expr {($C + [G $D $A $B] + $X11 + 0x5a827999) <<< 9}]
        set B [expr {($B + [G $C $D $A] + $X15 + 0x5a827999) <<< 13}]
        
        # Round 3.
        # Let [abcd k s] denote the operation
        #   a = (a + H(b,c,d) + X[k] + 6ED9EBA1) <<< s.
        # Do the following 16 operations.
        # [ABCD  0  3]  [DABC  8  9]  [CDAB  4 11]  [BCDA 12 15]
        set A [expr {($A + [H $B $C $D] + $X0  + 0x6ed9eba1) <<< 3}]
        set D [expr {($D + [H $A $B $C] + $X8  + 0x6ed9eba1) <<< 9}]
        set C [expr {($C + [H $D $A $B] + $X4  + 0x6ed9eba1) <<< 11}]
        set B [expr {($B + [H $C $D $A] + $X12 + 0x6ed9eba1) <<< 15}]
        # [ABCD  2  3]  [DABC 10  9]  [CDAB  6 11]  [BCDA 14 15]
        set A [expr {($A + [H $B $C $D] + $X2  + 0x6ed9eba1) <<< 3}]
        set D [expr {($D + [H $A $B $C] + $X10 + 0x6ed9eba1) <<< 9}]
        set C [expr {($C + [H $D $A $B] + $X6  + 0x6ed9eba1) <<< 11}]
        set B [expr {($B + [H $C $D $A] + $X14 + 0x6ed9eba1) <<< 15}]
        # [ABCD  1  3]  [DABC  9  9]  [CDAB  5 11]  [BCDA 13 15]
        set A [expr {($A + [H $B $C $D] + $X1  + 0x6ed9eba1) <<< 3}]
        set D [expr {($D + [H $A $B $C] + $X9  + 0x6ed9eba1) <<< 9}]
        set C [expr {($C + [H $D $A $B] + $X5  + 0x6ed9eba1) <<< 11}]
        set B [expr {($B + [H $C $D $A] + $X13 + 0x6ed9eba1) <<< 15}]
        # [ABCD  3  3]  [DABC 11  9]  [CDAB  7 11]  [BCDA 15 15]
        set A [expr {($A + [H $B $C $D] + $X3  + 0x6ed9eba1) <<< 3}]
        set D [expr {($D + [H $A $B $C] + $X11 + 0x6ed9eba1) <<< 9}]
        set C [expr {($C + [H $D $A $B] + $X7  + 0x6ed9eba1) <<< 11}]
        set B [expr {($B + [H $C $D $A] + $X15 + 0x6ed9eba1) <<< 15}]

        # Then perform the following additions. (That is, increment each
        # of the four registers by the value it had before this block
        # was started.)
        incr state(A) $A
        incr state(B) $B
        incr state(C) $C
        incr state(D) $D
    }

    return
}

proc ::md4::byte {n v} {expr {((0xFF << (8 * $n)) & $v) >> (8 * $n)}}
proc ::md4::bytes {v} { 
    #format %c%c%c%c [byte 0 $v] [byte 1 $v] [byte 2 $v] [byte 3 $v]
    format %c%c%c%c \
        [expr {0xFF & $v}] \
        [expr {(0xFF00 & $v) >> 8}] \
        [expr {(0xFF0000 & $v) >> 16}] \
        [expr {((0xFF000000 & $v) >> 24) & 0xFF}]
}

# 32bit rotate-left
proc ::md4::<<< {v n} {
    return [expr {((($v << $n) \
                        | (($v >> (32 - $n)) \
                               & (0x7FFFFFFF >> (31 - $n))))) \
                      & 0xFFFFFFFF}]
}

# Convert our <<< pseudo-operator into a procedure call.
regsub -all -line \
    {\[expr {(.*) <<< (\d+)}\]} \
    $::md4::MD4Hash_body \
    {[<<< [expr {\1}] \2]} \
    ::md4::MD4Hash_body

# RFC1320:3.4 - function F
proc ::md4::F {X Y Z} {
    return [expr {($X & $Y) | ((~$X) & $Z)}]
}

# Inline the F function
regsub -all -line \
    {\[F (\$[ABCD]) (\$[ABCD]) (\$[ABCD])\]} \
    $::md4::MD4Hash_body \
    {( (\1 \& \2) | ((~\1) \& \3) )} \
    ::md4::MD4Hash_body
    
# RFC1320:3.4 - function G
proc ::md4::G {X Y Z} {
    return [expr {($X & $Y) | ($X & $Z) | ($Y & $Z)}]
}

# Inline the G function
regsub -all -line \
    {\[G (\$[ABCD]) (\$[ABCD]) (\$[ABCD])\]} \
    $::md4::MD4Hash_body \
    {((\1 \& \2) | (\1 \& \3) | (\2 \& \3))} \
    ::md4::MD4Hash_body

# RFC1320:3.4 - function H
proc ::md4::H {X Y Z} {
    return [expr {$X ^ $Y ^ $Z}]
}

# Inline the H function
regsub -all -line \
    {\[H (\$[ABCD]) (\$[ABCD]) (\$[ABCD])\]} \
    $::md4::MD4Hash_body \
    {(\1 ^ \2 ^ \3)} \
    ::md4::MD4Hash_body

# Define the MD4 hashing procedure with inline functions.
proc ::md4::MD4Hash {token msg} $::md4::MD4Hash_body
unset ::md4::MD4Hash_body

# -------------------------------------------------------------------------

if {[package provide Trf] != {}} {
    interp alias {} ::md4::Hex {} ::hex -mode encode --
} else {
    proc ::md4::Hex {data} {
        binary scan $data H* result
        return [string toupper $result]
    }
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
proc ::md4::LoadAccelerator {name} {
    variable accel
    set r 0
    switch -exact -- $name {
        critcl {
            if {![catch {package require tcllibc}]
                || ![catch {package require md4c}]} {
                set r [expr {[info commands ::md4::md4c] != {}}]
            }
        }
        cryptkit {
            if {![catch {package require cryptkit}]} {
                set r [expr {![catch {cryptkit::cryptInit}]}]
            }
        }
        #trf {
        #    if {![catch {package require Trf}]} {
        #        set r [expr {![catch {::md4 aa} msg]}]
        #    }
        #}
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
proc ::md4::Pop {varname {nth 0}} {
    upvar $varname args
    set r [lindex $args $nth]
    set args [lreplace $args $nth $nth]
    return $r
}

# -------------------------------------------------------------------------

# fileevent handler for chunked file hashing.
#
proc ::md4::Chunk {token channel {chunksize 4096}} {
    # FRINK: nocheck
    variable $token
    upvar 0 $token state
    
    if {[eof $channel]} {
        fileevent $channel readable {}
        set state(reading) 0
    }
        
    MD4Update $token [read $channel $chunksize]
}

# -------------------------------------------------------------------------

proc ::md4::md4 {args} {
    array set opts {-hex 0 -filename {} -channel {} -chunksize 4096}
    while {[string match -* [set option [lindex $args 0]]]} {
        switch -glob -- $option {
            -hex       { set opts(-hex) 1 }
            -file*     { set opts(-filename) [Pop args 1] }
            -channel   { set opts(-channel) [Pop args 1] }
            -chunksize { set opts(-chunksize) [Pop args 1] }
            default {
                if {[llength $args] == 1} { break }
                if {[string compare $option "--"] == 0 } { Pop args; break }
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
                should be \"md4 ?-hex? -filename file | string\""
        }
        set tok [MD4Init]
        MD4Update $tok [lindex $args 0]
        set r [MD4Final $tok]

    } else {

        set tok [MD4Init]
        # FRINK: nocheck
        set [subst $tok](reading) 1
        fileevent $opts(-channel) readable \
            [list [namespace origin Chunk] \
                 $tok $opts(-channel) $opts(-chunksize)]
        vwait [subst $tok](reading)
        set r [MD4Final $tok]

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

proc ::md4::hmac {args} {
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
                if {[string compare $option "--"] == 0 } { Pop args; break }
                set err [join [lsort [array names opts]] ", "]
                return -code error "bad option $option:\
                    must be one of $err"
            }
        }
        Pop args
    }

    if {![info exists opts(-key)]} {
        return -code error "wrong # args:\
            should be \"hmac ?-hex? -key key -filename file | string\""
    }

    if {$opts(-filename) != {}} {
        set opts(-channel) [open $opts(-filename) r]
        fconfigure $opts(-channel) -translation binary
    }

    if {$opts(-channel) == {}} {

        if {[llength $args] != 1} {
            return -code error "wrong # args:\
                should be \"hmac ?-hex? -key key -filename file | string\""
        }
        set tok [HMACInit $opts(-key)]
        HMACUpdate $tok [lindex $args 0]
        set r [HMACFinal $tok]

    } else {

        set tok [HMACInit $opts(-key)]
        # FRINK: nocheck
        set [subst $tok](reading) 1
        fileevent $opts(-channel) readable \
            [list [namespace origin Chunk] \
                 $tok $opts(-channel) $opts(-chunksize)]
        vwait [subst $tok](reading)
        set r [HMACFinal $tok]

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
# Try and load a compiled extension to help.
namespace eval ::md4 {
    variable e {}
    foreach e {critcl cryptkit} { if {[LoadAccelerator $e]} { break } }
    unset e
}

package provide md4 1.0.7

# -------------------------------------------------------------------------
# Local Variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:


