# aes.tcl - 
#
# Copyright (c) 2005 Thorsten Schloermann
# Copyright (c) 2005 Pat Thoyts <patthoyts@users.sourceforge.net>
# Copyright (c) 2013 Andreas Kupries
#
# A Tcl implementation of the Advanced Encryption Standard (US FIPS PUB 197)
#
# AES is a block cipher with a block size of 128 bits and a variable
# key size of 128, 192 or 256 bits.
# The algorithm works on each block as a 4x4 state array. There are 4 steps
# in each round:
#   SubBytes    a non-linear substitution step using a predefined S-box
#   ShiftRows   cyclic transposition of rows in the state matrix
#   MixColumns  transformation upon columns in the state matrix
#   AddRoundKey application of round specific sub-key
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------

package require Tcl 8.5

namespace eval ::aes {
    variable uid
    if {![info exists uid]} { set uid 0 }

    namespace export aes

    # constants

    # S-box
    variable sbox {
        0x63 0x7c 0x77 0x7b 0xf2 0x6b 0x6f 0xc5 0x30 0x01 0x67 0x2b 0xfe 0xd7 0xab 0x76
        0xca 0x82 0xc9 0x7d 0xfa 0x59 0x47 0xf0 0xad 0xd4 0xa2 0xaf 0x9c 0xa4 0x72 0xc0
        0xb7 0xfd 0x93 0x26 0x36 0x3f 0xf7 0xcc 0x34 0xa5 0xe5 0xf1 0x71 0xd8 0x31 0x15
        0x04 0xc7 0x23 0xc3 0x18 0x96 0x05 0x9a 0x07 0x12 0x80 0xe2 0xeb 0x27 0xb2 0x75
        0x09 0x83 0x2c 0x1a 0x1b 0x6e 0x5a 0xa0 0x52 0x3b 0xd6 0xb3 0x29 0xe3 0x2f 0x84
        0x53 0xd1 0x00 0xed 0x20 0xfc 0xb1 0x5b 0x6a 0xcb 0xbe 0x39 0x4a 0x4c 0x58 0xcf
        0xd0 0xef 0xaa 0xfb 0x43 0x4d 0x33 0x85 0x45 0xf9 0x02 0x7f 0x50 0x3c 0x9f 0xa8
        0x51 0xa3 0x40 0x8f 0x92 0x9d 0x38 0xf5 0xbc 0xb6 0xda 0x21 0x10 0xff 0xf3 0xd2
        0xcd 0x0c 0x13 0xec 0x5f 0x97 0x44 0x17 0xc4 0xa7 0x7e 0x3d 0x64 0x5d 0x19 0x73
        0x60 0x81 0x4f 0xdc 0x22 0x2a 0x90 0x88 0x46 0xee 0xb8 0x14 0xde 0x5e 0x0b 0xdb
        0xe0 0x32 0x3a 0x0a 0x49 0x06 0x24 0x5c 0xc2 0xd3 0xac 0x62 0x91 0x95 0xe4 0x79
        0xe7 0xc8 0x37 0x6d 0x8d 0xd5 0x4e 0xa9 0x6c 0x56 0xf4 0xea 0x65 0x7a 0xae 0x08
        0xba 0x78 0x25 0x2e 0x1c 0xa6 0xb4 0xc6 0xe8 0xdd 0x74 0x1f 0x4b 0xbd 0x8b 0x8a
        0x70 0x3e 0xb5 0x66 0x48 0x03 0xf6 0x0e 0x61 0x35 0x57 0xb9 0x86 0xc1 0x1d 0x9e
        0xe1 0xf8 0x98 0x11 0x69 0xd9 0x8e 0x94 0x9b 0x1e 0x87 0xe9 0xce 0x55 0x28 0xdf
        0x8c 0xa1 0x89 0x0d 0xbf 0xe6 0x42 0x68 0x41 0x99 0x2d 0x0f 0xb0 0x54 0xbb 0x16
    }
    # inverse S-box
    variable xobs {
        0x52 0x09 0x6a 0xd5 0x30 0x36 0xa5 0x38 0xbf 0x40 0xa3 0x9e 0x81 0xf3 0xd7 0xfb
        0x7c 0xe3 0x39 0x82 0x9b 0x2f 0xff 0x87 0x34 0x8e 0x43 0x44 0xc4 0xde 0xe9 0xcb
        0x54 0x7b 0x94 0x32 0xa6 0xc2 0x23 0x3d 0xee 0x4c 0x95 0x0b 0x42 0xfa 0xc3 0x4e
        0x08 0x2e 0xa1 0x66 0x28 0xd9 0x24 0xb2 0x76 0x5b 0xa2 0x49 0x6d 0x8b 0xd1 0x25
        0x72 0xf8 0xf6 0x64 0x86 0x68 0x98 0x16 0xd4 0xa4 0x5c 0xcc 0x5d 0x65 0xb6 0x92
        0x6c 0x70 0x48 0x50 0xfd 0xed 0xb9 0xda 0x5e 0x15 0x46 0x57 0xa7 0x8d 0x9d 0x84
        0x90 0xd8 0xab 0x00 0x8c 0xbc 0xd3 0x0a 0xf7 0xe4 0x58 0x05 0xb8 0xb3 0x45 0x06
        0xd0 0x2c 0x1e 0x8f 0xca 0x3f 0x0f 0x02 0xc1 0xaf 0xbd 0x03 0x01 0x13 0x8a 0x6b
        0x3a 0x91 0x11 0x41 0x4f 0x67 0xdc 0xea 0x97 0xf2 0xcf 0xce 0xf0 0xb4 0xe6 0x73
        0x96 0xac 0x74 0x22 0xe7 0xad 0x35 0x85 0xe2 0xf9 0x37 0xe8 0x1c 0x75 0xdf 0x6e
        0x47 0xf1 0x1a 0x71 0x1d 0x29 0xc5 0x89 0x6f 0xb7 0x62 0x0e 0xaa 0x18 0xbe 0x1b
        0xfc 0x56 0x3e 0x4b 0xc6 0xd2 0x79 0x20 0x9a 0xdb 0xc0 0xfe 0x78 0xcd 0x5a 0xf4
        0x1f 0xdd 0xa8 0x33 0x88 0x07 0xc7 0x31 0xb1 0x12 0x10 0x59 0x27 0x80 0xec 0x5f
        0x60 0x51 0x7f 0xa9 0x19 0xb5 0x4a 0x0d 0x2d 0xe5 0x7a 0x9f 0x93 0xc9 0x9c 0xef
        0xa0 0xe0 0x3b 0x4d 0xae 0x2a 0xf5 0xb0 0xc8 0xeb 0xbb 0x3c 0x83 0x53 0x99 0x61
        0x17 0x2b 0x04 0x7e 0xba 0x77 0xd6 0x26 0xe1 0x69 0x14 0x63 0x55 0x21 0x0c 0x7d
    }
}

