# montecarlo.tcl --
#     Utilities for Monte Carlo simulations
#
# Copyright (c) 2007 by Arjen Markus <arjenmarkus@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: montecarlo.tcl,v 1.2 2008/01/23 05:35:02 arjenmarkus Exp $
#------------------------------------------------------------------------------

package require Tcl 8.4
package require simulation::random
package require math::statistics

# ::simulation::montecarlo --
#     Create the namespace
#
namespace eval ::simulation::montecarlo {
}


# AcceptAll --
#     Accept any point
#
# Arguments:
#     args            Coordinates
#     y               Y-coordinate
#
proc ::simulation::montecarlo::AcceptAll {args} {
    return 1
}


# integral2D --
#     Estimate an integral over a two-dimensional domain, using MC
#
# Arguments:
#     domain          List of minimum x, maximum x, minimum y and maximum y
#     func            Function to be integrated
#     args            Option-value pairs:
#                     -region proc  - accept or reject the chosen point
#                     -samples n    - number of samples to use
# Result:
#     Estimated value of the integral
#
proc ::simulation::montecarlo::integral2D {domain func args} {
    set option(-region)  AcceptAll
    set option(-samples) 1000

    foreach {key value} $args {
        if { [string index $key 0] != "-" } {
            return -code error "Incorrect option: $key - should start with a -"
        }
        set option($key) $value
    }

    set sum      0.0
    set count    0
    set accepted 0
    set maxcount [expr {10*$option(-samples)}]

    foreach {xmin xmax ymin ymax} $domain {break}
    set area [expr {($xmax-$xmin)*($ymax-$ymin)}]

    while { $accepted < $option(-samples) && $count < $maxcount } {
        set x [expr {$xmin + ($xmax-$xmin)*rand()}]
        set y [expr {$ymin + ($ymax-$ymin)*rand()}]

        if { [$option(-region) $x $y] } {
            set sum [expr {$sum + [$func $x $y]}]
            incr accepted
        }
        incr count
    }

    #
    # The ratio accepted/count gives an estimate of the area
    # over which we just integrated.
    #
    return [expr {$accepted*$sum/$count/$count*$area}]
}


# integral3D --
#     Estimate an integral over a three-dimensional domain, using MC
#
# Arguments:
#     domain          List of minimum x, maximum x, minimum y and maximum y,
#                     minimum z, maximum z
#     func            Function to be integrated
#     args            Option-value pairs:
#                     -region proc  - accept or reject the chosen point
#                     -samples n    - number of samples to use
# Result:
#     Estimated value of the integral
#
proc ::simulation::montecarlo::integral3D {domain func args} {
    set option(-region)  AcceptAll
    set option(-samples) 1000

    foreach {key value} $args {
        if { [string index $key 0] != "-" } {
            return -code error "Incorrect option: $key - should start with a -"
        }
        set option($key) $value
    }

    set sum      0.0
    set count    0
    set accepted 0
    set maxcount [expr {10*$option(-samples)}]

    foreach {xmin xmax ymin ymax zmin zmax} $domain {break}
    set area [expr {($xmax-$xmin)*($ymax-$ymin)*($zmax-$zmin)}]

    while { $accepted < $option(-samples) && $count < $maxcount } {
        set x [expr {$xmin + ($xmax-$xmin)*rand()}]
        set y [expr {$ymin + ($ymax-$ymin)*rand()}]
        set z [expr {$zmin + ($zmax-$zmin)*rand()}]

        if { [$option(-region) $x $y $z] } {
            set sum [expr {$sum + [$func $x $y $z]}]
            incr accepted
        }
        incr count
    }

    #
    # The ratio accepted/count gives an estimate of the area
    # over which we just integrated.
    #
    return [expr {$accepted*$sum/$count/$count*$area}]
}


