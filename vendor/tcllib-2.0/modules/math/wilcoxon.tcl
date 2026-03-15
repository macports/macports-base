# wilcoxon.tcl --
#     Implementation of the Wilcoxon test: test if the medians
#     of two samples are the same
#
#     Also: Levene's and Brown-Forsythe's test
#

# test-Wilcoxon
#     Compute the statistic that indicates if the medians of two
#     samples are the same
#
# Arguments:
#     sample_a       List of values in the first sample
#     sample_b       List of values in the second sample
#
# Result:
#     Statistic for the test (if both samples have 10 or more
#     values, the statistic behaves as a standard normal variable)
#
proc ::math::statistics::test-Wilcoxon {sample_a sample_b} {

    #
    # Construct the sorted list for both
    #
    set sorted  {}
    set count_a 0
    set count_b 0
    foreach sample {sample_a sample_b} code {0 1} count {count_a count_b} {
        foreach v [set $sample] {
            if { $v ne {} } {
                incr $count
                lappend sorted [list $v $code]
            }
        }
    }

    set raw_sorted [lsort -index 0 -real $sorted]

    #
    # Resolve the ties (TODO)
    # - Make sure the previous value is never equal to the first
    # - Take care of the last part of the sorted samples
    #
    set previous [expr {0.5*[lindex $raw_sorted 0 0] - 1.0}]

    set sorted    $raw_sorted
    set rank      0
    set sum_ranks 0
    set count     0
    set first     0
    set index     0
    foreach v [concat $raw_sorted {{} -1}] {
        set  sum_ranks [expr {$sum_ranks + $rank}]
        incr count
        set  current [lindex $v 0]
        if { $current != $previous } {
            set new_rank [expr {$sum_ranks / $count}]

            if { $index > [llength $raw_sorted] } {
                set index [llength $raw_sorted]
            }

            for {set elem $first} {$elem < $index} {incr elem} {
                lset sorted $elem 0 $new_rank
            }

            set previous  $current
            set first     $index
            set count     0
            set sum_ranks 0
        }

        incr index
        incr rank
    }

    #
    # Sum the ranks for the first sample and determine
    # the statistic
    #
    if { $count_a < 2 || $count_b < 2 } {
        return -code error \
               -errorcode DATA -errorinfo {Too few data in one or both samples}
    }

    set sum  0
    foreach v $sorted {
        if { [lindex $v 1] == 0 } {
            set rank [lindex $v 0]
            set sum  [expr {$sum + $rank}]
        }
    }

    set expected  [expr {$count_a * ($count_a + $count_b + 1)/2.0}]
    set stdev     [expr {sqrt($count_b * $expected/6.0)}]
    set statistic [expr {($sum-$expected)/$stdev}]

    return $statistic
}

# SpearmanRankData --
#     Auxiliary procedure to rank the data
#
# Arguments:
#     sample             Series of data to be ranked
#
# Returns:
#     Ranks of the data
#
proc ::math::statistics::SpearmanRankData {sample} {

    set counted_sample {}
    set count          0
    foreach v $sample {
        if { $v ne {} } {
            incr count
            lappend counted_sample [list $v 0 $count]
        }
    }

    set raw_sorted [lsort -index 0 -real $counted_sample]

    #
    # Resolve the ties (TODO)
    # - Make sure the previous value is never equal to the first
    # - Take care of the last part of the sorted samples
    #
    set previous [expr {0.5*[lindex $raw_sorted 0 0] - 1.0}]

    set sorted    $raw_sorted
    set rank      0
    set sum_ranks 0
    set count     0
    set first     0
    set index     0
    foreach v [concat $raw_sorted {{} -1}] {
        set  sum_ranks [expr {$sum_ranks + $rank}]
        incr count
        set  current [lindex $v 0]
        if { $current != $previous } {
            set new_rank [expr {$sum_ranks / $count}]

            if { $index > [llength $raw_sorted] } {
                set index [llength $raw_sorted]
            }

            for {set elem $first} {$elem < $index} {incr elem} {
                lset sorted $elem 1 $new_rank
            }

            set previous  $current
            set first     $index
            set count     0
            set sum_ranks 0
        }

        incr index
        incr rank
    }

    #
    # Return the ranks of the data in the original order
    #
    set ranks {}
    foreach values [lsort -index 2 -integer $sorted] {
        lappend ranks [lindex $values 1]
    }

    return $ranks
}

