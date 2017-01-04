# stat_kernel.tcl --
#
#    Part of the statistics package for basic statistical analysis
#    Based on http://en.wikipedia.org/wiki/Kernel_(statistics) and
#             http://en.wikipedia.org/wiki/Kernel_density_estimation
#
# version 0.1:   initial implementation, january 2014

# kernel-density --
#     Estimate the probability density using the kernel density
#     estimation method
#
# Arguments:
#     data            List of univariate data
#     args            List of options in the form of keyword-value pairs:
#                     -weights weights: per data point the weight
#                     -bandwidth value: bandwidth to be used for the estimation
#                     -number value: number of bins to be returned
#                     -interval {begin end}: begin and end of the interval for
#                         which the density is returned
#                     -kernel function: kernel to be used (gaussian, cosine,
#                         epanechnikov, uniform, triangular, biweight,
#                         logistic)
#                     For all options more or less sensible defaults are
#                     provided.
#
# Result:
#     A list of the bin centres, a list of the corresponding density
#     estimates and a list containing several computational parameters:
#     begin and end of the interval, mean, standard deviation and bandwidth
#
# Note:
#     The conditions for the kernel function are fairly weak:
#     - It should integrate to 1
#     - It should be symmetric around 0
#
#     As for the implementation in Tcl: it should be reachable in the
#     ::math::statistics namespace. As a consequence, you can define
#     your own kernel function too. Hence there is no check.
#
proc ::math::statistics::kernel-density {data args} {

    #
    # Determine the basic statistics
    #
    set basicStats [BasicStats all $data]

    set mean       [lindex $basicStats 0]
    set ndata      [lindex $basicStats 3]
    set stdev      [lindex $basicStats 4]

    if { $ndata < 1 } {
        return -code error -errorcode ARG -errorinfo "Too few actual data"
    }

    #
    # Get the options (providing defaults as needed)
    #
    set opt(-weights)   {}
    set opt(-number)    100
    set opt(-kernel)    gaussian

    #
    # The default bandwidth is set via a simple expression, which
    # is supposed to be optimal for the Gaussian kernel.
    # Perhaps a more sophisticated method should be provided as well
    #
    set opt(-bandwidth) [expr {1.06 * $stdev / pow($ndata,0.2)}]

    #
    # The default interval is derived from the mean and the
    # standard deviation
    #
    set opt(-interval) [list [expr {$mean - 3.0 * $stdev}] [expr {$mean + 3.0 * $stdev}]]

    #
    # Retrieve the given options from $args
    #
    if { [llength $args] % 2 != 0 } {
        return -code error -errorcode ARG -errorinfo "The options must all have a value"
    }
    array set opt $args

    #
    # Elementary checks
    #
    if { $opt(-bandwidth) <= 0.0 } {
        return -code error -errorcode ARG -errorinfo "The bandwidth must be positive: $opt(-bandwidth)"
    }

    if { $opt(-number) <= 0.0 } {
        return -code error -errorcode ARG -errorinfo "The number of bins must be positive: $opt(-number)"
    }

    if { [lindex $opt(-interval) 0] == [lindex $opt(-interval) 1] } {
        return -code error -errorcode ARG -errorinfo "The interval has length zero: $opt(-interval)"
    }

    if { [llength [info proc $opt(-kernel)]] == 0 } {
        return -code error -errorcode ARG -errorinfo "Unknown kernel function: $opt(-kernel)"
    }

    #
    # Construct the weights
    #
    if { [llength $opt(-weights)] > 0 } {
        if { [llength $data] != [llength $opt(-weights)] } {
            return -code error -errorcode ARG -errorinfo "The list of weights must match the data"
        }

        set sum 0.0
        foreach d $data w $opt(-weights) {
            if { $d != {} } {
                set sum [expr {$sum + $w}]
            }
        }
        set scale [expr {1.0/$sum/$ndata}]

        set weight {}
        foreach w $opt(-weights) {
            if { $d != {} } {
                lappend weight [expr {$w / $scale}]
            } else {
                lappend weight {}
            }
        }
    } else {
        set weight [lrepeat [llength $data] [expr {1.0/$ndata}]] ;# Note: missing values have weight zero
    }

    #
    # Construct the centres of the bins
    #
    set xbegin [lindex $opt(-interval) 0]
    set xend   [lindex $opt(-interval) 1]
    set dx     [expr {($xend - $xbegin) / double($opt(-number))}]
    set xb     [expr {$xbegin + 0.5 * $dx}]
    set xvalue {}
    for {set i 0} {$i < $opt(-number)} {incr i} {
        lappend xvalue [expr {$xb + $i * $dx}]
    }

    #
    # Construct the density function
    #
    set density {}
    set scale   [expr {1.0/$opt(-bandwidth)}]
    foreach x $xvalue {
        set sum 0.0
        foreach d $data w $weight {
            if { $d != {} } {
                set kvalue [$opt(-kernel) [expr {$scale * ($x-$d)}]]
                set sum [expr {$sum + $w * $kvalue}]
            }
        }
        lappend density [expr {$sum * $scale}]
    }

    #
    # Return the result
    #
    return [list $xvalue $density [list $xbegin $xend $mean $stdev $opt(-bandwidth)]]
}

# gaussian, uniform, triangular, epanechnikov, biweight, cosine, logistic --
#    The Gaussian kernel
#
# Arguments:
#    x            (Scaled) argument
#
# Result:
#    Value of the kernel
#
# Note:
#    The standard deviation is 1.
#
proc ::math::statistics::gaussian {x} {
    return [expr {exp(-0.5*$x*$x) / sqrt(2.0*acos(-1.0))}]
}
proc ::math::statistics::uniform {x} {
    if { abs($x) <= 1.0 } {
        return 0.5
    } else {
        return 0.0
    }
}
proc ::math::statistics::triangular {x} {
    if { abs($x) < 1.0 } {
        return [expr {1.0 - abs($x)}]
    } else {
        return 0.0
    }
}
proc ::math::statistics::epanechnikov {x} {
    if { abs($x) < 1.0 } {
        return [expr {0.75 * (1.0 - abs($x)*abs($x))}]
    } else {
        return 0.0
    }
}
proc ::math::statistics::biweight {x} {
    if { abs($x) < 1.0 } {
        return [expr {0.9375 * pow((1.0 - abs($x)*abs($x)),2)}]
    } else {
        return 0.0
    }
}
proc ::math::statistics::cosine {x} {
    if { abs($x) < 1.0 } {
        return [expr {0.25 * acos(-1.0) * cos(0.5 * acos(-1.0) * $x)}]
    } else {
        return 0.0
    }
}
proc ::math::statistics::logistic {x} {
    return [expr {1.0 / (exp($x) + 2.0 + exp(-$x))}]
}
