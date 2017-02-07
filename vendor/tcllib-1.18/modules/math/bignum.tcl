# bignum library in pure Tcl [VERSION 7Sep2004]
# Copyright (C) 2004 Salvatore Sanfilippo <antirez at invece dot org>
# Copyright (C) 2004 Arjen Markus <arjen dot markus at wldelft dot nl>
#
# LICENSE
#
# This software is:
# Copyright (C) 2004 Salvatore Sanfilippo <antirez at invece dot org>
# Copyright (C) 2004 Arjen Markus <arjen dot markus at wldelft dot nl>
# The following terms apply to all files associated with the software
# unless explicitly disclaimed in individual files.
#
# The authors hereby grant permission to use, copy, modify, distribute,
# and license this software and its documentation for any purpose, provided
# that existing copyright notices are retained in all copies and that this
# notice is included verbatim in any distributions. No written agreement,
# license, or royalty fee is required for any of the authorized uses.
# Modifications to this software may be copyrighted by their authors
# and need not follow the licensing terms described here, provided that
# the new terms are clearly indicated on the first page of each file where
# they apply.
#
# IN NO EVENT SHALL THE AUTHORS OR DISTRIBUTORS BE LIABLE TO ANY PARTY
# FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
# ARISING OUT OF THE USE OF THIS SOFTWARE, ITS DOCUMENTATION, OR ANY
# DERIVATIVES THEREOF, EVEN IF THE AUTHORS HAVE BEEN ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# THE AUTHORS AND DISTRIBUTORS SPECIFICALLY DISCLAIM ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.  THIS SOFTWARE
# IS PROVIDED ON AN "AS IS" BASIS, AND THE AUTHORS AND DISTRIBUTORS HAVE
# NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
# MODIFICATIONS.
#
# GOVERNMENT USE: If you are acquiring this software on behalf of the
# U.S. government, the Government shall have only "Restricted Rights"
# in the software and related documentation as defined in the Federal
# Acquisition Regulations (FARs) in Clause 52.227.19 (c) (2).  If you
# are acquiring the software on behalf of the Department of Defense, the
# software shall be classified as "Commercial Computer Software" and the
# Government shall have only "Restricted Rights" as defined in Clause
# 252.227-7013 (c) (1) of DFARs.  Notwithstanding the foregoing, the
# authors grant the U.S. Government and others acting in its behalf
# permission to use and distribute the software in accordance with the
# terms specified in this license.

# TODO
# - pow and powm should check if the exponent is zero in order to return one

package require Tcl 8.4

namespace eval ::math::bignum {}

#################################### Misc ######################################

# Don't change atombits define if you don't know what you are doing.
# Note that it must be a power of two, and that 16 is too big
# because expr may overflow in the product of two 16 bit numbers.
set ::math::bignum::atombits 16
set ::math::bignum::atombase [expr {1 << $::math::bignum::atombits}]
set ::math::bignum::atommask [expr {$::math::bignum::atombase-1}]

# Note: to change 'atombits' is all you need to change the
# library internal representation base.

# Return the max between a and b (not bignums)
proc ::math::bignum::max {a b} {
    expr {($a > $b) ? $a : $b}
}

# Return the min between a and b (not bignums)
proc ::math::bignum::min {a b} {
    expr {($a < $b) ? $a : $b}
}

############################ Basic bignum operations ###########################

# Returns a new bignum initialized to the value of 0.
#
# The big numbers are represented as a Tcl lists
# The all-is-a-string representation does not pay here
# bignums in Tcl are already slow, we can't slow-down it more.
#
# The bignum representation is [list bignum <sign> <atom0> ... <atomN>]
# Where the atom0 is the least significant. Atoms are the digits
# of a number in base 2^$::math::bignum::atombits
#
# The sign is 0 if the number is positive, 1 for negative numbers.

# Note that the function accepts an argument used in order to
# create a bignum of <atoms> atoms. For default zero is
# represented as a single zero atom.
#
# The function is designed so that "set b [zero [atoms $a]]" will
# produce 'b' with the same number of atoms as 'a'.
proc ::math::bignum::zero {{value 0}} {
    set v [list bignum 0 0]
    while { $value > 1 } {
       lappend v 0
       incr value -1
    }
    return $v
}

