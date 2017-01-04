# statistics.tcl --
#
#    Package for basic statistical analysis
#
# version 0.1:   initial implementation, january 2003
# version 0.1.1: added linear regres
# version 0.1.2: border case in stdev taken care of
# version 0.1.3: moved initialisation of CDF to first call, november 2004
# version 0.3:   added test for normality (as implemented by Torsten Reincke), march 2006
#                (also fixed an error in the export list)
# version 0.4:   added the multivariate linear regression procedures by
#                Eric Kemp-Benedict, february 2007
# version 0.5:   added the population standard deviation and variance,
#                as suggested by Dimitrios Zachariadis
# version 0.6:   added pdf and cdf procedures for various distributions
#                (provided by Eric Kemp-Benedict)
# version 0.7:   added Kruskal-Wallis test (by Torsten Berg)
# version 0.8:   added Wilcoxon test and Spearman rank correlation
# version 0.9:   added kernel density estimation
# version 0.9.3: added histogram-alt, corrected test-normal

package require Tcl 8.4
package provide math::statistics 1.0
package require math

if {![llength [info commands ::lrepeat]]} {
    # Forward portability, emulate lrepeat
    proc ::lrepeat {n args} {
	if {$n < 1} {
	    return -code error "must have a count of at least 1"
	}
	set res {}
	while {$n} {
	    foreach x $args { lappend res $x }
	    incr n -1
	}
	return $res
    }
}

# ::math::statistics --
#   Namespace holding the procedures and variables
#

namespace eval ::math::statistics {
    #
    # Safer: change to short procedures
    #
    namespace export mean min max number var stdev pvar pstdev basic-stats corr \
	    histogram histogram-alt interval-mean-stdev t-test-mean quantiles \
	    test-normal lillieforsFit \
	    autocorr crosscorr filter map samplescount median \
	    test-2x2 print-2x2 control-xbar test_xbar \
	    control-Rchart test-Rchart \
	    test-Kruskal-Wallis analyse-Kruskal-Wallis group-rank \
	    test-Wilcoxon spearman-rank spearman-rank-extended \
	    test-Duckworth
    #
    # Error messages
    #
    variable NEGSTDEV   {Zero or negative standard deviation}
    variable TOOFEWDATA {Too few or invalid data}
    variable OUTOFRANGE {Argument out of range}

    #
    # Coefficients involved
    #
    variable factorNormalPdf
    set factorNormalPdf [expr {sqrt(8.0*atan(1.0))}]

    # xbar/R-charts:
    # Data from:
    #    Peter W.M. John:
    #    Statistical methods in engineering and quality assurance
    #    Wiley and Sons, 1990
    #
    variable control_factors {
        A2 {1.880 1.093 0.729 0.577 0.483 0.419 0.419}
        D3 {0.0   0.0   0.0   0.0   0.0   0.076 0.076}
        D4 {3.267 2.574 2.282 2.114 2.004 1.924 1.924}
    }
}

# mean, min, max, number, var, stdev, pvar, pstdev --
#    Return the mean (minimum, maximum) value of a list of numbers
#    or number of non-missing values
#
# Arguments:
#    type     Type of value to be returned
#    values   List of values to be examined
#
# Results:
#    Value that was required
#
#
namespace eval ::math::statistics {
    foreach type {mean min max number stdev var pstdev pvar} {
	proc $type { values } "BasicStats $type \$values"
    }
    proc basic-stats { values } "BasicStats all \$values"
}

# BasicStats --
#    Return the one or all of the basic statistical properties
#
# Arguments:
#    type     Type of value to be returned
#    values   List of values to be examined
#
# Results:
#    Value that was required
#
proc ::math::statistics::BasicStats { type values } {
    variable TOOFEWDATA

    if { [lsearch {all mean min max number stdev var pstdev pvar} $type] < 0 } {
	return -code error \
		-errorcode ARG -errorinfo [list unknown type of statistic -- $type] \
		[list unknown type of statistic -- $type]
    }

    set min    {}
    set max    {}
    set mean   {}
    set stdev  {}
    set var    {}

    set sum    0.0
    set sumsq  0.0
    set number 0
    set first  {}

    foreach value $values {
	if { $value == {} } {
	    continue
	}
	set value [expr {double($value)}]

	if { $first == {} } {
	    set first $value
	}

	incr number
	set  sum    [expr {$sum+$value}]
	set  sumsq  [expr {$sumsq+($value-$first)*($value-$first)}]

	if { $min == {} || $value < $min } {
	    set min $value
	}
	if { $max == {} || $value > $max } {
	    set max $value
	}
    }

    if { $number > 0 } {
	set mean [expr {$sum/$number}]
    } else {
	return -code error -errorcode DATA -errorinfo $TOOFEWDATA $TOOFEWDATA
    }

    if { $number > 1 } {
	set var    [expr {($sumsq-($mean-$first)*($sum-$number*$first))/double($number-1)}]
        #
        # Take care of a rare situation: uniform data might
        # cause a tiny negative difference
        #
        if { $var < 0.0 } {
           set var 0.0
        }
	set stdev  [expr {sqrt($var)}]
    }
	set pvar [expr {($sumsq-($mean-$first)*($sum-$number*$first))/double($number)}]
        #
        # Take care of a rare situation: uniform data might
        # cause a tiny negative difference
        #
        if { $pvar < 0.0 } {
           set pvar 0.0
        }
	set pstdev  [expr {sqrt($pvar)}]

    set all [list $mean $min $max $number $stdev $var $pstdev $pvar]

    #
    # Return the appropriate value
    #
    set $type
}

# histogram --
#    Return histogram information from a list of numbers
#
# Arguments:
#    limits   Upper limits for the buckets (in increasing order)
#    values   List of values to be examined
#    weights  List of weights, one per value (optional)
#
# Results:
#    List of number of values in each bucket (length is one more than
#    the number of limits)
#
#
proc ::math::statistics::histogram { limits values {weights {}} } {

    if { [llength $limits] < 1 } {
	return -code error -errorcode ARG -errorinfo {No limits given} {No limits given}
    }
    if { [llength $weights] > 0 && [llength $values] != [llength $weights] } {
	return -code error -errorcode ARG -errorinfo {Number of weights be equal to number of values} {Weights and values differ in length}
    }

    set limits [lsort -real -increasing $limits]

    for { set index 0 } { $index <= [llength $limits] } { incr index } {
	set buckets($index) 0
    }

    set last [llength $limits]

    # Will do integer arithmetic if unset
    if {$weights eq ""} {
       set weights [lrepeat [llength $values] 1]
    }

    foreach value $values weight $weights {
	if { $value == {} } {
	    continue
	}

	set index 0
	set found 0
	foreach limit $limits {
	    if { $value <= $limit } {
		set found 1
		set buckets($index) [expr $buckets($index)+$weight]
		break
	    }
	    incr index
	}

	if { $found == 0 } {
	    set buckets($last) [expr $buckets($last)+$weight]
	}
    }

    set result {}
    for { set index 0 } { $index <= $last } { incr index } {
	lappend result $buckets($index)
    }

    return $result
}

