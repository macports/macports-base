## -*- tcl -*-
# ### ### ### ######### ######### #########
##
## Tcl implementation for map::slippy
##
## See
##	http://wiki.openstreetmap.org/wiki/Slippy_map_tilenames#Pseudo-Code
##
## for the coordinate conversions and other information.

# ### ### ### ######### ######### #########
## Requisites

package require math::constants

# ### ### ### ######### ######### #########
## API - Ensemble setup

namespace eval ::map::slippy {
    math::constants::constants pi radtodeg degtorad

    variable ourtilesize 256 ; # Size of slippy tiles <pixels>
}

# Space for RDP helpers
namespace eval ::map::slippy::point::simplify {}

# ### ### ### ######### ######### #########
## Implementation

proc ::map::slippy::tcl_geo_valid_list {gs} {
    foreach g $gs { if {![valid $g]} { return 0 } }
    return 1
}

proc ::map::slippy::tcl_geo_box_valid_list {gs} {
    foreach g $gs { if {![valid $g]} { return 0 } }
    return 1
}

proc ::map::slippy::tcl_geo_valid {g} {
    ::map::slippy::Check2 $g
    lassign $g lat lon
    return [expr {[map slippy valid latitude $lat] && [map slippy valid longitude $lon]}]
}

proc ::map::slippy::tcl_geo_box_valid {gbox} {
    ::map::slippy::Check4 $gbox
    lassign $gbox lat0 lon0 lat1 lon1
    return [expr {
	  [map slippy valid latitude $lat0] && [map slippy valid longitude $lon0] &&
	  [map slippy valid latitude $lat1] && [map slippy valid longitude $lon1]
    }]
}

proc ::map::slippy::tcl_valid_latitude {x} {
    if {$x >  90} { return 0 }
    if {$x < -90} { return 0 }
    return 1
}

proc ::map::slippy::tcl_valid_longitude {x} {
    if {$x >  180} { return 0 }
    if {$x < -180} { return 0 }
    return 1
}

proc ::map::slippy::tcl_limit6 {x} { Limit $x 1000000. }
proc ::map::slippy::tcl_limit3 {x} { Limit $x 1000.    }
proc ::map::slippy::tcl_limit2 {x} { Limit $x 100.     }
proc ::map::slippy::Limit {x f} {
    set y [expr {int($x)}]
    if {$x == $y} { return $y }
    set x [expr {round($x * $f)/$f}]
    set y [expr {int($x)}]
    if {$x == $y} { return $y }
    return $x
}

proc ::map::slippy::tcl_length {level} {
    variable ourtilesize
    return [expr {$ourtilesize * (1 << $level)}]
}

proc ::map::slippy::tcl_tiles {level} {
    return [expr {1 << $level}]
}

proc ::map::slippy::tcl_tile_size {} {
    variable ::map::slippy::ourtilesize
    return $ourtilesize
}

proc ::map::slippy::tcl_tile_valid {zoom row col levels {msgv {}}} {
    if {$msgv ne ""} { upvar 1 $msgv msg }

    # Requests outside of the valid ranges are rejected immediately

    if {($zoom < 0) || ($zoom >= $levels)} {
	set msg "Bad zoom level '$zoom' (max: $levels)"
	return 0
    }

    set tiles [map slippy tiles $zoom]
    if {($row < 0) || ($row >= $tiles) ||
	($col < 0) || ($col >= $tiles)
    } {
	set msg "Bad cell '$row $col' (max: $tiles)"
	return 0
    }

    return 1
}

proc ::map::slippy::tcl_geo_box_limit {gbox} {
    ::map::slippy::Check4 $gbox
    lassign $gbox latmin lonmin latmax lonmax

    lappend r [map slippy limit6 $latmin]
    lappend r [map slippy limit6 $lonmin]
    lappend r [map slippy limit6 $latmax]
    lappend r [map slippy limit6 $lonmax]

    return $r
}

