# calculus.tcl --
#    Package that implements several basic numerical methods, such
#    as the integration of a one-dimensional function and the
#    solution of a system of first-order differential equations.
#
# Copyright (c) 2002, 2003, 2004, 2006 by Arjen Markus.
# Copyright (c) 2004 by Kevin B. Kenny.  All rights reserved.
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: calculus.tcl,v 1.15 2008/10/08 03:30:48 andreas_kupries Exp $

package require Tcl 8.5;# lrepeat
package require math::interpolate
package provide math::calculus 0.8.2

# math::calculus --
#    Namespace for the commands

namespace eval ::math::calculus {

    namespace import ::math::interpolate::neville

    namespace import ::math::expectDouble ::math::expectInteger

    namespace export \
	integral integralExpr integral2D integral3D \
	qk15 qk15_detailed \
	eulerStep heunStep rungeKuttaStep           \
	boundaryValueSecondOrder solveTriDiagonal   \
	newtonRaphson newtonRaphsonParameters
    namespace export \
        integral2D_2accurate integral3D_accurate

    namespace export romberg romberg_infinity
    namespace export romberg_sqrtSingLower romberg_sqrtSingUpper
    namespace export romberg_powerLawLower romberg_powerLawUpper
    namespace export romberg_expLower romberg_expUpper

    namespace export regula_falsi

    variable nr_maxiter    20
    variable nr_tolerance   0.001

}

# integral --
#    Integrate a function over a given interval using the Simpson rule
#
# Arguments:
#    begin       Start of the interval
#    end         End of the interval
#    nosteps     Number of steps in which to divide the interval
#    func        Name of the function to be integrated (takes one
#                argument)
# Return value:
#    Computed integral
#
proc ::math::calculus::integral { begin end nosteps func } {

   set delta    [expr {($end-$begin)/double($nosteps)}]
   set hdelta   [expr {$delta/2.0}]
   set result   0.0
   set xval     $begin
   set func_end [uplevel 1 $func $xval]
   for { set i 1 } { $i <= $nosteps } { incr i } {
      set func_begin  $func_end
      set func_middle [uplevel 1 $func [expr {$xval+$hdelta}]]
      set func_end    [uplevel 1 $func [expr {$xval+$delta}]]
      set result      [expr  {$result+$func_begin+4.0*$func_middle+$func_end}]

      set xval        [expr {$begin+double($i)*$delta}]
   }

   return [expr {$result*$delta/6.0}]
}

# integralExpr --
#    Integrate an expression with "x" as the integrate according to the
#    Simpson rule
#
# Arguments:
#    begin       Start of the interval
#    end         End of the interval
#    nosteps     Number of steps in which to divide the interval
#    expression  Expression with "x" as the integrate
# Return value:
#    Computed integral
#
proc ::math::calculus::integralExpr { begin end nosteps expression } {

   set delta    [expr {($end-$begin)/double($nosteps)}]
   set hdelta   [expr {$delta/2.0}]
   set result   0.0
   set x        $begin
   # FRINK: nocheck
   set func_end [expr $expression]
   for { set i 1 } { $i <= $nosteps } { incr i } {
      set func_begin  $func_end
      set x           [expr {$x+$hdelta}]
       # FRINK: nocheck
      set func_middle [expr $expression]
      set x           [expr {$x+$hdelta}]
       # FRINK: nocheck
      set func_end    [expr $expression]
      set result      [expr {$result+$func_begin+4.0*$func_middle+$func_end}]

      set x           [expr {$begin+double($i)*$delta}]
   }

   return [expr {$result*$delta/6.0}]
}

# integral2D --
#    Integrate a given fucntion of two variables over a block,
#    using bilinear interpolation (for this moment: block function)
#
# Arguments:
#    xinterval   Start, stop and number of steps of the "x" interval
#    yinterval   Start, stop and number of steps of the "y" interval
#    func        Function of the two variables to be integrated
# Return value:
#    Computed integral
#
proc ::math::calculus::integral2D { xinterval yinterval func } {

   foreach { xbegin xend xnumber } $xinterval { break }
   foreach { ybegin yend ynumber } $yinterval { break }

   set xdelta    [expr {($xend-$xbegin)/double($xnumber)}]
   set ydelta    [expr {($yend-$ybegin)/double($ynumber)}]
   set hxdelta   [expr {$xdelta/2.0}]
   set hydelta   [expr {$ydelta/2.0}]
   set result   0.0
   set dxdy      [expr {$xdelta*$ydelta}]
   for { set j 0 } { $j < $ynumber } { incr j } {
      set y [expr {$ybegin+$hydelta+double($j)*$ydelta}]
      for { set i 0 } { $i < $xnumber } { incr i } {
         set x           [expr {$xbegin+$hxdelta+double($i)*$xdelta}]
         set func_value  [uplevel 1 $func $x $y]
         set result      [expr {$result+$func_value}]
      }
   }

   return [expr {$result*$dxdy}]
}

# integral3D --
#    Integrate a given fucntion of two variables over a block,
#    using trilinear interpolation (for this moment: block function)
#
# Arguments:
#    xinterval   Start, stop and number of steps of the "x" interval
#    yinterval   Start, stop and number of steps of the "y" interval
#    zinterval   Start, stop and number of steps of the "z" interval
#    func        Function of the three variables to be integrated
# Return value:
#    Computed integral
#
proc ::math::calculus::integral3D { xinterval yinterval zinterval func } {

   foreach { xbegin xend xnumber } $xinterval { break }
   foreach { ybegin yend ynumber } $yinterval { break }
   foreach { zbegin zend znumber } $zinterval { break }

   set xdelta    [expr {($xend-$xbegin)/double($xnumber)}]
   set ydelta    [expr {($yend-$ybegin)/double($ynumber)}]
   set zdelta    [expr {($zend-$zbegin)/double($znumber)}]
   set hxdelta   [expr {$xdelta/2.0}]
   set hydelta   [expr {$ydelta/2.0}]
   set hzdelta   [expr {$zdelta/2.0}]
   set result   0.0
   set dxdydz    [expr {$xdelta*$ydelta*$zdelta}]
   for { set k 0 } { $k < $znumber } { incr k } {
      set z [expr {$zbegin+$hzdelta+double($k)*$zdelta}]
      for { set j 0 } { $j < $ynumber } { incr j } {
         set y [expr {$ybegin+$hydelta+double($j)*$ydelta}]
         for { set i 0 } { $i < $xnumber } { incr i } {
            set x           [expr {$xbegin+$hxdelta+double($i)*$xdelta}]
            set func_value  [uplevel 1 $func $x $y $z]
            set result      [expr {$result+$func_value}]
         }
      }
   }

   return [expr {$result*$dxdydz}]
}

