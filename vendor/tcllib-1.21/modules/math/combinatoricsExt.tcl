# combinatoricsExt.tcl --
#     Procedures for combinatorial functions and generating combinatorial collections
#
#     Note:
#     The older procedures factorial and choose assume Tcl 8.0, so no large integer support
#     The versions in this package, permutations and combinations, depend on Tcl 8.6 and later
#     for the large integer support and for TclOO.
#
#     Several parts based on: https://wiki.tcl-lang.org/page/Permutations and other Wiki pages
#
package require Tcl 8.6
package require TclOO
package provide math::combinatorics 2.0

# ::math::combinatorics --
#     Encompassing namespace and auxiliary variables
#
namespace eval ::math::combinatorics {
    variable factorial
    variable partition

    set factorial {1 1 2 6 24 120 720}

    set partition(0) 0
    set partition(1) 1

    namespace export permutations      variations      combinations      derangements      \
                     list-permutations list-variations list-combinations list-derangements \
                     catalan firstStirling secondStirling partitionP \
                     permutationObj combinationObj
}

# permutations --
#     Calculate the number of permutations
#
# Arguments:
#     n           Size of the set
#
# Returns:
#     Number of permutations of the set {0 ... n}
#
proc ::math::combinatorics::permutations {n} {
    variable factorial

    if { $n <= 1 } {
        return 1
    }

    if { $n < [llength $factorial] } {
        return [lindex $factorial $n]
    }

    set newfactorial [lindex $$factorial end]

    for {set k [llength $factorial]} { $k <= $n} {incr k} {
        set newfactorial [expr {$newfactorial * $k}]
        lappend factorial $newfactorial
    }

    return $newfactorial
}

# variations --
#     Calculate the number of variations
#
# Arguments:
#     n           Size of the set
#     k           Number of elements per subset
#
# Returns:
#     Number of variations of the set {0 ... n}
#
proc ::math::combinatorics::variations {n k} {
    if { $k < 0 || $k > $n } {
        return 0
    }

    if { $n <= 1 || $k == 0 } {
        return 1
    }

    set perms1 [permutations $n]
    set perms2 [permutations [expr {$n-$k}]]

    return [expr {$perms1 / $perms2}]
}

# combinations --
#     Calculate the number of combinations
#
# Arguments:
#     n           Size of the set
#     k           Number of elements per subset
#
# Returns:
#     Number of combinations of the set {0 ... n}
#
proc ::math::combinatorics::combinations {n k}  {
    if { $k < 0 || $k > $n } {
        return 0
    }

    if { $n <= 1 || $k == 0 || $k == $n } {
        return 1
    }

    set perms1 [permutations $n]
    set perms2 [permutations $k]
    set perms3 [permutations [expr {$n - $k}]]

    return [expr {$perms1 / $perms2 / $perms3}]
}

# derangements --
#     Calculate the number of derangements
#
# Arguments:
#     n           Size of the set
#
# Returns:
#     Number of permutations of the set {0 ... n} where every
#     element is displaced
#
proc ::math::combinatorics::derangements {n} {
    if { $n <= 1 } {
        return 0
    }

    if { $n == 2 } {
        return 1
    }

    set dim2 0
    set dim1 1

    for {set i 3} {$i <= $n} {incr i} {
        set di [expr {($i-1) * ($dim1 + $dim2)}]
        set dim2 $dim1
        set dim1 $di
    }

    return $di
}

# catalan --
#     Return the n-th Catalan number
#
# Arguments:
#     n           Index for the Catalan number (n >= 1)
#
# Result:
#     The n-th Catalan number
#
proc ::math::combinatorics::catalan {n} {
    if { $n < 0 || $n != int($n) } {
        return -code error "The argument must be a non-negative integer"
    }

    set combin [combinations [expr {2*$n}] $n]

    return [expr {$combin / ($n + 1)}]
}

# firstStirling --
#     Calculate a Stirling number of the first kind
#     (signed version, m cycles in a permutation of n items)
#
# Arguments:
#     n           Number of items
#     m           Number of cycles
#
# Note:
#     The Stirling number returned is a signed number.
#     For efficiency memoization is used.
#
proc ::math::combinatorics::firstStirling {n m} {
    variable stirling

    if { $n == $m } {
        return 1
    }

    if { $n <= 0 || $m < 0 || $n < $m } {
        return 0
    }

    if { [info exists stirling($n,$m)] } {
        return $stirling($n,$m)
    }

    set nm1 [expr {$n-1}]
    set mm1 [expr {$m-1}]

    set Snm1_m   [firstStirling $nm1 $m]
    set Snm1_mm1 [firstStirling $nm1 $mm1]

    set stirling($n,$m) [expr {$Snm1_mm1 - $nm1 * $Snm1_m}]

    return $stirling($n,$m)
}

