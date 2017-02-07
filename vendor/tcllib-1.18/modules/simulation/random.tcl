# random.tcl --
#     Create procedures that return various types of pseudo-random
#     number generators (PRNGs)
#
# Copyright (c) 2007 by Arjen Markus <arjenmarkus@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# TODO:
# - Beta
# - Weighted discrete
# - Poisson
# - Cauchy
# - Binomial
#
#     Note:
#     Several formulae and algorithms come from "Monte Carlo Simulation"
#     by C. Mooney (Sage Publications, 1997)
#
# RCS: @(#) $Id: random.tcl,v 1.5 2012/08/15 04:38:48 arjenmarkus Exp $
#------------------------------------------------------------------------------

package require Tcl 8.4

# ::simulation::random --
#     Create the namespace
#
namespace eval ::simulation::random {
    variable count 0
    variable pi    [expr {4.0*atan(1.0)}]
}


# prng_Bernoulli --
#     Create a PRNG with a Bernoulli distribution
#
# Arguments:
#     p         Probability that the outcome will be 1
#
# Result:
#     Name of a procedure that returns a Bernoulli-distributed random number
#
proc ::simulation::random::prng_Bernoulli {p} {
    variable count

    incr count

    set name ::simulation::random::PRNG_$count
    proc $name {} [string map [list P $p] {return [expr {rand()<P? 1 : 0}]}]

    return $name
}


# prng_Uniform --
#     Create a PRNG with a uniform distribution in a given range
#
# Arguments:
#     min       Minimum value
#     max       Maximum value
#
# Result:
#     Name of a procedure that returns a uniformly distributed
#     random number
#
proc ::simulation::random::prng_Uniform {min max} {
    variable count

    incr count

    set name ::simulation::random::PRNG_$count
    set range [expr {$max-$min}]
    proc $name {} [string map [list MIN $min RANGE $range] {return [expr {MIN+RANGE*rand()}]}]

    return $name
}


# prng_Exponential --
#     Create a PRNG with an exponential distribution with given mean
#
# Arguments:
#     min       Minimum value
#     mean      Mean value
#
# Result:
#     Name of a procedure that returns an exponentially distributed
#     random number
#
proc ::simulation::random::prng_Exponential {min mean} {
    variable count

    incr count

    set name ::simulation::random::PRNG_$count
    set b [expr {$mean-$min}]
    proc $name {} [string map [list MIN $min B $b] {return [expr {MIN-B*log(rand())}]}]

    return $name
}


# prng_Discrete --
#     Create a PRNG with a uniform but discrete distribution
#
# Arguments:
#     n         Outcome is an integer between 0 and n-1
#
# Result:
#     Name of a procedure that returns such a random number
#
proc ::simulation::random::prng_Discrete {n} {
    variable count

    incr count

    set name ::simulation::random::PRNG_$count
    proc $name {} [string map [list N $n] {return [expr {int(N*rand())}]}]

    return $name
}


# prng_Poisson --
#     Create a PRNG with a Poisson distribution
#
# Arguments:
#     lambda    The one parameter of the Poisson distribution
#
# Result:
#     Name of a procedure that returns such a random number
#
proc ::simulation::random::prng_Poisson {lambda} {
    variable count

    incr count

    set name ::simulation::random::PRNG_$count

    set explambda [expr {exp(-$lambda)}]

    proc $name {} [string map [list INIT $explambda LAMBDA $lambda] {
        set r      [expr {rand()}]
        set number 0
        set sum    INIT
        set rfact  INIT

        while { $r > $sum } {
            set rfact [expr {$rfact * LAMBDA /($number+1.0)}]
            set sum [expr {$sum + $rfact}]
            incr number
        }
        return $number
    }]

    return $name
}


# prng_Normal --
#     Create a PRNG with a normal distribution
#
# Arguments:
#     mean      Mean of the distribution
#     stdev     Standard deviation of the distribution
#
# Result:
#     Name of a procedure that returns such a random number
#
# Note:
#     Use the Box-Mueller method to generate a normal random number
#
proc ::simulation::random::prng_Normal {mean stdev} {
    variable count

    incr count

    set name ::simulation::random::PRNG_$count
    proc $name {} [string map [list MEAN $mean STDEV $stdev] \
    {
        variable pi
        set rad [expr {sqrt(-2.0*log(rand()))}]
        set phi [expr {2.0*$pi*rand()}]
        set r   [expr {$rad*cos($phi)}]
        return [expr {MEAN + STDEV*$r}]
    }]

    return $name
}


