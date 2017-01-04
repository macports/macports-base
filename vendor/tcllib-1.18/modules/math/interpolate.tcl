# interpolate.tcl --
#
#    Package for interpolation methods (one- and two-dimensional)
#
# Remarks:
#    None of the methods deal gracefully with missing values
#
# To do:
#    Add B-splines as methods
#    For spatial interpolation in two dimensions also quadrant method?
#    Method for destroying a table
#    Proper documentation
#    Proper test cases
#
# version 0.1: initial implementation, january 2003
# version 0.2: added linear and Lagrange interpolation, straightforward
#              spatial interpolation, april 2004
# version 0.3: added Neville algorithm.
# version 1.0: added cubic splines, september 2004
#
# Copyright (c) 2004 by Arjen Markus. All rights reserved.
# Copyright (c) 2004 by Kevin B. Kenny.  All rights reserved.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: interpolate.tcl,v 1.10 2009/10/22 18:19:52 arjenmarkus Exp $
#
#----------------------------------------------------------------------

package require Tcl 8.4
package require struct::matrix

# ::math::interpolate --
#   Namespace holding the procedures and variables
#

namespace eval ::math::interpolate {
   variable search_radius {}
   variable inv_dist_pow  2

   namespace export interp-1d-table interp-table interp-linear \
                    interp-lagrange
   namespace export neville
}

# defineTable --
#    Define a two-dimensional table of data
#
# Arguments:
#    name     Name of the table to be created
#    cols     Names of the columns (for convenience and for counting)
#    values   List of values to fill the table with (must be sorted
#             w.r.t. first column or first column and first row)
#
# Results:
#    Name of the new command
#
# Side effects:
#    Creates a new command, which is used in subsequent calls
#
proc ::math::interpolate::defineTable { name cols values } {

   set table ::math::interpolate::__$name
   ::struct::matrix $table

   $table add columns [llength $cols]
   $table add row
   $table set row 0 $cols

   set row    1
   set first  0
   set nocols [llength $cols]
   set novals [llength $values]
   while { $first < $novals } {
      set last [expr {$first+$nocols-1}]
      $table add row
      $table set row $row [lrange $values $first $last]

      incr first $nocols
      incr row
   }

   return $table
}

# inter-1d-table --
#    Interpolate in a one-dimensional table
#    (first column is independent variable, all others dependent)
#
# Arguments:
#    table    Name of the table
#    xval     Value of the independent variable
#
# Results:
#    List of interpolated values, including the x-variable
#
proc ::math::interpolate::interp-1d-table { table xval } {

   #
   # Search for the records that enclose the x-value
   #
   set xvalues [lrange [$table get column 0] 2 end]

   foreach {row row2} [FindEnclosingEntries $xval $xvalues] break
   incr row
   incr row2

   set prev_values [$table get row $row]
   set next_values [$table get row $row2]

   set xprev       [lindex $prev_values 0]
   set xnext       [lindex $next_values 0]

   if { $row == $row2 } {
      return [concat $xval [lrange $prev_values 1 end]]
   } else {
      set wprev [expr {($xnext-$xval)/($xnext-$xprev)}]
      set wnext [expr {1.0-$wprev}]
      set results {}
      foreach vprev $prev_values vnext $next_values {
         set vint  [expr {$vprev*$wprev+$vnext*$wnext}]
         lappend results $vint
      }
      return $results
   }
}

# interp-table --
#    Interpolate in a two-dimensional table
#    (first column and first row are independent variables)
#
# Arguments:
#    table    Name of the table
#    xval     Value of the independent row-variable
#    yval     Value of the independent column-variable
#
# Results:
#    Interpolated value
#
# Note:
#    Use bilinear interpolation
#
proc ::math::interpolate::interp-table { table xval yval } {

   #
   # Search for the records that enclose the x-value
   #
   set xvalues [lrange [$table get column 0] 2 end]

   foreach {row row2} [FindEnclosingEntries $xval $xvalues] break
   incr row
   incr row2

   #
   # Search for the columns that enclose the y-value
   #
   set yvalues [lrange [$table get row 1] 1 end]

   foreach {col col2} [FindEnclosingEntries $yval $yvalues] break

   set yvalues [concat "." $yvalues] ;# Prepend a dummy column!

   set prev_values [$table get row $row]
   set next_values [$table get row $row2]

   set x1          [lindex $prev_values 0]
   set x2          [lindex $next_values 0]
   set y1          [lindex $yvalues     $col]
   set y2          [lindex $yvalues     $col2]

   set v11         [lindex $prev_values $col]
   set v12         [lindex $prev_values $col2]
   set v21         [lindex $next_values $col]
   set v22         [lindex $next_values $col2]

   #
   # value = v0 + a*(x-x1) + b*(y-y1) + c*(x-x1)*(y-y1)
   # if x == x1 and y == y1: value = v11
   # if x == x1 and y == y2: value = v12
   # if x == x2 and y == y1: value = v21
   # if x == x2 and y == y2: value = v22
   #
   set a 0.0
   if { $x1 != $x2 } {
      set a [expr {($v21-$v11)/($x2-$x1)}]
   }
   set b 0.0
   if { $y1 != $y2 } {
      set b [expr {($v12-$v11)/($y2-$y1)}]
   }
   set c 0.0
   if { $x1 != $x2 && $y1 != $y2 } {
      set c [expr {($v11+$v22-$v12-$v21)/($x2-$x1)/($y2-$y1)}]
   }

   set result \
   [expr {$v11+$a*($xval-$x1)+$b*($yval-$y1)+$c*($xval-$x1)*($yval-$y1)}]

   return $result
}

