# figurate.tcl --
#     Package for evaluating expressions regarding so-called figurate numbers:
#     - triangular numbers: sum of 1, 2, 3, ... n
#     - hex numbers: sum of centred hexagons with sides of n long, sum of 1, 6, 12, 18, ..., 6n
#     - etc.
#     - also sums of kth powers of 1, 2, 3, ... n (k = 1 to 10)
#
#     Inspired by "gold", definitions of the figurate numbers following https://mathworld.wolfram.com/FigurateNumber.html
#
package require Tcl 8.6
package provide math::figurate 1.0

namespace eval ::math::figurate {
    namespace export sum_sequence sum_squares sum_cubes sum_4th_power sum_5th_power sum_6th_power \
              sum_7th_power sum_8th_power sum_9th_power sum_10th_power \
              sum_sequence_odd sum_squares_odd sum_cubes_odd sum_4th_power_odd sum_5th_power_odd sum_6th_power_odd \
              sum_7th_power_odd sum_8th_power_odd sum_9th_power_odd sum_10th_power_odd \
              oblong pronic triangular square cubic biquadratic centeredSquare centeredCube centeredPentagonal \
              centeredHexagonal decagonal heptagonal hexagonal octagonal octahedral pentagonal squarePyramidal \
              tetrahedral pentatope centeredTriangular
}

# sum_* --
#     Compute the sums of powers of integers 1 to n
#
# Arguments:
#     n         Largest integer in the sum
#
# Returns:
#     Sum 1**k + 2**k + ... + n**k
#
proc ::math::figurate::sum_sequence {n} {
    expr {$n > 0 ? $n * ($n+1) / 2 : 0}
}

proc ::math::figurate::sum_squares {n} {
    expr {$n > 0 ? $n*($n + 1) * (2*$n +1 ) / 6 : 0}
}

proc ::math::figurate::sum_cubes {n} {
    expr {$n > 0 ? $n**2 * ($n + 1)**2 / 4 : 0}
}

proc ::math::figurate::sum_4th_power {n} {
    expr {$n > 0 ? $n* ($n + 1) * (2*$n + 1) * (3*$n**2 + 3*$n -1 ) / 30 : 0}
}

proc ::math::figurate::sum_5th_power {n} {
    expr {$n > 0 ? $n**2 * ($n + 1)**2 * (2*$n**2 + 2*$n - 1) / 12 : 0}
}

proc ::math::figurate::sum_6th_power {n} {
    expr {$n > 0 ? $n * ($n + 1) * (2*$n + 1 ) * (3*$n**4 + 6*$n**3 - 3*$n + 1) / 42 : 0}
}

proc ::math::figurate::sum_7th_power {n} {
    expr {$n > 0 ? $n**2 * ($n + 1)**2 * (3*$n**4 + 6*$n**3 - $n**2 - 4*$n + 2) / 24 : 0}
}

proc ::math::figurate::sum_8th_power {n} {
    expr {$n > 0 ? $n * ($n + 1) * (2*$n + 1) * (5*$n**6 + 15*$n**5 + 5*$n**4 - 15*$n**3 - $n**2 + 9*$n - 3) / 90 : 0}
}

proc ::math::figurate::sum_9th_power {n} {
    expr {$n > 0 ? $n**2 * ($n + 1)**2 * (2*$n**6 + 6*$n**5 + $n**4 - 8*$n**3 + $n**2 + 6*$n - 3) / 20 : 0}
}

proc ::math::figurate::sum_10th_power {n} {
    expr {$n > 0 ? $n * ($n + 1) * (2*$n + 1) * (3*$n**8 + 12*$n**7 + 8*$n**6 - 18*$n**5 - 10*$n**4 + 24*$n**3 + 2*$n**2 - 15*$n + 5) / 66 : 0}
}

# calculate sums of odd integers:
#
# Arguments:
#     n         Number of odd integers (not the largest number)
#
# Note:
#     The procedures sum the values (2*k+1)**m from k = 1 to n
#     The calculations rely on the following identity:
#
#     Sum (2k+1)**m = Sum j**m - 2**m Sum k**m, where k = 0,...,n, j = 0,..., 2*n+1
#
proc ::math::figurate::sum_sequence_odd {n} {
    if { $n > 0 } {
        set maxnum [expr {2 * $n - 1}]
        set sum1 [sum_sequence [expr {$n-1}]]
        set sum2 [sum_sequence $maxnum]

        return [expr {$sum2 - 2 * $sum1}]
    } else {
        return 0
    }
}

proc ::math::figurate::sum_squares_odd {n} {
    if { $n > 0 } {
        set maxnum [expr {2 * $n - 1}]
        set sum1 [sum_squares [expr {$n-1}]]
        set sum2 [sum_squares $maxnum]

        return [expr {$sum2 - 4 * $sum1}]
    } else {
        return 0
    }
}

proc ::math::figurate::sum_cubes_odd {n} {
    if { $n > 0 } {
        set maxnum [expr {2 * $n - 1}]
        set sum1 [sum_cubes [expr {$n-1}]]
        set sum2 [sum_cubes $maxnum]

        return [expr {$sum2 - 8 * $sum1}]
    } else {
        return 0
    }
}

proc ::math::figurate::sum_4th_power_odd {n} {
    if { $n > 0 } {
        set maxnum [expr {2 * $n - 1}]
        set sum1 [sum_4th_power [expr {$n-1}]]
        set sum2 [sum_4th_power $maxnum]

        return [expr {$sum2 - 16 * $sum1}]
    } else {
        return 0
    }
}

