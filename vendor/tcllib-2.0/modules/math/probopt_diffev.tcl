# probopt_diffev.tcl --
#     Implementation of the differential probopt algorithm
#     for optimising functions
#
#     Note:
#     The algorithm does not confine the points to the given
#     hyper block - it is merely used to initialise it.
#
namespace eval ::math::probopt {}

# diffev --
#      Optimise a function using the differential probopt algorithm
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
proc ::math::probopt::diffev {func bounds args} {
    #
    # Set the default options
    #
    set dims [llength $bounds]
    set options [dict create -number 0 -factor 0.6 -lambda 0.0 -crossover 0.5 \
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

    if { ${-number} == 0 } {
        set -number [expr {4 * $dims}]
        dict set options -number ${-number}
    }

    #
    # Set up the initial collections of points
    #
    set evals  0
    set points {}
    for {set i 0} {$i < ${-number}} {incr i} {
        set coords [GeneratePoint $bounds]
        lappend points [list $coords [$func $coords]]
        incr evals
    }
    #puts [join $points \n]

    #
    # Iteration over the generations:
    # - For each point, construct a new estimate and check if it is better
    # - If it is, replace the original point by the new point
    #
    set oldIndex [IndexBestPoint $points]
    set oldValue [lindex $points $oldIndex 1]
    set bestPerGeneration {}

    for {set generation 0} {$generation < ${-iterations}} {incr generation} {
        #puts "$generation"
        set newPoints {}
        set renewed   0   ;# Keep track of the replacement of points to avoid
                           # a premature ending

        for {set i 0} {$i < ${-number}} {incr i} {
            set point [lindex $points $i]

            set newCoords [ConstructNewCoords $points ${-factor} ${-lambda} ${-crossover} $i $oldIndex]

            set fvalue    [$func $newCoords]
            incr evals
            #puts "$newCoords -- $fvalue -- $evals"

            if { $fvalue < [lindex $point 1] } {
                set renewed  [expr {$i == $oldIndex? 1 : 0}] ;# Is the best estimate being replaced?
                set newPoint [list $newCoords $fvalue]
            } else {
                set newPoint $point
            }

            #puts "$newPoint -- $evals"
            lappend newPoints $newPoint
        }

        #
        # Check the number of evaluations ... not quite accurate, but it will do
        #
        # Hm, this will fail if this happens in the first generation
        #
        if { $evals >= ${-maxevaluations} } {
            #puts "Maximum evaluations reached"
            break
        }

        #
        # Get the best point in the current generation
        #
        set bestIndex [IndexBestPoint $newPoints]
        set bestValue [lindex $newPoints $bestIndex 1]

        #puts "$oldIndex -- $oldValue -- $bestIndex -- $bestValue"
        #if { $renewed } {}
        if { ( $oldValue != $bestValue || $oldIndex != $bestIndex ) &&
             ( ($oldValue - $bestValue) <= ${-abstolerance} ||
               ($oldValue - $bestValue) <= 0.5 * ${-reltolerance} * (abs($oldValue) + abs($bestValue)) ) } {
            #puts "Values: $oldValue -- $bestValue"
            break
        } else {
            set points   $newPoints
            set oldIndex $bestIndex
            set oldValue $bestValue
            lappend bestPerGeneration $bestValue
        }

        #puts "$oldIndex -- $oldValue -- $bestIndex -- $bestValue"
    }

    return [dict create optimum-coordinates [lindex $newPoints $bestIndex 0] \
                        optimum-value [lindex $newPoints $bestIndex 1] evaluations $evals best-values $bestPerGeneration]
}

# ConstructNewCoords --
#     Constructs the coordinates of a new point using the DE method
#
# Arguments:
#     points         Current set of points (each together with the function value)
#     factor         Weight for the difference vector
#     lambda         Weight for the best vector
#     crossover      Probability of cross-over
#     idx            Current index
#     bestIdx        Index of the current best vector
#
# Result:
#     List of coordinates
#
proc ::math::probopt::ConstructNewCoords {points factor lambda crossover idx bestIdx} {
    set number [llength $points]
    set dims   [llength [lindex $points 0 0]]
    set r1     [SelectIndex $idx $number]
    set r2     [SelectIndex $idx $number]
    set r3     [SelectIndex $idx $number]

    if { $lambda == 0.0 } {
        set vcoords {}
        foreach c1 [lindex $points $r1 0] \
                c2 [lindex $points $r2 0] \
                c3 [lindex $points $r3 0] {
            set vc [expr {$c1 + $factor * ($c2 - $c3)}]
            lappend vcoords $vc
        }
    } else {
        set vcoords {}
        foreach c1 [lindex $points $idx 0]       \
                cb [lindex $points $bestIndex 0] \
                c2 [lindex $points $r2 0]        \
                c3 [lindex $points $r3 0]        {
            set vc [expr {$c1 + $lambda * ($cb - $c1) + $factor * ($c2 - $c3)}]
            lappend vcoords $vc
        }
    }

    #
    # Now the cross-over per dimension
    #
    set start  [SelectIndex {} $number]
    set length [SelectLength $crossover $dims]

    set combined $vcoords
    for {set i $start} {$i < $start+$length} {incr i} {
        set j [expr {$i % $dims}]
        lset combined $j [lindex $vcoords $j]
    }

    return $combined
}

# SelectIndex --
#     Select a random index unequal to a given index
#
# Arguments:
#     avoidIdx       Index to be avoided
#     maximum        Maximum + 1 for the index
#
# Result:
#     Random index in [0,maximum-1], not equal avoidIdx
#
proc ::math::probopt::SelectIndex {avoidIdx maximum} {

    set idx $avoidIdx
    while { $idx == $avoidIdx } {
        set idx [expr {int($maximum * rand())}]
    }

    return $idx
}

# SelectLength --
#     Select a random length using a cross-over probability
#
# Arguments:
#     crossover      Cross-over probability
#     maximum        Maximum + 1 for the index
#
# Result:
#     Random index in [0,maximum-1]
#
proc ::math::probopt::SelectLength {crossover maximum} {

    set length 0
    while {1} {
        incr length
        if { rand() > $crossover || $length >= $maximum } {
            break
        }
    }

    return $length
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

# IndexBestPoint --
#     Find the index of the best point (lowest function value)
#
# Arguments:
#     points         List of points (each is a pair of coordinates and the function value)
#
# Result:
#     Index of the best point
#
proc ::math::probopt::IndexBestPoint {points} {

    set index     0
    set bestValue [lindex $points 0 1]

    for {set i 1} {$i < [llength $points]} {incr i} {
        set newValue [lindex $points $i 1]
        if { $newValue < $bestValue } {
            set index     $i
            set bestValue $newValue
        }
    }

    return $index
}
