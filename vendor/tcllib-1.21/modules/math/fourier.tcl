# fourier.tcl --
#    Package for discrete (ordinary) and fast fourier transforms
#
# Author: Lars Hellstrom (...)
#
# The two top-level procedures defined are
#
#          dft data-list
#          inverse_dft data-list
#
# which take a list of complex numbers and apply a Discrete Fourier
# Transform (DFT) or its inverse respectively to these lists of numbers.
# A "complex number" in this case is either (i) a pair (two element
# list) of numbers, interpreted as the real and imaginary parts of the
# complex number, or (ii) a single number, interpreted as the real
# part of a complex number whose imaginary part is zero. The return
# value is always in the first format. (The DFT generally produces
# complex results even if the input is purely real.) Applying first
# one and then the other of these procedures to a list of complex
# numbers will (modulo rounding errors due to floating point
# arithmetic) return the original list of numbers.
#
# If the input length N is a power of two then these procedures will
# utilize the O(N log N) Fast Fourier Transform algorithm. If input
# length is not a power of two then the DFT will instead be computed
# using a the naive quadratic algorithm.
#
# Some examples:
#
#   % dft {1 2 3 4}
#   {10 0.0} {-2.0 2.0} {-2 0.0} {-2.0 -2.0}
#   % inverse_dft {{10 0.0} {-2.0 2.0} {-2 0.0} {-2.0 -2.0}}
#   {1.0 0.0} {2.0 0.0} {3.0 0.0} {4.0 0.0}
#   % dft {1 2 3 4 5}
#   {15.0 0.0} {-2.5 3.44095480118} {-2.5 0.812299240582} {-2.5 -0.812299240582} {-2.5 -3.44095480118}
#   % inverse_dft {{15.0 0.0} {-2.5 3.44095480118} {-2.5 0.812299240582} {-2.5 -0.812299240582} {-2.5 -3.44095480118}}
#   {1.0 0.0} {2.0 8.881784197e-17} {3.0 4.4408920985e-17} {4.0 4.4408920985e-17} {5.0 -8.881784197e-17}
                                   #
# In the last case, the imaginary parts <1e-16 would have been zero in
# exact arithmetic, but aren't here due to rounding errors.
#
# Internally, the procedures use a flat list format where every even
# index element of a list is a real part and every odd index element is
# an imaginary part. This is reflected in the variable names by Re_ and
# Im_ prefixes.
#

namespace eval ::math::fourier {
   #::math::constants pi

   namespace export dft inverse_dft lowpass highpass
}

# dft --
#     Return the discrete fourier transform as a list of complex numbers
#
# Arguments:
#     in_data     List of data (either real or complex)
# Returns:
#     List of complex amplitudes for the Fourier components
# Note:
#     The procedure uses an ordinary DFT if the number of data is
#     not a power of 2, otherwise it uses FFT.
#
proc ::math::fourier::dft {in_data} {
    # First convert to internal format
    set dataL [list]
    set n 0
    foreach datum $in_data {
        if {[llength $datum] == 1} then {
            lappend dataL $datum 0.0
        } else {
            lappend dataL [lindex $datum 0] [lindex $datum 1]
        }
        incr n
    }

    # Then compute a list of n'th roots of unity (explanation below)
    set rootL [DFT_make_roots $n -1]

    # Check if the input length is a power of two.
    set p 1
    while {$p < $n} {set p [expr {$p << 1}]}
    # By construction, $p is a power of two. If $n==$p then $n is too.

    # Finally compute the transform using Fast_DFT or Slow_DFT,
    # and convert back to the input format.
    set res [list]
    foreach {Re Im} [
        if {$p == $n} then {
            Fast_DFT $dataL $rootL
        } else {
            Slow_DFT $dataL $rootL
        }
    ] {
        lappend res [list $Re $Im]
    }
    return $res
}

# inverse_dft --
#     Invert the discrete fourier transform and return the restored data
#     as complex numbers
#
# Arguments:
#     in_data     List of fourier coefficients (either real or complex)
# Returns:
#     List of complex amplitudes for the Fourier components
# Note:
#     The procedure uses an ordinary DFT if the number of data is
#     not a power of 2, otherwise it uses FFT.
#
proc ::math::fourier::inverse_dft {in_data} {
    # First convert to internal format
    set dataL [list]
    set n 0
    foreach datum $in_data {
        if {[llength $datum] == 1} then {
            lappend dataL $datum 0.0
        } else {
            lappend dataL [lindex $datum 0] [lindex $datum 1]
        }
        incr n
    }

    # Then compute a list of n'th roots of unity (explanation below)
    set rootL [DFT_make_roots $n 1]

    # Check if the input length is a power of two.
    set p 1
    while {$p < $n} {set p [expr {$p << 1}]}
    # By construction, $p is a power of two. If $n==$p then $n is too.

    # Finally compute the transform using Fast_DFT or Slow_DFT,
    # divide by input data length to correct the amplitudes,
    # and convert back to the input format.
    set res [list]
    foreach {Re Im} [
        # $p is power of two. If $n==$p then $n is too.
        if {$p == $n} then {
            Fast_DFT $dataL $rootL
        } else {
            Slow_DFT $dataL $rootL
        }
    ] {
        lappend res [list [expr {$Re/$n}] [expr {$Im/$n}]]
    }
    return $res
}