# aes::Init --
#
#	Initialise our AES state and calculate the key schedule. An initialization
#	vector is maintained in the state for modes that require one. The key must
#	be binary data of the correct size and the IV must be 16 bytes.
#
#	Nk: columns of the key-array
#	Nr: number of rounds (depends on key-length)
#	Nb: columns of the text-block, is always 4 in AES
#
proc ::aes::Init {mode key iv} {
    switch -exact -- $mode {
        ecb - cbc { }
        cfb - ofb {
            return -code error "$mode mode not implemented"
        }
        default {
            return -code error "invalid mode \"$mode\":\
                must be one of ecb or cbc."
        }
    }

    set size [expr {[string length $key] << 3}]
    switch -exact -- $size {
        128 {set Nk 4; set Nr 10; set Nb 4}
        192 {set Nk 6; set Nr 12; set Nb 4}
        256 {set Nk 8; set Nr 14; set Nb 4}
        default {
            return -code error "invalid key size \"$size\":\
                must be one of 128, 192 or 256."
        }
    }

    variable uid
    set Key [namespace current]::[incr uid]
    upvar #0 $Key state
    if {[binary scan $iv Iu4 state(I)] != 1} {
        return -code error "invalid initialization vector: must be 16 bytes"
    }
    array set state [list M $mode K $key Nk $Nk Nr $Nr Nb $Nb W {}]
    ExpandKey $Key
    return $Key
}

