
[//000000001]: # (math::geometry \- Tcl Math Library)
[//000000002]: # (Generated from file 'math\_geometry\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2001 by Ideogramic ApS and other parties)
[//000000004]: # (Copyright &copy; 2010 by Andreas Kupries)
[//000000005]: # (Copyright &copy; 2010 by Kevin Kenny)
[//000000006]: # (Copyright &copy; 2018 by Arjen Markus)
[//000000007]: # (Copyright &copy; 2020 by Manfred Rosenberger)
[//000000008]: # (math::geometry\(n\) 1\.4\.1 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::geometry \- Geometrical computations

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PROCEDURES](#section2)

  - [COORDINATE SYSTEM](#section3)

  - [References](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl ?8\.5?  
package require math::geometry ?1\.4\.1?  

[__::math::geometry::\+__ *point1* *point2*](#1)  
[__::math::geometry::\-__ *point1* *point2*](#2)  
[__::math::geometry::p__ *x* *y*](#3)  
[__::math::geometry::distance__ *point1* *point2*](#4)  
[__::math::geometry::length__ *point*](#5)  
[__::math::geometry::s\*__ *factor* *point*](#6)  
[__::math::geometry::direction__ *angle*](#7)  
[__::math::geometry::h__ *length*](#8)  
[__::math::geometry::v__ *length*](#9)  
[__::math::geometry::between__ *point1* *point2* *s*](#10)  
[__::math::geometry::octant__ *point*](#11)  
[__::math::geometry::rect__ *nw* *se*](#12)  
[__::math::geometry::nwse__ *rect*](#13)  
[__::math::geometry::angle__ *line*](#14)  
[__::math::geometry::angleBetween__ *vector1* *vector2*](#15)  
[__::math::geometry::inproduct__ *vector1* *vector2*](#16)  
[__::math::geometry::areaParallellogram__ *vector1* *vector2*](#17)  
[__::math::geometry::calculateDistanceToLine__ *P* *line*](#18)  
[__::math::geometry::calculateDistanceToLineSegment__ *P* *linesegment*](#19)  
[__::math::geometry::calculateDistanceToPolyline__ *P* *polyline*](#20)  
[__::math::geometry::calculateDistanceToPolygon__ *P* *polygon*](#21)  
[__::math::geometry::findClosestPointOnLine__ *P* *line*](#22)  
[__::math::geometry::findClosestPointOnLineSegment__ *P* *linesegment*](#23)  
[__::math::geometry::findClosestPointOnPolyline__ *P* *polyline*](#24)  
[__::math::geometry::lengthOfPolyline__ *polyline*](#25)  
[__::math::geometry::movePointInDirection__ *P* *direction* *dist*](#26)  
[__::math::geometry::lineSegmentsIntersect__ *linesegment1* *linesegment2*](#27)  
[__::math::geometry::findLineSegmentIntersection__ *linesegment1* *linesegment2*](#28)  
[__::math::geometry::findLineIntersection__ *line1* *line2*](#29)  
[__::math::geometry::polylinesIntersect__ *polyline1* *polyline2*](#30)  
[__::math::geometry::polylinesBoundingIntersect__ *polyline1* *polyline2* *granularity*](#31)  
[__::math::geometry::intervalsOverlap__ *y1* *y2* *y3* *y4* *strict*](#32)  
[__::math::geometry::rectanglesOverlap__ *P1* *P2* *Q1* *Q2* *strict*](#33)  
[__::math::geometry::bbox__ *polyline*](#34)  
[__::math::geometry::overlapBBox__ *polyline1* *polyline2* ?strict?](#35)  
[__::math::geometry::pointInsideBBox__ *bbox* *point*](#36)  
[__::math::geometry::cathetusPoint__ *pa* *pb* *cathetusLength* ?location?](#37)  
[__::math::geometry::parallel__ *line* *offset* ?orient?](#38)  
[__::math::geometry::unitVector__ *line*](#39)  
[__::math::geometry::pointInsidePolygon__ *P* *polyline*](#40)  
[__::math::geometry::pointInsidePolygonAlt__ *P* *polyline*](#41)  
[__::math::geometry::rectangleInsidePolygon__ *P1* *P2* *polyline*](#42)  
[__::math::geometry::areaPolygon__ *polygon*](#43)  
[__::math::geometry::translate__ *vector* *polyline*](#44)  
[__::math::geometry::rotate__ *angle* *polyline*](#45)  
[__::math::geometry::rotateAbout__ *p* *angle* *polyline*](#46)  
[__::math::geometry::reflect__ *angle* *polyline*](#47)  
[__::math::geometry::degToRad__ *angle*](#48)  
[__::math::geometry::radToDeg__ *angle*](#49)  
[__::math::geometry::circle__ *centre* *radius*](#50)  
[__::math::geometry::circleTwoPoints__ *point1* *point2*](#51)  
[__::math::geometry::pointInsideCircle__ *point* *circle*](#52)  
[__::math::geometry::lineIntersectsCircle__ *line* *circle*](#53)  
[__::math::geometry::lineSegmentIntersectsCircle__ *segment* *circle*](#54)  
[__::math::geometry::intersectionLineWithCircle__ *line* *circle*](#55)  
[__::math::geometry::intersectionCircleWithCircle__ *circle1* *circle2*](#56)  
[__::math::geometry::tangentLinesToCircle__ *point* *circle*](#57)  
[__::math::geometry::intersectionPolylines__ *polyline1* *polyline2* ?mode? ?granularity?](#58)  
[__::math::geometry::intersectionPolylineCircle__ *polyline* *circle* ?mode? ?granularity?](#59)  
[__::math::geometry::polylineCutOrigin__ *polyline1* *polyline2* ?granularity?](#60)  
[__::math::geometry::polylineCutEnd__ *polyline1* *polyline2* ?granularity?](#61)  
[__::math::geometry::splitPolyline__ *polyline* *numberVertex*](#62)  
[__::math::geometry::enrichPolyline__ *polyline* *accuracy*](#63)  
[__::math::geometry::cleanupPolyline__ *polyline*](#64)  

# <a name='description'></a>DESCRIPTION

The __math::geometry__ package is a collection of functions for computations
and manipulations on two\-dimensional geometrical objects, such as points, lines
and polygons\.

The geometrical objects are implemented as plain lists of coordinates\. For
instance a line is defined by a list of four numbers, the x\- and y\-coordinate of
a first point and the x\- and y\-coordinates of a second point on the line\.

*Note:* In version 1\.4\.0 an inconsistency was repaired \- see
[https://core\.tcl\-lang\.org/tcllib/tktview?name=fb4812f82b](https://core\.tcl\-lang\.org/tcllib/tktview?name=fb4812f82b)\.
More in [COORDINATE SYSTEM](#section3)

The various types of object are recognised by the number of coordinate pairs and
the context in which they are used: a list of four elements can be regarded as
an infinite line, a finite line segment but also as a polyline of one segment
and a point set of two points\.

Currently the following types of objects are distinguished:

  - *point* \- a list of two coordinates representing the x\- and y\-coordinates
    respectively\.

  - *line* \- a list of four coordinates, interpreted as the x\- and
    y\-coordinates of two distinct points on the line\.

  - *line segment* \- a list of four coordinates, interpreted as the x\- and
    y\-coordinates of the first and the last points on the line segment\.

  - *polyline* \- a list of an even number of coordinates, interpreted as the
    x\- and y\-coordinates of an ordered set of points\.

  - *polygon* \- like a polyline, but the implicit assumption is that the
    polyline is closed \(if the first and last points do not coincide, the
    missing segment is automatically added\)\.

  - *point set* \- again a list of an even number of coordinates, but the
    points are regarded without any ordering\.

  - *circle* \- a list of three numbers, the first two are the coordinates of
    the centre and the third is the radius\.

# <a name='section2'></a>PROCEDURES

The package defines the following public procedures:

  - <a name='1'></a>__::math::geometry::\+__ *point1* *point2*

    Compute the sum of the two vectors given as points and return it\. The result
    is a vector as well\.

  - <a name='2'></a>__::math::geometry::\-__ *point1* *point2*

    Compute the difference \(point1 \- point2\) of the two vectors given as points
    and return it\. The result is a vector as well\.

  - <a name='3'></a>__::math::geometry::p__ *x* *y*

    Construct a point from its coordinates and return it as the result of the
    command\.

  - <a name='4'></a>__::math::geometry::distance__ *point1* *point2*

    Compute the distance between the two points and return it as the result of
    the command\. This is in essence the same as

        math::geometry::length [math::geomtry::- point1 point2]

  - <a name='5'></a>__::math::geometry::length__ *point*

    Compute the length of the vector and return it as the result of the command\.

  - <a name='6'></a>__::math::geometry::s\*__ *factor* *point*

    Scale the vector by the factor and return it as the result of the command\.
    This is a vector as well\.

  - <a name='7'></a>__::math::geometry::direction__ *angle*

    Given the angle in degrees this command computes and returns the unit vector
    pointing into this direction\. The vector for angle == 0 points to the right
    \(east\), and for angle == 90 up \(north\)\.

  - <a name='8'></a>__::math::geometry::h__ *length*

    Returns a horizontal vector on the X\-axis of the specified length\. Positive
    lengths point to the right \(east\)\.

  - <a name='9'></a>__::math::geometry::v__ *length*

    Returns a vertical vector on the Y\-axis of the specified length\. Positive
    lengths point down \(south\)\.

  - <a name='10'></a>__::math::geometry::between__ *point1* *point2* *s*

    Compute the point which is at relative distance *s* between the two points
    and return it as the result of the command\. A relative distance of __0__
    returns *point1*, the distance __1__ returns *point2*\. Distances < 0
    or > 1 extrapolate along the line between the two point\.

  - <a name='11'></a>__::math::geometry::octant__ *point*

    Compute the octant of the circle the point is in and return it as the result
    of the command\. The possible results are

      1. east

      1. northeast

      1. north

      1. northwest

      1. west

      1. southwest

      1. south

      1. southeast

    Each octant is the arc of the circle \+/\- 22\.5 degrees from the cardinal
    direction the octant is named for\.

  - <a name='12'></a>__::math::geometry::rect__ *nw* *se*

    Construct a rectangle from its northwest and southeast corners and return it
    as the result of the command\.

  - <a name='13'></a>__::math::geometry::nwse__ *rect*

    Extract the northwest and southeast corners of the rectangle and return them
    as the result of the command \(a 2\-element list containing the points, in the
    named order\)\.

  - <a name='14'></a>__::math::geometry::angle__ *line*

    Calculate the angle from the positive x\-axis to a given line \(in two
    dimensions only\)\.

      * list *line*

        Coordinates of the line

  - <a name='15'></a>__::math::geometry::angleBetween__ *vector1* *vector2*

    Calculate the angle between two vectors \(in degrees\)

      * list *vector1*

        First vector

      * list *vector2*

        Second vector

  - <a name='16'></a>__::math::geometry::inproduct__ *vector1* *vector2*

    Calculate the inner product of two vectors

      * list *vector1*

        First vector

      * list *vector2*

        Second vector

  - <a name='17'></a>__::math::geometry::areaParallellogram__ *vector1* *vector2*

    Calculate the area of the parallellogram with the two vectors as its sides

      * list *vector1*

        First vector

      * list *vector2*

        Second vector

  - <a name='18'></a>__::math::geometry::calculateDistanceToLine__ *P* *line*

    Calculate the distance of point P to the \(infinite\) line and return the
    result

      * list *P*

        List of two numbers, the coordinates of the point

      * list *line*

        List of four numbers, the coordinates of two points on the line

  - <a name='19'></a>__::math::geometry::calculateDistanceToLineSegment__ *P* *linesegment*

    Calculate the distance of point P to the \(finite\) line segment and return
    the result\.

      * list *P*

        List of two numbers, the coordinates of the point

      * list *linesegment*

        List of four numbers, the coordinates of the first and last points of
        the line segment

  - <a name='20'></a>__::math::geometry::calculateDistanceToPolyline__ *P* *polyline*

    Calculate the distance of point P to the polyline and return the result\.
    Note that a polyline needs not to be closed\.

      * list *P*

        List of two numbers, the coordinates of the point

      * list *polyline*

        List of numbers, the coordinates of the vertices of the polyline

  - <a name='21'></a>__::math::geometry::calculateDistanceToPolygon__ *P* *polygon*

    Calculate the distance of point P to the polygon and return the result\. If
    the list of coordinates is not closed \(first and last points differ\), it is
    automatically closed\.

      * list *P*

        List of two numbers, the coordinates of the point

      * list *polygon*

        List of numbers, the coordinates of the vertices of the polygon

  - <a name='22'></a>__::math::geometry::findClosestPointOnLine__ *P* *line*

    Return the point on a line which is closest to a given point\.

      * list *P*

        List of two numbers, the coordinates of the point

      * list *line*

        List of four numbers, the coordinates of two points on the line

  - <a name='23'></a>__::math::geometry::findClosestPointOnLineSegment__ *P* *linesegment*

    Return the point on a *line segment* which is closest to a given point\.

      * list *P*

        List of two numbers, the coordinates of the point

      * list *linesegment*

        List of four numbers, the first and last points on the line segment

  - <a name='24'></a>__::math::geometry::findClosestPointOnPolyline__ *P* *polyline*

    Return the point on a *polyline* which is closest to a given point\.

      * list *P*

        List of two numbers, the coordinates of the point

      * list *polyline*

        List of numbers, the vertices of the polyline

  - <a name='25'></a>__::math::geometry::lengthOfPolyline__ *polyline*

    Return the length of the *polyline* \(note: it not regarded as a polygon\)

      * list *polyline*

        List of numbers, the vertices of the polyline

  - <a name='26'></a>__::math::geometry::movePointInDirection__ *P* *direction* *dist*

    Move a point over a given distance in a given direction and return the new
    coordinates \(in two dimensions only\)\.

      * list *P*

        Coordinates of the point to be moved

      * double *direction*

        Direction \(in degrees; 0 is to the right, 90 upwards\)

      * list *dist*

        Distance over which to move the point

  - <a name='27'></a>__::math::geometry::lineSegmentsIntersect__ *linesegment1* *linesegment2*

    Check if two line segments intersect or coincide\. Returns 1 if that is the
    case, 0 otherwise \(in two dimensions only\)\. If an endpoint of one segment
    lies on the other segment \(or is very close to the segment\), they are
    considered to intersect

      * list *linesegment1*

        First line segment

      * list *linesegment2*

        Second line segment

  - <a name='28'></a>__::math::geometry::findLineSegmentIntersection__ *linesegment1* *linesegment2*

    Find the intersection point of two line segments\. Return the coordinates or
    the keywords "coincident" or "none" if the line segments coincide or have no
    points in common \(in two dimensions only\)\.

      * list *linesegment1*

        First line segment

      * list *linesegment2*

        Second line segment

  - <a name='29'></a>__::math::geometry::findLineIntersection__ *line1* *line2*

    Find the intersection point of two \(infinite\) lines\. Return the coordinates
    or the keywords "coincident" or "none" if the lines coincide or have no
    points in common \(in two dimensions only\)\.

      * list *line1*

        First line

      * list *line2*

        Second line

    See section [References](#section4) for details on the algorithm and
    math behind it\.

  - <a name='30'></a>__::math::geometry::polylinesIntersect__ *polyline1* *polyline2*

    Check if two polylines intersect or not \(in two dimensions only\)\.

      * list *polyline1*

        First polyline

      * list *polyline2*

        Second polyline

  - <a name='31'></a>__::math::geometry::polylinesBoundingIntersect__ *polyline1* *polyline2* *granularity*

    Check whether two polylines intersect, but reduce the correctness of the
    result to the given granularity\. Use this for faster, but weaker,
    intersection checking\.

    How it works:

    Each polyline is split into a number of smaller polylines, consisting of
    granularity points each\. If a pair of those smaller lines' bounding boxes
    intersect, then this procedure returns 1, otherwise it returns 0\.

      * list *polyline1*

        First polyline

      * list *polyline2*

        Second polyline

      * int *granularity*

        Number of points in each part \(<=1 means check every edge\)

  - <a name='32'></a>__::math::geometry::intervalsOverlap__ *y1* *y2* *y3* *y4* *strict*

    Check if two intervals overlap\.

      * double *y1,y2*

        Begin and end of first interval

      * double *y3,y4*

        Begin and end of second interval

      * logical *strict*

        Check for strict or non\-strict overlap

  - <a name='33'></a>__::math::geometry::rectanglesOverlap__ *P1* *P2* *Q1* *Q2* *strict*

    Check if two rectangles overlap\.

      * list *P1*

        upper\-left corner of the first rectangle

      * list *P2*

        lower\-right corner of the first rectangle

      * list *Q1*

        upper\-left corner of the second rectangle

      * list *Q2*

        lower\-right corner of the second rectangle

      * list *strict*

        choosing strict or non\-strict interpretation

  - <a name='34'></a>__::math::geometry::bbox__ *polyline*

    Calculate the bounding box of a polyline\. Returns a list of four
    coordinates: the upper\-left and the lower\-right corner of the box\.

      * list *polyline*

        The polyline to be examined

  - <a name='35'></a>__::math::geometry::overlapBBox__ *polyline1* *polyline2* ?strict?

    Check if the bounding boxes of two polylines overlap or not\.

    Arguments:

      * list *polyline1*

        The first polyline

      * list *polyline1*

        The second polyline

      * int *strict*

        Whether strict overlap is to checked \(1\) or if the bounding boxes may
        touch \(0, default\)

  - <a name='36'></a>__::math::geometry::pointInsideBBox__ *bbox* *point*

    Check if the point is inside or on the bounding box or not\. Arguments:

      * list *bbox*

        The bounding box given as a list of x/y coordinates

      * list *point*

        The point to be checked

  - <a name='37'></a>__::math::geometry::cathetusPoint__ *pa* *pb* *cathetusLength* ?location?

    Return the third point of the rectangular triangle defined by the two given
    end points of the hypothenusa\. The triangle's side from point A \(or B, if
    the location is given as "b"\) to the third point is the cathetus length\. If
    the cathetus' length is lower than the length of the hypothenusa, an empty
    list is returned\.

    Arguments:

      * list *pa*

        The starting point on hypotenuse

      * list *pb*

        The ending point on hypotenuse

      * float *cathetusLength*

        The length of the cathetus of the triangle

      * string *location*

        The location of the given cathetus, "a" means given cathetus shares
        point pa \(default\) "b" means given cathetus shares point pb

  - <a name='38'></a>__::math::geometry::parallel__ *line* *offset* ?orient?

    Return a line parallel to the given line, with a distance "offset"\. The
    orientation is determined by the two points defining the line\.

    Arguments:

      * list *line*

        The given line

      * float *offset*

        The distance to the given line

      * string *orient*

        Orientation of the new line with respect to the given line \(defaults to
        "right"\)

  - <a name='39'></a>__::math::geometry::unitVector__ *line*

    Return a unit vector from the given line or direction, if the
    *[line](\.\./\.\./\.\./\.\./index\.md\#line)* argument is a single point \(then a
    line through the origin is assumed\) Arguments:

      * list *line*

        The line in question \(or a single point, implying a line through the
        origin\)

  - <a name='40'></a>__::math::geometry::pointInsidePolygon__ *P* *polyline*

    Determine if a point is completely inside a polygon\. If the point touches
    the polygon, then the point is not completely inside the polygon\.

      * list *P*

        Coordinates of the point

      * list *polyline*

        The polyline to be examined

  - <a name='41'></a>__::math::geometry::pointInsidePolygonAlt__ *P* *polyline*

    Determine if a point is completely inside a polygon\. If the point touches
    the polygon, then the point is not completely inside the polygon\. *Note:*
    this alternative procedure uses the so\-called winding number to determine
    this\. It handles self\-intersecting polygons in a "natural" way\.

      * list *P*

        Coordinates of the point

      * list *polyline*

        The polyline to be examined

  - <a name='42'></a>__::math::geometry::rectangleInsidePolygon__ *P1* *P2* *polyline*

    Determine if a rectangle is completely inside a polygon\. If polygon touches
    the rectangle, then the rectangle is not complete inside the polygon\.

      * list *P1*

        Upper\-left corner of the rectangle

      * list *P2*

        Lower\-right corner of the rectangle

      * list *polygon*

        The polygon in question

  - <a name='43'></a>__::math::geometry::areaPolygon__ *polygon*

    Calculate the area of a polygon\.

      * list *polygon*

        The polygon in question

  - <a name='44'></a>__::math::geometry::translate__ *vector* *polyline*

    Translate a polyline over a given vector

      * list *vector*

        Translation vector

      * list *polyline*

        The polyline to be translated

  - <a name='45'></a>__::math::geometry::rotate__ *angle* *polyline*

    Rotate a polyline over a given angle \(degrees\) around the origin

      * list *angle*

        Angle over which to rotate the polyline \(degrees\)

      * list *polyline*

        The polyline to be rotated

  - <a name='46'></a>__::math::geometry::rotateAbout__ *p* *angle* *polyline*

    Rotate a polyline around a given point p and return the new polyline\.

    Arguments:

      * list *p*

        The point of rotation

      * float *angle*

        The angle over which to rotate the polyline \(degrees\)

      * list *polyline*

        The polyline to be rotated

  - <a name='47'></a>__::math::geometry::reflect__ *angle* *polyline*

    Reflect a polyline in a line through the origin at a given angle \(degrees\)
    to the x\-axis

      * list *angle*

        Angle of the line of reflection \(degrees\)

      * list *polyline*

        The polyline to be reflected

  - <a name='48'></a>__::math::geometry::degToRad__ *angle*

    Convert from degrees to radians

      * list *angle*

        Angle in degrees

  - <a name='49'></a>__::math::geometry::radToDeg__ *angle*

    Convert from radians to degrees

      * list *angle*

        Angle in radians

  - <a name='50'></a>__::math::geometry::circle__ *centre* *radius*

    Convenience procedure to create a circle from a point and a radius\.

      * list *centre*

        Coordinates of the circle centre

      * list *radius*

        Radius of the circle

  - <a name='51'></a>__::math::geometry::circleTwoPoints__ *point1* *point2*

    Convenience procedure to create a circle from two points on its
    circumference The centre is the point between the two given points, the
    radius is half the distance between them\.

      * list *point1*

        First point

      * list *point2*

        Second point

  - <a name='52'></a>__::math::geometry::pointInsideCircle__ *point* *circle*

    Determine if the given point is inside the circle or on the circumference
    \(1\) or outside \(0\)\.

      * list *point*

        Point to be checked

      * list *circle*

        Circle that may or may not contain the point

  - <a name='53'></a>__::math::geometry::lineIntersectsCircle__ *line* *circle*

    Determine if the given line intersects the circle or touches it \(1\) or does
    not \(0\)\.

      * list *line*

        Line to be checked

      * list *circle*

        Circle that may or may not be intersected

  - <a name='54'></a>__::math::geometry::lineSegmentIntersectsCircle__ *segment* *circle*

    Determine if the given line segment intersects the circle or touches it \(1\)
    or does not \(0\)\.

      * list *segment*

        Line segment to be checked

      * list *circle*

        Circle that may or may not be intersected

  - <a name='55'></a>__::math::geometry::intersectionLineWithCircle__ *line* *circle*

    Determine the points at which the given line intersects the circle\. There
    can be zero, one or two points\. \(If the line touches the circle or is close
    to it, then one point is returned\. An arbitrary margin of 1\.0e\-10 times the
    radius is used to determine this situation\.\)

      * list *line*

        Line to be checked

      * list *circle*

        Circle that may or may not be intersected

  - <a name='56'></a>__::math::geometry::intersectionCircleWithCircle__ *circle1* *circle2*

    Determine the points at which the given two circles intersect\. There can be
    zero, one or two points\. \(If the two circles touch the circle or are very
    close, then one point is returned\. An arbitrary margin of 1\.0e\-10 times the
    mean of the radii of the two circles is used to determine this situation\.\)

      * list *circle1*

        First circle

      * list *circle2*

        Second circle

  - <a name='57'></a>__::math::geometry::tangentLinesToCircle__ *point* *circle*

    Determine the tangent lines from the given point to the circle\. There can be
    zero, one or two lines\. \(If the point is on the cirucmference or very close
    to the circle, then one line is returned\. An arbitrary margin of 1\.0e\-10
    times the radius of the circle is used to determine this situation\.\)

      * list *point*

        Point in question

      * list *circle*

        Circle to which the tangent lines are to be determined

  - <a name='58'></a>__::math::geometry::intersectionPolylines__ *polyline1* *polyline2* ?mode? ?granularity?

    Return the first point or all points where the two polylines intersect\. If
    the number of points in the polylines is large, you can use the granularity
    to get an approximate answer faster\.

    Arguments:

      * list *polyline1*

        The first polyline

      * list *polyline2*

        The second polyline

      * string *mode*

        Whether to return only the first \(default\) or to return all intersection
        points \("all"\)

      * int *granularity*

        The number of points that will be skipped plus 1 in the search for
        intersection points \(1 or smaller means an exact answer is returned\)

  - <a name='59'></a>__::math::geometry::intersectionPolylineCircle__ *polyline* *circle* ?mode? ?granularity?

    Return the first point or all points where the polyline intersects the
    circle\. If the number of points in the polyline is large, you can use the
    granularity to get an approximate answer faster\.

    Arguments:

      * list *polyline*

        The polyline that may intersect the circle

      * list *circle*

        The circle in question

      * string *mode*

        Whether to return only the first \(default\) or to return all intersection
        points \("all"\)

      * int *granularity*

        The number of points that will be skipped plus 1 in the search for
        intersection points \(1 or smaller means an exact answer is returned\)

  - <a name='60'></a>__::math::geometry::polylineCutOrigin__ *polyline1* *polyline2* ?granularity?

    Return the part of the first polyline from the origin up to the first
    intersection with the second\. If the number of points in the polyline is
    large, you can use the granularity to get an approximate answer faster\.

    Arguments:

      * list *polyline1*

        The first polyline \(from which a part is to be returned\)

      * list *polyline2*

        The second polyline

      * int *granularity*

        The number of points that will be skipped plus 1 in the search for
        intersection points \(1 or smaller means an exact answer is returned\)

  - <a name='61'></a>__::math::geometry::polylineCutEnd__ *polyline1* *polyline2* ?granularity?

    Return the part of the first polyline from the last intersection point with
    the second to the end\. If the number of points in the polyline is large, you
    can use the granularity to get an approximate answer faster\.

    Arguments:

      * list *polyline1*

        The first polyline \(from which a part is to be returned\)

      * list *polyline2*

        The second polyline

      * int *granularity*

        The number of points that will be skipped plus 1 in the search for
        intersection points \(1 or smaller means an exact answer is returned\)

  - <a name='62'></a>__::math::geometry::splitPolyline__ *polyline* *numberVertex*

    Split the poyline into a set of polylines where each separate polyline holds
    "numberVertex" vertices between the two end points\.

    Arguments:

      * list *polyline*

        The polyline to be split up

      * int *numberVertex*

        The number of "internal" vertices

  - <a name='63'></a>__::math::geometry::enrichPolyline__ *polyline* *accuracy*

    Split up each segment of a polyline into a number of smaller segments and
    return the result\.

    Arguments:

      * list *polyline*

        The polyline to be refined

      * int *accuracy*

        The number of subsegments to be created

  - <a name='64'></a>__::math::geometry::cleanupPolyline__ *polyline*

    Remove duplicate neighbouring vertices and return the result\.

    Arguments:

      * list *polyline*

        The polyline to be cleaned up

# <a name='section3'></a>COORDINATE SYSTEM

The coordinate system used by the package is the ordinary cartesian system,
where the positive x\-axis is directed to the right and the positive y\-axis is
directed upwards\. Angles and directions are defined with respect to the positive
x\-axis in a counter\-clockwise direction, so that an angle of 90 degrees is the
direction of the positive y\-axis\. Note that the Tk canvas coordinates differ
from this, as there the origin is located in the upper left corner of the
window\. Up to and including version 1\.3, the direction and octant procedures of
this package used this convention inconsistently\.

# <a name='section4'></a>References

  1. [Polygon Intersection](http:/wiki\.tcl\.tk/12070)

  1. [http://en\.wikipedia\.org/wiki/Line\-line\_intersection](http://en\.wikipedia\.org/wiki/Line\-line\_intersection)

  1. [http://local\.wasp\.uwa\.edu\.au/~pbourke/geometry/lineline2d/](http://local\.wasp\.uwa\.edu\.au/~pbourke/geometry/lineline2d/)

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: geometry* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[angle](\.\./\.\./\.\./\.\./index\.md\#angle),
[distance](\.\./\.\./\.\./\.\./index\.md\#distance),
[line](\.\./\.\./\.\./\.\./index\.md\#line), [math](\.\./\.\./\.\./\.\./index\.md\#math),
[plane geometry](\.\./\.\./\.\./\.\./index\.md\#plane\_geometry),
[point](\.\./\.\./\.\./\.\./index\.md\#point)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2001 by Ideogramic ApS and other parties  
Copyright &copy; 2010 by Andreas Kupries  
Copyright &copy; 2010 by Kevin Kenny  
Copyright &copy; 2018 by Arjen Markus  
Copyright &copy; 2020 by Manfred Rosenberger
