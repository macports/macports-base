# machineparameters.tcl --
#   Compute double precision machine parameters.
#
# Description
#   This the Tcl equivalent of the DLAMCH LAPCK function.
#   In floating point systems, a floating point number is represented
#   by
#   x = +/- d1 d2 ... dt basis^e
#   where digits satisfy
#   0 <= di <= basis - 1, i = 1, t
#   with the convention :
#   - t is the size of the mantissa
#   - basis is the basis (the "radix")
#
# References
#
#   "Algorithms to Reveal Properties of Floating-Point Arithmetic"
#   Michael A. Malcolm
#   Stanford University
#   Communications of the ACM
#   Volume 15 ,  Issue 11  (November 1972)
#   Pages: 949 - 951
#
#   "More on Algorithms that Reveal Properties of Floating
#   Point Arithmetic Units"
#   W. Morven Gentleman, University of Waterloo
#   Scott B. Marovich, Purdue University
#   Communications of the ACM
#   Volume 17 ,  Issue 5  (May 1974)
#   Pages: 276 - 277
#
# Example
#
#   In the following example, one compute the parameters of a desktop
#   under Linux with the following Tcl 8.4.19 properties :
#
#% parray tcl_platform
#tcl_platform(byteOrder) = littleEndian
#tcl_platform(machine)   = i686
#tcl_platform(os)        = Linux
#tcl_platform(osVersion) = 2.6.24-19-generic
#tcl_platform(platform)  = unix
#tcl_platform(tip,268)   = 1
#tcl_platform(tip,280)   = 1
#tcl_platform(user)      = <username>
#tcl_platform(wordSize)  = 4
#
#   The following example creates a machineparameters object,
#   computes the properties and displays it.
#
#     set pp [machineparameters create %AUTO%]
#     $pp compute
#     $pp print
#     $pp destroy
#
#   This prints out :
#
#     Machine parameters
#     Epsilon : 1.11022302463e-16
#     Beta : 2
#     Rounding : proper
#     Mantissa : 53
#     Maximum exponent : 1024
#     Minimum exponent : -1021
#     Overflow threshold : 8.98846567431e+307
#     Underflow threshold : 2.22507385851e-308
#
#   That compares well with the results produced by Lapack 3.1.1 :
#
#     Epsilon                      =   1.11022302462515654E-016
#     Safe minimum                 =   2.22507385850720138E-308
#     Base                         =    2.0000000000000000
#     Precision                    =   2.22044604925031308E-016
#     Number of digits in mantissa =    53.000000000000000
#     Rounding mode                =   1.00000000000000000
#     Minimum exponent             =   -1021.0000000000000
#     Underflow threshold          =   2.22507385850720138E-308
#     Largest exponent             =    1024.0000000000000
#     Overflow threshold           =   1.79769313486231571E+308
#     Reciprocal of safe minimum   =   4.49423283715578977E+307
#
# Copyright 2008 Michael Baudin
#
package require Tcl 8.4
package require snit
package provide math::machineparameters 0.1