# integral2D_accurate --
#    Integrate a given function of two variables over a block,
#    using a four-point quadrature formula
#
# Arguments:
#    xinterval   Start, stop and number of steps of the "x" interval
#    yinterval   Start, stop and number of steps of the "y" interval
#    func        Function of the two variables to be integrated
# Return value:
#    Computed integral
#
proc ::math::calculus::integral2D_accurate { xinterval yinterval func } {

    foreach { xbegin xend xnumber } $xinterval { break }
    foreach { ybegin yend ynumber } $yinterval { break }

    set alpha     [expr {sqrt(2.0/3.0)}]
    set minalpha  [expr {-$alpha}]
    set dpoints   [list $alpha 0.0 $minalpha 0.0 0.0 $alpha 0.0 $minalpha]

    set xdelta    [expr {($xend-$xbegin)/double($xnumber)}]
    set ydelta    [expr {($yend-$ybegin)/double($ynumber)}]
    set hxdelta   [expr {$xdelta/2.0}]
    set hydelta   [expr {$ydelta/2.0}]
    set result   0.0
    set dxdy      [expr {0.25*$xdelta*$ydelta}]

    for { set j 0 } { $j < $ynumber } { incr j } {
        set y [expr {$ybegin+$hydelta+double($j)*$ydelta}]
        for { set i 0 } { $i < $xnumber } { incr i } {
            set x [expr {$xbegin+$hxdelta+double($i)*$xdelta}]

            foreach {dx dy} $dpoints {
                set x1          [expr {$x+$dx}]
                set y1          [expr {$y+$dy}]
                set func_value  [uplevel 1 $func $x1 $y1]
                set result      [expr {$result+$func_value}]
            }
        }
    }

    return [expr {$result*$dxdy}]
}

# integral3D_accurate --
#    Integrate a given function of three variables over a block,
#    using an 8-point quadrature formula
#
# Arguments:
#    xinterval   Start, stop and number of steps of the "x" interval
#    yinterval   Start, stop and number of steps of the "y" interval
#    zinterval   Start, stop and number of steps of the "z" interval
#    func        Function of the three variables to be integrated
# Return value:
#    Computed integral
#
proc ::math::calculus::integral3D_accurate { xinterval yinterval zinterval func } {

    foreach { xbegin xend xnumber } $xinterval { break }
    foreach { ybegin yend ynumber } $yinterval { break }
    foreach { zbegin zend znumber } $zinterval { break }

    set alpha     [expr {sqrt(1.0/3.0)}]
    set minalpha  [expr {-$alpha}]

    set dpoints   [list $alpha    $alpha    $alpha    \
                        $alpha    $alpha    $minalpha \
                        $alpha    $minalpha $alpha    \
                        $alpha    $minalpha $minalpha \
                        $minalpha $alpha    $alpha    \
                        $minalpha $alpha    $minalpha \
                        $minalpha $minalpha $alpha    \
                        $minalpha $minalpha $minalpha ]

    set xdelta    [expr {($xend-$xbegin)/double($xnumber)}]
    set ydelta    [expr {($yend-$ybegin)/double($ynumber)}]
    set zdelta    [expr {($zend-$zbegin)/double($znumber)}]
    set hxdelta   [expr {$xdelta/2.0}]
    set hydelta   [expr {$ydelta/2.0}]
    set hzdelta   [expr {$zdelta/2.0}]
    set result    0.0
    set dxdydz    [expr {0.125*$xdelta*$ydelta*$zdelta}]

    for { set k 0 } { $k < $znumber } { incr k } {
        set z [expr {$zbegin+$hzdelta+double($k)*$zdelta}]
        for { set j 0 } { $j < $ynumber } { incr j } {
            set y [expr {$ybegin+$hydelta+double($j)*$ydelta}]
            for { set i 0 } { $i < $xnumber } { incr i } {
                set x [expr {$xbegin+$hxdelta+double($i)*$xdelta}]

                foreach {dx dy dz} $dpoints {
                    set x1 [expr {$x+$dx}]
                    set y1 [expr {$y+$dy}]
                    set z1 [expr {$z+$dz}]
                    set func_value  [uplevel 1 $func $x1 $y1 $z1]
                    set result      [expr {$result+$func_value}]
                }
            }
        }
    }

    return [expr {$result*$dxdydz}]
}

# eulerStep --
#    Integrate a system of ordinary differential equations of the type
#    x' = f(x,t), where x is a vector of quantities. Integration is
#    done over a single step according to Euler's method.
#
# Arguments:
#    t           Start value of independent variable (time for instance)
#    tstep       Step size of interval
#    xvec        Vector of dependent values at the start
#    func        Function taking the arguments t and xvec to return
#                the derivative of each dependent variable.
# Return value:
#    List of values at the end of the step
#
proc ::math::calculus::eulerStep { t tstep xvec func } {

   set xderiv   [uplevel 1 $func $t [list $xvec]]
   set result   {}
   foreach xv $xvec dx $xderiv {
      set xnew [expr {$xv+$tstep*$dx}]
      lappend result $xnew
   }

   return $result
}

# heunStep --
#    Integrate a system of ordinary differential equations of the type
#    x' = f(x,t), where x is a vector of quantities. Integration is
#    done over a single step according to Heun's method.
#
# Arguments:
#    t           Start value of independent variable (time for instance)
#    tstep       Step size of interval
#    xvec        Vector of dependent values at the start
#    func        Function taking the arguments t and xvec to return
#                the derivative of each dependent variable.
# Return value:
#    List of values at the end of the step
#
proc ::math::calculus::heunStep { t tstep xvec func } {

   #
   # Predictor step
   #
   set funcq    [uplevel 1 namespace which -command $func]
   set xpred    [eulerStep $t $tstep $xvec $funcq]

   #
   # Corrector step
   #
   set tcorr    [expr {$t+$tstep}]
   set xcorr    [eulerStep $tcorr $tstep $xpred $funcq]

   set result   {}
   foreach xv $xvec xc $xcorr {
      set xnew [expr {0.5*($xv+$xc)}]
      lappend result $xnew
   }

   return $result
}

# rungeKuttaStep --
#    Integrate a system of ordinary differential equations of the type
#    x' = f(x,t), where x is a vector of quantities. Integration is
#    done over a single step according to Runge-Kutta 4th order.
#
# Arguments:
#    t           Start value of independent variable (time for instance)
#    tstep       Step size of interval
#    xvec        Vector of dependent values at the start
#    func        Function taking the arguments t and xvec to return
#                the derivative of each dependent variable.
# Return value:
#    List of values at the end of the step
#
proc ::math::calculus::rungeKuttaStep { t tstep xvec func } {

   set funcq    [uplevel 1 namespace which -command $func]

   #
   # Four steps:
   # - k1 = tstep*func(t,x0)
   # - k2 = tstep*func(t+0.5*tstep,x0+0.5*k1)
   # - k3 = tstep*func(t+0.5*tstep,x0+0.5*k2)
   # - k4 = tstep*func(t+    tstep,x0+    k3)
   # - x1 = x0 + (k1+2*k2+2*k3+k4)/6
   #
   set tstep2   [expr {$tstep/2.0}]
   set tstep6   [expr {$tstep/6.0}]

   set xk1      [$funcq $t $xvec]
   set xvec2    {}
   foreach x1 $xvec xv $xk1 {
      lappend xvec2 [expr {$x1+$tstep2*$xv}]
   }
   set xk2      [$funcq [expr {$t+$tstep2}] $xvec2]

   set xvec3    {}
   foreach x1 $xvec xv $xk2 {
      lappend xvec3 [expr {$x1+$tstep2*$xv}]
   }
   set xk3      [$funcq [expr {$t+$tstep2}] $xvec3]

   set xvec4    {}
   foreach x1 $xvec xv $xk3 {
      lappend xvec4 [expr {$x1+$tstep*$xv}]
   }
   set xk4      [$funcq [expr {$t+$tstep}] $xvec4]

   set result   {}
   foreach x0 $xvec k1 $xk1 k2 $xk2 k3 $xk3 k4 $xk4 {
      set dx [expr {$k1+2.0*$k2+2.0*$k3+$k4}]
      lappend result [expr {$x0+$dx*$tstep6}]
   }

   return $result
}