# prng_Pareto --
#     Create a PRNG with a Pareto distribution
#
# Arguments:
#     min       Minimum value for the distribution
#     steep     Steepness of the descent
#
# Result:
#     Name of a procedure that returns a Pareto-distributed number
#
proc ::simulation::random::prng_Pareto {min steep} {
    variable count

    incr count

    set name ::simulation::random::PRNG_$count

    set rsteep [expr {1.0/$steep}]
    proc $name {} [string map [list MIN $min RSTEEP $rsteep] \
    {
        return [expr {MIN * pow(1.0-rand(),RSTEEP)}]
    }]

    return $name
}


# prng_Gumbel --
#     Create a PRNG with a Gumbel distribution
#
# Arguments:
#     min       Minimum value for the distribution
#     f         Factor to scale the value
#
# Result:
#     Name of a procedure that returns a Gumbel-distributed number
#
# Note:
#     The chance P(v) = exp( -exp( f*(v-min) ) )
#
proc ::simulation::random::prng_Gumbel {min f} {
    variable count

    incr count

    set name ::simulation::random::PRNG_$count

    proc $name {} [string map [list MIN $min F $f] \
    {
        return [expr {MIN + log( -log(1.0-rand()) ) / F}]
    }]

    return $name
}


# prng_chiSquared --
#     Create a PRNG with a chi-squared distribution
#
# Arguments:
#     df        Degrees of freedom
#
# Result:
#     Name of a procedure that returns a chi-squared distributed number
#     with mean 0 and standard deviation 1
#
proc ::simulation::random::prng_chiSquared {df} {
    variable count

    incr count

    set name ::simulation::random::PRNG_$count
    proc $name {} [string map [list DF $df] \
    {
        variable pi
        set y 0.0
        for { set i 0 } { $i < DF } { incr i } {
            set rad [expr {sqrt(-log(rand()))}]
            set phi [expr {2.0*$pi*rand()}]
            set r   [expr {$rad*cos($phi)}]
            set y   [expr {$y+$r*$r}]
        }
        return [expr {($y-DF)/sqrt(2.0*DF)}]
    }]

    return $name
}


# prng_Disk --
#     Create a PRNG with a uniform distribution of points on a disk
#
# Arguments:
#     rad       Radius of the disk
#
# Result:
#     Name of a procedure that returns the x- and y-coordinates of
#     such a random point
#
proc ::simulation::random::prng_Disk {rad} {
    variable count

    incr count

    set name ::simulation::random::PRNG_$count
    proc $name {} [string map [list RAD $rad] \
    {
        variable pi
        set rad [expr {RAD*sqrt(rand())}]
        set phi [expr {2.0*$pi*rand()}]
        set x   [expr {$rad*cos($phi)}]
        set y   [expr {$rad*sin($phi)}]
        return [list $x $y]
    }]

    return $name
}


# prng_Ball --
#     Create a PRNG with a uniform distribution of points within a ball
#
# Arguments:
#     rad       Radius of the ball
#
# Result:
#     Name of a procedure that returns the x-, y- and z-coordinates of
#     such a random point
#
proc ::simulation::random::prng_Ball {rad} {
    variable count

    incr count

    set name ::simulation::random::PRNG_$count
    proc $name {} [string map [list RAD $rad] \
    {
        variable pi
        set rad   [expr {RAD*pow(rand(),0.333333333333)}]
        set phi   [expr {2.0*$pi*rand()}]
        set theta [expr {acos(2.0*rand()-1.0)}]
        set x     [expr {$rad*cos($phi)*cos($theta)}]
        set y     [expr {$rad*sin($phi)*cos($theta)}]
        set z     [expr {$rad*sin($theta)}]
        return [list $x $y $z]
    }]

    return $name
}


# prng_Sphere --
#     Create a PRNG with a uniform distribution of points on the surface
#     of a sphere
#
# Arguments:
#     rad       Radius of the sphere
#
# Result:
#     Name of a procedure that returns the x-, y- and z-coordinates of
#     such a random point
#
proc ::simulation::random::prng_Sphere {rad} {
    variable count

    incr count

    set name ::simulation::random::PRNG_$count
    proc $name {} [string map [list RAD $rad] \
    {
        variable pi
        set phi   [expr {2.0*$pi*rand()}]
        set theta [expr {acos(2.0*rand()-1.0)}]
        set x     [expr {RAD*cos($phi)*cos($theta)}]
        set y     [expr {RAD*sin($phi)*cos($theta)}]
        set z     [expr {RAD*sin($theta)}]
        return [list $x $y $z]
    }]

    return $name
}


# prng_Rectangle --
#     Create a PRNG with a uniform distribution of points in a rectangle
#
# Arguments:
#     length    Length of the rectangle (x-direction)
#     width     Width of the rectangle (y-direction)
#
# Result:
#     Name of a procedure that returns the x- and y-coordinates of
#     such a random point
#
proc ::simulation::random::prng_Rectangle {length width} {
    variable count

    incr count

    set name ::simulation::random::PRNG_$count

    proc $name {} [string map [list LENGTH $length WIDTH $width] \
     {
         set x [expr {LENGTH*rand()}]
         set y [expr {WIDTH*rand()}]
         return [list $x $y]
    }]

    return $name
}


