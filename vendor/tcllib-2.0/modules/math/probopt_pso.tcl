# probopt_pso.tcl --
#     Straightforward implementation of particle swarm optimisation
#
#     Options:
#     - The "best" is taken to be the globally best particle (global)
#     - The "best" is taken to be the best of the neighbourhood of
#       each particle
#
#     For more information see: https://en.wikipedia.org/wiki/Particle_swarm_optimization
#

# namespace --
#
namespace eval ::math::probopt {}



# pso --
#     Public interface to the PSO implementations
#
# Arguments:
#     func          Function to be minimized
#     bounds        List of pairs of minimum and maximum per dimension
#     args          Key-value pairs:
#                   -swarmsize  number        Number of particles to consider (default: 50)
#                   -vweight    value         Weight for the current "velocity" (0-1, default: 0.5)
#                   -pweight    value         Weight for the individual particle's best position (0-1, default: 0.3)
#                   -gweight    value         Weight for the "best" overall position as per particle (0-1, default: 0.3)
#                   -type       local/global  Type of optimisation
#                   -neighbours number        Size of the neighbourhood (default: 5, used if "local")
#                   -iterations number        Maximum number of iterations
#                   -tolerance  value         Absolute minimal improvement for minimum value
#
# Result:
#     Dictionary with the coordinates of the "best" position and the value as well as
#     list of best values per iteration and the number of function evaluations.
#
proc ::math::probopt::pso {func bounds args} {

    set func [uplevel 1 [list namespace which -command $func]]

    set options [dict create -swarmsize 50 -vweight 0.5 -pweight 0.3 -gweight 0.3 \
                     -type global -neighbours 5 -iterations 50 -tolerance 0.0]

    foreach {key value} $args {
        if { [dict key $options $key] != "" } {
            dict set options $key $value
        } else {
            return -code error "Unknown option: $key"
        }
    }

    set xmin {}
    set xmax {}

    foreach bound $bounds {
        lappend xmin [lindex $bound 0]
        lappend xmax [lindex $bound 1]
    }

    set type [dict get $options -type]

    if { $type == "global" } {
        return [Pso_global $func $xmin $xmax $options]
    }
    if { $type == "local" } {
        return [Pso_local $func $xmin $xmax $options]
    }

    return -code error "Unknown type: $type"
}

# Pso_global --
#     Use the "global" PSO algorithm
#
# Arguments:
#     func          Function to be minimized
#     xmin          Minimum values for the coordinates
#     xmax          Maximum values for the coordinates
#     options       Dictionary of options
#
proc ::math::probopt::Pso_global {func xmin xmax options} {
    #
    # Set up the initial positions
    #
    set swarmsize [dict get $options -swarmsize]
    set maxiters  [dict get $options -iterations]

    set particle_bests     {}
    set positions          {}
    set velocities         {}
    set global_best        -1
    set global_best_value  {}
    set evaluations         0
    set best_values        {}

    for {set i 0} {$i < $swarmsize} {incr i} {
        set coords [Pso_position $xmin $xmax]

        set fvalue [$func $coords]
        incr evaluations

        lappend positions      $coords
        lappend velocities     [lrepeat [llength $coords] 0.0]
        lappend particle_bests [list $fvalue $coords]

        if { $global_best == -1 || $global_best_value > $fvalue } {
            set global_best       $i
            set global_best_value $fvalue
        }
    }

    set vweight   [dict get $options -vweight]
    set pweight   [dict get $options -pweight]
    set gweight   [dict get $options -gweight]
    set tolerance [dict get $options -tolerance]

    for {set iteration 0} {$iteration < $maxiters} {incr iteration} {

        set new_positions      {}
        set new_velocities     {}
        set new_particle_bests {}

        #
        # Determine the new positions for all particles
        #
        for {set i 0} {$i < $swarmsize} {incr i} {
            set old_velocity  [lindex $velocities $i]
            set old_position  [lindex $positions  $i]
            set old_bestvalue [lindex $particle_bests $i 0]
            set old_bestpos   [lindex $particle_bests $i 1]

            set velocity      [Pso_update_vel $vweight $pweight $gweight $old_velocity $old_position $old_bestpos [lindex $positions $global_best]]

            set position      [Pso_new_position $old_position $velocity]
            set fvalue        [$func $position]
            incr evaluations

            lappend new_positions  $position
            lappend new_velocities $velocity

            if { $fvalue < $old_bestvalue } {
                lappend new_particle_bests [list $fvalue $position]
            } else {
                lappend new_particle_bests [list $old_bestvalue $old_position]
            }
        }

        set positions      $new_positions
        set velocities     $new_velocities
        set particle_bests $new_particle_bests

        #
        # Determine the globally best position
        #
        for {set i 0} {$i < $swarmsize} {incr i} {
            set fvalue [lindex $particle_bests $i 0]

            if { $fvalue < $global_best_value } {
                set global_best_value $fvalue
                set global_best       $i
                set global_best_pos   [lindex $particle_bests $i 1]
            }
        }

        #
        # Have we reached the tolerance yet?
        #
        if { $iteration > 0 } {
            if { abs($prev_best_value - $global_best_value) < $tolerance &&
                 $prev_best_value > $global_best_value } {
                break
            }
        }
        set prev_best_value $global_best_value
        lappend best_values $global_best_value
    }

    return [dict create optimum-coordinates $global_best_pos optimum-value $global_best_value evaluations $evaluations best-values $best_values]
}

