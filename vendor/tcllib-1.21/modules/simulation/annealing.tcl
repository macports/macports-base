# annealing.tcl --
#     Package implementing simulated annealing for minimizing functions
#     of one or more parameters
#
# Copyright (c) 2007 by Arjen Markus <arjenmarkus@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: annealing.tcl,v 1.4 2008/02/22 13:34:07 arjenmarkus Exp $
#------------------------------------------------------------------------------

package require Tcl 8.4

# ::simulation::annealing --
#     Create the namespace
#
namespace eval ::simulation::annealing {
}


# getOption --
#     Return the value of an option
#
# Arguments:
#     option         Name of the option (without -)
# Result:
#     The value or an error message if it does not exist
#
proc ::simulation::annealing::getOption {option} {
    variable ann_option

    if { [info exists ann_option(-$option)] } {
        return $ann_option(-$option)
    } else {
        return -code error "No such option: $option"
    }
}


# setOption --
#     Set the value of an option
#
# Arguments:
#     option         Name of the option (without -)
#     value          Value of the option
# Result:
#     None
#
proc ::simulation::annealing::setOption {option value} {
    variable ann_option

    set ann_option(-$option) $value
}


# hasOption --
#     Return whether the given option exists or not
#
# Arguments:
#     option         Name of the option (without -)
# Result:
#     1 if it exists, 0 if not
#
proc ::simulation::annealing::hasOption {option} {
    variable ann_option

    if { [info exists ann_option(-$option)] } {
        return 1
    } else {
        return 0
    }
}


