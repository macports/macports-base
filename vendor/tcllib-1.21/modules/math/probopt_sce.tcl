# probopt_sce.tcl --
#     Implementation of the "shuffled complexes evolution" optimisation method in Tcl
#
#     Note:
#     This implementation is based on:
#     - Qingyuan Duan, Soroosh Sorooshian and Vijai Gupta:
#       Optimal use of the SCE-UA global optimisation method for calibrating
#       watershed models, Journal of Hydrology, volume 158, 1994, pp. 265-284
#
#     - Q.Y. Duan, V.K. Gupta and S. Sorooshian:
#       Shuffled Comples Evolution Approach for Effective and Efficient
#       Global Minimization, Journal of Optimization Theory and Applications,
#       volume 76, no. 3, 1993, pp. 501-521
#
#     TODO:
#     - Limit the number of iterations
#     - Provide a dictionary of calculation results
#

# namespace --
#
namespace eval ::math::probopt {
    variable sceNevals 0
}

# sce --
#     Front-end procedure for the SCE algorithm
#
# Arguments:
#     func            Function for which the global minimum is to be found
#     bounds          Boundaries for all independent variables of the function,
#                     as a list of pairs of minimum and maximum
#     args            Set of options - key-value pairs
#
# Result:
#     Estimate of the global minimum as found via the procedure
#
proc ::math::probopt::sce {func bounds args} {
    variable sceNevals
    #
    # Set the default options
    #
    set dims [llength $bounds]
    set options [dict create -complexes 2 -mincomplexes 2 -newpoints 1 -shuffle 0 -pointspercomplex 0 -pointspersubcomplex 0 \
                             -iterations 100 -maxevaluations 1.0e9 -abstolerance 0.0 -reltolerance 0.001]
    #
    # Handle the options
    #

    foreach {key value} $args {
        if { [dict exists $options $key] } {
                dict set options $key $value
        } else {
            return -code error "Unknown option: $key"
        }
    }

    dict with options {}

    #
    # Recalculate a few options
    #
    foreach v {-shuffle -pointspercomplex} {
        if { [set $v] == 0 } {
            set $v [expr {2*$dims + 1}]
            dict set options $v [set $v]
        }
    }
    set v "-pointspersubcomplex"
    if { [set $v] == 0 } {
        set $v [expr {$dims + 1}]
        dict set options $v [set $v]
    }

    #
    # Ready to call the actual procedure
    #
    set sceNEvals 0

    return [SceCompute $func $bounds $options]

    #SceCompute $func $bounds $options
}

# SceCompute --
#     Actually compute the global optimum using the SCE algorithm
#
# Arguments:
#     func            Function for which the global minimum is to be found
#     bounds          Boundaries for all independent variables of the function,
#                     as a list of pairs of minimum and maximum
#     options         Dictionary of options
#
# Result:
#     Dictionary containing among other things the estimate of the
#     global minimum as found via the procedure
#
proc ::math::probopt::SceCompute {func bounds options} {
    variable sceNEvals

    set dims         [llength $bounds]
    set npcomplex    [dict get $options -pointspercomplex]
    set p            [dict get $options -complexes]
    set pmin         [dict get $options -mincomplexes]
    set npsubcomplex [dict get $options -pointspersubcomplex]
    set nnewpoints   [dict get $options -newpoints]
    set nshuffle     [dict get $options -shuffle]
    set niterations  [dict get $options -iterations]
    set abstol       [dict get $options -abstolerance]
    set reltol       [dict get $options -reltolerance]

    set npoints [expr {$npcomplex * $p}]

    #
    # Generate the initial set of points
    #
    set points {}
    for {set i 0} {$i < $p} {incr i} {
        for {set k 0} {$k < $npcomplex} {incr k} {
            set coords [GeneratePoint $bounds]
            lappend points [list $coords [$func $coords]]
            incr sceNEvals
        }
    }

    for {set iteration 0} {$iteration < $niterations} {incr iteration} {
        #
        # Sort the points and create subcomplexes
        #
        set points [lsort -index 1 -increasing $points]

        array unset complex
        for {set i 0} {$i < $p} {incr i} {
            for {set k 0} {$k < $npcomplex} {incr k} {
                lappend complex($i) [lindex $points [expr {$k*$p + $i}]]
            }
        }

        #
        # Optimise the subcomplexes
        #
        for {set i 0} {$i < $p} {incr i} {
            for {set shuffle 0} {$shuffle < $nshuffle} {incr shuffle} {
                set complex($i) [OptimiseComplex $complex($i) $npsubcomplex $nnewpoints $func $bounds]
            }
        }

        #
        # Join the subcomplexes into a list of points and sort the points
        #
        set points {}

        for {set i 0} {$i < $p} {incr i} {
            set points [concat $points $complex($i)]
        }

        if { $iteration == 0 } {
            set oldminimum [lindex [lsort -index 1 -increasing $points] 0 1]
        } else {
            set newminimum [lindex [lsort -index 1 -increasing $points] 0 1]
            if { abs($oldminimum-$newminimum) != 0.0 &&
                 ( abs($oldminimum-$newminimum) < $abstol ||
                   abs($oldminimum-$newminimum) < 0.5 * $reltol * (abs($oldminimum)+abs($newminimum)) ) } {
                break
            } else {
                set oldminimum $newminimum
            }
        }
    }

    #
    # Sort the points and return the best one
    #
    set result [lsort -index 1 -increasing $points]
    set optimum_coords [lindex $result 0 0]
    set optimum_value  [lindex $result 0 1]
    set best_values    {}
    foreach r $result {
        set best_values [concat [lindex $r 1] $best_values]
    }
    return [dict create optimum-coordinates $optimum_coords optimum-value $optimum_value evaluations $sceNEvals best-values $best_values]
}