# DFT_make_roots --
#     Return a list of the complex roots of unity or of -1
#
# Arguments:
#     n           Order of the roots
#     sign        Whether to use 1 or -1 (for inverse transform)
# Returns:
#     List of complex roots of unity or -1
#
proc ::math::fourier::DFT_make_roots {n sign} {
    set res [list]
    for {set k 0} {2*$k < $n} {incr k} {
        set alpha [expr {2*3.1415926535897931*$sign*$k/$n}]
        lappend res [expr {cos($alpha)}] [expr {sin($alpha)}]
    }
    return $res
}

# Fast_DFT --
#     Perform the fast Fourier transform
#
# Arguments:
#     dataL       List of data
#     rootL       Roots of unity or -1 to use in the transform
# Returns:
#     List of complex numbers
#
proc ::math::fourier::Fast_DFT {dataL rootL} {
    if {[llength $dataL] == 8} then {
        foreach {Re_z0 Im_z0 Re_z1 Im_z1 Re_z2 Im_z2 Re_z3 Im_z3} $dataL {break}
        if {[lindex $rootL 3] > 0} then {
            return [list\
              [expr {$Re_z0 + $Re_z1 + $Re_z2 + $Re_z3}] [expr {$Im_z0 + $Im_z1 + $Im_z2 + $Im_z3}]\
              [expr {$Re_z0 - $Im_z1 - $Re_z2 + $Im_z3}] [expr {$Im_z0 + $Re_z1 - $Im_z2 - $Re_z3}]\
              [expr {$Re_z0 - $Re_z1 + $Re_z2 - $Re_z3}] [expr {$Im_z0 - $Im_z1 + $Im_z2 - $Im_z3}]\
              [expr {$Re_z0 + $Im_z1 - $Re_z2 - $Im_z3}] [expr {$Im_z0 - $Re_z1 - $Im_z2 + $Re_z3}]]
        } else {
            return [list\
              [expr {$Re_z0 + $Re_z1 + $Re_z2 + $Re_z3}] [expr {$Im_z0 + $Im_z1 + $Im_z2 + $Im_z3}]\
              [expr {$Re_z0 + $Im_z1 - $Re_z2 - $Im_z3}] [expr {$Im_z0 - $Re_z1 - $Im_z2 + $Re_z3}]\
              [expr {$Re_z0 - $Re_z1 + $Re_z2 - $Re_z3}] [expr {$Im_z0 - $Im_z1 + $Im_z2 - $Im_z3}]\
              [expr {$Re_z0 - $Im_z1 - $Re_z2 + $Im_z3}] [expr {$Im_z0 + $Re_z1 - $Im_z2 - $Re_z3}]]
        }
    } elseif {[llength $dataL] > 8} then {
        set evenL [list]
        set oddL [list]
        foreach {Re_z0 Im_z0 Re_z1 Im_z1} $dataL {
            lappend evenL $Re_z0 $Im_z0
            lappend oddL $Re_z1 $Im_z1
        }
        set squarerootL [list]
        foreach {Re_omega0 Im_omega0 Re_omega1 Im_omega1} $rootL {
            lappend squarerootL $Re_omega0 $Im_omega0
        }
        set lowL [list]
        set highL [list]
        foreach\
          {Re_y0 Im_y0}       [Fast_DFT $evenL $squarerootL]\
          {Re_y1 Im_y1}       [Fast_DFT $oddL $squarerootL]\
          {Re_omega Im_omega} $rootL {
            set Re_y1t [expr {$Re_y1 * $Re_omega - $Im_y1 * $Im_omega}]
            set Im_y1t [expr {$Im_y1 * $Re_omega + $Re_y1 * $Im_omega}]
            lappend lowL  [expr {$Re_y0 + $Re_y1t}] [expr {$Im_y0 + $Im_y1t}]
            lappend highL [expr {$Re_y0 - $Re_y1t}] [expr {$Im_y0 - $Im_y1t}]
        }
        return [concat $lowL $highL]
    } elseif {[llength $dataL] == 4} then {
        foreach {Re_z0 Im_z0 Re_z1 Im_z1} $dataL {break}
        return [list\
          [expr {$Re_z0 + $Re_z1}] [expr {$Im_z0 + $Im_z1}]\
          [expr {$Re_z0 - $Re_z1}] [expr {$Im_z0 - $Im_z1}]]
    } else {
        return $dataL
    }
}