# boundaryValueSecondOrder --
#    Integrate a second-order differential equation and solve for
#    given boundary values.
#
#    The equation is (see the documentation):
#       d       dy   d
#       -- A(x) -- + -- B(x) y + C(x) y = D(x)
#       dx      dx   dx
#
#    The procedure uses finite differences and tridiagonal matrices to
#    solve the equation. The boundary values are put in the matrix
#    directly.
#
# Arguments:
#    coeff_func  Name of triple-valued function for coefficients A, B, C
#    force_func  Name of the function providing the force term D(x)
#    leftbnd     Left boundary condition (list of: xvalue, boundary
#                value or keyword zero-flux, zero-derivative)
#    rightbnd    Right boundary condition (ditto)
#    nostep      Number of steps
# Return value:
#    List of x-values and calculated values (x1, y1, x2, y2, ...)
#
proc ::math::calculus::boundaryValueSecondOrder {
   coeff_func force_func leftbnd rightbnd nostep } {

   set coeffq    [uplevel 1 namespace which -command $coeff_func]
   set forceq    [uplevel 1 namespace which -command $force_func]

   if { [llength $leftbnd] != 2 || [llength $rightbnd] != 2 } {
      error "Boundary condition(s) incorrect"
   }
   if { $nostep < 1 } {
      error "Number of steps must be larger/equal 1"
   }

   #
   # Set up the matrix, as three different lists and the
   # righthand side as the fourth
   #
   set xleft  [lindex $leftbnd 0]
   set xright [lindex $rightbnd 0]
   set xstep  [expr {($xright-$xleft)/double($nostep)}]

   set acoeff {}
   set bcoeff {}
   set ccoeff {}
   set dvalue {}

   set x $xleft
   foreach {A B C} [$coeffq $x] { break }

   set A1 [expr {$A/$xstep-0.5*$B}]
   set B1 [expr {$A/$xstep+0.5*$B+0.5*$C*$xstep}]
   set C1 0.0

   for { set i 1 } { $i <= $nostep } { incr i } {
      set x [expr {$xleft+double($i)*$xstep}]
      if { [expr {abs($x)-0.5*abs($xstep)}] < 0.0 } {
         set x 0.0
      }
      foreach {A B C} [$coeffq $x] { break }

      set A2 0.0
      set B2 [expr {$A/$xstep-0.5*$B+0.5*$C*$xstep}]
      set C2 [expr {$A/$xstep+0.5*$B}]
      lappend acoeff [expr {$A1+$A2}]
      lappend bcoeff [expr {-$B1-$B2}]
      lappend ccoeff [expr {$C1+$C2}]
      set A1 [expr {$A/$xstep-0.5*$B}]
      set B1 [expr {$A/$xstep+0.5*$B+0.5*$C*$xstep}]
      set C1 0.0
   }
   set xvec {}
   for { set i 0 } { $i < $nostep } { incr i } {
      set x [expr {$xleft+(0.5+double($i))*$xstep}]
      if { [expr {abs($x)-0.25*abs($xstep)}] < 0.0 } {
         set x 0.0
      }
      lappend xvec   $x
      lappend dvalue [expr {$xstep*[$forceq $x]}]
   }

   #
   # Substitute the boundary values
   #
   set A  [lindex $acoeff 0]
   set D  [lindex $dvalue 0]
   set D1 [expr {$D-$A*[lindex $leftbnd 1]}]
   set C  [lindex $ccoeff end]
   set D  [lindex $dvalue end]
   set D2 [expr {$D-$C*[lindex $rightbnd 1]}]
   set dvalue [concat $D1 [lrange $dvalue 1 end-1] $D2]

   set yvec [solveTriDiagonal [lrange $acoeff 1 end] $bcoeff [lrange $ccoeff 0 end-1] $dvalue]

   foreach x $xvec y $yvec {
      lappend result $x $y
   }
   return $result
}

# solveTriDiagonal --
#    Solve a system of equations Ax = b where A is a tridiagonal matrix
#
# Arguments:
#    acoeff      Values on lower diagonal
#    bcoeff      Values on main diagonal
#    ccoeff      Values on upper diagonal
#    dvalue      Values on righthand side
# Return value:
#    List of values forming the solution
#
proc ::math::calculus::solveTriDiagonal { acoeff bcoeff ccoeff dvalue } {

   set nostep [llength $acoeff]
   #
   # First step: Gauss-elimination
   #
   set B [lindex $bcoeff 0]
   set C [lindex $ccoeff 0]
   set D [lindex $dvalue 0]
   set acoeff  [concat 0.0 $acoeff]
   set bcoeff2 [list $B]
   set dvalue2 [list $D]
   for { set i 1 } { $i <= $nostep } { incr i } {
      set A2    [lindex $acoeff $i]
      set B2    [lindex $bcoeff $i]
      set D2    [lindex $dvalue $i]
      set ratab [expr {$A2/double($B)}]
      set B2    [expr {$B2-$ratab*$C}]
      set D2    [expr {$D2-$ratab*$D}]
      lappend bcoeff2 $B2
      lappend dvalue2 $D2
      set B     $B2
      set C     [lindex $ccoeff $i]
      set D     $D2
   }

   #
   # Second step: substitution
   #
   set yvec {}
   set B [lindex $bcoeff2 end]
   set D [lindex $dvalue2 end]
   set y [expr {$D/$B}]
   for { set i [expr {$nostep-1}] } { $i >= 0 } { incr i -1 } {
      set yvec  [concat $y $yvec]
      set B     [lindex $bcoeff2 $i]
      set C     [lindex $ccoeff  $i]
      set D     [lindex $dvalue2 $i]
      set y     [expr {($D-$C*$y)/$B}]
   }
   set yvec [concat $y $yvec]

   return $yvec
}

