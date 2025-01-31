# liststat.tcl --
#
#    Set of operations on lists, meant for the statistics package
#
# version 0.1: initial implementation, january 2003

namespace eval ::math::statistics {}

# filter --
#    Filter a list based on whether an expression is true for
#    an element or not
#
# Arguments:
#    varname        Name of the variable that represents the data in the
#                   expression
#    data           List to be filtered
#    expression     (Logical) expression that is to be evaluated
#
# Result:
#    List of those elements for which the expression is true
# TODO:
#    Substitute local variables in caller
#
proc ::math::statistics::filter { varname data expression } {
   upvar $varname _x_
   set result {}
   set _x_ \$_x_
   set expression [uplevel subst -nocommands [list $expression]]
   foreach _x_ $data {
      # FRINK: nocheck
      if $expression {

         lappend result $_x_
      }
   }
   return $result
}

# map --
#    Map the elements of a list according to an expression
#
# Arguments:
#    varname        Name of the variable that represents the data in the
#                   expression
#    data           List whose elements must be transformed (mapped)
#    expression     Expression that is evaluated with $varname an
#                   element in the list
#
# Result:
#    List of transformed elements
#
proc ::math::statistics::map { varname data expression } {
   upvar $varname _x_
   set result {}
   set _x_ \$_x_
   set expression [uplevel subst -nocommands [list $expression]]
   foreach _x_ $data {
      # FRINK: nocheck
      lappend result [expr $expression]
   }
   return $result
}

# samplescount --
#    Count the elements in each sublist and return a list of counts
#
# Arguments:
#    varname        Name of the variable that represents the data in the
#                   expression
#    list           List of lists
#    expression     Expression in that is evaluated with $varname an
#                   element in the sublist (defaults to "true")
#
# Result:
#    List of transformed elements
#
proc ::math::statistics::samplescount { varname list {expression 1} } {
   upvar $varname _x_
   set result {}
   set _x_ \$_x_
   set expression [uplevel subst -nocommands [list $expression]]
   foreach data $list {
      set number 0
      foreach _x_ $data {
         # FRINK: nocheck
         if $expression {
            incr number
         }
      }
      lappend result $number
   }
   return $result
}

# End of list procedures
