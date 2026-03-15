# plotstat.tcl --
#
#    Set of very simple drawing routines, belonging to the statistics
#    package
#
# version 0.1: initial implementation, january 2003

namespace eval ::math::statistics {}

# plot-scale
#    Set the scale for a plot in the given canvas
#
# Arguments:
#    canvas   Canvas widget to use
#    xmin     Minimum x value
#    xmax     Maximum x value
#    ymin     Minimum y value
#    ymax     Maximum y value
#
# Result:
#    None
#
# Side effect:
#    Array elements set
#
proc ::math::statistics::plot-scale { canvas xmin xmax ymin ymax } {
    variable plot

    if { $xmin == $xmax } { set xmax [expr {1.1*$xmin+1.0}] }
    if { $ymin == $ymax } { set ymax [expr {1.1*$ymin+1.0}] }

    set plot($canvas,xmin) $xmin
    set plot($canvas,xmax) $xmax
    set plot($canvas,ymin) $ymin
    set plot($canvas,ymax) $ymax

    set cwidth  [$canvas cget -width]
    set cheight [$canvas cget -height]
    set cx      20
    set cy      20
    set cx2     [expr {$cwidth-$cx}]
    set cy2     [expr {$cheight-$cy}]

    set plot($canvas,cx)   $cx
    set plot($canvas,cy)   $cy

    set plot($canvas,dx)   [expr {($cwidth-2*$cx)/double($xmax-$xmin)}]
    set plot($canvas,dy)   [expr {($cheight-2*$cy)/double($ymax-$ymin)}]
    set plot($canvas,cx2)  $cx2
    set plot($canvas,cy2)  $cy2

    $canvas create line $cx $cy $cx $cy2 $cx2 $cy2 -tag axes
}

# plot-xydata
#    Create a simple XY plot in the given canvas (collection of dots)
#
# Arguments:
#    canvas   Canvas widget to use
#    xdata    Series of independent data
#    ydata    Series of dependent data
#    tag      Tag to give to the plotted data (defaults to xyplot)
#
# Result:
#    None
#
# Side effect:
#    Simple xy graph in the canvas
#
# Note:
#    The tag can be used to manipulate the xy graph
#
proc ::math::statistics::plot-xydata { canvas xdata ydata {tag xyplot} } {
    PlotXY $canvas points $tag $xdata $ydata
}

# plot-xyline
#    Create a simple XY plot in the given canvas (continuous line)
#
# Arguments:
#    canvas   Canvas widget to use
#    xdata    Series of independent data
#    ydata    Series of dependent data
#    tag      Tag to give to the plotted data (defaults to xyplot)
#
# Result:
#    None
#
# Side effect:
#    Simple xy graph in the canvas
#
# Note:
#    The tag can be used to manipulate the xy graph
#
proc ::math::statistics::plot-xyline { canvas xdata ydata {tag xyplot} } {
    PlotXY $canvas line $tag $xdata $ydata
}

# plot-tdata
#    Create a simple XY plot in the given canvas (the index in the list
#    is the horizontal coordinate; points)
#
# Arguments:
#    canvas   Canvas widget to use
#    tdata    Series of dependent data
#    tag      Tag to give to the plotted data (defaults to xyplot)
#
# Result:
#    None
#
# Side effect:
#    Simple xy graph in the canvas
#
# Note:
#    The tag can be used to manipulate the xy graph
#
proc ::math::statistics::plot-tdata { canvas tdata {tag xyplot} } {
    PlotXY $canvas points $tag {} $tdata
}

# plot-tline
#    Create a simple XY plot in the given canvas (the index in the list
#    is the horizontal coordinate; line)
#
# Arguments:
#    canvas   Canvas widget to use
#    tdata    Series of dependent data
#    tag      Tag to give to the plotted data (defaults to xyplot)
#
# Result:
#    None
#
# Side effect:
#    Simple xy graph in the canvas
#
# Note:
#    The tag can be used to manipulate the xy graph
#
proc ::math::statistics::plot-tline { canvas tdata {tag xyplot} } {
    PlotXY $canvas line $tag {} $tdata
}