# Get the bignum sign
proc ::math::bignum::sign bignum {
    lindex $bignum 1
}

# Get the number of atoms in the bignum
proc ::math::bignum::atoms bignum {
    expr {[llength $bignum]-2}
}

# Get the i-th atom out of a bignum.
# If the bignum is shorter than i atoms, the function
# returns 0.
proc ::math::bignum::atom {bignum i} {
    if {[::math::bignum::atoms $bignum] < [expr {$i+1}]} {
	return 0
    } else {
	lindex $bignum [expr {$i+2}]
    }
}

# Set the i-th atom out of a bignum. If the bignum
# has less than 'i+1' atoms, add zero atoms to reach i.
proc ::math::bignum::setatom {bignumvar i atomval} {
    upvar 1 $bignumvar bignum
    while {[::math::bignum::atoms $bignum] < [expr {$i+1}]} {
	lappend bignum 0
    }
    lset bignum [expr {$i+2}] $atomval
}

# Set the bignum sign
proc ::math::bignum::setsign {bignumvar sign} {
    upvar 1 $bignumvar bignum
    lset bignum 1 $sign
}

# Remove trailing atoms with a value of zero
# The normalized bignum is returned
proc ::math::bignum::normalize bignumvar {
    upvar 1 $bignumvar bignum
    set atoms [expr {[llength $bignum]-2}]
    set i [expr {$atoms+1}]
    while {$atoms && [lindex $bignum $i] == 0} {
	set bignum [lrange $bignum 0 end-1]
	incr atoms -1
	incr i -1
    }
    if {!$atoms} {
	set bignum [list bignum 0 0]
    }
    return $bignum
}

# Return the absolute value of N
proc ::math::bignum::abs n {
    ::math::bignum::setsign n 0
    return $n
}

################################# Comparison ###################################

# Compare by absolute value. Called by ::math::bignum::cmp after the sign check.
#
# Returns 1 if |a| > |b|
#         0 if a == b
#        -1 if |a| < |b|
#
proc ::math::bignum::abscmp {a b} {
    if {[llength $a] > [llength $b]} {
	return 1
    } elseif {[llength $a] < [llength $b]} {
	return -1
    }
    set j [expr {[llength $a]-1}]
    while {$j >= 2} {
	if {[lindex $a $j] > [lindex $b $j]} {
	    return 1
	} elseif {[lindex $a $j] < [lindex $b $j]} {
	    return -1
	}
	incr j -1
    }
    return 0
}

# High level comparison. Return values:
#
#  1 if a > b
# -1 if a < b
#  0 if a == b
#
proc ::math::bignum::cmp {a b} { ; # same sign case
    set a [_treat $a]
    set b [_treat $b]
    if {[::math::bignum::sign $a] == [::math::bignum::sign $b]} {
	if {[::math::bignum::sign $a] == 0} {
	    ::math::bignum::abscmp $a $b
	} else {
	    expr {-([::math::bignum::abscmp $a $b])}
	}
    } else { ; # different sign case
	if {[::math::bignum::sign $a]} {return -1}
	return 1
    }
}

# Return true if 'z' is zero.
proc ::math::bignum::iszero z {
    set z [_treat $z]
    expr {[llength $z] == 3 && [lindex $z 2] == 0}
}

# Comparison facilities
proc ::math::bignum::lt {a b} {expr {[::math::bignum::cmp $a $b] < 0}}
proc ::math::bignum::le {a b} {expr {[::math::bignum::cmp $a $b] <= 0}}
proc ::math::bignum::gt {a b} {expr {[::math::bignum::cmp $a $b] > 0}}
proc ::math::bignum::ge {a b} {expr {[::math::bignum::cmp $a $b] >= 0}}
proc ::math::bignum::eq {a b} {expr {[::math::bignum::cmp $a $b] == 0}}
proc ::math::bignum::ne {a b} {expr {[::math::bignum::cmp $a $b] != 0}}

########################### Addition / Subtraction #############################