# findMinimum --
#     Find the (global) minimum of a function using simulated annealing
#
# Arguments:
#     args            Option-value pairs:
#                     -parameters list - triples defining parameters and ranges
#                     -function expr   - expression defining the function
#                     -code body       - body of code to define the function
#                                        (takes precedence over -function)
#                                        should set the variable "result"
#                     -init code       - code to be run at start up
#                     -final code      - code to be run at the end
#                     -trials n        - number of trials before reducing the temperature
#                     -reduce factor   - reduce the temperature by this factor
#                                        (between 0 and 1)
#                     -initial-temp t  - initial temperature
#                     -scale s         - scale of the function (order of
#                                        magnitude of the values)
#                     -estimate-scale y/n - estimate the scale (only if -scale not present)
#                     -verbose y/n     - Turn verbose printing on (1) or off (0)
#                     -reportfile file - Channel to write verbose output to
#                     Any others can be used via the getOption procedure
#                     in the body.
#
# Result:
#     Estimated minimum and the parameters involved:
#     function value param1 value param2 value ...
#
proc ::simulation::annealing::findMinimum {args} {
    variable ann_option

    #
    # Handle the options
    #
    set ann_option(-parameters)     {}
    set ann_option(-function)       {}
    set ann_option(-code)           {}
    set ann_option(-init)           {}
    set ann_option(-final)          {}
    set ann_option(-trials)         300
    set ann_option(-reduce)         0.95
    set ann_option(-initial-temp)   1.0
    set ann_option(-scale)          {}
    set ann_option(-estimate-scale) 0
    set ann_option(-verbose)        0
    set ann_option(-reportfile)     stdout

    foreach {option value} $args {
        set ann_option($option) $value
    }

    if { $ann_option(-scale) == {} } {
        if { ! $ann_option(-estimate-scale) } {
            set ann_option(-scale) 1.0
        }
    }

    if { $ann_option(-code) != {} } {
        set ann_option(-function) {}
    }

    if { $ann_option(-code) == {} && $ann_option(-function) == {} } {
        return -code error "Neither code nor function given! Nothing to optimize"
    }
    if { $ann_option(-parameters) == {} } {
        return -code error "No parameters given! Nothing to optimize"
    }

    if { $ann_option(-function) != {} } {
        set ann_option(-code) "set result \[expr {$ann_option(-function)}\]"
    }

    #
    # Create the procedure
    #
    proc FindMin {} [string map \
        [list PARAMETERS $ann_option(-parameters) \
              CODE  $ann_option(-code) \
              INIT  $ann_option(-init) \
              FINAL $ann_option(-final)] {
        #
        # Give all parameters a value
        #
        foreach {_param_ _min_ _max_} {PARAMETERS} {
            set $_param_ $_min_
        }

        set _trials_ [getOption trials]
        set _temperature_ [getOption initial-temp]
        set _reduce_      [getOption reduce]
        set _noparams_    [expr {[llength {PARAMETERS}]/3}]
        set _verbose_     [getOption verbose]
        set _reportfile_  [getOption reportfile]

        INIT

        #
        # Estimate the scale
        #
        if { [getOption estimate-scale] == 1 } {
            set _sum_ 0.0
            for { set _trial_ 0 } { $_trial_ < $_trials_/3 } { incr _trial_ } {
                set _randp_ [expr {3*int($_noparams_*rand())}]
                set _param_ [lindex {PARAMETERS} $_randp_]
                set _min_   [lindex {PARAMETERS} [expr {$_randp_+1}]]
                set _max_   [lindex {PARAMETERS} [expr {$_randp_+2}]]
                set _old_param_ [set $_param_]
                set $_param_ [expr {$_min_ + rand()*($_max_-$_min_)}]

                CODE

                set _sum_  [expr {$_sum_ + abs($result)}]
            }
            set _scale_ [expr {3.0*$_sum_/$_trials_}]
        } else {
            set _scale_ [getOption scale]
        }
        if { $_verbose_ } {
            puts $_reportfile_ "Scale value: $_scale_"
        }

        #
        # Start the outer loop
        #
        set _changes_     1

        #
        # Get the initial value of the function
        #
        CODE
        set _old_result_ $result

        if { $_verbose_ } {
            puts $_reportfile_ "Result -- Mean of accepted values -- % accepted"
        }

        while {1} {
            set _sum_       $_old_result_
            set _accepted_  1
            for { set _trial_ 0 } { $_trial_ < $_trials_} { incr _trial_ } {
                set _randp_ [expr {3*int($_noparams_*rand())}]
                set _param_ [lindex {PARAMETERS} $_randp_]
                set _min_   [lindex {PARAMETERS} [expr {$_randp_+1}]]
                set _max_   [lindex {PARAMETERS} [expr {$_randp_+2}]]
                set _old_param_ [set $_param_]
                set $_param_ [expr {$_min_ + rand()*($_max_-$_min_)}]

                CODE

                #
                # Accept the new solution?
                #
                set _rand_  [expr {rand()}]
                if { log($_rand_) < -($result-$_old_result_)/($_scale_*$_temperature_) } {
                    incr _changes_
                    set _old_result_ $result
                    set _sum_        [expr {$_sum_ + $result}]
                    incr _accepted_
                } else {
                    set $_param_ $_old_param_
                }
            }

            if { $_verbose_ } {
                puts $_reportfile_ \
                    [format "%.5g -- %.5g -- %.2f %%" $_old_result_ \
                        [expr {$_sum_/$_accepted_}] [expr {100.0*double($_changes_)/$_trials_}]]
            }

            set _temperature_ [expr {$_reduce_ * $_temperature_}]
            if { $_changes_ == 0 } {
                break
            } else {
                set _changes_ 0
            }
        }

        set result [list result $_old_result_] ;# Note: we need the last accepted result!
        foreach {_param_ _min_ _max_} {PARAMETERS} {
            lappend result $_param_ [set $_param_]
        }

        FINAL

        return $result
    }]

    #
    # Do the actual computation and return the result
    #
    return [FindMin]
}