# newtonRaphson --
#    Determine the root of an equation via the Newton-Raphson method
#
# Arguments:
#    func        Function (proc) in x
#    deriv       Derivative (proc) of func w.r.t. x
#    initval     Initial value for x
# Return value:
#    Estimate of root
#
proc ::math::calculus::newtonRaphson { func deriv initval } {
   variable nr_maxiter
   variable nr_tolerance

   set funcq  [uplevel 1 namespace which -command $func]
   set derivq [uplevel 1 namespace which -command $deriv]

   set value $initval
   set diff  [expr {10.0*$nr_tolerance}]

   for { set i 0 } { $i < $nr_maxiter } { incr i } {
      if { $diff < $nr_tolerance } {
         break
      }

      set newval [expr {$value-[$funcq $value]/[$derivq $value]}]
      if { $value != 0.0 } {
         set diff   [expr {abs($newval-$value)/abs($value)}]
      } else {
         set diff   [expr {abs($newval-$value)}]
      }
      set value $newval
   }

   return $newval
}

# newtonRaphsonParameters --
#    Set the parameters for the Newton-Raphson method
#
# Arguments:
#    maxiter     Maximum number of iterations
#    tolerance   Relative precisiion of the result
# Return value:
#    None
#
proc ::math::calculus::newtonRaphsonParameters { maxiter tolerance } {
   variable nr_maxiter
   variable nr_tolerance

   if { $maxiter > 0 } {
      set nr_maxiter $maxiter
   }
   if { $tolerance > 0 } {
      set nr_tolerance $tolerance
   }
}

#----------------------------------------------------------------------
#
# midpoint --
#
#	Perform one set of steps in evaluating an integral using the
#	midpoint method.
#
# Usage:
#	midpoint f a b s ?n?
#
# Parameters:
#	f - function to integrate
#	a - One limit of integration
#	b - Other limit of integration.  a and b need not be in ascending
#	    order.
#	s - Value returned from a previous call to midpoint (see below)
#	n - Step number (see below)
#
# Results:
#	Returns an estimate of the integral obtained by dividing the
#	interval into 3**n equal intervals and using the midpoint rule.
#
# Side effects:
#	f is evaluated 2*3**(n-1) times and may have side effects.
#
# The 'midpoint' procedure is designed for successive approximations.
# It should be called initially with n==0.  On this initial call, s
# is ignored.  The function is evaluated at the midpoint of the interval, and
# the value is multiplied by the width of the interval to give the
# coarsest possible estimate of the integral.
#
# On each iteration except the first, n should be incremented by one,
# and the previous value returned from [midpoint] should be supplied
# as 's'.  The function will be evaluated at additional points
# to give a total of 3**n equally spaced points, and the estimate
# of the integral will be updated and returned
#
# Under normal circumstances, user code will not call this function
# directly. Instead, it will use ::math::calculus::romberg to
# do error control and extrapolation to a zero step size.
#
#----------------------------------------------------------------------

proc ::math::calculus::midpoint { f a b { n 0 } { s 0. } } {

    if { $n == 0 } {

	# First iteration.  Simply evaluate the function at the midpoint
	# of the interval.

	set cmd $f; lappend cmd [expr { 0.5 * ( $a + $b ) }]; set v [eval $cmd]
	return [expr { ( $b - $a ) * $v }]

    } else {

	# Subsequent iterations. We've divided the interval into
	# $it subintervals.  Evaluate the function at the 1/3 and
	# 2/3 points of each subinterval.  Then update the estimate
	# of the integral that we produced on the last step with
	# the new sum.

	set it [expr { pow( 3, $n-1 ) }]
	set h [expr { ( $b - $a ) / ( 3. * $it ) }]
	set h2 [expr { $h + $h }]
	set x [expr { $a + 0.5 * $h }]
	set sum 0
	for { set j 0 } { $j < $it } { incr j } {
	    set cmd $f; lappend cmd $x; set y [eval $cmd]
	    set sum [expr { $sum + $y }]
	    set x [expr { $x + $h2 }]
	    set cmd $f; lappend cmd $x; set y [eval $cmd]
	    set sum [expr { $sum + $y }]
	    set x [expr { $x + $h}]
	}
	return [expr { ( $s + ( $b - $a ) * $sum / $it ) / 3. }]

    }
}

#----------------------------------------------------------------------
#
# romberg --
#
#	Compute the integral of a function over an interval using
#	Romberg's method.
#
# Usage:
#	romberg f a b ?-option value?...
#
# Parameters:
#	f - Function to integrate.  Must be a single Tcl command,
#	    to which will be appended the abscissa at which the function
#	    should be evaluated.  f should be analytic over the
#	    region of integration, but may have a removable singularity
#	    at either endpoint.
#	a - One bound of the interval
#	b - The other bound of the interval.  a and b need not be in
#	    ascending order.
#
# Options:
#	-abserror ABSERROR
#		Requests that the integration be performed to make
#		the estimated absolute error of the integral less than
#		the given value.  Default is 1.e-10.
#	-relerror RELERROR
#		Requests that the integration be performed to make
#		the estimated absolute error of the integral less than
#		the given value.  Default is 1.e-6.
#	-degree N
#		Specifies the degree of the polynomial that will be
#		used to extrapolate to a zero step size.  -degree 0
#		requests integration with the midpoint rule; -degree 1
#		is equivalent to Simpson's 3/8 rule; higher degrees
#		are difficult to describe but (within reason) give
#		faster convergence for smooth functions.  Default is
#		-degree 4.
#	-maxiter N
#		Specifies the maximum number of triplings of the
#		number of steps to take in integration.  At most
#		3**N function evaluations will be performed in
#		integrating with -maxiter N.  The integration
#		will terminate at that time, even if the result
#		satisfies neither the -relerror nor -abserror tests.
#
# Results:
#	Returns a two-element list.  The first element is the estimated
#	value of the integral; the second is the estimated absolute
#	error of the value.
#
#----------------------------------------------------------------------