# Add two bignums, don't care about the sign.
proc ::math::bignum::rawAdd {a b} {
    while {[llength $a] < [llength $b]} {lappend a 0}
    while {[llength $b] < [llength $a]} {lappend b 0}
    set r [::math::bignum::zero [expr {[llength $a]-1}]]
    set car 0
    for {set i 2} {$i < [llength $a]} {incr i} {
	set sum [expr {[lindex $a $i]+[lindex $b $i]+$car}]
	set car [expr {$sum >> $::math::bignum::atombits}]
	set sum [expr {$sum & $::math::bignum::atommask}]
	lset r $i $sum
    }
    if {$car} {
	lset r $i $car
    }
    ::math::bignum::normalize r
}

# Subtract two bignums, don't care about the sign. a > b condition needed.
proc ::math::bignum::rawSub {a b} {
    set atoms [::math::bignum::atoms $a]
    set r [::math::bignum::zero $atoms]
    while {[llength $b] < [llength $a]} {lappend b 0} ; # b padding
    set car 0
    incr atoms 2
    for {set i 2} {$i < $atoms} {incr i} {
	set sub [expr {[lindex $a $i]-[lindex $b $i]-$car}]
	set car 0
	if {$sub < 0} {
	    incr sub $::math::bignum::atombase
	    set car 1
	}
	lset r $i $sub
    }
    # Note that if a > b there is no car in the last for iteration
    ::math::bignum::normalize r
}

# Higher level addition, care about sign and call rawAdd or rawSub
# as needed.
proc ::math::bignum::add {a b} {
    set a [_treat $a]
    set b [_treat $b]
    # Same sign case
    if {[::math::bignum::sign $a] == [::math::bignum::sign $b]} {
	set r [::math::bignum::rawAdd $a $b]
	::math::bignum::setsign r [::math::bignum::sign $a]
    } else {
	# Different sign case
	set cmp [::math::bignum::abscmp $a $b]
	# 's' is the sign, set accordingly to A or B negative
	set s [expr {[::math::bignum::sign $a] == 1}]
	switch -- $cmp {
	    0 {return [::math::bignum::zero]}
	    1 {
		set r [::math::bignum::rawSub $a $b]
		::math::bignum::setsign r $s
		return $r
	    }
	    -1 {
		set r [::math::bignum::rawSub $b $a]
		::math::bignum::setsign r [expr {!$s}]
		return $r
	    }
	}
    }
    return $r
}

# Higher level subtraction, care about sign and call rawAdd or rawSub
# as needed.
proc ::math::bignum::sub {a b} {
    set a [_treat $a]
    set b [_treat $b]
    # Different sign case
    if {[::math::bignum::sign $a] != [::math::bignum::sign $b]} {
	set r [::math::bignum::rawAdd $a $b]
	::math::bignum::setsign r [::math::bignum::sign $a]
    } else {
	# Same sign case
	set cmp [::math::bignum::abscmp $a $b]
	# 's' is the sign, set accordingly to A and B both negative or positive
	set s [expr {[::math::bignum::sign $a] == 1}]
	switch -- $cmp {
	    0 {return [::math::bignum::zero]}
	    1 {
		set r [::math::bignum::rawSub $a $b]
		::math::bignum::setsign r $s
		return $r
	    }
	    -1 {
		set r [::math::bignum::rawSub $b $a]
		::math::bignum::setsign r [expr {!$s}]
		return $r
	    }
	}
    }
    return $r
}

############################### Multiplication #################################

set ::math::bignum::karatsubaThreshold 32

# Multiplication. Calls Karatsuba that calls Base multiplication under
# a given threshold.
proc ::math::bignum::mul {a b} {
    set a [_treat $a]
    set b [_treat $b]
    set r [::math::bignum::kmul $a $b]
    # The sign is the xor between the two signs
    ::math::bignum::setsign r [expr {[::math::bignum::sign $a]^[::math::bignum::sign $b]}]
}

