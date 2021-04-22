# sha256.tcl - Copyright (C) 2005 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# SHA1 defined by FIPS 180-2, "The Secure Hash Standard"
# HMAC defined by RFC 2104, "Keyed-Hashing for Message Authentication"
#
# This is an implementation of the secure hash algorithms specified in the
# FIPS 180-2 document.
#
# This implementation permits incremental updating of the hash and 
# provides support for external compiled implementations using critcl.
#
# This implementation permits incremental updating of the hash and 
# provides support for external compiled implementations either using
# critcl (sha256c).
#
# Ref: http://csrc.nist.gov/publications/fips/fips180-2/fips180-2.pdf
#      http://csrc.nist.gov/publications/fips/fips180-2/fips180-2withchangenotice.pdf
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------
# @mdgen EXCLUDE: sha256c.tcl

package require Tcl 8.2;                # tcl minimum version

namespace eval ::sha2 {
    variable  accel
    array set accel {tcl 0 critcl 0}
    variable  loaded {}

    namespace export sha256 hmac \
            SHA256Init SHA256Update SHA256Final


    variable uid
    if {![info exists uid]} {
        set uid 0
    }

    variable K
    if {![info exists K]} {
        # FIPS 180-2: 4.2.2 SHA-256 constants
        set K [list \
                   0x428a2f98 0x71374491 0xb5c0fbcf 0xe9b5dba5 \
                   0x3956c25b 0x59f111f1 0x923f82a4 0xab1c5ed5 \
                   0xd807aa98 0x12835b01 0x243185be 0x550c7dc3 \
                   0x72be5d74 0x80deb1fe 0x9bdc06a7 0xc19bf174 \
                   0xe49b69c1 0xefbe4786 0x0fc19dc6 0x240ca1cc \
                   0x2de92c6f 0x4a7484aa 0x5cb0a9dc 0x76f988da \
                   0x983e5152 0xa831c66d 0xb00327c8 0xbf597fc7 \
                   0xc6e00bf3 0xd5a79147 0x06ca6351 0x14292967 \
                   0x27b70a85 0x2e1b2138 0x4d2c6dfc 0x53380d13 \
                   0x650a7354 0x766a0abb 0x81c2c92e 0x92722c85 \
                   0xa2bfe8a1 0xa81a664b 0xc24b8b70 0xc76c51a3 \
                   0xd192e819 0xd6990624 0xf40e3585 0x106aa070 \
                   0x19a4c116 0x1e376c08 0x2748774c 0x34b0bcb5 \
                   0x391c0cb3 0x4ed8aa4a 0x5b9cca4f 0x682e6ff3 \
                   0x748f82ee 0x78a5636f 0x84c87814 0x8cc70208 \
                   0x90befffa 0xa4506ceb 0xbef9a3f7 0xc67178f2 \
                  ]
    }
    
}

# -------------------------------------------------------------------------
# Management of sha256 implementations.

# LoadAccelerator --
#
#	This package can make use of a number of compiled extensions to
#	accelerate the digest computation. This procedure manages the
#	use of these extensions within the package. During normal usage
#	this should not be called, but the test package manipulates the
#	list of enabled accelerators.
#
proc ::sha2::LoadAccelerator {name} {
    variable accel
    set r 0
    switch -exact -- $name {
        tcl {
            # Already present (this file)
            set r 1
        }
        critcl {
            if {![catch {package require tcllibc}]
                || ![catch {package require sha256c}]} {
                set r [expr {[info commands ::sha2::sha256c_update] != {}}]
            }
        }
        default {
            return -code error "invalid accelerator $key:\
                must be one of [join [KnownImplementations] {, }]"
        }
    }
    set accel($name) $r
    return $r
}

# ::sha2::Implementations --
#
#	Determines which implementations are
#	present, i.e. loaded.
#
# Arguments:
#	None.
#
# Results:
#	A list of implementation keys.

proc ::sha2::Implementations {} {
    variable accel
    set res {}
    foreach n [array names accel] {
	if {!$accel($n)} continue
	lappend res $n
    }
    return $res
}

