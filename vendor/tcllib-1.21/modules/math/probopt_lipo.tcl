# probopt_lipo.tcl --
#     Implementation of the LIPO algorithm to find
#     the global maximum of a function in a given region
#
#     Based on:
#     Cedric Malherbe and Nicolas Vayatis, Global optimization of Lipschitz functions,
#          june 2017, https://arxiv.org/pdf/1703.02628.pdf
#

# namespace --
#
namespace eval ::math::probopt {}

# Dist --
#     Determine the Euclidean distance between two points in N-dimensional space
#
# Arguments:
#     x                List of coordinates for the first point
#     y                List of coordinates for the second point
#
# Returns:
#     Euclidean distance between the two points
#
proc ::math::probopt::Dist {x y} {
    set dist 0.0

    foreach xc $x yc $y {
        set dist [expr {$dist + ($xc-$yc) ** 2}]
    }
    return $dist
}

# lipoMax --
#     Find the global maximum of a function in a given region
#
# Arguments:
#     f           Name of the procedure implementing the function
#     bounds      List of pairs of minimum and maximum per dimension
#     args        Key-value pairs for the options:
#                 -iterations number     Number of iterations (function evaluations; default: 100)
#                 -lipschitz  value      Estimate of the Lipschitz parameter (default: 10.0)
#
# Returns:
#     The coordinates of the point where the function attains the maximum
#     value that was encountered
#
proc ::math::probopt::lipoMax {f bounds args} {
    set options [dict create -iterations 100 -lipschitz 10.0]

    foreach {key value} $args {
        if { [dict key $options $key] != "" } {
            dict set options $key $value
        } else {
            return -code error "Unknown option: $key"
        }
    }

    set k [dict get $options -lipschitz]
    set n [dict get $options -iterations]

    #
    # Convert the region
    #
    set region {}
    foreach b $bounds {
        lassign $b min max
        lappend region $min $max
    }

    #
    # Initial guess
    #
    set coords  {}
    set fvalues {}
    foreach {min max} $region {
        set c [expr {$min + ($max-$min) * rand()}]
        lappend coords $c
    }

    set fval   [$f $coords]
    set maxval $fval
    set maxcrd $coords
    set nevals 1

    lappend fvalues    $fval
    lappend samples    $coords
    set     bestValues {}

    set numberSamples 1
    while { $numberSamples < $n } {
        # New guess
        set coords  {}
        foreach {min max} $region {
            set c [expr {$min + ($max-$min) * rand()}]
            lappend coords $c
        }

        # Check via Lipschitz condition
        foreach csample $samples fval $fvalues {
            set estimate [expr {$fval + $k * [Dist $coords $csample]}]

            if { $estimate > $maxval } {
                incr numberSamples
                set fval [$f $coords]
                incr nevals

                lappend samples $coords
                lappend fvalues $fval

                if { $fval > $maxval } {
                    set maxval $fval
                    set maxcrd $coords
                    #puts "$maxval -- $maxcrd"
                    lappend bestValues $maxval
                }
                break
            }
        }
    }

    return [dict create optimum-coordinates $maxcrd optimum-value $maxval evaluations $nevals best-values $bestValues]
}

# adaLipoMax --
#     Find the global maximum of a function in a given region,
#     using a heuristic estimate of the Lipschitz constant
#
# Arguments:
#     f           Name of the procedure implementing the function
#     bounds      List of minimum and maximum per dimension
#     args        Key-value pairs for the options:
#                 -iterations number     Number of iterations (function evaluations; default: 100)
#                 -bernoulli  value      Parameter for random decisions (default: 0.1)
#
# Returns:
#     The coordinates of the point where the function attains the maximum
#     value that was encountered
#
proc ::math::probopt::adaLipoMax {f bounds args} {
    set options [dict create -iterations 100 -bernoulli 0.1]

    foreach {key value} $args {
        if { [dict key $options $key] != "" } {
            dict set options $key $value
        } else {
            return -code error "Unknown option: $key"
        }
    }

    set p [dict get $options -bernoulli]
    set n [dict get $options -iterations]

    set kparam [expr {1.0 + 0.01/([llength $bounds])}]

    #
    # Convert the region
    #
    set region {}
    foreach b $bounds {
        lassign $b min max
        lappend region $min $max
    }

    #
    # Initial guess
    #
    set k       0.0
    set kmax    0.0
    set coords  {}
    set fvalues {}
    foreach {min max} $region {
        set c [expr {$min + ($max-$min) * rand()}]
        lappend coords $c
    }

    set fval   [$f $coords]
    set maxval $fval
    set maxcrd $coords
    set nevals 1

    lappend fvalues    $fval
    lappend samples    $coords
    set     bestValues {}

    set numberSamples 1
    while { $numberSamples < $n } {
        # New guess
        set coords  {}
        foreach {min max} $region {
            set c [expr {$min + ($max-$min) * rand()}]
            lappend coords $c
        }

        set added 0
        if { rand() < $p } {
            # Exploration ...
            set     added 1
            incr    numberSamples
            set     fval [$f $coords]
            incr    nevals

            lappend samples $coords
            lappend fvalues $fval
        } else {
            # Exploitation - check via Lipschitz condition
            foreach csample $samples fval $fvalues {
                set estimate [expr {$fval + $k * [Dist $coords $csample]}]

                if { $estimate > $maxval } {
                    set     added 1
                    incr    numberSamples
                    set     fval [$f $coords]
                    incr    nevals
                    lappend samples $coords
                    lappend fvalues $fval

                    if { $fval > $maxval } {
                        set maxval $fval
                        set maxcrd $coords
                        #puts "$maxval -- $maxcrd"
                        lappend bestValues $maxval
                    }
                    break
                }
            }
        }

        # Update the estimate of the Lipschitz constant
        foreach csample [lrange $samples 0 end-$added] fsample [lrange $fvalues 0 end-$added] {
            set estimate [expr {abs($fval - $fsample) / [Dist $coords $csample]}]

            if { $estimate > $kmax } {
                set kmax $estimate
            }
        }

        set k [expr {$kparam ** int($estimate/log($kparam)+0.99)}]
    }

    return [dict create optimum-coordinates $maxcrd optimum-value $maxval evaluations $nevals best-values $bestValues]
}