# Karatsuba Multiplication
proc ::math::bignum::kmul {a b} {
    set n [expr {[::math::bignum::max [llength $a] [llength $b]]-2}]
    set nmin [expr {[::math::bignum::min [llength $a] [llength $b]]-2}]
    if {$nmin < $::math::bignum::karatsubaThreshold} {return [::math::bignum::bmul $a $b]}
    set m [expr {($n+($n&1))/2}]

    set x0 [concat [list bignum 0] [lrange $a 2 [expr {$m+1}]]]
    set y0 [concat [list bignum 0] [lrange $b 2 [expr {$m+1}]]]
    set x1 [concat [list bignum 0] [lrange $a [expr {$m+2}] end]]
    set y1 [concat [list bignum 0] [lrange $b [expr {$m+2}] end]]

    if {0} {
    puts "m: $m"
    puts "x0: $x0"
    puts "x1: $x1"
    puts "y0: $y0"
    puts "y1: $y1"
    }

    set p1 [::math::bignum::kmul $x1 $y1]
    set p2 [::math::bignum::kmul $x0 $y0]
    set p3 [::math::bignum::kmul [::math::bignum::add $x1 $x0] [::math::bignum::add $y1 $y0]]

    set p3 [::math::bignum::sub $p3 $p1]
    set p3 [::math::bignum::sub $p3 $p2]
    set p1 [::math::bignum::lshiftAtoms $p1 [expr {$m*2}]]
    set p3 [::math::bignum::lshiftAtoms $p3 $m]
    set p3 [::math::bignum::add $p3 $p1]
    set p3 [::math::bignum::add $p3 $p2]
    return $p3
}

# Base Multiplication.
proc ::math::bignum::bmul {a b} {
    set r [::math::bignum::zero [expr {[llength $a]+[llength $b]-3}]]
    for {set j 2} {$j < [llength $b]} {incr j} {
	set car 0
	set t [list bignum 0 0]
	for {set i 2} {$i < [llength $a]} {incr i} {
	    # note that A = B * C + D + E
	    # with A of N*2 bits and C,D,E of N bits
	    # can't overflow since:
	    # (2^N-1)*(2^N-1)+(2^N-1)+(2^N-1) == 2^(2*N)-1
	    set t0 [lindex $a $i]
	    set t1 [lindex $b $j]
	    set t2 [lindex $r [expr {$i+$j-2}]]
	    set mul [expr {wide($t0)*$t1+$t2+$car}]
	    set car [expr {$mul >> $::math::bignum::atombits}]
	    set mul [expr {$mul & $::math::bignum::atommask}]
	    lset r [expr {$i+$j-2}] $mul
	}
	if {$car} {
	    lset r [expr {$i+$j-2}] $car
	}
    }
    ::math::bignum::normalize r
}

################################## Shifting ####################################

# Left shift 'z' of 'n' atoms. Low-level function used by ::math::bignum::lshift
# Exploit the internal representation to go faster.
proc ::math::bignum::lshiftAtoms {z n} {
    while {$n} {
	set z [linsert $z 2 0]
	incr n -1
    }
    return $z
}

# Right shift 'z' of 'n' atoms. Low-level function used by ::math::bignum::lshift
# Exploit the internal representation to go faster.
proc ::math::bignum::rshiftAtoms {z n} {
    set z [lreplace $z 2 [expr {$n+1}]]
}

# Left shift 'z' of 'n' bits. Low-level function used by ::math::bignum::lshift.
# 'n' must be <= $::math::bignum::atombits
proc ::math::bignum::lshiftBits {z n} {
    set atoms [llength $z]
    set car 0
    for {set j 2} {$j < $atoms} {incr j} {
	set t [lindex $z $j]
	lset z $j \
	    [expr {wide($car)|((wide($t)<<$n)&$::math::bignum::atommask)}]
	set car [expr {wide($t)>>($::math::bignum::atombits-$n)}]
    }
    if {$car} {
	lappend z 0
	lset z $j $car
    }
    return $z ; # No normalization needed
}

# Right shift 'z' of 'n' bits. Low-level function used by ::math::bignum::rshift.
# 'n' must be <= $::math::bignum::atombits
proc ::math::bignum::rshiftBits {z n} {
    set atoms [llength $z]
    set car 0
    for {set j [expr {$atoms-1}]} {$j >= 2} {incr j -1} {
	set t [lindex $z $j]
	lset z $j [expr {wide($car)|(wide($t)>>$n)}]
	set car \
	    [expr {(wide($t)<<($::math::bignum::atombits-$n))&$::math::bignum::atommask}]
    }
    ::math::bignum::normalize z
}