# histogram-alt --
#    Return histogram information from a list of numbers -
#    intervals are open-ended at the lower bound instead of at the upper bound
#
# Arguments:
#    limits   Upper limits for the buckets (in increasing order)
#    values   List of values to be examined
#    weights  List of weights, one per value (optional)
#
# Results:
#    List of number of values in each bucket (length is one more than
#    the number of limits)
#
#
proc ::math::statistics::histogram-alt { limits values {weights {}} } {

    if { [llength $limits] < 1 } {
	return -code error -errorcode ARG -errorinfo {No limits given} {No limits given}
    }
    if { [llength $weights] > 0 && [llength $values] != [llength $weights] } {
	return -code error -errorcode ARG -errorinfo {Number of weights be equal to number of values} {Weights and values differ in length}
    }

    set limits [lsort -real -increasing $limits]

    for { set index 0 } { $index <= [llength $limits] } { incr index } {
	set buckets($index) 0
    }

    set last [llength $limits]

    # Will do integer arithmetic if unset
    if {$weights eq ""} {
       set weights [lrepeat [llength $values] 1]
    }

    foreach value $values weight $weights {
	if { $value == {} } {
	    continue
	}

	set index 0
	set found 0
	foreach limit $limits {
	    if { $value < $limit } {
		set found 1
		set buckets($index) [expr $buckets($index)+$weight]
		break
	    }
	    incr index
	}

	if { $found == 0 } {
	    set buckets($last) [expr $buckets($last)+$weight]
	}
    }

    set result {}
    for { set index 0 } { $index <= $last } { incr index } {
	lappend result $buckets($index)
    }

    return $result
}

# corr --
#    Return the correlation coefficient of two sets of data
#
# Arguments:
#    data1    List with the first set of data
#    data2    List with the second set of data
#
# Result:
#    Correlation coefficient of the two
#
proc ::math::statistics::corr { data1 data2 } {
    variable TOOFEWDATA

    set number  0
    set sum1    0.0
    set sum2    0.0
    set sumsq1  0.0
    set sumsq2  0.0
    set sumprod 0.0

    foreach value1 $data1 value2 $data2 {
	if { $value1 == {} || $value2 == {} } {
	    continue
	}
	set  value1  [expr {double($value1)}]
	set  value2  [expr {double($value2)}]

	set  sum1    [expr {$sum1+$value1}]
	set  sum2    [expr {$sum2+$value2}]
	set  sumsq1  [expr {$sumsq1+$value1*$value1}]
	set  sumsq2  [expr {$sumsq2+$value2*$value2}]
	set  sumprod [expr {$sumprod+$value1*$value2}]
	incr number
    }
    if { $number > 0 } {
	set numerator   [expr {$number*$sumprod-$sum1*$sum2}]
	set denom1      [expr {sqrt($number*$sumsq1-$sum1*$sum1)}]
	set denom2      [expr {sqrt($number*$sumsq2-$sum2*$sum2)}]
	if { $denom1 != 0.0 && $denom2 != 0.0 } {
	    set corr_coeff  [expr {$numerator/$denom1/$denom2}]
	} elseif { $denom1 != 0.0 || $denom2 != 0.0 } {
	    set corr_coeff  0.0 ;# Uniform against non-uniform
	} else {
	    set corr_coeff  1.0 ;# Both uniform
	}

    } else {
	return -code error -errorcode DATA -errorinfo $TOOFEWDATA $TOOFEWDATA
    }
    return $corr_coeff
}

# lillieforsFit --
#     Calculate the goodness of fit according to Lilliefors
#     (goodness of fit to a normal distribution)
#
# Arguments:
#     values          List of values to be tested for normality
#
# Result:
#     Value of the statistic D
#
proc ::math::statistics::lillieforsFit {values} {
    #
    # calculate the goodness of fit according to Lilliefors
    # (goodness of fit to a normal distribution)
    #
    # values -> list of values to be tested for normality
    # (these values are sampled counts)
    #

    # calculate standard deviation and mean of the sample:
    set n [llength $values]
    if { $n < 5 } {
        return -code error "Insufficient number of data (at least five required)"
    }
    set sd   [stdev $values]
    set mean [mean $values]

    # sort the sample for further processing:
    set values [lsort -real $values]

    # standardize the sample data (Z-scores):
    foreach x $values {
        lappend stdData [expr {($x - $mean)/double($sd)}]
    }

    # compute the value of the distribution function at every sampled point:
    foreach x $stdData {
        lappend expData [pnorm $x]
    }

    # compute D+:
    set i 0
    foreach x $expData {
        incr i
        lappend dplus [expr {$i/double($n)-$x}]
    }
    set dplus [lindex [lsort -real $dplus] end]

    # compute D-:
    set i 0
    foreach x $expData {
        incr i
        lappend dminus [expr {$x-($i-1)/double($n)}]
    }
    set dminus [lindex [lsort -real $dminus] end]

    # Calculate the test statistic D
    # by finding the maximal vertical difference
    # between the sample and the expectation:
    #
    set D [expr {$dplus > $dminus ? $dplus : $dminus}]

    # We now use the modified statistic Z,
    # because D is only reliable
    # if the p-value is smaller than 0.1
    return [expr {$D * (sqrt($n) - 0.01 + 0.831/sqrt($n))}]
}

# pnorm --
#     Calculate the cumulative distribution function (cdf)
#     for the standard normal distribution like in the statistical
#     software 'R' (mean=0 and sd=1)
#
# Arguments:
#     x               Value fro which the cdf should be calculated
#
# Result:
#     Value of the statistic D
#
proc ::math::statistics::pnorm {x} {
    #
    # cumulative distribution function (cdf)
    # for the standard normal distribution like in the statistical software 'R'
    # (mean=0 and sd=1)
    #
    # x -> value for which the cdf should be calculated
    #
    set sum [expr {double($x)}]
    set oldSum 0.0
    set i 1
    set denom 1.0
    while {$sum != $oldSum} {
            set oldSum $sum
            incr i 2
            set denom [expr {$denom*$i}]
            #puts "$i - $denom"
            set sum [expr {$oldSum + pow($x,$i)/$denom}]
    }
    return [expr {0.5 + $sum * exp(-0.5 * $x*$x - 0.91893853320467274178)}]
}