proc ::math::calculus::romberg { f a b args } {

    # Replace f with a context-independent version

    set f [lreplace $f 0 0 [uplevel 1 [list namespace which [lindex $f 0]]]]

    # Assign default parameters

    array set params {
	-abserror 1.0e-10
	-degree 4
	-relerror 1.0e-6
	-maxiter 14
    }

    # Extract parameters

    if { ( [llength $args] % 2 ) != 0 } {
        return -code error -errorcode [list romberg wrongNumArgs] \
            "wrong \# args, should be\
                 \"[lreplace [info level 0] 1 end \
                         f x1 x2 ?-option value?...]\""
    }
    foreach { key value } $args {
        if { ![info exists params($key)] } {
            return -code error -errorcode [list romberg badoption $key] \
                "unknown option \"$key\",\
                     should be -abserror, -degree, -relerror, or -maxiter"
        }
        set params($key) $value
    }

    # Check params

    if { ![string is double -strict $a] } {
	return -code error [expectDouble $a]
    }
    if { ![string is double -strict $b] } {
	return -code error [expectDouble $b]
    }
    if { ![string is double -strict $params(-abserror)] } {
	return -code error [expectDouble $params(-abserror)]
    }
    if { ![string is integer -strict $params(-degree)] } {
	return -code error [expectInteger $params(-degree)]
    }
    if { ![string is integer -strict $params(-maxiter)] } {
	return -code error [expectInteger $params(-maxiter)]
    }
    if { ![string is double -strict $params(-relerror)] } {
	return -code error [expectDouble $params(-relerror)]
    }
    foreach key {-abserror -degree -maxiter -relerror} {
	if { $params($key) <= 0 } {
	    return -code error -errorcode [list romberg notPositive $key] \
		"$key must be positive"
	}
    }
    if { $params(-maxiter) <= $params(-degree) } {
	return -code error -errorcode [list romberg tooFewIter] \
	    "-maxiter must be greater than -degree"
    }

    # Create lists of step size and sum with the given number of steps.

    set x [list]
    set y [list]
    set s 0;				# Current best estimate of integral
    set indx end-$params(-degree)
    set pow3 1.;			# Current step size (times b-a)

    # Perform successive integrations, tripling the number of steps each time

    for { set i 0 } { $i < $params(-maxiter) } { incr i } {
	set s [midpoint $f $a $b $i $s]
	lappend x $pow3
	lappend y $s
	set pow3 [expr { $pow3 / 9. }]

	# Once $degree steps have been done, start Richardson extrapolation
	# to a zero step size.

	if { $i >= $params(-degree) } {
	    set x [lrange $x $indx end]
	    set y [lrange $y $indx end]
	    foreach {estimate err} [neville $x $y 0.] break
	    if { $err < $params(-abserror)
		 || $err < $params(-relerror) * abs($estimate) } {
		return [list $estimate $err]
	    }
	}
    }

    # If -maxiter iterations have been done, give up, and return
    # with the current error estimate.

    return [list $estimate $err]
}

#----------------------------------------------------------------------
#
# u_infinity --
#	Change of variable for integrating over a half-infinite
#	interval
#
# Parameters:
#	f - Function being integrated
#	u - 1/x, where x is the abscissa where f is to be evaluated
#
# Results:
#	Returns f(1/u)/(u**2)
#
# Side effects:
#	Whatever f does.
#
#----------------------------------------------------------------------

proc ::math::calculus::u_infinity { f u } {
    set cmd $f
    lappend cmd [expr { 1.0 / $u }]
    set y [eval $cmd]
    return [expr { $y / ( $u * $u ) }]
}

#----------------------------------------------------------------------
#
# romberg_infinity --
#	Evaluate a function on a half-open interval
#
# Usage:
#	Same as 'romberg'
#
# The 'romberg_infinity' procedure performs Romberg integration on
# an interval [a,b] where an infinite a or b may be represented by
# a large number (e.g. 1.e30).  It operates by a change of variable;
# instead of integrating f(x) from a to b, it makes a change
# of variable u = 1/x, and integrates from 1/b to 1/a f(1/u)/u**2 du.
#
#----------------------------------------------------------------------

proc ::math::calculus::romberg_infinity { f a b args } {
    if { ![string is double -strict $a] } {
	return -code error [expectDouble $a]
    }
    if { ![string is double -strict $b] } {
	return -code error [expectDouble $b]
    }
    if { $a * $b <= 0. } {
        return -code error -errorcode {romberg_infinity cross-axis} \
            "limits of integration have opposite sign"
    }
    set f [lreplace $f 0 0 [uplevel 1 [list namespace which [lindex $f 0]]]]
    set f [list u_infinity $f]
    return [eval [linsert $args 0 \
                      romberg $f [expr { 1.0 / $b }] [expr { 1.0 / $a }]]]
}

#----------------------------------------------------------------------
#
# u_sqrtSingLower --
#	Change of variable for integrating over an interval with
#	an inverse square root singularity at the lower bound.
#
# Parameters:
#	f - Function being integrated
#	a - Lower bound
#	u - sqrt(x-a), where x is the abscissa where f is to be evaluated
#
# Results:
#	Returns 2 * u * f( a + u**2 )
#
# Side effects:
#	Whatever f does.
#
#----------------------------------------------------------------------

proc ::math::calculus::u_sqrtSingLower { f a u } {
    set cmd $f
    lappend cmd [expr { $a + $u * $u }]
    set y [eval $cmd]
    return [expr { 2. * $u * $y }]
}

#----------------------------------------------------------------------
#
# u_sqrtSingUpper --
#	Change of variable for integrating over an interval with
#	an inverse square root singularity at the upper bound.
#
# Parameters:
#	f - Function being integrated
#	b - Upper bound
#	u - sqrt(b-x), where x is the abscissa where f is to be evaluated
#
# Results:
#	Returns 2 * u * f( b - u**2 )
#
# Side effects:
#	Whatever f does.
#
#----------------------------------------------------------------------

proc ::math::calculus::u_sqrtSingUpper { f b u } {
    set cmd $f
    lappend cmd [expr { $b - $u * $u }]
    set y [eval $cmd]
    return [expr { 2. * $u * $y }]
}

#----------------------------------------------------------------------
#
# math::calculus::romberg_sqrtSingLower --
#	Integrate a function with an inverse square root singularity
#	at the lower bound
#
# Usage:
#	Same as 'romberg'
#
# The 'romberg_sqrtSingLower' procedure is a wrapper for 'romberg'
# for integrating a function with an inverse square root singularity
# at the lower bound of the interval.  It works by making the change
# of variable u = sqrt( x-a ).
#
#----------------------------------------------------------------------

proc ::math::calculus::romberg_sqrtSingLower { f a b args } {
    if { ![string is double -strict $a] } {
	return -code error [expectDouble $a]
    }
    if { ![string is double -strict $b] } {
	return -code error [expectDouble $b]
    }
    if { $a >= $b } {
	return -code error "limits of integration out of order"
    }
    set f [lreplace $f 0 0 [uplevel 1 [list namespace which [lindex $f 0]]]]
    set f [list u_sqrtSingLower $f $a]
    return [eval [linsert $args 0 \
			     romberg $f 0 [expr { sqrt( $b - $a ) }]]]
}

#----------------------------------------------------------------------
#
# math::calculus::romberg_sqrtSingUpper --
#	Integrate a function with an inverse square root singularity
#	at the upper bound
#
# Usage:
#	Same as 'romberg'
#
# The 'romberg_sqrtSingUpper' procedure is a wrapper for 'romberg'
# for integrating a function with an inverse square root singularity
# at the upper bound of the interval.  It works by making the change
# of variable u = sqrt( b-x ).
#
#----------------------------------------------------------------------

proc ::math::calculus::romberg_sqrtSingUpper { f a b args } {
    if { ![string is double -strict $a] } {
	return -code error [expectDouble $a]
    }
    if { ![string is double -strict $b] } {
	return -code error [expectDouble $b]
    }
    if { $a >= $b } {
	return -code error "limits of integration out of order"
    }
    set f [lreplace $f 0 0 [uplevel 1 [list namespace which [lindex $f 0]]]]
    set f [list u_sqrtSingUpper $f $b]
    return [eval [linsert $args 0 \
		      romberg $f 0. [expr { sqrt( $b - $a ) }]]]
}