# Left shift 'z' of 'n' bits.
proc ::math::bignum::lshift {z n} {
    set z [_treat $z]
    set atoms [expr {$n / $::math::bignum::atombits}]
    set bits [expr {$n & ($::math::bignum::atombits-1)}]
    ::math::bignum::lshiftBits [math::bignum::lshiftAtoms $z $atoms] $bits
}

# Right shift 'z' of 'n' bits.
proc ::math::bignum::rshift {z n} {
    set z [_treat $z]
    set atoms [expr {$n / $::math::bignum::atombits}]
    set bits [expr {$n & ($::math::bignum::atombits-1)}]

    #
    # Correct for "arithmetic shift" - signed integers
    #
    set corr 0
    if { [::math::bignum::sign $z] == 1 } {
        for {set j [expr {$atoms+1}]} {$j >= 2} {incr j -1} {
            set t [lindex $z $j]
            if { $t != 0 } {
                set corr 1
            }
        }
        if { $corr == 0 } {
            set t [lindex $z [expr {$atoms+2}]]
            if { ( $t & ~($::math::bignum::atommask<<($bits)) ) != 0 } {
                set corr 1
            }
        }
    }

    set newz [::math::bignum::rshiftBits [math::bignum::rshiftAtoms $z $atoms] $bits]
    if { $corr } {
        set newz [::math::bignum::sub $newz 1]
    }
    return $newz
}

############################## Bit oriented ops ################################

# Set the bit 'n' of 'bignumvar'
proc ::math::bignum::setbit {bignumvar n} {
    upvar 1 $bignumvar z
    set atom [expr {$n / $::math::bignum::atombits}]
    set bit [expr {1 << ($n & ($::math::bignum::atombits-1))}]
    incr atom 2
    while {$atom >= [llength $z]} {lappend z 0}
    lset z $atom [expr {[lindex $z $atom]|$bit}]
}

# Clear the bit 'n' of 'bignumvar'
proc ::math::bignum::clearbit {bignumvar n} {
    upvar 1 $bignumvar z
    set atom [expr {$n / $::math::bignum::atombits}]
    incr atom 2
    if {$atom >= [llength $z]} {return $z}
    set mask [expr {$::math::bignum::atommask^(1 << ($n & ($::math::bignum::atombits-1)))}]
    lset z $atom [expr {[lindex $z $atom]&$mask}]
    ::math::bignum::normalize z
}

# Test the bit 'n' of 'z'. Returns true if the bit is set.
proc ::math::bignum::testbit {z n} {
    set  atom [expr {$n / $::math::bignum::atombits}]
    incr atom 2
    if {$atom >= [llength $z]} {return 0}
    set mask [expr {1 << ($n & ($::math::bignum::atombits-1))}]
    expr {([lindex $z $atom] & $mask) != 0}
}

# does bitwise and between a and b
proc ::math::bignum::bitand {a b} {
    # The internal number rep is little endian. Appending zeros is
    # equivalent to adding leading zeros to a regular big-endian
    # representation. The two numbers are extended to the same length,
    # then the operation is applied to the absolute value.
    set a [_treat $a]
    set b [_treat $b]
    while {[llength $a] < [llength $b]} {lappend a 0}
    while {[llength $b] < [llength $a]} {lappend b 0}
    set r [::math::bignum::zero [expr {[llength $a]-1}]]
    for {set i 2} {$i < [llength $a]} {incr i} {
	set or [expr {[lindex $a $i] & [lindex $b $i]}]
	lset r $i $or
    }
    ::math::bignum::normalize r
}

# does bitwise XOR between a and b
proc ::math::bignum::bitxor {a b} {
    # The internal number rep is little endian. Appending zeros is
    # equivalent to adding leading zeros to a regular big-endian
    # representation. The two numbers are extended to the same length,
    # then the operation is applied to the absolute value.
    set a [_treat $a]
    set b [_treat $b]
    while {[llength $a] < [llength $b]} {lappend a 0}
    while {[llength $b] < [llength $a]} {lappend b 0}
    set r [::math::bignum::zero [expr {[llength $a]-1}]]
    for {set i 2} {$i < [llength $a]} {incr i} {
	set or [expr {[lindex $a $i] ^ [lindex $b $i]}]
	lset r $i $or
    }
    ::math::bignum::normalize r
}