# pnorm_quicker --
#     Calculate the cumulative distribution function (cdf)
#     for the standard normal distribution - quicker alternative
#     (less accurate)
#
# Arguments:
#     x               Value for which the cdf should be calculated
#
# Result:
#     Value of the statistic D
#
proc ::math::statistics::pnorm_quicker {x} {

    set n [expr {abs($x)}]
    set n [expr {1.0 + $n*(0.04986735 + $n*(0.02114101 + $n*(0.00327763 \
            + $n*(0.0000380036 + $n*(0.0000488906 + $n*0.000005383)))))}]
    set n [expr {1.0/pow($n,16)}]
    #
    if {$x >= 0} {
        return [expr {1 - $n/2.0}]
    } else {
        return [expr {$n/2.0}]
    }
}

# test-normal --
#     Test for normality (using method Lilliefors)
#
# Arguments:
#     data            Values that need to be tested
#     significance    Level at which the discrepancy from normality is tested
#
# Result:
#     1 if the Lilliefors statistic D is larger than the critical level
#
# Note:
#     There was a mistake in the implementation before 0.9.3: confidence (wrong word)
#     instead of significance. To keep compatibility with earlier versions, both
#     significance and 1-significance are accepted.
#
proc ::math::statistics::test-normal {data significance} {
    set D [lillieforsFit $data]

    if { $significance > 0.5 } {
        set significance [expr {1.0-$significance}] ;# Convert the erroneous levels pre 0.9.3
    }

    set Dcrit --
    if { abs($significance-0.20) < 0.0001 } {
        set Dcrit 0.741
    }
    if { abs($significance-0.15) < 0.0001 } {
        set Dcrit 0.775
    }
    if { abs($significance-0.10) < 0.0001 } {
        set Dcrit 0.819
    }
    if { abs($significance-0.05) < 0.0001 } {
        set Dcrit 0.895
    }
    if { abs($significance-0.01) < 0.0001 } {
        set Dcrit 1.035
    }
    if { $Dcrit != "--" } {
        return [expr {$D > $Dcrit ? 1 : 0 }]
    } else {
        return -code error "Significancce level must be one of: 0.20, 0.15, 0.10, 0.05 or 0.01"
    }
}

# t-test-mean --
#    Test whether the mean value of a sample is in accordance with the
#    estimated normal distribution with a certain probability
#    (Student's t test)
#
# Arguments:
#    data         List of raw data values (small sample)
#    est_mean     Estimated mean of the distribution
#    est_stdev    Estimated stdev of the distribution
#    alpha        Probability level (0.95 or 0.99 for instance)
#
# Result:
#    1 if the test is positive, 0 otherwise. If there are too few data,
#    returns an empty string
#
proc ::math::statistics::t-test-mean { data est_mean est_stdev alpha } {
    variable NEGSTDEV
    variable TOOFEWDATA

    if { $est_stdev <= 0.0 } {
	return -code error -errorcode ARG -errorinfo $NEGSTDEV $NEGSTDEV
    }

    set allstats        [BasicStats all $data]

    set alpha2          [expr {(1.0+$alpha)/2.0}]

    set sample_mean     [lindex $allstats 0]
    set sample_number   [lindex $allstats 3]

    if { $sample_number > 1 } {
	set tzero   [expr {abs($sample_mean-$est_mean)/$est_stdev * \
		sqrt($sample_number-1)}]
	set degrees [expr {$sample_number-1}]
	set prob    [cdf-students-t $degrees $tzero]

	return [expr {$prob<$alpha2}]

    } else {
	return -code error -errorcode DATA -errorinfo $TOOFEWDATA $TOOFEWDATA
    }
}

# interval-mean-stdev --
#    Return the interval containing the mean value and one
#    containing the standard deviation with a certain
#    level of confidence (assuming a normal distribution)
#
# Arguments:
#    data         List of raw data values
#    confidence   Confidence level (0.95 or 0.99 for instance)
#
# Result:
#    List having the following elements: lower and upper bounds of
#    mean, lower and upper bounds of stdev
#
#
proc ::math::statistics::interval-mean-stdev { data confidence } {
    variable TOOFEWDATA

    set allstats [BasicStats all $data]

    set conf2    [expr {(1.0+$confidence)/2.0}]
    set mean     [lindex $allstats 0]
    set number   [lindex $allstats 3]
    set stdev    [lindex $allstats 4]

    if { $number > 1 } {
	set degrees    [expr {$number-1}]
	set student_t  [expr {sqrt([Inverse-cdf-toms322 1 $degrees $conf2])}]
	set mean_lower [expr {$mean-$student_t*$stdev/sqrt($number)}]
	set mean_upper [expr {$mean+$student_t*$stdev/sqrt($number)}]
	set stdev_lower {}
	set stdev_upper {}
	return [list $mean_lower $mean_upper $stdev_lower $stdev_upper]
    } else {
	return -code error -errorcode DATA -errorinfo $TOOFEWDATA $TOOFEWDATA
    }
}

# quantiles --
#    Return the quantiles for a given set of data or histogram
#
# Arguments:
#    (two arguments)
#    data         List of raw data values
#    confidence   Confidence level (0.95 or 0.99 for instance)
#    (three arguments)
#    limits       List of upper limits from histogram
#    counts       List of counts for for each interval in histogram
#    confidence   Confidence level (0.95 or 0.99 for instance)
#
# Result:
#    List of quantiles
#
proc ::math::statistics::quantiles { arg1 arg2 {arg3 {}} } {
    variable TOOFEWDATA

    if { [catch {
	if { $arg3 == {} } {
	    set result \
		    [::math::statistics::QuantilesRawData $arg1 $arg2]
	} else {
	    set result \
		    [::math::statistics::QuantilesHistogram $arg1 $arg2 $arg3]
	}
    } msg] } {
	return -code error -errorcode $msg $msg
    }
    return $result
}