#----------------------------------------------------------------------
#
# u_powerLawLower --
#	Change of variable for integrating over an interval with
#	an integrable power law singularity at the lower bound.
#
# Parameters:
#	f - Function being integrated
#	gammaover1mgamma - gamma / (1 - gamma), where gamma is the power
#	oneover1mgamma - 1 / (1 - gamma), where gamma is the power
#	a - Lower limit of integration
#	u - Changed variable u == (x-a)**(1-gamma)
#
# Results:
#	Returns u**(1/1-gamma) * f(a + u**(1/1-gamma) ).
#
# Side effects:
#	Whatever f does.
#
#----------------------------------------------------------------------

proc ::math::calculus::u_powerLawLower { f gammaover1mgamma oneover1mgamma
					 a u } {
    set cmd $f
    lappend cmd [expr { $a + pow( $u, $oneover1mgamma ) }]
    set y [eval $cmd]
    return [expr { $y * pow( $u, $gammaover1mgamma ) }]
}

#----------------------------------------------------------------------
#
# math::calculus::romberg_powerLawLower --
#	Integrate a function with an integrable power law singularity
#	at the lower bound
#
# Usage:
#	romberg_powerLawLower gamma f a b ?-option value...?
#
# Parameters:
#	gamma - Power (0<gamma<1) of the singularity
#	f - Function to integrate.  Must be a single Tcl command,
#	    to which will be appended the abscissa at which the function
#	    should be evaluated.  f is expected to have an integrable
#	    power law singularity at the lower endpoint; that is, the
#	    integrand is expected to diverge as (x-a)**gamma.
#	a - One bound of the interval
#	b - The other bound of the interval.  a and b need not be in
#	    ascending order.
#
# Options:
#	-abserror ABSERROR
#		Requests that the integration be performed to make
#		the estimated absolute error of the integral less than
#		the given value.  Default is 1.e-10.
#	-relerror RELERROR
#		Requests that the integration be performed to make
#		the estimated absolute error of the integral less than
#		the given value.  Default is 1.e-6.
#	-degree N
#		Specifies the degree of the polynomial that will be
#		used to extrapolate to a zero step size.  -degree 0
#		requests integration with the midpoint rule; -degree 1
#		is equivalent to Simpson's 3/8 rule; higher degrees
#		are difficult to describe but (within reason) give
#		faster convergence for smooth functions.  Default is
#		-degree 4.
#	-maxiter N
#		Specifies the maximum number of triplings of the
#		number of steps to take in integration.  At most
#		3**N function evaluations will be performed in
#		integrating with -maxiter N.  The integration
#		will terminate at that time, even if the result
#		satisfies neither the -relerror nor -abserror tests.
#
# Results:
#	Returns a two-element list.  The first element is the estimated
#	value of the integral; the second is the estimated absolute
#	error of the value.
#
# The 'romberg_sqrtSingLower' procedure is a wrapper for 'romberg'
# for integrating a function with an integrable power law singularity
# at the lower bound of the interval.  It works by making the change
# of variable u = (x-a)**(1-gamma).
#
#----------------------------------------------------------------------

proc ::math::calculus::romberg_powerLawLower { gamma f a b args } {
    if { ![string is double -strict $gamma] } {
	return -code error [expectDouble $gamma]
    }
    if { $gamma <= 0.0 || $gamma >= 1.0 } {
	return -code error -errorcode [list romberg gammaTooBig] \
	    "gamma must lie in the interval (0,1)"
    }
    if { ![string is double -strict $a] } {
	return -code error [expectDouble $a]
    }
    if { ![string is double -strict $b] } {
	return -code error [expectDouble $b]
    }
    if { $a >= $b } {
	return -code error "limits of integration out of order"
    }
    set f [lreplace $f 0 0 [uplevel 1 [list namespace which [lindex $f 0]]]]
    set onemgamma [expr { 1. - $gamma }]
    set f [list u_powerLawLower $f \
	       [expr { $gamma / $onemgamma }] \
	       [expr { 1 / $onemgamma }] \
	       $a]

    set limit [expr { pow( $b - $a, $onemgamma ) }]
    set result {}
    foreach v [eval [linsert $args 0 romberg $f 0 $limit]] {
	lappend result [expr { $v / $onemgamma }]
    }
    return $result

}

#----------------------------------------------------------------------
#
# u_powerLawLower --
#	Change of variable for integrating over an interval with
#	an integrable power law singularity at the upper bound.
#
# Parameters:
#	f - Function being integrated
#	gammaover1mgamma - gamma / (1 - gamma), where gamma is the power
#	oneover1mgamma - 1 / (1 - gamma), where gamma is the power
#	b - Upper limit of integration
#	u - Changed variable u == (b-x)**(1-gamma)
#
# Results:
#	Returns u**(1/1-gamma) * f(b-u**(1/1-gamma) ).
#
# Side effects:
#	Whatever f does.
#
#----------------------------------------------------------------------

proc ::math::calculus::u_powerLawUpper { f gammaover1mgamma oneover1mgamma
					 b u } {
    set cmd $f
    lappend cmd [expr { $b - pow( $u, $oneover1mgamma ) }]
    set y [eval $cmd]
    return [expr { $y * pow( $u, $gammaover1mgamma ) }]
}

#----------------------------------------------------------------------
#
# math::calculus::romberg_powerLawUpper --
#	Integrate a function with an integrable power law singularity
#	at the upper bound
#
# Usage:
#	romberg_powerLawLower gamma f a b ?-option value...?
#
# Parameters:
#	gamma - Power (0<gamma<1) of the singularity
#	f - Function to integrate.  Must be a single Tcl command,
#	    to which will be appended the abscissa at which the function
#	    should be evaluated.  f is expected to have an integrable
#	    power law singularity at the upper endpoint; that is, the
#	    integrand is expected to diverge as (b-x)**gamma.
#	a - One bound of the interval
#	b - The other bound of the interval.  a and b need not be in
#	    ascending order.
#
# Options:
#	-abserror ABSERROR
#		Requests that the integration be performed to make
#		the estimated absolute error of the integral less than
#		the given value.  Default is 1.e-10.
#	-relerror RELERROR
#		Requests that the integration be performed to make
#		the estimated absolute error of the integral less than
#		the given value.  Default is 1.e-6.
#	-degree N
#		Specifies the degree of the polynomial that will be
#		used to extrapolate to a zero step size.  -degree 0
#		requests integration with the midpoint rule; -degree 1
#		is equivalent to Simpson's 3/8 rule; higher degrees
#		are difficult to describe but (within reason) give
#		faster convergence for smooth functions.  Default is
#		-degree 4.
#	-maxiter N
#		Specifies the maximum number of triplings of the
#		number of steps to take in integration.  At most
#		3**N function evaluations will be performed in
#		integrating with -maxiter N.  The integration
#		will terminate at that time, even if the result
#		satisfies neither the -relerror nor -abserror tests.
#
# Results:
#	Returns a two-element list.  The first element is the estimated
#	value of the integral; the second is the estimated absolute
#	error of the value.
#
# The 'romberg_PowerLawUpper' procedure is a wrapper for 'romberg'
# for integrating a function with an integrable power law singularity
# at the upper bound of the interval.  It works by making the change
# of variable u = (b-x)**(1-gamma).
#
#----------------------------------------------------------------------