# does bitwise or between a and b
proc ::math::bignum::bitor {a b} {
    # The internal number rep is little endian. Appending zeros is
    # equivalent to adding leading zeros to a regular big-endian
    # representation. The two numbers are extended to the same length,
    # then the operation is applied to the absolute value.
    set a [_treat $a]
    set b [_treat $b]
    while {[llength $a] < [llength $b]} {lappend a 0}
    while {[llength $b] < [llength $a]} {lappend b 0}
    set r [::math::bignum::zero [expr {[llength $a]-1}]]
    for {set i 2} {$i < [llength $a]} {incr i} {
	set or [expr {[lindex $a $i] | [lindex $b $i]}]
	lset r $i $or
    }
    ::math::bignum::normalize r
}

# Return the number of bits needed to represent 'z'.
proc ::math::bignum::bits z {
    set atoms [::math::bignum::atoms $z]
    set bits [expr {($atoms-1)*$::math::bignum::atombits}]
    set atom [lindex $z [expr {$atoms+1}]]
    while {$atom} {
	incr bits
	set atom [expr {$atom >> 1}]
    }
    return $bits
}

################################## Division ####################################

# Division. Returns [list n/d n%d]
#
# I got this algorithm from PGP 2.6.3i (see the mp_udiv function).
# Here is how it works:
#
# Input:  N=(Nn,...,N2,N1,N0)radix2
#         D=(Dn,...,D2,D1,D0)radix2
# Output: Q=(Qn,...,Q2,Q1,Q0)radix2 = N/D
#         R=(Rn,...,R2,R1,R0)radix2 = N%D
#
# Assume: N >= 0, D > 0
#
# For j from 0 to n
#      Qj <- 0
#      Rj <- 0
# For j from n down to 0
#      R <- R*2
#      if Nj = 1 then R0 <- 1
#      if R => D then R <- (R - D), Qn <- 1
#
# Note that the doubling of R is usually done leftshifting one position.
# The only operations needed are bit testing, bit setting and subtraction.
#
# This is the "raw" version, don't care about the sign, returns both
# quotient and rest as a two element list.
# This procedure is used by divqr, div, mod, rem.
proc ::math::bignum::rawDiv {n d} {
    set bit [expr {[::math::bignum::bits $n]-1}]
    set r [list bignum 0 0]
    set q [::math::bignum::zero [expr {[llength $n]-2}]]
    while {$bit >= 0} {
	set b_atom [expr {($bit / $::math::bignum::atombits) + 2}]
	set b_bit [expr {1 << ($bit & ($::math::bignum::atombits-1))}]
	set r [::math::bignum::lshiftBits $r 1]
	if {[lindex $n $b_atom]&$b_bit} {
	    lset r 2 [expr {[lindex $r 2] | 1}]
	}
	if {[::math::bignum::abscmp $r $d] >= 0} {
	    set r [::math::bignum::rawSub $r $d]
	    lset q $b_atom [expr {[lindex $q $b_atom]|$b_bit}]
	}
	incr bit -1
    }
    ::math::bignum::normalize q
    list $q $r
}

# Divide by single-atom immediate. Used to speedup bignum -> string conversion.
# The procedure returns a two-elements list with the bignum quotient and
# the remainder (that's just a number being <= of the max atom value).
proc ::math::bignum::rawDivByAtom {n d} {
    set atoms [::math::bignum::atoms $n]
    set t 0
    set j $atoms
    incr j -1
    for {} {$j >= 0} {incr j -1} {
	set t [expr {($t << $::math::bignum::atombits)+[lindex $n [expr {$j+2}]]}]
	lset n [expr {$j+2}] [expr {$t/$d}]
	set t [expr {$t % $d}]
    }
    ::math::bignum::normalize n
    list $n $t
}

# Higher level division. Returns a list with two bignums, the first
# is the quotient of n/d, the second the remainder n%d.
# Note that if you want the *modulo* operator you should use ::math::bignum::mod
#
# The remainder sign is always the same as the divident.
proc ::math::bignum::divqr {n d} {
    set n [_treat $n]
    set d [_treat $d]
    if {[::math::bignum::iszero $d]} {
	error "Division by zero"
    }
    foreach {q r} [::math::bignum::rawDiv $n $d] break
    ::math::bignum::setsign q [expr {[::math::bignum::sign $n]^[::math::bignum::sign $d]}]
    ::math::bignum::setsign r [::math::bignum::sign $n]
    list $q $r
}