# FindEnclosingEntries --
#    Search within a sorted list
#
# Arguments:
#    val      Value to be searched
#    values   List of values to be examined
#
# Results:
#    Returns a list of the previous and next indices
#
proc FindEnclosingEntries { val values } {
   set found 0
   set row2  1
   foreach v $values {
      if { $val <= $v } {
         set row   [expr {$row2-1}]
         set found 1
         break
      }
      incr row2
   }

   #
   # Border cases: extrapolation needed
   #
   if { ! $found } {
      incr row2 -1
      set  row $row2
   }
   if { $row == 0 } {
      set row $row2
   }

   return [list $row $row2]
}

# interp-linear --
#    Use linear interpolation
#
# Arguments:
#    xyvalues   List of x/y values to be interpolated
#    xval       x-value for which a value is sought
#
# Results:
#    Estimated value at $xval
#
# Note:
#    The list xyvalues must be sorted w.r.t. the x-value
#
proc ::math::interpolate::interp-linear { xyvalues xval } {
   #
   # Border cases first
   #
   if { [lindex $xyvalues 0] > $xval } {
      return [lindex $xyvalues 1]
   }
   if { [lindex $xyvalues end-1] < $xval } {
      return [lindex $xyvalues end]
   }

   #
   # The ordinary case
   #
   set idxx -2
   set idxy -1
   foreach { x y } $xyvalues {
      if { $xval < $x } {
         break
      }
      incr idxx 2
      incr idxy 2
   }

   set x2 [lindex $xyvalues $idxx]
   set y2 [lindex $xyvalues $idxy]

   if { $x2 != $x } {
      set yval [expr {$y+($y2-$y)*($xval-$x)/($x2-$x)}]
   } else {
      set yval $y
   }
   return $yval
}

# interp-lagrange --
#    Use the Lagrange interpolation method
#
# Arguments:
#    xyvalues   List of x/y values to be interpolated
#    xval       x-value for which a value is sought
#
# Results:
#    Estimated value at $xval
#
# Note:
#    The list xyvalues must be sorted w.r.t. the x-value
#    Furthermore the Lagrange method is not a very practical
#    method, as potentially the errors are unbounded
#
proc ::math::interpolate::interp-lagrange { xyvalues xval } {
   #
   # Border case: xval equals one of the "nodes"
   #
   foreach { x y } $xyvalues {
      if { $x == $xval } {
         return $y
      }
   }

   #
   # Ordinary case
   #
   set nonodes2 [llength $xyvalues]

   set yval 0.0

   for { set i 0 } { $i < $nonodes2 } { incr i 2 } {
      set idxn 0
      set xn   [lindex $xyvalues $i]
      set yn   [lindex $xyvalues [expr {$i+1}]]

      foreach { x y } $xyvalues {
         if { $idxn != $i } {
            set yn [expr {$yn*($x-$xval)/($x-$xn)}]
         }
         incr idxn 2
      }

      set yval [expr {$yval+$yn}]
   }

   return $yval
}