# ::sha2::KnownImplementations --
#
#	Determines which implementations are known
#	as possible implementations.
#
# Arguments:
#	None.
#
# Results:
#	A list of implementation keys. In the order
#	of preference, most prefered first.

proc ::sha2::KnownImplementations {} {
    return {critcl tcl}
}

proc ::sha2::Names {} {
    return {
	critcl   {tcllibc based}
	tcl      {pure Tcl}
    }
}

# ::sha2::SwitchTo --
#
#	Activates a loaded named implementation.
#
# Arguments:
#	key	Name of the implementation to activate.
#
# Results:
#	None.

proc ::sha2::SwitchTo {key} {
    variable accel
    variable loaded

    if {[string equal $key $loaded]} {
	# No change, nothing to do.
	return
    } elseif {![string equal $key ""]} {
	# Validate the target implementation of the switch.

	if {![info exists accel($key)]} {
	    return -code error "Unable to activate unknown implementation \"$key\""
	} elseif {![info exists accel($key)] || !$accel($key)} {
	    return -code error "Unable to activate missing implementation \"$key\""
	}
    }

    # Deactivate the previous implementation, if there was any.

    if {![string equal $loaded ""]} {
        foreach c {
            SHA256Init   SHA224Init
            SHA256Final  SHA224Final
            SHA256Update
        } {
            interp alias {} ::sha2::$c {}
        }
    }

    # Activate the new implementation, if there is any.

    if {![string equal $key ""]} {
        foreach c {
            SHA256Init   SHA224Init
            SHA256Final  SHA224Final
            SHA256Update
        } {
	    interp alias {} ::sha2::$c {} ::sha2::${c}-${key}
        }
    }

    # Remember the active implementation, for deactivation by future
    # switches.

    set loaded $key
    return
}

# -------------------------------------------------------------------------

# SHA256Init --
#
#   Create and initialize an SHA256 state variable. This will be
#   cleaned up when we call SHA256Final
#

proc ::sha2::SHA256Init-tcl {} {
    variable uid
    set token [namespace current]::[incr uid]
    upvar #0 $token tok

    # FIPS 180-2: 5.3.2 Setting the initial hash value
    array set tok \
            [list \
            A [expr {int(0x6a09e667)}] \
            B [expr {int(0xbb67ae85)}] \
            C [expr {int(0x3c6ef372)}] \
            D [expr {int(0xa54ff53a)}] \
            E [expr {int(0x510e527f)}] \
            F [expr {int(0x9b05688c)}] \
            G [expr {int(0x1f83d9ab)}] \
            H [expr {int(0x5be0cd19)}] \
            n 0 i "" v 256]
    return $token
}

proc ::sha2::SHA256Init-critcl {} {
    variable uid
    set token [namespace current]::[incr uid]
    upvar #0 $token tok

    # FIPS 180-2: 5.3.2 Setting the initial hash value
    set tok(sha256c) [sha256c_init256]
    return $token
}

# SHA256Update --
#
#   This is called to add more data into the hash. You may call this
#   as many times as you require. Note that passing in "ABC" is equivalent
#   to passing these letters in as separate calls -- hence this proc 
#   permits hashing of chunked data
#
#   If we have a C-based implementation available, then we will use
#   it here in preference to the pure-Tcl implementation.
#

proc ::sha2::SHA256Update-tcl {token data} {
    upvar #0 $token state

    # Update the state values
    incr   state(n) [string length $data]
    append state(i) $data

    # Calculate the hash for any complete blocks
    set len [string length $state(i)]
    for {set n 0} {($n + 64) <= $len} {} {
        SHA256Transform $token [string range $state(i) $n [incr n 64]]
    }

    # Adjust the state for the blocks completed.
    set state(i) [string range $state(i) $n end]
    return
}

proc ::sha2::SHA256Update-critcl {token data} {
    upvar #0 $token state

    set state(sha256c) [sha256c_update $data $state(sha256c)]
    return
}

# SHA256Final --
#
#    This procedure is used to close the current hash and returns the
#    hash data. Once this procedure has been called the hash context
#    is freed and cannot be used again.
#
#    Note that the output is 256 bits represented as binary data.
#