# Pso_local --
#     Use the "local" PSO algorithm, i.e. look only at the "neighbours"
#
# Arguments:
#     func          Function to be minimized
#     xmin          Minimum values for the coordinates
#     xmax          Maximum values for the coordinates
#     options       Dictionary of options
#
proc ::math::probopt::Pso_local {func xmin xmax options} {
    #
    # Set up the initial positions
    #
    set swarmsize  [dict get $options -swarmsize]
    set maxiters   [dict get $options -iterations]
    set neighbours [dict get $options -neighbours]

    set particle_bests     {}
    set positions          {}
    set velocities         {}
    set global_best        -1
    set global_best_value  {}
    set evaluations         0
    set best_values        {}

    for {set i 0} {$i < $swarmsize+$neighbours} {incr i} {
        lappend neighbours_idx [expr {$i % $swarmsize}]
    }

    for {set i 0} {$i < $swarmsize} {incr i} {
        set coords [Pso_position $xmin $xmax]

        set fvalue [$func $coords]
        incr evaluations

        lappend positions        $coords
        lappend velocities       [lrepeat [llength $coords] 0.0]
        lappend particle_bests   [list $fvalue $coords]

        lappend local_best       $i
        lappend local_best_value $fvalue
        lappend local_best_pos   $coords
        lappend prev_best_value  $fvalue
    }

    #
    # Initial estimates:
    # Examine the neighbouring particles and determine which holds the best result
    #
    for {set i 0} {$i < $swarmsize} {incr i} {
        set current_best       [lindex $local_best $i]
        set current_best_value [lindex $particle_bests $current_best 0]
        set current_best_pos   [lindex $particle_bests $current_best 1]

        for {set n 0} {$n < $neighbours} {incr n} {
            set nth     [lindex $neighbours_idx [expr {$i+$n}]]
            set fvalue [lindex $particle_bests $nth 0]

            if { $current_best_value > $fvalue } {
                set current_best       $nth
                set current_best_value $fvalue
                set current_best_pos   [lindex $particle_bests $nth 1]
            }
        }

        lset local_best       $i $current_best
        lset local_best_value $i $current_best_value
        lset local_best_pos   $i $current_best_pos
    }

    #
    # Actual loop
    #
    set vweight   [dict get $options -vweight]
    set pweight   [dict get $options -pweight]
    set gweight   [dict get $options -gweight]
    set tolerance [dict get $options -tolerance]

    set stop      0

    for {set iteration 0} {$iteration < $maxiters && $stop == 0} {incr iteration} {

        set new_positions      {}
        set new_velocities     {}
        set new_particle_bests {}

        #
        # Determine the new positions for all particles
        #
        for {set i 0} {$i < $swarmsize} {incr i} {
            set old_velocity  [lindex $velocities $i]
            set old_position  [lindex $positions  $i]
            set old_bestvalue [lindex $particle_bests $i 0]
            set old_bestpos   [lindex $particle_bests $i 1]

            set idx [lindex $local_best $i]

            set velocity      [Pso_update_vel $vweight $pweight $gweight $old_velocity $old_position $old_bestpos [lindex $positions $idx]]

            set position      [Pso_new_position $old_position $velocity]
            set fvalue        [$func $position]
            incr evaluations

            lappend new_positions  $position
            lappend new_velocities $velocity

            if { $fvalue < $old_bestvalue } {
                lappend new_particle_bests [list $fvalue $position]
            } else {
                lappend new_particle_bests [list $old_bestvalue $old_position]
            }
        }

        set positions      $new_positions
        set velocities     $new_velocities
        set particle_bests $new_particle_bests

        #
        # Examine the neighbouring particles and determine which holds the best result
        #
        for {set i 0} {$i < $swarmsize} {incr i} {
            set current_best       [lindex $local_best $i]
            set current_best_value [lindex $local_best_value $i]
            set current_best_pos   [lindex $local_best_pos $i]

            for {set n 0} {$n < $neighbours} {incr n} {
                set nth     [lindex $neighbours_idx [expr {$i+$n}]]
                set fvalue [lindex $particle_bests $nth 0]

                if { $current_best_value > $fvalue } {
                    set current_best       $nth
                    set current_best_value $fvalue
                    set current_best_pos   [lindex $particle_bests $nth 1]
                }
            }

            lset local_best       $i $current_best
            lset local_best_value $i $current_best_value
            lset local_best_pos   $i $current_best_pos

            #
            # Have we reached the tolerance yet?
            # Note: local citerium - one group reaching a minimum? Then stop
            #
            if { $iteration > 0 } {
                if { abs([lindex $prev_best_value $i] - $current_best_value) < $tolerance &&
                     [lindex $prev_best_value $i] > $current_best_value } {
                    set stop 1
                    break
                }
            }
            lset prev_best_value $i $current_best_value
        }

        #
        # Now determine the overall best position - within this iteration
        # (to have a history)
        #
        set global_best_value [lindex $local_best_value 0]
        set global_best_pos   [lindex $local_best_pos   0]

        for {set i 1} {$i <$swarmsize} {incr i} {
            set particle_best_value [lindex $local_best_value $i]

            if { $global_best_value > $particle_best_value } {
                set global_best_value $particle_best_value
                set global_best_pos   [lindex $local_best_pos $i]
            }
        }

        lappend best_values $global_best_value
    }

    return [dict create optimum-coordinates $global_best_pos optimum-value $global_best_value evaluations $evaluations best-values $best_values]
}