# aes::Reset --
#
#	Reset the initialization vector for the specified key. This permits the
#	key to be reused for encryption or decryption without the expense of
#	re-calculating the key schedule.
#
proc ::aes::Reset {Key iv} {
    upvar #0 $Key state
    if {[binary scan $iv Iu4 state(I)] != 1} {
        return -code error "invalid initialization vector: must be 16 bytes"
    }
    return
}
    
# aes::Final --
#
#	Clean up the key state
#
proc ::aes::Final {Key} {
    # FRINK: nocheck
    unset $Key
}

# -------------------------------------------------------------------------

# 5.1 Cipher:  Encipher a single block of 128 bits.
proc ::aes::EncryptBlock {Key block} {
    upvar #0 $Key state
    if {[binary scan $block Iu4 data] != 1} {
        return -code error "invalid block size: blocks must be 16 bytes"
    }

    if {$state(M) eq {cbc}} {
        # Loop unrolled.
        lassign $data     d0 d1 d2 d3
        lassign $state(I) s0 s1 s2 s3
        set data [list \
                      [expr {$d0 ^ $s0}] \
                      [expr {$d1 ^ $s1}] \
                      [expr {$d2 ^ $s2}] \
                      [expr {$d3 ^ $s3}] ]
    }

    set data [AddRoundKey $Key 0 $data]
    for {set n 1} {$n < $state(Nr)} {incr n} {
        set data [AddRoundKey $Key $n [MixColumns [ShiftRows [SubBytes $data]]]]
    }
    set data [AddRoundKey $Key $n [ShiftRows [SubBytes $data]]]

    # Bug 2993029:
    # Force all elements of data into the 32bit range.
    # Loop unrolled
    set res [Clamp32 $data]

    set state(I) $res
    binary format Iu4 $res
}

# 5.3: Inverse Cipher: Decipher a single 128 bit block.
proc ::aes::DecryptBlock {Key block} {
    upvar #0 $Key state
    if {[binary scan $block Iu4 data] != 1} {
        return -code error "invalid block size: block must be 16 bytes"
    }
    set iv $data

    set n $state(Nr)
    set data [AddRoundKey $Key $state(Nr) $data]
    for {incr n -1} {$n > 0} {incr n -1} {
        set data [InvMixColumns [AddRoundKey $Key $n [InvSubBytes [InvShiftRows $data]]]]
    }
    set data [AddRoundKey $Key $n [InvSubBytes [InvShiftRows $data]]]
    
    if {$state(M) eq {cbc}} {
        lassign $data     d0 d1 d2 d3
        lassign $state(I) s0 s1 s2 s3
        set data [list \
                      [expr {($d0 ^ $s0) & 0xffffffff}] \
                      [expr {($d1 ^ $s1) & 0xffffffff}] \
                      [expr {($d2 ^ $s2) & 0xffffffff}] \
                      [expr {($d3 ^ $s3) & 0xffffffff}] ]
    } else {
        # Bug 2993029:
        # The integrated clamping we see above only happens for CBC mode.
        set data [Clamp32 $data]
    }

    set state(I) $iv
    binary format Iu4 $data
}

proc ::aes::Clamp32 {data} {
    # Force all elements into 32bit range.
    lassign $data d0 d1 d2 d3
    list \
        [expr {$d0 & 0xffffffff}] \
        [expr {$d1 & 0xffffffff}] \
        [expr {$d2 & 0xffffffff}] \
        [expr {$d3 & 0xffffffff}]
}

# 5.2: KeyExpansion
proc ::aes::ExpandKey {Key} {
    upvar #0 $Key state
    set Rcon [list 0x00000000 0x01000000 0x02000000 0x04000000 0x08000000 \
                   0x10000000 0x20000000 0x40000000 0x80000000 0x1b000000 \
                   0x36000000 0x6c000000 0xd8000000 0xab000000 0x4d000000]
    # Split the key into Nk big-endian words
    binary scan $state(K) I* W
    set max [expr {$state(Nb) * ($state(Nr) + 1)}]
    set i $state(Nk)
    set h [expr {$i - 1}]
    set j 0
    for {} {$i < $max} {incr i; incr h; incr j} {
        set temp [lindex $W $h]
        if {($i % $state(Nk)) == 0} {
            set sub [SubWord [RotWord $temp]]
            set rc [lindex $Rcon [expr {$i/$state(Nk)}]]
            set temp [expr {$sub ^ $rc}]
        } elseif {$state(Nk) > 6 && ($i % $state(Nk)) == 4} { 
            set temp [SubWord $temp]
        }
        lappend W [expr {[lindex $W $j] ^ $temp}]
    }
    set state(W) $W
}

