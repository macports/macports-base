# mapproj.tcl --
#
#	Package for map projections.
#
# Copyright (c) 2007 by Kevin B. Kenny.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: mapproj.tcl,v 1.1 2007/08/24 22:36:35 kennykb Exp $
#------------------------------------------------------------------------------

package require Tcl 8.4
package require math::interpolate 1.0
package require math::special 0.2.1

package provide mapproj 1.0

# ::mapproj --
#
#	Namespace holding the procedures and values.

namespace eval ::mapproj {

    # Cylindrical projections

    namespace export toPlateCarree fromPlateCarree
    namespace export toCassini fromCassini
    namespace export toCylindricalEqualArea fromCylindricalEqualArea
    namespace export toMercator fromMercator

    # Named cylindric equal-area projections with specific
    # standard parallels

    namespace export toLambertCylindricalEqualArea \
	fromLambertCylindricalEqualArea
    namespace export toBehrmann fromBehrmann
    namespace export toTrystanEdwards fromTrystanEdwards
    namespace export toHoboDyer fromHoboDyer
    namespace export toGallPeters fromGallPeters
    namespace export toBalthasart fromBalthasart

    # Pseudocylindrical projections - equal area

    namespace export toSinusoidal fromSinusoidal
    namespace export toMillerCylindrical fromMillerCylindrical
    namespace export toMollweide fromMollweide
    namespace export toEckertIV fromEckertIV toEckertVI fromEckertVI

    # Pseudocylindrical projections - compromise

    namespace export toRobinson fromRobinson

    # Azimuthal projections

    namespace export toAzimuthalEquidistant fromAzimuthalEquidistant
    namespace export toLambertAzimuthalEqualArea fromLambertAzimuthalEqualArea
    namespace export toStereographic fromStereographic
    namespace export toOrthographic fromOrthographic
    namespace export toGnomonic fromGnomonic

    # Pseudo-azimuthal projections

    namespace export toHammer fromHammer

    # Conic projections

    namespace export toConicEquidistant fromConicEquidistant
    namespace export toLambertConformalConic fromLambertConformalConic
    namespace export toAlbersEqualAreaConic fromAlbersEqualAreaConic

    # Miscellaneous projections

    namespace export toPeirceQuincuncial fromPeirceQuincuncial

    # Fundamental constants

    variable pi [expr {acos(-1.0)}]
    variable twopi [expr {2.0 * $pi}]
    variable halfpi [expr {0.5 * $pi}]
    variable quarterpi [expr {0.25 * $pi}]
    variable threequarterpi [expr {0.75 * $pi}]
    variable mquarterpi [expr {-0.25 * $pi}]
    variable mthreequarterpi [expr {-0.75 * $pi}]
    variable radian [expr {180. / $pi}]
    variable degree [expr {$pi / 180.}]
    variable sqrt2 [expr {sqrt(2.)}]
    variable sqrt8 [expr {2. * $sqrt2}]
    variable halfSqrt3 [expr {sqrt(3.) / 2.}]
    variable halfSqrt2 [expr {sqrt(2.) / 2.}]
    variable EckertIVK1 [expr {2.0 / sqrt($pi * (4.0 + $pi))}]
    variable EckertIVK2 [expr {2.0 * sqrt($pi / (4.0 + $pi))}]
    variable EckertVIK1 [expr {sqrt(2.0 + $pi)}]
    variable PeirceQuincuncialScale 3.7081493546027438 ;# 2*K(1/2)
    variable PeirceQuincuncialLimit 1.8540746773013719 ;# K(1/2)

    # Table of parallel length and distance from equator for the
    # Robinson projection

    variable RobinsonLatitude {
	-90.0 	-85.0	-80.0	-75.0	-70.0	-65.0
	-60.0	-55.0	-50.0	-45.0	-40.0	-35.0
	-30.0	-25.0	-20.0	-15.0	-10.0	-5.0
	0.0	5.0	10.0	15.0	20.0	25.0	30.0
	35.0	40.0	45.0	50.0	55.0	60.0
	65.0	70.0	75.0	80.0	85.0	90.0
    }
    variable RobinsonPLEN {
	0.5322	0.5722	0.6213	0.6732	0.7186	0.7597
	0.7986	0.8350	0.8679	0.8962	0.9216	0.9427
	0.9600	0.9730	0.9822	0.9900	0.9954	0.9986
	1.0000	0.9986	0.9954	0.9900	0.9822	0.9730	0.9600
	0.9427	0.9216	0.8962	0.8679	0.8350	0.7986
	0.7597	0.7186	0.6732	0.6213	0.5722	0.5322
    }
    variable RobinsonPDFE {
	-1.0000	-0.9761	-0.9394	-0.8936	-0.8435	-0.7903
	-0.7346	-0.6769	-0.6176	-0.5571	-0.4958	-0.4340
	-0.3720	-0.3100	-0.2480	-0.1860	-0.1240	-0.0620
	0.0000	0.0620	0.1240	0.1860	0.2480	0.3100	0.3720
	0.4340	0.4958	0.5571	0.6176	0.6769	0.7346
	0.7903	0.8435	0.8936	0.9394	0.9761	1.0000
    }

    # Interpolation tables for Robinson

    variable RobinsonSplinePLEN \
	[math::interpolate::prepare-cubic-splines \
	     $RobinsonLatitude $RobinsonPLEN]
    variable RobinsonSplinePDFE \
	[math::interpolate::prepare-cubic-splines \
	     $RobinsonLatitude $RobinsonPDFE]
    variable RobinsonM [expr {0.5072 * $pi}]

    namespace import ::math::special::cn

}

# ::mapproj::ellF - 
#
#	Computes the Legendre incomplete elliptic integral of the
#	first kind:
#
#	F(phi, k) = \integral_0^phi dtheta/sqrt(1 - k**2 sin**2 theta)
#
#
# Parameters:
#	phi -- Limit of integration; angle around the ellipse
#	k -- Eccentricity
#
# Results:
#	Returns F(phi, k)
#
# Notes:
#	We compute this integral in terms of the Carlson elliptic integral
#	ellRF(x, y, z).

proc ::mapproj::ellF {phi k} {
    return [ellFaux [expr {cos($phi)}] [expr {sin($phi)}] $k]
}

# ::mapproj::ellFaux -
#
#	Computes the Legendre incomplete elliptic integral of the
#	first kind when circular functions of the 'phi' argument
#	are already available.
#
# Parameters:
#	cos_phi - Cosine of the argument
#	sin_phi - Sine of the argument
#	k - Parameter
#
# Results:
#	Returns F(atan(sin_phi/cos_phi), k)

proc ::mapproj::ellFaux {cos_phi sin_phi k} {
    set rf [ellRF [expr {$cos_phi * $cos_phi}] \
	       [expr {1.0 - $k * $k * $sin_phi * $sin_phi}] \
	       1.0]
    return [expr {$sin_phi * $rf}]
}

# ::mapproj::ellRF --
#
#	Computes the Carlson incomplete elliptic integral of the
#	first kind:
#
#	RF(x, y, z) = 1/2 * integral_0^inf dt/sqrt((t+x)*(t+y)*(t+z))
#
# Parameters:
#	x, y, z -- Interchangeable parameters of the integral
#
# Results:
#	Returns the value of RF

proc ::mapproj::ellRF {x y z} {
    if {$x < 0.0 || $y < 0.0 || $z < 0.0} {
	return -code error "Negative argument to Carlson's ellRF" \
	    -errorCode "ellRF negArgument"
    }
    set delx 1.0; set dely 1.0; set delz 1.0
    while {abs($delx) > 0.0025 || abs($dely) > 0.0025 || abs($delz) > 0.0025} {
	set sx [expr {sqrt($x)}]
	set sy [expr {sqrt($y)}]
	set sz [expr {sqrt($z)}]
	set len [expr {$sx * ($sy + $sz) + $sy * $sz}]
	set x [expr {0.25 * ($x + $len)}]
	set y [expr {0.25 * ($y + $len)}]
	set z [expr {0.25 * ($z + $len)}]
	set mean [expr {($x + $y + $z) / 3.0}]
	set delx [expr {($mean - $x) / $mean}]
	set dely [expr {($mean - $y) / $mean}]
	set delz [expr {($mean - $z) / $mean}]
    }
    set e2 [expr {$delx * $dely - $delz * $delz}]
    set e3 [expr {$delx * $dely * $delz}]
    return [expr {(1.0 + ($e2 / 24.0 - 0.1 - 3.0 * $e3 / 44.0) * $e2
		   + $e3 / 14.) / sqrt($mean)}]
}