# QuantilesRawData --
#    Return the quantiles based on raw data
#
# Arguments:
#    data         List of raw data values
#    confidence   Confidence level (0.95 or 0.99 for instance)
#
# Result:
#    List of quantiles
#
proc ::math::statistics::QuantilesRawData { data confidence } {
    variable TOOFEWDATA
    variable OUTOFRANGE

    if { [llength $confidence] <= 0 } {
	return -code error -errorcode ARG "$TOOFEWDATA - quantiles"
    }

    if { [llength $data] <= 0 } {
	return -code error -errorcode ARG "$TOOFEWDATA - raw data"
    }

    foreach cond $confidence {
	if { $cond <= 0.0 || $cond >= 1.0 } {
	    return -code error -errorcode ARG "$OUTOFRANGE - quantiles"
	}
    }

    #
    # Sort the data first
    #
    set sorted_data [lsort -real -increasing $data]

    #
    # Determine the list element lower or equal to the quantile
    # and return the corresponding value
    #
    set result      {}
    set number_data [llength $sorted_data]
    foreach cond $confidence {
	set elem [expr {round($number_data*$cond)-1}]
	if { $elem < 0 } {
	    set elem 0
	}
	lappend result [lindex $sorted_data $elem]
    }

    return $result
}

# QuantilesHistogram --
#    Return the quantiles based on histogram information only
#
# Arguments:
#    limits       Upper limits for histogram intervals
#    counts       Counts for each interval
#    confidence   Confidence level (0.95 or 0.99 for instance)
#
# Result:
#    List of quantiles
#
proc ::math::statistics::QuantilesHistogram { limits counts confidence } {
    variable TOOFEWDATA
    variable OUTOFRANGE

    if { [llength $confidence] <= 0 } {
	return -code error -errorcode ARG "$TOOFEWDATA - quantiles"
    }

    if { [llength $confidence] <= 0 } {
	return -code error -errorcode ARG "$TOOFEWDATA - histogram limits"
    }

    if { [llength $counts] <= [llength $limits] } {
	return -code error -errorcode ARG "$TOOFEWDATA - histogram counts"
    }

    foreach cond $confidence {
	if { $cond <= 0.0 || $cond >= 1.0 } {
	    return -code error -errorcode ARG "$OUTOFRANGE - quantiles"
	}
    }

    #
    # Accumulate the histogram counts first
    #
    set sum 0
    set accumulated_counts {}
    foreach count $counts {
	set sum [expr {$sum+$count}]
	lappend accumulated_counts $sum
    }
    set total_counts $sum

    #
    # Determine the list element lower or equal to the quantile
    # and return the corresponding value (use interpolation if
    # possible)
    #
    set result      {}
    foreach cond $confidence {
	set found       0
	set bound       [expr {round($total_counts*$cond)}]
	set lower_limit {}
	set lower_count 0
	foreach acc_count $accumulated_counts limit $limits {
	    if { $acc_count >= $bound } {
		set found 1
		break
	    }
	    set lower_limit $limit
	    set lower_count $acc_count
	}

	if { $lower_limit == {} || $limit == {} || $found == 0 } {
	    set quant $limit
	    if { $limit == {} } {
		set quant $lower_limit
	    }
	} else {
	    set quant [expr {$limit+($lower_limit-$limit) *
	    ($acc_count-$bound)/($acc_count-$lower_count)}]
	}
	lappend result $quant
    }

    return $result
}

# autocorr --
#    Return the autocorrelation function (assuming equidistance between
#    samples)
#
# Arguments:
#    data         Raw data for which the autocorrelation must be determined
#
# Result:
#    List of autocorrelation values (about 1/2 the number of raw data)
#
proc ::math::statistics::autocorr { data } {
    variable TOOFEWDATA

    if { [llength $data] <= 1 } {
	return -code error -errorcode ARG "$TOOFEWDATA"
    }

    return [crosscorr $data $data]
}

# crosscorr --
#    Return the cross-correlation function (assuming equidistance
#    between samples)
#
# Arguments:
#    data1        First set of raw data
#    data2        Second set of raw data
#
# Result:
#    List of cross-correlation values (about 1/2 the number of raw data)
#
# Note:
#    The number of data pairs is not kept constant - because tests
#    showed rather awkward results when it was kept constant.
#
proc ::math::statistics::crosscorr { data1 data2 } {
    variable TOOFEWDATA

    if { [llength $data1] <= 1 || [llength $data2] <= 1 } {
	return -code error -errorcode ARG "$TOOFEWDATA"
    }

    #
    # First determine the number of data pairs
    #
    set number1 [llength $data1]
    set number2 [llength $data2]

    set basic_stat1 [basic-stats $data1]
    set basic_stat2 [basic-stats $data2]
    set vmean1      [lindex $basic_stat1 0]
    set vmean2      [lindex $basic_stat2 0]
    set vvar1       [lindex $basic_stat1 end]
    set vvar2       [lindex $basic_stat2 end]

    set number_pairs $number1
    if { $number1 > $number2 } {
	set number_pairs $number2
    }
    set number_values $number_pairs
    set number_delays [expr {$number_values/2.0}]

    set scale [expr {sqrt($vvar1*$vvar2)}]

    set result {}
    for { set delay 0 } { $delay < $number_delays } { incr delay } {
	set sumcross 0.0
	set no_cross 0
	for { set idx 0 } { $idx < $number_values } { incr idx } {
	    set value1 [lindex $data1 $idx]
	    set value2 [lindex $data2 [expr {$idx+$delay}]]
	    if { $value1 != {} && $value2 != {} } {
		set  sumcross \
			[expr {$sumcross+($value1-$vmean1)*($value2-$vmean2)}]
		incr no_cross
	    }
	}
	lappend result [expr {$sumcross/($no_cross*$scale)}]

	incr number_values -1
    }

    return $result
}