# interp-spatial --
#    Use a straightforward interpolation method with weights as
#    function of the inverse distance to interpolate in 2D and N-D
#    space
#
# Arguments:
#    xyvalues   List of coordinates and values at these coordinates
#    coord      List of coordinates for which a value is sought
#
# Results:
#    Estimated value(s) at $coord
#
# Note:
#    The list xyvalues is a list of lists:
#    { {x1 y1 z1 {v11 v12 v13 v14}
#      {x2 y2 z2 {v21 v22 v23 v24}
#      ...
#    }
#    The last element of each inner list is either a single number
#    or a list in itself. In the latter case the return value is
#    a list with the same number of elements.
#
#    The method is influenced by the search radius and the
#    power of the inverse distance
#
proc ::math::interpolate::interp-spatial { xyvalues coord } {
   variable search_radius
   variable inv_dist_pow

   set result {}
   foreach v [lindex [lindex $xyvalues 0] end] {
      lappend result 0.0
   }

   set total_weight 0.0

   if { $search_radius != {} } {
      set max_radius2  [expr {$search_radius*$search_radius}]
   } else {
      set max_radius2  {}
   }

   foreach point $xyvalues {
      set dist 0.0
      foreach c [lrange $point 0 end-1] cc $coord {
         set dist [expr {$dist+($c-$cc)*($c-$cc)}]
      }

      #
      # Take care of coincident points
      #
      if { $dist == 0.0 } {
          return [lindex $point end]
      }

      #
      # The general case
      #
      if { $max_radius2 == {} || $dist <= $max_radius2 } {
         if { $inv_dist_pow == 1 } {
            set dist [expr {sqrt($dist)}]
         }
         set total_weight [expr {$total_weight+1.0/$dist}]

         set idx 0
         foreach v [lindex $point end] r $result {
            lset result $idx [expr {$r+$v/$dist}]
            incr idx
         }
      }
   }

   if { $total_weight == 0.0 } {
      set idx 0
      foreach r $result {
         lset result $idx {}
         incr idx
      }
   } else {
      set idx 0
      foreach r $result {
         lset result $idx [expr {$r/$total_weight}]
         incr idx
      }
   }

   return $result
}

# interp-spatial-params --
#    Set the parameters for spatial interpolation
#
# Arguments:
#    max_search   Search radius (if none: use {} or "")
#    power        Power for the inverse distance (1 or 2, defaults to 2)
#
# Results:
#    None
#
proc ::math::interpolate::interp-spatial-params { max_search {power 2} } {
   variable search_radius
   variable inv_dist_pow

   set search_radius $max_search
   if { $power == 1 } {
      set inv_dist_pow 1
   } else {
      set inv_dist_pow 2
   }
}

#----------------------------------------------------------------------
#
# neville --
#
#	Interpolate a function between tabulated points using Neville's
#	algorithm.
#
# Parameters:
#	xtable - Table of abscissae.
#	ytable - Table of ordinates.  Must be a list of the same
#		 length as 'xtable.'
#	x - Abscissa for which the function value is desired.
#
# Results:
#	Returns a two-element list.  The first element is the
#	requested ordinate.  The second element is a rough estimate
#	of the absolute error, that is, the magnitude of the first
#	neglected term of a power series.
#
# Side effects:
#	None.
#
#----------------------------------------------------------------------

proc ::math::interpolate::neville { xtable ytable x } {

    set n [llength $xtable]

    # Initialization.  Set c and d to the ordinates, and set ns to the
    # index of the nearest abscissa. Set y to the zero-order approximation
    # of the nearest ordinate, and dif to the difference between x
    # and the nearest tabulated abscissa.

    set c [list]
    set d [list]
    set i 0
    set ns 0
    set dif [expr { abs( $x - [lindex $xtable 0] ) }]
    set y [lindex $ytable 0]
    foreach xi $xtable yi $ytable {
	set dift [expr { abs ( $x - $xi ) }]
	if { $dift < $dif } {
	    set ns $i
	    set y $yi
	    set dif $dift
	}
	lappend c $yi
	lappend d $yi
	incr i
    }

    # Compute successively higher-degree approximations to the fit
    # function by using the recurrence:
    #   d_m[i] = ( c_{m-1}[i+1] - d{m-1}[i] ) * (x[i+m]-x) /
    #			(x[i] - x[i+m])
    #   c_m[i] = ( c_{m-1}[i+1] - d{m-1}[i] ) * (x[i]-x) /
    #			(x[i] - x[i+m])

    for { set m 1 } { $m < $n } { incr m } {
	for { set i 0 } { $i < $n - $m } { set i $ip1 } {
	    set ip1 [expr { $i + 1 }]
	    set ipm [expr { $i + $m }]
	    set ho [expr { [lindex $xtable $i] - $x }]
	    set hp [expr { [lindex $xtable $ipm] - $x }]
	    set w [expr { [lindex $c $ip1] - [lindex $d $i] }]
	    set q [expr { $w / ( $ho - $hp ) }]
	    lset d $i [expr { $hp * $q }]
	    lset c $i [expr { $ho * $q }]
	}

	# Take the straighest path possible through the tableau of c
	# and d approximations back to the tabulated value
	if { 2 * $ns < $n - $m } {
	    set dy [lindex $c $ns]
	} else {
	    incr ns -1
	    set dy [lindex $d $ns]
	}
	set y [expr { $y + $dy }]
    }

    # Return the approximation and the highest-order correction term.

    return [list $y [expr { abs($dy) }]]
}