# ::mapproj::toPlateCarree --
#
#	Project a latitude and longitude onto the plate carrée.
#
# Parameters:
#	phi_0 -- Latitude of the center of the sheet in degrees
#	lambda_0 -- Longitude of the center of sheet in degrees
#	lambda -- Longitude of the point to be projected in degrees
#	phi -- Latitude of the point to be projected in degrees
#
# Results:
#	Returns x and y co-ordinates.  Units of x and y are Earth radii;
#	scale is true at the Equator.

proc ::mapproj::toPlateCarree {lambda_0 phi_0 lambda phi} {
    variable degree
    set lambda [expr {$lambda - $lambda_0 + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    set x [expr {$lambda * $degree}]
    set y [expr {($phi - $phi_0) * $degree}]
    return [list $x $y]
}

# ::mapproj::fromPlateCarree --
#
#	Solve a plate carrée projection for the
#	latitude and longitude represented by a point on the map.
#
# Parameters:
#	phi_0 -- Latitude of the center of the sheet in degrees
#	lambda_0 -- Longitude of the center of projection
#	x,y -- normalized x and y co-ordinates of a point on the map
#
# Results:
#	Returns a list consisting of the longitude and latitude in degrees.

proc ::mapproj::fromPlateCarree {phi_0 lambda_0 x y} {
    variable radian
    set lambda [expr {$lambda_0 + $x * $radian + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    set phi [expr {$y * $radian + $phi_0}]
    return [list $lambda $phi]
}

# mapproj::toCylindricalEqualArea --
#
#	Project a latitude and longitude into cylindrical equal-area
#	co-ordinates.
#
# Parameters:
#	phi_1 --    Standard latitude in degrees
#	phi_0 -- Latitude of the center of the sheet in degrees
#	lambda_0 -- Longitude of the center of projection in degrees
#	lambda --   Longitude of the point to be projected in degrees
#	phi -- Latitude of the point to be projected in degrees
#
# Results:
#	Returns x and y co-ordinates.  Units of x and y are Earth radii;
#	scale is true at the reference latitude

proc ::mapproj::toCylindricalEqualArea {phi_1 lambda_0 phi_0 lambda phi} {
    variable degree
    set cos_phi_s [expr {cos($phi_1 * $degree)}]
    set lambda [expr {$lambda - $lambda_0 + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    set x [expr {$lambda * $degree * $cos_phi_s}]
    set y0 [expr {sin($phi_0 * $degree) / $cos_phi_s}]
    set y [expr {sin($phi * $degree) / $cos_phi_s}]
    return [list $x [expr {$y - $y0}]]
}

# ::mapproj::fromCylindricalEqualArea --
#
#	Solve a cylindrical equal area map projection for the
#	latitude and longitude represented by a point on the map.
#
# Parameters:
#	phi_1 -- Standard latitude in degrees
#	phi_0 -- Latitude of the center of the sheet in degrees
#	lambda_0 -- Longitude of the center of sheet in degrees
#	x,y -- normalized x and y co-ordinates of a point on the map
#
# Results:
#	Returns a list consisting of the longitude and latitude in degrees.

proc ::mapproj::fromCylindricalEqualArea {phi_1 lambda_0 phi_0 x y} {
    variable degree
    variable radian
    set cos_phi_s [expr {cos($phi_1 * $degree)}]
    set lambda [expr {$lambda_0 + $x / $cos_phi_s * $radian + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    set y0 [expr {sin($phi_0 * $degree) / $cos_phi_s}]
    set phi [expr {asin(($y + $y0) * $cos_phi_s) * $radian}]
    return [list $lambda $phi]
}

# ::mapproj::toMercator --
#
#	Project a latitude and longitude into the Mercator projection
#	co-ordinates.
#
# Parameters:
#	lambda_0 -- Longitude of the center of projection in degrees
#	phi_0 -- Latitude of the center of sheet in degrees
#	lambda --   Longitude of the point to be projected in degrees
#	phi -- Latitude of the point to be projected in degrees
#
# Results:
#	Returns x and y co-ordinates in Earth radii. Scale is true
#	at the Equator and increases without bounds toward the Poles.

proc ::mapproj::toMercator {lambda_0 phi_0 lambda phi} {
    variable trace; if {[info exists trace]} { puts [info level 0] }
    variable degree
    variable quarterpi
    set lambda [expr {$lambda - $lambda_0 + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    set x [expr {$lambda * $degree}]
    set y [expr {log(tan($quarterpi + 0.5 * $phi * $degree))}]
    set y0 [expr {log(tan($quarterpi + 0.5 * $phi_0 * $degree))}]
    if {[info exists trace]} { puts "[info level 0] -> $x [expr {$y - $y0}]" }
    return [list $x [expr {$y - $y0}]]
}

# ::mapproj::fromMercator --
#
#	Converts Mercator map co-ordinates to latitude and longitude.
#
# Parameters:
#	lambda_0 -- Longitude of the center of projection
#	phi_0 -- Latitude of the center of sheet in degrees
#	x,y -- normalized x and y co-ordinates of a point on the map
#
# Results:
#	Returns a list consisting of the longitude and latitude in degrees.

proc ::mapproj::fromMercator {lambda_0 phi_0 x y} {
    variable quarterpi
    variable degree
    variable radian
    set y0 [expr {log(tan($quarterpi + 0.5 * $phi_0 * $degree))}]
    set lambda [expr {$lambda_0 + $x  * $radian + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    set phi [expr {$radian * 2.0 * atan(exp($y + $y0)) - 90.0}]
    return [list $lambda $phi]
}

# ::mapproj::toMillerCylindrical --
#
#	Project a latitude and longitude into the Miller Cylindrical projection
#	co-ordinates.
#
# Parameters:
#	lambda_0 -- Longitude of the center of projection in degrees
#	lambda --   Longitude of the point to be projected in degrees
#	phi -- Latitude of the point to be projected in degrees
#
# Results:
#	Returns x and y co-ordinates.  The x co-ordinate ranges from
#	-$pi to pi.

proc ::mapproj::toMillerCylindrical {lambda_0 lambda phi} {
    foreach {x y} [toMercator $lambda_0 0.0 \
		       $lambda [expr {0.8 * $phi}]] break
    set y [expr {1.25 * $y}]
    return [list $x $y]
}

# ::mapproj::fromMillerCylindrical --
#
#	Converts Miller Cylindrical projected  map co-ordinates 
#	to latitude and longitude.
#
# Parameters:
#	lambda_0 -- Longitude of the center of projection
#	x,y -- normalized x and y co-ordinates of a point on the map
#
# Results:
#	Returns a list consisting of the longitude and latitude in degrees.

proc ::mapproj::fromMillerCylindrical {lambda_0 x y} {
    foreach {lambda phi} [fromMercator $lambda_0 0.0 \
			      $x [expr {0.8 * $y}]] break
    return [list $lambda [expr {1.25 * $phi}]]
}

# ::mapproj::toSinusoidal --
#
#	Project a latitude and longitude into the sinusoidal
#	(Sanson-Flamsteed) projection.
#
# Parameters:
#	lambda_0 -- Longitude of the center of projection in degrees
#	phi_0 -- Latitude of the center of the sheet, in degrees
#	lambda --   Longitude of the point to be projected in degrees
#	phi -- Latitude of the point to be projected in degrees
#
# Results:
#	Returns x and y co-ordinates, in Earth radii. 
#	Scale is true along the Equator and central meridian.

proc ::mapproj::toSinusoidal {lambda_0 phi_0 lambda phi} {
    variable degree
    variable quarterpi
    set lambda [expr {$lambda - $lambda_0 + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {($lambda - 180.) * $degree}]
    set phi [expr {$phi * $degree}]
    set x [expr {$lambda * cos($phi)}]
    set phi [expr {$phi - $phi_0 * $degree}]
    return [list $x $phi]
}

# ::mapproj::fromSinusoidal --
#
#	Converts sinusoidal (Sanson-Flamsteed) map co-ordinates 
#	to latitude and longitude.
#
# Parameters:
#	lambda_0 -- Longitude of the center of projection
#	phi_0 -- Latitude of the center of the sheet, in degrees
#	x,y -- normalized x and y co-ordinates of a point on the map
#
# Results:
#	Returns a list consisting of the longitude and latitude in degrees.

proc ::mapproj::fromSinusoidal {lambda_0 phi_0 x y} {
    variable degree
    variable radian
    set y [expr {$y + $phi_0 * $degree}]
    set phi [expr {$y * $radian}]
    set lambda [expr {180. + $lambda_0 + $radian * $x / cos($y)}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    return [list $lambda $phi]
}

# ::mapproj::toMollweide --
#
#	Project a latitude and longitude into the Mollweide projection
#	co-ordinates.
#
# Parameters:
#	lambda_0 -- Longitude of the center of projection in degrees
#	lambda --   Longitude of the point to be projected in degrees
#	phi -- Latitude of the point to be projected in degrees
#
# Results:
#	Returns x and y co-ordinates, in Earth radii. 
#	Scale is true along the 40 deg 44 min parallels

proc ::mapproj::toMollweide {lambda_0 lambda phi} {
    variable degree
    variable pi
    variable halfpi
    variable sqrt2
    variable sqrt8
    set lambda [expr {$lambda - $lambda_0 + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {($lambda - 180.) * $degree}]
    set phi [expr {$phi * $degree}]
    set theta [expr {2.0 * asin(2.0 * $phi / $pi)}]
    set diff 1.0
    set pisinphi [expr {$pi * sin($phi)}]
    while {abs($diff) >= 1.0e-4} {
	set diff [expr {($theta + sin($theta) - $pisinphi)
			/ (1.0 + cos($theta))}]
	set theta [expr {$theta - $diff}]
    }
    set theta [expr {0.5 * $theta}]
    set x [expr {$sqrt8 * $lambda * cos($theta) / $pi}]
    set y [expr {$sqrt2 * sin($theta)}]
    return [list $x $y]
}

# ::mapproj::fromMollweide --
#
#	Converts Mollweide projected  map co-ordinates to latitude 
#	and longitude.
#
# Parameters:
#	lambda_0 -- Longitude of the center of projection
#	x,y -- normalized x and y co-ordinates of a point on the map
#
# Results:
#	Returns a list consisting of the longitude and latitude in degrees.

proc ::mapproj::fromMollweide {lambda_0 x y} {
    variable pi
    variable radian
    variable degree
    variable halfpi
    variable sqrt2
    variable sqrt8
    set theta [expr {asin($y / $sqrt2)}]
    set lambda [expr {$lambda_0 + $radian * $pi * $x / 
		      ($sqrt8 * cos($theta)) + 180.}]
    set phi [expr {asin((2.0 * $theta + sin(2.0 * $theta)) / $pi)}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    return [list $lambda [expr {$phi * $radian}]]
}

# ::mapproj::toEckertIV --
#
#	Project a latitude and longitude into the Eckert IV projection
#	co-ordinates.
#
# Parameters:
#	lambda_0 -- Longitude of the center of projection in degrees
#	lambda --   Longitude of the point to be projected in degrees
#	phi -- Latitude of the point to be projected in degrees
#
# Results:
#	Returns x and y co-ordinates.  Scale is true along the 40 deg 30 min
#	parallels.

proc ::mapproj::toEckertIV {lambda_0 lambda phi} {
    variable degree
    variable pi
    variable halfpi
    variable EckertIVK1
    variable EckertIVK2
    set lambda [expr {$lambda - $lambda_0 + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {($lambda - 180.) * $degree}]
    set phi [expr {$phi * $degree}]
    set theta [expr {$phi / 2}]
    set diff 1.0
    set A [expr {(2.0 + $halfpi) * sin($phi)}]
    while {abs($diff) >= 1.0e-4} {
	set costheta [expr {cos($theta)}]
	set sintheta [expr {sin($theta)}]
	set diff \
	    [expr {($theta + $sintheta * $costheta + 2.0 * sin($theta) - $A)
		   / (2.0 * $costheta * (1.0 + $costheta))}]
	set theta [expr {$theta - $diff}]
    }
    set x [expr {$EckertIVK1 * $lambda * (1.0 + cos($theta))}]
    set y [expr {$EckertIVK2 * sin($theta)}]
    return [list $x $y]
}

# ::mapproj::fromEckertIV --
#
#	Converts Eckert IV projected  map co-ordinates to latitude 
#	and longitude.
#
# Parameters:
#	lambda_0 -- Longitude of the center of projection
#	x,y -- normalized x and y co-ordinates of a point on the map
#
# Results:
#	Returns a list consisting of the longitude and latitude in degrees.

proc ::mapproj::fromEckertIV {lambda_0 x y} {
    variable pi
    variable radian
    variable degree
    variable halfpi
    variable sqrt2
    variable EckertIVK1
    variable EckertIVK2
    set sintheta [expr {$y / $EckertIVK2}]
    set costheta [expr {sqrt(1.0 - $sintheta * $sintheta)}]
    set theta [expr {atan2($sintheta, $costheta)}]
    set phi [expr {asin(($theta + $sintheta*$costheta + 2.*$sintheta)
			/ (2. + $halfpi))}]
    set lambda [expr {180.0 + $lambda_0
		      + $radian / $EckertIVK1 * $x / (1.0 + $costheta)}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    return [list $lambda [expr {$phi * $radian}]]
}

# ::mapproj::toEckertVI --
#
#	Project a latitude and longitude into the Eckert IV projection
#	co-ordinates.
#
# Parameters:
#	lambda_0 -- Longitude of the center of projection in degrees
#	lambda --   Longitude of the point to be projected in degrees
#	phi -- Latitude of the point to be projected in degrees
#
# Results:
#	Returns x and y co-ordinates.  Scale is true along the 40 deg 30 min
#	parallels.

proc ::mapproj::toEckertVI {lambda_0 lambda phi} {
    variable degree
    variable pi
    variable halfpi
    variable EckertVIK1
    set lambda [expr {$lambda - $lambda_0 + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {($lambda - 180.) * $degree}]
    set phi [expr {$phi * $degree}]
    set theta [expr {$phi / 2}]
    set diff 1.0
    set A [expr {(1.0 + $halfpi) * sin($phi)}]
    while {abs($diff) >= 1.0e-4} {
	set costheta [expr {cos($theta)}]
	set sintheta [expr {sin($theta)}]
	set diff \
	    [expr {($theta + $sintheta - $A)
		   / (1.0 + $costheta)}]
	set theta [expr {$theta - $diff}]
    }
    set x [expr {$lambda * (1.0 + cos($theta)) / $EckertVIK1}]
    set y [expr {2.0 * $theta / $EckertVIK1}]
    return [list $x $y]
}

# ::mapproj::fromEckertVI --
#
#	Converts Eckert IV projected  map co-ordinates to latitude 
#	and longitude.
#
# Parameters:
#	lambda_0 -- Longitude of the center of projection
#	x,y -- normalized x and y co-ordinates of a point on the map
#
# Results:
#	Returns a list consisting of the longitude and latitude in degrees.

proc ::mapproj::fromEckertVI {lambda_0 x y} {
    variable pi
    variable radian
    variable degree
    variable halfpi
    variable sqrt2
    variable EckertVIK1
    puts [info level 0]
    set theta [expr {0.5 * $EckertVIK1 * $y}]
    puts [list theta = $theta]
    set phi [expr {asin(($theta + sin($theta)) / (1.0 + $halfpi))}]
    puts [list phi = $phi]
    set lambda [expr {180.0 + $lambda_0 + $radian * $EckertVIK1 * $x
		      / (1 + cos($theta))}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    return [list $lambda [expr {$phi * $radian}]]
}

# ::mapproj::toRobinson --
#
#	Project a latitude and longitude into the Robinson projection.
#
# Parameters:
#	lambda_0 -- Longitude of the center of projection in degrees
#	lambda --   Longitude of the point to be projected in degrees
#	phi -- Latitude of the point to be projected in degrees
#
# Results:
#	Returns x and y co-ordinates, in Earth radii. 
#	Scale is true along the Equator.

proc ::mapproj::toRobinson {lambda_0 lambda phi} {
    variable RobinsonLatitude
    variable RobinsonSplinePLEN
    variable RobinsonSplinePDFE
    variable RobinsonM
    variable pi
    variable degree
    set lambda [expr {$lambda - $lambda_0 + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    set y [math::interpolate::interp-cubic-splines $RobinsonSplinePDFE $phi]
    set y [expr {$RobinsonM * $y}]
    set s [math::interpolate::interp-cubic-splines $RobinsonSplinePLEN $phi]
    set x [expr {$degree * $s * $lambda}]
    return [list $x $y]
}

# ::mapproj::fromRobinson --
#
#	Solve the Robinson projection for the
#	latitude and longitude represented by a point on the map.
#
# Parameters:
#	lambda_0 -- Longitude of the center of projection
#	x,y -- normalized x and y co-ordinates of a point on the map
#
# Results:
#	Returns a list consisting of the longitude and latitude in degrees.

proc ::mapproj::fromRobinson {lambda_0 x y} {
    variable RobinsonLatitude
    variable RobinsonPDFE
    variable RobinsonSplinePLEN
    variable RobinsonSplinePDFE
    variable RobinsonM
    variable radian

    # We know that Robinson latitudes are equally spaced from [-90..90]
    # at 5-degree intervals.  Find the values for RobinsonPDFE that
    # bracket the y co-ordinate.

    set y [expr {$y / $RobinsonM}]
    set l 0
    set u [expr {[llength $RobinsonPDFE] - 1}]
    while {$l < $u} {
	set m [expr {($l + $u + 1) / 2}]
	if {$y >= [lindex $RobinsonPDFE $m]} {
	    set l $m
	} else {
	    set u [expr {$m - 1}]
	}
    }
    set u [lindex $RobinsonLatitude [expr {$l+1}]]
    set l [lindex $RobinsonLatitude $l]
    for {set i 0} {$i < 12} {incr i} {
	set m [expr {0.5 * ($u + $l)}]
	set ystar [math::interpolate::interp-cubic-splines \
		       $RobinsonSplinePDFE $m]
	if {$ystar < $y} {
	    set l $m
	} else {
	    set u $m
	}
    }
    puts "latitude $m"
    set s [math::interpolate::interp-cubic-splines $RobinsonSplinePLEN $m]
    puts "parallel length $s"
    set lambda [expr {180.0 + $lambda_0 + $radian * $x / $s}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    return [list $lambda $m]
}

# ::mapproj::toCassini --
#
#	Project a latitude and longitude into the Cassini projection.
#
# Parameters:
#	lambda_0 -- Longitude of the center of projection in degrees
#	phi_0 -- Latitude of the center of the sheet
#	lambda --   Longitude of the point to be projected in degrees
#	phi -- Latitude of the point to be projected in degrees
#
# Results:
#	Returns x and y co-ordinates, in Earth radii. 
#	Scale is true along the central meridian.

proc ::mapproj::toCassini {lambda_0 phi_0 lambda phi} {
    variable degree
    variable pi
    variable twopi
    variable quarterpi
    set lambda [expr {$lambda - $lambda_0 + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {($lambda - 180.) * $degree}]
    set phi [expr {$phi * $degree}]
    set x [expr {asin(cos($phi) * sin($lambda))}]
    set y [expr {atan2(tan($phi), cos($lambda)) - $degree * $phi_0}]
    if {$y < -$pi} {
	set y [expr {$y + $twopi}]
    } elseif {$y > $pi} {
	set y [expr {$y - $twopi}]
    }
    return [list $x $y]
}

# ::mapproj::fromCassini --
#
#	Converts Cassini map co-ordinates to latitude and longitude.
#
# Parameters:
#	lambda_0 -- Longitude of the center of projection
#	phi_0 -- Latitude of the center of the sheet
#	x,y -- normalized x and y co-ordinates of a point on the map
#
# Results:
#	Returns a list consisting of the longitude and latitude in degrees.

proc ::mapproj::fromCassini {lambda_0 phi_0 x y} {
    variable degree
    variable radian
    set y [expr {$y + $degree * $phi_0}]
    set phi [expr {$radian * asin(cos($x) * sin($y))}]
    set lambda [expr {180. + $lambda_0 + $radian * atan2(tan($x), cos($y))}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    return [list $lambda $phi]
}

# ::mapproj::toPeirceQuincuncial
#
#	Converts geodetic co-ordinates to the Peirce Quincuncial projection.
#
# Parameters:
#	lambda_0 - Longitude of the central meridian.  (Conventionally, 20.0).
#	lambda - Longitude of the point to be projected in degrees
#	phi - Latitude of the point to be projected in degrees.
#
# Results:
#	Returns a list of the x and y co-ordinates.

proc ::mapproj::toPeirceQuincuncial {lambda_0 lambda phi} {
    variable degree
    variable halfSqrt2
    variable pi
    variable quarterpi
    variable mquarterpi
    variable threequarterpi
    variable mthreequarterpi
    variable PeirceQuincuncialScale

    # Convert latitude and longitude to radians relative to the
    # central meridian

    set lambda [expr {$lambda - $lambda_0 + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {($lambda - 180.) * $degree}]
    set phi [expr {$phi * $degree}]

    # Compute the auxiliary quantities 'm' and 'n'. Set 'm' to match
    # the sign of 'lambda' and 'n' to be positive if |lambda| > pi/2

    set cos_phiosqrt2 [expr {$halfSqrt2 * cos($phi)}]
    set cos_lambda [expr {cos($lambda)}]
    set sin_lambda [expr {sin($lambda)}]
    set cos_a [expr {$cos_phiosqrt2 * ($sin_lambda + $cos_lambda)}]
    set cos_b [expr {$cos_phiosqrt2 * ($sin_lambda - $cos_lambda)}]
    set sin_a [expr {sqrt(1.0 - $cos_a * $cos_a)}]
    set sin_b [expr {sqrt(1.0 - $cos_b * $cos_b)}]
    set cos_a_cos_b [expr {$cos_a * $cos_b}]
    set sin_a_sin_b [expr {$sin_a * $sin_b}]
    set sin2_m [expr {1.0 + $cos_a_cos_b - $sin_a_sin_b}]
    set sin2_n [expr {1.0 - $cos_a_cos_b - $sin_a_sin_b}]
    if {$sin2_m < 0.0} {set sin2_m 0.0}
    set sin_m [expr {sqrt($sin2_m)}]
    if {$sin2_m > 1.0} { set sin2_m 1.0 }
    set cos_m [expr {sqrt(1.0 - $sin2_m)}]
    if {$sin_lambda < 0.0} {
	set sin_m [expr {-$sin_m}]
    }
   if {$sin2_n < 0.0} { set sin2_n 0.0 }
    set sin_n [expr {sqrt($sin2_n)}]
    if {$sin2_n > 1.0} { set sin2_n 1.0 }
    set cos_n [expr {sqrt(1.0 - $sin2_n)}]
    if {$cos_lambda > 0.0} {
	set sin_n [expr {-$sin_n}]
    }

    # Compute elliptic integrals to map the disc to the square

    set x [ellFaux $cos_m $sin_m $halfSqrt2]
    set y [ellFaux $cos_n $sin_n $halfSqrt2]

    # Reflect the Southern Hemisphere outward

    if {$phi < 0} {
	if {$lambda < $mthreequarterpi} {
	    set y [expr {$PeirceQuincuncialScale - $y}]
	} elseif {$lambda < $mquarterpi} {
	    set x [expr {-$PeirceQuincuncialScale - $x}]
	} elseif {$lambda < $quarterpi} {
	    set y [expr {-$PeirceQuincuncialScale - $y}]
	} elseif {$lambda < $threequarterpi} {
	    set x [expr {$PeirceQuincuncialScale - $x}]
	} else {
	    set y [expr {$PeirceQuincuncialScale - $y}]
	}
    }

    # Rotate the square by 45 degrees to fit the screen better

    set X [expr {($x - $y) * $halfSqrt2}]
    set Y [expr {($x + $y) * $halfSqrt2}]

    return [list $X $Y]
}

# ::mapproj::fromPeirceQuincuncial --
#
#	Converts Peirce Quincuncial map co-ordinates to latitude and longitude.
#
# Parameters:
#	lambda_0 -- Longitude of the center of projection
#	x,y -- normalized x and y co-ordinates of a point on the map
#
# Results:
#	Returns a list consisting of the longitude and latitude in degrees.

proc ::mapproj::fromPeirceQuincuncial {lambda_0 x y} {
    variable halfSqrt2
    variable radian
    variable pi
    variable halfpi
    variable quarterpi
    variable PeirceQuincuncialScale
    variable PeirceQuincuncialLimit

    # Rotate x and y 45 degrees

    set X [expr {($x + $y) * $halfSqrt2}]
    set Y [expr {($y - $x) * $halfSqrt2}]

    # Reflect Southern Hemisphere into the Northern

    set southern 0
    if {$X < -$PeirceQuincuncialLimit} {
	set X [expr {-$PeirceQuincuncialScale - $X}]
	set southern 1
    } elseif {$X > $PeirceQuincuncialLimit} {
	set X [expr {$PeirceQuincuncialScale - $X}]
	set southern 1
    } elseif {$Y < -$PeirceQuincuncialLimit} {
	set Y [expr {-$PeirceQuincuncialScale - $Y}]
	set southern 1
    } elseif {$Y > $PeirceQuincuncialLimit} {
	set Y [expr {$PeirceQuincuncialScale - $Y}]
	set southern 1
    }

    # Now we know that latitude will be positive.  If X is negative, then
    # longitude will be negative; reflect the Western Hemisphere into the
    # Eastern.

    set western 0
    if {$X < 0.0} {
	set western 1
	set X [expr {-$X}]
    }

    # If Y is positive, the point is in the back hemisphere.  Reflect
    # it to the front.

    set back 0
    if {$Y > 0.0} {
	set back 1
	set Y [expr {-$Y}]
    }

    # Finally, constrain longitude to be less than pi/4, by reflecting across
    # the 45 degree meridian.

    set complement 0
    if {$X > -$Y} {
	set complement 1
	set t [expr {-$X}]
	set X [expr {-$Y}]
	set Y $t
    }

    # Compute the elliptic functions to map the plane onto the sphere

    set cnx [cn $X $halfSqrt2]
    set cny [cn $Y $halfSqrt2]

    # Undo the mapping to latitude and longitude

    set a1 [expr {acos(-$cnx * $cnx)}]
    set a2 [expr {acos($cny * $cny)}]
    set b [expr {0.5 * ($a1 + $a2)}]
    set a [expr {0.5 * ($a1 - $a2)}]
    set cos_a [expr {cos($a)}]
    set cos_b [expr {-cos($b)}]
    set lambda [expr {$quarterpi - atan2($cos_b, $cos_a)}]
    set phi [expr {acos(hypot($cos_b, $cos_a))}]

    # Undo the reflections that were done above, to get correct latitude
    # and longitude

    if {$complement} {
	set lambda [expr {$halfpi - $lambda}]
    }
    if {$back} {
	set lambda [expr {$pi - $lambda}]
    }
    if {$western} {
	set lambda [expr {-$lambda}]
    }
    if {$southern} {
	set phi [expr {-$phi}]
    }

    # Convert latitude and longitude to degrees

    set lambda [expr {$lambda * $radian + 180. + $lambda_0}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    set phi [expr {$phi * $radian}]

    return [list $lambda $phi]
}

# ::mapproj::RotateCartesianY
#
#	Rotates Cartesian co-ordinates about the y axis
#
# Parameters:
#	phi - Angle (in degrees) about which to rotate.
#	x,y,z - Cartesian co-ordinates
#
# Results:
#	Returns a three-element list giving the rotated co-ordinates.

proc ::mapproj::RotateCartesianY {phi x y z} {
    variable degree
    set phi [expr {$degree * $phi}]
    set cos_phi [expr {cos($phi)}]
    set sin_phi [expr {sin($phi)}]
    return [list [expr {$x * $cos_phi - $z * $sin_phi}] \
		$y \
		[expr {$z * $cos_phi + $x * $sin_phi}]]
}

# ::mapproj::ToCartesian --
#
#	Converts geodetic co-ordinates to Cartesian
#
# Parameters:
#	lambda - Longitude of the point to be projected, in degrees
#	phi - Latitude of the point to be projected, in degrees
#
# Results:
#	Returns a three-element list, x, y, z where x is the component
#	in the direction of longitude 0, latitude 0, y is the component
#	in the direction of longitude 90 East, latitude 0, and
#	z is the component in the direction of the North Pole
#
# Auxiliary procedure used in several projections to convert
# geodetic coordinates to Cartesian range and bearing.

proc ::mapproj::ToCartesian {lambda phi} {
    variable degree
    set lambda [expr {$degree * $lambda}]
    set phi [expr {$degree * $phi}]
    set cos_phi [expr cos($phi)]
    return [list [expr {$cos_phi * cos($lambda)}] \
		[expr {$cos_phi * sin($lambda)}] \
		[expr {sin($phi)}]]
}

# ::mapproj::CartesianToRangeAndBearing
#
#	Transforms view-relative Cartesian co-ordinates to range and
#	bearing.
#
# Parameters:
#	x,y,z - Cartesian co-ordinates relative to center of Earth;
#	+x points to the viewer and +z to the "view-up" direction.
#
# Results:
#	Returns a three-element list containing, in order,
#	the cosine (easting) of the bearing, the sine (northing) of the
#	bearing, and the range.

proc ::mapproj::CartesianToRangeAndBearing {x y z} {
    set c [expr {hypot($z, $y)}]
    if {$c == 0} {
	set cos_b 1.0
	set sin_b 0.0
    } else {
	set cos_b [expr {$y / $c}]
	set sin_b [expr {$z / $c}]
    }
    set range [expr {atan2($c, $x)}]
    return [list $cos_b $sin_b $range]
}

# ::mapproj::RangeAndBearingToCartesian --
#
#	Converts range and bearing to Cartesian co-ordinates.
#
# Parameters:
#	cos_b, sin_b -- Cosine (easting) and sine (northing) of the bearing
#	range - Range, in Earth radii
#
# Results:
#	Returns Cartesian co-ordinates relative to center of Earth.
#	x is toward the station, and z is "view up"

proc ::mapproj::RangeAndBearingToCartesian {cos_b sin_b range} {
    set c [expr {sin($range)}]
    set x [expr {cos($range)}]
    set y [expr {$cos_b * $c}]
    set z [expr {$sin_b * $c}]
    return [list $x $y $z]
}
    

# ::mapproj::CartesianToSpherical --
#
#	Transforms Cartesian x, y, z to spherical co-ordinates
#
# Parameters:
#	x, y, z -- Coordinates of a point on the surface of the Earth,
#	           in Earth radii
#
# Results:
#	Returns a two-element list comprising longitude and latitude
#	in radians

proc ::mapproj::CartesianToSpherical {x y z} {
    return [list [expr {atan2($y, $x)}] [expr {atan2($z, hypot($y, $x))}]]
}

# ::mapproj::toOrthographic --
#
#	Transforms latitude and longitude to x and y co-ordinates
#	on an orthographic projection.  Scale is true only at the
#	point of projection.
#
# Parameters:
#	lambda_0, phi_0 -- Longitude and latitude of the center of projection
#			   in degrees
#	lambda, phi -- Longitude and latitude of the point to be projected
#		       in degrees
#
# Results:
#	Returns map x and y co-ordinates, in Earth radii.

proc ::mapproj::toOrthographic {lambda_0 phi_0 lambda phi} {
    foreach {x y z} [ToCartesian [expr {$lambda-$lambda_0}] $phi] \
	break
    foreach {x y z} [RotateCartesianY [expr {-$phi_0}] $x $y $z] \
	break
    if {$x < 0} {
	return {}
    } else {
	return [list $y $z]
    }
}

# ::mapproj::fromOrthographic --
#
#	Transforms x and y on an orthographic projection to latitude
#	and longitude.
#
# Parameters:
#	lambda_0, phi_0 -- Longitude and latitude of the center of projection
#			   in degrees
#	x, y -- Co-ordinates of the projected point, in Earth radii
#
# Results:
#	Returns a two element list containing longitude and latitude
#	in degrees.

proc ::mapproj::fromOrthographic {lambda_0 phi_0 x y} {
    variable radian
    set r [expr {hypot($x, $y)}]
    set alpha [expr {asin($r)}]
    set z [expr {sqrt(1.0 - $r*$r)}]
    foreach {x y z} [RotateCartesianY $phi_0 $z $x $y] break
    foreach {lambda phi} [CartesianToSpherical $x $y $z] break

    # Convert latitude and longitude to degrees

    set lambda [expr {$lambda * $radian + 180. + $lambda_0}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    set phi [expr {$phi * $radian}]

    return [list $lambda $phi]
}

# ::mapproj::toStereographic --
#
#	Transforms latitude and longitude to x and y co-ordinates
#	on an orthographic projection.  Scale is true only at the
#	point of projection.
#
# Parameters:
#	lambda_0, phi_0 -- Longitude and latitude of the center of projection
#			   in degrees
#	lambda, phi -- Longitude and latitude of the point to be projected
#		       in degrees
#
# Results:
#	Returns map x and y co-ordinates, in Earth radii.

proc ::mapproj::toStereographic {lambda_0 phi_0 lambda phi} {
    foreach {x y z} [ToCartesian [expr {$lambda-$lambda_0}] $phi] \
	break
    foreach {x y z} [RotateCartesianY [expr {-$phi_0}] $x $y $z] \
	break
    if {$x < -0.5} {
	return {}
    } else {
	set y [expr {2. * $y / (1. + $x)}]
	set z [expr {2. * $z / (1. + $x)}]
	return [list $y $z]
    }
}

# ::mapproj::fromStereographic --
#
#	Transforms x and y on an orthographic projection to latitude
#	and longitude.
#
# Parameters:
#	lambda_0, phi_0 -- Longitude and latitude of the center of projection
#			   in degrees
#	x, y -- Co-ordinates of the projected point, in Earth radii
#
# Results:
#	Returns a two element list containing longitude and latitude
#	in degrees.

proc ::mapproj::fromStereographic {lambda_0 phi_0 x y} {
    variable radian
    variable halfpi
    set denom [expr {4.0 + $x*$x + $y*$y}]
    foreach {x y z} [list \
			 [expr {(4.0 - $x*$x - $y*$y) / $denom}] \
			 [expr {4. * $x / $denom}] \
			 [expr {4. * $y / $denom}]] break
    
    foreach {x y z} [RotateCartesianY $phi_0 $x $y $z] break
    foreach {lambda phi} [CartesianToSpherical $x $y $z] break

    # Convert latitude and longitude to degrees

    set lambda [expr {$lambda * $radian + 180. + $lambda_0}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    set phi [expr {$phi * $radian}]

    return [list $lambda $phi]
}

# ::mapproj::toGnomonic --
#
#	Transforms latitude and longitude to x and y co-ordinates
#	on an orthographic projection.  Scale is true only at the
#	point of projection.
#
# Parameters:
#	lambda_0, phi_0 -- Longitude and latitude of the center of projection
#			   in degrees
#	lambda, phi -- Longitude and latitude of the point to be projected
#		       in degrees
#
# Results:
#	Returns map x and y co-ordinates, in Earth radii.

proc ::mapproj::toGnomonic {lambda_0 phi_0 lambda phi} {
    foreach {x y z} [ToCartesian [expr {$lambda-$lambda_0}] $phi] \
	break
    foreach {x y z} [RotateCartesianY [expr {-$phi_0}] $x $y $z] \
	break
    if {$x < 0.01} {
	return {}
    } else {
	set y [expr {$y / $x}]
	set z [expr {$z / $x}]
	return [list $y $z]
    }
}

# ::mapproj::fromGnomonic --
#
#	Transforms x and y on an orthographic projection to latitude
#	and longitude.
#
# Parameters:
#	lambda_0, phi_0 -- Longitude and latitude of the center of projection
#			   in degrees
#	x, y -- Co-ordinates of the projected point, in Earth radii
#
# Results:
#	Returns a two element list containing longitude and latitude
#	in degrees.

proc ::mapproj::fromGnomonic {lambda_0 phi_0 x y} {
    variable radian
    variable halfpi
    set denom [expr {hypot(1.0, hypot($x, $y))}]
    foreach {x y z} [list \
			 [expr {1.0 / $denom}] \
			 [expr {$x / $denom}] \
			 [expr {$y / $denom}]] break
    
    foreach {x y z} [RotateCartesianY $phi_0 $x $y $z] break
    foreach {lambda phi} [CartesianToSpherical $x $y $z] break

    # Convert latitude and longitude to degrees

    set lambda [expr {$lambda * $radian + 180. + $lambda_0}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    set phi [expr {$phi * $radian}]

    return [list $lambda $phi]
}

# ::mapproj::toAzimuthalEquidistant --
#
#	Transforms latitude and longitude to x and y co-ordinates
#	on an orthographic projection.  Scale is true only at the
#	point of projection.
#
# Parameters:
#	lambda_0, phi_0 -- Longitude and latitude of the center of projection
#			   in degrees
#	lambda, phi -- Longitude and latitude of the point to be projected
#		       in degrees
#
# Results:
#	Returns map x and y co-ordinates, in Earth radii.

proc ::mapproj::toAzimuthalEquidistant {lambda_0 phi_0 lambda phi} {
    foreach {x y z} [ToCartesian [expr {$lambda-$lambda_0}] $phi] \
	break
    foreach {x y z} [RotateCartesianY [expr {-$phi_0}] $x $y $z] \
	break
    foreach {cs sn range} [CartesianToRangeAndBearing $x $y $z] break
    return [list [expr {$cs * $range}] [expr {$sn * $range}]]
}

# ::mapproj::fromAzimuthalEquidistant --
#
#	Transforms x and y on an orthographic projection to latitude
#	and longitude.
#
# Parameters:
#	lambda_0, phi_0 -- Longitude and latitude of the center of projection
#			   in degrees
#	x, y -- Co-ordinates of the projected point, in Earth radii
#
# Results:
#	Returns a two element list containing longitude and latitude
#	in degrees.

proc ::mapproj::fromAzimuthalEquidistant {lambda_0 phi_0 x y} {
    variable radian
    variable halfpi

    set range [expr {hypot($y, $x)}]
    set cos_b [expr {$x / $range}]
    set sin_b [expr {$y / $range}]
    foreach {x y z} [RangeAndBearingToCartesian $cos_b $sin_b $range] break
    foreach {x y z} [RotateCartesianY $phi_0 $x $y $z] break
    foreach {lambda phi} [CartesianToSpherical $x $y $z] break

    # Convert latitude and longitude to degrees

    set lambda [expr {$lambda * $radian + 180. + $lambda_0}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    set phi [expr {$phi * $radian}]

    return [list $lambda $phi]
}

# ::mapproj::toLambertAzimuthalEqualArea --
#
#	Transforms latitude and longitude to x and y co-ordinates
#	on an orthographic projection.  Scale is true only at the
#	point of projection.
#
# Parameters:
#	lambda_0, phi_0 -- Longitude and latitude of the center of projection
#			   in degrees
#	lambda, phi -- Longitude and latitude of the point to be projected
#		       in degrees
#
# Results:
#	Returns map x and y co-ordinates, in Earth radii.

proc ::mapproj::toLambertAzimuthalEqualArea {lambda_0 phi_0 lambda phi} {
    foreach {x y z} [ToCartesian [expr {$lambda-$lambda_0}] $phi] \
	break
    foreach {x y z} [RotateCartesianY [expr {-$phi_0}] $x $y $z] \
	break
    foreach {cs sn range} [CartesianToRangeAndBearing $x $y $z] break
    set range [expr {2.0 * sin(0.5 * $range)}]
    return [list [expr {$cs * $range}] [expr {$sn * $range}]]
}

# ::mapproj::fromLambertAzimuthalEqualArea --
#
#	Transforms x and y on an orthographic projection to latitude
#	and longitude.
#
# Parameters:
#	lambda_0, phi_0 -- Longitude and latitude of the center of projection
#			   in degrees
#	x, y -- Co-ordinates of the projected point, in Earth radii
#
# Results:
#	Returns a two element list containing longitude and latitude
#	in degrees.

proc ::mapproj::fromLambertAzimuthalEqualArea {lambda_0 phi_0 x y} {
    variable radian
    variable halfpi

    set range [expr {hypot($y, $x)}]
    set cos_b [expr {$x / $range}]
    set sin_b [expr {$y / $range}]
    set range [expr {2.0 * asin(0.5 * $range)}]
    foreach {x y z} [RangeAndBearingToCartesian $cos_b $sin_b $range] break
    foreach {x y z} [RotateCartesianY $phi_0 $x $y $z] break
    foreach {lambda phi} [CartesianToSpherical $x $y $z] break

    # Convert latitude and longitude to degrees

    set lambda [expr {$lambda * $radian + 180. + $lambda_0}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    set phi [expr {$phi * $radian}]

    return [list $lambda $phi]
}

# ::mapproj::toHammer --
#
#	Transforms latitude and longitude to x and y co-ordinates
#	on an orthographic projection.  Scale is true only at the
#	point of projection.
#
# Parameters:
#	lambda_0-- Longitude of the center of projection
#			   in degrees
#	lambda, phi -- Longitude and latitude of the point to be projected
#		       in degrees
#
# Results:
#	Returns map x and y co-ordinates, in Earth radii.

proc ::mapproj::toHammer {lambda_0 lambda phi} {
    set lambda [expr {$lambda - $lambda_0 + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.0}]
    foreach {x y z} [ToCartesian [expr {$lambda/2.}] $phi] \
	break
    foreach {cs sn range} [CartesianToRangeAndBearing $x $y $z] break
    set range [expr {2.0 * sin(0.5 * $range)}]
    return [list [expr {2.0 * $cs * $range}] [expr {$sn * $range}]]
}

# ::mapproj::fromHammer --
#
#	Transforms x and y on an orthographic projection to latitude
#	and longitude.
#
# Parameters:
#	lambda_0, phi_0 -- Longitude and latitude of the center of projection
#			   in degrees
#	x, y -- Co-ordinates of the projected point, in Earth radii
#
# Results:
#	Returns a two element list containing longitude and latitude
#	in degrees.

proc ::mapproj::fromHammer {lambda_0 x y} {
    variable radian
    variable halfpi

    set x [expr {0.5 * $x}]
    set range [expr {hypot($y, $x)}]
    set cos_b [expr {$x / $range}]
    set sin_b [expr {$y / $range}]
    set range [expr {2.0 * asin(0.5 * $range)}]
    foreach {x y z} [RangeAndBearingToCartesian $cos_b $sin_b $range] break
    foreach {lambda phi} [CartesianToSpherical $x $y $z] break

    # Convert latitude and longitude to degrees

    set lambda [expr {2.0 * $lambda * $radian + 180. + $lambda_0}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    set phi [expr {$phi * $radian}]

    return [list $lambda $phi]
}

# ::mapproj::toConicEquidistant
#
#	Converts latitude and longitude to map co-ordinates on a
#	conic equidistant projection.
#
# Parameters:
#	lambda_0, phi_0 -- Longitude and latitude of the center of the sheet.
#	phi_1, phi_2 -- Latitudes of the two standard parallels at which scale
#			is true
#	lambda, phi -- Longitude and latitude of the point to be projected
#
# Results:
#	Returns a list of map x and y measured in Earth radii.

proc ::mapproj::toConicEquidistant {lambda_0 phi_0 phi_1 phi_2 lambda phi} {
    variable degree
    set phi_0 [expr {$phi_0 * $degree}]
    set phi_1 [expr {$phi_1 * $degree}]
    set phi_2 [expr {$phi_2 * $degree}]
    set lambda [expr {$lambda - $lambda_0 + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {($lambda - 180.0) * $degree}]
    set phi [expr {$phi * $degree}]
    set cos_phi_1 [expr {cos($phi_1)}]
    set n [expr {($cos_phi_1 - cos($phi_2)) / ($phi_2 - $phi_1)}]
    set G [expr {$cos_phi_1 / $n + $phi_1}]
    set rho_0 [expr {$G - $phi_0}]
    set theta [expr {$n * $lambda}]
    set rho [expr {$G - $phi}]
    set x [expr {$rho * sin($theta)}]
    set y [expr {$rho_0 - $rho * cos($theta)}]
    return [list $x $y]
}

# ::mapproj::fromConicEquidistant --
#
#	Unprojects map x and y in a conic equidistant projection to
#	latitude and longitude
#
# Parameters:
#	lambda_0, phi_0 -- Longitude and latitude of the center of the sheet.
#	phi_1, phi_2 -- Latitudes of the two standard parallels at which scale
#			is true
#	x, y -- Map co-ordinates in Earth radii
#
# Results:
#	Returns a list of longitude and latitude in degrees.

proc ::mapproj::fromConicEquidistant {lambda_0 phi_0 phi_1 phi_2 x y} {
    variable degree
    variable radian
    set phi_0 [expr {$phi_0 * $degree}]
    set phi_1 [expr {$phi_1 * $degree}]
    set phi_2 [expr {$phi_2 * $degree}]
    set cos_phi_1 [expr {cos($phi_1)}]
    set n [expr {($cos_phi_1 - cos($phi_2)) / ($phi_2 - $phi_1)}]
    set G [expr {$cos_phi_1 / $n + $phi_1}]
    set rho_0 [expr {$G - $phi_0}]
    set rho_0my [expr {$rho_0 - $y}]
    set theta [expr {atan2($x, $rho_0my)}]
    set rho [expr {sqrt($x*$x + $rho_0my * $rho_0my)}]
    if {$n < 0.0} {set rho [expr {-$rho}]}
    set phi [expr {($G - $rho) * $radian}]
    set lambda [expr {($theta / $n * $radian) + $lambda_0 + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    return [list $lambda $phi]
}

# ::mapproj::toAlbersEqualAreaConic
#
#	Converts latitude and longitude to map co-ordinates on a
#	conic equal-area projection.
#
# Parameters:
#	lambda_0, phi_0 -- Longitude and latitude of the center of the sheet.
#	phi_1, phi_2 -- Latitudes of the two standard parallels at which scale
#			is true
#	lambda, phi -- Longitude and latitude of the point to be projected
#
# Results:
#	Returns a list of map x and y measured in Earth radii.

proc ::mapproj::toAlbersEqualAreaConic {lambda_0 phi_0 phi_1 phi_2 lambda phi} {
    variable degree
    set phi_0 [expr {$phi_0 * $degree}]
    set phi_1 [expr {$phi_1 * $degree}]
    set phi_2 [expr {$phi_2 * $degree}]
    set lambda [expr {$lambda - $lambda_0 + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {($lambda - 180.0) * $degree}]
    set phi [expr {$phi * $degree}]
    set cos_phi_1 [expr {cos($phi_1)}]
    set sin_phi_1 [expr {sin($phi_1)}]
    set n [expr {0.5 * ($sin_phi_1 + sin($phi_2))}]
    set theta [expr {$n * $lambda}]
    set C [expr {$cos_phi_1 * $cos_phi_1 + 2.0 * $n * $sin_phi_1}]
    set rho [expr {sqrt($C - 2.0 * $n * sin($phi)) / $n}]
    set rho_0 [expr {sqrt($C - 2.0 * $n * sin($phi_0)) / $n}]
    set x [expr {$rho * sin($theta)}]
    set y [expr {$rho_0 - $rho * cos($theta)}]
    return [list $x $y]
}

# ::mapproj::fromAlbersEqualAreaConic --
#
#	Unprojects map x and y in a conic equal-area projection to
#	latitude and longitude
#
# Parameters:
#	lambda_0, phi_0 -- Longitude and latitude of the center of the sheet.
#	phi_1, phi_2 -- Latitudes of the two standard parallels at which scale
#			is true
#	x, y -- Map co-ordinates in Earth radii
#
# Results:
#	Returns a list of longitude and latitude in degrees.

proc ::mapproj::fromAlbersEqualAreaConic {lambda_0 phi_0 phi_1 phi_2 x y} {
    variable degree
    variable radian
    variable twopi
    set phi_0 [expr {$phi_0 * $degree}]
    set phi_1 [expr {$phi_1 * $degree}]
    set phi_2 [expr {$phi_2 * $degree}]
    set cos_phi_1 [expr {cos($phi_1)}]
    set sin_phi_1 [expr {sin($phi_1)}]
    set n [expr {0.5 * ($sin_phi_1 + sin($phi_2))}]
    set C [expr {$cos_phi_1 * $cos_phi_1 + 2.0 * $n * $sin_phi_1}]
    set rho_0 [expr {sqrt($C - 2.0 * $n * sin($phi_0)) / $n}]
    set theta [expr {atan2($x, $rho_0 - $y)}]
    set rho [expr {hypot($x, $rho_0 - $y)}]
    set phi [expr {$radian * asin(($C - $rho*$rho*$n*$n) / (2.0 * $n))}]
    set lambda [expr {($theta / $n * $radian) + $lambda_0 + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    return [list $lambda $phi]
}

# ::mapproj::toLambertConformalConic
#
#	Converts latitude and longitude to map co-ordinates on a
#	conformal conic projection.
#
# Parameters:
#	lambda_0, phi_0 -- Longitude and latitude of the center of the sheet.
#	phi_1, phi_2 -- Latitudes of the two standard parallels at which scale
#			is true
#	lambda, phi -- Longitude and latitude of the point to be projected
#
# Results:
#	Returns a list of map x and y measured in Earth radii.

proc ::mapproj::toLambertConformalConic {lambda_0 phi_0 phi_1 phi_2 lambda phi} {
    variable degree
    variable quarterpi
    set phi_0 [expr {$phi_0 * $degree}]
    set phi_1 [expr {$phi_1 * $degree}]
    set phi_2 [expr {$phi_2 * $degree}]
    set lambda [expr {$lambda - $lambda_0 + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {($lambda - 180.0) * $degree}]
    set phi [expr {$phi * $degree}]
    set cos_phi_1 [expr {cos($phi_1)}]
    set sin_phi_1 [expr {sin($phi_1)}]
    set tan1 [expr {tan($quarterpi + 0.5 * $phi_1)}]
    set n [expr {log($cos_phi_1 / cos($phi_2))
		 / log(tan($quarterpi + 0.5 * $phi_2) / $tan1)}]
    set F [expr {$cos_phi_1 * pow($tan1, $n) / $n}]
    set rho [expr {$F * pow(tan($quarterpi + 0.5 * $phi), -$n)}]
    set rho_0 [expr {$F * pow(tan($quarterpi + 0.5 * $phi_0), -$n)}]
    set x [expr {$rho * sin($n * $lambda)}]
    set y [expr {$rho_0 - $rho * cos($n * $lambda)}]
    return [list $x $y]
}

# ::mapproj::fromLambertConformalConic --
#
#	Unprojects map x and y in a conformal conic projection to
#	latitude and longitude
#
# Parameters:
#	lambda_0, phi_0 -- Longitude and latitude of the center of the sheet.
#	phi_1, phi_2 -- Latitudes of the two standard parallels at which scale
#			is true
#	x, y -- Map co-ordinates in Earth radii
#
# Results:
#	Returns a list of longitude and latitude in degrees.

proc ::mapproj::fromLambertConformalConic {lambda_0 phi_0 phi_1 phi_2 x y} {
    variable degree
    variable radian
    variable quarterpi
    set phi_0 [expr {$phi_0 * $degree}]
    set phi_1 [expr {$phi_1 * $degree}]
    set phi_2 [expr {$phi_2 * $degree}]
    set cos_phi_1 [expr {cos($phi_1)}]
    set sin_phi_1 [expr {sin($phi_1)}]
    set tan1 [expr {tan($quarterpi + 0.5 * $phi_1)}]
    set n [expr {log($cos_phi_1 / cos($phi_2))
		 / log(tan($quarterpi + 0.5 * $phi_2) / $tan1)}]
    set F [expr {$cos_phi_1 * pow($tan1, $n) / $n}]
    set rho_0 [expr {$F * pow(tan($quarterpi + 0.5 * $phi_0), -$n)}]
    set y [expr {$rho_0 - $y}]
    set rho [expr {sqrt($x*$x + $y*$y)}]
    if {$n < 0} { set rho [expr {-$rho}] }
    set theta [expr {atan2($x, $y)}]
    set phi [expr {$radian * 2 * atan(pow($F / $rho, 1.0 / $n)) - 90.}]
    set lambda [expr {($theta / $n * $radian) + $lambda_0 + 180.}]
    if {$lambda < 0.0 || $lambda > 360.0} {
	set lambda [expr {$lambda - 360. * floor($lambda / 360.)}]
    }
    set lambda [expr {$lambda - 180.}]
    return [list $lambda $phi]
}

# Define commonly used cylindrical equal-area projections

proc ::mapproj::toLambertCylindricalEqualArea {lambda_0 phi_0 lambda phi} {
    toCylindricalEqualArea 0.0 $lambda_0 $phi_0 $lambda $phi
}
proc ::mapproj::fromLambertCylindricalEqualArea {lambda_0 phi_0 x y} {
    fromCylindricalEqualArea 0.0 $lambda_0 $phi_0 $x $y
}
proc ::mapproj::toBehrmann {lambda_0 phi_0 lambda phi} {
    toCylindricalEqualArea 30.0 $lambda_0 $phi_0 $lambda $phi
}
proc ::mapproj::fromBehrmann {lambda_0 phi_0 x y} {
    fromCylindricalEqualArea 30.0 $lambda_0 $phi_0 $x $y
}
proc ::mapproj::toTrystanEdwards {lambda_0 phi_0 lambda phi} {
    toCylindricalEqualArea 37.4 $lambda_0 $phi_0 $lambda $phi
}
proc ::mapproj::fromTrystanEdwards {lambda_0 phi_0 x y} {
    fromCylindricalEqualArea 37.4 $lambda_0 $phi_0 $x $y
}
proc ::mapproj::toHoboDyer {lambda_0 phi_0 lambda phi} {
    toCylindricalEqualArea 37.5 $lambda_0 $phi_0 $lambda $phi
}
proc ::mapproj::fromHoboDyer {lambda_0 phi_0 x y} {
    fromCylindricalEqualArea 37.5 $lambda_0 $phi_0 $x $y
}
proc ::mapproj::toGallPeters {lambda_0 phi_0 lambda phi} {
    toCylindricalEqualArea 45.0 $lambda_0 $phi_0 $lambda $phi
}
proc ::mapproj::fromGallPeters {lambda_0 phi_0 x y} {
    fromCylindricalEqualArea 45.0 $lambda_0 $phi_0 $x $y
}
proc ::mapproj::toBalthasart {lambda_0 phi_0 lambda phi} {
    toCylindricalEqualArea 50.0 $lambda_0 $phi_0 $lambda $phi
}
proc ::mapproj::fromBalthasart {lambda_0 phi_0 x y} {
    fromCylindricalEqualArea 50.0 $lambda_0 $phi_0 $x $y
}