# mean-histogram-limits
#    Determine reasonable limits based on mean and standard deviation
#    for a histogram
#
# Arguments:
#    mean         Mean of the data
#    stdev        Standard deviation
#    number       Number of limits to generate (defaults to 8)
#
# Result:
#    List of limits
#
proc ::math::statistics::mean-histogram-limits { mean stdev {number 8} } {
    variable NEGSTDEV

    if { $stdev <= 0.0 } {
	return -code error -errorcode ARG "$NEGSTDEV"
    }
    if { $number < 1 } {
	return -code error -errorcode ARG "Number of limits must be positive"
    }

    #
    # Always: between mean-3.0*stdev and mean+3.0*stdev
    # number = 2: -0.25, 0.25
    # number = 3: -0.25, 0, 0.25
    # number = 4: -1, -0.25, 0.25, 1
    # number = 5: -1, -0.25, 0, 0.25, 1
    # number = 6: -2, -1, -0.25, 0.25, 1, 2
    # number = 7: -2, -1, -0.25, 0, 0.25, 1, 2
    # number = 8: -3, -2, -1, -0.25, 0.25, 1, 2, 3
    #
    switch -- $number {
	"1" { set limits {0.0} }
	"2" { set limits {-0.25 0.25} }
	"3" { set limits {-0.25 0.0 0.25} }
	"4" { set limits {-1.0 -0.25 0.25 1.0} }
	"5" { set limits {-1.0 -0.25 0.0 0.25 1.0} }
	"6" { set limits {-2.0 -1.0 -0.25 0.25 1.0 2.0} }
	"7" { set limits {-2.0 -1.0 -0.25 0.0 0.25 1.0 2.0} }
	"8" { set limits {-3.0 -2.0 -1.0 -0.25 0.25 1.0 2.0 3.0} }
	"9" { set limits {-3.0 -2.0 -1.0 -0.25 0.0 0.25 1.0 2.0 3.0} }
	default {
	    set dlim [expr {6.0/double($number-1)}]
	    for {set i 0} {$i <$number} {incr i} {
		lappend limits [expr {$dlim*($i-($number-1)/2.0)}]
	    }
	}
    }

    set result {}
    foreach limit $limits {
	lappend result [expr {$mean+$limit*$stdev}]
    }

    return $result
}

# minmax-histogram-limits
#    Determine reasonable limits based on minimum and maximum bounds
#    for a histogram
#
# Arguments:
#    min          Estimated minimum
#    max          Estimated maximum
#    number       Number of limits to generate (defaults to 8)
#
# Result:
#    List of limits
#
proc ::math::statistics::minmax-histogram-limits { min max {number 8} } {
    variable NEGSTDEV

    if { $number < 1 } {
	return -code error -errorcode ARG "Number of limits must be positive"
    }
    if { $min >= $max } {
	return -code error -errorcode ARG "Minimum must be lower than maximum"
    }

    set result {}
    set dlim [expr {($max-$min)/double($number-1)}]
    for {set i 0} {$i <$number} {incr i} {
	lappend result [expr {$min+$dlim*$i}]
    }

    return $result
}

# linear-model
#    Determine the coefficients for a linear regression between
#    two series of data (the model: Y = A + B*X)
#
# Arguments:
#    xdata        Series of independent (X) data
#    ydata        Series of dependent (Y) data
#    intercept    Whether to use an intercept or not (optional)
#
# Result:
#    List of the following items:
#    - (Estimate of) Intercept A
#    - (Estimate of) Slope B
#    - Standard deviation of Y relative to fit
#    - Correlation coefficient R2
#    - Number of degrees of freedom df
#    - Standard error of the intercept A
#    - Significance level of A
#    - Standard error of the slope B
#    - Significance level of B
#
#
proc ::math::statistics::linear-model { xdata ydata {intercept 1} } {
   variable TOOFEWDATA

   if { [llength $xdata] < 3 } {
      return -code error -errorcode ARG "$TOOFEWDATA: not enough independent data"
   }
   if { [llength $ydata] < 3 } {
      return -code error -errorcode ARG "$TOOFEWDATA: not enough dependent data"
   }
   if { [llength $xdata] != [llength $ydata] } {
      return -code error -errorcode ARG "$TOOFEWDATA: number of dependent data differs from number of independent data"
   }

   set sumx  0.0
   set sumy  0.0
   set sumx2 0.0
   set sumy2 0.0
   set sumxy 0.0
   set df    0
   foreach x $xdata y $ydata {
      if { $x != "" && $y != "" } {
         set sumx  [expr {$sumx+$x}]
         set sumy  [expr {$sumy+$y}]
         set sumx2 [expr {$sumx2+$x*$x}]
         set sumy2 [expr {$sumy2+$y*$y}]
         set sumxy [expr {$sumxy+$x*$y}]
         incr df
      }
   }

   if { $df <= 2 } {
      return -code error -errorcode ARG "$TOOFEWDATA: too few valid data"
   }
   if { $sumx2 == 0.0 } {
      return -code error -errorcode ARG "$TOOFEWDATA: independent values are all the same"
   }

   #
   # Calculate the intermediate quantities
   #
   set sx  [expr {$sumx2-$sumx*$sumx/$df}]
   set sy  [expr {$sumy2-$sumy*$sumy/$df}]
   set sxy [expr {$sumxy-$sumx*$sumy/$df}]

   #
   # Calculate the coefficients
   #
   if { $intercept } {
      set B [expr {$sxy/$sx}]
      set A [expr {($sumy-$B*$sumx)/$df}]
   } else {
      set B [expr {$sumxy/$sumx2}]
      set A 0.0
   }

   #
   # Calculate the error estimates
   #
   set stdevY 0.0
   set varY   0.0

   if { $intercept } {
      set ve [expr {$sy-$B*$sxy}]
      if { $ve >= 0.0 } {
         set varY [expr {$ve/($df-2)}]
      }
   } else {
      set ve [expr {$sumy2-$B*$sumxy}]
      if { $ve >= 0.0 } {
         set varY [expr {$ve/($df-1)}]
      }
   }
   set seY [expr {sqrt($varY)}]

   if { $intercept } {
      set R2    [expr {$sxy*$sxy/($sx*$sy)}]
      set seA   [expr {$seY*sqrt(1.0/$df+$sumx*$sumx/($sx*$df*$df))}]
      set seB   [expr {sqrt($varY/$sx)}]
      set tA    {}
      set tB    {}
      if { $seA != 0.0 } {
         set tA    [expr {$A/$seA*sqrt($df-2)}]
      }
      if { $seB != 0.0 } {
         set tB    [expr {$B/$seB*sqrt($df-2)}]
      }
   } else {
      set R2    [expr {$sumxy*$sumxy/($sumx2*$sumy2)}]
      set seA   {}
      set tA    {}
      set tB    {}
      set seB   [expr {sqrt($varY/$sumx2)}]
      if { $seB != 0.0 } {
         set tB    [expr {$B/$seB*sqrt($df-1)}]
      }
   }

   #
   # Return the list of parameters
   #
   return [list $A $B $seY $R2 $df $seA $tA $seB $tB]
}

