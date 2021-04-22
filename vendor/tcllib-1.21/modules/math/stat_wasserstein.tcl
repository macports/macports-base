# stat-wasserstein.tcl --
#     Determine the Wasserstein distance between two probability distributions
#
#     Note:
#     This is an implementation for one-dimensional distributions (or better:
#     non-negative patterns)
#
#     Note 2:
#     The lower bound of 1.0e-10 is probably not at all necessary
#

# LastNonZero --
#     Auxiliary procedure to find the last non-zero entry
#
# Arguments:
#     prob           Probability distribution
#
# Result:
#     Index in the list of the last non-zero entry
#
# Note:
#     To avoid numerical problems any value smaller than 1.0e-10 is considered to
#     be zero
#
proc ::math::statistics::LastNonZero {prob} {
    set maxidx [expr {[llength $prob] - 1}]

    for {set idx $maxidx} {$idx >= 0} {incr idx -1} {
        if { [lindex $prob $idx] > 1.0e-10 } {
            return $idx
        }
    }

    return -1 ;# No non-zero entry
}

# Normalise --
#     Auxiliary procedure to normalise the probability distribution
#
# Arguments:
#     prob           Probability distribution
#
# Result:
#     Normalised distribution (i.e. the entries sum to 1)
#
# Note:
#     To avoid numerical problems any value smaller than 1.0e-10 is set to zero
#
proc ::math::statistics::Normalise {prob} {

    set newprob {}
    set sum     0.0

    foreach p $prob {
        set sum [expr {$sum + $p}]
    }

    if { $sum == 0.0 } {
        return -code error "Probability distribution should not consist of only zeroes"
    }

    foreach p $prob {
        lappend newprob [expr {$p > 1.0e-10? ($p/$sum) : 0.0}]
    }

    return $newprob
}

# wasserstein-distance --
#     Determine the Wasserstein distance using a "greedy" algorithm.
#
# Arguments:
#     prob1          First probability distribution, interpreted as a histogram
#                    with uniform bin width
#     prob2          Second probability distribution
#
# Result:
#     Distance between the two distributions
#
proc ::math::statistics::wasserstein-distance {prob1 prob2} {
    #
    # First step: make sure the histograms have the same length and the
    # same cumulative weight.
    #
    if { [llength $prob1] != [llength $prob2] } {
        return -code error "Lengths of the probability histograms must be the same"
    }

    set prob1 [Normalise $prob1]
    set prob2 [Normalise $prob2]

    set distance 0.0

    #
    # Determine the last non-zero bin - this bin will be shifted to the second
    # distribution
    #
    while {1} {
        set idx1 [LastNonZero $prob1]
        set idx2 [LastNonZero $prob2]

        if { $idx1 < 0 } {
            break ;# We are done
        }

        set bin1 [lindex $prob1 $idx1]
        set bin2 [lindex $prob2 $idx2]

        if { $bin1 <= $bin2 } {
            lset prob1 $idx1 0.0
            lset prob2 $idx2 [expr {$bin2 - $bin1}]
            set distance [expr {$distance + abs($idx2-$idx1) * $bin1}]
        } else {
            lset prob1 $idx1 [expr {$bin1 - $bin2}]
            lset prob2 $idx2 0.0
            set distance [expr {$distance + abs($idx2-$idx1) * $bin2}]
        }
    }

    return $distance
}

# kl-divergence --
#     Calculate the Kullback-Leibler (KL) divergence for two discrete distributions
#
# Arguments:
#     prob1          First probability distribution - the divergence is calculated
#                    with this one as the basis
#     prob2          Second probability distribution - the divergence of this
#                    distribution wrt the first is calculated
#
# Notes:
#     - The KL divergence is an asymmetric measure
#     - It is actually only defined if prob2 is only zero when prob1 is too
#     - The number of elements in the two distributions must be the same and
#       bins must be the same
#
proc ::math::statistics::kl-divergence {prob1 prob2} {
    if { [llength $prob1] != [llength $prob2] } {
        return -code error "Lengths of the two probability histograms must be the same"
    }

    #
    # Normalise the probability histograms
    #
    set prob1 [Normalise $prob1]
    set prob2 [Normalise $prob2]

    #
    # Check for well-definedness while going along
    #
    set sum 0.0
    foreach p1 $prob1 p2 $prob2 {
        if { $p2 == 0.0 && $p1 != 0.0 } {
            return -code error "Second probability histogram contains unmatched zeroes"
        }

        if { $p1 != 0.0 } {
            set sum [expr {$sum - $p1 * log($p2/$p1)}]
        }
    }

    return $sum
}

if {0} {
# tests --
#

# Almost trivial
set prob1 {0.0 0.0 0.0 1.0}
set prob2 {0.0 0.0 1.0 0.0}

puts "Expected distance: 1"
puts "Calculated: [wasserstein-distance $prob1 $prob2]"
puts "Symmetric:  [wasserstein-distance $prob2 $prob1]"

# Less trivial
set prob1 {0.0 0.75 0.25 0.0}
set prob2 {0.0 0.0  1.0  0.0}

puts "Expected distance: 0.75"
puts "Calculated: [wasserstein-distance $prob1 $prob2]"
puts "Symmetric:  [wasserstein-distance $prob2 $prob1]"

# Shift trivial
set prob1 {0.0 0.1 0.2 0.4 0.2 0.1 0.0 0.0}
set prob2 {0.0 0.0 0.0 0.1 0.2 0.4 0.2 0.1}

puts "Expected distance: 2"
puts "Calculated: [wasserstein-distance $prob1 $prob2]"
puts "Symmetric:  [wasserstein-distance $prob2 $prob1]"


# KL-divergence
set prob1 {0.0 0.1 0.2 0.4 0.2 0.1 0.0 0.0}
set prob2 {0.0 0.1 0.2 0.4 0.2 0.1 0.0 0.0}

puts "KL-divergence for equal distributions: 0"
puts "KL-divergence: [kl-divergence $prob1 $prob2]"

set prob1 {0.1e-8 0.1    0.2 0.4 0.2 0.1 0.0 0.0    0.0}
set prob2 {0.1e-8 0.1e-8 0.1 0.2 0.4 0.2 0.1 0.1e-8 0.1e-8}

puts "KL-divergence for shifted distributions: ??"
puts "KL-divergence: [kl-divergence $prob1 $prob2]"

# Hm, the normalisation proc causes a slight problem with elements of 1.0e-10
set prob1 {0.1e-8 0.1  0.2  0.4 0.2  0.1  0.0     0.0}
set prob2 {0.1e-8 0.11 0.19 0.4 0.24 0.06 0.1e-8  0.1e-8}

puts "KL-divergence slightly dififerent distributions: ??"
puts "KL-divergence: [kl-divergence $prob1 $prob2]"
}