# 5.2: Key Expansion: Apply S-box to each byte in the 32 bit word
proc ::aes::SubWord {w} {
    variable sbox
    set s3 [lindex $sbox [expr {($w >> 24) & 255}]]
    set s2 [lindex $sbox [expr {($w >> 16) & 255}]]
    set s1 [lindex $sbox [expr {($w >> 8 ) & 255}]]
    set s0 [lindex $sbox [expr { $w        & 255}]]
    return [expr {($s3 << 24) | ($s2 << 16) | ($s1 << 8) | $s0}]
}

proc ::aes::InvSubWord {w} {
    variable xobs
    set s3 [lindex $xobs [expr {($w >> 24) & 255}]]
    set s2 [lindex $xobs [expr {($w >> 16) & 255}]]
    set s1 [lindex $xobs [expr {($w >> 8 ) & 255}]]
    set s0 [lindex $xobs [expr { $w        & 255}]]
    return [expr {($s3 << 24) | ($s2 << 16) | ($s1 << 8) | $s0}]
}

# 5.2: Key Expansion: Rotate a 32bit word by 8 bits
proc ::aes::RotWord {w} {
    return [expr {(($w << 8) | (($w >> 24) & 0xff)) & 0xffffffff}]
}

# 5.1.1: SubBytes() Transformation
proc ::aes::SubBytes {words} {
    lassign $words w0 w1 w2 w3
    list [SubWord $w0] [SubWord $w1] [SubWord $w2] [SubWord $w3]
}

# 5.3.2: InvSubBytes() Transformation
proc ::aes::InvSubBytes {words} {
    lassign $words w0 w1 w2 w3
    list [InvSubWord $w0] [InvSubWord $w1] [InvSubWord $w2] [InvSubWord $w3]
}

# 5.1.2: ShiftRows() Transformation
proc ::aes::ShiftRows {words} {
    for {set n0 0} {$n0 < 4} {incr n0} {
        set n1 [expr {($n0 + 1) % 4}]
        set n2 [expr {($n0 + 2) % 4}]
        set n3 [expr {($n0 + 3) % 4}]
        lappend r [expr {(  [lindex $words $n0] & 0xff000000)
                         | ([lindex $words $n1] & 0x00ff0000)
                         | ([lindex $words $n2] & 0x0000ff00)
                         | ([lindex $words $n3] & 0x000000ff)
                     }]
    }
    return $r
}


# 5.3.1: InvShiftRows() Transformation
proc ::aes::InvShiftRows {words} {
    for {set n0 0} {$n0 < 4} {incr n0} {
        set n1 [expr {($n0 + 1) % 4}]
        set n2 [expr {($n0 + 2) % 4}]
        set n3 [expr {($n0 + 3) % 4}]
        lappend r [expr {(  [lindex $words $n0] & 0xff000000)
                         | ([lindex $words $n3] & 0x00ff0000)
                         | ([lindex $words $n2] & 0x0000ff00)
                         | ([lindex $words $n1] & 0x000000ff)
                     }]
    }
    return $r
}

# 5.1.3: MixColumns() Transformation
proc ::aes::MixColumns {words} {
    set r {}
    foreach w $words {
        set r0 [expr {(($w >> 24) & 255)}]
        set r1 [expr {(($w >> 16) & 255)}]
        set r2 [expr {(($w >> 8 ) & 255)}]
        set r3 [expr {( $w        & 255)}]

        set s0 [expr {[GFMult2 $r0] ^ [GFMult3 $r1] ^ $r2 ^ $r3}]
        set s1 [expr {$r0 ^ [GFMult2 $r1] ^ [GFMult3 $r2] ^ $r3}]
        set s2 [expr {$r0 ^ $r1 ^ [GFMult2 $r2] ^ [GFMult3 $r3]}]
        set s3 [expr {[GFMult3 $r0] ^ $r1 ^ $r2 ^ [GFMult2 $r3]}]

        lappend r [expr {($s0 << 24) | ($s1 << 16) | ($s2 << 8) | $s3}]
    }
    return $r
}

