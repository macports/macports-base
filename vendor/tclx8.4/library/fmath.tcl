#
# fmath.tcl --
#
#   Contains a package of procs that interface to the Tcl expr command built-in
# functions.  These procs provide compatibility with older versions of TclX and
# are also generally useful.
#------------------------------------------------------------------------------
# Copyright 1993-1999 Karl Lehenbauer and Mark Diekhans.
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose and without fee is hereby granted, provided
# that the above copyright notice appear in all copies.  Karl Lehenbauer and
# Mark Diekhans make no representations about the suitability of this
# software for any purpose.  It is provided "as is" without express or
# implied warranty.
#------------------------------------------------------------------------------
# $Id: fmath.tcl,v 1.2 2002/04/02 03:00:14 hobbs Exp $
#------------------------------------------------------------------------------

#@package: TclX-fmath acos asin atan ceil cos cosh exp fabs floor log log10 \
           sin sinh sqrt tan tanh fmod pow atan2 abs double int round

proc acos  x {uplevel 1 [list expr acos($x)]}
proc asin  x {uplevel 1 [list expr asin($x)]}
proc atan  x {uplevel 1 [list expr atan($x)]}
proc ceil  x {uplevel 1 [list expr ceil($x)]}
proc cos   x {uplevel 1 [list expr cos($x)]}
proc cosh  x {uplevel 1 [list expr cosh($x)]}
proc exp   x {uplevel 1 [list expr exp($x)]}
proc fabs  x {uplevel 1 [list expr abs($x)]}
proc floor x {uplevel 1 [list expr floor($x)]}
proc log   x {uplevel 1 [list expr log($x)]}
proc log10 x {uplevel 1 [list expr log10($x)]}
proc sin   x {uplevel 1 [list expr sin($x)]}
proc sinh  x {uplevel 1 [list expr sinh($x)]}
proc sqrt  x {uplevel 1 [list expr sqrt($x)]}
proc tan   x {uplevel 1 [list expr tan($x)]}
proc tanh  x {uplevel 1 [list expr tanh($x)]}

proc fmod {x n} {uplevel 1 [list expr fmod($x,$n)]}
proc pow {x n} {uplevel 1 [list expr pow($x,$n)]}

# New functions that TclX did not provide in eariler versions.

proc atan2  x {uplevel 1 [list expr atan2($x)]}
proc abs    x {uplevel 1 [list expr abs($x)]}
proc double x {uplevel 1 [list expr double($x)]}
proc int    x {uplevel 1 [list expr int($x)]}
proc round  x {uplevel 1 [list expr round($x)]}