# PlotXY
#    Create a simple XY plot (points or lines) in the given canvas
#
# Arguments:
#    canvas   Canvas widget to use
#    type     Type: points or line
#    tag      Tag to give to the plotted data
#    xdata    Series of independent data (if empty: index used instead)
#    ydata    Series of dependent data
#
# Result:
#    None
#
# Side effect:
#    Simple xy graph in the canvas
#
# Note:
#    This is the actual routine
#
proc ::math::statistics::PlotXY { canvas type tag xdata ydata } {
    variable plot

    if { ![info exists plot($canvas,xmin)] } {
	return -code error -errorcode "No scaling given for canvas $canvas"
    }

    set xmin $plot($canvas,xmin)
    set xmax $plot($canvas,xmax)
    set ymin $plot($canvas,ymin)
    set ymax $plot($canvas,ymax)
    set dx   $plot($canvas,dx)
    set dy   $plot($canvas,dy)
    set cx   $plot($canvas,cx)
    set cy   $plot($canvas,cy)
    set cx2  $plot($canvas,cx2)
    set cy2  $plot($canvas,cy2)

    set plotpoints [expr {$type == "points"}]
    set xpresent   [expr {[llength $xdata] > 0}]
    set idx        0
    set coords     {}

    foreach y $ydata {
	if { $xpresent } {
	    set x [lindex $xdata $idx]
	} else {
	    set x $idx
	}
	incr idx

	if { $x == {}    } continue
	if { $y == {}    } continue
	if { $x >  $xmax } continue
	if { $x <  $xmin } continue
	if { $y >  $ymax } continue
	if { $y <  $ymin } continue

	if { $plotpoints } {
	    set xc [expr {$cx+$dx*($x-$xmin)-2}]
	    set yc [expr {$cy2-$dy*($y-$ymin)-2}]
	    set xc2 [expr {$xc+4}]
	    set yc2 [expr {$yc+4}]
	    $canvas create oval $xc $yc $xc2 $yc2 -tag $tag -fill black
	} else {
	    set xc [expr {$cx+$dx*($x-$xmin)}]
	    set yc [expr {$cy2-$dy*($y-$ymin)}]
	    lappend coords $xc $yc
	}
    }

    if { ! $plotpoints } {
	$canvas create line $coords -tag $tag
    }
}

# plot-histogram
#    Create a simple histogram in the given canvas
#
# Arguments:
#    canvas   Canvas widget to use
#    counts   Series of bucket counts
#    limits   Series of upper limits for the buckets
#    tag      Tag to give to the plotted data (defaults to xyplot)
#
# Result:
#    None
#
# Side effect:
#    Simple histogram in the canvas
#
# Note:
#    The number of limits determines how many bars are drawn,
#    the number of counts that is expected is one larger. The
#    lower and upper limits of the first and last bucket are
#    taken to be equal to the scale's extremes
#
proc ::math::statistics::plot-histogram { canvas counts limits {tag xyplot} } {
    variable plot

    if { ![info exists plot($canvas,xmin)] } {
	return -code error -errorcode DATA "No scaling given for canvas $canvas"
    }

    if { ([llength $counts]-[llength $limits]) != 1 } {
	return -code error -errorcode ARG \
		"Number of counts does not correspond to number of limits"
    }

    set xmin $plot($canvas,xmin)
    set xmax $plot($canvas,xmax)
    set ymin $plot($canvas,ymin)
    set ymax $plot($canvas,ymax)
    set dx   $plot($canvas,dx)
    set dy   $plot($canvas,dy)
    set cx   $plot($canvas,cx)
    set cy   $plot($canvas,cy)
    set cx2  $plot($canvas,cx2)
    set cy2  $plot($canvas,cy2)

    #
    # Construct a sufficiently long list of x-coordinates
    #
    set xdata [concat $xmin $limits $xmax]

    set idx   0
    foreach x $xdata y $counts {
	incr idx

	if { $y == {}    } continue

	set x1 $x
	if { $x <  $xmin } { set x1 $xmin }
	if { $x >  $xmax } { set x1 $xmax }

	if { $y >  $ymax } { set y $ymax }
	if { $y <  $ymin } { set y $ymin }

	set x2  [lindex $xdata $idx]
	if { $x2 <  $xmin } { set x2 $xmin }
	if { $x2 >  $xmax } { set x2 $xmax }

	set xc  [expr {$cx+$dx*($x1-$xmin)}]
	set xc2 [expr {$cx+$dx*($x2-$xmin)}]
	set yc  [expr {$cy2-$dy*($y-$ymin)}]
	set yc2 $cy2

	$canvas create rectangle $xc $yc $xc2 $yc2 -tag $tag -fill blue
    }
}

#
# Simple test code
#
if { [info exists ::argv0] && ([file tail [info script]] == [file tail $::argv0]) } {

    set xdata {1 2 3 4 5 10 20 6 7 8 1 3 4 5 6 7}
    set ydata {2 3 4 5 6 10 20 7 8 1 3 4 5 6 7 1}

    canvas .c
    canvas .c2
    pack   .c .c2 -side top -fill both
    ::math::statistics::plot-scale .c  0 10 0 10
    ::math::statistics::plot-scale .c2 0 20 0 10

    ::math::statistics::plot-xydata .c  $xdata $ydata
    ::math::statistics::plot-xyline .c  $xdata $ydata
    ::math::statistics::plot-histogram .c2 {1 3 2 0.1 4 2} {-1 3 10 11 23}
    ::math::statistics::plot-tdata  .c2 $xdata
    ::math::statistics::plot-tline  .c2 $xdata
}
