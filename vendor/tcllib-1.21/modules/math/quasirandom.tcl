# quasirandom.tcl --
#     Generate quasi-random points in n dimensions and provide simple
#     methods to evaluate an integral
#
#     Note: provide a OO-style interface
#
#     TODO: integral-detailed, minimum, maximum
#
#     Based on the blog "The Unreasonable Effectiveness of Quasirandom Sequences" by Martin Roberts,
#     http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
#

package require Tcl 8.5
package require TclOO

package provide math::quasirandom 1.0

namespace eval ::math::quasirandom {

# qrpoints --
#     Create the class
#
::oo::class create qrpoints {

    # constructor --
    #     Construct a new instance of the qrpoints class
    #
    # Arguments:
    #     dim             Number of dimensions, or one of: circle, disk, sphere, ball
    #     args            Zero or more key-value pairs:
    #                     -start       - start the generation with the given multiplier (integer)
    #                     -evaluations - default number of evaluations for the integration
    #                     (possibly others as well)
    #
    constructor {dimin args} {
        my variable dim
        my variable coord_factors
        my variable step
        my variable evaluations
        my variable use_radius
        my variable effective_dim

        if { ( ![string is integer -strict $dimin] || $dimin <= 0 ) && $dimin ni {circle disk sphere ball} } {
            return -code error "The dimension argument should be a positive integer value or one of circle, disk, sphere or ball"
        }

        set use_radius 1
        switch -- $dimin {
            "circle" {
                set dim 1
                set effective_dim 2
                ::oo::objdefine [self] {
                    forward next   my CircleNext
                    forward Volume my CircleVolume
                }
            }
            "disk" {
                set dim 2
                set effective_dim 2
                ::oo::objdefine [self] {
                    forward next   my DiskNext
                    forward Volume my DiskVolume
                }
            }
            "sphere" {
                set dim 2
                set effective_dim 3
                ::oo::objdefine [self] {
                    forward next   my SphereNext
                    forward Volume my SphereVolume
                }
            }
            "ball" {
                set dim 3
                set effective_dim 3
                ::oo::objdefine [self] {
                    forward next   my BallNext
                    forward Volume my BallVolume
                }
            }
            default {
                set dim $dimin
                set use_radius 0
                ::oo::objdefine [self] {
                    forward next   my PlainNext
                    forward Volume my PlainVolume
                }
            }
        }

        set step        1
        set evaluations 100

        set coord_factors [::math::quasirandom::CoordFactors $dim]

        foreach {key value} $args {
            switch -- $key {
            "-start" {

                 my set-step $value
            }
            "-evaluations" {
                 if { ![string is -strict integer $value] || $value <= 0 } {
                     return -code error "The value for the option $key should be a positive integer value"
                 }

                 my set-evaluations $value
            }
            default {
                return -code error "Unknown option: $key -- value: $value"
            }
            }
        }
    }

    # PlainNext --
    #     Generate the next point - for a hyperblock
    #
    method PlainNext {} {
        my variable step
        my variable coord_factors

        set coords {}
        foreach f $coord_factors {
            lappend coords [expr {fmod( $f * $step, 1.0 )}]
        }

        incr step

        return $coords
    }

    # PlainVolume --
    #     Calculate the volume of a hyperblock
    #
    # Arguments:
    #     minmax              List of minimum and maximum per dimension
    #
    # Returns:
    #     The volume
    #
    method PlainVolume {minmax} {
        set volume 1.0
        foreach range $minmax {
            lassign $range xmin xmax
            set volume [expr {$volume * ($xmax-$xmin)}]
        }
        return $volume
    }

    # CircleNext --
    #     Generate the next point on a unit circle
    #
    method CircleNext {} {

        set f      [lindex [my PlainNext] 0]
        set rad    [expr {2.0 * acos(-1.0) * $f}]

        set coords [list [expr {cos($rad)}] [expr {sin($rad)}]]

        return $coords
    }

    # CircleVolume --
    #     Calculate the "volume" of the unit circle
    #
    # Arguments:
    #     radius        Radius of the circle
    #
    method CircleVolume {radius} {
         return [expr {$radius * 2.0*cos(-1.0)}]
    }

    # DiskNext --
    #     Generate the next point on a unit disk
    #
    method DiskNext {} {

        while {1} {
            set coords [my PlainNext]

            lassign $coords x y

            if { hypot($x-0.5,$y-0.5) <= 0.25 } {
                set coords [list [expr {2.0*$x-1.0}] [expr {2.0*$y-1.0}]]
                break
            }
        }
        return $coords
    }

    # DiskVolume --
    #     Calculate the "volume" of the unit disk
    #
    # Arguments:
    #     radius        Radius of the disk
    #
    method DiskVolume {radius} {
         return [expr {$radius**2 * cos(-1.0)}]
    }

    # BallNext --
    #     Generate the next point on a unit ball
    #
    method BallNext {} {

        while {1} {
            set coords [my PlainNext]

            lassign $coords x y z

            set r [expr {($x-0.5)**2 + ($y-0.5)**2 + ($z-0.5)**2}]
            if { $r <= 0.25 } {
                set coords [list [expr {2.0*$x-1.0}] [expr {2.0*$y-1.0}] [expr {2.0*$z-1.0}]]
                break
            }
        }

        return $coords
    }

    # BallVolume --
    #     Calculate the volume of the unit ball
    #
    # Arguments:
    #     radius        Radius of the ball
    #
    method BallVolume {radius} {
         return [expr {4.0/3.0 * $radius**3 * cos(-1.0)}]
    }

    # SphereNext --
    #     Generate the next point on a unit sphere
    #
    method SphereNext {} {

        set coords [my PlainNext]

        lassign $coords u v

        set phi    [expr {2.0 * acos(-1.0) * $v}]
        set lambda [expr {acos(2.0 * $u - 1.0) + 0.5 * acos(-1.0)}]

        set x      [expr {cos($lambda) * cos($phi)}]
        set y      [expr {cos($lambda) * sin($phi)}]
        set z      [expr {sin($lambda)}]

        return [list $x $y $z]
    }

    # SphereVolume --
    #     Calculate the "volume" of the unit sphere
    #
    # Arguments:
    #     radius        Radius of the sphere
    #
    method SphereVolume {radius} {
         return [expr {4.0 * $radius**2 * cos(-1.0)}]
    }

    # set-step --
    #     Set the first step to be used
    #
    method set-step {{value ""}} {
        my variable step

        if { $value eq "" } {
            return $step
        }

        if { ![string is integer -strict $value] } {
            return -code error "The value for the option $key should be an integer value"
        }

        set step [expr {int($value)}]
    }

    # set-evaluations --
    #     Set the number of evaluations for integration
    #
    method set-evaluations {{value ""}} {
        my variable evaluations

        if { $value eq "" } {
            return $evaluations
        }

        if { ![string is integer -strict $value] || $value <= 0 } {
            return -code error "The value for the option $key should be a positive integer value"
        }

        set evaluations [expr {4*int(($value+3)/4)}]  ;# Make sure it is a 4-fold
    }

    # integral --
    #     Evaluate the integral of a function over a given (rectangular) domain
    #
    # Arguments:
    #     func              Function to be integrated
    #     minmax            List of minimum and maximum bounds for each coordinate
    #     args              Key-value pair: number of evaluations
    #
    # Returns:
    #     Estimate of the integral based on "evaluations" evaluations
    #     Note: no error estimate
    #
    method integral {func minmax args} {
        my variable dim
        my variable step
        my variable coord_factors
        my variable evaluations
        my variable use_radius
        my variable effective_dim

        set evals $evaluations

        set func [uplevel 1 [list namespace which -command $func]]

        foreach {key value} $args {
            switch -- $key {
            "-evaluations" {
                 if { ![string is integer -strict $value] || $value <= 0 } {
                     return -code error "The value for the option $key should be a positive integer value"
                 }

                 set evals $value ;# Local only!
            }
            default {
                return -code error "Unknown option: $key -- value: $value"
            }
            }
        }

        if { ! $use_radius } {
            if { [llength $minmax] != $dim } {
                return -code error "The number of ranges (minmax) should be equal to the dimension ($dim)"
            } else {
                set volume [my Volume $minmax]
            }
        } else {
            if { ! [string is double $minmax] } {
                return -code error "For a circle, disk, sphere or ball only the radius should be given"
            } else {
                set radius $minmax
                set minmax [lrepeat $effective_dim [list 0.0 $radius]]
                set volume [my Volume $radius]
            }
        }

        set sum 0.0

        for {set i 0} {$i < $evals} {incr i} {
            set coords {}
            foreach c [my next] range $minmax {
                lassign $range xmin xmax
                lappend coords [expr {$xmin + ($xmax-$xmin) * $c}]
            }
            set sum [expr {$sum + [$func $coords]}]
        }

        return [expr {$sum * $volume / $evals}]
    }

    # integral-detailed --
    #     Evaluate the integral of a function over a given (rectangular) domain
    #     and provide detailed information
    #
    # Arguments:
    #     func              Function to be integrated
    #     minmax            List of minimum and maximum bounds for each coordinate
    #     args              Key-value pair: number of evaluations
    #
    # Returns:
    #     Dictionary of:
    #     -estimate value     - estimate of the integral
    #     -evaluations number - total number of evaluations
    #     -error value        - estimate of the error
    #     -rawvalues list     - list of raw values obtained for the integral
    #
    method integral-detailed {func minmax args} {
        my variable evaluations

        set evals $evaluations

        set func [uplevel 1 [list namespace which -command $func]]

        foreach {key value} $args {
            switch -- $key {
            "-evaluations" {
                 if { ![string is integer -strict $value] || $value <= 0 } {
                     return -code error "The value for the option $key should be a positive integer value"
                 }

                 set evals $value ;# Local only!
            }
            default {
                return -code error "Unknown option: $key -- value: $value"
            }
            }
        }

        lappend args -evaluations [expr {($evals+3)/4}]

        for {set i 0} {$i < 4} {incr i} {
            lappend rawvalues [my integral $func $minmax {*}$args]
        }

        set sum   0.0
        set sqsum 0.0

        foreach value $rawvalues {
            set sum   [expr {$sum + $value}]
            set sqsum [expr {$sqsum + $value**2}]
        }

        set stdev [expr {sqrt(($sqsum - $sum**2/4.0)/3.0)}]
        set sum   [expr {$sum / 4.0}]
                                            # Standard error of mean
        return [dict create -estimate $sum -error [expr {$stdev/2.0}] -rawvalues $rawvalues -evaluations [expr {4*(($evals+3)/4)}]]
    }

} ;# End of class

} ;# End of namespace eval

