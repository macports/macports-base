# fuzzy.tcl --
#
#    Script to define tolerant floating-point comparisons
#    (Tcl-only version)
#
#    version 0.2: improved and extended, march 2002
#    version 0.2.1: fix bug #2933130, january 2010

package provide math::fuzzy 0.2.1

namespace eval ::math::fuzzy {
   variable eps3 2.2e-16

   namespace export teq tne tge tgt tle tlt tfloor tceil tround troundn

# DetermineTolerance
#    Determine the epsilon value
#
# Arguments:
#    None
#
# Result:
#    None
#
# Side effects:
#    Sets variable eps3
#
proc DetermineTolerance { } {
   variable eps3
   set eps 1.0
   while { [expr {1.0+$eps}] != 1.0 } {
      set eps3 [expr 3.0*$eps]
      set eps  [expr 0.5*$eps]
   }
   #set check [expr {1.0+2.0*$eps}]
   #puts "Eps3: $eps3 ($eps) ([expr {1.0-$check}] [expr 1.0-$check]"
}

# Absmax --
#    Return the absolute maximum of two numbers
#
# Arguments:
#    first      First number
#    second     Second number
#
# Result:
#    Maximum of the absolute values
#
proc Absmax { first second } {
   return [expr {abs($first) > abs($second)? abs($first) : abs($second)}]
}

# teq, tne, tge, tgt, tle, tlt --
#    Compare two floating-point numbers and return the logical result
#
# Arguments:
#    first      First number
#    second     Second number
#
# Result:
#    1 if the condition holds, 0 if not.
#
proc teq { first second } {
   variable eps3
   set scale [Absmax $first $second]
   return [expr {abs($first-$second) <= $eps3 * $scale}]
}

proc tne { first second } {
   variable eps3

   return [expr {![teq $first $second]}]
}

proc tgt { first second } {
   variable eps3
   set scale [Absmax $first $second]
   return [expr {($first-$second) > $eps3 * $scale}]
}

proc tle { first second } {
   return [expr {![tgt $first $second]}]
}

proc tlt { first second } {
   expr { [tle $first $second] && [tne $first $second] }
}

proc tge { first second } {
   if { [tgt $first $second] } {
      return 1
   } else {
      return [teq $first $second]
   }
}

# tfloor --
#    Determine the "floor" of a number and return the result
#
# Arguments:
#    number     Number in question
#
# Result:
#    Largest integer number that is tolerantly smaller than the given
#    value
#
proc tfloor { number } {
   variable eps3

   set q      [expr {($number < 0.0)? (1.0-$eps3) : 1.0 }]
   set rmax   [expr {$q / (2.0 - $eps3)}]
   set eps5   [expr {$eps3/$q}]
   set vmin1  [expr {$eps5*abs(1.0+floor($number))}]
   set vmin2  [expr {($rmax < $vmin1)? $rmax : $vmin1}]
   set vmax   [expr {($eps3 > $vmin2)? $eps3 : $vmin2}]
   set result [expr {floor($number+$vmax)}]
   if { $number <= 0.0 || ($result-$number) < $rmax } {
      return $result
   } else {
      return [expr {$result-1.0}]
   }
}

# tceil --
#    Determine the "ceil" of a number and return the result
#
# Arguments:
#    number     Number in question
#
# Result:
#    Smallest integer number that is tolerantly greater than the given
#    value
#
proc tceil { number } {
   expr {-[tfloor [expr {-$number}]]}
}

# tround --
#    Round off a number and return the result
#
# Arguments:
#    number     Number in question
#
# Result:
#    Nearest integer number
#
proc tround { number } {
   tfloor [expr {$number+0.5}]
}

# troundn --
#    Round off a number to a given precision and return the result
#
# Arguments:
#    number     Number in question
#    ndec       Number of decimals to keep
#
# Result:
#    Nearest number with given precision
#
proc troundn { number ndec } {
   set scale   [expr {pow(10.0,$ndec)}]
   set rounded [tfloor [expr {$number*$scale+0.5}]]
   expr {$rounded/$scale}
}

#
# Determine the tolerance once and for all
#
DetermineTolerance
rename DetermineTolerance {}

} ;# End of namespace