# prepare-cubic-splines --
#    Prepare interpolation based on cubic splines
#
# Arguments:
#    xcoord    The x-coordinates
#    ycoord    Y-values for these x-coordinates
# Result:
#    Intermediate parameters describing the spline function,
#    to be used in the second step, interp-cubic-splines.
# Note:
#    Implicitly it is assumed that the function decribed by xcoord
#    and ycoord has a second derivative 0 at the end points.
#    To minimise the work if more than one value is needed, the
#    algorithm is divided in two steps
#    (Derived from the routine SPLINT in Davis and Rabinowitz:
#    Methods for Numerical Integration, AP, 1984)
#
proc ::math::interpolate::prepare-cubic-splines {xcoord ycoord} {

    if { [llength $xcoord] < 3 } {
        return -code error "At least three points are required"
    }
    if { [llength $xcoord] != [llength $ycoord] } {
        return -code error "Equal number of x and y values required"
    }

    set m2 [expr {[llength $xcoord]-1}]

    set s  0.0
    set h  {}
    set c  {}
    for { set i 0 } { $i < $m2 } { incr i } {
        set ip1 [expr {$i+1}]
        set h1  [expr {[lindex $xcoord $ip1]-[lindex $xcoord $i]}]
        lappend h $h1
        if { $h1 <= 0.0 } {
            return -code error "X values must be strictly ascending"
        }
        set r [expr {([lindex $ycoord $ip1]-[lindex $ycoord $i])/$h1}]
        lappend c [expr {$r-$s}]
        set s $r
    }
    set s 0.0
    set r 0.0
    set t {--}
    lset c 0 0.0

    for { set i 1 } { $i < $m2 } { incr i } {
        set ip1 [expr {$i+1}]
        set im1 [expr {$i-1}]
        set y2  [expr {[lindex $c $i]+$r*[lindex $c $im1]}]
        set t1  [expr {2.0*([lindex $xcoord $im1]-[lindex $xcoord $ip1])-$r*$s}]
        set s   [lindex $h $i]
        set r   [expr {$s/$t1}]
        lset c  $i $y2
        lappend t  $t1
    }
    lappend c 0.0

    for { set j 1 } { $j < $m2 } { incr j } {
        set i   [expr {$m2-$j}]
        set ip1 [expr {$i+1}]
        set h1  [lindex $h $i]
        set yp1 [lindex $c $ip1]
        set y1  [lindex $c $i]
        set t1  [lindex $t $i]
        lset c  $i [expr {($h1*$yp1-$y1)/$t1}]
    }

    set b {}
    set d {}
    for { set i 0 } { $i < $m2 } { incr i } {
        set ip1 [expr {$i+1}]
        set s   [lindex $h $i]
        set yp1 [lindex $c $ip1]
        set y1  [lindex $c $i]
        set r   [expr {$yp1-$y1}]
        lappend d [expr {$r/$s}]
        set y1    [expr {3.0*$y1}]
        lset c $i $y1
        lappend b [expr {([lindex $ycoord $ip1]-[lindex $ycoord $i])/$s
                         -($y1+$r)*$s}]
    }

    lappend d 0.0
    lappend b 0.0

    return [list $d $c $b $ycoord $xcoord]
}

# interp-cubic-splines --
#    Interpolate based on cubic splines
#
# Arguments:
#    coeffs    Coefficients resulting from the preparation step
#    x         The x-coordinate for which to estimate the value
# Result:
#    Interpolated value at x
#
proc ::math::interpolate::interp-cubic-splines {coeffs x} {
    foreach {dcoef ccoef bcoef acoef xcoord} $coeffs {break}

    #
    # Check the bounds - no extrapolation
    #
    if { $x < [lindex $xcoord 0] } {error "X value too small"}
    if { $x > [lindex $xcoord end] } {error "X value too large"}

    #
    # Which interval?
    #
    set idx -1
    foreach xv $xcoord {
        if { $xv > $x } {
            break
        }
        incr idx
    }

    set a      [lindex $acoef $idx]
    set b      [lindex $bcoef $idx]
    set c      [lindex $ccoef $idx]
    set d      [lindex $dcoef $idx]
    set dx     [expr {$x-[lindex $xcoord $idx]}]

    return [expr {(($d*$dx+$c)*$dx+$b)*$dx+$a}]
}



#
# Announce our presence
#
package provide math::interpolate 1.1