# Slow_DFT --
#     Perform the ordinary discrete (slow) Fourier transform
#
# Arguments:
#     dataL       List of data
#     rootL       Roots of unity or -1 to use in the transform
# Returns:
#     List of complex numbers
#
proc ::math::fourier::Slow_DFT {dataL rootL} {
    set n [expr {[llength $dataL] / 2}]

    # The missing roots are computed by complex conjugating the given
    # roots. If $n is even then -1 is also needed; it is inserted explicitly.
    set k [llength $rootL]
    if {$n % 2 == 0} then {
        lappend rootL -1.0 0.0
    }
    for {incr k -2} {$k > 0} {incr k -2} {
        lappend rootL [lindex $rootL $k]\
          [expr {-[lindex $rootL [expr {$k+1}]]}]
    }

    # This is strictly following the naive formula.
    # The product jk is kept as a separate counter variable.
    set res [list]
    for {set k 0} {$k < $n} {incr k} {
        set Re_sum 0.0
        set Im_sum 0.0
        set jk 0
        foreach {Re_z Im_z} $dataL {
            set Re_omega [lindex $rootL [expr {2*$jk}]]
            set Im_omega [lindex $rootL [expr {2*$jk+1}]]
            set Re_sum [expr {$Re_sum +
              $Re_z * $Re_omega - $Im_z * $Im_omega}]
            set Im_sum [expr {$Im_sum +
              $Im_z * $Re_omega + $Re_z * $Im_omega}]
            incr jk $k
            if {$jk >= $n} then {set jk [expr {$jk - $n}]}
        }
        lappend res $Re_sum $Im_sum
    }
    return $res
}

# lowpass --
#     Apply a low-pass filter to the Fourier transform
#
# Arguments:
#     cutoff      Cut-off frequency
#     in_data     Input transform (complex data)
# Returns:
#     Filtered transform
#
proc ::math::fourier::lowpass {cutoff in_data} {
    package require math::complexnumbers

    set res    [list]
    set cutoff [list $cutoff 0.0]
    set f      0.0
    foreach a $in_data {
       set an [::math::complexnumbers::/ $a \
                  [::math::complexnumbers::+ {1.0 0.0} \
                      [::math::complexnumbers::/ [list 0.0 $f] $cutoff]]]
       lappend res $an
       set f [expr {$f+1.0}]
    }

    return $res
}

# highpass --
#     Apply a high-pass filter to the Fourier transform
#
# Arguments:
#     cutoff      Cut-off frequency
#     in_data     Input transform (complex data)
# Returns:
#     Filtered transform (high-pass)
#
proc ::math::fourier::highpass {cutoff in_data} {
    package require math::complexnumbers

    set res    [list]
    set cutoff [list $cutoff 0.0]
    set f      0.0
    foreach a $in_data {
       set ff [::math::complexnumbers::/ [list 0.0 $f] $cutoff]
       set an [::math::complexnumbers::/ $ff \
                  [::math::complexnumbers::+ {1.0 0.0} $ff]]
       lappend res $an
       set f [expr {$f+1.0}]
    }

    return $res
}

#
# Announce the package
#
package provide math::fourier 1.0.2

# test --
#
proc test_dft {points {real 0} {iterations 20}} {
    set in_dataL [list]
    for {set k 0} {$k < $points} {incr k} {
        if {$real} then {
            lappend in_dataL [expr {2*rand()-1}]
        } else {
            lappend in_dataL [list [expr {2*rand()-1}] [expr {2*rand()-1}]]
        }
    }
    set time1 [time {
        set conv_dataL [::math::fourier::dft $in_dataL]
    } $iterations]
    set time2 [time {
        set out_dataL [::math::fourier::inverse_dft $conv_dataL]
    } $iterations]
    set err 0.0
    foreach iz $in_dataL oz $out_dataL {
        if {$real} then {
            foreach {o1 o2} $oz {break}
            set err [expr {$err + ($i-$o1)*($i-$o1) + $o2*$o2}]
        } else {
            foreach i $iz o $oz {
                set err [expr {$err + ($i-$o)*($i-$o)}]
            }
        }
    }
    return [format "Forward: %s\nInverse: %s\nAverage error: %g"\
      $time1 $time2 [expr {sqrt($err/$points)}]]
}

# Note:
# Add simple filters

if { 0 } {
puts [::math::fourier::dft {1 2 3 4}]
puts [::math::fourier::inverse_dft {{10 0.0} {-2.0 2.0} {-2 0.0} {-2.0 -2.0}}]
puts [::math::fourier::dft {1 2 3 4 5}]
puts [::math::fourier::inverse_dft {{15.0 0.0} {-2.5 3.44095480118} {-2.5 0.812299240582} {-2.5 -0.812299240582} {-2.5 -3.44095480118}}]
puts [test_dft 10]
puts [test_dft 16]
puts [test_dft 100]
puts [test_dft 128]

puts [::math::fourier::dft {1 2 3 4}]
puts [::math::fourier::lowpass 1.5 [::math::fourier::dft {1 2 3 4}]]
}
