# changepoint.tcl --
#     Statistical procedures for change point detection:
#     - Implementation of the CUSUM procedure to detect changes in the
#       mean of a series of data
#
#       Partly based on: https://www.itl.nist.gov/div898/handbook/pmc/section3/pmc323.htm
#
#       Note:
#       Since there do not seem to be online resources for the finer details, the
#       implementation uses simple guidelines as found for instance at
#       https://en.wikipedia.org/wiki/CUSUM.
#
#       There are two commands:
#       - One to examine a complete time series
#       - One (OO style) to examine data from a time series online
#
#    - Implementation of the binary segmentation algorithm
#

package require Tcl 8.6
package require TclOO
package require math::statistics
package provide math::changepoint 0.1

namespace eval ::math::changepoint {
    namespace export cusum-detect cusum-online binary-segmentation
}

# cusum-detect --
#     Procedure to examine a given data series and return the location
#     of the first change (if any)
#
# Arguments:
#     data                    List of values to be examined
#     args                    (Optional) key-value pairs to define the parameters:
#                             -target value    -- the target (or mean) for the time series
#                             -tolerance value -- the tolerated standard deviation
#                             -kfactor         -- the factor by which to multiply the
#                                                 standard deviation (defaults to 0.5,
#                                                 typically between 0.5 and 1.0
#                             -hfactor         -- the factor determining the limits
#                                                 betweem which the "cusum" statistic
#                                                 is accepted (typicaly 3.0-5.0, default 4.0)
#
# Result:
#     Index of the location of the first change or an empty string
#
# Note:
#     The CUSUM procedure is rather sensitive and details regarding the limits differ
#     between descriptions. This is a straightforward implementation.
#
#     If no options are given, the given time series is used for the target and the
#     tolerance.
#
#     Because of the senstivity using the raw data may give spurious results.
#
proc ::math::changepoint::cusum-detect {data args} {

    set kfactor   0.5
    set hfactor   4.0

    set target    {}
    set tolerance {}

    foreach {key value} $args {
        if { [string match "-*" $key] } {
            set name [string range $key 1 end]
            set $name $value
        } else {
            return -code error "Unknown/invalid option: $key"
        }
    }

    if { $target eq {} } {
        set target [::math::statistics::mean $data]
    }

    if { $tolerance eq {} } {
        set tolerance [::math::statistics::stdev $data]
    }

    set k [expr {$kfactor * $tolerance}]
    set h [expr {$hfactor * $tolerance}]

    set Shi 0.0
    set Slo 0.0

    set location {}
    set index    0
    foreach value $data {
        set Shi [expr {max( 0.0, $Shi + $value - $target - $k )}]
        set Slo [expr {max( 0.0, $Slo + $target - $value - $k )}]

        if { $Shi > $h || $Slo > $h } {
            set location $index
            break
        }

        incr index
    }

    return $location
}

# cusum-online --
#     Class to examine data passed in against expected properties
#
# Arguments:
#     data                    List of values to be examined
#     args                    (Optional) key-value pairs to define the parameters:
#                             -target value    -- the target (or mean) for the time series
#                             -tolerance value -- the tolerated standard deviation
#                             -kfactor         -- the factor by which to multiply the
#                                                 standard deviation (defaults to 0.5,
#                                                 typically between 0.5 and 1.0
#                             -hfactor         -- the factor determining the limits
#                                                 betweem which the "cusum" statistic
#                                                 is accepted (typicaly 3.0-5.0, default 4.0)
#
# Result:
#     Index of the location of the first change or an empty string
#
# Note:
#     All parameters used in this algorithm are set to default values.
#     The threshold are based on 3 * stdev and a quick detection of
#     a change of 1 * stdev.
#
::oo::class create ::math::changepoint::cusum-online {
    variable target    {}
    variable tolerance {}
    variable Slo       0.0
    variable Shi       0.0
    variable k         0.0
    variable h         0.0

    #
    # Constructor:
    # - two key-value pairs required: -target and -tolerance
    #
    constructor {args} {
        variable target
        variable tolerance
        variable k
        variable h

        set kfactor 0.5
        set hfactor 4.0

        foreach {option value} $args {
            switch -- $option {
                "-target"    { set target    $value }
                "-tolerance" { set tolerance $value }
                "-kfactor"   { set kfactor   $value }
                "-hfactor"   { set hfactor   $value }
                default {
                    return -code error "Unknown/invalid option: $option"
                }
            }
        }

        if { $target eq {} || $tolerance eq {} } {
            return -code error "Values for target and tolerance are required"
        }

        set k [expr {$kfactor * $tolerance}]
        set h [expr {$hfactor * $tolerance}]

        set Shi 0.0
        set Slo 0.0

    }

    #
    # Restart the object
    #
    method reset {} {
        variable Slo
        variable Shi

        set Shi 0.0
        set Slo 0.0
    }

    #
    # Add a new value to the object and examine it. If the cusum exceeds
    # the range, 1 is returned, otherwise 0.
    #
    method examine {value} {
        variable Slo
        variable Shi
        variable k
        variable h

        set Shi [expr {max( 0.0, $Shi + $value - $target - $k )}]
        set Slo [expr {max( 0.0, $Slo + $target - $value - $k )}]

        return [expr { $Shi > $h || $Slo > $h }]
    }
}

