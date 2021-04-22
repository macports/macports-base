# trig.tcl --
#     Package for additional trigonometric and hyperbolic functions
#
#     Besides the ordinary functions that take/return angles in radians,
#     also versions that use angles in degrees.
#
#     See tickets https://core.tcl-lang.org/tcllib/tktview/df3676c9821ba917c5cfda68c2ea0ad7a6947ac9
#     and https://core.tcl-lang.org/tcllib/tktview/21fef042b91ca252fc2a20ead5cd05c2b51b1776
#
package provide math::trig 1.0

# ::math::trig --
#     Create the namespace
#
namespace eval ::math::trig {
    namespace export radian_reduced degree_reduced \
                     cosec sec cotan acosec asec acotan \
                     cosech sech cotanh asinh acosh atanh acosech asech acotanh \
                     sind cosd tand cosecd secd cotand acosecd asecd acotand

    variable pi     [expr {acos(-1.0)}]
    variable twopi  [expr {2.0 * acos(-1.0)}]
    variable halfpi [expr {0.5 * acos(-1.0)}]
    variable torad  [expr {acos(-1.0) / 180.0}]
    variable todeg  [expr {180.0 / acos(-1.0)}]
}

# radian_reduced --
#     Reduce the given value to a value in the interval [0,2pi]
#
# Arguments:
#     angle      Angle in radians that should be reduced
#
# Note:
#     If the angle is very large, then numerical accuracy will
#     diminish, up to a point where the answer is meaningless.
#     This is not (yet) taken care of.
#
proc ::math::trig::radian_reduced {angle} {
    variable twopi

    set n       [expr {int($angle/$twopi)}]
    set reduced [expr {$angle - $n * $twopi}]
    if { $reduced < 0.0 } {
        set reduced [expr {$reduced + $twopi}]
    }

    return $reduced
}

# degree_reduced --
#     Reduce the given value to a value in the interval [0,360]
#
# Arguments:
#     angle      Angle in degrees that should be reduced
#
# Note:
#     If the angle is very large, then numerical accuracy will
#     diminish, up to a point where the answer is meaningless.
#     This is not (yet) taken care of.
#
proc ::math::trig::degree_reduced {angle} {

    set n       [expr {int($angle/360.0)}]
    set reduced [expr {$angle - $n * 360.0}]
    if { $reduced < 0.0 } {
        set reduced [expr {$reduced + 360.0}]
    }

    return $reduced
}


# cosec, sec, cotan --
#     Calculate the cosecans, secans and cotangent
#
# Arguments:
#     angle      Angle in radians
#
proc ::math::trig::cosec {angle} {
    return [expr {1.0 / sin($angle)}]
}

proc ::math::trig::sec {angle} {
    return [expr {1.0 / cos($angle)}]
}

proc ::math::trig::cotan {angle} {
    variable halfpi
    return [expr {tan($halfpi - $angle)}]
}


# cosech, sech, cotanh --
#     Calculate the hyperbolic cosecans, secans and cotangent
#
# Arguments:
#     value      Argument value
#
proc ::math::trig::cosech {value} {
    return [expr {1.0 / sinh($value)}]
}

proc ::math::trig::sech {value} {
    return [expr {1.0 / cosh($value)}]
}

proc ::math::trig::cotanh {value} {
    return [expr {1.0/tanh($value)}]
}


# asinh, acosh, atanh --
#     Calculate the arc hyperbolic sine, cosine and tangent
#
# Arguments:
#     value      Argument value
#
proc ::math::trig::asinh {value} {
    return [expr {log($value + sqrt($value**2 + 1.0))}]
}

proc ::math::trig::acosh {value} {
    if { $value < 1.0 } {
        return -code error "acosh: argument should be larger/equal 1.0"
    }
    return [expr {log($value + sqrt($value**2 - 1.0))}]
}

proc ::math::trig::atanh {value} {
    if { $value <= -1.0 || $value >= 1.0} {
        return -code error "atanh: argument should be between -1.0 and 1.0"
    }
    return [expr {0.5 * log((1.0 + $value) / (1.0 - $value))}]
}


# acosec, asec, acotan --
#     Calculate the arc cosecans, secans and cotangent
#
# Arguments:
#     value      Value for which the angle is sought
#
proc ::math::trig::acosec {value} {
    return [expr {asin(1.0/$value)}]
}