# 5.3.3: InvMixColumns() Transformation
proc ::aes::InvMixColumns {words} {
    set r {}
    foreach w $words {
        set r0 [expr {(($w >> 24) & 255)}]
        set r1 [expr {(($w >> 16) & 255)}]
        set r2 [expr {(($w >> 8 ) & 255)}]
        set r3 [expr {( $w        & 255)}]

        set s0 [expr {[GFMult0e $r0] ^ [GFMult0b $r1] ^ [GFMult0d $r2] ^ [GFMult09 $r3]}]
        set s1 [expr {[GFMult09 $r0] ^ [GFMult0e $r1] ^ [GFMult0b $r2] ^ [GFMult0d $r3]}]
        set s2 [expr {[GFMult0d $r0] ^ [GFMult09 $r1] ^ [GFMult0e $r2] ^ [GFMult0b $r3]}]
        set s3 [expr {[GFMult0b $r0] ^ [GFMult0d $r1] ^ [GFMult09 $r2] ^ [GFMult0e $r3]}]

        lappend r [expr {($s0 << 24) | ($s1 << 16) | ($s2 << 8) | $s3}]
    }
    return $r
}

# 5.1.4: AddRoundKey() Transformation
proc ::aes::AddRoundKey {Key round words} {
    upvar #0 $Key state
    set r {}
    set n [expr {$round * $state(Nb)}]
    foreach w $words {
        lappend r [expr {$w ^ [lindex $state(W) $n]}]
        incr n
    }
    return $r
}
    
# -------------------------------------------------------------------------
# ::aes::GFMult*
#
#	some needed functions for multiplication in a Galois-field
#
proc ::aes::GFMult2 {number} {
    # this is a tabular representation of xtime (multiplication by 2)
    # it is used instead of calculation to prevent timing attacks
    set xtime {
        0x00 0x02 0x04 0x06 0x08 0x0a 0x0c 0x0e 0x10 0x12 0x14 0x16 0x18 0x1a 0x1c 0x1e
        0x20 0x22 0x24 0x26 0x28 0x2a 0x2c 0x2e 0x30 0x32 0x34 0x36 0x38 0x3a 0x3c 0x3e 
        0x40 0x42 0x44 0x46 0x48 0x4a 0x4c 0x4e 0x50 0x52 0x54 0x56 0x58 0x5a 0x5c 0x5e
        0x60 0x62 0x64 0x66 0x68 0x6a 0x6c 0x6e 0x70 0x72 0x74 0x76 0x78 0x7a 0x7c 0x7e 
        0x80 0x82 0x84 0x86 0x88 0x8a 0x8c 0x8e 0x90 0x92 0x94 0x96 0x98 0x9a 0x9c 0x9e 
        0xa0 0xa2 0xa4 0xa6 0xa8 0xaa 0xac 0xae 0xb0 0xb2 0xb4 0xb6 0xb8 0xba 0xbc 0xbe 
        0xc0 0xc2 0xc4 0xc6 0xc8 0xca 0xcc 0xce 0xd0 0xd2 0xd4 0xd6 0xd8 0xda 0xdc 0xde 
        0xe0 0xe2 0xe4 0xe6 0xe8 0xea 0xec 0xee 0xf0 0xf2 0xf4 0xf6 0xf8 0xfa 0xfc 0xfe 
        0x1b 0x19 0x1f 0x1d 0x13 0x11 0x17 0x15 0x0b 0x09 0x0f 0x0d 0x03 0x01 0x07 0x05 
        0x3b 0x39 0x3f 0x3d 0x33 0x31 0x37 0x35 0x2b 0x29 0x2f 0x2d 0x23 0x21 0x27 0x25 
        0x5b 0x59 0x5f 0x5d 0x53 0x51 0x57 0x55 0x4b 0x49 0x4f 0x4d 0x43 0x41 0x47 0x45 
        0x7b 0x79 0x7f 0x7d 0x73 0x71 0x77 0x75 0x6b 0x69 0x6f 0x6d 0x63 0x61 0x67 0x65 
        0x9b 0x99 0x9f 0x9d 0x93 0x91 0x97 0x95 0x8b 0x89 0x8f 0x8d 0x83 0x81 0x87 0x85 
        0xbb 0xb9 0xbf 0xbd 0xb3 0xb1 0xb7 0xb5 0xab 0xa9 0xaf 0xad 0xa3 0xa1 0xa7 0xa5 
        0xdb 0xd9 0xdf 0xdd 0xd3 0xd1 0xd7 0xd5 0xcb 0xc9 0xcf 0xcd 0xc3 0xc1 0xc7 0xc5 
        0xfb 0xf9 0xff 0xfd 0xf3 0xf1 0xf7 0xf5 0xeb 0xe9 0xef 0xed 0xe3 0xe1 0xe7 0xe5
    }
    lindex $xtime $number
}

