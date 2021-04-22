# geometry_circle.tcl --
#
#     Geometry functions with an emphasis on circles
#
# Copyright (c) 2018 Arjen Markus
#
#     Part of the math::geometry package
#

package require Tcl 8.5
package require math

namespace eval ::math::geometry {
    namespace export circle circleTwoPoints \
        pointInsideCircle lineIntersectsCircle lineSegmentIntersectsCircle \
        intersectionLineWithCircle intersectionCircleWithCircle tangentLinesToCircle \


    variable margin 1.0e-10
}

# circles:
#     List of three numbers, the first two are the x and y coordinates of the
#     centre, the third is the radius
#

# circle --
#     Return a list of numbers representing a circle
#
# Arguments:
#     point         Coordinates of the centre
#     radius        Radius of the circle
#
# Returns:
#     Three-element list
#
proc ::math::geometry::circle {point radius} {
    if { [llength $point] != 2 } {
        return -code error "The first argument must be a point"
    }
    if { [llength $radius] != 1 } {
        return -code error "The second argument must be a single value"
    }

    return [concat $point $radius]
}

# circleTwoPoints --
#     Construct a circle from two points - they appear on the circumference
#
# Arguments:
#     point1        Coordinates of one point
#     point2        Coordinates of the second point
#
# Returns:
#     Three-element list
#
proc ::math::geometry::circleTwoPoints {point1 point2} {
    set centre [s* 0.5 [+ $point1 $point2]]
    set radius [expr {[distance $point1 $point2] * 0.5}]


    return [concat $centre $radius]
}

# pointInsideCircle --
#     Return whether the given point lies in the circle or not
#
# Arguments:
#     point         Point to be checked
#     circle        Circle possibly containing the point
#
# Returns:
#     1 if the point lies in or on the circle
#     0 if not
#
proc ::math::geometry::pointInsideCircle {point circle} {
    set centre [lrange $circle 0 1]
    set radius [lindex $circle end]

    if { [distance $point $centre] <= $radius } {
        return 1
    } else {
        return 0
    }
}

# lineIntersectsCircle --
#     Return whether the given (infinite) line intersects the circle or not
#
# Arguments:
#     line          Infinite line to be checked
#     circle        Circle to be checked
#
# Returns:
#     1 if the line intersects the circle or is tangent to it
#     0 if not
#
proc ::math::geometry::lineIntersectsCircle {line circle} {
    set centre [lrange $circle 0 1]
    set radius [lindex $circle end]

    if { [calculateDistanceToLine $centre $line] <= $radius } {
        return 1
    } else {
        return 0
    }
}

# lineSegmentIntersectsCircle --
#     Return whether the given line segment intersects the circle or not
#
# Arguments:
#     line          Line segment to be checked
#     circle        Circle to be checked
#
# Returns:
#     1 if the line segment intersects the circle or is tangent to it
#     0 if not
#
proc ::math::geometry::lineSegmentIntersectsCircle {line circle} {
    set centre [lrange $circle 0 1]
    set radius [lindex $circle end]

    if { [calculateDistanceToLineSegment $centre $line] <= $radius } {
        #
        # Check that not both end points are inside the circle
        #
        set point1  [lrange $line 0 1]
        set point2  [lrange $line 2 3]

        set inside1 [pointInsideCircle $point1 $circle]
        set inside2 [pointInsideCircle $point2 $circle]

        return [expr {$inside1+$inside2 <= 1 ? 1 : 0}]
    } else {
        return 0
    }
}

# IntersectionVerticallineCircle --
#     Calculate the intersection points of a vertical line and a circle
#
# Arguments:
#     line          Vertical line right of y-axis
#     circle        Circle with centre at (0,0)
#
# Returns:
#     Zero, one or two points - the intersection points
#
# Note:
#     The procedure is easiest when using a horizontal or vertical
#     line and a circle with centre (0,0). To be used in combination
#     with suitable transformations.
#
proc ::math::geometry::IntersectionVerticalLineCircle {line circle} {
    set radius [lindex $circle end]
    set xval   [lindex $line 0]

    if { $xval > $radius } {
        return {}
    } elseif { $xval == $radius } {
        return [list $radius 0.0]
    }

    set yval   [expr {sqrt($radius**2 - $xval**2)}]

    return [list [list $xval $yval] [list $xval [expr {-$yval}]]]
}

