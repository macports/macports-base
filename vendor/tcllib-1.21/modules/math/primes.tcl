##
## This is the file `primes.tcl',
## generated with the SAK utility
## (sak docstrip/regen).
##
## The original source files were:
##
## numtheory.dtx  (with options: `pkg_primes pkg_common')
##
## In other words:
## **************************************
## * This Source is not the True Source *
## **************************************
## the true source is the file from which this one was generated.
##
# Copyright (c) 2010 by Lars Hellstrom.  All rights reserved.
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# primes.tcl --
#     Provide additional procedures for the number theory package
#
namespace eval ::math::numtheory {
    variable primes {2 3 5 7 11 13 17}
    variable nextPrimeCandidate 19
    variable nextPrimeIncrement  1 ;# Examine numbers 6n+1 and 6n+5

    namespace export firstNprimes primesLowerThan primeFactors uniquePrimeFactors factors \
                     totient moebius legendre jacobi gcd lcm \
                     numberPrimesGauss numberPrimesLegendre numberPrimesLegendreModified \
                     differenceNumberPrimesLegendreModified listPrimeProgressions
}

# ComputeNextPrime --
#     Determine the next prime
#
# Arguments:
#     None
#
# Result:
#     None
#
# Side effects:
#     One prime added to the list of primes
#
# Note:
#     Using a true sieve of Erathostenes might be faster, but
#     this does work. Even computing the first ten thousand
#     does not seem to be slow.
#
proc ::math::numtheory::ComputeNextPrime {} {
    variable primes
    variable nextPrimeCandidate
    variable nextPrimeIncrement

    while {1} {
        #
        # Test the current candidate
        #
        set sqrtCandidate [expr {sqrt($nextPrimeCandidate)}]

        set isprime 1
        foreach p $primes {
            if { $p > $sqrtCandidate } {
                break
            }
            if { $nextPrimeCandidate % $p == 0 } {
                set isprime 0
                break
            }
        }

        if { $isprime } {
            lappend primes $nextPrimeCandidate
        }

        #
        # In any case get the next candidate
        #
        if { $nextPrimeIncrement == 1 } {
            set nextPrimeIncrement 5
            set nextPrimeCandidate [expr {$nextPrimeCandidate + 4}]
        } else {
            set nextPrimeIncrement 1
            set nextPrimeCandidate [expr {$nextPrimeCandidate + 2}]
        }

        if { $isprime } {
            break
        }
    }
}

# firstNprimes --
#     Return the first N primes
#
# Arguments:
#     number           Number of primes to return
#
# Result:
#     List of the first $number primes
#
proc ::math::numtheory::firstNprimes {number} {
    variable primes

    while { [llength $primes] < $number } {
        ComputeNextPrime
    }

    return [lrange $primes 0 [expr {$number-1}]]
}

# primesLowerThan --
#     Return the primes lower than some threshold
#
# Arguments:
#     threshold        Threshold for the primes
#
# Result:
#     List of primes lower/equal to the threshold
#
proc ::math::numtheory::primesLowerThan {threshold} {
    variable primes

    while { [lindex $primes end] < $threshold } {
        ComputeNextPrime
    }

    set n 0
    foreach p $primes {
        if { $p > $threshold } {
            break
        } else {
            incr n
        }
    }
    return [lrange $primes 0 [expr {$n-1}]]
}

# primeFactors --
#     Determine the prime factors of a number
#
# Arguments:
#     number           Number to factorise
#
# Result:
#     List of prime factors
#
proc ::math::numtheory::primeFactors {number} {
    variable primes

    #
    # Make sure we have enough primes
    #
    primesLowerThan [expr {sqrt($number)}]

    set factors {}

    set idx 0

    while { $number > 1 } {
        set p [lindex $primes $idx]
        if {$p == {}} {
            lappend factors $number
            break
        }
        if { $number % $p == 0 } {
            lappend factors $p
            set number [expr {$number/$p}]
        } else {
            incr idx
        }
    }

    return $factors
}

# uniquePrimeFactors --
#     Determine the unique prime factors of a number
#
# Arguments:
#     number           Number to factorise
#
# Result:
#     List of unique prime factors
#
proc ::math::numtheory::uniquePrimeFactors {number} {
    return [lsort -unique -integer [primeFactors $number]]
}

# totient --
#     Evaluate the Euler totient function for a number
#
# Arguments:
#     number           Number in question
#
# Result:
#     Totient of the given number (number of numbers
#     relatively prime to the number)
#
proc ::math::numtheory::totient {number} {
    set factors [uniquePrimeFactors $number]

    set totient $number

    foreach f $factors {
        set totient [expr {($totient * ($f-1)) / $f}]
    }

    return $totient
}