snit::type machineparameters {
  # Epsilon is the smallest value so that 1+epsilon>1 is false
  variable epsilon 0
  # basis is the basis of the floating-point representation.
  # basis is usually 2, i.e. binary representation (for example IEEE 754 machines),
  # but some machines (like HP calculators for example) uses 10, or 16, etc...
  variable basis 0
  # The rounding mode used on the machine.
  # The rounding occurs when more than t digits would be required to
  # represent the number.
  # Two modes can be determined with the current system :
  # "chop" means than only t digits are kept, no matter the value of the number
  # "proper" means that another rounding mode is used, be it "round to nearest",
  #   "round up", "round down".
  variable rounding ""
  # the size of the mantissa
  variable mantissa 0
  # The first non-integer is A = 2^m with m is the
  # smallest positive integer so that fl(A+1)=A
  variable firstnoninteger 0
  # Maximum number of iterations in loops
  option -maxiteration 10000
  # Set to 1 to enable verbose logging
  option -verbose -default 0
  # The largest positive exponent before overflow occurs
  variable exponentmax 0
  # The largest negative exponent before (gradual) underflow occurs
  variable exponentmin 0
  # Largest positive value before overflow occurs
  variable vmax
  # Largest negative value before (gradual) underflow occurs
  variable vmin
  #
  # compute --
  #   Computes the machine parameters.
  #
  method compute {} {
    $self log "compute"
    $self computeepsilon
    $self computefirstnoninteger
    $self computebasis
    $self computerounding
    $self computemantissa
    $self computeemax
    $self computeemin
    return ""
  }
  #
  # computeepsilon --
  #   Find epsilon the minimum value for which 1.0 + epsilon > 1.0
  #
  method computeepsilon {} {
    $self log "computeepsilon"
    set factor 2.
    set epsilon 0.5
    for {set i 0} {$i<$options(-maxiteration)} {incr i} {
      $self log "$i/$options(-maxiteration) : $epsilon"
      set epsilon [expr {$epsilon / $factor}]
      set inequality [expr {1.0+$epsilon>1.0}]
      if {$inequality==0} then {
        break
      }
    }
    $self log "epsilon : $epsilon (after $i loops)"
    return ""
  }
  #
  # computefirstnoninteger --
  #   Compute the first positive non-integer real.
  #   It is the smallest a such that (a+1)-a is different from 1
  #
  method computefirstnoninteger {} {
    $self log "computefirstnoninteger"
    set firstnoninteger 2.
    for {set i 0} {$i < $options(-maxiteration)} {incr i} {
      $self log "$i/$options(-maxiteration) : $firstnoninteger"
      set firstnoninteger [expr {2.*$firstnoninteger}]
      set one [expr {($firstnoninteger+1.)-$firstnoninteger}]
      if {$one!=1.} then {
        break
      }
    }
    $self log "Found firstnoninteger : $firstnoninteger"
    return ""
  }
  #
  # computebasis --
  #   Compute the basis (basis)
  #
  method computebasis {} {
    $self log "computebasis"
    #
    # Compute b where b is the smallest real so that fl(a+b)> a,
    # where a is the first non integer.
    # Note :
    #  With floating point numbers, a+1==a !
    #  b is denoted by "B" in Malcolm's algorithm
    #
    set b 1
    for {set i 0} {$i < $options(-maxiteration)} {incr i} {
      $self log "$i/$options(-maxiteration) : $b"
      set basis [expr {int(($firstnoninteger+$b)-$firstnoninteger)}]
      if {$basis!=0.} then {
        break
      }
      incr b
    }
    $self log "Found basis : $basis"
    return ""
  }
  #
  # computerounding --
  #   Compute the rounding mode.
  # Note:
  #   This corresponds to DLAMCH implementation (DLAMC1 exactly).
  #
  method computerounding {} {
    $self log "computerounding"
    # Now determine whether rounding or chopping occurs,  by adding a
    # bit  less  than  beta/2  and a  bit  more  than  beta/2  to  a (=firstnoninteger).
    set F [expr {$basis/2.0 - $basis/100.0}]
    set C [expr {$F + $firstnoninteger}]
    if {$C==$firstnoninteger} then {
      set rounding "proper"
    } else {
      set rounding "chop"
    }
    set F [expr {$basis/2.0 + $basis/100.0}]
    set C [expr {$F + $firstnoninteger}]
    if {$rounding=="proper" && $C==$firstnoninteger} then {
      set rounding "chop"
    }
    $self log "Found rounding : $rounding"
    return ""
  }
  #
  # computemantissa --
  #   Compute the mantissa size
  #
  method computemantissa {} {
    $self log "computemantissa"
    set a 1.
    set mantissa 0
    for {set i 0} {$i < $options(-maxiteration)} {incr i} {
      incr mantissa
      $self log "$i/$options(-maxiteration) : $mantissa"
      set a [expr {$a * double($basis)}]
      set one [expr {($a+1)-$a}]
      if {$one!=1.} then {
        break
      }
    }
    $self log "Found mantissa : $mantissa"
    return ""
  }
  #
  # computeemax --
  #   Compute the maximum exponent before overflow
  #
  method computeemax {} {
    $self log "computeemax"
    set vmax 1.
    set exponentmax 1
    for {set i 0} {$i < $options(-maxiteration)} {incr i} {
      $self log "Iteration #$i , exponentmax = $exponentmax, vmax = $vmax"
      incr exponentmax
      # Condition #1 : no exception is generated
      set errflag [catch {
        set new [expr {$vmax * $basis}]
      }]
      if {$errflag!=0} then {
        break
      }
      # Condition #2 : one can recover the original number
      if {$new / $basis != $vmax} then {
        break
      }
      set vmax $new
    }
    incr exponentmax -1
    $self log "Exponent maximum : $exponentmax"
    $self log "Value maximum : $vmax"
    return ""
  }
  #
  # computeemin --
  #   Compute the minimum exponent before underflow
  #
  method computeemin {} {
    $self log "computeemin"
    set vmin 1.
    set exponentmin 1
    for {set i 0} {$i < $options(-maxiteration)} {incr i} {
      $self log "Iteration #$i , exponentmin = $exponentmin, vmin = $vmin"
      incr exponentmin -1
      # Condition #1 : no exception is generated
      set errflag [catch {
        set new [expr {$vmin / $basis}]
      }]
      if {$errflag!=0} then {
        break
      }
      # Condition #2 : one can recover the original number
      if {$new * $basis != $vmin} then {
        break
      }
      set vmin $new
    }
    incr exponentmin +1
    # See in DMALCH.f, DLAMC2 relative to IEEE machines.
    # TODO : what happens on non-IEEE machine ?
    set exponentmin [expr {$exponentmin - 1 + $mantissa}]
    set vmin [expr {$vmin * pow($basis,$mantissa-1)}]
    $self log "Exponent minimum : $exponentmin"
    $self log "Value minimum : $vmin"
    return ""
  }
  #
  # log --
  #   Puts the given message on standard output.
  #
  method log {msg} {
    if {$options(-verbose)==1} then {
      puts "(mp) $msg"
    }
    return ""
  }
  #
  # get --
  #   Return value for key
  #
  method get {key} {
    $self log "get $key"
    switch -- $key {
      -epsilon {
        set result $epsilon
      }
      -rounding {
        set result $rounding
      }
      -basis {
        set result $basis
      }
      -mantissa {
        set result $mantissa
      }
      -exponentmax {
        set result $exponentmax
      }
      -exponentmin {
        set result $exponentmin
      }
      -vmax {
        set result $vmax
      }
      -vmin {
        set result $vmin
      }
      default {
        error "Unknown key $key"
      }
    }
    return $result
  }
  #
  # print --
  #   Print machine parameters on standard output
  #
  method print {} {
    set str [$self tostring]
    puts "$str"
    return ""
  }
  #
  # tostring --
  #   Return a report for machine parameters
  #
  method tostring {} {
    set str ""
    append str "Machine parameters\n"
    append str  "Epsilon : $epsilon\n"
    append str "Basis : $basis\n"
    append str "Rounding : $rounding\n"
    append str "Mantissa : $mantissa\n"
    append str "Maximum exponent before overflow : $exponentmax\n"
    append str "Minimum exponent before underflow : $exponentmin\n"
    append str "Overflow threshold : $vmax\n"
    append str "Underflow threshold : $vmin\n"
    return $str
  }
}