# secondStirling --
#     Calculate a Stirling number of the second kind
#     (m non-empty subsets from n items)
#
# Arguments:
#     n           Number of items
#     m           Number of subsets
#
# Note:
#     For efficiency memoization is used.
#
proc ::math::combinatorics::secondStirling {n m} {
    variable stirlingSecond

    if { $n == $m || $m == 1 } {
        return 1
    }

    if { $n <= 0 || $m < 0 || $n < $m } {
        return 0
    }

    if { [info exists stirlingSecond($n,$m)] } {
        return $stirlingSecond($n,$m)
    }

    set nm1 [expr {$n-1}]
    set mm1 [expr {$m-1}]

    set Snm1_m   [secondStirling $nm1 $m]
    set Snm1_mm1 [secondStirling $nm1 $mm1]

    set stirlingSecond($n,$m) [expr {$Snm1_mm1 + $m * $Snm1_m}]

    return $stirlingSecond($n,$m)
}


# partitionP --
#     Calculate the partitionP function (wrapper)
#
# Arguments:
#     n             The integer number to be partitioned
#
# Result:
#     Number of partitions
#
proc ::math::combinatorics::partitionP {n} {
    incr n
    return [PartitionP $n]
}

# partitionQ --
#     Calculate the partitionQ function (wrapper) - the number of partitions with distinct values
#     (that is: an acceptable partition of 4 is (3,1) but not (2,2)
#
# Arguments:
#     n             The integer number to be partitioned
#
# Result:
#     Number of partitions
#
proc ::math::combinatorics::partitionQ {n} {
    incr n
    TODO - see https://mathworld.wolfram.com/PartitionFunctionQ.html

    The calculation is not entirely trivial
}

# PartitionP --
#     Calculate the partitionP function - see note
#
# Arguments:
#     n             The integer number to be partitioned
#
# Result:
#     Number of partitions
#
# Note:
#     This code computes partitionP(n-1) rather than partitionP(n),
#     so it should not be called directly.
#
proc ::math::combinatorics::PartitionP {n} {
    variable partition

    if { $n <= 0} {
        return 0
    }

    if { [info exists partition($n)] } {
        return $partition($n)
    }

    set part 0

    for {set k 1} {$k <= $n} {incr k} {
        set partm1 [PartitionP [expr {$n - $k*(3*$k-1)/2}]]
        set partp1 [PartitionP [expr {$n - $k*(3*$k+1)/2}]]
        set part [expr {$part + ($partm1 + $partp1) * (-1)**($k+1)}]
    }

    set partition($n) $part

    return $part
}


# list-permutations --
#     Generate a list of permutations
#
# Arguments:
#     n           Size of the set
#
# Returns:
#     List of all permutations of the set {0 ... n}
#
proc ::math::combinatorics::list-permutations {n} {
    if { $n < 1 } {
        return -error "Size n of the set must be positive"
    }

    if { $n == 1 } {
        return [list 0]
    }

    set listperms [list-permutations [expr {$n-1}]]

    set newlist {}

    set nm1 [expr {$n-1}]
    foreach perm $listperms {
        for {set i 0} {$i < $n} {incr i} {
            set newperm [linsert $perm $i $nm1]
            lappend newlist $newperm
        }
    }

    return $newlist
}


# list-variations --
#     Generate a list of variations (permuted subsets)
#
# Arguments:
#     n           Size of the set
#     k           Number of elements per subset
#
# Returns:
#     List of all permutations of the set {0 ... n}
#
proc ::math::combinatorics::list-variations {n k} {
     set combinations [list-combinations $n $k]

     set variations {}
     foreach c $combinations {
         lappend variations [List-permuted $c $k]
     }

     return [concat {*}$variations]
}


# List-permuted --
#     Generate a list of permutations of given elements
#
# Arguments:
#     list        List of elements
#     size        Number of elements
#
# Returns:
#     List of all permutations of the given set
#
# Note:
#     Intended for private use only
#
#
proc ::math::combinatorics::List-permuted {list size} {
    if { $size == 0 } {
        return [list [list]]
    }
    set retval {}

    for { set i 0 } { $i < [llength $list] } { incr i } {
        set firstElement [lindex $list $i]
        set remainingElements [lreplace $list $i $i]
        foreach subset [List-permuted $remainingElements [expr { $size - 1 }]] {
            lappend retval [linsert $subset 0 $firstElement]
       }
    }
    return $retval
}