# linear-residuals
#    Determine the difference between actual data and predicted from
#    the linear model
#
# Arguments:
#    xdata        Series of independent (X) data
#    ydata        Series of dependent (Y) data
#    intercept    Whether to use an intercept or not (optional)
#
# Result:
#    List of differences
#
proc ::math::statistics::linear-residuals { xdata ydata {intercept 1} } {
   variable TOOFEWDATA

   if { [llength $xdata] < 3 } {
      return -code error -errorcode ARG "$TOOFEWDATA: no independent data"
   }
   if { [llength $ydata] < 3 } {
      return -code error -errorcode ARG "$TOOFEWDATA: no dependent data"
   }
   if { [llength $xdata] != [llength $ydata] } {
      return -code error -errorcode ARG "$TOOFEWDATA: number of dependent data differs from number of independent data"
   }

   foreach {A B} [linear-model $xdata $ydata $intercept] {break}

   set result {}
   foreach x $xdata y $ydata {
      set residue [expr {$y-$A-$B*$x}]
      lappend result $residue
   }
   return $result
}

# median
#    Determine the median from a list of data
#
# Arguments:
#    data         (Unsorted) list of data
#
# Result:
#    Median (either the middle value or the mean of two values in the
#    middle)
#
# Note:
#    Adapted from the Wiki page "Stats", code provided by JPS
#
proc ::math::statistics::median { data } {
    set org_data $data
    set data     {}
    foreach value $org_data {
        if { $value != {} } {
            lappend data $value
        }
    }
    set len [llength $data]

    set data [lsort -real $data]
    if { $len % 2 } {
        lindex $data [expr {($len-1)/2}]
    } else {
        expr {([lindex $data [expr {($len / 2) - 1}]] \
		+ [lindex $data [expr {$len / 2}]]) / 2.0}
    }
}

# test-2x2 --
#     Compute the chi-square statistic for a 2x2 table
#
# Arguments:
#     a           Element upper-left
#     b           Element upper-right
#     c           Element lower-left
#     d           Element lower-right
# Return value:
#     Chi-square
# Note:
#     There is only one degree of freedom - this is important
#     when comparing the value to the tabulated values
#     of chi-square
#
proc ::math::statistics::test-2x2 { a b c d } {
    set ab     [expr {$a+$b}]
    set ac     [expr {$a+$c}]
    set bd     [expr {$b+$d}]
    set cd     [expr {$c+$d}]
    set N      [expr {$a+$b+$c+$d}]
    set det    [expr {$a*$d-$b*$c}]
    set result [expr {double($N*$det*$det)/double($ab*$cd*$ac*$bd)}]
}

# print-2x2 --
#     Print a 2x2 table
#
# Arguments:
#     a           Element upper-left
#     b           Element upper-right
#     c           Element lower-left
#     d           Element lower-right
# Return value:
#     Printed version with marginals
#
proc ::math::statistics::print-2x2 { a b c d } {
    set ab     [expr {$a+$b}]
    set ac     [expr {$a+$c}]
    set bd     [expr {$b+$d}]
    set cd     [expr {$c+$d}]
    set N      [expr {$a+$b+$c+$d}]
    set chisq  [test-2x2 $a $b $c $d]

    set    line   [string repeat - 10]
    set    result [format "%10d%10d | %10d\n" $a $b $ab]
    append result [format "%10d%10d | %10d\n" $c $d $cd]
    append result [format "%10s%10s + %10s\n" $line $line $line]
    append result [format "%10d%10d | %10d\n" $ac $bd $N]
    append result "Chisquare = $chisq\n"
    append result "Difference is significant?\n"
    append result "   at 95%: [expr {$chisq<3.84146? "no":"yes"}]\n"
    append result "   at 99%: [expr {$chisq<6.63490? "no":"yes"}]"
}

# control-xbar --
#     Determine the control lines for an x-bar chart
#
# Arguments:
#     data        List of observed values (at least 20*nsamples)
#     nsamples    Number of data per subsamples (default: 4)
# Return value:
#     List of: mean, lower limit, upper limit, number of data per
#     subsample. Can be used in the test-xbar procedure
#
proc ::math::statistics::control-xbar { data {nsamples 4} } {
    variable TOOFEWDATA
    variable control_factors

    #
    # Check the number of data
    #
    if { $nsamples <= 1 } {
        return -code error -errorcode DATA -errorinfo $OUTOFRANGE \
            "Number of data per subsample must be at least 2"
    }
    if { [llength $data] < 20*$nsamples } {
        return -code error -errorcode DATA -errorinfo $TOOFEWDATA $TOOFEWDATA
    }

    set nogroups [expr {[llength $data]/$nsamples}]
    set mrange   0.0
    set xmeans   0.0
    for { set i 0 } { $i < $nogroups } { incr i } {
        set subsample [lrange $data [expr {$i*$nsamples}] [expr {$i*$nsamples+$nsamples-1}]]

        set xmean 0.0
        set xmin  [lindex $subsample 0]
        set xmax  $xmin
        foreach d $subsample {
            set xmean [expr {$xmean+$d}]
            set xmin  [expr {$xmin<$d? $xmin : $d}]
            set xmax  [expr {$xmax>$d? $xmax : $d}]
        }
        set xmean [expr {$xmean/double($nsamples)}]

        set xmeans [expr {$xmeans+$xmean}]
        set mrange [expr {$mrange+($xmax-$xmin)}]
    }

    #
    # Determine the control lines
    #
    set xmeans [expr {$xmeans/double($nogroups)}]
    set mrange [expr {$mrange/double($nogroups)}]
    set A2     [lindex [lindex $control_factors 1] $nsamples]
    if { $A2 == "" } { set A2 [lindex [lindex $control_factors 1] end] }

    return [list $xmeans [expr {$xmeans-$A2*$mrange}] \
                         [expr {$xmeans+$A2*$mrange}] $nsamples]
}

# test-xbar --
#     Determine if any data points lie outside the x-bar control limits
#
# Arguments:
#     control     List returned by control-xbar with control data
#     data        List of observed values
# Return value:
#     Indices of any subsamples that violate the control limits
#
proc ::math::statistics::test-xbar { control data } {
    foreach {xmean xlower xupper nsamples} $control {break}

    if { [llength $data] < 1 } {
        return -code error -errorcode DATA -errorinfo $TOOFEWDATA $TOOFEWDATA
    }

    set nogroups [expr {[llength $data]/$nsamples}]
    if { $nogroups <= 0 } {
        set nogroup  1
        set nsamples [llength $data]
    }

    set result {}

    for { set i 0 } { $i < $nogroups } { incr i } {
        set subsample [lrange $data [expr {$i*$nsamples}] [expr {$i*$nsamples+$nsamples-1}]]

        set xmean 0.0
        foreach d $subsample {
            set xmean [expr {$xmean+$d}]
        }
        set xmean [expr {$xmean/double($nsamples)}]

        if { $xmean < $xlower } { lappend result $i }
        if { $xmean > $xupper } { lappend result $i }
    }

    return $result
}