# prng_Block --
#     Create a PRNG with a uniform distribution of points in a block
#
# Arguments:
#     length    Length of the block (x-direction)
#     width     Width of the block (y-direction)
#     depth     Depth of the block (y-direction)
#
# Result:
#     Name of a procedure that returns the x-, y- and z-coordinates of
#     such a random point
#
proc ::simulation::random::prng_Block {length width depth} {
    variable count

    incr count

    set name ::simulation::random::PRNG_$count

    proc $name {} [string map [list LENGTH $length WIDTH $width DEPTH $depth] \
     {
         set x [expr {LENGTH*rand()}]
         set y [expr {WIDTH*rand()}]
         set z [expr {DEPTH*rand()}]
         return [list $x $y $z]
    }]

    return $name
}

# Announce the package
#
package provide simulation::random 0.3.1


# main --
#     Test code
#
if { 0 } {
set bin [::simulation::random::prng_Bernoulli 0.2]

set ones  0
set zeros 0
for { set i 0} {$i < 100000} {incr i} {
    if { [$bin] } {
        incr ones
    } else {
        incr zeros
    }
}

puts "Bernoulli: $ones - $zeros"

set discrete [::simulation::random::prng_Discrete 10]

for { set i 0} {$i < 100000} {incr i} {
    set v [$discrete]

    if { [info exists count($v)] } {
        incr count($v)
    } else {
        set count($v) 1
    }
}

puts "Discrete:"
parray count

set rect [::simulation::random::prng_Rectangle 10 3]

puts "Rectangle:"
for { set i 0} {$i < 10} {incr i} {
    puts [$rect]
}

set normal [::simulation::random::prng_Normal 0 1]

puts "Normal:"
for { set i 0} {$i < 10} {incr i} {
    puts [$normal]
}

#
# Timing: how fast is the normal random number generator?
#
# Surprising speed: 15 million numbers per minute!
#
puts "Normal random number generator:"
puts "[time {set value [$normal]} 30000]"
set result [lindex [time {set value [$normal]} 30000] 0]
puts "[expr {60.0e6/$result}] numbers per minute"
puts "Creating a long list: [time {lappend value [$normal]} 30000]"
puts "[lrange $value 0 20] - [llength $value] numbers in total"
set value {}
set result [lindex [time {lappend value [$normal]} 30000] 0]
puts "[expr {60.0e6/$result}] numbers per minute"

puts "Points in a rectangle:"
puts "[time {set value [$rect]} 30000]"
set result [lindex [time {set value [$rect]} 30000] 0]
puts "[expr {60.0e6/$result}] numbers per minute"

#
# A more formal test
#
package require math
unset count
set samples 100000

set lambda 10.0
set poisson [::simulation::random::prng_Poisson $lambda]
for { set i 0 } { $i < $samples } { incr i } {
    set number [$poisson]
    if { [info exists count($number)] } {
        incr count($number)
    } else {
        set count($number) 1
    }
}
parray count
for { set i 0 } { $i < 30 } { incr i } {
    set expected [expr {int($samples * pow($lambda,$i) * exp(-$lambda) / [::math::factorial $i])}]
    set exp_error [expr {sqrt($expected)}]
    if { [info exists count($i)] } {
        if { $expected-$exp_error < $count($i) &&
             $expected+$exp_error > $count($i) } {
            set okay "okay"
        } else {
            set okay "difference too large"
        }
        puts "$i $expected $count($i) - [expr {$expected/double($count($i))}] - $okay"
    } else {
        puts "$i $expected none"
    }
}
}

#
# Test hypothesis concerning rectangle
#
if { 0 } {
set r2 [::simulation::random::prng_Rectangle2 10 1]

set count_down  0
set count_up    0
set count_left  0
set count_right 0
for { set i 0 } { $i < 1000000 } { incr i } {

    foreach {x y} [$r2] {
        if { $x < 2.0 } { incr count_left  }
        if { $x > 8.0 } { incr count_right }
        if { $y < 0.2 } { incr count_down  }
        if { $y > 0.8 } { incr count_up    }
    }
}
puts "Left-right:\t$count_left\t$count_right"
puts "Up-down:   \t$count_up\t$count_down"
}

#
# Check normal distribution
#
if { 0 } {
    package require math::statistics
    set normal [::simulation::random::prng_Normal 0 1]

    for { set i 0} {$i < 1000} {incr i} {
        lappend numbers [$normal]
    }
    puts "Mean:  [::math::statistics::mean  $numbers]"
    puts "Stdev: [::math::statistics::stdev $numbers]"
}