# factors --
#     Return all (unique) factors of a number
#
# Arguments:
#     number           Number in question
#
# Result:
#     List of factors including 1 and the number itself
#
# Note:
#     The algorithm for constructing the power set was taken from
#     wiki.tcl.tk/2877 (algorithm subsets2b).
#
proc ::math::numtheory::factors {number} {
    set factors [primeFactors $number]

    #
    # Iterate over the power set of this list
    #
    set result [list 1 $number]
    for {set n 1} {$n < [llength $factors]} {incr n} {
        set subsets [list [list]]
        foreach f $factors {
            foreach subset $subsets {
                lappend subset $f
                if {[llength $subset] == $n} {
                    lappend result [Product $subset]
                } else {
                    lappend subsets $subset
                }
            }
        }
    }
    return [lsort -unique -integer $result]
}

# Product --
#     Auxiliary function: return the product of a list of numbers
#
# Arguments:
#     list           List of numbers
#
# Result:
#     The product of all the numbers
#
proc ::math::numtheory::Product {list} {
    set product 1
    foreach e $list {
        set product [expr {$product * $e}]
    }
    return $product
}

# moebius --
#     Return the value of the Moebius function for "number"
#
# Arguments:
#     number         Number in question
#
# Result:
#     The product of all the numbers
#
proc ::math::numtheory::moebius {number} {
    if { $number < 1 } {
        return -code error "The number must be positive"
    }
    if { $number == 1 } {
        return 1
    }

    set primefactors [primeFactors $number]
    if { [llength $primefactors] != [llength [lsort -unique -integer $primefactors]] } {
        return 0
    } else {
        return [expr {(-1)**([llength $primefactors]%2)}]
    }
}

# legendre --
#     Return the value of the Legendre symbol (a/p)
#
# Arguments:
#     a              Upper number in the symbol
#     p              Lower number in the symbol
#
# Result:
#     The Legendre symbol
#
proc ::math::numtheory::legendre {a p} {
    if { $p == 0 } {
        return -code error "The number p must be non-zero"
    }

    if { $a % $p == 0 } {
        return 0
    }

    #
    # Just take the brute force route
    # (Negative values of a present a small problem, but only a small one)
    #
    while { $a < 0 } {
        set a [expr {$p + $a}]
    }

    set legendre -1
    for {set n 1} {$n < $p} {incr n} {
        if { $n**2 % $p == $a } {
            set legendre 1
            break
        }
    }

    return $legendre
}

# jacobi --
#     Return the value of the Jacobi symbol (a/b)
#
# Arguments:
#     a              Upper number in the symbol
#     b              Lower number in the symbol
#
# Result:
#     The Jacobi symbol
#
# Note:
#     Implementation adopted from the Wiki - http://wiki.tcl.tk/36990
#     encoded by rmelton 9/25/12
#     Further references:
#     http://en.wikipedia.org/wiki/Jacobi_symbol
#     http://2000clicks.com/mathhelp/NumberTh27JacobiSymbolAlgorithm.aspx
#
proc ::math::numtheory::jacobi {a b} {
    if { $b<=0 || ($b&1)==0 } {
        return 0;
    }

    set j 1
    if {$a<0} {
        set a [expr {0-$a}]
        set j [expr {0-$j}]
    }
    while {$a != 0} {
        while {($a&1) == 0} {
            ##/* Process factors of 2: Jacobi(2,b)=-1 if b=3,5 (mod 8) */
            set a [expr {$a>>1}]
            if {(($b & 7)==3) || (($b & 7)==5)} {
                set j [expr {0-$j}]
            }
        }
        ##/* Quadratic reciprocity: Jacobi(a,b)=-Jacobi(b,a) if a=3,b=3 (mod 4) */
        lassign [list $a $b] b a
        if {(($a & 3)==3) && (($b & 3)==3)} {
            set j [expr {0-$j}]
        }
        set a [expr {$a % $b}]
    }
    if {$b==1} {
        return $j
    } else {
        return 0
    }
}

# gcd --
#     Return the greatest common divisor of two numbers n and m
#
# Arguments:
#     n              First number
#     m              Second number
#
# Result:
#     The greatest common divisor
#
proc ::math::numtheory::gcd {n m} {
    #
    # Apply Euclid's good old algorithm
    #
    if { $n > $m } {
        set t $n
        set n $m
        set m $t
    }

    while { $n > 0 } {
        set r [expr {$m % $n}]
        set m $n
        set n $r
    }

    return $m
}