proc ::aes::GFMult3 {number} {
    # multliply by 2 (via GFMult2) and add the number again on the result (via XOR)
    expr {$number ^ [GFMult2 $number]}
}

proc ::aes::GFMult09 {number} {
    # 09 is: (02*02*02) + 01
    expr {[GFMult2 [GFMult2 [GFMult2 $number]]] ^ $number}
}

proc ::aes::GFMult0b {number} {
    # 0b is: (02*02*02) + 02 + 01
    #return [expr [GFMult2 [GFMult2 [GFMult2 $number]]] ^ [GFMult2 $number] ^ $number]
    #set g0 [GFMult2 $number]
    expr {[GFMult09 $number] ^ [GFMult2 $number]}
}

proc ::aes::GFMult0d {number} {
    # 0d is: (02*02*02) + (02*02) + 01
    set temp [GFMult2 [GFMult2 $number]]
    expr {[GFMult2 $temp] ^ ($temp ^ $number)}
}

proc ::aes::GFMult0e {number} {
    # 0e is: (02*02*02) + (02*02) + 02
    set temp [GFMult2 [GFMult2 $number]]
    expr {[GFMult2 $temp] ^ ($temp ^ [GFMult2 $number])}
}

# -------------------------------------------------------------------------

# aes::Encrypt --
#
#	Encrypt a blocks of plain text and returns blocks of cipher text.
#	The input data must be a multiple of the block size (16).
#
proc ::aes::Encrypt {Key data} {
    set len [string length $data]
    if {($len % 16) != 0} {
        return -code error "invalid block size: AES requires 16 byte blocks"
    }

    set result {}
    for {set i 0} {$i < $len} {incr i 1} {
        set block [string range $data $i [incr i 15]]
        append result [EncryptBlock $Key $block]
    }
    return $result
}

# aes::Decrypt --
#
#	Decrypt blocks of cipher text and returns blocks of plain text.
#	The input data must be a multiple of the block size (16).
#
proc ::aes::Decrypt {Key data} {
    set len [string length $data]
    if {($len % 16) != 0} {
        return -code error "invalid block size: AES requires 16 byte blocks"
    }

    set result {}
    for {set i 0} {$i < $len} {incr i 1} {
        set block [string range $data $i [incr i 15]]
        append result [DecryptBlock $Key $block]
    }
    return $result
}

# -------------------------------------------------------------------------
# chan event handler for chunked file reading.
#
proc ::aes::Chunk {Key in {out {}} {chunksize 4096}} {
    upvar #0 $Key state

    #puts ||CHUNK.X||i=$in|o=$out|c=$chunksize|eof=[eof $in]
    
    if {[eof $in]} {
        chan event $in readable {}
        set state(reading) 0
    }

    set data [read $in $chunksize]

    #puts ||CHUNK.R||i=$in|o=$out|c=$chunksize|eof=[eof $in]||[string length $data]||$data||

    # Do nothing when data was read at all.
    if {$data eq {}} return

    if {[eof $in]} {
        #puts CHUNK.Z
        set data [Pad $data 16]
    }

    #puts ||CHUNK.P||i=$in|o=$out|c=$chunksize|eof=[eof $in]||[string length $data]||$data||
    
    if {$out eq {}} {
        append state(output) [$state(cmd) $Key $data]
    } else {
        puts -nonewline $out [$state(cmd) $Key $data]
    }
}