# findCombinatorialMinimum --
#     Find the (global) minimum of a combinatorial function using simulated annealing
#
# Arguments:
#     args            Option-value pairs:
#                     -number-params n     - number of (binary) parameters
#                     -initial-values list - list of parameter values to start with
#                     -function expr       - expression defining the function
#                     -code body           - body of code to define the function
#                                            (takes precedence over -function)
#                                            should set the variable "result"
#                                            The values of the solutions
#                                            are stored as a list in the
#                                            variable params
#                     -init code           - code to be run at start up
#                     -final code          - code to be run at the end
#                     -trials n            - number of trials before reducing the temperature
#                     -reduce factor       - reduce the temperature by this factor
#                                            (between 0 and 1)
#                     -initial-temp t      - initial temperature
#                     -scale s             - scale of the function (order of
#                                            magnitude of the values)
#                     -estimate-scale y/n  - estimate the scale (only if -scale not present)
#                     -verbose y/n         - Turn verbose printing on (1) or off (0)
#                     -reportfile file     - Channel to write verbose output to
#                     Any others can be used via the getOption procedure
#                     in the body.
#
# Result:
#     Estimated minimum and the parameters involved:
#     function value, list of values
#
# Note:
#     The parameters have the values 0 or 1
#
#     The stop criterion is that if the result value does not change in
#     sqrt(trials) then the iteration stops. Experiments with the
#     example below show that the function to be minimised can show
#     a very wide minimum due to the parameters being discrete.
#     sqrt(trials) is just an arbitrary value.
#
proc ::simulation::annealing::findCombinatorialMinimum {args} {
    variable ann_option

    #
    # Handle the options
    #
    set ann_option(-number-params)  {}
    set ann_option(-initial-values) {}
    set ann_option(-function)       {}
    set ann_option(-code)           {}
    set ann_option(-init)           {}
    set ann_option(-final)          {}
    set ann_option(-trials)         300
    set ann_option(-reduce)         0.95
    set ann_option(-initial-temp)   1.0
    set ann_option(-scale)          {}
    set ann_option(-estimate-scale) 0
    set ann_option(-verbose)        0
    set ann_option(-reportfile)     stdout

    foreach {option value} $args {
        set ann_option($option) $value
    }

    if { $ann_option(-scale) == {} } {
        if { ! $ann_option(-estimate-scale) } {
            set ann_option(-scale) 1.0
        }
    }

    if { $ann_option(-code) != {} } {
        set ann_option(-function) {}
    }

    if { $ann_option(-code) == {} && $ann_option(-function) == {} } {
        return -code error "Neither code nor function given! Nothing to optimize"
    }
    if { $ann_option(-number-params) == {} } {
        return -code error "Number of parameters not given! Nothing to optimize"
    }

    if { $ann_option(-initial-values) == {} } {
        for { set i 0 } { $i < $ann_option(-number-params) } { incr i } {
            lappend ann_option(-initial-values) 0
        }
    }

    if { $ann_option(-function) != {} } {
        set ann_option(-code) "set result \[expr {$ann_option(-function)}\]"
    }

    #
    # Create the procedure
    #
    proc FindCombMin {params} [string map \
        [list CODE  $ann_option(-code) \
              INIT  $ann_option(-init) \
              FINAL $ann_option(-final)] {

        set _trials_      [getOption trials]
        set _temperature_ [getOption initial-temp]
        set _reduce_      [getOption reduce]
        set _noparams_    [llength $params]
        set _verbose_     [getOption verbose]
        set _reportfile_  [getOption reportfile]

        INIT

        #
        # Estimate the scale
        #
        if { [getOption estimate-scale] == 1 } {
            set _sum_ 0.0
            set _old_params_ $params
            for { set _trial_ 0 } { $_trial_ < $_trials_/3 } { incr _trial_ } {
                set _randp_ [expr {int($_noparams_*rand())}]
                lset params $_randp_ [expr {rand()>0.5? 0 : 1}]

                CODE

                set _sum_  [expr {$_sum_ + abs($result)}]
            }
            set _scale_ [expr {3.0*$_sum_/$_trials_}]
            set params $_old_params_
        } else {
            set _scale_ [getOption scale]
        }
        if { $_verbose_ } {
            puts $_reportfile_ "Scale value: $_scale_"
        }

        #
        # Start the outer loop
        #
        set _changes_     1

        #
        # Get the initial value of the function
        #
        CODE
        set _old_result_        $result
        set _result_same_       0
        set _result_after_loop_ $result

        if { $_verbose_ } {
            puts $_reportfile_ "Result -- Mean of accepted values -- % accepted"
        }

        while {1} {
            set _sum_       $_old_result_
            set _accepted_  1
            for { set _trial_ 0 } { $_trial_ < $_trials_} { incr _trial_ } {
                set _old_params_ $params
                set _randp_ [expr {int($_noparams_*rand())}]
                lset params $_randp_ [expr {rand()>0.5? 0 : 1}]

                CODE

                #
                # Accept the new solution?
                #
                set _rand_  [expr {rand()}]
                if { log($_rand_) < -($result-$_old_result_)/($_scale_*$_temperature_) } {
                    incr _changes_
                    set _old_result_ $result
                    set _sum_        [expr {$_sum_ + $result}]
                    incr _accepted_
                } else {
                    set params $_old_params_
                }
            }

            if { $_verbose_ } {
                puts $_reportfile_ \
                    [format "%.5g -- %.5g -- %.2f %%" $_old_result_ \
                        [expr {$_sum_/$_accepted_}] [expr {100.0*double($_changes_)/$_trials_}]]
            }

            set _temperature_ [expr {$_reduce_ * $_temperature_}]
            if { $_changes_ == 0 || $_result_same_ > sqrt($_trials_) } {
                break
            } else {
                set _changes_ 0
            }

            if { $_result_after_loop_ == $_old_result_ } {
                incr _result_same_
            } else {
                set _result_after_loop_ $_old_result_
            }
        }

        set result [list result $_old_result_] ;# Note: we need the last accepted result!
        lappend result solution $params

        FINAL

        return $result
    }]

    #
    # Do the actual computation and return the result
    #
    return [FindCombMin $ann_option(-initial-values)]
}

