# stat_logit.tcl --
#     Logistic regression functions - part of the statistics package
#
#     Note:
#     The implementation was derived from the Wikipedia page on logistic regression,
#     (https://en.wikipedia.org/wiki/Logistic_regression) as is the test case.
#
#     TODO:
#     - Deviance to evaluate the goodness of fit
#     - Evaluate the probability
#

package require math::optimize

namespace eval ::math::statistics {
     variable xLogit {}
     variable yLogit {}
}

# logistic-model --
#     Fit 1/0 data to a logistic model
#
# Arguments:
#     xdata        Independent variables (list of lists if there are more than one)
#     ydata        Corresponding scores (0 or 1)
#
# Result:
#     Estimate of the parameters for a logistic model
#
# Note:
#     It is expected that the independent variables have roughly the same scale
#
proc ::math::statistics::logistic-model {xdata ydata} {
    variable xLogit
    variable yLogit

    set xLogit {}
    foreach coords $xdata {
        lappend xLogit [concat 1.0 $coords]
    }
    set yLogit $ydata

    #
    # Use a trivial starting point
    #
    set startx [lrepeat [llength [lindex $xLogit 0]] 0.0]

    set result [::math::optimize::nelderMead LogisticML_NM $startx]

    return [dict get $result x]
}


# LogisticML_NM --
#     Calculate the (log) maximum likelihood for the given logistic model
#     using Nelder-Mead
#
# Arguments:
#     args        Vector of the current regression coefficients
#
# Returns:
#     Log maximum likelihood
#
proc ::math::statistics::LogisticML_NM {args} {
    variable xLogit
    variable yLogit

    set loglike 0.0
    foreach coords $xLogit score $yLogit {
        set sum 0.0

        foreach c $coords v $args {
            set sum [expr {$sum + $v * $c}]
        }
        set exp [expr {exp(-$sum)}]

        if { $score == 1 } {
            set loglike [expr {$loglike - log(1.0 + $exp)}]
        } else {
            set loglike [expr {$loglike - $sum - log(1.0 + $exp)}]
        }
    }
    return [expr {-$loglike}]
}

# logistic-probability --
#     Calculate the probability of a positive score (1) given the model
#
# Arguments:
#     coeffs      Coefficients of the logistic model (for instance outcome of model fit)
#     values      Values of the independent variables
#
# Returns:
#     Probability
#
proc ::math::statistics::logistic-probability {coeffs values} {
    set sum 0.0

    foreach c $coeffs v [concat 1.0 $values] {
        set sum [expr {$sum + $c * $v}]
    }

    return [expr {1.0 / (1.0 + exp(-$sum))}]
}

# test case: from Wikipedia
if {0} {
set xdata {0.50 0.75 1.00 1.25 1.50 1.75 1.75 2.00 2.25 2.50 2.75 3.00 3.25 3.50 4.00 4.25 4.50 4.75 5.00 5.50}
set ydata {0    0    0    0    0    0    1    0    1    0    1    0    1    0    1    1    1    1    1    1   }

set coeffs [::math::statistics::logistic-model $xdata $ydata]

puts "Model fit: $coeffs"

puts "Probabilities:"

foreach x {1 2 3 4 5} {
    puts "$x - [::math::statistics::logistic-probability $coeffs $x]"
}
}