proc ::math::trig::asec {value} {
    return [expr {1.0 / acos($value)}]
}

proc ::math::trig::acotan {value} {
    variable halfpi
    return [expr {atan($halfpi - $angle)}]
}


# acosech, asech, acotanh --
#     Calculate the arc hyperbolic cosecans, secans and cotangent
#
# Arguments:
#     value      Value for which the angle is sought
#
proc ::math::trig::acosech {value} {
    return [asinh [expr {1.0/$value}]]
}

proc ::math::trig::asech {value} {
    return [acosh [expr {1.0/$value}]]
}

proc ::math::trig::acotanh {value} {
    return [atanh [expr {1.0/$value}]]
}

# cossind --
#     Reduce the angle (in degrees) to ensure exact results
#     for multiples of 90 degrees.
#
# Arguments:
#     angle           Angle in degrees
#
# Result:
#     sine and cosine of the angle
#
proc ::math::trig::cossind {angle} {
    variable torad

    set angle [::math::trig::degree_reduced $angle]

    if { $angle <= 45.0 || $angle >= 315.0 } {
        set sind [expr {sin($angle*$torad)}]
        set cosd [expr {cos($angle*$torad)}]
    } elseif { $angle <= 135.0 } {
        set sind [expr {cos(($angle-90.0)*$torad)}]
        set cosd [expr {-sin(($angle-90.0)*$torad)}]
    } elseif { $angle <= 225.0 } {
        set sind [expr {-sin(($angle-180.0)*$torad)}]
        set cosd [expr {-cos(($angle-180.0)*$torad)}]
    } else { ;#elseif { $angle <= 315.0 }
        set sind [expr {-cos(($angle-270.0)*$torad)}]
        set cosd [expr {sin(($angle-270.0)*$torad)}]
    }

    return [list $sind $cosd]
}

# cosd, sind, tand, cosecd, secd, cotand --
#     Trigonometric functions taking the angle in degrees
#
# Arguments:
#     angle            Angle in degrees
#
# Result:
#     cosine, sine, etc. of the given angle
#
proc ::math::trig::cosd {angle} {
    return [lindex [cossind $angle] 1]
}

proc ::math::trig::sind {angle} {
    return [lindex [cossind $angle] 0]
}

proc ::math::trig::tand {angle} {
    lassign [cossind $angle] s c
    return [expr {$s / $c}]
}

proc ::math::trig::cosecd {angle} {
    lassign [cossind $angle] s c
    return [expr {1.0 / $s}]
}

proc ::math::trig::secd {angle} {
    lassign [cossind $angle] s c
    return [expr {1.0 / $c}]
}

proc ::math::trig::cotand {angle} {
    lassign [cossind $angle] s c
    return [expr {$c / $s}]
}

# inverse trigonometric functions
# Do not bother with exactitude in this case
#
proc ::math::trig::acosd {value} {
    variable todeg
    return [expr {$todeg * acos($value)}]
}

proc ::math::trig::asind {value} {
    variable todeg
    return [expr {$todeg * asin($value)}]
}

proc ::math::trig::atand {value} {
    variable todeg
    return [expr {$todeg * atan($value)}]
}

proc ::math::trig::acosecd {value} {
    variable todeg
    return [expr {$todeg * asin(1.0/$value)}]
}

proc ::math::trig::asecd {value} {
    variable todeg
    return [expr {$todeg * acos(1.0/$value)}]
}
proc ::math::trig::acotand {value} {
    variable todeg
    return [expr {$todeg * atan(1.0/$value)}]
}

# tests --
if {0} {
foreach angle {0 30 45 60 90 120 135 150 180 210 225 240 270 300 315 330 360} {
    puts "$angle -- [::math::trig::sind $angle] -- [::math::trig::cosd $angle] [::math::trig::tand $angle]"
}

# simple test
foreach angle {-10 -7 -4 -1 0 2 5 8 11} {
    puts "$angle -- [::math::trig::radian_reduced $angle]"
}
foreach angle {-10 -7 -4 -1 0 2 5 8 11} {
    puts "$angle -- [expr {101.0*$angle}] -- [::math::trig::degree_reduced [expr {101.0*$angle}]]"
}
}