# Like divqr, but only the quotient is returned.
proc ::math::bignum::div {n d} {
    lindex [::math::bignum::divqr $n $d] 0
}

# Like divqr, but only the remainder is returned.
proc ::math::bignum::rem {n d} {
    lindex [::math::bignum::divqr $n $d] 1
}

# Modular reduction. Returns N modulo M
proc ::math::bignum::mod {n m} {
    set n [_treat $n]
    set m [_treat $m]
    set r [lindex [::math::bignum::divqr $n $m] 1]
    if {[::math::bignum::sign $m] != [::math::bignum::sign $r]} {
	set r [::math::bignum::add $r $m]
    }
    return $r
}

# Returns true if n is odd
proc ::math::bignum::isodd n {
    expr {[lindex $n 2]&1}
}

# Returns true if n is even
proc ::math::bignum::iseven n {
    expr {!([lindex $n 2]&1)}
}

############################# Power and Power mod N ############################

# Returns b^e
proc ::math::bignum::pow {b e} {
    set b [_treat $b]
    set e [_treat $e]
    if {[::math::bignum::iszero $e]} {return [list bignum 0 1]}
    # The power is negative is the base is negative and the exponent is odd
    set sign [expr {[::math::bignum::sign $b] && [::math::bignum::isodd $e]}]
    # Set the base to it's abs value, i.e. make it positive
    ::math::bignum::setsign b 0
    # Main loop
    set r [list bignum 0 1]; # Start with result = 1
    while {[::math::bignum::abscmp $e [list bignum 0 1]] > 0} { ;# While the exp > 1
	if {[::math::bignum::isodd $e]} {
	    set r [::math::bignum::mul $r $b]
	}
	set e [::math::bignum::rshiftBits $e 1] ;# exp = exp / 2
	set b [::math::bignum::mul $b $b]
    }
    set r [::math::bignum::mul $r $b]
    ::math::bignum::setsign r $sign
    return $r
}

# Returns b^e mod m
proc ::math::bignum::powm {b e m} {
    set b [_treat $b]
    set e [_treat $e]
    set m [_treat $m]
    if {[::math::bignum::iszero $e]} {return [list bignum 0 1]}
    # The power is negative is the base is negative and the exponent is odd
    set sign [expr {[::math::bignum::sign $b] && [::math::bignum::isodd $e]}]
    # Set the base to it's abs value, i.e. make it positive
    ::math::bignum::setsign b 0
    # Main loop
    set r [list bignum 0 1]; # Start with result = 1
    while {[::math::bignum::abscmp $e [list bignum 0 1]] > 0} { ;# While the exp > 1
	if {[::math::bignum::isodd $e]} {
	    set r [::math::bignum::mod [::math::bignum::mul $r $b] $m]
	}
	set e [::math::bignum::rshiftBits $e 1] ;# exp = exp / 2
	set b [::math::bignum::mod [::math::bignum::mul $b $b] $m]
    }
    set r [::math::bignum::mul $r $b]
    ::math::bignum::setsign r $sign
    set r [::math::bignum::mod $r $m]
    return $r
}

################################## Square Root #################################

# SQRT using the 'binary sqrt algorithm'.
#
# The basic algoritm consists in starting from the higer-bit
# the real square root may have set, down to the bit zero,
# trying to set every bit and checking if guess*guess is not
# greater than 'n'. If it is greater we don't set the bit, otherwise
# we set it. In order to avoid to compute guess*guess a trick
# is used, so only addition and shifting are really required.
proc ::math::bignum::sqrt n {
    if {[lindex $n 1]} {
	error "Square root of a negative number"
    }
    set i [expr {(([::math::bignum::bits $n]-1)/2)+1}]
    set b [expr {$i*2}] ; # Bit to set to get 2^i*2^i

    set r [::math::bignum::zero] ; # guess
    set x [::math::bignum::zero] ; # guess^2
    set s [::math::bignum::zero] ; # guess^2 backup
    set t [::math::bignum::zero] ; # intermediate result
    for {} {$i >= 0} {incr i -1; incr b -2} {
	::math::bignum::setbit t $b
	set x [::math::bignum::rawAdd $s $t]
	::math::bignum::clearbit t $b
	if {[::math::bignum::abscmp $x $n] <= 0} {
	    set s $x
	    ::math::bignum::setbit r $i
	    ::math::bignum::setbit t [expr {$b+1}]
	}
	set t [::math::bignum::rshiftBits $t 1]
    }
    return $r
}

