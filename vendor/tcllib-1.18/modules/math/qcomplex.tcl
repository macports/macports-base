# qcomplex.tcl --
#    Small module for dealing with complex numbers
#    The design goal was to make the operations as fast
#    as possible, not to offer a nice interface. So:
#    - complex numbers are represented as lists of two elements
#    - there is hardly any error checking, all arguments are assumed
#      to be complex numbers already (with a few obvious exceptions)
#    Missing:
#    the inverse trigonometric functions and the hyperbolic functions
#

namespace eval ::math::complexnumbers {
    namespace export + - / * conj exp sin cos tan real imag mod arg log pow sqrt tostring
}

# complex --
#    Create a new complex number
# Arguments:
#    real      The real part
#    imag      The imaginary part
# Result:
#    New complex number
#
proc ::math::complexnumbers::complex {real imag} {
    return [list $real $imag]
}

# binary operations --
#    Implement the basic binary operations
# Arguments:
#    z1        First argument
#    z2        Second argument
# Result:
#    New complex number
#
proc ::math::complexnumbers::+ {z1 z2} {
    set result {}
    foreach c $z1 d $z2 {
        lappend result [expr {$c+$d}]
    }
    return $result
}
proc ::math::complexnumbers::- {z1 {z2 {}}} {
    if { $z2 == {} } {
        set z2 $z1
        set z1 {0.0 0.0}
    }
    set result {}
    foreach c $z1 d $z2 {
        lappend result [expr {$c-$d}]
    }
    return $result
}
proc ::math::complexnumbers::* {z1 z2} {
    set result {}
    foreach {c1 d1} $z1 {break}
    foreach {c2 d2} $z2 {break}

    return [list [expr {$c1*$c2-$d1*$d2}] [expr {$c1*$d2+$c2*$d1}]]
}
proc ::math::complexnumbers::/ {z1 z2} {
    set result {}
    foreach {c1 d1} $z1 {break}
    foreach {c2 d2} $z2 {break}

    set denom [expr {$c2*$c2+$d2*$d2}]
    return [list [expr {($c1*$c2+$d1*$d2)/$denom}] \
                 [expr {(-$c1*$d2+$c2*$d1)/$denom}]]
}

# unary operations --
#    Implement the basic unary operations
# Arguments:
#    z1        Argument
# Result:
#    New complex number
#
proc ::math::complexnumbers::conj {z1} {
    foreach {c d} $z1 {break}
    return [list $c [expr {-$d}]]
}
proc ::math::complexnumbers::real {z1} {
    foreach {c d} $z1 {break}
    return $c
}
proc ::math::complexnumbers::imag {z1} {
    foreach {c d} $z1 {break}
    return $d
}
proc ::math::complexnumbers::mod {z1} {
    foreach {c d} $z1 {break}
    return [expr {hypot($c,$d)}]
}
proc ::math::complexnumbers::arg {z1} {
    foreach {c d} $z1 {break}
    if { $c != 0.0 || $d != 0.0 } {
        return [expr {atan2($d,$c)}]
    } else {
        return 0.0
    }
}

# elementary functions --
#    Implement the elementary functions
# Arguments:
#    z1        Argument
#    z2        Second argument (if any)
# Result:
#    New complex number
#
proc ::math::complexnumbers::exp {z1} {
    foreach {c d} $z1 {break}
    return [list [expr {exp($c)*cos($d)}] [expr {exp($c)*sin($d)}]]
}
proc ::math::complexnumbers::cos {z1} {
    foreach {c d} $z1 {break}
    return [list [expr {cos($c)*cosh($d)}] [expr {-sin($c)*sinh($d)}]]
}
proc ::math::complexnumbers::sin {z1} {
    foreach {c d} $z1 {break}
    return [list [expr {sin($c)*cosh($d)}] [expr {cos($c)*sinh($d)}]]
}
proc ::math::complexnumbers::tan {z1} {
    return [/ [sin $z1] [cos $z1]]
}
proc ::math::complexnumbers::log {z1} {
    return [list [expr {log([mod $z1])}] [arg $z1]]
}
proc ::math::complexnumbers::sqrt {z1} {
    set argz [expr {0.5*[arg $z1]}]
    set modz [expr {sqrt([mod $z1])}]
    return [list [expr {$modz*cos($argz)}] [expr {$modz*sin($argz)}]]
}
proc ::math::complexnumbers::pow {z1 z2} {
    return [exp [* [log $z1] $z2]]
}
# transformational functions --
#    Implement transformational functions
# Arguments:
#    z1        Argument
# Result:
#    String like 1+i
#
proc ::math::complexnumbers::tostring {z1} {
    foreach {c d} $z1 {break}
    if { $d == 0.0 } {
        return "$c"
    } else {
        if { $c == 0.0 } {
            if { $d == 1.0 } {
                return "i"
            } elseif { $d == -1.0 } {
                return "-i"
            } else {
                return "${d}i"
            }
        } else {
            if { $d > 0.0 } {
                if { $d == 1.0 } {
                    return "$c+i"
                } else {
                    return "$c+${d}i"
                }
            } else {
                if { $d == -1.0 } {
                    return "$c-i"
                } else {
                    return "$c${d}i"
                }
            }
        }
    }
}

#
# Announce our presence
#
package provide math::complexnumbers 1.0.2