proc ::math::figurate::sum_5th_power_odd {n} {
    if { $n > 0 } {
        set maxnum [expr {2 * $n - 1}]
        set sum1 [sum_5th_power [expr {$n-1}]]
        set sum2 [sum_5th_power $maxnum]

        return [expr {$sum2 - 32 * $sum1}]
    } else {
        return 0
    }
}

proc ::math::figurate::sum_6th_power_odd {n} {
    if { $n > 0 } {
        set maxnum [expr {2 * $n - 1}]
        set sum1 [sum_6th_power [expr {$n-1}]]
        set sum2 [sum_6th_power $maxnum]

        return [expr {$sum2 - 64 * $sum1}]
    } else {
        return 0
    }
}

proc ::math::figurate::sum_7th_power_odd {n} {
    if { $n > 0 } {
        set maxnum [expr {2 * $n - 1}]
        set sum1 [sum_7th_power [expr {$n-1}]]
        set sum2 [sum_7th_power $maxnum]

        return [expr {$sum2 - 128 * $sum1}]
    } else {
        return 0
    }
}

proc ::math::figurate::sum_8th_power_odd {n} {
    if { $n > 0 } {
        set maxnum [expr {2 * $n - 1}]
        set sum1 [sum_8th_power [expr {$n-1}]]
        set sum2 [sum_8th_power $maxnum]

        return [expr {$sum2 - 256 * $sum1}]
    } else {
        return 0
    }
}

proc ::math::figurate::sum_9th_power_odd {n} {
    if { $n > 0 } {
        set maxnum [expr {2 * $n - 1}]
        set sum1 [sum_9th_power [expr {$n-1}]]
        set sum2 [sum_9th_power $maxnum]

        return [expr {$sum2 - 512 * $sum1}]
    } else {
        return 0
    }
}

proc ::math::figurate::sum_10th_power_odd {n} {
    if { $n > 0 } {
        set maxnum [expr {2 * $n - 1}]
        set sum1 [sum_10th_power [expr {$n-1}]]
        set sum2 [sum_10th_power $maxnum]

        return [expr {$sum2 - 1024 * $sum1}]
    } else {
        return 0
    }
}

# calculate figurate numbers --
#
# Arguments:
#     n         Largest integer in the sum
#
# Notes:
#     - pronic and oblong are identical (see Mathworld page)
#     - definitions follow the Mathworld page, though in some cases a more verbose name has been chosen
#       (instead of hex, centeredHexagonal)
#     - there are some trivial procedures as well (square for instance)
#     - for the interpretation: again see the Mathworld page
#
proc ::math::figurate::oblong {n} {
    expr {$n > 0 ? $n * ($n + 1) : 0}
}

proc ::math::figurate::pronic {n} {
    expr {$n > 0 ? $n * ($n + 1) : 0}
}

proc ::math::figurate::triangular {n} {
    expr {$n > 0 ? $n * ($n + 1)/2 : 0}
}

proc ::math::figurate::square {n} {
    expr {$n > 0 ? $n**2 : 0}
}

proc ::math::figurate::cubic {n} {
    expr {$n > 0 ? $n**3 : 0}
}

proc ::math::figurate::biquadratic {n} {
    expr {$n > 0 ? $n**4 : 0}
}

proc ::math::figurate::centeredTriangular {n} {
    expr {$n > 0 ? (3*$n**2 - 3*$n + 2) / 2 : 0}
}

proc ::math::figurate::centeredSquare {n} {
    expr {$n >0 ? $n**2 + ($n-1)**2 : 0}
}

proc ::math::figurate::centeredCube {n} {
    expr {$n > 0 ? $n**3 + ($n-1)**3 : 0}
}

proc ::math::figurate::centeredPentagonal {n} {
    expr {$n > 0 ? (5*($n-1)**2 + 5*($n-1) + 2) / 2 : 0}
}

proc ::math::figurate::centeredHexagonal {n} {
    expr {$n > 0 ? 3*($n-1)**2 + 3*($n-1) + 1 : 0}
}

proc ::math::figurate::decagonal {n} {
    expr {$n > 0 ? 4*$n**2 - 3*$n : 0}
}

proc ::math::figurate::heptagonal {n} {
    expr {$n > 0 ? $n * (5*$n - 3) / 2 : 0}
}

proc ::math::figurate::hexagonal {n} {
    expr {$n > 0 ? $n * (2*$n - 1) : 0}
}

proc ::math::figurate::octagonal {n} {
    expr {$n > 0 ? $n * (3*$n - 2) : 0}
}

proc ::math::figurate::octahedral {n} {
    expr {$n > 0 ? $n * (2*$n**2 + 1) / 3 : 0}
}

proc ::math::figurate::pentagonal {n} {
    expr {$n > 0 ? $n * (3*$n - 1) / 2 : 0}
}

proc ::math::figurate::squarePyramidal {n} {
    expr {$n > 0 ? $n * ($n + 1) * (2*$n + 1)/ 6 : 0}
}

proc ::math::figurate::tetrahedral {n} {
    expr {$n > 0 ? $n * ($n + 1) *  ($n + 2) / 6 : 0}
}

proc ::math::figurate::pentatope {n} {
    expr {$n > 0 ? $n * ($n + 1) *  ($n + 2) * ($n + 3) / 24 : 0}
}

