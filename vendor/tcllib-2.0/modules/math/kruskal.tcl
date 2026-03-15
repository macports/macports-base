# kruskal.tcl --
#     Procedures related to ranking and the Kruskal-Wallis test
#

# test-Kruskal-Wallis --
#     Perform a one-way analysis of variance according
#     to Kruskal-Wallis
#
# Arguments:
#     confidence    Confidence level (between 0 and 1)
#     args          Two or more lists of data
#
# Result:
#     0 if the medians of the groups differ, 1 if they
#     are the same (accept the null hypothesis)
#
proc ::math::statistics::test-Kruskal-Wallis {confidence args} {

    foreach {H p} [eval analyse-Kruskal-Wallis $args] {break}

    expr {$p < 1.0 - $confidence}
}

# analyse-Kruskal-Wallis --
#     Perform a one-way analysis of variance according
#     to Kruskal-Wallis and return the details
#
# Arguments:
#     args          Two or more lists of data
#
# Result:
#     Kruskal-Wallis statistic H and the probability p
#     that this value occurs if the
#
proc ::math::statistics::analyse-Kruskal-Wallis {args} {

    set setCount [llength $args]

    #
    # Rank the data with respect to the whole set
    #
    set rankList [eval group-rank $args]

    set length [llength $rankList]

    #
    # Re-establish original sets of values, but using the ranks
    #
    foreach item $rankList {
        lappend rankValues([lindex $item 0]) [lindex $item 2]
    }

    #
    # Now compute H
    #
    set H 0
    for {set i 0} {$i < $setCount} {incr i} {
        set total [expr [join $rankValues($i) +]]
        set count [llength $rankValues($i)]
        set H [expr {$H + pow($total,2)/double($count)}]
    }
    set H [expr {$H*(12.0/($length*($length + 1))) - (3*($length + 1))}]
    incr setCount -1
    set p [expr {1 - [::math::statistics::cdf-chisquare $setCount $H]}]
    return [list $H $p]
}

# group-rank --
#     Rank groups of data with respect to the whole set
#
# Arguments:
#     args          Two or more lists of data
#
# Result:
#     List of ranking data: for each data item, the group-ID,
#     the value and the rank (may be a fraction, in case of ties)
#
proc ::math::statistics::group-rank {args} {

    set index 0
    set rankList [list]
    set setCount [llength $args]
    #
    # Read lists of values
    #
    foreach item $args {
        set values($index) [lindex $args $index]
        #
        # Prepare ranking with rank=0
        #
        foreach value $values($index) {
            lappend rankList [list $index $value 0]
        }
        incr index 1
    }
    #
    # Sort the values
    #
    set rankList [lsort -real -index 1 $rankList]
    #
    # Assign the ranks (disregarding ties)
    #
    set length [llength $rankList]
    for {set i 0} {$i < $length} {incr i} {
        lset rankList $i 2 [expr {$i + 1}]
    }
    #
    # Value of the previous list element
    #
    set prevValue {}

    #
    # List of indices of list elements having the same value (ties)
    #
    set equalIndex [list]

    #
    # Test for ties and re-assign mean ranks for tied values
    #
    for {set i 0} {$i < $length} {incr i} {
        set value [lindex $rankList $i 1]
        if {($value != $prevValue) && ($i > 0) && ([llength $equalIndex] > 0)} {
            #
            # We are still missing the first tied value
            #
            set j [lindex $equalIndex 0]
            incr j -1
            set equalIndex [linsert $equalIndex 0 $j]

            #
            # Re-assign rank as mean rank of tied values
            #
            set firstRank [lindex $rankList [lindex $equalIndex 0] 2]
            set lastRank  [lindex $rankList [lindex $equalIndex end] 2]
            set newRank   [expr {($firstRank+$lastRank)/2.0}]
            foreach j $equalIndex {
                lset rankList $j 2 $newRank
            }

            #
            # Clear list of equal elements
            #
            set equalIndex [list]
        } elseif {$value == $prevValue} {
            #
            # Remember index of equal value element
            #
            lappend equalIndex $i
        }
        set prevValue $value
    }

    return $rankList
}