proc ::map::slippy::tcl_geo_box_inside {gbox g} {
    ::map::slippy::Check4 $gbox
    ::map::slippy::Check2 $g
    lassign $gbox latmin lonmin latmax lonmax
    lassign $g    lat lon

    if {$lat < $latmin} { return 0 }
    if {$lat > $latmax} { return 0 }
    if {$lon < $lonmin} { return 0 }
    if {$lon > $lonmax} { return 0 }

    return 1
}

proc ::map::slippy::tcl_geo_box_center {gbox} {
    ::map::slippy::Check4 $gbox
    lassign $gbox latmin lonmin latmax lonmax

    set lat [expr {($latmin + $latmax)/2.}]
    set lon [expr {($lonmin + $lonmax)/2.}]

    return [list $lat $lon]
}

proc ::map::slippy::tcl_geo_box_dimensions {gbox} {
    ::map::slippy::Check4 $gbox
    lassign $gbox latmin lonmin latmax lonmax

    set dlat [expr {$latmax - $latmin}]
    set dlon [expr {$lonmax - $lonmin}]

    return [list $dlon $dlat]
}

proc ::map::slippy::tcl_geo_box_2point {zoom gbox} {
    return [map slippy point bbox-list [map slippy geo 2point-list $zoom [opposites $gbox]]]
}

proc ::map::slippy::tcl_geo_box_corners {gbox} {
    ::map::slippy::Check4 $gbox
    lassign $gbox latmin lonmin latmax lonmax
    return [list \
		[list $latmin $lonmin] [list $latmin $lonmax] \
		[list $latmax $lonmin] [list $latmax $lonmax]]
}

proc ::map::slippy::tcl_geo_box_diameter {gbox} {
    ::map::slippy::Check4 $gbox
    lassign $gbox latmin lonmin latmax lonmax
    return [map slippy geo distance* 0 [list $latmin $lonmin] [list $latmax $lonmax]]
}

proc ::map::slippy::tcl_geo_box_opposites {gbox} {
    ::map::slippy::Check4 $gbox
    return [list [lrange $gbox 0 1] [lrange $gbox 2 3]]
}

proc ::map::slippy::tcl_geo_box_perimeter {gbox} {
    return [map slippy geo distance-list 1 [corners $gbox]]
}

proc ::map::slippy::tcl_geo_box_fit {gbox canvdim zmax {zmin 0}} {
    ::map::slippy::Check4 $gbox
    ::map::slippy::Check2 $canvdim

    variable ::map::slippy::ourtilesize
    lassign $canvdim canvw canvh
    lassign [dimensions $gbox] gw gh

    # NOTE we assume ourtilesize == [map::slippy length 0].
    # Further, we assume that each zoom step "grows" the linear resolution by a factor 2
    # (that's the log(2) down there)
    set canvw [expr {abs($canvw)}]
    set canvh [expr {abs($canvh)}]
    set z [expr {int(log(min( \
		  ($canvh/$ourtilesize) / (abs($gh)/180), \
		  ($canvw/$ourtilesize) / (abs($gw)/360))) \
                 / log(2))}]
    #puts z'initial:$z
    # clamp ...
    set z [expr {($z<$zmin) ? $zmin : (($z>$zmax) ? $zmax : $z)}]
    #puts z'clamp:$z

    # The zoom we have now is an approximation, since the scale factor isn't uniform across the map
    # (the vertical dimension depends on latitude). We have to refine it iteratively, i.e. try to
    # grow/shrink until it does (not) fit any longer, and then back off.
    while {1} {
	# Now we can run "uphill", then there's z0 = z - 1 and "downhill", then there's z1 = z + 1
	# (from the last iteration)
	#puts "try zoom $z"

	lassign [map slippy point box dimensions [2point $z $gbox]] w h

	#puts dimensions|w|[expr {abs($w)}]|$canvw|h|[expr {abs($h)}]|$canvh|

	if { (abs($w) > $canvw) || (abs($h) > $canvh) } {
	    # too big: shrink
	    #puts "too big: shrink..."
	    if { [info exists z0] } break; # but not if we come "from below"
	    if {$z <= $zmin} break; # can't be < $zmin
	    set z1 $z
	    incr z -1
	} else {
	    # fits: grow
	    #puts "fits: grow..."
	    if { [info exists z1] } break; # but not if we come "from above"
	    if {$z >= $zmax} {
		#puts "fits: at max!"
		break
	    }
	    set z0 $z
	    incr z
	}
    }
    if { [info exists z0] } { set z $z0 }
    #puts z'final:$z
    return $z
}

proc ::map::slippy::tcl_geo_limit {g} {
    ::map::slippy::Check2 $g
    lassign $g lat lon

    lappend r [map slippy limit6 $lat]
    lappend r [map slippy limit6 $lon]

    return $r
}

proc ::map::slippy::tcl_geo_distance {geoa geob} {
    ::map::slippy::Check2 $geoa
    ::map::slippy::Check2 $geob

    # https://en.wikipedia.org/wiki/Haversine_formula
    # https://wiki.tcl-lang.org/page/geodesy
    # https://en.wikipedia.org/wiki/Geographical_distance	| For radius used in angle
    # https://en.wikipedia.org/wiki/Earth_radius		| to meter conversion
    ##
    # Go https://en.wikipedia.org/wiki/N-vector ?

    #puts deg.A($geoa)-B($geob)

    variable ::map::slippy::degtorad
    variable ::map::slippy::pi

    # Get the decimal degrees
    lassign $geoa lata lona
    lassign $geob latb lonb

    # Convert all to radians
    set lata [expr {$degtorad * $lata}]
    set lona [expr {$degtorad * $lona}]
    set latb [expr {$degtorad * $latb}]
    set lonb [expr {$degtorad * $lonb}]

    #puts rad.A($lata|$lona)-B($latb|$lonb)

    set dlat [expr {$latb - $lata}]
    set dlon [expr {$lonb - $lona}]

    # puts d.lat($dlat).lon.($dlon)

    set h [expr {pow((sin($dlat/2)),2) + cos($lata)*cos($latb)*pow((sin($dlon/2)),2)}]
    #       dy^2 + cos*cos*dx^2
    #       dy^2 + (sqrt(cos*cos)*dx)^2
    # puts H.($h)

    # Fix rounding errors, clamp to range -1...1
    if {abs($h) > 1.0} { set h [expr {($h > 0) ? 1.0 : -1.0}] }
    # puts HC.($h)

    # Distance angle
    set d [expr {2 * asin(sqrt($h))}]
    # puts D.($d)

    # set d [expr {2*asin(hypot( sin($dlat/2), sqrt(cos($y1)*cos($y2)) * sin($dlon/2) )  )}]
    # not sure how bad that is with rounding errors for antipodal points.

    # Convert to meters and return
    set meters [expr {6371009*$d}]
    #puts M.($meters)
    return $meters
}

proc ::map::slippy::tcl_geo_distance_args {closed args} {
    return [distance-list $closed $args]
}

proc ::map::slippy::tcl_geo_distance_list {closed geos} {
    if {[llength $geos] < 2} { return 0 }

    set d 0
    set last [lindex $geos 0]
    if {$closed} {
	set first $last
    }
    foreach now [lrange $geos 1 end] {
	set d [expr {$d + [distance $last $now]}]
	set last $now
    }
    if {$closed} {
	set d [expr {$d + [distance $last $first]}]
    }
    return $d
}

proc ::map::slippy::tcl_geo_bbox {args} {
    return [bbox-list $args]
}

proc ::map::slippy::tcl_geo_bbox_list {geos} {
    if {![llength $geos]} { return {0 0 0 0} }

    set lat0  Inf
    set lon0  Inf
    set lat1 -Inf
    set lon1 -Inf

    foreach g $geos {
	lassign $g lat lon
	set lat0 [expr {min ($lat0, $lat)}]
	set lon0 [expr {min ($lon0, $lon)}]
	set lat1 [expr {max ($lat1, $lat)}]
	set lon1 [expr {max ($lon1, $lon)}]

    }
    return [list $lat0 $lon0 $lat1 $lon1]
}

proc ::map::slippy::tcl_geo_center {args} {
        return [center-list $args]
}

proc ::map::slippy::tcl_geo_center_list {geos} {
    if {![llength $geos]} { return {0 0} }

    set lat0  Inf
    set lon0  Inf
    set lat1 -Inf
    set lon1 -Inf

    foreach g $geos {
	lassign $g lat lon
	set lat0 [expr {min ($lat0, $lat)}]
	set lon0 [expr {min ($lon0, $lon)}]
	set lat1 [expr {max ($lat1, $lat)}]
	set lon1 [expr {max ($lon1, $lon)}]

    }

    set lat [expr {($lat0 + $lat1)/2.}]
    set lon [expr {($lon0 + $lon1)/2.}]

    return [list $lat $lon]
}

proc ::map::slippy::tcl_geo_diameter {args} {
    return [diameter-list $args]
}

proc ::map::slippy::tcl_geo_diameter_list {geos} {
    if {[llength $geos] < 2} { return 0 }

    # The diameter of the set of points is computed as the maximum distance over the distances
    # between all pairs of points. The algorithm below is O(n^2).
    ##
    # It can be done better by (a) determining the convex hull of the set of points, followed by (b)
    # using rotating calipers over the hull to determine the diameter.

    # https://en.wikipedia.org/wiki/Rotating_calipers
    # file:///home/aku/Downloads/MQ50856.pdf

    # -- no three consecutive vertices are collinear -- collinear in spherical geo ?

    set d 0
    set k 0
    foreach a $geos {
	incr k
	foreach b [lrange $geos $k end] {
	    set d [expr {max($d, [distance $a $b])}]
	}
    }
    return $d
}

# Coordinate conversions.
# geo   = latitude, longitude
# point = x, y

proc ::map::slippy::tcl_geo_2point {zoom g} {
    ::map::slippy::Check/Z2 $zoom $g

    variable ::map::slippy::degtorad
    variable ::map::slippy::pi
    variable ::map::slippy::ourtilesize
    lassign $g lat lon
    set tiles  [map slippy tiles $zoom]
    set latrad [expr {$degtorad * $lat}]
    set y      [expr {$ourtilesize * ((1 - (log(tan($latrad) + 1.0/cos($latrad)) / $pi)) / 2 * $tiles)}]
    set x      [expr {$ourtilesize * ((($lon + 180.0) / 360.0) * $tiles)}]
    return [list $x $y]
}

proc ::map::slippy::tcl_geo_2point_args {zoom args} {
    return [2point-list $zoom $args]
}

proc ::map::slippy::tcl_geo_2point_list {zoom geos} {
    return [lmap geo $geos { 2point $zoom $geo }]
}

proc ::map::slippy::tcl_point_box_inside {pbox p} {
    ::map::slippy::Check4 $pbox
    ::map::slippy::Check2 $p
    lassign $pbox x0 y0 x1 y1
    lassign $p    x y

    if {$y < $y0} { return 0 }
    if {$y > $y1} { return 0 }
    if {$x < $x0} { return 0 }
    if {$x > $x1} { return 0 }

    return 1
}

proc ::map::slippy::tcl_point_box_center {pbox} {
    ::map::slippy::Check4 $pbox
    lassign $pbox x0 y0 x1 y1

    set x [expr {($x0 + $x1)/2.}]
    set y [expr {($y0 + $y1)/2.}]

    return [list $x $y]
}

proc ::map::slippy::tcl_point_box_dimensions {pbox} {
    ::map::slippy::Check4 $pbox
    lassign $pbox x0 y0 x1 y1

    set dx [expr {$x1 - $x0}]
    set dy [expr {$y1 - $y0}]

    return [list $dx $dy]
}

proc ::map::slippy::tcl_point_box_2geo {zoom pbox} {
    return [map slippy geo bbox-list [map slippy point 2geo-list $zoom [opposites $pbox]]]
}

proc ::map::slippy::tcl_point_box_corners {pbox} {
    ::map::slippy::Check4 $pbox
    lassign $pbox xmin ymin xmax ymax
    return [list \
		[list $xmin $ymin] [list $xmin $ymax] \
		[list $xmax $ymin] [list $xmax $ymax]]
}

proc ::map::slippy::tcl_point_box_diameter {pbox} {
    ::map::slippy::Check4 $pbox
    lassign $pbox x0 y0 x1 y1
    return [map slippy point distance* 0 [list $x0 $y0] [list $x1 $y1]]
}

proc ::map::slippy::tcl_point_box_opposites {pbox} {
    ::map::slippy::Check4 $pbox
    return [list [lrange $pbox 0 1] [lrange $pbox 2 3]]
}

proc ::map::slippy::tcl_point_box_perimeter {pbox} {
    return [map slippy point distance-list 1 [corners $pbox]]
}

proc ::map::slippy::tcl_point_distance {pointa pointb} {
    # points here are type point (list/p (x y))
    ::map::slippy::Check2 $pointa
    ::map::slippy::Check2 $pointb

    lassign $pointa x0 y0
    lassign $pointb x1 y1

    return [expr { hypot ($x1 - $x0, $y1 - $y0) }]
}

proc ::map::slippy::tcl_point_distance_args {closed args} {
    return [distance-list $closed $args]
}

proc ::map::slippy::tcl_point_distance_list {closed points} {
    # points here are type point (list/pair (x y))
    if {[llength $points] < 2} { return 0 }

    set d 0
    set last [lindex $points 0]
    if {$closed} {
	set first $last
    }
    foreach now [lrange $points 1 end] {
	set d [expr {$d + [distance $last $now]}]
	set last $now
    }
    if {$closed} {
	set d [expr {$d + [distance $last $first]}]
    }
    return $d
}

proc ::map::slippy::tcl_point_bbox {args} {
    return [bbox-list $args]
}

proc ::map::slippy::tcl_point_bbox_list {points} {
    # points here are type point (list/pair (x y))
    if {![llength $points]} { return {0 0 0 0} }

    set y0  Inf
    set x0  Inf
    set y1 -Inf
    set x1 -Inf

    foreach g $points {
	lassign $g x y
	set y0 [expr {min ($y0, $y)}]
	set x0 [expr {min ($x0, $x)}]
	set y1 [expr {max ($y1, $y)}]
	set x1 [expr {max ($x1, $x)}]

    }
    return [list $x0 $y0 $x1 $y1]
}

proc ::map::slippy::tcl_point_center {args} {
    return [center-list $args]
}

proc ::map::slippy::tcl_point_center_list {points} {
    if {![llength $points]} { return {0 0} }

    set y0  Inf
    set x0  Inf
    set y1 -Inf
    set x1 -Inf

    foreach g $points {
	lassign $g x y
	set y0 [expr {min ($y0, $y)}]
	set x0 [expr {min ($x0, $x)}]
	set y1 [expr {max ($y1, $y)}]
	set x1 [expr {max ($x1, $x)}]

    }

    set y [expr {($y0 + $y1)/2.}]
    set x [expr {($x0 + $x1)/2.}]

    # point type
    return [list $x $y]
}

proc ::map::slippy::tcl_point_diameter {args} {
        return [diameter-list $args]
}

proc ::map::slippy::tcl_point_diameter_list {points} {
    if {[llength $points] < 2} { return 0 }

    # The diameter of the set of points is computed as the maximum distance over the distances
    # between all pairs of points. The algorithm below is O(n^2).
    ##
    # It can be done better by (a) determining the convex hull of the set of points, followed by (b)
    # using rotating calipers over the hull to determine the diameter.

    # https://en.wikipedia.org/wiki/Rotating_calipers
    # file:///home/aku/Downloads/MQ50856.pdf

    # -- no three consecutive vertices are collinear -- collinear in spherical geo ?

    set d 0
    set k 0
    foreach a $points {
	incr k
	foreach b [lrange $points $k end] {
	    set d [expr {max($d, [distance $a $b])}]
	}
    }
    return $d
}

proc ::map::slippy::tcl_point_2geo {zoom p} {
    ::map::slippy::Check/Z2 $zoom $p

    variable ::map::slippy::radtodeg
    variable ::map::slippy::pi
    lassign $p x y
    set length [map slippy length $zoom]
    set lat    [expr {$radtodeg * (atan(sinh($pi * (1 - 2 * double($y) / $length))))}]
    set lon    [expr {double($x) / $length * 360.0 - 180.0}]
    return [list $lat $lon]
}

proc ::map::slippy::tcl_point_2geo_args {zoom args} {
    return [2geo-list $zoom $args]
}

proc ::map::slippy::tcl_point_2geo_list {zoom points} {
    return [lmap point $points { 2geo $zoom $point }]
}

proc ::map::slippy::tcl_point_simplify_radial {threshold closed points} {
    # Pass input if nothing or single pixel
    if {[llength $points] <= 1} { return $points }

    # Enough data to run the full algorithm
    set anchor [lindex $points 0]
    set result [list $anchor]
    set len    [llength $points]
    set current 1

    lassign $anchor ax ay

    for {set current 1} {$current < $len} {incr current} {
	set now [lindex $points $current]
	lassign $now nx ny
	set distance [expr {hypot($nx-$ax,$ny-$ay)}]
	if {$distance <= $threshold} continue
	# Far enough away from the anchor. Keep and make new anchor to check from.
	lappend result $now
	set ax $nx
	set ay $ny
    }

    if {!$closed || ([llength $result] < 2)} {
	return $result
    }

    lassign [lindex $result 0  ] fx fy
    lassign [lindex $result end] lx ly
    set d [expr {hypot($lx-$fx,$ly-$fy)}]

    if {$d <= $threshold} { set result [lreplace $result end end] }

    if {[llength $result] == 2} {
	# If the polygon became a line make it a point anyway
	#puts \tsingle/x
	return [list [map slippy point center {*}$result]]
    }

    return $result
}

proc ::map::slippy::tcl_point_simplify_rdp {points} {
    # References:
    # - https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm
    # - https://github.com/BobLd/RamerDouglasPeuckerNetV2

    if {[llength $points] < 3} {
	return $points
    }

    set end [llength $points] ; incr end -1

    RDPCore keep $points 0 $end
    set result [lmap i [lsort -integer [dict keys $keep]] { lindex $points $i }]

    return $result
}

proc ::map::slippy::point::simplify::RDPCore {kv points i j} {
    upvar 1 $kv keep

    if {($j - $i) < 2} {
	# no intermediate points - keep this line
	dict set keep $i .
	dict set keep $j .
	return
    }

    set la [lindex $points $i]
    set lb [lindex $points $j]

    lassign [RDPFindFarthest $points $la $lb $i $j] d k
    set t   [RDPThreshold    $points $la $lb]
    if {$d <= $t} {
	# Near enough, ignore the intermediaries
	dict set keep $i .
	dict set keep $j .
	return
    }

    # Recurse into the pseudo-halves
    RDPCore keep $points $i $k
    RDPCore keep $points $k $j
    return
}

proc ::map::slippy::point::simplify::RDPThreshold {points la lb} {
    # References
    # - https://core.ac.uk/download/pdf/131287229.pdf
    # - https://github.com/BobLd/RamerDouglasPeuckerNetV2/blob/b3d00f43d0ed5951ea2b1ca86bedfa72bb3d42a4/RamerDouglasPeuckerNetV2.Test/RamerDouglasPeuckerNetV2/RamerDouglasPeucker.cs#L97-L111
    # Modification:
    # - special case threshold for distance (s) <= 0. Which puts tmax at +Inf (Div by zero).

    lassign $la x0 y0
    lassign $lb x1 y1

    set dx [expr {$x1 - $x0}]
    set dy [expr {$y1 - $y0}]
    set s  [expr {hypot ($dy, $dx)}]

    # If there is "no distance" at all, dismiss anything in between.
    if {$s <= 0} { return 0	}

    # Non-singular distance, continue as normal

    set phi  [expr {atan2 ($dy, $dx)}]
    set cphi [expr {cos ($phi)}]
    set sphi [expr {sin ($phi)}]
    set tmax [expr {(abs ($cphi) + abs ($sphi))/$s}]

    # puts la..|$la
    # puts lb..|$lb
    # puts s...|$s
    # puts phi.|$phi
    # puts cphi|$cphi
    # puts sphi|$sphi
    # puts tmax|$tmax

    set poly [expr {1 - $tmax + $tmax * $tmax}]

    # puts poly|$poly

    set px   [expr {$poly/$s}]
    set pphi [expr {max (atan(abs($sphi + $cphi)*$px),
			 atan(abs($sphi - $cphi)*$px))}]
    set dmax [expr {$s * $pphi}]

    # optimize: square for squared distance
    return $dmax
}

proc ::map::slippy::point::simplify::RDPFindFarthest {points la lb i j} {
    # Naive: max of distance for all intermediate points...
    # Optimize: inline distance, avoid sqrt and recompute of commons.
    # la ~ i, lb ~ j

    set max 0
    set d   0
    set k  $i

    for {incr k} {$k < $j} {incr k} {
	set dx [RDPDistanceLine [lindex $points $k] $la $lb]
	if {$dx < $d} continue
	set d $dx
	set max $k
    }

    return [list $d $max]
}

proc ::map::slippy::point::simplify::RDPDistanceLine {c a b} { ;# puts [info level 0]
    # Distance of point C from line through A-B
    # See also canvas::edit::polyline -- DistanceTo
    # Check tcllib / math::geometry

    lassign $c cx cy
    lassign $a ax ay
    lassign $b bx by

    # Solution based on FAQ 1.02 on comp.graphics.algorithms
    #
    # L = hypot( Bx-Ax, By-Ay )
    #
    #     (Ay-Cy)(Bx-Ax)-(Ax-Cx)(By-Ay)
    # s = -----------------------------
    #                 L^2
    # dist = |s|*L
    #
    # =>
    #
    #        | (Ay-Cy)(Bx-Ax)-(Ax-Cx)(By-Ay) |
    # dist = ---------------------------------
    #                       L

    if {($ax == $bx) && ($ay == $by)} {
	# (a == b) => distance is to the point
	return [expr {hypot($cx-$ax,$cy-$ay)}]
    }

    return [expr {abs(($ay-$cy)*($bx-$ax)-($ax-$cx)*($by-$ay)) / hypot($bx-$ax,$by-$ay)}]
}

proc ::map::slippy::Check/Z2 {z p} {
    if {[llength $p] != 2} {
	return -code error {Bad point, expected list of 2}
    }
    lassign $p b c
    if {![string is int    -strict $z]} { return -code error "expected integer but got \"$z\"" }
    if {![string is double -strict $b]} { return -code error "expected floating-point number but got \"$b\"" }
    if {![string is double -strict $c]} { return -code error "expected floating-point number but got \"$c\"" }
    return
}

proc ::map::slippy::Check2 {p} {
    if {[llength $p] != 2} {
	return -code error {Bad point, expected list of 2}
    }
    lassign $p a b
    if {![string is double -strict $a]} { return -code error "expected floating-point number but got \"$a\"" }
    if {![string is double -strict $b]} { return -code error "expected floating-point number but got \"$b\"" }
    return
}

proc ::map::slippy::Check4 {p} {
    if {[llength $p] != 4} {
	return -code error {Bad box, expected list of 4}
    }
    lassign $p a b c d
    if {![string is double -strict $a]} { return -code error "expected floating-point number but got \"$a\"" }
    if {![string is double -strict $b]} { return -code error "expected floating-point number but got \"$b\"" }
    if {![string is double -strict $c]} { return -code error "expected floating-point number but got \"$c\"" }
    if {![string is double -strict $d]} { return -code error "expected floating-point number but got \"$d\"" }
    return
}

# ### ### ### ######### ######### #########
## Ready
return