# lcm --
#     Return the lowest common multiple of two numbers n and m
#
# Arguments:
#     n              First number
#     m              Second number
#
# Result:
#     The lowest common multiple
#
proc ::math::numtheory::lcm {n m} {
    set gcd [gcd $n $m]
    return [expr {$n*$m/$gcd}]
}

# numberPrimesGauss --
#     Return the approximate number of primes lower than the given value based on the formula by Gauss
#
# Arguments:
#     limit            The limit for the largest prime to be included in the estimate
#
# Returns:
#     Approximate number of primes
#
proc ::math::numtheory::numberPrimesGauss {limit} {
    if { $limit <= 1 } {
        return -code error "The limit must be larger than 1"
    }
    expr {$limit / log($limit)}
}

# numberPrimesLegendre --
#     Return the approximate number of primes lower than the given value based on the formula by Legendre
#
# Arguments:
#     limit            The limit for the largest prime to be included in the estimate
#
# Returns:
#     Approximate number of primes
#
proc ::math::numtheory::numberPrimesLegendre {limit} {
    if { $limit <= 1 } {
        return -code error "The limit must be larger than 1"
    }
    expr {$limit / (log($limit) - 1.0)}
}

# numberPrimesLegendreModified --
#     Return the approximate number of primes lower than the given value based on the
#     modified formula by Legendre
#
# Arguments:
#     limit            The limit for the largest prime to be included in the estimate
#
# Returns:
#     Approximate number of primes
#
proc ::math::numtheory::numberPrimesLegendreModified {limit} {
    if { $limit <= 1 } {
        return -code error "The limit must be larger than 1"
    }
    expr {$limit / (log($limit) - 1.08366)}
}

# differenceNumberPrimesLegendreModified --
#     Return the approximate difference number of primes
#     between a lower and higher limit as given values
#     for approximate number of primes based on the
#     modified formula by Legendre
#
# Arguments:
#     limit1     The lower limit for the interval, largest prime to be included in the l.limit
#     limit2     The upper limit for the interval, largest prime to be included in the u.mlimit
#
# Returns:
#     Approximate difference number of primes
#
proc ::math::numtheory::differenceNumberPrimesLegendreModified {limit1 limit2} {
    if { $limit1 <= 1 } {
        return -code error "The lower limit must be larger than 1"
    }
    if { $limit2 <= 1 } {
        return -code error "The upper limit must be larger than 1"
    }

     set aa [::math::numtheory::numberPrimesLegendreModified [expr ($limit1)]]
     set bb [::math::numtheory::numberPrimesLegendreModified [expr ($limit2)]]
     expr {abs($bb-$aa)}
}

# listPrimeProgressions --
#     Return a list of arithmetic progressions of primes that differ by a given number
#
# Arguments:
#     lower      The lower limit for the interval from which to chose the primes
#     upper      The upper limit for the interval
#     step       The difference between sucessive primes (default to 2)
#
# Returns:
#     A list of lists of successive primes differing the given step
#
proc ::math::numtheory::listPrimeProgressions {lower upper {step 2}} {
    if { $upper <= $lower } {
        return -code error "The upper limit must be larger than the lower limit"
    }
    if { $step <= 0 } {
        return -code error "The step must be at least 1"
    }

    set output {}
    set found  {}
    for {set i $lower} {$i <= $upper} {incr i 1} {
        if { [isprime $i] } {
            set newset $i
            for { set j [expr {$i + $step}]} {$j <= $upper} {incr j $step} {
                if { [isprime $j] && $j ni $found } {
                    lappend newset $j
                    lappend found  $j
                } else {
                    break
                }
            }
            if { [llength $newset] > 1 } {
                lappend output $newset
            }
        }
    }

    return $output
}

# listPrimePairs --
#     Return a list of pairso of primes that differ by a given number
#
# Arguments:
#     lower      The lower limit for the interval from which to chose the primes
#     upper      The upper limit for the interval
#     step       The difference between sucessive primes (default to 2)
#
# Returns:
#     A list of pairs of primes differing the given step
#
proc ::math::numtheory::listPrimePairs {lower upper {step 2}} {
    if { $upper <= $lower } {
        return -code error "The upper limit must be larger than the lower limit"
    }
    if { $step <= 0 } {
        return -code error "The step must be at least 1"
    }

    set output {}
    for {set i $lower} {$i <= $upper} {incr i 1} {
        set next [expr {$i + $step}]
        if { [isprime $i] && [isprime $next] } {
            lappend output [list $i $next]
        }
    }

    return $output
}

##
##
## End of file `primes.tcl'.