# list-derangements --
#     Generate a list of derangements - permutations where
#     all elements are displaced
#
# Arguments:
#     n           Size of the set
#
# Returns:
#     List of all derangements of the set {0 ... n}
#
# Note:
#     A naive implementation did not ork properly, so use
#     brute force instead: filter out the permutations that are
#     also derangements
#
proc ::math::combinatorics::list-derangements {n} {
    set plist [::math::combinatorics::list-permutations $n]
    set dlist {}

    set numbers {}
    for {set i 0} {$i < $n} {incr i} {
        lappend numbers $i
    }

    foreach p $plist {
        set accept 1
        foreach n $numbers e $p {
            if { $n == $e } {
                set accept 0
                break
            }
        }
        if { $accept } {
            lappend dlist $p
        }
    }
    return $dlist
}

# list-combinations-deprecated --
#     Generate a list of combinations - deprecated
#
# Arguments:
#     n           Size of the set
#     k           Number of elements per subset
#
# Returns:
#     List of all combinations of the set {0 ... n}
#
# Note:
#    This implementation is deprecated in cfavour of the Wiki implementation
#
proc ::math::combinatorics::list-combinations-deprecated {n k} {
    if { $n < 1 } {
        return -error "Size n of the set must be positive"
    }
    if { $k < 0 || $k > $n } {
        return -error "Size k of the subsets must be positive and smaller/equal to n"
    }

    if { $n == 1 } {
        if { $k == 0 } {
            return [list]
        } else {
            return [list 0]
        }
    }

    if { $k > 1 } {
        set listperms [list-combinations-deprecated [expr {$n-1}] [expr {$k-1}]]

        set newlist {}

        set nm1 [expr {$n-1}]
        foreach perm $listperms {
           lappend newlist [concat $perm $nm1]
        }
        set newlist [concat $newlist [list-combinations-deprecated [expr {$n-1}] $k]]
    } else {
        set newlist {}
        for {set i 0} {$i < $n} {incr i} {
            lappend newlist [list $i]
        }
    }

    return $newlist
}

# list-combinations --
#     Generate a list of combinations
#
# Arguments:
#     n           Size of the set
#     k           Number of elements per subset
#
# Returns:
#     List of all combinations of the set {0 ... n}
#
# Note:
#      Copied from the WIki - the implementation is three times
#      faster than the deprecated version
#
proc ::math::combinatorics::list-combinations {n k} {
    set myList {}
    for {set i 0} {$i < $n} {incr i} {
        lappend myList $i
    }

    return [List-Combinations2 $myList $k]
}

# List-Combinations2 --
#     Generate a list of combinations of a given list of elements
#
# Arguments:
#     list        List of elements
#     k           Number of elements per subset
#
# Returns:
#     List of all combinations
#
proc ::math::combinatorics::List-Combinations2 {myList size {prefix {}}} {
    #
    # End recursion when size is 0 or equals our list size
    #
    if {$size == 0} {return [list $prefix]}
    if {$size == [llength $myList]} {return [list [concat $prefix $myList]]}

    set first [lindex $myList 0]
    set rest [lrange $myList 1 end]

    #
    # Combine solutions w/ first element and solutions w/o first element
    #
    set ans1 [List-Combinations2 $rest [expr {$size-1}] [concat $prefix $first]]
    set ans2 [List-Combinations2 $rest $size $prefix]
    return [concat $ans1 $ans2]
}

# list-powerset --
#     Generate a list representing the power set of {0 ... n}
#
# Arguments:
#     n           Size of the set
#
# Returns:
#     List of all subsets of the set {0 ... n}
#
proc ::math::combinatorics::list-powerset {n} {
    set ret {{{}}}
    for {set i 1} {$i <= $n} {incr i} {
        lappend ret [list-combinations $n $i]
    }
    return [concat {*}$ret]
}