proc ::sha2::SHA256Final-tcl {token} {
    upvar #0 $token state
    SHA256Penultimate $token
    
    # Output
    set r [bytes $state(A)][bytes $state(B)][bytes $state(C)][bytes $state(D)][bytes $state(E)][bytes $state(F)][bytes $state(G)][bytes $state(H)]
    unset state
    return $r
}

proc ::sha2::SHA256Final-critcl {token} {
    upvar #0 $token state
    set r $state(sha256c)
    unset  state
    return $r
}

# SHA256Penultimate --
#
#
proc ::sha2::SHA256Penultimate {token} {
    upvar #0 $token state

    # FIPS 180-2: 5.1.1: Padding the message
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

    # Append length in bits as big-endian wide int.
    set dlen [expr {8 * $state(n)}]
    append state(i) [binary format II 0 $dlen]

    # Calculate the hash for the remaining block.
    set len [string length $state(i)]
    for {set n 0} {($n + 64) <= $len} {} {
        SHA256Transform $token [string range $state(i) $n [incr n 64]]
    }
}

# -------------------------------------------------------------------------

proc ::sha2::SHA224Init-tcl {} {
    variable uid
    set token [namespace current]::[incr uid]
    upvar #0 $token tok

    # FIPS 180-2 (change notice 1) (1): SHA-224 initialization values
    array set tok \
            [list \
            A [expr {int(0xc1059ed8)}] \
            B [expr {int(0x367cd507)}] \
            C [expr {int(0x3070dd17)}] \
            D [expr {int(0xf70e5939)}] \
            E [expr {int(0xffc00b31)}] \
            F [expr {int(0x68581511)}] \
            G [expr {int(0x64f98fa7)}] \
            H [expr {int(0xbefa4fa4)}] \
            n 0 i "" v 224]
    return $token
}

proc ::sha2::SHA224Init-critcl {} {
    variable uid
    set token [namespace current]::[incr uid]
    upvar #0 $token tok

    # FIPS 180-2 (change notice 1) (1): SHA-224 initialization values
    set tok(sha256c) [sha256c_init224]
    return $token
}

interp alias {} ::sha2::SHA224Update {} ::sha2::SHA256Update

proc ::sha2::SHA224Final-tcl {token} {
    upvar #0 $token state
    SHA256Penultimate $token
    
    # Output
    set r [bytes $state(A)][bytes $state(B)][bytes $state(C)][bytes $state(D)][bytes $state(E)][bytes $state(F)][bytes $state(G)]
    unset state
    return $r
}

proc ::sha2::SHA224Final-critcl {token} {
    upvar #0 $token state
    # Trim result down to 224 bits (by 4 bytes).
    # See output below, A..G, not A..H
    set r [string range $state(sha256c) 0 end-4]
    unset state
    return $r
}

# -------------------------------------------------------------------------
# HMAC Hashed Message Authentication (RFC 2104)
#
# hmac = H(K xor opad, H(K xor ipad, text))
#