# CoordFactors --
#     Determine the factors for the coordinates
#
# Arguments:
#     dim         Number of dimensions
#
proc ::math::quasirandom::CoordFactors {dim} {
    set n [expr {$dim + 1}]

    set f 1.0
    for {set i 0} {$i < 10} {incr i} {
        set f [expr {$f - ($f**$n-$f-1.0) / ($n*$f**($n-1)-1.0)}]
    }

    set factors {}
    set af      1.0

    for {set i 0} {$i < $dim} {incr i} {
        set af [expr {$af/$f}]
        lappend factors $af
    }

    return $factors
}

# End of code for package

# --------------------------------------------
# test --
#

if {0} {

::math::quasirandom::qrpoints create square 2

puts [square next]
puts [square next]
puts [square next]


proc f {coords} {
    lassign $coords x y

    expr {$x**2+$y**2}
}

proc g {coords} {
    lassign $coords x y

    expr {(1.0-cos($x))**2 * (1.0-cos($y))**2}
}

# Print four estimates - should not deviate too much from 10.0
puts [square integral f {{0 1} {0 3}}]
puts [square integral f {{0 1} {0 3}}]
puts [square integral f {{0 1} {0 3}}]
puts [square integral f {{0 1} {0 3}}]

# Print a sequence of estimates - should converge to (3pi/2)**2
foreach n {20 40 100 300 1000} {
    square set-evaluations $n

    puts "$n: [square integral g [list [list 0.0 [expr {acos(-1)}]] [list 0.0 [expr {acos(-1)}]]]]"
}


::math::quasirandom::qrpoints create block 3
puts [block next]

puts "Circle ..."
::math::quasirandom::qrpoints create circle circle
puts [circle next]
puts [circle next]
puts [circle next]

# Test values for CoordFactors
# dim = 1: 1.6180339887498948482045...
# dim = 2: 1.3247179572447460259609...
# dim = 3: 1.2207440846057594753616...

set f [::math::quasirandom::CoordFactors 1]
puts 1.6180339887498948482045...
puts [expr {1.0/$f}]

set f [lindex [::math::quasirandom::CoordFactors 2] 0]
puts 1.3247179572447460259609...
puts [expr {1.0/$f}]

set f [lindex [::math::quasirandom::CoordFactors 3] 0]
puts 1.2207440846057594753616...
puts [expr {1.0/$f}]
}