################################## Random Number ###############################

# Returns a random number in the range [0,2^n-1]
proc ::math::bignum::rand bits {
    set atoms [expr {($bits+$::math::bignum::atombits-1)/$::math::bignum::atombits}]
    set shift [expr {($atoms*$::math::bignum::atombits)-$bits}]
    set r [list bignum 0]
    while {$atoms} {
	lappend r [expr {int(rand()*(1<<$::math::bignum::atombits))}]
	incr atoms -1
    }
    set r [::math::bignum::rshiftBits $r $shift]
    return $r
}

############################ Convertion to/from string #########################

# The string representation charset. Max base is 36
set ::math::bignum::cset "0123456789abcdefghijklmnopqrstuvwxyz"

# Convert 'z' to a string representation in base 'base'.
# Note that this is missing a simple but very effective optimization
# that's to divide by the biggest power of the base that fits
# in a Tcl plain integer, and then to perform divisions with [expr].
proc ::math::bignum::tostr {z {base 10}} {
    if {[string length $::math::bignum::cset] < $base} {
	error "base too big for string convertion"
    }
    if {[::math::bignum::iszero $z]} {return 0}
    set sign [::math::bignum::sign $z]
    set str {}
    while {![::math::bignum::iszero $z]} {
	foreach {q r} [::math::bignum::rawDivByAtom $z $base] break
	append str [string index $::math::bignum::cset $r]
	set z $q
    }
    if {$sign} {append str -}
    # flip the resulting string
    set flipstr {}
    set i [string length $str]
    incr i -1
    while {$i >= 0} {
	append flipstr [string index $str $i]
	incr i -1
    }
    return $flipstr
}

# Create a bignum from a string representation in base 'base'.
proc ::math::bignum::fromstr {str {base 0}} {
    set z [::math::bignum::zero]
    set str [string trim $str]
    set sign 0
    if {[string index $str 0] eq {-}} {
	set str [string range $str 1 end]
	set sign 1
    }
    if {$base == 0} {
	switch -- [string tolower [string range $str 0 1]] {
	    0x {set base 16; set str [string range $str 2 end]}
	    ox {set base 8 ; set str [string range $str 2 end]}
	    bx {set base 2 ; set str [string range $str 2 end]}
	    default {set base 10}
	}
    }
    if {[string length $::math::bignum::cset] < $base} {
	error "base too big for string convertion"
    }
    set bigbase [list bignum 0 $base] ; # Build a bignum with the base value
    set basepow [list bignum 0 1] ; # multiply every digit for a succ. power
    set i [string length $str]
    incr i -1
    while {$i >= 0} {
	set digitval [string first [string index $str $i] $::math::bignum::cset]
	if {$digitval == -1} {
	    error "Illegal char '[string index $str $i]' for base $base"
	}
	set bigdigitval [list bignum 0 $digitval]
	set z [::math::bignum::rawAdd $z [::math::bignum::mul $basepow $bigdigitval]]
	set basepow [::math::bignum::mul $basepow $bigbase]
	incr i -1
    }
    if {![::math::bignum::iszero $z]} {
	::math::bignum::setsign z $sign
    }
    return $z
}

#
# Pre-treatment of some constants : 0 and 1
# Updated 19/11/2005 : abandon the 'upvar' command and its cost
#
proc ::math::bignum::_treat {num} {
    if {[llength $num]<2} {
        if {[string equal $num 0]} {
            # set to the bignum 0
            return {bignum 0 0}
        } elseif {[string equal $num 1]} {
            # set to the bignum 1
            return {bignum 0 1}
        }
    }
    return $num
}

namespace eval ::math::bignum {
    namespace export *
}

# Announce the package

package provide math::bignum 3.1.1