# binary-segmentation --
#     Apply the binary segmentation method recursively to find change points
#
# Arguments:
#     series            The series in question
#     args              Key-value pairs defining the options:
#                       -minlength 5    Minimum number of points in each segment
#                       -threshold 1.0  Factor applied to the standard deviation
#                                       functioning as a threshold for accepting
#                                       the change in cost function as an improvement
# Result:
#     List of indices where change points have been detected
#
proc ::math::changepoint::binary-segmentation {series args} {
    set minlength 5
    set threshold 1.0

    foreach {key value} $args {
        switch -- $key {
            "-minlength" {
                set minlength $value
            }
            "-threshold" {
                set threshold $value
            }
            default {
                return -error "Unknown keyword: $key"
            }
        }
    }

    if { [llength $series] < $minlength } {
        return -error "Series too short - at least $minlength values expected"
    }

    #
    # The real work is done by this procedure
    #
    set indices [BinSegRecursive 0 $series $minlength $threshold]

    return $indices
}

# BinSegRecursive --
#     Procedure for doing the actual work
#
# Arguments:
#     first            Index of the first value in the segment wrt the original series
#     series           Series/segment to be examined
#     minlength        Minimum length
#     threshold        Factor for the standard deviation
#
proc ::math::changepoint::BinSegRecursive {first series minlength threshold} {

    set length [llength $series]

    if { $length < $minlength } {
        return {}
    }

    #
    # Overall parameters
    #
    set stdev [::math::statistics::stdev $series]
    set idxmin  -1
    set maxcost [expr {$length * $stdev ** 2}]
    set mincost $maxcost

    #
    # Calculate the cost function for each split of the series
    #
    for {set idx $minlength} {$idx < $length-$minlength} {incr idx} {
        set segment1 [lrange $series 0 $idx]
        set segment2 [lrange $series [expr {$idx+1}] end]

        set stdev1   [::math::statistics::stdev $segment1]
        set stdev2   [::math::statistics::stdev $segment2]

        set cost     [expr {($idx+1) * $stdev1**2 + ($length-$idx) * $stdev2**2}]
        if { $cost < $mincost } {
            set mincost $cost
            set idxmin  $idx
        }
    }

    #
    # Do we accept it?
    #
    set indices {}

    if { $maxcost > $mincost + $threshold * $stdev ** 2 } {
        set segment1 [lrange $series 0 $idxmin]
        set segment2 [lrange $series [expr {$idxmin+1}] end]

        set left  [BinSegRecursive [expr {$first+0}]       $segment1 $minlength $threshold]
        set right [BinSegRecursive [expr {$first+$idxmin}] $segment2 $minlength $threshold]

        set indices [list [expr {$first+$idxmin}]]

        if { [llength $left] > 0 } {
            set indices [concat $left $indices]
        }

        if { [llength $right] > 0 } {
            set indices [concat $indices $right]
        }
    }

    return $indices
}