# OptimiseComplex --
#     Optimise the complex, using subcomplexes
#
# Arguments:
#     complex           The points (and the function values) making up the full complex
#     nsubcomplex       The number of points to be selected for the subcomplex
#     nnewpoints        The number of new points to be generated
#     bounds            The bounds on the coordinates defining the feasible region
#
# Result:
#     A new set of points
#
proc ::math::probopt::OptimiseComplex {complex nsubcomplex nnewpoints func bounds} {
    variable sceNEvals
    #
    # Construct the subcomplex
    #
    set subcomplex [lsort -index 1 -increasing [TriangularSelect $complex $nsubcomplex]]

    #
    # Construct new points:
    # - Determine the centroid, excluding the worst point
    # - Reflect the worst point
    # - Make sure the result is within the feasible region, otherwise
    #   select a new point
    # - Keep the new point if it has a lower function value
    # - Otherwise try a contraction step
    #
    for {set new 0} {$new < $nnewpoints} {incr new} {
        set centroid [Centroid [lrange $complex 0 end-1]]
        set newPoint [ReflectPointInPoint $centroid [lindex $complex end 0]]

        if { ! [WithinBounds $bounds $newPoint] } {
            set newPoint [GeneratePoint $bounds]
            set fvalue [$func $newPoint]
            incr sceNEvals
        } else {
            set fvalue [$func $newPoint]
            incr sceNEvals

            #
            # If the point is better, keep it, otherwise attempt a contraction step
            #
            if { $fvalue > [lindex $complex end 1] } {
                set newPoint [Centroid [list [list $centroid 0.0] [list $newPoint $fvalue]]]
                set fvalue [$func $newPoint]
                incr sceNEvals

                if { $fvalue > [lindex $complex end 1] } {
                    set newPoint [GeneratePoint $bounds]
                    set fvalue [$func $newPoint]
                    incr sceNEvals
                }
            }
        }

        lset complex end [list $newPoint $fvalue]

        set complex [lsort -index 1 -increasing $complex]
    }

    return $complex
}

# GeneratePoint --
#     Generate the coordinates of a random point within the given bounds
#
# Arguments:
#     bounds         Bounds on all coordinates
#
# Result:
#     List of coordinates
#
proc ::math::probopt::GeneratePoint {bounds} {

    set coords {}
    foreach bound $bounds {
        lassign $bound cmin cmax
        lappend coords [expr {$cmin + ($cmax - $cmin) * rand()}]
    }

    return $coords
}

# WithinBounds --
#     Determine if the coordinates of a point are within the given bounds
#
# Arguments:
#     bounds         Bounds on all coordinates
#     point          Coordinates of the point
#
# Result:
#     1 if the point is within the hyperrectangle, 0 otherwise
#
proc ::math::probopt::WithinBounds {bounds point} {

    set within 1

    foreach c $point bound $bounds {
        lassign $bound cmin cmax
        if { $c < $cmin || $c > $cmax } {
            set within 0
            break
        }
    }

    return $within
}

# Centroid --
#     Calculate the centroid of a set of points in N dimensions
#
# Arguments:
#     points         List of point coordinates
#
# Result:
#     Coordinates of the centroid
#
# Note:
#     As this is to be used in the SCE algorithm, the list of
#     point coordinates is slightly more complicated than
#     just the coordinates.
#
proc ::math::probopt::Centroid {points} {
    set dims   [llength [lindex $points 0 0]]
    set number [llength $points]

    set centroid [lrepeat $dims 0]

    foreach point $points {
        set coords [lindex $point 0]

        set idx 0
        foreach c $coords sum $centroid {
            set sum [expr {$sum + $c}]
            lset centroid $idx $sum
            incr idx
        }
    }

    set idx 0
    foreach c $centroid {
        lset centroid $idx [expr {$c / double($number)}]
        incr idx
    }

    return $centroid
}

# ReflectPointInPoint --
#     Reflect a point in another point and return the result
#
# Arguments:
#     centre         Point that serves as the reflection center
#     point          Point to be reflected (list of coordinates)
#
# Result:
#     Coordinates of the new point
#
proc ::math::probopt::ReflectPointInPoint {centre point} {

    set newPoint {}

    foreach c $centre p $point {
        lappend newPoint [expr {2.0 * $c - $p}]
    }

    return $newPoint
}

# TriangularSelect --
#     Select "number" values from a list of values
#     - the probability is triangular
#
# Arguments:
#     values       List of values to choose from
#     number       Number of values to choose (must be smaller than length of the list)
#
# Result:
#     Selected values
#
proc ::math::probopt::TriangularSelect {values number} {
    set selected {}

    for {set i 0} {$i < $number} {incr i} {
        set n [llength $values]

        set r   [expr {1.0 - sqrt(1.0 - rand())}]
        set idx [expr {int($r * $n)}]
        lappend selected [lindex $values $idx]
        set values [lreplace $values $idx $idx]
    }

    return $selected
}