proc ::aes::SetOneOf {lst item} {
    set ndx [lsearch -glob $lst "${item}*"]
    if {$ndx == -1} {
        set err [join $lst ", "]
        return -code error "invalid mode \"$item\": must be one of $err"
    }
    lindex $lst $ndx
}

proc ::aes::CheckSize {what size thing} {
    if {[string length $thing] != $size} {
        return -code error "invalid value for $what: must be $size bytes long"
    }
    return $thing
}

proc ::aes::Pad {data blocksize {fill \0}} {
    set len [string length $data]
    if {$len == 0} {
        set data [string repeat $fill $blocksize]
    } elseif {($len % $blocksize) != 0} {
        set pad [expr {$blocksize - ($len % $blocksize)}]
        append data [string repeat $fill $pad]
    }
    return $data
}

proc ::aes::Pop {varname {nth 0}} {
    upvar 1 $varname args
    set r [lindex $args $nth]
    set args [lreplace $args $nth $nth]
    return $r
}

proc ::aes::aes {args} {
    array set opts {-dir encrypt -mode cbc -key {} -in {} -out {} -chunksize 4096 -hex 0}
    set opts(-iv) [string repeat \0 16]
    set modes {ecb cbc}
    set dirs {encrypt decrypt}
    while {([llength $args] > 1) && [string match -* [set option [lindex $args 0]]]} {
        switch -exact -- $option {
            -mode      { set opts(-mode) [SetOneOf $modes [Pop args 1]] }
            -dir       { set opts(-dir) [SetOneOf $dirs [Pop args 1]] }
            -iv        { set opts(-iv) [CheckSize -iv 16 [Pop args 1]] }
            -key       { set opts(-key) [Pop args 1] }
            -in        { set opts(-in) [Pop args 1] }
            -out       { set opts(-out) [Pop args 1] }
            -chunksize { set opts(-chunksize) [Pop args 1] }
            -hex       { set opts(-hex) 1 }
            --         { Pop args ; break }
            default {
                set err [join [lsort [array names opts]] ", "]
                return -code error "bad option \"$option\":\
                    must be one of $err"
            }
        }
        Pop args
    }

    if {$opts(-key) eq {}} {
        return -code error "no key provided: the -key option is required"
    }

    set r {}
    if {$opts(-in) eq {}} {

        if {[llength $args] != 1} {
            return -code error "wrong \# args:\
                should be \"aes ?options...? -key keydata plaintext\""
        }

        set data [Pad [lindex $args 0] 16]
        set Key [Init $opts(-mode) $opts(-key) $opts(-iv)]
        if {[string equal $opts(-dir) "encrypt"]} {
            set r [Encrypt $Key $data]
        } else {
            set r [Decrypt $Key $data]
        }

        if {$opts(-out) ne {}} {
            puts -nonewline $opts(-out) $r
            set r {}
        }
        Final $Key

    } else {

        if {[llength $args] != 0} {
            return -code error "wrong \# args:\
                should be \"aes ?options...? -key keydata -in channel\""
        }

        set Key [Init $opts(-mode) $opts(-key) $opts(-iv)]

        set readcmd [list [namespace origin Chunk] \
                         $Key $opts(-in) $opts(-out) \
                         $opts(-chunksize)]

        upvar 1 $Key state
        set state(reading) 1
        if {[string equal $opts(-dir) "encrypt"]} {
            set state(cmd) Encrypt
        } else {
            set state(cmd) Decrypt
        }
        set state(output) ""
        chan event $opts(-in) readable $readcmd
        if {[info commands ::tkwait] != {}} {
            tkwait variable [subst $Key](reading)
        } else {
            vwait [subst $Key](reading)
        }
        if {$opts(-out) == {}} {
            set r $state(output)
        }
        Final $Key
    }

    if {$opts(-hex)} {
        binary scan $r H* r
    }
    return $r
}

# -------------------------------------------------------------------------

package provide aes 1.2.1

# -------------------------------------------------------------------------
# Local variables:
# mode: tcl
# indent-tabs-mode: nil
# End:
