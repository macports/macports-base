 # geometry_ext.tcl --
 #     Adapted from vectormath
 #
 ##+##########################################################################
 #
 # package: vectormath	->	vectormath.tcl
 #
 #   vectormath is software of Manfred ROSENBERGER
 #       based on tclTk, BWidgets and tdom on their
 #       own Licenses.
 #
 # Copyright (c) Manfred ROSENBERGER, 2010/10/24
 #
 # The author  hereby grant permission to use,  copy, modify, distribute,
 # and  license this  software  and its  documentation  for any  purpose,
 # provided that  existing copyright notices  are retained in  all copies
 # and that  this notice  is included verbatim  in any  distributions. No
 # written agreement, license, or royalty  fee is required for any of the
 # authorized uses.  Modifications to this software may be copyrighted by
 # their authors and need not  follow the licensing terms described here,
 # provided that the new terms are clearly indicated on the first page of
 # each file where they apply.
 #
 # IN NO  EVENT SHALL THE AUTHOR  OR DISTRIBUTORS BE LIABLE  TO ANY PARTY
 # FOR  DIRECT, INDIRECT, SPECIAL,  INCIDENTAL, OR  CONSEQUENTIAL DAMAGES
 # ARISING OUT  OF THE  USE OF THIS  SOFTWARE, ITS DOCUMENTATION,  OR ANY
 # DERIVATIVES  THEREOF, EVEN  IF THE  AUTHOR  HAVE BEEN  ADVISED OF  THE
 # POSSIBILITY OF SUCH DAMAGE.
 #
 # THE  AUTHOR  AND DISTRIBUTORS  SPECIFICALLY  DISCLAIM ANY  WARRANTIES,
 # INCLUDING,   BUT   NOT  LIMITED   TO,   THE   IMPLIED  WARRANTIES   OF
 # MERCHANTABILITY,    FITNESS   FOR    A    PARTICULAR   PURPOSE,    AND
 # NON-INFRINGEMENT.  THIS  SOFTWARE IS PROVIDED  ON AN "AS  IS" BASIS,
 # AND  THE  AUTHOR  AND  DISTRIBUTORS  HAVE  NO  OBLIGATION  TO  PROVIDE
 # MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 #
 # ---------------------------------------------------------------------------
 #	namespace:  vectormath
 # ---------------------------------------------------------------------------
 #
 #  0.7 ... proc tangent_2_circles ... exception on equal radius
 #      ... proc angleVector (use proc angle)
 #

        #
        #
namespace eval ::math::geometry {
        #
    variable pi     $::math::geometry::pi
    variable torad  $::math::geometry::torad
    variable todeg  $::math::geometry::todeg
        #
    variable margin 1.0e-10
        #

    variable  CONST_PI [expr {4*atan(1)}]

        #
}
    #
    #
    # ::math::geometry::cathetusPoint
    #
    #       Return point of rectangular triangle locating the rectangular angle.
    #
    # Arguments:
    #       pa       starting point on hypotenuse
    #       pb       ending point on hypotenuse
    #       cathetus a cathetus of the triangle
    #       location location of the given cathetus
    #                    a means given cathetus shares point pa (default)
    #                    b means given cathetus shares point pb
    #
    # Result:
    #       pc point locating the rectangular angle
    #
    # Examples:
    #     - cathetusPoint {1 1} {5 2} 3
    #       Result: {3.6168 -0.4671}
    #     - cathetusPoint {1 1} {5 2} 3 a
    #       Result: {3.6168 -0.4671}
    #     - cathetusPoint {1 1} {5 2} 3 b
    #       Result: {3.3815 -0.5259}
    #     - cathetusPoint {1 1} {5 2} 9 b
    #       Result: {}
    #
proc ::math::geometry::cathetusPoint {pa pb cathetus {location {a}}} {
    variable todeg
    if {$location eq {close}} {set location a}
    set length_c	[length [- $pa $pb]]
    set angle_c	    [angle [concat $pa $pb]]
    if {$length_c >= $cathetus} {
        set angle_cath	[expr {acos($cathetus/$length_c) * $todeg}]
    } else {
        return {}
    }
    if {$location == {a}} { # cathetus next to pa
      set angle_cath    [expr {$angle_c - $angle_cath}]
      set pc            [+ $pa [s* $cathetus [direction $angle_cath]]]
    } else {  # cathetus next to pb
      set angle_cath    [expr {180 + $angle_c + $angle_cath}]
      set vct_cath      [s* $cathetus [direction $angle_cath]]
      set pc            [+ $pb [s* $cathetus [direction $angle_cath]]]
    }
    return $pc
}
    #
    #
    # ::math::geometry::parallel
    #
    #       Return line parallel to line by offset
    #           direction is defined by the first two coordinates of line, e.g. [lrange $line 0 3]
    # Arguments:
    #       line
    #       offset
    #       orient   right (default), left
    #
    # Result:
    #       pc point locating the rectangular angle
    #
    # Examples:
    #     - parallel {1 1} {5 2} 3
    #       Result: {1.7276 -1.9104 5.7276 -0.9104}
    #     - parallel {1 1} {5 2} 3 a
    #       Result: {1.7276 -1.9104 5.7276 -0.9104}
    #     - parallel {1 1} {5 2} 3 b
    #       Result: {0.2724 3.9104 4.2724 4.9104}
    #
proc ::math::geometry::parallel {line offset {orient {right}}} {
    set a   [angle [lrange $line 0 3]]
    if {$orient == {right}} { # cathetus next to p1
        set a_p [expr {$a - 90}]
    } else {  # cathetus next to p2
        set a_p [expr {$a + 90}]
    }
    set parallel    {}
    set v           [rotate $a_p [list $offset 0]]
    foreach {x y} $line {
        set p       [+ [list $x $y] $v]
        lappend     parallel $p
    }
    return [join $parallel]
}
    #
    #
    # rotateAbout --
    #
    #       rotate a polyline
    #           about a given position and angle
    #
    # Arguments:
    #       p
    #       angle
    #       polyline
    #
    # Result:
    #       rotated polyline
    #
    # Examples:
    #     - rotateAbout    {10 10}  90 {20 0  20 20}
    #       Result: {20.0 20.0 0.0 20.0}
    #     - rotateAbout    {10 10} 180 {20 0  20 20}
    #       Result: {0.0 20.0 0.0 0.0}
    #
proc ::math::geometry::rotateAbout {p angle polyline} {
    lassign $p px py
    set polyline    [translate [list [expr {- $px}] [expr {- $py}]] $polyline]
    set polyline    [rotate $angle $polyline]
    set polyline    [translate $p $polyline]
    return $polyline
}

    #
    #
    # ::math::geometry::unitVector
    #
    #       Calculates unit vector from line.
    #
    # Arguments:
    #       line/direction    a line defined by two points A and B
    #                         a point defined by x and y
    #
    # Results:
    #       x y         unit vector describing the angle between the line (0,0)->(1,0) and (Ax,Ay)->(Bx,By).
    #                     Angle is in 360-degrees going counter-clockwise
    #
    # Examples:
    #     - angle {10 10 15 15}
    #       Result: 0.7071067811865476 0.7071067811865476
    #     - angle {10 10}
    #       Result: 0.7071067811865476 0.7071067811865476
    #
proc ::math::geometry::unitVector {line} {
    return [::math::geometry::direction [::math::geometry::angle $line]]
}

    #
    #
    # tangentLinesToCircle --
    #     Determine the tangents from a point to a circle
    #
    # Arguments:
    #     point         Point in question
    #     circle        Circle in question
    #
    # Returns:
    #     The two tangent lines or an empty list if the point is inside the circle
    #
    # Note:
    #     Shift and rotate the point and circle first, then determine the
    #     intersection and transform back.
    #
proc ::math::geometry::tangentLinesToCircle {point circle} {
    variable margin

    set centre [lrange $circle 0 1]
    set radius [lindex $circle end]

    set distance [distance $centre $point]

    if { $distance < $radius } {
        return {}
    } else {
        set vector [- $point $centre]
        set vector [s* [expr {1.0/$distance}] [- $point $centre]]

        if { abs($distance - $radius) < $margin*$radius } {
            lassign $vector vx vy
            return [list [concat $point [+ $point [list $vy [expr {-$vx}]]]]]
                # The two tangent lines coincide
        }
    }

    set halfdistance [expr {$distance / 2.0}]
    set newcircle    [list $halfdistance 0.0 $halfdistance]
    set intersection [IntersectionCircleCircle $circle $newcircle]

    set newIntersection {}
    lassign $vector vx vy
    lassign $centre cx cy
    if { [llength [lindex $intersection 0]] == 1 } {
        set intersection [list $intersection]
    }
    foreach xy $intersection {
        lassign $xy x y

        set xn [expr {$vx * $x - $vy * $y + $cx}]
        set yn [expr {$vy * $x + $vx * $y + $cy}]

        lappend newIntersection [list $xn $yn]
    }

    return [list [concat $point [lindex $newIntersection 0]] \
                 [concat $point [lindex $newIntersection 1]]]
}
    #
    #
    # ::math::geometry::angle
    #
    #       Calculates angle from the horizon (0,0)->(1,0) to a line.
    #
    # Arguments:
    #       line/direction    a line defined by two points A and B
    #                         a direction defined by x and y
    #
    # Results:
    #       angle         the angle between the line (0,0)->(1,0) and (Ax,Ay)->(Bx,By).
    #                     Angle is in 360-degrees going counter-clockwise
    #
    # Examples:
    #     - angle {10 10 15 13}
    #       Result: 30.9637565321
    #     - angle {10 10}
    #       Result: 45.0
    #
proc ::math::geometry::angle {line} {
    if {[llength $line] == 2} {
        set x1 0
        set y1 0
        lassign $line x2 y2
    } else {
        lassign $line x1 y1 x2 y2
    }
        # set x1 [lindex $line 0]
        # set y1 [lindex $line 1]
        # set x2 [lindex $line 2]
        # set y2 [lindex $line 3]
    # - handle vertical lines
    if {$x1==$x2} {if {$y1<$y2} {return 90} else {return 270}}
    # - handle other lines
    set a [expr {atan(abs((1.0*$y1-$y2)/(1.0*$x1-$x2)))}] ; # a is between 0 and pi/2
    set pi [expr {4*atan(1)}]
    if {$y1<=$y2} {
	# line is going upwards
	if {$x1<$x2} {set b $a} else {set b [expr {$pi-$a}]}
    } else {
	# line is going downwards
	if {$x1<$x2} {set b [expr {2*$pi-$a}]} else {set b [expr {$pi+$a}]}
    }
    return [expr {$b/$pi*180}] ; # convert b to degrees
}
    #
    #
    # ::math::geometry::unitVector
    #
    #       Calculates unit vector from line.
    #
    # Arguments:
    #       line/direction    a line defined by two points A and B
    #                         a point defined by x and y
    #
    # Results:
    #       x y         unit vector describing the angle between the line (0,0)->(1,0) and (Ax,Ay)->(Bx,By).
    #                     Angle is in 360-degrees going counter-clockwise
    #
    # Examples:
    #     - angle {10 10 15 15}
    #       Result: 0.7071067811865476 0.7071067811865476
    #     - angle {10 10}
    #       Result: 0.7071067811865476 0.7071067811865476
    #
proc ::math::geometry::unitVector {line} {
    return [::math::geometry::direction [::math::geometry::angle $line]]
}
    #
    #
    # Unit vector into specific direction given by angle (degrees)
    #   ... opposite behaviour of ::math::geometry::direction
proc ::math::geometry::direction {angle} {
    variable torad
    set x [expr {cos($angle * $torad)}]
    set y [expr {sin($angle * $torad)}]
    return [list $x $y]
}
    #
    #
    # Find direction octant the point (vector) lies in.
    #   ... opposite behaviour of ::math::geometry::direction
    #
proc ::math::geometry::octant {p} {
    variable todeg
    lassign $p x y

    set a [expr {(atan2(-$y,$x)*$todeg)}]
    while {$a >  360} {set a [expr {$a - 360}]}
    while {$a < -360} {set a [expr {$a + 360}]}
    if {$a < 0} {set a [expr {360 + $a}]}

    # puts "p ($x, $y) @ angle $a | [expr {atan2($y,$x)}] | [expr {atan2($y,$x)*$todeg}]"
    # XXX : Add outer conditions to make a log2 tree of checks.

    if {$a <= 157.5} {
	if {$a <= 67.5} {
	    if {$a <= 22.5} { return east }
	    return southeast
	}
	if {$a <=  112.5} { return south }
	return southwest
    } else {
	if {$a <=  247.5} {
	    if {$a <=  202.5} { return west }
	    return northwest
	}
	if {$a <=  337.5} {
	    if {$a <=  292.5} { return north }
	    return northeast
	}
	return east ; # a <= 360.0
    }
}
    #
    #
    # ::math::geometry::intersectSegmentCircle
    #
proc ::math::geometry::intersectSegmentCircle {line circle} {
    return [::math::geometry::lineSegmentIntersectsCircle $line $circle]
}
    #
    #
    # ::math::geometryExt::intersectLineCircle
    #
proc ::math::geometry::intersectLineCircle {line circle} {
    return [::math::geometry::lineIntersectsCircle $line $circle]
}
    #
    #
    # ::math::geometry::intersectLineSegments
    #
proc ::math::geometry::intersectLineSegments {line1 line2} {
    return [::math::geometry::lineSegmentsIntersect $line1 $line2]
}
    #
    # ::math::geometry::intersectionLineCircle
    #               ... intersectionLineWithCircle
    #
proc ::math::geometry::intersectionLineCircle {line circle} {
    return [::math::geometry::intersectionLineWithCircle $line $circle]
}
    #
    # ::math::geometry::intersectionLineCircle
    #               ... findLineSegmentIntersection
    #
proc ::math::geometry::intersectionLineSegments {line1 line2} {
    return [::math::geometry::findLineSegmentIntersection $line1 $line2]
}
    #
    #
    # ::math::geometry::intersectionSegmentCircle
    #
proc ::math::geometry::intersectionSegmentCircle {line circle} {
    if [intersectLineCircle $line $circle] {
        set posList {}
        foreach pos [intersectionLineCircle $line $circle] {
            if { [pointInsideBBox $line $pos] } {
                lappend posList $pos
            }
        }
        return $posList
    } else {
        return {}
    }
}
    #
    #
    # ::math::geometry::intersectionPolylines
    #
    #       ... based on ::math::geometry::polylinesBoundingIntersect
    #
    #       Computes the first or all intersections of two polylines.
    #
    #       How it works:
    #          Each polyline is split into a number of smaller polylines,
    #          consisting of granularity points each. If a pair of those smaller
    #          lines' bounding boxes intersect, then this procedure computes the
    #          first {mode=first} or alls {mode=all} intersecting points.
    #
    # Arguments:
    #       polyline1     the first polyline
    #       polyline2     the second polyline
    #       mode          [first|all] results
    #
    # Results:
    #       posIntersect   ... pos of intersections or empty list in case of no intersection found
    #
    # Examples:
    #     - intersectionPolylines {0 0 10 10 10 20} {0 10 10 0}
    #       Result: {5 5}
    #     - intersectionPolylines {0 0 10 10 10 20} {5 4 10 4}
    #       Result: {}
    #
    #
    #                               *
    #                              /
    #       +─────+               /
    #              \       * - - *
    #               \     /
    #                +── o ───────── ─>
    #                   /
    #                  *
    #
proc ::math::geometry::___polylineIntersection {polyline1 polyline2 {mode first}} {
    return [intersectionPolylines $polyline1 $polyline2 $mode]
}
proc ::math::geometry::intersectionPolylines {polyline1 polyline2 {mode first} {granularity 1}} {
        #
    #set granularity 10  ;   # the number of points in each part-polyline
    #                        #   granularity<=1 means full correctness
    #                        #   10 ... optimal search granularity?
        #
        # split the lines into parts consisting of $granularity points
    if {$granularity > 1 } {
        set polyline1parts {}
        for {set i 0} {$i<[llength $polyline1]} {incr i [expr {2*$granularity-2}]} {
            lappend polyline1parts [lrange $polyline1 $i [expr {$i+2*$granularity-1}]]
        }
        set polyline2parts {}
        for {set i 0} {$i<[llength $polyline2]} {incr i [expr {2*$granularity-2}]} {
            lappend polyline2parts [lrange $polyline2 $i [expr {$i+2*$granularity-1}]]
        }
    } else {
        set polyline1parts [list $polyline1]
        set polyline2parts [list $polyline2]
    }
        #
    set posList    {}
        #
        # do any of the parts overlap?
        #
        #
    foreach part1 $polyline1parts {
            #
            # puts "    -> \$part1    $part1"
        set part1bbox [bbox $part1]
            #
        foreach part2 $polyline2parts {
                # puts "    -> \$part2    $part2"
            set part2bbox [bbox $part2]
                # puts "      -> \$part1bbox $part1bbox"
                # puts "      -> \$part2bbox $part2bbox"
                #
            if {[rectanglesOverlap  [lrange $part1bbox 0 1] [lrange $part1bbox 2 3]  [lrange $part2bbox 0 1] [lrange $part2bbox 2 3] 0]} {
                    # puts " the lines' bounding boxes intersect"
                foreach {l1x2 l1y2} [lassign $part1 l1x1 l1y1] {
                    foreach {l2x2 l2y2} [lassign $part2 l2x1 l2y1] {
                            #
                            # puts "  -> try   [list $l1x1 $l1y1 $l1x2 $l1y2] 	<-?->   [list $l2x1 $l2y1 $l2x2 $l2y2]"
                        if {[intersectLineSegments [list $l1x1 $l1y1 $l1x2 $l1y2] [list $l2x1 $l2y1 $l2x2 $l2y2]]} {
                                # puts " two line segments overlap"
                                # compute intersection
                                # return position
                                # puts "      -> intersect - A1: yes"
                            set posIntersect    [intersectionLineSegments [list $l1x1 $l1y1 $l1x2 $l1y2] [list $l2x1 $l2y1 $l2x2 $l2y2]]
                            if {$posIntersect eq "coincident" || $posIntersect eq "none"} {
                                set posIntersect ""
                            }
                                # puts "      -> \$k: $k -> [list $l1x1 $l1y1 $l1x2 $l1y2]"
                                # puts "      -> \$l: $l -> [list $l2x1 $l2y1 $l2x2 $l2y2]"
                                # puts "      -> intersection: $posIntersect"
                            if {$mode ne "first"} {
                                lappend posList $posIntersect
                            } else {
                                return $posIntersect
                            }
                                #
                        }
                        set l2x1 $l2x2; set l2y1 $l2y2
                            #
                    }
                    set l1x1 $l1x2; set l1y1 $l1y2
                }
            }
        }
    }
        #
        #
    return $posList
        #
}
    #
    #
    # ::math::geometry::intersectionPolylineCircle
    #
    #       ... based on ::math::geometry::polylinesBoundingIntersect
    #
    #       Computes the first or all intersections of polyline and circle.
    #
    #       How it works:
    #          The polyline is split into a number of smaller polylines,
    #          consisting of granularity points each. If a pair of those smaller
    #          lines' bounding boxes intersect, then this procedure returns 1,
    #          otherwise it returns 0.
    #
    # Arguments:
    #       polyline1     the first polyline
    #       polyline2     the second polyline
    #       mode          return [first|all] intersections
    #
    # Results:
    #       posIntersect   ... pos of intersections or empty list in case of no intersection found
    #
    # Examples:
    #     - intersectionPolylineCircle {0 0  10 10  20 10  30 0} {40 0 20}
    #       Result: {30.564404225837308 4.717797887081346}
    #     - intersectionPolylineCircle {0 0  10 10  20 10  30 0} {20 0 15}
    #       Result: {18.81966011250105 10.0}
    #     - intersectionPolylineCircle {0 0  10 10  20 10  40 0} {20 0 15}
    #       Result: {34.77032961426901 2.6148351928654963} {6.464466094067264 6.464466094067264}
    #     - intersectionPolylineCircle {0 0  10 10  20 10  40 0} {20 0 15}
    #       Result: {}
    #
    #
    # Results:
    #       posList ...... e.g: {34.77032961426901 2.6148351928654963} {6.464466094067264 6.464466094067264}
    #
    #
    #
    #                   \
    #       +─────+      \
    #              \     |
    #               \    |
    #                +── o ───────── ─>
    #                   /
    #                  /
    #
proc ::math::geometry::___polylineCircleIntersection {polyline circle {mode first}} {
    return [intersectionPolylineCircle $polyline $circle $mode]
}
proc ::math::geometry::intersectionPolylineCircle {polyline circle {mode first} {granularity 1}} {
        #
        # puts "\n   -> ::math::geometry::polylineCircleIntersection \n"
        #
    #set granularity 5   ;   # the number of points in each part-polyline
                             #   granularity<=1 means full correctness
                             #   5 ... optimal search granularity?
        #
        # split the lines into parts consisting of $granularity points
    set polylineAllParts {}
    if { $granularity > 1 } {
        for {set i 0} {$i<[llength $polyline]} {incr i [expr {2*$granularity-2}]} {
            lappend polylineAllParts [lrange $polyline $i [expr {$i+2*$granularity-1}]]
        }
    } else {
        set polylineAllParts [list $polyline]
    }
         #
    lassign $circle x y r
    set posCenter   [list $x $y]
    set bboxCircle  [list [expr {$x - $r}] [expr {$y - $r}] [expr {$x + $r}] [expr {$y + $r}]]
        #
    set polylineUseParts    {}
        #
        # -- get parts of $polylineAllParts that might intersect circle
    foreach part $polylineAllParts {
            #
        set part1bbox       [bbox $part]
            #
        if {[rectanglesOverlap  [lrange $part1bbox 0 1] [lrange $part1bbox 2 3]  [lrange $bboxCircle 0 1] [lrange $bboxCircle 2 3] 1]} {
            lappend polylineUseParts    $part
        }
    }
        #
    if 0 {
        puts "   -> llength \$polylineAllParts -> [llength $polylineAllParts]"
        puts "   -> llength \$polylineUseParts -> [llength $polylineUseParts]"
        foreach polylinePart $polylineUseParts {
            puts "        \$polylineUseParts -> $polylinePart"
        }
    }
        #
        #
        # -- iterate through $polylineUseParts
        #
    set posList {}
        #
    set m 0
    foreach polylinePart $polylineUseParts {
            #
        incr m
            #
            # puts "--------------------"
            # puts "    -> \$polylinePart    $polylinePart"
        set n 0
        foreach {seg_x2 seg_y2} [lassign $polylinePart seg_x1 seg_y1] {
            incr n
            set segment         [list $seg_x1 $seg_y1 $seg_x2 $seg_y2]
            set posIntersect    [intersectionSegmentCircle $segment $circle]
            if {$posIntersect != {}} {
                    # puts "\n"
                    # puts "         $m / $n -> \$segment:  $segment"
                    # puts "         $m / $n -> \n\[::math::geometry::intersectionSegmentCircle \\\n    [list $segment] \\\n    [list $circle]\]"
                    # puts "         $m / $n -> \$posIntersect: $posIntersect"
                foreach pos $posIntersect {
                    # puts "       -> $m / $n : $segment"
                    # puts "       -> $m / $n : $pos"
                    if {$mode ne "first"} {
                        #lassign $pos _x_ _y_
                        #lappend posList [list [format {%0.6f} $_x_] [format {%0.6f} $_y_]]
                        lappend posList $pos
                    } else {
                        return $pos
                    }
                }
            }
            set seg_x1 $seg_x2; set seg_y1 $seg_y2
        }
    }
        #
        # puts "   -> \$posList $posList"
        # set posList [lsort -unique $posList]
        # puts "   -> \$posList $posList"
        #
    return $posList
        #
        #
}
    #
    #
    # ::math::geometry::polylineCutOrigin
    #
    # Arguments:
    #       polyline1      the first polyline
    #       polyline2      the second polyline
    #       granularity    the coarseness for the procedure
    #
    # Return:
    #       polyline       polyline from cut position to end
    #
proc ::math::geometry::polylineCutOrigin {polyline1 polyline2 {granularity 1}} {
        #
    #set granularity 10  ;   # the number of points in each part-polyline
                             #   granularity<=1 means full correctness
                             #   10 ... optimal search granularity?
        #
        # split the lines into parts consisting of $granularity points
    set granularity [expr {min(2,$granularity+1)}];# We need the total number of points in the section

    set polyline1parts {}
    for {set i 0} {$i<[llength $polyline1]} {incr i [expr {2*$granularity-2}]} {
        lappend polyline1parts [lrange $polyline1 $i [expr {$i+2*$granularity-1}]]
    }
    set polyline2parts {}
    for {set i 0} {$i<[llength $polyline2]} {incr i [expr {2*$granularity-2}]} {
        lappend polyline2parts [lrange $polyline2 $i [expr {$i+2*$granularity-1}]]
    }
        #
    set posIntersect    {}
    set polyline        {}
        #
        # do any of the parts overlap?
        #
        #
    foreach part1 $polyline1parts {
            # puts "    -> \$part1    $part1"
        set part1bbox [bbox $part1]
            #
        foreach part2 $polyline2parts {
                # puts "    -> \$part2    $part2"
            set part2bbox [bbox $part2]
                # puts "      -> \$part1bbox $part1bbox"
                # puts "      -> \$part2bbox $part2bbox"
                #
            if {[rectanglesOverlap  [lrange $part1bbox 0 1] [lrange $part1bbox 2 3]  [lrange $part2bbox 0 1] [lrange $part2bbox 2 3] 0]} {
                    # puts " the lines' bounding boxes intersect"
                foreach {l1x2 l1y2} [lassign $part1 l1x1 l1y1] {
                    if {$polyline eq {}} {
                        foreach {l2x2 l2y2} [lassign $part2 l2x1 l2y1] {
                                #
                                # puts "  -> try   [list $l1x1 $l1y1 $l1x2 $l1y2] 	<-?->   [list $l2x1 $l2y1 $l2x2 $l2y2]"
                            if {[intersectLineSegments [list $l1x1 $l1y1 $l1x2 $l1y2] [list $l2x1 $l2y1 $l2x2 $l2y2]]} {
                                    # puts " two line segments overlap"
                                    # compute intersection
                                    # return position
                                    # puts "      -> intersect - A1: yes"
                                set posIntersect    [intersectionLineSegments [list $l1x1 $l1y1 $l1x2 $l1y2] [list $l2x1 $l2y1 $l2x2 $l2y2]]
                                if {$posIntersect eq "coincident" || $posIntersect eq "none"} {
                                    set posIntersect ""
                                }
                                    # puts "      -> \$k: $k -> [list $l1x1 $l1y1 $l1x2 $l1y2]"
                                    # puts "      -> \$l: $l -> [list $l2x1 $l2y1 $l2x2 $l2y2]"
                                    # puts "      -> intersection: $posIntersect"
                                set polyline        [join "$posIntersect $l1x2 $l1y2"]
                                    #
                            }
                            set l2x1 $l2x2; set l2y1 $l2y2
                                #
                        }
                    } else {
                        lappend polyline $l1x2 $l1y2
                    }
                        #
                    set l1x1 $l1x2; set l1y1 $l1y2
                        #
                }
            }
        }
    }
        #
        #
    return $polyline
        #
}
    #
    #
    # ::math::geometry::polylineCutEnd
    #
    # Arguments:
    #       polyline1      the first polyline
    #       polyline2      the second polyline
    #       granularity    the coarseness for the procedure
    #
    # Return:
    #       polyline       polyline from origin to cut position
    #
proc ::math::geometry::polylineCutEnd {polyline1 polyline2 {granularity 1}} {
        #
    #set granularity 10  ;   # the number of points in each part-polyline
                             #   granularity<=1 means full correctness
                             #   10 ... optimal search granularity?
    set granularity [expr {min(2,$granularity+1)}];# We need the total number of points in the section
        #
        # split the lines into parts consisting of $granularity points
    set polyline1parts {}
    for {set i 0} {$i<[llength $polyline1]} {incr i [expr {2*$granularity-2}]} {
        lappend polyline1parts [lrange $polyline1 $i [expr {$i+2*$granularity-1}]]
    }
    set polyline2parts {}
    for {set i 0} {$i<[llength $polyline2]} {incr i [expr {2*$granularity-2}]} {
        lappend polyline2parts [lrange $polyline2 $i [expr {$i+2*$granularity-1}]]
    }
        #
    set posIntersect    {}
    set polyline        [lrange $polyline1 0 1]
        #
        # do any of the parts overlap?
        #
        #
    foreach part1 $polyline1parts {
            # puts "    -> \$part1    $part1"
        set part1bbox [bbox $part1]
            #
        foreach part2 $polyline2parts {
                #puts "    -> \$part2    $part2"
            set part2bbox [bbox $part2]
                # puts "      -> \$part1bbox $part1bbox"
                # puts "      -> \$part2bbox $part2bbox"
                #
            if {[rectanglesOverlap  [lrange $part1bbox 0 1] [lrange $part1bbox 2 3]  [lrange $part2bbox 0 1] [lrange $part2bbox 2 3] 0]} {
                        # puts " the lines' bounding boxes intersect"
                foreach {l1x2 l1y2} [lassign $part1 l1x1 l1y1] {
                    foreach {l2x2 l2y2} [lassign $part2 l2x1 l2y1] {
                            #
                            # puts "  -> try   [list $l1x1 $l1y1 $l1x2 $l1y2] 	<-?->   [list $l2x1 $l2y1 $l2x2 $l2y2]"
                        if {[intersectLineSegments [list $l1x1 $l1y1 $l1x2 $l1y2] [list $l2x1 $l2y1 $l2x2 $l2y2]]} {
                                # puts " two line segments overlap"
                                # compute intersection
                                # return position
                                # puts "      -> intersect - A1: yes"
                            set posIntersect    [intersectionLineSegments [list $l1x1 $l1y1 $l1x2 $l1y2] [list $l2x1 $l2y1 $l2x2 $l2y2]]
                            if {$posIntersect eq "coincident" || $posIntersect eq "none"} {
                                continue
                            }
                                # puts "      -> \$k: $k -> [list $l1x1 $l1y1 $l1x2 $l1y2]"
                                # puts "      -> \$l: $l -> [list $l2x1 $l2y1 $l2x2 $l2y2]"
                                # puts "      ...    intersection found for part1 in part2 ->  $l1x1 $l1y1 $l1x2 $l1y2 -?- $l2x1 $l2y1 $l2x2 $l2y2"
                            lappend polyline    $posIntersect
                                #
                            return [join $polyline]
                                #
                        } else {
                            # puts "      ... no intersection found for part1 in part2 ->  $l1x1 $l1y1 $l1x2 $l1y2 -?- $l2x1 $l2y1 $l2x2 $l2y2"
                        }
                            #
                        set l2x1 $l2x2; set l2y1 $l2y2
                            #
                    }
                        #
                    lappend polyline $l1x2 $l1y2
                        #
                    set l1x1 $l1x2; set l1y1 $l1y2
                        #
                }
            } else {
                    # puts "      ... no overlap found for part1 in part2 -> [lrange $part1 2 end]"
                lappend polyline [lrange $part1 2 end]
                    #
            }
        }
            #
    }
        #
        #
    return [join $polyline]
        #
}
    #
    #
    # ::math::geometry::splitPolyline
    #
    # Arguments:
    #       polyline        the given polyline
    #
    # Return:
    #       list of segments
    #
proc ::math::geometry::splitPolyline {polyline numbVertex} {
        #
    set listSegments        {}
        #
        # puts "    -> splitPolyline"
        # puts "        -> \$numbVertex $numbVertex"
        #
    set myPolygon           [lassign $polyline x y]
        #
    set xy                  [list $x $y]
        #
    set i           0
        #
    set tmpPolyline         $xy
        #
        #
    foreach {x y} $myPolygon {
            #
        lappend tmpPolyline $x $y
            #
            # puts "   -> $i: $tmpPolyline"
            #
        if {$i < $numbVertex} {
                #
            incr i
                #
        } else {
                #
            lappend listSegments    [join $tmpPolyline]
                #
            set tmpPolyline         [list $x $y]
            set i 0
                #
        }
            #
    }
        #
    if {[lindex $listSegments end] != $tmpPolyline} {
        lappend listSegments    $tmpPolyline
    }
        #
    return $listSegments
        #
}
    #
    #
    # ::math::geometry::enrichPolyline
    #
    # Arguments:
    #       polyline      the given polyline
    #       accuracy      divide each segment into $accuracy number of segments
    #
    # Results:
    #       polyline      each segment divided in $accuracy number of segments
    #
    # Example:
    #     - enrichPolyline  {0 0  40 0  40 20  80 20} 4
    #       Result:         {0 0   10 0  20 0  30 0   40 0   40 5  40 10  40 15   40 20   50 20  60 20  70 20   80 20}
    #
proc ::math::geometry::enrichPolyline {polyline accuracy} {
        #
    set retValue    [lrange $polyline 0 1]
        #
    set accuracy    [expr {$accuracy + 0.0}] ;# Avoid division by an integer

    foreach {x2 y2} [lassign $polyline x1 y1] {
            # puts "       -> $x1 $y1  ->  $x2 $y2"
        set dx      [expr {($x2 - $x1) / $accuracy}]
        set dy      [expr {($y2 - $y1) / $accuracy}]
         for {set i 1} {$i <= $accuracy} {incr i} {
            lappend retValue [expr {$x1 + $i * $dx}] [expr {$y1 + $i * $dy}]
        }
        set x1 $x2
        set y1 $y2
    }
        #
    return $retValue
        #
}
    #
    #
    # ::math::geometry::cleanupPolyline
    #
    # remove coincidencies of neighbored points
    #
    # Arguments:
    #       polyline    the given polyline
    #
    # Results:
    #       polyline
    #
    # Example:
    #     - cleanupPolyline {0 0  40 0  40 20  40 20.0  80 20  80 20.0}
    #       Result:         {0 0  40 0  40 20  80 20}
    #
proc ::math::geometry::cleanupPolyline {polyline} {
        #
    set retValue    [lrange $polyline 0 1]
        #
    foreach {x2 y2} [lassign $polyline x1 y1] {
            # puts "       -> $x1 $y1  ->  $x2 $y2"
        if {$x2 != $x1 || $y2 != $y1} {
            # puts "     differ: $x2 -?- $x1  --- $y2  -?-  $y1"
            lappend retValue $x2 $y2
        }
        set x1 $x2
        set y1 $y2
    }
        #
    return $retValue
        #
}
    #
    #
    # ::math::geometry::pointInsideBBox
    #
    # check wether a point is inside or on BoundingBoy
    #
    # Arguments:
    #       bbox        the given polyline
    #       point       the point to be checked
    #
    # Results:
    #       0 ... totally outside bbox
    #       1 ... inside bbox
    #
    # Example:
    #     - pointInsideBBox {0 0  40 20} {20 10}
    #       Result:         1
    #     - pointInsideBBox {0 0  40 20} {30 20}
    #       Result:         1
    #     - pointInsideBBox {0 0  40 20} {50 10}
    #       Result:         0
    #
proc ::math::geometry::pointInsideBBox {bbox point} {
    lassign $bbox  bb_x0 bb_y0 bb_x1 bb_y1
    lassign $point x y
    if {$x == [lindex [lsort -real -increasing "$bb_x0 $bb_x1 $x"] 1]} {
        if {$y == [lindex [lsort -real -increasing "$bb_y0 $bb_y1 $y"] 1]} {
            return 1
        }
    }
    return 0
}
    #
    #
    # ::math::geometry::overlapBBox
    #
proc ::math::geometry::overlapBBox {polyline1 polyline2 {strict 0}} {
        # puts "   -> \$polyline1 $polyline1"
        # puts "   -> \$polyline2 $polyline2"
    set bbox1   [bbox $polyline1]
    set bbox2   [bbox $polyline2]
        # puts "         -> \$bbox1 $bbox1"
        # puts "         -> \$bbox2 $bbox2"
        # puts "         -> [::math::geometry::rectanglesOverlap  [lrange $bbox1 0 1] [lrange $bbox1 2 3]  [lrange $bbox2 0 1] [lrange $bbox2 2 3] $strict]"
    return [rectanglesOverlap  [lrange $bbox1 0 1] [lrange $bbox1 2 3]  [lrange $bbox2 0 1] [lrange $bbox2 2 3] $strict]
}