# singleExperiment --
#     Perform a single MC experiment
#
# Arguments:
#     args            Option-value pairs, predefined options:
#                     -init body      - code to initialise the experiment
#                     -loop body      - code to be run for each trial
#                     -final body     - code to finalise the experiment
#                     -trials n       - number of trials
#                     -reportfile f   - channel to report file
#                     -verbose yesno  - whether to report the details or not
#                     -analysis type  - type of analysis to perform
#                                       (standard, none or the name of a procedure)
#                     -columns names  - list of names of the columns (for printing)
#                     All option-value pairs are available via
#                     the procedure getOption
#
# Result:
#     Whatever was set via [setExpResult]
#
proc ::simulation::montecarlo::singleExperiment {args} {
    variable exp_option
    variable exp_result
    variable trial_result
    variable trial_first

    catch {unset exp_option}
    set exp_option(-init)       {}
    set exp_option(-loop)       {}
    set exp_option(-final)      {}
    set exp_option(-trials)     {}
    set exp_option(-reportfile) stdout
    set exp_option(-verbose)    0
    set exp_option(-analysis)   standard
    set exp_option(-columns)    {}

    set exp_result   {}
    set trial_result {}

    #
    # Sanity check for the options, and store them
    #
    foreach {key value} $args {
        if { [string index $key 0] != "-" } {
            return -code error "Incorrect option: $key - should start with a -"
        }
        set exp_option($key) $value
    }

    #
    # Which analysis procedure
    #
    switch -- $exp_option(-analysis) {
        "standard" { set exp_option(-analysis) ::simulation::montecarlo::StandardAnalysis }
        "none"     { set exp_option(-analysis) "" }
    }

    #
    # Now construct the temporary procedure that will do the work
    #
    proc DoExperiment {} [string map \
        [list INIT $exp_option(-init) LOOP $exp_option(-loop) \
              FINAL $exp_option(-final) TRIALS $exp_option(-trials) \
              VERBOSE $exp_option(-verbose) \
              ANALYSIS $exp_option(-analysis)] \
        {
            INIT
            for { set trial 0 } { $trial < TRIALS } { incr trial } {
                LOOP
                if { VERBOSE } {
                    ::simulation::montecarlo::PrintTrialResult $trial
                }
            }
            FINAL
            ANALYSIS
        }]
        # TODO: analysis of all trial results

    #
    # Do the experiment and remove it. The results
    #
    DoExperiment
    rename DoExperiment {}

    return $exp_result
}


# transposeData --
#     Transpose a matrix of data
#
# Arguments:
#     values          List of lists of values
#
# Result:
#     Transposed list
#
proc ::simulation::montecarlo::transposeData {values} {
    set transpose {}
    set c 0
    foreach col [lindex $values 0] {
        set newrow {}
        foreach row $values {
            lappend newrow [lindex $row $c]
        }
        lappend transpose $newrow
        incr c
    }
    return $transpose
}


# setTrialResult --
#     Set the result of an individual trial
#
# Arguments:
#     values          List of values to be stored
#
# Result:
#     None
#
proc ::simulation::montecarlo::setTrialResult {values} {

    lappend ::simulation::montecarlo::trial_result $values
}


# PrintTrialResult --
#     Print the result of the current trial
#
# Arguments:
#     trial            Trial number
#
# Result:
#     None
#
proc ::simulation::montecarlo::PrintTrialResult {trial} {

    set outfile [getOption reportfile]

    #
    # Print the column names
    #
    if { $trial == 0 } {
        set columns [getOption columns]
        set format "%5.5s [string repeat %12.12s [llength $columns]]"

        puts $outfile [eval format [list $format] [list " "] $columns]
    }

    #
    # Print the results
    #
    set result [lindex $::simulation::montecarlo::trial_result end]

    set format "%5d:[string repeat %12g [llength $result]]"

    puts $outfile [eval format $format $trial $result]
}


# setExpResult --
#     Set the result for the complete experiment
#
# Arguments:
#     values          List of values to be stored
#
# Result:
#     None
#
proc ::simulation::montecarlo::setExpResult {values} {

    set ::simulation::montecarlo::exp_result $values
}