# permutationObj --
#     Class for generating permutations one by one
#
::oo::class create ::math::combinatorics::permutationObj {
    variable n
    variable k
    variable current
    variable elements

    # constructor --
    #     Generate permutations of the set {0 .. n}
    # Arguments:
    #     n_in           Size of the set
    #
    constructor {n_in} {
        variable n
        variable k
        variable current
        variable start

        if { $n_in < 1 } {
            return -code error "Size of the set must be positive"
        }

        set n $n_in

        set elements {}
        for {set i 0} {$i < $n} {incr i} {
            lappend elements $i
        }

        my reset
    }

    # method: reset --
    #     Restart the object
    #
    # Arguments:
    #     None
    #
    method reset {} {
        variable current
        variable start

        set start   1
        set current {}
        for {set i 0} {$i < $n} {incr i} {
            lappend current $i
        }
    }

    # method: next
    #     Return the next permutation
    #
    method next {} {
        variable current
        variable start

        # Return the first permutation?
        if { $start } {
            set start 0
            return $current
        }

        # Find the smallest subscript j such that we have already visited
        # all permutations beginning with the first j elements.

        set j [expr { [llength $current] - 1 }]
        set ajp1 [lindex $current $j]
        while { $j > 0 } {
            incr j -1
            set aj [lindex $current $j]
            if { [string compare $ajp1 $aj] > 0 } {
                set foundj {}
                break
            }
            set ajp1 $aj
        }
        if { ![info exists foundj] } return

        # Find the smallest element greater than the j'th among the elements
        # following aj. Let its index be l, and interchange aj and al.

        set l [expr { [llength $current] - 1 }]
        while { $aj >= [set al [lindex $current $l]] } {
            incr l -1
        }
        lset current $j $al
        lset current $l $aj

        # Reverse a_j+1 ... an

        set k [expr {$j + 1}]
        set l [expr { [llength $current] - 1 }]
        while { $k < $l } {
            set al [lindex $current $l]
            lset current $l [lindex $current $k]
            lset current $k $al
            incr k
            incr l -1
        }

        return $current
    }

    # method: setElements --
    #     Register a list of elements to be permuted
    #
    # Arguments:
    #     list           List of elements
    #
    method setElements {list} {
        variable n
        variable elements

        if { [llength $list] != $n } {
            return -code error "The number of elements should be $n"
        }
        set elements $list

        # Implicit reset
        my reset
    }

    #
    # method: nextElements
    #     Returns the next permutation of the given elements
    #
    # Arguments:
    #    None
    #
    method nextElements {} {
        variable elements

        set permutation [my next]

        set list {}

        foreach idx $permutation {
            lappend list [lindex $elements $idx]
        }

        return $list
    }
}

# combinationObj --
#     Class for generating combinations (k-subsets) one by one
#
::oo::class create ::math::combinatorics::combinationObj {
    variable n
    variable k
    variable current
    variable elements

    # constructor --
    #     Generate combinations of k elements out of the set {0 .. n}
    # Arguments:
    #     n_in           Size of the set
    #     k_in           Size of the subsets
    #
    constructor {n_in k_in} {
        variable n
        variable k
        variable current

        if { $n_in < 1 || $k_in < 1 || $k_in > $n_in } {
            return -code error "Sizes of the set and subset must be positive, subset may not be larger than the set"
        }

        set n $n_in
        set k $k_in

        set current {}

        set elements {}
        for {set i 0} {$i < $n} {incr i} {
            lappend elements $i
        }
    }

    # method: reset --
    #     Restart the object
    #
    # Arguments:
    #     None
    #
    method reset {} {
        variable current

        set current {}
    }

    #
    # method: next --
    #     Return the next combination
    #
    # Arguments:
    #     None
    #
    method next {} {
        variable n
        variable k
        variable current

        if { [llength $current] == 0 } {
            for {set i 1} {$i <= $k} {incr i} {
                set c($i) $i
            }
        } else {
            for {set i 1; set j 0} {$i <= $k} {incr i; incr j} {
                set c($i) [lindex $current $j]
            }
            set ptr $k
            while {$ptr > 0 && $c($ptr) == $n - $k + $ptr} {
               incr ptr -1
            }
            if {$ptr == 0} {
              return {}
            }
            incr c($ptr)
            for {set i [expr {$ptr + 1}]} {$i <= $k} {incr i} {
               set c($i) [expr $c([expr {$i - 1}]) + 1]
            }
        }
        set cL      [list]
        set current [list]
        for {set i 1} {$i <= $k} {incr i} {
               lappend cL      [expr {$c($i)-1}]
               lappend current $c($i)
        }
        return $cL
    }

    # method: setElements --
    #     Register a list of elements to be permuted and selected
    #
    # Arguments:
    #     list           List of elements
    #
    method setElements {list} {
        variable n
        variable elements

        if { [llength $list] != $n } {
            return -code error "The number of elements should be $n"
        }
        set elements $list

        # Implicit reset
        my reset
    }

    #
    # method: nextElements
    #     Returns next k-subset of the given elements
    #
    # Arguments:
    #    None
    #
    method nextElements {} {
        variable elements

        set combination [my next]

        set list {}

        foreach idx $combination {
            lappend list [lindex $elements $idx]
        }

        return $list
    }
}