# control-Rchart --
#     Determine the control lines for an R chart
#
# Arguments:
#     data        List of observed values (at least 20*nsamples)
#     nsamples    Number of data per subsamples (default: 4)
# Return value:
#     List of: mean range, lower limit, upper limit, number of data per
#     subsample. Can be used in the test-Rchart procedure
#
proc ::math::statistics::control-Rchart { data {nsamples 4} } {
    variable TOOFEWDATA
    variable control_factors

    #
    # Check the number of data
    #
    if { $nsamples <= 1 } {
        return -code error -errorcode DATA -errorinfo $OUTOFRANGE \
            "Number of data per subsample must be at least 2"
    }
    if { [llength $data] < 20*$nsamples } {
        return -code error -errorcode DATA -errorinfo $TOOFEWDATA $TOOFEWDATA
    }

    set nogroups [expr {[llength $data]/$nsamples}]
    set mrange   0.0
    for { set i 0 } { $i < $nogroups } { incr i } {
        set subsample [lrange $data [expr {$i*$nsamples}] [expr {$i*$nsamples+$nsamples-1}]]

        set xmin  [lindex $subsample 0]
        set xmax  $xmin
        foreach d $subsample {
            set xmin  [expr {$xmin<$d? $xmin : $d}]
            set xmax  [expr {$xmax>$d? $xmax : $d}]
        }
        set mrange [expr {$mrange+($xmax-$xmin)}]
    }

    #
    # Determine the control lines
    #
    set mrange [expr {$mrange/double($nogroups)}]
    set D3     [lindex [lindex $control_factors 3] $nsamples]
    set D4     [lindex [lindex $control_factors 5] $nsamples]
    if { $D3 == "" } { set D3 [lindex [lindex $control_factors 3] end] }
    if { $D4 == "" } { set D4 [lindex [lindex $control_factors 5] end] }

    return [list $mrange [expr {$D3*$mrange}] \
                         [expr {$D4*$mrange}] $nsamples]
}

# test-Rchart --
#     Determine if any data points lie outside the R-chart control limits
#
# Arguments:
#     control     List returned by control-xbar with control data
#     data        List of observed values
# Return value:
#     Indices of any subsamples that violate the control limits
#
proc ::math::statistics::test-Rchart { control data } {
    foreach {rmean rlower rupper nsamples} $control {break}

    #
    # Check the number of data
    #
    if { [llength $data] < 1 } {
        return -code error -errorcode DATA -errorinfo $TOOFEWDATA $TOOFEWDATA
    }

    set nogroups [expr {[llength $data]/$nsamples}]

    set result {}
    for { set i 0 } { $i < $nogroups } { incr i } {
        set subsample [lrange $data [expr {$i*$nsamples}] [expr {$i*$nsamples+$nsamples-1}]]

        set xmin  [lindex $subsample 0]
        set xmax  $xmin
        foreach d $subsample {
            set xmin  [expr {$xmin<$d? $xmin : $d}]
            set xmax  [expr {$xmax>$d? $xmax : $d}]
        }
        set range [expr {$xmax-$xmin}]

        if { $range < $rlower } { lappend result $i }
        if { $range > $rupper } { lappend result $i }
    }

    return $result
}

# test-Duckworth --
#     Determine if two data sets have the same median according to the Tukey-Duckworth test
#
# Arguments:
#     list1           Values in the first data set
#     list2           Values in the second data set
#     significance    Significance level (either 0.05, 0.01 or 0.001)
#
# Returns:
#     0 if the medians are unequal, 1 if they are equal, -1 if the test can not
#     be conducted (the smallest value must be in a different set than the greatest value)
#
proc ::math::statistics::test-Duckworth {list1 list2 significance} {
    set sorted1   [lsort -real $list1]
    set sorted2   [lsort -real -decreasing $list2]

    set lowest1   [lindex $sorted1 0]
    set lowest2   [lindex $sorted2 end]
    set greatest1 [lindex $sorted1 end]
    set greatest2 [lindex $sorted2 0]

    if { $lowest1 <= $lowest2 && $greatest1 >= $greatest2 } {
        return -1
    }
    if { $lowest1 >= $lowest2 && $greatest1 <= $greatest2 } {
        return -1
    }

    #
    # Determine how many elements of set 1 are lower than the lowest of set 2
    # Ditto for the number of elements of set 2 greater than the greatest of set 1
    # (Or vice versa)
    #
    if { $lowest1 < $lowest2 } {
        set lowest   $lowest2
        set greatest $greatest1
    } else {
        set lowest   $lowest1
        set greatest $greatest2
        set sorted1   [lsort -real $list2]
        set sorted2   [lsort -real -decreasing $list1]
        #lassign [list $sorted1 $sorted2] sorted2 sorted1
    }

    set count1 0
    set count2 0
    foreach v1 $sorted1 {
        if { $v1 >= $lowest } {
            break
        }
        incr count1
    }
    foreach v2 $sorted2 {
        if { $v2 <= $greatest } {
            break
        }
        incr count2
    }

    #
    # Determine the statistic D, possibly with correction
    #
    set n1 [llength $list1]
    set n2 [llength $list2]

    set correction 0
    if { 3 + 4*$n1/3 <= $n2 && $n2 <= 2*$n1 } {
        set correction -1
    }
    if { 3 + 4*$n2/3 <= $n1 && $n1 <= 2*$n2 } {
        set correction -1
    }

    set D [expr {$count1 + $count2 + $correction}]

    switch -- [string trim $significance 0] {
        ".05" {
             return [expr {$D >= 7? 0 : 1}]
        }
        ".01" {
             return [expr {$D >= 10? 0 : 1}]
        }
        ".001" {
             return [expr {$D >= 13? 0 : 1}]
        }
        default {
             return -code error "Significance level must be 0.05, 0.01 or 0.001"
        }
    }
}