# IntersectionCircleCircle --
#     Calculate the intersection points of two circles
#
# Arguments:
#     circle        Circle with centre at (0,0)
#     circle1       Circle with centre on positive x-axis
#
# Returns:
#     Zero, one or two points - the intersection points
#
# Note:
#     The procedure is easiest when using a circle with centre (0,0)
#     and the other with the centre on an axis. To be used in combination
#     with suitable transformations.
#
# Note:
#     The situation of two identical circles is not handled
#
proc ::math::geometry::IntersectionCircleCircle {circle1 circle2} {
    set radius1 [lindex $circle1 end]
    set xval    [lindex $circle2 0]
    set radius2 [lindex $circle2 end]

    if { $xval - $radius2 > $radius1 } {
        return {}
    } elseif { $xval - $radius2 == $radius1 } {
        return [list $radius1 0.0]
    } elseif { $xval - $radius2 == -$radius1 } {
        return [list -$radius1 0.0]
    } else {
        # One circle inside the other circle
        if { $radius2 > $radius1 } {
            if { $xval - $radius2 < -$radius1 } {
                return {}
            }
        } else {
            if { $xval + $radius2 < $radius1 } {
                return {}
            }
        }
    }

    set b [expr {0.5 * ($xval + ($radius1**2 - $radius2**2)/$xval) }]

    set yval [expr {sqrt($radius1**2 - $b**2)}]

    return [list [list $b $yval] [list $b [expr {-$yval}]]]
}

# intersectionLineWithCircle --
#     Determine the points of intersection between a line and a circle
#
# Arguments:
#     line          Line in question
#     circle        Circle in question
#
# Returns:
#     Zero, one or two points - the intersection points
#
# Note:
#     Shift and rotate the line and circle first, then determine the
#     intersection and transform back.
#
proc ::math::geometry::intersectionLineWithCircle {line circle} {
    variable margin

    set centre [lrange $circle 0 1]
    set radius [lindex $circle end]

    set midpoint [findClosestPointOnLine $centre $line]
    set distance [distance $midpoint $centre]

    if { $distance > $margin*$radius } { ;# Rather arbitrary margin
        set vector   [s* [expr {1.0/$distance}] [- $midpoint $centre]]
    } else {
        lassign $line x1 y1 x2 y2
        set vector    [list [expr {$y2-$y1}] [expr {$x1-$x2}]]
        set distance2 [length $vector]
        set vector    [s* [expr {1.0/$distance2}] $vector]
    }

    set newline      [list $distance [expr {1.0+$radius}] $distance [expr {-1.0-$radius}]]
    set intersection [IntersectionVerticalLineCircle $newline $circle]

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

    return $newIntersection
}

# intersectionCircleWithCircle --
#     Determine the points of intersection between two circles
#
# Arguments:
#     circle1       First circle
#     circle2       Second circle
#
# Returns:
#     Zero, one or two points - the intersection points
#
# Note:
#     Shift and rotate the circles first, then determine the
#     intersection and transform back.
#
proc ::math::geometry::intersectionCircleWithCircle {circle1 circle2} {
    variable margin

    set centre1 [lrange $circle1 0 1]
    set radius1 [lindex $circle1 end]
    set centre2 [lrange $circle2 0 1]
    set radius2 [lindex $circle2 end]

    set distance [distance $centre1 $centre2]

    if { $distance > 0.5*$margin*($radius1+$radius2) } { ;# Rather arbitrary margin
        set vector   [s* [expr {1.0/$distance}] [- $centre2 $centre1]]
    } else {
        return {} ;# Bit of a hack: either the circles are concentric and have different
                   # radii - no intersection - or they are identical, then we should
                   # return the complete circle, but we don't do that ...
    }

    set newcircle    [list $distance 0.0 $radius2]
    set intersection [IntersectionCircleCircle $circle1 $newcircle]

    set newIntersection {}
    lassign $vector  vx vy
    lassign $centre1 cx cy
    if { [llength [lindex $intersection 0]] == 1 } {
        set intersection [list $intersection]
    }
    foreach xy $intersection {
        lassign $xy x y

        set xn [expr {$vx * $x - $vy * $y + $cx}]
        set yn [expr {$vy * $x + $vx * $y + $cy}]

        lappend newIntersection [list $xn $yn]
    }

    return $newIntersection
}

# tangentLinesToCircle --
#     Determine the tangents from a point to a circle
#
# Arguments:
#     point         Point in question
#     circle        Second circle
#
# Returns:
#     Zero, one or two points - the intersection points
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
