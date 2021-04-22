##################################################
#
# md5.tcl - MD5 in Tcl
# Author: Don Libes <libes@nist.gov>, July 1999
# Version 1.2.0
#
# MD5  defined by RFC 1321, "The MD5 Message-Digest Algorithm"
# HMAC defined by RFC 2104, "Keyed-Hashing for Message Authentication"
#
# Most of the comments below come right out of RFC 1321; That's why
# they have such peculiar numbers.  In addition, I have retained
# original syntax, bugs in documentation (yes, really), etc. from the
# RFC.  All remaining bugs are mine.
#
# HMAC implementation by D. J. Hagberg <dhagberg@millibits.com> and
# is based on C code in RFC 2104.
#
# For more info, see: http://expect.nist.gov/md5pure
#
# - Don
#
# Modified by Miguel Sofer to use inlines and simple variables
##################################################

# @mdgen EXCLUDE: md5c.tcl

package require Tcl 8.2
namespace eval ::md5 {
}

if {![catch {package require Trf 2.0}] && ![catch {::md5 -- test}]} {
    # Trf is available, so implement the functionality provided here
    # in terms of calls to Trf for speed.

    proc ::md5::md5 {msg} {
	string tolower [::hex -mode encode -- [::md5 -- $msg]]
    }

    # hmac: hash for message authentication

    # MD5 of Trf and MD5 as defined by this package have slightly
    # different results. Trf returns the digest in binary, here we get
    # it as hex-string. In the computation of the HMAC the latter
    # requires back conversion into binary in some places. With Trf we
    # can use omit these.

    proc ::md5::hmac {key text} {
	# if key is longer than 64 bytes, reset it to MD5(key).  If shorter, 
	# pad it out with null (\x00) chars.
	set keyLen [string length $key]
	if {$keyLen > 64} {
	    #old: set key [binary format H32 [md5 $key]]
	    set key [::md5 -- $key]
	    set keyLen [string length $key]
	}
    
	# ensure the key is padded out to 64 chars with nulls.
	set padLen [expr {64 - $keyLen}]
	append key [binary format "a$padLen" {}]

	# Split apart the key into a list of 16 little-endian words
	binary scan $key i16 blocks

	# XOR key with ipad and opad values
	set k_ipad {}
	set k_opad {}
	foreach i $blocks {
	    append k_ipad [binary format i [expr {$i ^ 0x36363636}]]
	    append k_opad [binary format i [expr {$i ^ 0x5c5c5c5c}]]
	}
    
	# Perform inner md5, appending its results to the outer key
	append k_ipad $text
	#old: append k_opad [binary format H* [md5 $k_ipad]]
	append k_opad [::md5 -- $k_ipad]

	# Perform outer md5
	#old: md5 $k_opad
	string tolower [::hex -mode encode -- [::md5 -- $k_opad]]
    }

} else {
    # Without Trf use the all-tcl implementation by Don Libes.

    # T will be inlined after the definition of md5body

    # test md5
    #
    # This proc is not necessary during runtime and may be omitted if you
    # are simply inserting this file into a production program.
    #
    proc ::md5::test {} {
	foreach {msg expected} {
	    ""
	    "d41d8cd98f00b204e9800998ecf8427e"
	    "a"
	    "0cc175b9c0f1b6a831c399e269772661"
	    "abc"
	    "900150983cd24fb0d6963f7d28e17f72"
	    "message digest"
	    "f96b697d7cb7938d525a2f31aaf161d0"
	    "abcdefghijklmnopqrstuvwxyz"
	    "c3fcd3d76192e4007dfb496cca67e13b"
	    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	    "d174ab98d277d9f5a5611c2c9f419d9f"
	    "12345678901234567890123456789012345678901234567890123456789012345678901234567890"
	    "57edf4a22be3c955ac49da2e2107b67a"
	} {
	    puts "testing: md5 \"$msg\""
	    set computed [md5 $msg]
	    puts "expected: $expected"
	    puts "computed: $computed"
	    if {0 != [string compare $computed $expected]} {
		puts "FAILED"
	    } else {
		puts "SUCCEEDED"
	    }
	}
    }

    # time md5
    #
    # This proc is not necessary during runtime and may be omitted if you
    # are simply inserting this file into a production program.
    #
    proc ::md5::time {} {
	foreach len {10 50 100 500 1000 5000 10000} {
	    set time [::time {md5 [format %$len.0s ""]} 100]
	    set msec [lindex $time 0]
	    puts "input length $len: [expr {$msec/1000}] milliseconds per interation"
	}
    }

    #
    # We just define the body of md5pure::md5 here; later we
    # regsub to inline a few function calls for speed
    #

    set ::md5::md5body {

	#
	# 3.1 Step 1. Append Padding Bits
	#

	set msgLen [string length $msg]

	set padLen [expr {56 - $msgLen%64}]
	if {$msgLen % 64 > 56} {
	    incr padLen 64
	}

	# pad even if no padding required
	if {$padLen == 0} {
	    incr padLen 64
	}

	# append single 1b followed by 0b's
	append msg [binary format "a$padLen" \200]

	#
	# 3.2 Step 2. Append Length
	#

	# RFC doesn't say whether to use little- or big-endian
	# code demonstrates little-endian
	# This step limits our input to size 2^32b or 2^24B
	append msg [binary format "i1i1" [expr {8*$msgLen}] 0]
	
	#
	# 3.3 Step 3. Initialize MD Buffer
	#

	set A [expr 0x67452301]
	set B [expr 0xefcdab89]
	set C [expr 0x98badcfe]
	set D [expr 0x10325476]

	#
	# 3.4 Step 4. Process Message in 16-Word Blocks
	#

	# process each 16-word block
	# RFC doesn't say whether to use little- or big-endian
	# code says little-endian
	binary scan $msg i* blocks

	# loop over the message taking 16 blocks at a time

	foreach {X0 X1 X2 X3 X4 X5 X6 X7 X8 X9 X10 X11 X12 X13 X14 X15} $blocks {

	    # Save A as AA, B as BB, C as CC, and D as DD.
	    set AA $A
	    set BB $B
	    set CC $C
	    set DD $D

	    # Round 1.
	    # Let [abcd k s i] denote the operation
	    #      a = b + ((a + F(b,c,d) + X[k] + T[i]) <<< s).
	    # [ABCD  0  7  1]  [DABC  1 12  2]  [CDAB  2 17  3]  [BCDA  3 22  4]
	    set A [expr {($B + [<<< [expr {$A + [F $B $C $D] + $X0  + $T01}]  7]) & 0xffffffff}]
	    set D [expr {($A + [<<< [expr {$D + [F $A $B $C] + $X1  + $T02}] 12]) & 0xffffffff}]
	    set C [expr {($D + [<<< [expr {$C + [F $D $A $B] + $X2  + $T03}] 17]) & 0xffffffff}]
	    set B [expr {($C + [<<< [expr {$B + [F $C $D $A] + $X3  + $T04}] 22]) & 0xffffffff}]
	    # [ABCD  4  7  5]  [DABC  5 12  6]  [CDAB  6 17  7]  [BCDA  7 22  8]
	    set A [expr {($B + [<<< [expr {$A + [F $B $C $D] + $X4  + $T05}]  7]) & 0xffffffff}]
	    set D [expr {($A + [<<< [expr {$D + [F $A $B $C] + $X5  + $T06}] 12]) & 0xffffffff}]
	    set C [expr {($D + [<<< [expr {$C + [F $D $A $B] + $X6  + $T07}] 17]) & 0xffffffff}]
	    set B [expr {($C + [<<< [expr {$B + [F $C $D $A] + $X7  + $T08}] 22]) & 0xffffffff}]
	    # [ABCD  8  7  9]  [DABC  9 12 10]  [CDAB 10 17 11]  [BCDA 11 22 12]
	    set A [expr {($B + [<<< [expr {$A + [F $B $C $D] + $X8  + $T09}]  7]) & 0xffffffff}]
	    set D [expr {($A + [<<< [expr {$D + [F $A $B $C] + $X9  + $T10}] 12]) & 0xffffffff}]
	    set C [expr {($D + [<<< [expr {$C + [F $D $A $B] + $X10 + $T11}] 17]) & 0xffffffff}]
	    set B [expr {($C + [<<< [expr {$B + [F $C $D $A] + $X11 + $T12}] 22]) & 0xffffffff}]
	    # [ABCD 12  7 13]  [DABC 13 12 14]  [CDAB 14 17 15]  [BCDA 15 22 16]
	    set A [expr {($B + [<<< [expr {$A + [F $B $C $D] + $X12 + $T13}]  7]) & 0xffffffff}]
	    set D [expr {($A + [<<< [expr {$D + [F $A $B $C] + $X13 + $T14}] 12]) & 0xffffffff}]
	    set C [expr {($D + [<<< [expr {$C + [F $D $A $B] + $X14 + $T15}] 17]) & 0xffffffff}]
	    set B [expr {($C + [<<< [expr {$B + [F $C $D $A] + $X15 + $T16}] 22]) & 0xffffffff}]

	    # Round 2.
	    # Let [abcd k s i] denote the operation
	    #      a = b + ((a + G(b,c,d) + X[k] + T[i]) <<< s).
	    # Do the following 16 operations.
	    # [ABCD  1  5 17]  [DABC  6  9 18]  [CDAB 11 14 19]  [BCDA  0 20 20]
	    set A [expr {($B + [<<< [expr {$A + [G $B $C $D] + $X1  + $T17}]  5]) & 0xffffffff}]
	    set D [expr {($A + [<<< [expr {$D + [G $A $B $C] + $X6  + $T18}]  9]) & 0xffffffff}]
	    set C [expr {($D + [<<< [expr {$C + [G $D $A $B] + $X11 + $T19}] 14]) & 0xffffffff}]
	    set B [expr {($C + [<<< [expr {$B + [G $C $D $A] + $X0  + $T20}] 20]) & 0xffffffff}]
	    # [ABCD  5  5 21]  [DABC 10  9 22]  [CDAB 15 14 23]  [BCDA  4 20 24]
	    set A [expr {($B + [<<< [expr {$A + [G $B $C $D] + $X5  + $T21}]  5]) & 0xffffffff}]
	    set D [expr {($A + [<<< [expr {$D + [G $A $B $C] + $X10 + $T22}]  9]) & 0xffffffff}]
	    set C [expr {($D + [<<< [expr {$C + [G $D $A $B] + $X15 + $T23}] 14]) & 0xffffffff}]
	    set B [expr {($C + [<<< [expr {$B + [G $C $D $A] + $X4  + $T24}] 20]) & 0xffffffff}]
	    # [ABCD  9  5 25]  [DABC 14  9 26]  [CDAB  3 14 27]  [BCDA  8 20 28]
	    set A [expr {($B + [<<< [expr {$A + [G $B $C $D] + $X9  + $T25}]  5]) & 0xffffffff}]
	    set D [expr {($A + [<<< [expr {$D + [G $A $B $C] + $X14 + $T26}]  9]) & 0xffffffff}]
	    set C [expr {($D + [<<< [expr {$C + [G $D $A $B] + $X3  + $T27}] 14]) & 0xffffffff}]
	    set B [expr {($C + [<<< [expr {$B + [G $C $D $A] + $X8  + $T28}] 20]) & 0xffffffff}]
	    # [ABCD 13  5 29]  [DABC  2  9 30]  [CDAB  7 14 31]  [BCDA 12 20 32]
	    set A [expr {($B + [<<< [expr {$A + [G $B $C $D] + $X13 + $T29}]  5]) & 0xffffffff}]
	    set D [expr {($A + [<<< [expr {$D + [G $A $B $C] + $X2  + $T30}]  9]) & 0xffffffff}]
	    set C [expr {($D + [<<< [expr {$C + [G $D $A $B] + $X7  + $T31}] 14]) & 0xffffffff}]
	    set B [expr {($C + [<<< [expr {$B + [G $C $D $A] + $X12 + $T32}] 20]) & 0xffffffff}]

	    # Round 3.
	    # Let [abcd k s t] [sic] denote the operation
	    #     a = b + ((a + H(b,c,d) + X[k] + T[i]) <<< s).
	    # Do the following 16 operations.
	    # [ABCD  5  4 33]  [DABC  8 11 34]  [CDAB 11 16 35]  [BCDA 14 23 36]
	    set A [expr {($B + [<<< [expr {$A + [H $B $C $D] + $X5  + $T33}]  4]) & 0xffffffff}]
	    set D [expr {($A + [<<< [expr {$D + [H $A $B $C] + $X8  + $T34}] 11]) & 0xffffffff}]
	    set C [expr {($D + [<<< [expr {$C + [H $D $A $B] + $X11 + $T35}] 16]) & 0xffffffff}]
	    set B [expr {($C + [<<< [expr {$B + [H $C $D $A] + $X14 + $T36}] 23]) & 0xffffffff}]
	    # [ABCD  1  4 37]  [DABC  4 11 38]  [CDAB  7 16 39]  [BCDA 10 23 40]
	    set A [expr {($B + [<<< [expr {$A + [H $B $C $D] + $X1  + $T37}]  4]) & 0xffffffff}]
	    set D [expr {($A + [<<< [expr {$D + [H $A $B $C] + $X4  + $T38}] 11]) & 0xffffffff}]
	    set C [expr {($D + [<<< [expr {$C + [H $D $A $B] + $X7  + $T39}] 16]) & 0xffffffff}]
	    set B [expr {($C + [<<< [expr {$B + [H $C $D $A] + $X10 + $T40}] 23]) & 0xffffffff}]
	    # [ABCD 13  4 41]  [DABC  0 11 42]  [CDAB  3 16 43]  [BCDA  6 23 44]
	    set A [expr {($B + [<<< [expr {$A + [H $B $C $D] + $X13 + $T41}]  4]) & 0xffffffff}]
	    set D [expr {($A + [<<< [expr {$D + [H $A $B $C] + $X0  + $T42}] 11]) & 0xffffffff}]
	    set C [expr {($D + [<<< [expr {$C + [H $D $A $B] + $X3  + $T43}] 16]) & 0xffffffff}]
	    set B [expr {($C + [<<< [expr {$B + [H $C $D $A] + $X6  + $T44}] 23]) & 0xffffffff}]
	    # [ABCD  9  4 45]  [DABC 12 11 46]  [CDAB 15 16 47]  [BCDA  2 23 48]
	    set A [expr {($B + [<<< [expr {$A + [H $B $C $D] + $X9  + $T45}]  4]) & 0xffffffff}]
	    set D [expr {($A + [<<< [expr {$D + [H $A $B $C] + $X12 + $T46}] 11]) & 0xffffffff}]
	    set C [expr {($D + [<<< [expr {$C + [H $D $A $B] + $X15 + $T47}] 16]) & 0xffffffff}]
	    set B [expr {($C + [<<< [expr {$B + [H $C $D $A] + $X2  + $T48}] 23]) & 0xffffffff}]

	    # Round 4.
	    # Let [abcd k s t] [sic] denote the operation
	    #     a = b + ((a + I(b,c,d) + X[k] + T[i]) <<< s).
	    # Do the following 16 operations.
	    # [ABCD  0  6 49]  [DABC  7 10 50]  [CDAB 14 15 51]  [BCDA  5 21 52]
	    set A [expr {($B + [<<< [expr {$A + [I $B $C $D] + $X0  + $T49}]  6]) & 0xffffffff}]
	    set D [expr {($A + [<<< [expr {$D + [I $A $B $C] + $X7  + $T50}] 10]) & 0xffffffff}]
	    set C [expr {($D + [<<< [expr {$C + [I $D $A $B] + $X14 + $T51}] 15]) & 0xffffffff}]
	    set B [expr {($C + [<<< [expr {$B + [I $C $D $A] + $X5  + $T52}] 21]) & 0xffffffff}]
	    # [ABCD 12  6 53]  [DABC  3 10 54]  [CDAB 10 15 55]  [BCDA  1 21 56]
	    set A [expr {($B + [<<< [expr {$A + [I $B $C $D] + $X12 + $T53}]  6]) & 0xffffffff}]
	    set D [expr {($A + [<<< [expr {$D + [I $A $B $C] + $X3  + $T54}] 10]) & 0xffffffff}]
	    set C [expr {($D + [<<< [expr {$C + [I $D $A $B] + $X10 + $T55}] 15]) & 0xffffffff}]
	    set B [expr {($C + [<<< [expr {$B + [I $C $D $A] + $X1  + $T56}] 21]) & 0xffffffff}]
	    # [ABCD  8  6 57]  [DABC 15 10 58]  [CDAB  6 15 59]  [BCDA 13 21 60]
	    set A [expr {($B + [<<< [expr {$A + [I $B $C $D] + $X8  + $T57}]  6]) & 0xffffffff}]
	    set D [expr {($A + [<<< [expr {$D + [I $A $B $C] + $X15 + $T58}] 10]) & 0xffffffff}]
	    set C [expr {($D + [<<< [expr {$C + [I $D $A $B] + $X6  + $T59}] 15]) & 0xffffffff}]
	    set B [expr {($C + [<<< [expr {$B + [I $C $D $A] + $X13 + $T60}] 21]) & 0xffffffff}]
	    # [ABCD  4  6 61]  [DABC 11 10 62]  [CDAB  2 15 63]  [BCDA  9 21 64]
	    set A [expr {($B + [<<< [expr {$A + [I $B $C $D] + $X4  + $T61}]  6]) & 0xffffffff}]
	    set D [expr {($A + [<<< [expr {$D + [I $A $B $C] + $X11 + $T62}] 10]) & 0xffffffff}]
	    set C [expr {($D + [<<< [expr {$C + [I $D $A $B] + $X2  + $T63}] 15]) & 0xffffffff}]
	    set B [expr {($C + [<<< [expr {$B + [I $C $D $A] + $X9  + $T64}] 21]) & 0xffffffff}]

	    # Then perform the following additions. (That is increment each
	    #   of the four registers by the value it had before this block
	    #   was started.)
	    incr A $AA
	    incr B $BB
	    incr C $CC
	    incr D $DD
	}
	# 3.5 Step 5. Output

	# ... begin with the low-order byte of A, and end with the high-order byte
	# of D.

	return [bytes $A][bytes $B][bytes $C][bytes $D]
    }

    #
    # Here we inline/regsub the functions F, G, H, I and <<< 
    #

    namespace eval ::md5 {
	#proc md5pure::F {x y z} {expr {(($x & $y) | ((~$x) & $z))}}
	regsub -all -- {\[ *F +(\$.) +(\$.) +(\$.) *\]} $md5body {((\1 \& \2) | ((~\1) \& \3))} md5body

	#proc md5pure::G {x y z} {expr {(($x & $z) | ($y & (~$z)))}}
	regsub -all -- {\[ *G +(\$.) +(\$.) +(\$.) *\]} $md5body {((\1 \& \3) | (\2 \& (~\3)))} md5body

	#proc md5pure::H {x y z} {expr {$x ^ $y ^ $z}}
	regsub -all -- {\[ *H +(\$.) +(\$.) +(\$.) *\]} $md5body {(\1 ^ \2 ^ \3)} md5body

	#proc md5pure::I {x y z} {expr {$y ^ ($x | (~$z))}}
	regsub -all -- {\[ *I +(\$.) +(\$.) +(\$.) *\]} $md5body {(\2 ^ (\1 | (~\3)))} md5body

	# bitwise left-rotate
	if {0} {
	    proc md5pure::<<< {x i} {
		# This works by bitwise-ORing together right piece and left
		# piece so that the (original) right piece becomes the left
		# piece and vice versa.
		#
		# The (original) right piece is a simple left shift.
		# The (original) left piece should be a simple right shift
		# but Tcl does sign extension on right shifts so we
		# shift it 1 bit, mask off the sign, and finally shift
		# it the rest of the way.
		
		# expr {($x << $i) | ((($x >> 1) & 0x7fffffff) >> (31-$i))}

		#
		# New version, faster when inlining
		# We replace inline (computing at compile time):
		#   R$i -> (32 - $i)
		#   S$i -> (0x7fffffff >> (31-$i))
		#

		expr { ($x << $i) | (($x >> [set R$i]) & [set S$i])}
	    }
	}
	# inline <<<
	regsub -all -- {\[ *<<< +\[ *expr +({[^\}]*})\] +([0-9]+) *\]} $md5body {(([set x [expr \1]] << \2) |  (($x >> R\2) \& S\2))} md5body

	# now replace the R and S
	variable map {}
	variable i
	foreach i { 
	    7 12 17 22
	    5  9 14 20
	    4 11 16 23
	    6 10 15 21 
	} {
	    lappend map R$i [expr {32 - $i}] S$i [expr {0x7fffffff >> (31-$i)}]
	}
	
	# inline the values of T
	variable tVal
	variable tName
	foreach \
		tName {
	    T01 T02 T03 T04 T05 T06 T07 T08 T09 T10 
	    T11 T12 T13 T14 T15 T16 T17 T18 T19 T20 
	    T21 T22 T23 T24 T25 T26 T27 T28 T29 T30 
	    T31 T32 T33 T34 T35 T36 T37 T38 T39 T40 
	    T41 T42 T43 T44 T45 T46 T47 T48 T49 T50 
	    T51 T52 T53 T54 T55 T56 T57 T58 T59 T60 
	    T61 T62 T63 T64 } \
		tVal {
	    0xd76aa478 0xe8c7b756 0x242070db 0xc1bdceee
	    0xf57c0faf 0x4787c62a 0xa8304613 0xfd469501
	    0x698098d8 0x8b44f7af 0xffff5bb1 0x895cd7be
	    0x6b901122 0xfd987193 0xa679438e 0x49b40821

	    0xf61e2562 0xc040b340 0x265e5a51 0xe9b6c7aa
	    0xd62f105d 0x2441453  0xd8a1e681 0xe7d3fbc8
	    0x21e1cde6 0xc33707d6 0xf4d50d87 0x455a14ed
	    0xa9e3e905 0xfcefa3f8 0x676f02d9 0x8d2a4c8a

	    0xfffa3942 0x8771f681 0x6d9d6122 0xfde5380c
	    0xa4beea44 0x4bdecfa9 0xf6bb4b60 0xbebfbc70
	    0x289b7ec6 0xeaa127fa 0xd4ef3085 0x4881d05
	    0xd9d4d039 0xe6db99e5 0x1fa27cf8 0xc4ac5665

	    0xf4292244 0x432aff97 0xab9423a7 0xfc93a039
	    0x655b59c3 0x8f0ccc92 0xffeff47d 0x85845dd1
	    0x6fa87e4f 0xfe2ce6e0 0xa3014314 0x4e0811a1
	    0xf7537e82 0xbd3af235 0x2ad7d2bb 0xeb86d391
	} {
	    lappend map \$$tName $tVal
	}
	set md5body [string map $map $md5body]
	

	# Finally, define the proc
	proc md5 {msg} $md5body

	# unset auxiliary variables
	unset md5body tName tVal map i
    }

    proc ::md5::byte0 {i} {expr {0xff & $i}}
    proc ::md5::byte1 {i} {expr {(0xff00 & $i) >> 8}}
    proc ::md5::byte2 {i} {expr {(0xff0000 & $i) >> 16}}
    proc ::md5::byte3 {i} {expr {((0xff000000 & $i) >> 24) & 0xff}}

    proc ::md5::bytes {i} {
	format %0.2x%0.2x%0.2x%0.2x [byte0 $i] [byte1 $i] [byte2 $i] [byte3 $i]
    }

    # hmac: hash for message authentication
    proc ::md5::hmac {key text} {
	# if key is longer than 64 bytes, reset it to MD5(key).  If shorter, 
	# pad it out with null (\x00) chars.
	set keyLen [string length $key]
	if {$keyLen > 64} {
	    set key [binary format H32 [md5 $key]]
	    set keyLen [string length $key]
	}

	# ensure the key is padded out to 64 chars with nulls.
	set padLen [expr {64 - $keyLen}]
	append key [binary format "a$padLen" {}]
	
	# Split apart the key into a list of 16 little-endian words
	binary scan $key i16 blocks

	# XOR key with ipad and opad values
	set k_ipad {}
	set k_opad {}
	foreach i $blocks {
	    append k_ipad [binary format i [expr {$i ^ 0x36363636}]]
	    append k_opad [binary format i [expr {$i ^ 0x5c5c5c5c}]]
	}
    
	# Perform inner md5, appending its results to the outer key
	append k_ipad $text
	append k_opad [binary format H* [md5 $k_ipad]]

	# Perform outer md5
	md5 $k_opad
    }
}

package provide md5 1.4.5