#
# Load the auxiliary scripts
#
source [file join [file dirname [info script]] pdf_stat.tcl]
source [file join [file dirname [info script]] plotstat.tcl]
source [file join [file dirname [info script]] liststat.tcl]
source [file join [file dirname [info script]] mvlinreg.tcl]
source [file join [file dirname [info script]] kruskal.tcl]
source [file join [file dirname [info script]] wilcoxon.tcl]
source [file join [file dirname [info script]] stat_kernel.tcl]

#
# Define the tables
#
namespace eval ::math::statistics {
    variable student_t_table

    #   set student_t_table [::math::interpolation::defineTable student_t
    #          {X        80%    90%    95%    98%    99%}
    #          {X      0.80   0.90   0.95   0.98   0.99
    #           1      3.078  6.314 12.706 31.821 63.657
    #           2      1.886  2.920  4.303  6.965  9.925
    #           3      1.638  2.353  3.182  4.541  5.841
    #           5      1.476  2.015  2.571  3.365  4.032
    #          10      1.372  1.812  2.228  2.764  3.169
    #          15      1.341  1.753  2.131  2.602  2.947
    #          20      1.325  1.725  2.086  2.528  2.845
    #          30      1.310  1.697  2.042  2.457  2.750
    #          60      1.296  1.671  2.000  2.390  2.660
    #         1.0e9    1.282  1.645  1.960  2.326  2.576 }]

    # PM
    #set chi_squared_table [::math::interpolation::defineTable chi_square
    #   ...
}

#
# Simple test code
#
if { [info exists ::argv0] && ([file tail [info script]] == [file tail $::argv0]) } {

    console show
    puts [interp aliases]

    set values {1 1 1 1 {}}
    puts [::math::statistics::basic-stats $values]
    set values {1 2 3 4}
    puts [::math::statistics::basic-stats $values]
    set values {1 -1 1 -2}
    puts [::math::statistics::basic-stats $values]
    puts [::math::statistics::mean   $values]
    puts [::math::statistics::min    $values]
    puts [::math::statistics::max    $values]
    puts [::math::statistics::number $values]
    puts [::math::statistics::stdev  $values]
    puts [::math::statistics::var    $values]

    set novals 100
    #set maxvals 100001
    set maxvals 1001
    while { $novals < $maxvals } {
	set values {}
	for { set i 0 } { $i < $novals } { incr i } {
	    lappend values [expr {rand()}]
	}
	puts [::math::statistics::basic-stats $values]
	puts [::math::statistics::histogram {0.0 0.2 0.4 0.6 0.8 1.0} $values]
	set novals [expr {$novals*10}]
    }

    puts "Normal distribution:"
    puts "X=0:  [::math::statistics::pdf-normal 0.0 1.0 0.0]"
    puts "X=1:  [::math::statistics::pdf-normal 0.0 1.0 1.0]"
    puts "X=-1: [::math::statistics::pdf-normal 0.0 1.0 -1.0]"

    set data1 {0.0 1.0 3.0 4.0 100.0 -23.0}
    set data2 {1.0 2.0 4.0 5.0 101.0 -22.0}
    set data3 {0.0 2.0 6.0 8.0 200.0 -46.0}
    set data4 {2.0 6.0 8.0 200.0 -46.0 1.0}
    set data5 {100.0 99.0 90.0 93.0 5.0 123.0}
    puts "Correlation data1 and data1: [::math::statistics::corr $data1 $data1]"
    puts "Correlation data1 and data2: [::math::statistics::corr $data1 $data2]"
    puts "Correlation data1 and data3: [::math::statistics::corr $data1 $data3]"
    puts "Correlation data1 and data4: [::math::statistics::corr $data1 $data4]"
    puts "Correlation data1 and data5: [::math::statistics::corr $data1 $data5]"

    #   set data {1.0 2.0 2.3 4.0 3.4 1.2 0.6 5.6}
    #   puts [::math::statistics::basicStats $data]
    #   puts [::math::statistics::interval-mean-stdev $data 0.90]
    #   puts [::math::statistics::interval-mean-stdev $data 0.95]
    #   puts [::math::statistics::interval-mean-stdev $data 0.99]

    #   puts "\nTest mean values:"
    #   puts [::math::statistics::test-mean $data 2.0 0.1 0.90]
    #   puts [::math::statistics::test-mean $data 2.0 0.5 0.90]
    #   puts [::math::statistics::test-mean $data 2.0 1.0 0.90]
    #   puts [::math::statistics::test-mean $data 2.0 2.0 0.90]

    set rc [catch {
	set m [::math::statistics::mean {}]
    } msg ] ; # {}
    puts "Result: $rc $msg"

    puts "\nTest quantiles:"
    set data      {1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0}
    set quantiles {0.11 0.21 0.51 0.91 0.99}
    set limits    {2.1 4.1 6.1 8.1}
    puts [::math::statistics::quantiles $data $quantiles]

    set histogram [::math::statistics::histogram $limits $data]
    puts [::math::statistics::quantiles $limits $histogram $quantiles]

    puts "\nTest autocorrelation:"
    set data      {1.0 -1.0 1.0 -1.0 1.0 -1.0 1.0 -1.0 1.0}
    puts [::math::statistics::autocorr $data]
    set data      {1.0 -1.1 2.0 -0.6 3.0 -4.0 0.5 0.9 -1.0}
    puts [::math::statistics::autocorr $data]

    puts "\nTest histogram limits:"
    puts [::math::statistics::mean-histogram-limits   1.0 1.0]
    puts [::math::statistics::mean-histogram-limits   1.0 1.0 4]
    puts [::math::statistics::minmax-histogram-limits 1.0 10.0 10]

}

#
# Test xbar/R-chart procedures
#
if { 0 } {
    set data {}
    for { set i 0 } { $i < 500 } { incr i } {
        lappend data [expr {rand()}]
    }
    set limits [::math::statistics::control-xbar $data]
    puts $limits

    puts "Outliers? [::math::statistics::test-xbar $limits $data]"

    set newdata {1.0 1.0 1.0 1.0 0.5 0.5 0.5 0.5 10.0 10.0 10.0 10.0}
    puts "Outliers? [::math::statistics::test-xbar $limits $newdata] -- 0 2"

    set limits [::math::statistics::control-Rchart $data]
    puts $limits

    puts "Outliers? [::math::statistics::test-Rchart $limits $data]"

    set newdata {0.0 1.0 2.0 1.0 0.4 0.5 0.6 0.5 10.0  0.0 10.0 10.0}
    puts "Outliers? [::math::statistics::test-Rchart $limits $newdata] -- 0 2"
}