# getExpResult --
#     Return the result of the complete experiment
#
# Arguments:
#     None
# Result:
#     Whatever was set via setExpResult
#
proc ::simulation::montecarlo::getExpResult {} {

    return $::simulation::montecarlo::exp_result
}


# getTrialResults --
#     Return the list of individual results for all trials
#
# Arguments:
#     None
# Result:
#     Whatever was set via setTrialResult
#
proc ::simulation::montecarlo::getTrialResults {} {

    return $::simulation::montecarlo::trial_result
}


# getOption --
#     Return the value of an option
#
# Arguments:
#     option         Name of the option (without -)
# Result:
#     The value or an error message if it does not exist
#
proc ::simulation::montecarlo::getOption {option} {
    variable exp_option

    if { [info exists exp_option(-$option)] } {
        return $exp_option(-$option)
    } else {
        return -code error "No such option: $option"
    }
}


# hasOption --
#     Check if the option is available
#
# Arguments:
#     option         Name of the option (without -)
# Result:
#     1 if it is available, 0 if not
#
proc ::simulation::montecarlo::hasOption {option} {
    variable exp_option

    if { [info exists exp_option(-$option)] } {
        return 1
    } else {
        return 0
    }
}


# StandardAnalysis --
#     Perform standard analysis on the trial data
#
# Arguments:
#     None
# Result:
#     None
# Side effects:
#     Prints the results to the result file and stores them as
#     the experiment results.
#
proc ::simulation::montecarlo::StandardAnalysis {} {

    set repfile [getOption reportfile]
    set names   [getOption columns]

    set values [transposeData [getTrialResults]]

    set exp_result {}

    #
    # First part: basic statistics
    #
    set part_one {}

    puts $repfile "Basic statistical parameters:"
    set form "%12.12s[string repeat %12g 4]"
    puts $repfile [format [string repeat "%12.12s" 5] "" Mean Stdev Min Max]

    foreach row $values name $names {
        set basicStats [::math::statistics::basic-stats $row]
        lappend part_one $basicStats

        puts $repfile [format $form $name \
            [lindex $basicStats 0] \
            [lindex $basicStats 4] \
            [lindex $basicStats 1] \
            [lindex $basicStats 2]]
    }

    #
    # Second part: correlation matrix
    #
    set form "%12.12s[string repeat %12g [llength $values]]"

    puts $repfile "Correlation matrix:"
    puts $repfile [eval format "%12.12s[string repeat %12.12s [llength $values]]" [list ""] $names]

    set part_two {}
    foreach row $values rowname $names {
        set line {}

        foreach col $values {
            set corr [::math::statistics::corr $col $row]
            lappend line $corr
        }
        lappend part_two $line
        puts $repfile [eval format $form $rowname $line]
    }

    setExpResult [list $part_one $part_two]
}

# Announce the package
#
package provide simulation::montecarlo 0.1

# main --
#     Quick test
#
if { 0 } {
proc f {x y} {
    return $x
}
puts "Integral over rectangle: [::simulation::montecarlo::integral2D {0 1 0 1} f]"
puts [time {
set a [::simulation::montecarlo::integral2D {0 1 0 1} f]
} 100]

#
# MC experiments:
# Determine the mean and median of a set of points and compare them
#
::simulation::montecarlo::singleExperiment -init {
    package require math::statistics

    set prng [::simulation::random::prng_Normal 0.0 1.0]
} -loop {
    set numbers {}
    for { set i 0 } { $i < [getOption samples] } { incr i } {
        lappend numbers [$prng]
    }
    set mean   [::math::statistics::mean $numbers]
    set median [::math::statistics::median $numbers] ;# ? Exists?
    setTrialResult [list $mean $median]
} -final {
    set result [getTrialResults]
    set means   {}
    set medians {}
    foreach r $result {
        foreach {m M} $r break
        lappend means   $m
        lappend medians $M
    }
    puts [getOption reportfile] "Correlation: [::math::statistics::corr $means $medians]"

} -trials 100 -samples 10 -verbose 1 -columns {Mean Median}
}