# HMACInit --
#
#    This is equivalent to the SHA1Init procedure except that a key is
#    added into the algorithm
#
proc ::sha2::HMACInit {K} {

    # Key K is adjusted to be 64 bytes long. If K is larger, then use
    # the SHA1 digest of K and pad this instead.
    set len [string length $K]
    if {$len > 64} {
        set tok [SHA256Init]
        SHA256Update $tok $K
        set K [SHA256Final $tok]
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

    set tok [SHA256Init]
    SHA256Update $tok $Ki;                 # initialize with the inner pad
    
    # preserve the Ko value for the final stage.
    # FRINK: nocheck
    set [subst $tok](Ko) $Ko

    return $tok
}

# HMACUpdate --
#
#    Identical to calling SHA256Update
#
proc ::sha2::HMACUpdate {token data} {
    SHA256Update $token $data
    return
}

# HMACFinal --
#
#    This is equivalent to the SHA256Final procedure. The hash context is
#    closed and the binary representation of the hash result is returned.
#
proc ::sha2::HMACFinal {token} {
    upvar #0 $token state

    set tok [SHA256Init];                 # init the outer hashing function
    SHA256Update $tok $state(Ko);         # prepare with the outer pad.
    SHA256Update $tok [SHA256Final $token]; # hash the inner result
    return [SHA256Final $tok]
}

# -------------------------------------------------------------------------
# Description:
#  This is the core SHA1 algorithm. It is a lot like the MD4 algorithm but
#  includes an extra round and a set of constant modifiers throughout.
#
set ::sha2::SHA256Transform_body {
    variable K
    upvar #0 $token state

    # FIPS 180-2: 6.2.2 SHA-256 Hash computation.
    binary scan $msg I* blocks
    set blockLen [llength $blocks]
    for {set i 0} {$i < $blockLen} {incr i 16} {
        set W [lrange $blocks $i [expr {$i+15}]]

        # FIPS 180-2: 6.2.2 (1) Prepare the message schedule
        # For t = 16 to 64 
        #   let Wt = (sigma1(Wt-2) + Wt-7 + sigma0(Wt-15) + Wt-16)
        set t2  13
        set t7   8
        set t15  0
        set t16 -1
        for {set t 16} {$t < 64} {incr t} {
            lappend W [expr {([sigma1 [lindex $W [incr t2]]] \
                                 + [lindex $W [incr t7]] \
                                 + [sigma0 [lindex $W [incr t15]]] \
                                 + [lindex $W [incr t16]]) & 0xffffffff}]
        }
        
        # FIPS 180-2: 6.2.2 (2) Initialise the working variables
        set A $state(A)
        set B $state(B)
        set C $state(C)
        set D $state(D)
        set E $state(E)
        set F $state(F)
        set G $state(G)
        set H $state(H)

        # FIPS 180-2: 6.2.2 (3) Do permutation rounds
        # For t = 0 to 63 do
        #   T1 = h + SIGMA1(e) + Ch(e,f,g) + Kt + Wt
        #   T2 = SIGMA0(a) + Maj(a,b,c)
        #   h = g; g = f;  f = e;  e = d + T1;  d = c;  c = b; b = a;
        #   a = T1 + T2
        #
        for {set t 0} {$t < 64} {incr t} {
            set T1 [expr {($H + [SIGMA1 $E] + [Ch $E $F $G] 
                          + [lindex $K $t] + [lindex $W $t]) & 0xffffffff}]
            set T2 [expr {([SIGMA0 $A] + [Maj $A $B $C]) & 0xffffffff}]
            set H $G
            set G $F
            set F $E
            set E [expr {($D + $T1) & 0xffffffff}]
            set D $C
            set C $B
            set B $A
            set A [expr {($T1 + $T2) & 0xffffffff}]
        }

        # FIPS 180-2: 6.2.2 (4) Compute the intermediate hash
        incr state(A) $A
        incr state(B) $B
        incr state(C) $C
        incr state(D) $D
        incr state(E) $E
        incr state(F) $F
        incr state(G) $G
        incr state(H) $H
    }

    return
}

# -------------------------------------------------------------------------

# FIPS 180-2: 4.1.2 equation 4.2
proc ::sha2::Ch {x y z} {
    return [expr {($x & $y) ^ (~$x & $z)}]
}

# FIPS 180-2: 4.1.2 equation 4.3
proc ::sha2::Maj {x y z} {
    return [expr {($x & $y) ^ ($x & $z) ^ ($y & $z)}]
}

# FIPS 180-2: 4.1.2 equation 4.4
#  (x >>> 2) ^ (x >>> 13) ^ (x >>> 22)
proc ::sha2::SIGMA0 {x} {
    return [expr {[>>> $x 2] ^ [>>> $x 13] ^ [>>> $x 22]}]
}

# FIPS 180-2: 4.1.2 equation 4.5
#  (x >>> 6) ^ (x >>> 11) ^ (x >>> 25)
proc ::sha2::SIGMA1 {x} {
    return [expr {[>>> $x 6] ^ [>>> $x 11] ^ [>>> $x 25]}]
}

# FIPS 180-2: 4.1.2 equation 4.6
#  s0 = (x >>> 7)  ^ (x >>> 18) ^ (x >> 3)
proc ::sha2::sigma0 {x} {
    #return [expr {[>>> $x 7] ^ [>>> $x 18] ^ (($x >> 3) & 0x1fffffff)}]
    return [expr {((($x<<25) | (($x>>7) & (0x7FFFFFFF>>6))) \
                 ^ (($x<<14) | (($x>>18) & (0x7FFFFFFF>>17))) & 0xFFFFFFFF) \
                 ^ (($x>>3) & 0x1fffffff)}]
}

# FIPS 180-2: 4.1.2 equation 4.7
#  s1 = (x >>> 17) ^ (x >>> 19) ^ (x >> 10)
proc ::sha2::sigma1 {x} {
    #return [expr {[>>> $x 17] ^ [>>> $x 19] ^ (($x >> 10) & 0x003fffff)}]
    return [expr {((($x<<15) | (($x>>17) & (0x7FFFFFFF>>16))) \
                 ^ (($x<<13) | (($x>>19) & (0x7FFFFFFF>>18))) & 0xFFFFFFFF) \
                 ^ (($x >> 10) & 0x003fffff)}]
}

# 32bit rotate-right
proc ::sha2::>>> {v n} {
    return [expr {(($v << (32 - $n)) \
                       | (($v >> $n) & (0x7FFFFFFF >> ($n - 1)))) \
                      & 0xFFFFFFFF}]
}

# 32bit rotate-left
proc ::sha2::<<< {v n} {
    return [expr {((($v << $n) \
                        | (($v >> (32 - $n)) \
                               & (0x7FFFFFFF >> (31 - $n))))) \
                      & 0xFFFFFFFF}]
}

# -------------------------------------------------------------------------
# We speed up the SHA256Transform code while maintaining readability in the
# source code by substituting inline for a number of functions.
# The idea is to reduce the number of [expr] calls.

# Inline the Ch function
regsub -all -line \
    {\[Ch (\$[ABCDEFGH]) (\$[ABCDEFGH]) (\$[ABCDEFGH])\]} \
    $::sha2::SHA256Transform_body \
    {((\1 \& \2) ^ ((~\1) \& \3))} \
    ::sha2::SHA256Transform_body

# Inline the Maj function
regsub -all -line \
    {\[Maj (\$[ABCDEFGH]) (\$[ABCDEFGH]) (\$[ABCDEFGH])\]} \
    $::sha2::SHA256Transform_body \
    {((\1 \& \2) ^ (\1 \& \3) ^ (\2 \& \3))} \
    ::sha2::SHA256Transform_body


# Inline the SIGMA0 function
regsub -all -line \
    {\[SIGMA0 (\$[ABCDEFGH])\]} \
    $::sha2::SHA256Transform_body \
    {((((\1<<30) | ((\1>>2) \& (0x7FFFFFFF>>1))) \& 0xFFFFFFFF) \
          ^ (((\1<<19) | ((\1>>13) \& (0x7FFFFFFF>>12))) \& 0xFFFFFFFF) \
          ^ (((\1<<10) | ((\1>>22) \& (0x7FFFFFFF>>21))) \& 0xFFFFFFFF) \
          )} \
    ::sha2::SHA256Transform_body

# Inline the SIGMA1 function
regsub -all -line \
    {\[SIGMA1 (\$[ABCDEFGH])\]} \
    $::sha2::SHA256Transform_body \
    {((((\1<<26) | ((\1>>6) \& (0x7FFFFFFF>>5))) \& 0xFFFFFFFF) \
          ^ (((\1<<21) | ((\1>>11) \& (0x7FFFFFFF>>10))) \& 0xFFFFFFFF) \
          ^ (((\1<<7) | ((\1>>25) \& (0x7FFFFFFF>>24))) \& 0xFFFFFFFF) \
          )} \
    ::sha2::SHA256Transform_body

proc ::sha2::SHA256Transform {token msg} $::sha2::SHA256Transform_body

# -------------------------------------------------------------------------

# Convert a integer value into a binary string in big-endian order.
proc ::sha2::byte {n v} {expr {((0xFF << (8 * $n)) & $v) >> (8 * $n)}}
proc ::sha2::bytes {v} { 
    #format %c%c%c%c [byte 3 $v] [byte 2 $v] [byte 1 $v] [byte 0 $v]
    format %c%c%c%c \
        [expr {((0xFF000000 & $v) >> 24) & 0xFF}] \
        [expr {(0xFF0000 & $v) >> 16}] \
        [expr {(0xFF00 & $v) >> 8}] \
        [expr {0xFF & $v}]
}

# -------------------------------------------------------------------------

proc ::sha2::Hex {data} {
    binary scan $data H* result
    return $result
}

# -------------------------------------------------------------------------

# Description:
#  Pop the nth element off a list. Used in options processing.
#
proc ::sha2::Pop {varname {nth 0}} {
    upvar $varname args
    set r [lindex $args $nth]
    set args [lreplace $args $nth $nth]
    return $r
}

# -------------------------------------------------------------------------

# fileevent handler for chunked file hashing.
#
proc ::sha2::Chunk {token channel {chunksize 4096}} {
    upvar #0 $token state
    
    SHA256Update $token [read $channel $chunksize]

    if {[eof $channel]} {
        fileevent $channel readable {}
        set state(reading) 0
    }
    return
}

# -------------------------------------------------------------------------

proc ::sha2::_sha256 {ver args} {
    array set opts {-hex 0 -filename {} -channel {} -chunksize 4096}
    if {[llength $args] == 1} {
        set opts(-hex) 1
    } else {
        while {[string match -* [set option [lindex $args 0]]]} {
            switch -glob -- $option {
                -hex       { set opts(-hex) 1 }
                -bin       { set opts(-hex) 0 }
                -file*     { set opts(-filename) [Pop args 1] }
                -channel   { set opts(-channel) [Pop args 1] }
                -chunksize { set opts(-chunksize) [Pop args 1] }
                default {
                    if {[llength $args] == 1} { break }
                    if {[string compare $option "--"] == 0} { Pop args; break }
                    set err [join [lsort [concat -bin [array names opts]]] ", "]
                    return -code error "bad option $option:\
                    must be one of $err"
                }
            }
            Pop args
        }
    }

    if {$opts(-filename) != {}} {
        set opts(-channel) [open $opts(-filename) r]
        fconfigure $opts(-channel) -translation binary
    }

    if {$opts(-channel) == {}} {
        if {[llength $args] != 1} {
            return -code error "wrong # args: should be\
                \"[namespace current]::sha$ver ?-hex|-bin? -filename file\
                | -channel channel | string\""
        }
        set tok [SHA${ver}Init]
        SHA${ver}Update $tok [lindex $args 0]
        set r [SHA${ver}Final $tok]

    } else {

        set tok [SHA${ver}Init]
        # FRINK: nocheck
        set [subst $tok](reading) 1
        fileevent $opts(-channel) readable \
            [list [namespace origin Chunk] \
                 $tok $opts(-channel) $opts(-chunksize)]
        # FRINK: nocheck
        vwait [subst $tok](reading)
        set r [SHA${ver}Final $tok]

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

interp alias {} ::sha2::sha256 {} ::sha2::_sha256 256
interp alias {} ::sha2::sha224 {} ::sha2::_sha256 224

# -------------------------------------------------------------------------

proc ::sha2::hmac {args} {
    array set opts {-hex 1 -filename {} -channel {} -chunksize 4096}
    if {[llength $args] != 2} {
        while {[string match -* [set option [lindex $args 0]]]} {
            switch -glob -- $option {
                -key       { set opts(-key) [Pop args 1] }
                -hex       { set opts(-hex) 1 }
                -bin       { set opts(-hex) 0 }
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
    }

    if {[llength $args] == 2} {
        set opts(-key) [Pop args]
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
        # FRINK: nocheck
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
namespace eval ::sha2 {
    variable e {}
    foreach e [KnownImplementations] {
	if {[LoadAccelerator $e]} {
	    SwitchTo $e
	    break
	}
    }
    unset e
}

package provide sha256 1.0.4

# -------------------------------------------------------------------------
# Local Variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