proc ::math::calculus::romberg_powerLawUpper { gamma f a b args } {
    if { ![string is double -strict $gamma] } {
	return -code error [expectDouble $gamma]
    }
    if { $gamma <= 0.0 || $gamma >= 1.0 } {
	return -code error -errorcode [list romberg gammaTooBig] \
	    "gamma must lie in the interval (0,1)"
    }
    if { ![string is double -strict $a] } {
	return -code error [expectDouble $a]
    }
    if { ![string is double -strict $b] } {
	return -code error [expectDouble $b]
    }
    if { $a >= $b } {
	return -code error "limits of integration out of order"
    }
    set f [lreplace $f 0 0 [uplevel 1 [list namespace which [lindex $f 0]]]]
    set onemgamma [expr { 1. - $gamma }]
    set f [list u_powerLawUpper $f \
	       [expr { $gamma / $onemgamma }] \
	       [expr { 1. / $onemgamma }] \
	       $b]

    set limit [expr { pow( $b - $a, $onemgamma ) }]
    set result {}
    foreach v [eval [linsert $args 0 romberg $f 0 $limit]] {
	lappend result [expr { $v / $onemgamma }]
    }
    return $result

}

#----------------------------------------------------------------------
#
# u_expUpper --
#
#	Change of variable to integrate a function that decays
#	exponentially.
#
# Parameters:
#	f - Function to integrate
#	u - Changed variable u = exp(-x)
#
# Results:
#	Returns (1/u)*f(-log(u))
#
# Side effects:
#	Whatever f does.
#
#----------------------------------------------------------------------

proc ::math::calculus::u_expUpper { f u } {
    set cmd $f
    lappend cmd [expr { -log($u) }]
    set y [eval $cmd]
    return [expr { $y / $u }]
}

#----------------------------------------------------------------------
#
# romberg_expUpper --
#
#	Integrate a function that decays exponentially over a
#	half-infinite interval.
#
# Parameters:
#	Same as romberg.  The upper limit of integration, 'b',
#	is expected to be very large.
#
# Results:
#	Same as romberg.
#
# The romberg_expUpper function operates by making the change of
# variable, u = exp(-x).
#
#----------------------------------------------------------------------

proc ::math::calculus::romberg_expUpper { f a b args } {
    if { ![string is double -strict $a] } {
	return -code error [expectDouble $a]
    }
    if { ![string is double -strict $b] } {
	return -code error [expectDouble $b]
    }
    if { $a >= $b } {
	return -code error "limits of integration out of order"
    }
    set f [lreplace $f 0 0 [uplevel 1 [list namespace which [lindex $f 0]]]]
    set f [list u_expUpper $f]
    return [eval [linsert $args 0 \
		      romberg $f [expr {exp(-$b)}] [expr {exp(-$a)}]]]
}

#----------------------------------------------------------------------
#
# u_expLower --
#
#	Change of variable to integrate a function that grows
#	exponentially.
#
# Parameters:
#	f - Function to integrate
#	u - Changed variable u = exp(x)
#
# Results:
#	Returns (1/u)*f(log(u))
#
# Side effects:
#	Whatever f does.
#
#----------------------------------------------------------------------

proc ::math::calculus::u_expLower { f u } {
    set cmd $f
    lappend cmd [expr { log($u) }]
    set y [eval $cmd]
    return [expr { $y / $u }]
}

#----------------------------------------------------------------------
#
# romberg_expLower --
#
#	Integrate a function that grows exponentially over a
#	half-infinite interval.
#
# Parameters:
#	Same as romberg.  The lower limit of integration, 'a',
#	is expected to be very large and negative.
#
# Results:
#	Same as romberg.
#
# The romberg_expUpper function operates by making the change of
# variable, u = exp(x).
#
#----------------------------------------------------------------------

proc ::math::calculus::romberg_expLower { f a b args } {
    if { ![string is double -strict $a] } {
	return -code error [expectDouble $a]
    }
    if { ![string is double -strict $b] } {
	return -code error [expectDouble $b]
    }
    if { $a >= $b } {
	return -code error "limits of integration out of order"
    }
    set f [lreplace $f 0 0 [uplevel 1 [list namespace which [lindex $f 0]]]]
    set f [list u_expLower $f]
    return [eval [linsert $args 0 \
		      romberg $f [expr {exp($a)}] [expr {exp($b)}]]]
}


# regula_falsi --
#    Compute the zero of a function via regula falsi
# Arguments:
#    f       Name of the procedure/command that evaluates the function
#    xb      Start of the interval that brackets the zero
#    xe      End of the interval that brackets the zero
#    eps     Relative error that is allowed (default: 1.0e-4)
# Result:
#    Estimate of the zero, such that the estimated (!)
#    error < eps * abs(xe-xb)
# Note:
#    f(xb)*f(xe) must be negative and eps must be positive
#
proc ::math::calculus::regula_falsi { f xb xe {eps 1.0e-4} } {
    if { $eps <= 0.0 } {
       return -code error "Relative error must be positive"
    }

    set fb [$f $xb]
    set fe [$f $xe]

    if { $fb * $fe > 0.0 } {
       return -code error "Interval must be chosen such that the \
function has a different sign at the beginning than at the end"
    }

    set max_error [expr {$eps * abs($xe-$xb)}]
    set interval  [expr {abs($xe-$xb)}]

    while { $interval > $max_error } {
       set coeff [expr {($fe-$fb)/($xe-$xb)}]
       set xi    [expr {$xb-$fb/$coeff}]
       set fi    [$f $xi]

       if { $fi == 0.0 } {
          break
       }
       set diff1 [expr {abs($xe-$xi)}]
       set diff2 [expr {abs($xb-$xi)}]
       if { $diff1 > $diff2 } {
          set interval $diff2
       } else {
          set interval $diff1
       }

       if { $fb*$fi < 0.0 } {
          set xe $xi
          set fe $fi
       } else {
          set xb $xi
          set fb $fi
       }
    }

    return $xi
}

#

# qk15_basic --
#     Apply the QK15 rule to a single interval and return all results
#
# Arguments:
#     f             Function to integrate (name of procedure)
#     xstart        Start of the interval
#     xend          End of the interval
#
# Returns:
#     List of the following:
#     result        Estimated integral (I) of function f
#     abserr        Estimate of the absolute error in "result"
#     resabs        Estimated integral of the absolute value of f
#     resasc        Estimated integral of abs(f - I/(xend-xstart))
#
# Note:
#     Translation of the 15-point Gauss-Kronrod rule (QK15) as found
#     in the SLATEC library (QUADPACK) into Tcl.
#
namespace eval ::math::calculus {
    variable qk15_xgk
    variable qk15_wgk
    variable qk15_wg