# Pso_position --
#     Determine the initial position
#
# Arguments:
#     xmin              Minimum values for the coordinates
#     xmax              Maximum values for the coordinates
#
# Result:
#     Vector of coordinates
#
proc ::math::probopt::Pso_position {xmin xmax} {

    set new_position {}

    foreach min $xmin max $xmax {
        lappend new_position [expr {$min + ($max - $min) * rand()}]
    }

    return $new_position
}

# Pso_new_position --
#     Update the position
#
# Arguments:
#     position          Position vector
#     velocity          Velocity vector
#
# Result:
#     Vector of new coordinates
#
proc ::math::probopt::Pso_new_position {position velocity} {

    set new_position {}

    foreach p $position v $velocity {
        lappend new_position [expr {$p + $v}]
    }

    return $new_position
}

# Pso_update_vel --
#     Update the velocity
#
# Arguments:
#     vweight           Weight for the old vector
#     pweight           Weight for the particle's best position
#     gweight           Weight for the globally (locally) best position
#     old_velocity      Old velocity vector
#     old_position      Old position vector
#     old_particle_best Old best vector for the particle
#     old_global_best   Old globally (locally) best vector
#
# Result:
#     Vector of new coordinates
#
proc ::math::probopt::Pso_update_vel {vweight pweight gweight old_velocity old_position old_particle_best old_global_best} {

    set new_velocity {}

    set pw [expr {$pweight * rand()}]
    set gw [expr {$gweight * rand()}]

    foreach v $old_velocity p $old_position b $old_particle_best g $old_global_best {
        lappend new_velocity [expr {$vweight * $v + $pw * ($b - $p) + $gw * ($g - $p)}]
    }

    return $new_velocity
}