# spearman-rank-extended --
#     Compute the Spearman's rank correlation coefficient and
#     associated parameters
#
# Arguments:
#     sample_a       List of values in the first sample
#     sample_b       List of values in the second sample
#
# Result:
#     List of:
#     - Rank correlation coefficient
#     - Number of data
#     - z-score to test the null hyothesis
#
proc ::math::statistics::spearman-rank-extended {sample_a sample_b} {

    #
    # Filter out missing data
    #
    if { [llength $sample_a] != [llength $sample_b] } {
        return -code error \
               -errorcode DATA -errorinfo {The two samples should have the same number of data}
    }

    set new_sample_a {}
    set new_sample_b {}
    foreach a $sample_a b $sample_b {
        if { $a != {} && $b != {} } {
            lappend new_sample_a $a
            lappend new_sample_b $b
        }
    }

    #
    # Construct the ranks
    #
    set rank_a [SpearmanRankData $new_sample_a]
    set rank_b [SpearmanRankData $new_sample_b]

    set rcorr  [corr $rank_a $rank_b]
    set number [llength $new_sample_a]
    set zscore [expr {sqrt(($number-3)/1.06) * 0.5 * log((1.0+$rcorr)/(1.0-$rcorr))}]

    return [list $rcorr $number $zscore]
}

# spearman-rank --
#     Compute the Spearman's rank correlation coefficient
#
# Arguments:
#     sample_a       List of values in the first sample
#     sample_b       List of values in the second sample
#
# Result:
#     Rank correlation coefficient
#
proc ::math::statistics::spearman-rank {sample_a sample_b} {
    return [lindex [spearman-rank-extended $sample_a $sample_b] 0]
}

# test-Levene --
#     Compute the Levene statistic that indicates if the variances of
#     groups of data are the same
#
# Arguments:
#     groups         List of groups of values to be examined
#
# Result:
#     Statistic for the test (an F statistic with k-1, N-k degrees
#     of freedom - k the number of groups and N the total number
#     of values)
#     The test uses the mean of the values in the groups.
#
proc ::math::statistics::test-Levene {groups} {

    return [Test-Levene-Brown-Forsythe 0 $groups]
}

# test-Brown-Forsythe --
#     Compute the Brown-Forsythe statistic that indicates if the variances of
#     groups of data are the same
#
# Arguments:
#     groups         List of groups of values to be examined
#
# Result:
#     Statistic for the test (an F statistic with k-1, N-k degrees
#     of freedom - k the number of groups and N the total number
#     of values)
#     The test uses the median of the values in the groups.
#
proc ::math::statistics::test-Brown-Forsythe {groups} {

    return [Test-Levene-Brown-Forsythe 1 $groups]
}

# Test-Levene-Brown-Forsythe --
#     Compute either the Levene or the Brown-Forsythe statistic that indicates
#     if the variances of groups of data are the same
#
# Arguments:
#     choice         Which of the two versions
#     groups         List of groups of values to be examined
#
# Result:
#     Statistic for the test
#     The test uses either the mean or the median of the values in the groups.
#
proc ::math::statistics::Test-Levene-Brown-Forsythe {choice groups} {

    #
    # Compute the deviations from the mean/median within each group
    #
    set alldevs {}
    set zscores {}
    set zmeans  {}
    foreach group $groups {
        if { $choice } {
            set zm [median $group]
        } else {
            set zm [mean $group]
        }
        set zgroup {}
        foreach element $group {
            lappend zgroup [expr {abs($element-$zm)}]
        }

        set alldevs [concat $alldevs $zgroup]
        lappend zscores $zgroup
        lappend zmeans  [mean $zgroup]
    }

    set zoverall [mean $alldevs]

    set ndata   [llength $alldevs]
    set ngroups [llength $groups]

    #
    # Compute the numerator of the statistic
    #
    set sumsqmeans 0.0

    foreach zm $zmeans group $groups {
        set n          [llength $group]
        set sumsqmeans [expr { $sumsqmeans + $n * ($zm - $zoverall)**2 }]
    }

    #
    # Compute the denominator
    #
    set sumsqpergroup 0.0

    foreach zm $zmeans zs $zscores {
        set sumsq 0.0
        foreach z $zs {
            set sumsq [expr {$sumsq + ($z-$zm)**2}]
        }

        set sumsqpergroup [expr { $sumsqpergroup + $sumsq }]
    }

    #
    # Finally, the statistic
    #

    return [expr { ($ndata-$ngroups) * $sumsqmeans / double( ($ngroups-1) * $sumsqpergroup ) }]
}