    set qk15_xgk {
           0.9914553711208126e+00    0.9491079123427585e+00
           0.8648644233597691e+00    0.7415311855993944e+00
           0.5860872354676911e+00    0.4058451513773972e+00
           0.2077849550078985e+00    0.0e+00               }
    set qk15_wgk {
           0.2293532201052922e-01    0.6309209262997855e-01
           0.1047900103222502e+00    0.1406532597155259e+00
           0.1690047266392679e+00    0.1903505780647854e+00
           0.2044329400752989e+00    0.2094821410847278e+00}
    set qk15_wg {
           0.1294849661688697e+00    0.2797053914892767e+00
           0.3818300505051189e+00    0.4179591836734694e+00}
}

if {[package vsatisfies [package present Tcl] 8.5]} {
    proc ::math::calculus::Min {a b} { expr {min ($a, $b)} }
    proc ::math::calculus::Max {a b} { expr {max ($a, $b)} }
} else {
    proc ::math::calculus::Min {a b} { if {$a < $b} { return $a } else { return $b }}
    proc ::math::calculus::Max {a b} { if {$a > $b} { return $a } else { return $b }}
}

proc ::math::calculus::qk15_basic {xstart xend func} {
    variable qk15_wg
    variable qk15_wgk
    variable qk15_xgk

    #
    # Use fixed values for epmach and uflow:
    # - epmach is the largest relative spacing.
    # - uflow is the smallest positive magnitude.

    set epmach [expr {2.3e-308}]
    set uflow  [expr {1.2e-16}]

    set centr  [expr {0.5e+00*($xstart+$xend)}]
    set hlgth  [expr {0.5e+00*($xend-$xstart)}]
    set dhlgth [expr {abs($hlgth)}]

    #
    # Compute the 15-point Kronrod approximation to
    # the integral, and estimate the absolute error.
    #
    set fc     [uplevel 2 $func $centr]
    set resg   [expr {$fc*[lindex $qk15_wg 3]}]
    set resk   [expr {$fc*[lindex $qk15_wgk 7]}]
    set resabs [expr {abs($resk)}]

    set fv1    [lrepeat 7 0.0]
    set fv2    [lrepeat 7 0.0]

    for {set j 0} {$j < 3} {incr j} {
        set jtw [expr {$j*2 +1}]
        set absc [expr {$hlgth*[lindex $qk15_xgk $jtw]}]
        set fval1 [uplevel 2 $func [expr {$centr-$absc}]]
        set fval2 [uplevel 2 $func [expr {$centr+$absc}]]
        lset fv1 $jtw $fval1
        lset fv2 $jtw $fval2
        set fsum [expr {$fval1+$fval2}]
        set resg [expr {$resg+[lindex $qk15_wg $j]*$fsum}]
        set resk [expr {$resk+[lindex $qk15_wgk $jtw]*$fsum}]
        set resabs [expr {$resabs+[lindex $qk15_wgk $jtw]*(abs($fval1)+abs($fval2))}]
    }
    for {set j 0} {$j < 4} {incr j} {
        set jtwm1 [expr {$j*2}]
        set absc [expr {$hlgth*[lindex $qk15_xgk $jtwm1]}]
        set fval1 [uplevel 2 $func [expr {$centr-$absc}]]
        set fval2 [uplevel 2 $func [expr {$centr+$absc}]]
        lset fv1 $jtwm1 $fval1
        lset fv2 $jtwm1 $fval2
        set fsum [expr {$fval1+$fval2}]
        set resk [expr {$resk+[lindex $qk15_wgk $jtwm1]*$fsum}]
        set resabs [expr {$resabs+[lindex $qk15_wgk $jtwm1]*(abs($fval1)+abs($fval2))}]
    }

    set reskh [expr {$resk*0.5e+00}]
    set resasc [expr {[lindex $qk15_wgk 7]*abs($fc-$reskh)}]

    for {set j 0} {$j < 7} {incr j} {
        set wgk    [lindex $qk15_wgk $j]
        set FV1    [lindex $fv1      $j]
        set FV2    [lindex $fv2      $j]
        set resasc [expr {$resasc+$wgk*(abs($FV1-$reskh)+abs($FV2-$reskh))}]
    }

    set result [expr {$resk*$hlgth}]
    set resabs [expr {$resabs*$dhlgth}]
    set resasc [expr {$resasc*$dhlgth}]
    set abserr [expr {abs(($resk-$resg)*$hlgth)}]
    if { $resasc != 0.0e+00 && $abserr != 0.0e+00 } {
        set abserr [expr {$resasc*[Min 0.1e+01 [expr {pow((0.2e+3*$abserr/$resasc),1.5e+00)}]]}]
    }
    if { $resabs > $uflow/(0.5e+02*$epmach) } {
        set abserr [Max [expr {($epmach*0.5e+02)*$resabs}] $abserr]
    }

    return [list $result $abserr $resabs $resasc]
}

# qk15 --
#     Apply the QK15 rule to an interval and return the estimated integral
#
# Arguments:
#     xstart        Start of the interval
#     xend          End of the interval
#     func          Function to integrate (name of procedure)
#     n             Number of subintervals (default: 1)
#
# Returns:
#     Estimated integral of function func
#
proc ::math::calculus::qk15 {xstart xend func {n 1}} {
    if { $n == 1 } {
        return [lindex [qk15_basic $xstart $xend $func] 0]
    } else {
        set dx [expr {($xend-$xstart)/double($n)}]
        set result 0.0
        for {set i 0} {$i < $n} {incr i} {
            set xb [expr {$xstart + $dx * $i}]
            set xe [expr {$xstart + $dx * ($i+1)}]

            set result [expr {$result + [lindex [qk15_basic $xb $xe $func] 0]}]
        }
    }

    return $result
}

# qk15_detailed --
#     Apply the QK15 rule to an interval and return the estimated integral
#     as well as the other values
#
# Arguments:
#     xstart        Start of the interval
#     xend          End of the interval
#     func          Function to integrate (name of procedure)
#     n             Number of subintervals (default: 1)
#
# Returns:
#     List of the following:
#     result        Estimated integral (I) of function func
#     abserr        Estimate of the absolute error in "result"
#     resabs        Estimated integral of the absolute value of f
#     resasc        Estimated integral of abs(f - I/(xend-xstart))
#
proc ::math::calculus::qk15_detailed {xstart xend func {n 1}} {
    if { $n == 1 } {
        return [qk15_basic $xstart $xend $func]
    } else {
        set dx [expr {($xend-$xstart)/double($n)}]
        set result 0.0
        set abserr 0.0
        set resabs 0.0
        set resasc 0.0
        for {set i 0} {$i < $n} {incr i} {
            set xb [expr {$xstart + $dx * $i}]
            set xe [expr {$xstart + $dx * ($i+1)}]

            foreach {dresult dabserr dresabs dresasc} [qk15_basic $xb $xe $func] break
            set result [expr {$result + $dresult}]
            set abserr [expr {$abserr + $dabserr}]
            set resabs [expr {$resabs + $dresabs}]
            set resasc [expr {$resasc + $dresasc}]
        }
    }

    return [list $result $abserr $resabs $resasc]
}