# Announce the package
#
package provide simulation::annealing 0.2

# main --
#     Example
#
if { 0 } {
puts [::simulation::annealing::findMinimum \
    -trials 300 \
    -verbose 1 \
    -parameters {x -5.0 5.0 y -5.0 5.0} \
    -function {$x*$x+$y*$y+sin(10.0*$x)+4.0*cos(20.0*$y)}]

puts "Constrained:"
puts [::simulation::annealing::findMinimum \
    -trials 3000 \
    -reduce 0.98 \
    -parameters {x -5.0 5.0 y -5.0 5.0} \
    -code {
        if { hypot($x-5.0,$y-5.0) < 4.0 } {
            set result [expr {$x*$x+$y*$y+sin(10.0*$x)+4.0*cos(20.0*$y)}]
        } else {
           set result 1.0e100
        }
    }]
}

#
# A simple combinatorial problem:
# We have 100 items and the function is optimal if the first 10
# values are 1 and the result is 0. Can we find this solution?
#
# What if we have 1000 items? Or 10000 items?
#
# WARNING:
# 10000 items take a very long time!
#
if { 0 } {
    proc cost {params} {
        set cost 0
        foreach p [lrange $params 0 9] {
            if { $p == 0 } {
                incr cost
            }
        }
        foreach p [lrange $params 10 end] {
            if { $p == 1 } {
                incr cost
            }
        }
        return $cost
    }

    foreach n {100 1000 10000} {
        break
        puts "Problem size: $n"
        puts [::simulation::annealing::findCombinatorialMinimum \
            -trials 300 \
            -verbose 0 \
            -number-params $n \
            -code {set result [cost $params]}]
    }

    #
    # Second problem:
    #     Only the values of the first 10 items are important -
    #     they should be 1
    #
    proc cost2 {params} {
        set cost 0
        foreach p [lrange $params 0 9] {
            if { $p == 0 } {
                incr cost
            }
        }
        return $cost
    }

    foreach n {100 1000 10000} {
        puts "Problem size: $n"
        puts [::simulation::annealing::findCombinatorialMinimum \
            -trials 300 \
            -verbose 0 \
            -number-params $n \
            -code {set result [cost2 $params]}]
    }
}
