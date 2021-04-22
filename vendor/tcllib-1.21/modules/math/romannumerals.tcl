#==========================================================================
# Roman Numeral Utility Functions
#==========================================================================
# Description
#
#   A set of utility routines for handling and manipulating
#   roman numerals.
#-------------------------------------------------------------------------
# Copyright/License
#
#   This code was originally harvested from the Tcler's
#   wiki at http://wiki.tcl.tk/1823 and as such is free
#   for any use for any purpose.
#-------------------------------------------------------------------------
# Modification history
#
#   27 Sep 2005 Kenneth Green
#       Original version derived from wiki code
#-------------------------------------------------------------------------

package provide math::roman 1.0

#==========================================================================
# Namespace
#==========================================================================
namespace eval ::math::roman {
    namespace export tointeger toroman

    # We dont export 'sort' or 'expr' to prevent collision
    # with existing commands. These functions are less likely to be
    # commonly used and have to be accessed as fully-scoped names.

    # romanvalues - array that maps roman letters to integer values.
    #
    variable romanvalues

    # i2r - list of integer-roman tuples
    variable i2r {1000 M 900 CM 500 D 400 CD 100 C 90 XC 50 L 40 XL 10 X 9 IX 5 V 4 IV 1 I}

    # sortkey - list of patterns to supporting sorting of roman numerals
    variable sortkey {IX VIIII L Y XC YXXXX C Z D {\^} ZM {\^ZZZZ} M _}
    variable rsortkey {_ M {\^ZZZZ} ZM {\^} D Z C YXXXX XC Y L VIIII IX}

    # Initialise array variables
    array set romanvalues {M 1000 D 500 C 100 L 50 X 10 V 5 I 1}
}

#==========================================================================
# Public Functions
#==========================================================================

#----------------------------------------------------------
# Roman numerals sorted
#
proc ::math::roman::sort list {
    variable sortkey
    variable rsortkey

    foreach {from to} $sortkey {
        regsub -all $from $list $to list
    }
    set list [lsort $list]
    foreach {from to} $rsortkey {
        regsub -all $from $list $to list
    }
    return $list
}

#----------------------------------------------------------
# Roman numerals from integer
#
proc ::math::roman::toroman {i} {
    variable i2r

    set res ""
    foreach {value roman} $i2r {
        while {$i>=$value} {
            append res $roman
            incr i -$value
        }
    }
    return $res
}

#----------------------------------------------------------
# Roman numerals parsed into integer:
#
proc ::math::roman::tointeger {s} {
    variable romanvalues

    set last 99999
    set res  0
    foreach i [split [string toupper $s] ""] {
        if { [catch {set val $romanvalues($i)}] } {
            return -code error "roman::tointeger - un-Roman digit $i in $s"
        }
        incr res $val
        if { $val > $last } {
            incr res [::expr -2*$last]
        }
        set last $val
    }
    return $res
}

#----------------------------------------------------------
# Roman numeral arithmetic
#
proc ::math::roman::expr args {

    if { [string first \$ $args] >= 0 } {
        set args [uplevel subst $args]
    }

    regsub -all {[^IVXLCDM]} $args { & } args
    foreach i $args {
        catch {set i [tointeger $i]}
        lappend res $i
    }
    return [toroman [::expr $res]]
}

#==========================================================
# Developer test code
#
if { 0 } {

    puts "Basic int-to-roman-to-int conversion test"
    for { set i 0 } {$i < 50} {incr i} {
        set r [::math::roman::toroman   $i]
        set j [::math::roman::tointeger $r]
        puts [format "%5d   %-15s %s" $i $r $j]
        if { $i != $j } {
            error "Invalid conversion: $i -> $r -> $j"
        }
    }

    puts ""
    puts "roman arithmetic test"
    set x 23
    set xr [::math::roman::toroman $x]
    set y 77
    set yr [::math::roman::toroman $y]
    set xr+yr [::math::roman::expr $xr + $yr]
    set yr-xr [::math::roman::expr $yr - $xr]
    set xr*yr [::math::roman::expr $xr * $yr]
    set yr/xr [::math::roman::expr $yr / $xr]
    set yr/xr2 [::math::roman::expr {$yr / $xr}]
    puts "$x + $y\t\t= [expr $x + $y]"
    puts "$x * $y\t\t= [expr $x * $y]"
    puts "$y - $x\t\t= [expr $y - $x]"
    puts "$y / $x\t\t= [expr $y / $x]"
    puts "$xr + $yr\t= ${xr+yr} = [::math::roman::tointeger ${xr+yr}]"
    puts "$xr * $yr\t= ${xr*yr} = [::math::roman::tointeger ${xr*yr}]"
    puts "$yr - $xr\t= ${yr-xr} = [::math::roman::tointeger ${yr-xr}]"
    puts "$yr / $xr\t= ${yr/xr} = [::math::roman::tointeger ${yr/xr}]"
    puts "$yr / $xr\t= ${yr/xr2} = [::math::roman::tointeger ${yr/xr2}]"

    puts ""
    puts "roman sorting test"
    set l {X III IV I V}
    puts "IN : $l"
    puts "OUT: [::math::roman::sort $l]"
}
